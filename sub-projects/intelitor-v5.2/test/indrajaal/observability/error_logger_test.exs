defmodule Indrajaal.Observability.ErrorLoggerTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.ErrorLogger.

  ## STAMP Safety Integration
  - SC-OBS-001: Error logging mandatory for all domain operations

  ## TPS 5-Level RCA Context
  - L1 Symptom: Untracked errors surface in production
  - L5 Root Cause: Prevents root cause analysis chain
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.ErrorLogger

  describe "log_error/4" do
    test "returns :ok for a basic error log" do
      result = ErrorLogger.log_error(:accounts, "create_user", :invalid_email)
      assert result == :ok
    end

    test "returns :ok with metadata" do
      result =
        ErrorLogger.log_error(:accounts, "create_user", :invalid_email, user_id: 123)

      assert result == :ok
    end

    test "handles exception reasons" do
      result = ErrorLogger.log_error(:alarms, "process_alarm", %RuntimeError{message: "boom"})
      assert result == :ok
    end

    test "handles tuple reasons" do
      result = ErrorLogger.log_error(:access_control, "authorize", {:forbidden, :read})
      assert result == :ok
    end

    test "handles string reasons" do
      result = ErrorLogger.log_error(:billing, "charge", "card declined")
      assert result == :ok
    end

    test "works without metadata (defaults to empty)" do
      result = ErrorLogger.log_error(:analytics, "query", :timeout)
      assert result == :ok
    end

    test "handles nil reason" do
      result = ErrorLogger.log_error(:dispatch, "route", nil)
      assert result == :ok
    end

    test "handles complex metadata" do
      result =
        ErrorLogger.log_error(:video, "stream", :buffer_overflow,
          tenant_id: "t1",
          camera_id: "cam-01",
          timestamp: DateTime.utc_now()
        )

      assert result == :ok
    end
  end

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Observability.ErrorLogger)
    end

    test "log_error/3 exported" do
      assert function_exported?(Indrajaal.Observability.ErrorLogger, :log_error, 3)
    end

    test "log_error/4 exported" do
      assert function_exported?(Indrajaal.Observability.ErrorLogger, :log_error, 4)
    end
  end
end
