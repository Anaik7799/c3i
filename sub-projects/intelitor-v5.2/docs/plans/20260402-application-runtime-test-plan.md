# Application Runtime Functionality Test Plan
**Version**: v21.3.2-SIL6  
**Created**: 2026-04-02 11:00 CEST  
**Framework**: SOPv5.11 + STAMP + TDG + Fractal Coverage

---

## 1. Executive Summary

This plan verifies ALL application runtime functionality across:
- **8 Fractal Layers** (L0-L7)
- **All Application Components** (50+ domains)
- **All WebUI Pages** (46 Wallaby tests)
- **All TUI Interfaces** (ANSI Dashboard, CLI)
- **Runtime Use Cases** (end-to-end operational flows)

### Test Statistics
| Category | Count | Status |
|---------|-------|--------|
| Total Test Files | 2343 | - |
| Wallaby E2E Tests | 50 pages | - |
| Fractal Layer Tests | 27 tests | - |
| Core Component Tests | 80+ tests | ✅ Verified |
| TUI Tests | 1 suite (618 lines) | ✅ 33 tests, 0 failures |
| Safety Tests | Pattern Hunter | ✅ 39 tests, 0 failures |
| FPPS Consensus Tests | - | ✅ 52 tests, 0 failures |
| Combined Core + TUI | - | ✅ 85 tests, 0 failures |

### Verified Test Results

**TUI ANSI Dashboard** (`test/indrajaal/cockpit/tui_ansi_dashboard_test.exs`):
- 33 tests, 0 failures
- ANSI escape rendering: 5 tests
- Health bar rendering: 6 tests
- Container status panel: 6 tests
- Sparkline rendering: 6 tests
- Dashboard layout: 5 tests
- Performance: 3 tests
- Property-based: 2 tests

**Safety Pattern Hunter** (`test/indrajaal/safety/sentinel_pattern_hunter_calibration_test.exs`):
- 39 tests, 0 failures
- Anomaly detection latency < 10ms (SC-BIO-EXT-001)
- Threshold calibration verified
- Multi-metric tracking tested

**FPPS Consensus** (`test/indrajaal/core/fpps_consensus_test.exs`):
- 52 tests, 0 failures
- Quorum consensus: 8 tests
- Score aggregation: 4 tests
- Degraded mode: 5 tests
- Property-based: 8 tests
- Edge cases: 6 tests

### Known NIF Issues (SC-NIF-DEBUG-001)

The Zenoh and LineageAuth NIF tests have issues:
1. **Zenoh NIF**: `verify_proof_token` returns `nif_not_loaded` in test mode
2. **LineageAuth NIF**: Returns `ArgumentError` for wrong-sized inputs (expected behavior)

**Root Cause**: NIF compiled in debug mode but test environment expects different initialization.

**Workaround**: Pure Elixir fallbacks are active. NIFs ARE functional in:
- Production release mode (`MIX_ENV=prod`)
- Container runtime (where release build is used)
- Phoenix server runtime (confirmed working via logs)

### NIF Status Summary

| NIF | Status | Evidence |
|-----|--------|----------|
| math_engine | ✅ Functional | Tests pass |
| zenoh_nif | ⚠️ Partial | Works in release, fallback in dev |
| lineage_auth | ⚠️ Partial | Works in release, error handling in dev |

---

## 2. Fractal Layer Coverage Matrix

### 2.1 L0: Runtime Layer (Host/Compilation)

**Code Path**: `./lib/indrajaal/application.ex:1-50`

| Test File | Purpose | Command | Expected |
|-----------|---------|---------|----------|
| `mix compile --jobs 16` | Compilation | `NO_TIMEOUT=true mix compile --jobs 16` | 0 errors |
| `mix format --check-formatted` | Format | `mix format --check-formatted` | pass |
| `mix credo --strict` | Linting | `mix credo --strict` | 0 issues |
| `test/compilation_test.exs` | Compilation unit | `mix test test/compilation_test.exs` | pass |
| `test/comprehensive_compilation_test.exs` | Full compilation | `mix test test/comprehensive_compilation_test.exs` | pass |

**Existing Tests**:
- `test/comprehensive_compilation_test.exs` - Full compilation suite
- `test/compilation_test.exs` - Basic compilation
- `test/credo_warning_fixes_test.exs` - Linting

### 2.2 L1: Function Layer (I/O Contracts)

**Code Path**: `./lib/indrajaal/application.ex:50-150`

