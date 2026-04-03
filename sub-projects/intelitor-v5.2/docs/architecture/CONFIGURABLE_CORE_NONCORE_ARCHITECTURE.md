# Configurable Core/Non-Core Architecture for Indrajaal

**Version**: 1.0.0 | **Date**: 2026-01-01 | **Status**: ANALYSIS
**Author**: Claude Opus 4.5 | **Review**: Pending

## Executive Summary

This document defines the architectural approach for making Indrajaal fully configurable at both build-time (static) and runtime (dynamic). The system is stratified into immutable kernel, core services, capability modules, and extension modules - enabling deployment variants from minimal edge installations to full enterprise deployments.

## 1. Design Goals

1. **Minimal Viable Deployment**: Deploy with only kernel + core + 2-3 capabilities
2. **Build-Time Configurability**: Exclude unused code from compiled releases
3. **Runtime Configurability**: Enable/disable capabilities without restart
4. **Constitutional Preservation**: Kernel layer (L0) remains immutable regardless of configuration
5. **Dependency Safety**: Capabilities declare dependencies; system prevents orphan modules

## 2. Component Taxonomy

### 2.1 Layer Stratification

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            LAYER 0: IMMUTABLE KERNEL                        │
│  (Cannot be disabled - Constitutional Invariants Ψ₀-Ψ₅)                     │
├─────────────────────────────────────────────────────────────────────────────┤
│  • Guardian (Safety Kernel)         • ImmutableRegister (Hash Chain)        │
│  • Constitution Verifier            • Founder's Directive Engine            │
│  • Holon Core (SQLite/DuckDB)       • Regeneration Subsystem                │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
┌─────────────────────────────────────┴───────────────────────────────────────┐
│                         LAYER 1: CORE SERVICES                              │
│  (Required for any functional deployment)                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│  • Authentication/Authorization     • Accounts (Users, Tenants)             │
│  • Sentinel (Health Monitoring)     • Base Telemetry/Observability          │
│  • Cluster Coordination             • Configuration Management              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
┌─────────────────────────────────────┴───────────────────────────────────────┐
│                       LAYER 2: CAPABILITY MODULES                           │
│  (Independently deployable business domains)                                │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │   Alarms     │ │   Devices    │ │    Video     │ │  Analytics   │       │
│  │  (P0-HIGH)   │ │  (P0-HIGH)   │ │  (P1-MED)    │ │  (P1-MED)    │       │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │  Compliance  │ │    Shifts    │ │   Patrol     │ │   Billing    │       │
│  │  (P1-MED)    │ │  (P2-LOW)    │ │  (P2-LOW)    │ │  (P2-LOW)    │       │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
┌─────────────────────────────────────┴───────────────────────────────────────┐
│                        LAYER 3: EXTENSION MODULES                           │
│  (Optional enhancements, AI features, integrations)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│  • AI Copilot / RAG Engine          • Microsoft MCP Integration             │
│  • FLAME Distributed Compute        • Advanced Analytics (DuckDB)           │
│  • Prajna C3I Cockpit               • CEPAF F# Bridge                       │
│  • PatternHunter / SymbioticDefense • Zenoh Mesh Networking                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Layer Definitions

| Layer | Name | Configurability | STAMP Constraint |
|-------|------|-----------------|------------------|
| L0 | Immutable Kernel | NEVER disabled | SC-CONST-001 to SC-CONST-006 |
| L1 | Core Services | Stubbed for testing only | SC-RECONFIG-001 |
| L2 | Capability Modules | Build-time & Runtime | SC-RECONFIG-006 |
| L3 | Extension Modules | Build-time & Runtime | SC-RECONFIG-006 |

### 2.3 Module Classification

#### Layer 0: Immutable Kernel (6 modules)
```
lib/indrajaal/
├── guardian/                    # Safety kernel with absolute veto
│   ├── guardian.ex
│   └── safety_kernel.ex
├── constitution/                # Ψ₀-Ψ₅ invariant verification
│   └── verifier.ex
├── core/
│   ├── holon/                   # Holon state management
│   │   ├── core.ex
│   │   ├── founder_directive.ex
│   │   └── immutable_register.ex
│   └── regeneration/            # Self-healing subsystem
│       └── regenerator.ex
```

#### Layer 1: Core Services (6 modules)
```
lib/indrajaal/
├── authentication/              # Auth subsystem
├── authorization/               # RBAC/ABAC
├── accounts/                    # Users, tenants, teams
├── safety/
│   └── sentinel.ex              # Health monitoring
├── observability/               # Base telemetry
└── cluster/                     # Coordination
```

#### Layer 2: Capability Modules (10 modules)
```
lib/indrajaal/
├── alarms/                      # P0 - Alarm processing
├── devices/                     # P0 - Device management
├── access_control/              # P0 - Physical access
├── video/                       # P1 - Video analytics
├── analytics/                   # P1 - Reporting
├── compliance/                  # P1 - Audit/evidence
├── communication/               # P1 - Notifications
├── shifts/                      # P2 - Guard scheduling
├── patrol/                      # P2 - Guard tours
└── billing/                     # P2 - Invoicing
```

#### Layer 3: Extension Modules (8 modules)
```
lib/indrajaal/
├── ai/                          # AI Copilot, RAG
├── cockpit/prajna/              # C3I Cockpit
├── flame/                       # Distributed compute
├── mesh/                        # Zenoh networking
├── knowledge/                   # Vector store, embeddings
├── integrations/
│   ├── microsoft_mcp/           # MS Graph via MCP
│   └── external_apis/           # Third-party integrations
└── cepaf_bridge/                # F# interop
```

## 3. Build-Time Configurability

### 3.1 Mix Configuration Strategy

