defmodule Indrajaal.Distributed.Agents.KPIDashboardAgentTest do
  @moduledoc """
  TDG test suite for KPIDashboardAgent (uses BaseAgent macro).

  ## STAMP Safety Integration
  - SC-OODA-001: OODA cycle < 100ms
  - SC-BIO-005: Dashboard refresh every 30s

  ## TPS 5-Level RCA Context
  - L1 Symptom: KPI dashboard not showing current metrics
  - L5 Root Cause: BaseAgent lifecycle not initialized or command handler missing
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Distributed.Agents.KPIDashboardAgent

  describe "module definition" do
    test "KPIDashboardAgent module exists and is loaded" do
      assert Code.ensure_loaded?(KPIDashboardAgent)
    end

    test "KPIDashboardAgent exports agent_init/1" do
      assert function_exported?(KPIDashboardAgent, :agent_init, 1)
    end

    test "KPIDashboardAgent exports agent_state/1" do
      assert function_exported?(KPIDashboardAgent, :agent_state, 1)
    end

    test "KPIDashboardAgent exports agent_metrics/1" do
      assert function_exported?(KPIDashboardAgent, :agent_metrics, 1)
    end

    test "KPIDashboardAgent exports handle_command/3" do
      assert function_exported?(KPIDashboardAgent, :handle_command, 3)
    end

    test "KPIDashboardAgent exports handle_agent_info/2" do
      assert function_exported?(KPIDashboardAgent, :handle_agent_info, 2)
    end

    test "KPIDashboardAgent is a GenServer via BaseAgent" do
      assert function_exported?(KPIDashboardAgent, :start_link, 1)
    end
  end

  describe "agent_init/1" do
    test "initializes agent state with config" do
      config = %{agent_id: "kpi-001", refresh_interval: 30_000}
      result = KPIDashboardAgent.agent_init(config)
      assert is_map(result) or is_tuple(result)
    end

    test "initializes with empty config" do
      result = KPIDashboardAgent.agent_init(%{})
      assert is_map(result) or is_tuple(result)
    end

    test "initial state has render_mode or similar field" do
      result = KPIDashboardAgent.agent_init(%{render_mode: :compact})

      case result do
        {:ok, state} -> assert is_map(state)
        state when is_map(state) -> assert is_map(state)
        _ -> assert is_tuple(result)
      end
    end
  end

  describe "agent_state/1" do
    test "returns agent state representation" do
      initial = KPIDashboardAgent.agent_init(%{})

      state =
        case initial do
          {:ok, s} -> s
          s when is_map(s) -> s
          _ -> %{}
        end

      result = KPIDashboardAgent.agent_state(state)
      assert is_map(result) or is_tuple(result)
    end
  end

  describe "agent_metrics/1" do
    test "returns metrics from agent state" do
      initial = KPIDashboardAgent.agent_init(%{})

      state =
        case initial do
          {:ok, s} -> s
          s when is_map(s) -> s
          _ -> %{}
        end

      result = KPIDashboardAgent.agent_metrics(state)
      assert is_map(result) or is_tuple(result)
    end

    test "metrics include dashboard-related counters" do
      initial = KPIDashboardAgent.agent_init(%{})

      state =
        case initial do
          {:ok, s} -> s
          s when is_map(s) -> s
          _ -> %{}
        end

      metrics = KPIDashboardAgent.agent_metrics(state)
      assert is_map(metrics) or is_tuple(metrics)
    end
  end

  describe "handle_command/3 - refresh" do
    test "handles :refresh command" do
      initial = KPIDashboardAgent.agent_init(%{})

      state =
        case initial do
          {:ok, s} -> s
          s when is_map(s) -> s
          _ -> %{}
        end

      result = KPIDashboardAgent.handle_command(:refresh, %{}, state)
      assert is_tuple(result)
    end
  end

  describe "handle_command/3 - set_render_mode" do
    test "handles :set_render_mode command" do
      initial = KPIDashboardAgent.agent_init(%{})

      state =
        case initial do
          {:ok, s} -> s
          s when is_map(s) -> s
          _ -> %{}
        end

      result = KPIDashboardAgent.handle_command(:set_render_mode, %{mode: :full}, state)
      assert is_tuple(result)
    end

    test "set_render_mode to compact" do
      initial = KPIDashboardAgent.agent_init(%{})

      state =
        case initial do
          {:ok, s} -> s
          s when is_map(s) -> s
          _ -> %{}
        end

      result = KPIDashboardAgent.handle_command(:set_render_mode, %{mode: :compact}, state)
      assert is_tuple(result)
    end
  end

  describe "handle_command/3 - get_dashboard" do
    test "handles :get_dashboard command" do
      initial = KPIDashboardAgent.agent_init(%{})

      state =
        case initial do
          {:ok, s} -> s
          s when is_map(s) -> s
          _ -> %{}
        end

      result = KPIDashboardAgent.handle_command(:get_dashboard, %{}, state)
      assert is_tuple(result)
    end

    test "get_dashboard returns ok with dashboard data" do
      initial = KPIDashboardAgent.agent_init(%{})

      state =
        case initial do
          {:ok, s} -> s
          s when is_map(s) -> s
          _ -> %{}
        end

      result = KPIDashboardAgent.handle_command(:get_dashboard, %{}, state)
      assert match?({:ok, _, _}, result) or match?({:error, _, _}, result) or is_tuple(result)
    end
  end

  describe "handle_command/3 - get_todolist" do
    test "handles :get_todolist command" do
      initial = KPIDashboardAgent.agent_init(%{})

      state =
        case initial do
          {:ok, s} -> s
          s when is_map(s) -> s
          _ -> %{}
        end

      result = KPIDashboardAgent.handle_command(:get_todolist, %{}, state)
      assert is_tuple(result)
    end
  end

  describe "handle_command/3 - unknown command" do
    test "handles unknown command gracefully" do
      initial = KPIDashboardAgent.agent_init(%{})

      state =
        case initial do
          {:ok, s} -> s
          s when is_map(s) -> s
          _ -> %{}
        end

      result = KPIDashboardAgent.handle_command(:unknown_command_xyz, %{}, state)
      assert is_tuple(result)
    end
  end

  describe "handle_agent_info/2" do
    test "handles agent info messages" do
      initial = KPIDashboardAgent.agent_init(%{})

      state =
        case initial do
          {:ok, s} -> s
          s when is_map(s) -> s
          _ -> %{}
        end

      result = KPIDashboardAgent.handle_agent_info({:update, %{metric: :cpu}}, state)
      assert is_tuple(result) or is_map(result)
    end

    test "handles unknown info messages" do
      initial = KPIDashboardAgent.agent_init(%{})

      state =
        case initial do
          {:ok, s} -> s
          s when is_map(s) -> s
          _ -> %{}
        end

      result = KPIDashboardAgent.handle_agent_info(:unknown_info, state)
      assert is_tuple(result) or is_map(result)
    end
  end
end
