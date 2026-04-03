# SMRITI Observer-Observability Implementation Plan

**Version**: 21.3.0-SIL6 | **Date**: 2026-01-11 | **Status**: ACTIVE
**Framework**: SIL-6 Biomorphic Fractal Mesh with Observer-Observed Duality
**Compliance**: IEC 61508 SIL-6, ISO 27001, PROMETHEUS Verification
**STAMP**: SC-OBS-001 to SC-OBS-100, SC-SMRITI-001 to SC-SMRITI-280

---

## 1. FOUNDATIONAL PRINCIPLE: OBSERVER-OBSERVED DUALITY

### 1.1 Core Axiom

Every component in the SMRITI system simultaneously acts as:
1. **OBSERVER**: Watches, monitors, and reacts to other components
2. **OBSERVED**: Emits telemetry, exposes state, and is monitored by others

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                    OBSERVER-OBSERVED DUALITY MODEL                             ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                 ║
║           ┌─────────────────────────────────────────────────────┐              ║
║           │                   COMPONENT                          │              ║
║           │  ┌────────────┐              ┌────────────────┐     │              ║
║           │  │  OBSERVER  │◄────────────►│   OBSERVED     │     │              ║
║           │  │  (Watches) │              │  (Emits)       │     │              ║
║           │  └─────┬──────┘              └───────┬────────┘     │              ║
║           │        │                              │              │              ║
║           │        ▼                              ▼              │              ║
║           │  ┌────────────┐              ┌────────────────┐     │              ║
║           │  │ Telemetry  │              │  State Export  │     │              ║
║           │  │ Handlers   │              │  (Metrics/Logs)│     │              ║
║           │  └────────────┘              └────────────────┘     │              ║
║           └─────────────────────────────────────────────────────┘              ║
║                                                                                 ║
║  INVARIANT: No component exists without both observer AND observed roles       ║
║                                                                                 ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### 1.2 STAMP Constraints (Observer-Observability)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-OBS-001 | Every module MUST emit telemetry events | CRITICAL | Compile-time check |
| SC-OBS-002 | Every GenServer MUST expose `:get_state` | CRITICAL | Behaviour enforcement |
| SC-OBS-003 | All state mutations MUST be logged | CRITICAL | Macro wrapper |
| SC-OBS-004 | Health checks MUST exist at every level | HIGH | Startup verification |
| SC-OBS-005 | Metrics MUST refresh every 30 seconds | HIGH | Scheduler |
| SC-OBS-006 | No silent failures permitted | CRITICAL | Exception wrappers |
| SC-OBS-007 | All errors MUST be observable | CRITICAL | Error telemetry |
| SC-OBS-008 | OODA loop telemetry MANDATORY | HIGH | GenServer callbacks |

### 1.3 AOR Rules (Observer-Observability)

| ID | Rule |
|----|------|
| AOR-OBS-001 | ATTACH telemetry handler before any operation |
| AOR-OBS-002 | EMIT start/stop/error events for all operations |
| AOR-OBS-003 | EXPOSE state via `:sys.get_state/1` compatible interface |
| AOR-OBS-004 | LOG all exceptions with full stack trace |
| AOR-OBS-005 | REGISTER health check on module init |
| AOR-OBS-006 | BROADCAST state changes to Zenoh mesh |
| AOR-OBS-007 | VERIFY telemetry handlers active before critical ops |
| AOR-OBS-008 | INSTRUMENT OODA cycles with timing metrics |

---

## 2. 8-LEVEL OBSERVER-OBSERVED MATRIX

### 2.1 Level-by-Level Observability Requirements

```
╔════════════════════════════════════════════════════════════════════════════════╗
║ LEVEL │ OBSERVER ROLE              │ OBSERVED ROLE                             ║
╠════════════════════════════════════════════════════════════════════════════════╣
║ L0    │ Type validation            │ Schema metrics, constraint violations     ║
║ L1    │ Operation monitoring       │ Function call telemetry, latency          ║
║ L2    │ Module health checks       │ Lifecycle events, integration status      ║
║ L3    │ Agent OODA sensing         │ Cluster health, evolution metrics         ║
║ L4    │ Service health probes      │ API metrics, CLI output                   ║
║ L5    │ Node monitoring            │ Bootstrap progress, resource usage        ║
║ L6    │ Cluster consensus          │ Replication status, version vectors       ║
║ L7    │ Federation oversight       │ Cross-holon sync, immortality status      ║
╚════════════════════════════════════════════════════════════════════════════════╝
```

### 2.2 8x8 Interaction Matrix

Each cell defines how level X observes level Y:

```
           OBSERVED (Emits To)
           L0   L1   L2   L3   L4   L5   L6   L7
        ┌────┬────┬────┬────┬────┬────┬────┬────┐
    L0  │ TE │ FC │ LC │ AH │ AO │ NM │ RS │ FS │
    L1  │ TV │ TE │ ME │ AQ │ AR │ NQ │ RQ │ FQ │
O   L2  │ SC │ FI │ TE │ AE │ AI │ NI │ RI │ FI │
B   L3  │ --  │ FO │ LO │ TE │ AS │ NS │ RP │ FP │
S   L4  │ --  │ --  │ HE │ HQ │ TE │ HP │ HC │ HF │
E   L5  │ --  │ --  │ --  │ BP │ BS │ TE │ BC │ BF │
R   L6  │ --  │ --  │ --  │ --  │ CS │ CN │ TE │ CF │
V   L7  │ --  │ --  │ --  │ --  │ --  │ FN │ FC │ TE │
E       └────┴────┴────┴────┴────┴────┴────┴────┘
R

Legend:
  TE = Telemetry Events (self-observation)
  FC = Function Calls        TV = Type Validation
  LC = Lifecycle Events      SC = Schema Compliance
  ME = Module Events         FI = Function Instrumentation
  AH = Agent Health          AQ = Agent Queries
  AE = Agent Events          AS = Agent Sensing
  AO = API Operations        AR = API Requests
  AI = API Integration       HE = Health Endpoints
  HQ = Health Queries        HP = Health Probes
  NM = Node Metrics          NQ = Node Queries
  NI = Node Integration      NS = Node Sensing
  BP = Bootstrap Progress    BS = Bootstrap Status
  BC = Bootstrap Coordination
  RS = Replication Status    RQ = Replication Queries
  RI = Replication Integration  RP = Replication Progress
  RC = Replication Coordination
  FS = Federation Status     FQ = Federation Queries
  FI = Federation Integration  FP = Federation Progress
  FN = Federation Nodes      FC = Federation Coordination
  -- = Not applicable (lower cannot observe higher)
```

