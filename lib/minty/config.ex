defmodule Minty.Config do
  @moduledoc false
  @enforce_keys [:address]
  defstruct [
    # protocol options
    :address, transport_opts: [], protocols: [], proxy: nil, proxy_headers: [],

    # genserver options
    name: nil,
  ]

  def http2(uri_or_opts, opts) do
    case new(uri_or_opts, opts) do
      %__MODULE__{address: {scheme, _, _}} when scheme != :https ->
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

  def gen_server_opts(%__MODULE__{} = config) do
    config
    |> Map.take([:name])
    |> Map.to_list()
    |> Enum.filter(fn({_, v}) -> v != nil end)
  end

  defp new(uri, opts) when is_binary(uri) and is_list(opts) do
    %URI{scheme: scheme, host: host, port: port} = URI.parse(uri)
    new(Keyword.put(opts, :address, {scheme(scheme), host, port}))
  end

  defp new(opts, _) when is_list(opts) do
    new(opts)
  end

  defp new(opts) when is_list(opts) do
    struct = struct!(__MODULE__, opts)
    Enum.reduce(Map.keys(struct), struct, &cast/2)
  end

  defp cast(:address, %__MODULE__{address: {s, h, p}} = config) do
    %__MODULE__{config|address: {scheme(s), h, p}}
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
