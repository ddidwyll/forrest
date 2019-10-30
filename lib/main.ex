defmodule Tree.Main do
  @moduledoc false

  import Tree.Utils
  import Tree.Store
  import Tree.Guards
  import Tree.Validator
  import Tree.Events, only: [event: 4]
  import Tree.Config, only: [env: 1, schema: 1]

  import String, only: [split: 2]

  import :cowboy_req,
    only: [read_body: 1, set_resp_body: 2]

  import Jason,
    only: [decode: 2, decode!: 2, encode!: 2]

  @copy [strings: :copy]
  @html [escape: :html_safe]

  defp get_body({req, state}) do
    with {:ok, json, _} <- read_body(req),
         {:ok, body} <- decode(json, @copy) do
      {:ok, req, %{state | in: body}}
    else
      {:error, e} ->
        message = "Invalid json #{e.position || ""}"
        {:error, req, %{state | out: message}}
    end
  end

  defp substitution(state) do
    %{
      time: state.now |> to_string,
      uid: state.uid,
      gid: state.gid
    }
  end

  defp rise({result, req, state}) do
    with :ok <- result,
         true <- is_binary(state.to),
         lvls <- split(state.to, ","),
         schema <- deep_get(lvls, state.schema),
         true <- schema["type"] == "array",
         struct <- schema["struct"],
         true <- is_map(struct) do
      {:ok, req, %{state | schema: struct, to: lvls}}
    else
      err ->
        IO.inspect({"rise", err})
        message = "Unable to push into #{state.to} of #{state.branch}"
        {:error, req, %{state | out: message}}
    end
  end

  defp sit({result, req, state}) do
    with :ok <- result,
         rec0 <- decode!(state.out, @copy),
         arr <- [state.in | deep_get(state.to, rec0) || []],
         rec <- deep_set(state.to, arr, rec0) do
      {result, req, %{state | schema: schema(state.branch), to: nil, in: rec}}
    else
      err ->
        IO.inspect({"sit", err})
        {result, req, state}
    end
  end

  defp merge({result, req, state}) do
    if result == :ok do
      rec =
        decode!(state.out, @copy)
        |> deep_merge(state.in)

      {result, req, %{state | in: rec}}
    else
      {result, req, state}
    end
  end

  defp validate({result, req, state}) do
    with :ok <- result,
         %{in: r, schema: s} <- state,
         subs <- substitution(state),
         {:ok, rec} <- process({r, s}, subs) do
      {:ok, req, %{state | in: rec}}
    else
      {:error, e} ->
        IO.inspect({"validate", e})
        {:error, req, %{state | out: e}}
      err ->
        IO.inspect({"validate", err})
        {:error, req, state}
    end
  end

  def message({result, req0, state}) do
    req =
      unless state.out,
        do: req0,
        else:
          state.out
          |> encode!(@html)
          |> set_resp_body(req0)

    {result, req, state}
  end

  defp title(state) do
    state.branch
  end

  defp create({result, req, state}) do
    if result == :ok do
      {:ok, id, time} =
        post(
          state.branch,
          state.uid,
          state.gid,
          state.in
        )

      message = state.branch <> " posted successful"
      {:ok, req, %{state | to: time, from: id, out: message}}
    else
      {result, req, state}
    end
  end

  defp update({result, req, state}) do
    if result == :ok do
      {:ok, _, time} =
        put(
          state.branch,
          state.from,
          state.uid,
          state.gid,
          "active",
          state.in
        )

      message = title(state) <> " updated successful"
      {true, req, %{state | to: time, out: message}}
    else
      {false, req, %{state | out: state.out || "something went wrong"}}
    end
  end

  defp event({result, req, state}, action) do
    if result in [true, :ok] do
      event(
        state.branch,
        state.from,
        action,
        state.to
      )
    end

    {result, req, state}
  end

  defp result({result, req, state}) do
    cond do
      result == :ok && !state.to ->
        {true, req, state}

      result == :ok && state.to ->
        url = "//rest.#{env("host")}/#{state.branch}/#{state.to}"
        {{true, url}, req, state}

      true ->
        {false, req, state}
    end
  end

  def exist(req, state) do
    with false <- is_nil(state.from),
         list <-
           get_one(
             state.type,
             state.branch,
             state.from
           ),
         false <- is_empty_list(list),
         {_, _, gid, uid, upd, json} <- hd(list) do
      {
        true,
        req,
        %{state | upd: upd, out: json}
      }
    else
      _ -> {false, req, state}
    end
  end

  def status(state) do
    statuses =
      if state.from,
        do:
          get_all(
            state.type,
            state.branch,
            :_,
            :_,
            :_,
            state.from
          )
          |> list_status,
        else: []

    cond do
      is_empty_list(statuses) ->
        state

      statuses == [:deleted] || :deleted in [statuses] ->
        %{state | out: title(state) <> " deleted"}

      statuses == [:blocked] || :blocked in [statuses] ->
        %{state | out: title(state) <> " blocked"}

      statuses == [:archived] || :archived in [statuses] ->
        to = {true, "//arch.#{env("host")}/#{state.branch}/#{state.from}"}
        %{state | out: title(state) <> " moved to archive", to: to}
    end
  end

  def post(req, state) do
    {req, state}
    |> get_body()
    |> validate()
    |> create()
    |> message()
    |> event("post")
    |> result()
  end

  def patch(req, state) do
    {req, state}
    |> get_body()
    |> merge()
    |> validate()
    |> update()
    |> message()
    |> event("patch")
  end

  def put(req, state) do
    {req, state}
    |> get_body()
    |> rise()
    |> validate()
    |> sit()
    |> validate()
    |> update()
    |> message()
    |> event("patch")
  end

  def delete({req, state}) do
    unless state.to do
      case delete(state.branch, state.from) do
        {:ok, time} ->
          {true, req, %{state | to: time}}
          |> event("delete")

        err ->
          IO.inspect({"delete", err})
          {false, req, state}
      end
    end
  end
end
