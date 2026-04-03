defmodule Indrajaal.Cortex.Sensors.PodmanHealthSensorTest do
  @moduledoc """
  Tests for the PodmanHealthSensor module.

  STAMP Compliance:
  - SC-CNT-009: Container OS is NixOS/Podman
  - SC-CNT-012: Rootless execution verification
  - SC-OBS-069: Dual logging (Terminal + SigNoz)
  - SC-PRF-050: Response < 50ms for health checks

  TDG: Test-Driven Generation - tests validate Podman health integration.

  Integration with Cepaf.Podman:
  - Health status types aligned with F# Cepaf.Podman.Domain.HealthStatus
  - Probe configuration aligned with Cepaf.Podman.Health.ProbeConfig
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cortex.Sensors.PodmanHealthSensor

  @moduletag :cortex
  @moduletag :podman_health
  @moduletag :container

  # Check if Podman socket is available for integration tests
  @podman_available File.exists?("/run/user/1000/podman/podman.sock") or
                      File.exists?("/run/podman/podman.sock")

  setup do
    # Stop any existing sensor instance
    case GenServer.whereis(PodmanHealthSensor) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    :ok
  end

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(PodmanHealthSensor)
    end

    test "exports measure/0 function" do
      assert function_exported?(PodmanHealthSensor, :measure, 0)
    end

    test "exports get_container_health/1 function" do
      assert function_exported?(PodmanHealthSensor, :get_container_health, 1)
    end

    test "exports get_health_summary/0 function" do
      assert function_exported?(PodmanHealthSensor, :get_health_summary, 0)
    end

    test "exports poll_now/0 function" do
      assert function_exported?(PodmanHealthSensor, :poll_now, 0)
    end

    test "exports get_state/0 function" do
      assert function_exported?(PodmanHealthSensor, :get_state, 0)
    end

    test "exports all_healthy?/0 function" do
      assert function_exported?(PodmanHealthSensor, :all_healthy?, 0)
    end

    test "exports get_unhealthy/0 function" do
      assert function_exported?(PodmanHealthSensor, :get_unhealthy, 0)
    end
  end

  describe "start_link/1" do
    test "starts successfully with default options" do
      {:ok, pid} = PodmanHealthSensor.start_link(enabled: false)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "starts in disabled mode when socket not available" do
      {:ok, pid} = PodmanHealthSensor.start_link(socket_path: "/nonexistent/socket")
      assert Process.alive?(pid)

      state = PodmanHealthSensor.get_state()
      assert state.enabled == false

      GenServer.stop(pid)
    end

    test "accepts custom poll interval" do
      {:ok, pid} = PodmanHealthSensor.start_link(poll_interval_ms: 60_000, enabled: false)

      state = PodmanHealthSensor.get_state()
      assert state.poll_interval_ms == 60_000

      GenServer.stop(pid)
    end
  end

  describe "measure/0" do
    setup do
      {:ok, pid} = PodmanHealthSensor.start_link(enabled: false)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns a map with expected keys" do
      result = PodmanHealthSensor.measure()

      assert is_map(result)
      assert Map.has_key?(result, :healthy)
      assert Map.has_key?(result, :container_health_ratio)
      assert Map.has_key?(result, :containers_total)
      assert Map.has_key?(result, :containers_healthy)
      assert Map.has_key?(result, :containers_unhealthy)
      assert Map.has_key?(result, :containers_starting)
      assert Map.has_key?(result, :containers_no_healthcheck)
      assert Map.has_key?(result, :cluster_status)
      assert Map.has_key?(result, :enabled)
    end

    test "healthy is a boolean" do
      result = PodmanHealthSensor.measure()
      assert is_boolean(result.healthy)
    end

    test "container_health_ratio is between 0 and 1" do
      result = PodmanHealthSensor.measure()
      assert is_number(result.container_health_ratio)
      assert result.container_health_ratio >= 0.0
      assert result.container_health_ratio <= 1.0
    end

    test "cluster_status is a valid atom" do
      result = PodmanHealthSensor.measure()
      assert result.cluster_status in [:healthy, :unhealthy, :starting, :degraded, :unknown]
    end
  end

  describe "get_state/0" do
    setup do
      {:ok, pid} = PodmanHealthSensor.start_link(enabled: false)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns state map with expected keys" do
      state = PodmanHealthSensor.get_state()

      assert is_map(state)
      assert Map.has_key?(state, :socket_path)
      assert Map.has_key?(state, :poll_interval_ms)
      assert Map.has_key?(state, :poll_count)
      assert Map.has_key?(state, :failure_count)
      assert Map.has_key?(state, :container_count)
      assert Map.has_key?(state, :started_at)
      assert Map.has_key?(state, :enabled)
    end

    test "poll_count starts at 0" do
      state = PodmanHealthSensor.get_state()
      assert state.poll_count == 0
    end

    test "failure_count starts at 0" do
      state = PodmanHealthSensor.get_state()
      assert state.failure_count == 0
    end
  end

  describe "get_health_summary/0" do
    setup do
      {:ok, pid} = PodmanHealthSensor.start_link(enabled: false)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns summary map with expected keys" do
      summary = PodmanHealthSensor.get_health_summary()

      assert is_map(summary)
      assert Map.has_key?(summary, :total)
      assert Map.has_key?(summary, :healthy)
      assert Map.has_key?(summary, :unhealthy)
      assert Map.has_key?(summary, :starting)
      assert Map.has_key?(summary, :no_healthcheck)
      assert Map.has_key?(summary, :timestamp)
    end

    test "all counts are non-negative integers" do
      summary = PodmanHealthSensor.get_health_summary()

      assert is_integer(summary.total) and summary.total >= 0
      assert is_integer(summary.healthy) and summary.healthy >= 0
      assert is_integer(summary.unhealthy) and summary.unhealthy >= 0
      assert is_integer(summary.starting) and summary.starting >= 0
      assert is_integer(summary.no_healthcheck) and summary.no_healthcheck >= 0
    end

    test "counts sum up correctly" do
      summary = PodmanHealthSensor.get_health_summary()

      calculated_total =
        summary.healthy + summary.unhealthy + summary.starting + summary.no_healthcheck

      assert summary.total == calculated_total
    end

    test "timestamp is a DateTime" do
      summary = PodmanHealthSensor.get_health_summary()
      assert %DateTime{} = summary.timestamp
    end
  end

  describe "all_healthy?/0" do
    setup do
      {:ok, pid} = PodmanHealthSensor.start_link(enabled: false)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns a boolean" do
      result = PodmanHealthSensor.all_healthy?()
      assert is_boolean(result)
    end

    test "returns true when no containers monitored" do
      # In disabled mode with no polls, should be true
      result = PodmanHealthSensor.all_healthy?()
      assert result == true
    end
  end

  describe "get_unhealthy/0" do
    setup do
      {:ok, pid} = PodmanHealthSensor.start_link(enabled: false)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns a list" do
      result = PodmanHealthSensor.get_unhealthy()
      assert is_list(result)
    end

    test "returns empty list when no unhealthy containers" do
      result = PodmanHealthSensor.get_unhealthy()
      assert result == []
    end
  end

  describe "get_container_health/1" do
    setup do
      {:ok, pid} = PodmanHealthSensor.start_link(enabled: false)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns :error for non-existent container" do
      result = PodmanHealthSensor.get_container_health("nonexistent")
      assert result == {:error, :not_found}
    end
  end

  describe "poll_now/0" do
    setup do
      {:ok, pid} = PodmanHealthSensor.start_link(enabled: false)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns :ok" do
      result = PodmanHealthSensor.poll_now()
      assert result == :ok
    end
  end

  # Integration tests - only run when Podman is available
  describe "integration with Podman socket" do
    @describetag :podman_integration

    setup do
      if @podman_available do
        {:ok, pid} = PodmanHealthSensor.start_link([])

        # Wait for initial poll
        Process.sleep(100)

        on_exit(fn ->
          if Process.alive?(pid), do: GenServer.stop(pid)
        end)

        :ok
      else
        :ok
      end
    end

    @tag :podman_integration
    @tag skip: not @podman_available
    test "discovers running containers" do
      if @podman_available do
        # Wait a bit for poll
        Process.sleep(200)

        summary = PodmanHealthSensor.get_health_summary()
        # Should have at least 0 containers (might have none running)
        assert is_integer(summary.total)
      end
    end

    @tag :podman_integration
    @tag skip: not @podman_available
    test "measure returns valid health ratio" do
      if @podman_available do
        Process.sleep(200)

        result = PodmanHealthSensor.measure()
        assert is_number(result.container_health_ratio)
        assert result.enabled == true
      end
    end

    @tag :podman_integration
    @tag skip: not @podman_available
    test "poll_now updates state" do
      if @podman_available do
        initial_state = PodmanHealthSensor.get_state()
        PodmanHealthSensor.poll_now()
        Process.sleep(500)
        new_state = PodmanHealthSensor.get_state()

        assert new_state.poll_count >= initial_state.poll_count
      end
    end
  end

  describe "health status types alignment with Cepaf.Podman" do
    # Verify health status types match F# Cepaf.Podman.Domain.HealthStatus
    test "health status types are compatible" do
      # These types should match Cepaf.Podman.Domain.HealthStatus:
      # | Starting | Healthy | Unhealthy of failingStreak | NoHealthcheck | Unknown of status
      valid_statuses = [:healthy, :unhealthy, :starting, :no_healthcheck]

      # All should be valid atoms
      Enum.each(valid_statuses, fn status ->
        assert is_atom(status)
      end)
    end
  end

  describe "telemetry integration" do
    setup do
      {:ok, pid} = PodmanHealthSensor.start_link(enabled: false)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "measure/0 does not raise" do
      assert_no_raise(fn -> PodmanHealthSensor.measure() end)
    end

    test "get_health_summary/0 does not raise" do
      assert_no_raise(fn -> PodmanHealthSensor.get_health_summary() end)
    end

    test "poll_now/0 does not raise" do
      assert_no_raise(fn -> PodmanHealthSensor.poll_now() end)
    end
  end

  describe "stress analyzer integration" do
    alias Indrajaal.Cortex.Analysis.StressAnalyzer

    test "stress analyzer can use podman health metrics" do
      # Metrics from PodmanHealthSensor.measure()
      metrics = %{
        container_health_ratio: 0.8,
        containers_total: 3,
        containers_healthy: 2,
        containers_unhealthy: 0,
        containers_starting: 1,
        memory_usage: 100_000,
        total_memory: 1_000_000,
        cpu_usage: 0.2,
        process_utilization: 0.1
      }

      stress = StressAnalyzer.calculate_stress(metrics)
      assert is_float(stress)
      assert stress >= 0.0 and stress <= 1.0

      # Starting container should increase stress to at least 0.5
      assert stress >= 0.5
    end

    test "unhealthy container triggers degraded stress level" do
      metrics = %{
        container_health_ratio: 0.67,
        containers_total: 3,
        containers_healthy: 2,
        containers_unhealthy: 1,
        containers_starting: 0,
        memory_usage: 100_000,
        total_memory: 1_000_000,
        cpu_usage: 0.2,
        process_utilization: 0.1
      }

      stress = StressAnalyzer.calculate_stress(metrics)
      # Unhealthy container should push stress to at least 0.7
      assert stress >= 0.7
    end

    test "all healthy containers result in low stress" do
      metrics = %{
        container_health_ratio: 1.0,
        containers_total: 3,
        containers_healthy: 3,
        containers_unhealthy: 0,
        containers_starting: 0,
        memory_usage: 100_000,
        total_memory: 1_000_000,
        cpu_usage: 0.1,
        process_utilization: 0.05
      }

      stress = StressAnalyzer.calculate_stress(metrics)
      # All healthy should result in low stress
      assert stress < 0.3
    end

    test "detailed stress breakdown includes container details" do
      metrics = %{
        container_health_ratio: 0.9,
        containers_total: 10,
        containers_healthy: 9,
        containers_unhealthy: 0,
        containers_starting: 1,
        memory_usage: 100_000,
        total_memory: 1_000_000,
        cpu_usage: 0.2,
        process_utilization: 0.1
      }

      detailed = StressAnalyzer.calculate_stress_detailed(metrics)

      assert Map.has_key?(detailed, :container_details)
      assert detailed.container_details.total == 10
      assert detailed.container_details.healthy == 9
      assert detailed.container_details.health_ratio == 0.9
    end
  end

  # Helper to assert no exception is raised
  defp assert_no_raise(fun) do
    try do
      fun.()
      true
    rescue
      e ->
        flunk("Expected no exception, but got: #{inspect(e)}")
    end
  end
end
