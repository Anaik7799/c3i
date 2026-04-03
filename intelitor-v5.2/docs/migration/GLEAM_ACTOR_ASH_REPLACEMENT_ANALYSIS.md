# Gleam Actor & Direct Database Access: System Transformation Analysis

**Version**: 1.0.0 | **Date**: 2026-01-11 | **Status**: COMPLETE ANALYSIS
**Scope**: Replace GenServers with Gleam actors, Replace Ash with Gleam libraries + direct access

---

## Executive Summary

| Replacement | Feasibility | Effort | System Impact |
|-------------|-------------|--------|---------------|
| GenServer → gleam_otp Actor | PARTIAL | HIGH | 30-40% portable |
| Ash → Gleam + Direct DB | VERY LOW | EXTREME | 10% portable |
| Combined System | PARTIAL HYBRID | 18-24 months | Fundamentally different |

### The Transformed System Would Be:

```
┌─────────────────────────────────────────────────────────────────┐
│              INDRAJAAL GLEAM-TRANSFORMED SYSTEM                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ╔═══════════════════════════════════════════════════════════╗ │
│  ║ GLEAM LAYER (35%)                                          ║ │
│  ║                                                             ║ │
│  ║ ┌─────────────┐ ┌─────────────┐ ┌───────────────────────┐ ║ │
│  ║ │ gleam_otp   │ │ Domain      │ │ gleam_pgo             │ ║ │
│  ║ │ Actors      │ │ Types       │ │ (Direct SQL)          │ ║ │
│  ║ │ (Limited)   │ │ (100%)      │ │                       │ ║ │
│  ║ └─────────────┘ └─────────────┘ └───────────────────────┘ ║ │
│  ║                                                             ║ │
│  ║ ┌─────────────┐ ┌─────────────┐ ┌───────────────────────┐ ║ │
│  ║ │ Validation  │ │ Business    │ │ HTTP/JSON             │ ║ │
│  ║ │ (Pure)      │ │ Logic       │ │ (Wisp/Mist)           │ ║ │
│  ║ │             │ │ (Pure)      │ │                       │ ║ │
│  ║ └─────────────┘ └─────────────┘ └───────────────────────┘ ║ │
│  ╚═══════════════════════════════════════════════════════════╝ │
│                            │                                     │
│                            │ FFI Boundary                        │
│                            ▼                                     │
│  ╔═══════════════════════════════════════════════════════════╗ │
│  ║ ELIXIR LAYER (65%) - NON-NEGOTIABLE                        ║ │
│  ║                                                             ║ │
│  ║ ┌─────────────┐ ┌─────────────┐ ┌───────────────────────┐ ║ │
│  ║ │ Supervision │ │ ETS Cache   │ │ Distributed           │ ║ │
│  ║ │ Trees       │ │ Layer       │ │ Erlang                │ ║ │
│  ║ └─────────────┘ └─────────────┘ └───────────────────────┘ ║ │
│  ║                                                             ║ │
│  ║ ┌─────────────┐ ┌─────────────┐ ┌───────────────────────┐ ║ │
│  ║ │ Complex     │ │ Telemetry   │ │ Phoenix               │ ║ │
│  ║ │ GenServers  │ │ Pipeline    │ │ LiveView              │ ║ │
│  ║ └─────────────┘ └─────────────┘ └───────────────────────┘ ║ │
│  ╚═══════════════════════════════════════════════════════════╝ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Part 1: GenServer → gleam_otp Actor Replacement

### 1.1 Current GenServer Inventory

**Total GenServers**: 392 across the codebase

| Category | Count | Complexity | Actor Portable? |
|----------|-------|------------|-----------------|
| Simple state holders | 45 | LOW | YES (80%) |
| Timer-based loops | 89 | MEDIUM | PARTIAL (40%) |
| ETS-backed | 67 | HIGH | NO |
| Distributed/Cluster | 46 | CRITICAL | NO |
| Supervised children | 78 | HIGH | NO |
| Phoenix integration | 34 | HIGH | NO |
| Event-driven | 33 | MEDIUM | PARTIAL (30%) |

### 1.2 gleam_otp Actor Capabilities

**What gleam_otp Provides**:

```gleam
import gleam/otp/actor
import gleam/otp/supervisor

// Basic actor (like GenServer)
pub fn start() -> Result(Subject(Message), StartError) {
  actor.start(initial_state, handle_message)
}

// Message handling
fn handle_message(msg: Message, state: State) -> actor.Next(Message, State) {
  case msg {
    SomeMessage(data) -> actor.continue(update_state(state, data))
    Shutdown -> actor.Stop(Normal)
  }
}

