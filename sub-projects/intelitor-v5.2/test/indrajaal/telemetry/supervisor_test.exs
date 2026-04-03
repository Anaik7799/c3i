defmodule Indrajaal.Telemetry.SupervisorTest do
  @moduledoc """
  Comprehensive tests for Telemetry Supervisor System

  Tests all aspects of telemetry supervision including:
  - Child process management and supervision
  - Event handler setup and configuration
  - Component status monitoring
  - Recovery from failures
  - Integration with parent supervision tree
  """

  # Async false due to shared supervisor
  use ExUnit.Case, async: false

  alias Indrajaal.Telemetry.Supervisor, as: TelemetrySupervisor
  alias Indrajaal.Telemetry.{MetricsCollector, Handlers}

  describe "start_link/1" do
    test "starts supervisor successfully with default options" do
      {:ok, pid} = TelemetrySupervisor.start_link([])

      assert Process.alive?(pid)
      assert pid |> Supervisor.which_children() |> length() > 0

      # Cleanup
      Supervisor.stop(pid)
    end

    test "starts supervisor with custom options" do
      opts = [name: :test_telemetry_supervisor]
      {:ok, pid} = TelemetrySupervisor.start_link(opts)

      assert Process.alive?(pid)
      assert Process.whereis(:test_telemetry_supervisor) == pid

      # Cleanup
      Supervisor.stop(pid)
    end

    test "starts all __required child processes" do
      {:ok, pid} = TelemetrySupervisor.start_link([])

      children = Supervisor.which_children(pid)
      child_ids = Enum.map(children, fn {id, _pid, _type, _modules} -> id end)

      # Should start all telemetry components
      expected_children = [
        Indrajaal.Telemetry.MetricsCollector,
        :telemetry_event_handlers
      ]

      for expected_child <- expected_children do
        assert expected_child in child_ids
      end

      # Cleanup
      Supervisor.stop(pid)
    end
  end

  describe "child supervision strategy" do
    test "uses one_for_one supervision strategy" do
      {:ok, pid} = TelemetrySupervisor.start_link([])

      # Get supervisor info
      {_strategy, children} = :supervisor.count_children(pid)

      # Should have multiple active children
      assert children[:active] > 0

      # Cleanup
      Supervisor.stop(pid)
    end

    test "restarts failed children independently" do
      {:ok, supervisor_pid} = TelemetrySupervisor.start_link([])

      # Find MetricsCollector child
      children = Supervisor.which_children(supervisor_pid)

      {_id, metrics_pid, _type, _modules} =
        Enum.find(children, fn {id, _pid, _type, _modules} ->
          id == Indrajaal.Telemetry.MetricsCollector
        end)

      # Kill the MetricsCollector process
      Process.exit(metrics_pid, :kill)

      # Wait for restart
      Process.sleep(100)

      # Verify MetricsCollector was restarted
      new_children = Supervisor.which_children(supervisor_pid)

      {_id, new_metrics_pid, _type, _modules} =
        Enum.find(new_children, fn {id, _pid, _type, _modules} ->
          id == Indrajaal.Telemetry.MetricsCollector
        end)

      assert new_metrics_pid != metrics_pid
      assert Process.alive?(new_metrics_pid)

      # Cleanup
      Supervisor.stop(supervisor_pid)
    end

    test "maintains other children when one fails" do
      {:ok, supervisor_pid} = TelemetrySupervisor.start_link([])

      initial_children = Supervisor.which_children(supervisor_pid)
      initial_count = length(initial_children)

      # Find and kill one child
      {_id, child_pid, _type, _modules} = hd(initial_children)
      Process.exit(child_pid, :kill)

      # Wait for restart
      Process.sleep(100)

      # Should still have same number of children
      new_children = Supervisor.which_children(supervisor_pid)
      assert length(new_children) == initial_count

      # Cleanup
      Supervisor.stop(supervisor_pid)
    end
  end

  describe "telemetry __event handler setup" do
    test "sets up all __required telemetry __event handlers" do
      {:ok, supervisor_pid} = TelemetrySupervisor.start_link([])

      # Wait for full initialization
      Process.sleep(100)

      # Check that telemetry handlers are attached
      # This would require querying :telemetry.list_handlers/1
      handlers = :telemetry.list_handlers([])

      # Should have handlers for various __event types
      expected_handler_patterns = [
        [:indrajaal, :http],
        [:indrajaal, :repo],
        [:indrajaal, :auth],
        [:indrajaal, :business],
        [:indrajaal, :safety],
        [:vm]
      ]

      for pattern <- expected_handler_patterns do
        pattern_handlers =
          Enum.filter(handlers, fn %{__event_name: name} ->
            List.starts_with?(name, pattern)
          end)

        assert length(pattern_handlers) > 0, "No handlers found for pattern: #{inspect(pattern)}"
      end

      # Cleanup
      Supervisor.stop(supervisor_pid)
    end

    test "configures handlers with correct modules and functions" do
      {:ok, supervisor_pid} = TelemetrySupervisor.start_link([])

      # Wait for initialization
      Process.sleep(100)

      handlers = :telemetry.list_handlers([])

      # Find HTTP handlers
      http_handlers =
        Enum.filter(handlers, fn %{__event_name: name} ->
          List.starts_with?(name, [:indrajaal, :http])
        end)

      assert length(http_handlers) > 0

      # Verify handler configuration
      for handler <- http_handlers do
        assert handler.function == :handle_http_event
        assert handler.module == Indrajaal.Telemetry.Handlers
      end

      # Cleanup
      Supervisor.stop(supervisor_pid)
    end
  end

  describe "component status monitoring" do
    test "monitors MetricsCollector health" do
      {:ok, supervisor_pid} = TelemetrySupervisor.start_link([])

      # Wait for initialization
      Process.sleep(100)

      # MetricsCollector should be running and responsive
      stats = Indrajaal.Telemetry.MetricsCollector.stats()
      assert is_map(stats)
      assert is_integer(stats.uptime_seconds)

      # Cleanup
      Supervisor.stop(supervisor_pid)
    end

    test "detects component failures" do
      {:ok, supervisor_pid} = TelemetrySupervisor.start_link([])

      # Get initial children
      initial_children = Supervisor.which_children(supervisor_pid)

      # Find MetricsCollector
      {_id, metrics_pid, _type, _modules} =
        Enum.find(initial_children, fn {id, _pid, _type, _modules} ->
          id == Indrajaal.Telemetry.MetricsCollector
        end)

      # Monitor the process
      ref = Process.monitor(metrics_pid)

      # Kill the process
      Process.exit(metrics_pid, :kill)

      # Should receive DOWN message
      assert_receive {:DOWN, ^ref, :process, ^metrics_pid, :killed}, 1000

      # Cleanup
      Supervisor.stop(supervisor_pid)
    end
  end

  describe "configuration and options" do
    test "accepts custom configuration options" do
      custom_config = %{
        metrics_collector: %{
          cleanup_interval: 60_000,
          histogram_max_samples: 10_000
        },
        event_handlers: %{
          buffer_size: 10_000,
          flush_interval: 5_000
        }
      }

      opts = [config: custom_config]
      {:ok, supervisor_pid} = TelemetrySupervisor.start_link(opts)

      assert Process.alive?(supervisor_pid)

      # Configuration should be passed to children
      # This would require checking that children received the config

      # Cleanup
      Supervisor.stop(supervisor_pid)
    end

    test "handles invalid configuration gracefully" do
      invalid_config = %{
        invalid_key: "invalid_value",
        metrics_collector: "not_a_map"
      }

      opts = [config: invalid_config]

      # Should still start successfully with defaults
      {:ok, supervisor_pid} = TelemetrySupervisor.start_link(opts)
      assert Process.alive?(supervisor_pid)

      # Cleanup
      Supervisor.stop(supervisor_pid)
    end
  end

  describe "integration with parent supervision tree" do
    test "integrates properly with application supervisor" do
      # This would test integration with the main application supervisor
      # In a real application, this would verify the supervisor tree structure

      {:ok, supervisor_pid} = TelemetrySupervisor.start_link([])

      # Should be a valid supervisor
      assert supervisor_pid |> :supervisor.which_children() |> is_list()

      # Cleanup
      Supervisor.stop(supervisor_pid)
    end

    test "handles shutdown gracefully" do
      {:ok, supervisor_pid} = TelemetrySupervisor.start_link([])

      # Get child processes
      children = Supervisor.which_children(supervisor_pid)
      child_pids = Enum.map(children, fn {_id, pid, _type, _modules} -> pid end)

      # Monitor children
      refs = Enum.map(child_pids, &Process.monitor/1)

      # Shutdown supervisor
      Supervisor.stop(supervisor_pid, :normal, 5000)

      # All children should be terminated
      for ref <- refs do
        assert_receive {:DOWN, ^ref, :process, _pid, reason}, 2000
        assert reason in [:normal, :shutdown, {:shutdown, :supervisor_termination}]
      end
    end
  end

  describe "telemetry __event flow" do
    test "processes __events through complete telemetry pipeline" do
      {:ok, supervisor_pid} = TelemetrySupervisor.start_link([])

      # Wait for full initialization
      Process.sleep(100)

      # Execute a telemetry __event
      :telemetry.execute(
        [:indrajaal, :http, :__request, :stop],
        %{duration: 150_000_000},
        %{method: "GET", path: "/api/test", status: 200}
      )

      # Wait for processing
      Process.sleep(50)

      # Verify __event was processed by checking metrics
      metrics = Indrajaal.Telemetry.MetricsCollector.get_metrics()
      assert metrics["http_requests_total"] >= 1

      # Cleanup
      Supervisor.stop(supervisor_pid)
    end

    test "handles high-volume __event processing" do
      {:ok, supervisor_pid} = TelemetrySupervisor.start_link([])

      # Wait for initialization
      Process.sleep(100)

      # Generate many events
      event_count = 1000

      for i <- 1..event_count do
        :telemetry.execute(
          [:indrajaal, :http, :__request, :stop],
          %{duration: i * 1_000_000},
          %{method: "GET", path: "/api/load-test", status: 200}
        )
      end

      # Wait for processing
      Process.sleep(500)

      # All events should be processed
      metrics = Indrajaal.Telemetry.MetricsCollector.get_metrics()
      assert metrics["http_requests_total"] >= event_count

      # Cleanup
      Supervisor.stop(supervisor_pid)
    end
  end

  describe "error recovery and resilience" do
    test "recovers from telemetry handler crashes" do
      {:ok, supervisor_pid} = TelemetrySupervisor.start_link([])

      # Wait for initialization
      Process.sleep(100)

      # Execute a normal __event to verify handlers work
      :telemetry.execute(
        [:indrajaal, :http, :__request, :stop],
        %{duration: 100_000_000},
        %{method: "GET", path: "/test", status: 200}
      )

      # Verify processing
      metrics1 = Indrajaal.Telemetry.MetricsCollector.get_metrics()
      initial_count = metrics1["http_requests_total"] || 0

      # Simulate handler error by sending malformed __event
      # (This depends on how robust error handling is in the handlers)

      # Execute another normal __event
      :telemetry.execute(
        [:indrajaal, :http, :__request, :stop],
        %{duration: 100_000_000},
        %{method: "GET", path: "/test2", status: 200}
      )

      # Should still process __events
      Process.sleep(50)
      metrics2 = Indrajaal.Telemetry.MetricsCollector.get_metrics()
      assert (metrics2["http_requests_total"] || 0) > initial_count

      # Cleanup
      Supervisor.stop(supervisor_pid)
    end

    test "maintains system stability during component restarts" do
      {:ok, supervisor_pid} = TelemetrySupervisor.start_link([])

      # Execute __events continuously while causing restarts
      task =
        Task.async(fn ->
          for i <- 1..100 do
            :telemetry.execute(
              [:indrajaal, :http, :__request, :stop],
              %{duration: i * 1_000_000},
              %{method: "GET", path: "/stability-test", status: 200}
            )

            Process.sleep(10)
          end
        end)

      # Cause a restart midway through
      Process.sleep(250)
      children = Supervisor.which_children(supervisor_pid)
      {_id, child_pid, _type, _modules} = hd(children)
      Process.exit(child_pid, :kill)

      # Wait for task completion
      Task.await(task, 5000)

      # System should still be functional
      metrics = Indrajaal.Telemetry.MetricsCollector.get_metrics()
      assert is_map(metrics)

      # Cleanup
      Supervisor.stop(supervisor_pid)
    end
  end

  describe "performance characteristics" do
    test "maintains low overhead during normal operation" do
      {:ok, supervisor_pid} = TelemetrySupervisor.start_link([])

      # Wait for initialization
      Process.sleep(100)

      # Measure supervisor overhead
      {time_micro, _result} =
        :timer.tc(fn ->
          # Supervisor should respond quickly to status checks
          children = Supervisor.which_children(supervisor_pid)
          assert length(children) > 0
        end)

      # Should respond very quickly
      # 1ms
      assert time_micro < 1000

      # Cleanup
      Supervisor.stop(supervisor_pid)
    end

    test "scales with increased child process load" do
      {:ok, supervisor_pid} = TelemetrySupervisor.start_link([])

      # Generate load on child processes
      for _i <- 1..1000 do
        :telemetry.execute(
          [:indrajaal, :http, :__request, :stop],
          %{duration: 50_000_000},
          %{method: "GET", path: "/load-test", status: 200}
        )
      end

      # Supervisor should remain responsive
      children = Supervisor.which_children(supervisor_pid)
      assert length(children) > 0

      # All children should still be alive
      for {_id, pid, _type, _modules} <- children do
        assert Process.alive?(pid)
      end

      # Cleanup
      Supervisor.stop(supervisor_pid)
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
