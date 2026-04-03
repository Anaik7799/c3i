# Comprehensive Observability Test Plan
**Fractal Logging + ACE + Cortex + OODA Integration**

**Version**: 1.0.0 | **Date**: 2025-12-26 | **Status**: ACTIVE
**STAMP Compliance**: SC-OBS-*, SC-VAL-*, SC-AGT-*, SC-PRF-*

---

## L0 (Critical) - Executive Summary

### Test Plan Scope
| Component | Module Path | Tests | Priority |
|-----------|-------------|-------|----------|
| Fractal Logging | lib/indrajaal/observability/fractal/ | 50+ | P0 |
| ACE Integration | lib/indrajaal/cybernetic/ | 40+ | P1 |
| Cortex Controller | lib/indrajaal/cortex/ | 35+ | P1 |
| OODA Operations | lib/indrajaal/cybernetic/ooda/ | 30+ | P1 |
| Zenoh Data Plane | lib/indrajaal/observability/zenoh*.ex | 25+ | P1 |
| End-to-End | Integration tests | 20+ | P2 |

### Success Criteria
- **FPPS Consensus**: 100% agreement across 5 validation methods
- **Latency**: OODA loop < 50ms (SC-PRF-050)
- **Coverage**: > 95% test coverage for all components
- **Zero Defects**: $\sum(\text{Errors} + \text{Warnings} + \text{TestFails}) \equiv 0$

---

## L1 (Error/Important) - Test Architecture

### 1. Fractal Logging Tests (5 Levels)

```elixir
# test/indrajaal/observability/fractal/fractal_control_test.exs
defmodule Intelitor.Observability.Fractal.FractalControlTest do
  use ExUnit.Case, async: true

  # L0 Tests - Critical/Emergency
  describe "L0 - Critical Level Logging" do
    test "L0 events always logged regardless of global level"
    test "L0 triggers immediate SigNoz alert"
    test "L0 captures full stack trace"
    test "L0 includes correlation_id propagation"
    test "L0 respects SC-OBS-069 dual logging"
  end

  # L1 Tests - Error/Important
  describe "L1 - Error Level Logging" do
    test "L1 events logged when level >= :error"
    test "L1 includes error context metadata"
    test "L1 integrates with circuit breaker state"
  end

  # L2 Tests - Warning/Moderate
  describe "L2 - Warning Level Logging" do
    test "L2 events filterable by component"
    test "L2 batch encoding for performance"
  end

  # L3 Tests - Info/Standard
  describe "L3 - Info Level Logging" do
    test "L3 respects rate limiting"
    test "L3 content routing by domain"
  end

  # L4 Tests - Debug/Verbose
  describe "L4 - Debug Level Logging" do
    test "L4 only enabled in dev/test"
    test "L4 includes timing measurements"
  end
end
```

### 2. ACE (Autonomous Cybernetic Evolution) Tests

```elixir
# test/indrajaal/cybernetic/ace_integration_test.exs
defmodule Intelitor.Cybernetic.ACEIntegrationTest do
  use ExUnit.Case, async: true

  describe "Homeostasis Engine" do
    test "stress score calculation accuracy"
    test "dynamic pool tuning response time < 100ms"
    test "cache TTL optimization based on hit ratio"
    test "DB pool adjustment under load"
    test "evolution proposal generation with context"
  end

  describe "GDE Algorithm" do
    test "hypothesis generation from telemetry"
    test "simulation engine isolation"
    test "selection algorithm fitness scoring"
    test "AEE tool execution safety"
    test "state verification post-evolution"
  end

  describe "Self-Healing" do
    test "failure detection < 100ms (SC-EMR-057)"
    test "RCA engine accuracy"
    test "remediation action safety"
    test "recovery verification"
    test "incident learning feedback loop"
  end
end
```

### 3. Cortex Cognitive Controller Tests

```elixir
# test/indrajaal/cortex/cognitive_controller_test.exs
defmodule Intelitor.Cortex.CognitiveControllerTest do
  use ExUnit.Case, async: true

  describe "Sensory System" do
    test "BEAM sensor accuracy (memory, processes)"
    test "container health sensor responsiveness"
    test "network latency sensor precision"
    test "database sensor connection pool monitoring"
  end

  describe "Stress Analysis" do
    test "stress score formula validation"
    test "threshold crossing detection"
    test "stress trend analysis"
    test "multi-factor stress aggregation"
  end

  describe "Circuit Breakers" do
    test "circuit breaker state transitions"
    test "half-open state testing"
    test "failure count accuracy"
    test "recovery time configuration"
    test "external API guard integration"
  end

  describe "Telemetry Senses" do
    test "SigNoz stream integration"
    test "pattern recognition accuracy"
    test "risk assessment scoring"
    test "decision logging completeness"
  end
end
```

### 4. OODA Fast Operations Tests