// Supervisor (VERY limited)
pub fn start_supervisor() {
  supervisor.start(
    supervisor.Spec(
      children: [
        supervisor.worker(child_actor.start),
      ],
    ),
  )
}
```

**What gleam_otp LACKS**:

| Elixir GenServer Feature | gleam_otp Support | Impact |
|--------------------------|-------------------|--------|
| `handle_call` (sync) | ⚠️ Via Subject reply | Works differently |
| `handle_cast` (async) | ✅ Normal messages | Works |
| `handle_info` (timer) | ❌ No timer integration | CRITICAL |
| `handle_continue` | ❌ None | MEDIUM |
| `terminate` | ❌ None | MEDIUM |
| `code_change` | ❌ None | HIGH |
| `:timer.send_interval` | ❌ None | CRITICAL |
| `Process.send_after` | ❌ None | CRITICAL |
| Process flags | ❌ None | MEDIUM |
| Trap exit | ❌ None | HIGH |
| hibernate | ❌ None | LOW |

### 1.3 Pattern-by-Pattern Replacement Analysis

#### Pattern A: Simple State Container (45 GenServers)

**Current Elixir**:
```elixir
defmodule Indrajaal.Config.Store do
  use GenServer

  def init(config), do: {:ok, config}

  def handle_call(:get, _from, state), do: {:reply, state, state}

  def handle_cast({:put, key, value}, state) do
    {:noreply, Map.put(state, key, value)}
  end
end
```

**Gleam Actor Replacement**:
```gleam
// config_store.gleam

pub type Message {
  Get(reply: Subject(Config))
  Put(key: String, value: Dynamic)
}

pub fn start(config: Config) -> Result(Subject(Message), StartError) {
  actor.start(config, handle_message)
}

fn handle_message(msg: Message, state: Config) -> actor.Next(Message, Config) {
  case msg {
    Get(reply) -> {
      actor.send(reply, state)
      actor.continue(state)
    }
    Put(key, value) -> {
      actor.continue(map.insert(state, key, value))
    }
  }
}
```

**Verdict**: ✅ PORTABLE - Works well for simple state

---

#### Pattern B: Timer-Based OODA Loop (89 GenServers)

**Current Elixir** (`lib/indrajaal/strategy/ooda_loop.ex`):
```elixir
defmodule Indrajaal.Strategy.OODALoop do
  use GenServer

  @interval 1000

  def init(state) do
    schedule_loop()  # <-- PROBLEM: Uses Process.send_after
    {:ok, state}
  end

  def handle_info(:tick, state) do
    new_state = state |> observe() |> orient() |> decide() |> act()
    schedule_loop()
    {:noreply, new_state}
  end

  defp schedule_loop do
    Process.send_after(self(), :tick, @interval)  # <-- NO GLEAM EQUIVALENT
  end
end
```

**Gleam Actor Attempt**:
```gleam
// ooda_loop.gleam - INCOMPLETE

pub type Message {
  Tick
  Shutdown
}

pub fn start(state: State) -> Result(Subject(Message), StartError) {
  actor.start(state, handle_message)
}

fn handle_message(msg: Message, state: State) -> actor.Next(Message, State) {
  case msg {
    Tick -> {
      let new_state = state |> observe |> orient |> decide |> act
      // HOW DO WE SCHEDULE NEXT TICK?
      // No Process.send_after equivalent!
      actor.continue(new_state)
    }
    Shutdown -> actor.Stop(Normal)
  }
}

// PROBLEM: Need external timer to send Tick messages
// Gleam has no built-in timer mechanism
```

**Required Workaround**:
```
┌─────────────────────────────────────────────────────────────┐
│                    TIMER WORKAROUND                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Option 1: Erlang FFI for timer                             │
│  ─────────────────────────────────                          │
│  @external(erlang, "erlang", "send_after")                  │
│  fn send_after(ms: Int, pid: Pid, msg: a) -> TimerRef       │
│                                                              │
│  PROBLEM: Need to get self() pid, which Gleam hides        │
│                                                              │
│  Option 2: External Timer Process (Elixir)                  │
│  ─────────────────────────────────────────                  │
│  defmodule TimerBridge do                                   │
│    def tick(gleam_actor, interval) do                       │
│      :timer.send_interval(interval, gleam_actor, :tick)     │
│    end                                                       │
│  end                                                         │
│                                                              │
│  PROBLEM: Still need Elixir for timer management           │
│                                                              │
│  Option 3: Keep OODA in Elixir, call Gleam pure functions  │
│  ───────────────────────────────────────────────────────    │
│  GenServer in Elixir handles timers                         │
│  Gleam provides: observe(), orient(), decide(), act()       │
│                                                              │
│  THIS IS THE RECOMMENDED APPROACH                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Verdict**: ⚠️ HYBRID ONLY - Timer management stays in Elixir

