defmodule Indrajaal.Federation.DirectoryTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Federation.Directory.
  Tests GenServer init contract and node registry API.
  STAMP: SC-SIL6-001, SC-COG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Federation.Directory

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Directory)
    end

    test "implements GenServer behaviour" do
      assert function_exported?(Directory, :start_link, 1)
      assert function_exported?(Directory, :init, 1)
    end
  end

  describe "public API surface" do
    test "exports register/1" do
      assert function_exported?(Directory, :register, 1)
    end

    test "exports update/2" do
      assert function_exported?(Directory, :update, 2)
    end

    test "exports get_node/1" do
      assert function_exported?(Directory, :get_node, 1)
    end

    test "exports list_nodes/0" do
      assert function_exported?(Directory, :list_nodes, 0)
    end

    test "exports query/1" do
      assert function_exported?(Directory, :query, 1)
    end

    test "exports remove/1" do
      assert function_exported?(Directory, :remove, 1)
    end

    test "exports topology/0" do
      assert function_exported?(Directory, :topology, 0)
    end

    test "exports stats/0" do
      assert function_exported?(Directory, :stats, 0)
    end

    test "exports find_children/1" do
      assert function_exported?(Directory, :find_children, 1)
    end

    test "exports get_lineage/1" do
      assert function_exported?(Directory, :get_lineage, 1)
    end
  end

  describe "start_link/1 contract" do
    test "starts GenServer with empty opts" do
      {:ok, pid} = start_supervised({Directory, []})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "initial state is a map" do
      {:ok, pid} = start_supervised({Directory, []})
      state = :sys.get_state(pid)
      assert is_map(state)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = Directory.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
    end
  end
end