```elixir
# config/config.exs - Feature Flag Foundation
config :indrajaal, :capabilities,
  # Layer 0 - Always enabled (cannot be disabled)
  kernel: :immutable,

  # Layer 1 - Core (default enabled, can be stubbed for testing)
  authentication: true,
  accounts: true,
  sentinel: true,
  telemetry: true,

  # Layer 2 - Capability Modules (configurable)
  alarms: System.get_env("INDRAJAAL_CAP_ALARMS", "true") == "true",
  devices: System.get_env("INDRAJAAL_CAP_DEVICES", "true") == "true",
  access_control: System.get_env("INDRAJAAL_CAP_ACCESS", "true") == "true",
  video: System.get_env("INDRAJAAL_CAP_VIDEO", "false") == "true",
  analytics: System.get_env("INDRAJAAL_CAP_ANALYTICS", "false") == "true",
  compliance: System.get_env("INDRAJAAL_CAP_COMPLIANCE", "false") == "true",
  communication: System.get_env("INDRAJAAL_CAP_COMM", "false") == "true",
  shifts: System.get_env("INDRAJAAL_CAP_SHIFTS", "false") == "true",
  patrol: System.get_env("INDRAJAAL_CAP_PATROL", "false") == "true",
  billing: System.get_env("INDRAJAAL_CAP_BILLING", "false") == "true",

  # Layer 3 - Extensions (optional)
  ai_copilot: System.get_env("INDRAJAAL_EXT_AI", "false") == "true",
  prajna_cockpit: System.get_env("INDRAJAAL_EXT_PRAJNA", "false") == "true",
  flame_compute: System.get_env("INDRAJAAL_EXT_FLAME", "false") == "true",
  zenoh_mesh: System.get_env("INDRAJAAL_EXT_ZENOH", "false") == "true",
  knowledge_engine: System.get_env("INDRAJAAL_EXT_KNOWLEDGE", "false") == "true",
  microsoft_mcp: System.get_env("INDRAJAAL_EXT_MSMCP", "false") == "true",
  cepaf_bridge: System.get_env("INDRAJAAL_EXT_CEPAF", "false") == "true"
```

### 3.2 Conditional Compilation Macros

```elixir
# lib/indrajaal/capability.ex
defmodule Indrajaal.Capability do
  @moduledoc """
  Compile-time capability detection macros.

  WHAT: Provides macros for conditional module inclusion
  WHY: Enables minimal builds without unused code
  CONSTRAINTS: SC-RECONFIG-001 (Minimal Change)
  """

  @doc """
  Conditionally compile a block if capability is enabled.

  ## Example

      require Indrajaal.Capability

      Indrajaal.Capability.if_capability :video do
        def process_video(frame), do: VideoProcessor.analyze(frame)
      end
  """
  defmacro if_capability(cap, do: block) do
    if Application.compile_env(:indrajaal, [:capabilities, cap], false) do
      block
    end
  end

  @doc """
  Check if capability is enabled at compile time.
  """
  defmacro capability_enabled?(cap) do
    quote do
      Application.compile_env(:indrajaal, [:capabilities, unquote(cap)], false)
    end
  end

  @doc """
  Return the capability manifest for introspection.
  """
  def manifest do
    %{
      kernel: [
        :guardian,
        :constitution,
        :immutable_register,
        :holon_core,
        :founder_directive,
        :regeneration
      ],
      core: [
        :authentication,
        :authorization,
        :accounts,
        :sentinel,
        :telemetry,
        :cluster
      ],
      capabilities: [
        :alarms,
        :devices,
        :access_control,
        :video,
        :analytics,
        :compliance,
        :communication,
        :shifts,
        :patrol,
        :billing
      ],
      extensions: [
        :ai_copilot,
        :prajna_cockpit,
        :flame_compute,
        :zenoh_mesh,
        :knowledge_engine,
        :microsoft_mcp,
        :cepaf_bridge
      ]
    }
  end

  @doc """
  Get all enabled capabilities for current build.
  """
  def enabled_capabilities do
    config = Application.get_all_env(:indrajaal)[:capabilities] || %{}

    for {cap, enabled} <- config, enabled == true, do: cap
  end

  @doc """
  Check if a capability's dependencies are satisfied.
  """
  def dependencies_satisfied?(cap) do
    deps = capability_dependencies()[cap] || []
    enabled = enabled_capabilities()

    Enum.all?(deps, &(&1 in enabled))
  end

  defp capability_dependencies do
    %{
      # L2 dependencies
      video: [:devices],
      analytics: [:alarms, :devices],
      patrol: [:devices, :shifts],
      billing: [:accounts],

      # L3 dependencies
      ai_copilot: [:sentinel],
      prajna_cockpit: [:sentinel, :ai_copilot],
      flame_compute: [:cluster],
      knowledge_engine: [:ai_copilot],
      microsoft_mcp: [:ai_copilot]
    }
  end
end
```

### 3.3 Umbrella App Structure (Alternative Approach)

For organizations preferring stronger isolation, an umbrella structure can be used:

```
indrajaal/
├── apps/
│   ├── indrajaal_kernel/        # L0: Immutable (always included)
│   │   ├── lib/
│   │   │   ├── guardian/
│   │   │   ├── constitution/
│   │   │   ├── immutable_register/
│   │   │   ├── holon_core/
│   │   │   └── founder_directive/
│   │   ├── mix.exs
│   │   └── README.md
│   │
│   ├── indrajaal_core/          # L1: Core Services
│   │   ├── lib/
│   │   │   ├── authentication/
│   │   │   ├── authorization/
│   │   │   ├── accounts/
│   │   │   ├── sentinel/
│   │   │   ├── telemetry/
│   │   │   └── cluster/
│   │   ├── mix.exs
│   │   └── README.md
│   │
│   ├── indrajaal_alarms/        # L2: Capability
│   ├── indrajaal_devices/       # L2: Capability
│   ├── indrajaal_access/        # L2: Capability
│   ├── indrajaal_video/         # L2: Capability
│   ├── indrajaal_analytics/     # L2: Capability
│   ├── indrajaal_compliance/    # L2: Capability
│   ├── indrajaal_communication/ # L2: Capability
│   ├── indrajaal_shifts/        # L2: Capability
│   ├── indrajaal_patrol/        # L2: Capability
│   ├── indrajaal_billing/       # L2: Capability
│   │
│   ├── indrajaal_ai/            # L3: Extension
│   ├── indrajaal_prajna/        # L3: Extension
│   ├── indrajaal_flame/         # L3: Extension
│   ├── indrajaal_mesh/          # L3: Extension
│   ├── indrajaal_knowledge/     # L3: Extension
│   ├── indrajaal_integrations/  # L3: Extension
│   │
│   └── indrajaal_web/           # Web layer (routes conditionally)
│
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── test.exs
│   ├── prod.exs
│   └── variants/                # Variant-specific configs
│       ├── minimal.exs
│       ├── standard.exs
│       └── full.exs
│
└── mix.exs                      # Umbrella root
```

### 3.4 Build Profiles

