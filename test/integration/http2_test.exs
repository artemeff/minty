defmodule Integration.HTTP2Test do
  use ExUnit.Case

  alias Minty.HTTP2

  @moduletag :integration

  setup %{conn_args: conn_args} do
    {:ok, conn} = apply(HTTP2, :start_link, conn_args)
    {:ok, conn: conn}
  end

  describe "httpbin.org" do
    @describetag conn_args: ["https://httpbin.org"]

    test "making requests", %{conn: conn} do
      assert {:ok, %Minty.Response{status: 200}}
            = HTTP2.request(conn, "GET", "/bytes/1", [], nil)
    end

    test "respond with large body", %{conn: conn} do
      assert {:ok, %Minty.Response{status: 200, body: body}}
            = HTTP2.request(conn, "GET", "/bytes/#{1024 * 64}", [], nil)
      assert byte_size(body) == 1024 * 64
    end

    test "simultaneously", %{conn: conn} do
      refs =
        for _ <- 1..10 do
          Task.async(fn ->
            HTTP2.request(conn, "GET", "/bytes/1024", [], nil)
          end)
        end

      Enum.each(refs, fn(ref) ->
        assert {:ok, %Minty.Response{status: 200}} = Task.await(ref)
      end)
    end

    test "simultaneously with big response body", %{conn: conn} do
      refs =
        for _ <- 1..10 do
          Task.async(fn ->
            HTTP2.request(conn, "GET", "/bytes/#{1024 * 64}", [], nil, timeout: 15_000)
          end)
        end

      Enum.each(refs, fn(ref) ->
        assert {:ok, %Minty.Response{status: 200}} = Task.await(ref, 15_000)
      end)
    end

    test "ping", %{conn: conn} do
      assert {:ok, :pong} == HTTP2.ping(conn)
    end

    test "errors", %{conn: conn} do
      assert {:error, :timeout}
            = HTTP2.request(conn, "GET", "/delay/10", [], nil)
    end
  end

  describe "httpbin.org robust" do
    @describetag conn_args: ["https://httpbin.org", [
      robust: true,
    ]]

    test "making requests", %{conn: conn} do
      assert {:ok, %Minty.Response{status: 200}}
            = HTTP2.request(conn, "GET", "/bytes/1", [], nil)
    end

    test "respond with large body", %{conn: conn} do
      assert {:ok, %Minty.Response{status: 200, body: body}}
            = HTTP2.request(conn, "GET", "/bytes/#{1024 * 64}", [], nil)
      assert byte_size(body) == 1024 * 64
    end

    test "simultaneously", %{conn: conn} do
      refs =
        for _ <- 1..10 do
          Task.async(fn ->
            HTTP2.request(conn, "GET", "/bytes/1024", [], nil)
          end)
        end

      Enum.each(refs, fn(ref) ->
        assert {:ok, %Minty.Response{status: 200}} = Task.await(ref)
      end)
    end

    test "simultaneously with big response body", %{conn: conn} do
      refs =
        for _ <- 1..10 do
          Task.async(fn ->
            HTTP2.request(conn, "GET", "/bytes/#{1024 * 64}", [], nil, timeout: 15_000)
          end)
        end

      Enum.each(refs, fn(ref) ->
        assert {:ok, %Minty.Response{status: 200}} = Task.await(ref, 15_000)
      end)
    end

    test "ping", %{conn: conn} do
      assert {:ok, :pong} == HTTP2.ping(conn)
    end

    test "errors", %{conn: conn} do
      assert {:error, :timeout}
            = HTTP2.request(conn, "GET", "/delay/10", [], nil)
    end
  end

  describe "httpbin.org through proxy" do
    @describetag :proxy
    @describetag conn_args: ["https://httpbin.org", [
      proxy: {:http, "localhost", 8888, []},
      transport_opts: [verify: :verify_none],
    ]]

    test "making requests", %{conn: conn} do
      assert {:ok, %Minty.Response{status: 200}}
            = HTTP2.request(conn, "GET", "/bytes/1", [], nil)
    end

    test "respond with large body", %{conn: conn} do
      assert {:ok, %Minty.Response{status: 200, body: body}}
            = HTTP2.request(conn, "GET", "/bytes/#{1024 * 64}", [], nil)
      assert byte_size(body) == 1024 * 64
    end

    test "simultaneously", %{conn: conn} do
      refs =
        for _ <- 1..10 do
          Task.async(fn ->
            HTTP2.request(conn, "GET", "/bytes/1024", [], nil)
          end)
        end

      Enum.each(refs, fn(ref) ->
        assert {:ok, %Minty.Response{status: 200}} = Task.await(ref)
      end)
    end

    test "simultaneously with big response body", %{conn: conn} do
      refs =
        for _ <- 1..10 do
          Task.async(fn ->
            HTTP2.request(conn, "GET", "/bytes/#{1024 * 64}", [], nil, timeout: 15_000)
          end)
        end

      Enum.each(refs, fn(ref) ->
        assert {:ok, %Minty.Response{status: 200}} = Task.await(ref, 15_000)
      end)
    end

    test "ping", %{conn: conn} do
      assert {:ok, :pong} == HTTP2.ping(conn)
    end

    test "errors", %{conn: conn} do
      assert {:error, :timeout}
            = HTTP2.request(conn, "GET", "/delay/10", [], nil)
    end
  end

  describe "httpbin.org through proxy with auth" do
    @describetag :proxy_auth
    @describetag conn_args: ["https://httpbin.org", [
      proxy: {:http, "localhost", 8888, []},
      proxy_headers: [{"proxy-authorization", "basic #{Base.encode64("user:password")}"}],
      transport_opts: [verify: :verify_none],
    ]]

    test "making requests", %{conn: conn} do
      assert {:ok, %Minty.Response{status: 200}}
            = HTTP2.request(conn, "GET", "/bytes/1", [], nil)
    end

    test "respond with large body", %{conn: conn} do
      assert {:ok, %Minty.Response{status: 200, body: body}}
            = HTTP2.request(conn, "GET", "/bytes/#{1024 * 64}", [], nil)
      assert byte_size(body) == 1024 * 64
    end

    test "simultaneously", %{conn: conn} do
      refs =
        for _ <- 1..10 do
          Task.async(fn ->
            HTTP2.request(conn, "GET", "/bytes/1024", [], nil)
          end)
        end

      Enum.each(refs, fn(ref) ->
        assert {:ok, %Minty.Response{status: 200}} = Task.await(ref)
      end)
    end

    test "simultaneously with big response body", %{conn: conn} do
      refs =
        for _ <- 1..10 do
          Task.async(fn ->
            HTTP2.request(conn, "GET", "/bytes/#{1024 * 64}", [], nil, timeout: 15_000)
          end)
        end

      Enum.each(refs, fn(ref) ->
        assert {:ok, %Minty.Response{status: 200}} = Task.await(ref, 15_000)
      end)
    end

    test "ping", %{conn: conn} do
      assert {:ok, :pong} == HTTP2.ping(conn)
    end

    test "errors", %{conn: conn} do
      assert {:error, :timeout}
            = HTTP2.request(conn, "GET", "/delay/10", [], nil)
    end
  end
end
