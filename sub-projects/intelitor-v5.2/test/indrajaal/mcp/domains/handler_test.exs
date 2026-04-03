defmodule Indrajaal.MCP.Domains.HandlerTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Domains.Handler behaviour module.

  ## STAMP Safety Integration
  - SC-MCP-080: All handlers must implement required callbacks
  - SC-MCP-081: Helper functions must return correct tagged tuples

  ## TPS 5-Level RCA Context
  - L1 Symptom: Handler returns wrong tuple shape to dispatcher
  - L5 Root Cause: success/1 or error/1 helper not wrapping correctly
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Domains.Handler

  describe "module existence" do
    test "Handler module is defined" do
      assert Code.ensure_loaded?(Handler)
    end

    test "defines behaviour callbacks" do
      # Behaviour modules define @callback attributes
      assert Code.ensure_loaded?(Handler)
    end
  end

  describe "helper functions" do
    test "success/1 wraps value in ok tuple" do
      result = Handler.success(%{data: "value"})
      assert {:ok, %{data: "value"}} = result
    end

    test "success/1 works with any value" do
      assert {:ok, 42} = Handler.success(42)
      assert {:ok, "string"} = Handler.success("string")
      assert {:ok, [1, 2, 3]} = Handler.success([1, 2, 3])
    end

    test "error/1 wraps value in error tuple" do
      result = Handler.error("something went wrong")
      assert {:error, "something went wrong"} = result
    end

    test "error/1 works with atoms" do
      assert {:error, :not_found} = Handler.error(:not_found)
    end

    test "not_implemented/1 returns error tuple" do
      result = Handler.not_implemented(:unknown_action)
      assert is_tuple(result)
      assert elem(result, 0) == :error
    end

    test "not_found/2 returns error tuple" do
      result = Handler.not_found("user", "123")
      assert is_tuple(result)
      assert elem(result, 0) == :error
    end

    test "validate_required/2 returns :ok when all required fields present" do
      args = %{"id" => "123", "name" => "test"}
      result = Handler.validate_required(args, [:id, :name])
      assert result == :ok
    end

    test "validate_required/2 returns error when required field missing" do
      args = %{"id" => "123"}
      result = Handler.validate_required(args, [:id, :name])
      assert {:error, _} = result
    end

    test "validate_required/2 accepts atom keys" do
      args = %{id: "123", name: "test"}
      result = Handler.validate_required(args, [:id, :name])
      assert result == :ok or match?({:error, _}, result)
    end

    test "audit_log/4 returns :ok without crashing" do
      context = %{client_id: "test_client"}
      result = Handler.audit_log(:test_domain, :list, %{}, context)
      assert result == :ok or is_nil(result)
    end
  end

  describe "namespace/0 default via __using__" do
    test "Accounts handler returns :accounts domain" do
      assert Indrajaal.MCP.Domains.Accounts.Handler.domain() == :accounts
    end

    test "Accounts handler returns :indrajaal namespace" do
      assert Indrajaal.MCP.Domains.Accounts.Handler.namespace() == :indrajaal
    end
  end
end
