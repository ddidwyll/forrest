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
      mod: {Forrest.Application, []}
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.0"},
      # {:amnesia, "~> 0.2.7"},
      # {:exquisite, github: "meh/exquisite", branch: "master", override: true},
      {:ex_json_schema, "~> 0.5.8"},
      {:jason, "~> 1.1"},
      # {:sse, "~> 0.4.0"},
      # {:event_bus, "~> 1.6"},
      {:uuid, "~> 1.1"},
      # {:lasse, "~> 1.2"},
      # {:access_pass, "~> 1.0"}
      # {:ueberauth, "~> 0.6"},
      # {:wire, "~> 0.2.0"},
      # {:plug_heartbeat, "~> 0.1"},
      # {:plug_response_header, "~> 0.2.1"},
      # {:mogrify, "~> 0.7.2"},
      # {:json, "~> 1.2"},
      # {:rest, "~> 1.5"},
      # {:joken, "~> 2.0"},
      # {:ecto, "~> 3.0"},
      # {:ecto_mnesia, "~> 0.9.1"},
      # {:core, "~> 0.14.1"},
      # {:immortal, "~> 0.2.2"},
      # {:vex, "~> 0.8.0"},
      # {:guardian, "~> 1.2"},
      # {:benchee, "~> 0.9", only: [:dev]},
      {:dialyxir, "~> 0.4", only: [:dev]}
      # {:ex_doc, "~> 0.19.3", only: [:dev]}
    ]
  end
end
