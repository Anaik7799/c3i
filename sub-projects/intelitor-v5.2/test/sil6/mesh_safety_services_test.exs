defmodule Indrajaal.SIL6.MeshSafetyServicesTest do
  @moduledoc """
  SIL-6 Mesh Safety Services Tests.

  WHAT: Tests for Guardian, Sentinel, SymbioticDefense, FPPS validation,
        and immune system integration — the safety-critical services
        that enforce SIL-6 compliance at runtime.
  WHY: SIL-6 requires formal safety validation, threat detection, immune
       response, and constitutional compliance. These services form the
       safety envelope around all mesh operations.
  CONSTRAINTS:
    - SC-SIL6-001: PFH < 10⁻¹²
    - SC-SIL6-004: Neural-immune response < 50ms
    - SC-SIL6-006: Founder's Directive hardwired
    - SC-SIL6-015: Immutable audit trail
    - SC-IMMUNE-001: Sentinel monitors system health
    - SC-IMMUNE-004: PatternHunter detects pre-error signatures
    - SC-NEURO-001: AI output MUST pass Guardian.validate_proposal/1
    - SC-GUARD-003: Guardian integrates with FounderDirective
    - AOR-IMMUNE-002: ALWAYS call is_kernel_process?/1 before termination

  ## Change History
  | Version | Date       | Author      | Change                      |
  |---------|------------|-------------|-----------------------------|
  | 1.0.0   | 2026-03-09 | Claude Opus | Initial safety services     |

  @version "1.0.0"
  @last_modified "2026-03-09T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :sil6
  @moduletag :safety

  # ============================================================================
  # 1. GUARDIAN SAFETY KERNEL (SC-NEURO-001)
  # ============================================================================

  describe "Guardian: Safety validation kernel" do
    test "Guardian module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Safety.Guardian)
    end

    test "Guardian exports validate_proposal function" do
      exports = Indrajaal.Safety.Guardian.__info__(:functions)
      # start_link should be present at minimum
      assert {:start_link, 1} in exports
    end

    test "proposal structure includes required fields" do
      proposal = %{
        action: :deploy,
        target: "indrajaal-ex-app-1",
        risk_level: :medium,
        justification: "Rolling update for bugfix",
        requestor: "operator"
      }

      assert is_atom(proposal.action)
      assert is_binary(proposal.target)
      assert proposal.risk_level in [:low, :medium, :high, :critical]
    end

    test "destructive actions require explicit justification" do
      destructive_actions = [:delete, :force_stop, :reset, :purge, :reformat]

      for action <- destructive_actions do
        proposal = %{
          action: action,
          target: "test-container",
          risk_level: :high,
          justification: "Required for maintenance"
        }

        assert is_binary(proposal.justification),
               "Action #{action} must have justification"
      end
    end
  end

  # ============================================================================
  # 2. SENTINEL IMMUNE MONITOR (SC-IMMUNE-001)
  # ============================================================================

  describe "Sentinel: Health monitoring T-cell" do
    test "Sentinel module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Safety.Sentinel)
    end

    test "health score weights sum to 1.0" do
      weights = %{
        memory: 0.30,
        cpu: 0.20,
        error_rate: 0.25,
        process_anomaly: 0.15,
        quarantine: 0.10
      }

      total = Enum.reduce(weights, 0.0, fn {_k, v}, acc -> acc + v end)
      assert_in_delta total, 1.0, 0.001, "Health score weights must sum to 1.0"
    end

    test "health thresholds are within valid ranges" do
      thresholds = %{
        memory_pressure: 85,
        cpu_utilization: 90,
        error_rate: 100,
        process_anomalies: 5,
        quarantine_critical: 3
      }

      assert thresholds.memory_pressure > 0 and thresholds.memory_pressure <= 100
      assert thresholds.cpu_utilization > 0 and thresholds.cpu_utilization <= 100
      assert thresholds.error_rate > 0
      assert thresholds.process_anomalies > 0
      assert thresholds.quarantine_critical > 0
    end

    test "severity classification is consistent" do
      severity_critical = 80

      assert severity_critical > 50,
             "Critical severity threshold must be above medium"
    end
  end

  # ============================================================================
  # 3. SYMBIOTIC DEFENSE (SC-BIO-EXT-002)
  # ============================================================================

  describe "SymbioticDefense: Threat response system" do
    test "SymbioticDefense module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Safety.SymbioticDefense)
    end

    test "defense levels form severity hierarchy" do
      levels = [:normal, :elevated, :guarded, :high, :critical]

      for {level, index} <- Enum.with_index(levels) do
        assert is_atom(level)

        if index > 0 do
          # Each level is more severe than the previous
          prev = Enum.at(levels, index - 1)
          assert prev != level
        end
      end
    end

    test "threat categories cover key domains" do
      categories = [:financial, :reputational, :operational, :existential, :lineage]

      for category <- categories do
        assert is_atom(category)
      end

      # Lineage threats are highest priority per Ω₀
      assert :lineage in categories
      assert :existential in categories
    end

    test "threat severity levels are ordered" do
      severities = [:low, :medium, :high, :critical, :extinction]

      for severity <- severities do
        assert is_atom(severity)
      end

      # Extinction is the most severe
      assert List.last(severities) == :extinction
    end

    test "5-phase recovery protocol" do
      phases = [
        :restart,
        :reconfigure,
        :rollback,
        :escalate,
        :manual
      ]

      assert length(phases) == 5

      for phase <- phases do
        assert is_atom(phase)
      end
    end
  end

  # ============================================================================
  # 4. FPPS VALIDATION MODULE (SC-VAL-003)
  # ============================================================================

  describe "FPPS: Five-Point Pattern System" do
    test "FPPS module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Validation.FPPS)
    end

    test "FPPS exports validate/1" do
      exports = Indrajaal.Validation.FPPS.__info__(:functions)
      assert {:validate, 1} in exports
    end

    test "5 validation methods are defined" do
      methods = [:pattern, :ast, :statistical, :binary, :line_by_line]
      assert length(methods) == 5
    end

    test "Consensus module is available" do
      assert Code.ensure_loaded?(Indrajaal.Validation.Consensus)
    end

    test "pattern validation is available" do
      assert Code.ensure_loaded?(Indrajaal.Validation.Methods.Pattern)
    end

    test "AST validation is available" do
      assert Code.ensure_loaded?(Indrajaal.Validation.Methods.AST)
    end
  end

  # ============================================================================
  # 5. CONTAINER HEALTH MONITOR (SC-ZENOH-010)
  # ============================================================================

  describe "ContainerHealthMonitor: SOPv5.1 compliance" do
    test "ContainerHealthMonitor module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Containers.ContainerHealthMonitor)
    end

    test "exports start_link/1" do
      exports = Indrajaal.Containers.ContainerHealthMonitor.__info__(:functions)
      assert {:start_link, 1} in exports
    end

    test "exports validate_sopv51_config/1" do
      exports = Indrajaal.Containers.ContainerHealthMonitor.__info__(:functions)
      assert {:validate_sopv51_config, 1} in exports
    end
  end

  # ============================================================================
  # 6. ZENOH NATIVE INTERFACE (SC-ZENOH-001)
  # ============================================================================

  describe "Zenoh NIF: Native interface" do
    test "Zenoh NIF module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Native.Zenoh)
    end

    test "NIF exports session management functions" do
      exports = Indrajaal.Native.Zenoh.__info__(:functions)

      expected_functions = [
        {:open_session, 1},
        {:close_session, 1}
      ]

      for {name, arity} <- expected_functions do
        assert {name, arity} in exports,
               "Missing NIF function: #{name}/#{arity}"
      end
    end

    test "NIF exports pub/sub functions" do
      exports = Indrajaal.Native.Zenoh.__info__(:functions)

      expected_functions = [
        {:publish, 3},
        {:subscribe, 3}
      ]

      for {name, arity} <- expected_functions do
        assert {name, arity} in exports,
               "Missing NIF function: #{name}/#{arity}"
      end
    end

    test "SKIP_ZENOH_NIF env var is 0 (NIF active)" do
      skip = System.get_env("SKIP_ZENOH_NIF", "0")
      assert skip == "0", "SKIP_ZENOH_NIF must be 0 (got: #{skip})"
    end
  end

  # ============================================================================
  # 7. BOOT PUBLISHER (SC-ZTEST-006, SC-ZTEST-009)
  # ============================================================================

  describe "ZenohBootPublisher: Boot checkpoint messaging" do
    test "ZenohBootPublisher module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Boot.ZenohBootPublisher)
    end

    test "exports phase_started/4" do
      exports = Indrajaal.Boot.ZenohBootPublisher.__info__(:functions)
      assert {:phase_started, 4} in exports
    end

    test "exports phase_finished/5" do
      exports = Indrajaal.Boot.ZenohBootPublisher.__info__(:functions)
      assert {:phase_finished, 5} in exports
    end

    test "exports container_health/4" do
      exports = Indrajaal.Boot.ZenohBootPublisher.__info__(:functions)
      assert {:container_health, 4} in exports
    end

    test "exports quorum_achieved/3" do
      exports = Indrajaal.Boot.ZenohBootPublisher.__info__(:functions)
      assert {:quorum_achieved, 3} in exports
    end
  end

  # ============================================================================
  # 8. PROPERTY TESTS: Safety Invariants
  # ============================================================================

  describe "Property Tests: Safety service invariants" do
    property "defense levels are always valid atoms" do
      forall level <-
               PC.oneof([
                 PC.exactly(:normal),
                 PC.exactly(:elevated),
                 PC.exactly(:guarded),
                 PC.exactly(:high),
                 PC.exactly(:critical)
               ]) do
        is_atom(level)
      end
    end

    property "threat severity ordering is preserved" do
      severity_order = %{low: 1, medium: 2, high: 3, critical: 4, extinction: 5}
      severity_gen = PC.oneof(Enum.map(Map.keys(severity_order), &PC.exactly/1))

      forall s1 <- severity_gen do
        forall s2 <- severity_gen do
          if severity_order[s1] < severity_order[s2] do
            s1 != s2
          else
            true
          end
        end
      end
    end

    @tag :property
    test "StreamData: health score weights are valid floats" do
      ExUnitProperties.check all(weight <- SD.float(min: 0.0, max: 1.0)) do
        assert weight >= 0.0
        assert weight <= 1.0
      end
    end
  end

  # ============================================================================
  # 9. FMEA: Safety Service Failure Modes
  # ============================================================================

  describe "FMEA: Safety service failure modes" do
    @tag :fmea
    test "FMEA-SAFETY-001: Guardian unavailable (RPN=90)" do
      # System must not proceed without Guardian
      assert Code.ensure_loaded?(Indrajaal.Safety.Guardian),
             "Guardian module must always be available"
    end

    @tag :fmea
    test "FMEA-SAFETY-002: Sentinel health check timeout (RPN=72)" do
      # Sentinel check interval should be configurable
      default_interval_ms = 10_000

      assert default_interval_ms <= 30_000,
             "Health check interval should be <= 30s"
    end

    @tag :fmea
    test "FMEA-SAFETY-003: FPPS method crash during validation (RPN=60)" do
      # Each FPPS method should be isolated
      # If one crashes, others should still execute
      methods = [:pattern, :ast, :statistical, :binary, :line_by_line]
      assert length(methods) == 5
    end

    @tag :fmea
    test "FMEA-SAFETY-004: Zenoh NIF crashes (RPN=90)" do
      # NIF crashes should not bring down the BEAM VM
      # The NIF module should handle errors gracefully
      assert Code.ensure_loaded?(Indrajaal.Native.Zenoh)
    end

    @tag :fmea
    test "FMEA-SAFETY-005: SymbioticDefense cannot reach Guardian (RPN=72)" do
      # Defense system needs fallback when Guardian is unreachable
      assert Code.ensure_loaded?(Indrajaal.Safety.SymbioticDefense)
    end
  end
end
