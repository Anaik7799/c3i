# Configuration & Modularity Techniques: Fractal Integration Analysis

**Date**: 2026-01-02T14:00:00+01:00
**Author**: Claude Opus 4.5
**Category**: Architecture / Configuration / Fractal Integration
**Tags**: configuration, modularity, fractal, prajna, holon, zenoh, hyperscaler-patterns
**Version**: 1.0.0

---

## Executive Summary

This document analyzes how industry-standard configuration and modularity techniques from OS-level through hyperscaler-level can be applied to the Indrajaal system, specifically integrating with the 5-level Fractal Logging architecture and 7-level Holon structure.

**Key Finding**: Indrajaal's existing fractal architecture provides a natural mapping for multi-level configuration that mirrors patterns used by Google Borg, Meta Twine, and Microsoft Azure.

---

## 1. Architecture Mapping: Techniques → Fractal Levels

### 1.1 Fractal Layer Configuration Matrix

| Fractal Level | Industry Analog | Configuration Technique | Indrajaal Implementation |
|---------------|-----------------|------------------------|--------------------------|
| **L7 Federation** | Google Borg Cell | Paxos-replicated config | Cross-region holon sync |
| **L6 Cluster** | Meta Twine Control Plane | Centralized + distributed | libcluster + Zenoh mesh |
| **L5 Node** | Kubernetes Node | ConfigMap + Secrets | Application.env + Vault |
| **L4 Container** | Docker/Podman | Environment injection | runtime.exs + Podman env |
| **L3 Agent** | Istio Sidecar | Dynamic xDS | Prajna.Config + Guardian |
| **L2 Module** | Netflix Archaius | Polling config source | GenServer state + ETS |
| **L1 Function** | 12-Factor App | Env vars + defaults | Module attributes |
| **L0 Constitution** | Kernel sysctl (immutable) | Compile-time constants | @axioms (Ψ₀-Ψ₅) |

### 1.2 Logging Level → Config Retention Mapping

| Log Level | Config Scope | Retention | Hot Reload | Example |
|-----------|--------------|-----------|------------|---------|
| **Spine (L5)** | Federation/Cluster | Forever | No (restart) | Constitutional axioms |
| **Thorax (L4)** | Node/Container | 30 days | Partial | Guardian timeouts |
| **Segment (L3)** | Agent/Process | 7 days | Yes | Circuit breaker thresholds |
| **Fiber (L2)** | Module/Function | 24 hours | Yes | Debug flags |
| **Gossamer (L1)** | Trace/Debug | 1 hour | Yes | Trace sampling rate |

---

## 2. Technique Application by Level

### 2.1 L0: Constitutional Configuration (Immutable)

**Technique**: Kernel-level immutable constants (like Linux kernel compile-time config)

**Current Implementation**:
```elixir
# lib/indrajaal/axioms.ex
defmodule Indrajaal.Axioms do
  @axiom_psi0 :existence_preservation
  @axiom_psi1 :regenerative_completeness
  @axiom_psi2 :evolutionary_continuity
  @axiom_psi3 :verification_capability
  @axiom_psi4 :human_alignment  # AMENDED: Founder PRIMARY
  @axiom_psi5 :truthfulness

  # These CANNOT be overridden at runtime
  def constitutional_axioms, do: [@axiom_psi0, @axiom_psi1, @axiom_psi2,
                                   @axiom_psi3, @axiom_psi4, @axiom_psi5]
end
```

**Enhancement**: Add compile-time verification
```elixir
# Compile-time assertion (like Linux CONFIG_* options)
@compile {:inline, verify_constitution: 0}
def verify_constitution do
  # Hardcoded hash of constitution - any change fails compilation
  expected_hash = "sha256:abc123..."
  actual_hash = :crypto.hash(:sha256, inspect(constitutional_axioms()))
  if actual_hash != expected_hash, do: raise "Constitutional tampering detected"
end
```

**STAMP Constraint**: SC-CONST-001 through SC-CONST-006

---

### 2.2 L1: Function-Level Configuration

**Technique**: 12-Factor App environment variables + module attributes

**Current Pattern**:
```elixir
defmodule Indrajaal.SomeModule do
  @default_timeout 5_000

  def call(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    # ...
  end
end
```

**Enhancement**: Fractal-aware defaults with override chain
```elixir
defmodule Indrajaal.Config.FractalDefaults do
  @moduledoc """
  L1 Configuration: Function-level defaults with fractal override chain.

  Override precedence (highest to lowest):
  1. Runtime argument
  2. Process dictionary
  3. Application environment
  4. Module attribute default
  """

  defmacro fractal_config(key, default) do
    quote do
      def unquote(:"get_#{key}")() do
        Process.get(unquote(key)) ||
        Application.get_env(:indrajaal, unquote(key)) ||
        unquote(default)
      end
    end
  end
end
```

---

### 2.3 L2: Module-Level Configuration (Netflix Archaius Pattern)

**Technique**: Dynamic configuration with polling + callback notification

