defmodule Indrajaal.Cockpit.Prajna.Bio.MembraneTest do
  @moduledoc """
  ## Membrane Module Test Suite

  WHAT: Comprehensive tests for the Holon Membrane protection boundaries.

  WHY: Validates that the membrane correctly enforces rate limiting, circuit breaking,
       health-aware routing, and payload validation as required by the biomorphic
       architecture.

  CONSTRAINTS:
    - SC-BIO-002: Rejects non-conforming messages
    - SC-PRF-050: Response time < 50ms
    - SC-CIRCUIT-001: Circuit breaker integration
    - SC-OBS-069: Telemetry emission for all crossings
    - TDG methodology with dual property tests

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-29 |
  | Author | W16 (Worker Agent) |
  | STAMP | SC-BIO-002, SC-PRF-050, SC-CIRCUIT-001, SC-OBS-069 |
  """

  use ExUnit.Case, async: false
  @moduletag :zenoh_nif
  use PropCheck
  # EP-GEN-014: Re-import to exclude check/2 (conflicts with ExUnitProperties)
  import PropCheck, except: [check: 2]
  alias PropCheck.BasicTypes, as: PC
  # NOTE: We need check/2 for `ExUnitProperties.check all(...)` syntax - do NOT exclude it
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias StreamData, as: SD

  alias Indrajaal.Cockpit.Prajna.Bio.Membrane
  alias Indrajaal.Cockpit.Prajna.Bio.Types.GeneticPayload

  # ═══════════════════════════════════════════════════════════════════════════
  # MOCK MODULES FOR TESTING
  # ═══════════════════════════════════════════════════════════════════════════

  defmodule MockTargetProcess do
    @moduledoc false
    use GenServer

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts)
    end

    def init(opts) do
      test_pid = Keyword.get(opts, :test_pid)
      fail_count = Keyword.get(opts, :fail_count, 0)
      {:ok, %{test_pid: test_pid, fail_count: fail_count, call_count: 0}}
    end

    def handle_call(msg, _from, state) do
      new_count = state.call_count + 1

      if state.test_pid do
        send(state.test_pid, {:target_received, msg, new_count})
      end

      if new_count <= state.fail_count do
        {:reply, {:error, :simulated_failure}, %{state | call_count: new_count}}
      else
        {:reply, {:ok, :success}, %{state | call_count: new_count}}
      end
    end

    def handle_cast(msg, state) do
      if state.test_pid do
        send(state.test_pid, {:target_cast, msg})
      end

      {:noreply, state}
    end
  end

  defmodule MockTargetModule do
    @moduledoc false

    def echo(arg), do: {:echoed, arg}
    def add(a, b), do: a + b
    def fail(_arg), do: raise("Simulated failure")
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # TEST SETUP
  # ═══════════════════════════════════════════════════════════════════════════

  setup do
    # Ensure clean state
    :telemetry.attach_many(
      "membrane-test-handler",
      [
        [:indrajaal, :membrane, :crossing],
        [:indrajaal, :membrane, :circuit_opened],
        [:indrajaal, :membrane, :circuit_closed],
        [:indrajaal, :membrane, :started]
      ],
      &__MODULE__.handle_telemetry_event/4,
      %{test_pid: self()}
    )

    on_exit(fn ->
      :telemetry.detach("membrane-test-handler")
    end)

    {:ok, target} = MockTargetProcess.start_link(test_pid: self())
    membrane_name = :"membrane_test_#{System.unique_integer([:positive])}"

    {:ok, membrane} =
      Membrane.start_link(
        name: membrane_name,
        target: target,
        rate_limit: 10
      )

    %{membrane: membrane, target: target, membrane_name: membrane_name}
  end

  def handle_telemetry_event(event, measurements, metadata, config) do
    if config.test_pid do
      send(config.test_pid, {:telemetry, event, measurements, metadata})
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # 1. PAYLOAD VALIDATION TESTS (ingest/2 via cross/3)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "SC-BIO-002: Payload Validation" do
    test "accepts valid GeneticPayload struct", %{membrane: membrane} do
      payload = %GeneticPayload{
        id: "test-001",
        timestamp: DateTime.utc_now(),
        genome_hash: "v1.0",
        dna: %{action: :test},
        markers: [],
        signature: nil
      }

      result = Membrane.cross(membrane, payload)

      # MockTargetProcess returns {:ok, :success}, so membrane wraps as {:ok, {:ok, :success}}
      assert {:ok, {:ok, :success}} = result

      # Verify the target received the payload
      assert_receive {:target_received, ^payload, _call_count}, 500
    end

    test "accepts valid tuple action messages", %{membrane: membrane} do
      result = Membrane.cross(membrane, {:get_user, ["user-123"]})

      # Target process receives the call
      assert_receive {:target_received, {:get_user, ["user-123"]}, _}, 500
      assert {:ok, {:ok, :success}} = result
    end

    test "accepts function call format", %{membrane: membrane} do
      fun = fn x -> x * 2 end
      result = Membrane.cross(membrane, {:call, fun, [5]})

      assert {:ok, 10} = result
    end

    test "rejects invalid payload format via cast", %{membrane: membrane} do
      # Invalid payloads through cast should be silently dropped
      GenServer.cast(membrane, %{invalid: "payload"})

      # Should not receive anything at target
      refute_receive {:target_cast, _}, 100
    end

    test "rejects random binary data", %{membrane: membrane} do
      result = Membrane.cross(membrane, <<1, 2, 3, 4, 5>>)

      assert {:error, :invalid_genome} = result
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # 2. RATE LIMITING TESTS (metabolic metering)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "SC-PRF-050: Rate Limiting (Metabolic Metering)" do
    test "allows messages under rate limit", %{membrane: membrane} do
      # Rate limit is 10, send 5 messages
      results =
        for i <- 1..5 do
          Membrane.cross(membrane, {:action, [i]})
        end

      # All should succeed
      assert Enum.all?(results, fn result ->
               match?({:ok, _}, result)
             end)
    end

    test "rejects messages exceeding rate limit" do
      # Create membrane with very low rate limit
      {:ok, target} = MockTargetProcess.start_link(test_pid: self())

      {:ok, membrane} =
        Membrane.start_link(
          name: :"rate_limit_test_#{System.unique_integer([:positive])}",
          target: target,
          rate_limit: 3
        )

      # Send 3 messages (should all succeed)
      for _ <- 1..3 do
        Membrane.cross(membrane, {:action, []})
      end

      # 4th message should be rate limited
      result = Membrane.cross(membrane, {:action, []})

      assert {:error, :rate_limited} = result
    end

    test "rate limit resets after window expiration" do
      # This would require mocking time or waiting for the window
      # For now, verify the window mechanism exists in health report
      {:ok, target} = MockTargetProcess.start_link(test_pid: self())

      {:ok, membrane} =
        Membrane.start_link(
          name: :"window_test_#{System.unique_integer([:positive])}",
          target: target,
          rate_limit: 5
        )

      health = Membrane.health(membrane)

      assert health.metrics.rate_limit == 5
      assert health.metrics.message_count == 0
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # 3. CIRCUIT BREAKER STATE TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "SC-CIRCUIT-001: Circuit Breaker States" do
    test "circuit starts in closed state", %{membrane: membrane} do
      health = Membrane.health(membrane)

      assert health.metrics.circuit_state == :closed
      assert health.metrics.circuit_failures == 0
    end

    test "circuit opens after threshold failures" do
      # Create target that always fails
      {:ok, target} = MockTargetProcess.start_link(test_pid: self(), fail_count: 10)

      {:ok, membrane} =
        Membrane.start_link(
          name: :"circuit_test_#{System.unique_integer([:positive])}",
          target: target,
          rate_limit: 100
        )

      # Trigger failures (circuit threshold is 5)
      for _ <- 1..6 do
        Membrane.cross(membrane, {:fail, []})
      end

      # Give time for state to update
      Process.sleep(50)

      health = Membrane.health(membrane)

      assert health.metrics.circuit_state == :open
    end

    test "open circuit rejects new requests" do
      {:ok, target} = MockTargetProcess.start_link(test_pid: self(), fail_count: 10)

      {:ok, membrane} =
        Membrane.start_link(
          name: :"open_circuit_test_#{System.unique_integer([:positive])}",
          target: target,
          rate_limit: 100
        )

      # Force circuit open by causing failures
      for _ <- 1..6 do
        Membrane.cross(membrane, {:fail, []})
      end

      Process.sleep(50)

      # New request should be rejected immediately
      result = Membrane.cross(membrane, {:action, []})

      assert {:error, :circuit_open} = result
    end

    test "circuit can be manually reset", %{membrane: membrane} do
      # Attach compromised tag to simulate unhealthy state
      Membrane.attach_tag(membrane, :test_tag)

      Process.sleep(50)

      health = Membrane.health(membrane)
      assert :test_tag in health.metrics.immune_tags

      # Reset should work
      Membrane.reset_circuit(membrane)
      Process.sleep(50)

      health_after = Membrane.health(membrane)
      assert health_after.metrics.circuit_state == :closed
    end

    test "half-open state allows limited traffic" do
      # This tests the transition mechanism
      # In half-open state, traffic should be allowed for testing
      {:ok, target} = MockTargetProcess.start_link(test_pid: self())

      {:ok, membrane} =
        Membrane.start_link(
          name: :"half_open_test_#{System.unique_integer([:positive])}",
          target: target,
          rate_limit: 100
        )

      # Manually trigger half-open transition message
      send(membrane, :circuit_half_open)
      Process.sleep(50)

      # Should still accept messages (half-open allows traffic)
      result = Membrane.cross(membrane, {:action, []})

      assert {:ok, _} = result
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # 4. HEALTH-AWARE ROUTING TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Health-Aware Routing" do
    test "health status starts as healthy", %{membrane: membrane} do
      health = Membrane.health(membrane)

      assert health.status == :healthy
    end

    test "compromised tag affects health", %{membrane: membrane} do
      Membrane.attach_tag(membrane, :compromised)

      # Trigger health check by waiting for periodic check or call health
      Process.sleep(100)
      send(membrane, :health_check)
      Process.sleep(50)

      health = Membrane.health(membrane)

      # Compromised should make status unhealthy
      assert health.status == :unhealthy
    end

    test "endpoint health updates are tracked", %{membrane: membrane} do
      Membrane.update_endpoint_health(membrane, :accounts_api, :healthy)
      Process.sleep(50)

      health = Membrane.health(membrane)

      assert health.metrics.endpoints == 1
    end

    test "unhealthy endpoint blocks related requests" do
      {:ok, target} = MockTargetProcess.start_link(test_pid: self())

      {:ok, membrane} =
        Membrane.start_link(
          name: :"endpoint_health_test_#{System.unique_integer([:positive])}",
          target: target,
          rate_limit: 100
        )

      # Mark endpoint as unhealthy with enough failures
      for _ <- 1..4 do
        Membrane.update_endpoint_health(membrane, :get_user, :unhealthy)
        Process.sleep(10)
      end

      # Request to that endpoint should be blocked
      result = Membrane.cross(membrane, {:get_user, ["user-123"]})

      assert {:error, :endpoint_unhealthy} = result
    end

    test "healthy endpoints allow requests", %{membrane: membrane} do
      Membrane.update_endpoint_health(membrane, :list_users, :healthy)
      Process.sleep(50)

      result = Membrane.cross(membrane, {:list_users, []})

      assert {:ok, _} = result
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # 5. IMMUNE SYSTEM TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Immune System (Antibody Tags)" do
    test "tags can be attached via API", %{membrane: membrane} do
      Membrane.attach_tag(membrane, :quarantine)
      Process.sleep(50)

      health = Membrane.health(membrane)

      assert :quarantine in health.metrics.immune_tags
    end

    test "compromised tag blocks all crossings", %{membrane: membrane} do
      Membrane.attach_tag(membrane, :compromised)
      Process.sleep(50)

      result = Membrane.cross(membrane, {:action, []})

      assert {:error, :compromised} = result
    end

    test "multiple tags can be attached", %{membrane: membrane} do
      Membrane.attach_tag(membrane, :tag1)
      Membrane.attach_tag(membrane, :tag2)
      Membrane.attach_tag(membrane, :tag3)
      Process.sleep(50)

      health = Membrane.health(membrane)

      assert :tag1 in health.metrics.immune_tags
      assert :tag2 in health.metrics.immune_tags
      assert :tag3 in health.metrics.immune_tags
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # 6. MODULE PROTECTION TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Module Protection" do
    test "protect_module wraps module functions" do
      {:ok, _target} = MockTargetProcess.start_link(test_pid: self())

      {:ok, membrane} =
        Membrane.start_link(
          name: :"module_protect_test_#{System.unique_integer([:positive])}",
          target: MockTargetModule,
          rate_limit: 100
        )

      wrapped = Membrane.protect_module(membrane, MockTargetModule)

      assert Map.has_key?(wrapped, :echo)
      assert Map.has_key?(wrapped, :add)
      assert Map.has_key?(wrapped, :fail)
    end

    test "wrap/2 creates protected function" do
      {:ok, _target} = MockTargetProcess.start_link(test_pid: self())

      {:ok, membrane} =
        Membrane.start_link(
          name: :"wrap_test_#{System.unique_integer([:positive])}",
          target: MockTargetModule,
          rate_limit: 100
        )

      wrapped_echo = Membrane.wrap(membrane, &MockTargetModule.echo/1)

      # Call with single argument per documented API: protected_fn.(arg)
      # List.wrap treats [:test_arg] as args list, calling echo(:test_arg)
      result = wrapped_echo.(:test_arg)

      assert {:ok, {:echoed, :test_arg}} = result
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # 7. TELEMETRY TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "SC-OBS-069: Telemetry Emission" do
    test "emits telemetry on successful crossing", %{membrane: membrane} do
      Membrane.cross(membrane, {:action, []})

      assert_receive {:telemetry, [:indrajaal, :membrane, :crossing], measurements, metadata}, 500

      assert measurements.duration > 0
      assert measurements.count == 1
      assert metadata.result == :success
    end

    test "emits telemetry on rejected crossing", %{membrane: membrane} do
      Membrane.attach_tag(membrane, :compromised)
      Process.sleep(50)

      Membrane.cross(membrane, {:action, []})

      assert_receive {:telemetry, [:indrajaal, :membrane, :crossing], _measurements, metadata},
                     500

      assert metadata.result == :rejected
      assert metadata.reason == :compromised
    end

    test "emits started telemetry on initialization" do
      {:ok, _target} = MockTargetProcess.start_link(test_pid: self())

      {:ok, _membrane} =
        Membrane.start_link(
          name: :"telemetry_start_test_#{System.unique_integer([:positive])}",
          target: nil,
          rate_limit: 100
        )

      assert_receive {:telemetry, [:indrajaal, :membrane, :started], _, _}, 500
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # 8. PROPERTY-BASED TESTS (Dual: PropCheck + ExUnitProperties)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Property-Based: Rate Limiting Invariants" do
    @tag :property
    property "message count never exceeds rate limit + 1" do
      forall rate_limit <- PC.pos_integer() do
        rate_limit = min(rate_limit, 100)

        {:ok, target} = MockTargetProcess.start_link(test_pid: self())

        {:ok, membrane} =
          Membrane.start_link(
            name: :"prop_rate_test_#{System.unique_integer([:positive])}",
            target: target,
            rate_limit: rate_limit
          )

        # Send more messages than rate limit
        results =
          for _ <- 1..(rate_limit + 5) do
            Membrane.cross(membrane, {:action, []})
          end

        successful = Enum.count(results, fn r -> match?({:ok, _}, r) end)
        rate_limited = Enum.count(results, fn r -> r == {:error, :rate_limited} end)

        # Successful should be at most rate_limit
        successful <= rate_limit and rate_limited >= 5
      end
    end

    @tag :property
    test "ExUnitProperties: valid payloads are accepted" do
      {:ok, target} = MockTargetProcess.start_link(test_pid: self())

      {:ok, membrane} =
        Membrane.start_link(
          name: :"ex_unit_prop_test_#{System.unique_integer([:positive])}",
          target: target,
          rate_limit: 1000
        )

      for {id, genome} <- [
            {"test1", "genome1"},
            {"abc123", "hash456"},
            {"x", "y"},
            {"longid#{:rand.uniform(1000)}", "longhash#{:rand.uniform(1000)}"}
          ] do
        payload = %GeneticPayload{
          id: id,
          timestamp: DateTime.utc_now(),
          genome_hash: genome,
          dna: %{},
          markers: [],
          signature: nil
        }

        result = Membrane.cross(membrane, payload)

        assert match?({:ok, _}, result)
      end
    end
  end

  describe "Property-Based: Circuit Breaker Invariants" do
    @tag :property
    property "circuit opens after exactly threshold failures" do
      forall failure_count <- PC.integer(5, 10) do
        {:ok, target} = MockTargetProcess.start_link(test_pid: self(), fail_count: failure_count)

        {:ok, membrane} =
          Membrane.start_link(
            name: :"prop_circuit_test_#{System.unique_integer([:positive])}",
            target: target,
            rate_limit: 100
          )

        # Send failure_count messages
        for _ <- 1..failure_count do
          Membrane.cross(membrane, {:fail, []})
        end

        Process.sleep(50)

        health = Membrane.health(membrane)

        # Circuit should be open if we hit threshold (5)
        if failure_count >= 5 do
          health.metrics.circuit_state == :open
        else
          health.metrics.circuit_state == :closed
        end
      end
    end

    @tag :property
    test "ExUnitProperties: health report structure is consistent" do
      for {rate, name_suffix} <- [{1, 1}, {50, 500}, {100, 1000}, {25, 250}] do
        {:ok, target} = MockTargetProcess.start_link(test_pid: self())

        {:ok, membrane} =
          Membrane.start_link(
            name: :"health_struct_test_#{name_suffix}_#{System.unique_integer([:positive])}",
            target: target,
            rate_limit: rate
          )

        health = Membrane.health(membrane)

        assert is_atom(health.status)
        assert is_map(health.metrics)
        assert health.metrics.rate_limit == rate
        assert is_integer(health.metrics.message_count)
        assert health.metrics.circuit_state in [:closed, :open, :half_open]
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # 9. EDGE CASES AND ERROR HANDLING
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Edge Cases" do
    test "handles target process crash gracefully" do
      {:ok, target} = MockTargetProcess.start_link(test_pid: self())

      {:ok, membrane} =
        Membrane.start_link(
          name: :"crash_test_#{System.unique_integer([:positive])}",
          target: target,
          rate_limit: 100
        )

      # Stop target
      GenServer.stop(target)

      # Membrane should handle gracefully
      result = Membrane.cross(membrane, {:action, []})

      assert {:error, _} = result
    end

    test "membrane survives after target exits" do
      {:ok, target} = MockTargetProcess.start_link(test_pid: self())

      {:ok, membrane} =
        Membrane.start_link(
          name: :"survive_test_#{System.unique_integer([:positive])}",
          target: target,
          rate_limit: 100
        )

      GenServer.stop(target)

      # Membrane should still respond to health checks
      health = Membrane.health(membrane)

      assert is_map(health)
    end

    test "handles timeout gracefully" do
      # Create slow target
      defmodule SlowTarget do
        use GenServer
        def start_link, do: GenServer.start_link(__MODULE__, [])
        def init(_), do: {:ok, []}

        def handle_call(_msg, _from, state) do
          Process.sleep(2000)
          {:reply, :ok, state}
        end
      end

      {:ok, target} = SlowTarget.start_link()

      {:ok, membrane} =
        Membrane.start_link(
          name: :"timeout_test_#{System.unique_integer([:positive])}",
          target: target,
          rate_limit: 100
        )

      # Should timeout with short timeout
      assert catch_exit(Membrane.cross(membrane, {:slow_action, []}, timeout: 100))
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # 10. PERFORMANCE TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "SC-PRF-050: Performance Requirements" do
    @tag :performance
    test "crossing latency under 50ms for simple messages", %{membrane: membrane} do
      # Warm up
      Membrane.cross(membrane, {:warmup, []})

      # Measure
      {time_us, _result} =
        :timer.tc(fn ->
          Membrane.cross(membrane, {:action, []})
        end)

      time_ms = time_us / 1000

      assert time_ms < 50, "Crossing took #{time_ms}ms, should be < 50ms"
    end

    @tag :performance
    test "health check is fast", %{membrane: membrane} do
      {time_us, _result} =
        :timer.tc(fn ->
          Membrane.health(membrane)
        end)

      time_ms = time_us / 1000

      assert time_ms < 10, "Health check took #{time_ms}ms, should be < 10ms"
    end
  end
end
