# C3I Remaining Implementation Plan for Lightweight Models

## Purpose
This document provides step-by-step, copy-paste-ready instructions for a lightweight LLM (e.g., Claude Haiku, GPT-4o-mini, Gemini Flash) to implement each remaining feature. Every task is self-contained with exact file paths, type definitions, function signatures, and test expectations.

## Current State
- **395 pub functions** across **96 modules**
- **479 tests**, 0 failures
- **23 API endpoints**, all HTTP 200
- Server running at `http://0.0.0.0:4100`

## Remaining Gap: 353 pure functions + 297 FFI functions = 650 total
- **Priority 1 (Pure, no FFI):** 171 functions across 4 modules
- **Priority 2 (Mixed, some FFI):** 182 functions across 4 modules  
- **Priority 3 (Heavy FFI, defer):** 297 functions across 4 modules

---

# PRIORITY 1: PURE LOGIC (No FFI Required)

## Task P1-A: Prajna Biomorphic Control (33 functions)

### File: `src/cepaf_gleam/prajna/bio.gleam`
### F# Source: `Cepaf/Prajna.fs` (Bio module)

**MSTS Header:**
```gleam
//// [C3I-SIL6-MSTS] MATHEMATICAL & SEMANTIC MODULE CONTRACT
//// <c3i-module>
////   <identity><module>cepaf_gleam/prajna/bio</module>
////     <fsharp-lineage>Cepaf.Prajna.Bio</fsharp-lineage></identity>
////   <fractal-topology><layer>L0_CONSTITUTIONAL</layer></fractal-topology>
////   <compliance><criticality>DAL-A / SIL-6</criticality>
////     <stamp-controls>SC-PRAJNA-001</stamp-controls></compliance>
//// </c3i-module>
```

**Types to define:**
```gleam
pub type Permeability { Closed Open Selective(allowed: List(String)) Emergency }
pub type HolonState { Dormant Awakening Active Stressed Healing Apoptotic }
pub type VitalSigns { VitalSigns(health_index: Float, stress_index: Float, energy: Float) }
pub type MembraneConfig { MembraneConfig(permeability: Permeability, blocked_sources: List(String)) }
pub type HolonInstance { HolonInstance(id: String, holon_type: String, state: HolonState, vitals: VitalSigns, membrane: MembraneConfig, parent_id: option.Option(String)) }
```

**Functions to implement (5):**
```gleam
pub fn create_holon(id: String, holon_type: String, parent_id: Option(String)) -> HolonInstance
/// Default: Dormant state, health=1.0, stress=0.0, energy=1.0, Open membrane
pub fn transition(holon: HolonInstance, target: HolonState) -> Result(HolonInstance, String)
/// Valid: Dormant->Awakening->Active->Stressed->Healing->Active, Active->Apoptotic
/// Invalid transitions return Error
pub fn is_healthy(holon: HolonInstance) -> Bool
/// health_index > 0.5 AND stress_index < 0.8 AND state == Active
pub fn can_pass(membrane: MembraneConfig, source: String, msg_type: String) -> Bool
/// Closed: always False; Open: True unless source in blocked_sources;
/// Selective: True if msg_type in allowed; Emergency: True only if msg_type == "emergency"
pub fn default_membrane_config() -> MembraneConfig
/// Open permeability, empty blocked_sources
```

**Tests to write** in `test/prajna_bio_test.gleam`:
- `create_holon_test`: verify default state is Dormant, health=1.0
- `transition_dormant_to_awakening_test`: should succeed
- `transition_dormant_to_active_test`: should fail (must go through Awakening)
- `is_healthy_active_test`: Active with health=0.8 -> True
- `is_healthy_dormant_test`: Dormant -> False (wrong state)
- `can_pass_closed_test`: always False
- `can_pass_open_test`: True unless blocked
- `can_pass_selective_test`: only allowed types
- `can_pass_emergency_test`: only "emergency" type

### File: `src/cepaf_gleam/prajna/immune.gleam`
### F# Source: `Cepaf.Prajna.Immune`

**Types:**
```gleam
pub type ThreatLevel { None Low Medium High Critical }
pub type ThreatType { ResourceExhaustion UnauthorizedAccess SystemCorruption AnomalousBehavior ConfigurationDrift UnknownThreat }
pub type AntibodyAction { Ignore Log Alert Isolate Escalate Terminate }
pub type Strategy { Passive Adaptive Defensive Aggressive }
pub type Threat { Threat(id: String, threat_type: ThreatType, level: ThreatLevel, source: String, timestamp: String) }
pub type AntibodyResponse { AntibodyResponse(action: AntibodyAction, confidence: Float, strategy: Strategy) }
```

