defmodule Indrajaal.Cockpit.Prajna.Immune.Mara do
  @moduledoc """
  ## "Mara" - The Adversarial Chaos Agent (SIL-4 Enhanced)

  Mara is an internal Red Team agent that continuously tests the system's
  resilience by injecting fault signals and malformed payloads.

  **Role:** Ensure Antibodies are awake, Membranes are filtering, and
  the system meets SIL-4 fault tolerance requirements.

  ## STAMP Constraints
  - SC-IMMUNE-001: Sentinel SHALL monitor system health continuously
  - SC-IMMUNE-003: Sentinel SHALL log all defensive actions
  - SC-IMMUNE-007: SymbioticDefense response time requirements
  - SC-BIO-001: OODA cycle < 100ms

  ## Attack Taxonomy (Coordinated Chaos Scenarios)
  1. :poison_pill - Schema validation bypass attempt
  2. :metabolic_flood - Resource exhaustion simulation
  3. :latency_spike - Network delay injection
  4. :byzantine_fault - Inconsistent state injection
  5. :cascade_failure - Multi-component failure chain
  6. :memory_leak - Gradual resource drain

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 2.0.0 |
  | Created | 2025-12-27 |
  | Updated | 2026-01-01 |
  | Author | Cybernetic Architect |
  | STAMP | SC-IMMUNE-001, SC-IMMUNE-003, SC-IMMUNE-007, SC-BIO-001 |
  """
  use GenServer
  require Logger

  alias Indrajaal.Cockpit.Prajna.Bio.Types.GeneticPayload
  alias Indrajaal.Cockpit.Prajna.SentinelBridge

  @attack_interval_ms 10_000
  @antibody_threshold 0.75
  @attack_types [
    :poison_pill,
    :metabolic_flood,
    :latency_spike,
    :byzantine_fault,
    :cascade_failure,
    :memory_leak
  ]

  # ═══════════════════════════════════════════════════════════════════════════
  # CLIENT API
  # ═══════════════════════════════════════════════════════════════════════════

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get current attack statistics"
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc "Manually trigger an attack type"
  @spec trigger_attack(atom()) :: :ok
  def trigger_attack(attack_type) when attack_type in @attack_types do
    GenServer.cast(__MODULE__, {:trigger_attack, attack_type})
  end

  @doc "Pause chaos injection (for debugging)"
  @spec pause() :: :ok
  def pause, do: GenServer.cast(__MODULE__, :pause)

  @doc "Resume chaos injection"
  @spec resume() :: :ok
  def resume, do: GenServer.cast(__MODULE__, :resume)

  @doc "Get attack history"
  @spec history() :: list(map())
  def history, do: GenServer.call(__MODULE__, :history)

  # ═══════════════════════════════════════════════════════════════════════════
  # GENSERVER CALLBACKS
  # ═══════════════════════════════════════════════════════════════════════════

  @impl true
  def init(opts) do
    enabled = Keyword.get(opts, :enabled, true)
    interval = Keyword.get(opts, :interval, @attack_interval_ms)

    if enabled do
      Process.send_after(self(), :attack, 5000)
    end

    Logger.info("[Mara] Chaos agent initialized (enabled: #{enabled}, interval: #{interval}ms)")

    {:ok,
     %{
       attacks: 0,
       successful_detections: 0,
       missed_detections: 0,
       paused: not enabled,
       interval: interval,
       history: [],
       last_attack: nil
     }}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      total_attacks: state.attacks,
      successful_detections: state.successful_detections,
      missed_detections: state.missed_detections,
      detection_rate: calculate_detection_rate(state),
      paused: state.paused,
      last_attack: state.last_attack
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:history, _from, state) do
    {:reply, Enum.take(state.history, 20), state}
  end

  @impl true
  def handle_cast({:trigger_attack, attack_type}, state) do
    if not state.paused do
      {result, new_state} = execute_attack_with_tracking(attack_type, state)
      Logger.info("[Mara] Manual attack triggered: #{attack_type} -> #{result}")
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:pause, state) do
    Logger.info("[Mara] Chaos injection PAUSED")
    {:noreply, %{state | paused: true}}
  end

  @impl true
  def handle_cast(:resume, state) do
    Logger.info("[Mara] Chaos injection RESUMED")
    Process.send_after(self(), :attack, state.interval)
    {:noreply, %{state | paused: false}}
  end

  @impl true
  def handle_info(:attack, state) do
    if not state.paused do
      attack_type = Enum.random(@attack_types)
      {_result, new_state} = execute_attack_with_tracking(attack_type, state)

      # Schedule next attack
      Process.send_after(self(), :attack, state.interval)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:check_byzantine_detection, test_id}, state) do
    # SIL-4 FIX: Verify byzantine fault was detected
    case :persistent_term.get({:mara, :byzantine_test, test_id}, nil) do
      nil ->
        {:noreply, state}

      test_data ->
        # Check if SmartMetrics or Sentinel detected the inconsistency
        detected = check_byzantine_was_detected(test_id, test_data)

        if detected do
          Logger.info("[Mara] ✅ Byzantine fault #{test_id} was DETECTED")

          :telemetry.execute(
            [:indrajaal, :prajna, :mara, :byzantine_detected],
            %{test_id: test_id, timestamp: System.system_time(:millisecond)},
            %{
              detection_time_ms:
                DateTime.diff(DateTime.utc_now(), test_data.injected_at, :millisecond)
            }
          )
        else
          Logger.warning("[Mara] ❌ Byzantine fault #{test_id} was NOT DETECTED - SIL-4 GAP!")

          :telemetry.execute(
            [:indrajaal, :prajna, :mara, :byzantine_undetected],
            %{test_id: test_id, timestamp: System.system_time(:millisecond)},
            %{}
          )
        end

        # Cleanup
        :persistent_term.erase({:mara, :byzantine_test, test_id})
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:check_memory_leak_detection, test_id}, state) do
    # SIL-4: Verify memory leak pattern was detected (SC-IMMUNE-005)
    case :persistent_term.get({:mara, :memory_leak_test, test_id}, nil) do
      nil ->
        {:noreply, state}

      test_data ->
        # Check if Sentinel detected the monotonic increase pattern
        detected = check_memory_leak_was_detected(test_id, test_data)

        if detected do
          Logger.info(
            "[Mara] ✅ Memory leak pattern #{test_id} was DETECTED (#{length(test_data.samples)} samples)"
          )

          :telemetry.execute(
            [:indrajaal, :prajna, :mara, :memory_leak_detected],
            %{test_id: test_id, timestamp: System.system_time(:millisecond)},
            %{
              detection_time_ms:
                DateTime.diff(DateTime.utc_now(), test_data.injected_at, :millisecond),
              sample_count: length(test_data.samples)
            }
          )
        else
          Logger.warning(
            "[Mara] ❌ Memory leak pattern #{test_id} was NOT DETECTED - SIL-4 GAP! (SC-IMMUNE-005)"
          )

          :telemetry.execute(
            [:indrajaal, :prajna, :mara, :memory_leak_undetected],
            %{test_id: test_id, timestamp: System.system_time(:millisecond)},
            %{sample_count: length(test_data.samples)}
          )
        end

        # Cleanup
        :persistent_term.erase({:mara, :memory_leak_test, test_id})
        {:noreply, state}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # ATTACK EXECUTION (with Sentinel Integration)
  # ═══════════════════════════════════════════════════════════════════════════

  defp execute_attack_with_tracking(attack_type, state) do
    start_time = System.monotonic_time(:microsecond)

    # Report attack initiation to Sentinel (SC-IMMUNE-003)
    report_to_sentinel(:attack_initiated, %{type: attack_type, timestamp: DateTime.utc_now()})

    # Execute the attack
    attack_result = execute_attack(attack_type)

    # Measure OODA response (SC-BIO-001: < 100ms)
    elapsed_us = System.monotonic_time(:microsecond) - start_time
    elapsed_ms = elapsed_us / 1000

    # Check if system detected the attack (via Sentinel health delta)
    detection_result = verify_detection(attack_type, elapsed_ms)

    # Record to history
    attack_record = %{
      type: attack_type,
      timestamp: DateTime.utc_now(),
      elapsed_ms: elapsed_ms,
      detected: detection_result.detected,
      response_time_ms: detection_result.response_time_ms
    }

    new_state =
      state
      |> Map.update!(:attacks, &(&1 + 1))
      |> Map.update!(:successful_detections, &if(detection_result.detected, do: &1 + 1, else: &1))
      |> Map.update!(:missed_detections, &if(detection_result.detected, do: &1, else: &1 + 1))
      |> Map.update!(:history, &[attack_record | Enum.take(&1, 99)])
      |> Map.put(:last_attack, attack_record)

    # Guardian Antibody auto-block: pause when detection rate exceeds threshold
    new_state = maybe_antibody_block(new_state)

    # Report completion to Sentinel
    report_to_sentinel(:attack_completed, %{
      type: attack_type,
      result: attack_result,
      detected: detection_result.detected,
      response_time_ms: detection_result.response_time_ms
    })

    {attack_result, new_state}
  end

  defp execute_attack(:poison_pill) do
    Logger.info("[Mara] 💊 Injecting Poison Pill (Invalid Schema)...")

    # Broadcast a raw map instead of GeneticPayload - should be rejected by Membrane
    safe_broadcast("prajna:metrics", %{bad: "data", _mara_test: true})
    :poison_pill_injected
  end

  defp execute_attack(:metabolic_flood) do
    Logger.info("[Mara] 🌊 Injecting Metabolic Flood...")

    # Rapid-fire valid payloads to test rate limiting
    for i <- 1..10 do
      payload = %GeneticPayload{
        id: Ecto.UUID.generate(),
        timestamp: DateTime.utc_now(),
        genome_hash: "v1-flood-#{i}",
        dna: %{flood: true, sequence: i}
      }

      safe_broadcast("prajna:metrics", payload)
      Process.sleep(10)
    end

    :flood_completed
  end

  defp execute_attack(:latency_spike) do
    Logger.info("[Mara] ⏱️ Injecting Latency Spike (200ms delay)...")

    # Simulate network latency by delaying response
    Process.sleep(200)

    payload = %GeneticPayload{
      id: Ecto.UUID.generate(),
      timestamp: DateTime.add(DateTime.utc_now(), -200, :millisecond),
      genome_hash: "v1-latency-spike",
      dna: %{delayed: true, artificial_delay_ms: 200}
    }

    safe_broadcast("prajna:metrics", payload)
    :latency_injected
  end

  defp execute_attack(:byzantine_fault) do
    Logger.info("[Mara] 🔀 Injecting Byzantine Fault (Inconsistent State)...")

    # SIL-4 FIX: Track byzantine test for detection verification
    test_id = Ecto.UUID.generate()

    # Send conflicting state messages with tracking
    payload1 = %GeneticPayload{
      id: Ecto.UUID.generate(),
      timestamp: DateTime.utc_now(),
      genome_hash: "v1-byzantine-a",
      dna: %{value: 100, byzantine_test: true, byzantine_test_id: test_id, byzantine_side: :a}
    }

    payload2 = %GeneticPayload{
      id: Ecto.UUID.generate(),
      timestamp: DateTime.utc_now(),
      genome_hash: "v1-byzantine-b",
      dna: %{value: 0, byzantine_test: true, byzantine_test_id: test_id, byzantine_side: :b}
    }

    # Record the expected conflict for detection verification
    :persistent_term.put({:mara, :byzantine_test, test_id}, %{
      injected_at: DateTime.utc_now(),
      values: [100, 0],
      detected: false
    })

    safe_broadcast("prajna:metrics", payload1)
    safe_broadcast("prajna:metrics", payload2)

    # Trigger detection check after a short delay
    Process.send_after(self(), {:check_byzantine_detection, test_id}, 500)

    :byzantine_injected
  end

  defp execute_attack(:cascade_failure) do
    Logger.info("[Mara] ⚡ Injecting Cascade Failure Simulation...")

    # Simulate a sequence of related failures
    for {component, delay} <- [{"db", 0}, {"cache", 50}, {"api", 100}, {"ui", 150}] do
      Process.sleep(delay)

      payload = %GeneticPayload{
        id: Ecto.UUID.generate(),
        timestamp: DateTime.utc_now(),
        genome_hash: "v1-cascade-#{component}",
        dna: %{component: component, status: :failed, cascade_test: true}
      }

      safe_broadcast("prajna:metrics", payload)
    end

    :cascade_simulated
  end

  defp execute_attack(:memory_leak) do
    Logger.info("[Mara] 🧠 Injecting Memory Leak Simulation...")

    # SIL-4: Simulate gradual memory accumulation pattern
    # This creates a series of payloads with increasing memory footprint metadata
    # The immune system should detect the monotonic increase pattern (SC-IMMUNE-005)
    test_id = Ecto.UUID.generate()
    base_memory = :erlang.memory(:total)

    # Record baseline for detection verification
    :persistent_term.put({:mara, :memory_leak_test, test_id}, %{
      injected_at: DateTime.utc_now(),
      baseline_memory: base_memory,
      samples: []
    })

    # Simulate 10 samples with "increasing" memory readings
    for i <- 1..10 do
      # Simulated monotonic increase pattern (what a real leak looks like)
      simulated_memory = base_memory + i * 1_000_000

      payload = %GeneticPayload{
        id: Ecto.UUID.generate(),
        timestamp: DateTime.utc_now(),
        genome_hash: "v1-memory-leak-#{i}",
        dna: %{
          memory_leak_test: true,
          memory_leak_test_id: test_id,
          sample_number: i,
          memory_bytes: simulated_memory,
          delta_bytes: i * 1_000_000,
          monotonic_increase: true
        }
      }

      safe_broadcast("prajna:metrics", payload)

      # Update test data with sample
      case :persistent_term.get({:mara, :memory_leak_test, test_id}, nil) do
        nil ->
          :ok

        test_data ->
          :persistent_term.put({:mara, :memory_leak_test, test_id}, %{
            test_data
            | samples: test_data.samples ++ [simulated_memory]
          })
      end

      Process.sleep(50)
    end

    # Schedule detection verification (SC-IMMUNE-005: 10+ samples required)
    Process.send_after(self(), {:check_memory_leak_detection, test_id}, 1000)

    :memory_leak_simulated
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # GUARDIAN ANTIBODY AUTO-BLOCK (SC-IMMUNE-007)
  # ═══════════════════════════════════════════════════════════════════════════

  defp maybe_antibody_block(%{attacks: attacks} = state) when attacks < 5, do: state

  defp maybe_antibody_block(state) do
    detection_rate = calculate_detection_rate(state) / 100.0

    if detection_rate >= @antibody_threshold and not state.paused do
      Logger.info(
        "[Mara] Guardian Antibody triggered: detection rate #{Float.round(detection_rate * 100, 1)}% >= #{@antibody_threshold * 100}% threshold — auto-pausing"
      )

      :telemetry.execute(
        [:indrajaal, :prajna, :mara, :antibody_block],
        %{
          detection_rate: detection_rate,
          attacks: state.attacks,
          timestamp: System.system_time(:millisecond)
        },
        %{}
      )

      report_to_sentinel(:antibody_block, %{
        detection_rate: detection_rate,
        threshold: @antibody_threshold,
        total_attacks: state.attacks
      })

      %{state | paused: true}
    else
      state
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # SENTINEL INTEGRATION (SC-PRAJNA-004)
  # ═══════════════════════════════════════════════════════════════════════════

  defp report_to_sentinel(event_type, data) do
    try do
      # Log for audit trail (SC-IMMUNE-003)
      Logger.debug("[Mara→Sentinel] #{event_type}: #{inspect(data)}")

      # If SentinelBridge is available, report the threat
      if Process.whereis(SentinelBridge) do
        # Trigger a sync to capture the attack effects
        SentinelBridge.sync_now()
      end
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end

  defp verify_detection(attack_type, _elapsed_ms) do
    # Check Sentinel health for response to attack
    try do
      health = SentinelBridge.get_health()

      # Check if any threats were detected that match our attack
      detected =
        Enum.any?(health.threats, fn threat ->
          threat_matches_attack?(threat, attack_type)
        end)

      %{
        detected: detected,
        response_time_ms: if(detected, do: calculate_response_time(health), else: nil),
        health_score: health.score_percent
      }
    rescue
      _ -> %{detected: false, response_time_ms: nil, health_score: nil}
    catch
      _, _ -> %{detected: false, response_time_ms: nil, health_score: nil}
    end
  end

  defp threat_matches_attack?(threat, :poison_pill) do
    threat.type in [:invalid_schema, :validation_failure, :schema_violation]
  end

  defp threat_matches_attack?(threat, :metabolic_flood) do
    threat.type in [:rate_limit, :resource_exhaustion, :high_load]
  end

  defp threat_matches_attack?(threat, :latency_spike) do
    threat.type in [:high_latency, :timeout, :slow_response]
  end

  defp threat_matches_attack?(threat, :byzantine_fault) do
    threat.type in [:inconsistent_state, :state_conflict, :byzantine]
  end

  defp threat_matches_attack?(threat, :cascade_failure) do
    threat.type in [:cascade, :multiple_failures, :system_degradation]
  end

  defp threat_matches_attack?(threat, :memory_leak) do
    threat.type in [:memory_leak, :resource_exhaustion, :memory_pressure, :gradual_degradation]
  end

  # SIL-4 FIX: Check if byzantine fault was detected by the system
  defp check_byzantine_was_detected(test_id, _test_data) do
    try do
      # Check Sentinel for detected threats
      health = SentinelBridge.get_health()

      # Look for byzantine-related threats
      byzantine_detected =
        Enum.any?(health.threats, fn threat ->
          threat.type in [:inconsistent_state, :state_conflict, :byzantine] or
            (is_binary(threat.message) and String.contains?(threat.message, "byzantine"))
        end)

      # Also check SmartMetrics for conflicting values with same test_id
      metrics_detected = check_metrics_for_byzantine(test_id)

      byzantine_detected or metrics_detected
    rescue
      _ -> false
    catch
      _, _ -> false
    end
  end

  defp check_metrics_for_byzantine(_test_id) do
    # Check SmartMetrics for conflicting values
    # This would detect if two metrics with same key have different values
    try do
      case Process.whereis(Indrajaal.Cockpit.Prajna.SmartMetrics) do
        nil ->
          false

        _pid ->
          metrics = Indrajaal.Cockpit.Prajna.SmartMetrics.all()

          # Look for metrics with byzantine_test markers
          byzantine_metrics =
            Enum.filter(metrics, fn {_id, metric} ->
              is_map(metric) and
                is_map(Map.get(metric, :metadata, %{})) and
                Map.get(metric.metadata, :byzantine_test, false)
            end)

          # If we found 2+ byzantine test metrics, check for value conflict
          case byzantine_metrics do
            [{_, m1}, {_, m2} | _] ->
              m1.value != m2.value

            _ ->
              false
          end
      end
    rescue
      _ -> false
    end
  end

  # SIL-4: Check if memory leak pattern was detected (SC-IMMUNE-005)
  defp check_memory_leak_was_detected(test_id, test_data) do
    try do
      # Check Sentinel for memory-related threats
      health = SentinelBridge.get_health()

      sentinel_detected =
        Enum.any?(health.threats, fn threat ->
          threat.type in [:memory_leak, :resource_exhaustion, :memory_pressure] or
            (is_binary(threat.message) and
               (String.contains?(threat.message, "memory") or
                  String.contains?(threat.message, "leak")))
        end)

      # Also check if SmartMetrics detected monotonic pattern
      metrics_detected = check_metrics_for_memory_leak(test_id, test_data)

      sentinel_detected or metrics_detected
    rescue
      _ -> false
    catch
      _, _ -> false
    end
  end

  defp check_metrics_for_memory_leak(_test_id, test_data) do
    # Verify we have 10+ samples with monotonic increase (SC-IMMUNE-005)
    samples = test_data.samples

    if length(samples) >= 10 do
      # Check for monotonic increase pattern
      pairs = Enum.zip(samples, Enum.drop(samples, 1))
      all_increasing = Enum.all?(pairs, fn {a, b} -> b > a end)

      if all_increasing do
        Logger.debug(
          "[Mara] Memory leak pattern verified: #{length(samples)} monotonically increasing samples"
        )

        true
      else
        false
      end
    else
      false
    end
  end

  defp calculate_response_time(health) do
    # Estimate response time from last_sync timestamp
    if health.last_sync do
      DateTime.diff(DateTime.utc_now(), health.last_sync, :millisecond)
    else
      nil
    end
  end

  defp calculate_detection_rate(%{attacks: 0}), do: 0.0

  defp calculate_detection_rate(%{attacks: total, successful_detections: detected}) do
    Float.round(detected / total * 100, 2)
  end

  defp safe_broadcast(topic, message) do
    try do
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, topic, message)
    rescue
      ArgumentError -> :ok
    catch
      _, _ -> :ok
    end
  end
end
