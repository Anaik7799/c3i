# EVOLUTION MASTER ANALYSIS - PART 3
## Implementation, Testing, Interaction Issues, and Usage

---

## 9. IMPLEMENTATION PLAN

### 9.1 Sprint Roadmap

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        EVOLUTION SPRINT ROADMAP                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  PHASE 1: FOUNDATION (Sprints 46-48)                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Sprint 46: Zenoh.Net Core                                               ││
│  │  ├── E1-F01: Session Manager                                             ││
│  │  ├── E1-F02: Publisher API                                               ││
│  │  ├── E1-F03: Subscriber API                                              ││
│  │  └── E1-F07: Session Reconnection                                        ││
│  │                                                                          ││
│  │  Sprint 47: Vector Search Core                                           ││
│  │  ├── E2-F01: Embedding Generator                                         ││
│  │  ├── E2-F02: HNSW Index                                                  ││
│  │  ├── E2-F03: k-NN Search                                                 ││
│  │  └── E2-F05: Index Persistence                                           ││
│  │                                                                          ││
│  │  Sprint 48: Hierarchical IDs + Planning                                  ││
│  │  ├── E3-F01: ID Generation                                               ││
│  │  ├── E3-F02: Parent-Child Links                                          ││
│  │  ├── E4-F01: Dependency Graph                                            ││
│  │  └── E4-F03: Cycle Detection                                             ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  PHASE 2: BUSINESS DOMAINS (Sprints 49-56)                                   │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Sprint 49-50: Access Control Domain                                     ││
│  │  ├── Permission, Role, Policy resources                                  ││
│  │  ├── RoleAssignment, AccessGroup resources                               ││
│  │  ├── AccessLog, PolicyViolation resources                                ││
│  │  └── Guardian integration, audit trail                                   ││
│  │                                                                          ││
│  │  Sprint 51: Guard Tour Domain                                            ││
│  │  ├── Route, Checkpoint resources                                         ││
│  │  ├── Patrol, Deviation resources                                         ││
│  │  └── Real-time tracking integration                                      ││
│  │                                                                          ││
│  │  Sprint 52-53: Analytics Domain                                          ││
│  │  ├── Report, Dashboard, KPI resources                                    ││
│  │  ├── DataSource, Visualization resources                                 ││
│  │  └── DuckDB integration for OLAP                                         ││
│  │                                                                          ││
│  │  Sprint 54: Communication Domain                                         ││
│  │  ├── Message, Notification, Channel resources                            ││
│  │  └── Push notification integration                                       ││
│  │                                                                          ││
│  │  Sprint 55: Asset + Risk Domains                                         ││
│  │  ├── Equipment, Location, Maintenance resources                          ││
│  │  ├── Threat, Assessment, Mitigation resources                            ││
│  │  └── Risk scoring algorithms                                             ││
│  │                                                                          ││
│  │  Sprint 56: Visitor + Training Domains                                   ││
│  │  ├── Visitor, Badge, CheckIn resources                                   ││
│  │  ├── Course, Certification, SOP resources                                ││
│  │  └── Expiry tracking, compliance reports                                 ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  PHASE 3: ADVANCED (Sprints 57-62)                                           │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Sprint 57-58: Zenoh Advanced                                            ││
│  │  ├── E1-F04: Queryable API                                               ││
│  │  ├── E1-F05: Key Expression Router                                       ││
│  │  ├── E1-F09: Cluster Discovery                                           ││
│  │  └── E1-F10: Federation Gateway                                          ││
│  │                                                                          ││
│  │  Sprint 59: Vector Search Advanced                                       ││
│  │  ├── E2-F04: Hybrid Search                                               ││
│  │  ├── E2-F06: Incremental Updates                                         ││
│  │  └── E2-F10: Federation Sync                                             ││
│  │                                                                          ││
│  │  Sprint 60-61: SMRITI Evolution                                          ││
│  │  ├── E7-F01: Pattern Mining                                              ││
│  │  ├── E7-F02: Knowledge Graph                                             ││
│  │  ├── E7-F03: Federation Protocol                                         ││
│  │  └── E7-F08: AI Agent Memory                                             ││
│  │                                                                          ││
│  │  Sprint 62: Observability                                                ││
│  │  ├── E8-F01: SIL-6 Dashboard                                             ││
│  │  ├── E8-F02: Trace Correlation                                           ││
│  │  └── E8-F03: Anomaly Detection                                           ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  PHASE 4: PODMAN + POLISH (Sprints 63-68)                                    │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Sprint 63-64: Podman API                                                ││
│  │  ├── E5-F01: Volume Streaming                                            ││
│  │  ├── E5-F02: Image Layer Stream                                          ││
│  │  ├── E5-F03: Exec with PTY                                               ││
│  │  └── E5-F06: Event Subscription                                          ││
│  │                                                                          ││
│  │  Sprint 65-66: Planning Advanced                                         ││
│  │  ├── E4-F04: OODA Telemetry                                              ││
│  │  ├── E4-F05: Mesh Distribution                                           ││
│  │  ├── E4-F06: Auto-Scheduling                                             ││
│  │  └── E4-F07: Gantt Export                                                ││
│  │                                                                          ││
│  │  Sprint 67-68: Integration + GA                                          ││
│  │  ├── Full system integration testing                                     ││
│  │  ├── Performance optimization                                            ││
│  │  ├── Documentation completion                                            ││
│  │  └── GA Release v22.0.0                                                  ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 9.2 Implementation Templates

