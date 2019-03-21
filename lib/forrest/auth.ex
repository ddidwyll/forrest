defmodule Forrest.Auth do
  @moduledoc false

  def init do
    :dets.open_file(
      :user_store,
      type: :set
    )
  end

  def schema do
    %{
      "name" => "user",
      "type" => "object",
      "title" => "User",
      "properties" => %{
        "id" => %{
          "type" => "string",
          "title" => "Login",
          "not_null" => true
        },
        "gid" => %{
          "type" => "string",
          "title" => "Group"
        },
        "name" => %{
          "type" => "string",
          "title" => "Name"
        },
        "role" => %{
          "type" => "string",
          "title" => "Role"
        }
      }
    }
  end
end

defmodule Forrest.Auth.Plug do
  @moduledoc false

  use Plug.Router
  alias Forrest.Auth.Store
  alias Forrest.Auth.Valid

  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  )

  plug(:dispatch)

  get "/:id" do
    case Store.get(id) do
      {:ok, json} -> send_resp(conn, 200, json)
      {:error, json} -> send_resp(conn, 404, json)
    end
  end

  put "/:id" do
    with user <- conn.body_params,
         true <- Store.exists?(id),
         true <- Valid.valid?(user),
         :ok <- Store.put(user) do
      send_resp(conn, 200, "\"Done\"")
    else
      _ -> send_resp(conn, 400, "\"Wrong data\"")
    end
  end

  # post "/:id" do

  match _ do
    send_resp(conn, 404, "\"Not Found\"")
  end
end

defmodule Forrest.Auth.Store do
  @moduledoc false

  @db :user_store
  alias :dets, as: Dets

  def now() do
    :os.system_time(:millisecond)
  end

  def to_json({status, value}) do
    case Jason.encode(value) do
      {:ok, json} -> {status, json}
      _ -> {:error, "\"Something went wrong\""}
    end
  end

  def to_json(value), do: to_json({:ok, value})

  def from_json!({:ok, json}), do: Jason.decode!(json)
  def from_json!({:error, _}), do: nil

  def exists?(id) do
    {status, _} = get(id)
    status === :ok
  end

  def get_all() do
  end

  def get(id) do
    case @db |> Dets.lookup(id) do
      [{_, :active, json} | _] -> {:ok, json}
      _ -> {:error, "\"User not exists or blocked\""}
    end
  end

  def put(user) do
    case to_json(user) do
      {:ok, json} -> @db |> Dets.insert({user["id"], :active, json})
      _ -> :error
    end
  end
end

defmodule Forrest.Auth.Valid do
  @moduledoc false

  import Forrest.Auth, only: [schema: 0]

  defp empty?(val) when is_map(val) or is_list(val), do: Enum.count(val) == 0
  defp empty?(val) when is_binary(val), do: val == ""
  defp empty?(val) when is_nil(val), do: true
  defp empty?(_), do: false

  def valid?(user) do
    is_map(user) && ExJsonSchema.Validator.valid?(schema(), user) &&
      for {key, spec} <- schema()["properties"] do
        with {:ok, value} <- Map.fetch(user, key),
             true <- !spec["not_null"] || !empty?(value) do
          true
        else
          _ -> false
        end
      end
      |> Enum.all?()
  end
end
