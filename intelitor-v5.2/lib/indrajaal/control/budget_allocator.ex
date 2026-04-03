defmodule Indrajaal.Control.BudgetAllocator do
  @moduledoc """
  L3 Control Layer — VSM System 3 resource budget allocation.

  ## Design Intent
  Tracks resource budgets per domain (CPU%, memory MB, process count).
  Allocation and release operations use optimistic concurrency control (OCC)
  via a per-domain version counter to prevent stale write races.  When any
  domain exceeds its budget an alert is broadcast on PubSub so upstream
  observers can react immediately (SC-S3-003 anomaly reporting within 10ms).

  ETS is used for O(1) read access under high concurrency.  All mutations
  go through the GenServer to serialize version increments.

  ## STAMP Constraints
  - SC-S3-001: Budget MUST be enforced atomically
  - SC-S3-003: Anomalies MUST be reported within 10ms
  - SC-ORCH-005: Critical actions MUST request Guardian approval when over budget
  - SC-BUS-001: Async messaging only for over-budget alerts
  - SC-CONC-001: ETS read_concurrency for hot read paths

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L3 control layer) |
  """

  use GenServer

  require Logger

  @pubsub Indrajaal.PubSub
  @exceeded_topic "control:budget:exceeded"

  @type domain :: atom()

  @type resource_budget :: %{
          cpu_pct: non_neg_integer(),
          memory_mb: non_neg_integer(),
          process_count: non_neg_integer()
        }

  @type allocation :: %{
          domain: domain(),
          cpu_pct: non_neg_integer(),
          memory_mb: non_neg_integer(),
          process_count: non_neg_integer(),
          version: non_neg_integer(),
          allocated_at: DateTime.t()
        }

  @type allocator_state :: %{
          table: :ets.tid(),
          budgets: %{domain() => resource_budget()},
          metrics: %{
            allocations: non_neg_integer(),
            releases: non_neg_integer(),
            over_budget_count: non_neg_integer(),
            occ_conflicts: non_neg_integer()
          }
        }

  @default_budget %{cpu_pct: 25, memory_mb: 512, process_count: 1000}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Start the BudgetAllocator GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Allocate resources for a domain.

  Returns `{:ok, allocation}` or `{:error, reason}`.
  Pass the current `version` from a prior `get_allocation/1` call for OCC.
  Pass `version: 0` for an initial allocation.

  ## Examples

      iex> BudgetAllocator.allocate(:crm, %{cpu_pct: 10, memory_mb: 128, process_count: 50}, 0)
      {:ok, %{domain: :crm, cpu_pct: 10, memory_mb: 128, process_count: 50, version: 1, ...}}
  """
  @spec allocate(domain(), resource_budget(), non_neg_integer()) ::
          {:ok, allocation()} | {:error, :over_budget | :occ_conflict | term()}
  def allocate(domain, resources, expected_version) when is_atom(domain) and is_map(resources) do
    GenServer.call(__MODULE__, {:allocate, domain, resources, expected_version})
  end

  @doc """
  Release resources for a domain.

  Returns `:ok` or `{:error, :not_found}`.
  """
  @spec release(domain()) :: :ok | {:error, :not_found}
  def release(domain) when is_atom(domain) do
    GenServer.call(__MODULE__, {:release, domain})
  end

  @doc """
  Get the current allocation for a domain (fast ETS read).

  Returns the allocation map or `nil` if no allocation exists.
  """
  @spec get_allocation(domain()) :: allocation() | nil
  def get_allocation(domain) when is_atom(domain) do
    table = :ets.whereis(:budget_allocations)

    if table != :undefined do
      case :ets.lookup(table, domain) do
        [{^domain, alloc}] -> alloc
        [] -> nil
      end
    else
      nil
    end
  end

  @doc "Return all current allocations."
  @spec list_allocations() :: [allocation()]
  def list_allocations do
    GenServer.call(__MODULE__, :list_allocations)
  end

  @doc "Set or update the budget for a domain."
  @spec set_budget(domain(), resource_budget()) :: :ok
  def set_budget(domain, budget) when is_atom(domain) and is_map(budget) do
    GenServer.call(__MODULE__, {:set_budget, domain, budget})
  end

  @doc "Get current allocator metrics."
  @spec metrics() :: map()
  def metrics do
    GenServer.call(__MODULE__, :metrics)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    table =
      :ets.new(:budget_allocations, [
        :set,
        :named_table,
        :protected,
        read_concurrency: true
      ])

    initial_budgets = Keyword.get(opts, :budgets, %{})

    state = %{
      table: table,
      budgets: initial_budgets,
      metrics: %{
        allocations: 0,
        releases: 0,
        over_budget_count: 0,
        occ_conflicts: 0
      }
    }

    Logger.info("[BudgetAllocator] L3 resource budget allocator started (SC-S3-001)")
    {:ok, state}
  end

  @impl true
  def handle_call({:allocate, domain, resources, expected_version}, _from, state) do
    budget = Map.get(state.budgets, domain, @default_budget)

    with :ok <- check_budget(resources, budget),
         :ok <- check_occ(domain, expected_version, state.table) do
      new_version = expected_version + 1

      alloc = %{
        domain: domain,
        cpu_pct: Map.get(resources, :cpu_pct, 0),
        memory_mb: Map.get(resources, :memory_mb, 0),
        process_count: Map.get(resources, :process_count, 0),
        version: new_version,
        allocated_at: DateTime.utc_now()
      }

      :ets.insert(state.table, {domain, alloc})

      new_metrics = Map.update!(state.metrics, :allocations, &(&1 + 1))

      emit_telemetry(:allocate, %{domain: domain, version: new_version})
      {:reply, {:ok, alloc}, %{state | metrics: new_metrics}}
    else
      {:error, :over_budget} = err ->
        broadcast_exceeded(domain, resources, budget)
        new_metrics = Map.update!(state.metrics, :over_budget_count, &(&1 + 1))
        {:reply, err, %{state | metrics: new_metrics}}

      {:error, :occ_conflict} = err ->
        new_metrics = Map.update!(state.metrics, :occ_conflicts, &(&1 + 1))
        {:reply, err, %{state | metrics: new_metrics}}
    end
  end

  @impl true
  def handle_call({:release, domain}, _from, state) do
    case :ets.lookup(state.table, domain) do
      [{^domain, _alloc}] ->
        :ets.delete(state.table, domain)
        new_metrics = Map.update!(state.metrics, :releases, &(&1 + 1))
        emit_telemetry(:release, %{domain: domain})
        {:reply, :ok, %{state | metrics: new_metrics}}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:list_allocations, _from, state) do
    allocs =
      state.table
      |> :ets.tab2list()
      |> Enum.map(fn {_domain, alloc} -> alloc end)

    {:reply, allocs, state}
  end

  @impl true
  def handle_call({:set_budget, domain, budget}, _from, state) do
    new_budgets = Map.put(state.budgets, domain, budget)
    Logger.info("[BudgetAllocator] Budget updated for domain=#{domain}")
    {:reply, :ok, %{state | budgets: new_budgets}}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec check_budget(resource_budget(), resource_budget()) :: :ok | {:error, :over_budget}
  defp check_budget(requested, budget) do
    over =
      Map.get(requested, :cpu_pct, 0) > Map.get(budget, :cpu_pct, 100) or
        Map.get(requested, :memory_mb, 0) > Map.get(budget, :memory_mb, 4096) or
        Map.get(requested, :process_count, 0) > Map.get(budget, :process_count, 10_000)

    if over, do: {:error, :over_budget}, else: :ok
  end

  @spec check_occ(domain(), non_neg_integer(), :ets.tid()) ::
          :ok | {:error, :occ_conflict}
  defp check_occ(domain, expected_version, table) do
    current_version =
      case :ets.lookup(table, domain) do
        [{^domain, alloc}] -> alloc.version
        [] -> 0
      end

    if current_version == expected_version, do: :ok, else: {:error, :occ_conflict}
  end

  defp broadcast_exceeded(domain, requested, budget) do
    payload = %{
      domain: domain,
      requested: requested,
      budget: budget,
      timestamp: DateTime.utc_now()
    }

    Logger.warning(
      "[BudgetAllocator] Over-budget domain=#{domain} requested=#{inspect(requested)} budget=#{inspect(budget)}"
    )

    try do
      Phoenix.PubSub.broadcast(@pubsub, @exceeded_topic, {:budget_exceeded, payload})
    rescue
      _ -> :ok
    end
  end

  defp emit_telemetry(event, measurements) do
    :telemetry.execute(
      [:indrajaal, :control, :budget_allocator, event],
      measurements,
      %{timestamp: DateTime.utc_now()}
    )
  end
end