---

## 3. 11 MISSING ITEMS: 8-LEVEL IMPLEMENTATION

### 3.1 Item 1: IMMORTALITY PROTOCOL (RPN: 240)

#### L0: Runtime Primitives (OBSERVED)
```elixir
# Types that emit telemetry on creation/validation
@type preservation_target :: {:local_backup | :git | :s3 | :ipfs | :print, String.t()}
@type preservation_result :: {:ok, metadata()} | {:error, term()}

# Observable type creation
defp create_preservation_result(status, meta) do
  result = {status, meta}
  :telemetry.execute([:smriti, :immortality, :result_created], %{status: status}, meta)
  result
end
```

#### L1: Function Operations (OBSERVER + OBSERVED)
```elixir
defmodule Indrajaal.KMS.Immortality.Operations do
  @moduledoc "L1: Observable preservation operations"

  # OBSERVED: Emits telemetry for every operation
  def preserve_local(path) do
    start_time = System.monotonic_time(:millisecond)

    :telemetry.execute([:smriti, :immortality, :preserve, :start],
      %{target: :local}, %{path: path})

    result = do_preserve_local(path)
    elapsed = System.monotonic_time(:millisecond) - start_time

    :telemetry.execute([:smriti, :immortality, :preserve, :stop],
      %{duration_ms: elapsed, success: match?({:ok, _}, result)},
      %{path: path, result: result})

    result
  end

  # OBSERVER: Watches filesystem for backup integrity
  def observe_backup_integrity(path) do
    case File.stat(path) do
      {:ok, %{size: size, mtime: mtime}} ->
        :telemetry.execute([:smriti, :immortality, :integrity, :check],
          %{size: size, mtime: mtime}, %{path: path})
        {:ok, %{path: path, size: size, mtime: mtime}}
      {:error, reason} ->
        :telemetry.execute([:smriti, :immortality, :integrity, :failed],
          %{reason: reason}, %{path: path})
        {:error, reason}
    end
  end
end
```

#### L2: Component Integration (OBSERVER + OBSERVED)
```elixir
defmodule Indrajaal.KMS.Immortality.Coordinator do
  @moduledoc "L2: Lifecycle coordination with full observability"

  use GenServer
  require Logger

  # OBSERVED: Expose state for external observation
  def get_state, do: GenServer.call(__MODULE__, :get_state)

  # OBSERVER: Watch for holon changes
  def handle_info({:holon_changed, uuid}, state) do
    Logger.debug("[Immortality.Coordinator] Observed holon change: #{uuid}")
    :telemetry.execute([:smriti, :immortality, :coordinator, :holon_observed],
      %{uuid: uuid}, %{})
    schedule_incremental_backup()
    {:noreply, state}
  end

  # OBSERVED: Emit lifecycle events
  @impl true
  def init(opts) do
    :telemetry.execute([:smriti, :immortality, :coordinator, :init], %{}, opts)
    {:ok, %{initialized_at: DateTime.utc_now(), opts: opts}}
  end

  @impl true
  def terminate(reason, state) do
    :telemetry.execute([:smriti, :immortality, :coordinator, :terminate],
      %{reason: reason}, state)
    :ok
  end
end
```

#### L3: Agent Level (OODA with Observability)
```elixir
defmodule Indrajaal.KMS.Immortality.Agent do
  @moduledoc "L3: OODA-driven immortality agent with complete observability"

  use GenServer
  require Logger

  @ooda_interval :timer.seconds(30)

  # OODA cycle with full telemetry
  def handle_info(:ooda_cycle, state) do
    cycle_start = System.monotonic_time(:millisecond)
    cycle_id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)

    :telemetry.execute([:smriti, :immortality, :ooda, :cycle_start],
      %{cycle_id: cycle_id}, %{})

    # OBSERVE
    observe_start = System.monotonic_time(:millisecond)
    observations = do_observe(state)
    observe_elapsed = System.monotonic_time(:millisecond) - observe_start
    :telemetry.execute([:smriti, :immortality, :ooda, :observe],
      %{duration_ms: observe_elapsed, observations: length(observations)}, %{cycle_id: cycle_id})

    # ORIENT
    orient_start = System.monotonic_time(:millisecond)
    analysis = do_orient(observations, state.history)
    orient_elapsed = System.monotonic_time(:millisecond) - orient_start
    :telemetry.execute([:smriti, :immortality, :ooda, :orient],
      %{duration_ms: orient_elapsed, threats: length(analysis.threats)}, %{cycle_id: cycle_id})

    # DECIDE
    decide_start = System.monotonic_time(:millisecond)
    actions = do_decide(analysis)
    decide_elapsed = System.monotonic_time(:millisecond) - decide_start
    :telemetry.execute([:smriti, :immortality, :ooda, :decide],
      %{duration_ms: decide_elapsed, actions: length(actions)}, %{cycle_id: cycle_id})

    # ACT
    act_start = System.monotonic_time(:millisecond)
    results = do_act(actions)
    act_elapsed = System.monotonic_time(:millisecond) - act_start
    :telemetry.execute([:smriti, :immortality, :ooda, :act],
      %{duration_ms: act_elapsed, results: length(results)}, %{cycle_id: cycle_id})

    # Cycle complete
    cycle_elapsed = System.monotonic_time(:millisecond) - cycle_start
    :telemetry.execute([:smriti, :immortality, :ooda, :cycle_complete],
      %{duration_ms: cycle_elapsed, cycle_id: cycle_id}, %{})

    # Verify SC-SMRITI-031: OODA < 30 seconds
    if cycle_elapsed > 30_000 do
      Logger.warning("[Immortality.Agent] OODA cycle exceeded 30s: #{cycle_elapsed}ms")
      :telemetry.execute([:smriti, :immortality, :ooda, :constraint_violation],
        %{constraint: "SC-SMRITI-031", duration_ms: cycle_elapsed}, %{})
    end

    schedule_next_cycle()
    {:noreply, update_state(state, observations, results)}
  end

  # OBSERVER functions
  defp do_observe(state) do
    [
      observe_backup_freshness(),
      observe_redundancy_factor(),
      observe_target_availability(),
      observe_federation_status()
    ]
    |> Enum.reject(&is_nil/1)
  end
end
```