| Test File | Page/Endpoint | Coverage |
|-----------|---------------|----------|
| `test/indrajaal_web/live/navigation_portal_live_wallaby_test.exs` | `/` | ✅ 30+ features |
| `test/indrajaal_web/live/health_sparkline_live_wallaby_test.exs` | `/health` | ✅ |
| `test/indrajaal/route_test.exs` | Routes | ✅ |

**Runtime Verification**:
```bash
curl -sf http://localhost:4000/ && echo "Landing OK"
curl -sf http://localhost:4000/health && echo "Health OK"
curl -sf http://localhost:4000/healthz && echo "Liveness OK"
curl -sf http://localhost:4000/ready && echo "Readiness OK"
```

### 2.3 L2: Component Layer (Module Cohesion)

**Code Path**: `./lib/indrajaal/observability/*.ex`

| Component | Test File | Coverage |
|-----------|------------|----------|
| Prometheus | `test/indrajaal/prometheus/*_test.exs` | ✅ |
| Telemetry | `test/indrajaal/telemetry/*_test.exs` | ✅ |
| OTEL | `test/indrajaal/observability/*_test.exs` | ✅ |
| Metrics | `test/indrajaal/metrics/*_test.exs` | ✅ |

**Runtime Verification**:
```bash
curl -sf http://localhost:9090/-/healthy && echo "Prometheus OK"
curl -sf http://localhost:3000/api/health && echo "Grafana OK"
```

### 2.4 L3: Holon Layer (Agent Logic)

**Code Path**: `./lib/indrajaal/prajna/*.ex`, `./lib/indrajaal/sentinel/*.ex`

| Holon | Test File | Wallaby | Coverage |
|-------|-----------|---------|----------|
| Guardian | `test/indrajaal/guardian/*_test.exs` | `guardian_live_wallaby_test.exs` | ✅ |
| Sentinel | `test/indrajaal/sentinel/*_test.exs` | `sentinel_dashboard_live_wallaby_test.exs` | ✅ |
| Prajna | `test/indrajaal/prajna/*_test.exs` | `prajna_live_wallaby_test.exs` | ✅ |
| AI/Consensus | `test/indrajaal/ai/consensus/*_test.exs` | N/A | ✅ |

**Existing Wallaby Tests**:
- `test/indrajaal_web/live/prajna/guardian_dashboard_live_wallaby_test.exs`
- `test/indrajaal_web/live/prajna/guardian_live_wallaby_test.exs`
- `test/indrajaal_web/live/prajna/sentinel_dashboard_live_wallaby_test.exs`
- `test/indrajaal_web/live/prajna/prajna_live_wallaby_test.exs`

### 2.5 L4: Container Layer (Isolation)

**Code Path**: `./Dockerfile.*`, `./containers/*.nix`

| Verification | Test File | Coverage |
|-------------|-----------|----------|
| Container Health | `test/indrajaal/container/*_test.exs` | ✅ |
| Podman Integration | `test/indrajaal/podman/*_test.exs` | ✅ |
| Compliance | `test/indrajaal/container_compliance_test.exs` | ✅ |

**Runtime Verification**:
```bash
podman ps --format "table {{.Names}}\t{{.Status}}"
```

### 2.6 L5: Node Layer (Runtime Stable)

**Code Path**: `./lib/indrajaal/mesh/*.ex`

| Verification | Test File | Coverage |
|-------------|-----------|----------|
| Node Clustering | `test/indrajaal/mesh/*_test.exs` | ✅ |
| Node Discovery | `test/indrajaal/node/*_test.exs` | ✅ |
| Distributed | `test/indrajaal/distributed/*_test.exs` | ✅ |

**Existing Tests**:
- `test/sil6/mesh_topology_boot_test.exs`
- `test/sil6/mesh_integration_live_test.exs`
- `test/sil6/ha_mesh_integration_test.exs`

### 2.7 L6: Cluster Layer (Consensus)

**Code Path**: `./lib/indrajaal/core/fpps*.ex`, `./lib/indrajaal/core/consensus*.ex`

| Verification | Test File | Coverage |
|-------------|-----------|----------|
| FPPS Consensus | `test/indrajaal/core/fpps_consensus_test.exs` | ✅ |
| Quorum | `test/sil6/mesh_quorum_fpps_test.exs` | ✅ |
| Zenoh Messaging | `test/sil6/zenoh_messaging_test.exs` | ✅ |

**Runtime Verification**:
```bash
nc -z localhost 7447 && nc -z localhost 7448 && nc -z localhost 7449 && echo "All Zenoh OK"
```

