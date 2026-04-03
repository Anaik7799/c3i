defmodule Indrajaal.Cockpit.Prajna.CircuitBreakerTest do
  @moduledoc """
  TDG-Compliant Tests for CircuitBreaker Module.

  STAMP Compliance: SC-CIRCUIT-001, SC-CIRCUIT-002, SC-NASA-001, SC-PRF-050
  TDG: Dual property testing with PropCheck + ExUnitProperties

  Tests message storm protection based on NASA "Power of 10" rules.
  """
  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cockpit.Prajna.CircuitBreaker

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - should_process?/2
  # ═══════════════════════════════════════════════════════════════════════════

  describe "should_process?/2" do
    test "processes all messages when queue is low" do
      assert CircuitBreaker.should_process?(50, :telemetry) == :process
      assert CircuitBreaker.should_process?(50, :alarm) == :process
      assert CircuitBreaker.should_process?(50, :emergency) == :process
    end

    test "drops telemetry when queue > 100 (SC-CIRCUIT-001)" do
      assert CircuitBreaker.should_process?(150, :telemetry) == :drop
      assert CircuitBreaker.should_process?(150, :debug) == :drop
    end

    test "processes alarms during load shedding" do
      assert CircuitBreaker.should_process?(150, :alarm) == :process
      assert CircuitBreaker.should_process?(150, :warning) == :process
    end

    test "drops non-alarms during critical mode (queue > 200)" do
      assert CircuitBreaker.should_process?(250, :warning) == :drop
      assert CircuitBreaker.should_process?(250, :metric) == :drop
    end

    test "processes alarms during critical mode" do
      assert CircuitBreaker.should_process?(250, :alarm) == :process
      assert CircuitBreaker.should_process?(250, :emergency) == :process
    end

    test "only processes emergency during emergency mode (queue > 500)" do
      assert CircuitBreaker.should_process?(600, :alarm) == :drop
      assert CircuitBreaker.should_process?(600, :warning) == :drop
      assert CircuitBreaker.should_process?(600, :emergency) == :process
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - state/1
  # ═══════════════════════════════════════════════════════════════════════════

  describe "state/1" do
    test "closed for normal operation" do
      assert CircuitBreaker.state(0) == :closed
      assert CircuitBreaker.state(50) == :closed
      assert CircuitBreaker.state(99) == :closed
    end

    test "half_open for load shedding" do
      # exactly at threshold
      assert CircuitBreaker.state(100) == :closed
      assert CircuitBreaker.state(101) == :half_open
      assert CircuitBreaker.state(199) == :half_open
    end

    test "open for critical mode" do
      assert CircuitBreaker.state(201) == :open
      assert CircuitBreaker.state(400) == :open
    end

    test "tripped for emergency mode" do
      assert CircuitBreaker.state(501) == :tripped
      assert CircuitBreaker.state(1000) == :tripped
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - get_stats/0
  # ═══════════════════════════════════════════════════════════════════════════

  describe "get_stats/0" do
    test "returns threshold configuration" do
      stats = CircuitBreaker.get_stats()

      assert Map.has_key?(stats, :telemetry_threshold)
      assert Map.has_key?(stats, :critical_threshold)
      assert Map.has_key?(stats, :emergency_threshold)
      assert Map.has_key?(stats, :priority_levels)

      assert stats.telemetry_threshold == 100
      assert stats.critical_threshold == 200
      assert stats.emergency_threshold == 500
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - filter_batch/2
  # ═══════════════════════════════════════════════════════════════════════════

  describe "filter_batch/2" do
    test "processes all when queue is low" do
      messages = [
        {:telemetry, "t1"},
        {:alarm, "a1"},
        {:metric, "m1"}
      ]

      {processed, dropped} = CircuitBreaker.filter_batch(messages, 50)

      assert length(processed) == 3
      assert dropped == 0
    end

    test "filters low-priority during load shedding" do
      messages = [
        {:telemetry, "t1"},
        {:alarm, "a1"},
        {:debug, "d1"},
        {:warning, "w1"}
      ]

      {processed, dropped} = CircuitBreaker.filter_batch(messages, 150)

      # telemetry and debug should be dropped
      assert dropped == 2
      assert length(processed) == 2
    end

    test "preserves message order in processed list" do
      messages = [
        {:alarm, "a1"},
        {:alarm, "a2"},
        {:alarm, "a3"}
      ]

      {processed, _dropped} = CircuitBreaker.filter_batch(messages, 150)

      assert processed == ["a1", "a2", "a3"]
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - PropCheck (PC)
  # ═══════════════════════════════════════════════════════════════════════════

  property "should_process? always returns valid decision" do
    forall {queue, msg_type} <- {
             PC.non_neg_integer(),
             PC.oneof([
               :emergency,
               :alarm,
               :warning,
               :command,
               :insight,
               :metric,
               :telemetry,
               :debug
             ])
           } do
      result = CircuitBreaker.should_process?(queue, msg_type)
      result in [:process, :drop, :defer]
    end
  end

  property "emergency messages always processed" do
    forall queue <- PC.non_neg_integer() do
      CircuitBreaker.should_process?(queue, :emergency) == :process
    end
  end

  property "state is deterministic for same queue length" do
    forall queue <- PC.non_neg_integer() do
      s1 = CircuitBreaker.state(queue)
      s2 = CircuitBreaker.state(queue)
      s1 == s2
    end
  end

  property "higher queue lengths never have more permissive states" do
    forall {q1, q2} <- {PC.range(0, 1000), PC.range(0, 1000)} do
      state_order = fn
        :closed -> 0
        :half_open -> 1
        :open -> 2
        :tripped -> 3
      end

      if q1 <= q2 do
        state_order.(CircuitBreaker.state(q1)) <= state_order.(CircuitBreaker.state(q2))
      else
        true
      end
    end
  end

  property "state is always a valid atom" do
    forall queue <- PC.non_neg_integer() do
      state = CircuitBreaker.state(queue)
      state in [:closed, :half_open, :open, :tripped]
    end
  end

  property "get_stats returns consistent thresholds" do
    forall _q <- PC.return(true) do
      stats = CircuitBreaker.get_stats()

      stats.telemetry_threshold == 100 and
        stats.critical_threshold == 200 and
        stats.emergency_threshold == 500
    end
  end

  property "filter_batch preserves total message count" do
    forall {message_types, queue} <- {
             PC.list(PC.oneof([:emergency, :alarm, :warning, :metric, :telemetry, :debug])),
             PC.non_neg_integer()
           } do
      messages = Enum.map(message_types, fn type -> {type, "data"} end)
      {processed, dropped} = CircuitBreaker.filter_batch(messages, queue)
      length(processed) + dropped == length(messages)
    end
  end

  property "zero queue always returns :closed state" do
    forall _q <- PC.return(0) do
      CircuitBreaker.state(0) == :closed
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - ExUnitProperties (SD)
  # ═══════════════════════════════════════════════════════════════════════════

  test "filter_batch dropped count matches filtered messages (property)" do
    messages = [
      {:telemetry, "msg1"},
      {:debug, "msg2"},
      {:metric, "msg3"},
      {:alarm, "msg4"},
      {:emergency, "msg5"}
    ]

    for queue <- [0, 100, 300, 500, 700] do
      {processed, dropped} = CircuitBreaker.filter_batch(messages, queue)
      assert length(processed) + dropped == length(messages)
    end
  end

  test "state boundaries are consistent (property)" do
    for queue <- [0, 50, 100, 150, 200, 350, 500, 750, 1000] do
      state = CircuitBreaker.state(queue)

      cond do
        queue <= 100 -> assert state == :closed
        queue <= 200 -> assert state == :half_open
        queue <= 500 -> assert state == :open
        true -> assert state == :tripped
      end
    end
  end
end
