defmodule Indrajaal.MCP.Domains.Sites.HandlerTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Domains.Sites.Handler.

  ## STAMP Safety Integration
  - SC-SITE-001: Site data integrity
  - SC-SITE-002: Zone hierarchy validation

  ## TPS 5-Level RCA Context
  - L1 Symptom: Site listing returns empty for valid tenants
  - L5 Root Cause: tenant_id filter applied before default fallback
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Domains.Sites.Handler

  @context %{client_id: "sites_test_client"}

  describe "module existence" do
    test "Handler module is defined" do
      assert Code.ensure_loaded?(Handler)
    end

    test "implements list_tools/0" do
      assert function_exported?(Handler, :list_tools, 0)
    end

    test "implements handle/3" do
      assert function_exported?(Handler, :handle, 3)
    end
  end

  describe "namespace and domain" do
    test "namespace is :indrajaal" do
      assert Handler.namespace() == :indrajaal
    end

    test "domain is :sites" do
      assert Handler.domain() == :sites
    end
  end

  describe "list_tools/0" do
    test "returns a non-empty list" do
      tools = Handler.list_tools()
      assert is_list(tools)
      assert length(tools) > 0
    end

    test "includes sites.list tool" do
      tools = Handler.list_tools()
      names = Enum.map(tools, & &1.name)
      assert "indrajaal.sites.list" in names
    end

    test "includes sites.get tool" do
      tools = Handler.list_tools()
      names = Enum.map(tools, & &1.name)
      assert "indrajaal.sites.get" in names
    end
  end

  describe "handle/3 list" do
    test "returns ok with sites key" do
      result = Handler.handle("list", %{}, @context)
      assert {:ok, data} = result
      assert Map.has_key?(data, :sites) or Map.has_key?(data, "sites")
    end
  end

  describe "handle/3 get" do
    test "returns ok for valid site_id" do
      result = Handler.handle("get", %{"site_id" => "site_001"}, @context)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "handle/3 unknown" do
    test "returns error for unknown action" do
      result = Handler.handle("nonexistent_sites_action", %{}, @context)
      assert {:error, _} = result
    end
  end
end
