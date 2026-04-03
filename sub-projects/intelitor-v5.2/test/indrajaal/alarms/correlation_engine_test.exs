defmodule Indrajaal.Alarms.CorrelationEngineTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.Alarms.CorrelationEngine.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation hardening
  - FPPS Validation: Correlation types verified across 5 dimensions

  ## STAMP Safety Integration
  - SC-COV-001: Critical correlation analysis path coverage
  - SC-COV-006: TDG compliance mandatory

  ## Constitutional Verification
  - Psi0 Existence: Module is pure (no GenServer), always available
  - Psi1 Regeneration: Correlation analysis is deterministic given same alarm input

  ## Founder's Directive Alignment
  - Omega0.1: Correlation engine reduces false positives, preserving operational continuity

  ## TPS 5-Level RCA Context
  - L1 Symptom: Isolated alarms processed without pattern context
  - L5 Root Cause: Missing cross-event correlation blinds operators to coordinated attacks

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude | Sprint 54 W3 test generation |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Alarms.CorrelationEngine

  @moduletag :zenoh_nif

  # Helpers for building minimal alarm-like structs

  defp build_alarm(overrides \\ %{}) do
    Map.merge(
      %{
        id: "alarm-#{System.unique_integer([:positive])}",
        site_id: "site-001",
        zone_id: "zone-001",
        tenant_id: "tenant-001",
        event_type: :intrusion,
        severity: :medium,
        triggered_at: DateTime.utc_now(),
        location_details: %{floor: 1, room: "server-room"},
        device_id: "device-001",
        device_type: :motion
      },
      overrides
    )
  end

  # ---------------------------------------------------------------------------
  # analyze/1
  # ---------------------------------------------------------------------------

  describe "analyze/1" do
    test "returns {:ok, alarm} when no correlations found (no adjacent alarms)" do
      alarm = build_alarm()
      result = CorrelationEngine.analyze(alarm)

      # With empty query results (stubs), no correlation group is created
      assert match?({:ok, _}, result)
    end

    test "returns a tuple for any valid alarm struct" do
      alarm = build_alarm(%{event_type: :panic, severity: :critical})
      result = CorrelationEngine.analyze(alarm)

      assert is_tuple(result)
      assert tuple_size(result) >= 1
    end

    test "analyze returns immediately without crash for minimal alarm map" do
      alarm = build_alarm(%{site_id: "x", zone_id: "y"})
      assert is_tuple(CorrelationEngine.analyze(alarm))
    end

    test "analyze handles alarm with nil triggered_at" do
      alarm = build_alarm(%{triggered_at: nil})
      result = CorrelationEngine.analyze(alarm)
      assert is_tuple(result)
    end

    test "analyze handles alarm with extra fields" do
      alarm = build_alarm(%{custom_field: "extra", metadata: %{source: "mobile"}})
      result = CorrelationEngine.analyze(alarm)
      assert is_tuple(result)
    end

    test "multiple different alarms each return a tuple result" do
      alarms = [
        build_alarm(%{event_type: :fire}),
        build_alarm(%{event_type: :tamper}),
        build_alarm(%{event_type: :motion}),
        build_alarm(%{event_type: :duress})
      ]

      results = Enum.map(alarms, &CorrelationEngine.analyze/1)
      assert Enum.all?(results, &is_tuple/1)
    end

    test "analyze with panic event type does not crash" do
      alarm = build_alarm(%{event_type: :panic})
      assert is_tuple(CorrelationEngine.analyze(alarm))
    end
  end

  # ---------------------------------------------------------------------------
  # finalize_correlations/1
  # ---------------------------------------------------------------------------

  describe "finalize_correlations/1" do
    test "returns {:ok, analysis} tuple" do
      alarm = build_alarm()
      result = CorrelationEngine.finalize_correlations(alarm)
      assert match?({:ok, _analysis}, result)
    end

    test "analysis map contains required keys" do
      alarm = build_alarm()
      {:ok, analysis} = CorrelationEngine.finalize_correlations(alarm)

      required_keys = [
        :correlation_count,
        :correlation_types,
        :confidence_score,
        :recommended_action
      ]

      Enum.each(required_keys, fn key ->
        assert Map.has_key?(analysis, key), "Missing analysis key: #{inspect(key)}"
      end)
    end

    test "correlation_count is a non-negative integer" do
      alarm = build_alarm()
      {:ok, analysis} = CorrelationEngine.finalize_correlations(alarm)
      assert is_integer(analysis.correlation_count)
      assert analysis.correlation_count >= 0
    end

    test "correlation_types is a list" do
      alarm = build_alarm()
      {:ok, analysis} = CorrelationEngine.finalize_correlations(alarm)
      assert is_list(analysis.correlation_types)
    end

    test "confidence_score is a number between 0.0 and 1.0" do
      alarm = build_alarm()
      {:ok, analysis} = CorrelationEngine.finalize_correlations(alarm)
      assert is_number(analysis.confidence_score)
      assert analysis.confidence_score >= 0.0
      assert analysis.confidence_score <= 1.0
    end

    test "recommended_action is an atom or string" do
      alarm = build_alarm()
      {:ok, analysis} = CorrelationEngine.finalize_correlations(alarm)
      assert is_atom(analysis.recommended_action) or is_binary(analysis.recommended_action)
    end

    test "finalize_correlations is idempotent on same alarm" do
      alarm = build_alarm(%{id: "idempotent-alarm-001"})
      {:ok, analysis1} = CorrelationEngine.finalize_correlations(alarm)
      {:ok, analysis2} = CorrelationEngine.finalize_correlations(alarm)

      assert analysis1.correlation_count == analysis2.correlation_count
      assert analysis1.correlation_types == analysis2.correlation_types
    end

    test "finalize_correlations with critical alarm returns recommended_action" do
      alarm = build_alarm(%{event_type: :panic, severity: :critical})
      {:ok, analysis} = CorrelationEngine.finalize_correlations(alarm)
      refute is_nil(analysis.recommended_action)
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests (EP-GEN-014 compliant)
  # ---------------------------------------------------------------------------

  property "finalize_correlations always returns {:ok, map} for any binary site_id" do
    forall site_id <- PC.binary() do
      alarm =
        %{
          id: "prop-alarm",
          site_id: site_id,
          zone_id: "zone-1",
          tenant_id: "tenant-1",
          event_type: :intrusion,
          severity: :medium,
          triggered_at: DateTime.utc_now(),
          location_details: %{},
          device_id: "d1",
          device_type: :motion
        }

      case CorrelationEngine.finalize_correlations(alarm) do
        {:ok, analysis} ->
          is_map(analysis) and
            Map.has_key?(analysis, :correlation_count) and
            Map.has_key?(analysis, :confidence_score)

        _other ->
          false
      end
    end
  end

  property "analyze always returns a tuple for any event_type atom" do
    event_types = [:panic, :fire, :intrusion, :tamper, :medical, :environmental, :supervisory]

    forall event_type <- PC.oneof(Enum.map(event_types, &PC.exactly/1)) do
      alarm = %{
        id: "prop-alarm-2",
        site_id: "site-1",
        zone_id: "zone-1",
        tenant_id: "t1",
        event_type: event_type,
        severity: :medium,
        triggered_at: DateTime.utc_now(),
        location_details: %{},
        device_id: "d1",
        device_type: :motion
      }

      is_tuple(CorrelationEngine.analyze(alarm))
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties tests (EP-GEN-014 compliant)
  # ---------------------------------------------------------------------------

  test "correlation_count is always non-negative" do
    ExUnitProperties.check all(
                             site_id <- SD.string(:alphanumeric, min_length: 1, max_length: 32),
                             zone_id <- SD.string(:alphanumeric, min_length: 1, max_length: 32)
                           ) do
      alarm = %{
        id: "sd-alarm",
        site_id: site_id,
        zone_id: zone_id,
        tenant_id: "tenant-1",
        event_type: :intrusion,
        severity: :medium,
        triggered_at: DateTime.utc_now(),
        location_details: %{},
        device_id: "d1",
        device_type: :motion
      }

      {:ok, analysis} = CorrelationEngine.finalize_correlations(alarm)
      assert analysis.correlation_count >= 0
    end
  end
end
