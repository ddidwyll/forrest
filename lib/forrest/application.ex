defmodule Forrest.Application do
  @moduledoc false

  use Application
  alias :mnesia, as: Mnesia

  def start(_, _) do
    children = [
      Config,
      Events
    ]

    opts = [
      strategy: :one_for_one,
      name: Forrest.Supervisor
    ]

    # Forrest.Auth.init()
    Mnesia.create_schema([node()])
    Mnesia.start()
    {:ok, pid} = Supervisor.start_link(children, opts)
    Tree.init()
    Router.start()
    {:ok, pid}
  end
end