**Functions (5):**
```gleam
pub fn assess_threat(vitals: bio.VitalSigns) -> ThreatLevel
/// health<0.1 or stress>0.95 -> Critical; health<0.3 or stress>0.8 -> High;
/// health<0.5 or stress>0.6 -> Medium; health<0.7 -> Low; else -> None
pub fn recommend_action(level: ThreatLevel) -> AntibodyAction
/// None->Ignore, Low->Log, Medium->Alert, High->Isolate, Critical->Escalate
pub fn mara_recommend(threats: List(Threat)) -> AntibodyResponse
/// Critical threats -> Defensive(confidence>=0.9); multiple High -> Adaptive; else Passive
pub fn create_threat(threat_type: ThreatType, level: ThreatLevel, source: String) -> Threat
pub fn respond(threat: Threat) -> AntibodyResponse
```

### File: `src/cepaf_gleam/prajna/neuro.gleam`
### F# Source: `Cepaf.Prajna.Neuro`

**Types:**
```gleam
pub type MessagePriority { Normal Urgent Emergency }
pub type RoutingDecision { Deliver Forward(next_hop: String) Broadcast Drop(reason: String) }
pub type SpineMessage { SpineMessage(id: String, source: String, destination: String, payload: String, priority: MessagePriority, ttl: Int) }
```

**Functions (4):**
```gleam
pub fn create_message(source: String, dest: String, payload: String, priority: MessagePriority) -> SpineMessage
/// Default TTL=10
pub fn route(msg: SpineMessage, local_node: String) -> RoutingDecision
/// dest == local_node -> Deliver; dest == "*" -> Broadcast; ttl <= 0 -> Drop; else -> Forward(dest)
pub fn decrement_ttl(msg: SpineMessage) -> SpineMessage
pub fn is_expired(msg: SpineMessage) -> Bool
/// ttl <= 0
```

### File: `src/cepaf_gleam/prajna/dark_cockpit.gleam`
### F# Source: `Cepaf.Prajna.DarkCockpit`

**Types:**
```gleam
pub type CockpitMode { Dark Dim Normal Bright EmergencyMode }
pub type AlertSeverity { WarningSeverity ErrorSeverity CriticalSeverity }
pub type Alert { Alert(id: String, severity: AlertSeverity, message: String, acknowledged: Bool, timestamp: String) }
pub type CockpitState { CockpitState(mode: CockpitMode, alerts: List(Alert), health_score: Float, total_systems: Int, healthy_systems: Int) }
```

**Functions (6):**
```gleam
pub fn initial_state() -> CockpitState
/// Dark mode, no alerts, health=1.0
pub fn determine_mode(state: CockpitState) -> CockpitMode
/// >90% healthy -> Dark; >70% -> Dim; >30% -> Normal; >0% -> Bright; else or critical alerts -> EmergencyMode
pub fn add_alert(state: CockpitState, alert: Alert) -> CockpitState
pub fn acknowledge_alert(state: CockpitState, alert_id: String) -> CockpitState
pub fn get_unacknowledged_by_severity(state: CockpitState, severity: AlertSeverity) -> List(Alert)
pub fn update(state: CockpitState, healthy: Int, total: Int) -> CockpitState
/// Recalculates health_score and mode
```

### File: `src/cepaf_gleam/prajna/circuit_breaker.gleam`
### F# Source: `Cepaf.Prajna.CircuitBreaker`

**Types:**
```gleam
pub type BreakerState { BreakerClosed BreakerOpen(opened_at: String) BreakerHalfOpen }
pub type Breaker { Breaker(state: BreakerState, failure_count: Int, failure_threshold: Int, reset_timeout_ms: Int, last_failure: Option(String)) }
```

**Functions (6):**
```gleam
pub fn create(threshold: Int, timeout_ms: Int) -> Breaker
pub fn record_failure(breaker: Breaker, timestamp: String) -> Breaker
/// Increments count; if >= threshold, opens circuit
pub fn record_success(breaker: Breaker) -> Breaker
/// If HalfOpen, close and reset. If Closed, just return.
pub fn should_attempt_reset(breaker: Breaker, current_time_ms: Int) -> Bool
/// True if Open AND enough time has passed
pub fn attempt_half_open(breaker: Breaker) -> Breaker
/// Transition from Open to HalfOpen
pub fn is_allowed(breaker: Breaker) -> Bool
/// Closed or HalfOpen -> True; Open -> False
```

