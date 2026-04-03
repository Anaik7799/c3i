defmodule Indrajaal.Repo.Migrations.CreateKmsTodos do
  use Ecto.Migration

  def change do
    create table(:kms_todos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      
      # Core Identity
      add :title, :string, null: false
      add :description, :text
      add :readable_id, :integer # Application managed auto-increment
      
      # Fractal Hierarchy
      add :layer, :string, null: false, default: "l1"
      add :parent_id, references(:kms_todos, type: :binary_id, on_delete: :nothing)
      # Note: ltree removed for SQLite compatibility. using Recursive CTE.
      
      # State Machine
      add :status, :string, null: false, default: "backlog"
      add :priority, :string, null: false, default: "p2"
      
      # Agile
      add :points, :integer
      add :cycle_id, :binary_id
      
      # Timeline
      add :start_at, :utc_datetime_usec
      add :due_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      
      # Flexibility (SQLite Text for JSON)
      add :custom_fields, :text, default: "{}" 
      add :tags, :text, default: "[]"
      
      # Compliance
      add :payload, :text, default: "{}"
      
      timestamps(type: :utc_datetime_usec)
    end

    # Dependency Graph
    create table(:kms_todo_dependencies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :blocking_id, references(:kms_todos, type: :binary_id, on_delete: :delete_all), null: false
      add :blocked_id, references(:kms_todos, type: :binary_id, on_delete: :delete_all), null: false
      
      timestamps(type: :utc_datetime_usec)
    end

    # Indexes
    create index(:kms_todos, [:parent_id])
    create index(:kms_todos, [:status])
    # create index(:kms_todos, [:readable_id], unique: true) # Defer unique constraint to app logic or partial index if needed
    
    create index(:kms_todo_dependencies, [:blocking_id])
    create index(:kms_todo_dependencies, [:blocked_id])
    create unique_index(:kms_todo_dependencies, [:blocking_id, :blocked_id])
  end
end
