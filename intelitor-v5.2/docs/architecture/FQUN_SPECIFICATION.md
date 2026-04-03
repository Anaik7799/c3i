# FQUN (Fully Qualified Unique Name) Specification

## Document Control

| Field | Value |
|-------|-------|
| **Document ID** | FQUN-SPEC-001 |
| **Version** | 1.0.0 |
| **Status** | ACTIVE |
| **Created** | 2025-12-26T12:30:00+01:00 |
| **Last Modified** | 2025-12-26T12:30:00+01:00 |
| **Author** | Claude Code (Cybernetic Architect) |
| **Reviewed By** | - |
| **Approved By** | - |
| **Classification** | INTERNAL |
| **STAMP Constraints** | SC-DIST-001, SC-DIST-002, SC-DIST-003, SC-DIST-004 |

## Change History

| Version | Date | Author | Description | Review Status |
|---------|------|--------|-------------|---------------|
| 1.0.0 | 2025-12-26 | Claude Code | Initial specification with 5-level analysis, implementation plan, integration details, test plan, and usability documentation | PENDING |

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Level 1: Conceptual Analysis](#2-level-1-conceptual-analysis)
3. [Level 2: Technical Design](#3-level-2-technical-design)
4. [Level 3: Implementation Specification](#4-level-3-implementation-specification)
5. [Level 4: Integration Architecture](#5-level-4-integration-architecture)
6. [Level 5: Operational Details](#6-level-5-operational-details)
7. [Test Plan](#7-test-plan)
8. [Usability Guidelines](#8-usability-guidelines)
9. [Appendices](#9-appendices)

---

## 1. Executive Summary

### 1.1 Purpose

The Fully Qualified Unique Name (FQUN) system provides a universal addressing scheme for all dynamic resources in the Indrajaal distributed system. FQUNs enable seamless resource discovery, routing, and lifecycle management across Elixir processes, mesh networking, Zenoh pub/sub, Erlang clustering, FLAME elastic compute, and container resources.

### 1.2 Scope

This specification covers:
- FQUN format and semantics
- Registry implementation
- Integration with 12 system components
- Test-Driven Generation (TDG) validation
- STAMP safety constraints
- Agent Operating Rules (AOR)

### 1.3 Key Benefits

| Benefit | Description |
|---------|-------------|
| **Universal Addressing** | Single naming scheme for all resource types |
| **Mesh Discovery** | Automatic resource discovery via Zenoh key expressions |
| **Distributed Lookup** | O(1) local lookup, O(log n) mesh-wide discovery |
| **Lifecycle Tracking** | Automatic registration/deregistration with processes |
| **Collision-Free** | HLC timestamps ensure uniqueness |

---

## 2. Level 1: Conceptual Analysis

### 2.1 Problem Statement

In a distributed system with multiple resource types (agents, workers, containers, connections), we need a unified naming scheme that:

1. **Uniquely identifies** every resource across the entire mesh
2. **Enables discovery** without prior knowledge of resource location
3. **Supports routing** through Zenoh key expressions
4. **Integrates** with Erlang node naming and distribution
5. **Persists** across restarts with deterministic regeneration

### 2.2 Mathematical Foundation

```
FQUN ∈ Σ* where Σ = {alphanumeric, '/', '@', '#', '_', '.', '-'}

FQUN := Prefix '/' Layer '/' Type '/' Namespace '/' Name '@' Node '#' Instance

where:
  Prefix     = "indrajaal"                    (constant)
  Layer      ∈ {agent, worker, supervisor, dashboard, resource}
  Type       ∈ TypeRegistry[Layer]            (layer-dependent)
  Namespace  ∈ [a-z][a-z0-9_]*               (lowercase, starts with letter)
  Name       ∈ [a-z][a-z0-9_]*               (lowercase, starts with letter)
  Node       ∈ ErlangNodeName                 (atom format)
  Instance   ∈ Base62(HLC) ⊕ Random(4 bytes)  (unique per creation)
```

### 2.3 Uniqueness Proof

**Theorem**: Given the FQUN format, no two resources can have identical FQUNs.

**Proof**:
1. `Instance` contains a Hybrid Logical Clock (HLC) timestamp (nanosecond precision)
2. HLC guarantees monotonically increasing values within a node
3. Random suffix (4 bytes = 2^32 possibilities) handles simultaneous creations
4. Node component ensures cross-node uniqueness
5. Therefore: P(collision) < 1/(10^9 × 2^32) ≈ 2.3 × 10^-19

### 2.4 Invariants

| ID | Invariant | Formal Statement |
|----|-----------|------------------|
| INV-1 | Uniqueness | ∀ fqun₁, fqun₂: fqun₁ ≠ fqun₂ ⟹ key(fqun₁) ≠ key(fqun₂) |
| INV-2 | Parsability | ∀ fqun ∈ FQUN: parse(fqun) = Some(components) |
| INV-3 | Zenoh Compatibility | ∀ fqun: is_valid_zenoh_key(to_zenoh_key(fqun)) |
| INV-4 | Determinism | ∀ (layer, type, ns, name): generate(args) ⟹ parse(result).layer = layer |

---

## 3. Level 2: Technical Design

### 3.1 FQUN Format Specification

```
indrajaal/{layer}/{type}/{namespace}/{name}@{node}#{instance}

Examples:
  indrajaal/agent/cybernetic/ooda/controller@indrajaal@app.ts.net#0ABC123def456
  indrajaal/worker/flame/analytics/batch_processor@indrajaal@vm-1.local#0XYZ789abc123
  indrajaal/resource/container/cepaf/indrajaal_db@indrajaal@host.ts.net#0DEF456ghi789
```

### 3.2 Layer and Type Registry

```elixir
@type_registry %{
  agent: [:domain, :cybernetic, :ml, :integration, :observability, :security],
  worker: [:flame, :oban, :broadway, :batch],
  supervisor: [:cluster, :domain, :pool, :sentinel],
  dashboard: [:cepaf, :metrics, :kpi, :admin],
  resource: [:compute, :storage, :network, :container]
}
```

### 3.3 Component Constraints

| Component | Max Length | Charset | Validation |
|-----------|------------|---------|------------|
| Layer | 12 | a-z | Must be in layer set |
| Type | 20 | a-z | Must be in type registry |
| Namespace | 32 | a-z0-9_ | Must start with letter |
| Name | 64 | a-z0-9_ | Must start with letter |
| Node | 128 | Erlang atom chars | Valid Erlang node |
| Instance | 20 | Base62 | Auto-generated |

### 3.4 Zenoh Key Expression Mapping

FQUNs map to Zenoh key expressions for pub/sub:

```
FQUN:  indrajaal/agent/cybernetic/ooda/controller@node.ts.net#01HWX123
Zenoh: indrajaal/agent/cybernetic/ooda/controller/node/node.ts.net/instance/01HWX123

Wildcards:
  indrajaal/agent/**          → All agents
  indrajaal/agent/cybernetic/* → All cybernetic agents
  indrajaal/*/flame/**        → All FLAME resources across layers
```

### 3.5 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FQUN SYSTEM ARCHITECTURE                        │
└─────────────────────────────────────────────────────────────────────────┘

                              ┌─────────────────┐
                              │   FQUN Module   │
                              │   (GenServer)   │
                              └────────┬────────┘
                                       │
         ┌─────────────────────────────┼─────────────────────────────┐
         │                             │                             │
         ▼                             ▼                             ▼
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│   Generation    │         │    Registry     │         │    Lookup       │
│                 │         │    (ETS)        │         │                 │
│ - Layer/Type    │         │                 │         │ - By FQUN       │
│ - Namespace     │         │ - FQUN → Meta   │         │ - By Pattern    │
│ - HLC Instance  │         │ - PID → FQUN    │         │ - By Layer/Type │
└─────────────────┘         │ - Monitors      │         └─────────────────┘
                            └─────────────────┘
                                       │
         ┌─────────────────────────────┼─────────────────────────────┐
         │                             │                             │
         ▼                             ▼                             ▼
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│     Zenoh       │         │    Erlang       │         │     FLAME       │
│   Integration   │         │    Cluster      │         │   Integration   │
│                 │         │                 │         │                 │
│ - Key mapping   │         │ - Node naming   │         │ - Pool tracking │
│ - Pub/Sub       │         │ - Distribution  │         │ - Runner FQUNs  │
│ - Discovery     │         │ - RPC routing   │         │ - Auto cleanup  │
└─────────────────┘         └─────────────────┘         └─────────────────┘
```

---

## 4. Level 3: Implementation Specification

### 4.1 Core Module: `Indrajaal.Distributed.FQUN`

**Location**: `lib/indrajaal/distributed/fqun.ex`

#### 4.1.1 Public API

```elixir
# Generation
@spec generate(layer, type, namespace, name, opts) :: {:ok, fqun} | {:error, term}
@spec generate_for_process(layer, type, namespace, name, pid, opts) :: {:ok, fqun} | {:error, term}

# Parsing
@spec parse(fqun) :: {:ok, components} | {:error, :invalid_fqun}
@spec valid?(fqun) :: boolean

# Registry
@spec register(fqun, metadata) :: :ok | {:error, term}
@spec unregister(fqun) :: :ok
@spec lookup(fqun) :: {:ok, metadata} | {:error, :not_found}

# Discovery
@spec find(pattern) :: [fqun]
@spec find_by_layer(layer) :: [fqun]
@spec find_by_type(layer, type) :: [fqun]
@spec all() :: [fqun]

# Zenoh Interop
@spec to_zenoh_key(fqun) :: String.t()
@spec from_zenoh_key(key) :: {:ok, fqun} | {:error, :invalid_key}

# Statistics
@spec stats() :: map
```

#### 4.1.2 Internal State

```elixir
# ETS Tables
:fqun_registry    # {fqun, metadata} - primary registry
:fqun_reverse     # {pid, fqun} - reverse lookup for process cleanup

# GenServer State
%{
  monitors: %{reference => {fqun, pid}}  # Process monitors for auto-cleanup
}
```

### 4.2 HLC Integration

```elixir
defp generate_instance do
  # Use HLC for causal ordering
  timestamp = case HLC.now() do
    {:ok, ts} -> ts
    _ -> System.system_time(:nanosecond)
  end

  # Base62 encode for compactness + random suffix
  suffix = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  "#{base62_encode(timestamp)}#{suffix}"
end
```

### 4.3 Process Lifecycle Integration

```elixir
def generate_for_process(layer, type, namespace, name, pid, opts) do
  with {:ok, fqun} <- generate(layer, type, namespace, name, opts) do
    GenServer.call(__MODULE__, {:link_process, fqun, pid})
    {:ok, fqun}
  end
end

# When process dies, FQUN is automatically unregistered
def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
  case Map.get(state.monitors, ref) do
    {fqun, ^pid} ->
      :ets.delete(@registry_table, fqun)
      :ets.delete(@reverse_table, pid)
      {:noreply, %{state | monitors: Map.delete(state.monitors, ref)}}
    _ ->
      {:noreply, state}
  end
end
```

---

## 5. Level 4: Integration Architecture

### 5.1 System Integration Matrix

| System Component | Integration Point | FQUN Usage | STAMP Constraint |
|------------------|-------------------|------------|------------------|
| **Elixir Processes** | GenServer start | Auto-register on init | SC-DIST-001 |
| **Agent Mesh** | BaseAgent behaviour | FQUN in heartbeats | SC-AGENT-001 |
| **Worker Pool** | Worker supervisor | Pool FQUN + worker FQUNs | SC-DIST-002 |
| **Zenoh Pub/Sub** | Key expressions | FQUN → Zenoh key mapping | SC-DIST-003 |
| **Erlang Cluster** | Node naming | Node component extraction | SC-CLU-001 |
| **FLAME Pools** | Runner lifecycle | Runner FQUNs, auto-cleanup | SC-FLAME-001 |
| **Container (CEPAF)** | Container ops | Container resource FQUNs | SC-CNT-009 |
| **Dashboard** | Resource display | FQUN-based navigation | SC-DASH-001 |
| **Cortex** | Sensor identification | Sensor FQUNs | SC-CTX-001 |
| **Sentinel** | Node tracking | Node resource FQUNs | SC-CLU-002 |
| **Fractal Logger** | Log correlation | Source FQUN in log events | SC-LOG-001 |
| **Observability** | Telemetry events | FQUN as span attribute | SC-OBS-069 |

### 5.2 Elixir Process Integration

```elixir
# In any GenServer
def init(opts) do
  {:ok, fqun} = FQUN.generate_for_process(
    :worker,
    :flame,
    "analytics",
    "processor_1",
    self()
  )

  state = %{fqun: fqun, ...}
  {:ok, state}
end

# FQUN automatically unregistered when process terminates
```

### 5.3 Zenoh Integration

```elixir
# Publishing state with FQUN
def publish_state(state) do
  zenoh_key = FQUN.to_zenoh_key(state.fqun)
  # "indrajaal/agent/cybernetic/ooda/controller/node/app.ts.net/instance/01HWX"

  ZenohCoordinator.publish(zenoh_key, state_payload)
end

# Subscribing to patterns
def subscribe_to_agents do
  ZenohCoordinator.subscribe("indrajaal/agent/**", fn key, payload ->
    {:ok, fqun} = FQUN.from_zenoh_key(key)
    handle_agent_update(fqun, payload)
  end)
end
```

### 5.4 FLAME Integration

```elixir
# FLAME runner with FQUN tracking
defmodule MyFLAMERunner do
  use FLAME.Runner

  def run(args) do
    # Generate FQUN for this runner instance
    {:ok, fqun} = FQUN.generate_for_process(
      :worker,
      :flame,
      "intelligence",
      "model_inference",
      self()
    )

    # FQUN available for tracing, logging, routing
    execute_with_tracing(fqun, args)
  end
end
```

### 5.5 Cluster Integration

```elixir
# Node joins cluster
def handle_nodeup(node) do
  {:ok, fqun} = FQUN.generate(
    :resource,
    :compute,
    "cluster",
    node_to_name(node),
    node: node
  )

  FQUN.register(fqun, %{type: :erlang_node, joined_at: DateTime.utc_now()})
end

# Node leaves cluster
def handle_nodedown(node) do
  fquns = FQUN.find("indrajaal/**/cluster/*@#{node}#*")
  Enum.each(fquns, &FQUN.unregister/1)
end
```

### 5.6 Container (CEPAF) Integration

```elixir
# When container starts
def container_started(name, id, image) do
  {:ok, fqun} = FQUN.generate(
    :resource,
    :container,
    "cepaf",
    name
  )

  FQUN.register(fqun, %{
    container_id: id,
    image: image,
    started_at: DateTime.utc_now()
  })

  # Publish to Zenoh for mesh visibility
  ZenohCoordinator.publish_coord("cepaf/container/started", %{fqun: fqun})
end
```

---

## 6. Level 5: Operational Details

### 6.1 Performance Characteristics

| Operation | Complexity | Latency (p99) | Notes |
|-----------|------------|---------------|-------|
| generate | O(1) | < 50μs | HLC + random generation |
| register | O(1) | < 100μs | ETS insert |
| lookup | O(1) | < 10μs | ETS lookup |
| find (pattern) | O(n) | < 1ms | Regex scan of registry |
| find_by_layer | O(n) | < 500μs | Optimized prefix match |
| to_zenoh_key | O(1) | < 5μs | String transformation |

### 6.2 Memory Usage

```
Per FQUN Entry:
  - Key (FQUN string): ~100-150 bytes
  - Metadata map: ~200-500 bytes
  - Total: ~300-650 bytes per entry

For 10,000 entries: ~3-6.5 MB
```

### 6.3 Failure Modes and Recovery

| Failure Mode | Detection | Recovery |
|--------------|-----------|----------|
| Process crash | :DOWN monitor | Auto-unregister FQUN |
| Node crash | nodedown event | Bulk unregister node FQUNs |
| ETS corruption | Supervisor restart | Registry rebuild from processes |
| HLC drift | Periodic sync | HLC synchronization protocol |

### 6.4 Monitoring and Alerting

```elixir
# Telemetry events emitted
[:indrajaal, :fqun, :generate, :start | :stop | :exception]
[:indrajaal, :fqun, :register, :start | :stop | :exception]
[:indrajaal, :fqun, :lookup, :start | :stop | :exception]
[:indrajaal, :fqun, :cleanup, :process_down]

# Metrics to monitor
- fqun_registry_size (gauge)
- fqun_generation_latency (histogram)
- fqun_lookup_latency (histogram)
- fqun_process_cleanups (counter)
```

### 6.5 Configuration

```elixir
# config/config.exs
config :indrajaal, Indrajaal.Distributed.FQUN,
  # Enable process monitoring for auto-cleanup
  auto_cleanup: true,

  # Maximum registry size (for memory protection)
  max_entries: 100_000,

  # Telemetry emission
  telemetry_enabled: true,

  # HLC configuration
  hlc_drift_tolerance_ms: 1000
```

---

## 7. Test Plan

### 7.1 Test Categories (TDG Methodology)

| Category | Test Count | Coverage Target |
|----------|------------|-----------------|
| Unit Tests | 25 | 100% functions |
| Property Tests | 8 | Invariants |
| Integration Tests | 12 | All 12 integrations |
| Performance Tests | 5 | Latency SLAs |
| Chaos Tests | 3 | Failure recovery |

### 7.2 Unit Test Specification

```elixir
# test/indrajaal/distributed/fqun_test.exs

describe "generate/4" do
  test "generates valid FQUN for all layer/type combinations"
  test "rejects invalid layer"
  test "rejects invalid type for layer"
  test "rejects invalid namespace format"
  test "rejects invalid name format"
  test "includes correct node component"
  test "instance is unique per call"
end

describe "parse/1" do
  test "parses valid FQUN into components"
  test "returns error for malformed FQUN"
  test "handles edge cases (max length, special chars)"
end

describe "registry operations" do
  test "register/lookup round-trip"
  test "unregister removes entry"
  test "duplicate registration fails"
  test "process link auto-unregisters on exit"
end

describe "discovery" do
  test "find with exact pattern"
  test "find with wildcard *"
  test "find with globstar **"
  test "find_by_layer returns correct subset"
  test "find_by_type filters correctly"
end

describe "zenoh interop" do
  test "to_zenoh_key produces valid key expression"
  test "from_zenoh_key inverts to_zenoh_key"
  test "zenoh key supports subscriptions"
end
```

### 7.3 Property Tests

```elixir
# test/indrajaal/distributed/fqun_property_test.exs

property "generated FQUNs are always unique" do
  forall {layer, type, ns, name} <- fqun_components() do
    {:ok, fqun1} = FQUN.generate(layer, type, ns, name)
    {:ok, fqun2} = FQUN.generate(layer, type, ns, name)
    fqun1 != fqun2
  end
end

property "parse is inverse of generate" do
  forall {layer, type, ns, name} <- fqun_components() do
    {:ok, fqun} = FQUN.generate(layer, type, ns, name)
    {:ok, components} = FQUN.parse(fqun)
    components.layer == layer and components.type == type
  end
end

property "zenoh key conversion is bijective" do
  forall fqun <- valid_fqun() do
    key = FQUN.to_zenoh_key(fqun)
    {:ok, recovered} = FQUN.from_zenoh_key(key)
    recovered == fqun
  end
end
```

### 7.4 Integration Test Matrix

| Integration | Test File | Assertions |
|-------------|-----------|------------|
| Agent Mesh | agent_mesh_fqun_test.exs | Agents register FQUNs on start |
| Worker Pool | worker_pool_fqun_test.exs | Workers discoverable by pattern |
| Zenoh | zenoh_fqun_test.exs | Pub/sub works with FQUN keys |
| FLAME | flame_fqun_test.exs | Runners auto-cleanup on exit |
| Cluster | cluster_fqun_test.exs | Node FQUNs track membership |
| CEPAF | cepaf_fqun_test.exs | Containers have resource FQUNs |

### 7.5 Performance Test Specification

```elixir
# test/performance/fqun_performance_test.exs

test "generate latency < 100μs p99" do
  latencies = Enum.map(1..10_000, fn _ ->
    {time, _} = :timer.tc(fn -> FQUN.generate(:agent, :cybernetic, "test", "perf") end)
    time
  end)

  p99 = Enum.at(Enum.sort(latencies), 9900)
  assert p99 < 100
end

test "lookup latency < 20μs p99" do
  # Setup: register 10,000 FQUNs
  fquns = setup_registry(10_000)

  latencies = Enum.map(fquns, fn fqun ->
    {time, _} = :timer.tc(fn -> FQUN.lookup(fqun) end)
    time
  end)

  p99 = Enum.at(Enum.sort(latencies), 9900)
  assert p99 < 20
end
```

---

## 8. Usability Guidelines

### 8.1 When to Use FQUNs

| Resource Type | Use FQUN? | Pattern |
|---------------|-----------|---------|
| Long-lived GenServer | YES | generate_for_process in init/1 |
| Short-lived Task | MAYBE | Only if needs mesh visibility |
| FLAME Runner | YES | Track across node boundaries |
| Container | YES | Resource FQUN for lifecycle |
| Network Connection | YES | Resource FQUN for monitoring |
| Cache Entry | NO | Use application-level key |
| Database Record | NO | Use primary key |

### 8.2 Best Practices

1. **Generate Early**: Generate FQUN in process init/1, not later
2. **Use generate_for_process**: Automatic cleanup on process death
3. **Include in Logs**: Add `fqun: state.fqun` to all log metadata
4. **Publish to Zenoh**: Make resources discoverable via state publication
5. **Consistent Naming**: Use lowercase, underscores, meaningful names

### 8.3 Anti-Patterns

```elixir
# BAD: Generating FQUN without registration
fqun = "indrajaal/agent/custom/ns/name@node#123"  # Manual construction

# GOOD: Using API
{:ok, fqun} = FQUN.generate(:agent, :cybernetic, "ns", "name")

# BAD: Not linking to process
{:ok, fqun} = FQUN.generate(:worker, :flame, "ns", "name")
# Process exits, FQUN orphaned!

# GOOD: Linking to process
{:ok, fqun} = FQUN.generate_for_process(:worker, :flame, "ns", "name", self())
# Auto-cleanup on exit

# BAD: Ignoring layer/type constraints
{:ok, fqun} = FQUN.generate(:agent, :invalid_type, "ns", "name")
# Returns {:error, {:invalid_type, :invalid_type, valid_types}}

# GOOD: Using registered types
{:ok, fqun} = FQUN.generate(:agent, :cybernetic, "ns", "name")
```

### 8.4 Common Patterns

#### Pattern 1: Agent with FQUN

```elixir
defmodule MyAgent do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    {:ok, fqun} = FQUN.generate_for_process(
      :agent,
      :domain,
      opts[:namespace],
      opts[:name],
      self()
    )

    {:ok, %{fqun: fqun, ...}}
  end

  # Include FQUN in all logs
  def handle_call(:process, _from, state) do
    Logger.info("Processing request", fqun: state.fqun)
    ...
  end
end
```

#### Pattern 2: Resource Discovery

```elixir
# Find all FLAME workers in analytics namespace
workers = FQUN.find("indrajaal/worker/flame/analytics/**")

# Find all agents on a specific node
node_agents = FQUN.find("indrajaal/agent/**@#{node}#*")

# Find all resources of a type
containers = FQUN.find_by_type(:resource, :container)
```

#### Pattern 3: Zenoh State Publication

```elixir
def publish_state(state) do
  zenoh_key = FQUN.to_zenoh_key(state.fqun)

  ZenohCoordinator.publish(zenoh_key, %{
    fqun: state.fqun,
    status: state.status,
    metrics: get_metrics(state),
    timestamp: DateTime.utc_now()
  })
end
```

---

## 9. Appendices

### Appendix A: STAMP Constraints

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-DIST-001 | All dynamic resources MUST have FQUN | Enforced in generate/4 |
| SC-DIST-002 | FQUNs MUST be Zenoh key-expression compatible | Validated in to_zenoh_key/1 |
| SC-DIST-003 | FQUNs MUST be deterministically derivable | Layer/Type/Namespace/Name fixed |
| SC-DIST-004 | FQUN registry MUST support mesh-wide lookup | Zenoh integration |

### Appendix B: AOR Rules

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-FQUN-001 | Generate FQUN in init/1 | Documentation, review |
| AOR-FQUN-002 | Use generate_for_process for GenServers | Lint rule |
| AOR-FQUN-003 | Include FQUN in log metadata | Logger config |
| AOR-FQUN-004 | Publish FQUN state to Zenoh | BaseAgent behaviour |

### Appendix C: Mathematical Proofs

#### C.1 Uniqueness Guarantee

Given FQUN instance = Base62(HLC) ⊕ Random(4 bytes):

- HLC provides nanosecond precision: 10^9 unique values per second
- Random suffix: 2^32 = 4.3 × 10^9 possibilities
- Combined: 10^9 × 4.3 × 10^9 = 4.3 × 10^18 unique instances per second
- P(collision in 1 billion FQUNs) < 10^-9

#### C.2 Discovery Completeness

For pattern P and registry R:
```
find(P) = {fqun ∈ R : matches(P, fqun)}
```

Since we scan all entries: ∀ fqun ∈ R: matches(P, fqun) ⟹ fqun ∈ find(P)

### Appendix D: Version History Template

For all future updates, use this template:

```markdown
## Version X.Y.Z - YYYY-MM-DD

### Added
- New feature or capability

### Changed
- Modification to existing behavior

### Fixed
- Bug fix

### Deprecated
- Feature marked for removal

### Removed
- Feature removed

### Security
- Security-related changes

### Migration
- Required migration steps
```

---

**Document End**

*This specification is maintained under version control. All changes must be reviewed and approved before merging.*
