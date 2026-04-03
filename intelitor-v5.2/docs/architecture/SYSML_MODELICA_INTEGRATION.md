# SysML & Modelica Integration for Indrajaal

**Version**: 1.0.0 | **Date**: 2026-01-01 | **Status**: ANALYSIS
**Author**: Claude Opus 4.5

## 1. Executive Summary

This document defines integration points for SysML (Systems Modeling Language) and Modelica artifacts within the Indrajaal system. These formal modeling tools enable:

- **SysML**: Structural and behavioral specification of system architecture
- **Modelica**: Dynamic simulation of resource consumption, scaling, and physical behavior

## 2. SysML Integration Points

### 2.1 Requirements Engineering (SysML Requirements Diagrams)

| Artifact | Purpose | Maps To |
|----------|---------|---------|
| `req/constitutional_invariants.reqif` | Ψ₀-Ψ₅ formal requirements | SC-CONST-* constraints |
| `req/founder_directive.reqif` | Ω₀ supreme directive decomposition | AOR-FOUNDER-* rules |
| `req/capability_requirements.reqif` | Per-capability functional requirements | TDG test specifications |
| `req/safety_requirements.reqif` | STAMP safety constraints | SC-* constraint catalog |

**Traceability Matrix Generation**:
```
SysML Requirements → STAMP Constraints → Test Cases → Implementation
     ↓                    ↓                  ↓              ↓
  reqif/             CLAUDE.md           test/         lib/
```

### 2.2 System Architecture (SysML Block Definition Diagrams)

#### 2.2.1 Four-Layer Architecture BDD

```
┌─────────────────────────────────────────────────────────────────────┐
│ «block» IndrajaalSystem                                             │
├─────────────────────────────────────────────────────────────────────┤
│ parts:                                                              │
│   kernel: KernelLayer[1]           # L0 - Immutable                │
│   core: CoreLayer[1]               # L1 - Required                 │
│   capabilities: CapabilityLayer[0..1]  # L2 - Optional             │
│   extensions: ExtensionLayer[0..1]     # L3 - Optional             │
├─────────────────────────────────────────────────────────────────────┤
│ constraints:                                                        │
│   {kernel.enabled = true}          # Cannot disable                │
│   {core.enabled = true}            # Cannot disable                │
│   {capabilities.count >= 0}        # Zero or more                  │
│   {extensions.count >= 0}          # Zero or more                  │
└─────────────────────────────────────────────────────────────────────┘
```

**File**: `docs/sysml/architecture/system_layers.bdd.sysml`

#### 2.2.2 Capability Module Interface BDD

```
┌─────────────────────────────────────────────────────────────────────┐
│ «interface» ICapability                                             │
├─────────────────────────────────────────────────────────────────────┤
│ operations:                                                         │
│   + capability_info(): CapabilityInfo                              │
│   + init(config: Map): Result                                      │
│   + hibernate_state(): Result                                      │
│   + restore_state(state: Term): Result                             │
│   + health_check(): HealthStatus                                   │
│   + shutdown(reason: Term): :ok                                    │
├─────────────────────────────────────────────────────────────────────┤
│ properties:                                                         │
│   name: Atom                                                       │
│   version: String                                                  │
│   layer: {capability, extension}                                   │
│   dependencies: List<Atom>                                         │
│   required_resources: ResourceSpec                                 │
└─────────────────────────────────────────────────────────────────────┘
```

**File**: `docs/sysml/interfaces/capability_interface.bdd.sysml`

#### 2.2.3 Guardian-Capability Interaction BDD

```
┌─────────────────────────────────────────────────────────────────────┐
│ «block» CapabilityManager                                           │
├─────────────────────────────────────────────────────────────────────┤
│ parts:                                                              │
│   guardian: Guardian[1]            # Safety kernel                 │
│   registry: CapabilityRegistry[1]  # Enabled capabilities          │
│   depGraph: DependencyGraph[1]     # Dependency relationships      │
├─────────────────────────────────────────────────────────────────────┤
│ ports:                                                              │
│   ~enableRequest: EnablePort       # Incoming enable requests      │
│   ~disableRequest: DisablePort     # Incoming disable requests     │
│   ~healthReport: HealthPort        # To Sentinel                   │
│   ~auditLog: AuditPort             # To ImmutableRegister          │
└─────────────────────────────────────────────────────────────────────┘
```

