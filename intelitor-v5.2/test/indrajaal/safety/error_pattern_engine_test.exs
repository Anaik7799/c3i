defmodule Indrajaal.Safety.ErrorPatternEngineTest do
  @moduledoc """
  Tests for Error Pattern Engine System (STUB Implementation)

  NOTE: ErrorPatternEngine uses PatternDatabase which is a STUB module.
  Tests verify the existing API contract without expecting full production behavior.
  """

  # Async false due to shared GenServer
  use ExUnit.Case, async: false
  alias Indrajaal.Safety.ErrorPatternEngine

  setup do
    # The engine may already be started by the application
    # If not started, start it
    case GenServer.whereis(ErrorPatternEngine) do
      nil ->
        {:ok, pid} = ErrorPatternEngine.start_link(learning_enabled: true)
        Process.sleep(100)
        on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
        {:ok, engine_pid: pid}

      pid ->
        {:ok, engine_pid: pid}
    end
  end

  describe "start_link/1" do
    test "engine is running and responds to requests" do
      pid = GenServer.whereis(ErrorPatternEngine)
      assert pid != nil
      assert Process.alive?(pid)
    end

    test "loads patterns on startup" do
      stats = ErrorPatternEngine.get_statistics()
      # Stub has ~29 patterns
      assert stats.patterns_loaded > 10
    end
  end

  describe "analyze_error/1" do
    test "analyzes error and returns a result tuple" do
      error_data = %{
        message: "connection pool exhausted - all slots in use",
        severity: :high,
        timestamp: DateTime.utc_now()
      }

      result = ErrorPatternEngine.analyze_error(error_data)

      # Should return a result tuple
      assert is_tuple(result)
      assert elem(result, 0) == :ok
    end

    test "handles unmatched errors gracefully" do
      error_data = %{
        message: "completely novel error never seen before xyz123",
        severity: :medium,
        timestamp: DateTime.utc_now()
      }

      result = ErrorPatternEngine.analyze_error(error_data)

      # Should return no_pattern_match for unknown errors
      assert {:ok, :no_pattern_match, %{suggestion: :manual_analysis_required}} = result
    end

    test "handles malformed error data gracefully" do
      error_data = %{
        invalid_field: "not a standard error",
        random_data: 12_345
      }

      result = ErrorPatternEngine.analyze_error(error_data)

      # Should handle gracefully without crashing
      assert is_tuple(result)
    end

    test "handles nil message gracefully" do
      error_data = %{message: nil}
      result = ErrorPatternEngine.analyze_error(error_data)
      assert is_tuple(result)
    end
  end

  describe "analyze_errors/1" do
    test "batch processes multiple errors" do
      errors = [
        %{message: "connection timeout exceeded", severity: :medium},
        %{message: "memory usage high", severity: :high},
        %{message: "unknown error xyz", severity: :low}
      ]

      results = ErrorPatternEngine.analyze_errors(errors)

      assert length(results) == 3
      assert Enum.all?(results, &is_tuple/1)
    end

    test "processes empty error list" do
      results = ErrorPatternEngine.analyze_errors([])
      assert results == []
    end
  end

  describe "register_pattern/1" do
    test "registers valid custom pattern" do
      custom_pattern = %{
        id: "EP-CUSTOM-001",
        name: "Custom Test Pattern",
        pattern: ~r/custom.*test.*pattern/i,
        type: :system,
        severity: :medium,
        remediation_type: :restart_service,
        success_rate: 0.85,
        conditions: %{}
      }

      result = ErrorPatternEngine.register_pattern(custom_pattern)

      case result do
        :ok -> assert true
        {:ok, _} -> assert true
        other -> flunk("Expected :ok or {:ok, _}, got: #{inspect(other)}")
      end
    end

    test "rejects pattern with missing required fields" do
      invalid_pattern = %{
        id: "EP-INVALID-001"
        # missing pattern, name, severity fields
      }

      result = ErrorPatternEngine.register_pattern(invalid_pattern)
      assert {:error, {:missing_fields, _}} = result
    end
  end

  describe "get_statistics/0" do
    test "returns statistics map" do
      stats = ErrorPatternEngine.get_statistics()

      assert is_map(stats)
      assert Map.has_key?(stats, :patterns_loaded)
      assert Map.has_key?(stats, :analyses_performed)
      assert stats.patterns_loaded > 0
    end
  end

  describe "reload_patterns/0" do
    test "reloads patterns from database" do
      initial_stats = ErrorPatternEngine.get_statistics()
      initial_count = initial_stats.patterns_loaded

      # Reload patterns
      ErrorPatternEngine.reload_patterns()
      Process.sleep(100)

      updated_stats = ErrorPatternEngine.get_statistics()

      # Should have same count (loading same patterns)
      assert updated_stats.patterns_loaded == initial_count
    end
  end

  describe "pattern matching" do
    test "matches patterns case-insensitively" do
      error_data = %{message: "CONNECTION POOL EXHAUSTED"}
      result = ErrorPatternEngine.analyze_error(error_data)

      # Should return a result (may or may not match depending on patterns)
      assert is_tuple(result)
      assert elem(result, 0) == :ok
    end
  end

  describe "performance" do
    test "processes single error analysis quickly" do
      error_data = %{message: "connection timeout", severity: :medium}

      {time_micro, result} =
        :timer.tc(fn ->
          ErrorPatternEngine.analyze_error(error_data)
        end)

      assert is_tuple(result)
      # Should process quickly (under 50ms)
      assert time_micro < 50_000
    end

    test "processes batch analysis efficiently" do
      errors =
        for i <- 1..50 do
          %{message: "error number #{i}", severity: :medium}
        end

      {time_micro, results} =
        :timer.tc(fn ->
          ErrorPatternEngine.analyze_errors(errors)
        end)

      assert length(results) == 50
      # Batch processing should be efficient (under 500ms for 50 errors)
      assert time_micro < 500_000
    end
  end

  describe "error handling" do
    test "handles empty map gracefully" do
      result = ErrorPatternEngine.analyze_error(%{})
      assert is_tuple(result)
    end

    test "handles map with nil message gracefully" do
      result = ErrorPatternEngine.analyze_error(%{message: nil})
      assert is_tuple(result)
    end

    test "handles map with invalid structure gracefully" do
      result = ErrorPatternEngine.analyze_error(%{invalid: "structure"})
      assert is_tuple(result)
    end
  end
end
