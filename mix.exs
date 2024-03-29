defmodule Forrest.MixProject do
  use Mix.Project

  def project do
    [
      app: :forrest,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :cowboy],
      mod: {Forrest.Application, nil},
      included_applications: [:mnesia]
    ]
  end

  defp deps do
    [
      {:pbkdf2_elixir, "~> 0.12"},
      {:cowboy, "~> 2.6.1"},
      {:jason, "~> 1.1"},
      {:joken, "~> 2.0"},
      {:uuid, "~> 1.1"}
    ]
  end
end
