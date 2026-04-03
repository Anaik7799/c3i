defmodule Indrajaal.Cortex.Sensors.FLAMESensorTest do
  @moduledoc """
  Tests for the FLAMESensor module.

  STAMP Compliance:
  - SC-FLAME-001: Pool monitoring
  - SC-CTX-002: Sensor redundancy

  TDG: Test-Driven Generation - tests created before implementation validation.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cortex.Sensors.FLAMESensor

  describe "start_link/1" do
    test "starts the sensor process or uses existing" do
      case Process.whereis(FLAMESensor) do
        nil ->
          # Not running, start fresh
          assert {:ok, pid} = FLAMESensor.start_link([])
          assert Process.alive?(pid)

        pid ->
          # Already running from application supervisor
          assert Process.alive?(pid)
      end
    end

    test "process is registered with expected name" do
      case Process.whereis(FLAMESensor) do
        nil ->
          {:ok, pid} = FLAMESensor.start_link([])
          assert Process.whereis(FLAMESensor) == pid

        pid ->
          # Already registered from application supervisor
          assert Process.whereis(FLAMESensor) == pid
      end
    end
  end

  describe "measure/0" do
    setup do
      case Process.whereis(FLAMESensor) do
        nil ->
          {:ok, pid} = FLAMESensor.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns metrics map with expected keys", %{pid: _pid} do
      metrics = FLAMESensor.measure()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :pools)
      assert Map.has_key?(metrics, :total_runners)
      assert Map.has_key?(metrics, :total_queued)
      assert Map.has_key?(metrics, :avg_utilization)
      assert Map.has_key?(metrics, :measured_at)
    end

    test "pools is a map", %{pid: _pid} do
      metrics = FLAMESensor.measure()

      assert is_map(metrics.pools)
    end

    test "total_runners is non-negative", %{pid: _pid} do
      metrics = FLAMESensor.measure()

      assert is_integer(metrics.total_runners)
      assert metrics.total_runners >= 0
    end

    test "total_queued is non-negative", %{pid: _pid} do
      metrics = FLAMESensor.measure()

      assert is_integer(metrics.total_queued)
      assert metrics.total_queued >= 0
    end

    test "avg_utilization is between 0 and 1", %{pid: _pid} do
      metrics = FLAMESensor.measure()

      assert is_number(metrics.avg_utilization)
      assert metrics.avg_utilization >= 0.0
      assert metrics.avg_utilization <= 1.0
    end

    test "measured_at is a DateTime", %{pid: _pid} do
      metrics = FLAMESensor.measure()

      assert %DateTime{} = metrics.measured_at
    end

    test "includes pools_healthy count", %{pid: _pid} do
      metrics = FLAMESensor.measure()

      assert Map.has_key?(metrics, :pools_healthy)
      assert is_integer(metrics.pools_healthy)
      assert metrics.pools_healthy >= 0
    end

    test "includes pools_total count", %{pid: _pid} do
      metrics = FLAMESensor.measure()

      assert Map.has_key?(metrics, :pools_total)
      assert is_integer(metrics.pools_total)
      assert metrics.pools_total >= 0
    end
  end

  describe "pool_metrics/1" do
    setup do
      case Process.whereis(FLAMESensor) do
        nil ->
          {:ok, pid} = FLAMESensor.start_link([])
          # Allow initial measurement
          Process.sleep(100)
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns nil for unknown pool", %{pid: _pid} do
      result = FLAMESensor.pool_metrics(:unknown_pool)
      assert is_nil(result)
    end

    test "returns metrics for known pool", %{pid: _pid} do
      # Measure first to populate current data
      FLAMESensor.measure()

      result = FLAMESensor.pool_metrics(Indrajaal.FLAME.IntelligencePool)

      # May be nil if pool not running, but should not crash
      if result do
        assert is_map(result)
        assert Map.has_key?(result, :name)
        assert Map.has_key?(result, :status)
      end
    end
  end

  describe "history/1" do
    setup do
      case Process.whereis(FLAMESensor) do
        nil ->
          {:ok, pid} = FLAMESensor.start_link([])
          Process.sleep(100)
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns list of historical measurements", %{pid: _pid} do
      history = FLAMESensor.history(5)

      assert is_list(history)
    end

    test "respects count limit", %{pid: _pid} do
      for _ <- 1..3 do
        FLAMESensor.measure()
        Process.sleep(10)
      end

      history = FLAMESensor.history(2)
      assert length(history) <= 2
    end
  end

  describe "STAMP compliance" do
    setup do
      case Process.whereis(FLAMESensor) do
        nil ->
          {:ok, pid} = FLAMESensor.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "SC-FLAME-001: monitors all configured pools", %{pid: _pid} do
      metrics = FLAMESensor.measure()

      # Should track the 3 configured pools
      assert metrics.pools_total == 3
    end

    test "SC-CTX-002: graceful degradation when pools unavailable", %{pid: _pid} do
      # Should not crash even if pools are not running
      metrics = FLAMESensor.measure()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :pools)
    end
  end
end
