defmodule Indrajaal.Support.CLILoggerTest do
  @moduledoc """
  TDG test suite for Indrajaal.Support.CLILogger.

  ## TPS 5-Level RCA Context
  - L1 Symptom: CLI scripts failing with UndefinedFunctionError
  - L5 Root Cause: CLILogger missing functions needed by scripts
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Support.CLILogger

  describe "log/1" do
    test "function is exported" do
      assert function_exported?(CLILogger, :log, 1)
    end

    test "returns :ok for a string message" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          result = CLILogger.log("test message")
          assert result == :ok
        end)

      assert String.contains?(output, "test message")
    end

    test "handles empty string" do
      import ExUnit.CaptureIO

      capture_io(fn ->
        assert CLILogger.log("") == :ok
      end)
    end
  end

  describe "log_cmd/3" do
    test "function is exported" do
      assert function_exported?(CLILogger, :log_cmd, 3)
    end

    test "logs success with no output" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          CLILogger.log_cmd("test command", [], {"", 0})
        end)

      assert String.contains?(output, "test command")
    end

    test "logs success with output" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          CLILogger.log_cmd("test cmd", [], {"some output", 0})
        end)

      assert String.contains?(output, "test cmd")
    end

    test "logs failure with non-zero exit code" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          CLILogger.log_cmd("failing cmd", [], {"error output", 1})
        end)

      assert String.contains?(output, "failing cmd")
    end
  end

  describe "start_session/1" do
    test "function is exported" do
      assert function_exported?(CLILogger, :start_session, 1)
    end

    test "returns :ok" do
      result = CLILogger.start_session([])
      assert result == :ok
    end

    test "returns :ok with any args" do
      result = CLILogger.start_session(%{verbose: true})
      assert result == :ok
    end
  end
end
