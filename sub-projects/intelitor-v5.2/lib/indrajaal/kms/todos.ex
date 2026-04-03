defmodule Indrajaal.KMS.Todos do
  @moduledoc """
  ## KMS TODOS CONTEXT
  The "Brain" of the Task Management System.
  Handles complex logic, recursive queries, and state transitions.
  """
  import Ecto.Query, warn: false
  alias Indrajaal.KMSRepo
  alias Indrajaal.KMS.Schema.Todo

  alias Indrajaal.KMS.Schema.TodoDependency

  # --- READ OPERATIONS ---

  def get_task!(id) do
    KMSRepo.get!(Todo, id)
    |> KMSRepo.preload([:subtasks, :blocking, :blocked_by])
  end

  def list_tasks(params \\ %{}) do
    Todo
    |> filter_by_status(params[:status])
    |> filter_by_layer(params[:layer])
    |> KMSRepo.all()
  end

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, status), do: where(query, [t], t.status == ^status)

  defp filter_by_layer(query, nil), do: query
  defp filter_by_layer(query, layer), do: where(query, [t], t.layer == ^layer)

  # --- WRITE OPERATIONS ---

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

  def add_dependency(blocking_id, blocked_id) do
    %TodoDependency{}
    |> TodoDependency.changeset(%{blocking_id: blocking_id, blocked_id: blocked_id})
    |> KMSRepo.insert()
  end

  # --- ADVANCED LOGIC ---

  @doc """
  Gets the full hierarchy tree for a root task using Recursive CTE.
  """
  def get_task_tree(root_id) do
    initial_query = from t in Todo, where: t.id == ^root_id

    recursion_query =
      from t in Todo,
        join: p in "tree",
        on: t.parent_id == p.id

    tree_query = initial_query |> union_all(^recursion_query)

    "tree"
    |> recursive_ctes(true)
    |> with_cte("tree", as: ^tree_query)
    |> from()
    |> KMSRepo.all()
  end

  @doc """
  Moves a task to a new state if valid.
  """
  def transition_status(task, new_status) do
    # Here we can enforce strict transitions (e.g. Backlog -> In Progress)
    update_task(task, %{status: new_status})
  end
end
