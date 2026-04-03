defmodule Indrajaal.KMS.Schema.TodoDependency do
  @moduledoc """
  ## KMS DEPENDENCY SCHEMA (Ecto)
  Join table for Task Graph.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "todo_dependencies" do
    belongs_to :blocking, Indrajaal.KMS.Schema.Todo
    belongs_to :blocked, Indrajaal.KMS.Schema.Todo

    timestamps()
  end

  @doc false
  def changeset(dependency, attrs) do
    dependency
    |> cast(attrs, [:blocking_id, :blocked_id])
    |> validate_required([:blocking_id, :blocked_id])
    |> unique_constraint([:blocking_id, :blocked_id])
  end
end