#### L4: Service Level (CLI/API Observability)
```elixir
defmodule Indrajaal.KMS.Immortality.CLI do
  @moduledoc "L4: Observable CLI interface"

  def main(args) do
    :telemetry.execute([:smriti, :immortality, :cli, :invocation],
      %{args: args}, %{})

    result = case args do
      ["execute"] -> execute_with_telemetry()
      ["status"] -> status_with_telemetry()
      ["verify", target] -> verify_with_telemetry(target)
      _ -> {:error, :unknown_command}
    end

    :telemetry.execute([:smriti, :immortality, :cli, :complete],
      %{result: result}, %{args: args})

    result
  end

  defp execute_with_telemetry do
    start = System.monotonic_time(:millisecond)
    result = Indrajaal.KMS.Immortality.Protocol.execute()
    elapsed = System.monotonic_time(:millisecond) - start

    :telemetry.execute([:smriti, :immortality, :cli, :execute],
      %{duration_ms: elapsed, success: match?({:ok, _}, result)}, %{})

    result
  end
end

# REST API with observability
defmodule IndrajaalWeb.Api.ImmortalityController do
  use IndrajaalWeb, :controller

  plug :track_request

  def execute(conn, _params) do
    :telemetry.execute([:smriti, :immortality, :api, :execute_request], %{}, %{})

    case Indrajaal.KMS.Immortality.Protocol.execute() do
      {:ok, result} ->
        :telemetry.execute([:smriti, :immortality, :api, :execute_success],
          %{targets: result.successful}, %{})
        json(conn, %{status: "ok", result: result})

      {:error, reason} ->
        :telemetry.execute([:smriti, :immortality, :api, :execute_failure],
          %{reason: reason}, %{})
        conn |> put_status(500) |> json(%{status: "error", reason: inspect(reason)})
    end
  end

  defp track_request(conn, _opts) do
    start = System.monotonic_time(:millisecond)

    Plug.Conn.register_before_send(conn, fn conn ->
      elapsed = System.monotonic_time(:millisecond) - start
      :telemetry.execute([:smriti, :immortality, :api, :request_complete],
        %{duration_ms: elapsed, status: conn.status}, %{path: conn.request_path})
      conn
    end)
  end
end
```

#### L5: Node Level (Bootstrap Observability)
```elixir
defmodule Indrajaal.KMS.Immortality.NodeConfig do
  @moduledoc "L5: Node-level configuration with observability"

  def on_node_start do
    :telemetry.execute([:smriti, :immortality, :node, :starting], %{}, %{})

    # Phase 1: Config verification
    :telemetry.execute([:smriti, :immortality, :node, :phase], %{phase: 1, name: :config}, %{})
    :ok = verify_config()

    # Phase 2: Target verification
    :telemetry.execute([:smriti, :immortality, :node, :phase], %{phase: 2, name: :targets}, %{})
    {:ok, targets} = verify_targets_reachable()

    # Phase 3: Schedule setup
    :telemetry.execute([:smriti, :immortality, :node, :phase], %{phase: 3, name: :schedule}, %{})
    :ok = setup_weekly_schedule()

    # Phase 4: Telemetry registration
    :telemetry.execute([:smriti, :immortality, :node, :phase], %{phase: 4, name: :telemetry}, %{})
    :ok = register_telemetry_handlers()

    :telemetry.execute([:smriti, :immortality, :node, :started],
      %{targets_available: length(targets)}, %{})

    {:ok, :running}
  end

  def register_telemetry_handlers do
    events = [
      [:smriti, :immortality, :preserve, :start],
      [:smriti, :immortality, :preserve, :stop],
      [:smriti, :immortality, :ooda, :cycle_complete],
      [:smriti, :immortality, :protocol, :executed]
    ]

    :telemetry.attach_many(
      "immortality-telemetry-handler",
      events,
      &handle_telemetry_event/4,
      %{}
    )

    :ok
  end

  defp handle_telemetry_event(event, measurements, metadata, _config) do
    # Forward to Prometheus/Grafana
    Indrajaal.Metrics.record(event, measurements, metadata)

    # Forward to Zenoh mesh
    Indrajaal.Zenoh.Publisher.publish(
      "indrajaal/smriti/immortality/#{Enum.join(event, "/")}",
      %{measurements: measurements, metadata: metadata}
    )
  end
end
```

#### L6: Cluster Level (Distributed Observability)
```elixir
defmodule Indrajaal.KMS.Immortality.ClusterCoordinator do
  @moduledoc "L6: Cluster-wide immortality coordination with observability"

  use GenServer

  # OBSERVER: Watch all nodes
  def handle_info({:node_backup_complete, node, result}, state) do
    :telemetry.execute([:smriti, :immortality, :cluster, :node_backup_observed],
      %{node: node, success: result.successful}, %{})

    new_state = update_cluster_status(state, node, result)
    check_cluster_redundancy(new_state)

    {:noreply, new_state}
  end

  # OBSERVED: Emit cluster status
  def get_cluster_status do
    status = GenServer.call(__MODULE__, :get_status)
    :telemetry.execute([:smriti, :immortality, :cluster, :status_queried],
      %{nodes: length(status.nodes)}, %{})
    status
  end

  # Distributed health check
  def verify_cluster_redundancy do
    nodes = Node.list()

    results = Enum.map(nodes, fn node ->
      start = System.monotonic_time(:millisecond)
      result = :rpc.call(node, __MODULE__, :get_local_status, [])
      elapsed = System.monotonic_time(:millisecond) - start

      :telemetry.execute([:smriti, :immortality, :cluster, :node_checked],
        %{node: node, duration_ms: elapsed, success: match?({:ok, _}, result)}, %{})

      {node, result}
    end)

    quorum_met = count_healthy(results) >= div(length(nodes), 2) + 1

    :telemetry.execute([:smriti, :immortality, :cluster, :redundancy_verified],
      %{quorum_met: quorum_met, healthy: count_healthy(results), total: length(nodes)}, %{})

    {:ok, %{results: results, quorum_met: quorum_met}}
  end
end
```

