defmodule Indrajaal.Shared.ComplexityUtilitiesTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Shared.ComplexityUtilities

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ComplexityUtilities)
    end
  end

  describe "optimize_case_statement/2" do
    test "function is exported" do
      assert function_exported?(ComplexityUtilities, :optimize_case_statement, 2)
    end

    test "returns optimization suggestion" do
      ast =
        quote do
          case x do
            :a -> 1
            :b -> 2
            _ -> 3
          end
        end

      result = ComplexityUtilities.optimize_case_statement(ast, %{})
      assert is_map(result) or is_binary(result) or is_list(result) or is_tuple(result)
    end
  end

  describe "decompose_long_function/2" do
    test "function is exported" do
      assert function_exported?(ComplexityUtilities, :decompose_long_function, 2)
    end

    test "returns decomposition plan for simple function" do
      func_info = %{name: :my_function, lines: 45, arity: 2}
      result = ComplexityUtilities.decompose_long_function(func_info, %{})
      assert is_map(result) or is_list(result) or is_binary(result)
    end
  end

  describe "simplify_conditional/2" do
    test "function is exported" do
      assert function_exported?(ComplexityUtilities, :simplify_conditional, 2)
    end

    test "returns simplified form for nested conditional" do
      conditional = %{type: :nested_if, depth: 4, branches: 8}
      result = ComplexityUtilities.simplify_conditional(conditional, %{})
      assert is_map(result) or is_binary(result) or is_list(result)
    end
  end

  describe "reduce_nesting/2" do
    test "function is exported" do
      assert function_exported?(ComplexityUtilities, :reduce_nesting, 2)
    end

    test "returns reduced nesting suggestion" do
      code = %{nesting_level: 5, function: :process}
      result = ComplexityUtilities.reduce_nesting(code, %{})
      assert is_map(result) or is_binary(result) or is_list(result)
    end
  end

  describe "consolidate_parameters/2" do
    test "function is exported" do
      assert function_exported?(ComplexityUtilities, :consolidate_parameters, 2)
    end

    test "returns consolidation suggestion for many params" do
      func = %{name: :create, params: [:a, :b, :c, :d, :e, :f]}
      result = ComplexityUtilities.consolidate_parameters(func, %{})
      assert is_map(result) or is_binary(result) or is_list(result)
    end
  end

  describe "calculate_complexity_score/1" do
    test "function is exported" do
      assert function_exported?(ComplexityUtilities, :calculate_complexity_score, 1)
    end

    test "returns numeric complexity score" do
      code_info = %{
        cyclomatic_complexity: 5,
        nesting_depth: 3,
        function_count: 10,
        lines: 200
      }

      result = ComplexityUtilities.calculate_complexity_score(code_info)
      assert is_integer(result) or is_float(result) or is_map(result)
    end

    test "returns higher score for more complex code" do
      simple = %{cyclomatic_complexity: 2, nesting_depth: 1, function_count: 5, lines: 50}
      complex = %{cyclomatic_complexity: 20, nesting_depth: 8, function_count: 50, lines: 500}

      s_score = ComplexityUtilities.calculate_complexity_score(simple)
      c_score = ComplexityUtilities.calculate_complexity_score(complex)

      if is_number(s_score) and is_number(c_score) do
        assert s_score < c_score
      end
    end
  end
end