**File**: `docs/sysml/architecture/capability_manager.bdd.sysml`

### 2.3 Internal Block Diagrams (Data Flow)

#### 2.3.1 Capability Enable Flow IBD

```
┌─────────────────────────────────────────────────────────────────────┐
│ ibd [CapabilityManager] Enable Flow                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────┐    proposal    ┌──────────┐    approved   ┌────────┐ │
│  │ Request  │───────────────►│ Guardian │──────────────►│ Enable │ │
│  │  Port    │                │          │               │ Logic  │ │
│  └──────────┘                └────┬─────┘               └───┬────┘ │
│                                   │                         │      │
│                              veto │                         │      │
│                                   ▼                         ▼      │
│                             ┌──────────┐              ┌──────────┐ │
│                             │  Reject  │              │ Start    │ │
│                             │  Response│              │ Supervisor│ │
│                             └──────────┘              └────┬─────┘ │
│                                                            │      │
│                                                            ▼      │
│                                                      ┌──────────┐ │
│                                                      │ Audit    │ │
│                                                      │ Log      │ │
│                                                      └──────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

**File**: `docs/sysml/dataflows/capability_enable.ibd.sysml`

#### 2.3.2 Sentinel Health Monitoring IBD

```
┌─────────────────────────────────────────────────────────────────────┐
│ ibd [HealthMonitoring] Sentinel Integration                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐                                                   │
│  │ Capability 1 │──┐                                                │
│  └──────────────┘  │    ┌──────────┐    ┌──────────┐              │
│  ┌──────────────┐  ├───►│ Sentinel │───►│ Prajna   │              │
│  │ Capability 2 │──┤    │ (Assess) │    │ Dashboard│              │
│  └──────────────┘  │    └────┬─────┘    └──────────┘              │
│  ┌──────────────┐  │         │                                     │
│  │ Capability N │──┘         │ threat_detected                     │
│  └──────────────┘            ▼                                     │
│                        ┌──────────┐    ┌──────────┐              │
│                        │ Pattern  │───►│ Symbiotic│              │
│                        │ Hunter   │    │ Defense  │              │
│                        └──────────┘    └──────────┘              │
└─────────────────────────────────────────────────────────────────────┘
```

**File**: `docs/sysml/dataflows/health_monitoring.ibd.sysml`

### 2.4 State Machine Diagrams

#### 2.4.1 Capability Lifecycle State Machine

```
┌─────────────────────────────────────────────────────────────────────┐
│ stm [Capability] Lifecycle                                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│                    ┌─────────────────┐                              │
│                    │    [*] Start    │                              │
│                    └────────┬────────┘                              │
│                             │                                       │
│                             ▼                                       │
│                    ┌─────────────────┐                              │
│            ┌──────►│    Disabled     │◄──────┐                      │
│            │       └────────┬────────┘       │                      │
│            │                │ enable_request │                      │
│            │                │ [guardian_approved]                   │
│            │                ▼                │                      │
│            │       ┌─────────────────┐       │                      │
│            │       │   Validating    │       │                      │
│            │       │  Dependencies   │       │                      │
│            │       └────────┬────────┘       │                      │
│            │                │ [deps_satisfied]                      │
│            │                ▼                │                      │
│            │       ┌─────────────────┐       │                      │
│            │       │   Restoring     │       │ shutdown             │
│            │       │     State       │       │                      │
│            │       └────────┬────────┘       │                      │
│            │                │ [state_restored]                      │
│            │                ▼                │                      │
│            │       ┌─────────────────┐       │                      │
│            │       │    Enabled      │───────┤                      │
│            │       │                 │       │                      │
│            │       └────────┬────────┘       │                      │
│            │                │ disable_request                       │
│            │                ▼                │                      │
│            │       ┌─────────────────┐       │                      │
│            │       │  Hibernating    │───────┘                      │
│            │       │    State        │                              │
│            └───────┴─────────────────┘                              │
│                                                                     │
│  Guards:                                                            │
│    [guardian_approved] = Guardian.submit_proposal() == :approved   │
│    [deps_satisfied] = all dependencies enabled                     │
│    [state_restored] = restore_state() == :ok                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**File**: `docs/sysml/state_machines/capability_lifecycle.stm.sysml`

