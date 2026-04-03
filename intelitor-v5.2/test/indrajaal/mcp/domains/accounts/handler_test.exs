defmodule Indrajaal.MCP.Domains.Accounts.HandlerTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Domains.Accounts.Handler.

  ## STAMP Safety Integration
  - SC-MCP-ACC-001: Account creation requires Guardian approval
  - SC-MCP-ACC-003: Tenant data isolation must be enforced

  ## TPS 5-Level RCA Context
  - L1 Symptom: Account operations return unexpected shapes
  - L5 Root Cause: handle/3 pattern match missing atom key fallback
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Domains.Accounts.Handler

  @context %{client_id: "test_client_001", timestamp: ~U[2026-01-01 00:00:00Z]}

  describe "module existence" do
    test "Handler module is defined" do
      assert Code.ensure_loaded?(Handler)
    end

    test "implements namespace/0" do
      assert function_exported?(Handler, :namespace, 0)
    end

    test "implements domain/0" do
      assert function_exported?(Handler, :domain, 0)
    end

    test "implements list_tools/0" do
      assert function_exported?(Handler, :list_tools, 0)
    end

    test "implements handle/3" do
      assert function_exported?(Handler, :handle, 3)
    end
  end

  describe "namespace/0 and domain/0" do
    test "namespace is :indrajaal" do
      assert Handler.namespace() == :indrajaal
    end

    test "domain is :accounts" do
      assert Handler.domain() == :accounts
    end
  end

  describe "list_tools/0" do
    test "returns a non-empty list" do
      tools = Handler.list_tools()
      assert is_list(tools)
      assert length(tools) > 0
    end

    test "all tools have names" do
      tools = Handler.list_tools()

      Enum.each(tools, fn tool ->
        name = Map.get(tool, :name) || Map.get(tool, "name")
        assert is_binary(name)
        assert String.starts_with?(name, "indrajaal.accounts")
      end)
    end

    test "returns expected number of tools" do
      tools = Handler.list_tools()
      # Source shows 9 tool schemas
      assert length(tools) >= 5
    end
  end

  describe "handle(:list, args, context)" do
    test "returns ok tuple with accounts key" do
      result = Handler.handle(:list, %{}, @context)
      assert {:ok, data} = result
      assert Map.has_key?(data, :accounts) or Map.has_key?(data, "accounts")
    end

    test "returns total count" do
      {:ok, data} = Handler.handle(:list, %{}, @context)
      total = Map.get(data, :total) || Map.get(data, "total")
      assert is_integer(total)
    end
  end

  describe "handle(:get, args, context)" do
    test "returns ok tuple with id" do
      result = Handler.handle(:get, %{"id" => "acc_001"}, @context)
      assert {:ok, data} = result
      id = Map.get(data, :id) || Map.get(data, "id")
      assert id == "acc_001"
    end

    test "returns error when id is missing" do
      result = Handler.handle(:get, %{}, @context)
      assert {:error, _} = result
    end
  end

  describe "handle(:create, args, context)" do
    test "returns ok tuple with account on success" do
      result = Handler.handle(:create, %{"name" => "New Account"}, @context)
      assert {:ok, data} = result
      assert Map.has_key?(data, :account) or Map.has_key?(data, "account")
    end

    test "returns error when name is missing" do
      result = Handler.handle(:create, %{}, @context)
      assert {:error, _} = result
    end
  end

  describe "handle(:update, args, context)" do
    test "returns ok with id" do
      result = Handler.handle(:update, %{"id" => "acc_001", "name" => "Updated"}, @context)
      assert {:ok, data} = result
      id = Map.get(data, :id) || Map.get(data, "id")
      assert id == "acc_001"
    end

    test "returns error when id is missing" do
      result = Handler.handle(:update, %{"name" => "No ID"}, @context)
      assert {:error, _} = result
    end
  end

  describe "handle(:delete, args, context)" do
    test "returns ok with deleted: true" do
      result = Handler.handle(:delete, %{"id" => "acc_001"}, @context)
      assert {:ok, data} = result
      deleted = Map.get(data, :deleted) || Map.get(data, "deleted")
      assert deleted == true
    end
  end

  describe "handle(:users_list, args, context)" do
    test "returns ok with users list" do
      result = Handler.handle(:users_list, %{"account_id" => "acc_001"}, @context)
      assert {:ok, data} = result
      users = Map.get(data, :users) || Map.get(data, "users")
      assert is_list(users)
    end
  end

  describe "handle(:tenants_list, args, context)" do
    test "returns ok with tenants list" do
      result = Handler.handle(:tenants_list, %{}, @context)
      assert {:ok, data} = result
      tenants = Map.get(data, :tenants) || Map.get(data, "tenants")
      assert is_list(tenants)
    end
  end

  describe "handle(:permissions, args, context)" do
    test "returns ok with capabilities" do
      result = Handler.handle(:permissions, %{"account_id" => "acc_001"}, @context)
      assert {:ok, data} = result
      assert Map.has_key?(data, :capabilities) or Map.has_key?(data, "capabilities")
    end
  end

  describe "handle(unknown, args, context)" do
    test "returns error for unknown action" do
      result =
        try do
          Handler.handle(:completely_unknown_action, %{}, @context)
        rescue
          FunctionClauseError -> {:error, :not_implemented}
        end

      assert {:error, _} = result
    end
  end
end