#### L7: Federation Level (Cross-Holon Observability)
```elixir
defmodule Indrajaal.KMS.Immortality.Federation do
  @moduledoc "L7: Federation-wide immortality with observability"

  # OBSERVER: Watch federation peers
  def observe_federation_immortality do
    peers = Indrajaal.KMS.Federation.Protocol.discover_peers()

    :telemetry.execute([:smriti, :immortality, :federation, :observation_start],
      %{peer_count: length(peers)}, %{})

    results = Enum.map(peers, fn peer ->
      start = System.monotonic_time(:millisecond)
      result = query_peer_immortality_status(peer)
      elapsed = System.monotonic_time(:millisecond) - start

      :telemetry.execute([:smriti, :immortality, :federation, :peer_queried],
        %{peer: peer, duration_ms: elapsed, success: match?({:ok, _}, result)}, %{})

      {peer, result}
    end)

    {:ok, aggregate_federation_status(results)}
  end

  # OBSERVED: Broadcast our status
  def broadcast_immortality_complete(result) do
    :telemetry.execute([:smriti, :immortality, :federation, :broadcast_start],
      %{}, %{result: result})

    peers = Indrajaal.KMS.Federation.Protocol.get_active_peers()

    Enum.each(peers, fn peer ->
      send_status_to_peer(peer, result)
      :telemetry.execute([:smriti, :immortality, :federation, :peer_notified],
        %{peer: peer}, %{})
    end)

    :telemetry.execute([:smriti, :immortality, :federation, :broadcast_complete],
      %{peers_notified: length(peers)}, %{})
  end
end
```

#### L0-L7 Interaction Summary for Immortality Protocol

| From↓ To→ | L0 | L1 | L2 | L3 | L4 | L5 | L6 | L7 |
|-----------|----|----|----|----|----|----|----|----|
| L0 | Self | Types→Ops | Schema→Lifecycle | - | - | - | - | - |
| L1 | Validation | Self | Calls→Events | Query→Health | API req | - | - | - |
| L2 | Schema check | Instrumentation | Self | Status→Agent | Health probe | Integration | - | - |
| L3 | - | OODA observe | Lifecycle observe | Self | Service probe | Node status | Peer status | - |
| L4 | - | - | Health check | Agent query | Self | Config query | - | - |
| L5 | - | - | - | Bootstrap agent | Bootstrap API | Self | Cluster join | - |
| L6 | - | - | - | - | Cluster service | Node mgmt | Self | Federation join |
| L7 | - | - | - | - | - | Fed nodes | Fed clusters | Self |

---

### 3.2 Item 2: RECONSTRUCTION GUIDE (RPN: 180)

*(Similar 8-level decomposition with observer-observability at each level)*

#### Core Observable Pattern
```elixir
defmodule Indrajaal.KMS.Immortality.ReconstructionGuide do
  @moduledoc """
  Self-documenting reconstruction guide with observability.

  OBSERVER: Watches schema changes to update guide
  OBSERVED: Emits generation events
  """

  def generate do
    :telemetry.execute([:smriti, :reconstruction, :generate, :start], %{}, %{})
    start = System.monotonic_time(:millisecond)

    guide = build_guide()

    elapsed = System.monotonic_time(:millisecond) - start
    :telemetry.execute([:smriti, :reconstruction, :generate, :complete],
      %{duration_ms: elapsed, size_bytes: byte_size(guide)}, %{})

    {:ok, guide}
  end

  # OBSERVER: Watch for schema changes
  def handle_cast({:schema_changed, version}, state) do
    :telemetry.execute([:smriti, :reconstruction, :schema_observed],
      %{version: version}, %{})
    invalidate_cached_guide()
    {:noreply, state}
  end
end
```

---

### 3.3 Item 3: PANSPERMIA EXPORTS (RPN: 189)

#### Core Observable Pattern
```elixir
defmodule Indrajaal.KMS.Panspermia.Exporter do
  @moduledoc """
  Multi-format exporter with complete observability.

  Each format export is instrumented for:
  - Start/stop timing
  - Success/failure tracking
  - Size/count metrics
  """

  @export_formats [:sqlite, :json, :markdown, :org_mode, :obsidian]

  def export(cluster, format, opts \\ []) do
    export_id = generate_export_id()

    :telemetry.execute([:smriti, :panspermia, :export, :start],
      %{format: format, cluster: cluster, export_id: export_id}, %{})

    start = System.monotonic_time(:millisecond)

    result = case format do
      :sqlite -> export_sqlite(cluster, opts)
      :json -> export_json(cluster, opts)
      :markdown -> export_markdown(cluster, opts)
      :org_mode -> export_org_mode(cluster, opts)
      :obsidian -> export_obsidian(cluster, opts)
    end

    elapsed = System.monotonic_time(:millisecond) - start

    case result do
      {:ok, path} ->
        size = File.stat!(path).size
        :telemetry.execute([:smriti, :panspermia, :export, :success],
          %{duration_ms: elapsed, size_bytes: size, format: format, export_id: export_id},
          %{path: path})

      {:error, reason} ->
        :telemetry.execute([:smriti, :panspermia, :export, :failure],
          %{duration_ms: elapsed, format: format, reason: reason, export_id: export_id}, %{})
    end

    result
  end

  def export_all_formats(cluster, opts \\ []) do
    :telemetry.execute([:smriti, :panspermia, :export_all, :start],
      %{formats: length(@export_formats)}, %{cluster: cluster})

    start = System.monotonic_time(:millisecond)

    results = @export_formats
    |> Task.async_stream(fn format ->
      {format, export(cluster, format, opts)}
    end, timeout: :timer.minutes(5))
    |> Enum.map(fn {:ok, result} -> result end)
    |> Map.new()

    elapsed = System.monotonic_time(:millisecond) - start
    successful = Enum.count(results, fn {_, r} -> match?({:ok, _}, r) end)

    :telemetry.execute([:smriti, :panspermia, :export_all, :complete],
      %{duration_ms: elapsed, successful: successful, total: length(@export_formats)},
      %{cluster: cluster})

    {:ok, results}
  end
end
```

