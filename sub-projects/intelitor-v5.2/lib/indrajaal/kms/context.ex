defmodule Indrajaal.KMS.Context do
  @moduledoc """
  ## KMS CONTEXT (Logic Plane)
  The Ecto-based entry point for Knowledge Management.
  Replaces the Ash Domain facade.
  """
  import Ecto.Query, warn: false
  alias Indrajaal.KMSRepo
  alias Indrajaal.KMS.Schema.Todo
  alias Indrajaal.KMS.Schema.TodoDependency

  # --- READ ---

  def get_task!(id),
    do: KMSRepo.get!(Todo, id) |> KMSRepo.preload([:parent, :subtasks, :blocking, :blocked_by])

  def get_task_by_fqun(fqun) do
    Todo
    |> where([t], t.fqun == ^fqun)
    |> KMSRepo.one()
  end

  def list_tasks(params \\ %{}) do
    Todo
    |> filter_tasks(params)
    |> KMSRepo.all()
  end

  defp filter_tasks(query, params) do
    Enum.reduce(params, query, fn
      {:status, status}, q -> where(q, [t], t.status == ^status)
      {:layer, layer}, q -> where(q, [t], t.layer == ^layer)
      {:priority, p}, q -> where(q, [t], t.priority == ^p)
      _, q -> q
    end)
  end

  # --- WRITE ---

  def create_task(attrs) do
    %Todo{}
    |> Todo.changeset(attrs)
    |> KMSRepo.insert()
  end

  def update_task(%Todo{} = todo, attrs) do
    todo
    |> Todo.changeset(attrs)
    |> KMSRepo.update()
  end

  def delete_task(%Todo{} = todo) do
    KMSRepo.delete(todo)
  end

  # --- GRAPH OPERATIONS ---

  def add_dependency(blocking_id, blocked_id) do
    %TodoDependency{}
    |> TodoDependency.changeset(%{blocking_id: blocking_id, blocked_id: blocked_id})
    |> KMSRepo.insert()
  end

  def remove_dependency(blocking_id, blocked_id) do
    q =
      from d in TodoDependency,
        where: d.blocking_id == ^blocking_id and d.blocked_id == ^blocked_id

    KMSRepo.delete_all(q)
  end

  # --- STATE MACHINE LOGIC ---

  def transition_status(%Todo{} = todo, new_status) do
    # Simple transition logic (can be expanded to full FSM)
    update_task(todo, %{status: new_status})
  end
end