```elixir
# mix.exs - Build profiles for different deployments
defmodule Indrajaal.MixProject do
  use Mix.Project

  @version "21.1.0"

  def project do
    [
      app: :indrajaal,
      version: @version,
      elixir: "~> 1.19",
      deps: deps(),
      releases: releases()
    ]
  end

  defp deps do
    base_deps() ++
      profile_deps(profile())
  end

  defp base_deps do
    [
      # Always included - kernel and core dependencies
      {:phoenix, "~> 1.8"},
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:exqlite, "~> 0.20"},      # SQLite for holon state
      {:duckdbex, "~> 0.3"},      # DuckDB for history
      {:guardian, "~> 2.3"},      # Auth (different from our Guardian!)
      {:oban, "~> 2.18"},
      {:telemetry, "~> 1.2"},
      {:jason, "~> 1.4"}
    ]
  end

  defp profile_deps(:minimal), do: []

  defp profile_deps(:standard) do
    [
      # L2 capabilities for standard deployment
      {:timex, "~> 3.7"},         # For shifts
      {:geo, "~> 3.6"}            # For patrol
    ]
  end

  defp profile_deps(:full) do
    profile_deps(:standard) ++
    [
      # L3 extensions
      {:bumblebee, "~> 0.5"},     # AI/ML
      {:nx, "~> 0.7"},            # Numerical computing
      {:explorer, "~> 0.8"},      # DataFrames
      {:flame, "~> 0.3"},         # Distributed compute
      {:zenohex, "~> 0.1"}        # Zenoh mesh
    ]
  end

  defp profile do
    case System.get_env("INDRAJAAL_PROFILE", "standard") do
      "minimal" -> :minimal
      "standard" -> :standard
      "full" -> :full
      _ -> :standard
    end
  end

  defp releases do
    [
      indrajaal_minimal: [
        include_executables_for: [:unix],
        applications: minimal_apps(),
        steps: [:assemble, :tar]
      ],
      indrajaal_standard: [
        include_executables_for: [:unix],
        applications: standard_apps(),
        steps: [:assemble, :tar]
      ],
      indrajaal_full: [
        include_executables_for: [:unix],
        applications: full_apps(),
        steps: [:assemble, :tar]
      ]
    ]
  end

  defp minimal_apps do
    [
      indrajaal: :permanent,
      # Only kernel + core, no optional capabilities
    ]
  end

  defp standard_apps do
    minimal_apps() ++
    [
      # Add standard capabilities
    ]
  end

  defp full_apps do
    standard_apps() ++
    [
      # Add all extensions
    ]
  end
end
```

## 4. Runtime Configurability

### 4.1 Dynamic Supervision Tree

```elixir
# lib/indrajaal/application.ex
defmodule Indrajaal.Application do
  use Application

  @moduledoc """
  Main application with conditional capability loading.

  WHAT: Starts supervision tree based on enabled capabilities
  WHY: Enables runtime-configurable deployments
  CONSTRAINTS: SC-RECONFIG-001, SC-CONST-007
  """

  def start(_type, _args) do
    children =
      kernel_children() ++      # Always started (L0)
      core_children() ++        # Always started (L1)
      capability_children() ++  # Conditionally started (L2)
      extension_children()      # Conditionally started (L3)

    opts = [strategy: :one_for_one, name: Indrajaal.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        log_startup_manifest()
        {:ok, pid}
      error ->
        error
    end
  end

  # L0: Immutable Kernel - ALWAYS started, CANNOT be disabled
  defp kernel_children do
    [
      # Guardian MUST start first - it validates all other startups
      {Indrajaal.Guardian, []},
      {Indrajaal.Constitution.Verifier, []},
      {Indrajaal.ImmutableRegister, []},
      {Indrajaal.Holon.Core, []},
      {Indrajaal.Holon.FounderDirective, []},
      {Indrajaal.Regeneration.Supervisor, []}
    ]
  end

  # L1: Core Services - ALWAYS started (can be mocked in test)
  defp core_children do
    [
      {Indrajaal.Authentication.Supervisor, []},
      {Indrajaal.Authorization.Supervisor, []},
      {Indrajaal.Accounts.Supervisor, []},
      {Indrajaal.Safety.Sentinel, []},
      {Indrajaal.Telemetry.Supervisor, []},
      {Indrajaal.Cluster.Supervisor, []}
    ]
  end

  # L2: Capabilities - CONDITIONALLY started based on config
  defp capability_children do
    []
    |> maybe_add(:alarms, {Indrajaal.Alarms.Supervisor, []})
    |> maybe_add(:devices, {Indrajaal.Devices.Supervisor, []})
    |> maybe_add(:access_control, {Indrajaal.AccessControl.Supervisor, []})
    |> maybe_add(:video, {Indrajaal.Video.Supervisor, []})
    |> maybe_add(:analytics, {Indrajaal.Analytics.Supervisor, []})
    |> maybe_add(:compliance, {Indrajaal.Compliance.Supervisor, []})
    |> maybe_add(:communication, {Indrajaal.Communication.Supervisor, []})
    |> maybe_add(:shifts, {Indrajaal.Shifts.Supervisor, []})
    |> maybe_add(:patrol, {Indrajaal.Patrol.Supervisor, []})
    |> maybe_add(:billing, {Indrajaal.Billing.Supervisor, []})
  end

  # L3: Extensions - CONDITIONALLY started based on config
  defp extension_children do
    []
    |> maybe_add(:ai_copilot, {Indrajaal.AI.Supervisor, []})
    |> maybe_add(:prajna_cockpit, {Indrajaal.Cockpit.Prajna.Supervisor, []})
    |> maybe_add(:flame_compute, {Indrajaal.FLAME.Supervisor, []})
    |> maybe_add(:zenoh_mesh, {Indrajaal.Mesh.Supervisor, []})
    |> maybe_add(:knowledge_engine, {Indrajaal.Knowledge.Supervisor, []})
    |> maybe_add(:microsoft_mcp, {Indrajaal.Integrations.MicrosoftMCP.Supervisor, []})
    |> maybe_add(:cepaf_bridge, {Indrajaal.CepafBridge.Supervisor, []})
  end

  defp maybe_add(children, cap, child_spec) do
    if capability_enabled?(cap) and dependencies_satisfied?(cap) do
      [child_spec | children]
    else
      if capability_enabled?(cap) and not dependencies_satisfied?(cap) do
        Logger.warning("Capability #{cap} enabled but dependencies not satisfied, skipping")
      end
      children
    end
  end

  defp capability_enabled?(cap) do
    Application.get_env(:indrajaal, :capabilities, %{})[cap] == true
  end

  defp dependencies_satisfied?(cap) do
    Indrajaal.Capability.dependencies_satisfied?(cap)
  end

  defp log_startup_manifest do
    enabled = Indrajaal.Capability.enabled_capabilities()
    Logger.info("Indrajaal started with capabilities: #{inspect(enabled)}")

    # Record to immutable register
    Indrajaal.ImmutableRegister.append(%{
      type: :system_startup,
      timestamp: DateTime.utc_now(),
      capabilities: enabled,
      version: Application.spec(:indrajaal, :vsn)
    })
  end
end
```

