defmodule Indrajaal.Core.Holon.HealthPropagator do
  @moduledoc """
  Health Propagator - Fractal Health Flow for v20.0.0

  Propagates health status through the holon hierarchy:
  - Children report health to parents (bottom-up)
  - Parents derive aggregate health from children
  - Subscribers notified on health changes

  ## STAMP Constraints

  - SC-HOL-003: Holons MUST report to parent within 100ms
  - SC-HOL-004: Holons MUST propagate health to children

  ## Architecture

  ```
  CHILD-1 ──┐
            ├──→ PARENT (derives from children)
  CHILD-2 ──┤         │
            │         ├──→ GRANDPARENT
  CHILD-3 ──┘         │
                      │
  CHILD-4 ────────────┘
  ```

  ## Health Derivation Rules

  - All healthy → :healthy
  - Any degraded, none critical/failed → :degraded
  - Any critical, none failed → :critical
  - Any failed → :failed

  ## Usage

      {:ok, hp} = HealthPropagator.start_link()

      # Children report their health
      HealthPropagator.report_health(hp, "child-1", "parent-1", :healthy)
      HealthPropagator.report_health(hp, "child-2", "parent-1", :degraded)

      # Parent derives aggregate health
      health = HealthPropagator.derive_parent_health(hp, "parent-1")
      # => :degraded

  """

  use GenServer
  require Logger

  alias Indrajaal.Core.Holon

  @default_staleness_threshold_ms 100

  @type holon_id :: String.t()
  @type health :: Holon.health()

  @type health_record :: %{
          holon_id: holon_id(),
          parent_id: holon_id() | nil,
          health: health(),
          reported_at: DateTime.t(),
          previous_health: health() | nil
        }

  # ============================================================================
  # CLIENT API
  # ============================================================================

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Reports health from a holon to its parent.
  SC-HOL-003: Should complete within 100ms.
  """
  @spec report_health(GenServer.server(), holon_id(), holon_id() | nil, health()) :: :ok
  def report_health(server, holon_id, parent_id, health) do
    GenServer.call(server, {:report_health, holon_id, parent_id, health})
  end

  @doc """
  Gets the health record for a holon.
  """
  @spec get_health(GenServer.server(), holon_id()) :: health_record() | nil
  def get_health(server, holon_id) do
    GenServer.call(server, {:get_health, holon_id})
  end

  @doc """
  Derives parent health from children health.
  SC-HOL-004: Aggregates child health to parent.
  """
  @spec derive_parent_health(GenServer.server(), holon_id()) :: health()
  def derive_parent_health(server, parent_id) do
    GenServer.call(server, {:derive_parent_health, parent_id})
  end

  @doc """
  Gets health records for all children of a parent.
  """
  @spec get_children_health(GenServer.server(), holon_id()) :: [health_record()]
  def get_children_health(server, parent_id) do
    GenServer.call(server, {:get_children_health, parent_id})
  end

  @doc """
  Subscribes to health change notifications.
  Subscriber receives `{:health_changed, holon_id, old_health, new_health}`.
  """
  @spec subscribe(GenServer.server(), pid()) :: :ok
  def subscribe(server, pid) do
    GenServer.call(server, {:subscribe, pid})
  end

  @doc """
  Detects stale health reports (no update within threshold).
  """
  @spec detect_staleness(GenServer.server(), holon_id()) :: [holon_id()]
  def detect_staleness(server, parent_id) do
    GenServer.call(server, {:detect_staleness, parent_id})
  end

  @doc """
  Returns propagator metrics.
  """
  @spec metrics(GenServer.server()) :: map()
  def metrics(server) do
    GenServer.call(server, :metrics)
  end

  # ============================================================================
  # GENSERVER CALLBACKS
  # ============================================================================

  @impl true
  def init(opts) do
    staleness_threshold =
      Keyword.get(opts, :staleness_threshold_ms, @default_staleness_threshold_ms)

    state = %{
      holons: %{},
      by_parent: %{},
      subscribers: [],
      metrics: %{
        health_reports: 0,
        health_changes: 0
      },
      staleness_threshold_ms: staleness_threshold,
      started_at: DateTime.utc_now()
    }

    Logger.info("[HealthPropagator] Started with staleness threshold: #{staleness_threshold}ms")

    {:ok, state}
  end

  @impl true
  def handle_call({:report_health, holon_id, parent_id, health}, _from, state) do
    now = DateTime.utc_now()

    # Get existing record
    existing = Map.get(state.holons, holon_id)
    previous_health = if existing, do: existing.health, else: nil

    # Create new record
    record = %{
      holon_id: holon_id,
      parent_id: parent_id,
      health: health,
      reported_at: now,
      previous_health: previous_health
    }

    # Update holons map
    new_holons = Map.put(state.holons, holon_id, record)

    # Update by_parent index
    new_by_parent = update_parent_index(state.by_parent, holon_id, parent_id)

    # Update metrics
    new_metrics = %{state.metrics | health_reports: state.metrics.health_reports + 1}

    new_metrics =
      if previous_health && previous_health != health do
        # Notify subscribers of health change
        notify_health_change(state.subscribers, holon_id, previous_health, health)
        %{new_metrics | health_changes: new_metrics.health_changes + 1}
      else
        new_metrics
      end

    new_state = %{state | holons: new_holons, by_parent: new_by_parent, metrics: new_metrics}

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_health, holon_id}, _from, state) do
    record = Map.get(state.holons, holon_id)
    {:reply, record, state}
  end

  @impl true
  def handle_call({:derive_parent_health, parent_id}, _from, state) do
    children_ids = Map.get(state.by_parent, parent_id, [])

    children_health =
      children_ids
      |> Enum.map(&Map.get(state.holons, &1))
      |> Enum.filter(& &1)
      |> Enum.map(& &1.health)

    derived = derive_health(children_health)
    {:reply, derived, state}
  end

  @impl true
  def handle_call({:get_children_health, parent_id}, _from, state) do
    children_ids = Map.get(state.by_parent, parent_id, [])

    records =
      children_ids
      |> Enum.map(&Map.get(state.holons, &1))
      |> Enum.filter(& &1)

    {:reply, records, state}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | subscribers: [pid | state.subscribers]}}
  end

  @impl true
  def handle_call({:detect_staleness, parent_id}, _from, state) do
    now = DateTime.utc_now()
    threshold_ms = state.staleness_threshold_ms

    children_ids = Map.get(state.by_parent, parent_id, [])

    stale =
      children_ids
      |> Enum.filter(fn id ->
        case Map.get(state.holons, id) do
          nil ->
            false

          record ->
            age_ms = DateTime.diff(now, record.reported_at, :millisecond)
            age_ms > threshold_ms
        end
      end)

    {:reply, stale, state}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    metrics = %{
      total_holons: map_size(state.holons),
      total_parents: map_size(state.by_parent),
      health_reports: state.metrics.health_reports,
      health_changes: state.metrics.health_changes,
      subscriber_count: length(state.subscribers),
      uptime_ms: DateTime.diff(DateTime.utc_now(), state.started_at, :millisecond)
    }

    {:reply, metrics, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    new_subscribers = Enum.reject(state.subscribers, &(&1 == pid))
    {:noreply, %{state | subscribers: new_subscribers}}
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp update_parent_index(by_parent, holon_id, parent_id) when is_binary(parent_id) do
    existing = Map.get(by_parent, parent_id, [])

    if holon_id in existing do
      by_parent
    else
      Map.put(by_parent, parent_id, [holon_id | existing])
    end
  end

  defp update_parent_index(by_parent, _holon_id, nil), do: by_parent

  defp derive_health([]), do: :healthy

  defp derive_health(health_list) do
    cond do
      Enum.any?(health_list, &(&1 == :failed)) -> :failed
      Enum.any?(health_list, &(&1 == :critical)) -> :critical
      Enum.any?(health_list, &(&1 == :degraded)) -> :degraded
      true -> :healthy
    end
  end

  defp notify_health_change(subscribers, holon_id, old_health, new_health) do
    Enum.each(subscribers, fn pid ->
      send(pid, {:health_changed, holon_id, old_health, new_health})
    end)
  end
end
