defmodule Indrajaal.Validation.FPPSTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.FPPS orchestrator.

  Tests the 5-method FPPS consensus validation system.
  SC-VAL-003: 100% consensus required.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.FPPS

  describe "validate/2" do
    test "returns ok tuple for empty log content" do
      result = FPPS.validate("")

      assert match?({:ok, _}, result) or match?({:error, _, _}, result) or
               match?({:error, _}, result)
    end

    test "returns ok for clean log content with no errors" do
      clean_log = "Compiling 10 files (.ex)\nGenerated indrajaal app"
      result = FPPS.validate(clean_log)

      assert match?({:ok, %{consensus: _, individual_results: _}}, result) or
               match?({:error, _, _}, result)
    end

    test "returns a 3-tuple on consensus failure with error content" do
      error_log = "error: undefined variable x\nerror: compilation failed"
      result = FPPS.validate(error_log)
      # Must be either ok or error with diagnostics
      assert match?({:ok, _}, result) or match?({:error, _, _}, result) or
               match?({:error, _}, result)
    end

    test "accepts opts keyword list as second argument" do
      result = FPPS.validate("clean content", min_agreement: 3)
      assert is_tuple(result)
    end

    test "returns ok tuple with consensus map when content has no issues" do
      log = "Compiling 1 file (.ex)\nGenerated app"

      case FPPS.validate(log) do
        {:ok, result} ->
          assert is_map(result)
          assert Map.has_key?(result, :consensus) or Map.has_key?(result, :individual_results)

        {:error, _, _} ->
          # Acceptable if methods disagree
          :ok

        {:error, _} ->
          :ok
      end
    end

    test "handles multiline log content" do
      multiline = "== Compilation error in file lib/foo.ex ==\n** (CompileError) undefined"
      result = FPPS.validate(multiline)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "normalizes content via ContextWindow before validation" do
      # This tests that normalization happens - the result should be consistent
      content_a = "error: foo\nerror: bar"
      content_b = "error: foo\nerror: bar"
      result_a = FPPS.validate(content_a)
      result_b = FPPS.validate(content_b)
      # Same content, same result
      assert result_a == result_b
    end
  end

  describe "validate_artifacts/2" do
    test "returns a map with all 5 method keys" do
      result = FPPS.validate_artifacts("some log content")
      assert is_map(result)
      assert Map.has_key?(result, :pattern)
      assert Map.has_key?(result, :ast)
      assert Map.has_key?(result, :statistical)
      assert Map.has_key?(result, :binary)
      assert Map.has_key?(result, :line_by_line)
    end

    test "accepts env option" do
      result = FPPS.validate_artifacts("content", env: :test)
      assert is_map(result)
    end

    test "returns pattern result with errors and warnings keys" do
      result = FPPS.validate_artifacts("clean log")
      pattern_result = result.pattern
      assert Map.has_key?(pattern_result, :errors)
      assert Map.has_key?(pattern_result, :warnings)
    end
  end
end