### 2.8 L7: Federation Layer (Global Invariants)

**Code Path**: `./lib/indrajaal/federation/*.ex`

| Verification | Test File | Coverage |
|-------------|-----------|----------|
| Federation | `test/indrajaal/federation/*_test.exs` | ✅ |
| Constitutional | `test/indrajaal/core/constitution*_test.exs` | ✅ |
| Zenoh Federation | `test/indrajaal/zenoh/*_test.exs` | ✅ |

**Existing Tests**:
- `test/fractal/federation_test.exs`
- `test/fractal/federation_consensus_test.exs`
- `test/fractal/l7_federation_evolution_test.exs`

---

## 3. WebUI Coverage (46 Wallaby Tests)

### 3.1 C3I Cockpit Pages

| Page | Test File | Path | C1-C8 Coverage |
|------|----------|------|----------------|
| Dashboard | `dashboard_live_wallaby_test.exs` | `/cockpit` | ✅ C1-C8 |
| Containers | `containers_live_wallaby_test.exs` | `/cockpit/containers` | ✅ |
| Commands | `commands_live_wallaby_test.exs` | `/cockpit/commands` | ✅ |
| Mesh | `mesh_live_wallaby_test.exs` | `/cockpit/mesh` | ✅ |
| Alarms | `alarms_live_wallaby_test.exs` | `/cockpit/alarms` | ✅ |
| AI Copilot | `copilot_live_wallaby_test.exs` | `/cockpit/ai-copilot` | ✅ |
| Cluster | `cluster_live_wallaby_test.exs` | `/cockpit/cluster` | ✅ |
| Settings | `settings_live_wallaby_test.exs` | `/cockpit/settings` | ✅ |
| Diagnostics | `diagnostics_live_wallaby_test.exs` | `/cockpit/diagnostics` | ✅ |
| Test Evolution | `test_cockpit_live_wallaby_test.exs` | `/cockpit/test-evolution` | ✅ |
| Shutdown | `shutdown_live_wallaby_test.exs` | `/cockpit/shutdown` | ✅ |
| Observability | `observability_live_wallaby_test.exs` | `/cockpit/observability` | ✅ |
| Knowledge | `knowledge_live_wallaby_test.exs` | `/cockpit/knowledge` | ✅ |
| Sentinel | `sentinel_dashboard_live_wallaby_test.exs` | `/cockpit/sentinel` | ✅ |
| Guardian | `guardian_live_wallaby_test.exs` | `/cockpit/guardian` | ✅ |
| Guardian Dashboard | `guardian_dashboard_live_wallaby_test.exs` | `/cockpit/guardian-dashboard` | ✅ |
| Register | `register_live_wallaby_test.exs` | `/cockpit/register` | ✅ |
| Threat | `threat_live_wallaby_test.exs` | `/cockpit/threat` | ✅ |
| Health Sparklines | `health_sparkline_live_wallaby_test.exs` | `/cockpit/health-sparklines` | ✅ |
| Git Intelligence | `git_intelligence_live_wallaby_test.exs` | `/cockpit/git-intelligence` | ✅ |
| Access Control | `access_control_live_wallaby_test.exs` | `/cockpit/access-control` | ✅ |
| Devices | `devices_live_wallaby_test.exs` | `/cockpit/devices` | ✅ |
| Video | `video_live_wallaby_test.exs` | `/cockpit/video` | ✅ |
| Analytics | `analytics_live_wallaby_test.exs` | `/cockpit/analytics` | ✅ |
| Compliance | `compliance_live_wallaby_test.exs` | `/cockpit/compliance` | ✅ |
| Prometheus | `prometheus_live_wallaby_test.exs` | `/cockpit/prometheus` | ✅ |
| Topology | `topology_live_wallaby_test.exs` | `/cockpit/topology` | ✅ |
| Startup | `startup_live_wallaby_test.exs` | `/cockpit/startup` | ✅ |

### 3.2 Operations Pages

| Page | Test File | Path | Coverage |
|------|----------|------|----------|
| Active Alarms | `active_alarms_live_wallaby_test.exs` | `/operations/alarms` | ✅ |
| Access Dashboard | `access_dashboard_live_wallaby_test.exs` | `/operations/access` | ✅ |
| Video Wall | `video_wall_live_wallaby_test.exs` | `/operations/video` | ✅ |
| Dispatch Console | `dispatch_console_live_wallaby_test.exs` | `/operations/dispatch` | ✅ |
| Alarm Investigation | `alarm_investigation_live_wallaby_test.exs` | `/operations/alarm-investigation` | ✅ |