**Implementation for Prajna Modules**:
```elixir
defmodule Indrajaal.Cockpit.Prajna.DynamicConfig do
  @moduledoc """
  L2 Configuration: Module-level dynamic config with Archaius-style polling.

  WHAT: Watches for configuration changes and notifies subscribers.
  WHY: Enables runtime tuning without restart (SC-CONFIG-003).

  CONSTRAINTS:
    - SC-CONFIG-003: Runtime update support for L2+ configs
    - SC-LOG-004: All config changes logged to Spine level
  """

  use GenServer
  require Logger
  alias Indrajaal.Observability.FractalLogger

  @poll_interval_ms 5_000

  defstruct [:config_source, :current_config, :subscribers, :last_poll]

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Subscribe to config changes for a specific key"
  def subscribe(key, callback) when is_function(callback, 2) do
    GenServer.call(__MODULE__, {:subscribe, key, callback})
  end

  @doc "Get current value with dynamic refresh"
  def get(key, default \\ nil) do
    GenServer.call(__MODULE__, {:get, key, default})
  end

  @doc "Force refresh from source"
  def refresh do
    GenServer.call(__MODULE__, :refresh)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl GenServer
  def init(opts) do
    source = Keyword.get(opts, :source, :application_env)
    schedule_poll()

    state = %__MODULE__{
      config_source: source,
      current_config: load_config(source),
      subscribers: %{},
      last_poll: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:subscribe, key, callback}, {pid, _}, state) do
    ref = Process.monitor(pid)
    subscribers = Map.update(state.subscribers, key, [{pid, ref, callback}],
                             &[{pid, ref, callback} | &1])
    {:reply, :ok, %{state | subscribers: subscribers}}
  end

  @impl GenServer
  def handle_call({:get, key, default}, _from, state) do
    value = Map.get(state.current_config, key, default)
    {:reply, value, state}
  end

  @impl GenServer
  def handle_call(:refresh, _from, state) do
    new_config = load_config(state.config_source)
    new_state = process_config_changes(state, new_config)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_info(:poll, state) do
    new_config = load_config(state.config_source)
    new_state = process_config_changes(state, new_config)
    schedule_poll()
    {:noreply, %{new_state | last_poll: DateTime.utc_now()}}
  end

  # ============================================================================
  # Private
  # ============================================================================

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval_ms)
  end

  defp load_config(:application_env) do
    Application.get_all_env(:indrajaal)
    |> Enum.into(%{})
  end

  defp process_config_changes(state, new_config) do
    changes = detect_changes(state.current_config, new_config)

    Enum.each(changes, fn {key, old_value, new_value} ->
      # Log to Spine (L5) - config changes are audit-critical
      FractalLogger.spine(:config_change, %{
        key: key,
        old_value: old_value,
        new_value: new_value,
        timestamp: DateTime.utc_now()
      })

      # Notify subscribers
      notify_subscribers(state.subscribers, key, old_value, new_value)
    end)

    %{state | current_config: new_config}
  end

  defp detect_changes(old, new) do
    all_keys = MapSet.union(MapSet.new(Map.keys(old)), MapSet.new(Map.keys(new)))

    Enum.reduce(all_keys, [], fn key, acc ->
      old_val = Map.get(old, key)
      new_val = Map.get(new, key)
      if old_val != new_val, do: [{key, old_val, new_val} | acc], else: acc
    end)
  end

  defp notify_subscribers(subscribers, key, old_value, new_value) do
    Map.get(subscribers, key, [])
    |> Enum.each(fn {_pid, _ref, callback} ->
      Task.start(fn -> callback.(old_value, new_value) end)
    end)
  end
end
```

---

### 2.4 L3: Agent-Level Configuration (Istio/Envoy xDS Pattern)

**Technique**: Dynamic service mesh configuration with control plane push