### 4.2 Runtime Capability Manager

```elixir
# lib/indrajaal/capability_manager.ex
defmodule Indrajaal.CapabilityManager do
  @moduledoc """
  Runtime capability enable/disable with Guardian approval.

  WHAT: Manages hot-loading and unloading of capability modules
  WHY: Enables runtime reconfiguration without restart
  CONSTRAINTS: SC-RECONFIG-001, SC-CONST-007 (Guardian veto)
  """
  use GenServer

  require Logger

  # Client API

  @doc """
  Enable a capability at runtime.
  Requires Guardian approval.
  """
  def enable_capability(cap, opts \\ []) do
    GenServer.call(__MODULE__, {:enable, cap, opts}, 30_000)
  end

  @doc """
  Disable a capability at runtime.
  Cannot disable kernel capabilities.
  """
  def disable_capability(cap, opts \\ []) do
    GenServer.call(__MODULE__, {:disable, cap, opts}, 30_000)
  end

  @doc """
  List all capabilities and their status.
  """
  def list_capabilities do
    GenServer.call(__MODULE__, :list)
  end

  @doc """
  Get detailed status for a specific capability.
  """
  def capability_status(cap) do
    GenServer.call(__MODULE__, {:status, cap})
  end

  @doc """
  Check if capability can be enabled (dependencies met).
  """
  def can_enable?(cap) do
    GenServer.call(__MODULE__, {:can_enable, cap})
  end

  # Server Implementation

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    state = %{
      enabled: Indrajaal.Capability.enabled_capabilities(),
      supervisors: %{},
      history: []
    }
    {:ok, state}
  end

  def handle_call({:enable, cap, opts}, _from, state) do
    cond do
      cap in kernel_capabilities() ->
        {:reply, {:ok, :already_enabled_kernel}, state}

      cap in state.enabled ->
        {:reply, {:ok, :already_enabled}, state}

      not dependencies_satisfied?(cap, state.enabled) ->
        missing = missing_dependencies(cap, state.enabled)
        {:reply, {:error, {:missing_dependencies, missing}}, state}

      true ->
        # Guardian approval required (SC-PRAJNA-001)
        proposal = %{
          action: :enable_capability,
          capability: cap,
          reason: opts[:reason] || "Runtime enable request",
          requestor: opts[:requestor] || :system
        }

        case Indrajaal.Guardian.submit_proposal(proposal) do
          {:ok, :approved} ->
            case do_enable_capability(cap) do
              {:ok, pid} ->
                new_state = %{state |
                  enabled: [cap | state.enabled],
                  supervisors: Map.put(state.supervisors, cap, pid),
                  history: [{:enabled, cap, DateTime.utc_now()} | state.history]
                }
                log_to_register(:capability_enabled, cap)
                {:reply, {:ok, pid}, new_state}

              {:error, reason} ->
                {:reply, {:error, reason}, state}
            end

          {:veto, reason, _fallback} ->
            Logger.warning("Guardian vetoed enabling #{cap}: #{reason}")
            {:reply, {:error, {:guardian_veto, reason}}, state}
        end
    end
  end

  def handle_call({:disable, cap, opts}, _from, state) do
    cond do
      cap in kernel_capabilities() ->
        {:reply, {:error, :kernel_immutable}, state}

      cap not in state.enabled ->
        {:reply, {:ok, :already_disabled}, state}

      has_dependents?(cap, state.enabled) ->
        dependents = get_dependents(cap, state.enabled)
        {:reply, {:error, {:has_dependents, dependents}}, state}

      true ->
        case do_disable_capability(cap, state.supervisors[cap], opts) do
          :ok ->
            new_state = %{state |
              enabled: List.delete(state.enabled, cap),
              supervisors: Map.delete(state.supervisors, cap),
              history: [{:disabled, cap, DateTime.utc_now()} | state.history]
            }
            log_to_register(:capability_disabled, cap)
            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call(:list, _from, state) do
    manifest = Indrajaal.Capability.manifest()

    status = %{
      kernel: Enum.map(manifest.kernel, &{&1, :immutable}),
      core: Enum.map(manifest.core, &{&1, :enabled}),
      capabilities: Enum.map(manifest.capabilities, fn cap ->
        {cap, if(cap in state.enabled, do: :enabled, else: :disabled)}
      end),
      extensions: Enum.map(manifest.extensions, fn ext ->
        {ext, if(ext in state.enabled, do: :enabled, else: :disabled)}
      end)
    }

    {:reply, status, state}
  end

  def handle_call({:status, cap}, _from, state) do
    status = %{
      capability: cap,
      enabled: cap in state.enabled or cap in kernel_capabilities(),
      layer: get_layer(cap),
      dependencies: get_dependencies(cap),
      dependents: get_dependents(cap, state.enabled),
      supervisor_pid: state.supervisors[cap],
      can_disable: cap not in kernel_capabilities() and
                   not has_dependents?(cap, state.enabled)
    }
    {:reply, status, state}
  end

  def handle_call({:can_enable, cap}, _from, state) do
    result = dependencies_satisfied?(cap, state.enabled)
    {:reply, result, state}
  end

  # Private Functions

  defp do_enable_capability(cap) do
    supervisor = Indrajaal.Supervisor
    child_spec = capability_child_spec(cap)

    case DynamicSupervisor.start_child(supervisor, child_spec) do
      {:ok, pid} ->
        Logger.info("Enabled capability #{cap} with pid #{inspect(pid)}")
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        {:ok, pid}
      error ->
        Logger.error("Failed to enable capability #{cap}: #{inspect(error)}")
        error
    end
  end

  defp do_disable_capability(cap, supervisor_pid, opts) do
    # Serialize state before shutdown (SC-PROM-007)
    if function_exported?(capability_module(cap), :hibernate_state, 0) do
      :ok = capability_module(cap).hibernate_state()
    end

    # Graceful shutdown with timeout
    timeout = opts[:timeout] || 5_000

    case Supervisor.stop(supervisor_pid, :normal, timeout) do
      :ok ->
        Logger.info("Disabled capability #{cap}")
        :ok
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp kernel_capabilities do
    [:guardian, :constitution, :immutable_register, :holon_core,
     :founder_directive, :regeneration]
  end

  defp dependencies_satisfied?(cap, enabled) do
    deps = get_dependencies(cap)
    Enum.all?(deps, &(&1 in enabled or &1 in kernel_capabilities()))
  end

  defp missing_dependencies(cap, enabled) do
    deps = get_dependencies(cap)
    Enum.reject(deps, &(&1 in enabled or &1 in kernel_capabilities()))
  end

  defp has_dependents?(cap, enabled) do
    get_dependents(cap, enabled) != []
  end

  defp get_dependents(cap, enabled) do
    Enum.filter(enabled, fn other ->
      cap in get_dependencies(other)
    end)
  end

  defp get_dependencies(cap) do
    %{
      # L2 dependencies
      video: [:devices],
      analytics: [:alarms, :devices],
      patrol: [:devices, :shifts],
      billing: [:accounts],

      # L3 dependencies
      ai_copilot: [:sentinel],
      prajna_cockpit: [:sentinel, :ai_copilot],
      flame_compute: [:cluster],
      knowledge_engine: [:ai_copilot],
      microsoft_mcp: [:ai_copilot]
    }[cap] || []
  end

  defp get_layer(cap) do
    manifest = Indrajaal.Capability.manifest()
    cond do
      cap in manifest.kernel -> :kernel
      cap in manifest.core -> :core
      cap in manifest.capabilities -> :capability
      cap in manifest.extensions -> :extension
      true -> :unknown
    end
  end

  defp capability_child_spec(cap) do
    module = capability_supervisor_module(cap)
    {module, []}
  end

  defp capability_module(cap) do
    Module.concat([Indrajaal, Macro.camelize(to_string(cap))])
  end

  defp capability_supervisor_module(cap) do
    Module.concat([capability_module(cap), Supervisor])
  end

  defp log_to_register(event, cap) do
    Indrajaal.ImmutableRegister.append(%{
      type: event,
      capability: cap,
      timestamp: DateTime.utc_now()
    })
  end
end
```