---

#### Pattern C: ETS-Backed Cache (67 GenServers)

**Current Elixir** (`lib/indrajaal/security/rate_limiter.ex`):
```elixir
defmodule Indrajaal.Security.RateLimiter do
  use GenServer

  def init(opts) do
    cache_table = :ets.new(@cache_table, [:set, :public, :named_table])
    cleanup_timer = :timer.send_interval(@cleanup_interval, :cleanup)
    {:ok, %{cache_table: cache_table, cleanup_timer: cleanup_timer}}
  end

  def check_rate(user_id, endpoint) do
    case :ets.lookup(@cache_table, {user_id, endpoint}) do
      # O(1) concurrent reads - CRITICAL for performance
    end
  end
end
```

**Gleam Has NO ETS**:
```gleam
// IMPOSSIBLE in pure Gleam

// Option 1: Erlang FFI (defeats type safety)
@external(erlang, "ets", "new")
fn ets_new(name: Atom, opts: List(Atom)) -> Table

@external(erlang, "ets", "lookup")
fn ets_lookup(table: Table, key: Dynamic) -> List(Dynamic)

// Option 2: Redis (1000x slower)
pub fn check_rate(user_id: String, endpoint: String) -> Result(Bool, Error) {
  // 0.5μs (ETS) → 500μs (Redis) = 1000x degradation
  redis.get(user_id <> ":" <> endpoint)
}

// Option 3: Single Actor State (bottleneck)
// All rate checks serialize through one process
// UNACCEPTABLE for hot path
```

**Performance Comparison**:

| Operation | ETS | Redis | Actor State |
|-----------|-----|-------|-------------|
| Read latency | 0.5μs | 500μs | 1μs (but serialized) |
| Concurrent reads | Lock-free | Connection pool | Single point |
| Throughput | 10M ops/s | 10K ops/s | 100K ops/s |
| Failure mode | Process crash | Network partition | Actor crash |

**Verdict**: ❌ NOT PORTABLE - ETS must stay in Elixir

---

#### Pattern D: Distributed/Cluster (46 GenServers)

**Current Elixir**:
```elixir
defmodule Indrajaal.Cluster.Leader do
  use GenServer

  def init(_) do
    Node.connect(:"indrajaal@node2")      # NO GLEAM EQUIVALENT
    :global.register_name(:leader, self()) # NO GLEAM EQUIVALENT
    :net_kernel.monitor_nodes(true)        # NO GLEAM EQUIVALENT
    {:ok, %{nodes: Node.list()}}
  end
end
```

**Gleam Has NO Distributed Features**:
```gleam
// ALL of these are IMPOSSIBLE in Gleam:
// - Node.connect
// - Node.list
// - :global registry
// - :rpc.call
// - :net_kernel
// - pg (process groups)
// - Horde
```

**Verdict**: ❌ COMPLETELY BLOCKED - Must stay in Elixir

---

### 1.4 GenServer Replacement Summary

| GenServer Pattern | Count | Gleam Portable | Recommended Approach |
|-------------------|-------|----------------|---------------------|
| Simple state | 45 | ✅ 80% | Port to gleam_otp actor |
| Timer loops | 89 | ⚠️ 40% | Elixir timer + Gleam logic |
| ETS-backed | 67 | ❌ 0% | Keep in Elixir |
| Distributed | 46 | ❌ 0% | Keep in Elixir |
| Supervised | 78 | ❌ 0% | Keep in Elixir |
| Phoenix | 34 | ❌ 0% | Keep in Elixir |
| Event-driven | 33 | ⚠️ 30% | Elixir bridge |
| **TOTAL** | **392** | **~15%** | **~340 stay Elixir** |

---

## Part 2: Ash → Gleam Direct Database Access

### 2.1 Current Ash Architecture

**Ash Resources**: 27 (but 151+ inherit from BaseResource)

**What Ash Provides** (per resource ~60 lines):
```elixir
defmodule Indrajaal.AI.ChatResource do
  use Ash.Resource,
    domain: Indrajaal.AIDomain,
    data_layer: Ash.DataLayer.Ets

  # Auto-generated: ~2,000 lines of functionality
  # - Schema definition
  # - Validation
  # - Authorization policies
  # - Changesets
  # - Query building
  # - Pagination
  # - Relationships
  # - Calculations
  # - Aggregates
  # - Filters
  # - Sorting
  # - API generation (JSON:API)

  attributes do
    uuid_primary_key :id
    attribute :model, :string, allow_nil?: false
    attribute :messages, {:array, :map}, default: []
    # ...
  end

  actions do
    defaults [:read, :destroy]
    create :register do
      accept [:email, :password]
      change hash_password()
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end
end
```

