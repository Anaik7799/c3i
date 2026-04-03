defmodule Indrajaal.Observability.DashboardAgentTest do
  @moduledoc """
  Tests for the DashboardAgent GenServer.

  WHAT: Property-based and unit tests for dashboard monitoring.
  WHY: SC-DASH-001 requires verified always-on availability.
  CONSTRAINTS: Uses PC/SD aliases per SC-PROP-023/024.

  ## STAMP Constraints Verified
  - SC-DASH-001: Always-on availability
  - SC-DASH-003: Real-time KPI accuracy
  - SC-PROP-023: PropCheck/StreamData disambiguation
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]

  # EP-GEN-014 compliance: Import with exclusions and alias disambiguation
  # Only exclude property macros (not check) to avoid PropCheck conflict
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Observability.DashboardAgent

  # Test setup - start/stop the agent for each test
  setup do
    # Stop any existing agent
    case GenServer.whereis(DashboardAgent) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    # Give time for cleanup
    Process.sleep(50)

    # Start fresh agent
    {:ok, pid} = DashboardAgent.start_link([])

    # Wait for initial refresh
    Process.sleep(150)

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid, :normal, 5000)
      end
    end)

    {:ok, agent_pid: pid}
  end

  describe "GenServer lifecycle" do
    test "starts successfully with default options", %{agent_pid: pid} do
      assert Process.alive?(pid)
      assert GenServer.whereis(DashboardAgent) == pid
    end

    test "initializes with correct default state" do
      state = DashboardAgent.get_state()

      assert %DashboardAgent{} = state
      assert state.started_at != nil
      assert state.todos == []
      assert state.agents == %{}
      assert state.subscribers == []
    end

    test "performs initial refresh after startup" do
      # Wait for the scheduled refresh
      Process.sleep(200)

      state = DashboardAgent.get_state()
      assert state.refresh_count >= 1
      assert state.last_refresh != nil
    end
  end

  describe "KPI collection - SC-DASH-003" do
    test "get_kpis returns collected KPIs" do
      kpis = DashboardAgent.get_kpis()

      assert is_map(kpis)
      # After initial refresh, should have KPI categories
      assert Map.has_key?(kpis, :compilation) or Map.has_key?(kpis, :error)
    end

    test "KPIs include compilation metrics" do
      # Wait for refresh
      Process.sleep(200)
      kpis = DashboardAgent.get_kpis()

      if Map.has_key?(kpis, :compilation) do
        compilation = kpis.compilation
        assert Map.has_key?(compilation, :errors)
        assert Map.has_key?(compilation, :warnings)
        assert Map.has_key?(compilation, :files)
      end
    end

    test "KPIs include container health" do
      Process.sleep(200)
      kpis = DashboardAgent.get_kpis()

      if Map.has_key?(kpis, :containers) do
        containers = kpis.containers
        assert Map.has_key?(containers, :app)
        assert Map.has_key?(containers, :db)
        assert Map.has_key?(containers, :obs)
      end
    end

    test "KPIs include performance metrics" do
      Process.sleep(200)
      kpis = DashboardAgent.get_kpis()

      if Map.has_key?(kpis, :performance) do
        perf = kpis.performance
        assert Map.has_key?(perf, :p50)
        assert Map.has_key?(perf, :p95)
        assert Map.has_key?(perf, :p99)
      end
    end
  end

  describe "TODO management" do
    test "get_todos returns empty list initially" do
      assert DashboardAgent.get_todos() == []
    end

    test "update_todos stores the todo list" do
      todos = [
        %{id: 1, task: "Fix bug", status: :pending},
        %{id: 2, task: "Add feature", status: :in_progress}
      ]

      DashboardAgent.update_todos(todos)
      # Give time for async cast
      Process.sleep(50)

      assert DashboardAgent.get_todos() == todos
    end

    test "update_todos notifies subscribers" do
      :ok = DashboardAgent.subscribe()

      todos = [%{id: 1, task: "Test task", status: :pending}]
      DashboardAgent.update_todos(todos)

      assert_receive {:dashboard, {:todos_updated, ^todos}}, 1000
    end
  end

  describe "Agent status tracking" do
    test "get_agents returns empty map initially" do
      assert DashboardAgent.get_agents() == %{}
    end

    test "update_agent_status tracks agent status" do
      DashboardAgent.update_agent_status(:worker_1, :active)
      Process.sleep(50)

      agents = DashboardAgent.get_agents()
      assert Map.has_key?(agents, :worker_1)
      assert agents.worker_1.status == :active
      assert %DateTime{} = agents.worker_1.updated_at
    end

    test "update_agent_status notifies subscribers" do
      :ok = DashboardAgent.subscribe()

      DashboardAgent.update_agent_status(:test_agent, :busy)

      assert_receive {:dashboard, {:agent_updated, :test_agent, :busy}}, 1000
    end

    test "multiple agents can be tracked" do
      DashboardAgent.update_agent_status(:agent_1, :active)
      DashboardAgent.update_agent_status(:agent_2, :idle)
      DashboardAgent.update_agent_status(:agent_3, :busy)
      Process.sleep(100)

      agents = DashboardAgent.get_agents()
      assert map_size(agents) == 3
      assert agents.agent_1.status == :active
      assert agents.agent_2.status == :idle
      assert agents.agent_3.status == :busy
    end
  end

  describe "Subscriber management" do
    test "subscribe adds process to subscribers" do
      assert :ok = DashboardAgent.subscribe()

      state = DashboardAgent.get_state()
      assert self() in state.subscribers
    end

    test "subscribers receive refresh notifications" do
      :ok = DashboardAgent.subscribe()
      DashboardAgent.force_refresh()

      assert_receive {:dashboard, {:refresh, _kpis}}, 2000
    end

    test "dead subscribers are removed" do
      # Spawn a process that subscribes then dies
      parent = self()

      pid =
        spawn(fn ->
          DashboardAgent.subscribe()
          send(parent, :subscribed)

          receive do
            :die -> :ok
          end
        end)

      assert_receive :subscribed, 1000

      # Verify subscribed
      state = DashboardAgent.get_state()
      assert pid in state.subscribers

      # Kill the subscriber
      send(pid, :die)
      Process.sleep(100)

      # Verify removed
      state = DashboardAgent.get_state()
      refute pid in state.subscribers
    end
  end

  describe "Force refresh" do
    test "force_refresh triggers immediate KPI collection" do
      state_before = DashboardAgent.get_state()
      count_before = state_before.refresh_count

      DashboardAgent.force_refresh()
      Process.sleep(200)

      state_after = DashboardAgent.get_state()
      assert state_after.refresh_count > count_before
    end
  end

  # Property-based tests with PropCheck - SC-PROP-023
  describe "PropCheck properties" do
    property "TODO list always preserves all items" do
      forall todos <- PC.list(todo_generator()) do
        # Stop and restart for clean state
        GenServer.stop(DashboardAgent, :normal, 5000)
        Process.sleep(50)
        {:ok, _} = DashboardAgent.start_link([])
        Process.sleep(150)

        DashboardAgent.update_todos(todos)
        Process.sleep(50)

        retrieved = DashboardAgent.get_todos()
        length(retrieved) == length(todos)
      end
    end

    property "Agent status updates are idempotent" do
      forall {agent_id, status} <- {PC.atom(), status_atom()} do
        DashboardAgent.update_agent_status(agent_id, status)
        Process.sleep(20)
        DashboardAgent.update_agent_status(agent_id, status)
        Process.sleep(20)

        agents = DashboardAgent.get_agents()
        agents[agent_id].status == status
      end
    end
  end

  # StreamData property tests - SC-PROP-024
  # Using qualified ExUnitProperties.check to avoid PropCheck conflict
  describe "StreamData properties" do
    test "refresh count always increases with check all" do
      ExUnitProperties.check all(_i <- SD.integer(1..5)) do
        state_before = DashboardAgent.get_state()
        DashboardAgent.force_refresh()
        Process.sleep(200)
        state_after = DashboardAgent.get_state()

        assert state_after.refresh_count >= state_before.refresh_count
      end
    end

    test "multiple todos can be stored with check all" do
      ExUnitProperties.check all(todos <- SD.list_of(sd_todo_generator(), max_length: 10)) do
        DashboardAgent.update_todos(todos)
        Process.sleep(50)

        retrieved = DashboardAgent.get_todos()
        assert length(retrieved) == length(todos)
      end
    end

    test "agent statuses are always atoms with check all" do
      ExUnitProperties.check all(
                               agent_id <- SD.atom(:alphanumeric),
                               status <- SD.member_of([:active, :idle, :busy, :error])
                             ) do
        DashboardAgent.update_agent_status(agent_id, status)
        Process.sleep(30)

        agents = DashboardAgent.get_agents()

        if Map.has_key?(agents, agent_id) do
          assert is_atom(agents[agent_id].status)
        end
      end
    end
  end

  # PropCheck generators (PC. prefix per SC-PROP-023)
  defp todo_generator do
    let {id, task, status} <- {PC.pos_integer(), PC.utf8(), status_atom()} do
      %{id: id, task: task, status: status}
    end
  end

  defp status_atom do
    PC.oneof([:pending, :in_progress, :completed, :blocked])
  end

  # StreamData generators (SD. prefix per SC-PROP-024)
  defp sd_todo_generator do
    SD.fixed_map(%{
      id: SD.positive_integer(),
      task: SD.string(:alphanumeric, min_length: 1, max_length: 50),
      status: SD.member_of([:pending, :in_progress, :completed])
    })
  end
end
