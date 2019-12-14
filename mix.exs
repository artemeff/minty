defmodule Minty.MixProject do
  use Mix.Project

  def project do
    [
      app: :minty,
      version: "0.1.0",
      elixir: "~> 1.9",
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
      {:mint, "~> 1.0.0"},
      {:castore, "~> 0.1.4", optional: true}
    ]
  end
end
