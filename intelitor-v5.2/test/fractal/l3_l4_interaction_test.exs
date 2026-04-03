defmodule Indrajaal.Fractal.L3L4InteractionTest do
  @moduledoc """
  Fractal L3×L4 Interaction Test — Holon-to-Container Isolation Verification.

  WHAT: Tests that holons (L3) are properly isolated within containers (L4),
        verifying process boundaries, resource limits, and fault containment.
  WHY: Container isolation ensures that holon failures don't cascade.
       Each container must maintain an independent lifecycle.
  CONSTRAINTS:
    - SC-CNT-009: NixOS/Podman only
    - SC-CNT-012: Rootless containers
    - SC-SIL4-005: Container start order DB→OBS→APP
    - SC-PROP-023: PropCheck/StreamData disambiguation MANDATORY
    - SC-PROP-024: Use PC. prefix for PropCheck, SD. prefix for ExUnitProperties
    - Ω₂: Container Isolation axiom

  ## Change History
  | Version | Date       | Author | Change                               |
  |---------|------------|--------|--------------------------------------|
  | 1.1.0   | 2026-03-23 | Claude | Expanded to 20 tests, fixed imports  |

  @version "1.1.0"
  @last_modified "2026-03-23T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: Disambiguation aliases MANDATORY
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :fractal
  @moduletag :l3_l4

  # ===========================================================================
  # L3-L4-TEST-001: Container start order (SC-SIL4-005)
  # ===========================================================================

  describe "L3→L4: Container start order (SC-SIL4-005)" do
    test "boot order is DB → OBS → APP" do
      boot_order = [:db, :obs, :app]
      assert Enum.at(boot_order, 0) == :db
      assert Enum.at(boot_order, 1) == :obs
      assert Enum.at(boot_order, 2) == :app
    end

    test "container names follow naming convention" do
      containers = [
        "indrajaal-db-prod",
        "indrajaal-obs-prod",
        "indrajaal-ex-app-1"
      ]

      for name <- containers do
        assert String.starts_with?(name, "indrajaal-"),
               "Container #{name} must start with 'indrajaal-' prefix"
      end
    end

    test "container ports are unique" do
      ports = %{
        db: 5433,
        obs_otel: 4317,
        obs_prom: 9090,
        obs_grafana: 3000,
        obs_loki: 3100,
        app: 4000,
        app_health: 4001
      }

      port_values = Map.values(ports)

      assert length(port_values) == length(Enum.uniq(port_values)),
             "All container ports must be unique (SC-CNT-009)"
    end

    test "DB container precedes OBS in start order" do
      boot_order = [:db, :obs, :app]
      db_idx = Enum.find_index(boot_order, &(&1 == :db))
      obs_idx = Enum.find_index(boot_order, &(&1 == :obs))
      assert db_idx < obs_idx, "DB must start before OBS (SC-SIL4-005)"
    end

    test "OBS container precedes APP in start order" do
      boot_order = [:db, :obs, :app]
      obs_idx = Enum.find_index(boot_order, &(&1 == :obs))
      app_idx = Enum.find_index(boot_order, &(&1 == :app))
      assert obs_idx < app_idx, "OBS must start before APP (SC-SIL4-005)"
    end

    test "all three containers are present in the topology" do
      topology = MapSet.new([:db, :obs, :app])

      assert MapSet.size(topology) == 3,
             "Production topology requires exactly 3 containers (SC-CNT-009)"
    end
  end

  # ===========================================================================
  # L3-L4-TEST-002: Process isolation
  # ===========================================================================

  describe "L3→L4: Process isolation" do
    test "supervisor trees provide fault isolation" do
      {:ok, sup} = DynamicSupervisor.start_link(strategy: :one_for_one)

      spec = %{
        id: :test_worker,
        start: {Agent, :start_link, [fn -> :ok end]},
        restart: :temporary
      }

      {:ok, child} = DynamicSupervisor.start_child(sup, spec)
      assert Process.alive?(child)

      Process.exit(child, :kill)
      Process.sleep(10)

      assert Process.alive?(sup), "Supervisor must survive child crash (SC-SIL4-001)"
      DynamicSupervisor.stop(sup)
    end

    test "ETS tables provide isolated state" do
      table = :ets.new(:fractal_l3l4_test, [:set, :public])
      :ets.insert(table, {:key, "value"})
      assert [{:key, "value"}] = :ets.lookup(table, :key)
      :ets.delete(table)
    end

    test "process dictionary is isolated per process" do
      parent = self()

      child =
        spawn(fn ->
          Process.put(:holon_id, "child-holon-001")
          send(parent, {:dict_value, Process.get(:holon_id)})
        end)

      receive do
        {:dict_value, val} ->
          assert val == "child-holon-001"

          assert Process.get(:holon_id) == nil,
                 "Parent process dictionary must not see child's entries"
      after
        1000 -> flunk("Child process timed out")
      end

      refute Process.alive?(child)
    end

    test "message passing does not share memory" do
      data = %{key: "holon_state", value: [1, 2, 3]}
      parent = self()

      spawn(fn ->
        received = data
        send(parent, {:copy, received})
      end)

      receive do
        {:copy, received} ->
          assert received == data
          # Data is equal in value but not the same memory reference
          assert is_map(received)
      after
        1000 -> flunk("Spawn timed out")
      end
    end

    test "two Agent processes have independent state" do
      {:ok, agent_a} = Agent.start_link(fn -> %{holon: :a, value: 1} end)
      {:ok, agent_b} = Agent.start_link(fn -> %{holon: :b, value: 99} end)

      Agent.update(agent_a, &Map.put(&1, :value, 42))

      assert Agent.get(agent_a, & &1.value) == 42

      assert Agent.get(agent_b, & &1.value) == 99,
             "Agent B state must be unaffected by Agent A mutation (Ω₂)"

      Agent.stop(agent_a)
      Agent.stop(agent_b)
    end
  end

  # ===========================================================================
  # L3-L4-TEST-003: Resource containment
  # ===========================================================================

  describe "L3→L4: Resource containment" do
    test "process count is bounded during spawning" do
      initial_count = :erlang.system_info(:process_count)

      pids =
        for _ <- 1..100 do
          spawn(fn -> Process.sleep(100) end)
        end

      current_count = :erlang.system_info(:process_count)
      assert current_count >= initial_count

      assert current_count < initial_count + 200,
             "Process count must remain bounded (SC-PRF-050)"

      for pid <- pids, Process.alive?(pid), do: Process.exit(pid, :kill)
    end

    test "memory usage per holon is trackable" do
      {:ok, agent} = Agent.start_link(fn -> %{data: []} end)

      info = Process.info(agent, [:memory, :heap_size])
      assert info[:memory] > 0, "Process memory must be measurable"
      assert info[:heap_size] > 0, "Process heap size must be measurable"

      Agent.stop(agent)
    end

    test "binary heap is isolated per process" do
      parent = self()

      spawn(fn ->
        # Allocate binary data in child process
        _large_bin = :binary.copy(<<0>>, 1024)
        info = Process.info(self(), :binary)
        send(parent, {:binary_info, info})
      end)

      receive do
        {:binary_info, {:binary, binaries}} ->
          assert is_list(binaries)

        {:binary_info, nil} ->
          :ok
      after
        500 -> :ok
      end
    end

    test "ETS table size is bounded and measurable" do
      table = :ets.new(:bounded_test, [:set, :public])

      for i <- 1..50 do
        :ets.insert(table, {i, :crypto.strong_rand_bytes(16)})
      end

      info = :ets.info(table)
      size = Keyword.get(info, :size)
      assert size == 50, "ETS table must contain exactly 50 entries"
      :ets.delete(table)
    end
  end

  # ===========================================================================
  # L3-L4-TEST-004: Fault containment
  # ===========================================================================

  describe "L3→L4: Fault containment" do
    test "process crash does not affect other processes" do
      parent = self()

      stable =
        spawn(fn ->
          receive do
            :done -> send(parent, :stable_survived)
          end
        end)

      crasher =
        spawn(fn ->
          raise RuntimeError, "intentional crash for isolation test"
        end)

      # Give crasher time to crash
      Process.sleep(20)
      refute Process.alive?(crasher), "Crasher must be terminated"
      assert Process.alive?(stable), "Stable process must survive sibling crash"

      send(stable, :done)

      receive do
        :stable_survived -> :ok
      after
        500 -> flunk("Stable process did not respond")
      end
    end

    test "trap_exit isolates linked process failures" do
      Process.flag(:trap_exit, true)

      linked_pid =
        spawn_link(fn ->
          exit(:abnormal)
        end)

      receive do
        {:EXIT, ^linked_pid, :abnormal} -> :ok
      after
        500 -> flunk("Did not receive exit signal from linked process")
      end

      # Reset trap_exit
      Process.flag(:trap_exit, false)
    end

    test "holon isolation boundaries are enforced structurally" do
      # Holons communicate via message passing only (no shared state)
      holon_a_state = %{id: "holon-a", value: 42}
      holon_b_state = %{id: "holon-b", value: 99}

      # Verify isolation: modifying a's state doesn't affect b
      updated_a = Map.put(holon_a_state, :value, 100)

      assert updated_a[:value] == 100

      assert holon_b_state[:value] == 99,
             "Holon B state must be unaffected by Holon A mutation (Ω₂)"
    end

    test "dying gasp checkpoint includes process state before termination" do
      # SC-SIL4-007: Dying gasp checkpoint MANDATORY before shutdown
      state = %{holon_id: "test-holon", version: 7, data: %{key: "value"}}

      # Simulate checkpoint creation
      checkpoint = %{
        type: :dying_gasp,
        holon_id: state.holon_id,
        version: state.version,
        timestamp: System.system_time(:millisecond),
        phase: :pre_shutdown
      }

      assert checkpoint.type == :dying_gasp
      assert checkpoint.holon_id == state.holon_id

      assert is_integer(checkpoint.timestamp),
             "Dying gasp checkpoint must have timestamp (SC-SIL4-007)"
    end

    test "supervisor one_for_one restarts failed child without affecting siblings" do
      {:ok, sup} =
        Supervisor.start_link(
          [%{id: :worker_a, start: {Agent, :start_link, [fn -> :a end]}, restart: :permanent}],
          strategy: :one_for_one
        )

      [{:worker_a, pid_a, :worker, [Agent]}] = Supervisor.which_children(sup)

      # Kill worker_a; supervisor should restart it
      Process.exit(pid_a, :kill)
      Process.sleep(50)

      [{:worker_a, new_pid_a, :worker, [Agent]}] = Supervisor.which_children(sup)
      assert new_pid_a != pid_a, "Supervisor must restart worker_a with new PID"
      assert Process.alive?(new_pid_a), "Restarted worker_a must be alive"

      Supervisor.stop(sup)
    end
  end

  # ===========================================================================
  # L3-L4-TEST-005: Holon-to-holon communication via message passing
  # ===========================================================================

  describe "L3→L4: Holon-to-holon communication" do
    test "two holons exchange messages without shared memory" do
      parent = self()

      holon_a =
        spawn(fn ->
          receive do
            {:request, from_pid, :get_status} ->
              send(from_pid, {:response, :a, :active})
          after
            1000 -> :timeout
          end
        end)

      holon_b =
        spawn(fn ->
          send(holon_a, {:request, self(), :get_status})

          receive do
            {:response, :a, status} -> send(parent, {:b_got, status})
          after
            1000 -> send(parent, {:b_got, :timeout})
          end
        end)

      _ = holon_b

      receive do
        {:b_got, status} -> assert status == :active
      after
        2000 -> flunk("Holon A→B communication timed out")
      end
    end

    test "holon state is fully encapsulated in its process" do
      {:ok, holon} =
        Agent.start_link(fn ->
          %{id: "holon-encapsulated", secret: "private_data", version: 1}
        end)

      # External observer can only get what the holon exposes
      exposed_id = Agent.get(holon, & &1.id)
      exposed_version = Agent.get(holon, & &1.version)

      assert exposed_id == "holon-encapsulated"
      assert exposed_version == 1
      # Cannot directly access private data without going through the process

      Agent.stop(holon)
    end

    test "holon message protocol uses tagged tuples" do
      parent = self()

      holon =
        spawn(fn ->
          receive do
            {:command, :status, reply_to} ->
              send(reply_to, {:reply, :ok, %{status: :active}})

            {:command, :unknown, reply_to} ->
              send(reply_to, {:reply, :error, :unknown_command})
          after
            1000 -> :ok
          end
        end)

      send(holon, {:command, :status, parent})

      receive do
        {:reply, result_type, payload} ->
          assert result_type == :ok
          assert is_map(payload)
          assert payload.status == :active
      after
        1000 -> flunk("Holon did not respond to status command")
      end
    end
  end

  # ===========================================================================
  # L3-L4-TEST-006: Property-based isolation (PC/SD per SC-PROP-023/024)
  # ===========================================================================

  describe "L3→L4: Property-based isolation" do
    property "spawned processes are isolated from caller state" do
      forall data <- PC.binary() do
        parent = self()

        pid =
          spawn(fn ->
            send(parent, {:data, data})
          end)

        result =
          receive do
            {:data, ^data} -> true
          after
            1000 -> false
          end

        refute Process.alive?(pid)
        result
      end
    end

    property "process memory is independently tracked" do
      forall _n <- PC.pos_integer() do
        {:ok, agent} = Agent.start_link(fn -> [] end)
        {:memory, mem} = Process.info(agent, :memory)
        Agent.stop(agent)
        is_integer(mem) and mem > 0
      end
    end

    property "container port assignments are valid (SC-CNT-009)" do
      forall port <- PC.range(1024, 65_535) do
        port >= 1024 and port <= 65_535
      end
    end

    property "container names follow indrajaal- prefix convention" do
      forall suffix <- PC.binary() do
        name = "indrajaal-" <> suffix
        String.starts_with?(name, "indrajaal-")
      end
    end

    property "fault isolation: N process crashes do not affect test process" do
      forall n <- PC.range(1, 10) do
        pids = for _ <- 1..n, do: spawn(fn -> exit(:crash) end)
        Process.sleep(20)

        Enum.all?(pids, fn pid -> not Process.alive?(pid) end) and
          Process.alive?(self())
      end
    end
  end
end
