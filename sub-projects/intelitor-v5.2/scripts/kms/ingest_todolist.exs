#!/usr/bin/env elixir

# Script: ingest_todolist.exs
# Context: Phase 4 Unified / SIL-6 Biomorphic
# Objective: Standalone migration of legacy PROJECT_TODOLIST.md to KMS SQLite Graph.
# Note: Bypasses main app compilation to ensure execution despite codebase rot.

Mix.install([
  {:postgrex, ">= 0.0.0"},
  {:ecto_sql, ">= 0.0.0"},
  {:jason, "~> 1.4"}
])

defmodule MinimalRepo do
  use Ecto.Repo,
    otp_app: :minimal_script,
    adapter: Ecto.Adapters.Postgres
end

defmodule MinimalSchema do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "kms_todos" do
    field :title, :string
    field :description, :string
    field :readable_id, :integer
    field :layer, :string, default: "l1"
    field :status, :string, default: "backlog"
    field :priority, :string, default: "p2"
    field :points, :integer
    field :custom_fields, :map, default: %{}
    field :tags, {:array, :string}, default: []
    field :payload, :map, default: %{}
    field :start_at, :utc_datetime_usec
    field :due_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
    field :parent_id, :binary_id
    timestamps(type: :utc_datetime_usec)
  end
end

defmodule TodoIngester do
  import Ecto.Query
  require Logger

  @project_todo_path "PROJECT_TODOLIST.md"

  def run do
    setup_db()
    
    Logger.info("Starting KMS Todo Ingestion...")
    content = File.read!(@project_todo_path)
    _tasks = parse_markdown(content)
    Logger.info("Ingestion Complete.")
  end

  defp setup_db do
    # Configure Repo
    Application.put_env(:minimal_script, MinimalRepo, [
      url: "postgres://postgres:postgres@localhost:5433/indrajaal_dev",
      pool_size: 2
    ])
    
    {:ok, _} = MinimalRepo.start_link()
    
    # Ensure Table Exists (Idempotent)
    sql = """
    CREATE TABLE IF NOT EXISTS kms_todos (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      title TEXT NOT NULL,
      description TEXT,
      readable_id SERIAL,
      layer TEXT DEFAULT 'l1',
      status TEXT DEFAULT 'backlog',
      priority TEXT DEFAULT 'p2',
      points INTEGER,
      custom_fields JSONB DEFAULT '{}',
      tags JSONB DEFAULT '[]',
      payload JSONB DEFAULT '{}',
      start_at TIMESTAMP,
      due_at TIMESTAMP,
      completed_at TIMESTAMP,
      parent_id UUID REFERENCES kms_todos(id),
      inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );
    """
    Ecto.Adapters.SQL.query!(MinimalRepo, sql, [])
    
    # Add indexes if not exist (best effort)
    try do
        Ecto.Adapters.SQL.query!(MinimalRepo, "CREATE INDEX idx_kms_todos_parent ON kms_todos(parent_id)", [])
    rescue
        _ -> :ok
    end
  end

  defp parse_markdown(content) do
    lines = String.split(content, "\n")
    
    # We need to maintain a stack of parents to handle indentation/nesting
    # State: {parent_stack, current_tasks}
    # parent_stack: [{level, id}]
    
    {_, tasks} = Enum.reduce(lines, {[], []}, fn line, {stack, tasks} ->
      case parse_line(line) do
        nil -> 
            {stack, tasks}
            
        task ->
            # Determine parent based on hierarchy level
            # 1. Header (Level 1-3)
            # 2. List Item (Level 4+)
            
            # Simplified Logic:
            # If we find a task at level N, we pop stack until we find a parent < N
            # Then we push this task as new potential parent
            
            level = task.level
            
            # Pop stack
            new_stack = Enum.drop_while(stack, fn {l, _} -> l >= level end)
            
            parent_id = case List.first(new_stack) do
                {_, pid} -> pid
                nil -> nil
            end
            
            # Assign parent
            final_task = Map.put(task, :parent_id, parent_id)
            
            # Insert immediately to get ID for stack
            # (In a real run we might batch, but for hierarchy we need IDs)
            # Note: We simulate an ID here for the stack if we aren't inserting yet, 
            # but since we are running standalone, we can't easily get the UUID back without inserting.
            # So we will do a two-pass or just insert here.
            
            {:ok, inserted} = insert_task(final_task)
            
            {[{level, inserted.id} | new_stack], [inserted | tasks]}
      end
    end)
    
    tasks
  end

  defp parse_line(line) do
    cond do
      # Header: ### 31.1.0...
      match = Regex.run(~r/^(#+)\s+([\d\.]+)\s+-\s+(.+)$/, line) ->
        [_, hashes, id_str, title_raw] = match
        level = String.length(hashes)
        status = if String.contains?(line, "✅"), do: "done", else: "in_progress"
        
        %{ 
          title: clean_title(title_raw),
          status: status,
          priority: "p1",
          layer: "l#{level}",
          description: id_str, # Storing the numeric ID in description for now
          level: level
        }

      # List Item: - 31.1.1... [x]
      match = Regex.run(~r/^(\s*)-\s+([\d\.]+)\s+-\s+(.+?)\s+\[([ x])\]/, line) ->
        [_, indent, id_str, title_raw, check] = match
        
        # Calculate level based on indent (2 spaces = 1 level)
        indent_len = String.length(indent)
        level = 4 + div(indent_len, 2)
        
        status = if check == "x", do: "done", else: "backlog"
        
        %{ 
          title: clean_title(title_raw),
          status: status,
          priority: "p2",
          layer: "l#{level}",
          description: id_str,
          level: level
        }
        
      true -> nil
    end
  end
  
  defp clean_title(title) do
    title
    |> String.replace(~r/\s*\[.*?\]/, "")
    |> String.trim()
  end

  defp insert_task(attrs) do
    # Map map keys to schema
    db_attrs = %{
        title: attrs.title,
        description: attrs.description,
        status: attrs.status,
        priority: attrs.priority,
        layer: attrs.layer,
        parent_id: attrs.parent_id,
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
    }
    
    # We use raw insert to avoid changeset complexity in standalone script
    MinimalRepo.insert_all("kms_todos", [db_attrs], returning: [:id])
    |> case do
        {1, [result]} -> {:ok, result}
        _ -> {:error, :failed}
    end
  end
end

TodoIngester.run()