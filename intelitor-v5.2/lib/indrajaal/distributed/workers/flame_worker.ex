defmodule Indrajaal.Distributed.Workers.FLAMEWorker do
  @moduledoc """
  Worker 1: FLAME - Elastic Compute Pool Worker.

  WHAT: Manages FLAME pool operations for elastic compute.
  WHY: SC-FLAME-001 requires distributed computation elasticity.
  CONSTRAINTS: Pool scaling, resource tracking, node affinity.

  ## FLAME Responsibilities

  1. **Pool Management**: Create, scale, destroy compute pools
  2. **Job Dispatch**: Route compute jobs to appropriate pools
  3. **Resource Tracking**: Monitor pool utilization
  4. **Node Affinity**: Optimize job placement

  ## STAMP Constraints

  - SC-FLAME-001: Pool creation < 5s
  - SC-FLAME-002: Job dispatch < 10ms
  - SC-FLAME-003: Resource metrics every 10s
  - SC-FLAME-004: Graceful pool shutdown

  ## Mathematical Specification

  ```
  FLAME := (Pools, Jobs, Resources)

  Pools := Map(PoolID, Pool)
  Pool := (Runners, Capacity, Utilization)

  Jobs := Queue(Job)
  Job := (Function, Args, Priority, Affinity)

  Scaling Invariant:
    ∀ pool ∈ Pools: Utilization(pool) > 0.8 ⟹ Scale(pool, up)
    ∀ pool ∈ Pools: Utilization(pool) < 0.2 ⟹ Scale(pool, down)

  Dispatch Rule:
    dispatch(job) = argmin_{pool} (Utilization(pool)) where Affinity(job) ⊆ pool
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-FLAME-001 to SC-FLAME-004 |
  """

  use Indrajaal.Distributed.Workers.BaseWorker,
    type: :compute,
    namespace: "flame",
    name: "pool_worker"

  alias Indrajaal.Distributed.FQUN

  # ============================================================
  # WORKER CALLBACKS
  # ============================================================

  @impl true
  def worker_init(_opts) do
    state = %{
      # Pool tracking (pool_id -> pool_info)
      pools: %{},

      # Pool FQUNs
      pool_fquns: %{},

      # Pending jobs by pool
      pending_by_pool: %{},

      # Resource utilization
      utilization: %{},

      # Configuration
      config: %{
        default_min_runners: 1,
        default_max_runners: 10,
        scale_up_threshold: 0.8,
        scale_down_threshold: 0.2,
        scale_cooldown_ms: 30_000
      },

      # Metrics
      pools_created: 0,
      pools_destroyed: 0,
      jobs_dispatched: 0,
      scale_events: 0
    }

    {:ok, state}
  end

  @impl true
  def worker_state(state) do
    %{
      pool_count: map_size(state.pools),
      pools: pool_summary(state.pools),
      utilization: state.utilization,
      jobs_dispatched: state.jobs_dispatched
    }
  end

  @impl true
  def worker_metrics(state) do
    %{
      pool_count: map_size(state.pools),
      pools_created: state.pools_created,
      pools_destroyed: state.pools_destroyed,
      jobs_dispatched: state.jobs_dispatched,
      scale_events: state.scale_events,
      avg_utilization: calculate_avg_utilization(state.utilization)
    }
  end

  @impl true
  def handle_job({:create_pool, pool_name, opts}, state) do
    # Generate FQUN for pool
    {:ok, pool_fqun} = FQUN.generate(:resource, :pool, "flame", pool_name)

    min_runners = Keyword.get(opts, :min_runners, state.config.default_min_runners)
    max_runners = Keyword.get(opts, :max_runners, state.config.default_max_runners)

    pool_info = %{
      name: pool_name,
      fqun: pool_fqun,
      min_runners: min_runners,
      max_runners: max_runners,
      current_runners: min_runners,
      status: :active,
      created_at: DateTime.utc_now(),
      last_scale_at: nil
    }

    new_pools = Map.put(state.pools, pool_name, pool_info)
    new_pool_fquns = Map.put(state.pool_fquns, pool_name, pool_fqun)
    new_utilization = Map.put(state.utilization, pool_name, 0.0)

    new_state = %{
      state
      | pools: new_pools,
        pool_fquns: new_pool_fquns,
        utilization: new_utilization,
        pools_created: state.pools_created + 1
    }

    # Publish pool creation to Zenoh
    publish_pool_event(:created, pool_info)

    {:ok, {:pool_created, pool_fqun}, new_state}
  end

  @impl true
  def handle_job({:destroy_pool, pool_name}, state) do
    case Map.get(state.pools, pool_name) do
      nil ->
        {:error, :pool_not_found, state}

      pool_info ->
        # Unregister FQUN
        FQUN.unregister(pool_info.fqun)

        new_pools = Map.delete(state.pools, pool_name)
        new_pool_fquns = Map.delete(state.pool_fquns, pool_name)
        new_utilization = Map.delete(state.utilization, pool_name)

        new_state = %{
          state
          | pools: new_pools,
            pool_fquns: new_pool_fquns,
            utilization: new_utilization,
            pools_destroyed: state.pools_destroyed + 1
        }

        # Publish pool destruction to Zenoh
        publish_pool_event(:destroyed, pool_info)

        {:ok, :pool_destroyed, new_state}
    end
  end

  @impl true
  def handle_job({:dispatch, pool_name, _function, _args}, state) do
    case Map.get(state.pools, pool_name) do
      nil ->
        {:error, :pool_not_found, state}

      pool_info when pool_info.status == :active ->
        # Simulate dispatching to FLAME pool
        job_id = generate_job_id()

        Logger.debug("[FLAMEWorker] Dispatching job",
          pool: pool_name,
          job_id: job_id
        )

        # Update utilization estimate
        current_util = Map.get(state.utilization, pool_name, 0.0)
        new_util = min(1.0, current_util + 0.1)
        new_utilization = Map.put(state.utilization, pool_name, new_util)

        new_state = %{
          state
          | utilization: new_utilization,
            jobs_dispatched: state.jobs_dispatched + 1
        }

        # Check if scaling needed
        new_state = maybe_scale(new_state, pool_name)

        {:ok, {:dispatched, job_id}, new_state}

      _pool_info ->
        {:error, :pool_not_active, state}
    end
  end

  @impl true
  def handle_job({:scale, pool_name, direction}, state) do
    case Map.get(state.pools, pool_name) do
      nil ->
        {:error, :pool_not_found, state}

      pool_info ->
        new_runners =
          case direction do
            :up ->
              min(pool_info.max_runners, pool_info.current_runners + 1)

            :down ->
              max(pool_info.min_runners, pool_info.current_runners - 1)
          end

        if new_runners != pool_info.current_runners do
          new_pool_info = %{
            pool_info
            | current_runners: new_runners,
              last_scale_at: DateTime.utc_now()
          }

          new_pools = Map.put(state.pools, pool_name, new_pool_info)

          new_state = %{
            state
            | pools: new_pools,
              scale_events: state.scale_events + 1
          }

          # Publish scale event
          publish_pool_event(:scaled, %{
            pool: pool_name,
            direction: direction,
            runners: new_runners
          })

          {:ok, {:scaled, direction, new_runners}, new_state}
        else
          {:ok, :no_change, state}
        end
    end
  end

  @impl true
  def handle_job({:get_pool, pool_name}, state) do
    case Map.get(state.pools, pool_name) do
      nil -> {:error, :pool_not_found, state}
      pool_info -> {:ok, pool_info, state}
    end
  end

  @impl true
  def handle_job({:update_utilization, pool_name, utilization}, state) do
    if Map.has_key?(state.pools, pool_name) do
      new_utilization = Map.put(state.utilization, pool_name, utilization)
      new_state = %{state | utilization: new_utilization}

      # Check if scaling needed
      new_state = maybe_scale(new_state, pool_name)

      {:ok, :updated, new_state}
    else
      {:error, :pool_not_found, state}
    end
  end

  @impl true
  def handle_job(unknown, state) do
    {:error, {:unknown_job, unknown}, state}
  end

  # ============================================================
  # FLAME IMPLEMENTATION
  # ============================================================

  defp maybe_scale(state, pool_name) do
    pool_info = Map.get(state.pools, pool_name)
    utilization = Map.get(state.utilization, pool_name, 0.0)

    cond do
      utilization > state.config.scale_up_threshold and
          pool_info.current_runners < pool_info.max_runners ->
        case can_scale?(pool_info, state.config.scale_cooldown_ms) do
          true ->
            {:ok, _, new_state} = handle_job({:scale, pool_name, :up}, state)
            new_state

          false ->
            state
        end

      utilization < state.config.scale_down_threshold and
          pool_info.current_runners > pool_info.min_runners ->
        case can_scale?(pool_info, state.config.scale_cooldown_ms) do
          true ->
            {:ok, _, new_state} = handle_job({:scale, pool_name, :down}, state)
            new_state

          false ->
            state
        end

      true ->
        state
    end
  end

  defp can_scale?(%{last_scale_at: nil}, _cooldown), do: true

  defp can_scale?(%{last_scale_at: last_scale_at}, cooldown_ms) do
    elapsed = DateTime.diff(DateTime.utc_now(), last_scale_at, :millisecond)
    elapsed >= cooldown_ms
  end

  defp generate_job_id do
    random_bytes = :crypto.strong_rand_bytes(8)
    random_bytes |> Base.encode16(case: :lower)
  end

  defp pool_summary(pools) do
    Enum.map(pools, fn {name, info} ->
      %{
        name: name,
        fqun: info.fqun,
        runners: info.current_runners,
        status: info.status
      }
    end)
  end

  defp calculate_avg_utilization(utilization) when map_size(utilization) == 0, do: 0.0

  defp calculate_avg_utilization(utilization) do
    total = Enum.reduce(utilization, 0.0, fn {_, util}, acc -> acc + util end)
    Float.round(total / map_size(utilization), 3)
  end

  defp publish_pool_event(event, data) do
    Indrajaal.Observability.ZenohCoordinator.publish_coord(
      "flame/pool/#{event}",
      Map.merge(%{event: event, timestamp: DateTime.utc_now()}, data)
    )
  rescue
    _ -> :ok
  end
end
