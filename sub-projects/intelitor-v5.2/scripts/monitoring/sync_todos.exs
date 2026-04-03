#!/usr/bin/env elixir
# Sync Claude session todos to dashboard format
# Called by dashboard to get current todo state

defmodule TodoSync do
  @todo_file "data/tmp/claude_todos.json"

  def sync(todos) when is_list(todos) do
    json = Jason.encode!(%{
      todos: todos,
      updated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      session_id: System.get_env("CLAUDE_SESSION_ID", "unknown")
    })
    File.write!(@todo_file, json)
    :ok
  end

  def read do
    case File.read(@todo_file) do
      {:ok, content} -> Jason.decode!(content)
      _ -> %{"todos" => [], "updated_at" => nil}
    end
  end
end