#### 9.2.1 F# Module Template (Zenoh)

```fsharp
// File: lib/cepaf/src/Cepaf.Zenoh/ZenohSession.fs
namespace Cepaf.Zenoh

open System
open System.Threading.Tasks
open Zenoh.Net

/// <summary>
/// Zenoh session manager with automatic reconnection.
/// SC-ZENOH-001: Zenoh NIF MUST be loaded on ALL nodes
/// SC-ZENOH-005: Zenoh session reconnect on failure
/// </summary>
[<RequireQualifiedAccess>]
module ZenohSession =

    /// Session configuration
    type Config = {
        Mode: ZenohMode
        ConnectEndpoints: string list
        ListenEndpoints: string list
        Timeout: TimeSpan
        MaxRetries: int
        RetryDelayMs: int
    }

    /// Session state
    type State =
        | Disconnected
        | Connecting
        | Connected of Session
        | Reconnecting of int  // retry count
        | Failed of exn

    /// Session events
    type Event =
        | Connect
        | Connected of Session
        | Disconnected of exn
        | MaxRetriesExceeded

    /// Create default config
    let defaultConfig = {
        Mode = ZenohMode.Client
        ConnectEndpoints = ["tcp/localhost:7447"]
        ListenEndpoints = []
        Timeout = TimeSpan.FromSeconds(5.0)
        MaxRetries = 5
        RetryDelayMs = 1000
    }

    /// Connect to Zenoh router
    let connect (config: Config) : Task<Result<Session, exn>> =
        task {
            try
                let! session =
                    Zenoh.open'(
                        config.Mode,
                        config.ConnectEndpoints,
                        config.Timeout
                    )
                return Ok session
            with ex ->
                return Error ex
        }

    /// Reconnect with exponential backoff
    let reconnect (config: Config) (retryCount: int) : Task<Result<Session, exn>> =
        task {
            if retryCount >= config.MaxRetries then
                return Error (exn "Max retries exceeded")
            else
                let delay = config.RetryDelayMs * (pown 2 retryCount)
                do! Task.Delay(delay)
                return! connect config
        }

    /// Close session gracefully
    let close (session: Session) : Task<unit> =
        task {
            do! session.close()
        }
```

#### 9.2.2 Elixir Resource Template (Ash 3.x)

```elixir
# File: lib/indrajaal/access_control/resources/permission.ex
defmodule Indrajaal.AccessControl.Permission do
  @moduledoc """
  Atomic permission unit for access control.

  ## STAMP Constraints
  - SC-DB-001: Use BaseResource
  - SC-DB-005: uuid_primary_key
  - SC-ASH-001: force_change_attribute in before_action

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 22.0.0 | 2026-XX-XX | Claude | Initial implementation |
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AccessControl,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "access_control_permissions"
    repo Indrajaal.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 100
    end

    attribute :resource, :string do
      allow_nil? false
      description "Resource this permission applies to"
    end

    attribute :action, :atom do
      allow_nil? false
      constraints one_of: [:create, :read, :update, :delete, :execute]
    end

    attribute :scope, :map do
      default %{}
      description "Conditional scope for the permission"
    end

    attribute :active, :boolean do
      default true
    end

    timestamps()
  end

  identities do
    identity :unique_permission, [:name, :resource, :action]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :resource, :action, :scope, :active]

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :active, true)
      end
    end

    update :update do
      accept [:name, :scope, :active]
      require_atomic? false
    end

    read :by_resource do
      argument :resource, :string, allow_nil?: false
      filter expr(resource == ^arg(:resource) and active == true)
    end
  end

  code_interface do
    domain Indrajaal.AccessControl

    define :create
    define :read
    define :by_resource, args: [:resource]
    define :update
    define :destroy
  end
end
```

#### 9.2.3 Vector Search Implementation

