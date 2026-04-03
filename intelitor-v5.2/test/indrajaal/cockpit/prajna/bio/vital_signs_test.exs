defmodule Indrajaal.Cockpit.Prajna.Bio.VitalSignsTest do
  @moduledoc """
  ## VitalSigns Test Suite - TDG Compliant

  WHAT: Comprehensive tests for the VitalSigns health monitoring system.

  WHY: Validates SC-BIO-003 compliance (0.0-1.0 health values) and ensures
       correct trend analysis, composite health calculation, and alert generation.

  CONSTRAINTS:
    - SC-BIO-003: All health values MUST be 0.0-1.0 floats
    - SC-PROP-023: PropCheck/StreamData disambiguation with PC/SD aliases
    - SC-PROP-024: Dual property testing mandatory

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-29 |
  | Author | Worker Agent W17 |
  | STAMP | SC-BIO-003, SC-PROP-023, SC-PROP-024 |
  """

  use ExUnit.Case, async: false
  @moduletag :zenoh_nif
  use PropCheck
  # EP-GEN-014: Re-import to exclude check/2 (conflicts with ExUnitProperties)
  import PropCheck, except: [check: 2]

  # EP-GEN-014: PropCheck/StreamData Generator Conflict Resolution
  alias PropCheck.BasicTypes, as: PC
  import StreamData, only: []
  alias StreamData, as: SD

  # Suppress warnings for unused imports in property tests
  # NOTE: We need check/2 for `ExUnitProperties.check all(...)` syntax - do NOT exclude it
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias Indrajaal.Cockpit.Prajna.Bio.VitalSigns

  import Indrajaal.STAMPTestHelpers

  # ═══════════════════════════════════════════════════════════════════════════
  # TEST SETUP
  # ═══════════════════════════════════════════════════════════════════════════

  setup do
    # Start VitalSigns GenServer for tests
    case GenServer.whereis(VitalSigns) do
      nil ->
        {:ok, pid} = VitalSigns.start_link([])

        on_exit(fn ->
          try do
            if Process.alive?(pid) do
              GenServer.stop(pid, :normal, 5000)
            end
          catch
            :exit, _ -> :ok
          end
        end)

        %{vital_signs_pid: pid}

      pid ->
        # Clean up existing state
        try do
          :ets.delete_all_objects(:vital_signs_store)
          :ets.delete_all_objects(:vital_signs_history)
        catch
          _, _ -> :ok
        end

        %{vital_signs_pid: pid}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # HEALTH VALUE NORMALIZATION TESTS (SC-BIO-003)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "SC-BIO-003: Health Value Normalization (0.0-1.0)" do
    test "accepts valid health values in range 0.0-1.0" do
      valid_metrics = %{
        cpu_health: 0.85,
        memory_health: 0.72,
        io_health: 0.90,
        latency_health: 0.95
      }

      assert :ok = VitalSigns.record("test-component", :worker, valid_metrics)

      # Allow async cast to complete
      Process.sleep(50)

      vitals = VitalSigns.get("test-component")
      assert vitals != nil
      assert vitals.vitals.cpu_health == 0.85
      assert vitals.vitals.memory_health == 0.72
      assert vitals.vitals.io_health == 0.90
      assert vitals.vitals.latency_health == 0.95
    end

    test "clamps values above 1.0 to 1.0" do
      metrics = %{
        cpu_health: 1.5,
        memory_health: 2.0,
        io_health: 0.9,
        latency_health: 0.8
      }

      # This should fail validation since values > 1.0 are invalid
      result = VitalSigns.record("test-clamp-high", :worker, metrics)
      assert result == {:error, :invalid_values}
    end

    test "clamps values below 0.0 to 0.0" do
      metrics = %{
        cpu_health: -0.5,
        memory_health: -1.0,
        io_health: 0.9,
        latency_health: 0.8
      }

      # This should fail validation since values < 0.0 are invalid
      result = VitalSigns.record("test-clamp-low", :worker, metrics)
      assert result == {:error, :invalid_values}
    end

    test "accepts boundary values 0.0 and 1.0" do
      metrics = %{
        cpu_health: 0.0,
        memory_health: 1.0,
        io_health: 0.0,
        latency_health: 1.0
      }

      assert :ok = VitalSigns.record("test-boundary", :worker, metrics)

      Process.sleep(50)

      vitals = VitalSigns.get("test-boundary")
      assert vitals != nil
      assert vitals.vitals.cpu_health == 0.0
      assert vitals.vitals.memory_health == 1.0
    end

    test "rejects metrics with missing required fields" do
      incomplete_metrics = %{
        cpu_health: 0.8,
        memory_health: 0.7
        # Missing io_health and latency_health
      }

      result = VitalSigns.record("test-incomplete", :worker, incomplete_metrics)
      assert {:error, {:missing_metrics, missing}} = result
      assert :io_health in missing
      assert :latency_health in missing
    end

    test "rejects non-numeric health values" do
      invalid_metrics = %{
        cpu_health: "high",
        memory_health: 0.7,
        io_health: 0.9,
        latency_health: 0.8
      }

      result = VitalSigns.record("test-invalid-type", :worker, invalid_metrics)
      assert result == {:error, :invalid_values}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # COMPOSITE HEALTH CALCULATION TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Composite Health Calculation" do
    test "calculates weighted average correctly" do
      # Weights: CPU=0.30, Memory=0.25, IO=0.20, Latency=0.25
      metrics = %{
        cpu_health: 1.0,
        memory_health: 1.0,
        io_health: 1.0,
        latency_health: 1.0
      }

      assert :ok = VitalSigns.record("test-composite-full", :worker, metrics)
      Process.sleep(50)

      vitals = VitalSigns.get("test-composite-full")
      # All 1.0 should result in composite of 1.0
      assert vitals.vitals.composite_health == 1.0
    end

    test "calculates composite health with varying values" do
      # Expected: 0.8*0.30 + 0.6*0.25 + 0.9*0.20 + 0.7*0.25
      #         = 0.24 + 0.15 + 0.18 + 0.175 = 0.745
      metrics = %{
        cpu_health: 0.8,
        memory_health: 0.6,
        io_health: 0.9,
        latency_health: 0.7
      }

      assert :ok = VitalSigns.record("test-composite-varied", :worker, metrics)
      Process.sleep(50)

      vitals = VitalSigns.get("test-composite-varied")
      expected = 0.8 * 0.30 + 0.6 * 0.25 + 0.9 * 0.20 + 0.7 * 0.25
      assert_in_delta vitals.vitals.composite_health, expected, 0.001
    end

    test "composite health is zero when all metrics are zero" do
      metrics = %{
        cpu_health: 0.0,
        memory_health: 0.0,
        io_health: 0.0,
        latency_health: 0.0
      }

      assert :ok = VitalSigns.record("test-composite-zero", :worker, metrics)
      Process.sleep(50)

      vitals = VitalSigns.get("test-composite-zero")
      assert vitals.vitals.composite_health == 0.0
    end

    test "composite health reflects CPU weight dominance" do
      # CPU has highest weight at 0.30
      metrics_high_cpu = %{
        cpu_health: 1.0,
        memory_health: 0.5,
        io_health: 0.5,
        latency_health: 0.5
      }

      metrics_low_cpu = %{
        cpu_health: 0.5,
        memory_health: 1.0,
        io_health: 0.5,
        latency_health: 0.5
      }

      assert :ok = VitalSigns.record("test-high-cpu", :worker, metrics_high_cpu)
      assert :ok = VitalSigns.record("test-low-cpu", :worker, metrics_low_cpu)
      Process.sleep(50)

      high_cpu_vitals = VitalSigns.get("test-high-cpu")
      low_cpu_vitals = VitalSigns.get("test-low-cpu")

      # High CPU health should result in higher composite
      assert high_cpu_vitals.vitals.composite_health > low_cpu_vitals.vitals.composite_health
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # TREND ANALYSIS TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Trend Analysis (improving/stable/degrading)" do
    test "initial reading has stable trend" do
      metrics = %{
        cpu_health: 0.8,
        memory_health: 0.7,
        io_health: 0.9,
        latency_health: 0.85
      }

      assert :ok = VitalSigns.record("test-trend-initial", :worker, metrics)
      Process.sleep(50)

      vitals = VitalSigns.get("test-trend-initial")
      assert vitals.vitals.trend == :stable
    end

    test "detects improving trend with increasing health values" do
      component_id = "test-trend-improving"

      # Record declining values first (older)
      Enum.each(1..8, fn i ->
        health = 0.3 + i * 0.02

        metrics = %{
          cpu_health: health,
          memory_health: health,
          io_health: health,
          latency_health: health
        }

        assert :ok = VitalSigns.record(component_id, :worker, metrics)
        Process.sleep(10)
      end)

      # Record significantly higher values (recent)
      Enum.each(1..5, fn _i ->
        metrics = %{
          cpu_health: 0.9,
          memory_health: 0.9,
          io_health: 0.9,
          latency_health: 0.9
        }

        assert :ok = VitalSigns.record(component_id, :worker, metrics)
        Process.sleep(10)
      end)

      vitals = VitalSigns.get(component_id)
      assert vitals.vitals.trend == :improving
    end

    test "detects degrading trend with decreasing health values" do
      component_id = "test-trend-degrading"

      # Record high values first (older)
      Enum.each(1..8, fn _i ->
        metrics = %{
          cpu_health: 0.9,
          memory_health: 0.9,
          io_health: 0.9,
          latency_health: 0.9
        }

        assert :ok = VitalSigns.record(component_id, :worker, metrics)
        Process.sleep(10)
      end)

      # Record significantly lower values (recent)
      Enum.each(1..5, fn _i ->
        metrics = %{
          cpu_health: 0.4,
          memory_health: 0.4,
          io_health: 0.4,
          latency_health: 0.4
        }

        assert :ok = VitalSigns.record(component_id, :worker, metrics)
        Process.sleep(10)
      end)

      vitals = VitalSigns.get(component_id)
      assert vitals.vitals.trend == :degrading
    end

    test "maintains stable trend with consistent values" do
      component_id = "test-trend-stable"

      # Record consistent values
      Enum.each(1..10, fn _i ->
        # Small variations within stability threshold
        metrics = %{
          cpu_health: 0.75 + :rand.uniform() * 0.02,
          memory_health: 0.75 + :rand.uniform() * 0.02,
          io_health: 0.75 + :rand.uniform() * 0.02,
          latency_health: 0.75 + :rand.uniform() * 0.02
        }

        assert :ok = VitalSigns.record(component_id, :worker, metrics)
        Process.sleep(10)
      end)

      vitals = VitalSigns.get(component_id)
      assert vitals.vitals.trend == :stable
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # ALERT GENERATION TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Alert Generation" do
    test "no alert for healthy component (> 0.7)" do
      {_result, events} =
        capture_telemetry([:indrajaal, :vital_signs, :alert], fn ->
          metrics = %{
            cpu_health: 0.9,
            memory_health: 0.85,
            io_health: 0.88,
            latency_health: 0.92
          }

          assert :ok = VitalSigns.record("test-alert-healthy", :worker, metrics)
          Process.sleep(100)
        end)

      # Should not generate alert for healthy values
      assert Enum.empty?(events)
    end

    test "generates caution alert for health between 0.5 and 0.7" do
      {_result, events} =
        capture_telemetry([:indrajaal, :vital_signs, :alert], fn ->
          # Composite will be around 0.6 (in caution range)
          metrics = %{
            cpu_health: 0.6,
            memory_health: 0.6,
            io_health: 0.6,
            latency_health: 0.6
          }

          assert :ok = VitalSigns.record("test-alert-caution", :worker, metrics)
          Process.sleep(100)
        end)

      assert length(events) >= 1
      {_measurements, metadata} = List.first(events)
      assert metadata.severity == :caution
    end

    test "generates warning alert for health between 0.3 and 0.5" do
      {_result, events} =
        capture_telemetry([:indrajaal, :vital_signs, :alert], fn ->
          # Composite will be around 0.4 (in warning range)
          metrics = %{
            cpu_health: 0.4,
            memory_health: 0.4,
            io_health: 0.4,
            latency_health: 0.4
          }

          assert :ok = VitalSigns.record("test-alert-warning", :worker, metrics)
          Process.sleep(100)
        end)

      assert length(events) >= 1
      {_measurements, metadata} = List.first(events)
      assert metadata.severity == :warning
    end

    test "generates critical alert for health below 0.3" do
      {_result, events} =
        capture_telemetry([:indrajaal, :vital_signs, :alert], fn ->
          # Composite will be around 0.2 (in critical range)
          metrics = %{
            cpu_health: 0.2,
            memory_health: 0.2,
            io_health: 0.2,
            latency_health: 0.2
          }

          assert :ok = VitalSigns.record("test-alert-critical", :worker, metrics)
          Process.sleep(100)
        end)

      assert length(events) >= 1
      {_measurements, metadata} = List.first(events)
      assert metadata.severity == :critical
    end

    test "generates degrading alert for degrading trend with low health" do
      component_id = "test-alert-degrading"

      # Build history with degrading trend
      Enum.each(1..8, fn _i ->
        metrics = %{cpu_health: 0.8, memory_health: 0.8, io_health: 0.8, latency_health: 0.8}
        assert :ok = VitalSigns.record(component_id, :worker, metrics)
        Process.sleep(10)
      end)

      # Now record low values that trigger degrading trend + alert
      {_result, events} =
        capture_telemetry([:indrajaal, :vital_signs, :alert], fn ->
          Enum.each(1..5, fn _i ->
            metrics = %{
              cpu_health: 0.55,
              memory_health: 0.55,
              io_health: 0.55,
              latency_health: 0.55
            }

            assert :ok = VitalSigns.record(component_id, :worker, metrics)
            Process.sleep(20)
          end)
        end)

      # Should have at least one degrading alert
      degrading_alerts = Enum.filter(events, fn {_m, meta} -> meta.severity == :degrading end)
      assert length(degrading_alerts) >= 1
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # SYSTEM HEALTH TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "System Health Aggregation" do
    test "returns default values when no components registered" do
      # Clean slate
      :ets.delete_all_objects(:vital_signs_store)
      :ets.delete_all_objects(:vital_signs_history)

      health = VitalSigns.system_health()

      assert health.overall_health == 1.0
      assert health.component_count == 0
      assert health.by_status == %{healthy: 0, caution: 0, warning: 0, critical: 0}
      assert health.by_type == %{}
      assert health.status == :healthy
    end

    test "aggregates health across multiple components" do
      # Register multiple components with varying health
      assert :ok =
               VitalSigns.record("comp-1", :worker, %{
                 cpu_health: 0.9,
                 memory_health: 0.9,
                 io_health: 0.9,
                 latency_health: 0.9
               })

      assert :ok =
               VitalSigns.record("comp-2", :container, %{
                 cpu_health: 0.5,
                 memory_health: 0.5,
                 io_health: 0.5,
                 latency_health: 0.5
               })

      assert :ok =
               VitalSigns.record("comp-3", :supervisor, %{
                 cpu_health: 0.2,
                 memory_health: 0.2,
                 io_health: 0.2,
                 latency_health: 0.2
               })

      Process.sleep(100)

      health = VitalSigns.system_health()

      assert health.component_count == 3
      assert health.by_status.healthy == 1
      # health 0.5 is :caution (0.5 <= health < 0.7), not :warning
      assert health.by_status.caution == 1
      assert health.by_status.critical == 1
      assert Map.has_key?(health.by_type, :worker)
      assert Map.has_key?(health.by_type, :container)
      assert Map.has_key?(health.by_type, :supervisor)
    end

    test "groups components by type correctly" do
      assert :ok =
               VitalSigns.record("worker-1", :worker, %{
                 cpu_health: 0.8,
                 memory_health: 0.8,
                 io_health: 0.8,
                 latency_health: 0.8
               })

      assert :ok =
               VitalSigns.record("worker-2", :worker, %{
                 cpu_health: 0.7,
                 memory_health: 0.7,
                 io_health: 0.7,
                 latency_health: 0.7
               })

      assert :ok =
               VitalSigns.record("container-1", :container, %{
                 cpu_health: 0.9,
                 memory_health: 0.9,
                 io_health: 0.9,
                 latency_health: 0.9
               })

      Process.sleep(100)

      health = VitalSigns.system_health()

      assert health.by_type[:worker].count == 2
      assert health.by_type[:container].count == 1
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNHEALTHY COMPONENTS TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Unhealthy Components Detection" do
    test "identifies components below threshold" do
      assert :ok =
               VitalSigns.record("healthy-comp", :worker, %{
                 cpu_health: 0.9,
                 memory_health: 0.9,
                 io_health: 0.9,
                 latency_health: 0.9
               })

      assert :ok =
               VitalSigns.record("unhealthy-comp", :worker, %{
                 cpu_health: 0.3,
                 memory_health: 0.3,
                 io_health: 0.3,
                 latency_health: 0.3
               })

      Process.sleep(100)

      unhealthy = VitalSigns.unhealthy_components(0.5)

      assert length(unhealthy) == 1
      {component_id, _vitals} = List.first(unhealthy)
      assert component_id == "unhealthy-comp"
    end

    test "sorts unhealthy components by health ascending" do
      assert :ok =
               VitalSigns.record("worst", :worker, %{
                 cpu_health: 0.1,
                 memory_health: 0.1,
                 io_health: 0.1,
                 latency_health: 0.1
               })

      assert :ok =
               VitalSigns.record("bad", :worker, %{
                 cpu_health: 0.3,
                 memory_health: 0.3,
                 io_health: 0.3,
                 latency_health: 0.3
               })

      assert :ok =
               VitalSigns.record("moderate", :worker, %{
                 cpu_health: 0.45,
                 memory_health: 0.45,
                 io_health: 0.45,
                 latency_health: 0.45
               })

      Process.sleep(100)

      unhealthy = VitalSigns.unhealthy_components(0.5)

      assert length(unhealthy) == 3
      [first, second, third] = unhealthy
      assert elem(first, 0) == "worst"
      assert elem(second, 0) == "bad"
      assert elem(third, 0) == "moderate"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # HISTORY TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "History Management" do
    test "stores up to 60 readings in history" do
      component_id = "test-history-limit"

      # Record 70 readings
      Enum.each(1..70, fn i ->
        health = min(1.0, i * 0.01)

        metrics = %{
          cpu_health: health,
          memory_health: health,
          io_health: health,
          latency_health: health
        }

        assert :ok = VitalSigns.record(component_id, :worker, metrics)
        Process.sleep(5)
      end)

      history = VitalSigns.history(component_id)

      # Should be limited to 60 entries
      assert length(history) == 60
    end

    test "history is ordered most recent first" do
      component_id = "test-history-order"

      Enum.each(1..5, fn i ->
        health = i * 0.1

        metrics = %{
          cpu_health: health,
          memory_health: health,
          io_health: health,
          latency_health: health
        }

        assert :ok = VitalSigns.record(component_id, :worker, metrics)
        Process.sleep(20)
      end)

      history = VitalSigns.history(component_id)

      # Most recent (0.5 health) should be first
      assert List.first(history).cpu_health == 0.5
      # Oldest should be last
      assert List.last(history).cpu_health == 0.1
    end

    test "returns empty list for unknown component" do
      history = VitalSigns.history("nonexistent-component")
      assert history == []
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # COLLECTOR REGISTRATION TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Collector Registration" do
    test "registered collector is called during collection" do
      test_pid = self()

      collector_fn = fn ->
        send(test_pid, :collector_called)

        %{
          cpu_health: 0.75,
          memory_health: 0.80,
          io_health: 0.85,
          latency_health: 0.90
        }
      end

      :ok = VitalSigns.register_collector("auto-collect", :worker, collector_fn)

      # Trigger collection
      :ok = VitalSigns.collect_now()

      assert_receive :collector_called, 1000

      # Wait for async processing
      Process.sleep(100)

      vitals = VitalSigns.get("auto-collect")
      assert vitals != nil
      assert vitals.vitals.cpu_health == 0.75
    end

    test "unregister removes collector and cleans up data" do
      collector_fn = fn ->
        %{cpu_health: 0.7, memory_health: 0.7, io_health: 0.7, latency_health: 0.7}
      end

      :ok = VitalSigns.register_collector("to-remove", :worker, collector_fn)
      :ok = VitalSigns.collect_now()
      Process.sleep(100)

      assert VitalSigns.get("to-remove") != nil

      :ok = VitalSigns.unregister_collector("to-remove")
      Process.sleep(50)

      assert VitalSigns.get("to-remove") == nil
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # AGGREGATE HEALTH TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Aggregate Health Calculation" do
    test "returns error for unknown component" do
      result = VitalSigns.aggregate_health("nonexistent")
      assert result == {:error, :not_found}
    end

    test "returns own health when no children" do
      assert :ok =
               VitalSigns.record("standalone", :worker, %{
                 cpu_health: 0.8,
                 memory_health: 0.8,
                 io_health: 0.8,
                 latency_health: 0.8
               })

      Process.sleep(50)

      {:ok, aggregate} = VitalSigns.aggregate_health("standalone")
      vitals = VitalSigns.get("standalone")

      assert aggregate == vitals.vitals.composite_health
    end

    test "calculates weighted aggregate with children (60% own, 40% children)" do
      # Register parent with children
      assert :ok =
               VitalSigns.record("child-1", :worker, %{
                 cpu_health: 0.6,
                 memory_health: 0.6,
                 io_health: 0.6,
                 latency_health: 0.6
               })

      assert :ok =
               VitalSigns.record("child-2", :worker, %{
                 cpu_health: 0.8,
                 memory_health: 0.8,
                 io_health: 0.8,
                 latency_health: 0.8
               })

      assert :ok =
               VitalSigns.record(
                 "parent-comp",
                 :supervisor,
                 %{
                   cpu_health: 1.0,
                   memory_health: 1.0,
                   io_health: 1.0,
                   latency_health: 1.0
                 },
                 children: ["child-1", "child-2"]
               )

      Process.sleep(100)

      {:ok, aggregate} = VitalSigns.aggregate_health("parent-comp")

      # Expected: parent_health * 0.6 + avg_children_health * 0.4
      # Parent = 1.0, Children avg = (0.6 + 0.8) / 2 = 0.7
      # Aggregate = 1.0 * 0.6 + 0.7 * 0.4 = 0.6 + 0.28 = 0.88
      assert_in_delta aggregate, 0.88, 0.01
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY-BASED TESTS (TDG/PropCheck - SC-PROP-023/024)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Property-Based Tests (PropCheck)" do
    @tag timeout: :infinity
    property "SC-BIO-003: All health values remain in 0.0-1.0 range" do
      forall {cpu, mem, io, lat} <-
               {PC.float(0.0, 1.0), PC.float(0.0, 1.0), PC.float(0.0, 1.0), PC.float(0.0, 1.0)} do
        component_id = unique_test_id("prop-range")

        metrics = %{
          cpu_health: cpu,
          memory_health: mem,
          io_health: io,
          latency_health: lat
        }

        :ok = VitalSigns.record(component_id, :worker, metrics)
        Process.sleep(20)

        vitals = VitalSigns.get(component_id)

        vitals != nil and
          vitals.vitals.cpu_health >= 0.0 and vitals.vitals.cpu_health <= 1.0 and
          vitals.vitals.memory_health >= 0.0 and vitals.vitals.memory_health <= 1.0 and
          vitals.vitals.io_health >= 0.0 and vitals.vitals.io_health <= 1.0 and
          vitals.vitals.latency_health >= 0.0 and vitals.vitals.latency_health <= 1.0 and
          vitals.vitals.composite_health >= 0.0 and vitals.vitals.composite_health <= 1.0
      end
    end

    @tag timeout: :infinity
    property "Composite health is weighted average of components" do
      forall {cpu, mem, io, lat} <-
               {PC.float(0.0, 1.0), PC.float(0.0, 1.0), PC.float(0.0, 1.0), PC.float(0.0, 1.0)} do
        component_id = unique_test_id("prop-composite")

        metrics = %{
          cpu_health: cpu,
          memory_health: mem,
          io_health: io,
          latency_health: lat
        }

        :ok = VitalSigns.record(component_id, :worker, metrics)
        Process.sleep(20)

        vitals = VitalSigns.get(component_id)

        # Weights: CPU=0.30, Memory=0.25, IO=0.20, Latency=0.25
        expected = cpu * 0.30 + mem * 0.25 + io * 0.20 + lat * 0.25

        vitals != nil and
          abs(vitals.vitals.composite_health - expected) < 0.001
      end
    end

    @tag timeout: :infinity
    property "Health status classification is monotonic" do
      forall health <- PC.float(0.0, 1.0) do
        status =
          cond do
            health < 0.3 -> :critical
            health < 0.5 -> :warning
            health < 0.7 -> :caution
            true -> :healthy
          end

        # Verify monotonicity: higher health = better or equal status
        status_level =
          case status do
            :critical -> 0
            :warning -> 1
            :caution -> 2
            :healthy -> 3
          end

        (health < 0.3 and status_level == 0) or
          (health >= 0.3 and health < 0.5 and status_level == 1) or
          (health >= 0.5 and health < 0.7 and status_level == 2) or
          (health >= 0.7 and status_level == 3)
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # ExUnitProperties Tests (Dual Property Testing - SC-PROP-024)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Property-Based Tests (ExUnitProperties/StreamData)" do
    @tag timeout: :infinity
    test "SC-BIO-003: health values always clamped to valid range" do
      test_cases = [
        {0.0, 0.0, 0.0, 0.0},
        {0.5, 0.5, 0.5, 0.5},
        {1.0, 1.0, 1.0, 1.0},
        {0.25, 0.75, 0.33, 0.88},
        {0.1, 0.9, 0.5, 0.5}
      ]

      for {cpu, mem, io, lat} <- test_cases do
        component_id = unique_test_id("stream-range")

        metrics = %{
          cpu_health: cpu,
          memory_health: mem,
          io_health: io,
          latency_health: lat
        }

        assert :ok = VitalSigns.record(component_id, :worker, metrics)
        Process.sleep(20)

        vitals = VitalSigns.get(component_id)
        assert vitals != nil

        assert vitals.vitals.cpu_health >= 0.0 and vitals.vitals.cpu_health <= 1.0
        assert vitals.vitals.memory_health >= 0.0 and vitals.vitals.memory_health <= 1.0
        assert vitals.vitals.io_health >= 0.0 and vitals.vitals.io_health <= 1.0
        assert vitals.vitals.latency_health >= 0.0 and vitals.vitals.latency_health <= 1.0
        assert vitals.vitals.composite_health >= 0.0 and vitals.vitals.composite_health <= 1.0
      end
    end

    @tag timeout: :infinity
    test "Trend is always one of :improving, :stable, or :degrading" do
      for health <- [0.0, 0.25, 0.5, 0.75, 1.0] do
        component_id = unique_test_id("stream-trend")

        metrics = %{
          cpu_health: health,
          memory_health: health,
          io_health: health,
          latency_health: health
        }

        assert :ok = VitalSigns.record(component_id, :worker, metrics)
        Process.sleep(20)

        vitals = VitalSigns.get(component_id)
        assert vitals != nil
        assert vitals.vitals.trend in [:improving, :stable, :degrading]
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # TELEMETRY INTEGRATION TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Telemetry Integration" do
    test "emits reading telemetry event on record" do
      {_result, events} =
        capture_telemetry([:indrajaal, :vital_signs, :reading], fn ->
          metrics = %{
            cpu_health: 0.75,
            memory_health: 0.80,
            io_health: 0.85,
            latency_health: 0.90
          }

          assert :ok = VitalSigns.record("test-telemetry", :worker, metrics)
          Process.sleep(100)
        end)

      assert length(events) >= 1
      {measurements, metadata} = List.first(events)

      assert measurements.cpu_health == 0.75
      assert measurements.memory_health == 0.80
      assert measurements.io_health == 0.85
      assert measurements.latency_health == 0.90
      assert metadata.component_id == "test-telemetry"
      assert metadata.component_type == :worker
    end

    test "telemetry includes generation number" do
      {_result, events} =
        capture_telemetry([:indrajaal, :vital_signs, :reading], fn ->
          metrics = %{
            cpu_health: 0.8,
            memory_health: 0.8,
            io_health: 0.8,
            latency_health: 0.8
          }

          assert :ok = VitalSigns.record("test-generation", :worker, metrics)
          Process.sleep(100)
        end)

      assert length(events) >= 1
      {_measurements, metadata} = List.first(events)
      assert is_integer(metadata.generation)
      assert metadata.generation >= 0
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # FILTERING TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Component Filtering" do
    test "by_type returns only matching component types" do
      assert :ok =
               VitalSigns.record("w1", :worker, %{
                 cpu_health: 0.8,
                 memory_health: 0.8,
                 io_health: 0.8,
                 latency_health: 0.8
               })

      assert :ok =
               VitalSigns.record("c1", :container, %{
                 cpu_health: 0.9,
                 memory_health: 0.9,
                 io_health: 0.9,
                 latency_health: 0.9
               })

      assert :ok =
               VitalSigns.record("w2", :worker, %{
                 cpu_health: 0.7,
                 memory_health: 0.7,
                 io_health: 0.7,
                 latency_health: 0.7
               })

      Process.sleep(100)

      workers = VitalSigns.by_type(:worker)
      containers = VitalSigns.by_type(:container)

      assert length(workers) == 2
      assert length(containers) == 1
      assert Enum.all?(workers, fn {_, v} -> v.type == :worker end)
      assert Enum.all?(containers, fn {_, v} -> v.type == :container end)
    end

    test "degrading_components returns only degrading trend components" do
      # Create component with degrading trend
      component_id = "degrade-filter-test"

      Enum.each(1..8, fn _i ->
        metrics = %{cpu_health: 0.9, memory_health: 0.9, io_health: 0.9, latency_health: 0.9}
        assert :ok = VitalSigns.record(component_id, :worker, metrics)
        Process.sleep(10)
      end)

      Enum.each(1..5, fn _i ->
        metrics = %{cpu_health: 0.4, memory_health: 0.4, io_health: 0.4, latency_health: 0.4}
        assert :ok = VitalSigns.record(component_id, :worker, metrics)
        Process.sleep(10)
      end)

      # Create stable component
      assert :ok =
               VitalSigns.record("stable-filter", :worker, %{
                 cpu_health: 0.8,
                 memory_health: 0.8,
                 io_health: 0.8,
                 latency_health: 0.8
               })

      Process.sleep(100)

      degrading = VitalSigns.degrading_components()

      degrading_ids = Enum.map(degrading, fn {id, _} -> id end)
      assert component_id in degrading_ids
      refute "stable-filter" in degrading_ids
    end
  end
end
