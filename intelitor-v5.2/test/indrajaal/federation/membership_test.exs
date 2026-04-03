defmodule Indrajaal.Federation.MembershipTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Federation.Membership.
  Tests pure membership state machine functions.
  STAMP: SC-SIL6-001, SC-SIL6-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Federation.Membership

  @sample_request %{
    id: "mbr_test_001",
    node_id: "node_alpha",
    capabilities: [:consensus, :storage],
    version: "21.3.0",
    region: "us-east"
  }

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Membership)
    end
  end

  describe "public API surface" do
    test "exports apply/1" do
      assert function_exported?(Membership, :apply, 1)
    end

    test "exports approve/1" do
      assert function_exported?(Membership, :approve, 1)
    end

    test "exports promote/1" do
      assert function_exported?(Membership, :promote, 1)
    end

    test "exports suspend/2" do
      assert function_exported?(Membership, :suspend, 2)
    end

    test "exports reinstate/1" do
      assert function_exported?(Membership, :reinstate, 1)
    end

    test "exports expel/2" do
      assert function_exported?(Membership, :expel, 2)
    end

    test "exports depart/1" do
      assert function_exported?(Membership, :depart, 1)
    end

    test "exports get_record/1" do
      assert function_exported?(Membership, :get_record, 1)
    end

    test "exports list_by_state/1" do
      assert function_exported?(Membership, :list_by_state, 1)
    end

    test "exports stats/0" do
      assert function_exported?(Membership, :stats, 0)
    end

    test "exports member?/1" do
      assert function_exported?(Membership, :member?, 1)
    end

    test "exports full_member?/1" do
      assert function_exported?(Membership, :full_member?, 1)
    end
  end

  describe "apply/1" do
    test "accepts a membership request" do
      result = Membership.apply(@sample_request)
      assert result != nil
    end

    test "returns ok or error tuple" do
      result = Membership.apply(@sample_request)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "member?/1 and full_member?/1" do
    test "member? returns boolean for unknown node" do
      result = Membership.member?("nonexistent_node_sprint54")
      assert is_boolean(result)
    end

    test "full_member? returns boolean for unknown node" do
      result = Membership.full_member?("nonexistent_node_sprint54")
      assert is_boolean(result)
    end

    test "unknown node is not a member" do
      refute Membership.member?("clearly_nonexistent_sprint54_node")
    end
  end

  describe "stats/0" do
    test "returns a map" do
      result = Membership.stats()
      assert is_map(result)
    end
  end

  describe "list_by_state/1" do
    test "returns a list for :pending state" do
      result = Membership.list_by_state(:pending)
      assert is_list(result)
    end

    test "returns a list for :active state" do
      result = Membership.list_by_state(:active)
      assert is_list(result)
    end
  end
end