### File: `src/cepaf_gleam/prajna/smart_metrics.gleam`
### F# Source: `Cepaf.Prajna.SmartMetrics`

**Functions (3):**
```gleam
pub fn detect_anomaly(values: List(Float), z_threshold: Float) -> Result(Bool, String)
/// <2 data points -> Error("insufficient data"); else: z-score of last value vs mean/stddev
pub fn moving_average(values: List(Float), window: Int) -> List(Float)
/// Sliding window average; handles window > data length
pub fn z_score(value: Float, mean: Float, stddev: Float) -> Float
```

### File: `src/cepaf_gleam/prajna/orchestrator.gleam`
### F# Source: `Cepaf.Prajna.Orchestrator`

**Types:**
```gleam
pub type CommandType { StatusCmd StartCmd StopCmd RestartCmd ScaleCmd(n: Int) }
pub type CommandStatus { Created Armed Executing Completed Failed(reason: String) }
pub type Command { Command(id: String, command_type: CommandType, status: CommandStatus, requires_two_key: Bool, audit: List(String)) }
```

**Functions (5):**
```gleam
pub fn requires_two_key(cmd_type: CommandType) -> Bool
/// Stop, Restart, Scale require two-key; Status, Start do not
pub fn create_command(id: String, cmd_type: CommandType) -> Command
pub fn arm(cmd: Command) -> Result(Command, String)
/// Only from Created state
pub fn confirm(cmd: Command) -> Result(Command, String)
/// If requires_two_key AND status != Armed -> Error; else -> Executing
pub fn complete(cmd: Command, success: Bool) -> Command
/// Executing -> Completed or Failed
```

**Total for P1-A: 34 functions, 7 files, 0 FFI**

---

## Task P1-B: Cybernetic Agents (18 functions)

### File: `src/cepaf_gleam/agents/cybernetic.gleam`
### F# Source: `Cepaf.CyberneticAgents`

**Types:**
```gleam
pub type AgentLevel { Executive DomainSupervisor FunctionalSupervisor Worker }
pub type AgentStatus { Idle Active(task: String) Blocked(reason: String) }
pub type Agent { Agent(id: String, name: String, level: AgentLevel, domain: String, status: AgentStatus, efficiency: Float, parent_id: Option(String)) }
pub type AgentHierarchy { AgentHierarchy(agents: Dict(String, Agent)) }
```

**Functions (18):**
```gleam
pub fn create_agent(id: String, name: String, level: AgentLevel, domain: String, parent_id: Option(String)) -> Agent
pub fn initialize_hierarchy() -> AgentHierarchy
/// Creates exactly 50 agents: 1 Executive (EXEC-001), 10 Domain Supervisors, 15 Functional Supervisors, 24 Workers
pub fn register_agent(hierarchy: AgentHierarchy, agent: Agent) -> AgentHierarchy
pub fn get_agent(hierarchy: AgentHierarchy, id: String) -> Result(Agent, String)
pub fn update_agent_status(hierarchy: AgentHierarchy, id: String, status: AgentStatus) -> Result(AgentHierarchy, String)
pub fn update_agent_efficiency(hierarchy: AgentHierarchy, id: String, efficiency: Float) -> Result(AgentHierarchy, String)
pub fn get_all_agents(hierarchy: AgentHierarchy) -> List(Agent)
pub fn get_agents_by_domain(hierarchy: AgentHierarchy, domain: String) -> List(Agent)
pub fn get_count_by_level(hierarchy: AgentHierarchy, level: AgentLevel) -> Int
pub fn check_efficiency_compliance(hierarchy: AgentHierarchy) -> Bool
/// SC-AGT-017: Average efficiency >= 90%
pub fn detect_deadlock(hierarchy: AgentHierarchy) -> Bool
/// SC-AGT-018: >50% agents Blocked
pub fn verify_executive_authority(hierarchy: AgentHierarchy) -> Bool
/// SC-AGT-019: Exactly 1 Executive
pub fn get_metrics(hierarchy: AgentHierarchy) -> Dict(String, String)
pub fn classify_agent_status(status: AgentStatus) -> String
pub fn classify_efficiency(efficiency: Float) -> String
/// >=90 "optimal", >=70 "adequate", >=50 "degraded", else "critical"
pub fn get_efficiency_status(hierarchy: AgentHierarchy) -> String
pub fn agent_to_json(agent: Agent) -> json.Json
pub fn hierarchy_to_json(hierarchy: AgentHierarchy) -> json.Json
```