### 4.3 Configuration Hot-Reload

```elixir
# lib/indrajaal/config/hot_reload.ex
defmodule Indrajaal.Config.HotReload do
  @moduledoc """
  Runtime configuration changes with validation.

  WHAT: Applies configuration changes without restart
  WHY: Enables operational flexibility in production
  CONSTRAINTS: SC-RECONFIG-003 (Rollback Testing)
  """

  require Logger

  @constitutional_keys [
    :guardian_enabled,
    :constitution_verifier_enabled,
    :immutable_register_enabled,
    :founder_directive_enabled,
    :holon_core_enabled,
    :regeneration_enabled
  ]

  @doc """
  Apply configuration changes with validation and rollback capability.
  """
  def apply_config(changes, opts \\ []) do
    with :ok <- validate_constitutional(changes),
         {:ok, :approved} <- submit_to_guardian(changes, opts),
         {:ok, rollback_id} <- create_rollback_point(),
         :ok <- do_apply_changes(changes),
         :ok <- verify_health_post_change() do
      log_config_change(changes, rollback_id)
      {:ok, %{applied: changes, rollback_id: rollback_id}}
    else
      {:error, :constitutional_violation} = error ->
        Logger.error("Constitutional violation in config change")
        error

      {:error, {:guardian_veto, reason}} = error ->
        Logger.warning("Guardian vetoed config change: #{reason}")
        error

      {:error, :health_degraded} ->
        Logger.error("Health degraded after config change, rolling back")
        rollback_to_previous()
        {:error, :health_degraded_rolled_back}

      error ->
        error
    end
  end

  @doc """
  Rollback to a specific configuration snapshot.
  """
  def rollback_to(rollback_id) do
    case get_rollback_point(rollback_id) do
      {:ok, config} ->
        do_apply_changes(config)

      {:error, :not_found} ->
        {:error, :rollback_point_not_found}
    end
  end

  @doc """
  List available rollback points.
  """
  def list_rollback_points do
    Indrajaal.ImmutableRegister.query(%{
      type: :config_rollback_point,
      limit: 100
    })
  end

  # Private Functions

  defp validate_constitutional(changes) do
    violations = Enum.filter(changes, fn {key, _value} ->
      key in @constitutional_keys
    end)

    if violations == [] do
      :ok
    else
      Logger.error("Constitutional keys cannot be modified: #{inspect(violations)}")
      {:error, :constitutional_violation}
    end
  end

  defp submit_to_guardian(changes, opts) do
    proposal = %{
      action: :config_change,
      changes: changes,
      reason: opts[:reason] || "Configuration update",
      requestor: opts[:requestor] || :system
    }

    Indrajaal.Guardian.submit_proposal(proposal)
  end

  defp create_rollback_point do
    current_config = Application.get_all_env(:indrajaal)
    rollback_id = generate_rollback_id()

    Indrajaal.ImmutableRegister.append(%{
      type: :config_rollback_point,
      id: rollback_id,
      config: current_config,
      timestamp: DateTime.utc_now()
    })

    {:ok, rollback_id}
  end

  defp do_apply_changes(changes) do
    Enum.each(changes, fn {key, value} ->
      Application.put_env(:indrajaal, key, value)
    end)
    :ok
  end

  defp verify_health_post_change do
    case Indrajaal.Safety.Sentinel.get_health_score(:system) do
      score when score >= 0.8 -> :ok
      score when score >= 0.5 ->
        Logger.warning("Health score degraded to #{score} after config change")
        :ok
      _score -> {:error, :health_degraded}
    end
  end

  defp get_rollback_point(rollback_id) do
    case Indrajaal.ImmutableRegister.get(%{type: :config_rollback_point, id: rollback_id}) do
      {:ok, %{config: config}} -> {:ok, config}
      _ -> {:error, :not_found}
    end
  end

  defp rollback_to_previous do
    case list_rollback_points() do
      {:ok, [latest | _]} ->
        do_apply_changes(latest.config)
      _ ->
        Logger.error("No rollback point available")
        :error
    end
  end

  defp log_config_change(changes, rollback_id) do
    Indrajaal.ImmutableRegister.append(%{
      type: :config_change_applied,
      changes: changes,
      rollback_id: rollback_id,
      timestamp: DateTime.utc_now()
    })
  end

  defp generate_rollback_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
```

## 5. Deployment Variants

### 5.1 Variant Definitions

| Variant | Layers | Use Case | Memory | CPU |
|---------|--------|----------|--------|-----|
| **Micro** | L0 + L1 (partial) | Edge devices, IoT gateways | 256MB | 0.5 |
| **Minimal** | L0 + L1 | Small installations, dev | 512MB | 1 |
| **Standard** | L0 + L1 + L2 (select) | Medium deployments | 1GB | 2 |
| **Full** | L0 + L1 + L2 + L3 | Enterprise, all features | 2GB+ | 4 |

### 5.2 Variant Configuration Files

