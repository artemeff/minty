defmodule Minty.HTTP2.ConnTest do
  use ExUnit.Case

  alias Minty.HTTP2.Conn

  describe "#start_link" do
    test "returns error when try to use http endpoint" do
      assert {:error, :https_only} == Conn.start_link("http://localhost")
      assert {:error, :https_only} == Conn.start_link(scheme: "http", host: "localhost", port: 80)
      assert {:error, :https_only} == Conn.start_link(scheme: :http, host: "localhost", port: 80)
    end

    test "returns error when try to use https proxy" do
      assert {:error, :proxy_http_only} == Conn.start_link("https://localhost", proxy: "https://proxy:3000")
      assert {:error, :proxy_http_only}
          == Conn.start_link(scheme: "https", host: "localhost", port: 443,
                             proxy: {:https, "proxy", 3000, []})
    end
  end
end
