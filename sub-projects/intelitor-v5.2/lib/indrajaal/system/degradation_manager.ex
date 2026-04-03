defmodule Indrajaal.System.DegradationManager do
  @moduledoc """
  Degradation Manager — L3 Control Layer (System Subsystem)

  ## Design Intent
  Manages graceful degradation when system resources are constrained. Maintains
  a priority-ordered registry of features that can be shed under pressure.
  Features are disabled in reverse priority order (lowest first) to preserve
  critical functionality.

  ## STAMP Constraints
  - SC-RECONFIG-007: Graceful degradation to older versions
  - SC-SIL4-001: Safety functions fail to safe state
  - SC-CIRCUIT-001: Drop telemetry when queue > 100

  ## Change History
  | Version | Date       | Author | Change                    |
  |---------|------------|--------|---------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation    |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @table :degradation_features
  @pubsub_topic "system:degradation"

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type feature_id :: atom()
  @type priority :: 1..10
  @type feature_status :: :active | :degraded | :disabled

  @type feature :: %{
          id: feature_id(),
          priority: priority(),
          status: feature_status(),
          description: String.t(),
          shed_fn: (-> :ok),
          restore_fn: (-> :ok)
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Register a sheddable feature with priority (1=lowest, 10=critical)."
  @spec register_feature(feature_id(), priority(), String.t(), keyword()) :: :ok
  def register_feature(id, priority, description, opts \\ []) do
    GenServer.call(@name, {:register, id, priority, description, opts})
  end

  @doc "Shed features to reduce load. Sheds N lowest-priority features."
  @spec shed(non_neg_integer()) :: [feature_id()]
  def shed(count \\ 1) do
    GenServer.call(@name, {:shed, count})
  end

  @doc "Restore previously shed features. Restores N highest-priority disabled features."
  @spec restore(non_neg_integer()) :: [feature_id()]
  def restore(count \\ 1) do
    GenServer.call(@name, {:restore, count})
  end

  @doc "Restore all shed features."
  @spec restore_all() :: [feature_id()]
  def restore_all do
    GenServer.call(@name, :restore_all)
  end

  @doc "Check if a feature is currently active."
  @spec active?(feature_id()) :: boolean()
  def active?(feature_id) do
    case :ets.lookup(@table, feature_id) do
      [{_, f}] -> f.status == :active
      [] -> true
    end
  rescue
    _ -> true
  end

  @doc "Get degradation status dashboard."
  @spec status() :: map()
  def status do
    GenServer.call(@name, :status)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

    Logger.info("[DegradationManager] Started [SC-RECONFIG-007]")

    {:ok, %{shed_count: 0, restore_count: 0, level: :normal}}
  end

  @impl true
  def handle_call({:register, id, priority, description, opts}, _from, state) do
    feature = %{
      id: id,
      priority: priority,
      status: :active,
      description: description,
      shed_fn: Keyword.get(opts, :shed_fn, fn -> :ok end),
      restore_fn: Keyword.get(opts, :restore_fn, fn -> :ok end)
    }

    :ets.insert(@table, {id, feature})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:shed, count}, _from, state) do
    # Get active features sorted by priority (lowest first for shedding)
    active =
      :ets.tab2list(@table)
      |> Enum.filter(fn {_, f} -> f.status == :active end)
      |> Enum.sort_by(fn {_, f} -> f.priority end)
      |> Enum.take(count)

    shed_ids =
      Enum.map(active, fn {id, feature} ->
        # Execute shed function
        try do
          feature.shed_fn.()
        rescue
          _ -> :ok
        end

        updated = %{feature | status: :disabled}
        :ets.insert(@table, {id, updated})
        id
      end)

    level = compute_level()

    if shed_ids != [] do
      broadcast(:features_shed, %{features: shed_ids, level: level})

      Logger.warning(
        "[DegradationManager] Shed #{length(shed_ids)} features: #{inspect(shed_ids)} [SC-RECONFIG-007]"
      )
    end

    emit_telemetry(:shed, %{count: length(shed_ids), level: level})

    {:reply, shed_ids, %{state | shed_count: state.shed_count + length(shed_ids), level: level}}
  end

  @impl true
  def handle_call({:restore, count}, _from, state) do
    # Get disabled features sorted by priority (highest first for restoring)
    disabled =
      :ets.tab2list(@table)
      |> Enum.filter(fn {_, f} -> f.status == :disabled end)
      |> Enum.sort_by(fn {_, f} -> f.priority end, :desc)
      |> Enum.take(count)

    restored_ids =
      Enum.map(disabled, fn {id, feature} ->
        try do
          feature.restore_fn.()
        rescue
          _ -> :ok
        end

        updated = %{feature | status: :active}
        :ets.insert(@table, {id, updated})
        id
      end)

    level = compute_level()

    if restored_ids != [] do
      broadcast(:features_restored, %{features: restored_ids, level: level})
    end

    {:reply, restored_ids,
     %{state | restore_count: state.restore_count + length(restored_ids), level: level}}
  end

  @impl true
  def handle_call(:restore_all, _from, state) do
    disabled =
      :ets.tab2list(@table)
      |> Enum.filter(fn {_, f} -> f.status == :disabled end)

    restored_ids =
      Enum.map(disabled, fn {id, feature} ->
        try do
          feature.restore_fn.()
        rescue
          _ -> :ok
        end

        updated = %{feature | status: :active}
        :ets.insert(@table, {id, updated})
        id
      end)

    level = compute_level()
    broadcast(:all_restored, %{count: length(restored_ids), level: level})

    {:reply, restored_ids,
     %{state | restore_count: state.restore_count + length(restored_ids), level: level}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    all = :ets.tab2list(@table) |> Enum.map(fn {_, f} -> f end)

    active = Enum.count(all, &(&1.status == :active))
    disabled = Enum.count(all, &(&1.status == :disabled))

    {:reply,
     %{
       total_features: length(all),
       active: active,
       disabled: disabled,
       level: state.level,
       shed_count: state.shed_count,
       restore_count: state.restore_count,
       features:
         Enum.map(all, fn f ->
           Map.take(f, [:id, :priority, :status, :description])
         end)
         |> Enum.sort_by(& &1.priority, :desc)
     }, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp compute_level do
    all = :ets.tab2list(@table) |> Enum.map(fn {_, f} -> f end)
    total = length(all)

    if total < 1 do
      :normal
    else
      disabled = Enum.count(all, &(&1.status == :disabled))
      ratio = disabled / total

      cond do
        ratio >= 0.5 -> :critical
        ratio >= 0.25 -> :degraded
        ratio > 0 -> :minor
        true -> :normal
      end
    end
  end

  defp broadcast(event, payload) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {event, payload}
    )
  rescue
    _ -> :ok
  end

  defp emit_telemetry(event, meta) do
    :telemetry.execute(
      [:indrajaal, :system, :degradation, event],
      %{timestamp: System.system_time(:millisecond)},
      meta
    )
  rescue
    _ -> :ok
  end
end
