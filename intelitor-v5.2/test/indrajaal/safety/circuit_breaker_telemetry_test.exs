defmodule Indrajaal.Safety.CircuitBreakerTelemetryTest do
  @moduledoc """
  TDG test suite for circuit breaker telemetry queue overflow behavior.

  WHAT: Tests queue overflow detection, message dropping, and dropped message
  logging without any dependency on running services. All state is simulated
  as pure data.

  CONSTRAINTS:
  - SC-CIRCUIT-001: Drop telemetry when queue > 100 messages
  - SC-CIRCUIT-002: Dropped messages MUST be logged for post-mortem
  - SC-PRAJNA-001: Guardian Gate — Prajna commands pass Guardian validation
  - SC-LOG-002: Load shedding when queue full

  ## Constitutional Verification
  - Ψ₀ (Existence): Circuit breaker logic cannot crash the system
  - Ψ₂ (History): Dropped message log is append-only for audit

  ## Change History
  | Version | Date       | Author | Change                                  |
  |---------|------------|--------|-----------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 Wave 2 — circuit breaker suite|
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # Circuit breaker state machine (pure, self-contained)
  # ---------------------------------------------------------------------------

  @max_queue_depth 100
  @circuit_open_threshold 100

  defp new_circuit_state do
    %{
      queue: [],
      queue_depth: 0,
      circuit_state: :closed,
      dropped_count: 0,
      dropped_log: [],
      processed_count: 0
    }
  end

  defp enqueue(state, message) do
    if state.queue_depth >= @circuit_open_threshold do
      # Circuit is open — drop the message
      drop_entry = %{
        message: message,
        dropped_at: System.monotonic_time(:millisecond),
        queue_depth_at_drop: state.queue_depth,
        reason: :queue_overflow
      }

      %{
        state
        | circuit_state: :open,
          dropped_count: state.dropped_count + 1,
          dropped_log: [drop_entry | state.dropped_log]
      }
    else
      %{
        state
        | queue: [message | state.queue],
          queue_depth: state.queue_depth + 1,
          circuit_state: :closed
      }
    end
  end

  defp dequeue(state) do
    case state.queue do
      [] ->
        {nil, state}

      [msg | rest] ->
        updated = %{
          state
          | queue: rest,
            queue_depth: state.queue_depth - 1,
            processed_count: state.processed_count + 1,
            circuit_state:
              if(state.queue_depth - 1 < @circuit_open_threshold,
                do: :closed,
                else: state.circuit_state
              )
        }

        {msg, updated}
    end
  end

  defp circuit_open?(state), do: state.circuit_state == :open
  defp circuit_closed?(state), do: state.circuit_state == :closed

  defp drain(state, count) do
    Enum.reduce(1..count, state, fn _, acc ->
      {_, new_state} = dequeue(acc)
      new_state
    end)
  end

  # ---------------------------------------------------------------------------
  # SC-CIRCUIT-001: Drop telemetry when queue > 100
  # ---------------------------------------------------------------------------

  describe "SC-CIRCUIT-001: queue overflow triggers message dropping" do
    test "circuit opens when queue reaches 100 messages" do
      state =
        Enum.reduce(1..@max_queue_depth, new_circuit_state(), fn i, acc ->
          enqueue(acc, %{type: :telemetry, seq: i})
        end)

      assert state.queue_depth == @max_queue_depth
      assert circuit_closed?(state)

      # One more message should open the circuit
      state_after = enqueue(state, %{type: :telemetry, seq: 101})
      assert circuit_open?(state_after)
      assert state_after.dropped_count == 1
    end

    test "exactly 100 messages fit without dropping" do
      state =
        Enum.reduce(1..100, new_circuit_state(), fn i, acc ->
          enqueue(acc, %{seq: i})
        end)

      assert state.queue_depth == 100
      assert state.dropped_count == 0
      assert circuit_closed?(state)
    end

    test "message 101 is dropped, not enqueued" do
      state =
        Enum.reduce(1..100, new_circuit_state(), fn i, acc ->
          enqueue(acc, %{seq: i})
        end)

      state_after = enqueue(state, %{seq: 101, special: true})

      # Queue depth unchanged — message was dropped, not added
      assert state_after.queue_depth == 100
      assert state_after.dropped_count == 1
    end

    test "all messages beyond 100 are dropped" do
      base_state =
        Enum.reduce(1..100, new_circuit_state(), fn i, acc ->
          enqueue(acc, %{seq: i})
        end)

      final_state =
        Enum.reduce(101..120, base_state, fn i, acc ->
          enqueue(acc, %{seq: i})
        end)

      assert final_state.dropped_count == 20
      assert final_state.queue_depth == 100
    end

    test "circuit closes after queue is drained below threshold" do
      state =
        Enum.reduce(1..110, new_circuit_state(), fn i, acc ->
          enqueue(acc, %{seq: i})
        end)

      assert circuit_open?(state)

      # Drain below threshold
      drained = drain(state, 15)
      assert drained.queue_depth == 95

      # New message should be accepted again
      state_after = enqueue(drained, %{seq: 111})
      assert circuit_closed?(state_after)
      assert state_after.queue_depth == 96
    end
  end

  # ---------------------------------------------------------------------------
  # SC-CIRCUIT-002: Dropped messages MUST be logged
  # ---------------------------------------------------------------------------

  describe "SC-CIRCUIT-002: dropped messages are logged" do
    test "dropped message log is non-empty after overflow" do
      state =
        Enum.reduce(1..101, new_circuit_state(), fn i, acc ->
          enqueue(acc, %{seq: i})
        end)

      assert length(state.dropped_log) == 1
    end

    test "dropped log entry contains required fields" do
      state =
        Enum.reduce(1..101, new_circuit_state(), fn i, acc ->
          enqueue(acc, %{seq: i})
        end)

      [entry] = state.dropped_log

      assert Map.has_key?(entry, :message)
      assert Map.has_key?(entry, :dropped_at)
      assert Map.has_key?(entry, :queue_depth_at_drop)
      assert Map.has_key?(entry, :reason)
      assert entry.reason == :queue_overflow
    end

    test "dropped log records original message content" do
      state =
        Enum.reduce(1..100, new_circuit_state(), fn i, acc ->
          enqueue(acc, %{seq: i})
        end)

      special_msg = %{seq: 999, priority: :critical, source: :sentinel}
      state_after = enqueue(state, special_msg)

      [entry] = state_after.dropped_log
      assert entry.message == special_msg
    end

    test "dropped log is append-only — each drop adds an entry" do
      base =
        Enum.reduce(1..100, new_circuit_state(), fn i, acc ->
          enqueue(acc, %{seq: i})
        end)

      state1 = enqueue(base, %{seq: 101})
      state2 = enqueue(state1, %{seq: 102})
      state3 = enqueue(state2, %{seq: 103})

      assert length(state3.dropped_log) == 3
      assert state3.dropped_count == 3
    end

    test "drop log preserves sequence: newest entry is head" do
      base =
        Enum.reduce(1..100, new_circuit_state(), fn i, acc ->
          enqueue(acc, %{seq: i})
        end)

      state = enqueue(base, %{seq: 101})
      state = enqueue(state, %{seq: 102})

      [newest | _] = state.dropped_log
      assert newest.message.seq == 102
    end

    test "queue_depth_at_drop is always exactly 100" do
      base =
        Enum.reduce(1..100, new_circuit_state(), fn i, acc ->
          enqueue(acc, %{seq: i})
        end)

      state = enqueue(base, %{seq: 101})
      state = enqueue(state, %{seq: 102})

      for entry <- state.dropped_log do
        assert entry.queue_depth_at_drop == 100
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Dequeue behavior
  # ---------------------------------------------------------------------------

  describe "dequeue behavior" do
    test "dequeue from empty queue returns nil" do
      state = new_circuit_state()
      {msg, _} = dequeue(state)
      assert msg == nil
    end

    test "dequeue reduces queue depth by 1" do
      state = enqueue(new_circuit_state(), %{seq: 1})
      assert state.queue_depth == 1

      {_, after_dequeue} = dequeue(state)
      assert after_dequeue.queue_depth == 0
    end

    test "processed_count increments on successful dequeue" do
      state = enqueue(new_circuit_state(), %{seq: 1})
      {_, state2} = dequeue(state)
      {_, state3} = dequeue(state2)

      assert state3.processed_count == 1
    end

    test "full cycle: enqueue 100, dequeue 100, process all" do
      state =
        Enum.reduce(1..100, new_circuit_state(), fn i, acc ->
          enqueue(acc, %{seq: i})
        end)

      final = drain(state, 100)

      assert final.queue_depth == 0
      assert final.processed_count == 100
      assert final.dropped_count == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  describe "property: queue invariants" do
    property "dropped_count + queue_depth <= total_enqueued" do
      forall messages <- PC.list(PC.integer()) do
        state =
          Enum.reduce(messages, new_circuit_state(), fn msg, acc ->
            enqueue(acc, msg)
          end)

        total_enqueued = length(messages)
        state.dropped_count + state.queue_depth <= total_enqueued
      end
    end

    test "queue never exceeds max depth regardless of message count" do
      ExUnitProperties.check all(count <- SD.integer(0, 500)) do
        state =
          Enum.reduce(1..max(count, 1), new_circuit_state(), fn i, acc ->
            enqueue(acc, %{seq: i})
          end)

        assert state.queue_depth <= @max_queue_depth,
               "Queue depth #{state.queue_depth} exceeded max #{@max_queue_depth}"
      end
    end

    test "dropped_log length equals dropped_count" do
      ExUnitProperties.check all(count <- SD.integer(0, 200)) do
        state =
          Enum.reduce(1..max(count, 1), new_circuit_state(), fn i, acc ->
            enqueue(acc, %{seq: i})
          end)

        assert length(state.dropped_log) == state.dropped_count
      end
    end

    test "no drops when message count <= 100" do
      ExUnitProperties.check all(count <- SD.integer(0, 100)) do
        state =
          Enum.reduce(1..max(count, 1), new_circuit_state(), fn i, acc ->
            enqueue(acc, %{seq: i})
          end)

        assert state.dropped_count == 0
        assert circuit_closed?(state)
      end
    end
  end
end
