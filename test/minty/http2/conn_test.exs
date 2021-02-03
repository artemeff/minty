defmodule Minty.HTTP2Test do
  use ExUnit.Case

  alias Minty.HTTP2

  describe "#start_link" do
    test "returns error when try to use http endpoint" do
      assert {:error, :https_only} == HTTP2.start_link("http://localhost")
      assert {:error, :https_only} == HTTP2.start_link(address: {"http", "localhost", 80})
      assert {:error, :https_only} == HTTP2.start_link(address: {:http, "localhost", 80})
    end

    test "returns error when try to use https proxy" do
      assert {:error, :proxy_http_only} == HTTP2.start_link("https://localhost", proxy: "https://proxy:3000")
      assert {:error, :proxy_http_only}
          == HTTP2.start_link(address: {"https", "localhost", 443},
                             proxy: {:https, "proxy", 3000, []})
    end
  end
end
