defmodule Indrajaal.Validation.FPPSStatisticalTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.FPPSStatistical.

  Tests statistical validation method for FPPS consensus.
  SC-VAL-003: Must produce consensus-compatible output.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.FPPSStatistical

  describe "validate_log_content/1" do
    test "returns map with method: :statistical key" do
      result = FPPSStatistical.validate_log_content("clean log")
      assert result.method == :statistical
    end

    test "returns map with errors integer" do
      result = FPPSStatistical.validate_log_content("no issues here")
      assert is_integer(result.errors)
      assert result.errors >= 0
    end

    test "returns map with warnings integer" do
      result = FPPSStatistical.validate_log_content("no issues here")
      assert is_integer(result.warnings)
      assert result.warnings >= 0
    end

    test "detects error: literal" do
      result = FPPSStatistical.validate_log_content("error: something went wrong")
      assert result.errors >= 1
    end

    test "detects warning: literal" do
      result = FPPSStatistical.validate_log_content("warning: deprecated function")
      assert result.warnings >= 1
    end

    test "returns zero errors for clean content" do
      result = FPPSStatistical.validate_log_content("Compiling 5 files")
      assert result.errors == 0
    end

    test "handles empty string" do
      result = FPPSStatistical.validate_log_content("")
      assert result.method == :statistical
      assert result.errors == 0
      assert result.warnings == 0
    end

    test "handles non-binary input gracefully" do
      result = FPPSStatistical.validate_log_content(nil)
      assert result.method == :statistical
      assert result.errors == 0
    end

    test "detects compilation error" do
      result = FPPSStatistical.validate_log_content("compilation error occurred")
      assert result.errors >= 1
    end

    test "detects undefined variable" do
      result = FPPSStatistical.validate_log_content("undefined variable foo")
      assert result.errors >= 1
    end
  end

  describe "validate/3 (rich reports)" do
    test "returns error tuple for unknown container" do
      result = FPPSStatistical.validate("nonexistent-container-xyz", :container)
      assert match?({:error, _}, result)
    end

    test "returns error for non-existent module string" do
      result = FPPSStatistical.validate("NonExistentModuleXYZ", :module)
      assert match?({:error, _}, result)
    end

    test "returns ok for existing module" do
      result = FPPSStatistical.validate("Indrajaal.Validation.FPPSStatistical", :module)
      assert match?({:ok, _}, result)
    end

    test "returns error for non-existent process" do
      result = FPPSStatistical.validate("nonexistent_process_xyz_123", :process)
      assert match?({:error, _}, result)
    end

    test "returns error for non-existent log file" do
      result = FPPSStatistical.validate("/tmp/nonexistent_log_xyz.log", :log_file)
      assert match?({:error, _}, result)
    end
  end

  describe "validate_log_file/2" do
    test "returns error for non-existent file" do
      result = FPPSStatistical.validate_log_file("/tmp/no_such_file_xyz.log")
      assert match?({:error, {:file_read_failed, _}}, result)
    end

    test "returns ok for existing file" do
      path = "/tmp/test_fpps_stat_#{System.unique_integer([:positive])}.log"
      File.write!(path, "clean log content\nno issues")

      result = FPPSStatistical.validate_log_file(path)
      assert match?({:ok, %{target: _, result: _}}, result)

      File.rm(path)
    end

    test "report includes required fields" do
      path = "/tmp/test_fpps_stat2_#{System.unique_integer([:positive])}.log"
      File.write!(path, "some log line\nanother line")

      {:ok, report} = FPPSStatistical.validate_log_file(path)
      assert Map.has_key?(report, :target)
      assert Map.has_key?(report, :result)
      assert Map.has_key?(report, :error_rate)
      assert Map.has_key?(report, :confidence)

      File.rm(path)
    end
  end

  describe "get_result/2" do
    test "returns atom result for module type" do
      result = FPPSStatistical.get_result("Indrajaal.Validation.FPPSStatistical", :module)
      assert result in [:healthy, :degraded, :unhealthy, :unknown]
    end

    test "returns :unknown for invalid target" do
      result = FPPSStatistical.get_result("NoSuchContainer", :container)
      assert result == :unknown
    end
  end
end