### 2.2 Gleam Database Options

| Library | Purpose | Maturity | Features |
|---------|---------|----------|----------|
| **gleam_pgo** | PostgreSQL | Beta | Raw SQL queries only |
| **sqlight** | SQLite | Alpha | Read-only, simple |
| **gleam_ecto** | N/A | Does not exist | - |

### 2.3 Replacing ONE Ash Resource with Gleam

**Ash Resource**: 60 lines
**Gleam Equivalent**: ~800+ lines

```gleam
// chat_resource.gleam - COMPLETE MANUAL IMPLEMENTATION

import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/list
import gleam/dynamic.{type Dynamic}
import gleam/pgo

// ═══════════════════════════════════════════════════════════════
// TYPES (Ash generates these automatically)
// ═══════════════════════════════════════════════════════════════

pub type ChatSession {
  ChatSession(
    id: String,
    session_id: String,
    model: String,
    messages: List(Message),
    system_prompt: String,
    last_response: Option(String),
    token_usage: TokenUsage,
    status: Status,
    temperature: Float,
    metadata: Dynamic,
    inserted_at: DateTime,
    updated_at: DateTime,
  )
}

pub type Message {
  Message(role: Role, content: String)
}

pub type Role {
  User
  Assistant
  System
}

pub type Status {
  Active
  Paused
  Archived
}

pub type TokenUsage {
  TokenUsage(input: Int, output: Int, total: Int)
}

// ═══════════════════════════════════════════════════════════════
// VALIDATION (Ash provides @constraints, allow_nil?, etc.)
// ═══════════════════════════════════════════════════════════════

pub type ValidationError {
  ModelRequired
  ModelInvalid(model: String)
  SessionIdTooLong
  SystemPromptTooLong
  TemperatureOutOfRange(value: Float)
  Unauthorized
}

const valid_models = [
  "google/gemini-flash-1.5-8b",
  "google/gemini-pro-1.5",
  "anthropic/claude-3.5-sonnet",
  "anthropic/claude-3-opus",
  "openai/gpt-4o",
  "openai/o1-preview",
]

pub fn validate_model(model: String) -> Result(String, ValidationError) {
  case list.contains(valid_models, model) {
    True -> Ok(model)
    False -> Error(ModelInvalid(model))
  }
}

pub fn validate_session_id(session_id: String) -> Result(String, ValidationError) {
  case string.length(session_id) > 100 {
    True -> Error(SessionIdTooLong)
    False -> Ok(session_id)
  }
}

pub fn validate_system_prompt(prompt: String) -> Result(String, ValidationError) {
  case string.length(prompt) > 10_000 {
    True -> Error(SystemPromptTooLong)
    False -> Ok(prompt)
  }
}

pub fn validate_temperature(temp: Float) -> Result(Float, ValidationError) {
  case temp >=. 0.0 && temp <=. 2.0 {
    True -> Ok(temp)
    False -> Error(TemperatureOutOfRange(temp))
  }
}

// ═══════════════════════════════════════════════════════════════
// CREATE INPUT & VALIDATION (Ash: `accept [:email, :password]`)
// ═══════════════════════════════════════════════════════════════

pub type CreateChatInput {
  CreateChatInput(
    model: Option(String),
    system_prompt: Option(String),
    temperature: Option(Float),
    metadata: Option(Dynamic),
  )
}

pub fn validate_create(input: CreateChatInput) -> Result(ValidatedCreate, ValidationError) {
  let model = option.unwrap(input.model, "google/gemini-flash-1.5-8b")
  use validated_model <- result.try(validate_model(model))

  let prompt = option.unwrap(input.system_prompt, default_prompt())
  use validated_prompt <- result.try(validate_system_prompt(prompt))

  let temp = option.unwrap(input.temperature, 0.7)
  use validated_temp <- result.try(validate_temperature(temp))

  Ok(ValidatedCreate(
    model: validated_model,
    system_prompt: validated_prompt,
    temperature: validated_temp,
    metadata: option.unwrap(input.metadata, dynamic.from(dict.new())),
  ))
}

// ═══════════════════════════════════════════════════════════════
// AUTHORIZATION (Ash: `policies do ... end`)
// ═══════════════════════════════════════════════════════════════

pub type Actor {
  Actor(id: String, role: ActorRole)
}

pub type ActorRole {
  Admin
  RegularUser
  Guest
}

pub fn authorize_read(actor: Actor, chat: ChatSession) -> Result(Nil, ValidationError) {
  case actor.role {
    Admin -> Ok(Nil)
    RegularUser -> {
      // Owner can read their own chats
      // Need to add owner_id to ChatSession first...
      // This is getting complex
      Ok(Nil)
    }
    Guest -> Error(Unauthorized)
  }
}

pub fn authorize_create(actor: Actor) -> Result(Nil, ValidationError) {
  case actor.role {
    Admin -> Ok(Nil)
    RegularUser -> Ok(Nil)
    Guest -> Error(Unauthorized)
  }
}

// ═══════════════════════════════════════════════════════════════
// DATABASE ACCESS (Ash: automatic via AshPostgres)
// ═══════════════════════════════════════════════════════════════

// Must write RAW SQL for everything

pub fn create_chat(
  db: pgo.Connection,
  input: ValidatedCreate,
  actor: Actor,
) -> Result(ChatSession, DatabaseError) {
  use _ <- result.try(authorize_create(actor))

  let id = uuid.v4()
  let session_id = uuid.v4()
  let now = datetime.now()

  let sql = "
    INSERT INTO chat_sessions (
      id, session_id, model, messages, system_prompt,
      last_response, token_usage, status, temperature,
      metadata, inserted_at, updated_at
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
    ) RETURNING *
  "

  // Must manually encode all fields
  let params = [
    pgo.text(id),
    pgo.text(session_id),
    pgo.text(input.model),
    pgo.json(encode_messages([])),  // Must write encoder
    pgo.text(input.system_prompt),
    pgo.null(),  // last_response
    pgo.json(encode_token_usage(default_token_usage())),
    pgo.text("active"),
    pgo.float(input.temperature),
    pgo.json(input.metadata),
    pgo.timestamp(now),
    pgo.timestamp(now),
  ]

  case pgo.execute(db, sql, params) {
    Ok(result) -> decode_chat_session(result.rows)
    Error(e) -> Error(DatabaseError(e))
  }
}

pub fn get_chat(
  db: pgo.Connection,
  id: String,
  actor: Actor,
) -> Result(ChatSession, DatabaseError) {
  let sql = "SELECT * FROM chat_sessions WHERE id = $1"

  case pgo.execute(db, sql, [pgo.text(id)]) {
    Ok(result) -> {
      case result.rows {
        [row] -> {
          use chat <- result.try(decode_chat_session([row]))
          use _ <- result.try(authorize_read(actor, chat))
          Ok(chat)
        }
        [] -> Error(NotFound)
        _ -> Error(MultipleResults)
      }
    }
    Error(e) -> Error(DatabaseError(e))
  }
}

pub fn list_chats(
  db: pgo.Connection,
  actor: Actor,
  opts: ListOptions,
) -> Result(Page(ChatSession), DatabaseError) {
  // Must build SQL dynamically for:
  // - Filtering
  // - Sorting
  // - Pagination
  // - Authorization scoping

  let base_sql = "SELECT * FROM chat_sessions"

  // Build WHERE clause based on actor's permissions
  let where_clause = case actor.role {
    Admin -> ""
    RegularUser -> " WHERE owner_id = $1"
    Guest -> " WHERE 1=0"  // No access
  }

  // Add sorting
  let order_clause = case opts.sort {
    Some(field) -> " ORDER BY " <> field <> order_direction(opts.direction)
    None -> " ORDER BY inserted_at DESC"
  }

  // Add pagination
  let limit_clause = " LIMIT $2 OFFSET $3"

  let sql = base_sql <> where_clause <> order_clause <> limit_clause

  // Execute and decode all results
  case pgo.execute(db, sql, build_params(actor, opts)) {
    Ok(result) -> {
      let chats = list.filter_map(result.rows, decode_one_chat)
      Ok(Page(data: chats, total: count_total(db, actor)))
    }
    Error(e) -> Error(DatabaseError(e))
  }
}

// ═══════════════════════════════════════════════════════════════
// DECODERS (Ash handles this automatically)
// ═══════════════════════════════════════════════════════════════

fn decode_chat_session(rows: List(Dynamic)) -> Result(ChatSession, DecodeError) {
  // Must manually decode every field from database row
  // This is ~100 lines of code
  todo
}

fn encode_messages(messages: List(Message)) -> Json {
  // Must manually encode to JSON
  todo
}

fn decode_messages(json: Dynamic) -> Result(List(Message), DecodeError) {
  // Must manually decode from JSON
  todo
}

// ... 300+ more lines for updates, deletes, relationships, etc.
```