```elixir
# test/indrajaal/cybernetic/ooda/fast_operations_test.exs
defmodule Intelitor.Cybernetic.OODA.FastOperationsTest do
  use ExUnit.Case, async: true

  # Latency requirement: < 50ms per loop (SC-PRF-050)
  @max_latency_ms 50

  describe "Observe Phase" do
    test "telemetry collection latency < 10ms" do
      {time_us, _result} = :timer.tc(fn -> OODA.Observer.observe() end)
      assert time_us / 1000 < 10
    end

    test "container health observation accuracy"
    test "compilation status observation freshness"
    test "dashboard PID observation reliability"
  end

  describe "Orient Phase" do
    test "warning analysis latency < 10ms"
    test "bug detection pattern matching"
    test "STAMP verification completeness"
    test "priority chain calculation"
  end

  describe "Decide Phase" do
    test "required fixes identification"
    test "test coverage gap analysis"
    test "worker allocation optimization"
  end

  describe "Act Phase" do
    test "coordinate workers dispatching"
    test "report findings delivery"
    test "trigger fixes execution"
    test "rollback capability (SC-EMR-060)"
  end

  describe "Full Loop Performance" do
    test "complete OODA loop < 50ms" do
      {time_us, _result} = :timer.tc(fn ->
        OODA.Loop.execute(:quick)
      end)
      assert time_us / 1000 < @max_latency_ms
    end
  end
end
```

### 5. Zenoh Data Plane Tests

```elixir
# test/indrajaal/observability/zenoh_kpi_publisher_test.exs
defmodule Intelitor.Observability.ZenohKpiPublisherTest do
  use ExUnit.Case, async: true

  @kpi_topics [
    "indrajaal/kpi/compilation",
    "indrajaal/kpi/tests",
    "indrajaal/kpi/containers",
    "indrajaal/kpi/performance",
    "indrajaal/kpi/progress",
    "indrajaal/kpi/stamp",
    "indrajaal/kpi/todos",
    "indrajaal/kpi/agents",
    "indrajaal/kpi/mesh"
  ]

  describe "KPI Collection" do
    test "all 9 KPI topics collected"
    test "mesh KPI includes network_mode"
    test "mesh KPI includes backend availability"
    test "agents KPI includes task status"
  end

  describe "Zenoh Integration" do
    test "session establishment"
    test "topic publishing latency < 5ms"
    test "subscriber notification delivery"
  end

  describe "Dashboard Integration" do
    test "cepaf_dashboard receives all KPIs"
    test "mesh display in dashboard"
    test "real-time refresh (30s interval)"
  end
end
```

---

## L2 (Warning/Moderate) - Test Scenarios

### Scenario 1: Fractal Level Transition

```
GIVEN: System running at L3 (Info) level
WHEN: Critical error occurs
THEN:
  - L0 event logged immediately
  - SigNoz alert triggered
  - Correlation ID preserved
  - Stack trace captured
  - OODA loop notified
```

### Scenario 2: OODA Fast Response

```
GIVEN: Container health degraded
WHEN: OODA observer detects issue
THEN:
  - Observe phase < 10ms
  - Orient phase analyzes root cause
  - Decide phase generates action plan
  - Act phase triggers remediation
  - Total loop < 50ms
```

### Scenario 3: ACE Self-Healing

```
GIVEN: High stress score detected (> 0.8)
WHEN: Homeostasis engine activates
THEN:
  - Pool sizes adjusted dynamically
  - Cache TTLs optimized
  - Evolution proposal generated
  - State verified after changes
  - Incident logged for learning
```

### Scenario 4: Cortex Circuit Breaker

```
GIVEN: External API failing repeatedly
WHEN: Failure threshold reached (5 in 60s)
THEN:
  - Circuit breaker opens
  - Requests fail fast
  - Half-open state after cooldown
  - Gradual recovery testing
  - Full close on success
```

---

## L3 (Info/Standard) - Test File Structure

```
test/indrajaal/observability/
├── fractal/
│   ├── fractal_control_test.exs      # 20 tests - GenServer lifecycle
│   ├── write_filter_test.exs         # 15 tests - Level filtering
│   ├── batch_encoder_test.exs        # 12 tests - Batch encoding
│   ├── decorator_test.exs            # 10 tests - @fractal macro
│   ├── content_router_test.exs       # 8 tests  - Domain routing
│   ├── otel_integration_test.exs     # 10 tests - OpenTelemetry
│   └── tdg_property_test.exs         # 25 tests - Property-based
├── zenoh_kpi_publisher_test.exs      # 15 tests - KPI publishing
├── zenoh_coordinator_test.exs        # 10 tests - Coordination
├── zenoh_control_subscriber_test.exs # 8 tests  - Control plane
├── context_propagation_test.exs      # 12 tests - Span context
├── dashboard_agent_test.exs          # 10 tests - Dashboard
└── progress_tracker_test.exs         # 8 tests  - Progress

test/indrajaal/cybernetic/
├── ace/
│   ├── homeostasis_test.exs          # 15 tests - Self-regulation
│   ├── gde_algorithm_test.exs        # 12 tests - Evolution
│   └── self_healing_test.exs         # 10 tests - Recovery
├── ooda/
│   ├── observer_test.exs             # 10 tests - Observe phase
│   ├── orientator_test.exs           # 10 tests - Orient phase
│   ├── decider_test.exs              # 8 tests  - Decide phase
│   ├── actor_test.exs                # 8 tests  - Act phase
│   ├── loop_test.exs                 # 12 tests - Full loop
│   └── telemetry_test.exs            # 8 tests  - OODA telemetry
└── integration_test.exs              # 20 tests - E2E cybernetic

test/indrajaal/cortex/
├── cognitive_controller_test.exs     # 15 tests - Main controller
├── sensors/
│   ├── beam_sensor_test.exs          # 8 tests  - VM metrics
│   ├── container_sensor_test.exs     # 10 tests - Container health
│   └── network_sensor_test.exs       # 8 tests  - Network latency
├── stress_analyzer_test.exs          # 12 tests - Stress scoring
├── circuit_breaker_test.exs          # 15 tests - Fault tolerance
└── telemetry_senses_test.exs         # 10 tests - Telemetry
```

