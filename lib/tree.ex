defmodule Tree do
  @moduledoc false

  use GenServer
  alias Tree.Store

  import GenServer,
    only: [cast: 2, call: 2, start_link: 3]

  @branch [:id, :uid, :gid, :status, :upd, :json]

  def init(state) do
    :mnesia.create_table(
      :tree,
      [
        {:disc_copies, [node()]},
        {:type, :set},
        {:attributes, @branch}
      ]
    )

    {:ok, state}
  end

  def start_link() do
    start_link(
      __MODULE__,
      [],
      name: :tree
    )
  end
end

defmodule Tree.Route do
  @moduledoc false

  import :cowboy_req,
    only: [stream_reply: 3, stream_events: 3]

  @headers %{
    "content-type" => "text/event-stream",
    "cache-control" => "no-cache",
    "connection" => "keep-alive"
  }

  def init(req0, state) do
    {:cowboy_loop, req, state, :hibernate}
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
