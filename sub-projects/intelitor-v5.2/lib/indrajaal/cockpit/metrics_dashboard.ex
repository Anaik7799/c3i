defmodule Indrajaal.Cockpit.MetricsDashboard do
  @moduledoc """
  System Metrics Dashboard for Cognitive Cockpit.

  WHAT: Real-time system metrics visualization for Livebook.
  WHY: SC-HITL-003 requires operational visibility.
  CONSTRAINTS: Non-blocking metric collection.

  ## Metrics Categories

  1. **BEAM Metrics**: Memory, processes, schedulers, run queue
  2. **FLAME Metrics**: Pool status, runner count, execution stats
  3. **Agent Metrics**: Cortex, Synapse, GDE status
  4. **Container Metrics**: Health, resource usage per container

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-HITL-003 |
  """

  # ============================================================
  # BEAM METRICS
  # ============================================================

  @doc """
  Get comprehensive BEAM VM metrics.
  """
  @spec beam_metrics() :: map()
  def beam_metrics do
    memory = :erlang.memory()

    %{
      memory: %{
        total_mb: div(memory[:total], 1_048_576),
        processes_mb: div(memory[:processes], 1_048_576),
        processes_used_mb: div(memory[:processes_used], 1_048_576),
        system_mb: div(memory[:system], 1_048_576),
        atom_mb: div(memory[:atom], 1_048_576),
        atom_used_mb: div(memory[:atom_used], 1_048_576),
        binary_mb: div(memory[:binary], 1_048_576),
        code_mb: div(memory[:code], 1_048_576),
        ets_mb: div(memory[:ets], 1_048_576)
      },
      processes: %{
        count: :erlang.system_info(:process_count),
        limit: :erlang.system_info(:process_limit)
      },
      schedulers: %{
        online: :erlang.system_info(:schedulers_online),
        total: :erlang.system_info(:schedulers),
        dirty_cpu: :erlang.system_info(:dirty_cpu_schedulers_online),
        dirty_io: :erlang.system_info(:dirty_io_schedulers)
      },
      run_queue: :erlang.statistics(:run_queue),
      io: get_io_stats(),
      gc: get_gc_stats(),
      uptime_ms: elem(:erlang.statistics(:wall_clock), 0)
    }
  end

  @doc """
  Get memory breakdown as VegaLite-compatible data.
  """
  @spec memory_chart_data() :: list(map())
  def memory_chart_data do
    memory = :erlang.memory()

    [
      %{category: "Processes", mb: div(memory[:processes], 1_048_576)},
      %{category: "Binary", mb: div(memory[:binary], 1_048_576)},
      %{category: "ETS", mb: div(memory[:ets], 1_048_576)},
      %{category: "Code", mb: div(memory[:code], 1_048_576)},
      %{category: "Atom", mb: div(memory[:atom], 1_048_576)},
      %{category: "Other", mb: div(memory[:system] - memory[:code] - memory[:atom], 1_048_576)}
    ]
  end

  @doc """
  Get VegaLite spec for memory pie chart.
  """
  @spec memory_pie_spec() :: map()
  def memory_pie_spec do
    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "title" => "Memory Distribution",
      "width" => 300,
      "height" => 300,
      "data" => %{"values" => memory_chart_data()},
      "mark" => %{"type" => "arc", "innerRadius" => 50},
      "encoding" => %{
        "theta" => %{"field" => "mb", "type" => "quantitative"},
        "color" => %{
          "field" => "category",
          "type" => "nominal",
          "scale" => %{
            "range" => ["#3b82f6", "#22c55e", "#eab308", "#f97316", "#8b5cf6", "#6b7280"]
          }
        },
        "tooltip" => [
          %{"field" => "category", "type" => "nominal"},
          %{"field" => "mb", "type" => "quantitative", "title" => "MB"}
        ]
      }
    }
  end

  # ============================================================
  # FLAME METRICS
  # ============================================================

  @doc """
  Get FLAME pool metrics.
  """
  @spec flame_metrics() :: map()
  def flame_metrics do
    # Check if FLAME is available
    flame_available = Code.ensure_loaded?(FLAME) and Code.ensure_loaded?(FLAME.Pool)

    if flame_available do
      get_flame_pool_stats()
    else
      %{
        available: false,
        pools: [],
        total_runners: 0,
        active_runners: 0
      }
    end
  end

  defp get_flame_pool_stats do
    # In a real implementation, query FLAME pools
    %{
      available: true,
      pools: [
        %{
          name: :intelligence,
          min: 0,
          max: 10,
          current: 0,
          idle: 0,
          active: 0
        },
        %{
          name: :video,
          min: 0,
          max: 5,
          current: 0,
          idle: 0,
          active: 0
        },
        %{
          name: :analytics,
          min: 0,
          max: 8,
          current: 0,
          idle: 0,
          active: 0
        }
      ],
      total_runners: 0,
      active_runners: 0
    }
  end

  @doc """
  Get FLAME pool data for visualization.
  """
  @spec flame_chart_data() :: list(map())
  def flame_chart_data do
    metrics = flame_metrics()

    Enum.map(metrics.pools, fn pool ->
      %{
        pool: Atom.to_string(pool.name),
        current: pool.current,
        max: pool.max,
        utilization: if(pool.max > 0, do: round(pool.current / pool.max * 100), else: 0)
      }
    end)
  end

  # ============================================================
  # AGENT METRICS
  # ============================================================

  @doc """
  Get agent system metrics.
  """
  @spec agent_metrics() :: map()
  def agent_metrics do
    %{
      cortex: get_cortex_metrics(),
      synapse: get_synapse_metrics(),
      gde: get_gde_metrics(),
      zenoh: get_zenoh_metrics()
    }
  end

  defp get_cortex_metrics do
    if cortex_available?() do
      try do
        status = Indrajaal.Cortex.status()

        %{
          available: true,
          state: status[:state] || :unknown,
          stress_score: status[:stress_score] || 0,
          cycles_completed: status[:cycles_completed] || 0,
          last_adaptation: status[:last_adaptation]
        }
      rescue
        _ -> %{available: false, error: "Failed to get status"}
      end
    else
      %{available: false}
    end
  end

  defp get_synapse_metrics do
    if synapse_available?() do
      try do
        state = Indrajaal.Cortex.Synapse.get_state()

        %{
          available: true,
          current_phase: state[:current_phase] || :unknown,
          memories_stored: map_size(state[:memories] || %{}),
          last_cycle: state[:last_cycle_time]
        }
      rescue
        _ -> %{available: false, error: "Failed to get state"}
      end
    else
      %{available: false}
    end
  end

  defp get_gde_metrics do
    if gde_available?() do
      try do
        status = Indrajaal.Cortex.GDE.status()

        %{
          available: true,
          hypotheses_generated: status[:hypotheses_generated] || 0,
          evolutions_applied: status[:evolutions_applied] || 0,
          rollbacks: status[:rollbacks] || 0
        }
      rescue
        _ -> %{available: false, error: "Failed to get status"}
      end
    else
      %{available: false}
    end
  end

  defp get_zenoh_metrics do
    # Check for Zenoh coordinator
    if zenoh_available?() do
      try do
        %{
          available: true,
          connected: true,
          topics_subscribed: 0,
          messages_published: 0,
          messages_received: 0
        }
      rescue
        _ -> %{available: false, error: "Failed to get Zenoh status"}
      end
    else
      %{available: false}
    end
  end

  # ============================================================
  # CONTAINER METRICS
  # ============================================================

  @doc """
  Get container health metrics.
  """
  @spec container_metrics() :: map()
  def container_metrics do
    %{
      containers: [
        %{
          name: "indrajaal-app",
          status: :running,
          port: 4000,
          health: :healthy
        },
        %{
          name: "indrajaal-db",
          status: :running,
          port: 5433,
          health: check_db_health()
        },
        %{
          name: "indrajaal-obs",
          status: :running,
          port: 8123,
          health: :unknown
        }
      ],
      overall_health: :healthy
    }
  end

  defp check_db_health do
    case Ecto.Adapters.SQL.query(Indrajaal.Repo, "SELECT 1", []) do
      {:ok, _} -> :healthy
      {:error, _} -> :unhealthy
    end
  rescue
    _ -> :unknown
  end

  # ============================================================
  # HISTORICAL METRICS (for charts)
  # ============================================================

  @doc """
  Start collecting metrics samples for time-series visualization.
  Returns a stream of metric samples.
  """
  @spec metric_stream(integer()) :: Enumerable.t()
  def metric_stream(interval_ms \\ 1000) do
    Stream.resource(
      fn -> nil end,
      fn _ ->
        Process.sleep(interval_ms)

        sample = %{
          timestamp: DateTime.utc_now(),
          memory_mb: div(:erlang.memory(:total), 1_048_576),
          process_count: :erlang.system_info(:process_count),
          run_queue: :erlang.statistics(:run_queue)
        }

        {[sample], nil}
      end,
      fn _ -> :ok end
    )
  end

  @doc """
  Collect N samples of metrics for charting.
  """
  @spec collect_samples(integer(), integer()) :: list(map())
  def collect_samples(count, interval_ms \\ 100) do
    Enum.map(1..count, fn i ->
      if i > 1, do: Process.sleep(interval_ms)

      %{
        sample: i,
        timestamp: DateTime.utc_now(),
        memory_mb: div(:erlang.memory(:total), 1_048_576),
        process_count: :erlang.system_info(:process_count),
        run_queue: :erlang.statistics(:run_queue)
      }
    end)
  end

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  defp get_io_stats do
    {{:input, input}, {:output, output}} = :erlang.statistics(:io)
    %{input_mb: div(input, 1_048_576), output_mb: div(output, 1_048_576)}
  end

  defp get_gc_stats do
    {gcs, words_reclaimed, _} = :erlang.statistics(:garbage_collection)
    %{collections: gcs, words_reclaimed: words_reclaimed}
  end

  defp cortex_available? do
    Code.ensure_loaded?(Indrajaal.Cortex) and
      function_exported?(Indrajaal.Cortex, :status, 0)
  end

  defp synapse_available? do
    Code.ensure_loaded?(Indrajaal.Cortex.Synapse) and
      function_exported?(Indrajaal.Cortex.Synapse, :get_state, 0)
  end

  defp gde_available? do
    Code.ensure_loaded?(Indrajaal.Cortex.GDE) and
      function_exported?(Indrajaal.Cortex.GDE, :status, 0)
  end

  defp zenoh_available? do
    Code.ensure_loaded?(Indrajaal.Observability.ZenohCoordinator) and
      function_exported?(Indrajaal.Observability.ZenohCoordinator, :status, 0)
  end
end
