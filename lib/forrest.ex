defmodule Forrest do
  @moduledoc false

  import File, only: [read!: 1]
  import Enum, only: [filter: 2]
  import List, only: [flatten: 1]
  import Logger, only: [error: 1]
  import Jason, only: [decode!: 2]
  # import Validator, only: [process: 2]

  @ets [
    :set,
    :protected,
    :named_table
  ]

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

  def init do
    :ets.new(:branches, @ets)
  end

  def get(config_json \\ nil) do
    try do
      (config_json ||
         read!("config.json"))
      |> decode!(strings: :copy)
    rescue
      e -> error("Invalid config, " <> inspect(e))
    end
  end

  def errors({leafs, branch}) do
    for {name, leaf} <- leafs do
      case Validator.process(leaf, @leaf) do
        {:error, errors} -> %{(branch <> "/" <> name) => errors}
        {:ok, _} -> nil
      end
    end
  end

  def errors({branches}) do
    for {name, branch} <- branches do
      case Validator.process(branch, @branch) do
        {:ok, _} -> errors({branch["leafs"], name})
        {:error, errors} -> %{name => errors}
      end
    end
  end

  def errors(config) do
    case Validator.process(config, @config) do
      {:ok, _} -> errors({config["branches"]})
      {:error, errors} -> [%{"config" => errors}]
    end
    |> flatten()
    |> filter(& &1)
  end

  @deal %{
    "title" => "deal",
    "titles" => "deals",
    "leafs" => %{
      "created" => %{
        "title" => "created",
        "type" => "integer",
        "required" => true,
        "freeze" => true
      },
      "company" => %{
        "title" => "company",
        "type" => "string",
        "required" => true,
        "max" => 80,
        "arr" => ["foo", "bar"]
      },
      "value" => %{
        "title" => "value",
        "type" => "integer",
        "min" => 0
      }
    },
    "rules" => %{
      "get_own" => "user",
      "get_grp" => "user",
      "get_all" => "user",
      "post_own" => "user",
      "post_grp" => "user",
      "patch_own" => "user",
      "patch_grp" => "manager",
      "patch_all" => "admin",
      "delete_own" => "manager",
      "delete_grp" => "manager",
      "delete_all" => "admin"
    }
  }

  @branches %{
    "deal" => @deal
  }

  def schema(branch) do
    @branches[branch]
  end
end
