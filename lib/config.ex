defmodule Config do
  @moduledoc false

  use GenServer

  import Map, only: [merge: 2]
  import Enum, only: [filter: 2]
  import List, only: [flatten: 1]
  import Regex, only: [compile: 1]
  import Logger, only: [error: 1]

  import File,
    only: [read!: 1, write!: 2]

  import Jason,
    only: [decode!: 1, encode!: 2]

  import GenServer,
    only: [call: 2, cast: 2, start_link: 3]

  @config %{
    "leafs" => %{
      "branches" => %{
        "title" => "branches",
        "type" => "map",
        "required" => true
      }
    }
  }

  @branch %{
    "leafs" => %{
      "title" => %{
        "title" => "branch title",
        "type" => "string",
        "required" => true
      },
      "titles" => %{
        "title" => "branch titles",
        "type" => "string",
        "required" => true
      },
      "leafs" => %{
        "title" => "branch leafs",
        "type" => "map",
        "required" => true
      },
      "rules" => %{
        "title" => "branch rules",
        "type" => "map",
        "required" => true
      }
    }
  }

  @leaf %{
    "leafs" => %{
      "title" => %{
        "title" => "value title",
        "type" => "string",
        "required" => true
      },
      "type" => %{
        "title" => "value type",
        "type" => "string",
        "required" => true,
        "arr" => [
          "integer",
          "number",
          "string",
          "array",
          "bool",
          "map"
        ]
      },
      "min" => %{
        "title" => "value min",
        "type" => "integer"
      },
      "max" => %{
        "title" => "value max",
        "type" => "integer"
      },
      "arr" => %{
        "title" => "value array",
        "type" => "array"
      },
      "re" => %{
        "title" => "value regex",
        "type" => "string"
      }
    }
  }

  @default_config %{
    "branches" => %{},
    "settings" => %{
      "host" => "localhost",
      "port" => 8080,
      "events_timeout" => 5 * 60_000
    }
  }

  def start_link(_) do
    start_link(
      __MODULE__,
      nil,
      name: :config
    )
  end

  def init(_) do
    config = load()
    errors = errors(config)

    if length(errors) == 0 do
      {:ok, merge(@default_config, config)}
    else
      error(inspect(errors))
      {:ok, @default_config}
    end
  end

  def handle_call(:get, _, config) do
    {:reply, config, config}
  end

  def handle_call({:set, config_json}, _, old_config) do
    with config <- load(config_json),
         [] <- errors(config),
         full <- merge(@default_config, config),
         :ok <- save(config) do
      {:reply, :ok, full}
    else
      e -> {:reply, {:error, e}, old_config}
    end
  end

  def handle_cast({:add, type, branch, leaf, value}, config) do
    branches = config["branches"]

    if branches[branch]["leafs"][leaf] do
      l3 = merge(branches[branch][type] || %{}, %{leaf => value})
      l2 = merge(branches[branch], %{type => l3})
      l1 = merge(branches, %{branch => l2})
      {:noreply, merge(config, %{"branches" => l1})}
    else
      {:noreply, config}
    end
  end

  defp load(config_json \\ nil) do
    try do
      (config_json ||
         read!("config.json"))
      |> decode!()
    rescue
      e -> error("Invalid config, " <> inspect(e))
    end
  end

  defp save(config) do
    try do
      json = encode!(config, pretty: true)
      write!("config.json", json)
      :ok
    rescue
      e ->
        error = "Config not saved, " <> inspect(e)
        error(error)
        {:error, error}
    end
  end

  defp errors({leafs, branch}) do
    for {name, leaf} <- leafs do
      case Validator.process(leaf, @leaf) do
        {:ok, _} ->
          with regexp <- leaf["re"],
               false <- is_nil(regexp),
               {:ok, re} <- compile(regexp) do
            add("regexps", branch, name, re)
          end

          if default = leaf["default"] do
            add("defaults", branch, name, default)
          end

          nil

        {:error, errors} ->
          %{(branch <> "/" <> name) => errors}
      end
    end
  end

  defp errors({branches}) do
    for {name, branch} <- branches do
      case Validator.process(branch, @branch) do
        {:ok, _} -> errors({branch["leafs"], name})
        {:error, errors} -> %{name => errors}
      end
    end
  end

  defp errors(config) do
    case Validator.process(config, @config) do
      {:error, errors} -> [%{"config" => errors}]
      {:ok, _} -> errors({config["branches"]})
    end
    |> flatten()
    |> filter(& &1)
  end

  def get_config, do: call(:config, :get)
  def env(key), do: get_config()["settings"][key]
  def set_config(json), do: call(:config, {:set, json})
  def rules(branch), do: get_config()["branches"][branch]
  def schema(branch), do: get_config()["branches"][branch]

  defp add(type, branch, leaf, value),
    do: cast(:config, {:add, type, branch, leaf, value})
end
