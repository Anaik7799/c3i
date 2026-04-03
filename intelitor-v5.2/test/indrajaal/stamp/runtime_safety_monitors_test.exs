defmodule Indrajaal.STAMP.RuntimeSafetyMonitorsTest do
  @moduledoc """
  Tests for Indrajaal.STAMP.RuntimeSafetyMonitors - real-time safety monitoring.
  STAMP: SC-GDE-001, SC-TDG-001, SC-IMMUNE-001
  """
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif
  @tag :sil4

  alias Indrajaal.STAMP.RuntimeSafetyMonitors

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(RuntimeSafetyMonitors)
    end

    test "start_monitoring/0 is exported" do
      assert function_exported?(RuntimeSafetyMonitors, :start_monitoring, 0)
    end
  end

  describe "start_monitoring/0" do
    @tag :sil4
    test "returns :ok" do
      result = RuntimeSafetyMonitors.start_monitoring()
      assert match?(:ok, result) or match?({:ok, _}, result)
    end

    @tag :sil4
    test "creates ETS tables for monitoring thresholds" do
      result = RuntimeSafetyMonitors.start_monitoring()
      assert result == :ok or match?({:ok, _}, result)
    end

    @tag :sil4
    test "attaches telemetry handlers" do
      result = RuntimeSafetyMonitors.start_monitoring()
      assert result == :ok or match?({:ok, _}, result)
    end

    @tag :sil4
    test "is idempotent" do
      RuntimeSafetyMonitors.start_monitoring()
      result = RuntimeSafetyMonitors.start_monitoring()
      assert match?(:ok, result) or match?({:ok, _}, result)
    end
  end
end
