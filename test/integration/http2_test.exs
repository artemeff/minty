defmodule Integration.HTTP2Test do
  use ExUnit.Case
  use Minty.Shared

  alias Minty.HTTP2.Conn

  @moduletag :integration

  setup %{conn_args: conn_args} do
    {:ok, conn} = apply(Conn, :start_link, conn_args)
    {:ok, conn: conn}
  end

  describe "nghttp2.org" do
    @describetag conn_args: ["https://nghttp2.org"]

    shared_http2_nghttp2()
  end

  describe "nghttp2.org through proxy" do
    @describetag :proxy
    @describetag conn_args: ["https://nghttp2.org", [
      proxy: {:http, "localhost", 8888, []},
      transport_opts: [verify: :verify_none],
    ]]

    shared_http2_nghttp2()
  end

  describe "nghttp2.org through proxy with auth" do
    @describetag :proxy_auth
    @describetag conn_args: ["https://nghttp2.org", [
      proxy: {:http, "localhost", 8888, []},
      proxy_headers: [{"proxy-authorization", "basic #{Base.encode64("user:password")}"}],
      transport_opts: [verify: :verify_none],
    ]]

    shared_http2_nghttp2()
  end
end