**Tests:** Create 50-agent hierarchy, verify counts, test status updates, efficiency compliance, deadlock detection.

**Total for P1-B: 18 functions, 1 file, 0 FFI**

---

## Task P1-C: Holon Identity (19 functions)

### File: `src/cepaf_gleam/holon/identity.gleam`
### F# Source: `Cepaf.Holon/DatabasePath.fs`

**Types:**
```gleam
pub type Runtime { Gleam Elixir FSharp Rust }
pub type FractalLayer { L0Constitutional L1AtomicDebug L2Component L3Transaction L4System L5Cognitive L6Ecosystem L7Federation }
pub type Domain { DomainPlanning DomainKnowledge DomainSecurity DomainObservability DomainPodman DomainZenoh DomainMetabolic DomainSubstrate DomainImmune DomainCockpit DomainMcp DomainVerification DomainConfig DomainBridge DomainSmriti DomainCortex }
pub type HolonType { Agent Supervisor Worker Coordinator Guardian Oracle Sensor Effector }
pub type DatabaseType { SQLite DuckDB Postgres InMemory Zenoh }
pub type UHI { UHI(runtime: Runtime, layer: FractalLayer, domain: Domain, holon_type: HolonType, instance: String) }
pub type FQDN { FQDN(mesh_id: String, uhi: UHI) }
pub type HolonManifest { HolonManifest(uhi: UHI, databases: List(DatabaseType), capabilities: List(String)) }
```

**Functions (19):**
```gleam
pub fn create_uhi(runtime: Runtime, layer: FractalLayer, domain: Domain, holon_type: HolonType, instance: String) -> UHI
pub fn uhi_to_string(uhi: UHI) -> String
/// Format: "runtime.layer.domain.type.instance"
pub fn parse_uhi(s: String) -> Result(UHI, String)
pub fn create_fqdn(mesh_id: String, uhi: UHI) -> FQDN
pub fn fqdn_to_string(fqdn: FQDN) -> String
pub fn parse_fqdn(s: String) -> Result(FQDN, String)
pub fn resolve(fqdn: FQDN) -> String
/// Returns the Zenoh topic for this holon
pub fn zenoh_topic(uhi: UHI) -> String
/// "c3i/{runtime}/{layer}/{domain}/{type}/{instance}"
pub fn runtime_to_string(r: Runtime) -> String
pub fn layer_to_string(l: FractalLayer) -> String
pub fn domain_to_string(d: Domain) -> String
pub fn holon_type_to_string(t: HolonType) -> String
pub fn database_type_to_string(d: DatabaseType) -> String
pub fn is_gleam_holon(uhi: UHI) -> Bool
pub fn is_fsharp_holon(uhi: UHI) -> Bool
pub fn all_databases() -> List(DatabaseType)
pub fn domain_registry() -> Dict(Domain, String)
/// Maps each Domain to its description
pub fn create_manifest(uhi: UHI, databases: List(DatabaseType), capabilities: List(String)) -> HolonManifest
pub fn manifest_to_json(manifest: HolonManifest) -> json.Json
```

**Tests:** Create UHI, roundtrip to_string/parse, FQDN resolution, Zenoh topic format.

**Total for P1-C: 19 functions, 1 file, 0 FFI**

---

## Task P1-D: Config & MeshConfig (42 functions)

### File: `src/cepaf_gleam/config/mesh_config.gleam`
### F# Source: `Cepaf.Config/MeshConfig.fs`

**Types:**
```gleam
pub type ContainerSpec { ContainerSpec(name: String, image: String, port: Int, health_check: String, cpu_limit: Float, memory_mb: Int) }
pub type NetworkSpec { NetworkSpec(name: String, subnet: String, gateway: String) }
pub type VolumeSpec { VolumeSpec(name: String, host_path: String, container_path: String, read_only: Bool) }
pub type MeshConfig { MeshConfig(containers: List(ContainerSpec), networks: List(NetworkSpec), volumes: List(VolumeSpec), quorum_size: Int) }
pub type ValidationError { DuplicatePort(port: Int) InvalidSubnet(subnet: String) MissingHealthCheck(container: String) InsufficientQuorum ExcessiveResources(container: String, resource: String) }
```

