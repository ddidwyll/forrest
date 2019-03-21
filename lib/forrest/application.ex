defmodule Forrest.Application do
  @moduledoc false

  use Application
  import Supervisor.Spec, only: [worker: 2]
  alias :mnesia, as: Mnesia

  def start(_type, _args) do
    children = [
      worker(Events, [])
    ]

    opts = [
      strategy: :one_for_one,
      name: Forrest.Supervisor
    ]

    # Forrest.Auth.init()
    Mnesia.create_schema(node())
    Mnesia.start()
    Router.start()
    Supervisor.start_link(children, opts)
  end
end
