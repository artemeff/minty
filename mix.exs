defmodule Minty.MixProject do
  use Mix.Project

  def project do
    [
      app: :minty,
      version: "0.1.2",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mint, "1.2.0"},
      {:castore, "~> 0.1.9", optional: true}
    ]
  end
end
