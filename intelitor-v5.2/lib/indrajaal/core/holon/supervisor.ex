defmodule Indrajaal.Core.Holon.Supervisor do
  @moduledoc """
  Holon Supervisor - Fractal Supervision Tree for v20.0.0

  Provides fractal supervision for holons:
  1. Layer-aware supervision strategies
  2. Automatic restart with constitution verification
  3. Health-based scaling decisions
  4. Graceful degradation support

  ## Supervision Strategies by Layer
  - :function → :one_for_one (isolated failures)
  - :module → :one_for_one (isolated failures)
  - :agent → :one_for_one (agent independence)
  - :container → :rest_for_one (ordered dependencies)
  - :node → :one_for_all (node integrity)
  - :cluster → :one_for_all (cluster integrity)
  - :federation → :one_for_all (federation integrity)

  ## STAMP Constraints
  - SC-SUP-001: Constitution MUST be verified before child restart
  - SC-SUP-002: Failed children MUST be reported to parent holon
  - SC-SUP-003: Max restarts MUST respect layer thresholds
  - SC-SUP-004: Supervision tree MUST match holon hierarchy
  """

  use Supervisor
  require Logger

  alias Indrajaal.Core.Holon
  alias Indrajaal.Core.Constitution.Verifier

  @layer_strategies %{
    function: :one_for_one,
    module: :one_for_one,
    agent: :one_for_one,
    container: :rest_for_one,
    node: :one_for_all,
    cluster: :one_for_all,
    federation: :one_for_all
  }

  @layer_max_restarts %{
    function: {10, 60},
    module: {5, 60},
    agent: {3, 60},
    container: {3, 300},
    node: {2, 600},
    cluster: {1, 900},
    federation: {1, 1800}
  }

  @doc """
  Starts the holon supervisor.
  """
  def start_link(opts) do
    _layer = Keyword.fetch!(opts, :layer)
    name = Keyword.get(opts, :name, __MODULE__)

    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns the supervision strategy for a layer.
  """
  @spec strategy_for_layer(Holon.layer()) :: Supervisor.strategy()
  def strategy_for_layer(layer) do
    Map.get(@layer_strategies, layer, :one_for_one)
  end

  @doc """
  Returns the max restart configuration for a layer.
  """
  @spec max_restarts_for_layer(Holon.layer()) :: {non_neg_integer(), non_neg_integer()}
  def max_restarts_for_layer(layer) do
    Map.get(@layer_max_restarts, layer, {3, 60})
  end

  @doc """
  Starts a child holon under this supervisor.
  """
  @spec start_child(Supervisor.supervisor(), module(), Keyword.t()) ::
          {:ok, pid()} | {:error, term()}
  def start_child(supervisor, child_module, opts \\ []) do
    # Verify constitution before starting child (SC-SUP-001)
    case Verifier.verify() do
      {:ok, _} ->
        child_spec = child_spec(child_module, opts)
        Supervisor.start_child(supervisor, child_spec)

      {:error, :constitution_violated, details} ->
        Logger.error("Cannot start child #{child_module}: constitution violated")
        {:error, {:constitution_violated, details}}
    end
  end

  @doc """
  Terminates a child holon.
  """
  @spec terminate_child(Supervisor.supervisor(), pid() | atom()) :: :ok | {:error, :not_found}
  def terminate_child(supervisor, child_id) do
    Supervisor.terminate_child(supervisor, child_id)
  end

  @doc """
  Restarts a child holon.
  """
  @spec restart_child(Supervisor.supervisor(), pid() | atom()) ::
          {:ok, pid()} | {:error, term()}
  def restart_child(supervisor, child_id) do
    # Verify constitution before restart (SC-SUP-001)
    case Verifier.verify() do
      {:ok, _} ->
        Supervisor.restart_child(supervisor, child_id)

      {:error, :constitution_violated, details} ->
        Logger.error("Cannot restart child #{child_id}: constitution violated")
        {:error, {:constitution_violated, details}}
    end
  end

  @doc """
  Returns the count of active children.
  """
  @spec child_count(Supervisor.supervisor()) :: non_neg_integer()
  def child_count(supervisor) do
    supervisor
    |> Supervisor.which_children()
    |> length()
  end

  @doc """
  Returns summary of children for monitoring.
  """
  @spec children_summary(Supervisor.supervisor()) :: map()
  def children_summary(supervisor) do
    children = Supervisor.which_children(supervisor)

    %{
      total: length(children),
      active: Enum.count(children, fn {_, pid, _, _} -> is_pid(pid) end),
      restarting: Enum.count(children, fn {_, pid, _, _} -> pid == :restarting end),
      undefined: Enum.count(children, fn {_, pid, _, _} -> pid == :undefined end)
    }
  end

  # Callbacks

  @impl true
  def init(opts) do
    layer = Keyword.fetch!(opts, :layer)
    children = Keyword.get(opts, :children, [])

    strategy = strategy_for_layer(layer)
    {max_restarts, max_seconds} = max_restarts_for_layer(layer)

    Logger.info("[HolonSupervisor] Starting for layer #{layer} with strategy #{strategy}")

    # Build child specs
    child_specs =
      Enum.map(children, fn
        {module, child_opts} -> child_spec(module, child_opts)
        module when is_atom(module) -> child_spec(module, [])
      end)

    Supervisor.init(child_specs,
      strategy: strategy,
      max_restarts: max_restarts,
      max_seconds: max_seconds
    )
  end

  # Private

  defp child_spec(module, opts) do
    %{
      id: Keyword.get(opts, :id, module),
      start: {module, :start_link, [opts]},
      restart: Keyword.get(opts, :restart, :permanent),
      shutdown: Keyword.get(opts, :shutdown, 5000),
      type: Keyword.get(opts, :type, :worker)
    }
  end
end