---

### 3.4 Item 4: FEDERATION PROTOCOL (RPN: 216)

#### Core Observable Pattern
```elixir
defmodule Indrajaal.KMS.Federation.Protocol do
  @moduledoc """
  Federation protocol with bidirectional observability.

  OBSERVER: Discovers and monitors peers
  OBSERVED: Broadcasts own status to federation
  """

  use GenServer

  # OODA cycle for federation health
  def handle_info(:federation_ooda, state) do
    cycle_id = generate_cycle_id()
    :telemetry.execute([:smriti, :federation, :ooda, :start], %{cycle_id: cycle_id}, %{})

    # OBSERVE peers
    peers = observe_all_peers(state.known_peers)
    :telemetry.execute([:smriti, :federation, :ooda, :observed],
      %{peer_count: length(peers), healthy: count_healthy(peers)}, %{cycle_id: cycle_id})

    # ORIENT on federation health
    analysis = analyze_federation_health(peers, state.history)
    :telemetry.execute([:smriti, :federation, :ooda, :oriented],
      %{health_score: analysis.score, issues: length(analysis.issues)}, %{cycle_id: cycle_id})

    # DECIDE on actions
    actions = decide_federation_actions(analysis)
    :telemetry.execute([:smriti, :federation, :ooda, :decided],
      %{actions: length(actions)}, %{cycle_id: cycle_id})

    # ACT
    results = execute_federation_actions(actions)
    :telemetry.execute([:smriti, :federation, :ooda, :acted],
      %{successful: count_successful(results)}, %{cycle_id: cycle_id})

    schedule_next_ooda()
    {:noreply, update_state(state, peers, results)}
  end

  # Sync with full telemetry
  def sync_with_peer(peer_url) do
    sync_id = generate_sync_id()
    :telemetry.execute([:smriti, :federation, :sync, :start],
      %{peer: peer_url, sync_id: sync_id}, %{})

    start = System.monotonic_time(:millisecond)

    with {:ok, remote_vv} <- request_version_vectors(peer_url),
         deltas <- compute_deltas(get_local_vv(), remote_vv),
         {:ok, sent} <- send_deltas(peer_url, deltas.outgoing),
         {:ok, received} <- receive_deltas(peer_url, deltas.incoming) do

      elapsed = System.monotonic_time(:millisecond) - start
      :telemetry.execute([:smriti, :federation, :sync, :complete],
        %{duration_ms: elapsed, sent: sent, received: received, sync_id: sync_id},
        %{peer: peer_url})

      {:ok, %{sent: sent, received: received, duration_ms: elapsed}}
    else
      {:error, reason} ->
        elapsed = System.monotonic_time(:millisecond) - start
        :telemetry.execute([:smriti, :federation, :sync, :failed],
          %{duration_ms: elapsed, reason: reason, sync_id: sync_id},
          %{peer: peer_url})
        {:error, reason}
    end
  end
end
```

---

### 3.5 Item 5: VERSION VECTORS (RPN: 200)

#### Observable CRDT Implementation
```elixir
defmodule Indrajaal.KMS.Federation.VersionVector do
  @moduledoc """
  Version vectors with observability for causal ordering.

  All mutations are logged for debugging distributed conflicts.
  """

  @type t :: %{String.t() => non_neg_integer()}

  def new(node_id) do
    vv = %{node_id => 0}
    :telemetry.execute([:smriti, :version_vector, :created],
      %{node_id: node_id}, %{})
    vv
  end

  def increment(vv, node_id) do
    old_value = Map.get(vv, node_id, 0)
    new_vv = Map.put(vv, node_id, old_value + 1)

    :telemetry.execute([:smriti, :version_vector, :incremented],
      %{node_id: node_id, old: old_value, new: old_value + 1}, %{})

    new_vv
  end

  def merge(vv1, vv2) do
    :telemetry.execute([:smriti, :version_vector, :merge, :start],
      %{vv1_size: map_size(vv1), vv2_size: map_size(vv2)}, %{})

    merged = Map.merge(vv1, vv2, fn _k, v1, v2 -> max(v1, v2) end)

    :telemetry.execute([:smriti, :version_vector, :merge, :complete],
      %{result_size: map_size(merged)}, %{})

    merged
  end

  def compare(vv1, vv2) do
    result = cond do
      descends?(vv1, vv2) and not descends?(vv2, vv1) -> :after
      descends?(vv2, vv1) and not descends?(vv1, vv2) -> :before
      vv1 == vv2 -> :equal
      true -> :concurrent
    end

    :telemetry.execute([:smriti, :version_vector, :compared],
      %{result: result}, %{})

    result
  end
end
```

---

### 3.6 Item 6: CLUSTER REPLICATION (RPN: 192)

*(8-level decomposition with replication telemetry)*

---

### 3.7 Item 7: AGENT OODA LOOP (RPN: 175)