#### 2.4.2 Guardian Proposal State Machine

```
┌─────────────────────────────────────────────────────────────────────┐
│ stm [Guardian] Proposal Processing                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│    ┌─────────┐                                                      │
│    │[*] Start│                                                      │
│    └────┬────┘                                                      │
│         │ proposal_received                                         │
│         ▼                                                           │
│    ┌─────────────────┐                                              │
│    │  Validating     │                                              │
│    │  Constitution   │                                              │
│    └────────┬────────┘                                              │
│             │                                                       │
│    ┌────────┴────────┐                                              │
│    │                 │                                              │
│    ▼                 ▼                                              │
│ [Ψ_violated]    [Ψ_satisfied]                                      │
│    │                 │                                              │
│    ▼                 ▼                                              │
│ ┌──────────┐   ┌─────────────────┐                                 │
│ │  VETO    │   │  Checking       │                                 │
│ │ (logged) │   │  STAMP/AOR      │                                 │
│ └──────────┘   └────────┬────────┘                                 │
│                         │                                          │
│                ┌────────┴────────┐                                 │
│                │                 │                                 │
│                ▼                 ▼                                 │
│           [SC_violated]    [SC_satisfied]                          │
│                │                 │                                 │
│                ▼                 ▼                                 │
│           ┌──────────┐   ┌─────────────────┐                       │
│           │  VETO    │   │   APPROVED      │                       │
│           │ (logged) │   │   (logged)      │                       │
│           └──────────┘   └─────────────────┘                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**File**: `docs/sysml/state_machines/guardian_proposal.stm.sysml`

#### 2.4.3 Holon Regeneration State Machine

```
┌─────────────────────────────────────────────────────────────────────┐
│ stm [Holon] Regeneration Lifecycle                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│    ┌─────────────────┐                                              │
│    │     Normal      │◄─────────────────────────┐                   │
│    │   Operation     │                          │                   │
│    └────────┬────────┘                          │                   │
│             │ corruption_detected               │                   │
│             ▼                                   │                   │
│    ┌─────────────────┐                          │                   │
│    │   Validating    │                          │                   │
│    │   Hash Chain    │                          │                   │
│    └────────┬────────┘                          │                   │
│             │                                   │                   │
│    ┌────────┴────────┐                          │                   │
│    │                 │                          │                   │
│    ▼                 ▼                          │                   │
│ [valid]         [invalid]                       │                   │
│    │                 │                          │                   │
│    │                 ▼                          │                   │
│    │        ┌─────────────────┐                 │                   │
│    │        │  Reed-Solomon   │                 │                   │
│    │        │    Repair       │                 │                   │
│    │        └────────┬────────┘                 │                   │
│    │                 │                          │                   │
│    │        ┌────────┴────────┐                 │                   │
│    │        │                 │                 │                   │
│    │        ▼                 ▼                 │                   │
│    │   [repair_ok]      [repair_fail]          │                   │
│    │        │                 │                 │                   │
│    │        │                 ▼                 │                   │
│    │        │        ┌─────────────────┐        │                   │
│    │        │        │  Full Regen     │        │                   │
│    │        │        │  from DuckDB    │        │                   │
│    │        │        └────────┬────────┘        │                   │
│    │        │                 │                 │                   │
│    └────────┴─────────────────┴─────────────────┘                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**File**: `docs/sysml/state_machines/holon_regeneration.stm.sysml`

### 2.5 Sequence Diagrams

#### 2.5.1 Runtime Capability Enable Sequence

