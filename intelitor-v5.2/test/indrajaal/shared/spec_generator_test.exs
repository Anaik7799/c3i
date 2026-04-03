defmodule SpecGeneratorTest do
  @moduledoc """
  TDG-compliant tests for SpecGenerator module.

  Tests comprehensive spec generation patterns for:
  - generatespec_for_function functionality
  - File path handling
  - Function analysis
  - AST-based type inference
  - Spec string generation
  - Generic spec fallback

  Note: The module is defined as SpecGenerator (not Indrajaal.Shared.SpecGenerator)

  Created: 2025-11-27 15:45:00 CEST
  Phase: 2.4 - C1 Security-Critical Testing (Pattern & Factory Modules)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  # Note: SpecGenerator is NOT namespaced under Indrajaal.Shared
  # It's defined as just "SpecGenerator" in the source

  # ============================================================================
  # MODULE EXISTENCE TESTS
  # ============================================================================

  describe "Module Structure" do
    test "SpecGenerator module exists" do
      assert Code.ensure_loaded?(SpecGenerator)
    end

    test "module exports generatespec_for_function function" do
      functions = SpecGenerator.__info__(:functions)
      assert {:generatespec_for_function, 3} in functions
    end
  end

  # ============================================================================
  # GENERATESPEC_FOR_FUNCTION TESTS
  # ============================================================================

  describe "generatespec_for_function/3" do
    test "generates spec for existing function" do
      # Use a real file that exists
      file_path = "lib/indrajaal/shared/spec_generator.ex"
      result = SpecGenerator.generatespec_for_function(file_path, :generatespec_for_function, 3)

      assert is_binary(result)
    end

    test "returns generic spec for non-existent file" do
      result =
        SpecGenerator.generatespec_for_function(
          "non_existent_file.ex",
          :some_function,
          2
        )

      assert is_binary(result)
    end

    test "returns generic spec for non-existent function" do
      file_path = "lib/indrajaal/shared/spec_generator.ex"

      result =
        SpecGenerator.generatespec_for_function(
          file_path,
          :non_existent_function,
          5
        )

      assert is_binary(result)
    end

    test "handles arity 0" do
      result =
        SpecGenerator.generatespec_for_function(
          "some_file.ex",
          :zero_arity_function,
          0
        )

      assert is_binary(result)
    end

    test "handles high arity" do
      result =
        SpecGenerator.generatespec_for_function(
          "some_file.ex",
          :high_arity_function,
          10
        )

      assert is_binary(result)
    end

    test "handles function name as string-like atom" do
      result =
        SpecGenerator.generatespec_for_function(
          "file.ex",
          :function_with_special_chars?,
          1
        )

      assert is_binary(result)
    end

    test "handles bang functions" do
      result =
        SpecGenerator.generatespec_for_function(
          "file.ex",
          :function!,
          2
        )

      assert is_binary(result)
    end

    test "handles predicate functions" do
      result =
        SpecGenerator.generatespec_for_function(
          "file.ex",
          :is_valid?,
          1
        )

      assert is_binary(result)
    end
  end

  # ============================================================================
  # SPEC STRING FORMAT TESTS
  # ============================================================================

  describe "Spec String Format" do
    test "spec contains @spec annotation" do
      result = SpecGenerator.generatespec_for_function("file.ex", :test_func, 2)

      assert String.contains?(result, "@spec")
    end

    test "generic spec has correct structure for arity 0" do
      result = SpecGenerator.generatespec_for_function("file.ex", :no_args, 0)

      # Should be something like "@spec no_args() :: term()"
      assert String.contains?(result, "no_args")
    end

    test "generic spec has correct structure for arity 1" do
      result = SpecGenerator.generatespec_for_function("file.ex", :one_arg, 1)

      assert String.contains?(result, "one_arg")
    end

    test "generic spec has correct structure for arity 2" do
      result = SpecGenerator.generatespec_for_function("file.ex", :two_args, 2)

      assert String.contains?(result, "two_args")
    end
  end

  # ============================================================================
  # FILE PATH HANDLING TESTS
  # ============================================================================

  describe "File Path Handling" do
    test "handles relative paths" do
      result =
        SpecGenerator.generatespec_for_function(
          "./lib/module.ex",
          :func,
          1
        )

      assert is_binary(result)
    end

    test "handles absolute paths" do
      result =
        SpecGenerator.generatespec_for_function(
          "/home/user/project/lib/module.ex",
          :func,
          1
        )

      assert is_binary(result)
    end

    test "handles paths with spaces" do
      result =
        SpecGenerator.generatespec_for_function(
          "path/with spaces/module.ex",
          :func,
          1
        )

      assert is_binary(result)
    end

    test "handles empty path" do
      result = SpecGenerator.generatespec_for_function("", :func, 1)

      assert is_binary(result)
    end

    test "handles nil-like empty string" do
      result = SpecGenerator.generatespec_for_function("", :test, 0)

      assert is_binary(result)
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "always returns a binary string" do
      forall {path, func_name, arity} <- {PC.binary(), PC.atom(), PC.non_neg_integer()} do
        result = SpecGenerator.generatespec_for_function(path, func_name, arity)
        is_binary(result)
      end
    end

    property "result always contains @spec" do
      forall {path, func_name, arity} <- {PC.binary(), PC.atom(), PC.range(0, 10)} do
        result = SpecGenerator.generatespec_for_function(path, func_name, arity)
        String.contains?(result, "@spec")
      end
    end

    property "result is non-empty for valid inputs" do
      forall {path, func_name, arity} <- {PC.binary(), PC.atom(), PC.range(0, 10)} do
        result = SpecGenerator.generatespec_for_function(path, func_name, arity)
        String.length(result) > 0
      end
    end

    property "function is deterministic" do
      forall {path, func_name, arity} <- {PC.binary(), PC.atom(), PC.range(0, 5)} do
        result1 = SpecGenerator.generatespec_for_function(path, func_name, arity)
        result2 = SpecGenerator.generatespec_for_function(path, func_name, arity)
        result1 == result2
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "handles very long function name" do
      duplicated = String.duplicate("a", 1000)
      long_name = duplicated |> String.to_atom()
      result = SpecGenerator.generatespec_for_function("file.ex", long_name, 1)

      assert is_binary(result)
    end

    test "handles very high arity" do
      result = SpecGenerator.generatespec_for_function("file.ex", :many_args, 100)

      assert is_binary(result)
    end

    test "handles special atoms as function names" do
      special_names = [
        :__struct__,
        :__info__,
        :module_info,
        :"Elixir.Something",
        :""
      ]

      results =
        Enum.map(special_names, fn name ->
          SpecGenerator.generatespec_for_function("file.ex", name, 1)
        end)

      assert Enum.all?(results, &is_binary/1)
    end

    test "handles unicode in path" do
      result =
        SpecGenerator.generatespec_for_function(
          "lib/модуль/файл.ex",
          :функция,
          1
        )

      assert is_binary(result)
    end
  end

  # ============================================================================
  # SOURCE CODE VALIDATION TESTS
  # ============================================================================

  describe "Source Code Validation" do
    test "source file exists" do
      assert File.exists?("lib/indrajaal/shared/spec_generator.ex")
    end

    test "source file is valid Elixir" do
      source = File.read!("lib/indrajaal/shared/spec_generator.ex")
      {:ok, _ast} = Code.string_to_quoted(source)
    end

    test "module has proper defmodule structure" do
      source = File.read!("lib/indrajaal/shared/spec_generator.ex")
      # Note: Module is SpecGenerator, not Indrajaal.Shared.SpecGenerator
      assert String.contains?(source, "defmodule SpecGenerator")
    end

    test "generatespec_for_function is public" do
      source = File.read!("lib/indrajaal/shared/spec_generator.ex")
      assert String.contains?(source, "def generatespec_for_function")
    end

    test "has private helper functions" do
      source = File.read!("lib/indrajaal/shared/spec_generator.ex")
      assert String.contains?(source, "defp analyze_function")
      assert String.contains?(source, "defp generate_spec_string")
      assert String.contains?(source, "defp generate_generic_spec")
    end
  end

  # ============================================================================
  # INTEGRATION SCENARIO TESTS
  # ============================================================================

  describe "Integration Scenarios" do
    test "batch spec generation for multiple functions" do
      functions = [
        {:func1, 0},
        {:func2, 1},
        {:func3, 2},
        {:func4, 3}
      ]

      results =
        Enum.map(functions, fn {name, arity} ->
          SpecGenerator.generatespec_for_function("test.ex", name, arity)
        end)

      assert length(results) == 4
      assert Enum.all?(results, &is_binary/1)
      assert Enum.all?(results, &String.contains?(&1, "@spec"))
    end

    test "spec generation workflow simulation" do
      # Simulate analyzing a real file
      file_path = "lib/indrajaal/shared/spec_generator.ex"

      # Generate specs for known functions
      specs = [
        SpecGenerator.generatespec_for_function(file_path, :generatespec_for_function, 3)
      ]

      assert Enum.all?(specs, &is_binary/1)
    end

    test "handles concurrent spec generation" do
      # Generate specs in parallel
      tasks =
        Enum.map(1..10, fn i ->
          Task.async(fn ->
            func_name = String.to_atom("func_#{i}")
            SpecGenerator.generatespec_for_function("file.ex", func_name, rem(i, 5))
          end)
        end)

      results = Enum.map(tasks, &Task.await/1)

      assert length(results) == 10
      assert Enum.all?(results, &is_binary/1)
    end
  end
end
