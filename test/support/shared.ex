defmodule Minty.Shared do
  defmacro __using__(_opts \\ []) do
    quote do
      require Minty.Shared
      import Minty.Shared
    end
  end

  defmacro shared_http2_nghttp2 do
    quote do
      test "making requests", %{conn: conn} do
        assert {:ok, %Minty.Response{status: 200}}
             = Minty.HTTP2.Conn.request(conn, "GET", "/httpbin/bytes/1", [], nil)
      end

      test "respond with large body", %{conn: conn} do
        assert {:ok, %Minty.Response{status: 200, body: body}}
             = Minty.HTTP2.Conn.request(conn, "GET", "/httpbin/bytes/#{1024 * 64}", [], nil)
        assert byte_size(body) == 1024 * 64
      end

      test "simultaneously", %{conn: conn} do
        refs =
          for i <- 1..10 do
            Task.async(fn ->
              Minty.HTTP2.Conn.request(conn, "GET", "/httpbin/bytes/#{1024 * 64}", [], nil)
            end)
          end

        Enum.each(refs, fn(ref) ->
          assert {:ok, %Minty.Response{status: 200}} = Task.await(ref)
        end)
      end

      test "ping", %{conn: conn} do
        assert {:ok, :pong} == Minty.HTTP2.Conn.ping(conn)
      end
    end
  end
end