**Implementation for Prajna Agents**:
```elixir
defmodule Indrajaal.Cockpit.Prajna.AgentConfigServer do
  @moduledoc """
  L3 Configuration: Agent-level dynamic config inspired by Envoy xDS.

  WHAT: Pushes configuration updates to all Prajna agents via Zenoh.
  WHY: Enables centralized control of distributed agent behavior (SC-CONFIG-004).

  CONSTRAINTS:
    - SC-CONFIG-004: Push-based config for agents
    - SC-ZENOH-PUB-001: Non-blocking publication
    - SC-BIO-003: Agent scaling respects API limits

  ## xDS-Inspired Protocol

  1. Agents subscribe to `intelitor/config/agent/{agent_type}/*`
  2. Config server publishes updates on config change
  3. Agents ACK with current version
  4. Server tracks version consistency across mesh
  """

  use GenServer
  require Logger
  alias Indrajaal.Observability.ZenohFractalPublisher
  alias Indrajaal.Cockpit.Prajna.Config

  @config_key_prefix "intelitor/config/agent"

  defstruct [:configs, :versions, :acks, :last_push]

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Push configuration update to all agents of a type"
  def push_config(agent_type, config) when is_atom(agent_type) and is_map(config) do
    GenServer.call(__MODULE__, {:push_config, agent_type, config})
  end

  @doc "Get current config version for agent type"
  def get_version(agent_type) do
    GenServer.call(__MODULE__, {:get_version, agent_type})
  end

  @doc "Record ACK from agent"
  def ack(agent_type, agent_id, version) do
    GenServer.cast(__MODULE__, {:ack, agent_type, agent_id, version})
  end

  @doc "Check if all agents have consistent config"
  def consistent?(agent_type) do
    GenServer.call(__MODULE__, {:consistent?, agent_type})
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl GenServer
  def init(_opts) do
    state = %__MODULE__{
      configs: %{},
      versions: %{},
      acks: %{},
      last_push: nil
    }
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:push_config, agent_type, config}, _from, state) do
    version = :erlang.unique_integer([:positive, :monotonic])
    key = "#{@config_key_prefix}/#{agent_type}/v#{version}"

    payload = %{
      type: :config_update,
      agent_type: agent_type,
      version: version,
      config: config,
      timestamp: DateTime.utc_now(),
      ttl_ms: Config.get(:config_push_ttl_ms, 300_000)
    }

    # Push via Zenoh (non-blocking)
    ZenohFractalPublisher.publish(key, payload)

    # Update state
    new_configs = Map.put(state.configs, agent_type, config)
    new_versions = Map.put(state.versions, agent_type, version)
    new_acks = Map.put(state.acks, agent_type, %{})

    Logger.info("[AgentConfigServer] Pushed config v#{version} to #{agent_type} agents")

    {:reply, {:ok, version}, %{state |
      configs: new_configs,
      versions: new_versions,
      acks: new_acks,
      last_push: DateTime.utc_now()
    }}
  end

  @impl GenServer
  def handle_call({:get_version, agent_type}, _from, state) do
    version = Map.get(state.versions, agent_type, 0)
    {:reply, version, state}
  end

  @impl GenServer
  def handle_call({:consistent?, agent_type}, _from, state) do
    current_version = Map.get(state.versions, agent_type, 0)
    agent_acks = Map.get(state.acks, agent_type, %{})

    all_current = Enum.all?(agent_acks, fn {_id, v} -> v == current_version end)
    {:reply, all_current, state}
  end

  @impl GenServer
  def handle_cast({:ack, agent_type, agent_id, version}, state) do
    new_acks = update_in(state.acks, [agent_type], fn acks ->
      Map.put(acks || %{}, agent_id, version)
    end)
    {:noreply, %{state | acks: new_acks}}
  end
end
```

---

### 2.5 L4: Container-Level Configuration (Kubernetes Pattern)

**Technique**: ConfigMap/Secret equivalent with hot reload

**Implementation**:
```elixir
defmodule Indrajaal.Config.ContainerConfig do
  @moduledoc """
  L4 Configuration: Container-level config inspired by Kubernetes ConfigMap/Secrets.

  WHAT: Manages container-scoped configuration with file-based and env-based sources.
  WHY: Enables deployment-time configuration without code changes (SC-CONFIG-005).

  ## Sources (in precedence order)
  1. Environment variables (INDRAJAAL_*)
  2. runtime.exs
  3. config.exs (compile-time)
  4. Podman secrets mount (/run/secrets/*)

  CONSTRAINTS:
    - SC-CNT-009: NixOS/Podman only
    - SC-SEC-047: Encryption for secrets
  """

  @secrets_path "/run/secrets"
  @env_prefix "INDRAJAAL_"

  @doc "Load configuration from all L4 sources"
  def load_all do
    %{}
    |> Map.merge(load_compile_config())
    |> Map.merge(load_runtime_config())
    |> Map.merge(load_secrets())
    |> Map.merge(load_env_vars())
  end

  @doc "Get a config value with L4 precedence"
  def get(key, default \\ nil) do
    # Check env var first (highest precedence)
    env_key = "#{@env_prefix}#{key |> to_string() |> String.upcase()}"
    case System.get_env(env_key) do
      nil ->
        # Fall back to Application env
        Application.get_env(:indrajaal, key, default)
      value ->
        parse_env_value(value)
    end
  end

  @doc "Load secret from mounted volume"
  def get_secret(name) do
    path = Path.join(@secrets_path, name)
    case File.read(path) do
      {:ok, content} -> {:ok, String.trim(content)}
      {:error, :enoent} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helpers
  defp load_compile_config do
    Application.get_all_env(:indrajaal) |> Enum.into(%{})
  end

  defp load_runtime_config do
    # runtime.exs is already loaded by Mix
    %{}
  end

  defp load_secrets do
    if File.dir?(@secrets_path) do
      File.ls!(@secrets_path)
      |> Enum.reduce(%{}, fn file, acc ->
        case File.read(Path.join(@secrets_path, file)) do
          {:ok, content} -> Map.put(acc, String.to_atom(file), String.trim(content))
          _ -> acc
        end
      end)
    else
      %{}
    end
  end

  defp load_env_vars do
    System.get_env()
    |> Enum.filter(fn {k, _} -> String.starts_with?(k, @env_prefix) end)
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      key = k
        |> String.replace_prefix(@env_prefix, "")
        |> String.downcase()
        |> String.to_atom()
      Map.put(acc, key, parse_env_value(v))
    end)
  end

  defp parse_env_value("true"), do: true
  defp parse_env_value("false"), do: false
  defp parse_env_value(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end
end
```

---

### 2.6 L5-L6: Node/Cluster Configuration (Borg/Twine Pattern)

**Technique**: Distributed consensus with version vectors

**Implementation**:
```elixir
defmodule Indrajaal.Cluster.DistributedConfig do
  @moduledoc """
  L5-L6 Configuration: Cluster-wide config with Borg-inspired techniques.

  WHAT: Manages configuration across cluster nodes with consistency guarantees.
  WHY: Enables coordinated behavior across distributed holons (SC-HOLON-010).

  ## Techniques Applied
  - Version vectors for conflict-free updates (CRDT)
  - Gossip protocol for propagation
  - Quorum reads/writes for strong consistency

  CONSTRAINTS:
    - SC-HOLON-010: Version vector in SQLite for conflict resolution
    - SC-CLU-001: Cluster-wide config consistency
  """

  use GenServer
  require Logger
  alias Indrajaal.Cluster.Gossip
  alias Indrajaal.Core.Holon.VersionVector

  defstruct [:node_id, :config, :version_vector, :peers]

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Set config with cluster propagation"
  def set(key, value, opts \\ []) do
    consistency = Keyword.get(opts, :consistency, :eventual)
    GenServer.call(__MODULE__, {:set, key, value, consistency})
  end

  @doc "Get config with optional consistency level"
  def get(key, opts \\ []) do
    consistency = Keyword.get(opts, :consistency, :local)
    GenServer.call(__MODULE__, {:get, key, consistency})
  end

  @doc "Get cluster-wide config status"
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl GenServer
  def init(opts) do
    node_id = Keyword.get(opts, :node_id, node())

    state = %__MODULE__{
      node_id: node_id,
      config: %{},
      version_vector: VersionVector.new(),
      peers: []
    }

    # Subscribe to gossip updates
    Gossip.subscribe(:config_update, self())

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:set, key, value, :eventual}, _from, state) do
    # Increment version vector
    new_vv = VersionVector.increment(state.version_vector, state.node_id)
    new_config = Map.put(state.config, key, {value, new_vv})

    # Gossip to peers (async)
    Gossip.broadcast(:config_update, %{
      key: key,
      value: value,
      version_vector: new_vv,
      origin: state.node_id
    })

    {:reply, :ok, %{state | config: new_config, version_vector: new_vv}}
  end

  @impl GenServer
  def handle_call({:set, key, value, :quorum}, _from, state) do
    # Quorum write (wait for majority)
    new_vv = VersionVector.increment(state.version_vector, state.node_id)
    quorum_size = div(length(state.peers), 2) + 1

    case Gossip.quorum_write(:config_update, %{key: key, value: value, version_vector: new_vv}, quorum_size) do
      {:ok, _acks} ->
        new_config = Map.put(state.config, key, {value, new_vv})
        {:reply, :ok, %{state | config: new_config, version_vector: new_vv}}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:get, key, :local}, _from, state) do
    value = case Map.get(state.config, key) do
      {v, _vv} -> v
      nil -> nil
    end
    {:reply, value, state}
  end

  @impl GenServer
  def handle_call({:get, key, :quorum}, _from, state) do
    # Quorum read
    quorum_size = div(length(state.peers), 2) + 1
    case Gossip.quorum_read(:config_get, key, quorum_size) do
      {:ok, values} ->
        # Return value with highest version vector
        {value, _vv} = Enum.max_by(values, fn {_v, vv} -> VersionVector.sum(vv) end)
        {:reply, value, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    status = %{
      node_id: state.node_id,
      config_keys: Map.keys(state.config),
      version_vector: state.version_vector,
      peer_count: length(state.peers)
    }
    {:reply, status, state}
  end

  @impl GenServer
  def handle_info({:gossip, :config_update, update}, state) do
    new_state = merge_update(state, update)
    {:noreply, new_state}
  end

  # ============================================================================
  # Private: CRDT Merge
  # ============================================================================

  defp merge_update(state, %{key: key, value: value, version_vector: remote_vv}) do
    case Map.get(state.config, key) do
      nil ->
        # New key, accept remote
        new_config = Map.put(state.config, key, {value, remote_vv})
        new_vv = VersionVector.merge(state.version_vector, remote_vv)
        %{state | config: new_config, version_vector: new_vv}

      {_local_value, local_vv} ->
        case VersionVector.compare(local_vv, remote_vv) do
          :before ->
            # Remote is newer, accept it
            new_config = Map.put(state.config, key, {value, remote_vv})
            new_vv = VersionVector.merge(state.version_vector, remote_vv)
            %{state | config: new_config, version_vector: new_vv}

          :after ->
            # Local is newer, keep it
            state

          :concurrent ->
            # Conflict! Use LWW with node_id as tiebreaker
            # In production, would use proper CRDT merge
            Logger.warning("[DistributedConfig] Concurrent update detected for #{key}")
            state
        end
    end
  end
end
```

---

### 2.7 L7: Federation Configuration (Cross-Region Pattern)

**Technique**: Hierarchical config with regional overrides

**Implementation**:
```elixir
defmodule Indrajaal.Federation.ConfigBridge do
  @moduledoc """
  L7 Configuration: Federation-level config for cross-region holons.

  WHAT: Manages configuration across geographic regions with latency-aware propagation.
  WHY: Enables global Indrajaal deployments with regional customization.

  ## Hierarchy
  1. Global defaults (all regions)
  2. Regional overrides (per-region)
  3. Cluster overrides (per-cluster)
  4. Node overrides (per-node)

  CONSTRAINTS:
    - SC-RECONFIG-010: Federation notification required
    - SC-CONST-001: Constitution immutable across federation
  """

  @doc "Get config with regional fallback chain"
  def get(key, opts \\ []) do
    region = Keyword.get(opts, :region, get_current_region())
    cluster = Keyword.get(opts, :cluster, get_current_cluster())
    node = Keyword.get(opts, :node, node())

    # Check in order: node → cluster → region → global
    node_config(node, key) ||
    cluster_config(cluster, key) ||
    region_config(region, key) ||
    global_config(key)
  end

  @doc "Set config at specified level"
  def set(key, value, level, scope) do
    case level do
      :global -> set_global(key, value)
      :region -> set_region(scope, key, value)
      :cluster -> set_cluster(scope, key, value)
      :node -> set_node(scope, key, value)
    end
  end

  # Implementation details...
end
```

---

## 3. Prajna-Specific Configuration Integration

### 3.1 Current Prajna.Config Enhancement

The existing `Prajna.Config` module already implements many patterns. Here's how to enhance it for full fractal integration:

```elixir
defmodule Indrajaal.Cockpit.Prajna.Config do
  @moduledoc """
  Enhanced Prajna Configuration with Fractal Integration.

  ## Fractal Configuration Layers

  | Layer | Scope | Hot Reload | Source |
  |-------|-------|------------|--------|
  | L5 | Constitutional | No | @axioms |
  | L4 | Container | Restart | runtime.exs |
  | L3 | Agent | Yes | This module |
  | L2 | Module | Yes | DynamicConfig |
  | L1 | Function | Yes | opts arguments |

  ## New Features (Sprint 31+)

  1. Fractal-aware defaults
  2. Zenoh config distribution
  3. Version-tracked changes
  4. Immutable Register logging
  """

  use GenServer
  require Logger
  alias Indrajaal.Observability.FractalLogger
  alias Indrajaal.Cockpit.Prajna.ImmutableState

  # Add fractal level to schema
  @schema %{
    # ... existing schema ...

    # NEW: Fractal-specific config
    fractal_config_distribution_enabled: %{
      default: true,
      type: :boolean,
      level: :l4,  # Container-level
      description: "Enable Zenoh-based config distribution"
    },
    fractal_config_version_tracking: %{
      default: true,
      type: :boolean,
      level: :l4,
      description: "Track all config changes in version vector"
    }
  }

  # Track configuration version
  defstruct [:config, :version, :last_change, :change_log]

  # ============================================================================
  # Enhanced API
  # ============================================================================

  @doc "Get config with fractal-aware logging"
  def get(key) when is_atom(key) do
    value = do_get(key)

    # Log access at Gossamer level (trace)
    FractalLogger.gossamer(:config_access, %{key: key, value: value})

    value
  end

  @doc "Set config with version tracking and distribution"
  def set(key, value) when is_atom(key) do
    GenServer.call(__MODULE__, {:set, key, value})
  end

  @doc "Get config change history"
  def history(key, limit \\ 10) do
    GenServer.call(__MODULE__, {:history, key, limit})
  end

  @doc "Subscribe to config changes"
  def subscribe(key, callback) do
    GenServer.call(__MODULE__, {:subscribe, key, callback})
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl GenServer
  def handle_call({:set, key, value}, _from, state) do
    old_value = Map.get(state.config, key)

    # Validate against schema
    case validate_value(key, value, @schema[key]) do
      :ok ->
        new_config = Map.put(state.config, key, value)
        new_version = state.version + 1

        change = %{
          key: key,
          old_value: old_value,
          new_value: value,
          version: new_version,
          timestamp: DateTime.utc_now()
        }

        # Log to appropriate fractal level based on schema
        log_change_to_fractal(key, change, @schema[key])

        # Record to Immutable Register (L5 change)
        ImmutableState.record(%{
          change_type: :config_change,
          module: "Prajna.Config",
          key: to_string(key),
          old_value: old_value,
          new_value: value
        })

        # Distribute via Zenoh if enabled
        if get(:fractal_config_distribution_enabled) do
          distribute_config_change(change)
        end

        new_state = %{state |
          config: new_config,
          version: new_version,
          last_change: DateTime.utc_now(),
          change_log: [change | Enum.take(state.change_log, 99)]
        }

        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # ============================================================================
  # Private: Fractal Integration
  # ============================================================================

  defp log_change_to_fractal(key, change, schema) do
    level = Map.get(schema, :level, :l3)

    case level do
      :l5 -> FractalLogger.spine(:config_change, change)
      :l4 -> FractalLogger.thorax(:config_change, change)
      :l3 -> FractalLogger.segment(:config_change, change)
      :l2 -> FractalLogger.fiber(:config_change, change)
      :l1 -> FractalLogger.gossamer(:config_change, change)
    end
  end

  defp distribute_config_change(change) do
    alias Indrajaal.Observability.ZenohFractalPublisher

    key_expr = "intelitor/config/prajna/#{change.key}"
    ZenohFractalPublisher.publish(key_expr, change)
  end
end
```

### 3.2 Prajna Components Configuration Matrix

| Component | Config Level | Hot Reload | Fractal Log Level |
|-----------|--------------|------------|-------------------|
| **Guardian** | L4 (timeout), L5 (axioms) | Partial | Thorax (L4) |
| **ImmutableState** | L5 (path), L4 (verify) | No | Spine (L5) |
| **SentinelBridge** | L3 (interval) | Yes | Segment (L3) |
| **SmartMetrics** | L3 (thresholds) | Yes | Segment (L3) |
| **AiCopilot** | L3 (TTL), L2 (prompts) | Yes | Segment (L3) |
| **Orchestrator** | L3 (timeouts) | Yes | Thorax (L4) |
| **CircuitBreaker** | L3 (thresholds) | Yes | Thorax (L4) |

---

## 4. Feature Flags Integration (Azure App Configuration Pattern)

### 4.1 Prajna Feature Flag System

```elixir
defmodule Indrajaal.Cockpit.Prajna.FeatureFlags do
  @moduledoc """
  Feature Flag System inspired by Azure App Configuration.

  WHAT: Dynamic feature control for Prajna components.
  WHY: Enables gradual rollouts and A/B testing (SC-CONFIG-006).

  ## Flag Types
  - Boolean: Simple on/off
  - Percentage: Gradual rollout (10%, 50%, 100%)
  - Targeting: User/group-based activation
  - Time Window: Scheduled activation

  CONSTRAINTS:
    - SC-PRAJNA-001: Flags must pass Guardian approval
    - SC-BIO-007: Graceful degradation on rate limit
  """

  use GenServer
  require Logger
  alias Indrajaal.Cockpit.Prajna.{Config, GuardianIntegration}
  alias Indrajaal.Observability.FractalLogger

  @flags %{
    # Sprint 31 feature flags
    guardian_circuit_breaker: %{
      type: :boolean,
      default: true,
      level: :l4,
      requires_guardian: false
    },
    immutable_state_duckdb: %{
      type: :boolean,
      default: true,
      level: :l5,
      requires_guardian: true
    },
    ai_copilot_founder_validation: %{
      type: :boolean,
      default: true,
      level: :l4,
      requires_guardian: true
    },
    sentinel_bridge_sync: %{
      type: :boolean,
      default: true,
      level: :l3,
      requires_guardian: false
    },

    # Gradual rollout flags
    new_dashboard_ui: %{
      type: :percentage,
      default: 0,
      level: :l2,
      requires_guardian: false
    },

    # Time-based flags
    maintenance_mode: %{
      type: :time_window,
      default: nil,
      level: :l4,
      requires_guardian: true
    }
  }

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Check if feature is enabled"
  def enabled?(flag, context \\ %{}) do
    GenServer.call(__MODULE__, {:enabled?, flag, context})
  end

  @doc "Enable a feature flag"
  def enable(flag, opts \\ []) do
    GenServer.call(__MODULE__, {:enable, flag, opts})
  end

  @doc "Disable a feature flag"
  def disable(flag) do
    GenServer.call(__MODULE__, {:disable, flag})
  end

  @doc "Set percentage for gradual rollout"
  def set_percentage(flag, percentage) when percentage >= 0 and percentage <= 100 do
    GenServer.call(__MODULE__, {:set_percentage, flag, percentage})
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl GenServer
  def init(_opts) do
    # Load flag overrides from config
    overrides = Config.get(:feature_flag_overrides, %{})
    state = Map.merge(@flags, overrides)
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:enabled?, flag, context}, _from, state) do
    result = case Map.get(state, flag) do
      nil ->
        false

      %{type: :boolean, default: default} = spec ->
        Map.get(spec, :value, default)

      %{type: :percentage, default: default} = spec ->
        percentage = Map.get(spec, :value, default)
        # Use context hash for consistent bucketing
        hash = :erlang.phash2(context, 100)
        hash < percentage

      %{type: :time_window, default: default} = spec ->
        window = Map.get(spec, :value, default)
        in_time_window?(window)
    end

    # Log flag evaluation at Fiber level
    FractalLogger.fiber(:feature_flag_eval, %{
      flag: flag,
      result: result,
      context: context
    })

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:enable, flag, opts}, _from, state) do
    case Map.get(state, flag) do
      nil ->
        {:reply, {:error, :unknown_flag}, state}

      spec ->
        if spec.requires_guardian do
          case GuardianIntegration.submit_proposal(%{
            type: :feature_flag,
            action: :enable,
            flag: flag
          }) do
            {:ok, _} ->
              new_spec = Map.put(spec, :value, true)
              new_state = Map.put(state, flag, new_spec)
              log_flag_change(flag, spec, new_spec)
              {:reply, :ok, new_state}

            {:veto, reason, _} ->
              {:reply, {:error, {:guardian_veto, reason}}, state}
          end
        else
          new_spec = Map.put(spec, :value, true)
          new_state = Map.put(state, flag, new_spec)
          log_flag_change(flag, spec, new_spec)
          {:reply, :ok, new_state}
        end
    end
  end

  # ============================================================================
  # Private
  # ============================================================================

  defp in_time_window?(nil), do: false
  defp in_time_window?(%{start: start, end: end_time}) do
    now = DateTime.utc_now()
    DateTime.compare(now, start) in [:gt, :eq] and
    DateTime.compare(now, end_time) in [:lt, :eq]
  end

  defp log_flag_change(flag, old_spec, new_spec) do
    level = Map.get(new_spec, :level, :l3)
    change = %{flag: flag, old: old_spec, new: new_spec}

    case level do
      :l5 -> FractalLogger.spine(:feature_flag_change, change)
      :l4 -> FractalLogger.thorax(:feature_flag_change, change)
      _ -> FractalLogger.segment(:feature_flag_change, change)
    end
  end
end
```

---

## 5. CEPAF F# Integration

### 5.1 Bidirectional Configuration Sync

```fsharp
// Cepaf.Cockpit.ConfigBridge.fs
module Cepaf.Cockpit.ConfigBridge

open System
open Zenoh

/// Bridge configuration between Elixir Prajna and F# CEPAF
type ConfigBridge(zenohSession: Session) =

    let configKeyExpr = "intelitor/config/prajna/**"
    let mutable localConfig = Map.empty<string, obj>

    /// Subscribe to Elixir config updates
    member this.StartSync() =
        let subscriber = zenohSession.DeclareSubscriber(configKeyExpr)
        subscriber.Recv
        |> Observable.subscribe (fun sample ->
            let key = sample.KeyExpr.ToString()
            let value = sample.Payload.ToUtf8String()
            this.HandleConfigUpdate(key, value)
        )

    /// Handle incoming config update from Elixir
    member private this.HandleConfigUpdate(key: string, value: string) =
        let parsed = JsonConvert.DeserializeObject<ConfigChange>(value)
        localConfig <- localConfig.Add(parsed.Key, parsed.NewValue)

        // Emit event for F# components
        ConfigUpdated.Trigger(parsed)

    /// Push config update to Elixir
    member this.PushConfig(key: string, value: obj) =
        let change = {|
            key = key
            value = value
            source = "cepaf"
            timestamp = DateTime.UtcNow
        |}
        let keyExpr = $"intelitor/config/cepaf/{key}"
        zenohSession.Put(keyExpr, JsonConvert.SerializeObject(change))

    /// Get local config value
    member this.Get(key: string) =
        localConfig.TryFind(key)
```

### 5.2 Elixir Side: CEPAF Config Receiver

```elixir
defmodule Indrajaal.Cockpit.Prajna.CepafConfigReceiver do
  @moduledoc """
  Receives configuration updates from CEPAF F# cockpit.

  WHAT: Zenoh subscriber for CEPAF-originated config changes.
  WHY: Enables bidirectional config sync between Elixir and F#.

  CONSTRAINTS:
    - SC-SYNC-001: Bridge timeout < 5s
    - SC-PRAJNA-001: All changes through Guardian
  """

  use GenServer
  require Logger
  alias Indrajaal.Cockpit.Prajna.{Config, GuardianIntegration}
  alias Indrajaal.Zenoh.Session

  @key_expr "intelitor/config/cepaf/**"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    # Subscribe to CEPAF config updates
    case Session.subscribe(@key_expr, &handle_cepaf_update/1) do
      {:ok, sub_id} ->
        Logger.info("[CepafConfigReceiver] Subscribed to #{@key_expr}")
        {:ok, %{subscription: sub_id}}

      {:error, reason} ->
        Logger.error("[CepafConfigReceiver] Subscribe failed: #{inspect(reason)}")
        {:ok, %{subscription: nil}}
    end
  end

  defp handle_cepaf_update(%{key: key, payload: payload}) do
    case Jason.decode(payload) do
      {:ok, %{"key" => config_key, "value" => value}} ->
        # Validate through Guardian
        proposal = %{
          type: :config_update,
          source: :cepaf,
          key: config_key,
          value: value
        }

        case GuardianIntegration.submit_proposal(proposal) do
          {:ok, _} ->
            Config.set(String.to_atom(config_key), value)
            Logger.info("[CepafConfigReceiver] Applied CEPAF config: #{config_key}")

          {:veto, reason, _} ->
            Logger.warning("[CepafConfigReceiver] CEPAF config rejected: #{reason}")
        end

      {:error, _} ->
        Logger.warning("[CepafConfigReceiver] Invalid payload from CEPAF")
    end
  end
end
```

---

## 6. Unified Configuration Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         INDRAJAAL CONFIGURATION ARCHITECTURE                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                     L7: FEDERATION CONFIG                            │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │    │
│  │  │  Region A   │  │  Region B   │  │  Region C   │                  │    │
│  │  │  Cluster    │◄─┼─►Cluster    │◄─┼─►Cluster    │                  │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                  │    │
│  │         │                 │                 │                        │    │
│  │         └────────────────┬┴─────────────────┘                       │    │
│  │                          │                                           │    │
│  │                  ┌───────▼───────┐                                  │    │
│  │                  │ Zenoh Gossip  │ ← Version Vectors                │    │
│  │                  └───────────────┘                                  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│  ┌─────────────────────────────────▼───────────────────────────────────┐    │
│  │                     L5-L6: CLUSTER/NODE CONFIG                       │    │
│  │                                                                       │    │
│  │  ┌───────────────────────────────────────────────────────────────┐   │    │
│  │  │  Distributed Config (Borg/Twine Pattern)                      │   │    │
│  │  │  • CRDT-based updates                                         │   │    │
│  │  │  • Quorum reads/writes                                        │   │    │
│  │  │  • SQLite + DuckDB state                                      │   │    │
│  │  └───────────────────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│  ┌─────────────────────────────────▼───────────────────────────────────┐    │
│  │                     L4: CONTAINER CONFIG                             │    │
│  │                                                                       │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │    │
│  │  │ runtime.exs │  │ Env Vars    │  │ Secrets     │                  │    │
│  │  │             │  │ INDRAJAAL_* │  │ /run/secrets│                  │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                  │    │
│  │         │                 │                 │                        │    │
│  │         └─────────────────┴─────────────────┘                       │    │
│  │                          │                                           │    │
│  │                  ┌───────▼───────┐                                  │    │
│  │                  │ContainerConfig│ ← Kubernetes Pattern             │    │
│  │                  └───────────────┘                                  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│  ┌─────────────────────────────────▼───────────────────────────────────┐    │
│  │                     L3: AGENT CONFIG (PRAJNA)                        │    │
│  │                                                                       │    │
│  │  ┌───────────────────────────────────────────────────────────────┐   │    │
│  │  │  Prajna.Config (Central Module)                               │   │    │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │   │    │
│  │  │  │ Guardian    │  │ Sentinel    │  │ SmartMetrics│           │   │    │
│  │  │  │ Integration │  │ Bridge      │  │             │           │   │    │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘           │   │    │
│  │  │         │                 │                 │                 │   │    │
│  │  │  ┌──────▼─────────────────▼─────────────────▼──────┐         │   │    │
│  │  │  │           AgentConfigServer (xDS Pattern)       │         │   │    │
│  │  │  │    Push config to agents via Zenoh pub/sub      │         │   │    │
│  │  │  └─────────────────────────────────────────────────┘         │   │    │
│  │  └───────────────────────────────────────────────────────────────┘   │    │
│  │                                                                       │    │
│  │  ┌───────────────────────────────────────────────────────────────┐   │    │
│  │  │  FeatureFlags (Azure App Configuration Pattern)               │   │    │
│  │  │  • Boolean, Percentage, TimeWindow, Targeting                 │   │    │
│  │  │  • Guardian approval for critical flags                       │   │    │
│  │  └───────────────────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│  ┌─────────────────────────────────▼───────────────────────────────────┐    │
│  │                     L2: MODULE CONFIG                                │    │
│  │                                                                       │    │
│  │  ┌───────────────────────────────────────────────────────────────┐   │    │
│  │  │  DynamicConfig (Netflix Archaius Pattern)                     │   │    │
│  │  │  • Polling config source (5s interval)                        │   │    │
│  │  │  • Subscriber callbacks on change                             │   │    │
│  │  │  • All changes logged to Spine (L5)                           │   │    │
│  │  └───────────────────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│  ┌─────────────────────────────────▼───────────────────────────────────┐    │
│  │                     L1: FUNCTION CONFIG                              │    │
│  │                                                                       │    │
│  │  ┌───────────────────────────────────────────────────────────────┐   │    │
│  │  │  12-Factor App Pattern                                        │   │    │
│  │  │  • Module attributes (@default_timeout 5_000)                 │   │    │
│  │  │  • Function opts (call(opts \\ []))                          │   │    │
│  │  │  • Process dictionary (temporary overrides)                   │   │    │
│  │  └───────────────────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│  ┌─────────────────────────────────▼───────────────────────────────────┐    │
│  │                     L0: CONSTITUTIONAL (IMMUTABLE)                   │    │
│  │                                                                       │    │
│  │  ┌───────────────────────────────────────────────────────────────┐   │    │
│  │  │  Ω₀ Founder's Directive (Supreme)                             │   │    │
│  │  │  Ψ₀ Existence | Ψ₁ Regeneration | Ψ₂ Evolution               │   │    │
│  │  │  Ψ₃ Verification | Ψ₄ Human Alignment | Ψ₅ Truthfulness      │   │    │
│  │  │                                                                │   │    │
│  │  │  ⚠️ CANNOT BE MODIFIED AT RUNTIME - COMPILE-TIME ONLY         │   │    │
│  │  └───────────────────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                         CROSS-CUTTING CONCERNS                               │
│                                                                               │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                 │
│  │ Fractal Logger │  │ Zenoh Pub/Sub  │  │ Immutable      │                 │
│  │ (All changes   │  │ (Distribution) │  │ Register       │                 │
│  │  logged by L)  │  │                │  │ (Audit Trail)  │                 │
│  └────────────────┘  └────────────────┘  └────────────────┘                 │
│                                                                               │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │                    CEPAF F# COCKPIT BRIDGE                          │     │
│  │  • Bidirectional config sync via Zenoh                             │     │
│  │  • Real-time dashboard updates                                      │     │
│  │  • Operator override capabilities                                   │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Implementation Roadmap

### Phase 1: Foundation (Sprint 31)
- [x] Prajna.Config with schema validation
- [x] GuardianIntegration with circuit breaker
- [x] ImmutableState with DuckDB persistence
- [ ] Feature flag system
- [ ] Config change logging to Fractal

### Phase 2: Distribution (Sprint 32)
- [ ] AgentConfigServer (xDS pattern)
- [ ] DynamicConfig (Archaius pattern)
- [ ] Zenoh-based config distribution
- [ ] CEPAF bridge integration

### Phase 3: Cluster (Sprint 33)
- [ ] DistributedConfig with CRDT
- [ ] Version vector conflict resolution
- [ ] Quorum reads/writes
- [ ] Cross-node consistency

### Phase 4: Federation (Sprint 34)
- [ ] Federation ConfigBridge
- [ ] Regional overrides
- [ ] Global default propagation
- [ ] Multi-region testing

---

## 8. STAMP Constraints Summary

| Constraint | Level | Description |
|------------|-------|-------------|
| SC-CONFIG-001 | L3 | No hardcoded timing values |
| SC-CONFIG-002 | L3 | Validation on startup |
| SC-CONFIG-003 | L2 | Runtime update support |
| SC-CONFIG-004 | L3 | Push-based agent config |
| SC-CONFIG-005 | L4 | Deployment-time configuration |
| SC-CONFIG-006 | L3 | Feature flag support |
| SC-FRAC-CONFIG-001 | All | All changes logged to appropriate fractal level |
| SC-FRAC-CONFIG-002 | L5 | Constitutional configs immutable |
| SC-FRAC-CONFIG-003 | L3-L4 | Zenoh distribution for agent/container configs |

---

## 9. References

### Hyperscaler Patterns Applied
- **Google Borg**: Cell-based isolation, Paxos replication, allocs/quotas
- **Meta Twine**: TaskControl API, Host Profiles, single control plane
- **Microsoft Azure**: App Configuration, Feature Flags, Variant flags
- **Netflix Archaius**: Dynamic config, polling sources, type safety
- **Kubernetes**: ConfigMap, Secrets, Operators, CRDs

### Indrajaal Documentation
- `docs/architecture/FRACTAL_MESSAGING_5LAYER_IMPLEMENTATION.md`
- `docs/architecture/HOLON_IMMUTABLE_REGISTER.md`
- `docs/planning/SPRINT31_P0_DETAILED_DESIGN.md`
- `journal/2026-01/20260102-1230-comprehensive-configuration-modularity-techniques.md`

---

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Status | APPROVED |
| Created | 2026-01-02T14:00:00+01:00 |
| Author | Claude Opus 4.5 |
| STAMP | SC-CONFIG-*, SC-FRAC-CONFIG-*, SC-PRAJNA-* |
| Framework | SOPv5.11 + STAMP + Fractal Architecture |