```
┌─────────────────────────────────────────────────────────────────────┐
│ sd [CapabilityEnable] Runtime Enable Sequence                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Operator    CapMgr     Guardian    DepGraph   Supervisor   Audit  │
│     │          │           │           │           │          │    │
│     │ enable   │           │           │           │          │    │
│     │─────────►│           │           │           │          │    │
│     │          │ proposal  │           │           │          │    │
│     │          │──────────►│           │           │          │    │
│     │          │           │ check_Ψ   │           │          │    │
│     │          │           │───┐       │           │          │    │
│     │          │           │◄──┘       │           │          │    │
│     │          │           │ check_SC  │           │          │    │
│     │          │           │───┐       │           │          │    │
│     │          │           │◄──┘       │           │          │    │
│     │          │ approved  │           │           │          │    │
│     │          │◄──────────│           │           │          │    │
│     │          │           │           │           │          │    │
│     │          │ validate_deps         │           │          │    │
│     │          │──────────────────────►│           │          │    │
│     │          │           │    ok     │           │          │    │
│     │          │◄──────────────────────│           │          │    │
│     │          │           │           │           │          │    │
│     │          │ start_child           │           │          │    │
│     │          │──────────────────────────────────►│          │    │
│     │          │           │           │    pid    │          │    │
│     │          │◄──────────────────────────────────│          │    │
│     │          │           │           │           │          │    │
│     │          │ log_enabled           │           │          │    │
│     │          │─────────────────────────────────────────────►│    │
│     │          │           │           │           │          │    │
│     │ {:ok,pid}│           │           │           │          │    │
│     │◄─────────│           │           │           │          │    │
│     │          │           │           │           │          │    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**File**: `docs/sysml/sequences/capability_enable.sd.sysml`

#### 2.5.2 Configuration Hot-Reload Sequence

```
┌─────────────────────────────────────────────────────────────────────┐
│ sd [ConfigHotReload] Configuration Change with Rollback             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Admin     HotReload   Guardian   Register   Config   Sentinel     │
│    │          │           │          │         │         │         │
│    │ apply    │           │          │         │         │         │
│    │─────────►│           │          │         │         │         │
│    │          │ validate_constitutional        │         │         │
│    │          │───┐       │          │         │         │         │
│    │          │◄──┘       │          │         │         │         │
│    │          │           │          │         │         │         │
│    │          │ proposal  │          │         │         │         │
│    │          │──────────►│          │         │         │         │
│    │          │ approved  │          │         │         │         │
│    │          │◄──────────│          │         │         │         │
│    │          │           │          │         │         │         │
│    │          │ create_rollback_point│         │         │         │
│    │          │─────────────────────►│         │         │         │
│    │          │      rollback_id     │         │         │         │
│    │          │◄─────────────────────│         │         │         │
│    │          │           │          │         │         │         │
│    │          │ put_env              │         │         │         │
│    │          │───────────────────────────────►│         │         │
│    │          │           │          │         │         │         │
│    │          │ health_check         │         │         │         │
│    │          │─────────────────────────────────────────►│         │
│    │          │           │          │  score   │         │         │
│    │          │◄─────────────────────────────────────────│         │
│    │          │           │          │         │         │         │
│    │          │  alt [score < 0.5]   │         │         │         │
│    │          │  ┌───────────────────────────────────────┐         │
│    │          │  │ rollback          │         │         │         │
│    │          │  │──────────────────►│         │         │         │
│    │          │  │ restore           │         │         │         │
│    │          │  │───────────────────────────►│         │         │
│    │          │  └───────────────────────────────────────┘         │
│    │          │           │          │         │         │         │
│    │ result   │           │          │         │         │         │
│    │◄─────────│           │          │         │         │         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**File**: `docs/sysml/sequences/config_hot_reload.sd.sysml`

### 2.6 Parametric Diagrams (Constraints)

#### 2.6.1 Resource Budget Constraints

