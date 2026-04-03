defmodule Indrajaal.Federation.UpgradeNotifierTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Federation.UpgradeNotifier.
  Tests GenServer init contract and peer upgrade coordination API.
  STAMP: SC-FRAC-006 (federation version negotiation), SC-SIL6-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Federation.UpgradeNotifier

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(UpgradeNotifier)
    end

    test "implements GenServer behaviour" do
      assert function_exported?(UpgradeNotifier, :start_link, 1)
      assert function_exported?(UpgradeNotifier, :init, 1)
    end
  end

  describe "public API surface" do
    test "exports announce_upgrade/3" do
      assert function_exported?(UpgradeNotifier, :announce_upgrade, 3)
    end

    test "exports commit_upgrade/2" do
      assert function_exported?(UpgradeNotifier, :commit_upgrade, 2)
    end

    test "exports version_vector/0" do
      assert function_exported?(UpgradeNotifier, :version_vector, 0)
    end

    test "exports peers/0" do
      assert function_exported?(UpgradeNotifier, :peers, 0)
    end

    test "exports pending_announcements/0" do
      assert function_exported?(UpgradeNotifier, :pending_announcements, 0)
    end

    test "exports add_peer/1" do
      assert function_exported?(UpgradeNotifier, :add_peer, 1)
    end

    test "exports remove_peer/1" do
      assert function_exported?(UpgradeNotifier, :remove_peer, 1)
    end
  end

  describe "start_link/1 contract" do
    test "starts GenServer with empty opts" do
      {:ok, pid} = start_supervised({UpgradeNotifier, []})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "initial state is a map" do
      {:ok, pid} = start_supervised({UpgradeNotifier, []})
      state = :sys.get_state(pid)
      assert is_map(state)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = UpgradeNotifier.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
    end
  end
end
