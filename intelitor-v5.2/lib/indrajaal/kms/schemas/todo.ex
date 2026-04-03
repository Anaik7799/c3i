defmodule Indrajaal.KMS.Schema.Todo do
  @moduledoc """
  ## KMS OMNI-TASK SCHEMA (Ecto)
  Pure Ecto schema representing the "Omni-Task" Holon.

  **Features**:
  - **Identity**: UUID + Readable ID (IND-123)
  - **Structure**: 10-Level Hierarchy
  - **Agile**: Points, Cycles
  - **Flexibility**: JSONB Custom Fields
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "kms_todos" do
    field :title, :string
    field :description, :string
    field :readable_id, :integer, read_after_writes: true

    # Virtual field for display (e.g. "IND-42")
    field :formatted_id, :string, virtual: true

    field :layer, Ecto.Enum,
      values: [:l1, :l2, :l3, :l4, :l5, :l6, :l7, :l8, :l9, :l10],
      default: :l1

    field :status, Ecto.Enum,
      values: [:backlog, :in_progress, :in_review, :done, :blocked, :archived],
      default: :backlog

    field :priority, Ecto.Enum, values: [:p0, :p1, :p2, :p3, :p4], default: :p2

    field :points, :integer
    field :custom_fields, Indrajaal.Ecto.JSONText, default: %{}
    field :tags, Indrajaal.Ecto.JSONText, default: []
    field :payload, Indrajaal.Ecto.JSONText, default: %{}

    # Timeline
    field :start_at, :utc_datetime_usec
    field :due_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec

    # Relationships
    belongs_to :parent, Indrajaal.KMS.Schema.Todo
    has_many :subtasks, Indrajaal.KMS.Schema.Todo, foreign_key: :parent_id

    many_to_many :blocked_by, Indrajaal.KMS.Schema.Todo,
      join_through: "kms_todo_dependencies",
      join_keys: [blocked_id: :id, blocking_id: :id],
      on_replace: :delete

    many_to_many :blocking, Indrajaal.KMS.Schema.Todo,
      join_through: "kms_todo_dependencies",
      join_keys: [blocking_id: :id, blocked_id: :id],
      on_replace: :delete

    timestamps()
  end

  def changeset(todo, attrs) do
    todo
    |> cast(attrs, [
      :title,
      :description,
      :layer,
      :status,
      :priority,
      :points,
      :start_at,
      :due_at,
      :completed_at,
      :custom_fields,
      :tags,
      :payload,
      :parent_id
    ])
    |> validate_required([:title, :status, :priority])
    |> validate_layer_depth()
  end

  defp validate_layer_depth(changeset) do
    # Placeholder: Could query parent to ensure max depth not exceeded
    changeset
  end
end
