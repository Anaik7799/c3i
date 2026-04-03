defmodule Indrajaal.KMS.Bootstrap.SequenceTest do
  @moduledoc """
  Tests for Indrajaal.KMS.Bootstrap.Sequence.

  Covers:
  - Module existence and public API surface
  - start/0 return value contract
  - start/0 idempotency: calling twice handles the already-started HealthMonitor

  STAMP: SC-KMS-001, SC-COG-001, SC-SMRITI-050

  NOTE: start/0 starts HealthMonitor (a globally-named GenServer). Each test
  that calls start/0 must stop the HealthMonitor in an on_exit callback.
  Tests that need HealthMonitor running use start_supervised so ExUnit owns
  the lifecycle. Remaining tests tolerate :already_started by matching on both
  success and the already-started variant.
  """
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.Bootstrap.Sequence
  alias Indrajaal.KMS.Monitoring.HealthMonitor

  # ---------------------------------------------------------------------------
  # Module existence
  # ---------------------------------------------------------------------------

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Sequence)
    end

    test "exports start/0" do
      assert function_exported?(Sequence, :start, 0)
    end
  end

  # ---------------------------------------------------------------------------
  # start/0 return value
  # ---------------------------------------------------------------------------

  describe "start/0 return value" do
    setup do
      on_exit(fn ->
        case Process.whereis(HealthMonitor) do
          nil -> :ok
          pid -> if Process.alive?(pid), do: GenServer.stop(pid, :normal)
        end
      end)

      :ok
    end

    test "returns {:ok, :started} on first call" do
      result = Sequence.start()
      assert {:ok, :started} = result
    end

    test "return value is a two-element tuple" do
      result = Sequence.start()
      assert is_tuple(result)
      assert tuple_size(result) == 2
    end

    test "first element of result is :ok" do
      {status, _} = Sequence.start()
      assert status == :ok
    end

    test "second element of result is :started" do
      {_, detail} = Sequence.start()
      assert detail == :started
    end
  end

  # ---------------------------------------------------------------------------
  # start/0 called when HealthMonitor already running
  # ---------------------------------------------------------------------------

  describe "start/0 when HealthMonitor already running" do
    setup do
      # Pre-start the HealthMonitor under test supervision
      start_supervised!(HealthMonitor)
      :ok
    end

    test "still returns {:ok, :started} when HealthMonitor is already started" do
      # Phase1-3 are pure :ok stubs; HealthMonitor.start_link/0 returns
      # {:error, {:already_started, pid}} but Sequence.start/0 always returns
      # {:ok, :started} regardless (it ignores the HealthMonitor return value)
      result = Sequence.start()
      assert {:ok, :started} = result
    end

    test "calling start/0 twice does not crash" do
      assert {:ok, :started} = Sequence.start()
      assert {:ok, :started} = Sequence.start()
    end
  end

  # ---------------------------------------------------------------------------
  # Phase functions (indirectly via start/0)
  # ---------------------------------------------------------------------------

  describe "phase execution via start/0" do
    setup do
      on_exit(fn ->
        case Process.whereis(HealthMonitor) do
          nil -> :ok
          pid -> if Process.alive?(pid), do: GenServer.stop(pid, :normal)
        end
      end)

      :ok
    end

    test "all phases complete without raising" do
      assert {:ok, :started} = Sequence.start()
    end

    test "start/0 leaves HealthMonitor process alive after success" do
      {:ok, :started} = Sequence.start()
      pid = Process.whereis(HealthMonitor)
      assert pid != nil
      assert Process.alive?(pid)
    end
  end
end
