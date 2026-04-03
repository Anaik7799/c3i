# Runtime System Configuration & Modularity Techniques

**Date**: 2026-01-02T12:00:00+01:00
**Author**: Claude Opus 4.5
**Category**: Architecture / Design Patterns
**Tags**: configuration, modularity, dependency-injection, OTP, feature-flags

## Executive Summary

This journal documents techniques for making runtime systems configurable and modular, with specific focus on Elixir/OTP patterns applicable to the Indrajaal holon architecture.

## 1. Dependency Injection (DI)

Dependency Injection is a software design pattern that supplies external dependencies to a component rather than allowing the component to create them. This is a form of Inversion of Control (IoC).

### Key Benefits
- **Reduced Coupling**: Systems become more modular, easier maintenance and scalability
- **Increased Flexibility**: Changing dependencies doesn't require changes to dependent components
- **Improved Testability**: Dependencies can be easily mocked or stubbed

### Elixir-Specific Techniques

| Technique | Description |
|-----------|-------------|
| **Constructor Injection** | Pass dependencies as function/process arguments |
| **Module Attributes** | `@impl_module Application.compile_env(:app, :module)` |
| **Behaviour Callbacks** | Define interface, swap implementations |
| **Process Config** | Pass deps via GenServer `init/1` opts |

### Example Pattern

```elixir
# Config-based injection
defmodule MyService do
  @guardian Application.compile_env(:app, :guardian_module, Guardian)

  def submit(proposal), do: @guardian.validate(proposal)
end
```

### Elixir-Specific Enhancements
- **Pattern Matching**: Destructure and validate dependencies
- **Immutable Data**: Ensure dependencies are not modified unexpectedly
- **Concurrency Model**: Manage dependencies in concurrent environment

## 2. Feature Flags / Toggles

| Type | Use Case |
|------|----------|
| **Release Toggles** | Incomplete features hidden in prod |
| **Experiment Toggles** | A/B testing, canary releases |
| **Ops Toggles** | Circuit breakers, degraded mode |
| **Permission Toggles** | Role-based feature access |

## 3. Configuration Layers

```
┌─────────────────────────────────────────┐
│ Runtime (env vars, runtime.exs)         │  ← Hot reload
├─────────────────────────────────────────┤
│ Release (rel/env.sh, vm.args)           │  ← Deploy time
├─────────────────────────────────────────┤
│ Compile (config.exs, Application.compile_env) │  ← Build time
├─────────────────────────────────────────┤
│ Default (module attributes, specs)      │  ← Code time
└─────────────────────────────────────────┘
```

### OTP Application Environment
Each OTP application has an environment that stores application-specific configuration by key. This allows:
- Default values in application definition
- Override by other applications as needed
- Runtime updates via `Application.put_env/3`

### Release Configuration Files
| File | Purpose |
|------|---------|
| `config/config.exs` | Compile-time config |
| `config/runtime.exs` | Runtime config (loaded on boot) |
| `rel/env.sh.eex` | Shell environment for releases |
| `rel/vm.args.eex` | Erlang VM flags |

## 4. Plugin/Extension Architecture

| Pattern | Mechanism |
|---------|-----------|
| **Behaviour + Registry** | Discover modules implementing behaviour |
| **Protocol Dispatch** | Polymorphism via `defprotocol` |
| **Hook System** | Pre/post callbacks for extensibility |
| **Event Sourcing** | Decouple producers/consumers |

## 5. OTP Patterns for Modularity

| Pattern | Description |
|---------|-------------|
| **Supervision Trees** | Isolate failure domains |
| **Application Environment** | Per-app config storage |
| **Dynamic Supervisors** | Runtime process spawning |
| **Registry** | Named process discovery |
| **PubSub** | Loose coupling via messages |

## 6. Strategy Pattern

```elixir
# Swap algorithms at runtime
defmodule Compiler do
  def compile(code, strategy \\ &default_strategy/1) do
    strategy.(code)
  end
end
```

