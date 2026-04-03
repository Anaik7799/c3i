defmodule Indrajaal.Cybernetic.OODA.ActTest do
  @moduledoc """
  TDG tests for Indrajaal.Cybernetic.OODA.Act pure module.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cybernetic.OODA.Act

  describe "Act module" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Act)
    end

    test "new/1 is exported" do
      assert function_exported?(Act, :new, 1)
    end

    test "act/2 is exported" do
      assert function_exported?(Act, :act, 2)
    end

    test "execute_action/3 is exported" do
      assert function_exported?(Act, :execute_action, 3)
    end

    test "emergency_stop/1 is exported" do
      assert function_exported?(Act, :emergency_stop, 1)
    end

    test "emergency_exit/2 is exported" do
      assert function_exported?(Act, :emergency_exit, 2)
    end

    test "check_emergency_timeout/1 is exported" do
      assert function_exported?(Act, :check_emergency_timeout, 1)
    end

    test "rollback/1 is exported" do
      assert function_exported?(Act, :rollback, 1)
    end

    test "generate_feedback/4 is exported" do
      assert function_exported?(Act, :generate_feedback, 4)
    end

    test "register_executor/3 is exported" do
      assert function_exported?(Act, :register_executor, 3)
    end

    test "stats/1 is exported" do
      assert function_exported?(Act, :stats, 1)
    end

    test "summary/1 is exported" do
      assert function_exported?(Act, :summary, 1)
    end
  end

  describe "Act new/1" do
    test "creates act context with options" do
      result = Act.new(timeout: 5000, mode: :normal)
      assert is_map(result)
    end

    test "creates act context with empty options" do
      result = Act.new([])
      assert is_map(result)
    end
  end

  describe "Act stats/1" do
    test "returns stats map" do
      ctx = Act.new([])
      stats = Act.stats(ctx)
      assert is_map(stats)
    end
  end

  describe "Act summary/1" do
    test "returns summary map" do
      ctx = Act.new([])
      summary = Act.summary(ctx)
      assert is_map(summary)
    end
  end

  describe "Act emergency_stop/1" do
    test "triggers emergency stop on act context" do
      ctx = Act.new([])
      result = Act.emergency_stop(ctx)
      assert is_map(result) or result == :ok or match?({:ok, _}, result)
    end
  end
end