```fsharp
// File: lib/cepaf/src/Cepaf.Vector/HnswIndex.fs
namespace Cepaf.Vector

open System
open System.Collections.Generic

/// <summary>
/// HNSW (Hierarchical Navigable Small World) index for vector similarity search.
/// SC-EVO-003: 95%+ test coverage required
/// </summary>
[<RequireQualifiedAccess>]
module HnswIndex =

    /// Index configuration
    type Config = {
        Dimensions: int
        M: int              // Max connections per node
        EfConstruction: int // Size of dynamic candidate list
        EfSearch: int       // Size of dynamic candidate list for search
        DistanceFunction: DistanceFunction
    }

    type DistanceFunction =
        | Euclidean
        | Cosine
        | DotProduct

    /// Node in the graph
    type Node = {
        Id: string
        Vector: float32[]
        Neighbors: Dictionary<int, HashSet<string>> // level -> neighbors
        MaxLevel: int
    }

    /// Index state
    type Index = {
        Config: Config
        Nodes: Dictionary<string, Node>
        EntryPoint: string option
        MaxLevel: int
    }

    /// Distance calculation
    let distance (func: DistanceFunction) (a: float32[]) (b: float32[]) : float32 =
        match func with
        | Euclidean ->
            let mutable sum = 0.0f
            for i in 0 .. a.Length - 1 do
                let diff = a.[i] - b.[i]
                sum <- sum + diff * diff
            sqrt sum
        | Cosine ->
            let mutable dot = 0.0f
            let mutable normA = 0.0f
            let mutable normB = 0.0f
            for i in 0 .. a.Length - 1 do
                dot <- dot + a.[i] * b.[i]
                normA <- normA + a.[i] * a.[i]
                normB <- normB + b.[i] * b.[i]
            1.0f - (dot / (sqrt normA * sqrt normB))
        | DotProduct ->
            let mutable dot = 0.0f
            for i in 0 .. a.Length - 1 do
                dot <- dot + a.[i] * b.[i]
            -dot  // Negative because we want larger = closer

    /// Create empty index
    let create (config: Config) : Index = {
        Config = config
        Nodes = Dictionary<string, Node>()
        EntryPoint = None
        MaxLevel = 0
    }

    /// Generate random level for new node
    let randomLevel (m: int) : int =
        let mL = 1.0 / log (float m)
        int (floor (-log (Random().NextDouble()) * mL))

    /// Search k nearest neighbors
    let searchKnn (index: Index) (query: float32[]) (k: int) : (string * float32) list =
        match index.EntryPoint with
        | None -> []
        | Some entryId ->
            let ef = index.Config.EfSearch
            let distFunc = distance index.Config.DistanceFunction

            // Greedy search from top to layer 0
            let mutable currentId = entryId
            let mutable currentNode = index.Nodes.[currentId]

            for level in index.MaxLevel .. -1 .. 1 do
                // Greedy search at this level
                let mutable improved = true
                while improved do
                    improved <- false
                    let currentDist = distFunc query currentNode.Vector
                    for neighborId in currentNode.Neighbors.[level] do
                        let neighbor = index.Nodes.[neighborId]
                        let neighborDist = distFunc query neighbor.Vector
                        if neighborDist < currentDist then
                            currentId <- neighborId
                            currentNode <- neighbor
                            improved <- true

            // Search at layer 0 with ef candidates
            let candidates = SortedSet<float32 * string>()
            let visited = HashSet<string>()

            candidates.Add((distFunc query currentNode.Vector, currentId)) |> ignore
            visited.Add(currentId) |> ignore

            let results = SortedSet<float32 * string>()

            while candidates.Count > 0 do
                let (dist, nodeId) = candidates.Min
                candidates.Remove(candidates.Min) |> ignore

                if results.Count >= k && dist > (fst results.Max) then
                    () // Skip if worse than worst result
                else
                    results.Add((dist, nodeId)) |> ignore
                    if results.Count > k then
                        results.Remove(results.Max) |> ignore

                    let node = index.Nodes.[nodeId]
                    if node.Neighbors.ContainsKey(0) then
                        for neighborId in node.Neighbors.[0] do
                            if not (visited.Contains(neighborId)) then
                                visited.Add(neighborId) |> ignore
                                let neighbor = index.Nodes.[neighborId]
                                let neighborDist = distFunc query neighbor.Vector
                                if candidates.Count < ef || neighborDist < (fst candidates.Max) then
                                    candidates.Add((neighborDist, neighborId)) |> ignore
                                    if candidates.Count > ef then
                                        candidates.Remove(candidates.Max) |> ignore

            results |> Seq.map (fun (d, id) -> (id, d)) |> Seq.toList
```

---

## 10. TESTING STRATEGY

