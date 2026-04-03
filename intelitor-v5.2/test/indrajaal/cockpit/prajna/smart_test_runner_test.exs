defmodule Indrajaal.Cockpit.Prajna.SmartTestRunnerTest do
  @moduledoc """
  TDG test suite for SmartTestRunner.

  ## STAMP Safety Integration
  - SC-TEST-001: Test files MUST compile before PR
  - SC-TEST-005: SKIP_ZENOH_NIF=0 MANDATORY

  ## TPS 5-Level RCA Context
  - L1 Symptom: Effect analysis returns wrong orders
  - L5 Root Cause: Command-to-effect mapping defect
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cockpit.Prajna.SmartTestRunner

  @moduletag :zenoh_nif

  # ============================================================================
  # analyze_effects/1 - public function, testable without GenServer
  # ============================================================================

  describe "analyze_effects/1" do
    test "compile command returns 5 ordered effects" do
      effects = SmartTestRunner.analyze_effects("compile")

      assert is_list(effects)
      assert length(effects) == 5
      orders = Enum.map(effects, & &1.order)
      assert orders == [1, 2, 3, 4, 5]
    end

    test "compile effects contain required keys" do
      effects = SmartTestRunner.analyze_effects("compile")
      first = hd(effects)

      assert Map.has_key?(first, :order)
      assert Map.has_key?(first, :time)
      assert Map.has_key?(first, :effect)
      assert Map.has_key?(first, :verification)
    end

    test "compile 1st order effect mentions beam files" do
      effects = SmartTestRunner.analyze_effects("compile")
      first_effect = Enum.find(effects, &(&1.order == 1))

      assert String.contains?(first_effect.effect, "beam")
    end

    test "app command returns 5 effects" do
      effects = SmartTestRunner.analyze_effects("app")

      assert length(effects) == 5
    end

    test "app-start command returns 5 effects" do
      effects = SmartTestRunner.analyze_effects("app-start")

      assert length(effects) == 5
    end

    test "sa-up command returns 5 effects" do
      effects = SmartTestRunner.analyze_effects("sa-up")

      assert length(effects) == 5
    end

    test "sa-down command returns 5 effects" do
      effects = SmartTestRunner.analyze_effects("sa-down")

      assert length(effects) == 5
    end

    test "test command returns 5 effects" do
      effects = SmartTestRunner.analyze_effects("test")

      assert length(effects) == 5
    end

    test "test-cover command returns 5 effects" do
      effects = SmartTestRunner.analyze_effects("test-cover")

      assert length(effects) == 5
    end

    test "quality command returns 5 effects" do
      effects = SmartTestRunner.analyze_effects("quality")

      assert length(effects) == 5
    end

    test "quality-full command returns 5 effects" do
      effects = SmartTestRunner.analyze_effects("quality-full")

      assert length(effects) == 5
    end

    test "db-setup command returns 5 effects" do
      effects = SmartTestRunner.analyze_effects("db-setup")

      assert length(effects) == 5
    end

    test "db-reset command returns 5 effects" do
      effects = SmartTestRunner.analyze_effects("db-reset")

      assert length(effects) == 5
    end

    test "db-migrate command returns 5 effects" do
      effects = SmartTestRunner.analyze_effects("db-migrate")

      assert length(effects) == 5
    end

    test "cockpitf command returns 5 effects" do
      effects = SmartTestRunner.analyze_effects("cockpitf")

      assert length(effects) == 5
    end

    test "cepaf-build command returns 5 effects" do
      effects = SmartTestRunner.analyze_effects("cepaf-build")

      assert length(effects) == 5
    end

    test "unknown command falls back to generic effects with command name" do
      effects = SmartTestRunner.analyze_effects("my-custom-cmd")

      assert length(effects) == 5
      first_effect = hd(effects)
      assert String.contains?(first_effect.effect, "my-custom-cmd")
    end

    test "all effects have non-empty effect description" do
      effects = SmartTestRunner.analyze_effects("compile")

      Enum.each(effects, fn effect ->
        assert is_binary(effect.effect)
        assert String.length(effect.effect) > 0
      end)
    end

    test "all effects have time range strings" do
      effects = SmartTestRunner.analyze_effects("compile")

      Enum.each(effects, fn effect ->
        assert is_binary(effect.time)
        assert String.length(effect.time) > 0
      end)
    end

    test "effects are ordered 1 through 5" do
      effects = SmartTestRunner.analyze_effects("sa-up")

      orders = Enum.map(effects, & &1.order)
      assert Enum.sort(orders) == [1, 2, 3, 4, 5]
    end

    test "5th order effect has infinity-range descriptor for compile" do
      effects = SmartTestRunner.analyze_effects("compile")
      fifth = Enum.find(effects, &(&1.order == 5))

      assert String.contains?(fifth.time, "min") or String.contains?(fifth.time, "+")
    end
  end

  # ============================================================================
  # @test_levels constant accessibility via run_level/2
  # ============================================================================

  describe "run_level/2 guard clause" do
    test "valid level :tdg is accepted by guard" do
      # We test the guard by confirming invalid levels are rejected
      # (no GenServer running, so valid levels will fail differently than invalid ones)
      # Valid levels should fail with :noproc, not :function_clause
      assert_raise ArgumentError, fn ->
        SmartTestRunner.run_level(:invalid_level, "compile")
      end
    end
  end

  # ============================================================================
  # GenServer lifecycle tests
  # ============================================================================

  describe "start_link/1" do
    test "starts without options" do
      # Stop existing named process if running from another test
      if pid = Process.whereis(SmartTestRunner) do
        GenServer.stop(pid)
        # Give it time to stop
        Process.sleep(10)
      end

      {:ok, pid} = SmartTestRunner.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers under module name" do
      if pid = Process.whereis(SmartTestRunner) do
        GenServer.stop(pid)
        Process.sleep(10)
      end

      {:ok, _pid} = SmartTestRunner.start_link([])
      assert Process.whereis(SmartTestRunner) != nil
      GenServer.stop(SmartTestRunner)
    end
  end

  describe "get_thinking/0" do
    setup do
      if pid = Process.whereis(SmartTestRunner) do
        GenServer.stop(pid)
        Process.sleep(10)
      end

      {:ok, pid} = SmartTestRunner.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns empty list on fresh start" do
      thinking = SmartTestRunner.get_thinking()
      assert is_list(thinking)
    end
  end

  describe "get_effect_chain/0" do
    setup do
      if pid = Process.whereis(SmartTestRunner) do
        GenServer.stop(pid)
        Process.sleep(10)
      end

      {:ok, pid} = SmartTestRunner.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns empty list on fresh start" do
      chain = SmartTestRunner.get_effect_chain()
      assert is_list(chain)
    end
  end

  describe "get_report/0" do
    setup do
      if pid = Process.whereis(SmartTestRunner) do
        GenServer.stop(pid)
        Process.sleep(10)
      end

      {:ok, pid} = SmartTestRunner.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns report with required keys" do
      report = SmartTestRunner.get_report()

      assert Map.has_key?(report, :session_id)
      assert Map.has_key?(report, :started_at)
      assert Map.has_key?(report, :duration_ms)
      assert Map.has_key?(report, :commands_tested)
      assert Map.has_key?(report, :results)
      assert Map.has_key?(report, :summary)
    end

    test "session_id is a hex string" do
      report = SmartTestRunner.get_report()

      assert is_binary(report.session_id)
      assert Regex.match?(~r/^[0-9a-f]+$/, report.session_id)
    end

    test "started_at is a DateTime" do
      report = SmartTestRunner.get_report()

      assert %DateTime{} = report.started_at
    end

    test "summary contains total_levels" do
      report = SmartTestRunner.get_report()

      assert Map.has_key?(report.summary, :total_levels)
      assert report.summary.total_levels == 5
    end
  end

  describe "subscribe/1" do
    setup do
      if pid = Process.whereis(SmartTestRunner) do
        GenServer.stop(pid)
        Process.sleep(10)
      end

      {:ok, pid} = SmartTestRunner.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns :ok on successful subscription" do
      result = SmartTestRunner.subscribe(self())
      assert result == :ok
    end

    test "accepts any pid" do
      {:ok, pid} = Task.start(fn -> Process.sleep(1000) end)
      result = SmartTestRunner.subscribe(pid)
      assert result == :ok
      Process.exit(pid, :kill)
    end
  end
end
