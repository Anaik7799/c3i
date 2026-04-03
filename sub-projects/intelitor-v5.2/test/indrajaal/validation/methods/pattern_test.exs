defmodule Indrajaal.Validation.Methods.PatternTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.Methods.Pattern.

  Tests regex pattern-based FPPS validation method (L1).
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.Methods.Pattern

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(Pattern)
    end

    test "validate/1 is exported" do
      assert function_exported?(Pattern, :validate, 1)
    end
  end

  describe "validate/1 return structure" do
    test "returns a map" do
      result = Pattern.validate("clean log output")
      assert is_map(result)
    end

    test "result contains method key set to :pattern" do
      result = Pattern.validate("clean log output")
      assert result.method == :pattern
    end

    test "result contains errors key as integer" do
      result = Pattern.validate("clean log output")
      assert Map.has_key?(result, :errors)
      assert is_integer(result.errors)
    end

    test "result contains warnings key as integer" do
      result = Pattern.validate("clean log output")
      assert Map.has_key?(result, :warnings)
      assert is_integer(result.warnings)
    end

    test "errors count is non-negative" do
      result = Pattern.validate("clean log output")
      assert result.errors >= 0
    end

    test "warnings count is non-negative" do
      result = Pattern.validate("clean log output")
      assert result.warnings >= 0
    end
  end

  describe "validate/1 clean content" do
    test "returns zero errors for clean log" do
      result = Pattern.validate("Compiled successfully. 0 files changed.")
      assert result.errors == 0
    end

    test "returns zero warnings for clean log" do
      result = Pattern.validate("Compiled successfully. 0 files changed.")
      assert result.warnings == 0
    end

    test "returns zero counts for empty string" do
      result = Pattern.validate("")
      assert result.errors == 0
      assert result.warnings == 0
    end
  end

  describe "validate/1 error detection" do
    test "detects error: literal" do
      result = Pattern.validate("error: something went wrong")
      assert result.errors >= 1
    end

    test "detects compilation error header" do
      result = Pattern.validate("== Compilation error in file lib/foo.ex ==")
      assert result.errors >= 1
    end

    test "detects exception prefix ** (" do
      result = Pattern.validate("** (CompileError) undefined function")
      assert result.errors >= 1
    end

    test "detects CompileError exception type" do
      result = Pattern.validate("** (CompileError) lib/foo.ex:10: something")
      assert result.errors >= 1
    end

    test "detects undefined variable" do
      result = Pattern.validate("error: undefined variable x in scope")
      assert result.errors >= 1
    end

    test "detects undefined function" do
      result = Pattern.validate("error: undefined function foo/1")
      assert result.errors >= 1
    end

    test "detects syntax error" do
      result = Pattern.validate("syntax error before: 'end'")
      assert result.errors >= 1
    end

    test "multiple error patterns accumulate" do
      log = "error: undefined variable\n** (CompileError) bad code"
      result = Pattern.validate(log)
      assert result.errors >= 2
    end
  end

  describe "validate/1 warning detection" do
    test "detects warning: literal" do
      result = Pattern.validate("warning: variable 'x' is unused")
      assert result.warnings >= 1
    end

    test "detects deprecated keyword" do
      result = Pattern.validate("Function foo is deprecated")
      assert result.warnings >= 1
    end

    test "detects unused keyword" do
      result = Pattern.validate("warning: unused variable bar")
      assert result.warnings >= 1
    end

    test "detects shadowed keyword" do
      result = Pattern.validate("warning: variable x is shadowed")
      assert result.warnings >= 1
    end

    test "detects unreachable keyword" do
      result = Pattern.validate("warning: unreachable code after return")
      assert result.warnings >= 1
    end
  end

  describe "validate/1 non-binary input" do
    test "handles nil gracefully" do
      result = Pattern.validate(nil)
      assert is_map(result)
      assert result.method == :pattern
    end

    test "handles integer gracefully" do
      result = Pattern.validate(42)
      assert is_map(result)
      assert result.errors == 0
    end

    test "handles list gracefully" do
      result = Pattern.validate([])
      assert is_map(result)
      assert result.warnings == 0
    end
  end
end