### 10.1 Test Level Matrix

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TEST LEVEL MATRIX                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Level    │ Type           │ Tools              │ Coverage Target           │
│  ─────────┼────────────────┼────────────────────┼────────────────────────── │
│  L1       │ Unit           │ ExUnit, Expecto    │ 100% critical paths       │
│  L2       │ Integration    │ Wallaby, HttpPoison│ 100% API endpoints        │
│  L3       │ Property       │ PropCheck, FsCheck │ 100% data transformations │
│  L4       │ BDD            │ Cucumber, SpecFlow │ 100% user stories         │
│  L5       │ FMEA           │ RPN Analysis       │ All RPN > 50 mitigated    │
│  L6       │ Graph          │ CFG/DFG Analysis   │ 80%+ path coverage        │
│  L7       │ Formal         │ Agda, Quint        │ All critical invariants   │
│  L8       │ Chaos          │ Litmus, Jepsen     │ All failure modes         │
│  L9       │ Performance    │ Benchee, K6        │ All SLAs met              │
│  L10      │ Security       │ Sobelow, OWASP     │ 0 critical vulnerabilities│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 10.2 Test Cases by Evolution Domain

#### 10.2.1 E1: Zenoh.Net Test Suite

```elixir
# test/cepaf/zenoh/zenoh_session_test.exs
defmodule Cepaf.Zenoh.ZenohSessionTest do
  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # L1: Unit Tests
  describe "connect/1" do
    test "connects to running Zenoh router" do
      config = ZenohSession.default_config()
      assert {:ok, session} = ZenohSession.connect(config)
      assert ZenohSession.connected?(session)
      ZenohSession.close(session)
    end

    test "returns error when router unavailable" do
      config = %{ZenohSession.default_config() | connect_endpoints: ["tcp/invalid:7447"]}
      assert {:error, _reason} = ZenohSession.connect(config)
    end
  end

  # L3: Property Tests
  property "messages published are received by subscribers" do
    forall topic <- PC.utf8() do
      forall payload <- PC.binary() do
        {:ok, pub_session} = ZenohSession.connect(ZenohSession.default_config())
        {:ok, sub_session} = ZenohSession.connect(ZenohSession.default_config())

        received = Agent.start_link(fn -> nil end)
        ZenohSession.subscribe(sub_session, topic, fn msg ->
          Agent.update(received, fn _ -> msg end)
        end)

        :timer.sleep(100)
        ZenohSession.publish(pub_session, topic, payload)
        :timer.sleep(100)

        result = Agent.get(received, & &1)

        ZenohSession.close(pub_session)
        ZenohSession.close(sub_session)

        result == payload
      end
    end
  end

  # L4: BDD Scenario
  @tag :bdd
  test "Scenario: Session reconnects after network failure" do
    # Given a connected Zenoh session
    {:ok, session} = ZenohSession.connect(ZenohSession.default_config())
    assert ZenohSession.connected?(session)

    # When the network connection is interrupted
    simulate_network_failure()

    # Then the session automatically reconnects
    :timer.sleep(5000)
    assert ZenohSession.connected?(session)

    # And publishes resume without data loss
    ZenohSession.publish(session, "test/topic", "message")
    assert_received {:zenoh_ack, _}

    ZenohSession.close(session)
  end
end
```

#### 10.2.2 E2: Vector Search Test Suite

```fsharp
// test/Cepaf.Vector.Tests/HnswIndexTests.fs
module Cepaf.Vector.Tests.HnswIndexTests

open Xunit
open FsCheck
open FsCheck.Xunit
open Cepaf.Vector.HnswIndex

[<Fact>]
let ``create returns empty index`` () =
    let config = {
        Dimensions = 128
        M = 16
        EfConstruction = 200
        EfSearch = 50
        DistanceFunction = Cosine
    }
    let index = create config
    Assert.Equal(0, index.Nodes.Count)
    Assert.True(Option.isNone index.EntryPoint)

[<Property>]
let ``searchKnn returns k results when index has k+ vectors`` (k: PositiveInt) =
    let k = min k.Get 100
    let config = {
        Dimensions = 32
        M = 16
        EfConstruction = 200
        EfSearch = 50
        DistanceFunction = Euclidean
    }
    let index = create config

    // Insert k+10 random vectors
    let rng = System.Random(42)
    for i in 0 .. k + 9 do
        let vec = Array.init 32 (fun _ -> float32 (rng.NextDouble()))
        insert index (sprintf "vec_%d" i) vec |> ignore

    // Search for k neighbors
    let query = Array.init 32 (fun _ -> float32 (rng.NextDouble()))
    let results = searchKnn index query k

    List.length results = k

[<Fact>]
let ``nearest neighbor is closest by distance`` () =
    let config = {
        Dimensions = 3
        M = 4
        EfConstruction = 10
        EfSearch = 10
        DistanceFunction = Euclidean
    }
    let index = create config

    // Insert known vectors
    insert index "origin" [| 0.0f; 0.0f; 0.0f |] |> ignore
    insert index "near" [| 1.0f; 0.0f; 0.0f |] |> ignore
    insert index "far" [| 10.0f; 10.0f; 10.0f |] |> ignore

    // Query from origin
    let results = searchKnn index [| 0.0f; 0.0f; 0.0f |] 1

    Assert.Equal("origin", fst results.[0])
```

