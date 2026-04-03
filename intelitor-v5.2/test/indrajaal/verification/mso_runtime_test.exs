defmodule Indrajaal.Verification.MSORuntime.Test do
  @moduledoc """
  TDG-compliant tests for MSO/Quint Runtime Verifier (FM-006).

  ## STAMP Constraints Verified
  - SC-COV-006: TDG compliance mandatory
  - SC-PROP-023, SC-PROP-024: Dual property testing with PC/SD aliases
  - SC-FM-006: MSO temporal logic verification

  ## Test Levels
  - L1: Unit tests for core functions
  - L2: Property tests with PropCheck/ExUnitProperties
  - L3: Integration with GenServer lifecycle
  """
  use ExUnit.Case, async: false
  use PropCheck
  import PropCheck, except: [check: 1, check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Verification.MSORuntime

  # ============================================================================
  # Setup & Teardown
  # ============================================================================

  setup do
    case GenServer.whereis(MSORuntime) do
      nil ->
        {:ok, _pid} = MSORuntime.start_link([])

      _pid ->
        :ok
    end

    on_exit(fn ->
      if GenServer.whereis(MSORuntime) do
        GenServer.cast(MSORuntime, :reset_state)
      end
    end)

    :ok
  end

  # ============================================================================
  # L1: Unit Tests - Core Functions
  # ============================================================================

  describe "register_property/1" do
    test "registers a safety property" do
      property = %{
        id: :test_safety_prop,
        name: "Test Safety Property",
        type: :safety,
        formula: {:always, {:not, :error_state}},
        violation_action: :log_violation
      }

      assert :ok = MSORuntime.register_property(property)
    end

    test "registers a liveness property" do
      property = %{
        id: :test_liveness_prop,
        name: "Test Liveness Property",
        type: :liveness,
        formula: {:eventually, {:within_ms, 1000}, :completion},
        violation_action: :alert_sentinel
      }

      assert :ok = MSORuntime.register_property(property)
    end

    test "rejects duplicate property ID" do
      property = %{
        id: :duplicate_prop,
        name: "Duplicate Property",
        type: :safety,
        formula: {:always, {:not, :bad}},
        violation_action: :log_violation
      }

      :ok = MSORuntime.register_property(property)
      assert {:error, :already_registered} = MSORuntime.register_property(property)
    end
  end

  describe "submit_event/2" do
    test "submits event and updates trace" do
      property = %{
        id: :event_test_prop,
        name: "Event Test Property",
        type: :safety,
        formula: {:always, {:not, :catastrophic_failure}},
        violation_action: :log_violation
      }

      :ok = MSORuntime.register_property(property)
      assert :ok = MSORuntime.submit_event(:normal_operation, %{data: "test"})
    end

    test "detects violation on bad event" do
      property = %{
        id: :violation_detect_prop,
        name: "Violation Detect Property",
        type: :safety,
        formula: {:always, {:not, :bad_state}},
        violation_action: :log_violation
      }

      :ok = MSORuntime.register_property(property)
      :ok = MSORuntime.submit_event(:bad_state, %{})

      # Check verdict changed
      verdicts = MSORuntime.get_verdicts()
      assert verdicts[:violation_detect_prop] == :violated
    end
  end

  describe "heartbeat/0" do
    test "records heartbeat without violation" do
      # Get initial stats
      {:ok, stats_before} = MSORuntime.get_stats()

      # Submit heartbeat
      :ok = MSORuntime.heartbeat()

      # Verify heartbeat count increased
      {:ok, stats_after} = MSORuntime.get_stats()
      assert stats_after.heartbeats_received > stats_before.heartbeats_received
    end
  end

  describe "property_satisfied?/1" do
    test "returns true for satisfied property" do
      property = %{
        id: :satisfied_prop,
        name: "Satisfied Property",
        type: :safety,
        formula: {:always, {:not, :never_happens}},
        violation_action: :log_violation
      }

      :ok = MSORuntime.register_property(property)
      :ok = MSORuntime.submit_event(:good_event, %{})

      assert MSORuntime.property_satisfied?(:satisfied_prop) == true
    end

    test "returns false for violated property" do
      property = %{
        id: :violated_prop,
        name: "Violated Property",
        type: :safety,
        formula: {:always, {:not, :trigger_violation}},
        violation_action: :log_violation
      }

      :ok = MSORuntime.register_property(property)
      :ok = MSORuntime.submit_event(:trigger_violation, %{})

      assert MSORuntime.property_satisfied?(:violated_prop) == false
    end
  end

  describe "get_verdicts/0" do
    test "returns all property verdicts" do
      prop1 = %{
        id: :verdict_prop_1,
        name: "Verdict Property 1",
        type: :safety,
        formula: {:always, {:not, :x}},
        violation_action: :log_violation
      }

      prop2 = %{
        id: :verdict_prop_2,
        name: "Verdict Property 2",
        type: :safety,
        formula: {:always, {:not, :y}},
        violation_action: :log_violation
      }

      :ok = MSORuntime.register_property(prop1)
      :ok = MSORuntime.register_property(prop2)

      verdicts = MSORuntime.get_verdicts()
      assert Map.has_key?(verdicts, :verdict_prop_1)
      assert Map.has_key?(verdicts, :verdict_prop_2)
    end
  end

  describe "verify_formula/1" do
    test "verifies simple always formula" do
      {:ok, result} = MSORuntime.verify_formula({:always, {:not, :error}})
      assert is_boolean(result)
    end

    test "verifies eventually formula" do
      {:ok, result} = MSORuntime.verify_formula({:eventually, :goal})
      assert is_boolean(result)
    end

    test "verifies until formula" do
      {:ok, result} = MSORuntime.verify_formula({:until, :condition, :goal})
      assert is_boolean(result)
    end
  end

  # ============================================================================
  # L2: Property Tests (PropCheck)
  # ============================================================================

  describe "PropCheck property tests" do
    @tag :property
    property "registered properties are trackable" do
      forall prop_id <- PC.atom() |> match?({:ok, _}) do
        property = %{
          id: prop_id,
          name: "Generated Property #{prop_id}",
          type: :safety,
          formula: {:always, {:not, :bad}},
          violation_action: :log_violation
        }

        case MSORuntime.register_property(property) do
          :ok ->
            verdicts = MSORuntime.get_verdicts()
            Map.has_key?(verdicts, prop_id)

          {:error, :already_registered} ->
            true
        end
      end
    end

    @tag :property
    property "events never crash the runtime" do
      forall {event_type, data} <- {PC.atom(), PC.map(PC.atom(), PC.any())} |> match?({:ok, _}) do
        result = MSORuntime.submit_event(event_type, data)
        result == :ok
      end
    end

    @tag :property
    @tag timeout: 30_000
    property "heartbeats monotonically increase counter", numtests: 20 do
      forall count <- PC.pos_integer() |> match?({:ok, _}) do
        # Limit iterations
        count = min(count, 10)

        {:ok, stats_before} = MSORuntime.get_stats()

        Enum.each(1..count, fn _ ->
          MSORuntime.heartbeat()
        end)

        {:ok, stats_after} = MSORuntime.get_stats()
        stats_after.heartbeats_received >= stats_before.heartbeats_received + count
      end
    end
  end

  # ============================================================================
  # L2: ExUnitProperties Tests (StreamData)
  # ============================================================================

  describe "ExUnitProperties tests" do
    @tag :property
    test "concurrent event submission is safe" do
      ExUnitProperties.check all(
                               event_types <-
                                 SD.list_of(SD.atom(:alphanumeric), min_length: 1, max_length: 20)
                             ) do
        tasks =
          Enum.map(event_types, fn event_type ->
            Task.async(fn ->
              MSORuntime.submit_event(event_type, %{concurrent: true})
            end)
          end)

        results = Task.await_many(tasks, 5000)
        assert Enum.all?(results, &(&1 == :ok))
      end
    end

    @tag :property
    test "formula verification is deterministic" do
      ExUnitProperties.check all(formula_type <- SD.member_of([:always, :eventually])) do
        formula =
          case formula_type do
            :always -> {:always, {:not, :never_state}}
            :eventually -> {:eventually, :some_goal}
          end

        {:ok, result1} = MSORuntime.verify_formula(formula)
        {:ok, result2} = MSORuntime.verify_formula(formula)

        assert result1 == result2
      end
    end
  end

  # ============================================================================
  # L3: Integration Tests
  # ============================================================================

  describe "builtin properties" do
    test "heartbeat_liveness is registered on startup" do
      verdicts = MSORuntime.get_verdicts()
      assert Map.has_key?(verdicts, :heartbeat_liveness)
    end

    test "no_deadlock is registered on startup" do
      verdicts = MSORuntime.get_verdicts()
      assert Map.has_key?(verdicts, :no_deadlock)
    end

    test "ooda_cycle_time is registered on startup" do
      verdicts = MSORuntime.get_verdicts()
      assert Map.has_key?(verdicts, :ooda_cycle_time)
    end
  end

  describe "GenServer lifecycle" do
    test "handles concurrent property registrations" do
      tasks =
        Enum.map(1..10, fn i ->
          Task.async(fn ->
            property = %{
              id: :"concurrent_prop_#{i}",
              name: "Concurrent Property #{i}",
              type: :safety,
              formula: {:always, {:not, :bad}},
              violation_action: :log_violation
            }

            MSORuntime.register_property(property)
          end)
        end)

      results = Task.await_many(tasks, 5000)
      success_count = Enum.count(results, &(&1 == :ok))
      already_registered = Enum.count(results, &(&1 == {:error, :already_registered}))

      assert success_count + already_registered == 10
    end

    test "stats are tracked correctly" do
      {:ok, stats} = MSORuntime.get_stats()

      assert Map.has_key?(stats, :events_processed)
      assert Map.has_key?(stats, :properties_registered)
      assert Map.has_key?(stats, :violations_detected)
      assert Map.has_key?(stats, :heartbeats_received)
    end
  end

  # ============================================================================
  # L4: FMEA Test Cases
  # ============================================================================

  describe "FMEA scenarios" do
    @tag :fmea
    test "handles invalid formula gracefully" do
      result = MSORuntime.verify_formula({:unknown_operator, :x, :y, :z})
      # Graceful handling
      assert {:ok, _} = result
    end

    @tag :fmea
    test "handles nil event data" do
      result = MSORuntime.submit_event(:test_event, nil)
      assert result == :ok
    end

    @tag :fmea
    test "handles very large event data" do
      large_data = %{
        list: Enum.to_list(1..10_000),
        nested: %{deep: %{deeper: %{data: "test"}}}
      }

      result = MSORuntime.submit_event(:large_event, large_data)
      assert result == :ok
    end

    @tag :fmea
    test "handles rapid event submission" do
      Enum.each(1..100, fn i ->
        MSORuntime.submit_event(:"rapid_event_#{i}", %{i: i})
      end)

      {:ok, stats} = MSORuntime.get_stats()
      assert stats.events_processed >= 100
    end
  end

  # ============================================================================
  # L5: Temporal Property Tests
  # ============================================================================

  describe "temporal semantics" do
    test "always property tracks state correctly" do
      property = %{
        id: :always_test,
        name: "Always Test",
        type: :safety,
        formula: {:always, {:not, :error}},
        violation_action: :log_violation
      }

      :ok = MSORuntime.register_property(property)

      # Good events should keep it satisfied
      :ok = MSORuntime.submit_event(:good, %{})
      :ok = MSORuntime.submit_event(:another_good, %{})

      assert MSORuntime.property_satisfied?(:always_test) == true

      # Bad event should violate
      :ok = MSORuntime.submit_event(:error, %{})
      assert MSORuntime.property_satisfied?(:always_test) == false
    end
  end
end