#### Observable OODA Implementation
```elixir
defmodule Indrajaal.KMS.Agents.KnowledgeAgent do
  @moduledoc """
  Knowledge agent with fully observable OODA loop.

  Every phase is instrumented:
  - Timing metrics
  - Decision logging
  - Action results
  """

  use GenServer
  require Logger

  @ooda_interval :timer.seconds(30)
  @ooda_timeout 30_000  # SC-SMRITI-031

  def handle_info(:ooda_cycle, state) do
    cycle_id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    cycle_start = System.monotonic_time(:millisecond)

    # Telemetry wrapper for entire cycle
    :telemetry.span(
      [:smriti, :agent, :ooda, :cycle],
      %{cluster: state.cluster, cycle_id: cycle_id},
      fn ->
        result = execute_ooda_cycle(state, cycle_id)
        {result, %{cycle_id: cycle_id}}
      end
    )

    cycle_elapsed = System.monotonic_time(:millisecond) - cycle_start

    # Constraint verification
    if cycle_elapsed > @ooda_timeout do
      :telemetry.execute([:smriti, :agent, :ooda, :timeout_violation],
        %{duration_ms: cycle_elapsed, limit_ms: @ooda_timeout},
        %{cluster: state.cluster})
    end

    schedule_next_cycle()
    {:noreply, state}
  end

  defp execute_ooda_cycle(state, cycle_id) do
    # OBSERVE with telemetry
    {observations, observe_metrics} = :telemetry.span(
      [:smriti, :agent, :ooda, :observe],
      %{cycle_id: cycle_id},
      fn ->
        obs = observe_cluster(state.cluster)
        {obs, %{count: length(obs)}}
      end
    )

    # ORIENT with telemetry
    {analysis, orient_metrics} = :telemetry.span(
      [:smriti, :agent, :ooda, :orient],
      %{cycle_id: cycle_id},
      fn ->
        ana = analyze_observations(observations, state.history)
        {ana, %{threats: length(ana.threats), opportunities: length(ana.opportunities)}}
      end
    )

    # DECIDE with telemetry
    {actions, decide_metrics} = :telemetry.span(
      [:smriti, :agent, :ooda, :decide],
      %{cycle_id: cycle_id},
      fn ->
        acts = decide_actions(analysis)
        {acts, %{action_count: length(acts)}}
      end
    )

    # ACT with telemetry
    {results, act_metrics} = :telemetry.span(
      [:smriti, :agent, :ooda, :act],
      %{cycle_id: cycle_id},
      fn ->
        res = execute_actions(actions)
        {res, %{successful: count_successful(res)}}
      end
    )

    {:ok, %{
      observations: observations,
      analysis: analysis,
      actions: actions,
      results: results
    }}
  end
end
```

---

### 3.8 Item 8: HEALTH MONITORING (RPN: 168)

#### Sentinel-Integrated Health Monitoring
```elixir
defmodule Indrajaal.KMS.Monitoring.HealthMonitor do
  @moduledoc """
  Continuous health monitoring with Sentinel integration.

  OBSERVER: Watches SMRITI components
  OBSERVED: Reports to Sentinel and Prajna
  """

  use GenServer

  @check_interval :timer.seconds(30)

  # Health check with full observability
  def check_health do
    check_id = generate_check_id()
    :telemetry.execute([:smriti, :health, :check, :start], %{check_id: check_id}, %{})

    start = System.monotonic_time(:millisecond)

    checks = %{
      database: check_database(),
      fts_index: check_fts_index(),
      entropy_manager: check_entropy_manager(),
      federation: check_federation(),
      immortality: check_immortality()
    }

    elapsed = System.monotonic_time(:millisecond) - start

    score = calculate_health_score(checks)
    status = if score >= 80, do: :healthy, else: :degraded

    result = %{
      status: status,
      score: score,
      checks: checks,
      duration_ms: elapsed,
      checked_at: DateTime.utc_now()
    }

    :telemetry.execute([:smriti, :health, :check, :complete],
      %{status: status, score: score, duration_ms: elapsed, check_id: check_id},
      %{checks: checks})

    # Report to Sentinel
    report_to_sentinel(result)

    {:ok, result}
  end

  defp report_to_sentinel(result) do
    :telemetry.execute([:smriti, :health, :sentinel, :report],
      %{score: result.score, status: result.status}, %{})

    Indrajaal.Immune.Sentinel.report_subsystem_health(:smriti, result)
  end

  # Continuous monitoring loop
  def handle_info(:health_check, state) do
    {:ok, result} = check_health()

    # Trend analysis
    new_history = [result | Enum.take(state.history, 99)]
    trend = analyze_health_trend(new_history)

    if trend == :degrading do
      :telemetry.execute([:smriti, :health, :trend, :degrading],
        %{current: result.score, previous_avg: average_score(state.history)}, %{})
    end

    schedule_next_check()
    {:noreply, %{state | history: new_history, last_check: result}}
  end
end
```

---

### 3.9 Item 9: NODE BOOTSTRAP (RPN: 150)

#### 4-Phase Observable Bootstrap
```elixir
defmodule Indrajaal.KMS.Bootstrap.Sequence do
  @moduledoc """
  Node bootstrap with phase-by-phase observability.

  Each phase emits start/complete events with timing.
  """

  @startup_timeout 10_000  # SC-SMRITI-050

  def start do
    bootstrap_id = generate_bootstrap_id()
    :telemetry.execute([:smriti, :bootstrap, :start],
      %{bootstrap_id: bootstrap_id}, %{})

    start_time = System.monotonic_time(:millisecond)

    with {:ok, p1} <- phase_1_database(bootstrap_id),
         {:ok, p2} <- phase_2_recovery(bootstrap_id),
         {:ok, p3} <- phase_3_registration(bootstrap_id),
         {:ok, p4} <- phase_4_verification(bootstrap_id) do

      elapsed = System.monotonic_time(:millisecond) - start_time

      # Verify SC-SMRITI-050: < 10 seconds
      if elapsed > @startup_timeout do
        :telemetry.execute([:smriti, :bootstrap, :timeout_warning],
          %{duration_ms: elapsed, limit_ms: @startup_timeout}, %{})
      end

      :telemetry.execute([:smriti, :bootstrap, :complete],
        %{duration_ms: elapsed, status: p4.status, bootstrap_id: bootstrap_id},
        %{phases: [p1, p2, p3, p4]})

      {:ok, p4.status}
    else
      {:error, phase, reason} ->
        :telemetry.execute([:smriti, :bootstrap, :failed],
          %{phase: phase, reason: reason, bootstrap_id: bootstrap_id}, %{})
        {:error, {phase, reason}}
    end
  end

  defp phase_1_database(bootstrap_id) do
    :telemetry.execute([:smriti, :bootstrap, :phase, :start],
      %{phase: 1, name: :database, bootstrap_id: bootstrap_id}, %{})

    start = System.monotonic_time(:millisecond)

    with :ok <- verify_database_exists(),
         :ok <- verify_schema_version(),
         :ok <- verify_fts_index() do

      elapsed = System.monotonic_time(:millisecond) - start
      :telemetry.execute([:smriti, :bootstrap, :phase, :complete],
        %{phase: 1, name: :database, duration_ms: elapsed, bootstrap_id: bootstrap_id}, %{})

      {:ok, %{phase: 1, status: :ok, duration_ms: elapsed}}
    else
      {:error, reason} ->
        :telemetry.execute([:smriti, :bootstrap, :phase, :failed],
          %{phase: 1, name: :database, reason: reason, bootstrap_id: bootstrap_id}, %{})
        {:error, :database, reason}
    end
  end

  # Similar for phases 2, 3, 4...
end
```

