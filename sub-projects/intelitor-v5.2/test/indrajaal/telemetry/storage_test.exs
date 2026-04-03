defmodule Indrajaal.Telemetry.StorageTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Telemetry.Storage

  describe "store_critical_event/3" do
    test "returns {:ok, :stored} for any event_data, arg2, arg3" do
      assert {:ok, :stored} ==
               Storage.store_critical_event(%{type: :fire}, "zone-1", %{severity: :critical})
    end

    test "returns {:ok, :stored} for atom event data" do
      assert {:ok, :stored} == Storage.store_critical_event(:intrusion_detected, :zone_a, :high)
    end

    test "returns {:ok, :stored} for nil arguments" do
      assert {:ok, :stored} == Storage.store_critical_event(nil, nil, nil)
    end

    test "returns {:ok, :stored} for string arguments" do
      assert {:ok, :stored} == Storage.store_critical_event("event-data", "arg2", "arg3")
    end

    test "returns {:ok, :stored} for integer arguments" do
      assert {:ok, :stored} == Storage.store_critical_event(1, 2, 3)
    end

    test "returns {:ok, :stored} for list arguments" do
      assert {:ok, :stored} == Storage.store_critical_event([1, 2, 3], [:a, :b], [])
    end

    test "result is always a 2-tuple {:ok, atom}" do
      result = Storage.store_critical_event(%{}, %{}, %{})
      assert is_tuple(result)
      assert tuple_size(result) == 2
      assert elem(result, 0) == :ok
    end
  end

  describe "store_event/3" do
    test "returns {:ok, :stored} for any arg1, arg2, arg3" do
      assert {:ok, :stored} ==
               Storage.store_event(%{event: "user_login"}, "user-123", %{ip: "10.0.0.1"})
    end

    test "returns {:ok, :stored} for atom arguments" do
      assert {:ok, :stored} == Storage.store_event(:auth_event, :user_session, :normal)
    end

    test "returns {:ok, :stored} for nil arguments" do
      assert {:ok, :stored} == Storage.store_event(nil, nil, nil)
    end

    test "returns {:ok, :stored} for mixed argument types" do
      assert {:ok, :stored} == Storage.store_event("event", 42, [:tag1, :tag2])
    end

    test "result is always a 2-tuple {:ok, atom}" do
      result = Storage.store_event("data", "arg", "extra")
      assert is_tuple(result)
      assert tuple_size(result) == 2
      assert elem(result, 0) == :ok
    end

    test "multiple consecutive calls all return {:ok, :stored}" do
      for i <- 1..5 do
        assert {:ok, :stored} == Storage.store_event("event_#{i}", i, %{})
      end
    end
  end

  describe "module API" do
    test "exports store_critical_event/3" do
      assert function_exported?(Storage, :store_critical_event, 3)
    end

    test "exports store_event/3" do
      assert function_exported?(Storage, :store_event, 3)
    end

    test "module is loaded" do
      assert Code.ensure_loaded?(Storage)
    end

    test "uses GenServer behavior" do
      assert function_exported?(Storage, :init, 1)
    end
  end
end
