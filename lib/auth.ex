defmodule Tree.Auth do
  @moduledoc false

  use GenServer
  use Joken.Config

  import Tree.Guards
  import Map, only: [put: 3]
  import Jason, only: [encode!: 1]
  import Tree.Config, only: [env: 1]
  import Joken, only: [current_time: 0]
  import Joken.Signer, only: [create: 2]
  import Tree.Validator, only: [process: 2]

  import Pbkdf2,
    only: [hash_pwd_salt: 1, verify_pass: 2]

  import GenServer,
    only: [call: 2, start_link: 3]

  import :mnesia,
    only: [
      create_table: 2,
      match_object: 1,
      transaction: 1,
      write: 1,
      read: 2
    ]

  @month 30 * 24 * 60 * 60

  @struct [
    :id_st,
    :pass,
    :mail,
    :groups,
    :sessions,
    :json
  ]

  @schema %{
    "leafs" => %{
      "id" => %{
        "title" => "login",
        "type" => "string",
        "required" => true,
        "min" => 3
      },
      "pass" => %{
        "title" => "password",
        "type" => "string",
        "required" => true,
        "min" => 3
      },
      "mail" => %{
        "type" => "string",
        "title" => "e-mail"
      }
    }
  }

  def start_link(_) do
    __MODULE__
    |> start_link(nil, name: :auth)
  end

  @impl true
  def init(_) do
    create_table(
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

  def get(id, status \\ :active) do
    fn -> read(:auth, {id, status}) end
    |> transaction()
    |> first()
  end

  def status(id) do
    fn ->
      match_object({:auth, {id, :_}, :_, :_, :_, :_, :_})
    end
    |> transaction()
    |> first()
  end

  defp first({:atomic, list}) when is_empty_list(list), do: nil
  defp first({:atomic, list}), do: hd(list)

  def validate(id, pass, mail, is_new \\ true) do
    cond do
      is_new && status(id) ->
        {:error, "Login already taken"}

      !env("registration") ->
        {:error, "Registration not allowed"}

      true ->
        %{"id" => id, "pass" => pass, "mail" => mail}
        |> process(@schema)
    end
  end

  def signup(id, pass, mail \\ "", role \\ nil, status \\ :active) do
    hash = hash_pwd_salt(pass)
    groups = %{"system" => role || env("default_role")}
    json = "{\"id\":\"#{id}\",\"groups\":#{groups |> encode!}}"

    {:auth, {id, status}, mail, hash, groups, %{}, json}
    |> write_fn()
  end

  defp write_fn(tuple) do
    fn -> write(tuple) end
    |> transaction()
  end

  defp session_key(req) do
    {{a, b, c, d}, _} = req.peer
    ua = req.headers["user-agent"] || ""
    ip = "#{a}.#{b}.#{c}.#{d}"
    "{\"ip\":\"#{ip}\",\"ua\":\"#{ua}\"}"
  end

  def sign(ip, ua, uid), do: generate_and_sign!(%{id: uid, sid: ip <> ua})
  # def sign(ip, ua, uid), do: call(:auth, {:sign, ip, ua, uid})
  def claims(token), do: call(:auth, {:claims, token})
  def state, do: call(:auth, :state)
end