#### 10.2.3 E6: Access Control Test Suite

```elixir
# test/indrajaal/access_control/permission_test.exs
defmodule Indrajaal.AccessControl.PermissionTest do
  use Indrajaal.DataCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.AccessControl.Permission

  # L1: Unit Tests
  describe "create/1" do
    test "creates permission with valid attributes" do
      attrs = %{
        name: "read_users",
        resource: "User",
        action: :read
      }

      assert {:ok, permission} = Permission.create(attrs)
      assert permission.name == "read_users"
      assert permission.resource == "User"
      assert permission.action == :read
      assert permission.active == true
    end

    test "fails with missing required fields" do
      assert {:error, changeset} = Permission.create(%{})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "fails with invalid action" do
      attrs = %{name: "test", resource: "Test", action: :invalid}
      assert {:error, changeset} = Permission.create(attrs)
      assert "is invalid" in errors_on(changeset).action
    end
  end

  # L3: Property Tests
  property "permission names are unique per resource+action" do
    forall {name, resource, action} <- {PC.utf8(), PC.utf8(), PC.oneof([:create, :read, :update, :delete])} do
      implies String.length(name) > 0 and String.length(resource) > 0 do
        attrs = %{name: name, resource: resource, action: action}
        {:ok, _p1} = Permission.create(attrs)

        case Permission.create(attrs) do
          {:error, changeset} ->
            "has already been taken" in errors_on(changeset).name
          {:ok, _} ->
            false  # Should not succeed
        end
      end
    end
  end

  # L4: BDD Scenario
  @tag :bdd
  test "Scenario: Admin creates granular permissions for role" do
    # Given I am an admin user
    admin = create_admin_user()

    # When I create permissions for the "Operator" role
    permissions = [
      %{name: "view_cameras", resource: "Camera", action: :read},
      %{name: "control_ptz", resource: "Camera.PTZ", action: :execute},
      %{name: "view_alarms", resource: "Alarm", action: :read},
      %{name: "acknowledge_alarms", resource: "Alarm", action: :update}
    ]

    created = Enum.map(permissions, fn attrs ->
      {:ok, p} = Permission.create(attrs, actor: admin)
      p
    end)

    # Then all permissions are created successfully
    assert length(created) == 4

    # And each permission is active
    Enum.each(created, fn p ->
      assert p.active == true
    end)

    # And permissions can be queried by resource
    {:ok, camera_perms} = Permission.by_resource("Camera")
    assert length(camera_perms) == 1
  end
end
```

### 10.3 FMEA Test Requirements

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         FMEA TEST MATRIX                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Failure Mode           │ Severity │ Test Type      │ Mitigation Test       │
│  ───────────────────────┼──────────┼────────────────┼────────────────────── │
│  Zenoh router crash     │    9     │ Chaos          │ test_zenoh_failover   │
│  Vector index corrupt   │    8     │ Durability     │ test_index_recovery   │
│  Task dependency cycle  │    7     │ Property       │ test_cycle_detection  │
│  Permission escalation  │    9     │ Security       │ test_authz_bypass     │
│  DB connection pool     │    8     │ Load           │ test_pool_exhaustion  │
│  Memory leak in search  │    7     │ Stress         │ test_memory_growth    │
│  Race in pub/sub        │    6     │ Concurrent     │ test_message_ordering │
│  Stale cache entries    │    5     │ Integration    │ test_cache_invalidate │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 11. INTERACTION ISSUES & MITIGATIONS

### 11.1 Cross-Domain Interaction Matrix

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INTERACTION ISSUE MATRIX                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│           │ E1    │ E2    │ E3    │ E4    │ E5    │ E6    │ E7    │ E8    │
│  ─────────┼───────┼───────┼───────┼───────┼───────┼───────┼───────┼─────  │
│  E1 Zenoh │   -   │ I-12  │   -   │ I-14  │   -   │ I-16  │ I-17  │ I-18  │
│  E2 Vec   │ I-12  │   -   │   -   │   -   │   -   │   -   │ I-27  │   -   │
│  E3 ID    │   -   │   -   │   -   │ I-34  │   -   │   -   │   -   │   -   │
│  E4 Plan  │ I-14  │   -   │ I-34  │   -   │   -   │   -   │ I-47  │ I-48  │
│  E5 Pod   │   -   │   -   │   -   │   -   │   -   │   -   │   -   │ I-58  │
│  E6 Biz   │ I-16  │   -   │   -   │   -   │   -   │ I-66  │ I-67  │ I-68  │
│  E7 SMRIT │ I-17  │ I-27  │   -   │ I-47  │   -   │ I-67  │   -   │ I-78  │
│  E8 Obs   │ I-18  │   -   │   -   │ I-48  │ I-58  │ I-68  │ I-78  │   -   │
│                                                                              │
│  I-XX = Interaction Issue ID                                                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 11.2 Critical Interaction Issues