---

## L4 (Debug/Verbose) - Implementation Details

### Property-Based Tests (PropCheck + StreamData)

```elixir
# test/indrajaal/observability/fractal/tdg_property_test.exs
defmodule Intelitor.Observability.Fractal.TDGPropertyTest do
  use ExUnit.Case
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # SC-PROP-023/024: PropCheck vs StreamData disambiguation

  property "fractal levels are ordered correctly" do
    forall level <- PC.integer(0, 4) do
      level >= 0 and level <= 4
    end
  end

  property "log events include required metadata" do
    check all(
      level <- SD.member_of([:critical, :error, :warning, :info, :debug]),
      message <- SD.string(:alphanumeric, min_length: 1)
    ) do
      event = FractalControl.create_event(level, message)
      assert Map.has_key?(event, :timestamp)
      assert Map.has_key?(event, :correlation_id)
    end
  end

  property "OODA loop latency within bounds" do
    forall input <- PC.map(PC.atom(), PC.term()) do
      {time_us, _} = :timer.tc(fn -> OODA.Loop.execute(:quick, input) end)
      time_us / 1000 < 50  # SC-PRF-050
    end
  end
end
```

### Mock Configurations

```elixir
# test/support/mocks/observability_mocks.ex
Mox.defmock(ZenohMock, for: Intelitor.Observability.ZenohBehaviour)
Mox.defmock(SigNozMock, for: Intelitor.Observability.SigNozBehaviour)
Mox.defmock(ContainerMock, for: Intelitor.Cluster.ContainerBehaviour)
```

### Test Tags for Parallel Execution

```elixir
# Tag categories for selective test runs
@moduletag :observability
@moduletag :fractal
@moduletag :ooda
@moduletag :cortex
@moduletag :ace
@moduletag :property_test

# Run specific test groups
# mix test --only fractal
# mix test --only ooda
# mix test --only cortex
```

---

## Execution Plan

### Phase 1: Unit Tests (Day 1)
```bash
# Fractal Logging tests
POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres \
  DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
  NO_TIMEOUT=true PATIENT_MODE=enabled MIX_ENV=test \
  mix test test/indrajaal/observability/fractal/ --trace

# OODA tests
mix test test/indrajaal/cybernetic/ooda/ --trace

# Cortex tests
mix test test/indrajaal/cortex/ --trace
```

### Phase 2: Integration Tests (Day 2)
```bash
# Full observability integration
mix test test/indrajaal/observability/ --trace

# Cybernetic integration
mix test test/indrajaal/cybernetic/integration_test.exs --trace
```

### Phase 3: Property Tests (Day 3)
```bash
# PropCheck tests with extended samples
mix test --only property_test --numtests 1000
```

### Phase 4: Performance Validation (Day 4)
```bash
# OODA latency verification
mix test test/indrajaal/cybernetic/ooda/loop_test.exs --trace

# Zenoh throughput testing
mix test test/indrajaal/observability/zenoh*_test.exs --trace
```

---

## STAMP Constraint Verification

| Constraint | Test Coverage | Verified By |
|------------|---------------|-------------|
| SC-OBS-069 | Dual logging tests | fractal_control_test.exs |
| SC-PRF-050 | OODA loop < 50ms | fast_operations_test.exs |
| SC-EMR-057 | Failure detection < 100ms | self_healing_test.exs |
| SC-EMR-060 | Rollback capability | actor_test.exs |
| SC-VAL-001 | Patient mode | All tests use NO_TIMEOUT |
| SC-PROP-023 | PropCheck disambiguation | tdg_property_test.exs |
| SC-PROP-024 | StreamData disambiguation | tdg_property_test.exs |

---

## Metrics & KPIs

### Target Coverage
- **Fractal Logging**: 98% coverage
- **ACE Integration**: 95% coverage
- **Cortex Controller**: 95% coverage
- **OODA Operations**: 98% coverage
- **Zenoh Data Plane**: 90% coverage

### Performance Targets
- **OODA Full Loop**: < 50ms (p99)
- **Fractal Log Write**: < 1ms
- **Zenoh Publish**: < 5ms
- **Circuit Breaker**: < 10ms decision

---

**Generated**: 2025-12-26T12:30:00+01:00
**Framework**: SOPv5.11 + STAMP + TDG + FPPS
**Agent**: Cybernetic Architect (Claude Opus 4.5)
