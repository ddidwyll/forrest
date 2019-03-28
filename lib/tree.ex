defmodule Tree do
  @moduledoc false

  @branch [:id, :uid, :gid, :status, :upd, :json]

  def init() do
    :mnesia.create_table(
      :tree,
      [
        {:disc_copies, [node()]},
        {:type, :set},
        {:attributes, @branch}
      ]
    )
  end
end

defmodule Tree.Route do
  @moduledoc false

  alias Tree.Rest
  import :cowboy_req, only: [reply: 4]

  @methods [
    "OPTIONS",
    "POST",
    "PATCH",
    "GET",
    "DELETE"
  ]

  @to_json {
    {"application", "json", :*},
    :to_json
  }
  
  @from_json {
    {"application", "json", :*},
    :from_json
  }

  @utf8 "utf-8"

  @headers %{
    "server" => "Forrest"
  }

  def init(req, _) do
    case req.method do
      "POST" -> Rest.post(req)
      "PATCH" -> Rest.patch(req)
      "GET" -> Rest.get(req)
      "OPTIONS" -> options(req)
    end
  end

  def content_types_provided(req, state) do
    {[@to_json], req, state}
  end

  def content_types_accepted(req, state) do
    {[@from_json], req, state}
  end

  def allowed_methods(req, state) do
    {@methods, req, state}
  end

  def charsets_provided(req, state) do
    {[@utf8], req, state}
  end

  def to_json(req, body)
      when is_list(body) do
    json = "[" <> Enum.join(body, ",") <> "]"
    {json, req, body}
  end
  
  def from_json(req0, body) do
    req = :cowboy_req.set_resp_body(body, req0)
    {true, req, body}
  end

  def options(req0) do
    branch = req0.bindings.branch

    headers = %{
      "server" => "Forrest",
      "ddidwyll" => "gmail.com"
    }

    schema =
      Forrest.schema(branch)
      |> Jason.encode!()

    req = reply(200, headers, schema, req0)
    {:ok, req, []}
  end
end

defmodule Tree.Rest do
  @moduledoc false

  def post(req) do
    message = ["P", "O", "S", "T"]
    {:cowboy_rest, req, message}
  end

  def patch(req) do
    message = "PATCH"
    {:cowboy_rest, req, message}
  end

  def get(req) do
    body = [1, 2, 3, 4]
    {:cowboy_rest, req, body}
  end
end

defmodule Tree.Store do
  @moduledoc false

  alias :mnesia, as: Mnesia
  import Enum, only: [each: 2]

  @db :events
  @ids [:"$1"]
  @all [:"$$"]
  @db_struct {@db, :"$1", :"$2", :"$3", :"$4"}

  defp now do
    :os.system_time(:millisecond)
  end

  def put(action, branch, id) do
    time = now() |> to_string

    fun = fn ->
      {@db, time, action, branch, id}
      |> Mnesia.write()
    end

    case Mnesia.transaction(fun) do
      {:atomic, :ok} -> {:ok, time}
      _ -> :error
    end
  end

  defp select(matcher, fields \\ @all) do
    {:atomic, result} =
      fn ->
        Mnesia.select(
          @db,
          [{@db_struct, matcher, fields}]
        )
      end
      |> Mnesia.transaction()

    result
  end

  def get(from \\ "") do
    [{:>, :"$1", from}]
    |> select()
  end

  def garbage() do
    day_ago =
      (now() - 24 * 60 * 60 * 1000)
      |> to_string()

    fn ->
      Mnesia.select(
        @db,
        [{@db_struct, [{:<, :"$1", day_ago}], @ids}]
      )
      |> each(&Mnesia.delete({@db, &1}))
    end
    |> Mnesia.transaction()
  end
end
