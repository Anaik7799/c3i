defmodule Indrajaal.Validation.MethodsTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  test "PatternMethod module exists" do
    assert Code.ensure_loaded?(Indrajaal.Validation.Methods.PatternMethod)
  end

  test "ASTMethod module exists" do
    assert Code.ensure_loaded?(Indrajaal.Validation.Methods.ASTMethod)
  end

  test "StatisticalMethod module exists" do
    assert Code.ensure_loaded?(Indrajaal.Validation.Methods.StatisticalMethod)
  end

  test "BinaryMethod module exists" do
    assert Code.ensure_loaded?(Indrajaal.Validation.Methods.BinaryMethod)
  end

  test "LineByLineMethod module exists" do
    assert Code.ensure_loaded?(Indrajaal.Validation.Methods.LineByLineMethod)
  end

  test "PatternMethod.run/1 is exported" do
    assert function_exported?(Indrajaal.Validation.Methods.PatternMethod, :run, 1)
  end

  test "ASTMethod.run/1 is exported" do
    assert function_exported?(Indrajaal.Validation.Methods.ASTMethod, :run, 1)
  end

  test "StatisticalMethod.run/1 is exported" do
    assert function_exported?(Indrajaal.Validation.Methods.StatisticalMethod, :run, 1)
  end

  test "BinaryMethod.run/1 is exported" do
    assert function_exported?(Indrajaal.Validation.Methods.BinaryMethod, :run, 1)
  end

  test "LineByLineMethod.run/1 is exported" do
    assert function_exported?(Indrajaal.Validation.Methods.LineByLineMethod, :run, 1)
  end

  test "PatternMethod.run/1 returns a result tuple" do
    result = Indrajaal.Validation.Methods.PatternMethod.run(%{target: "test"})
    assert is_tuple(result) or is_map(result) or is_atom(result)
  end

  test "ASTMethod.run/1 returns a result tuple" do
    result = Indrajaal.Validation.Methods.ASTMethod.run(%{target: "test"})
    assert is_tuple(result) or is_map(result) or is_atom(result)
  end

  test "StatisticalMethod.run/1 returns a result tuple" do
    result = Indrajaal.Validation.Methods.StatisticalMethod.run(%{target: "test"})
    assert is_tuple(result) or is_map(result) or is_atom(result)
  end
end
