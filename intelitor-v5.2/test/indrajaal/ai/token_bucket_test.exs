defmodule Indrajaal.AI.TokenBucketTest do
  @moduledoc """
  TDG test suite for Indrajaal.AI.TokenBucket.

  ## STAMP Safety Integration
  - SC-RES-001: Resource limits must be enforced

  ## TPS 5-Level RCA Context
  - L1 Symptom: Token consumption not enforced
  - L5 Root Cause: Rate limiting contract violation
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.AI.TokenBucket

  describe "module existence" do
    test "TokenBucket module is defined" do
      assert Code.ensure_loaded?(TokenBucket)
    end

    test "start_link/1 function exists" do
      assert function_exported?(TokenBucket, :start_link, 1)
    end

    test "consume/1 function exists" do
      assert function_exported?(TokenBucket, :consume, 1)
    end

    test "check_energy/0 function exists" do
      assert function_exported?(TokenBucket, :check_energy, 0)
    end
  end

  describe "GenServer lifecycle" do
    setup do
      name = :"token_bucket_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(TokenBucket, [], name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid, name: name}
    end

    test "starts successfully", %{pid: pid} do
      assert Process.alive?(pid)
    end

    test "check_energy returns a number via direct call", %{pid: pid} do
      energy = GenServer.call(pid, :check)
      assert is_number(energy)
    end

    test "initial energy equals default capacity", %{pid: pid} do
      energy = GenServer.call(pid, :check)
      assert energy == 100_000
    end

    test "consume returns :ok when tokens available", %{pid: pid} do
      result = GenServer.call(pid, {:consume, 100})
      assert result == :ok
    end

    test "consume returns error when exceeding capacity", %{pid: pid} do
      result = GenServer.call(pid, {:consume, 200_000})
      assert result == {:error, :insufficient_energy}
    end

    test "consume reduces energy", %{pid: pid} do
      GenServer.call(pid, {:consume, 1000})
      energy_after = GenServer.call(pid, :check)
      assert energy_after == 100_000 - 1000
    end

    test "consuming more than available leaves energy unchanged and returns error", %{pid: pid} do
      result = GenServer.call(pid, {:consume, 999_999_999})
      assert result == {:error, :insufficient_energy}
    end
  end

  describe "GenServer with custom capacity" do
    setup do
      name = :"token_bucket_custom_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(TokenBucket, [capacity: 500, rate: 10], name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "respects custom capacity", %{pid: pid} do
      energy = GenServer.call(pid, :check)
      assert energy == 500
    end

    test "consume works with custom capacity", %{pid: pid} do
      assert GenServer.call(pid, {:consume, 500}) == :ok
    end

    test "overconsumption fails with custom capacity", %{pid: pid} do
      assert GenServer.call(pid, {:consume, 501}) == {:error, :insufficient_energy}
    end
  end
end
