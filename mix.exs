defmodule Kaguya.Mixfile do
  use Mix.Project

  def project do
    [
      app: :kaguya,
      version: "0.6.6",
      elixir: "~> 1.1",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      description: description(),
      package: package(),
      deps: deps(),

      #ex_doc variables
      name: "Kaguya",
      docs: [main: "Kaguya",
             extras: ["README.md"]]
    ]
  end

  def application do
    [
      applications: [:logger],
      mod: {Kaguya, []}
    ]
  end

  def deps do
    [
      {:earmark, "~> 1.2.2", only: :dev},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
    ]
  end

  defp description do
    """
    A small, powerful, and modular IRC bot framework. Using a flexible macro based
    routing system, modules can be easily created and used.
    """
  end

  defp package do
    [
     files: ["lib", "mix.exs", "README*", "LICENSE*"],
     maintainers: ["Luminarys"],
     licenses: ["ISC"],
     links: %{"GitHub" => "https://github.com/Luminarys/Kaguya"},
   ]
  end
end
