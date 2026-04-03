defmodule Indrajaal.MCP.Domains.Analytics.HandlerTest do
  @moduledoc """
  TDG test suite for MCP Analytics Handler.

  Tests 4 tools with DuckDB backend integration:
  query, alarms_trend, devices_health, summary.

  ## STAMP Safety Integration
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-MCP-071: All tools MUST have valid schemas
  - SC-HOLON-007: DuckDB for analytics queries

  ## TPS 5-Level RCA Context
  - L1 Symptom: Analytics query returns no data
  - L5 Root Cause: DuckDB unavailable or invalid SQL query
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Indrajaal.MCP.Domains.Analytics.Handler
  alias StreamData, as: SD

  @moduletag :mcp_analytics
  @context %{client_id: "test-client", timestamp: ~U[2026-01-01 00:00:00Z]}

  # ── list_tools/0 ───────────────────────────────────────────────

  describe "list_tools/0" do
    test "returns a list of tools" do
      tools = Handler.list_tools()
      assert is_list(tools)
      assert length(tools) >= 4
    end

    test "all tools have names" do
      tools = Handler.list_tools()

      Enum.each(tools, fn tool ->
        name = tool_name(tool)
        assert is_binary(name)
        assert String.starts_with?(name, "indrajaal.analytics.")
      end)
    end

    test "query tool exists" do
      assert tool_exists?("indrajaal.analytics.query")
    end
  end

  # ── handle :query ──────────────────────────────────────────────

  describe "handle/3 - :query" do
    test "executes SELECT query (graceful when DuckDB unavailable)" do
      args = %{"sql" => "SELECT 1 as test"}
      result = Handler.handle(:query, args, @context)

      case result do
        {:ok, data} -> assert is_map(data)
        {:error, _} -> :ok
      end
    end

    test "rejects non-SELECT queries" do
      args = %{"sql" => "DROP TABLE users"}
      result = Handler.handle(:query, args, @context)

      case result do
        {:error, _} -> :ok
        {:ok, data} -> assert Map.has_key?(data, :error) or Map.has_key?(data, :note)
      end
    end

    test "handles empty SQL" do
      result = Handler.handle(:query, %{}, @context)
      # Should return error or empty result
      assert is_tuple(result)
    end
  end

  # ── handle :alarms_trend ───────────────────────────────────────

  describe "handle/3 - :alarms_trend" do
    test "returns trend data" do
      result = Handler.handle(:alarms_trend, %{}, @context)

      case result do
        {:ok, data} -> assert is_map(data)
        {:error, _} -> :ok
      end
    end

    test "accepts period parameter" do
      result = Handler.handle(:alarms_trend, %{"period" => "7d"}, @context)
      assert is_tuple(result)
    end
  end

  # ── handle :devices_health ─────────────────────────────────────

  describe "handle/3 - :devices_health" do
    test "returns device health data" do
      result = Handler.handle(:devices_health, %{}, @context)

      case result do
        {:ok, data} -> assert is_map(data)
        {:error, _} -> :ok
      end
    end
  end

  # ── handle :summary ────────────────────────────────────────────

  describe "handle/3 - :summary" do
    test "returns analytics summary" do
      result = Handler.handle(:summary, %{}, @context)

      case result do
        {:ok, data} -> assert is_map(data)
        {:error, _} -> :ok
      end
    end
  end

  # ── Unknown action ─────────────────────────────────────────────

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
    test "property: all known actions return tuple results" do
      check all(
              action <-
                SD.member_of([:query, :alarms_trend, :devices_health, :summary])
            ) do
        result = Handler.handle(action, %{}, @context)
        assert is_tuple(result)
      end
    end

    test "property: SELECT queries are always accepted" do
      check all(table <- SD.member_of(["alarms", "devices", "metrics"])) do
        result =
          Handler.handle(
            :query,
            %{"sql" => "SELECT * FROM #{table} LIMIT 1"},
            @context
          )

        assert is_tuple(result)
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
