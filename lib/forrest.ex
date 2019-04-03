defmodule Forrest do
  @moduledoc false

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
