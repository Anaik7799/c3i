defmodule Indrajaal.Cockpit.Prajna.TestCockpitTest do
  @moduledoc """
  TDG test suite for Cockpit.Prajna.TestCockpit.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation verification
  - 5-Level fractal test coverage validation

  ## STAMP Safety Integration
  - SC-COV-001: Static coverage >= 100% for critical paths
  - SC-COV-006: TDG compliance mandatory
  - SC-COV-007: All 5 levels MUST pass before merge

  ## Constitutional Verification
  - Ψ₀ Existence: GenServer survives domain/level query calls
  - Ψ₃ Verification: Hash chain readable via coverage_report

  ## TPS 5-Level RCA Context
  - L1 Symptom: run_level raises FunctionClauseError for out-of-range level
  - L5 Root Cause: Guard clause `when level in 1..5` rejects non-integer or out-of-range values
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cockpit.Prajna.TestCockpit

  @moduletag :zenoh_nif

  setup do
    case Process.whereis(TestCockpit) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    Process.sleep(50)
    :ok
  end

  # ============================================================================
  # Pure data accessor functions (no GenServer required)
  # ============================================================================

  describe "domains/0" do
    test "returns a list" do
      assert is_list(TestCockpit.domains())
    end

    test "returns exactly 30 domains" do
      assert length(TestCockpit.domains()) == 30
    end

    test "contains :alarms domain" do
      assert :alarms in TestCockpit.domains()
    end

    test "contains :cockpit domain" do
      assert :cockpit in TestCockpit.domains()
    end

    test "contains :safety domain" do
      assert :safety in TestCockpit.domains()
    end

    test "contains :access_control domain" do
      assert :access_control in TestCockpit.domains()
    end

    test "contains :video domain" do
      assert :video in TestCockpit.domains()
    end

    test "all entries are atoms" do
      assert Enum.all?(TestCockpit.domains(), &is_atom/1)
    end

    test "all expected domains present" do
      domains = TestCockpit.domains()

      expected = [
        :access_control,
        :accounts,
        :alarms,
        :analytics,
        :authentication,
        :authorization,
        :billing,
        :cluster,
        :cockpit,
        :communication,
        :compliance,
        :coordination,
        :cortex,
        :cybernetic,
        :devices,
        :dispatch,
        :distributed,
        :flame,
        :identity,
        :integration,
        :knowledge,
        :maintenance,
        :mesh,
        :observability,
        :policy,
        :safety,
        :security,
        :sites,
        :validation,
        :video
      ]

      Enum.each(expected, fn d -> assert d in domains end)
    end
  end

  describe "levels/0" do
    test "returns a list" do
      assert is_list(TestCockpit.levels())
    end

    test "returns exactly 5 levels" do
      assert length(TestCockpit.levels()) == 5
    end

    test "each level has an :id key" do
      Enum.each(TestCockpit.levels(), fn level ->
        assert Map.has_key?(level, :id)
      end)
    end

    test "each level has a :name key" do
      Enum.each(TestCockpit.levels(), fn level ->
        assert Map.has_key?(level, :name)
      end)
    end

    test "each level has a :stamp key" do
      Enum.each(TestCockpit.levels(), fn level ->
        assert Map.has_key?(level, :stamp)
      end)
    end

    test "level ids are 1 through 5" do
      ids = TestCockpit.levels() |> Enum.map(& &1.id) |> Enum.sort()
      assert ids == [1, 2, 3, 4, 5]
    end

    test "level 1 is TDG" do
      level1 = Enum.find(TestCockpit.levels(), &(&1.id == 1))
      assert level1.name == "TDG"
    end

    test "level 5 is BDD" do
      level5 = Enum.find(TestCockpit.levels(), &(&1.id == 5))
      assert level5.name == "BDD"
    end

    test "each level has tools list" do
      Enum.each(TestCockpit.levels(), fn level ->
        assert Map.has_key?(level, :tools)
        assert is_list(level.tools)
      end)
    end

    test "each level has coverage_target" do
      Enum.each(TestCockpit.levels(), fn level ->
        assert Map.has_key?(level, :coverage_target)
        assert is_integer(level.coverage_target)
      end)
    end
  end

  describe "effect_orders/0" do
    test "returns a list" do
      assert is_list(TestCockpit.effect_orders())
    end

    test "returns exactly 5 effect orders" do
      assert length(TestCockpit.effect_orders()) == 5
    end

    test "each effect order has :order key" do
      Enum.each(TestCockpit.effect_orders(), fn eo ->
        assert Map.has_key?(eo, :order)
      end)
    end

    test "each effect order has :name key" do
      Enum.each(TestCockpit.effect_orders(), fn eo ->
        assert Map.has_key?(eo, :name)
      end)
    end

    test "each effect order has :time_scale key" do
      Enum.each(TestCockpit.effect_orders(), fn eo ->
        assert Map.has_key?(eo, :time_scale)
      end)
    end

    test "order numbers are 1 through 5" do
      orders = TestCockpit.effect_orders() |> Enum.map(& &1.order) |> Enum.sort()
      assert orders == [1, 2, 3, 4, 5]
    end

    test "first order is Immediate" do
      first = Enum.find(TestCockpit.effect_orders(), &(&1.order == 1))
      assert first.name == "Immediate"
    end
  end

  # ============================================================================
  # Guard clause validation (no GenServer needed)
  # ============================================================================

  describe "run_level/1 guard clause" do
    test "raises FunctionClauseError for level 0" do
      assert_raise FunctionClauseError, fn ->
        TestCockpit.run_level(0)
      end
    end

    test "raises FunctionClauseError for level 6" do
      assert_raise FunctionClauseError, fn ->
        TestCockpit.run_level(6)
      end
    end

    test "raises FunctionClauseError for negative level" do
      assert_raise FunctionClauseError, fn ->
        TestCockpit.run_level(-1)
      end
    end

    test "raises FunctionClauseError for non-integer level" do
      assert_raise FunctionClauseError, fn ->
        TestCockpit.run_level(:invalid)
      end
    end
  end

  describe "run_domain/1 guard clause" do
    test "raises FunctionClauseError for invalid domain atom" do
      assert_raise FunctionClauseError, fn ->
        TestCockpit.run_domain(:not_a_real_domain)
      end
    end

    test "raises FunctionClauseError for string domain" do
      assert_raise FunctionClauseError, fn ->
        TestCockpit.run_domain("alarms")
      end
    end

    test "raises FunctionClauseError for nil domain" do
      assert_raise FunctionClauseError, fn ->
        TestCockpit.run_domain(nil)
      end
    end
  end

  # ============================================================================
  # GenServer lifecycle
  # ============================================================================

  describe "start_link/1" do
    test "starts GenServer successfully" do
      assert {:ok, pid} = TestCockpit.start_link([])
      assert Process.alive?(pid)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "registers under module name" do
      {:ok, pid} = TestCockpit.start_link([])
      assert Process.whereis(TestCockpit) == pid
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "second start_link returns already_started error" do
      {:ok, pid} = TestCockpit.start_link([])

      assert {:error, {:already_started, ^pid}} = TestCockpit.start_link([])

      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end
  end

  describe "status/0" do
    setup do
      {:ok, pid} = TestCockpit.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns a map" do
      result = TestCockpit.status()
      assert is_map(result)
    end

    test "status map has :status key" do
      result = TestCockpit.status()
      assert Map.has_key?(result, :status)
    end
  end

  describe "coverage_report/0" do
    setup do
      {:ok, pid} = TestCockpit.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns a value without crashing" do
      result = TestCockpit.coverage_report()
      assert not is_nil(result)
    end
  end

  describe "effect_chain_analysis/0" do
    setup do
      {:ok, pid} = TestCockpit.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns a value without crashing" do
      result = TestCockpit.effect_chain_analysis()
      assert not is_nil(result)
    end
  end
end
