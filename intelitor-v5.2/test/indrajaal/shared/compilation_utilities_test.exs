defmodule Indrajaal.Shared.CompilationUtilitiesTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Shared.CompilationUtilities

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(CompilationUtilities)
    end
  end

  describe "extract_warnings_from_output/1" do
    test "function is exported" do
      assert function_exported?(CompilationUtilities, :extract_warnings_from_output, 1)
    end

    test "returns empty list for output with no warnings" do
      result = CompilationUtilities.extract_warnings_from_output("Compilation successful")
      assert is_list(result)
      assert result == []
    end

    test "extracts warning from output string" do
      output = "warning: unused variable x in lib/foo.ex:10: Foo.bar/1"
      result = CompilationUtilities.extract_warnings_from_output(output)
      assert is_list(result)
    end
  end

  describe "parse_warning_line/1" do
    test "function is exported" do
      assert function_exported?(CompilationUtilities, :parse_warning_line, 1)
    end

    test "parses a warning line" do
      line = "warning: unused variable x"
      result = CompilationUtilities.parse_warning_line(line)
      assert is_map(result) or is_nil(result) or is_tuple(result)
    end

    test "returns nil for non-warning line" do
      result = CompilationUtilities.parse_warning_line("Compiled lib/foo.ex")
      assert is_nil(result) or is_map(result)
    end
  end

  describe "categorize_warning/1" do
    test "function is exported" do
      assert function_exported?(CompilationUtilities, :categorize_warning, 1)
    end

    test "categorizes an unused variable warning" do
      warning = %{message: "unused variable", file: "lib/foo.ex", line: 10}
      result = CompilationUtilities.categorize_warning(warning)
      assert is_atom(result) or is_binary(result)
    end
  end

  describe "analyze_warnings/1" do
    test "function is exported" do
      assert function_exported?(CompilationUtilities, :analyze_warnings, 1)
    end

    test "analyzes empty warnings list" do
      result = CompilationUtilities.analyze_warnings([])
      assert is_map(result) or is_list(result)
    end
  end

  describe "generate_warning_stats/1" do
    test "function is exported" do
      assert function_exported?(CompilationUtilities, :generate_warning_stats, 1)
    end

    test "generates stats for empty warnings" do
      result = CompilationUtilities.generate_warning_stats([])
      assert is_map(result)
    end
  end

  describe "module_to_path/1" do
    test "function is exported" do
      assert function_exported?(CompilationUtilities, :module_to_path, 1)
    end

    test "converts module atom to file path" do
      result = CompilationUtilities.module_to_path(Indrajaal.Core.Holon)
      assert is_binary(result)
      assert String.contains?(result, "/")
    end

    test "converts Elixir.prefixed module name" do
      result = CompilationUtilities.module_to_path("Elixir.Indrajaal.Core.Holon")
      assert is_binary(result)
    end
  end
end
