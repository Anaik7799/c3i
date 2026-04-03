defmodule Indrajaal.Core.CpuGovernorTest do
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Core.CpuGovernor

  setup do
    # Stop existing instance if running
    case Process.whereis(CpuGovernor) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 1000)
    end

    # Clean up ETS table
    if :ets.whereis(:cpu_governor_metrics) != :undefined do
      :ets.delete(:cpu_governor_metrics)
    end

    :ok
  end

  describe "start_link/1" do
    test "starts the GenServer and returns {:ok, pid}" do
      assert {:ok, pid} = CpuGovernor.start_link()
      assert is_pid(pid)
      GenServer.stop(pid, :normal)
    end

    test "registers process under the module name" do
      {:ok, pid} = CpuGovernor.start_link()
      assert Process.whereis(CpuGovernor) == pid
      GenServer.stop(pid, :normal)
    end

    test "creates ETS table on start" do
      {:ok, pid} = CpuGovernor.start_link()
      assert :ets.whereis(:cpu_governor_metrics) != :undefined
      GenServer.stop(pid, :normal)
    end

    test "second start fails with already_started" do
      {:ok, pid} = CpuGovernor.start_link()
      assert {:error, {:already_started, ^pid}} = CpuGovernor.start_link()
      GenServer.stop(pid, :normal)
    end
  end

  describe "get_metrics/0" do
    test "returns empty map when no GenServer running" do
      assert CpuGovernor.get_metrics() == %{}
    end

    test "returns metrics map after GenServer start" do
      {:ok, pid} = CpuGovernor.start_link()
      metrics = CpuGovernor.get_metrics()
      assert is_map(metrics)
      assert Map.has_key?(metrics, :cpu_pct)
      assert Map.has_key?(metrics, :mode)
      assert Map.has_key?(metrics, :schedulers)
      GenServer.stop(pid, :normal)
    end
  end

  describe "get_metric/1" do
    test "returns nil when no GenServer running" do
      assert CpuGovernor.get_metric(:cpu_pct) == nil
    end

    test "returns specific metric value" do
      {:ok, pid} = CpuGovernor.start_link()
      assert is_integer(CpuGovernor.get_metric(:cpu_pct))
      GenServer.stop(pid, :normal)
    end
  end

  describe "current_mode/0" do
    test "returns :full by default" do
      assert CpuGovernor.current_mode() == :full
    end

    test "returns a valid mode atom" do
      {:ok, pid} = CpuGovernor.start_link()
      mode = CpuGovernor.current_mode()
      assert mode in [:full, :slight, :moderate, :heavy, :wait]
      GenServer.stop(pid, :normal)
    end
  end

  describe "current_cpu/0" do
    test "returns 0 when no GenServer running" do
      assert CpuGovernor.current_cpu() == 0
    end

    test "returns a non-negative integer" do
      {:ok, pid} = CpuGovernor.start_link()
      cpu = CpuGovernor.current_cpu()
      assert is_integer(cpu)
      assert cpu >= 0
      GenServer.stop(pid, :normal)
    end
  end

  describe "adaptive_env/0" do
    test "returns map with ELIXIR_ERL_OPTIONS, MIX_JOBS, NICE_LEVEL" do
      env = CpuGovernor.adaptive_env()
      assert Map.has_key?(env, "ELIXIR_ERL_OPTIONS")
      assert Map.has_key?(env, "MIX_JOBS")
      assert Map.has_key?(env, "NICE_LEVEL")
    end

    test "scheduler count is valid in ERL_OPTIONS" do
      env = CpuGovernor.adaptive_env()
      opts = env["ELIXIR_ERL_OPTIONS"]
      assert opts =~ ~r/\+S \d+:\d+ \+SDio \d+/
    end
  end

  describe "status/0" do
    test "returns comprehensive status map" do
      {:ok, pid} = CpuGovernor.start_link()
      status = CpuGovernor.status()

      assert is_map(status)
      assert Map.has_key?(status, :cpu_pct)
      assert Map.has_key?(status, :ewma_cpu)
      assert Map.has_key?(status, :mode)
      assert Map.has_key?(status, :schedulers)
      assert Map.has_key?(status, :jobs)
      assert Map.has_key?(status, :nice)
      assert Map.has_key?(status, :hard_limit)
      assert Map.has_key?(status, :pid_output)
      assert Map.has_key?(status, :entropy)
      assert Map.has_key?(status, :cores)

      GenServer.stop(pid, :normal)
    end

    test "hard_limit is 85" do
      {:ok, pid} = CpuGovernor.start_link()
      assert CpuGovernor.status().hard_limit == 85
      GenServer.stop(pid, :normal)
    end

    test "setpoint is 70.0" do
      {:ok, pid} = CpuGovernor.start_link()
      assert CpuGovernor.status().setpoint == 70.0
      GenServer.stop(pid, :normal)
    end
  end

  describe "over_limit?/0" do
    test "returns boolean" do
      assert is_boolean(CpuGovernor.over_limit?())
    end
  end

  describe "entropy/0" do
    test "returns a float" do
      assert is_float(CpuGovernor.entropy())
    end
  end

  describe "INV: formal invariants" do
    test "INV-1: cpu_pct in [0, 100]" do
      {:ok, pid} = CpuGovernor.start_link()
      cpu = CpuGovernor.current_cpu()
      assert cpu >= 0 and cpu <= 100
      GenServer.stop(pid, :normal)
    end

    test "INV-2: schedulers in [4, 16]" do
      {:ok, pid} = CpuGovernor.start_link()
      sched = CpuGovernor.status().schedulers
      assert sched >= 4 and sched <= 16
      GenServer.stop(pid, :normal)
    end

    test "INV-3: jobs in [4, 16]" do
      {:ok, pid} = CpuGovernor.start_link()
      jobs = CpuGovernor.status().jobs
      assert jobs >= 4 and jobs <= 16
      GenServer.stop(pid, :normal)
    end

    test "INV-4: nice in [10, 19]" do
      {:ok, pid} = CpuGovernor.start_link()
      nice = CpuGovernor.status().nice
      assert nice >= 10 and nice <= 19
      GenServer.stop(pid, :normal)
    end

    test "INV-5: mode is valid atom" do
      {:ok, pid} = CpuGovernor.start_link()
      mode = CpuGovernor.current_mode()
      assert mode in [:full, :slight, :moderate, :heavy, :wait]
      GenServer.stop(pid, :normal)
    end

    test "INV-8: ETS table exists while GenServer alive" do
      {:ok, pid} = CpuGovernor.start_link()
      assert :ets.whereis(:cpu_governor_metrics) != :undefined
      GenServer.stop(pid, :normal)
    end
  end

  describe "periodic check" do
    test "check_count increases over time" do
      {:ok, pid} = CpuGovernor.start_link()
      initial = CpuGovernor.status().check_count

      # Wait for at least one check cycle (2s interval)
      Process.sleep(2500)

      assert CpuGovernor.status().check_count > initial
      GenServer.stop(pid, :normal)
    end
  end
end