```yaml
# config/variants/micro.yml
variant: micro
description: "Edge deployment for IoT gateways"

layers:
  kernel: enabled     # Immutable, always enabled
  core:
    authentication: enabled
    accounts: enabled
    sentinel: enabled
    telemetry: disabled  # Minimal telemetry
    cluster: disabled    # No clustering
  capabilities: []    # None
  extensions: []      # None

resources:
  memory_limit: 256Mi
  memory_request: 128Mi
  cpu_limit: 500m
  cpu_request: 100m
  replicas: 1

containers:
  - name: indrajaal-app
    image: localhost/indrajaal:micro
  - name: indrajaal-db
    image: localhost/indrajaal-db:minimal
    # Embedded SQLite instead of PostgreSQL for micro

features:
  hot_reload: false
  dynamic_capabilities: false
  distributed_mode: false
```

```yaml
# config/variants/minimal.yml
variant: minimal
description: "Core security platform without optional modules"

layers:
  kernel: enabled     # Immutable
  core: enabled       # All core services
  capabilities: []    # None
  extensions: []      # None

resources:
  memory_limit: 512Mi
  memory_request: 256Mi
  cpu_limit: 1
  cpu_request: 250m
  replicas: 1

containers:
  - name: indrajaal-app
    image: localhost/indrajaal:minimal
  - name: indrajaal-db
    image: localhost/indrajaal-db:17

features:
  hot_reload: true
  dynamic_capabilities: true
  distributed_mode: false
```

```yaml
# config/variants/standard.yml
variant: standard
description: "Standard deployment with alarms, devices, access control"

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
  memory_request: 512Mi
  cpu_limit: 2
  cpu_request: 500m
  replicas: 2

containers:
  - name: indrajaal-app
    image: localhost/indrajaal:standard
  - name: indrajaal-db
    image: localhost/indrajaal-db:17-timescale
  - name: indrajaal-obs
    image: localhost/indrajaal-obs:lite

features:
  hot_reload: true
  dynamic_capabilities: true
  distributed_mode: true
```

```yaml
# config/variants/full.yml
variant: full
description: "Full enterprise deployment with all capabilities"

layers:
  kernel: enabled
  core: enabled
  capabilities:
    - alarms
    - devices
    - access_control
    - video
    - analytics
    - compliance
    - communication
    - shifts
    - patrol
    - billing
  extensions:
    - ai_copilot
    - prajna_cockpit
    - flame_compute
    - zenoh_mesh
    - knowledge_engine
    - microsoft_mcp
    - cepaf_bridge

resources:
  memory_limit: 4Gi
  memory_request: 2Gi
  cpu_limit: 4
  cpu_request: 1
  replicas: 3

containers:
  - name: indrajaal-app
    image: localhost/indrajaal:full
  - name: indrajaal-db
    image: localhost/indrajaal-db:17-timescale
  - name: indrajaal-obs
    image: localhost/indrajaal-obs:full
  - name: indrajaal-flame-runner
    image: localhost/indrajaal-flame:latest

features:
  hot_reload: true
  dynamic_capabilities: true
  distributed_mode: true
  flame_enabled: true
  zenoh_mesh: true
```

### 5.3 Build & Deploy Script

```elixir
# scripts/build_variant.exs
defmodule Indrajaal.Build.Variant do
  @moduledoc """
  Build script for creating deployment variants.

  Usage:
    elixir scripts/build_variant.exs minimal
    elixir scripts/build_variant.exs standard
    elixir scripts/build_variant.exs full
  """

  def main(args) do
    variant_name = List.first(args) || "standard"
    build(variant_name)
  end

  def build(variant_name) do
    IO.puts("Building variant: #{variant_name}")

    config = load_variant_config(variant_name)

    # Set environment for compilation
    set_capability_env(config)

    # Validate dependencies
    validate_dependencies(config)

    # Build release
    IO.puts("Running mix release #{variant_name}...")
    {output, exit_code} = System.cmd("mix", ["release", variant_name],
      env: build_env(config),
      stderr_to_stdout: true
    )
    IO.puts(output)

    if exit_code == 0 do
      # Generate deployment manifests
      generate_podman_compose(config, variant_name)
      generate_kubernetes_manifests(config, variant_name)

      IO.puts("")
      IO.puts("=" |> String.duplicate(60))
      IO.puts("BUILD SUCCESSFUL: #{variant_name}")
      IO.puts("=" |> String.duplicate(60))
      IO.puts("Capabilities: #{inspect(config["layers"]["capabilities"])}")
      IO.puts("Extensions: #{inspect(config["layers"]["extensions"])}")
      IO.puts("")
      IO.puts("Artifacts:")
      IO.puts("  - _build/prod/rel/#{variant_name}/")
      IO.puts("  - deploy/#{variant_name}/podman-compose.yml")
      IO.puts("  - deploy/#{variant_name}/kubernetes/")
    else
      IO.puts("BUILD FAILED")
      System.halt(1)
    end
  end

  defp load_variant_config(variant_name) do
    path = "config/variants/#{variant_name}.yml"

    case YamlElixir.read_from_file(path) do
      {:ok, config} -> config
      {:error, reason} ->
        IO.puts("Error loading variant config: #{reason}")
        System.halt(1)
    end
  end

  defp set_capability_env(config) do
    # Set capability environment variables
    for cap <- config["layers"]["capabilities"] || [] do
      key = "INDRAJAAL_CAP_#{String.upcase(cap)}"
      System.put_env(key, "true")
    end

    # Set extension environment variables
    for ext <- config["layers"]["extensions"] || [] do
      key = "INDRAJAAL_EXT_#{String.upcase(ext)}"
      System.put_env(key, "true")
    end
  end

  defp build_env(config) do
    base = [
      {"MIX_ENV", "prod"},
      {"INDRAJAAL_VARIANT", config["variant"]}
    ]

    caps = for cap <- config["layers"]["capabilities"] || [] do
      {"INDRAJAAL_CAP_#{String.upcase(cap)}", "true"}
    end

    exts = for ext <- config["layers"]["extensions"] || [] do
      {"INDRAJAAL_EXT_#{String.upcase(ext)}", "true"}
    end

    base ++ caps ++ exts
  end

  defp validate_dependencies(config) do
    caps = config["layers"]["capabilities"] || []
    exts = config["layers"]["extensions"] || []
    all_enabled = caps ++ exts

    deps = %{
      "video" => ["devices"],
      "analytics" => ["alarms", "devices"],
      "patrol" => ["devices", "shifts"],
      "billing" => ["accounts"],
      "ai_copilot" => ["sentinel"],
      "prajna_cockpit" => ["sentinel", "ai_copilot"],
      "flame_compute" => ["cluster"],
      "knowledge_engine" => ["ai_copilot"],
      "microsoft_mcp" => ["ai_copilot"]
    }

    for {cap, required} <- deps, cap in all_enabled do
      missing = required -- all_enabled
      if missing != [] do
        IO.puts("ERROR: #{cap} requires #{inspect(missing)}")
        System.halt(1)
      end
    end

    IO.puts("Dependencies validated OK")
  end

  defp generate_podman_compose(config, variant_name) do
    File.mkdir_p!("deploy/#{variant_name}")

    content = """
    # Generated for variant: #{variant_name}
    # DO NOT EDIT - Generated by build_variant.exs

    version: "3.8"

    services:
      indrajaal-app:
        image: localhost/indrajaal:#{variant_name}
        ports:
          - "4000:4000"
        environment:
          - DATABASE_URL=ecto://postgres:postgres@indrajaal-db:5432/indrajaal_#{variant_name}
          - SECRET_KEY_BASE=${SECRET_KEY_BASE}
    #{capability_env_yaml(config)}
        depends_on:
          - indrajaal-db
        deploy:
          resources:
            limits:
              memory: #{config["resources"]["memory_limit"]}
              cpus: "#{config["resources"]["cpu_limit"]}"

      indrajaal-db:
        image: #{db_image(config)}
        volumes:
          - db_data:/var/lib/postgresql/data
        environment:
          - POSTGRES_USER=postgres
          - POSTGRES_PASSWORD=postgres
          - POSTGRES_DB=indrajaal_#{variant_name}

    #{obs_service(config)}

    volumes:
      db_data:
    """

    File.write!("deploy/#{variant_name}/podman-compose.yml", content)
    IO.puts("Generated deploy/#{variant_name}/podman-compose.yml")
  end

  defp capability_env_yaml(config) do
    caps = for cap <- config["layers"]["capabilities"] || [] do
      "      - INDRAJAAL_CAP_#{String.upcase(cap)}=true"
    end

    exts = for ext <- config["layers"]["extensions"] || [] do
      "      - INDRAJAAL_EXT_#{String.upcase(ext)}=true"
    end

    (caps ++ exts) |> Enum.join("\n")
  end

  defp db_image(config) do
    case config["variant"] do
      "micro" -> "localhost/indrajaal-db:minimal"
      _ -> "localhost/indrajaal-db:17-timescale"
    end
  end

  defp obs_service(config) do
    if "full" == config["variant"] or "standard" == config["variant"] do
      """
        indrajaal-obs:
          image: localhost/indrajaal-obs:#{config["variant"]}
          ports:
            - "4317:4317"
            - "9090:9090"
            - "3000:3000"
      """
    else
      ""
    end
  end

  defp generate_kubernetes_manifests(config, variant_name) do
    dir = "deploy/#{variant_name}/kubernetes"
    File.mkdir_p!(dir)

    # Generate deployment.yaml, service.yaml, configmap.yaml, etc.
    # ... implementation details

    IO.puts("Generated Kubernetes manifests in #{dir}/")
  end
end

# Run if called directly
if System.argv() != [] do
  Indrajaal.Build.Variant.main(System.argv())
end
```

