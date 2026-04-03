defmodule Indrajaal.Observability.Fractal.ContentRouterTest do
  @moduledoc """
  TDG Tests for ContentRouter module.

  WHAT: Tests for intelligent log backend selection and routing.
  WHY: Ensures STAMP compliance (SC-LOG-001, SC-LOG-006, SC-LOG-010) and
       verifies routing decisions are correct and performant.
  CONSTRAINTS:
  - Performance: < 1us per route decision
  - Multi-cast support to multiple backends
  - Key expression matching

  ## Test Categories

  1. Routing Logic Tests - route/1, route_batch/1
  2. Rule Management Tests - add_rule/1, remove_rule/1, set_rule_enabled/2
  3. Backend Health Tests - set_backend_health/2, healthy_backends/0
  4. Default Routing Rules Tests - Security, L5, Error tracking
  5. Performance Tests - Latency verification
  6. Integration Tests - Cross-module behavior
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: PropCheck/StreamData disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Observability.Fractal.ContentRouter
  alias Indrajaal.Observability.Fractal.FractalControl

  @moduletag :content_router

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Start ContentRouter if not running
    case Process.whereis(ContentRouter) do
      nil ->
        {:ok, pid} = ContentRouter.start_link([])

        on_exit(fn ->
          if Process.alive?(pid), do: GenServer.stop(pid)
        end)

        %{pid: pid}

      pid ->
        # Reset stats for clean test
        ContentRouter.reset_stats()
        %{pid: pid}
    end
  end

  # ============================================================
  # ROUTING LOGIC TESTS
  # ============================================================

  describe "route/1" do
    test "returns routing decision for entry" do
      entry = %{key: "Indrajaal/Alarms/create", level: :l4}
      decision = ContentRouter.route(entry)

      assert is_map(decision)
      assert Map.has_key?(decision, :backends)
      assert Map.has_key?(decision, :retention)
      assert Map.has_key?(decision, :matched_rule)
      assert Map.has_key?(decision, :should_emit)
    end

    test "routes L4/L5 entries to persistent backends" do
      entry = %{key: "Indrajaal/System/health", level: :l4}
      decision = ContentRouter.route(entry)

      # L4 should include PostgreSQL or TimescaleDB
      assert :postgresql in decision.backends or :timescale_db in decision.backends or
               :otlp in decision.backends
    end

    test "routes L1/L2 entries to ephemeral backends" do
      entry = %{key: "Indrajaal/Debug/trace", level: :l1}
      decision = ContentRouter.route(entry)

      # L1 should use memory or console
      assert :memory in decision.backends or :console in decision.backends
    end

    test "matches security audit rule" do
      ContentRouter.initialize_with_defaults()
      entry = %{key: "Indrajaal/Security/audit/login", level: :l4}
      decision = ContentRouter.route(entry)

      # Should match security-audit rule
      assert decision.matched_rule == "security-audit" or :siem in decision.backends
    end

    test "matches error tracking rule" do
      ContentRouter.initialize_with_defaults()
      entry = %{key: "Indrajaal/Alarms/error", level: :l3}
      decision = ContentRouter.route(entry)

      # Should match error-tracking rule
      assert decision.matched_rule == "error-tracking" or :error_tracker in decision.backends
    end

    test "uses default routing when no rules match" do
      entry = %{key: "Unknown/Module/function", level: :l3}
      decision = ContentRouter.route(entry)

      # Should use defaults
      assert is_list(decision.backends)
      assert length(decision.backends) > 0
    end
  end

  describe "route_batch/1" do
    test "routes multiple entries efficiently" do
      entries = [
        %{key: "Indrajaal/Alarms/create", level: :l4},
        %{key: "Indrajaal/Security/audit", level: :l5},
        %{key: "Indrajaal/Debug/trace", level: :l1}
      ]

      results = ContentRouter.route_batch(entries)

      assert length(results) == 3

      assert Enum.all?(results, fn {entry, decision} ->
               is_map(entry) and is_map(decision)
             end)
    end
  end

  # ============================================================
  # RULE MANAGEMENT TESTS
  # ============================================================

  describe "add_rule/1" do
    test "adds a new routing rule" do
      rule = %{
        id: "test-rule",
        key_expr: "Test/**",
        compiled_expr: nil,
        min_level: :l3,
        max_level: :l5,
        backends: [:otlp],
        retention: %{
          min_retention: 60_000,
          max_retention: 3600_000,
          archive_on_expiry: false,
          compression_level: 0
        },
        priority: 50,
        enabled: true
      }

      assert :ok = ContentRouter.add_rule(rule)

      rules = ContentRouter.get_rules()
      assert Enum.any?(rules, fn r -> r.id == "test-rule" end)
    end
  end

  describe "remove_rule/1" do
    test "removes an existing rule" do
      rule = %{
        id: "remove-test",
        key_expr: "Remove/**",
        compiled_expr: nil,
        min_level: :l1,
        max_level: :l5,
        backends: [:console],
        retention: %{
          min_retention: 0,
          max_retention: 0,
          archive_on_expiry: false,
          compression_level: 0
        },
        priority: 1,
        enabled: true
      }

      ContentRouter.add_rule(rule)
      assert :ok = ContentRouter.remove_rule("remove-test")

      rules = ContentRouter.get_rules()
      refute Enum.any?(rules, fn r -> r.id == "remove-test" end)
    end

    test "returns error for non-existent rule" do
      assert {:error, :not_found} = ContentRouter.remove_rule("nonexistent")
    end
  end

  describe "set_rule_enabled/2" do
    test "enables and disables a rule" do
      rule = %{
        id: "toggle-test",
        key_expr: "Toggle/**",
        compiled_expr: nil,
        min_level: :l1,
        max_level: :l5,
        backends: [:console],
        retention: %{
          min_retention: 0,
          max_retention: 0,
          archive_on_expiry: false,
          compression_level: 0
        },
        priority: 1,
        enabled: true
      }

      ContentRouter.add_rule(rule)

      assert :ok = ContentRouter.set_rule_enabled("toggle-test", false)
      rules = ContentRouter.get_rules()
      toggle_rule = Enum.find(rules, fn r -> r.id == "toggle-test" end)
      assert toggle_rule.enabled == false

      assert :ok = ContentRouter.set_rule_enabled("toggle-test", true)
      rules = ContentRouter.get_rules()
      toggle_rule = Enum.find(rules, fn r -> r.id == "toggle-test" end)
      assert toggle_rule.enabled == true
    end
  end

  # ============================================================
  # BACKEND HEALTH TESTS
  # ============================================================

  describe "backend health management" do
    test "set_backend_health updates health status" do
      ContentRouter.set_backend_health(:siem, false)
      refute ContentRouter.backend_healthy?(:siem)

      ContentRouter.set_backend_health(:siem, true)
      assert ContentRouter.backend_healthy?(:siem)
    end

    test "healthy_backends returns only healthy backends" do
      ContentRouter.set_backend_health(:postgresql, true)
      ContentRouter.set_backend_health(:siem, false)

      healthy = ContentRouter.healthy_backends()
      assert :postgresql in healthy
      refute :siem in healthy
    end

    test "route falls back to console when all backends are unhealthy" do
      # Mark all backends as unhealthy
      ContentRouter.set_backend_health(:postgresql, false)
      ContentRouter.set_backend_health(:timescale_db, false)
      ContentRouter.set_backend_health(:otlp, false)
      ContentRouter.set_backend_health(:memory, false)

      entry = %{key: "Test/fallback", level: :l4}
      decision = ContentRouter.route(entry)

      # Should fallback to console
      assert :console in decision.backends

      # Restore health
      ContentRouter.set_backend_health(:postgresql, true)
      ContentRouter.set_backend_health(:timescale_db, true)
      ContentRouter.set_backend_health(:otlp, true)
      ContentRouter.set_backend_health(:memory, true)
    end
  end

  # ============================================================
  # DEFAULT ROUTING RULES TESTS
  # ============================================================

  describe "predefined rules" do
    test "security_audit_rule has correct configuration" do
      rule = ContentRouter.security_audit_rule()

      assert rule.id == "security-audit"
      assert rule.key_expr == "Indrajaal/Security/**"
      assert rule.priority == 100
      assert :siem in rule.backends
      assert rule.retention.archive_on_expiry == true
    end

    test "l5_dual_write_rule routes to SIEM and SigNoz" do
      rule = ContentRouter.l5_dual_write_rule()

      assert rule.id == "l5-dual-write"
      assert :siem in rule.backends
      assert :signoz in rule.backends
    end

    test "error_tracking_rule matches error patterns" do
      rule = ContentRouter.error_tracking_rule()

      assert rule.id == "error-tracking"
      assert rule.key_expr == "Indrajaal/**/error"
      assert :error_tracker in rule.backends
    end

    test "debug_rule has lowest priority" do
      rule = ContentRouter.debug_rule()

      assert rule.id == "debug"
      # Lowest
      assert rule.priority == 1
      assert :memory in rule.backends or :console in rule.backends
    end

    test "initialize_with_defaults adds all predefined rules" do
      ContentRouter.initialize_with_defaults()

      rules = ContentRouter.get_rules()
      rule_ids = Enum.map(rules, fn r -> r.id end)

      assert "security-audit" in rule_ids
      assert "l5-dual-write" in rule_ids
      assert "error-tracking" in rule_ids
      assert "debug" in rule_ids
    end
  end

  # ============================================================
  # STATISTICS TESTS
  # ============================================================

  describe "statistics" do
    test "get_stats returns comprehensive statistics" do
      stats = ContentRouter.get_stats()

      assert Map.has_key?(stats, :route_count)
      assert Map.has_key?(stats, :fallback_count)
      assert Map.has_key?(stats, :rule_count)
      assert Map.has_key?(stats, :enabled_rules)
      assert Map.has_key?(stats, :healthy_backends)
    end

    test "reset_stats clears counters" do
      # Route some entries
      for _ <- 1..10 do
        ContentRouter.route(%{key: "Test/stats", level: :l4})
      end

      ContentRouter.reset_stats()
      stats = ContentRouter.get_stats()

      assert stats.route_count == 0
      assert stats.fallback_count == 0
    end
  end

  # ============================================================
  # PERFORMANCE TESTS
  # ============================================================

  describe "performance" do
    @tag :performance
    test "route decision takes less than 100 microseconds" do
      entry = %{key: "Indrajaal/Performance/test", level: :l4}

      # Warm up
      for _ <- 1..100 do
        ContentRouter.route(entry)
      end

      # Measure
      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..1000 do
            ContentRouter.route(entry)
          end
        end)

      avg_time_us = time_us / 1000
      # Should average less than 100 microseconds per route
      assert avg_time_us < 100, "Average route time #{avg_time_us}us exceeds 100us target"
    end
  end

  # ============================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================

  describe "PropCheck property tests" do
    property "route always returns valid decision structure" do
      forall {key, level_int} <- {PC.binary(), PC.integer(1, 5)} do
        level = int_to_level(level_int)
        entry = %{key: key, level: level}
        decision = ContentRouter.route(entry)

        is_map(decision) and
          is_list(decision.backends) and
          is_map(decision.retention) and
          is_boolean(decision.should_emit)
      end
    end

    property "route_batch processes all entries" do
      forall count <- PC.integer(1, 10) do
        entries = for _ <- 1..count, do: %{key: "Test/key", level: :l4}
        results = ContentRouter.route_batch(entries)

        length(results) == count
      end
    end
  end

  # ============================================================
  # PROPERTY-BASED TESTS (ExUnitProperties)
  # ============================================================

  describe "ExUnitProperties property tests" do
    test "routing is deterministic for same entry" do
      ExUnitProperties.check all(
                               key <- SD.string(:alphanumeric, min_length: 1, max_length: 50),
                               level_int <- SD.integer(1..5)
                             ) do
        level = int_to_level(level_int)
        entry = %{key: key, level: level}

        decision1 = ContentRouter.route(entry)
        decision2 = ContentRouter.route(entry)

        assert decision1.backends == decision2.backends
        assert decision1.matched_rule == decision2.matched_rule
      end
    end

    test "backends list is never empty" do
      ExUnitProperties.check all(
                               key <- SD.string(:alphanumeric, min_length: 1, max_length: 50),
                               level_int <- SD.integer(1..5)
                             ) do
        level = int_to_level(level_int)
        entry = %{key: key, level: level}

        decision = ContentRouter.route(entry)
        assert length(decision.backends) > 0
      end
    end
  end

  # ============================================================
  # INTEGRATION TESTS
  # ============================================================

  describe "integration with FractalControl" do
    test "respects FractalControl shedding state" do
      # Start FractalControl if needed
      case Process.whereis(FractalControl) do
        nil -> FractalControl.start_link([])
        _ -> :ok
      end

      # Activate load shedding
      FractalControl.update_resource_metrics(95.0, 50.0)
      Process.sleep(100)

      # Route should still work during shedding
      entry = %{key: "Test/shedding", level: :l4}
      decision = ContentRouter.route(entry)

      assert is_map(decision)
      assert decision.should_emit == true

      # Deactivate shedding
      FractalControl.update_resource_metrics(50.0, 50.0)
      Process.sleep(100)
    end
  end

  describe "telemetry events" do
    test "emits telemetry on rule addition" do
      test_pid = self()

      :telemetry.attach(
        "test-rule-added",
        [:fractal, :router, :rule_added],
        fn event_name, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event_name, measurements, metadata})
        end,
        nil
      )

      rule = %{
        id: "telemetry-test",
        key_expr: "Telemetry/**",
        compiled_expr: nil,
        min_level: :l1,
        max_level: :l5,
        backends: [:console],
        retention: %{
          min_retention: 0,
          max_retention: 0,
          archive_on_expiry: false,
          compression_level: 0
        },
        priority: 1,
        enabled: true
      }

      ContentRouter.add_rule(rule)

      assert_receive {:telemetry, [:fractal, :router, :rule_added], %{count: 1},
                      %{rule_id: "telemetry-test"}},
                     1000

      :telemetry.detach("test-rule-added")
    end
  end

  # ============================================================
  # STAMP COMPLIANCE TESTS
  # ============================================================

  describe "STAMP compliance" do
    @tag :stamp
    test "SC-LOG-001: routing is non-blocking" do
      entry = %{key: "Indrajaal/STAMP/async", level: :l5}

      {time_us, _decision} =
        :timer.tc(fn ->
          ContentRouter.route(entry)
        end)

      # Should complete in under 1ms (1000 microseconds)
      assert time_us < 1000, "Route took #{time_us}us, should be < 1000us"
    end

    @tag :stamp
    test "SC-LOG-010: L1/L2 route to ephemeral, L4/L5 to persistent" do
      l1_entry = %{key: "Test/ephemeral", level: :l1}
      l5_entry = %{key: "Test/persistent", level: :l5}

      l1_decision = ContentRouter.route(l1_entry)
      l5_decision = ContentRouter.route(l5_entry)

      # L1 should not include persistent backends by default
      ephemeral = [:memory, :console, :wal]
      persistent = [:postgresql, :object_store]

      l1_has_ephemeral = Enum.any?(l1_decision.backends, fn b -> b in ephemeral end)

      l5_has_persistent =
        Enum.any?(l5_decision.backends, fn b -> b in persistent end) or
          :otlp in l5_decision.backends

      assert l1_has_ephemeral or :otlp in l1_decision.backends
      assert l5_has_persistent
    end
  end

  # ============================================================
  # HELPER FUNCTIONS
  # ============================================================

  defp int_to_level(1), do: :l1
  defp int_to_level(2), do: :l2
  defp int_to_level(3), do: :l3
  defp int_to_level(4), do: :l4
  defp int_to_level(5), do: :l5
  defp int_to_level(_), do: :l4
end
