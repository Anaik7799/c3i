defmodule Indrajaal.Cockpit.DashboardTest do
  @moduledoc """
  Tests for the Cognitive Cockpit Dashboard.

  WHAT: Validates dashboard functionality and HITL interface.
  WHY: SC-HITL-001 requires human oversight capability.
  CONSTRAINTS: Must verify all dashboard components work correctly.
  """
  use ExUnit.Case, async: false

  alias Indrajaal.Cockpit.Dashboard
  alias Indrajaal.Safety.Guardian

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Start Guardian for safety status
    case GenServer.whereis(Guardian) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    {:ok, _} = Guardian.start_link()

    # Start Dashboard
    case GenServer.whereis(Dashboard) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    {:ok, dashboard_pid} = Dashboard.start_link()

    on_exit(fn ->
      for module <- [Dashboard, Guardian] do
        case GenServer.whereis(module) do
          nil ->
            :ok

          pid ->
            try do
              GenServer.stop(pid, :normal, 5000)
            catch
              :exit, _ -> :ok
            end
        end
      end
    end)

    %{dashboard: dashboard_pid}
  end

  # ============================================================
  # SYSTEM STATUS TESTS
  # ============================================================

  describe "system_status/0" do
    test "returns comprehensive status map", _ctx do
      status = Dashboard.system_status()

      assert is_map(status)
      assert Map.has_key?(status, :safety)
      assert Map.has_key?(status, :resources)
      assert Map.has_key?(status, :agents)
      assert Map.has_key?(status, :session)
    end
  end

  describe "safety_status/0" do
    test "returns safety subsystem status", _ctx do
      status = Dashboard.safety_status()

      assert is_map(status)
      assert Map.has_key?(status, :guardian)
      assert Map.has_key?(status, :dead_mans_switch)
      assert Map.has_key?(status, :envelope)
      assert Map.has_key?(status, :overall_healthy)
    end

    test "guardian status includes expected fields", _ctx do
      status = Dashboard.safety_status()

      assert status.guardian.running == true
      assert is_integer(status.guardian.validations)
      assert is_integer(status.guardian.violations)
    end

    test "envelope status includes constraints", _ctx do
      status = Dashboard.safety_status()

      assert status.envelope.resource_limits.max_flame_nodes == 50
      assert status.envelope.resource_limits.max_ram_mb == 32_000
    end
  end

  describe "resource_status/0" do
    test "returns resource utilization", _ctx do
      status = Dashboard.resource_status()

      assert is_map(status)
      assert Map.has_key?(status, :memory)
      assert Map.has_key?(status, :schedulers)
      assert Map.has_key?(status, :process_count)
      assert Map.has_key?(status, :run_queue)
    end

    test "memory breakdown is complete", _ctx do
      status = Dashboard.resource_status()

      assert is_integer(status.memory.total_mb)
      assert is_integer(status.memory.processes_mb)
      assert is_integer(status.memory.binary_mb)
      assert is_integer(status.memory.ets_mb)
    end
  end

  # ============================================================
  # AGENT STATUS TESTS
  # ============================================================

  describe "agent_status/0" do
    test "returns agent status map", _ctx do
      status = Dashboard.agent_status()

      assert is_map(status)
      assert Map.has_key?(status, :cortex)
      assert Map.has_key?(status, :synapse)
      assert Map.has_key?(status, :gde)
    end
  end

  # ============================================================
  # SESSION TESTS
  # ============================================================

  describe "session_info/0" do
    test "returns session information", _ctx do
      info = Dashboard.session_info()

      assert info.running == true
      assert is_binary(info.session_id)
      assert %DateTime{} = info.started_at
    end
  end

  # ============================================================
  # AUTHORIZATION TESTS
  # ============================================================

  describe "request_authorization/2" do
    test "creates authorization request", _ctx do
      operator_id = "test_operator"
      operation = %{action: :test_action, target: "test"}

      result = Dashboard.request_authorization(operator_id, operation)

      assert {:ok, auth_id} = result
      assert String.starts_with?(auth_id, "auth_")
    end
  end

  describe "confirm_authorization/2" do
    test "rejects invalid auth_id", _ctx do
      result = Dashboard.confirm_authorization("invalid_id", "CODE")

      assert {:error, :not_found} = result
    end

    test "rejects invalid confirmation code", _ctx do
      {:ok, auth_id} = Dashboard.request_authorization("operator", %{action: :test})

      result = Dashboard.confirm_authorization(auth_id, "WRONG_CODE")

      assert {:error, :invalid_code} = result
    end
  end

  # ============================================================
  # KINO HELPER TESTS
  # ============================================================

  describe "safety_data_for_kino/0" do
    test "returns Kino-compatible data", _ctx do
      data = Dashboard.safety_data_for_kino()

      assert is_list(data)
      assert length(data) == 2

      [guardian_row, dms_row] = data
      assert guardian_row.component == "Guardian"
      assert dms_row.component == "Dead Man's Switch"
    end
  end

  describe "resource_data_for_kino/0" do
    test "returns resource data for charts", _ctx do
      data = Dashboard.resource_data_for_kino()

      assert is_list(data)
      assert Enum.all?(data, &Map.has_key?(&1, :resource))
      assert Enum.all?(data, &Map.has_key?(&1, :value_mb))
    end
  end

  describe "envelope_data_for_kino/0" do
    test "returns envelope visualization data", _ctx do
      data = Dashboard.envelope_data_for_kino()

      assert is_map(data)
      assert Map.has_key?(data, :resource)
      assert Map.has_key?(data, :physical)
      assert Map.has_key?(data, :temporal)

      assert data.resource.flame_nodes.max == 50
      assert data.resource.ram_mb.max == 32_000
    end
  end
end