**Functions (20 most important):**
```gleam
pub fn default_mesh_config() -> MeshConfig
/// 7 containers, 1 network, standard volumes, quorum=2
pub fn validate_unique_ports(config: MeshConfig) -> List(ValidationError)
pub fn validate_ip_subnet(subnet: String) -> Bool
pub fn validate_health_checks(config: MeshConfig) -> List(ValidationError)
pub fn validate_all(config: MeshConfig) -> List(ValidationError)
pub fn is_valid(config: MeshConfig) -> Bool
pub fn calculate_quorum(config: MeshConfig) -> Int
/// floor(n/2) + 1
pub fn get_container_by_name(config: MeshConfig, name: String) -> Result(ContainerSpec, String)
pub fn get_container_port(config: MeshConfig, name: String) -> Result(Int, String)
pub fn total_cpu_allocation(config: MeshConfig) -> Float
pub fn total_memory_allocation(config: MeshConfig) -> Int
pub fn config_to_json(config: MeshConfig) -> json.Json
pub fn container_spec_to_json(spec: ContainerSpec) -> json.Json
pub fn print_summary(config: MeshConfig) -> String
pub fn get_stage_info(stage: Int) -> String
/// 5 boot stages described
```

**Total for P1-D: 20 functions, 1 file, 0 FFI**

---

# PRIORITY 2: MIXED (Pure logic + some FFI)

## Task P2-A: Constraint Sync (30 pure functions)

### File: `src/cepaf_gleam/config/constraint_sync.gleam`

**Focus on pure information theory functions only (no file I/O):**
```gleam
pub fn shannon_entropy(distribution: List(Float)) -> Float
/// -sum(p * log2(p)) for each p > 0
pub fn kl_divergence(p: List(Float), q: List(Float)) -> Result(Float, String)
/// sum(p_i * log2(p_i / q_i))
pub fn cross_entropy(p: List(Float), q: List(Float)) -> Result(Float, String)
/// -sum(p_i * log2(q_i))
pub fn classify_priority(id: String) -> String
/// SC-*-001..010 -> "critical", 011-050 -> "high", 051-100 -> "medium", else -> "low"
pub fn extract_family(id: String) -> String
/// "SC-PLAN-001" -> "PLAN"
pub fn extract_id_number(id: String) -> Result(Int, String)
/// "SC-PLAN-042" -> Ok(42)
pub fn compute_criticality(severity: Int, occurrence: Int, detection: Int) -> Int
/// RPN = severity * occurrence * detection
pub fn assess_health(total: Int, covered: Int, critical_covered: Int, critical_total: Int) -> String
/// "excellent" if >90% coverage AND 100% critical; "good" >70%; "fair" >50%; else "poor"
```

**Total for P2-A: 8 pure functions, skip 22 FFI functions**

---

## Task P2-B: Git Intelligence Types + Analysis (47 pure functions)

### File: `src/cepaf_gleam/git/types.gleam`

```gleam
pub type CommitType { Feat Fix Docs Refactor Test Chore Security Perf Ci }
pub type IcpScope { Guardian App Mesh Vsm Fed TestScope Audit Compliance Crypto Zenoh Podman Substrate Metabolic Immune Knowledge Planning Cockpit Mcp Kms Telemetry Smriti Config Bridge }
pub type CommitStyle { IcpConventional ConventionalNoEmDash Emoji EvolutionRun Hyperbolic PhaseSop Other }
pub type ValidationIssue { TooLong InvalidScope(scope: String) PastTense(verb: String) MissingType NoDescription InvalidFormat }
pub type ParsedCommit { ParsedCommit(commit_type: CommitType, scope: IcpScope, subject: String, style: CommitStyle) }
```

### File: `src/cepaf_gleam/git/analysis.gleam`

```gleam
pub fn shannon_entropy(types: List(CommitType)) -> Float
pub fn max_entropy(n: Int) -> Float
pub fn compute_style_distribution(commits: List(ParsedCommit)) -> Dict(CommitStyle, Float)
pub fn compute_scope_compliance(commits: List(ParsedCommit)) -> Float
pub fn compute_health_score(adoption_rate: Float, scope_compliance: Float, type_diversity: Float) -> Float
pub fn validate_subject(subject: String) -> List(ValidationIssue)
pub fn classify_style(message: String) -> CommitStyle
pub fn commit_type_to_string(ct: CommitType) -> String
pub fn scope_to_string(s: IcpScope) -> String
pub fn scope_to_fractal_layer(s: IcpScope) -> String
```