```
┌─────────────────────────────────────────────────────────────────────┐
│ par [ResourceBudget] Variant Resource Constraints                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ «constraint» MemoryBudget                                    │   │
│  │                                                              │   │
│  │ constraints:                                                 │   │
│  │   {total_memory = kernel_mem + core_mem + cap_mem + ext_mem}│   │
│  │   {total_memory <= variant.memory_limit}                    │   │
│  │   {kernel_mem = 64 MB}  # Fixed                             │   │
│  │   {core_mem = 128 MB}   # Fixed                             │   │
│  │   {cap_mem = sum(enabled_capabilities.memory)}              │   │
│  │   {ext_mem = sum(enabled_extensions.memory)}                │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ «constraint» CPUBudget                                       │   │
│  │                                                              │   │
│  │ constraints:                                                 │   │
│  │   {total_cpu = kernel_cpu + core_cpu + cap_cpu + ext_cpu}   │   │
│  │   {total_cpu <= variant.cpu_limit}                          │   │
│  │   {kernel_cpu = 0.1}    # Fixed                             │   │
│  │   {core_cpu = 0.2}      # Fixed                             │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ «constraint» APIBudget                                       │   │
│  │                                                              │   │
│  │ constraints:                                                 │   │
│  │   {agent_count * avg_tokens_per_agent <= api_token_limit}   │   │
│  │   {agent_count <= 25}   # SC-API-001                        │   │
│  │   {api_usage <= 0.95 * api_limit}  # SC-PROM-002            │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**File**: `docs/sysml/parametric/resource_budget.par.sysml`

## 3. Modelica Integration Points

### 3.1 Resource Consumption Dynamics

#### 3.1.1 Capability Memory Model

```modelica
// File: docs/modelica/resources/CapabilityMemory.mo

model CapabilityMemory
  "Dynamic memory consumption model for a capability"

  parameter Real base_memory_mb = 64 "Base memory footprint";
  parameter Real growth_rate = 0.1 "Memory growth per request";
  parameter Real gc_efficiency = 0.8 "Garbage collection efficiency";
  parameter Real max_memory_mb = 512 "Maximum allowed memory";

  Real current_memory_mb(start=base_memory_mb) "Current memory usage";
  Real request_rate "Incoming request rate (req/s)";
  Real gc_rate "Garbage collection rate";

  Boolean memory_pressure "Memory pressure flag";

equation
  // Memory grows with requests, reduced by GC
  der(current_memory_mb) = growth_rate * request_rate - gc_rate * gc_efficiency;

  // GC activates when memory exceeds 80% of max
  gc_rate = if current_memory_mb > 0.8 * max_memory_mb then 10 else 1;

  // Memory pressure triggers hibernation consideration
  memory_pressure = current_memory_mb > 0.9 * max_memory_mb;

  // Clamp memory to bounds
  current_memory_mb = max(base_memory_mb, min(current_memory_mb, max_memory_mb));

end CapabilityMemory;
```

#### 3.1.2 System-Wide Resource Model

```modelica
// File: docs/modelica/resources/SystemResources.mo

model SystemResources
  "Aggregate resource consumption for all layers"

  // Subsystem models
  CapabilityMemory kernel(base_memory_mb=64, max_memory_mb=128);
  CapabilityMemory core(base_memory_mb=128, max_memory_mb=256);
  CapabilityMemory[10] capabilities;
  CapabilityMemory[8] extensions;

  // Aggregate metrics
  Real total_memory_mb;
  Real memory_limit_mb = 2048 "From variant config";
  Real memory_utilization;

  Boolean system_memory_pressure;

equation
  total_memory_mb = kernel.current_memory_mb +
                    core.current_memory_mb +
                    sum(cap.current_memory_mb for cap in capabilities if cap.enabled) +
                    sum(ext.current_memory_mb for ext in extensions if ext.enabled);

  memory_utilization = total_memory_mb / memory_limit_mb;

  system_memory_pressure = memory_utilization > 0.85;

end SystemResources;
```

### 3.2 Agent Scaling Dynamics (Metabolic Model)

```modelica
// File: docs/modelica/scaling/MetabolicScaling.mo

model MetabolicScaling
  "Biomorphic agent scaling based on API token budget"

  // API limits (from provider)
  parameter Real token_limit_per_minute = 100000;
  parameter Real request_limit_per_minute = 1000;

  // Scaling parameters
  parameter Real target_utilization = 0.8 "80% target";
  parameter Real redline = 0.95 "95% hard limit";
  parameter Real scale_up_threshold = 0.4;
  parameter Real scale_down_threshold = 0.7;
  parameter Integer min_agents = 1;
  parameter Integer max_agents = 25;

  // State variables
  Integer active_agents(start=5);
  Real tokens_consumed_per_minute;
  Real requests_per_minute;
  Real token_utilization;
  Real request_utilization;
  Real effective_utilization;

  // Control signals
  Boolean scale_up_signal;
  Boolean scale_down_signal;
  Boolean circuit_breaker;

  // Cooldown state
  Real cooldown_timer(start=0);
  parameter Real cooldown_period = 30 "seconds";