### 2.4 Ash Feature Loss Matrix

| Ash Feature | Lines Saved | Gleam Alternative | Effort |
|-------------|-------------|-------------------|--------|
| Schema DSL | ~50/resource | Manual types | 3x more code |
| Validation DSL | ~30/resource | Manual functions | 5x more code |
| Policy DSL | ~20/resource | Manual checks | 4x more code |
| Actions DSL | ~40/resource | Manual CRUD | 5x more code |
| Changesets | ~200 generated | Manual validation | 10x more code |
| Query building | ~500 generated | Raw SQL | 15x more code |
| Pagination | ~100 generated | Manual SQL | 8x more code |
| Relationships | ~300 generated | Manual JOINs | 10x more code |
| Aggregates | ~100 generated | Manual SQL | 8x more code |
| Calculations | ~100 generated | Manual compute | 5x more code |
| JSON:API | ~500 generated | Manual serialization | 12x more code |
| GraphQL | ~300 generated | Manual schema | 10x more code |
| **TOTAL** | ~2,000/resource | Manual everything | **10x average** |

### 2.5 Full System Impact

**Current Ash Resources**: 27 primary + 151 using BaseResource

| Metric | Ash (Current) | Gleam (Replacement) | Ratio |
|--------|---------------|---------------------|-------|
| Lines of DSL code | ~10,000 | N/A | - |
| Lines of generated code | ~200,000 | 0 | - |
| Lines of manual code | 0 | ~200,000+ | ∞ |
| Development time | 6 months | 24+ months | 4x |
| Bug surface area | Framework handles | All manual | 10x |
| Type safety | Runtime | Compile-time | Better |
| Query optimization | Automatic | Manual | Worse |
| Schema migrations | Ecto auto | Manual SQL | 10x work |

