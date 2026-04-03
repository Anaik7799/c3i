defmodule Indrajaal.Validation.Methods.ASTTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.Methods.AST.

  Tests AST-aware FPPS validation method (L2).
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.Methods.AST

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(AST)
    end

    test "validate/1 is exported" do
      assert function_exported?(AST, :validate, 1)
    end
  end

  describe "validate/1 return structure" do
    test "returns a map" do
      result = AST.validate("def hello, do: :world")
      assert is_map(result)
    end

    test "result contains method key set to :ast" do
      result = AST.validate("def hello, do: :world")
      assert result.method == :ast
    end

    test "result contains errors key as integer" do
      result = AST.validate("def hello, do: :world")
      assert Map.has_key?(result, :errors)
      assert is_integer(result.errors)
    end

    test "result contains warnings key as integer" do
      result = AST.validate("def hello, do: :world")
      assert Map.has_key?(result, :warnings)
      assert is_integer(result.warnings)
    end

    test "errors count is non-negative" do
      result = AST.validate("def hello, do: :world")
      assert result.errors >= 0
    end

    test "warnings count is non-negative" do
      result = AST.validate("def hello, do: :world")
      assert result.warnings >= 0
    end
  end

  describe "validate/1 clean code" do
    test "returns zero errors for valid elixir code" do
      result = AST.validate("def hello, do: :world")
      assert result.errors == 0
    end

    test "returns zero warnings for valid elixir code" do
      result = AST.validate("def hello, do: :world")
      assert result.warnings == 0
    end

    test "returns zero counts for empty string" do
      result = AST.validate("")
      assert result.errors == 0
      assert result.warnings == 0
    end

    test "returns zero counts for whitespace only" do
      result = AST.validate("   \n   ")
      assert result.errors == 0
      assert result.warnings == 0
    end
  end

  describe "validate/1 log content with errors" do
    test "detects error: literal in log content" do
      log = "== Compilation error ==\nerror: something went wrong"
      result = AST.validate(log)
      assert result.errors > 0
    end

    test "detects compilation error marker" do
      log = "== Compilation error in file lib/foo.ex =="
      result = AST.validate(log)
      assert result.errors > 0
    end

    test "detects exception prefix ** (" do
      log = "** (CompileError) lib/foo.ex:10: undefined variable x"
      result = AST.validate(log)
      assert result.errors > 0
    end

    test "detects undefined variable" do
      log = "error: undefined variable x in lib/foo.ex:5"
      result = AST.validate(log)
      assert result.errors > 0
    end

    test "detects warning: literal" do
      log = "warning: variable 'x' is unused"
      result = AST.validate(log)
      assert result.warnings > 0
    end

    test "detects deprecated keyword" do
      log = "warning: this function is deprecated"
      result = AST.validate(log)
      assert result.warnings > 0
    end

    test "detects unused variable warning" do
      log = "warning: unused variable foo"
      result = AST.validate(log)
      assert result.warnings > 0
    end
  end

  describe "validate/1 non-binary input" do
    test "handles nil gracefully" do
      result = AST.validate(nil)
      assert is_map(result)
      assert result.method == :ast
    end

    test "handles integer gracefully" do
      result = AST.validate(42)
      assert is_map(result)
      assert result.errors == 0
    end

    test "handles atom gracefully" do
      result = AST.validate(:some_atom)
      assert is_map(result)
      assert result.warnings == 0
    end
  end
end