equation
  token_utilization = tokens_consumed_per_minute / token_limit_per_minute;
  request_utilization = requests_per_minute / request_limit_per_minute;
  effective_utilization = max(token_utilization, request_utilization);

  // Scaling decisions
  scale_up_signal = effective_utilization < scale_up_threshold and
                    cooldown_timer <= 0 and
                    active_agents < max_agents;

  scale_down_signal = effective_utilization > scale_down_threshold and
                      cooldown_timer <= 0 and
                      active_agents > min_agents;

  // Circuit breaker at redline
  circuit_breaker = effective_utilization >= redline;

  // Cooldown timer dynamics
  der(cooldown_timer) = if scale_up_signal or scale_down_signal
                        then -1
                        else 0;

  when scale_up_signal then
    active_agents = pre(active_agents) + 1;
    reinit(cooldown_timer, cooldown_period);
  end when;

  when scale_down_signal then
    active_agents = pre(active_agents) - 1;
    reinit(cooldown_timer, cooldown_period);
  end when;

end MetabolicScaling;
```

### 3.3 Reliability Models

```modelica
// File: docs/modelica/reliability/CapabilityReliability.mo

model CapabilityReliability
  "MTBF and availability model for capability modules"

  parameter Real lambda = 1e-6 "Failure rate (failures/hour)";
  parameter Real mu = 0.1 "Repair rate (repairs/hour)";

  Real availability "Steady-state availability";
  Real mtbf "Mean time between failures (hours)";
  Real mttr "Mean time to repair (hours)";

  // State: 0=failed, 1=operational
  discrete Real state(start=1);
  Real time_in_state(start=0);

equation
  mtbf = 1 / lambda;
  mttr = 1 / mu;
  availability = mu / (lambda + mu);

  der(time_in_state) = 1;

  when state == 1 and time_in_state > mtbf then
    // Failure event
    state = 0;
    reinit(time_in_state, 0);
  end when;

  when state == 0 and time_in_state > mttr then
    // Repair event (via regeneration)
    state = 1;
    reinit(time_in_state, 0);
  end when;

end CapabilityReliability;
```

### 3.4 Economic Models

```modelica
// File: docs/modelica/economics/VariantEconomics.mo

model VariantEconomics
  "Cost optimization model for capability combinations"

  // Infrastructure costs
  parameter Real cost_per_gb_memory = 10 "$/GB/month";
  parameter Real cost_per_cpu = 50 "$/vCPU/month";
  parameter Real cost_per_1k_api_calls = 0.01 "$";

  // Capability values (revenue potential)
  parameter Real value_alarms = 100 "$/month";
  parameter Real value_devices = 80 "$/month";
  parameter Real value_video = 200 "$/month";
  parameter Real value_ai = 500 "$/month";

  // Resource consumption
  Real memory_gb;
  Real cpu_cores;
  Real api_calls_per_month;

  // Enabled capabilities (binary)
  Boolean alarms_enabled;
  Boolean devices_enabled;
  Boolean video_enabled;
  Boolean ai_enabled;

  // Economics
  Real total_cost;
  Real total_value;
  Real roi;

equation
  total_cost = memory_gb * cost_per_gb_memory +
               cpu_cores * cost_per_cpu +
               api_calls_per_month / 1000 * cost_per_1k_api_calls;

  total_value = (if alarms_enabled then value_alarms else 0) +
                (if devices_enabled then value_devices else 0) +
                (if video_enabled then value_video else 0) +
                (if ai_enabled then value_ai else 0);

  roi = (total_value - total_cost) / total_cost;

end VariantEconomics;
```

### 3.5 Thermal Model (Edge Deployments)

```modelica
// File: docs/modelica/thermal/EdgeThermal.mo