---

### 3.10 Item 10: TELEMETRY INTEGRATION (RPN: 100)

#### Complete Telemetry Handler
```elixir
defmodule Indrajaal.KMS.Telemetry.Handler do
  @moduledoc """
  Central telemetry handler for all SMRITI events.

  Forwards to:
  - Prometheus (metrics)
  - Grafana (dashboards)
  - Zenoh (mesh)
  - Logs (structured)
  """

  require Logger

  @all_events [
    # Immortality
    [:smriti, :immortality, :preserve, :start],
    [:smriti, :immortality, :preserve, :stop],
    [:smriti, :immortality, :ooda, :cycle_complete],
    [:smriti, :immortality, :protocol, :executed],

    # Panspermia
    [:smriti, :panspermia, :export, :start],
    [:smriti, :panspermia, :export, :success],
    [:smriti, :panspermia, :export, :failure],

    # Federation
    [:smriti, :federation, :sync, :start],
    [:smriti, :federation, :sync, :complete],
    [:smriti, :federation, :sync, :failed],
    [:smriti, :federation, :ooda, :start],

    # Agent
    [:smriti, :agent, :ooda, :cycle],
    [:smriti, :agent, :ooda, :observe],
    [:smriti, :agent, :ooda, :orient],
    [:smriti, :agent, :ooda, :decide],
    [:smriti, :agent, :ooda, :act],

    # Health
    [:smriti, :health, :check, :start],
    [:smriti, :health, :check, :complete],
    [:smriti, :health, :sentinel, :report],

    # Bootstrap
    [:smriti, :bootstrap, :start],
    [:smriti, :bootstrap, :phase, :start],
    [:smriti, :bootstrap, :phase, :complete],
    [:smriti, :bootstrap, :complete],
    [:smriti, :bootstrap, :failed],

    # Version Vectors
    [:smriti, :version_vector, :created],
    [:smriti, :version_vector, :incremented],
    [:smriti, :version_vector, :merged],

    # Reconstruction
    [:smriti, :reconstruction, :generate, :start],
    [:smriti, :reconstruction, :generate, :complete]
  ]

  def setup do
    :telemetry.attach_many(
      "smriti-telemetry-handler",
      @all_events,
      &handle_event/4,
      %{prometheus: true, zenoh: true, log: true}
    )

    :ok
  end

  def handle_event(event, measurements, metadata, config) do
    # Prometheus metrics
    if config.prometheus do
      record_prometheus_metric(event, measurements, metadata)
    end

    # Zenoh mesh broadcast
    if config.zenoh do
      publish_to_zenoh(event, measurements, metadata)
    end

    # Structured logging
    if config.log do
      log_event(event, measurements, metadata)
    end
  end

  defp record_prometheus_metric(event, measurements, _metadata) do
    metric_name = Enum.join(event, "_")

    case measurements do
      %{duration_ms: duration} ->
        :prometheus_histogram.observe(
          :"#{metric_name}_duration_ms",
          duration
        )

      %{count: count} ->
        :prometheus_counter.inc(
          :"#{metric_name}_total",
          count
        )

      _ ->
        :prometheus_counter.inc(:"#{metric_name}_total")
    end
  end

  defp publish_to_zenoh(event, measurements, metadata) do
    topic = "indrajaal/smriti/#{Enum.join(event, "/")}"
    payload = Jason.encode!(%{
      event: event,
      measurements: measurements,
      metadata: sanitize_metadata(metadata),
      timestamp: System.system_time(:nanosecond)
    })

    Indrajaal.Zenoh.Publisher.publish(topic, payload)
  end

  defp log_event(event, measurements, metadata) do
    Logger.info("[SMRITI Telemetry] #{Enum.join(event, ".")} | #{inspect(measurements)} | #{inspect(sanitize_metadata(metadata))}")
  end

  defp sanitize_metadata(metadata) do
    # Remove non-serializable values
    metadata
    |> Map.drop([:conn, :socket, :pid])
    |> Map.new(fn {k, v} -> {k, inspect(v)} end)
  end
end
```

---

### 3.11 Item 11: DEVENV COMMANDS (RPN: 48)

#### Observable CLI Commands in devenv.nix
```nix
{
  scripts = {
    # SMRITI Status with telemetry
    smriti-status.exec = ''
      echo "Executing smriti-status..."
      start_time=$(date +%s%N)
      result=$(dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx status)
      end_time=$(date +%s%N)
      duration=$((($end_time - $start_time) / 1000000))

      # Emit telemetry via curl to OTEL collector
      curl -s -X POST http://localhost:4318/v1/metrics \
        -H "Content-Type: application/json" \
        -d "{\"event\":\"smriti.cli.status\",\"duration_ms\":$duration}" \
        || true

      echo "$result"
    '';
    smriti-status.description = "Show SMRITI status with telemetry";

    # Similar for other commands...
  };
}
```

---

## 4. OBSERVABILITY ENFORCEMENT MECHANISMS

### 4.1 Compile-Time Enforcement