## 7. Layered Architecture (Designing Elixir Systems with OTP)

```
┌─────────────────┐
│   Boundary      │  ← External interfaces (changeable)
├─────────────────┤
│   Lifecycle     │  ← OTP processes (configurable)
├─────────────────┤
│   Core          │  ← Pure functions (stable)
├─────────────────┤
│   Data          │  ← Types/structs (immutable)
└─────────────────┘
```

### Layer Responsibilities
- **Boundary**: Phoenix controllers, GraphQL resolvers, CLI - highest change rate
- **Lifecycle**: GenServers, Supervisors, state management - medium change rate
- **Core**: Business logic, pure functions - low change rate
- **Data**: Structs, types, schemas - very low change rate

## 8. Environment-Specific Modules

```elixir
# config/config.exs
config :app, :http_client, HTTPoison

# config/test.exs
config :app, :http_client, HTTPMock

# Usage
@http Application.compile_env(:app, :http_client)
```

## 9. Modern Techniques

| Technique | Description |
|-----------|-------------|
| **Sidecar Pattern** | Separate config/proxy container |
| **Service Mesh** | External configuration plane (Istio, Linkerd) |
| **GitOps** | Config as code in version control |
| **Secrets Management** | Vault, AWS Secrets Manager, SOPS |
| **Hot Code Reload** | OTP release upgrades |
| **12-Factor App** | Config via environment variables |

## 10. Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Hardcoded values | Inflexible, requires recompile | Use config layers |
| Global mutable state | Race conditions, testing hell | Process state, ETS |
| Compile-time for runtime | Can't change without rebuild | Use `runtime.exs` |
| Over-abstraction | YAGNI, complexity | Start simple, evolve |
| Config in code | Mixed concerns | Separate config files |

## 11. Indrajaal Application

### Current Implementation
The Indrajaal project uses several of these techniques:

1. **Prajna Config Module** (`lib/indrajaal/cockpit/prajna/config.ex`)
   - Centralized configuration for all Prajna components
   - Environment-specific profiles (dev, test, prod, sil4)
   - Validation on startup

2. **Guardian Dependency Injection**
   - Configurable guardian module for testing
   - Behaviour-based interface

3. **Feature Flags via Application Environment**
   - Circuit breaker enable/disable
   - Debug logging toggles

4. **Supervision Tree Modularity**
   - Dynamic supervisor for agents
   - Isolated failure domains per domain

### Recommended Enhancements

1. **Configuration Validation** (Sprint 31)
   - Add `ConfigValidator.validate_all!/0`
   - Type-safe configuration with specs

2. **SIL-Level Profiles**
   - Development: Relaxed timeouts
   - Test: Deterministic timing
   - Production: Balanced
   - SIL-6: Strict with redundancy

## References

- [Dependency Injection in Elixir - Software Patterns Lexicon](https://softwarepatternslexicon.com/elixir/creational-design-patterns/dependency-injection-via-module-attributes-and-configurations/)
- [Configuration and Releases - Elixir](https://elixir-lang.org/getting-started/mix-otp/config-and-releases.html)
- [Understanding DI in Elixir - Elixir Merge](https://elixirmerge.com/p/understanding-and-applying-dependency-injection-in-elixir)
- [Configuration Demystified - Elixir School](https://elixirschool.com/blog/configuration-demystified)
- [Using DI in Elixir - AppSignal](https://blog.appsignal.com/2024/05/21/using-dependency-injection-in-elixir.html)
- [Designing Elixir Systems with OTP - Pragmatic Bookshelf](https://pragprog.com/titles/jgotp/designing-elixir-systems-with-otp/)

## STAMP Compliance

| Constraint | Status |
|------------|--------|
| SC-DOC-001 | Documented with WHAT/WHY/CONSTRAINTS |
| SC-GEM-001 | No destructive operations |
| AOR-DOC-001 | Journal format followed |

---

**Generated**: 2026-01-02T12:00:00+01:00
**Framework**: SOPv5.11 + STAMP
