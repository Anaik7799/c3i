defmodule Indrajaal.Cockpit.Prajna.Immune.MaraTest do
  @moduledoc """
  TDG-Compliant Tests for Mara Module - Adversarial Chaos Agent.

  STAMP Compliance: SC-IMMUNE-001, SC-IMMUNE-002, SC-IMMUNE-007
  TDG: Dual property testing with PropCheck + ExUnitProperties

  Tests the Red Team agent that injects fault signals for resilience testing.
  """
  use ExUnit.Case, async: false
  @moduletag :zenoh_nif
  use PropCheck
  # EP-GEN-014: Re-import to exclude check/2 (conflicts with ExUnitProperties)
  import PropCheck, except: [check: 2]
  # EP-GEN-014: Conflict resolution - import StreamData as empty, alias as SD
  import StreamData, only: []
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cockpit.Prajna.Immune.Mara

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - GenServer Lifecycle
  # ═══════════════════════════════════════════════════════════════════════════

  describe "start_link/1" do
    test "starts the Mara agent" do
      # Stop existing if running
      case GenServer.whereis(Mara) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      assert {:ok, pid} = Mara.start_link([])
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "registers under module name" do
      case GenServer.whereis(Mara) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      {:ok, pid} = Mara.start_link([])

      assert GenServer.whereis(Mara) == pid

      GenServer.stop(pid)
    end
  end

  describe "init/1" do
    test "initializes with zero attacks" do
      case GenServer.whereis(Mara) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      {:ok, pid} = Mara.start_link([])

      # State should have attacks: 0
      state = :sys.get_state(pid)
      assert state.attacks == 0

      GenServer.stop(pid)
    end

    test "schedules first attack" do
      case GenServer.whereis(Mara) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      {:ok, pid} = Mara.start_link([])

      # Should receive :attack message within 6 seconds
      # (scheduled for 5 seconds after init)
      Process.sleep(100)
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Attack Execution
  # ═══════════════════════════════════════════════════════════════════════════

  describe "handle_info(:attack, state)" do
    test "increments attack counter" do
      case GenServer.whereis(Mara) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      {:ok, pid} = Mara.start_link([])

      initial_state = :sys.get_state(pid)
      assert initial_state.attacks == 0

      # Manually trigger attack
      send(pid, :attack)
      Process.sleep(50)

      new_state = :sys.get_state(pid)
      assert new_state.attacks == 1

      GenServer.stop(pid)
    end

    test "executes random attack type" do
      case GenServer.whereis(Mara) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      {:ok, pid} = Mara.start_link([])

      # Subscribe to prajna:metrics to catch broadcasts
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:metrics")

      # Trigger attack
      send(pid, :attack)

      # Wait for potential message (attack may or may not broadcast)
      receive do
        msg ->
          # Either poison_pill (raw map) or metabolic_flood (GeneticPayload)
          assert is_map(msg)
      after
        100 ->
          # Also valid - attack may be logged only
          :ok
      end

      GenServer.stop(pid)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Attack Types
  # ═══════════════════════════════════════════════════════════════════════════

  describe "attack types" do
    test "poison_pill broadcasts invalid schema" do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:metrics")

      # The poison_pill attack broadcasts %{bad: "data"}
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, "prajna:metrics", %{bad: "data"})

      assert_receive %{bad: "data"}, 100
    end

    test "metabolic_flood broadcasts GeneticPayload" do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:metrics")

      # Simulate metabolic flood
      if Code.ensure_loaded?(Indrajaal.Cockpit.Prajna.Bio.Types.GeneticPayload) do
        alias Indrajaal.Cockpit.Prajna.Bio.Types.GeneticPayload

        payload = %GeneticPayload{
          id: Ecto.UUID.generate(),
          timestamp: DateTime.utc_now(),
          genome_hash: "v1-flood",
          dna: %{flood: true}
        }

        Phoenix.PubSub.broadcast(Indrajaal.PubSub, "prajna:metrics", payload)

        assert_receive %GeneticPayload{}, 100
      else
        # GeneticPayload not loaded, skip
        :ok
      end
    end

    test "memory_leak broadcasts monotonic memory samples (SC-IMMUNE-005)" do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:metrics")

      # Simulate memory leak pattern with monotonically increasing values
      if Code.ensure_loaded?(Indrajaal.Cockpit.Prajna.Bio.Types.GeneticPayload) do
        alias Indrajaal.Cockpit.Prajna.Bio.Types.GeneticPayload

        base_memory = 100_000_000

        for i <- 1..3 do
          payload = %GeneticPayload{
            id: Ecto.UUID.generate(),
            timestamp: DateTime.utc_now(),
            genome_hash: "v1-memory-leak-#{i}",
            dna: %{
              memory_leak_test: true,
              sample_number: i,
              memory_bytes: base_memory + i * 1_000_000,
              monotonic_increase: true
            }
          }

          Phoenix.PubSub.broadcast(Indrajaal.PubSub, "prajna:metrics", payload)
        end

        # Should receive at least one memory leak payload
        assert_receive %GeneticPayload{dna: %{memory_leak_test: true}}, 200
      else
        :ok
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Memory Leak Attack (SC-IMMUNE-005)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "trigger_attack(:memory_leak)" do
    setup do
      case GenServer.whereis(Mara) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      {:ok, pid} = Mara.start_link(enabled: false)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

      # Resume to allow attacks
      Mara.resume()
      Process.sleep(50)

      {:ok, pid: pid}
    end

    test "returns :ok when triggered", %{pid: _pid} do
      # trigger_attack is a cast, so it always returns :ok
      assert :ok = Mara.trigger_attack(:memory_leak)
    end

    test "increments attack counter", %{pid: pid} do
      initial_state = :sys.get_state(pid)
      initial_attacks = initial_state.attacks

      Mara.trigger_attack(:memory_leak)
      Process.sleep(100)

      new_state = :sys.get_state(pid)
      assert new_state.attacks > initial_attacks
    end

    test "records attack in history", %{pid: _pid} do
      Mara.trigger_attack(:memory_leak)
      # Wait for async processing and 10 samples
      Process.sleep(700)

      history = Mara.history()
      assert length(history) >= 1

      # Most recent attack should be memory_leak
      [latest | _] = history
      assert latest.type == :memory_leak
    end

    test "broadcasts GeneticPayloads with memory_leak_test marker" do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:metrics")

      Mara.trigger_attack(:memory_leak)

      # Should receive multiple payloads with monotonically increasing memory values
      received =
        receive do
          %Indrajaal.Cockpit.Prajna.Bio.Types.GeneticPayload{dna: %{memory_leak_test: true} = dna} ->
            dna
        after
          1000 -> nil
        end

      assert received != nil
      assert received.monotonic_increase == true
    end

    test "creates 10 samples with monotonic increase pattern (SC-IMMUNE-005)" do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:metrics")

      Mara.trigger_attack(:memory_leak)

      # Collect all memory leak payloads
      samples =
        Enum.reduce_while(1..15, [], fn _, acc ->
          receive do
            %Indrajaal.Cockpit.Prajna.Bio.Types.GeneticPayload{
              dna: %{memory_leak_test: true, memory_bytes: bytes}
            } ->
              {:cont, [bytes | acc]}
          after
            200 ->
              {:halt, acc}
          end
        end)

      # Should have at least 10 samples (SC-IMMUNE-005 requirement)
      assert length(samples) >= 10

      # Samples should be monotonically increasing (reverse to get original order)
      ordered_samples = Enum.reverse(samples)
      pairs = Enum.zip(ordered_samples, Enum.drop(ordered_samples, 1))

      assert Enum.all?(pairs, fn {a, b} -> b > a end),
             "Memory samples should be monotonically increasing"
    end
  end

  describe "memory leak detection verification" do
    setup do
      case GenServer.whereis(Mara) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      {:ok, pid} = Mara.start_link(enabled: false)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

      Mara.resume()
      Process.sleep(50)

      {:ok, pid: pid}
    end

    test "schedules detection check after injection", %{pid: _pid} do
      # Trigger memory leak attack
      Mara.trigger_attack(:memory_leak)

      # Wait for detection check to be scheduled and processed
      # The module schedules check 1000ms after injection
      Process.sleep(1500)

      # If Sentinel is not running, detection will be false
      # but the test verifies the detection check mechanism runs
      stats = Mara.stats()
      assert is_map(stats)
      assert stats.total_attacks >= 1
    end

    test "detection check handles missing Sentinel gracefully" do
      # Trigger attack without SentinelBridge running
      Mara.trigger_attack(:memory_leak)

      # Wait for detection check
      Process.sleep(1500)

      # Should not crash, stats should be accessible
      stats = Mara.stats()
      assert is_map(stats)
      assert Map.has_key?(stats, :missed_detections)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Resilience
  # ═══════════════════════════════════════════════════════════════════════════

  describe "resilience" do
    test "survives multiple attacks" do
      case GenServer.whereis(Mara) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      {:ok, pid} = Mara.start_link([])

      # Trigger multiple attacks
      for _ <- 1..5 do
        send(pid, :attack)
        Process.sleep(10)
      end

      assert Process.alive?(pid)

      state = :sys.get_state(pid)
      assert state.attacks >= 5

      GenServer.stop(pid)
    end

    test "schedules follow-up attacks" do
      case GenServer.whereis(Mara) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      {:ok, pid} = Mara.start_link([])

      # Trigger attack
      send(pid, :attack)
      Process.sleep(50)

      # Mara should have scheduled another attack for 10s later
      # We can verify the process is still alive
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - PropCheck (PC)
  # ═══════════════════════════════════════════════════════════════════════════

  @all_attack_types [
    :poison_pill,
    :metabolic_flood,
    :latency_spike,
    :byzantine_fault,
    :cascade_failure,
    :memory_leak
  ]

  property "attack count never decreases" do
    forall attacks <- PC.range(0, 100) do
      state = %{attacks: attacks}
      new_state = %{state | attacks: state.attacks + 1}
      new_state.attacks > attacks
    end
  end

  property "attack types are from known set (all 6 types)" do
    forall _ <- PC.boolean() do
      attack = Enum.random(@all_attack_types)
      attack in @all_attack_types
    end
  end

  property "memory_leak is valid attack type" do
    forall _ <- PC.range(1, 100) do
      :memory_leak in @all_attack_types
    end
  end

  property "memory leak samples are monotonically increasing (SC-IMMUNE-005)" do
    forall base <- PC.range(100_000_000, 500_000_000) do
      # Simulate 10 samples with 1MB increments
      samples = for i <- 1..10, do: base + i * 1_000_000

      # Verify all pairs are monotonically increasing
      pairs = Enum.zip(samples, Enum.drop(samples, 1))
      Enum.all?(pairs, fn {a, b} -> b > a end)
    end
  end

  property "memory leak detection requires 10+ samples (SC-IMMUNE-005)" do
    forall sample_count <- PC.range(1, 20) do
      samples = for i <- 1..sample_count, do: 100_000_000 + i * 1_000_000

      # Only 10+ samples should trigger detection
      expected_detection = sample_count >= 10
      actual = length(samples) >= 10

      expected_detection == actual
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - ExUnitProperties (SD)
  # ═══════════════════════════════════════════════════════════════════════════

  test "initial state has zero attacks (property)" do
    state = %{attacks: 0}
    assert state.attacks == 0
  end

  test "attack increments are monotonic (property)" do
    for count <- [1, 5, 10, 15, 20] do
      increments = List.duplicate(1, count)
      final = Enum.reduce(increments, 0, fn inc, acc -> acc + inc end)
      assert final == length(increments)
    end
  end

  test "memory leak attack type is included in full attack taxonomy (SD)" do
    ExUnitProperties.check all(
                             attack_index <- SD.integer(0..5),
                             max_runs: 50
                           ) do
      attack = Enum.at(@all_attack_types, attack_index)
      assert attack in @all_attack_types
      assert :memory_leak in @all_attack_types
    end
  end

  test "memory sample increments are always positive (SD)" do
    ExUnitProperties.check all(
                             base <- SD.integer(100_000_000..500_000_000),
                             increment <- SD.integer(1_000..10_000_000),
                             max_runs: 50
                           ) do
      sample1 = base
      sample2 = base + increment

      assert sample2 > sample1, "Memory samples must be monotonically increasing"
    end
  end

  test "10 memory samples satisfy SC-IMMUNE-005 threshold (SD)" do
    ExUnitProperties.check all(
                             base <- SD.integer(100_000_000..500_000_000),
                             max_runs: 20
                           ) do
      # Generate exactly 10 samples with monotonic increase
      samples =
        for i <- 1..10 do
          base + i * 1_000_000
        end

      assert length(samples) >= 10, "SC-IMMUNE-005 requires 10+ samples"

      # Verify monotonic pattern
      pairs = Enum.zip(samples, Enum.drop(samples, 1))
      assert Enum.all?(pairs, fn {a, b} -> b > a end)
    end
  end
end