## 6. Capability Dependency Graph

```
                    ┌─────────────────┐
                    │     KERNEL      │
                    │  (Immutable)    │
                    │                 │
                    │ • Guardian      │
                    │ • Constitution  │
                    │ • ImmutableReg  │
                    │ • HolonCore     │
                    │ • FounderDir    │
                    │ • Regeneration  │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
        ┌──────────┐  ┌──────────┐  ┌──────────┐
        │   Auth   │  │ Accounts │  │ Sentinel │
        │   +      │  │          │  │          │
        │  AuthZ   │  │          │  │          │
        └────┬─────┘  └────┬─────┘  └────┬─────┘
             │             │             │
     ┌───────┴─────────────┴─────────────┴───────┐
     │              CORE SERVICES                │
     │  (Cluster, Telemetry, Config)             │
     └───────────────────┬───────────────────────┘
                         │
     ┌───────────────────┼───────────────────────┐
     │                   │                       │
     ▼                   ▼                       ▼
┌─────────┐        ┌─────────┐            ┌──────────┐
│ Alarms  │◄───────│ Devices │◄───────────│ Access   │
│         │        │         │            │ Control  │
└────┬────┘        └────┬────┘            └──────────┘
     │                  │
     │    ┌─────────────┼─────────────┐
     │    │             │             │
     ▼    ▼             ▼             ▼
┌─────────────┐  ┌───────────┐  ┌───────────┐
│  Analytics  │  │   Video   │  │  Patrol   │
│             │  │           │  │     │     │
│ req: alarms │  │req:devices│  │ req:shifts│
│ req: devices│  │           │  │ req:device│
└─────────────┘  └───────────┘  └─────┬─────┘
                                      │
                                ┌─────▼─────┐
                                │  Shifts   │
                                └───────────┘

┌─────────────────────────────────────────────┐
│              EXTENSIONS (L3)                │
├─────────────────────────────────────────────┤
│                                             │
│  ┌───────────┐                              │
│  │  Sentinel │◄─────────────────────┐       │
│  └─────┬─────┘                      │       │
│        │                            │       │
│        ▼                            │       │
│  ┌───────────┐     ┌───────────┐    │       │
│  │ AI Copilot│◄────│ Knowledge │    │       │
│  │           │     │  Engine   │    │       │
│  └─────┬─────┘     └───────────┘    │       │
│        │                            │       │
│        │     ┌────────────────┐     │       │
│        ├────►│ Microsoft MCP  │     │       │
│        │     └────────────────┘     │       │
│        │                            │       │
│        ▼                            │       │
│  ┌───────────┐     ┌───────────┐    │       │
│  │  Prajna   │     │   FLAME   │◄───┘       │
│  │  Cockpit  │     │  Compute  │            │
│  │           │     │           │            │
│  │req:sentinel     │req:cluster│            │
│  │req:ai_copilot   └───────────┘            │
│  └───────────┘                              │
│                                             │
│  ┌───────────┐     ┌───────────┐            │
│  │   Zenoh   │     │   CEPAF   │            │
│  │   Mesh    │     │  Bridge   │            │
│  └───────────┘     └───────────┘            │
│                                             │
└─────────────────────────────────────────────┘

Legend:
  ───► Required dependency
  - - ► Optional dependency
  ◄─── Reverse dependency (dependent on)
```

## 7. Interface Contracts for Pluggability

### 7.1 Capability Behaviour