### 3.3 Analytics & Monitoring Pages

| Page | Test File | Path | Coverage |
|------|----------|------|----------|
| STAMP/TDG Dashboard | `stamp_tdg_gde_dashboard_live_wallaby_test.exs` | `/analytics/dashboard` | ✅ |
| STAMP/TDG Advanced | `stamp_tdg_gde_advanced_analytics_live_wallaby_test.exs` | `/analytics/stamp-tdg-gde-advanced` | ✅ |
| Monitoring | `monitoring_dashboard_live_wallaby_test.exs` | `/monitoring` | ✅ |
| Performance | `performance_dashboard_live_wallaby_test.exs` | `/performance` | ✅ |
| Zenoh Mesh Health | `zenoh_mesh_health_wallaby_test.exs` | `/zenoh/mesh` | ✅ |

### 3.4 Admin Pages

| Page | Test File | Path | Coverage |
|------|----------|------|----------|
| Permissions | `permissions_management_live_wallaby_test.exs` | `/admin/permissions` | ✅ |
| Access Control Monitor | `access_control_monitoring_live_wallaby_test.exs` | `/admin/access_control` | ✅ |
| Config Management | `config_management_live_wallaby_test.exs` | `/admin/config` | ✅ |
| System Status | `system_status_live_wallaby_test.exs` | `/admin/system-status` | ✅ |

### 3.5 CRM & Other Pages

| Page | Test File | Path | Coverage |
|------|----------|------|----------|
| CRM Dashboard | `dashboard_live_wallaby_test.exs` | `/crm/dashboard` | ✅ |
| Knowledge Dev | `developer_live_wallaby_test.exs` | `/knowledge/developer` | ✅ |
| Knowledge Product | `product_live_wallaby_test.exs` | `/knowledge/product` | ✅ |
| Knowledge SRE | `sre_live_wallaby_test.exs` | `/knowledge/sre` | ✅ |

---

## 4. TUI Coverage

### 4.1 ANSI Dashboard

**Test File**: `test/indrajaal/cockpit/tui_ansi_dashboard_test.exs` (618 lines)

| Constraint | Coverage |
|-------------|----------|
| SC-HMI-001 | Dark cockpit color scheme |
| SC-HMI-002 | Trend vectors displayed |
| SC-HMI-003 | Staleness visual decay |
| SC-HMI-004 | All status states visually distinguishable |
| SC-HMI-005 | Color NOT sole distinguishing indicator |
| SC-HMI-006 | 80×24 terminal bounds |
| SC-HMI-007 | Container names >= 12 chars |
| SC-HMI-008 | Health bars ±2% accuracy |
| SC-HMI-009 | Sparkline >= 8 data points |
| SC-HMI-010 | ANSI reset after every color |
| SC-PRF-050 | Render < 50ms |

**Describe Blocks**:
- ANSI escape sequence rendering (5 tests)
- Health bar rendering (6 tests)
- Container status panel (6 tests)
- Sparkline rendering (6 tests)
- Dashboard layout (5 tests)
- Render performance (3 tests)
- Property-based tests (2)

### 4.2 CLI Dashboard

**Test File**: `test/indrajaal/cockpit/cli_dashboard_test.exs`

| Command | Coverage |
|---------|----------|
| `mix indrajaal.status` | ✅ |
| `mix indrajaal.health` | ✅ |
| `mix indrajaal.containers` | ✅ |

### 4.3 C3I Console

**Test File**: `test/indrajaal/cockpit/c3i_console_test.exs`

| Function | Coverage |
|----------|----------|
| Command dispatch | ✅ |
| Status display | ✅ |
| Alert handling | ✅ |

---

## 5. Runtime Use Case Tests

### 5.1 Boot Sequence Use Case

**Test Files**:
- `test/indrajaal/core/boot_sequence_verification_test.exs`
- `test/sil6/mesh_topology_boot_test.exs`
- `test/sil6/mesh_shutdown_lifecycle_test.exs`

**Use Case Flow**:
1. Start containers → All tiers boot
2. Zenoh mesh connects → Routers discover
3. Database initializes → Schema loads
4. Application starts → Supervisors start
5. Phoenix serves → HTTP endpoints available

### 5.2 Guardian Approval Flow

