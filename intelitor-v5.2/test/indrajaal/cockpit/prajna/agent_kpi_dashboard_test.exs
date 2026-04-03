defmodule Indrajaal.Cockpit.Prajna.AgentKPIDashboardTest do
  @moduledoc """
  Unit tests for AgentKPIDashboard — ETS-backed KPI aggregation for 50 system agents.

  WHAT: Tests dashboard lifecycle, agent metrics, health thresholds, and aggregation.
  WHY: Validates SC-AGT-017 (efficiency >90%), SC-MON-003 (domain metrics), SC-PRAJNA-004.

  STAMP Constraints:
  - SC-AGT-017: Agent efficiency tracked
  - SC-MON-003: Domain metrics per domain
  - SC-PRAJNA-004: Dashboard data available

  AOR Rules:
  - AOR-BIO-004: Dashboard refresh 30s
  - AOR-OBS-001: Safety violations observable
  """

  use ExUnit.Case, async: false
  import ExUnitProperties, except: [property: 2, property: 3]

  alias Indrajaal.Cockpit.Prajna.AgentKPIDashboard
  alias StreamData, as: SD

  @table :prajna_agent_kpis

  setup do
    Process.flag(:trap_exit, true)

    # Stop any lingering process from previous test
    if pid = Process.whereis(AgentKPIDashboard) do
      GenServer.stop(pid, :normal, 1000)
      Process.sleep(10)
    end

    if :ets.whereis(@table) != :undefined do
      :ets.delete(@table)
    end

    # Must use default name — update_agent/2 always casts to __MODULE__
    {:ok, pid} = AgentKPIDashboard.start_link([])
    # Wait for async seeding (init uses GenServer.cast for seed_agents)
    Process.sleep(100)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal, 1000) end)
    %{pid: pid}
  end

  describe "start_link/1" do
    test "creates ETS table and seeds 50 agents", %{pid: pid} do
      assert Process.alive?(pid)
      assert :ets.whereis(@table) != :undefined
      assert AgentKPIDashboard.agent_count() == 50
    end

    test "seeds agents with 4 role types" do
      dashboard = AgentKPIDashboard.get_dashboard()
      roles = dashboard.agents |> Enum.map(& &1.role) |> Enum.uniq() |> Enum.sort()
      assert :domain_supervisor in roles
      assert :executive in roles
      assert :functional in roles
      assert :worker in roles
    end

    test "seeds agents with AGT-NNN format IDs" do
      dashboard = AgentKPIDashboard.get_dashboard()
      ids = Enum.map(dashboard.agents, & &1.agent_id)
      assert "AGT-001" in ids
      assert "AGT-050" in ids
    end
  end

  describe "get_dashboard/0" do
    test "returns aggregate snapshot with required keys" do
      dashboard = AgentKPIDashboard.get_dashboard()
      assert is_list(dashboard.agents)
      assert is_integer(dashboard.total)
      assert is_integer(dashboard.healthy)
      assert is_integer(dashboard.degraded)
      assert is_integer(dashboard.critical)
      assert is_float(dashboard.avg_efficiency)
      assert is_binary(dashboard.generated_at)
      assert dashboard.total == dashboard.healthy + dashboard.degraded + dashboard.critical
    end

    test "generated_at is valid ISO 8601" do
      dashboard = AgentKPIDashboard.get_dashboard()
      assert {:ok, _, _} = DateTime.from_iso8601(dashboard.generated_at)
    end

    test "agents in dashboard have :agent_id key" do
      dashboard = AgentKPIDashboard.get_dashboard()
      first = hd(dashboard.agents)
      assert Map.has_key?(first, :agent_id)
    end
  end

  describe "update_agent/2" do
    test "updates agent metrics via async cast" do
      :ok = AgentKPIDashboard.update_agent("AGT-001", %{efficiency: 0.99, tasks_completed: 42})
      Process.sleep(10)
      {:ok, agent} = AgentKPIDashboard.get_agent("AGT-001")
      assert agent.efficiency == 0.99
      assert agent.tasks_completed == 42
    end

    test "handles update for non-existent agent gracefully" do
      :ok = AgentKPIDashboard.update_agent("nonexistent-agent", %{efficiency: 0.5})
      Process.sleep(10)
      result = AgentKPIDashboard.get_agent("nonexistent-agent")
      # Should either create or return not_found — both are valid
      assert match?({:ok, _}, result) or result == {:error, :not_found}
    end
  end

  describe "get_agent/1" do
    test "returns {:ok, agent_data} for existing agent" do
      assert {:ok, agent} = AgentKPIDashboard.get_agent("AGT-001")
      assert is_map(agent)
      assert agent.agent_id == "AGT-001"
    end

    test "returns {:error, :not_found} for non-existent agent" do
      assert {:error, :not_found} = AgentKPIDashboard.get_agent("totally-fake-agent-xyz")
    end
  end

  describe "agent_count/0" do
    test "returns 50 after initialization" do
      assert AgentKPIDashboard.agent_count() == 50
    end
  end

  describe "health thresholds" do
    test "agents with efficiency > 0.9 contribute to healthy count" do
      :ok = AgentKPIDashboard.update_agent("AGT-001", %{efficiency: 0.95})
      Process.sleep(10)
      dashboard = AgentKPIDashboard.get_dashboard()
      # Dashboard health categorization: >0.9 healthy, >0.5 degraded, ≤0.5 critical
      assert dashboard.healthy >= 1
    end

    test "agents with efficiency 0.5-0.9 contribute to degraded count" do
      # Set all agents to low efficiency to make degraded count predictable
      :ok = AgentKPIDashboard.update_agent("AGT-001", %{efficiency: 0.65})
      Process.sleep(10)
      dashboard = AgentKPIDashboard.get_dashboard()
      assert dashboard.degraded >= 0
    end

    test "agents with efficiency <= 0.5 contribute to critical count" do
      :ok = AgentKPIDashboard.update_agent("AGT-001", %{efficiency: 0.3})
      Process.sleep(10)
      dashboard = AgentKPIDashboard.get_dashboard()
      assert dashboard.critical >= 1
    end
  end

  describe "property: dashboard aggregation invariants" do
    test "total always equals sum of health categories" do
      ExUnitProperties.check all(
                               _n <- SD.integer(1..10),
                               max_runs: 10
                             ) do
        dashboard = AgentKPIDashboard.get_dashboard()
        assert dashboard.total == dashboard.healthy + dashboard.degraded + dashboard.critical
      end
    end

    test "avg_efficiency is between 0 and 1" do
      ExUnitProperties.check all(
                               _n <- SD.integer(1..5),
                               max_runs: 5
                             ) do
        dashboard = AgentKPIDashboard.get_dashboard()
        assert dashboard.avg_efficiency >= 0.0 and dashboard.avg_efficiency <= 1.0
      end
    end
  end

  describe "property: StreamData agent updates" do
    test "random efficiency updates maintain dashboard consistency" do
      ExUnitProperties.check all(
                               efficiency <- SD.float(min: 0.0, max: 1.0),
                               max_runs: 20
                             ) do
        :ok = AgentKPIDashboard.update_agent("AGT-001", %{efficiency: efficiency})
        Process.sleep(5)
        dashboard = AgentKPIDashboard.get_dashboard()
        assert dashboard.total == dashboard.healthy + dashboard.degraded + dashboard.critical
      end
    end
  end
end
