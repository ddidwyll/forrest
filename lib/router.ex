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
    [
      {env("host"),
       [
         {"/", :cowboy_static, {:file, env("client_entry")}}
       ]},
      {"assets." <> env("host"),
       [
         {"/[...]", :cowboy_static, {:dir, env("client_assets")}}
       ]},
      {"upload." <> env("host"),
       [
         {"/[...]", :cowboy_static, {:dir, env("upload_dir")}}
       ]},
      {"events." <> env("host"),
       [
         {"/batch/[:last_id]", Tree.Events.Route, nil},
         {"/stream/:user/[:last_id]", Tree.Events.Stream, nil}
       ]},
      {"tree." <> env("host"),
       [
         {"/batch/:branch/[:to]/[:from]", Tree.Route, nil},
         # {"/archive/:branch/[:to]/[:from]", Tree.Route, nil},
         {"/rest/:branch/[:to]/[:from]", Tree.Rest, nil}
       ]}
    ]
    |> compile()
  end
end
