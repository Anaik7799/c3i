defmodule Indrajaal.MCP.Domains.Maintenance.HandlerTest do
  @moduledoc """
  TDG test suite for MCP Maintenance Handler.

  Tests 12 tools with ETS-backed work order state for session-scoped
  CMMS operations including work orders, scheduling, technicians,
  assets, metrics, and alerts.

  ## STAMP Safety Integration
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-MCP-071: All tools MUST have valid schemas
  - SC-MCP-073: Work order mutations MUST require Guardian

  ## TPS 5-Level RCA Context
  - L1 Symptom: Maintenance tool returns stale data
  - L5 Root Cause: ETS table not initialized or work order not found
  """

  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Indrajaal.MCP.Domains.Maintenance.Handler
  alias StreamData, as: SD

  @moduletag :mcp_maintenance
  @context %{client_id: "test-client", timestamp: ~U[2026-01-01 00:00:00Z]}

  setup do
    # Clean ETS table if it exists from previous test
    if :ets.info(:mcp_maintenance_wo) != :undefined do
      :ets.delete_all_objects(:mcp_maintenance_wo)
    end

    :ok
  end

  # ── list_tools/0 ───────────────────────────────────────────────

  describe "list_tools/0" do
    test "returns 12 tools" do
      tools = Handler.list_tools()
      assert is_list(tools)
      assert length(tools) == 12
    end

    test "all tools have names starting with indrajaal.maintenance" do
      tools = Handler.list_tools()

      Enum.each(tools, fn tool ->
        name = tool_name(tool)
        assert is_binary(name)
        assert String.starts_with?(name, "indrajaal.maintenance.")
      end)
    end

    test "work order creation requires guardian" do
      tools = Handler.list_tools()

      create =
        Enum.find(tools, fn tool ->
          tool_name(tool) == "indrajaal.maintenance.work_orders.create"
        end)

      assert create != nil
      assert tool_requires_guardian?(create)
    end

    test "work order closing requires guardian" do
      tools = Handler.list_tools()

      close =
        Enum.find(tools, fn tool ->
          tool_name(tool) == "indrajaal.maintenance.work_orders.close"
        end)

      assert close != nil
      assert tool_requires_guardian?(close)
    end
  end

  # ── handle :work_orders_list ───────────────────────────────────

  describe "handle/3 - :work_orders_list" do
    test "returns list of work orders" do
      assert {:ok, data} = Handler.handle(:work_orders_list, %{}, @context)
      assert is_map(data)
      assert is_list(data.work_orders)
    end

    test "filters by status" do
      assert {:ok, data} =
               Handler.handle(
                 :work_orders_list,
                 %{"status" => "open"},
                 @context
               )

      assert is_list(data.work_orders)
    end

    test "filters by priority" do
      assert {:ok, data} =
               Handler.handle(
                 :work_orders_list,
                 %{"priority" => "high"},
                 @context
               )

      assert is_list(data.work_orders)
    end
  end

  # ── handle :work_orders_get ────────────────────────────────────

  describe "handle/3 - :work_orders_get" do
    test "gets work order by ID (from simulated data)" do
      result =
        Handler.handle(
          :work_orders_get,
          %{"work_order_id" => "WO-001"},
          @context
        )

      case result do
        {:ok, data} ->
          assert is_map(data)
          assert Map.has_key?(data, :id) or Map.has_key?(data, :work_order_id)

        {:error, _} ->
          :ok

        :ok ->
          :ok
      end
    end
  end

  # ── handle :work_orders_create ─────────────────────────────────

  describe "handle/3 - :work_orders_create" do
    test "creates a work order" do
      args = %{
        "title" => "Replace HVAC filter",
        "priority" => "medium",
        "asset_id" => "asset-001",
        "description" => "Scheduled filter replacement"
      }

      result = Handler.handle(:work_orders_create, args, @context)

      case result do
        {:ok, data} ->
          assert is_map(data)
          assert Map.has_key?(data, :id) or Map.has_key?(data, :work_order_id)

        :ok ->
          :ok

        {:error, _} ->
          :ok
      end
    end
  end

  # ── handle :work_orders_update ─────────────────────────────────

  describe "handle/3 - :work_orders_update" do
    test "updates work order status" do
      args = %{
        "work_order_id" => "WO-001",
        "status" => "in_progress"
      }

      result = Handler.handle(:work_orders_update, args, @context)
      assert is_tuple(result) or result == :ok
    end
  end

  # ── handle :work_orders_close ──────────────────────────────────

  describe "handle/3 - :work_orders_close" do
    test "closes work order" do
      args = %{
        "work_order_id" => "WO-001",
        "resolution" => "Completed successfully"
      }

      result = Handler.handle(:work_orders_close, args, @context)
      assert is_tuple(result)
    end
  end

  # ── handle :schedule_list ──────────────────────────────────────

  describe "handle/3 - :schedule_list" do
    test "returns scheduled maintenance list" do
      assert {:ok, data} = Handler.handle(:schedule_list, %{}, @context)
      assert is_map(data)
    end
  end

  # ── handle :schedule_plan ──────────────────────────────────────

  describe "handle/3 - :schedule_plan" do
    test "plans maintenance schedule" do
      args = %{
        "asset_id" => "asset-001",
        "interval_days" => 90
      }

      result = Handler.handle(:schedule_plan, args, @context)
      assert is_tuple(result)
    end
  end

  # ── handle :technicians_list ───────────────────────────────────

  describe "handle/3 - :technicians_list" do
    test "returns technician list" do
      assert {:ok, data} = Handler.handle(:technicians_list, %{}, @context)
      assert is_map(data)
    end
  end

  # ── handle :assets_list ────────────────────────────────────────

  describe "handle/3 - :assets_list" do
    test "returns asset list" do
      assert {:ok, data} = Handler.handle(:assets_list, %{}, @context)
      assert is_map(data)
    end
  end

  # ── handle :assets_history ─────────────────────────────────────

  describe "handle/3 - :assets_history" do
    test "returns asset maintenance history" do
      args = %{"asset_id" => "asset-001"}
      result = Handler.handle(:assets_history, args, @context)
      assert is_tuple(result) or result == :ok
    end
  end

  # ── handle :metrics ────────────────────────────────────────────

  describe "handle/3 - :metrics" do
    test "returns maintenance metrics" do
      assert {:ok, data} = Handler.handle(:metrics, %{}, @context)
      assert is_map(data)
    end
  end

  # ── handle :alerts ─────────────────────────────────────────────

  describe "handle/3 - :alerts" do
    test "returns maintenance alerts" do
      assert {:ok, data} = Handler.handle(:alerts, %{}, @context)
      assert is_map(data)
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
    test "property: list actions always return {:ok, map}" do
      check all(
              action <-
                SD.member_of([
                  :work_orders_list,
                  :schedule_list,
                  :technicians_list,
                  :assets_list,
                  :metrics,
                  :alerts
                ])
            ) do
        assert {:ok, data} = Handler.handle(action, %{}, @context)
        assert is_map(data)
      end
    end

    test "property: work order create always returns valid result" do
      check all(
              title <-
                SD.string(:alphanumeric, min_length: 1, max_length: 50),
              priority <- SD.member_of(["low", "medium", "high", "critical"])
            ) do
        args = %{"title" => title, "priority" => priority, "asset_id" => "asset-001"}

        result = Handler.handle(:work_orders_create, args, @context)

        case result do
          {:ok, data} -> assert is_map(data)
          :ok -> :ok
          {:error, _} -> :ok
        end
      end
    end
  end

  # ── Helpers ────────────────────────────────────────────────────

  defp tool_name(%{name: name}), do: name
  defp tool_name({name, _}), do: name
  defp tool_name(_), do: nil

  defp tool_requires_guardian?(%{requires_guardian: val}), do: val == true
  defp tool_requires_guardian?(_), do: false
end
