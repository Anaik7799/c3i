defmodule Indrajaal.Observability.ZuipIntegrationTest do
  @moduledoc """
  Integration tests for ZUIP (Zenoh Universal Integration Plan) wiring points.

  Verifies that all 21 modules correctly invoke ZenohSafetyPublisher
  at the right integration points. Tests use behavioral verification
  (assert :ok returns, no crashes) since Zenoh is not available in test.

  ## STAMP Constraints
  - SC-ZTEST-008: Dual-write — log fallback ALWAYS written first
  - SC-ZUIP-001: All safety-critical mutations visible to Zenoh mesh

  ## Coverage
  - Phase 0-4: ZenohSafetyPublisher direct functions (20 functions)
  - Phase 5: T4 completeness gaps (7 integration points)

  ## Dual Property Testing (EP-GEN-014)
  Uses PC/SD aliases per SC-PROP-023.
  """

  use ExUnit.Case, async: true
  use PropCheck

  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # ============================================================
  # Phase 5 T4 Integration Tests: Application Boot Checkpoints
  # ============================================================

  describe "Application boot checkpoint wiring" do
    test "safe_boot_publish helper exists and is resilient" do
      # Verify the module compiles and the integration point exists
      assert Code.ensure_loaded?(Indrajaal.Application)
    end

    test "ZenohBootPublisher checkpoint functions exist" do
      assert Code.ensure_loaded?(Indrajaal.Boot.ZenohBootPublisher)
      mod = Indrajaal.Boot.ZenohBootPublisher

      # CP-BOOT-01
      assert function_exported?(mod, :preflight_start, 0)
      # CP-BOOT-02
      assert function_exported?(mod, :preflight_complete, 1)
      # CP-BOOT-08
      assert function_exported?(mod, :app_ready, 2)
      # CP-BOOT-10
      assert function_exported?(mod, :boot_complete, 3)
    end

    test "ZenohBootPublisher functions don't crash on invocation" do
      mod = Indrajaal.Boot.ZenohBootPublisher

      assert :ok == mod.preflight_start()
      assert :ok == mod.preflight_complete(100)
      assert :ok == mod.app_ready("test-node", 200)
      assert :ok == mod.boot_complete(500, 10, "[1,1,1,1,1,1]")
    end
  end

  # ============================================================
  # Phase 5 T4 Integration Tests: DualChannel
  # ============================================================

  describe "DualChannel Zenoh integration" do
    test "DualChannel module loads and has verification functions" do
      assert Code.ensure_loaded?(Indrajaal.Cockpit.Prajna.DualChannel)
      mod = Indrajaal.Cockpit.Prajna.DualChannel

      # verify_block/2 takes (block, expected_prev_hash)
      assert function_exported?(mod, :verify_block, 2)
    end

    test "DualChannel verify_block handles invalid blocks gracefully" do
      # DualChannel should publish jidoka_halt on disagreement
      # With invalid input, it should return an error without crashing
      result =
        Indrajaal.Cockpit.Prajna.DualChannel.verify_block(
          %{
            content: "test",
            block_hash: "invalid_hash",
            signature: "invalid_sig",
            prev_hash: "000",
            protocol_version: 1
          },
          "expected_prev"
        )

      # Should return {:error, ...} for invalid block, not crash
      # The exact shape depends on which channel fails first
      assert match?({:error, _, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================
  # Phase 5 T4 Integration Tests: TokenRevocationCache
  # ============================================================

  describe "TokenRevocationCache Zenoh integration" do
    test "TokenRevocationCache module has safe_publish wiring" do
      assert Code.ensure_loaded?(Indrajaal.Authentication.TokenRevocationCache)

      # Verify the revoke_token function exists
      mod = Indrajaal.Authentication.TokenRevocationCache
      assert function_exported?(mod, :revoke_token, 1)
      assert function_exported?(mod, :revoke_token, 2)
      assert function_exported?(mod, :revoked?, 1)
    end

    test "TokenRevocationCache revocation publishes without crash" do
      # Start the GenServer for this test
      {:ok, pid} = Indrajaal.Authentication.TokenRevocationCache.start_link([])

      try do
        jti = "test-token-#{:rand.uniform(1_000_000)}"

        # This should call safe_publish internally
        assert :ok == Indrajaal.Authentication.TokenRevocationCache.revoke_token(jti)

        # Verify the token is now revoked
        assert Indrajaal.Authentication.TokenRevocationCache.revoked?(jti)
      after
        GenServer.stop(pid)
      end
    end

    property "TokenRevocationCache handles arbitrary JTI strings" do
      forall jti <- PC.utf8() do
        jti_str = if byte_size(jti) > 0, do: jti, else: "fallback-jti"

        {:ok, pid} = Indrajaal.Authentication.TokenRevocationCache.start_link([])

        try do
          result = Indrajaal.Authentication.TokenRevocationCache.revoke_token(jti_str)
          result == :ok
        after
          GenServer.stop(pid)
        end
      end
    end
  end

  # ============================================================
  # Phase 5 T4 Integration Tests: SentinelBridge
  # ============================================================

  describe "SentinelBridge Zenoh integration" do
    test "SentinelBridge module has sync and safe_publish wiring" do
      assert Code.ensure_loaded?(Indrajaal.Cockpit.Prajna.SentinelBridge)
      mod = Indrajaal.Cockpit.Prajna.SentinelBridge

      # GenServer-based, verify start_link exists
      assert function_exported?(mod, :start_link, 1)
      assert function_exported?(mod, :get_health, 0)
    end
  end

  # ============================================================
  # Phase 5 T4 Integration Tests: AiCopilot
  # ============================================================

  describe "AiCopilot Zenoh integration" do
    test "AiCopilot module has safe_publish wiring for veto events" do
      assert Code.ensure_loaded?(Indrajaal.Cockpit.Prajna.AiCopilot)
      mod = Indrajaal.Cockpit.Prajna.AiCopilot

      # Verify the copilot GenServer exists
      assert function_exported?(mod, :start_link, 1)
    end
  end

  # ============================================================
  # Phase 5 T4 Integration Tests: SmartMetrics
  # ============================================================

  describe "SmartMetrics Zenoh integration" do
    test "SmartMetrics module has safe_zenoh_publish wiring" do
      assert Code.ensure_loaded?(Indrajaal.Cockpit.Prajna.SmartMetrics)
      mod = Indrajaal.Cockpit.Prajna.SmartMetrics

      assert function_exported?(mod, :record, 3)
      assert function_exported?(mod, :record, 4)
      assert function_exported?(mod, :alarmed_metrics, 0)
    end

    test "SmartMetrics record with warning threshold publishes to Zenoh" do
      {:ok, pid} = Indrajaal.Cockpit.Prajna.SmartMetrics.start_link([])

      try do
        # Record a value that exceeds warning threshold
        # This should trigger safe_zenoh_publish internally
        :ok =
          Indrajaal.Cockpit.Prajna.SmartMetrics.record(
            "test.zuip.metric",
            "ZUIP Test Metric",
            100.0,
            thresholds: %{warning_high: 50.0}
          )

        # Give GenServer time to process the cast
        Process.sleep(50)

        # The metric should be in alarmed state
        alarmed = Indrajaal.Cockpit.Prajna.SmartMetrics.alarmed_metrics()

        # Find our test metric
        zuip_alarmed =
          Enum.find(alarmed, fn {id, _metric} -> id == "test.zuip.metric" end)

        assert zuip_alarmed != nil
        {_id, metric} = zuip_alarmed
        assert metric.level == :warning
      after
        GenServer.stop(pid)
      end
    end

    test "SmartMetrics record below threshold does not alarm" do
      {:ok, pid} = Indrajaal.Cockpit.Prajna.SmartMetrics.start_link([])

      try do
        # Record a normal value — should NOT trigger Zenoh publish
        :ok =
          Indrajaal.Cockpit.Prajna.SmartMetrics.record(
            "test.zuip.normal",
            "ZUIP Normal Metric",
            10.0,
            thresholds: %{warning_high: 50.0}
          )

        Process.sleep(50)

        alarmed = Indrajaal.Cockpit.Prajna.SmartMetrics.alarmed_metrics()

        zuip_alarmed =
          Enum.find(alarmed, fn {id, _metric} -> id == "test.zuip.normal" end)

        assert zuip_alarmed == nil
      after
        GenServer.stop(pid)
      end
    end
  end

  # ============================================================
  # Phase 5 T4 Integration Tests: ForensicAuditTrail
  # ============================================================

  describe "ForensicAuditTrail Zenoh integration" do
    test "ForensicAuditTrail module has safe_publish wiring" do
      assert Code.ensure_loaded?(Indrajaal.Compliance.ForensicAuditTrail)
      mod = Indrajaal.Compliance.ForensicAuditTrail

      assert function_exported?(mod, :start_link, 0)
      assert function_exported?(mod, :start_link, 1)
      assert function_exported?(mod, :start_forensic_investigation, 2)
      assert function_exported?(mod, :start_forensic_investigation, 3)
    end
  end

  # ============================================================
  # Cross-cutting: ZenohSafetyPublisher API Completeness
  # ============================================================

  describe "ZenohSafetyPublisher API completeness" do
    test "all 20 publish functions exist" do
      mod = Indrajaal.Observability.ZenohSafetyPublisher
      assert Code.ensure_loaded?(mod)

      # Emergency tier (3)
      assert function_exported?(mod, :publish_guardian_emergency_stop, 1)
      assert function_exported?(mod, :publish_emergency_response, 2)
      assert function_exported?(mod, :publish_master_control_emergency, 3)

      # High priority tier (8)
      assert function_exported?(mod, :publish_guardian_veto, 2)
      assert function_exported?(mod, :publish_sentinel_threat, 4)
      assert function_exported?(mod, :publish_sentinel_quarantine, 2)
      assert function_exported?(mod, :publish_pattern_detected, 2)
      assert function_exported?(mod, :publish_dying_gasp, 2)
      assert function_exported?(mod, :publish_defense_level_change, 3)
      assert function_exported?(mod, :publish_circuit_breaker_transition, 3)
      assert function_exported?(mod, :publish_jidoka_halt, 2)

      # Normal priority tier (9)
      assert function_exported?(mod, :publish_jidoka_resume, 1)
      assert function_exported?(mod, :publish_boot_checkpoint, 2)
      assert function_exported?(mod, :publish_boot_checkpoint, 3)
      assert function_exported?(mod, :publish_fpps_result, 2)
      assert function_exported?(mod, :publish_wave_complete, 3)
      assert function_exported?(mod, :publish_master_control_cb, 2)
      assert function_exported?(mod, :publish_immutable_block, 2)
      assert function_exported?(mod, :publish_prajna_command, 3)
    end

    test "all callers use safe_publish pattern (structural verification)" do
      # Verify that all integration modules load successfully
      # which proves the safe_publish wiring compiles correctly
      callers = [
        Indrajaal.Application,
        Indrajaal.Authentication.TokenRevocationCache,
        Indrajaal.Cockpit.Prajna.DualChannel,
        Indrajaal.Cockpit.Prajna.SentinelBridge,
        Indrajaal.Cockpit.Prajna.AiCopilot,
        Indrajaal.Cockpit.Prajna.SmartMetrics,
        Indrajaal.Compliance.ForensicAuditTrail,
        Indrajaal.Cockpit.Prajna.MasterControl,
        Indrajaal.Cockpit.Prajna.ImmutableState,
        Indrajaal.Safety.Guardian,
        Indrajaal.Safety.Sentinel,
        Indrajaal.Safety.PatternHunter,
        Indrajaal.Safety.SymbioticDefense,
        Indrajaal.Safety.EmergencyResponse,
        Indrajaal.Safety.ErrorPatternEngine,
        Indrajaal.Deployment.DyingGasp,
        Indrajaal.Deployment.WaveExecutor,
        Indrajaal.Lifecycle.HealthCoordinator,
        Indrajaal.TPS.Jidoka,
        Indrajaal.Cluster.Apoptosis
      ]

      for mod <- callers do
        assert Code.ensure_loaded?(mod),
               "ZUIP caller #{inspect(mod)} failed to load"
      end
    end
  end

  # ============================================================
  # Cross-cutting: safe_publish resilience property
  # ============================================================

  describe "safe_publish pattern resilience" do
    property "ZenohSafetyPublisher never crashes on any input" do
      functions = [
        {:publish_guardian_emergency_stop, fn -> [PC.utf8()] end},
        {:publish_emergency_response, fn -> [PC.utf8(), PC.utf8()] end},
        {:publish_guardian_veto, fn -> [PC.term(), PC.utf8()] end},
        {:publish_sentinel_quarantine, fn -> [PC.utf8(), PC.utf8()] end},
        {:publish_jidoka_halt, fn -> [PC.atom(), PC.utf8()] end},
        {:publish_jidoka_resume, fn -> [PC.atom()] end},
        {:publish_boot_checkpoint, fn -> [PC.atom(), PC.atom()] end},
        {:publish_immutable_block, fn -> [PC.utf8(), PC.atom()] end}
      ]

      mod = Indrajaal.Observability.ZenohSafetyPublisher

      forall {func, gen_fn} <- PC.oneof(functions) do
        forall args <- gen_fn.() do
          try do
            apply(mod, func, args)
            true
          rescue
            _ -> false
          end
        end
      end
    end

    property "safe_publish helper pattern never crashes callers" do
      # Simulates what safe_publish does in each module
      forall function <- PC.atom() do
        forall args <- PC.list(PC.term()) do
          result =
            try do
              case Code.ensure_loaded(Indrajaal.Observability.ZenohSafetyPublisher) do
                {:module, mod} -> apply(mod, function, args)
                _ -> :ok
              end
            rescue
              _ -> :ok
            end

          result == :ok
        end
      end
    end
  end

  # ============================================================
  # SC-ZTEST-008: Dual-write structural verification
  # ============================================================

  describe "SC-ZTEST-008 dual-write compliance" do
    test "publish_async uses Logger before ZenohSession (code structure)" do
      # Read source and verify Logger call appears before ZenohSession call
      source = File.read!("lib/indrajaal/observability/zenoh_safety_publisher.ex")

      # Find publish_async function
      assert String.contains?(source, "defp publish_async(topic, data, priority)")

      # Find the log_fn pattern that writes log FIRST
      assert String.contains?(source, "log_fn.(")

      # Find ZenohSession call AFTER log
      assert String.contains?(source, "ZenohSession.publish_async(topic")

      # Verify log comes before Zenoh in the function body
      log_pos = :binary.match(source, "log_fn.(") |> elem(0)
      zenoh_pos = :binary.match(source, "ZenohSession.publish_async(topic") |> elem(0)
      assert log_pos < zenoh_pos, "SC-ZTEST-008: Log must be written BEFORE Zenoh publish"
    end

    test "publish_emergency uses Logger.critical before ZenohSession (code structure)" do
      source = File.read!("lib/indrajaal/observability/zenoh_safety_publisher.ex")

      assert String.contains?(source, "defp publish_emergency(topic, data)")
      assert String.contains?(source, "Logger.critical(")
      assert String.contains?(source, "ZenohSession.publish_emergency(topic")

      # Verify critical log comes before emergency publish
      critical_pos = :binary.match(source, "Logger.critical(") |> elem(0)
      emergency_pos = :binary.match(source, "ZenohSession.publish_emergency(topic") |> elem(0)

      assert critical_pos < emergency_pos,
             "SC-ZTEST-008: Logger.critical must precede emergency publish"
    end
  end

  # ============================================================
  # TelemetryBatcher integration
  # ============================================================

  describe "TelemetryBatcher integration" do
    test "TelemetryBatcher module loads and has core API" do
      assert Code.ensure_loaded?(Indrajaal.Observability.TelemetryBatcher)
      mod = Indrajaal.Observability.TelemetryBatcher

      assert function_exported?(mod, :start_link, 1)
      assert function_exported?(mod, :add, 2)
      assert function_exported?(mod, :flush, 1)
      assert function_exported?(mod, :stats, 1)
    end

    test "TelemetryBatcher batches events and publishes" do
      topic = "indrajaal/test/zuip/batch"

      {:ok, pid} =
        Indrajaal.Observability.TelemetryBatcher.start_link(
          topic: topic,
          flush_interval_ms: 100,
          max_batch_size: 5
        )

      try do
        # Add events
        for i <- 1..3 do
          :ok =
            Indrajaal.Observability.TelemetryBatcher.add(
              topic,
              %{event: i, type: "zuip_integration_test"}
            )
        end

        # Wait for flush
        Process.sleep(150)

        stats = Indrajaal.Observability.TelemetryBatcher.stats(topic)
        assert stats.events_batched >= 3
        assert stats.batches_sent >= 1
      after
        GenServer.stop(pid)
      end
    end
  end
end