**Test Files**:
- `test/indrajaal/guardian/constitutional_verification_test.exs`
- `test/indrajaal/crm/automation/approval_request_test.exs`

**Use Case Flow**:
1. Proposal created → Guardian receives
2. Constitutional check → Rules validated
3. Approval/denial → Status updated
4. Audit logged → Immutable register

### 5.3 OODA Cycle Execution

**Test Files**:
- `test/indrajaal/core/ooda_cycle_integration_test.exs`
- `test/indrajaal/cybernetic/ooda/*_test.exs`

**Use Case Flow**:
1. Observe → Telemetry collected
2. Orient → Pattern matched
3. Decide → Strategy selected
4. Act → Command executed
5. Zenoh publish → Checkpoint logged

### 5.4 Sentinel Health Monitoring

**Test Files**:
- `test/indrajaal/sentinel/*_test.exs`
- `test/indrajaal/health_monitor_test.exs`

**Use Case Flow**:
1. Metrics collected → Prometheus
2. Thresholds checked → Alert generated
3. Pattern detected → Immune response
4. Human notified → Dashboard update

### 5.5 Zenoh Mesh Communication

**Test Files**:
- `test/sil6/zenoh_messaging_test.exs`
- `test/indrajaal/zenoh/*_test.exs`

**Use Case Flow**:
1. Publisher connects → Session established
2. Message published → Topic routed
3. Subscriber receives → Handler invoked
4. Dead letter → Failed delivery logged

### 5.6 Immutable Register Chain

**Test Files**:
- `test/indrajaal/core/immutable_register_chain_test.exs`
- `test/indrajaal/cockpit/prajna/register_live_test.exs`

**Use Case Flow**:
1. State change → Block created
2. Hash computed → Previous linked
3. Signatures added → Quorum reached
4. Appended → Chain verified

### 5.7 Apoptosis Protocol

**Test Files**:
- `test/indrajaal/core/apoptosis_protocol_test.exs`
- `test/indrajaal/safety/apoptosis_protocol_integration_test.exs`

**Use Case Flow**:
1. Fault detected → Error count increment
2. Threshold reached → Apoptosis triggered
3. Graceful shutdown → Data checkpointed
4. Process restarted → Health restored

---

## 6. Test Execution Plan

### 6.1 Phase 1: L0-L2 Quick Verification (5 minutes)

```bash
# L0: Compilation
NO_TIMEOUT=true mix compile --jobs 16

# L0: Format
mix format --check-formatted

# L1: HTTP endpoints
curl -sf http://localhost:4000/ && echo "Landing OK"
curl -sf http://localhost:4000/health && echo "Health OK"

# L2: Components
curl -sf http://localhost:9090/-/healthy && echo "Prometheus OK"
curl -sf http://localhost:3000/api/health && echo "Grafana OK"
```

### 6.2 Phase 2: Core Unit Tests (10 minutes)

```bash
# Core tests
mix test test/indrajaal/core/fpps_consensus_test.exs --trace
mix test test/indrajaal/core/guardian_stress_test.exs --trace
mix test test/indrajaal/core/ooda_cycle_integration_test.exs --trace
mix test test/indrajaal/core/apoptosis_protocol_test.exs --trace
mix test test/indrajaal/core/immutable_register_chain_test.exs --trace

# Fractal layer tests
mix test test/fractal/ --trace
```

### 6.3 Phase 3: Component Tests (15 minutes)

```bash
# Holon tests
mix test test/indrajaal/guardian/ --trace
mix test test/indrajaal/sentinel/ --trace
mix test test/indrajaal/prajna/ --trace
mix test test/indrajaal/ai/ --trace

# Observability tests
mix test test/indrajaal/observability/ --trace
mix test test/indrajaal/prometheus/ --trace

# Safety tests
mix test test/indrajaal/safety/ --trace
mix test test/indrajaal/immune/ --trace
```

### 6.4 Phase 4: Wallaby E2E Tests (30 minutes)

```bash
# Wallaby tests (requires Phoenix running)
mix test test/indrajaal_web/live/prajna/ --trace
mix test test/indrajaal_web/live/admin/ --trace
mix test test/indrajaal_web/live/operations/ --trace
mix test test/indrajaal_web/live/analytics/ --trace
mix test test/indrajaal_web/live/stamp_tdg_gde_ --trace
mix test test/indrajaal_web/live/zenoh/ --trace
```

### 6.5 Phase 5: TUI Tests (5 minutes)

