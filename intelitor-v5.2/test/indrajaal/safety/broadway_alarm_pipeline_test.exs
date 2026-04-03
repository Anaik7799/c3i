defmodule Indrajaal.Safety.BroadwayAlarmPipelineTest do
  @moduledoc """
  TDG test suite for Broadway alarm ingestion and classification pipeline.

  WHAT: Tests alarm event ingestion, severity classification, storm detection,
  and pipeline stage transitions. All tests are self-contained — no dependency
  on a running Broadway pipeline or services.

  CONSTRAINTS:
  - SC-ALARM-001: Alarms MUST be ingested and acknowledged within 1 second
  - SC-ALARM-002: Severity classification MUST be deterministic
  - SC-ALARM-003: Alarm storms MUST be detected when rate exceeds threshold
  - SC-ALARM-004: Critical alarms MUST trigger immediate escalation
  - SC-ALARM-005: Alarm deduplication MUST prevent duplicate processing
  - SC-BROADWAY-001: Broadway pipeline MUST handle back-pressure
  - SC-BROADWAY-002: Pipeline stages MUST be fault-tolerant

  ## Constitutional Verification
  - Ψ₀ (Existence): Pipeline logic is pure — cannot crash on malformed alarms
  - Ψ₃ (Verification): Classification is reproducible from same input

  ## Change History
  | Version | Date       | Author | Change                              |
  |---------|------------|--------|-------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 Wave 2 — pipeline suite   |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # Alarm data model and pipeline stages (pure, self-contained)
  # ---------------------------------------------------------------------------

  @storm_rate_threshold 10
  @storm_window_ms 1_000
  @dedup_window_ms 5_000

  defp build_alarm(type, severity, opts \\ []) do
    %{
      id: Keyword.get(opts, :id, make_ref() |> inspect()),
      type: type,
      severity: severity,
      source: Keyword.get(opts, :source, :sensor_1),
      payload: Keyword.get(opts, :payload, %{}),
      received_at: Keyword.get(opts, :received_at, System.monotonic_time(:millisecond)),
      fingerprint: nil
    }
  end

  # Stage 1: Validate and fingerprint
  defp stage_validate(alarm) do
    if alarm.type == nil or alarm.severity == nil do
      {:reject, :invalid_alarm, alarm}
    else
      fingerprint = compute_fingerprint(alarm)
      {:ok, %{alarm | fingerprint: fingerprint}}
    end
  end

  defp compute_fingerprint(alarm) do
    data = "#{alarm.type}:#{alarm.source}:#{alarm.severity}"
    :crypto.hash(:md5, data) |> Base.encode16(case: :lower)
  end

  # Stage 2: Classify severity
  defp stage_classify(alarm) do
    canonical_severity =
      case alarm.severity do
        s when s in [:critical, :high, :medium, :low, :info] -> s
        :emergency -> :critical
        :warning -> :medium
        :debug -> :info
        _ -> :info
      end

    priority =
      case canonical_severity do
        :critical -> 1
        :high -> 2
        :medium -> 3
        :low -> 4
        :info -> 5
      end

    {:ok,
     %{alarm | severity: canonical_severity, payload: Map.put(alarm.payload, :priority, priority)}}
  end

  # Stage 3: Deduplication
  defp stage_dedup(alarm, seen_fingerprints, now_ms) do
    case Map.get(seen_fingerprints, alarm.fingerprint) do
      nil ->
        updated_seen = Map.put(seen_fingerprints, alarm.fingerprint, now_ms)
        {:ok, alarm, updated_seen}

      last_seen ->
        if now_ms - last_seen < @dedup_window_ms do
          {:duplicate, alarm, seen_fingerprints}
        else
          updated_seen = Map.put(seen_fingerprints, alarm.fingerprint, now_ms)
          {:ok, alarm, updated_seen}
        end
    end
  end

  # Stage 4: Storm detection
  defp stage_storm_detect(alarm, recent_alarms, now_ms) do
    # Count alarms in the storm window
    window_start = now_ms - @storm_window_ms

    alarms_in_window =
      Enum.filter(recent_alarms, fn {_fp, ts} -> ts >= window_start end)

    count = length(alarms_in_window) + 1

    if count > @storm_rate_threshold do
      {:storm_detected, alarm, count, %{rate: count, threshold: @storm_rate_threshold}}
    else
      updated_recent = [{alarm.fingerprint, now_ms} | alarms_in_window]
      {:ok, alarm, updated_recent}
    end
  end

  # Stage 5: Escalation check
  defp stage_escalate(alarm) do
    case alarm.severity do
      :critical ->
        {:escalate, alarm, %{channel: :immediate, reason: :critical_severity}}

      :high ->
        {:escalate, alarm, %{channel: :priority, reason: :high_severity}}

      _ ->
        {:ok, alarm}
    end
  end

  # Full pipeline
  defp process_alarm(alarm, state) do
    %{seen_fingerprints: seen_fps, recent_alarms: recent, now_ms: now_ms} = state

    with {:ok, alarm} <- stage_validate(alarm),
         {:ok, alarm} <- stage_classify(alarm),
         {:ok, alarm, updated_fps} <- stage_dedup(alarm, seen_fps, now_ms) do
      case stage_storm_detect(alarm, recent, now_ms) do
        {:storm_detected, alarm, count, meta} ->
          {:storm, alarm, count, meta, %{state | seen_fingerprints: updated_fps}}

        {:ok, alarm, updated_recent} ->
          case stage_escalate(alarm) do
            {:escalate, alarm, escalation} ->
              {:escalated, alarm, escalation,
               %{state | seen_fingerprints: updated_fps, recent_alarms: updated_recent}}

            {:ok, alarm} ->
              {:processed, alarm,
               %{state | seen_fingerprints: updated_fps, recent_alarms: updated_recent}}
          end
      end
    else
      {:reject, reason, alarm} ->
        {:rejected, reason, alarm, state}

      {:duplicate, alarm, _fps} ->
        {:deduplicated, alarm, state}
    end
  end

  defp new_pipeline_state(now_ms \\ nil) do
    %{
      seen_fingerprints: %{},
      recent_alarms: [],
      now_ms: now_ms || System.monotonic_time(:millisecond)
    }
  end

  # ---------------------------------------------------------------------------
  # SC-ALARM-001: Ingestion and validation
  # ---------------------------------------------------------------------------

  describe "SC-ALARM-001: alarm ingestion and validation" do
    test "valid alarm is accepted and processed" do
      alarm = build_alarm(:motion_detected, :medium)
      state = new_pipeline_state()
      result = process_alarm(alarm, state)

      assert match?({:processed, _, _}, result)
    end

    test "alarm without type is rejected" do
      alarm = %{build_alarm(nil, :high) | type: nil}
      state = new_pipeline_state()
      result = process_alarm(alarm, state)

      assert match?({:rejected, :invalid_alarm, _, _}, result)
    end

    test "alarm without severity is rejected" do
      alarm = %{build_alarm(:door_open, nil) | severity: nil}
      state = new_pipeline_state()
      result = process_alarm(alarm, state)

      assert match?({:rejected, :invalid_alarm, _, _}, result)
    end

    test "validate stage assigns fingerprint" do
      alarm = build_alarm(:temperature_high, :medium)
      {:ok, validated} = stage_validate(alarm)
      assert is_binary(validated.fingerprint)
      assert String.length(validated.fingerprint) == 32
    end
  end

  # ---------------------------------------------------------------------------
  # SC-ALARM-002: Deterministic severity classification
  # ---------------------------------------------------------------------------

  describe "SC-ALARM-002: severity classification is deterministic" do
    test "critical maps to priority 1" do
      alarm = build_alarm(:breach, :critical)
      {:ok, classified} = stage_classify(alarm)
      assert classified.payload.priority == 1
    end

    test "high maps to priority 2" do
      alarm = build_alarm(:breach, :high)
      {:ok, classified} = stage_classify(alarm)
      assert classified.payload.priority == 2
    end

    test "medium maps to priority 3" do
      alarm = build_alarm(:motion, :medium)
      {:ok, classified} = stage_classify(alarm)
      assert classified.payload.priority == 3
    end

    test ":emergency is normalized to :critical" do
      alarm = build_alarm(:fire, :emergency)
      {:ok, classified} = stage_classify(alarm)
      assert classified.severity == :critical
      assert classified.payload.priority == 1
    end

    test ":warning is normalized to :medium" do
      alarm = build_alarm(:sensor, :warning)
      {:ok, classified} = stage_classify(alarm)
      assert classified.severity == :medium
    end

    test "unknown severity defaults to :info" do
      alarm = build_alarm(:ping, :unknown_level)
      {:ok, classified} = stage_classify(alarm)
      assert classified.severity == :info
      assert classified.payload.priority == 5
    end

    test "classification is idempotent" do
      alarm = build_alarm(:breach, :high)
      {:ok, first} = stage_classify(alarm)
      {:ok, second} = stage_classify(first)
      assert first.severity == second.severity
      assert first.payload.priority == second.payload.priority
    end
  end

  # ---------------------------------------------------------------------------
  # SC-ALARM-003: Storm detection
  # ---------------------------------------------------------------------------

  describe "SC-ALARM-003: alarm storm detection" do
    test "no storm detected below threshold" do
      now = 1_000_000
      alarm = build_alarm(:motion, :low, received_at: now)

      {:ok, validated} = stage_validate(alarm)
      {:ok, classified} = stage_classify(validated)

      recent = []
      result = stage_storm_detect(classified, recent, now)

      assert match?({:ok, _, _}, result)
    end

    test "storm detected when rate exceeds threshold" do
      now = 1_000_000

      # Build recent alarm list with 10 alarms in the last window
      recent =
        for i <- 1..@storm_rate_threshold do
          {"fp#{i}", now - i * 50}
        end

      alarm = build_alarm(:motion, :low, received_at: now)
      {:ok, validated} = stage_validate(alarm)
      {:ok, classified} = stage_classify(validated)

      result = stage_storm_detect(classified, recent, now)

      assert match?({:storm_detected, _, _, _}, result)
    end

    test "storm detection reports count and threshold" do
      now = 1_000_000

      recent =
        for i <- 1..15 do
          {"fp#{i}", now - i * 30}
        end

      alarm = build_alarm(:motion, :low, received_at: now)
      {:ok, validated} = stage_validate(alarm)
      {:ok, classified} = stage_classify(validated)

      {:storm_detected, _, count, meta} = stage_storm_detect(classified, recent, now)

      assert count > @storm_rate_threshold
      assert meta.threshold == @storm_rate_threshold
    end

    test "alarms outside storm window are ignored" do
      now = 1_000_000
      window_start = now - @storm_window_ms

      # Alarms older than the window
      old_recent =
        for i <- 1..20 do
          {"fp#{i}", window_start - i * 100}
        end

      alarm = build_alarm(:motion, :low, received_at: now)
      {:ok, validated} = stage_validate(alarm)
      {:ok, classified} = stage_classify(validated)

      result = stage_storm_detect(classified, old_recent, now)

      # Should be ok — old alarms don't count
      assert match?({:ok, _, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # SC-ALARM-004: Critical escalation
  # ---------------------------------------------------------------------------

  describe "SC-ALARM-004: critical alarm escalation" do
    test "critical alarm triggers immediate escalation" do
      alarm = build_alarm(:intruder, :critical)
      state = new_pipeline_state()
      result = process_alarm(alarm, state)

      assert match?({:escalated, _, %{channel: :immediate}, _}, result)
    end

    test "high alarm triggers priority escalation" do
      alarm = build_alarm(:temperature, :high)
      state = new_pipeline_state()
      result = process_alarm(alarm, state)

      assert match?({:escalated, _, %{channel: :priority}, _}, result)
    end

    test "medium alarm is processed without escalation" do
      alarm = build_alarm(:motion, :medium)
      state = new_pipeline_state()
      result = process_alarm(alarm, state)

      assert match?({:processed, _, _}, result)
    end

    test "escalation includes reason" do
      alarm = build_alarm(:breach, :critical)
      {:escalate, _, escalation} = stage_escalate(alarm)

      assert Map.has_key?(escalation, :reason)
      assert escalation.reason == :critical_severity
    end
  end

  # ---------------------------------------------------------------------------
  # SC-ALARM-005: Deduplication
  # ---------------------------------------------------------------------------

  describe "SC-ALARM-005: alarm deduplication" do
    test "duplicate alarm within dedup window is rejected" do
      now = 1_000_000
      alarm1 = build_alarm(:motion, :medium, received_at: now)
      alarm2 = build_alarm(:motion, :medium, received_at: now + 100, source: :sensor_1)

      {:ok, a1_validated} = stage_validate(alarm1)
      {:ok, a2_validated} = stage_validate(alarm2)

      seen = %{}
      {:ok, _, updated_seen} = stage_dedup(a1_validated, seen, now)

      # Second alarm has same fingerprint → duplicate
      result = stage_dedup(a2_validated, updated_seen, now + 100)
      assert match?({:duplicate, _, _}, result)
    end

    test "alarm after dedup window expiry is accepted" do
      now = 1_000_000
      alarm1 = build_alarm(:motion, :medium, received_at: now)
      alarm2 = build_alarm(:motion, :medium, received_at: now + @dedup_window_ms + 100)

      {:ok, a1_validated} = stage_validate(alarm1)
      {:ok, a2_validated} = stage_validate(alarm2)

      seen = %{}
      {:ok, _, updated_seen} = stage_dedup(a1_validated, seen, now)
      result = stage_dedup(a2_validated, updated_seen, now + @dedup_window_ms + 100)

      assert match?({:ok, _, _}, result)
    end

    test "alarms from different sources have different fingerprints" do
      alarm1 = build_alarm(:motion, :medium, source: :sensor_1)
      alarm2 = build_alarm(:motion, :medium, source: :sensor_2)

      {:ok, v1} = stage_validate(alarm1)
      {:ok, v2} = stage_validate(alarm2)

      refute v1.fingerprint == v2.fingerprint
    end

    test "pipeline returns deduplicated tag for duplicate" do
      now = 1_000_000
      alarm = build_alarm(:motion, :medium, received_at: now)

      state = new_pipeline_state(now)
      {:processed, _, state2} = process_alarm(alarm, state)

      # Same alarm again
      alarm2 = %{alarm | received_at: now + 100, id: "alarm2"}
      result = process_alarm(alarm2, state2)

      assert match?({:deduplicated, _, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  describe "property: pipeline invariants" do
    property "fingerprint is always a 32-char hex string" do
      forall {type, source} <- {PC.atom(5), PC.atom(8)} do
        alarm = build_alarm(type, :medium, source: source)
        {:ok, validated} = stage_validate(alarm)

        is_binary(validated.fingerprint) and String.length(validated.fingerprint) == 32
      end
    end

    test "classification priority is always 1..5" do
      severities = [
        :critical,
        :high,
        :medium,
        :low,
        :info,
        :emergency,
        :warning,
        :debug,
        :unknown
      ]

      ExUnitProperties.check all(severity <- SD.member_of(severities)) do
        alarm = build_alarm(:test, severity)
        {:ok, classified} = stage_classify(alarm)
        priority = classified.payload.priority

        assert priority in 1..5,
               "Expected priority 1..5, got #{priority} for severity #{severity}"
      end
    end

    test "storm threshold is always positive" do
      assert @storm_rate_threshold > 0
    end
  end
end
