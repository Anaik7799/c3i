# Journal Entry: Configurable Core/Non-Core Architecture Analysis

**Date**: 2026-01-01T15:00:00+01:00
**Author**: Claude Opus 4.5
**Type**: Architecture Analysis
**Status**: Complete

## Context

User requested analysis for making Indrajaal fully configurable at both build-time (static) and runtime (dynamic). The system needs clear separation between core and non-core components, with ability to deploy minimal variants with only core services plus 2-3 additional capabilities.

## Analysis Summary

### Problem Statement

Current Indrajaal architecture has ~50 agents, 10 Ash domains, and numerous modules all compiled and started together. This creates:
1. Large deployment footprint even for small installations
2. No ability to create lightweight edge deployments
3. All-or-nothing capability inclusion
4. Restart required for any configuration change

### Solution: Four-Layer Stratification

#### Layer 0: Immutable Kernel (6 modules)
**Cannot be disabled under any circumstances**
- Guardian (Safety Kernel)
- Constitution Verifier
- ImmutableRegister
- Holon Core
- Founder's Directive Engine
- Regeneration Subsystem

Rationale: These enforce Ψ₀-Ψ₅ constitutional invariants. Disabling any would violate SC-CONST-* constraints.

#### Layer 1: Core Services (6 modules)
**Required for any functional deployment**
- Authentication/Authorization
- Accounts (Users, Tenants)
- Sentinel (Health Monitoring)
- Base Telemetry
- Cluster Coordination
- Configuration Management

Rationale: Even minimal deployments need auth, accounts, and health monitoring.

#### Layer 2: Capability Modules (10 modules)
**Independently deployable business domains**
- Alarms (P0 - most common)
- Devices (P0 - most common)
- Access Control (P0)
- Video (P1)
- Analytics (P1)
- Compliance (P1)
- Communication (P1)
- Shifts (P2)
- Patrol (P2)
- Billing (P2)

Rationale: Business domains can be mixed/matched based on customer needs.

#### Layer 3: Extension Modules (8 modules)
**Optional enhancements**
- AI Copilot / RAG Engine
- Prajna C3I Cockpit
- FLAME Distributed Compute
- Zenoh Mesh Networking
- Knowledge Engine
- Microsoft MCP Integration
- CEPAF F# Bridge

Rationale: Advanced features not needed for basic deployments.

### Build-Time Configurability

#### Approach: Environment Variables + Mix Config

```elixir
config :indrajaal, :capabilities,
  kernel: :immutable,
  alarms: System.get_env("INDRAJAAL_CAP_ALARMS", "true") == "true",
  # ... etc
```

Advantages:
- Standard Elixir pattern
- 12-factor compliant
- Works with CI/CD pipelines
- No code changes for different builds

#### Conditional Compilation Macros

```elixir
defmacro if_capability(cap, do: block) do
  if Application.compile_env(:indrajaal, [:capabilities, cap], false) do
    block
  end
end
```

This allows excluding entire code paths from builds.

#### Build Profiles

Four predefined profiles:
1. **Micro** (256MB) - Edge/IoT, kernel + partial core
2. **Minimal** (512MB) - Small installs, kernel + core
3. **Standard** (1GB) - Medium, kernel + core + alarms/devices/access
4. **Full** (2GB+) - Enterprise, everything

### Runtime Configurability

#### CapabilityManager GenServer

Provides hot-loading capabilities with Guardian approval:

```elixir
CapabilityManager.enable_capability(:video, reason: "Customer upgrade")
# => {:ok, #PID<0.123.0>}

CapabilityManager.disable_capability(:shifts)
# => :ok
```

Key features:
- Guardian approval required (SC-PRAJNA-001)
- Dependency validation
- Reverse dependency checking
- State hibernation before disable (SC-PROM-007)
- Immutable register logging

#### Configuration Hot-Reload

```elixir
Config.HotReload.apply_config(%{
  feature_x: true,
  threshold: 100
})
# Creates rollback point
# Validates no constitutional violations
# Applies changes
# Verifies health
# Auto-rollbacks if health degrades
```

### Dependency Graph

Critical insight: Capabilities have dependencies that must be respected:

```
video -> devices
analytics -> [alarms, devices]
patrol -> [devices, shifts]
ai_copilot -> sentinel
prajna_cockpit -> [sentinel, ai_copilot]
flame_compute -> cluster
knowledge_engine -> ai_copilot
microsoft_mcp -> ai_copilot
```

Cannot enable a capability without its dependencies.
Cannot disable a capability if others depend on it.

### Capability Behaviour

All L2/L3 modules must implement:

```elixir
@callback capability_info() :: %{name, version, layer, dependencies, resources}
@callback init(config) :: {:ok, state} | {:error, reason}
@callback hibernate_state() :: :ok | {:error, term}
@callback restore_state(state) :: :ok | {:error, term}
@callback health_check() :: :healthy | {:degraded, reason} | :unhealthy
@callback shutdown(reason) :: :ok
```

This enables:
- Introspection of capabilities
- Safe enable/disable cycles
- State preservation across disable/enable
- Health monitoring integration

### Deployment Variants

YAML-based variant definitions:

```yaml
variant: standard
layers:
  kernel: enabled
  core: enabled
  capabilities:
    - alarms
    - devices
    - access_control
  extensions: []
resources:
  memory_limit: 1Gi
  cpu_limit: 2
```

Build script generates:
- Mix release for variant
- Podman compose file
- Kubernetes manifests

### New Safety Constraints

| ID | Constraint |
|----|------------|
| SC-CAP-001 | Kernel capabilities CANNOT be disabled |
| SC-CAP-002 | Capability enable REQUIRES Guardian approval |
| SC-CAP-003 | Capability disable REQUIRES dependency check |
| SC-CAP-004 | All capability state changes logged |
| SC-CAP-005 | Hibernation state MUST persist before disable |
| SC-CAP-006 | Health degradation TRIGGERS auto-rollback |

### Implementation Recommendations

1. **Keep single app** (not umbrella) - simpler dependency management
2. **Environment variables + Mix config** - standard pattern
3. **CapabilityManager GenServer** - hot-loading with Guardian
4. **SQLite per capability** - portable state hibernation
5. **Explicit dependency declarations** - in capability_info/0
6. **Mock capabilities in test** - test core without full stack
7. **Variant YAML + generated manifests** - single source of truth

## Decisions Made

1. Four-layer stratification (L0-L3)
2. Kernel is truly immutable - no disable path
3. Guardian approval for all runtime changes
4. State hibernation mandatory before disable
5. Dependency graph enforced at both build and runtime
6. YAML-based variant configuration

## Files Created

1. `docs/architecture/CONFIGURABLE_CORE_NONCORE_ARCHITECTURE.md` - Full specification
2. `journal/2026-01/20260101-1500-configurable-core-noncore-architecture.md` - This entry

## Next Steps

1. Define `Indrajaal.Capability.Behaviour` module
2. Refactor `Application.start/2` for conditional loading
3. Implement `CapabilityManager` GenServer
4. Create variant YAML schema
5. Implement build script
6. Migrate existing domains to implement Behaviour

## Related Documents

- docs/architecture/HOLON_CONSTITUTIONAL_RECONFIGURATION.md
- docs/architecture/HOLON_FOUNDERS_DIRECTIVE.md
- CLAUDE.md sections 1.0 (Axioms), 5.0 (SC-RECONFIG-*)

## Tags

#architecture #configurability #build-time #runtime #capabilities #variants
