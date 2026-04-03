defmodule Indrajaal.Cybernetic.OODA.DecideTest do
  @moduledoc """
  TDG tests for Indrajaal.Cybernetic.OODA.Decide pure module.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cybernetic.OODA.Decide

  describe "Decide module" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Decide)
    end

    test "new/1 is exported" do
      assert function_exported?(Decide, :new, 1)
    end

    test "decide/2 is exported" do
      assert function_exported?(Decide, :decide, 2)
    end

    test "defer_decision/1 is exported" do
      assert function_exported?(Decide, :defer_decision, 1)
    end

    test "evaluate/3 is exported" do
      assert function_exported?(Decide, :evaluate, 3)
    end

    test "determine_mode/1 is exported" do
      assert function_exported?(Decide, :determine_mode, 1)
    end

    test "explain/1 is exported" do
      assert function_exported?(Decide, :explain, 1)
    end

    test "stats/1 is exported" do
      assert function_exported?(Decide, :stats, 1)
    end

    test "summary/1 is exported" do
      assert function_exported?(Decide, :summary, 1)
    end
  end

  describe "Decide new/1" do
    test "creates decide context with options" do
      result = Decide.new(mode: :autonomous, timeout: 5000)
      assert is_map(result)
    end

    test "creates decide context with empty options" do
      result = Decide.new([])
      assert is_map(result)
    end
  end

  describe "Decide stats/1" do
    test "returns stats map" do
      ctx = Decide.new([])
      stats = Decide.stats(ctx)
      assert is_map(stats)
    end
  end

  describe "Decide summary/1" do
    test "returns summary map" do
      ctx = Decide.new([])
      summary = Decide.summary(ctx)
      assert is_map(summary)
    end
  end

  describe "Decide determine_mode/1" do
    test "returns a mode atom" do
      ctx = Decide.new([])
      mode = Decide.determine_mode(ctx)
      assert is_atom(mode)
    end
  end
end
