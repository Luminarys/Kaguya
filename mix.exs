defmodule Kaguya.Mixfile do
  use Mix.Project

  def project do
    [
      app: :kaguya,
      version: "0.4.2",
      elixir: "~> 1.1",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      description: description,
      package: package,
      deps: deps,
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
      {:earmark, "~> 0.1", only: :dev},
      {:ex_doc, "~> 0.11", only: :dev},
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
