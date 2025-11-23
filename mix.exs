defmodule ExSift.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_sift,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "MongoDB-style query filtering for Elixir collections",
      package: package()
    ]
  end

  defp package do
    [
      name: "ex_sift",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/sahilpohare/ex_sift"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