#### I-12: Zenoh × Vector Search

| Aspect | Detail |
|--------|--------|
| **Issue** | Vector embeddings must be published via Zenoh for federation sync |
| **Risk** | Large payloads (768+ floats) may exceed Zenoh message limits |
| **RPN** | Severity: 7, Occurrence: 6, Detection: 4 = **168** |
| **Mitigation** | Implement chunked transfer with reassembly protocol |
| **Test** | `test_large_vector_zenoh_transfer` |
| **STAMP** | SC-EVO-006, SC-ZENOH-004 |

#### I-16: Zenoh × Business Domains

| Aspect | Detail |
|--------|--------|
| **Issue** | Domain events must propagate via Zenoh for real-time updates |
| **Risk** | Event ordering may be violated during network partitions |
| **RPN** | Severity: 8, Occurrence: 5, Detection: 5 = **200** |
| **Mitigation** | Implement vector clocks for causal ordering |
| **Test** | `test_domain_event_ordering` |
| **STAMP** | SC-BUS-004, SC-BRIDGE-001 |

#### I-34: Hierarchical ID × Planning

| Aspect | Detail |
|--------|--------|
| **Issue** | Task IDs must be generated consistently across mesh nodes |
| **Risk** | ID collisions possible during concurrent task creation |
| **RPN** | Severity: 6, Occurrence: 4, Detection: 6 = **144** |
| **Mitigation** | Use node-prefixed IDs with distributed sequence |
| **Test** | `test_concurrent_task_creation` |
| **STAMP** | SC-EVO-002 |

#### I-66: Business Domain Cross-References

| Aspect | Detail |
|--------|--------|
| **Issue** | Domains may reference each other (e.g., Asset → Location) |
| **Risk** | Circular dependencies, cascade delete issues |
| **RPN** | Severity: 7, Occurrence: 6, Detection: 5 = **210** |
| **Mitigation** | Use soft references with referential integrity checks |
| **Test** | `test_cross_domain_references` |
| **STAMP** | SC-DB-012, SC-ASH-004 |

#### I-67: Business Domains × SMRITI

| Aspect | Detail |
|--------|--------|
| **Issue** | Domain knowledge must be captured in SMRITI for AI context |
| **Risk** | Schema changes may invalidate stored knowledge |
| **RPN** | Severity: 5, Occurrence: 5, Detection: 4 = **100** |
| **Mitigation** | Version knowledge holons, migrate on schema change |
| **Test** | `test_knowledge_schema_evolution` |
| **STAMP** | SC-AI-001, SC-HOLON-011 |

### 11.3 Mitigation Implementation

```elixir
# Mitigation I-16: Vector Clocks for Event Ordering
defmodule Indrajaal.EventOrdering do
  @moduledoc """
  Vector clock implementation for causal event ordering.
  Mitigation for I-16: Zenoh × Business Domains interaction.

  SC-BUS-004: Message ordering FIFO
  """

  defstruct [:node_id, :clock]

  @type t :: %__MODULE__{
    node_id: String.t(),
    clock: %{String.t() => non_neg_integer()}
  }

  def new(node_id) do
    %__MODULE__{node_id: node_id, clock: %{node_id => 0}}
  end

  def increment(%__MODULE__{node_id: node_id, clock: clock} = vc) do
    new_clock = Map.update(clock, node_id, 1, &(&1 + 1))
    %{vc | clock: new_clock}
  end

  def merge(%__MODULE__{clock: clock1} = vc, %__MODULE__{clock: clock2}) do
    merged = Map.merge(clock1, clock2, fn _k, v1, v2 -> max(v1, v2) end)
    %{vc | clock: merged}
  end

  def happened_before?(%__MODULE__{clock: c1}, %__MODULE__{clock: c2}) do
    all_keys = Map.keys(c1) ++ Map.keys(c2) |> Enum.uniq()

    all_leq = Enum.all?(all_keys, fn k ->
      Map.get(c1, k, 0) <= Map.get(c2, k, 0)
    end)

    any_lt = Enum.any?(all_keys, fn k ->
      Map.get(c1, k, 0) < Map.get(c2, k, 0)
    end)

    all_leq and any_lt
  end
end
```

---

## 12. USAGE DOCUMENTATION

