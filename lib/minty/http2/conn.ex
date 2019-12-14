defmodule Minty.HTTP2.Conn do
  use GenServer

  require Logger

  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, Keyword.take(opts, [:name, :timeout, :debug, :spawn_opt]))
  end

  def start_link(uri) when is_binary(uri) do
    start_link(uri, [])
  end

  def start_link(uri, opts) when is_binary(uri) and is_list(opts) do
    case URI.parse(uri) do
      %URI{scheme: "https", host: host, port: port} ->
        start_link(Keyword.merge(opts, [host: host, port: port]))

      %URI{} ->
        {:error, :https_only}
    end
  end

  def request(conn, method, path, headers, body) do
    GenServer.call(conn, {:request, {method, path, headers, body}})
  end

  # GenServer callbacks

  defmodule State do
    defstruct [
      # Mint.HTTP.t() connection
      conn: nil,

      # credentials for connection
      conn_credentials: nil,

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

  def init(opts) do
    conn_opts =
      opts
      |> Keyword.take([:transport_opts, :mode, :proxy, :proxy_headers, :client_settings])
      |> Keyword.put(:protocols, [:http2])

    with {:ok, host} <- Keyword.fetch(opts, :host),
         {:ok, port} <- Keyword.fetch(opts, :port)
    do
      {:ok, %State{conn_credentials: {host, port, conn_opts}}, {:continue, :connect}}
    end
  end

  defp connect(nil, {host, port, conn_opts}) do
    Mint.HTTP2.connect(:https, host, port, conn_opts)
  end

  defp connect({:https, _, _, _}, _) do
    {:error, :proxy_http_only}
  end

  defp connect(proxy, {host, port, conn_opts}) do
    Mint.TunnelProxy.connect(proxy, {:https, host, port, conn_opts})
  end

  def handle_continue(:connect, %State{conn_credentials: {host, port, conn_opts}} = state) do
    {proxy, conn_opts} = Keyword.pop(conn_opts, :proxy)

    case connect(proxy, {host, port, conn_opts}) do
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

  defp pop_responses([{:status, ref, status}, {:headers, ref, headers}, {:data, ref, data}, {:done, ref} | tail]) do
    {:ok, ref, {:ok, %Minty.Response{status: status, headers: headers, body: data}}, tail}
  end

  defp pop_responses(responses) do
    {:wait, responses}
  end
end
