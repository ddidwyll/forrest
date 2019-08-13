defmodule Tree.Config do
  @moduledoc false

  import Tree.Guards
  import Map, only: [merge: 2]
  import Enum, only: [filter: 2]
  import Logger, only: [error: 1]
  import List, only: [flatten: 1]
  import Regex, only: [compile: 1]
  import String, only: [to_atom: 1]
  import Mix.Config, only: [persist: 1]
  import Application, only: [get_env: 3]
  import Tree.Validator, only: [process: 2]

  import Jason,
    only: [decode!: 1, encode!: 2]

  import File,
    only: [read!: 1, write!: 2]

  @config %{
    "leafs" => %{
      "branches" => %{
        "title" => "map [branches]",
        "type" => "map",
        "required" => true
      },
      "settings" => %{
        "title" => "app [settings]",
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
        "title" => "app [port]",
        "type" => "integer",
        "min" => 80
      },
      "host" => %{
        "title" => "app [host]",
        "type" => "string"
      },
      "secret" => %{
        "title" => "JWT [secret]",
        "type" => "string"
      },
      "events_timeout" => %{
        "title" => "idle [events_timeout]",
        "type" => "integer",
        "min" => 0
      },
      "roles" => %{
        "title" => "user [roles]",
        "type" => "array",
        "struct" => %{
          "type" => "string"
        },
        "min" => 1
      },
      "client_entry" => %{
        "title" => "[client_entry] point",
        "type" => "string"
      },
      "client_assets" => %{
        "title" => "[client_assets] directory",
        "type" => "string"
      },
      "upload_dir" => %{
        "title" => "files [upload_dir]",
        "type" => "string"
      },
      "registration" => %{
        "title" => "user [registration]",
        "type" => "bool"
      },
      "default_role" => %{
        "title" => "user [default_role]",
        "type" => "string"
      }
    }
  }

  @default_config %{
    "branches" => %{},
    "settings" => %{
      "client_entry" => "./client/public/index.html",
      "client_assets" => "./client/public/",
      "upload_dir" => "./priv/upload/",
      "secret" => "!!!CHANGE_ME!!!",
      "events_timeout" => 300_000,
      "default_role" => "user",
      "registration" => true,
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

  defp apply_config(old \\ %{}, new),
    do: persist(%{forrest: merge(old, new)})

  def init do
    config = load()
    errors = errors(config)

    if is_empty_list(errors) do
      merge(config)
      |> apply_config()
    else
      error(inspect(errors))
      apply_config(@default_config)
    end
  end

  def set_config(config_json) do
    with config <- load(config_json),
         [] <- errors(config),
         full <- merge(config),
         :ok <- save(config) do
      apply_config(full)
    else
      e -> {:error, e}
    end
  end

  defp add(type, branch, leaf \\ nil, value) do
    current = get(type)

    if leaf do
      br = merge(current[branch] || %{}, %{leaf => value})
      %{type => merge(current, %{branch => br})}
    else
      %{type => merge(current, %{branch => value})}
    end
    |> apply_config()
  end

  defp load(config_json \\ nil) do
    try do
      (config_json || read!("config.json"))
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

  defp merge(config) do
    settings =
      merge(
        @default_config["settings"],
        config["settings"] || %{}
      )

    defaults = get("defaults")
    regexps = get("regexps")
    types = get("types")

    branches =
      for {key, branch} <- config["branches"], into: %{} do
        {key,
         branch
         |> merge(%{"default" => defaults[key]})
         |> merge(%{"regexp" => regexps[key]})
         |> merge(%{"type" => types[key]})}
      end

    %{
      "settings" => settings,
      "branches" => branches
    }
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
      case(process(branch, @branch)) do
        {:ok, _} ->
          add("types", name, branch["type"] |> to_atom)

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

  def get(key), do: get_env(:forrest, key, %{})
  def env(key), do: get("settings")[key]
  def regexp(branch, leaf), do: get("regexps")[branch][leaf]
  def default(branch), do: get("defaults")[branch]
  def schema(branch), do: get("branches")[branch]
  def type(branch), do: get("types")[branch]
end