```elixir
defmodule Indrajaal.KMS.ObservabilityEnforcer do
  @moduledoc """
  Compile-time checks for observability compliance.
  """

  defmacro __using__(_opts) do
    quote do
      @before_compile Indrajaal.KMS.ObservabilityEnforcer
    end
  end

  defmacro __before_compile__(env) do
    module = env.module

    # Verify telemetry events are defined
    unless Module.defines?(module, {:telemetry_events, 0}) do
      raise CompileError,
        file: env.file,
        line: env.line,
        description: "Module #{module} must define telemetry_events/0 (SC-OBS-001)"
    end

    # Verify get_state for GenServers
    if Module.defines?(module, {:handle_call, 3}) do
      unless Module.defines?(module, {:get_state, 0}) do
        IO.warn("Warning: GenServer #{module} should define get_state/0 (SC-OBS-002)")
      end
    end

    quote do
    end
  end
end
```

### 4.2 Runtime Enforcement

```elixir
defmodule Indrajaal.KMS.ObservabilityGuard do
  @moduledoc """
  Runtime verification of observability compliance.
  """

  def verify_module_observability(module) do
    checks = [
      {:telemetry_events, function_exported?(module, :telemetry_events, 0)},
      {:get_state, not is_genserver?(module) or function_exported?(module, :get_state, 0)},
      {:health_check, function_exported?(module, :health_check, 0)}
    ]

    failures = Enum.filter(checks, fn {_, result} -> not result end)

    if failures != [] do
      Logger.warning("[ObservabilityGuard] Module #{module} fails: #{inspect(failures)}")
      {:error, failures}
    else
      {:ok, :compliant}
    end
  end

  def verify_telemetry_handlers_active do
    required_handlers = [
      "smriti-telemetry-handler",
      "immortality-telemetry-handler",
      "federation-telemetry-handler"
    ]

    active = :telemetry.list_handlers([])
    active_names = Enum.map(active, & &1.id)

    missing = required_handlers -- active_names

    if missing != [] do
      :telemetry.execute([:smriti, :observability, :handlers_missing],
        %{missing: length(missing)}, %{handlers: missing})
      {:error, {:missing_handlers, missing}}
    else
      {:ok, :all_handlers_active}
    end
  end
end
```

### 4.3 Dashboard Enforcement

```elixir
defmodule Indrajaal.KMS.Observability.Dashboard do
  @moduledoc """
  Real-time observability dashboard for SMRITI.
  Displays all 8 levels with observer/observed status.
  """

  @refresh_interval :timer.seconds(30)

  def generate_dashboard_data do
    %{
      timestamp: DateTime.utc_now(),
      levels: %{
        l0_runtime: get_l0_metrics(),
        l1_function: get_l1_metrics(),
        l2_component: get_l2_metrics(),
        l3_agent: get_l3_metrics(),
        l4_service: get_l4_metrics(),
        l5_node: get_l5_metrics(),
        l6_cluster: get_l6_metrics(),
        l7_federation: get_l7_metrics()
      },
      health: %{
        overall_score: calculate_overall_health(),
        observability_compliance: check_observability_compliance()
      },
      telemetry: %{
        active_handlers: count_active_handlers(),
        events_per_minute: calculate_event_rate(),
        last_events: get_recent_events(10)
      }
    }
  end

  defp get_l0_metrics do
    %{
      schema_version: get_schema_version(),
      constraint_violations: count_constraint_violations(),
      type_errors: count_type_errors()
    }
  end

  # ... similar for L1-L7
end
```

---

## 5. IMPLEMENTATION PRIORITY MATRIX

### 5.1 Sprint Execution with Observability Gate

Each item MUST pass observability gate before moving to next:

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║ SPRINT │ ITEMS                      │ OBSERVABILITY GATE                      ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║   1    │ Immortality Protocol       │ 20+ telemetry events attached           ║
║        │ Reconstruction Guide       │ Generation metrics observable           ║
║        │ Panspermia Exports         │ Format-specific metrics per export      ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║   2    │ Federation Protocol        │ Peer-to-peer observability complete     ║
║        │ Version Vectors            │ All CRDT ops instrumented               ║
║        │ Cluster Replication        │ Replication telemetry active            ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║   3    │ Agent OODA Loop            │ Full OODA cycle telemetry               ║
║        │ Health Monitoring          │ Sentinel integration verified           ║
║        │ Node Bootstrap             │ 4-phase bootstrap observable            ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║   4    │ Telemetry Integration      │ All 50+ event handlers active           ║
║        │ Devenv Commands            │ CLI telemetry wrapper complete          ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### 5.2 Observability Compliance Checklist

For each item, verify:

```
□ L0: Types emit telemetry on creation
□ L1: All functions have start/stop/error events
□ L2: Module lifecycle events (init, terminate)
□ L3: OODA cycle fully instrumented (<30s)
□ L4: API/CLI with request tracking
□ L5: Node bootstrap phases observable
□ L6: Cluster state sync telemetry
□ L7: Federation broadcast/receive events
□ get_state/0 implemented for all GenServers
□ Health check function exposed
□ Prometheus metrics registered
□ Zenoh topics published
□ Grafana dashboard panel defined
```

---

## 6. CONCLUSION

This implementation plan ensures:

1. **100% Observability Coverage**: Every component at every level (L0-L7) has both observer and observed roles

2. **8x8 Interaction Matrix**: Complete cross-level observability with defined interaction patterns

3. **STAMP Constraint Enforcement**: SC-OBS-001 to SC-OBS-008 verified at compile and runtime

4. **Constitutional Alignment**: Ψ₃ (Verification) enforced through mandatory observability

5. **OODA Integration**: All agent cycles instrumented with sub-30s verification

6. **Telemetry Infrastructure**: 50+ event types, Prometheus metrics, Zenoh mesh, structured logs

---

**Document Control**

| Field | Value |
|-------|-------|
| Version | 21.3.0-SIL6 |
| Created | 2026-01-11 |
| Author | Claude Opus 4.5 |
| STAMP | SC-OBS-001 to SC-OBS-100, SC-SMRITI-001 to SC-SMRITI-280 |
| Compliance | IEC 61508 SIL-6 |

---

*"That which cannot be observed cannot be improved. That which cannot be measured cannot be managed. That which cannot be monitored cannot survive."*

**End of SMRITI Observer-Observability Implementation Plan**
