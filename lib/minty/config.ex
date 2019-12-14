defmodule Minty.Config do
  @moduledoc false
  @enforce_keys [:scheme, :host, :port]
  defstruct [
    # protocol options
    :scheme, :host, :port, transport_opts: [], protocols: [], proxy: nil, proxy_headers: [],
  ]

  def http2(uri_or_opts, opts) do
    case new(uri_or_opts, opts) do
      %__MODULE__{scheme: scheme} when scheme != :https ->
        {:error, :https_only}

      %__MODULE__{proxy: {scheme, _, _, _}} when scheme != :http ->
        {:error, :proxy_http_only}

      %__MODULE__{} = config ->
        {:ok, %{config|protocols: [:http2]}}
    end
  end

  def conn_opts(%__MODULE__{} = config) do
    config
    |> Map.take([:transport_opts, :protocols, :proxy, :proxy_headers])
    |> Map.to_list()
  end

  defp new(uri, opts) when is_binary(uri) and is_list(opts) do
    %URI{scheme: scheme, host: host, port: port} = URI.parse(uri)
    new(Keyword.merge(opts, [scheme: scheme(scheme), host: host, port: port]))
  end

  defp new(opts, _) when is_list(opts) do
    new(opts)
  end

  defp new(opts) when is_list(opts) do
    struct = struct!(__MODULE__, opts)
    Enum.reduce(Map.keys(struct), struct, &cast/2)
  end

  defp cast(:scheme, %__MODULE__{scheme: scheme} = config) do
    %__MODULE__{config|scheme: scheme(scheme)}
  end

  defp cast(:proxy, %__MODULE__{proxy: proxy} = config) when is_binary(proxy) do
    %URI{scheme: scheme, host: host, port: port} = URI.parse(proxy)
    %__MODULE__{config|proxy: {scheme(scheme), host, port, []}}
  end

  defp cast(_field, %__MODULE__{} = config) do
    config
  end

  defp scheme("https"), do: :https
  defp scheme("http"), do: :http
  defp scheme(:https), do: :https
  defp scheme(:http), do: :http
end