**Total for P2-B: 10+ pure functions in types/analysis, skip Store/History (DB)**

---

# PRIORITY 3: HEAVY FFI (Defer or Stub)

These modules require extensive external service integration. Implementation approach: create type stubs with `todo` bodies that compile but panic at runtime. This preserves the API surface for future FFI wiring.

## Task P3-A: Database stubs
- Create `src/cepaf_gleam/db/holon_database.gleam` with types only
- Create `src/cepaf_gleam/db/cross_holon.gleam` with types only
- Create `src/cepaf_gleam/db/transaction_manager.gleam` with types only

## Task P3-B: Bridge stubs
- Create `src/cepaf_gleam/bridge/jsonrpc.gleam` with types only
- Create `src/cepaf_gleam/bridge/commands.gleam` with types only

## Task P3-C: Smriti stubs
- Create `src/cepaf_gleam/smriti/catalog.gleam` with types only
- Create `src/cepaf_gleam/smriti/ingestor.gleam` with types only

---

# IMPLEMENTATION CHECKLIST

Each task follows this exact workflow:

```
1. Read this plan section for the task
2. Create the .gleam file with MSTS header
3. Define all types
4. Implement all functions
5. Run: cd lib/cepaf_gleam && gleam check
6. Fix any errors
7. Create test file in test/
8. Run: cd lib/cepaf_gleam && gleam test
9. Fix any test failures
10. Add route to ui/wisp/router.gleam if the module has a JSON endpoint
11. Run: cd lib/cepaf_gleam && gleam check
```

## Execution Order (for lightweight model):

| Order | Task | Functions | Difficulty | Est. Time |
|:-----:|------|:---------:|:----------:|:---------:|
| 1 | P1-A: Prajna Bio | 5 | Easy | 15 min |
| 2 | P1-A: Prajna Immune | 5 | Easy | 10 min |
| 3 | P1-A: Prajna Neuro | 4 | Easy | 10 min |
| 4 | P1-A: Prajna DarkCockpit | 6 | Easy | 15 min |
| 5 | P1-A: Prajna CircuitBreaker | 6 | Easy | 10 min |
| 6 | P1-A: Prajna SmartMetrics | 3 | Medium | 10 min |
| 7 | P1-A: Prajna Orchestrator | 5 | Easy | 10 min |
| 8 | P1-B: CyberneticAgents | 18 | Medium | 30 min |
| 9 | P1-C: Holon Identity | 19 | Medium | 25 min |
| 10 | P1-D: MeshConfig | 20 | Medium | 25 min |
| 11 | P2-A: ConstraintSync (pure) | 8 | Medium | 15 min |
| 12 | P2-B: GitIntelligence (pure) | 10 | Medium | 20 min |
| 13 | Tests for all above | ~100 | Easy | 30 min |
| 14 | Router + Endpoints | 6 | Easy | 10 min |
| 15 | P3-A/B/C: Type stubs | 30 types | Easy | 20 min |
| **TOTAL** | | **~170 fns** | | **~4 hours** |

## Verification Command (run after each task):
```bash
cd lib/cepaf_gleam && gleam check && gleam test
```

## Final Target:
- **~565 pub functions** (395 current + 170 new)
- **~110 modules** (96 current + 14 new)
- **~580 tests** (479 current + ~100 new)
- **~29 endpoints** (23 current + 6 new)

---

# APPENDIX: Import Patterns

Every new file should use these standard imports:
```gleam
import gleam/dict.{type Dict}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
```

For modules needing IDs:
```gleam
import cepaf_gleam/core/ids
```

For modules needing domain types:
```gleam
import cepaf_gleam/core/types
```

For modules needing graph operations:
```gleam
import cepaf_gleam/planning/graph_verification as graph
```

# APPENDIX: Test Pattern

Every test file follows this structure:
```gleam
import cepaf_gleam/prajna/bio
import gleeunit/should

pub fn create_holon_default_state_test() {
  let holon = bio.create_holon("h1", "agent", None)
  holon.state
  |> should.equal(bio.Dormant)
}
```

# APPENDIX: Router Addition Pattern

To add a new endpoint:
```gleam
// In router.gleam route() function, add:
"/api/prajna/health" | "/api/v1/prajna" -> prajna_json()

// Then add the handler function:
fn prajna_json() -> String {
  json.object([
    #("page", json.string("Prajna")),
    #("status", json.string("active")),
    // ... domain-specific fields
  ])
  |> json.to_string()
}
```
