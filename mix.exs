defmodule Kaguya.Mixfile do
  use Mix.Project

  def project do
    [app: :kaguya,
     version: "0.3.2",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description,
     package: package,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger],
    mod: {Kaguya, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  def deps do
    [{:earmark, "~> 0.1", only: :dev},
      {:ex_doc, "~> 0.11", only: :dev}]
  end

  defp description do
    """
    A small, powerful, and modular IRC bot framework. Using a flexible macro based
    routing system, modules can be easily created and used.
    """
  end

  defp package do
    [# These are the default files included in the package
     files: ["lib", "priv", "mix.exs", "README*", "readme*", "LICENSE*", "license*"],
     maintainers: ["Luminarys"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/Luminarys/Kaguya"}]
  end
end
