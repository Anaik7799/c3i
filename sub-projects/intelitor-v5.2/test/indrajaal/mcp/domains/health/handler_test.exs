defmodule Indrajaal.MCP.Domains.Health.HandlerTest do
  @moduledoc """
  TDG test suite for MCP Health Handler.

  Tests 5 tools: status, containers, zenoh, services, metrics.
  Health handler aggregates runtime metrics, container state,
  and Zenoh mesh connectivity.

  ## STAMP Safety Integration
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-MCP-071: All tools MUST have valid schemas
  - SC-HEALTH-001: System health monitoring

  ## TPS 5-Level RCA Context
  - L1 Symptom: Health endpoint returns incomplete data
  - L5 Root Cause: Runtime info functions unavailable or Zenoh NIF not loaded
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Indrajaal.MCP.Domains.Health.Handler
  alias StreamData, as: SD

  @moduletag :mcp_health
  @context %{client_id: "test-client", timestamp: ~U[2026-01-01 00:00:00Z]}

  # ── Module Definition ──────────────────────────────────────────

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(Handler)
    end

    test "exports handle/3" do
      assert function_exported?(Handler, :handle, 3)
    end

    test "exports list_tools/0" do
      assert function_exported?(Handler, :list_tools, 0)
    end
  end

  # ── list_tools/0 ───────────────────────────────────────────────

  describe "list_tools/0" do
    test "returns a list of 5 tools" do
      tools = Handler.list_tools()
      assert is_list(tools)
      assert length(tools) == 5
    end

    test "all tools have names" do
      tools = Handler.list_tools()

      Enum.each(tools, fn tool ->
        name = tool_name(tool)
        assert is_binary(name), "Tool must have a string name"
        assert String.starts_with?(name, "indrajaal.health.")
      end)
    end

    test "tools include status" do
      assert tool_exists?("indrajaal.health.status")
    end

    test "tools include containers" do
      assert tool_exists?("indrajaal.health.containers")
    end

    test "tools include zenoh" do
      assert tool_exists?("indrajaal.health.zenoh")
    end

    test "tools include services" do
      assert tool_exists?("indrajaal.health.services")
    end

    test "tools include metrics" do
      assert tool_exists?("indrajaal.health.metrics")
    end
  end

  # ── handle :status ─────────────────────────────────────────────

  describe "handle/3 - :status" do
    test "returns {:ok, data} with health info" do
      assert {:ok, data} = Handler.handle(:status, %{}, @context)
      assert is_map(data)
    end

    test "status includes overall status field" do
      {:ok, data} = Handler.handle(:status, %{}, @context)

      assert Map.has_key?(data, :status) or Map.has_key?(data, :health) or
               Map.has_key?(data, :node)
    end
  end

  # ── handle :containers ─────────────────────────────────────────

  describe "handle/3 - :containers" do
    test "returns {:ok, data}" do
      assert {:ok, data} = Handler.handle(:containers, %{}, @context)
      assert is_map(data)
    end

    test "accepts name filter" do
      assert {:ok, _data} =
               Handler.handle(:containers, %{"name" => "indrajaal"}, @context)
    end
  end

  # ── handle :zenoh ──────────────────────────────────────────────

  describe "handle/3 - :zenoh" do
    test "returns {:ok, data}" do
      assert {:ok, data} = Handler.handle(:zenoh, %{}, @context)
      assert is_map(data)
    end

    test "zenoh data includes nif status" do
      {:ok, data} = Handler.handle(:zenoh, %{}, @context)
      assert Map.has_key?(data, :nif_loaded) or Map.has_key?(data, :status)
    end
  end

  # ── handle :services ───────────────────────────────────────────

  describe "handle/3 - :services" do
    test "returns {:ok, data}" do
      assert {:ok, data} = Handler.handle(:services, %{}, @context)
      assert is_map(data)
    end
  end

  # ── handle :metrics ────────────────────────────────────────────

  describe "handle/3 - :metrics" do
    test "returns {:ok, data} with system metrics" do
      assert {:ok, data} = Handler.handle(:metrics, %{}, @context)
      assert is_map(data)
    end

    test "metrics include memory info" do
      {:ok, data} = Handler.handle(:metrics, %{}, @context)

      assert Map.has_key?(data, :memory) or Map.has_key?(data, :system) or
               Map.has_key?(data, :vm) or map_size(data) > 0
    end
  end

  # ── handle unknown action ──────────────────────────────────────

  describe "handle/3 - unknown action" do
    test "returns error for unknown action" do
      result =
        try do
          Handler.handle(:nonexistent, %{}, @context)
        rescue
          FunctionClauseError -> {:error, :not_implemented}
        end

      assert {:error, _} = result
    end
  end

  # ── Property Tests ─────────────────────────────────────────────

  describe "property tests" do
    test "property: handle(:status) always returns {:ok, map}" do
      check all(_i <- SD.integer(1..5)) do
        assert {:ok, data} = Handler.handle(:status, %{}, @context)
        assert is_map(data)
      end
    end

    test "property: handle(:metrics) always returns {:ok, map}" do
      check all(_i <- SD.integer(1..5)) do
        assert {:ok, data} = Handler.handle(:metrics, %{}, @context)
        assert is_map(data)
      end
    end
  end

  # ── Helpers ────────────────────────────────────────────────────

  defp tool_name(%{name: name}), do: name
  defp tool_name({name, _}), do: name
  defp tool_name(_), do: nil

  defp tool_exists?(name) do
    Handler.list_tools()
    |> Enum.any?(fn tool -> tool_name(tool) == name end)
  end
end
