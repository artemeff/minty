defmodule Minty.HTTP2.Conn do
  use GenServer

  require Logger

  def start_link(uri_or_opts, opts \\ []) when is_list(opts) do
    case Minty.Config.http2(uri_or_opts, opts) do
      {:ok, config} ->
        GenServer.start_link(__MODULE__, config, Keyword.take(opts, [:name, :timeout, :debug, :spawn_opt]))

      {:error, reason} ->
        {:error, reason}
    end
  end

  def request(conn, method, path, headers, body, opts \\ []) do
    GenServer.call(conn, {:request, {method, path, headers, body}}, Keyword.get(opts, :timeout, 5000))
  end

  def ping(conn, payload \\ :binary.copy(<<0>>,  8)) do
    GenServer.call(conn, {:ping, payload})
  end

  # GenServer callbacks

  defmodule State do
    defstruct [
      # Mint.HTTP.t() connection
      conn: nil,

      # connection configuration
      conn_config: nil,

      # request references, used to determine caller for response
      refs: %{},

      # maximum number of request for this connection
      max_requests: 0,

      # pending requests, like queue when HTTP2 stream overflow
      pending: [],

      # inflight requests, sended but something went wrong with connection,
      # used to survive sended reeequests between reconnections
      inflight: [],

      # collected responses from `Mint.HTTP2.stream/2`s
      responses: [],
    ]
  end

  def init(config) do
    {:ok, %State{conn_config: config}, {:continue, :connect}}
  end

  defp connect(%Minty.Config{proxy: nil} = config) do
    Mint.HTTP2.connect(:https, config.host, config.port, Minty.Config.conn_opts(config))
  end

  defp connect(%Minty.Config{proxy: proxy} = config) do
    Mint.TunnelProxy.connect(proxy, {config.scheme, config.host, config.port, Minty.Config.conn_opts(config)})
  end

  def handle_continue(:connect, %State{conn_config: config} = state) do
    case connect(config) do
      {:ok, conn} ->
        mcs = Mint.HTTP2.get_server_setting(conn, :max_concurrent_streams)
        {:noreply, %State{state|conn: conn, max_requests: mcs,
                                refs: %{}, responses: []}, {:continue, :process_inflight}}

      {:error, reason} ->
        {:stop, {:error, reason}, state}
    end
  end

  def handle_continue(:process_inflight, %State{inflight: []} = state) do
    {:noreply, state, {:continue, :process_pending}}
  end

  def handle_continue(:process_inflight, %State{inflight: [{from, request} | inflight]} = state) do
    case make_request(request, from, state) do
      {:noreply, state} ->
        {:noreply, %State{state|inflight: inflight}, {:continue, :process_inflight}}

      {:noreply, state, continue} ->
        {:noreply, state, continue}
    end
  end

  def handle_continue(:process_pending, %State{pending: []} = state) do
    {:noreply, state}
  end

  def handle_continue(:process_pending, %State{pending: [{from, request} | tail]} = state) do
    if Mint.HTTP2.open_request_count(state.conn) < state.max_requests do
      state = %State{state|pending: tail}

      case make_request(request, from, %State{state|inflight: state.inflight ++ [{from, request}]}) do
        {:noreply, state} -> {:noreply, state}
        {:noreply, state, continue} -> {:noreply, state, continue}
      end
    else
      {:noreply, state}
    end
  end

  def handle_call({:request, request}, from, state) do
    if Mint.HTTP2.open_request_count(state.conn) < state.max_requests do
      make_request(request, from, %State{state|inflight: state.inflight ++ [{from, request}]})
    else
      {:noreply, %State{state|pending: state.pending ++ [{from, request}]}}
    end
  end

  def handle_call({:ping, payload}, from, state) do
    case Mint.HTTP2.ping(state.conn, payload) do
      {:ok, conn, ref} ->
        {:noreply, %State{state|conn: conn, refs: Map.put(state.refs, ref, from)}}

      {:error, conn, reason} ->
        {:reply, {:error, reason}, %State{state|conn: conn}}
    end
  end

  defp make_request({method, path, headers, body}, from, state) do
    case Mint.HTTP2.request(state.conn, method, path, headers, body) do
      {:ok, conn, ref} ->
        {:noreply, %State{state|conn: conn, refs: Map.put(state.refs, ref, from)}}

      {:error, conn, %Mint.HTTPError{} = error} ->
        state = close_connection(error, state)
        {:noreply, %State{state|conn: conn}, {:continue, :connect}}

      {:error, conn, %Mint.TransportError{} = error} ->
        state = close_connection(error, state)
        {:noreply, %State{state|conn: conn}, {:continue, :connect}}
    end
  end

  def handle_info(message, state) do
    case Mint.HTTP2.stream(state.conn, message) do
      :unknown ->
        {:noreply, state}

      {:ok, conn, []} ->
        {:noreply, %State{state|conn: conn}}

      {:ok, conn, responses} ->
        state = handle_responses(responses, state)
        state = %State{state|conn: conn}

        if state.inflight == [] && state.responses == [] && length(state.pending) > 0
            && Mint.HTTP2.open_request_count(state.conn) < state.max_requests do
          {:noreply, state, {:continue, :process_pending}}
        else
          {:noreply, state}
        end

      {:error, conn, error, reason} ->
        state = close_connection(error, state)
        {:noreply, %State{state|conn: conn}, {:continue, :connect}}
    end
  end

  defp close_connection(_reason, state) do
    state
  end

  defp handle_responses(responses, state) do
    case pop_responses(state.responses ++ responses) do
      {:ok, ref, reply, tail_responses} ->
        state = reply_response(ref, reply, state)
        handle_responses([], %State{state|responses: tail_responses})

      :done ->
        %State{state|responses: []}

      {:wait, partial_responses} ->
        %State{state|responses: partial_responses}

    end
  end

  defp reply_response(ref, message, %State{} = state) do
    case Map.fetch(state.refs, ref) do
      {:ok, from} ->
        GenServer.reply(from, message)
        %State{state|refs: Map.delete(state.refs, ref),
                     inflight: List.keydelete(state.inflight, from, 0)}

      :error ->
        Logger.error("#{inspect(__MODULE__)}.response unknown ref #{inspect(ref)}")
        state
    end
  end

  defp pop_responses([]) do
    :done
  end

  defp pop_responses([{:pong, ref} | t]) do
    {:ok, ref, {:ok, :pong}, t}
  end

  defp pop_responses([{:status, ref, status}, {:headers, ref, headers}, {:data, ref, data}, {:done, ref} | t]) do
    {:ok, ref, {:ok, %Minty.Response{status: status, headers: headers, body: data}}, t}
  end

  defp pop_responses([{:status, ref, status} | t] = responses) do
    if Enum.member?(t, {:done, ref}) do
      {accumulated, tail} =
        Enum.reduce_while(t, {%Minty.Response{body: <<>>}, []}, fn
          ({:headers, ^ref, headers}, {response, list}) ->
            {:cont, {%{response|headers: headers}, list}}

          ({:data, ^ref, data}, {response, list}) ->
            {:cont, {%{response|body: <<response.body :: binary, data :: binary>>}, list}}

          ({:done, ^ref}, acc) ->
            {:halt, acc}

          (_, acc) ->
            acc
        end)

      {:ok, ref, {:ok, %Minty.Response{accumulated|status: status}}, tail}
    else
      {:wait, responses}
    end
  end

  defp pop_responses(responses) do
    {:wait, responses}
  end
end
