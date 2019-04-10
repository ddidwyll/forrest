defmodule Tree.Config do
  @moduledoc false

  use GenServer

  import Map, only: [merge: 2]
  import Enum, only: [filter: 2]
  import Logger, only: [error: 1]
  import List, only: [flatten: 1]
  import Regex, only: [compile: 1]
  import String, only: [to_atom: 1]
  import Tree.Validator, only: [process: 2]

  import File,
    only: [read!: 1, write!: 2]

  import Jason,
    only: [decode!: 1, encode!: 2]

  import GenServer,
    only: [call: 2, cast: 2, start_link: 3]

  @config %{
    "leafs" => %{
      "branches" => %{
        "title" => "map [branches]",
        "type" => "map",
        "required" => true
      },
      "settings" => %{
        "title" => "env [settings]",
        "type" => "map"
      }
    }
  }

  @branch %{
    "leafs" => %{
      "title" => %{
        "title" => "branch [title]",
        "type" => "string",
        "required" => true
      },
      "titles" => %{
        "title" => "branch [titles]",
        "type" => "string",
        "required" => true
      },
      "leafs" => %{
        "title" => "branch [leafs]",
        "type" => "map",
        "required" => true
      },
      "rules" => %{
        "title" => "branch [rules]",
        "type" => "map",
        "required" => true
      },
      "type" => %{
        "title" => "branch [type]",
        "type" => "string",
        "required" => true,
        "arr" => [
          "tree",
          "bag",
          "rel"
        ]
      }
    }
  }

  @rules %{
    "leafs" => %{
      "get_all" => %{
        "title" => "Get all rule [get_all]",
        "type" => "array",
        "struct" => %{
          "type" => "string"
        },
        "required" => true
      },
      "get_grp" => %{
        "title" => "Get group rule [get_grp]",
        "type" => "array",
        "struct" => %{
          "type" => "string"
        },
        "required" => true
      },
      "get_own" => %{
        "title" => "Get own rule [get_own]",
        "type" => "array",
        "struct" => %{
          "type" => "string"
        },
        "required" => true
      },
      "post_own" => %{
        "title" => "Post own rule [post_own]",
        "type" => "array",
        "struct" => %{
          "type" => "string"
        },
        "required" => true
      },
      "post_grp" => %{
        "title" => "Post group rule [post_grp]",
        "type" => "array",
        "struct" => %{
          "type" => "string"
        },
        "required" => true
      },
      "patch_all" => %{
        "title" => "Patch all rule [patch_all]",
        "type" => "array",
        "struct" => %{
          "type" => "string"
        },
        "required" => true
      },
      "patch_grp" => %{
        "title" => "Patch group rule [patch_grp]",
        "type" => "array",
        "struct" => %{
          "type" => "string"
        },
        "required" => true
      },
      "patch_own" => %{
        "title" => "Patch own rule [patch_own]",
        "type" => "array",
        "struct" => %{
          "type" => "string"
        },
        "required" => true
      },
      "delete_all" => %{
        "title" => "Delete all rule [delete_all]",
        "type" => "array",
        "struct" => %{
          "type" => "string"
        },
        "required" => true
      },
      "delete_grp" => %{
        "title" => "Delete group rule [delete_grp]",
        "type" => "array",
        "struct" => %{
          "type" => "string"
        },
        "required" => true
      },
      "delete_own" => %{
        "title" => "Delete own rule [delete_own]",
        "type" => "array",
        "struct" => %{
          "type" => "string"
        },
        "required" => true
      }
    }
  }

  @leaf %{
    "leafs" => %{
      "title" => %{
        "title" => "value [title]",
        "type" => "string",
        "required" => true
      },
      "type" => %{
        "title" => "value [type]",
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
      "struct" => %{
        "title" => "value [struct]",
        "type" => "map",
        "struct" => %{
          "keys" => [
            "type",
            "min",
            "max",
            "keys"
          ]
        }
      },
      "required" => %{
        "title" => "is value [required]",
        "type" => "bool"
      },
      "default" => %{
        "title" => "[default] value",
        "type" => "any"
      },
      "min" => %{
        "title" => "value [min]",
        "type" => "integer"
      },
      "max" => %{
        "title" => "value [max]",
        "type" => "integer"
      },
      "arr" => %{
        "title" => "value [arr]ay",
        "type" => "array"
      },
      "re" => %{
        "title" => "value [re]gex",
        "type" => "string"
      }
    }
  }

  @settings %{
    "leafs" => %{
      "port" => %{
        "title" => "env [port]",
        "type" => "integer",
        "required" => true,
        "min" => 80
      },
      "host" => %{
        "title" => "env [host]",
        "type" => "string",
        "required" => true
      },
      "events_timeout" => %{
        "title" => "idle [events_timeout]",
        "type" => "integer",
        "required" => true,
        "min" => 0
      },
      "roles" => %{
        "title" => "user [roles]",
        "type" => "array",
        "struct" => %{
          "type" => "string"
        },
        "required" => true,
        "min" => 1
      },
      "client_entry" => %{
        "title" => "[client_entry] point",
        "type" => "string",
        "required" => true
      },
      "client_assets" => %{
        "title" => "[client_assets] directory",
        "type" => "string",
        "required" => true
      },
      "upload_dir" => %{
        "title" => "files [upload_dir]",
        "type" => "string",
        "required" => true
      }
    }
  }

  @default_config %{
    "branches" => %{},
    "settings" => %{
      "client_entry" => "./client/public/index.html",
      "client_assets" => "./client/public/",
      "upload_dir" => "./priv/upload/",
      "events_timeout" => 300_000,
      "host" => "localhost",
      "port" => 8080,
      "roles" => [
        "anon",
        "user",
        "manager",
        "admin"
      ]
    }
  }

  def start_link(_) do
    start_link(
      __MODULE__,
      nil,
      name: :config
    )
  end

  @impl true
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

  @impl true
  def handle_call(:get, _, config) do
    {:reply, config, config}
  end

  @impl true
  def handle_call({:set, config_json}, _, old_config) do
    with config <- load(config_json),
         [] <- errors(config),
         full <- merge(@default_config, config),
         :ok <- save(full) do
      {:reply, :ok, full}
    else
      e -> {:reply, {:error, e}, old_config}
    end
  end

  @impl true
  def handle_cast({:add, type, branch, leaf, value}, config) do
    branches = config["branches"]

    cond do
      leaf && branches[branch]["leafs"][leaf] ->
        l3 = merge(branches[branch][type] || %{}, %{leaf => value})
        l2 = merge(branches[branch], %{type => l3})
        l1 = merge(branches, %{branch => l2})
        {:noreply, merge(config, %{"branches" => l1})}

      is_nil(leaf) && branches[branch] ->
        l2 = merge(branches[branch], %{type => value})
        l1 = merge(branches, %{branch => l2})
        {:noreply, merge(config, %{"branches" => l1})}

      true ->
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

  defp errors({:leafs, leafs, branch}) do
    for {name, leaf} <- leafs do
      case process(leaf, @leaf) do
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
          %{(branch <> "." <> name) => errors}
      end
    end
  end

  defp errors({:other, model, name, schema}) do
    case process(model, schema) do
      {:ok, _} -> [nil]
      {:error, errors} -> [%{name => errors}]
    end
  end

  defp errors({:branches, branches}) do
    for {name, branch} <- branches do
      case process(branch, @branch) do
        {:ok, _} ->
          add("type", name, branch["type"] |> to_atom)

          errors({:leafs, branch["leafs"], name}) ++
            errors({:other, branch["rules"], name, @rules})

        {:error, errors} ->
          %{name => errors}
      end
    end
  end

  defp errors(config) do
    case process(config, @config) do
      {:error, errors} ->
        [%{"config" => errors}]

      {:ok, _} ->
        errors({:branches, config["branches"]}) ++
          if config["settings"] do
            errors({
              :other,
              config["settings"],
              "settings",
              @settings
            })
          else
            [nil]
          end
    end
    |> flatten()
    |> filter(& &1)
  end

  defp add(type, branch, leaf \\ nil, value),
    do: cast(:config, {:add, type, branch, leaf, value})

  def get_config, do: call(:config, :get)
  def env(key), do: get_config()["settings"][key]
  def set_config(json), do: call(:config, {:set, json})
  def rules(branch), do: get_config()["branches"][branch]
  def schema(branch), do: get_config()["branches"][branch]
end
