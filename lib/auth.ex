defmodule Tree.Auth do
  @moduledoc false

  use GenServer
  use Joken.Config
  import Map, only: [put: 3]
  import Tree.Config, only: [env: 1]
  import Joken, only: [current_time: 0]
  import Joken.Signer, only: [create: 2]

  import GenServer,
    only: [call: 2, start_link: 3]

  @month 30 * 24 * 60 * 60
  @struct [:id_st, :pass, :groups, :sessions]

  def start_link(_) do
    start_link(
      __MODULE__,
      nil,
      name: :auth
    )
  end

  @impl true
  def init(_) do
    :mnesia.create_table(
      :auth,
      [
        {:disc_copies, [node()]},
        {:type, :set},
        {:attributes, @struct}
      ]
    )

    state = %{
      signer: create("HS256", env("secret")),
      sessions: %{}
    }

    {:ok, state}
  end

  @impl true
  def token_config do
    host = env("host")

    %{}
    |> add_claim(
      "host",
      fn -> host end,
      &(&1 == host)
    )

    # |> add_claim(
    #   "exp",
    #   fn ->
    #     current_time() + 30 * 24 * 3600
    #   end,
    #   &(current_time() < &1)
    # )
  end

  @impl true
  def handle_call({:sign, ip, ua, uid}, _, state0) do
    sessions = state0.sessions
    sid = "{\"ip\":\"#{ip}\",\"ua\":\"#{ua || ""}\"}"
    user = put(sessions[uid] || %{}, sid, current_time())
    state = %{state0 | sessions: put(sessions, uid, user)}
    token = generate_and_sign!(%{sid: sid, id: uid}, state.signer)
    {:reply, {:ok, token}, state}
  end

  @impl true
  def handle_call(:state, _, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:claims, token}, _, state) do
    claims =
      case verify_and_validate(token, state.signer) do
        {:ok, claims} -> claims
        {:error, _} -> %{}
      end

    {:reply, claims, state}
  end

  def sid(req \\ @req) do
    {{a, b, c, d}, _} = req.peer
    ua = req.headers["user-agent"] || ""
    "{\"ip\":\"#{a}.#{b}.#{c}.#{d}\",\"ua\":\"#{ua}\"}"
  end

  def sign(ip, ua, uid), do: call(:auth, {:sign, ip, ua, uid})
  def claims(token), do: call(:auth, {:claims, token})
  def state, do: call(:auth, :state)
end
