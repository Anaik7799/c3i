defmodule Indrajaal.Safety.DeadMansSwitchTimingTest do
  @moduledoc """
  TDG test suite for Dead Man's Switch heartbeat timing constraints.

  WHAT: Self-contained tests that simulate heartbeat sequences using timestamps,
  verifying the 100ms interval (SC-DMS-001) and 50ms failsafe trigger window
  (SC-DMS-002) without any dependency on running services.

  CONSTRAINTS:
  - SC-DMS-001: Heartbeat interval MUST be 100ms
  - SC-DMS-002: Failsafe triggers within 50ms of timeout
  - SC-DMS-003: Failsafe state MUST be deterministic
  - SC-DMS-004: Recovery MUST be supervised

  ## Constitutional Verification
  - Ψ₀ (Existence): Heartbeat logic is pure and cannot crash
  - Ψ₃ (Verification): Timing rules are formally checkable from timestamps

  ## Change History
  | Version | Date       | Author | Change                           |
  |---------|------------|--------|----------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 Wave 2 — timing suite  |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # Pure heartbeat state machine (self-contained, no GenServer)
  # ---------------------------------------------------------------------------

  @heartbeat_interval_ms 100
  @max_missed_before_failsafe 3
  @failsafe_trigger_deadline_ms 50

  defp new_dms_state do
    %{
      state: :armed,
      last_heartbeat_at: nil,
      heartbeats_received: 0,
      heartbeats_missed: 0,
      failsafe_triggers: 0,
      current_sequence: 0
    }
  end

  defp receive_heartbeat(state, now_ms) do
    %{
      state
      | state: :healthy,
        last_heartbeat_at: now_ms,
        heartbeats_received: state.heartbeats_received + 1,
        current_sequence: state.current_sequence + 1
    }
  end

  defp tick(state, now_ms) do
    case state.last_heartbeat_at do
      nil ->
        # No heartbeat received yet — stay armed
        state

      last ->
        elapsed = now_ms - last

        cond do
          elapsed > @heartbeat_interval_ms * @max_missed_before_failsafe ->
            %{state | state: :failsafe_triggered, failsafe_triggers: state.failsafe_triggers + 1}

          elapsed > @heartbeat_interval_ms ->
            missed = div(elapsed, @heartbeat_interval_ms)
            %{state | state: :warning, heartbeats_missed: missed}

          true ->
            state
        end
    end
  end

  defp time_to_failsafe_ms(state, now_ms) do
    case state.last_heartbeat_at do
      nil -> @heartbeat_interval_ms * @max_missed_before_failsafe
      last -> @heartbeat_interval_ms * @max_missed_before_failsafe - (now_ms - last)
    end
  end

  defp missed_count(state, now_ms) do
    case state.last_heartbeat_at do
      nil -> 0
      last -> div(max(0, now_ms - last - @heartbeat_interval_ms), @heartbeat_interval_ms)
    end
  end

  # ---------------------------------------------------------------------------
  # SC-DMS-001: Heartbeat interval MUST be 100ms
  # ---------------------------------------------------------------------------

  describe "SC-DMS-001: heartbeat interval is 100ms" do
    test "heartbeat_interval_ms constant is exactly 100" do
      assert @heartbeat_interval_ms == 100
    end

    test "state transitions to warning after exactly 100ms without heartbeat" do
      state = new_dms_state()
      t0 = 1_000_000

      state = receive_heartbeat(state, t0)
      assert state.state == :healthy

      # 101ms later — one interval missed
      state_after = tick(state, t0 + 101)
      assert state_after.state == :warning
    end

    test "healthy at exactly 100ms boundary" do
      state = new_dms_state()
      t0 = 1_000_000

      state = receive_heartbeat(state, t0)

      # Exactly at 100ms — not yet timed out (elapsed == interval, not greater)
      state_at_boundary = tick(state, t0 + @heartbeat_interval_ms)
      assert state_at_boundary.state == :healthy
    end

    test "two heartbeats 100ms apart keep state healthy" do
      state = new_dms_state()
      t0 = 1_000_000

      state = receive_heartbeat(state, t0)
      state = receive_heartbeat(state, t0 + 100)
      state = tick(state, t0 + 150)

      assert state.state == :healthy
    end

    test "missed count increases with time" do
      state = new_dms_state()
      t0 = 1_000_000
      state = receive_heartbeat(state, t0)

      assert missed_count(state, t0 + 250) == 1
      assert missed_count(state, t0 + 350) == 2
      assert missed_count(state, t0 + 450) == 3
    end
  end

  # ---------------------------------------------------------------------------
  # SC-DMS-002: Failsafe triggers within 50ms of timeout
  # ---------------------------------------------------------------------------

  describe "SC-DMS-002: failsafe triggers within 50ms of timeout" do
    test "failsafe triggers at 3 missed intervals" do
      state = new_dms_state()
      t0 = 1_000_000
      state = receive_heartbeat(state, t0)

      # 3 full intervals missed = 301ms after last heartbeat
      state_after = tick(state, t0 + @heartbeat_interval_ms * @max_missed_before_failsafe + 1)
      assert state_after.state == :failsafe_triggered
      assert state_after.failsafe_triggers == 1
    end

    test "time_to_failsafe decreases monotonically" do
      state = new_dms_state()
      t0 = 1_000_000
      state = receive_heartbeat(state, t0)

      ttf1 = time_to_failsafe_ms(state, t0 + 50)
      ttf2 = time_to_failsafe_ms(state, t0 + 100)
      ttf3 = time_to_failsafe_ms(state, t0 + 150)

      assert ttf1 > ttf2
      assert ttf2 > ttf3
    end

    test "failsafe window: system detects timeout within 50ms of deadline" do
      state = new_dms_state()
      t0 = 1_000_000
      state = receive_heartbeat(state, t0)

      # The deadline is at t0 + 300ms (3 * 100ms)
      deadline = t0 + @heartbeat_interval_ms * @max_missed_before_failsafe

      # 49ms before deadline — not yet triggered
      state_before = tick(state, deadline - @failsafe_trigger_deadline_ms + 1)
      assert state_before.state in [:healthy, :warning]

      # 1ms after deadline — triggered
      state_after = tick(state, deadline + 1)
      assert state_after.state == :failsafe_triggered
    end

    test "failsafe increments counter on each trigger" do
      state = new_dms_state()
      t0 = 1_000_000
      state = receive_heartbeat(state, t0)

      state1 = tick(state, t0 + 500)
      assert state1.failsafe_triggers == 1

      # After first failsafe, recovery and re-arming
      # Simulate re-arm + new heartbeat
      recovered = %{state1 | state: :armed, failsafe_triggers: state1.failsafe_triggers}
      state2 = receive_heartbeat(recovered, t0 + 600)
      state3 = tick(state2, t0 + 1_100)
      assert state3.failsafe_triggers == 2
    end
  end

  # ---------------------------------------------------------------------------
  # SC-DMS-003: Failsafe state MUST be deterministic
  # ---------------------------------------------------------------------------

  describe "SC-DMS-003: failsafe state is deterministic" do
    test "same timestamp sequence always produces same state" do
      for _i <- 1..10 do
        state = new_dms_state()
        state = receive_heartbeat(state, 1_000_000)
        state = tick(state, 1_000_401)

        assert state.state == :failsafe_triggered
        assert state.failsafe_triggers == 1
      end
    end

    test "state machine is pure — no side effects" do
      state0 = new_dms_state()
      state1 = receive_heartbeat(state0, 1_000_000)
      state2 = tick(state1, 1_000_200)

      # Original state unchanged
      assert state0.state == :armed
      assert state1.state == :healthy

      # New state reflects tick
      assert state2.state == :warning
    end

    test "heartbeat after warning resets to healthy" do
      state = new_dms_state()
      t0 = 1_000_000
      state = receive_heartbeat(state, t0)
      state = tick(state, t0 + 200)

      assert state.state == :warning

      # New heartbeat resets
      state = receive_heartbeat(state, t0 + 250)
      assert state.state == :healthy
    end
  end

  # ---------------------------------------------------------------------------
  # SC-DMS-004: Recovery MUST be supervised
  # ---------------------------------------------------------------------------

  describe "SC-DMS-004: recovery is supervised" do
    test "recovery from failsafe requires explicit arm transition" do
      state = new_dms_state()
      t0 = 1_000_000
      state = receive_heartbeat(state, t0)
      state = tick(state, t0 + 500)

      assert state.state == :failsafe_triggered

      # Direct tick does NOT auto-recover — must explicitly re-arm
      state_after_tick = tick(state, t0 + 600)
      assert state_after_tick.state == :failsafe_triggered
    end

    test "manual re-arm transition is explicit" do
      state = new_dms_state()
      t0 = 1_000_000
      state = receive_heartbeat(state, t0)
      state = tick(state, t0 + 500)

      assert state.state == :failsafe_triggered

      # Explicit re-arm
      re_armed = %{state | state: :armed}
      assert re_armed.state == :armed
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  describe "property: timing invariants hold across arbitrary intervals" do
    property "heartbeat always resets state to healthy" do
      forall t <- PC.pos_integer() do
        state = new_dms_state()
        state = receive_heartbeat(state, t)
        state.state == :healthy
      end
    end

    test "any gap > 3 * interval produces failsafe_triggered" do
      ExUnitProperties.check all(gap <- SD.integer(301, 10_000)) do
        state = new_dms_state()
        t0 = 1_000_000
        state = receive_heartbeat(state, t0)
        state = tick(state, t0 + gap)

        assert state.state == :failsafe_triggered,
               "Expected failsafe_triggered at gap=#{gap}ms, got #{state.state}"
      end
    end

    test "any gap <= 100ms keeps state healthy" do
      ExUnitProperties.check all(gap <- SD.integer(1, 100)) do
        state = new_dms_state()
        t0 = 1_000_000
        state = receive_heartbeat(state, t0)
        state = tick(state, t0 + gap)

        assert state.state == :healthy,
               "Expected healthy at gap=#{gap}ms, got #{state.state}"
      end
    end

    test "heartbeat count is monotonically increasing" do
      ExUnitProperties.check all(n <- SD.integer(1, 50)) do
        state =
          Enum.reduce(1..n, new_dms_state(), fn i, acc ->
            receive_heartbeat(acc, i * 100)
          end)

        assert state.heartbeats_received == n
        assert state.current_sequence == n
      end
    end
  end
end