```elixir
# lib/indrajaal/capability/behaviour.ex
defmodule Indrajaal.Capability.Behaviour do
  @moduledoc """
  Behaviour contract for pluggable capability modules.
  All L2/L3 modules MUST implement this behaviour.

  WHAT: Defines the interface for hot-pluggable capabilities
  WHY: Enables runtime enable/disable with state preservation
  CONSTRAINTS: SC-PROM-007 (Hibernation), SC-RECONFIG-001
  """

  @doc """
  Return capability metadata.

  ## Example

      def capability_info do
        %{
          name: :alarms,
          version: "1.0.0",
          layer: :capability,
          dependencies: [:devices],
          required_resources: %{memory_mb: 128, connections: 10}
        }
      end
  """
  @callback capability_info() :: %{
    name: atom(),
    version: String.t(),
    layer: :capability | :extension,
    dependencies: [atom()],
    required_resources: map()
  }

  @doc """
  Initialize capability with config.
  Called when capability is enabled.
  """
  @callback init(config :: map()) :: {:ok, state :: term()} | {:error, reason :: term()}

  @doc """
  Serialize state for hibernation (SC-PROM-007).
  Called before capability is disabled.
  Must persist state to SQLite/DuckDB.
  """
  @callback hibernate_state() :: :ok | {:error, term()}

  @doc """
  Restore state from hibernation.
  Called when capability is re-enabled.
  """
  @callback restore_state(state :: term()) :: :ok | {:error, term()}

  @doc """
  Health check for the capability.
  Called periodically by Sentinel.
  """
  @callback health_check() :: :healthy | {:degraded, reason :: term()} | :unhealthy

  @doc """
  Graceful shutdown.
  Called when capability is being disabled or system is shutting down.
  """
  @callback shutdown(reason :: term()) :: :ok

  @doc """
  Return list of routes to register (optional).
  """
  @callback routes() :: [map()] | nil

  @optional_callbacks [routes: 0]
end
```

### 7.2 Example Capability Implementation

```elixir
# lib/indrajaal/alarms/alarms.ex
defmodule Indrajaal.Alarms do
  @moduledoc """
  Alarms capability module.

  WHAT: Alarm processing and management
  WHY: Core security monitoring capability
  CONSTRAINTS: SC-RECONFIG-006, TDG-ALARMS-*
  """

  @behaviour Indrajaal.Capability.Behaviour

  @impl true
  def capability_info do
    %{
      name: :alarms,
      version: "1.0.0",
      layer: :capability,
      dependencies: [],  # No dependencies
      required_resources: %{
        memory_mb: 256,
        db_connections: 5,
        pubsub_channels: 3
      }
    }
  end

  @impl true
  def init(config) do
    # Initialize alarm processing
    {:ok, %{config: config, started_at: DateTime.utc_now()}}
  end

  @impl true
  def hibernate_state do
    # Persist in-flight alarms to SQLite
    state = get_current_state()
    Indrajaal.Holon.Core.persist(:alarms, state)
    :ok
  end

  @impl true
  def restore_state(_state) do
    # Restore from SQLite
    case Indrajaal.Holon.Core.load(:alarms) do
      {:ok, state} ->
        restore_in_flight_alarms(state)
        :ok
      {:error, :not_found} ->
        :ok  # Fresh start
    end
  end

  @impl true
  def health_check do
    cond do
      queue_backlog() > 1000 -> {:degraded, :queue_backlog}
      processing_latency_ms() > 500 -> {:degraded, :high_latency}
      true -> :healthy
    end
  end

  @impl true
  def shutdown(_reason) do
    # Graceful drain of alarm queue
    drain_queue(timeout: 5_000)
    :ok
  end

  @impl true
  def routes do
    [
      %{path: "/api/v1/alarms", module: IndrajaalWeb.AlarmsController},
      %{path: "/api/v1/alarms/:id", module: IndrajaalWeb.AlarmsController}
    ]
  end

  # Private functions
  defp get_current_state, do: %{}
  defp restore_in_flight_alarms(_state), do: :ok
  defp queue_backlog, do: 0
  defp processing_latency_ms, do: 50
  defp drain_queue(_opts), do: :ok
end
```

## 8. Safety Constraints

### 8.1 New STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-CAP-001 | Kernel capabilities CANNOT be disabled | CRITICAL |
| SC-CAP-002 | Capability enable REQUIRES Guardian approval | HIGH |
| SC-CAP-003 | Capability disable REQUIRES dependency check | HIGH |
| SC-CAP-004 | All capability state changes logged to ImmutableRegister | CRITICAL |
| SC-CAP-005 | Hibernation state MUST be persisted before disable | HIGH |
| SC-CAP-006 | Health degradation TRIGGERS auto-rollback | HIGH |
| SC-CAP-007 | Build variant MUST declare all capabilities | MEDIUM |
| SC-CAP-008 | Runtime enable CANNOT exceed build capabilities | HIGH |

### 8.2 New AOR Rules

| ID | Rule |
|----|------|
| AOR-CAP-001 | Check dependency graph before enabling capability |
| AOR-CAP-002 | Check reverse dependencies before disabling capability |
| AOR-CAP-003 | Persist state before any capability state change |
| AOR-CAP-004 | Verify Guardian approval for all capability changes |
| AOR-CAP-005 | Log all capability lifecycle events |
| AOR-CAP-006 | Use build variants for deployments, not manual config |

## 9. Implementation Priority

### Phase 1: Foundation (Week 1)
1. Define `Indrajaal.Capability.Behaviour`
2. Create `Indrajaal.Capability` module with macros
3. Refactor `Application.start/2` for conditional loading

### Phase 2: Runtime Management (Week 2)
1. Implement `Indrajaal.CapabilityManager` GenServer
2. Implement `Indrajaal.Config.HotReload`
3. Wire Guardian approval for capability changes

### Phase 3: Build System (Week 3)
1. Create variant YAML configuration schema
2. Implement `scripts/build_variant.exs`
3. Generate Podman/Kubernetes manifests

### Phase 4: Migration (Week 4)
1. Migrate existing domains to implement Behaviour
2. Define dependency graph
3. Test all variants (micro, minimal, standard, full)

### Phase 5: Validation (Week 5)
1. Full test coverage for capability lifecycle
2. Property tests for dependency resolution
3. Chaos testing for runtime enable/disable

## 10. References

- SC-RECONFIG-001: Minimal Change principle
- SC-CONST-007: Guardian absolute veto
- SC-PROM-007: Hibernation Mandate
- AOR-HOLON-003: Portability requirement
- docs/architecture/HOLON_CONSTITUTIONAL_RECONFIGURATION.md
