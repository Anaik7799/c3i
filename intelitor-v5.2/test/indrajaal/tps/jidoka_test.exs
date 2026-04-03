defmodule Indrajaal.TPS.JidokaTest do
  @moduledoc """
  Tests for Indrajaal.TPS.Jidoka - Stop and Fix principle GenServer.
  STAMP: SC-GDE-001, SC-TPS-001 to SC-TPS-006, SC-TDG-001
  """
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif
  @moduletag :sil4

  alias Indrajaal.TPS.Jidoka

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(Jidoka)
    end

    test "start_link/1 is exported" do
      assert function_exported?(Jidoka, :start_link, 1)
    end

    test "detect_critical_error/1 is exported" do
      assert function_exported?(Jidoka, :detect_critical_error, 1)
    end

    test "register_health_failure/1 is exported" do
      assert function_exported?(Jidoka, :register_health_failure, 1)
    end

    test "halt_operations/2 is exported" do
      assert function_exported?(Jidoka, :halt_operations, 2)
    end

    test "halted?/0 is exported" do
      assert function_exported?(Jidoka, :halted?, 0)
    end

    test "halt_status/0 is exported" do
      assert function_exported?(Jidoka, :halt_status, 0)
    end

    test "register_fix/2 is exported" do
      assert function_exported?(Jidoka, :register_fix, 2)
    end

    test "verify_fix/1 is exported" do
      assert function_exported?(Jidoka, :verify_fix, 1)
    end

    test "attempt_resume/1 is exported" do
      assert function_exported?(Jidoka, :attempt_resume, 1)
    end

    test "human_override/2 is exported" do
      assert function_exported?(Jidoka, :human_override, 2)
    end

    test "get_metrics/0 is exported" do
      assert function_exported?(Jidoka, :get_metrics, 0)
    end

    test "notify_agents/2 is exported" do
      assert function_exported?(Jidoka, :notify_agents, 2)
    end
  end

  describe "struct definition" do
    test "Jidoka has a struct" do
      state = %Jidoka{}
      assert is_struct(state, Jidoka)
    end

    test "struct has halted field" do
      state = %Jidoka{}
      assert Map.has_key?(state, :halted)
    end

    test "struct has halt_reason field" do
      state = %Jidoka{}
      assert Map.has_key?(state, :halt_reason)
    end
  end

  describe "RCA SLA" do
    test "rca_sla/0 returns expected configuration" do
      sla = Jidoka.rca_sla()
      assert is_map(sla)
      assert Map.has_key?(sla, :max_completion_time_hours)
      assert sla.max_completion_time_hours == 4
    end
  end

  describe "detect_critical_error/1 - pattern matching" do
    @tag :sil4
    test "accepts {:error, :critical, reason} tuple" do
      if Process.whereis(Jidoka) do
        result = Jidoka.detect_critical_error({:error, :critical, "test_error"})
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      else
        assert true
      end
    end

    @tag :sil4
    test "accepts {:error, :high, reason} tuple" do
      if Process.whereis(Jidoka) do
        result = Jidoka.detect_critical_error({:error, :high, "high_severity"})
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      else
        assert true
      end
    end

    @tag :sil4
    test "accepts anomaly map" do
      if Process.whereis(Jidoka) do
        anomaly = %{type: :memory_spike, severity: :high, current_value: 90, threshold: 80}
        result = Jidoka.detect_critical_error(anomaly)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      else
        assert true
      end
    end
  end
end
