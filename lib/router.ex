defmodule Tree.Router do
  @moduledoc false

  import Tree.Config, only: [env: 1]
  import :cowboy, only: [start_clear: 3]
  import :cowboy_router, only: [compile: 1]

  def init do
    start_clear(
      :http,
      [{:port, env("port")}],
      %{
        env: %{dispatch: routes()},
        idle_timeout: env("events_timeout")
      }
    )
  end

  def routes do
    routes = [
      {"/assets/[...]", :cowboy_static, {:dir, env("client_assets")}},
      {"/upload/[...]", :cowboy_static, {:dir, env("upload_dir")}},
      {"/", :cowboy_static, {:file, env("client_entry")}},
      {"/events/:user/[:last_id]", Tree.Events.Route, nil},
      {"/:type/:branch/[:from]/[:to]", Tree.Route, nil}
    ]

    compile([{env("host"), routes}])
  end
end
