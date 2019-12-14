defmodule Integration.HTTP2Test do
  use ExUnit.Case

  alias Minty.HTTP2.Conn

  describe "nghttp2.org" do
    @describetag :integration

    test "making requests" do
      assert {:ok, conn} = Conn.start_link("https://nghttp2.org")
      assert {:ok, %Minty.Response{status: 200}} = Conn.request(conn, "GET", "/httpbin/bytes/1", [], nil)
    end

    test "respond with large body" do
      assert {:ok, conn} = Conn.start_link("https://nghttp2.org")
      assert {:ok, %Minty.Response{status: 200, body: body}}
           = Conn.request(conn, "GET", "/httpbin/bytes/#{1024 * 64}", [], nil)
      assert byte_size(body) == 1024 * 64
    end

    test "ping" do
      assert {:ok, conn} = Conn.start_link("https://nghttp2.org")
      assert {:ok, :pong} == Conn.ping(conn)
    end
  end

  describe "proxy" do
    @describetag :proxy

    test "to nghttp2.org" do
      opts = [
        proxy: {:http, "localhost", 8888, []},
        transport_opts: [verify: :verify_none],
      ]

      assert {:ok, conn} = Conn.start_link("https://nghttp2.org", opts)
      assert {:ok, %Minty.Response{status: 200}} = Conn.request(conn, "GET", "/httpbin/bytes/24", [], nil)
    end
  end

  describe "proxy with auth" do
    @describetag :proxy_auth

    test "to nghttp2.org" do
      opts = [
        proxy: {:http, "localhost", 8888, []},
        proxy_headers: [{"proxy-authorization", "basic #{Base.encode64("user:password")}"}],
        transport_opts: [verify: :verify_none],
      ]

      assert {:ok, conn} = Conn.start_link("https://nghttp2.org", opts)
      assert {:ok, %Minty.Response{status: 200}} = Conn.request(conn, "GET", "/httpbin/bytes/24", [], nil)
    end
  end
end