model EdgeThermal
  "Thermal model for edge/IoT deployments"

  parameter Real ambient_temp_c = 25 "Ambient temperature";
  parameter Real thermal_resistance = 0.5 "K/W";
  parameter Real thermal_capacitance = 100 "J/K";
  parameter Real max_temp_c = 85 "Maximum operating temperature";

  // Power consumption (from CPU model)
  Real power_watts;
  Real cpu_utilization;
  parameter Real idle_power = 5 "W";
  parameter Real max_power = 25 "W";

  // Temperature state
  Real device_temp_c(start=ambient_temp_c);
  Boolean thermal_throttle;

equation
  power_watts = idle_power + cpu_utilization * (max_power - idle_power);

  // Thermal dynamics
  thermal_capacitance * der(device_temp_c) =
    power_watts - (device_temp_c - ambient_temp_c) / thermal_resistance;

  // Thermal throttling kicks in at 80°C
  thermal_throttle = device_temp_c > 0.95 * max_temp_c;

end EdgeThermal;
```

## 4. Integration Architecture

### 4.1 Model-to-Code Pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│                     MODEL-TO-CODE PIPELINE                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    SysML Models                              │   │
│  │  (Papyrus / Cameo)                                          │   │
│  │                                                              │   │
│  │  • Requirements (.reqif)                                     │   │
│  │  • Block Diagrams (.bdd.sysml)                              │   │
│  │  • State Machines (.stm.sysml)                              │   │
│  │  • Sequences (.sd.sysml)                                    │   │
│  │  • Parametric (.par.sysml)                                  │   │
│  └──────────────────────┬──────────────────────────────────────┘   │
│                         │                                          │
│                         │ Export XMI/JSON                          │
│                         ▼                                          │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Model Transformation Layer                      │   │
│  │  (Elixir scripts)                                           │   │
│  │                                                              │   │
│  │  • scripts/sysml/parse_requirements.exs                     │   │
│  │  • scripts/sysml/generate_state_machines.exs                │   │
│  │  • scripts/sysml/validate_constraints.exs                   │   │
│  └──────────────────────┬──────────────────────────────────────┘   │
│                         │                                          │
│                         │ Generate                                 │
│                         ▼                                          │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                 Generated Artifacts                          │   │
│  │                                                              │   │
│  │  • lib/indrajaal/generated/state_machines.ex                │   │
│  │  • test/generated/requirement_traces.exs                    │   │
│  │  • docs/generated/traceability_matrix.md                    │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                   Modelica Models                            │   │
│  │  (OpenModelica / JModelica)                                 │   │
│  │                                                              │   │
│  │  • Resource models (.mo)                                    │   │
│  │  • Scaling models (.mo)                                     │   │
│  │  • Reliability models (.mo)                                 │   │
│  │  • Economic models (.mo)                                    │   │
│  └──────────────────────┬──────────────────────────────────────┘   │
│                         │                                          │
│                         │ Compile to FMU                           │
│                         ▼                                          │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              FMU Runtime Integration                         │   │
│  │  (Rust NIF)                                                 │   │
│  │                                                              │   │
│  │  • native/modelica_fmu/                                     │   │
│  │  • lib/indrajaal/simulation/fmu_runner.ex                   │   │
│  └──────────────────────┬──────────────────────────────────────┘   │
│                         │                                          │
│                         │ Runtime queries                          │
│                         ▼                                          │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                 Runtime Decisions                            │   │
│  │                                                              │   │
│  │  • CapabilityManager scaling decisions                      │   │
│  │  • Resource budget validation                               │   │
│  │  • Predictive maintenance alerts                            │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Directory Structure

```
docs/
├── sysml/
│   ├── requirements/
│   │   ├── constitutional_invariants.reqif
│   │   ├── founder_directive.reqif
│   │   ├── capability_requirements.reqif
│   │   └── safety_requirements.reqif
│   ├── architecture/
│   │   ├── system_layers.bdd.sysml
│   │   ├── capability_manager.bdd.sysml
│   │   └── guardian_integration.bdd.sysml
│   ├── interfaces/
│   │   ├── capability_interface.bdd.sysml
│   │   └── observer_interface.bdd.sysml
│   ├── dataflows/
│   │   ├── capability_enable.ibd.sysml
│   │   ├── health_monitoring.ibd.sysml
│   │   └── config_hot_reload.ibd.sysml
│   ├── state_machines/
│   │   ├── capability_lifecycle.stm.sysml
│   │   ├── guardian_proposal.stm.sysml
│   │   ├── holon_regeneration.stm.sysml
│   │   └── sentinel_threat_response.stm.sysml
│   ├── sequences/
│   │   ├── capability_enable.sd.sysml
│   │   ├── capability_disable.sd.sysml
│   │   ├── config_hot_reload.sd.sysml
│   │   └── threat_detection.sd.sysml
│   └── parametric/
│       ├── resource_budget.par.sysml
│       ├── api_constraints.par.sysml
│       └── reliability_constraints.par.sysml
│
├── modelica/
│   ├── resources/
│   │   ├── CapabilityMemory.mo
│   │   ├── SystemResources.mo
│   │   └── DatabaseConnections.mo
│   ├── scaling/
│   │   ├── MetabolicScaling.mo
│   │   ├── AgentPopulation.mo
│   │   └── LoadBalancing.mo
│   ├── reliability/
│   │   ├── CapabilityReliability.mo
│   │   ├── SystemAvailability.mo
│   │   └── FailoverDynamics.mo
│   ├── economics/
│   │   ├── VariantEconomics.mo
│   │   ├── CostOptimization.mo
│   │   └── ROIProjection.mo
│   ├── thermal/
│   │   ├── EdgeThermal.mo
│   │   └── DatacenterCooling.mo
│   └── package.mo
│
scripts/
├── sysml/
│   ├── parse_requirements.exs
│   ├── generate_state_machines.exs
│   ├── validate_constraints.exs
│   └── generate_traceability.exs
└── modelica/
    ├── compile_fmu.sh
    ├── run_simulation.exs
    └── extract_parameters.exs

