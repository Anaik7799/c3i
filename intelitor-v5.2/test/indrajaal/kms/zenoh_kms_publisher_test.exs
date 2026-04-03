defmodule Indrajaal.KMS.ZenohKmsPublisherTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.KMS.ZenohKmsPublisher.
  Tests GenServer start contract, pure subscribe_keys/0, get_stats/0, and
  public API surface. Init creates only in-memory struct state; Zenoh
  coordinator is nil-safe (optional), safe to start_supervised.
  STAMP: SC-KMS-005 (cross-runtime sync), SC-ZENOH-INT-001 (universal access)
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.ZenohKmsPublisher

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ZenohKmsPublisher)
    end

    test "implements GenServer behaviour" do
      assert function_exported?(ZenohKmsPublisher, :start_link, 1)
      assert function_exported?(ZenohKmsPublisher, :init, 1)
    end
  end

  describe "public API surface" do
    test "exports publish_holon_created/1" do
      assert function_exported?(ZenohKmsPublisher, :publish_holon_created, 1)
    end

    test "exports publish_holon_updated/1" do
      assert function_exported?(ZenohKmsPublisher, :publish_holon_updated, 1)
    end

    test "exports publish_holon_deleted/1" do
      assert function_exported?(ZenohKmsPublisher, :publish_holon_deleted, 1)
    end

    test "exports publish_state_snapshot/0" do
      assert function_exported?(ZenohKmsPublisher, :publish_state_snapshot, 0)
    end

    test "exports publish_now/0" do
      assert function_exported?(ZenohKmsPublisher, :publish_now, 0)
    end

    test "exports get_stats/0" do
      assert function_exported?(ZenohKmsPublisher, :get_stats, 0)
    end

    test "exports subscribe_keys/0" do
      assert function_exported?(ZenohKmsPublisher, :subscribe_keys, 0)
    end
  end

  describe "subscribe_keys/0" do
    test "returns a list" do
      keys = ZenohKmsPublisher.subscribe_keys()
      assert is_list(keys)
    end

    test "returns exactly 3 key expressions" do
      keys = ZenohKmsPublisher.subscribe_keys()
      assert length(keys) == 3
    end

    test "all keys are binary strings" do
      keys = ZenohKmsPublisher.subscribe_keys()

      Enum.each(keys, fn key ->
        assert is_binary(key)
        assert String.length(key) > 0
      end)
    end

    test "keys use indrajaal/kms prefix" do
      keys = ZenohKmsPublisher.subscribe_keys()

      Enum.each(keys, fn key ->
        assert String.starts_with?(key, "indrajaal/kms")
      end)
    end

    test "keys cover holons, state, and query namespaces" do
      keys = ZenohKmsPublisher.subscribe_keys()
      key_string = Enum.join(keys, " ")

      assert String.contains?(key_string, "holons")
      assert String.contains?(key_string, "state")
      assert String.contains?(key_string, "query")
    end

    test "returns same result on repeated calls (pure function)" do
      keys1 = ZenohKmsPublisher.subscribe_keys()
      keys2 = ZenohKmsPublisher.subscribe_keys()
      assert keys1 == keys2
    end
  end

  describe "start_link/1 contract" do
    test "starts GenServer with empty opts" do
      {:ok, pid} = start_supervised({ZenohKmsPublisher, []})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "initial state has zero publish count" do
      {:ok, pid} = start_supervised({ZenohKmsPublisher, []})
      state = :sys.get_state(pid)
      assert state.publish_count == 0
    end

    test "initial state has zero sequence" do
      {:ok, pid} = start_supervised({ZenohKmsPublisher, []})
      state = :sys.get_state(pid)
      assert state.sequence == 0
    end

    test "initial state has nil last_publish" do
      {:ok, pid} = start_supervised({ZenohKmsPublisher, []})
      state = :sys.get_state(pid)
      assert is_nil(state.last_publish)
    end

    test "initial state has a started_at timestamp" do
      {:ok, pid} = start_supervised({ZenohKmsPublisher, []})
      state = :sys.get_state(pid)
      assert %DateTime{} = state.started_at
    end

    test "initial state has empty subscriptions list" do
      {:ok, pid} = start_supervised({ZenohKmsPublisher, []})
      state = :sys.get_state(pid)
      assert state.subscriptions == []
    end
  end

  describe "get_stats/0 via running server" do
    setup do
      {:ok, pid} = start_supervised({ZenohKmsPublisher, []})
      {:ok, pid: pid}
    end

    test "returns a map", %{pid: _pid} do
      stats = GenServer.call(ZenohKmsPublisher, :get_stats)
      assert is_map(stats)
    end

    test "stats include started_at", %{pid: _pid} do
      stats = GenServer.call(ZenohKmsPublisher, :get_stats)
      assert Map.has_key?(stats, :started_at)
    end

    test "stats include publish_count", %{pid: _pid} do
      stats = GenServer.call(ZenohKmsPublisher, :get_stats)
      assert Map.has_key?(stats, :publish_count)
      assert is_integer(stats.publish_count)
    end

    test "stats include sequence", %{pid: _pid} do
      stats = GenServer.call(ZenohKmsPublisher, :get_stats)
      assert Map.has_key?(stats, :sequence)
      assert is_integer(stats.sequence)
    end

    test "stats include uptime_seconds", %{pid: _pid} do
      stats = GenServer.call(ZenohKmsPublisher, :get_stats)
      assert Map.has_key?(stats, :uptime_seconds)
      assert is_integer(stats.uptime_seconds)
      assert stats.uptime_seconds >= 0
    end

    test "stats include kms_prefix", %{pid: _pid} do
      stats = GenServer.call(ZenohKmsPublisher, :get_stats)
      assert Map.has_key?(stats, :kms_prefix)
      assert stats.kms_prefix == "indrajaal/kms"
    end

    test "initial publish_count is 0", %{pid: _pid} do
      stats = GenServer.call(ZenohKmsPublisher, :get_stats)
      assert stats.publish_count == 0
    end

    test "initial sequence is 0", %{pid: _pid} do
      stats = GenServer.call(ZenohKmsPublisher, :get_stats)
      assert stats.sequence == 0
    end
  end

  describe "cast API via running server" do
    setup do
      {:ok, pid} = start_supervised({ZenohKmsPublisher, []})
      {:ok, pid: pid}
    end

    test "publish_holon_created/1 does not raise", %{pid: _pid} do
      holon = %{id: "test-id", fqun: "test/fqun", type: "holon", name: "Test"}
      assert :ok = GenServer.cast(ZenohKmsPublisher, {:holon_event, :created, holon})
      # Allow async cast to be processed
      :sys.get_state(Process.whereis(ZenohKmsPublisher))
    end

    test "publish_holon_updated/1 does not raise", %{pid: _pid} do
      holon = %{id: "test-id", name: "Updated"}
      assert :ok = GenServer.cast(ZenohKmsPublisher, {:holon_event, :updated, holon})
      :sys.get_state(Process.whereis(ZenohKmsPublisher))
    end

    test "publish_holon_deleted/1 does not raise", %{pid: _pid} do
      assert :ok = GenServer.cast(ZenohKmsPublisher, {:holon_event, :deleted, %{id: "some-id"}})
      :sys.get_state(Process.whereis(ZenohKmsPublisher))
    end

    test "holon event increments publish_count", %{pid: _pid} do
      stats_before = GenServer.call(ZenohKmsPublisher, :get_stats)

      GenServer.cast(ZenohKmsPublisher, {:holon_event, :created, %{id: "x"}})

      # Flush the cast
      :sys.get_state(Process.whereis(ZenohKmsPublisher))

      stats_after = GenServer.call(ZenohKmsPublisher, :get_stats)
      assert stats_after.publish_count == stats_before.publish_count + 1
    end

    test "holon event increments sequence", %{pid: _pid} do
      stats_before = GenServer.call(ZenohKmsPublisher, :get_stats)

      GenServer.cast(ZenohKmsPublisher, {:holon_event, :updated, %{id: "y"}})
      :sys.get_state(Process.whereis(ZenohKmsPublisher))

      stats_after = GenServer.call(ZenohKmsPublisher, :get_stats)
      assert stats_after.sequence == stats_before.sequence + 1
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = ZenohKmsPublisher.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end
end