### 12.1 E1: Zenoh.Net Usage Guide

```markdown
# Zenoh.Net Integration Usage Guide

## Quick Start

### 1. Configure Zenoh Session

```fsharp
open Cepaf.Zenoh

let config = {
    ZenohSession.defaultConfig with
        ConnectEndpoints = ["tcp/zenoh-router:7447"]
        Timeout = TimeSpan.FromSeconds(10.0)
}
```

### 2. Connect and Publish

```fsharp
// Connect
let! session = ZenohSession.connect config

// Publish
do! ZenohSession.publish session "indrajaal/events/alarm" alarmJson

// With QoS
do! ZenohSession.publishWithQos session "indrajaal/critical/alert" payload Reliable
```

### 3. Subscribe to Topics

```fsharp
// Simple subscribe
let! subId = ZenohSession.subscribe session "indrajaal/events/**" (fun sample ->
    printfn $"Received: {sample.Payload}"
)

// With key expression patterns
let! subId = ZenohSession.subscribe session "indrajaal/*/health" handleHealth
```

### 4. Request-Response (Queryable)

```fsharp
// Register queryable
let! queryable = ZenohSession.registerQueryable session "indrajaal/api/status" (fun query ->
    let response = getSystemStatus()
    query.Reply(response)
)

// Make query
let! response = ZenohSession.query session "indrajaal/api/status" timeout
```

## Best Practices

1. **Always handle reconnection** - Use the built-in reconnection with backoff
2. **Use key expressions** - Leverage wildcards for flexible subscriptions
3. **Monitor session health** - Subscribe to session events for telemetry
4. **Close gracefully** - Always close sessions on shutdown

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Connection timeout | Check Zenoh router is running on configured port |
| Messages not received | Verify key expression matches publisher topic |
| High latency | Check network, consider QoS settings |
```

### 12.2 E2: Vector Search Usage Guide

```markdown
# Vector Similarity Search Usage Guide

## Quick Start

### 1. Initialize Index

```fsharp
open Cepaf.Vector

let config = {
    Dimensions = 768  // OpenAI embedding size
    M = 16
    EfConstruction = 200
    EfSearch = 50
    DistanceFunction = Cosine
}

let index = HnswIndex.create config
```

### 2. Generate Embeddings

```fsharp
// Using OpenRouter for embeddings
let! embedding = Embedder.embed "Your text here"
// Returns: float32[768]
```

### 3. Index Documents

```fsharp
// Single insert
HnswIndex.insert index "doc-123" embedding

// Batch insert
let docs = [("doc-1", vec1); ("doc-2", vec2); ("doc-3", vec3)]
HnswIndex.insertBatch index docs
```

### 4. Search

```fsharp
// k-NN search
let queryVec = Embedder.embed "search query"
let results = HnswIndex.searchKnn index queryVec 10
// Returns: [(docId, distance), ...]

// Hybrid search (vector + keyword)
let results = HybridSearch.search index queryVec "keyword" 10
```

### 5. Persist and Load

```fsharp
// Save to DuckDB
HnswIndex.persist index "vectors.parquet"

// Load from storage
let index = HnswIndex.load "vectors.parquet" config
```

## Performance Tuning

| Parameter | Effect | Recommendation |
|-----------|--------|----------------|
| M | Graph connectivity | 16-64 for most cases |
| EfConstruction | Build quality | 100-400, higher = better |
| EfSearch | Search quality | 50-200, tune for recall |
```

### 12.3 E6: Business Domain Usage Guide

```markdown
# Business Domain Usage Guide

## Access Control Domain

### 1. Create Permissions

```elixir
# Create atomic permissions
{:ok, view_cameras} = Permission.create(%{
  name: "view_cameras",
  resource: "Camera",
  action: :read
})

{:ok, control_ptz} = Permission.create(%{
  name: "control_ptz",
  resource: "Camera.PTZ",
  action: :execute
})
```

### 2. Create Roles

```elixir
# Create role with permissions
{:ok, operator_role} = Role.create(%{
  name: "Camera Operator",
  description: "Can view and control cameras"
})

# Assign permissions to role
Role.add_permissions(operator_role, [view_cameras, control_ptz])
```

### 3. Assign Roles to Users

```elixir
# Assign role to user
{:ok, assignment} = RoleAssignment.create(%{
  user_id: user.id,
  role_id: operator_role.id,
  assigned_by: admin.id,
  valid_from: DateTime.utc_now(),
  valid_until: ~U[2027-01-01 00:00:00Z]
})
```

### 4. Check Permissions

```elixir
# Check if user has permission
case Guardian.authorize(user, :read, Camera) do
  :ok -> # Allowed
  {:error, :forbidden} -> # Denied
end

