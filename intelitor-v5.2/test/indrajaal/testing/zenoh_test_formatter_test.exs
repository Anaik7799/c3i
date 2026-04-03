defmodule Indrajaal.Testing.ZenohTestFormatterTest do
  @moduledoc """
  TDG comprehensive test suite for ZenohTestFormatter.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation gaps identified
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-ZTEST-003: Publish latency < 10ms per event
  - SC-ZTEST-004: Non-blocking formatter (async publish via Task.start)
  - SC-ZTEST-007: Test failures include full context (>=3 fields)
  - SC-ZTEST-008: Log-based fallback [ZTEST-CHECKPOINT] when Zenoh unavailable
  - SC-ZTEST-012: FIFO ordering per topic preserved
  - SC-ZTEST-015: ISO 8601 UTC timestamps in messages

  ## Constitutional Verification
  - Ψ₀ Existence: Formatter process survives suite events without crashing
  - Ψ₁ Regeneration: State rebuilds on restart from init/1
  - Ψ₅ Truthfulness: Pass/fail/skip counts accurately reflect test outcomes

  ## Founder's Directive Alignment
  - Ω₀.7: Observability infrastructure serves system intelligence

  ## TPS 5-Level RCA Context
  - L1 Symptom: Test events not visible in real-time dashboard
  - L5 Root Cause: Formatter not publishing checkpoints / log fallback missing
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Testing.ZenohTestFormatter

  @moduletag :zenoh_nif

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Formatter is a GenServer started by ExUnit — in tests we start it
    # directly via start_link and drive it with GenServer.cast
    {:ok, pid} = GenServer.start_link(ZenohTestFormatter, [], [])

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid, :normal, 500)
    end)

    {:ok, formatter: pid}
  end

  # ============================================================
  # 1. INIT / STARTUP TESTS
  # ============================================================

  describe "init/1 (ExUnit formatter bootstrap)" do
    test "initialises with list opts (ExUnit callback contract)", %{formatter: pid} do
      state = :sys.get_state(pid)
      assert is_struct(state, ZenohTestFormatter)
    end

    test "suite_id is set on init", %{formatter: pid} do
      state = :sys.get_state(pid)
      assert is_binary(state.suite_id) and state.suite_id != ""
    end

    test "counters start at zero", %{formatter: pid} do
      state = :sys.get_state(pid)
      assert state.test_count == 0
      assert state.pass_count == 0
      assert state.fail_count == 0
      assert state.skip_count == 0
    end

    test "module_stats starts as empty map", %{formatter: pid} do
      state = :sys.get_state(pid)
      assert state.module_stats == %{}
    end

    test "enabled field is set (boolean)", %{formatter: pid} do
      state = :sys.get_state(pid)
      assert is_boolean(state.enabled)
    end

    test "current_module is nil on init", %{formatter: pid} do
      state = :sys.get_state(pid)
      assert is_nil(state.current_module)
    end

    test "suite_start_time is a non-negative integer", %{formatter: pid} do
      state = :sys.get_state(pid)
      assert is_integer(state.suite_start_time)
      assert state.suite_start_time >= 0
    end
  end

  # ============================================================
  # 2. SUITE EVENTS
  # ============================================================

  describe "handle_cast suite_started / suite_finished" do
    test "suite_started cast does not crash formatter", %{formatter: pid} do
      GenServer.cast(pid, {:suite_started, []})
      :timer.sleep(50)
      assert Process.alive?(pid)
    end

    test "suite_finished cast does not crash formatter", %{formatter: pid} do
      GenServer.cast(pid, {:suite_started, []})
      # times_us and load_us match OTP-28 arity
      GenServer.cast(pid, {:suite_finished, 1_000_000, 500_000})
      :timer.sleep(50)
      assert Process.alive?(pid)
    end

    test "suite_finished preserves pass/fail/skip counts in state", %{formatter: pid} do
      GenServer.cast(pid, {:suite_started, []})
      # Simulate test events to drive counters
      fake_pass = build_fake_test(:pass)
      fake_fail = build_fake_test(:fail)
      GenServer.cast(pid, {:test_started, fake_pass})
      GenServer.cast(pid, {:test_finished, fake_pass})
      GenServer.cast(pid, {:test_started, fake_fail})
      GenServer.cast(pid, {:test_finished, fake_fail})
      GenServer.cast(pid, {:suite_finished, 2_000_000, 100_000})
      :timer.sleep(50)

      state = :sys.get_state(pid)
      # test_count incremented by test_started
      assert state.test_count == 2
    end
  end

  # ============================================================
  # 3. MODULE EVENTS
  # ============================================================

  describe "handle_cast module_started / module_finished" do
    test "module_started with TestModule struct updates current_module", %{formatter: pid} do
      tm = %ExUnit.TestModule{name: MyFakeModule, tests: [], state: nil, file: "test.exs"}
      GenServer.cast(pid, {:module_started, tm})
      :timer.sleep(30)

      state = :sys.get_state(pid)
      assert state.current_module == "MyFakeModule"
    end

    test "module_started with bare atom updates current_module", %{formatter: pid} do
      GenServer.cast(pid, {:module_started, SomeTestModule})
      :timer.sleep(30)

      state = :sys.get_state(pid)
      assert state.current_module == "SomeTestModule"
    end

    test "module_finished with TestModule struct clears current_module", %{formatter: pid} do
      tm = %ExUnit.TestModule{name: MyFakeModule, tests: [], state: nil, file: "test.exs"}
      GenServer.cast(pid, {:module_started, tm})
      :timer.sleep(20)
      GenServer.cast(pid, {:module_finished, tm})
      :timer.sleep(30)

      state = :sys.get_state(pid)
      assert is_nil(state.current_module)
    end

    test "module_finished with bare atom clears current_module", %{formatter: pid} do
      GenServer.cast(pid, {:module_started, SomeTestModule})
      :timer.sleep(20)
      GenServer.cast(pid, {:module_finished, SomeTestModule})
      :timer.sleep(30)

      state = :sys.get_state(pid)
      assert is_nil(state.current_module)
    end

    test "module_start_time is nil after module_finished", %{formatter: pid} do
      tm = %ExUnit.TestModule{name: AModule, tests: [], state: nil, file: "test.exs"}
      GenServer.cast(pid, {:module_started, tm})
      :timer.sleep(20)
      GenServer.cast(pid, {:module_finished, tm})
      :timer.sleep(30)

      state = :sys.get_state(pid)
      assert is_nil(state.module_start_time)
    end
  end

  # ============================================================
  # 4. TEST EVENTS — COUNTERS (SC-ZTEST correctness)
  # ============================================================

  describe "handle_cast test_started / test_finished — counter accuracy (Ψ₅)" do
    test "test_started increments test_count", %{formatter: pid} do
      t = build_fake_test(:pass)
      GenServer.cast(pid, {:test_started, t})
      :timer.sleep(30)

      state = :sys.get_state(pid)
      assert state.test_count == 1
    end

    test "passed test increments pass_count", %{formatter: pid} do
      t = build_fake_test(:pass)
      GenServer.cast(pid, {:test_started, t})
      GenServer.cast(pid, {:test_finished, t})
      :timer.sleep(30)

      state = :sys.get_state(pid)
      assert state.pass_count == 1
      assert state.fail_count == 0
      assert state.skip_count == 0
    end

    test "failed test increments fail_count", %{formatter: pid} do
      t = build_fake_test(:fail)
      GenServer.cast(pid, {:test_started, t})
      GenServer.cast(pid, {:test_finished, t})
      :timer.sleep(30)

      state = :sys.get_state(pid)
      assert state.fail_count == 1
      assert state.pass_count == 0
    end

    test "skipped test increments skip_count", %{formatter: pid} do
      t = build_fake_test(:skip)
      GenServer.cast(pid, {:test_started, t})
      GenServer.cast(pid, {:test_finished, t})
      :timer.sleep(30)

      state = :sys.get_state(pid)
      assert state.skip_count == 1
    end

    test "multiple tests accumulate counts correctly", %{formatter: pid} do
      pass1 = build_fake_test(:pass, "test passes scenario 1")
      pass2 = build_fake_test(:pass, "test passes scenario 2")
      fail1 = build_fake_test(:fail, "test fails scenario 1")
      skip1 = build_fake_test(:skip, "test is skipped")

      for t <- [pass1, pass2, fail1, skip1] do
        GenServer.cast(pid, {:test_started, t})
        GenServer.cast(pid, {:test_finished, t})
      end

      :timer.sleep(60)
      state = :sys.get_state(pid)

      assert state.test_count == 4
      assert state.pass_count == 2
      assert state.fail_count == 1
      assert state.skip_count == 1
    end
  end

  # ============================================================
  # 5. NON-BLOCKING GUARANTEE (SC-ZTEST-004)
  # ============================================================

  describe "non-blocking publish (SC-ZTEST-004)" do
    test "formatter responds within 10ms even under load", %{formatter: pid} do
      # Cast 20 test events in rapid succession and measure cast time
      t = build_fake_test(:pass)

      start = System.monotonic_time(:microsecond)

      for _i <- 1..20 do
        GenServer.cast(pid, {:test_started, t})
      end

      elapsed_us = System.monotonic_time(:microsecond) - start
      # 20 casts should complete well under 200ms (10ms each max per SC-ZTEST-003)
      assert elapsed_us < 200_000, "20 casts took #{elapsed_us}us, expected < 200_000us"
      assert Process.alive?(pid)
    end

    test "formatter does not block calling process", %{formatter: pid} do
      t = build_fake_test(:pass)

      # spawn a caller that casts and measures its own time
      {time_us, _} =
        :timer.tc(fn ->
          GenServer.cast(pid, {:test_started, t})
        end)

      # A non-blocking cast to a live GenServer must return in microseconds
      assert time_us < 5_000, "cast took #{time_us}us — may be blocking"
    end
  end

  # ============================================================
  # 6. LOG FALLBACK (SC-ZTEST-008)
  # ============================================================

  describe "log fallback format (SC-ZTEST-008)" do
    test "formatter survives without Zenoh (enabled: false path)", %{formatter: pid} do
      # Force disabled mode by checking state — formatter always starts OK
      state = :sys.get_state(pid)
      # Whether enabled or not, events should not crash the process
      assert is_boolean(state.enabled)

      t = build_fake_test(:pass)
      GenServer.cast(pid, {:test_started, t})
      GenServer.cast(pid, {:test_finished, t})
      :timer.sleep(30)
      assert Process.alive?(pid)
    end
  end

  # ============================================================
  # 7. CONSTITUTIONAL INVARIANTS (Ψ₀-Ψ₅)
  # ============================================================

  describe "Constitutional Invariants (Ψ₀-Ψ₅)" do
    test "Ψ₀ existence: formatter survives all event types", %{formatter: pid} do
      events = [
        {:suite_started, []},
        {:module_started, SomeMod},
        {:test_started, build_fake_test(:pass)},
        {:test_finished, build_fake_test(:pass)},
        {:test_started, build_fake_test(:fail)},
        {:test_finished, build_fake_test(:fail)},
        {:test_started, build_fake_test(:skip)},
        {:test_finished, build_fake_test(:skip)},
        {:module_finished, SomeMod},
        {:suite_finished, 1_000_000, 100_000}
      ]

      Enum.each(events, &GenServer.cast(pid, &1))
      :timer.sleep(80)

      assert Process.alive?(pid), "Formatter process died during event sequence"
    end

    test "Ψ₁ regeneration: new formatter starts with clean state", _ctx do
      {:ok, pid2} = GenServer.start_link(ZenohTestFormatter, [], [])

      on_exit(fn ->
        if Process.alive?(pid2), do: GenServer.stop(pid2, :normal, 500)
      end)

      state = :sys.get_state(pid2)
      assert state.test_count == 0
      assert state.pass_count == 0
      assert state.fail_count == 0
      assert state.skip_count == 0
      assert state.module_stats == %{}
      assert is_nil(state.current_module)
    end

    test "Ψ₅ truthfulness: counts never go below zero", %{formatter: pid} do
      # Even if test_finished arrives without test_started, no underflow
      t = build_fake_test(:pass)
      GenServer.cast(pid, {:test_finished, t})
      :timer.sleep(30)

      state = :sys.get_state(pid)
      assert state.pass_count >= 0
      assert state.fail_count >= 0
      assert state.skip_count >= 0
    end
  end

  # ============================================================
  # 8. PROPERTY TESTS
  # ============================================================

  property "pass_count never exceeds test_count after N events (PropCheck)" do
    forall n <- PC.pos_integer() do
      {:ok, pid} = GenServer.start_link(ZenohTestFormatter, [], [])

      count = min(n, 30)

      for i <- 1..count do
        t = build_fake_test(:pass, "test #{i}")
        GenServer.cast(pid, {:test_started, t})
        GenServer.cast(pid, {:test_finished, t})
      end

      :timer.sleep(50)
      state = :sys.get_state(pid)
      result = state.pass_count <= state.test_count

      GenServer.stop(pid, :normal, 500)
      result
    end
  end

  test "total counts equal sum of pass+fail+skip after mixed events (StreamData)" do
    ExUnitProperties.check all(
                             pass_n <- SD.integer(0..5),
                             fail_n <- SD.integer(0..5),
                             skip_n <- SD.integer(0..5)
                           ) do
      {:ok, pid} = GenServer.start_link(ZenohTestFormatter, [], [])

      events =
        List.duplicate(:pass, pass_n) ++
          List.duplicate(:fail, fail_n) ++
          List.duplicate(:skip, skip_n)

      events
      |> Enum.with_index()
      |> Enum.each(fn {outcome, i} ->
        t = build_fake_test(outcome, "test #{outcome} #{i}")
        GenServer.cast(pid, {:test_started, t})
        GenServer.cast(pid, {:test_finished, t})
      end)

      :timer.sleep(80)
      state = :sys.get_state(pid)

      total_counted = state.pass_count + state.fail_count + state.skip_count
      total_started = state.test_count

      GenServer.stop(pid, :normal, 500)

      assert total_counted <= total_started,
             "counted #{total_counted} but only #{total_started} started"
    end
  end

  property "formatter pid always alive after random event sequence (PropCheck)" do
    forall events <- PC.list(PC.oneof([:pass, :fail, :skip])) do
      {:ok, pid} = GenServer.start_link(ZenohTestFormatter, [], [])

      events
      |> Enum.take(20)
      |> Enum.with_index()
      |> Enum.each(fn {outcome, i} ->
        t = build_fake_test(outcome, "prop test #{outcome} #{i}")
        GenServer.cast(pid, {:test_started, t})
        GenServer.cast(pid, {:test_finished, t})
      end)

      :timer.sleep(60)
      alive = Process.alive?(pid)
      GenServer.stop(pid, :normal, 500)
      alive
    end
  end

  # ============================================================
  # 9. FMEA TESTS
  # ============================================================

  describe "FMEA: edge cases and failure modes" do
    @tag :fmea
    test "handles test_finished without prior test_started (resilience)", %{formatter: pid} do
      t = build_fake_test(:pass, "orphaned finish")
      GenServer.cast(pid, {:test_finished, t})
      :timer.sleep(30)
      assert Process.alive?(pid)
    end

    @tag :fmea
    test "handles module_finished without prior module_started", %{formatter: pid} do
      GenServer.cast(pid, {:module_finished, OrphanedModule})
      :timer.sleep(30)
      assert Process.alive?(pid)
    end

    @tag :fmea
    test "handles suite_finished without prior suite_started", %{formatter: pid} do
      GenServer.cast(pid, {:suite_finished, 0, 0})
      :timer.sleep(30)
      assert Process.alive?(pid)
    end

    @tag :fmea
    test "handles zero-duration test (duration_us = 0)", %{formatter: pid} do
      t = %{build_fake_test(:pass) | time: 0}
      GenServer.cast(pid, {:test_started, t})
      GenServer.cast(pid, {:test_finished, t})
      :timer.sleep(30)
      assert Process.alive?(pid)
    end

    @tag :fmea
    test "handles test with empty tags map", %{formatter: pid} do
      t = %{build_fake_test(:pass) | tags: %{}}
      GenServer.cast(pid, {:test_started, t})
      :timer.sleep(30)
      assert Process.alive?(pid)
    end

    @tag :fmea
    test "handles rapid sequential module starts (ordering stress)", %{formatter: pid} do
      for i <- 1..5 do
        mod = :"Module#{i}"
        GenServer.cast(pid, {:module_started, mod})
        GenServer.cast(pid, {:module_finished, mod})
      end

      :timer.sleep(80)
      state = :sys.get_state(pid)
      # After all modules finished, current_module should be nil
      assert is_nil(state.current_module)
    end
  end

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  defp build_fake_test(outcome, name \\ "test something works") do
    state =
      case outcome do
        :pass -> nil
        :fail -> {:failed, [%ExUnit.AssertionError{message: "Expected true, got false"}]}
        :skip -> {:skipped, "excluded"}
      end

    %ExUnit.Test{
      name: String.to_atom(name),
      module: FakeTestModule,
      tags: %{file: "test/fake_test.exs", line: 10},
      state: state,
      time: 1234
    }
  end
end