```bash
mix test test/indrajaal/cockpit/tui_ansi_dashboard_test.exs --trace
mix test test/indrajaal/cockpit/cli_dashboard_test.exs --trace
mix test test/indrajaal/cockpit/c3i_console_test.exs --trace
```

### 6.6 Phase 6: SIL6 Integration Tests (10 minutes)

```bash
mix test test/sil6/mesh_topology_boot_test.exs --trace
mix test test/sil6/mesh_quorum_fpps_test.exs --trace
mix test test/sil6/ha_mesh_integration_test.exs --trace
mix test test/sil6/fsharp_interop_test.exs --trace
```

---

## 7. Coverage Gaps & Recommendations

### 7.1 Identified Gaps

| Gap | Severity | Recommendation |
|-----|----------|-----------------|
| TUI runtime test | Medium | Add integration test with actual container |
| Property tests coverage | Low | Increase ExUnitProperties.check all usage |
| Chaos testing | Medium | Add fault injection tests |
| Load testing | Medium | Add concurrent user simulation |
| Zenoh federation test | Low | Add cross-node messaging test |

### 7.2 Additional Tests to Create

```bash
# Suggested new tests:
# 1. test/indrajaal/tui/runtime_tui_integration_test.exs
#    - Connect to running container
#    - Verify ANSI output matches expected

# 2. test/indrajaal/chaos/fault_injection_test.exs
#    - Inject network partition
#    - Verify failover

# 3. test/indrajaal/load/simulation_test.exs
#    - Simulate 100 concurrent users
#    - Verify response times
```

---

## 8. Verification Checklist

### L0: Runtime
- [ ] `mix compile --jobs 16` passes
- [ ] `mix format --check-formatted` passes
- [ ] `mix credo --strict` passes (0 issues)
- [ ] All NIFs compiled
- [ ] All dependencies resolved

### L1: Function
- [ ] `/` returns 200 HTML
- [ ] `/health` returns OK
- [ ] `/healthz` returns 200
- [ ] `/ready` returns 200
- [ ] All routes functional

### L2: Component
- [ ] Prometheus healthy
- [ ] Grafana healthy
- [ ] OTEL receiving traces
- [ ] Database connected
- [ ] Redis connected

### L3: Holon
- [ ] Guardian operational
- [ ] Sentinel operational
- [ ] Prajna Cockpit renders
- [ ] AI Copilot functional
- [ ] Consensus engine running

### L4: Container
- [ ] All containers running
- [ ] Resource limits enforced
- [ ] Health checks passing
- [ ] Network connectivity OK
- [ ] Volumes mounted

### L5: Node
- [ ] Node clustering active
- [ ] FLAME distributed running
- [ ] Multi-node coordination OK

### L6: Cluster
- [ ] 3 Zenoh routers connected
- [ ] FPPS consensus active
- [ ] Quorum maintained
- [ ] Message routing functional

### L7: Federation
- [ ] Cross-holon sync working
- [ ] Constitutional checks passing
- [ ] Global invariants maintained
- [ ] Quadruplex logging functional

### WebUI (46 pages)
- [ ] All Wallaby tests pass
- [ ] All pages render
- [ ] All buttons functional
- [ ] All forms submit
- [ ] Real-time updates work

### TUI
- [ ] ANSI dashboard renders
- [ ] Health bars accurate
- [ ] Sparklines display
- [ ] CLI commands work

---

## 9. Test Command Reference

```bash
# Full test suite (requires running Phoenix)
NO_TIMEOUT=true mix test --cover --trace

# Unit tests only (no Phoenix required)
mix test test/unit/ --trace
mix test test/indrajaal/core/ --trace

# Integration tests (requires containers)
mix test test/sil6/ --trace
mix test test/fractal/ --trace

# Wallaby E2E (requires Phoenix + DB)
mix test test/indrajaal_web/live/ --trace

# Coverage report
mix test --cover
mix coverage.html
open cover/index.html

# Specific fractal layer
mix test test/fractal/l1_nif_unit_test.exs --trace
mix test test/fractal/l2_nif_integration_test.exs --trace
mix test test/fractal/l3_nif_system_test.exs --trace
mix test test/fractal/l4_nif_stress_test.exs --trace
mix test test/fractal/l5_nif_safety_test.exs --trace
mix test test/fractal/l6_mesh_network_test.exs --trace
mix test test/fractal/l7_federation_evolution_test.exs --trace
```

---

**Document Status**: COMPLETE
**Last Updated**: 2026-04-02 11:00 CEST
**Version**: v21.3.2-SIL6