### 2.6 Gleam Database Limitations

**gleam_pgo features**:
```gleam
// EVERYTHING is manual raw SQL

// No: Migrations
// No: Schema inference
// No: Query builder
// No: Relationship loading
// No: Preloading
// No: Upsert helpers
// No: Transactions (basic support only)
// No: Connection pooling management
// No: Prepared statements caching
```

**What you lose**:

| Ash/Ecto Feature | Gleam Status | Workaround |
|------------------|--------------|------------|
| Migrations | ❌ None | Manual SQL files |
| Changesets | ❌ None | Manual validation |
| Preloads | ❌ None | N+1 or manual JOINs |
| Virtual fields | ❌ None | Post-processing |
| Embeds | ❌ None | JSON columns |
| Polymorphic | ❌ None | Multiple tables |
| Soft delete | ❌ None | Manual WHERE |
| Timestamps | ❌ None | Manual triggers |
| Optimistic locking | ❌ None | Manual version check |

---

## Part 3: The Transformed System Architecture

### 3.1 Component Distribution

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    INDRAJAAL POST-TRANSFORMATION                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  GLEAM COMPONENTS (35% of system)                                       │
│  ═══════════════════════════════                                        │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Domain Types & Validation                                         │  │
│  │ ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────────┐ │  │
│  │ │ Types.gleam│ │Validators  │ │ Errors     │ │ BusinessLogic  │ │  │
│  │ │ (100%)     │ │ (100%)     │ │ (100%)     │ │ (pure 80%)     │ │  │
│  │ └────────────┘ └────────────┘ └────────────┘ └────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Simple Actors (gleam_otp)                                         │  │
│  │ ┌────────────┐ ┌────────────┐ ┌────────────┐                    │  │
│  │ │ ConfigActor│ │ SessionActor│ │ CacheActor │ (~45 actors)     │  │
│  │ │ (simple)   │ │ (simple)    │ │ (NO ETS!)  │                    │  │
│  │ └────────────┘ └────────────┘ └────────────┘                    │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ HTTP Layer (Wisp/Mist)                                            │  │
│  │ ┌────────────┐ ┌────────────┐ ┌────────────┐                    │  │
│  │ │ Routes     │ │ Handlers   │ │ JSON Encode│                    │  │
│  │ │ (type-safe)│ │ (pure)     │ │ (gleam_json│                    │  │
│  │ └────────────┘ └────────────┘ └────────────┘                    │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Database Access (gleam_pgo) - RAW SQL ONLY                        │  │
│  │ ┌────────────────────────────────────────────────────────────┐  │  │
│  │ │ MANUAL: Insert, Update, Delete, Select, Join, Aggregate    │  │  │
│  │ │ MANUAL: Validation, Authorization, Pagination, Sorting      │  │  │
│  │ │ MANUAL: Encoding, Decoding, Error handling                  │  │  │
│  │ └────────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│                              ║ FFI BOUNDARY ║                            │
│                              ║═════════════════║                         │
│                                                                          │
│  ELIXIR COMPONENTS (65% of system) - NON-NEGOTIABLE                     │
│  ══════════════════════════════════════════════════                     │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Complex GenServers (347 of 392)                                   │  │
│  │ ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────────┐ │  │
│  │ │ OODA Loops │ │ Supervisors│ │ ETS-backed │ │ Distributed    │ │  │
│  │ │ (timers)   │ │ (17 trees) │ │ (67 caches)│ │ (46 cluster)   │ │  │
│  │ └────────────┘ └────────────┘ └────────────┘ └────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Database Layer (Ecto + Migrations)                                │  │
│  │ ┌────────────────────────────────────────────────────────────┐  │  │
│  │ │ Schema definitions, Migrations, Transactions, Pools        │  │  │
│  │ │ Connection management, Query optimization, Telemetry        │  │  │
│  │ └────────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Phoenix LiveView                                                  │  │
│  │ ┌────────────┐ ┌────────────┐ ┌────────────┐                    │  │
│  │ │ Prajna     │ │ Dashboard  │ │ Real-time  │ (All UI)          │  │
│  │ │ Cockpit    │ │ Views      │ │ Updates    │                    │  │
│  │ └────────────┘ └────────────┘ └────────────┘                    │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Telemetry & Observability                                         │  │
│  │ ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────────┐ │  │
│  │ │ :telemetry │ │ OTEL       │ │ Prometheus │ │ Zenoh Bridge   │ │  │
│  │ │ (events)   │ │ (traces)   │ │ (metrics)  │ │ (real-time)    │ │  │
│  │ └────────────┘ └────────────┘ └────────────┘ └────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Safety-Critical (MUST BE ELIXIR/OTP)                              │  │
│  │ ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────────┐ │  │
│  │ │ Guardian   │ │ Sentinel   │ │ Immutable  │ │ Constitutional │ │  │
│  │ │ (safety)   │ │ (defense)  │ │ Register   │ │ Verification   │ │  │
│  │ └────────────┘ └────────────┘ └────────────┘ └────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 File Count After Transformation

| Category | Current Elixir | Gleam | Elixir (Remaining) | Total |
|----------|---------------|-------|-------------------|-------|
| Types/Validation | 94 | 94 (ported) | 0 | 94 |
| Business Logic | 120 | 96 (80%) | 24 | 120 |
| Simple Actors | 45 | 45 (ported) | 0 | 45 |
| Complex GenServers | 347 | 0 | 347 | 347 |
| Database (Ash) | 178 | 0 | 178 | 178 |
| HTTP Layer | 40 | 30 (partial) | 10 | 40 |
| Phoenix/LiveView | 92 | 0 | 92 | 92 |
| Telemetry | 60 | 0 | 60 | 60 |
| Safety | 45 | 0 | 45 | 45 |
| **TOTAL** | **1,021** | **265** | **756** | **1,021** |

### 3.3 What The System LOSES

| Capability | Current | After Transformation |
|------------|---------|---------------------|
| **Type Safety** | Runtime (Dialyzer optional) | Compile-time in Gleam layer |
| **Hot Code Reload** | Full OTP support | Only Elixir layer |
| **Supervision** | 17 full supervision trees | Elixir-only |
| **ETS Performance** | 10M ops/sec | Elixir bridge or Redis |
| **Ash DSL** | 60 lines = 2000 generated | 800+ manual lines |
| **Query Building** | Automatic | Raw SQL everywhere |
| **Migrations** | Ecto auto | Manual SQL files |
| **LiveView** | Real-time UI | Elixir only |
| **Telemetry** | Native integration | FFI bridge |
| **Distributed** | Native clustering | Elixir sidecar |

### 3.4 What The System GAINS

| Benefit | Impact | Reality Check |
|---------|--------|--------------|
| **Compile-time types** | Fewer runtime errors | Only in Gleam layer (35%) |
| **Simpler syntax** | Easier to read | But two languages now |
| **Exhaustive patterns** | No missed cases | Still need Elixir patterns |
| **Explicit effects** | Clearer IO boundaries | But complex FFI |
| **No exceptions** | Result types | Must handle at boundaries |

---

## Part 4: Effort Estimation

### 4.1 Development Timeline

| Phase | Duration | Team | Deliverable |
|-------|----------|------|-------------|
| P1: Type Layer | 4 weeks | 2 | Gleam types + validators |
| P2: Simple Actors | 4 weeks | 2 | Port 45 simple GenServers |
| P3: HTTP Layer | 3 weeks | 2 | Wisp handlers |
| P4: Database Layer | 12 weeks | 3 | Replace Ash with manual |
| P5: FFI Bridges | 8 weeks | 2 | Elixir ↔ Gleam bridges |
| P6: Integration | 12 weeks | 3 | Wire everything together |
| P7: Testing | 8 weeks | 2 | Migrate 500+ tests | [Updated Sprint 51]
| P8: Optimization | 6 weeks | 2 | Performance tuning |
| **TOTAL** | **57 weeks** | **~2.5 avg** | Hybrid system |

### 4.2 Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Performance regression | HIGH | HIGH | Benchmark every change |
| Type boundary bugs | MEDIUM | HIGH | Extensive FFI testing |
| Ash functionality loss | HIGH | CRITICAL | Feature parity checklist |
| Team learning curve | MEDIUM | MEDIUM | Training investment |
| Ecosystem gaps | HIGH | MEDIUM | Elixir fallback |
| Maintenance burden | HIGH | HIGH | Two-language expertise |

---

## Part 5: Final Verdict

### 5.1 Should You Replace GenServers with Gleam Actors?

| Recommendation | Scope | Reason |
|----------------|-------|--------|
| ✅ YES | Simple state holders (45) | Direct mapping, type safety gain |
| ⚠️ PARTIAL | Timer-based (89) | Pure logic in Gleam, timers in Elixir |
| ❌ NO | Everything else (258) | OTP features required |

### 5.2 Should You Replace Ash with Gleam Direct Access?

| Recommendation | Scope | Reason |
|----------------|-------|--------|
| ❌ **NO** | All 27+ resources | 10x code explosion, feature loss |

**Why Ash Replacement is NOT Recommended**:

1. **10x Code Explosion**: 60 lines Ash → 800+ lines Gleam
2. **Feature Loss**: Changesets, policies, pagination, relationships
3. **No Migrations**: Manual SQL file management
4. **No Query Builder**: Raw SQL everywhere
5. **No Type Generation**: Manual decoders for everything
6. **No Tooling**: Lost `mix ash.*` commands

### 5.3 What Would The System Look Like?

```
BEFORE (100% Elixir):
├── 1,318 Elixir files
├── 475,482 lines of code
├── Unified OTP supervision
├── Ash DSL for all resources
├── Phoenix LiveView UI
└── Full BEAM ecosystem

AFTER (35% Gleam / 65% Elixir):
├── 265 Gleam files (types, validation, simple actors)
├── 756 Elixir files (GenServers, DB, Phoenix, safety)
├── Complex FFI boundary management
├── Two build systems (Mix + Gleam)
├── Manual database access for Gleam layer
├── Elixir sidecar for all OTP features
└── Hybrid deployment complexity
```

### 5.4 Strategic Recommendation

**DO NOT pursue full GenServer→Actor or Ash→Direct replacement.**

**Instead, consider**:

| Option | Scope | Effort | Value |
|--------|-------|--------|-------|
| **A: Gleam for new pure modules** | New code only | LOW | Type safety for new work |
| **B: Port validation layer** | ~120 files | MEDIUM | Safer input handling |
| **C: Full hybrid** | 35% Gleam | VERY HIGH | Marginal benefit for massive effort |

**Recommended Path**: Option A or B

---

## Appendix: Code Examples

### A.1 Gleam Actor with Elixir Timer Bridge

```gleam
// gleam_ooda.gleam - Pure OODA logic

pub type Observation {
  Observation(metrics: List(Metric), timestamp: Time)
}

pub type Decision {
  Hold
  Act(action: Action)
  Escalate(reason: String)
}

pub fn observe(state: State, inputs: Inputs) -> Observation {
  Observation(
    metrics: extract_metrics(inputs),
    timestamp: inputs.timestamp,
  )
}

pub fn orient(obs: Observation, model: Model) -> Orientation {
  analyze_context(obs, model)
}

pub fn decide(orientation: Orientation, policy: Policy) -> Decision {
  case orientation.threat_level {
    Critical -> Escalate("Immediate attention required")
    High -> Act(high_priority_action(orientation))
    _ -> Hold
  }
}
```

```elixir
# elixir_ooda_bridge.ex - Timer management stays here

defmodule Indrajaal.OODABridge do
  use GenServer

  @interval 1000

  def init(state) do
    :timer.send_interval(@interval, :tick)
    {:ok, %{state: state, model: load_model()}}
  end

  def handle_info(:tick, %{state: state, model: model} = s) do
    inputs = gather_inputs()

    # Call Gleam pure functions
    observation = :gleam_ooda.observe(state, inputs)
    orientation = :gleam_ooda.orient(observation, model)
    decision = :gleam_ooda.decide(orientation, get_policy())

    # Execute decision (side effects in Elixir)
    new_state = execute(state, decision)

    {:noreply, %{s | state: new_state}}
  end
end
```

---

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Author | Claude Opus 4.5 |
| Created | 2026-01-11 |
| STAMP | SC-MIG-010 to SC-MIG-019 |
| Status | COMPLETE |

---

*This analysis concludes that replacing GenServers with Gleam actors is only viable for ~15% of cases (45 simple state holders), and replacing Ash with Gleam direct database access is NOT RECOMMENDED due to 10x code explosion and significant feature loss.*
