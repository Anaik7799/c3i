defmodule Indrajaal.Cortex.Reflexes.CircuitBreakerTest do
  @moduledoc """
  Tests for the CircuitBreaker module.

  STAMP Compliance:
  - SC-CTX-003: Graceful degradation
  - SC-EMR-058: Automatic failure detection
  - SC-OBS-071: Circuit breaker observability

  TDG: Test-Driven Generation - tests created before implementation validation.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cortex.Reflexes.CircuitBreaker

  describe "start_link/1" do
    test "starts the circuit breaker process or uses existing" do
      case Process.whereis(CircuitBreaker) do
        nil ->
          # Not running, start fresh
          assert {:ok, pid} = CircuitBreaker.start_link([])
          assert Process.alive?(pid)

        pid ->
          # Already running from application supervisor
          assert Process.alive?(pid)
      end
    end

    test "process is registered with expected name" do
      case Process.whereis(CircuitBreaker) do
        nil ->
          {:ok, pid} = CircuitBreaker.start_link([])
          assert Process.whereis(CircuitBreaker) == pid

        pid ->
          # Already registered from application supervisor
          assert Process.whereis(CircuitBreaker) == pid
      end
    end

    test "has default circuits registered" do
      # Ensure process is running
      case Process.whereis(CircuitBreaker) do
        nil -> CircuitBreaker.start_link([])
        _ -> :ok
      end

      status = CircuitBreaker.status()

      assert Map.has_key?(status, :database)
      assert Map.has_key?(status, :external_api)
      assert Map.has_key?(status, :ml_inference)
      assert Map.has_key?(status, :flame_pool)
    end
  end

  describe "register/2" do
    setup do
      case Process.whereis(CircuitBreaker) do
        nil ->
          {:ok, pid} = CircuitBreaker.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "registers a new circuit breaker", %{pid: _pid} do
      assert :ok = CircuitBreaker.register(:test_circuit)

      status = CircuitBreaker.status()
      assert Map.has_key?(status, :test_circuit)
    end

    test "registers with custom options", %{pid: _pid} do
      assert :ok =
               CircuitBreaker.register(:custom_circuit,
                 failure_threshold: 10,
                 reset_timeout: 60_000
               )

      {:ok, info} = CircuitBreaker.status(:custom_circuit)
      assert info.failure_threshold == 10
    end
  end

  describe "call/2" do
    setup do
      case Process.whereis(CircuitBreaker) do
        nil ->
          {:ok, pid} = CircuitBreaker.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "executes function when circuit is closed", %{pid: _pid} do
      CircuitBreaker.register(:test_call)

      result = CircuitBreaker.call(:test_call, fn -> {:success, 42} end)

      assert result == {:ok, {:success, 42}}
    end

    test "returns error for unknown circuit", %{pid: _pid} do
      result = CircuitBreaker.call(:nonexistent, fn -> :ok end)

      assert result == {:error, :circuit_not_found}
    end

    test "returns error when function raises", %{pid: _pid} do
      CircuitBreaker.register(:test_error)

      result = CircuitBreaker.call(:test_error, fn -> raise "test error" end)

      assert {:error, %RuntimeError{message: "test error"}} = result
    end

    test "trips circuit after failure threshold", %{pid: _pid} do
      CircuitBreaker.register(:trip_test, failure_threshold: 2)

      # First failure
      CircuitBreaker.call(:trip_test, fn -> raise "error 1" end)

      # Second failure - should trip
      CircuitBreaker.call(:trip_test, fn -> raise "error 2" end)

      # Circuit should now be open
      {:ok, info} = CircuitBreaker.status(:trip_test)
      assert info.state == :open
    end

    test "rejects calls when circuit is open", %{pid: _pid} do
      CircuitBreaker.register(:reject_test, failure_threshold: 1)

      # Trip the circuit
      CircuitBreaker.call(:reject_test, fn -> raise "error" end)

      # Should be rejected
      result = CircuitBreaker.call(:reject_test, fn -> :should_not_execute end)

      assert result == {:error, :circuit_open}
    end
  end

  describe "status/0 and status/1" do
    setup do
      case Process.whereis(CircuitBreaker) do
        nil ->
          {:ok, pid} = CircuitBreaker.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "status/0 returns all circuit states", %{pid: _pid} do
      status = CircuitBreaker.status()

      assert is_map(status)
      # Default circuits should be present
      assert Map.has_key?(status, :database)
    end

    test "status/1 returns specific circuit info", %{pid: _pid} do
      {:ok, info} = CircuitBreaker.status(:database)

      assert is_map(info)
      assert Map.has_key?(info, :name)
      assert Map.has_key?(info, :state)
      assert Map.has_key?(info, :failure_count)
      assert Map.has_key?(info, :failure_threshold)
    end

    test "status/1 returns error for unknown circuit", %{pid: _pid} do
      result = CircuitBreaker.status(:unknown)

      assert result == {:error, :not_found}
    end
  end

  describe "trip/1 and reset/1" do
    setup do
      case Process.whereis(CircuitBreaker) do
        nil ->
          {:ok, pid} = CircuitBreaker.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "trip/1 manually trips a circuit", %{pid: _pid} do
      CircuitBreaker.register(:manual_trip)

      assert :ok = CircuitBreaker.trip(:manual_trip)

      {:ok, info} = CircuitBreaker.status(:manual_trip)
      assert info.state == :open
    end

    test "reset/1 resets a tripped circuit", %{pid: _pid} do
      CircuitBreaker.register(:manual_reset)
      CircuitBreaker.trip(:manual_reset)

      assert :ok = CircuitBreaker.reset(:manual_reset)

      {:ok, info} = CircuitBreaker.status(:manual_reset)
      assert info.state == :closed
    end

    test "trip/1 returns error for unknown circuit", %{pid: _pid} do
      result = CircuitBreaker.trip(:unknown)

      assert result == {:error, :not_found}
    end

    test "reset/1 returns error for unknown circuit", %{pid: _pid} do
      result = CircuitBreaker.reset(:unknown)

      assert result == {:error, :not_found}
    end
  end

  describe "metrics/0" do
    setup do
      case Process.whereis(CircuitBreaker) do
        nil ->
          {:ok, pid} = CircuitBreaker.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns metrics map", %{pid: _pid} do
      metrics = CircuitBreaker.metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :total_calls)
      assert Map.has_key?(metrics, :successful_calls)
      assert Map.has_key?(metrics, :failed_calls)
      assert Map.has_key?(metrics, :rejected_calls)
      assert Map.has_key?(metrics, :trips)
      assert Map.has_key?(metrics, :resets)
    end

    test "tracks successful calls", %{pid: _pid} do
      CircuitBreaker.register(:metrics_success)

      CircuitBreaker.call(:metrics_success, fn -> :ok end)
      CircuitBreaker.call(:metrics_success, fn -> :ok end)

      metrics = CircuitBreaker.metrics()

      assert metrics.successful_calls >= 2
    end

    test "tracks failed calls", %{pid: _pid} do
      CircuitBreaker.register(:metrics_fail)

      CircuitBreaker.call(:metrics_fail, fn -> raise "error" end)

      metrics = CircuitBreaker.metrics()

      assert metrics.failed_calls >= 1
    end

    test "tracks circuit states", %{pid: _pid} do
      metrics = CircuitBreaker.metrics()

      assert Map.has_key?(metrics, :circuit_states)
      assert Map.has_key?(metrics, :total_circuits)
    end
  end

  describe "half-open state" do
    setup do
      case Process.whereis(CircuitBreaker) do
        nil ->
          {:ok, pid} = CircuitBreaker.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "successful call in half-open state closes circuit", %{pid: _pid} do
      CircuitBreaker.register(:half_open_success, failure_threshold: 1, reset_timeout: 50)

      # Trip the circuit
      CircuitBreaker.call(:half_open_success, fn -> raise "error" end)

      # Wait for half-open transition
      Process.sleep(100)

      # Call in half-open should succeed and close circuit
      result = CircuitBreaker.call(:half_open_success, fn -> :recovered end)

      assert result == {:ok, :recovered}

      {:ok, info} = CircuitBreaker.status(:half_open_success)
      assert info.state == :closed
    end

    test "failed call in half-open state re-trips circuit", %{pid: _pid} do
      CircuitBreaker.register(:half_open_fail, failure_threshold: 1, reset_timeout: 50)

      # Trip the circuit
      CircuitBreaker.call(:half_open_fail, fn -> raise "error" end)

      # Wait for half-open transition
      Process.sleep(100)

      # Force transition to half-open by triggering check
      # (The internal timer should have fired)

      # Fail again in half-open
      CircuitBreaker.call(:half_open_fail, fn -> raise "still broken" end)

      {:ok, info} = CircuitBreaker.status(:half_open_fail)
      assert info.state == :open
    end
  end

  describe "STAMP compliance" do
    setup do
      case Process.whereis(CircuitBreaker) do
        nil ->
          {:ok, pid} = CircuitBreaker.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "SC-CTX-003: provides graceful degradation", %{pid: _pid} do
      CircuitBreaker.register(:graceful, failure_threshold: 2)

      # Simulate failures
      CircuitBreaker.call(:graceful, fn -> raise "fail 1" end)
      CircuitBreaker.call(:graceful, fn -> raise "fail 2" end)

      # Circuit should be open, rejecting calls (graceful degradation)
      result = CircuitBreaker.call(:graceful, fn -> :should_not_run end)
      assert result == {:error, :circuit_open}
    end

    test "SC-EMR-058: automatic failure detection", %{pid: _pid} do
      CircuitBreaker.register(:auto_detect, failure_threshold: 3)

      # Failures are automatically tracked
      for _ <- 1..3 do
        CircuitBreaker.call(:auto_detect, fn -> raise "error" end)
      end

      {:ok, info} = CircuitBreaker.status(:auto_detect)
      assert info.state == :open
      assert info.failure_count >= 3
    end

    test "SC-OBS-071: circuit breaker observability", %{pid: _pid} do
      # Can observe all circuits
      status = CircuitBreaker.status()
      assert is_map(status)

      # Can observe individual circuit
      {:ok, info} = CircuitBreaker.status(:database)
      assert Map.has_key?(info, :state)
      assert Map.has_key?(info, :failure_count)
      assert Map.has_key?(info, :last_failure_at)

      # Can observe aggregate metrics
      metrics = CircuitBreaker.metrics()
      assert Map.has_key?(metrics, :total_calls)
    end
  end
end
