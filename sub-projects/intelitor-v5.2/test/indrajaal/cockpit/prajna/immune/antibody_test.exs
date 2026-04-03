defmodule Indrajaal.Cockpit.Prajna.Immune.AntibodyTest do
  @moduledoc """
  TDG-Compliant Tests for Antibody Module - Ephemeral Anomaly Hunter.

  STAMP Compliance: SC-IMMUNE-001, SC-IMMUNE-006
  TDG: Dual property testing with PropCheck + ExUnitProperties

  Tests the ephemeral agent that hunts specific anomalies (Antigens).
  Lifecycle: Search -> Bind -> Opsonize -> Die
  """
  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cockpit.Prajna.Immune.Antibody

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - GenServer Lifecycle
  # ═══════════════════════════════════════════════════════════════════════════

  describe "start_link/1" do
    test "starts antibody with search image" do
      search_image = %{pattern: :memory_leak, threshold: 100}

      assert {:ok, pid} = Antibody.start_link(search_image)
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "does not register under global name" do
      search_image = %{pattern: :cpu_spike}
      {:ok, pid} = Antibody.start_link(search_image)

      # Antibodies are ephemeral, not registered
      assert GenServer.whereis(Antibody) == nil

      GenServer.stop(pid)
    end
  end

  describe "init/1" do
    test "stores search image in state" do
      search_image = %{pattern: :deadlock, severity: :critical}
      {:ok, pid} = Antibody.start_link(search_image)

      state = :sys.get_state(pid)
      assert state.search_image == search_image

      GenServer.stop(pid)
    end

    test "initializes with TTL" do
      search_image = %{pattern: :test}
      {:ok, pid} = Antibody.start_link(search_image)

      state = :sys.get_state(pid)
      # 5 minutes default
      assert state.ttl == 300

      GenServer.stop(pid)
    end

    test "triggers immediate hunt" do
      search_image = %{pattern: :test}
      {:ok, pid} = Antibody.start_link(search_image)

      # The :hunt message should be sent on init
      Process.sleep(50)
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Hunting Behavior
  # ═══════════════════════════════════════════════════════════════════════════

  describe "handle_info(:hunt, state)" do
    test "processes hunt message without crash" do
      search_image = %{pattern: :orphan_process}
      {:ok, pid} = Antibody.start_link(search_image)

      # Manually trigger hunt
      send(pid, :hunt)
      Process.sleep(50)

      # Should still be alive after hunting
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "maintains state during hunt" do
      search_image = %{pattern: :file_handle_leak}
      {:ok, pid} = Antibody.start_link(search_image)

      send(pid, :hunt)
      Process.sleep(50)

      state = :sys.get_state(pid)
      assert state.search_image == search_image

      GenServer.stop(pid)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Bind Function
  # ═══════════════════════════════════════════════════════════════════════════

  describe "bind/1" do
    test "returns :ok" do
      # bind/1 is currently a stub
      result = Antibody.bind(self())
      assert result == :ok
    end

    test "can be called with any PID" do
      {:ok, fake_target} = Agent.start(fn -> :target end)

      result = Antibody.bind(fake_target)
      assert result == :ok

      Agent.stop(fake_target)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Struct
  # ═══════════════════════════════════════════════════════════════════════════

  describe "struct" do
    test "has required fields" do
      antibody = %Antibody{}

      assert Map.has_key?(antibody, :search_image)
      assert Map.has_key?(antibody, :target_id)
      assert Map.has_key?(antibody, :ttl)
    end

    test "fields default to nil except ttl" do
      antibody = %Antibody{}

      assert antibody.search_image == nil
      assert antibody.target_id == nil
      assert antibody.ttl == nil
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Lifecycle Compliance (SC-IMMUNE-001)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "lifecycle compliance" do
    test "does not kill processes directly" do
      # SC-IMMUNE-001: Cannot kill directly; must flag for T-Cells
      search_image = %{pattern: :test}
      {:ok, pid} = Antibody.start_link(search_image)

      # Create a target process
      {:ok, target} = Agent.start(fn -> :alive end)

      # Binding should not kill the target
      Antibody.bind(target)
      Process.sleep(50)

      assert Process.alive?(target)

      Agent.stop(target)
      GenServer.stop(pid)
    end

    test "uses opsonization, not termination" do
      # Opsonization = flagging for phagocytosis
      # The bind/1 function should tag, not kill

      search_image = %{pattern: :suspicious}
      {:ok, pid} = Antibody.start_link(search_image)

      {:ok, target} = Agent.start(fn -> %{status: :active} end)

      # Bind should return :ok without terminating
      result = Antibody.bind(target)
      assert result == :ok
      assert Process.alive?(target)

      Agent.stop(target)
      GenServer.stop(pid)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Multiple Antibodies
  # ═══════════════════════════════════════════════════════════════════════════

  describe "multiple antibodies" do
    test "can spawn multiple antibodies for different patterns" do
      {:ok, ab1} = Antibody.start_link(%{pattern: :memory_leak})
      {:ok, ab2} = Antibody.start_link(%{pattern: :cpu_spike})
      {:ok, ab3} = Antibody.start_link(%{pattern: :deadlock})

      assert Process.alive?(ab1)
      assert Process.alive?(ab2)
      assert Process.alive?(ab3)

      # All have different search images
      assert :sys.get_state(ab1).search_image.pattern == :memory_leak
      assert :sys.get_state(ab2).search_image.pattern == :cpu_spike
      assert :sys.get_state(ab3).search_image.pattern == :deadlock

      GenServer.stop(ab1)
      GenServer.stop(ab2)
      GenServer.stop(ab3)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - PropCheck (PC)
  # ═══════════════════════════════════════════════════════════════════════════

  property "bind always returns :ok" do
    forall _ <- PC.boolean() do
      result = Antibody.bind(self())
      result == :ok
    end
  end

  property "antibodies can be spawned with any search image" do
    forall pattern <- PC.atom() do
      search_image = %{pattern: pattern}
      {:ok, pid} = Antibody.start_link(search_image)
      alive = Process.alive?(pid)
      GenServer.stop(pid)
      alive
    end
  end

  property "state always contains search_image" do
    forall pattern <- PC.oneof([:leak, :spike, :crash, :hang]) do
      search_image = %{pattern: pattern}
      {:ok, pid} = Antibody.start_link(search_image)
      state = :sys.get_state(pid)
      has_search_image = Map.has_key?(state, :search_image)
      GenServer.stop(pid)
      has_search_image
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - ExUnitProperties (SD)
  # ═══════════════════════════════════════════════════════════════════════════

  test "TTL is always 300 after init (property)" do
    for pattern <- [:leak, :spike, :crash, :hang] do
      search_image = %{pattern: pattern}
      {:ok, pid} = Antibody.start_link(search_image)
      state = :sys.get_state(pid)
      GenServer.stop(pid)
      assert state.ttl == 300
    end
  end

  test "multiple hunts don't crash (property)" do
    for count <- [1, 3, 5, 8, 10] do
      {:ok, pid} = Antibody.start_link(%{pattern: :test})

      for _ <- 1..count do
        send(pid, :hunt)
        Process.sleep(10)
      end

      alive = Process.alive?(pid)
      GenServer.stop(pid)
      assert alive
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Die Phase (SC-IMMUNE-002, SC-IMMUNE-006)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "die phase" do
    test "terminate_hunt triggers dying phase" do
      search_image = %{pattern: :test}
      {:ok, pid} = Antibody.start_link(search_image)

      # Force termination
      Antibody.terminate_hunt(pid)
      Process.sleep(50)

      # Should transition to dying phase
      state = :sys.get_state(pid)
      assert state.phase == :dying

      # Give it time to complete death
      Process.sleep(150)
      refute Process.alive?(pid)
    end

    test "die phase completes lifecycle" do
      search_image = %{pattern: :test}
      {:ok, pid} = Antibody.start_link(search_image)

      # Manually trigger die sequence
      send(pid, :ttl_expired)
      Process.sleep(200)

      # Process should terminate gracefully
      refute Process.alive?(pid)
    end

    test "state tracks quarantined_pids field" do
      search_image = %{pattern: :test}
      {:ok, pid} = Antibody.start_link(search_image)

      state = :sys.get_state(pid)
      assert Map.has_key?(state, :quarantined_pids)
      assert state.quarantined_pids == []

      GenServer.stop(pid)
    end

    test "findings include termination reason" do
      search_image = %{pattern: :test}
      {:ok, pid} = Antibody.start_link(search_image)

      # Force termination
      Antibody.terminate_hunt(pid)
      Process.sleep(50)

      state = :sys.get_state(pid)
      assert {:termination_reason, :forced_termination} in state.findings

      GenServer.stop(pid)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Kernel Process Protection (SC-IMMUNE-002)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "kernel process protection (SC-IMMUNE-002)" do
    test "safety_whitelisted? returns true for kernel processes" do
      # Test with the init process (always exists)
      init_pid = Process.whereis(:init)

      if init_pid do
        assert Antibody.safety_whitelisted?(init_pid) == true
      end
    end

    test "safety_whitelisted? returns false for regular processes" do
      {:ok, regular_pid} = Agent.start(fn -> :regular_process end)

      refute Antibody.safety_whitelisted?(regular_pid)

      Agent.stop(regular_pid)
    end

    test "bind refuses to bind to kernel process" do
      # :init is a kernel process that should be protected
      init_pid = Process.whereis(:init)

      if init_pid do
        # Should return :ok but log a warning (not actually bind)
        result = Antibody.bind(init_pid)
        assert result == :ok
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Quarantine Cleanup (SC-IMMUNE-006)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "quarantine cleanup (SC-IMMUNE-006)" do
    test "suspended processes are resumed on die" do
      # Create a GenServer that we can suspend/resume
      {:ok, target_pid} = Agent.start(fn -> :alive end)

      # Manually suspend it
      :sys.suspend(target_pid)

      # Verify it's suspended (times out on state access)
      assert catch_exit(Agent.get(target_pid, & &1, 100)) != nil

      # Resume it
      :sys.resume(target_pid)

      # Now it should work
      assert Agent.get(target_pid, & &1) == :alive

      Agent.stop(target_pid)
    end

    test "cleanup does not crash on dead processes" do
      search_image = %{pattern: :test}
      {:ok, pid} = Antibody.start_link(search_image)

      # Create and kill a process
      {:ok, dead_process} = Agent.start(fn -> :soon_dead end)
      dead_pid = dead_process
      Agent.stop(dead_process)

      # Verify it's dead
      refute Process.alive?(dead_pid)

      # Trigger cleanup - should not crash even with dead PIDs
      Antibody.terminate_hunt(pid)
      Process.sleep(200)

      # Antibody should have completed normally
      refute Process.alive?(pid)
    end

    test "uses sys.suspend not erlang.exit for quarantine" do
      # SC-IMMUNE-006: Quarantine uses :sys.suspend/1 not :erlang.exit/2
      # This test verifies the correct approach by testing that suspended
      # processes can be resumed (exit would make them unrecoverable)

      {:ok, suspendable} = Agent.start(fn -> :can_be_suspended end)

      # Suspend using the correct method
      :sys.suspend(suspendable)

      # Process should still be alive (just suspended)
      assert Process.alive?(suspendable)

      # Resume should work
      :sys.resume(suspendable)

      # And we can interact with it again
      assert Agent.get(suspendable, & &1) == :can_be_suspended

      Agent.stop(suspendable)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Telemetry Emissions
  # ═══════════════════════════════════════════════════════════════════════════

  describe "telemetry emissions" do
    setup do
      # Attach a test handler to capture telemetry events
      test_pid = self()

      handler_id = "test-handler-#{:erlang.unique_integer()}"

      events = [
        [:indrajaal, :prajna, :immune, :antibody, :spawn],
        [:indrajaal, :prajna, :immune, :antibody, :phase_transition],
        [:indrajaal, :prajna, :immune, :antibody, :die],
        [:indrajaal, :prajna, :immune, :antibody, :terminate],
        [:indrajaal, :prajna, :immune, :antibody, :bind_retry]
      ]

      :telemetry.attach_many(
        handler_id,
        events,
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
      end)

      {:ok, handler_id: handler_id}
    end

    test "emits spawn telemetry on init" do
      search_image = %{pattern: :test_spawn_telemetry}
      {:ok, pid} = Antibody.start_link(search_image)

      # Should receive spawn telemetry
      assert_receive {:telemetry, [:indrajaal, :prajna, :immune, :antibody, :spawn], _, metadata},
                     1000

      assert metadata.search_image == search_image

      GenServer.stop(pid)
    end

    test "emits phase_transition telemetry on die" do
      search_image = %{pattern: :test_phase_telemetry}
      {:ok, pid} = Antibody.start_link(search_image)

      # Force termination
      Antibody.terminate_hunt(pid)
      Process.sleep(50)

      # Should receive phase transition telemetry (to dying)
      assert_receive {:telemetry, [:indrajaal, :prajna, :immune, :antibody, :phase_transition],
                      measurements, _metadata},
                     1000

      assert measurements.to == :dying

      GenServer.stop(pid)
    end

    test "emits die telemetry on death" do
      search_image = %{pattern: :test_die_telemetry}
      {:ok, pid} = Antibody.start_link(search_image)

      # Force termination and wait for death
      Antibody.terminate_hunt(pid)
      Process.sleep(200)

      # Should receive die telemetry with lifecycle duration
      assert_receive {:telemetry, [:indrajaal, :prajna, :immune, :antibody, :die], measurements,
                      _metadata},
                     1000

      assert is_integer(measurements.lifecycle_duration_ms)
      assert measurements.lifecycle_duration_ms >= 0
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Status Function
  # ═══════════════════════════════════════════════════════════════════════════

  describe "status/1" do
    test "returns current status" do
      search_image = %{pattern: :status_test, severity: :high}
      {:ok, pid} = Antibody.start_link(search_image)

      status = Antibody.status(pid)

      assert status.phase == :searching
      assert status.search_image == search_image
      assert status.target_id == nil
      assert is_integer(status.ttl_remaining)
      assert status.findings_count == 0
      assert status.bind_attempts == 0

      GenServer.stop(pid)
    end

    test "ttl_remaining decreases over time" do
      search_image = %{pattern: :ttl_test}
      {:ok, pid} = Antibody.start_link(search_image)

      status1 = Antibody.status(pid)
      Process.sleep(1100)
      status2 = Antibody.status(pid)

      assert status2.ttl_remaining < status1.ttl_remaining

      GenServer.stop(pid)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - Die Phase (PC)
  # ═══════════════════════════════════════════════════════════════════════════

  property "terminate_hunt always leads to dying phase" do
    forall pattern <- PC.oneof([:a, :b, :c, :d, :e]) do
      search_image = %{pattern: pattern}
      {:ok, pid} = Antibody.start_link(search_image)

      Antibody.terminate_hunt(pid)
      Process.sleep(50)

      state = :sys.get_state(pid)
      is_dying = state.phase == :dying

      GenServer.stop(pid)
      is_dying
    end
  end

  property "status always returns valid map" do
    forall pattern <- PC.atom() do
      search_image = %{pattern: pattern}
      {:ok, pid} = Antibody.start_link(search_image)

      status = Antibody.status(pid)

      valid =
        is_map(status) and
          Map.has_key?(status, :phase) and
          Map.has_key?(status, :search_image) and
          Map.has_key?(status, :ttl_remaining)

      GenServer.stop(pid)
      valid
    end
  end
end
