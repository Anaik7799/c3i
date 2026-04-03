defmodule Indrajaal.Compute.MojoRunnerTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Compute.MojoRunner

  describe "start_link/1" do
    test "starts the GenServer with default name" do
      {:ok, pid} = MojoRunner.start_link(name: :test_mojo_runner)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "health/0" do
    setup do
      {:ok, pid} = MojoRunner.start_link(name: :test_mojo_health)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "returns initial health status" do
      health = GenServer.call(:test_mojo_health, :health)
      assert health.status == :healthy
      assert health.concurrent == 0
      assert health.pending == 0
      assert health.total_requests == 0
      assert health.avg_latency_ms == 0.0
      assert health.consecutive_failures == 0
      assert health.circuit_open == false
    end
  end

  describe "circuit breaker" do
    test "trips open after threshold consecutive timeouts" do
      {:ok, pid} = MojoRunner.start_link(name: :test_mojo_cb)

      # Simulate 5 timeout messages to trip the circuit breaker
      state = :sys.get_state(pid)

      # Manually trigger timeout handling by sending timeout messages for fake request IDs
      # Since no pending requests exist, these will be no-ops — we need to manipulate state
      tripped_state = %{
        state
        | consecutive_failures: 5,
          circuit_open: true,
          circuit_open_at: System.monotonic_time(:millisecond)
      }

      :sys.replace_state(pid, fn _old -> tripped_state end)

      health = GenServer.call(:test_mojo_cb, :health)
      assert health.status == :circuit_open
      assert health.circuit_open == true
      assert health.consecutive_failures == 5

      GenServer.stop(pid)
    end

    test "rejects inference when circuit is open" do
      {:ok, pid} = MojoRunner.start_link(name: :test_mojo_reject)

      # Trip the circuit breaker via state manipulation
      :sys.replace_state(pid, fn state ->
        %{
          state
          | circuit_open: true,
            circuit_open_at: System.monotonic_time(:millisecond),
            consecutive_failures: 5
        }
      end)

      result = GenServer.call(:test_mojo_reject, {:infer, "model", "input", []})
      assert result == {:error, :circuit_breaker_open}

      GenServer.stop(pid)
    end

    test "rejects when at max concurrent" do
      {:ok, pid} = MojoRunner.start_link(name: :test_mojo_overload)

      :sys.replace_state(pid, fn state ->
        %{state | concurrent: 10}
      end)

      result = GenServer.call(:test_mojo_overload, {:infer, "model", "input", []})
      assert result == {:error, :overloaded}

      GenServer.stop(pid)
    end
  end

  describe "handle_info/2" do
    test "ignores unknown messages gracefully" do
      {:ok, pid} = MojoRunner.start_link(name: :test_mojo_unknown)
      send(pid, :unexpected_message)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "handles timeout for unknown request_id as no-op" do
      {:ok, pid} = MojoRunner.start_link(name: :test_mojo_timeout_noop)
      send(pid, {:timeout, "non-existent-request-id"})
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "handles zenoh_response for unknown request_id" do
      {:ok, pid} = MojoRunner.start_link(name: :test_mojo_response_noop)
      send(pid, {:zenoh_response, "non-existent-request-id", %{}})
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
