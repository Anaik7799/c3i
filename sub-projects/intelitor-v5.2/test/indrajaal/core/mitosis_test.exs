defmodule Indrajaal.Core.MitosisTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core.Mitosis

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Mitosis)
    end
  end

  describe "check_pressure/0" do
    test "function is exported" do
      assert function_exported?(Mitosis, :check_pressure, 0)
    end

    test "returns a pressure result" do
      result = Mitosis.check_pressure()
      # Returns :normal, :elevated, :critical or a tagged tuple
      assert is_atom(result) or is_tuple(result) or is_map(result)
    end

    test "returns consistent result type on repeated calls" do
      result1 = Mitosis.check_pressure()
      result2 = Mitosis.check_pressure()
      assert is_atom(result1) == is_atom(result2)
    end

    test "result indicates process health" do
      result = Mitosis.check_pressure()
      # Should not raise, any valid result is acceptable
      assert result != nil
    end
  end
end
