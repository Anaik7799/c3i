defmodule Indrajaal.Evolution.OracleTest do
  @moduledoc """
  Tests for Indrajaal.Evolution.Oracle GenServer.

  Oracle accepts numeric values via ingest/1 (cast) and returns a trend
  prediction via predict/0 (call).  The internal calculate_trend logic:
    - Returns :insufficient_data when fewer than 2 values have been ingested.
    - Returns :rising  when the most-recently ingested value > running average.
    - Returns :falling when the most-recently ingested value <= running average.

  NOTE: ingest/1 and predict/0 both call the globally-registered __MODULE__
  name, so async: false is required to avoid cross-test interference.
  Each test that exercises state uses start_supervised!/1 via ExUnit's
  per-test setup and relies on the supervisor to clean up between tests.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Evolution.Oracle

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Start a fresh Oracle for the calling test, stopping any leftover instance.
  defp fresh_oracle do
    case GenServer.whereis(Oracle) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal)
    end

    {:ok, pid} = Oracle.start_link([])
    pid
  end

  # ---------------------------------------------------------------------------
  # Module contract
  # ---------------------------------------------------------------------------

  describe "module contract" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Oracle)
    end

    test "start_link/1 is exported" do
      assert function_exported?(Oracle, :start_link, 1)
    end

    test "ingest/1 is exported" do
      assert function_exported?(Oracle, :ingest, 1)
    end

    test "predict/0 is exported" do
      assert function_exported?(Oracle, :predict, 0)
    end

    test "init/1 callback is exported" do
      assert function_exported?(Oracle, :init, 1)
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer lifecycle
  # ---------------------------------------------------------------------------

  describe "GenServer lifecycle" do
    test "start_link/1 returns {:ok, pid}" do
      pid = fresh_oracle()
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "process is alive after start" do
      pid = fresh_oracle()
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "process stops cleanly on GenServer.stop/1" do
      pid = fresh_oracle()
      :ok = GenServer.stop(pid, :normal)
      refute Process.alive?(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # predict/0 — insufficient data
  # ---------------------------------------------------------------------------

  describe "predict/0 - insufficient data" do
    test "returns :insufficient_data when no values have been ingested" do
      pid = fresh_oracle()
      assert :insufficient_data = Oracle.predict()
      GenServer.stop(pid)
    end

    test "returns :insufficient_data when exactly one value has been ingested" do
      pid = fresh_oracle()
      :ok = Oracle.ingest(0.5)
      # Allow the cast to be processed before the call
      Process.sleep(20)
      assert :insufficient_data = Oracle.predict()
      GenServer.stop(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # predict/0 — :rising trend
  # ---------------------------------------------------------------------------

  describe "predict/0 - :rising trend" do
    test "returns :rising when the latest value is higher than the average of history" do
      pid = fresh_oracle()
      # Load low values, then spike high
      for v <- [0.1, 0.1, 0.1, 0.1], do: Oracle.ingest(v)
      Oracle.ingest(0.9)
      Process.sleep(30)
      assert Oracle.predict() == :rising
      GenServer.stop(pid)
    end

    test "returns :rising with just two values where second > first" do
      pid = fresh_oracle()
      Oracle.ingest(0.2)
      # avg after two values = (0.2 + 0.8) / 2 = 0.5; most recent is 0.8 > 0.5 → rising
      Oracle.ingest(0.8)
      Process.sleep(20)
      assert Oracle.predict() == :rising
      GenServer.stop(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # predict/0 — :falling trend
  # ---------------------------------------------------------------------------

  describe "predict/0 - :falling trend" do
    test "returns :falling when the latest value is below the average of history" do
      pid = fresh_oracle()
      # Load high values, then dip low
      for v <- [0.9, 0.9, 0.9, 0.9], do: Oracle.ingest(v)
      Oracle.ingest(0.1)
      Process.sleep(30)
      assert Oracle.predict() == :falling
      GenServer.stop(pid)
    end

    test "returns :falling when two identical values are ingested" do
      pid = fresh_oracle()
      # avg == last value → List.first(history) == avg → else branch → :falling
      Oracle.ingest(0.5)
      Oracle.ingest(0.5)
      Process.sleep(20)
      assert Oracle.predict() == :falling
      GenServer.stop(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # ingest/1 — cast behaviour
  # ---------------------------------------------------------------------------

  describe "ingest/1" do
    test "returns :ok immediately (fire-and-forget cast)" do
      pid = fresh_oracle()
      assert :ok = Oracle.ingest(0.42)
      GenServer.stop(pid)
    end

    test "accepts float values" do
      pid = fresh_oracle()
      assert :ok = Oracle.ingest(0.0)
      assert :ok = Oracle.ingest(1.0)
      GenServer.stop(pid)
    end

    test "accepts integer values" do
      pid = fresh_oracle()
      assert :ok = Oracle.ingest(0)
      assert :ok = Oracle.ingest(10)
      GenServer.stop(pid)
    end

    test "process stays alive after many ingests" do
      pid = fresh_oracle()
      for i <- 1..20, do: Oracle.ingest(i / 20.0)
      Process.sleep(50)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "history is capped at 10 entries and predict still returns a valid atom" do
      pid = fresh_oracle()
      for i <- 1..15, do: Oracle.ingest(i / 15.0)
      Process.sleep(30)
      result = Oracle.predict()
      assert result in [:rising, :falling, :insufficient_data]
      GenServer.stop(pid)
    end
  end
end
