defmodule Indrajaal.Federation.ConsensusTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Federation.Consensus.
  Tests GenServer init contract and quorum-based consensus API.
  STAMP: SC-CON-002 (HMAC-SHA512 votes), SC-SIL6-006 (2oo3 voting)
  Quorum: Q(N) = floor(N/2)+1
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Federation.Consensus

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Consensus)
    end

    test "implements GenServer behaviour" do
      assert function_exported?(Consensus, :start_link, 1)
      assert function_exported?(Consensus, :init, 1)
    end
  end

  describe "public API surface" do
    test "exports rotate_key/1" do
      assert function_exported?(Consensus, :rotate_key, 1)
    end

    test "exports propose/3" do
      assert function_exported?(Consensus, :propose, 3)
    end

    test "exports vote/2" do
      assert function_exported?(Consensus, :vote, 2)
    end

    test "exports get_proposal/1" do
      assert function_exported?(Consensus, :get_proposal, 1)
    end

    test "exports list_active/0" do
      assert function_exported?(Consensus, :list_active, 0)
    end

    test "exports stats/0" do
      assert function_exported?(Consensus, :stats, 0)
    end
  end

  describe "start_link/1 contract" do
    test "starts GenServer with empty opts" do
      {:ok, pid} = start_supervised({Consensus, []})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "initial state is a map" do
      {:ok, pid} = start_supervised({Consensus, []})
      state = :sys.get_state(pid)
      assert is_map(state)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = Consensus.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
    end
  end
end
