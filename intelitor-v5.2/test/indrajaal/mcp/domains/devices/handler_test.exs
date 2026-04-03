defmodule Indrajaal.MCP.Domains.Devices.HandlerTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Domains.Devices.Handler.

  ## STAMP Safety Integration
  - SC-DEV-001: Device state sovereignty in holon
  - SC-DEV-002: Failsafe mode for critical devices

  ## TPS 5-Level RCA Context
  - L1 Symptom: Device commands silently fail
  - L5 Root Cause: handle/3 string action match missing pattern
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Domains.Devices.Handler

  @context %{client_id: "device_test_client"}

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

  describe "list_tools/0" do
    test "returns 12 device tools" do
      tools = Handler.list_tools()
      assert is_list(tools)
      assert length(tools) == 12
    end

    test "includes list tool" do
      tools = Handler.list_tools()
      names = Enum.map(tools, fn t -> t.name end)
      assert "indrajaal.devices.list" in names
    end

    test "includes failsafe tools" do
      tools = Handler.list_tools()
      names = Enum.map(tools, fn t -> t.name end)
      assert "indrajaal.devices.failsafe.status" in names
      assert "indrajaal.devices.failsafe.trigger" in names
    end

    test "register tool requires Guardian" do
      tools = Handler.list_tools()
      register_tool = Enum.find(tools, fn t -> t.name == "indrajaal.devices.register" end)
      assert register_tool != nil
      assert register_tool.requires_guardian == true
    end

    test "list tool does not require Guardian" do
      tools = Handler.list_tools()
      list_tool = Enum.find(tools, fn t -> t.name == "indrajaal.devices.list" end)
      assert list_tool != nil
      assert list_tool.requires_guardian == false
    end
  end

  describe "handle(\"list\", args, context)" do
    test "returns ok with devices list" do
      result = Handler.handle("list", %{}, @context)
      assert {:ok, data} = result
      devices = Map.get(data, :devices) || Map.get(data, "devices")
      assert is_list(devices)
    end
  end

  describe "handle(\"get\", args, context)" do
    test "returns ok with device id" do
      result = Handler.handle("get", %{"device_id" => "dev_001"}, @context)
      assert {:ok, data} = result
      id = Map.get(data, :id) || Map.get(data, "id")
      assert id == "dev_001"
    end
  end

  describe "handle(\"register\", args, context)" do
    test "returns ok with registered device" do
      args = %{
        "site_id" => "site_001",
        "type" => "panel",
        "model" => "XYZ-100",
        "serial_number" => "SN123456"
      }

      result = Handler.handle("register", args, @context)
      assert {:ok, data} = result
      assert Map.get(data, :registered) == true or Map.has_key?(data, :id)
    end
  end

  describe "handle(\"health\", args, context)" do
    test "returns ok with health score" do
      result = Handler.handle("health", %{"device_id" => "dev_001"}, @context)
      assert {:ok, data} = result
      health_score = Map.get(data, :health_score) || Map.get(data, "health_score")
      assert is_float(health_score) or is_integer(health_score)
    end
  end

  describe "handle(\"health.bulk\", args, context)" do
    test "returns ok with summary" do
      result = Handler.handle("health.bulk", %{}, @context)
      assert {:ok, data} = result
      assert Map.has_key?(data, :summary) or Map.has_key?(data, "summary")
    end
  end

  describe "handle(\"diagnostics\", args, context)" do
    test "returns ok with test results" do
      result = Handler.handle("diagnostics", %{"device_id" => "dev_001"}, @context)
      assert {:ok, data} = result
      assert Map.has_key?(data, :results) or Map.has_key?(data, "results")
    end
  end

  describe "handle(\"command\", args, context)" do
    test "returns ok for valid command" do
      result =
        Handler.handle("command", %{"device_id" => "dev_001", "command" => "arm"}, @context)

      assert {:ok, data} = result
      status = Map.get(data, :status) || Map.get(data, "status")
      assert status == :sent or status == "sent"
    end
  end

  describe "handle(\"firmware.check\", args, context)" do
    test "returns ok with version info" do
      result = Handler.handle("firmware.check", %{"device_id" => "dev_001"}, @context)
      assert {:ok, data} = result
      assert Map.has_key?(data, :update_available) or Map.has_key?(data, "update_available")
    end
  end

  describe "handle(\"failsafe.status\", args, context)" do
    test "returns ok with failsafe_active field" do
      result = Handler.handle("failsafe.status", %{"device_id" => "dev_001"}, @context)
      assert {:ok, data} = result
      failsafe = Map.get(data, :failsafe_active) || Map.get(data, "failsafe_active")
      assert is_boolean(failsafe)
    end
  end

  describe "handle(\"failsafe.trigger\", args, context)" do
    test "returns ok with failsafe_active true" do
      result =
        Handler.handle(
          "failsafe.trigger",
          %{"device_id" => "dev_001", "reason" => "test"},
          @context
        )

      assert {:ok, data} = result
      failsafe = Map.get(data, :failsafe_active) || Map.get(data, "failsafe_active")
      assert failsafe == true
    end
  end

  describe "handle(unknown, args, context)" do
    test "returns error for unknown action" do
      result = Handler.handle("nonexistent_action", %{}, @context)
      assert {:error, _} = result
    end
  end
end
