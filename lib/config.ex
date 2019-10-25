defmodule Tree.Config do
  @moduledoc false

  import Tree.Guards
  import Map, only: [merge: 2]
  import Enum, only: [filter: 2]
  import Logger, only: [error: 1]
  import List, only: [flatten: 1]
  import Regex, only: [compile: 1]
  import Tree.Validator, only: [process: 2]
  import String, only: [to_atom: 1, split: 2]
  import Application, only: [get_env: 3, put_env: 4]
  import Tree.Utils, only: [deep_merge: 2, deep_set: 3]

  import Jason,
    only: [decode!: 1, encode!: 2]

  import File,
    only: [read!: 1, write!: 2]

  @sep "/#/"

  @config %{
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

  @branch %{
    "api_title" => %{
      "title" => "branch [api_title]",
      "type" => "string",
      "required" => true
    },
    "api_type" => %{
      "title" => "branch [api_type]",
      "type" => "string",
      "arr" => [
        "tree",
        "bag"
      ]
    }
  }

  @leaf %{
    "title" => %{
      "title" => "value [title]",
      "type" => "string"
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
      "type" => "map"
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

  @settings %{
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

  defp apply_config(old \\ %{}, new) do
    for {k, v} <- deep_merge(old, new) do
      put_env(:forrest, k, v, persistent: true)
    end
  end

  def init do
    config = load()
    errors = errors(config)

    if is_empty_list(errors) do
      deep_merge(@default_config, config)
      |> save()
      |> merge()
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
         _ <- save(config) do
      apply_config(full)
    else
      e -> {:error, e}
    end
  end

  defp add_outside(type, branch, leaf0, value) do
    leaf = String.replace(leaf0, @sep <> "struct", "")
    add(type, branch, leaf, value)
  end

  defp add_inside(type, branch, leaf, value0) do
    value = %{type => value0}
    add(type, branch, leaf, value)
  end

  defp add(type, branch, leaf \\ nil, value) do
    current = get(type)

    if leaf do
      br = deep_set(split(leaf, @sep), value, current[branch])
      %{type => deep_merge(current, %{branch => br})}
    else
      %{type => deep_merge(current, %{branch => value})}
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
      config
    rescue
      e ->
        error = "Config not saved, " <> inspect(e)
        error(error)
        {:error, error}
    end
  end

  defp merge(config) do
    branches =
      for {key, branch} <- config["branches"], into: %{} do
        {key,
         branch
         |> deep_merge(get("regexp")[key])
         |> deep_merge(%{"defaults" => get("default")[key]})
         |> deep_merge(%{"type" => get("types")[key]})}
      end

    %{
      "settings" => config["settings"],
      "branches" => branches
    }
  end

  defp compile(branch, leaf, name) do
    with regexp <- leaf["re"],
         false <- is_nil(regexp),
         {:ok, re} <- compile(regexp) do
      add_inside("regexp", branch, name, re)
    end

    unless leaf["default"] |> is_nil do
      add_outside("default", branch, name, leaf["default"])
    end

    if leaf["type"] == "map" && is_map(leaf["struct"]) do
      for {subname, subleaf} <- leaf["struct"], is_map(subleaf) do
        compile(branch, subleaf, "#{subname}#{@sep}struct#{@sep}#{name}")
      end
    end
  end

  defp errors({:leafs, leafs, branch}) do
    for {name, leaf} <- leafs, is_map(leaf) do
      case process(leaf, @leaf) do
        {:ok, _} ->
          compile(branch, leaf, name)
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
          add("types", name, (branch["api_type"] || "tree") |> to_atom)
          errors({:leafs, branch, name})

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
  def regexp(branch, leaf), do: get("regexp")[branch][leaf]
  def default(branch), do: get("default")[branch]
  def type(branch), do: get("types")[branch]
  def schema(branch), do: get("branches")[branch]
end