native/
└── modelica_fmu/
    ├── Cargo.toml
    └── src/
        └── lib.rs
```

## 5. Use Case Matrix

| Model Type | Artifact | Design-Time Use | Runtime Use |
|------------|----------|-----------------|-------------|
| SysML Requirements | .reqif | Trace to tests/constraints | - |
| SysML BDD | .bdd.sysml | Define interfaces | Generate Behaviours |
| SysML IBD | .ibd.sysml | Document data flow | - |
| SysML STM | .stm.sysml | Specify state logic | Generate FSM code |
| SysML SD | .sd.sysml | Document protocols | Generate test cases |
| SysML PAR | .par.sysml | Define constraints | Validate at startup |
| Modelica Resource | .mo | Size variants | Live monitoring |
| Modelica Scaling | .mo | Plan capacity | Auto-scale decisions |
| Modelica Reliability | .mo | Predict MTBF | Maintenance alerts |
| Modelica Economics | .mo | Pricing models | Optimization |

## 6. Tooling Recommendations

| Tool | Purpose | License | Integration |
|------|---------|---------|-------------|
| **Papyrus** | Open-source SysML | EPL | XMI export → Elixir parse |
| **Cameo Systems Modeler** | Enterprise SysML | Commercial | API → REST calls |
| **OpenModelica** | Open-source Modelica | OSMC-PL | FMU → Rust NIF |
| **JModelica** | Optimization | Commercial | Python API → Port |
| **FMPy** | FMU simulation | BSD | Python → Elixir Port |

## 7. Implementation Priority

### Phase 1: SysML Foundation
1. Set up Papyrus project structure
2. Create requirements diagrams for SC-CAP-* constraints
3. Model capability lifecycle state machine
4. Generate traceability matrix

### Phase 2: Modelica Simulation
1. Set up OpenModelica environment
2. Create resource consumption models
3. Implement metabolic scaling model
4. Compile to FMU

### Phase 3: Runtime Integration
1. Create Rust NIF for FMU execution
2. Wire to CapabilityManager for scaling decisions
3. Add Prajna dashboard for simulation visualization
4. Implement predictive alerts

## 8. References

- OMG SysML Specification v1.6
- Modelica Language Specification 3.5
- FMI Standard 2.0 / 3.0
- docs/architecture/CONFIGURABLE_CORE_NONCORE_ARCHITECTURE.md