# In Phoenix controller
def show(conn, %{"id" => id}) do
  with :ok <- Guardian.authorize(conn.assigns.current_user, :read, Camera),
       {:ok, camera} <- Camera.get(id) do
    render(conn, :show, camera: camera)
  end
end
```

### 5. Policy-Based Access

```elixir
# Create conditional policy
{:ok, policy} = AccessPolicy.create(%{
  name: "night_shift_only",
  resource: "Camera",
  condition: %{
    time_range: %{start: "22:00", end: "06:00"},
    location: ["Building A", "Building B"]
  }
})
```

## Guard Tour Domain

### 1. Define Route

```elixir
{:ok, route} = GuardTour.Route.create(%{
  name: "Perimeter Patrol",
  checkpoints: [
    %{location: "Gate A", order: 1, dwell_time: 60},
    %{location: "Loading Dock", order: 2, dwell_time: 120},
    %{location: "Gate B", order: 3, dwell_time: 60}
  ],
  schedule: "*/30 * * * *"  # Every 30 minutes
})
```

### 2. Start Patrol

```elixir
{:ok, patrol} = GuardTour.Patrol.start(%{
  route_id: route.id,
  guard_id: guard.id,
  started_at: DateTime.utc_now()
})
```

### 3. Record Checkpoint

```elixir
{:ok, _} = GuardTour.Patrol.record_checkpoint(patrol, %{
  checkpoint_id: checkpoint.id,
  scanned_at: DateTime.utc_now(),
  method: :nfc,
  notes: "All clear"
})
```
```

---

## 13. REFERENCES

### 13.1 Internal Documents

| Document | Location | Description |
|----------|----------|-------------|
| CLAUDE.md | `/CLAUDE.md` | Master system specification |
| GEMINI.md | `/GEMINI.md` | Cybernetic architect specification |
| AGENT_BOOTSTRAP.md | `/AGENT_BOOTSTRAP.md` | Agent initialization protocol |
| HOLON_FOUNDERS_DIRECTIVE.md | `/docs/architecture/` | Supreme covenant |
| HOLON_IMMUTABLE_REGISTER.md | `/docs/architecture/` | Blockchain state spec |
| BDD_INTEGRATION_ARCHITECTURE.md | `/docs/architecture/` | Testing framework |
| GA_RUNTIME_TEST_PLAN.md | `/docs/verification/` | Release verification |

### 13.2 External References

| Resource | URL | Purpose |
|----------|-----|---------|
| Zenoh Documentation | https://zenoh.io/docs | Pub/sub protocol |
| HNSW Paper | https://arxiv.org/abs/1603.09320 | Vector search algorithm |
| Ash Framework | https://ash-hq.org | Elixir resource framework |
| IEC 61508 | ISO standard | SIL-6 safety requirements |
| STAMP/STPA | MIT | Safety constraint methodology |

### 13.3 STAMP Constraint Index

| ID Range | Domain | Count |
|----------|--------|-------|
| SC-EVO-001 to SC-EVO-010 | Evolution General | 10 |
| SC-ZENOH-001 to SC-ZENOH-015 | Zenoh Integration | 15 |
| SC-VEC-001 to SC-VEC-010 | Vector Search | 10 |
| SC-PLAN-001 to SC-PLAN-008 | Planning System | 8 |
| SC-ACC-001 to SC-ACC-020 | Access Control | 20 |
| SC-TOUR-001 to SC-TOUR-010 | Guard Tour | 10 |
| SC-ANA-001 to SC-ANA-015 | Analytics | 15 |
| **Total New Constraints** | | **88** |

### 13.4 AOR Rule Index

| ID Range | Domain | Count |
|----------|--------|-------|
| AOR-EVO-001 to AOR-EVO-010 | Evolution General | 10 |
| AOR-ZENOH-001 to AOR-ZENOH-010 | Zenoh Integration | 10 |
| AOR-VEC-001 to AOR-VEC-008 | Vector Search | 8 |
| AOR-PLAN-001 to AOR-PLAN-010 | Planning System | 10 |
| AOR-ACC-001 to AOR-ACC-015 | Access Control | 15 |
| AOR-TOUR-001 to AOR-TOUR-008 | Guard Tour | 8 |
| **Total New Rules** | | **61** |

---

## DOCUMENT CONTROL

| Field | Value |
|-------|-------|
| Document ID | DOC-EVO-2026-01-14 |
| Version | 1.0.0 |
| Status | ACTIVE |
| Author | Claude Opus 4.5 |
| Created | 2026-01-14 |
| Last Modified | 2026-01-14 |
| STAMP Compliance | SC-DOC-001, SC-CHG-001 |
| Review Cycle | Per Sprint |

---

**END OF EVOLUTION MASTER ANALYSIS**
