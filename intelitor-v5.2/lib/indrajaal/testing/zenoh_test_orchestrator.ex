defmodule Indrajaal.Testing.ZenohTestOrchestrator do
  @moduledoc """
  Central orchestrator for real-time test aggregation via Zenoh.

  ## STAMP Constraints
  - SC-ZTEST-005: Orchestrator aggregate update < 100ms
  - SC-ZTEST-008: No log parsing for test results
  - SC-ZTEST-001: All checkpoints have unique topics

  ## Architecture

  ```
  ExUnit Formatter ─────┐
                        │
  F# Smoke Tests ───────┼──────▶ ZenohTestOrchestrator ──────▶ Phoenix.PubSub
                        │               │                        zenoh:orchestrator
  Boot Publishers ──────┘               │
                                        ▼
                                   Dashboard
  ```

  ## Topics Subscribed
  - `indrajaal/test/**` - ExUnit test events
  - `indrajaal/smoke/**` - F# smoke test events
  - `indrajaal/boot/**` - Boot phase events
  - `indrajaal/sprint/**` - Sprint task lifecycle events

  ## Topics Published
  - `indrajaal/orchestrator/aggregate` - Aggregated statistics
  - `indrajaal/orchestrator/status` - Current status
  - `indrajaal/orchestrator/alerts` - Alerts on failures

  ## Usage
  ```elixir
  # Start orchestrator
  ZenohTestOrchestrator.start_link()

  # Get current stats
  ZenohTestOrchestrator.get_stats()

  # Subscribe to updates
  ZenohLiveViewBridge.subscribe(:orchestrator)
  ```
  """

  use GenServer
  require Logger

  alias Indrajaal.Testing.CheckpointMessages
  alias Phoenix.PubSub

  @pubsub Indrajaal.PubSub
  @aggregate_interval_ms 500
  @alert_threshold_failures 5

  # ============================================================
  # STATE
  # ============================================================

  defstruct [
    :started_at,
    :last_update,
    # ExUnit test stats
    test_suites: %{},
    test_total: 0,
    test_passed: 0,
    test_failed: 0,
    test_skipped: 0,
    test_running: 0,
    # Smoke test stats
    smoke_batches: %{},
    smoke_total: 0,
    smoke_passed: 0,
    smoke_failed: 0,
    # Boot phase stats
    boot_phases: %{},
    boot_started: false,
    boot_complete: false,
    boot_duration_ms: 0,
    # Quorum and state vector
    quorum_status: "Unknown",
    state_vector: "[0,0,0,0,0,0]",
    # Sprint task stats
    sprint_tasks: %{},
    sprint_waves: %{},
    sprint_completed: 0,
    sprint_failed: 0,
    sprint_gates_passed: 0,
    # F# agent stats (Phase 6: CP-AGENT-01..05)
    agent_runs: %{},
    agent_total: 0,
    agent_passed: 0,
    agent_failed: 0,
    agent_last_pass_rate: nil,
    # Failure tracking
    recent_failures: [],
    # Zenoh session ref
    zenoh_enabled: false
  ]

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc "Start the orchestrator GenServer."
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Get current aggregated statistics."
  @spec get_stats(GenServer.server()) :: map()
  def get_stats(server \\ __MODULE__) do
    GenServer.call(server, :get_stats)
  end

  @doc "Get pass rate as percentage."
  @spec get_pass_rate(GenServer.server()) :: float()
  def get_pass_rate(server \\ __MODULE__) do
    stats = get_stats(server)
    total = stats.test_total + stats.smoke_total

    if total > 0 do
      passed = stats.test_passed + stats.smoke_passed
      Float.round(passed / total * 100, 2)
    else
      0.0
    end
  end

  @doc "Get recent failures."
  @spec get_failures(GenServer.server()) :: list()
  def get_failures(server \\ __MODULE__) do
    GenServer.call(server, :get_failures)
  end

  @doc "Reset all statistics."
  @spec reset(GenServer.server()) :: :ok
  def reset(server \\ __MODULE__) do
    GenServer.cast(server, :reset)
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    Logger.info("[ZenohTestOrchestrator] Starting orchestrator - SC-ZTEST-005")

    state = %__MODULE__{
      started_at: DateTime.utc_now(),
      last_update: DateTime.utc_now(),
      zenoh_enabled: zenoh_available?()
    }

    # Subscribe to Zenoh topics via telemetry
    setup_subscriptions()

    # Schedule periodic aggregate publishing
    Process.send_after(self(), :publish_aggregate, @aggregate_interval_ms)

    {:ok, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      # Test stats
      test_total: state.test_total,
      test_passed: state.test_passed,
      test_failed: state.test_failed,
      test_skipped: state.test_skipped,
      test_running: state.test_running,
      test_suites: map_size(state.test_suites),
      # Smoke stats
      smoke_total: state.smoke_total,
      smoke_passed: state.smoke_passed,
      smoke_failed: state.smoke_failed,
      smoke_batches: map_size(state.smoke_batches),
      # Boot stats
      boot_started: state.boot_started,
      boot_complete: state.boot_complete,
      boot_duration_ms: state.boot_duration_ms,
      boot_phases: map_size(state.boot_phases),
      # Mesh stats
      quorum_status: state.quorum_status,
      state_vector: state.state_vector,
      # Sprint stats
      sprint_total: map_size(state.sprint_tasks),
      sprint_completed: state.sprint_completed,
      sprint_failed: state.sprint_failed,
      sprint_gates_passed: state.sprint_gates_passed,
      sprint_waves_evaluated: map_size(state.sprint_waves),
      # F# agent stats
      agent_total: state.agent_total,
      agent_passed: state.agent_passed,
      agent_failed: state.agent_failed,
      agent_runs: map_size(state.agent_runs),
      agent_last_pass_rate: state.agent_last_pass_rate,
      # Calculated
      pass_rate: calculate_pass_rate(state),
      total_tests: state.test_total + state.smoke_total,
      total_passed: state.test_passed + state.smoke_passed,
      total_failed: state.test_failed + state.smoke_failed,
      # Failure tracking
      recent_failures_count: length(state.recent_failures),
      # Meta
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
      last_update: state.last_update
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:get_failures, _from, state) do
    {:reply, state.recent_failures, state}
  end

  @impl true
  def handle_cast(:reset, state) do
    new_state = %__MODULE__{
      started_at: DateTime.utc_now(),
      last_update: DateTime.utc_now(),
      zenoh_enabled: state.zenoh_enabled
    }

    {:noreply, new_state}
  end

  # ============================================================
  # TEST EVENTS
  # ============================================================

  @impl true
  def handle_info({:test_suite_started, suite_id, data}, state) do
    new_suites =
      Map.put(state.test_suites, suite_id, %{
        started_at: DateTime.utc_now(),
        test_count: Map.get(data, :test_count, 0),
        status: :running
      })

    {:noreply, %{state | test_suites: new_suites, last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:test_suite_finished, suite_id, data}, state) do
    new_suites =
      Map.update(state.test_suites, suite_id, %{}, fn suite ->
        Map.merge(suite, %{
          finished_at: DateTime.utc_now(),
          status: :completed,
          duration_ms: Map.get(data, :duration_ms, 0),
          total: Map.get(data, :total, 0),
          passed: Map.get(data, :passed, 0),
          failed: Map.get(data, :failed, 0)
        })
      end)

    {:noreply, %{state | test_suites: new_suites, last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:test_started, _test_id, _data}, state) do
    {:noreply, %{state | test_running: state.test_running + 1, last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:test_passed, _test_id, _data}, state) do
    new_state = %{
      state
      | test_total: state.test_total + 1,
        test_passed: state.test_passed + 1,
        test_running: max(0, state.test_running - 1),
        last_update: DateTime.utc_now()
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:test_failed, test_id, data}, state) do
    failure = %{
      type: :test,
      id: test_id,
      failure: Map.get(data, :failure, %{}),
      timestamp: DateTime.utc_now()
    }

    recent_failures = Enum.take([failure | state.recent_failures], 50)

    new_state = %{
      state
      | test_total: state.test_total + 1,
        test_failed: state.test_failed + 1,
        test_running: max(0, state.test_running - 1),
        recent_failures: recent_failures,
        last_update: DateTime.utc_now()
    }

    # Check if we need to raise an alert
    if new_state.test_failed >= @alert_threshold_failures do
      publish_alert(new_state, "Test failures exceeded threshold: #{new_state.test_failed}")
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:test_skipped, _test_id, _data}, state) do
    new_state = %{
      state
      | test_total: state.test_total + 1,
        test_skipped: state.test_skipped + 1,
        test_running: max(0, state.test_running - 1),
        last_update: DateTime.utc_now()
    }

    {:noreply, new_state}
  end

  # ============================================================
  # SMOKE TEST EVENTS
  # ============================================================

  @impl true
  def handle_info({:smoke_batch_started, batch_id, data}, state) do
    new_batches =
      Map.put(state.smoke_batches, batch_id, %{
        started_at: DateTime.utc_now(),
        node_id: Map.get(data, :node_id),
        status: :running
      })

    {:noreply, %{state | smoke_batches: new_batches, last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:smoke_batch_finished, batch_id, data}, state) do
    new_batches =
      Map.update(state.smoke_batches, batch_id, %{}, fn batch ->
        Map.merge(batch, %{
          finished_at: DateTime.utc_now(),
          status: :completed,
          duration_ms: Map.get(data, :duration_ms, 0),
          tests_run: Map.get(data, :tests_run, 0),
          passed: Map.get(data, :tests_passed, 0),
          failed: Map.get(data, :tests_failed, 0)
        })
      end)

    {:noreply, %{state | smoke_batches: new_batches, last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:smoke_result, test_id, data}, state) do
    status = Map.get(data, :status, "Unknown")

    {passed_delta, failed_delta} =
      case status do
        "Passed" -> {1, 0}
        "Failed" -> {0, 1}
        _ -> {0, 0}
      end

    new_state = %{
      state
      | smoke_total: state.smoke_total + 1,
        smoke_passed: state.smoke_passed + passed_delta,
        smoke_failed: state.smoke_failed + failed_delta,
        last_update: DateTime.utc_now()
    }

    # Track failure details
    new_state =
      if status == "Failed" do
        failure = %{
          type: :smoke,
          id: test_id,
          failure: Map.get(data, :failure, %{}),
          timestamp: DateTime.utc_now()
        }

        %{new_state | recent_failures: Enum.take([failure | new_state.recent_failures], 50)}
      else
        new_state
      end

    {:noreply, new_state}
  end

  # ============================================================
  # BOOT EVENTS
  # ============================================================

  @impl true
  def handle_info({:boot_phase_started, phase, data}, state) do
    new_phases =
      Map.put(state.boot_phases, phase, %{
        started_at: DateTime.utc_now(),
        wave: Map.get(data, :wave, 0),
        status: :running
      })

    new_state = %{
      state
      | boot_phases: new_phases,
        boot_started: true,
        state_vector: Map.get(data, :state_vector, state.state_vector),
        last_update: DateTime.utc_now()
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:boot_phase_finished, phase, data}, state) do
    new_phases =
      Map.update(state.boot_phases, phase, %{}, fn phase_data ->
        Map.merge(phase_data, %{
          finished_at: DateTime.utc_now(),
          status: if(Map.get(data, :success, true), do: :completed, else: :failed),
          duration_ms: Map.get(data, :duration_ms, 0)
        })
      end)

    boot_complete = Map.get(data, :checkpoint) == "CP-BOOT-10"

    boot_duration =
      if boot_complete, do: Map.get(data, :total_duration_ms, 0), else: state.boot_duration_ms

    new_state = %{
      state
      | boot_phases: new_phases,
        boot_complete: boot_complete,
        boot_duration_ms: boot_duration,
        state_vector: Map.get(data, :state_vector, state.state_vector),
        last_update: DateTime.utc_now()
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:quorum_update, data}, state) do
    quorum_status = Map.get(data, :status, "Unknown")

    new_state = %{state | quorum_status: quorum_status, last_update: DateTime.utc_now()}

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:state_vector_update, data}, state) do
    {:noreply,
     %{
       state
       | state_vector: Map.get(data, :vector, state.state_vector),
         last_update: DateTime.utc_now()
     }}
  end

  # ============================================================
  # SPRINT TASK EVENTS
  # ============================================================

  @impl true
  def handle_info({:sprint_task_started, task_id, data}, state) do
    new_tasks =
      Map.put(state.sprint_tasks, task_id, %{
        started_at: DateTime.utc_now(),
        state_vector: Map.get(data, :state_vector, "[0,0,0,0,0,0]"),
        wave: Map.get(data, :wave, 0),
        priority: Map.get(data, :priority, "p1"),
        status: :running,
        progress_pct: 0
      })

    {:noreply, %{state | sprint_tasks: new_tasks, last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:sprint_task_progress, task_id, data}, state) do
    new_tasks =
      Map.update(state.sprint_tasks, task_id, %{}, fn task ->
        Map.merge(task, %{
          state_vector: Map.get(data, :state_vector, task[:state_vector]),
          progress_pct: Map.get(data, :progress_pct, task[:progress_pct])
        })
      end)

    {:noreply, %{state | sprint_tasks: new_tasks, last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:sprint_task_completed, task_id, data}, state) do
    new_tasks =
      Map.update(state.sprint_tasks, task_id, %{}, fn task ->
        Map.merge(task, %{
          finished_at: DateTime.utc_now(),
          status: :completed,
          state_vector: "[1,1,1,1,1,1]",
          progress_pct: 100,
          duration_ms: Map.get(data, :duration_ms, 0)
        })
      end)

    new_state = %{
      state
      | sprint_tasks: new_tasks,
        sprint_completed: state.sprint_completed + 1,
        last_update: DateTime.utc_now()
    }

    broadcast_to_pubsub(:sprint, %{type: :task_completed, task_id: task_id})

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:sprint_task_failed, task_id, data}, state) do
    failure = %{
      type: :sprint,
      id: task_id,
      failure: Map.get(data, :reason, "Unknown"),
      timestamp: DateTime.utc_now()
    }

    new_tasks =
      Map.update(state.sprint_tasks, task_id, %{}, fn task ->
        Map.merge(task, %{
          finished_at: DateTime.utc_now(),
          status: :failed,
          reason: Map.get(data, :reason, "Unknown")
        })
      end)

    new_state = %{
      state
      | sprint_tasks: new_tasks,
        sprint_failed: state.sprint_failed + 1,
        recent_failures: Enum.take([failure | state.recent_failures], 50),
        last_update: DateTime.utc_now()
    }

    publish_alert(new_state, "Sprint task failed: #{task_id}")

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:sprint_wave_gate, wave_id, data}, state) do
    gate_passed = Map.get(data, :gate_passed, false)

    new_waves =
      Map.put(state.sprint_waves, wave_id, %{
        gate_passed: gate_passed,
        results: Map.get(data, :gate_results, %{}),
        evaluated_at: DateTime.utc_now()
      })

    gates_passed =
      if gate_passed, do: state.sprint_gates_passed + 1, else: state.sprint_gates_passed

    new_state = %{
      state
      | sprint_waves: new_waves,
        sprint_gates_passed: gates_passed,
        last_update: DateTime.utc_now()
    }

    unless gate_passed do
      publish_alert(new_state, "Jidoka gate failed: Wave #{wave_id}")
    end

    broadcast_to_pubsub(:sprint, %{type: :wave_gate, wave: wave_id, passed: gate_passed})

    {:noreply, new_state}
  end

  # ============================================================
  # F# AGENT EVENTS (Phase 6: CP-AGENT-01..05)
  # ============================================================

  @impl true
  def handle_info({:agent_started, run_id, data}, state) do
    new_runs =
      Map.put(state.agent_runs, run_id, %{
        started_at: DateTime.utc_now(),
        levels: Map.get(data, :levels, []),
        status: :running
      })

    {:noreply, %{state | agent_runs: new_runs, last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:agent_running, run_id, data}, state) do
    new_runs =
      Map.update(state.agent_runs, run_id, %{}, fn run ->
        Map.merge(run, %{
          progress: Map.get(data, :progress, 0),
          current_level: Map.get(data, :current_level)
        })
      end)

    {:noreply, %{state | agent_runs: new_runs, last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:agent_done, run_id, data}, state) do
    pass_rate = Map.get(data, :pass_rate, 0.0)
    total = Map.get(data, :total, 0)
    passed = Map.get(data, :passed, 0)
    failed = Map.get(data, :failed, total - passed)

    new_runs =
      Map.update(state.agent_runs, run_id, %{}, fn run ->
        Map.merge(run, %{
          finished_at: DateTime.utc_now(),
          status: :completed,
          pass_rate: pass_rate,
          total: total,
          passed: passed,
          failed: failed
        })
      end)

    new_state = %{
      state
      | agent_runs: new_runs,
        agent_total: state.agent_total + total,
        agent_passed: state.agent_passed + passed,
        agent_failed: state.agent_failed + failed,
        agent_last_pass_rate: pass_rate,
        last_update: DateTime.utc_now()
    }

    broadcast_to_pubsub(:agent, %{type: :agent_done, run_id: run_id, pass_rate: pass_rate})

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:agent_stopped, run_id, _data}, state) do
    new_runs =
      Map.update(state.agent_runs, run_id, %{}, fn run ->
        Map.put(run, :status, :stopped)
      end)

    {:noreply, %{state | agent_runs: new_runs, last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:agent_error, run_id, data}, state) do
    failure = %{
      type: :agent,
      id: run_id,
      failure: Map.get(data, :error, "Unknown agent error"),
      timestamp: DateTime.utc_now()
    }

    new_runs =
      Map.update(state.agent_runs, run_id, %{}, fn run ->
        Map.merge(run, %{status: :error, error: Map.get(data, :error)})
      end)

    new_state = %{
      state
      | agent_runs: new_runs,
        recent_failures: Enum.take([failure | state.recent_failures], 50),
        last_update: DateTime.utc_now()
    }

    publish_alert(new_state, "F# agent error: #{run_id}")

    {:noreply, new_state}
  end

  # ============================================================
  # PERIODIC AGGREGATE
  # ============================================================

  @impl true
  def handle_info(:publish_aggregate, state) do
    # Schedule next aggregate
    Process.send_after(self(), :publish_aggregate, @aggregate_interval_ms)

    # Publish aggregate to Zenoh and PubSub
    stats = build_aggregate(state)
    publish_aggregate(state, stats)

    # Broadcast to Phoenix.PubSub for LiveView
    broadcast_to_pubsub(:orchestrator, stats)

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  defp setup_subscriptions do
    # Attach to telemetry events
    events = [
      [:indrajaal, :test, :suite, :started],
      [:indrajaal, :test, :suite, :finished],
      [:indrajaal, :test, :case, :started],
      [:indrajaal, :test, :case, :passed],
      [:indrajaal, :test, :case, :failed],
      [:indrajaal, :test, :case, :skipped],
      [:indrajaal, :smoke, :batch, :started],
      [:indrajaal, :smoke, :batch, :finished],
      [:indrajaal, :smoke, :result, :published],
      [:indrajaal, :boot, :phase, :started],
      [:indrajaal, :boot, :phase, :finished],
      [:indrajaal, :boot, :quorum, :update],
      [:indrajaal, :boot, :state_vector, :update],
      # Sprint task events
      [:indrajaal, :sprint, :task, :task_started],
      [:indrajaal, :sprint, :task, :task_progress],
      [:indrajaal, :sprint, :task, :task_completed],
      [:indrajaal, :sprint, :task, :task_failed],
      [:indrajaal, :sprint, :task, :wave_gate],
      # F# agent events (Phase 6: CP-AGENT-01..05)
      [:indrajaal, :agent, :started],
      [:indrajaal, :agent, :running],
      [:indrajaal, :agent, :done],
      [:indrajaal, :agent, :stopped],
      [:indrajaal, :agent, :error]
    ]

    :telemetry.attach_many(
      "zenoh-test-orchestrator",
      events,
      &handle_telemetry_event/4,
      %{orchestrator_pid: self()}
    )

    Logger.debug("[ZenohTestOrchestrator] Subscribed to #{length(events)} telemetry events")
  end

  defp handle_telemetry_event(event_name, measurements, metadata, %{orchestrator_pid: pid}) do
    message = translate_event(event_name, measurements, metadata)
    send(pid, message)
  end

  # SC-OTEL-MATH-009: Extract W3C trace context from checkpoint messages
  # Restores distributed trace continuity when messages cross runtime boundaries
  defp maybe_extract_trace_context(data) do
    case Map.get(data, :trace_context) do
      nil ->
        :ok

      ctx when is_map(ctx) ->
        try do
          Indrajaal.Cluster.Zenoh.TracePropagator.extract(ctx)
        rescue
          _ -> :ok
        end

      _ ->
        :ok
    end
  end

  defp translate_event(event_name, measurements, metadata) do
    data = Map.merge(measurements, metadata)
    maybe_extract_trace_context(data)

    case event_name do
      [:indrajaal, :test, :suite, :started] ->
        {:test_suite_started, Map.get(data, :suite_id), data}

      [:indrajaal, :test, :suite, :finished] ->
        {:test_suite_finished, Map.get(data, :suite_id), data}

      [:indrajaal, :test, :case, :started] ->
        {:test_started, Map.get(data, :test_id), data}

      [:indrajaal, :test, :case, :passed] ->
        {:test_passed, Map.get(data, :test_id), data}

      [:indrajaal, :test, :case, :failed] ->
        {:test_failed, Map.get(data, :test_id), data}

      [:indrajaal, :test, :case, :skipped] ->
        {:test_skipped, Map.get(data, :test_id), data}

      [:indrajaal, :smoke, :batch, :started] ->
        {:smoke_batch_started, Map.get(data, :batch_id), data}

      [:indrajaal, :smoke, :batch, :finished] ->
        {:smoke_batch_finished, Map.get(data, :batch_id), data}

      [:indrajaal, :smoke, :result, :published] ->
        {:smoke_result, Map.get(data, :test_id), data}

      [:indrajaal, :boot, :phase, :started] ->
        {:boot_phase_started, Map.get(data, :phase), data}

      [:indrajaal, :boot, :phase, :finished] ->
        {:boot_phase_finished, Map.get(data, :phase), data}

      [:indrajaal, :boot, :quorum, :update] ->
        {:quorum_update, data}

      [:indrajaal, :boot, :state_vector, :update] ->
        {:state_vector_update, data}

      # Sprint task events
      [:indrajaal, :sprint, :task, :task_started] ->
        {:sprint_task_started, Map.get(data, :task_id, Map.get(data, :id)), data}

      [:indrajaal, :sprint, :task, :task_progress] ->
        {:sprint_task_progress, Map.get(data, :task_id, Map.get(data, :id)), data}

      [:indrajaal, :sprint, :task, :task_completed] ->
        {:sprint_task_completed, Map.get(data, :task_id, Map.get(data, :id)), data}

      [:indrajaal, :sprint, :task, :task_failed] ->
        {:sprint_task_failed, Map.get(data, :task_id, Map.get(data, :id)), data}

      [:indrajaal, :sprint, :task, :wave_gate] ->
        {:sprint_wave_gate, Map.get(data, :wave, Map.get(data, :id)), data}

      # F# agent events (Phase 6: CP-AGENT-01..05)
      [:indrajaal, :agent, :started] ->
        {:agent_started, Map.get(data, :run_id, Map.get(data, :id)), data}

      [:indrajaal, :agent, :running] ->
        {:agent_running, Map.get(data, :run_id, Map.get(data, :id)), data}

      [:indrajaal, :agent, :done] ->
        {:agent_done, Map.get(data, :run_id, Map.get(data, :id)), data}

      [:indrajaal, :agent, :stopped] ->
        {:agent_stopped, Map.get(data, :run_id, Map.get(data, :id)), data}

      [:indrajaal, :agent, :error] ->
        {:agent_error, Map.get(data, :run_id, Map.get(data, :id)), data}

      _ ->
        {:unknown_event, event_name, data}
    end
  end

  defp calculate_pass_rate(state) do
    total = state.test_total + state.smoke_total

    if total > 0 do
      passed = state.test_passed + state.smoke_passed
      Float.round(passed / total * 100, 2)
    else
      0.0
    end
  end

  defp build_aggregate(state) do
    CheckpointMessages.build_aggregate(%{
      total: state.test_total + state.smoke_total,
      passed: state.test_passed + state.smoke_passed,
      failed: state.test_failed + state.smoke_failed,
      skipped: state.test_skipped,
      running: state.test_running,
      pass_rate: calculate_pass_rate(state),
      agent_total: state.agent_total,
      agent_passed: state.agent_passed,
      agent_failed: state.agent_failed,
      duration_ms: DateTime.diff(DateTime.utc_now(), state.started_at, :millisecond)
    })
  end

  defp publish_aggregate(state, stats) do
    if state.zenoh_enabled do
      Task.start(fn ->
        try do
          payload = Jason.encode!(stats)
          do_publish("indrajaal/orchestrator/aggregate", payload)
        rescue
          e -> Logger.debug("[ZenohTestOrchestrator] Publish failed: #{inspect(e)}")
        end
      end)
    end
  end

  defp publish_alert(state, message) do
    if state.zenoh_enabled do
      alert =
        CheckpointMessages.build_alert("warning", message, %{
          test_failed: state.test_failed,
          smoke_failed: state.smoke_failed
        })

      Task.start(fn ->
        try do
          payload = Jason.encode!(alert)
          do_publish("indrajaal/orchestrator/alerts", payload)
        catch
          kind, reason ->
            Logger.debug(
              "[ZenohTestOrchestrator] Alert publish failed: #{kind} #{inspect(reason)}"
            )
        end
      end)
    end

    # Also broadcast to PubSub
    broadcast_to_pubsub(:orchestrator, %{type: :alert, message: message})
  end

  defp do_publish(topic, payload) do
    case Code.ensure_loaded(Indrajaal.Observability.ZenohSession) do
      {:module, mod} ->
        mod.publish(topic, payload)

      _ ->
        Logger.debug("[ZenohTestOrchestrator] ZenohSession not available, topic: #{topic}")
    end
  end

  defp broadcast_to_pubsub(topic, data) when is_atom(topic) do
    message = {:zenoh_update, topic, enrich_message(data)}

    try do
      PubSub.broadcast(@pubsub, "zenoh:#{topic}", message)
    catch
      kind, reason ->
        Logger.debug(
          "[ZenohTestOrchestrator] PubSub broadcast failed: #{kind} #{inspect(reason)}"
        )

        :ok
    end
  end

  defp enrich_message(data) when is_map(data) do
    Map.merge(data, %{
      orchestrator_timestamp: DateTime.utc_now(),
      source: "orchestrator"
    })
  end

  defp enrich_message(data), do: %{value: data, orchestrator_timestamp: DateTime.utc_now()}

  defp zenoh_available? do
    System.get_env("SKIP_ZENOH_NIF", "1") == "0" or
      Application.get_env(:indrajaal, :zenoh_enabled, false)
  end
end
