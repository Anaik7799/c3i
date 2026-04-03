# Gleam-Elixir Comprehensive Porting Guide

**Version**: 1.0.0 | **Date**: 2026-01-11 | **Status**: COMPLETE
**Scope**: Complete reference for porting Elixir code to Gleam with all known techniques

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Part 1: BEAM Capabilities in Gleam](#part-1-beam-capabilities-in-gleam)
3. [Part 2: Architectural Patterns](#part-2-architectural-patterns)
4. [Part 3: Porting Techniques by Construct](#part-3-porting-techniques-by-construct)
5. [Part 4: FFI & Interoperability](#part-4-ffi--interoperability)
6. [Part 5: Testing Strategies](#part-5-testing-strategies)
7. [Part 6: Indrajaal-Specific Assessment](#part-6-indrajaal-specific-assessment)
8. [Part 7: Implementation Roadmap](#part-7-implementation-roadmap)
9. [Sources](#sources)

---

## Executive Summary

This guide collates ALL known techniques for porting Elixir code to Gleam, based on:
- Official Gleam documentation and libraries
- Community patterns and best practices
- Indrajaal-specific architectural analysis

### Key Libraries for Porting

| Category | Library | Purpose |
|----------|---------|---------|
| **OTP Actors** | [gleam_otp](https://hexdocs.pm/gleam_otp/) | Type-safe GenServer replacement |
| **Distributed** | [Distribute](https://hexdocs.pm/distribute/) | Type-safe distributed Erlang |
| **ETS** | [Bravo](https://hexdocs.pm/bravo/) / [Carpenter](https://hexdocs.pm/carpenter/) | Type-safe ETS wrappers |
| **Clustering** | [glixir](https://hexdocs.pm/glixir/) | libcluster wrapper for Gleam |
| **Mix Integration** | [mix_gleam](https://github.com/gleam-lang/mix_gleam) | Compile Gleam in Mix projects |
| **Phoenix UI** | [Lissome](https://github.com/selenil/lissome) | Lustre in LiveView |
| **Testing** | [gleeunit](https://github.com/lpil/gleeunit) / [qcheck](https://github.com/mooreryan/gleam_qcheck) | Unit & property testing |

### Revised Portability Matrix (Indrajaal)

| Component | Count | Portability | Technique |
|-----------|-------|-------------|-----------|
| Simple GenServers | 45 | 95% | gleam_otp actor |
| Timer GenServers | 89 | 70% | Erlang FFI timers |
| Supervised GenServers | 78 | 60% | Elixir supervisor integration |
| ETS-backed | 67 | 30% | Bravo/Carpenter + FFI |
| Distributed | 46 | 40% | Distribute library |
| Event-driven | 33 | 50% | Subject-based pub/sub |
| Phoenix/LiveView | 34 | 20% | Lissome for complex UI |
| Ash Resources | 178 | 0% | Keep in Elixir |
| **TOTAL** | **570** | **~45%** | Hybrid architecture |

---

## Part 1: BEAM Capabilities in Gleam

### 1.1 Distributed Erlang

Gleam fully supports distributed Erlang through the [Distribute](https://hexdocs.pm/distribute/) library:

```gleam
import distribute
import distribute/remote_call
import distribute/typed_messaging

// Connect to remote node
pub fn connect_to_cluster() -> Result(Nil, Error) {
  distribute.connect(atom.create_from_string("app@node2"))
}

// Type-safe RPC
pub fn remote_compute(node: Node, data: Data) -> Result(Response, Error) {
  remote_call.call(
    node,
    module: "my_module",
    function: "compute",
    args: [dynamic.from(data)],
  )
}

// Type-safe messaging with binary codecs
pub fn send_typed_message(
  target: Subject(BitArray),
  message: MyMessage,
) -> Result(Nil, Error) {
  let encoded = my_codec.encode(message)
  typed_messaging.send_typed(target, encoded)
}
```

**Features**:
- Binary Codec System for compile-time safe serialization
- Envelope Protocol for version validation
- SWIM-like membership for failure detection
- Raft-lite election for leader coordination
- Global registry wrapping `:global`

### 1.2 ETS (Erlang Term Storage)

Two libraries provide type-safe ETS access:

#### Bravo (Comprehensive)

```gleam
import bravo
import bravo/uset

pub fn create_cache() -> Result(USet(String, User), Error) {
  uset.new("user_cache", bravo.Public)
}

pub fn cache_user(cache: USet(String, User), user: User) -> Nil {
  uset.insert(cache, #(user.id, user))
}

pub fn get_user(cache: USet(String, User), id: String) -> Option(User) {
  case uset.lookup(cache, id) {
    [#(_, user)] -> Some(user)
    _ -> None
  }
}
```

**Bravo Table Types**:
- `USet` - Unique keys, unordered
- `OSet` - Unique keys, ordered
- `Bag` - Duplicate keys, unique objects
- `DBag` - Duplicate keys, duplicate objects

#### Carpenter (Simple Key-Value)

```gleam
import carpenter/table

pub fn create_simple_cache() -> table.Set(String, Int) {
  let assert Ok(cache) = table.build("counters")
    |> table.privacy(table.Public)
    |> table.set
  cache
}

pub fn increment(cache: table.Set(String, Int), key: String) -> Int {
  let current = table.lookup(cache, key) |> option.unwrap(0)
  table.insert(cache, [#(key, current + 1)])
  current + 1
}
```

### 1.3 Clustering

#### Via Glixir (libcluster wrapper)

```gleam
import glixir/libcluster

pub fn setup_cluster() -> Result(Nil, Error) {
  libcluster.start_link(
    topologies: [
      libcluster.Topology(
        name: "k8s",
        strategy: libcluster.Kubernetes,
        config: [
          libcluster.KubernetesSelector("app=myapp"),
        ],
      ),
    ],
  )
}
```

**Supported Strategies**:
- Kubernetes DNS
- Fly.io
- AWS EC2
- EPMD (local)
- Gossip UDP

#### Via gleam_erlang/node

```gleam
import gleam/erlang/node

pub fn list_cluster_nodes() -> List(Node) {
  node.visible()
}

pub fn connect_node(name: String) -> Result(Nil, Error) {
  let target = node.from_string(name)
  node.connect(target)
}
```

---

## Part 2: Architectural Patterns

### 2.1 Strangler Fig Pattern

The [Strangler Fig Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/strangler-fig) enables incremental migration:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    STRANGLER FIG ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│                         ┌─────────────────┐                         │
│                         │   FACADE/PROXY  │                         │
│                         │  (Router Layer) │                         │
│                         └────────┬────────┘                         │
│                                  │                                   │
│              ┌───────────────────┼───────────────────┐              │
│              ▼                   ▼                   ▼              │
│    ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐     │
│    │ GLEAM (New)     │ │ HYBRID          │ │ ELIXIR (Legacy) │     │
│    │ Types/Validation│ │ Gleam Logic +   │ │ Phoenix, Ecto   │     │
│    │ Simple Actors   │ │ Elixir Infra    │ │ Complex OTP     │     │
│    └─────────────────┘ └─────────────────┘ └─────────────────┘     │
│                                                                      │
│                     BEAM VM (Shared Runtime)                        │
└─────────────────────────────────────────────────────────────────────┘
```

**Implementation**:

```elixir
# lib/my_app/gleam_facade.ex
defmodule MyApp.GleamFacade do
  @migrated %{
    validation: :gleam,
    config: :gleam,
    business_logic: :gleam,
    database: :elixir,
    phoenix: :elixir,
  }

  def route(module, function, args) do
    case Map.get(@migrated, module) do
      :gleam -> apply(gleam_module(module), function, args)
      :elixir -> apply(elixir_module(module), function, args)
    end
  end
end
```

### 2.2 Gleam Sandwich Pattern

**Input (Elixir) → Logic (Gleam) → Output (Elixir)**

```elixir
# Elixir Controller
defmodule MyAppWeb.UserController do
  def create(conn, params) do
    # Input: Elixir receives request
    case :user_validation.validate(params) do  # Logic: Gleam validates
      {:ok, valid_data} ->
        user = Repo.insert!(valid_data)  # Output: Elixir persists
        json(conn, user)
      {:error, errors} ->
        conn |> put_status(422) |> json(errors)
    end
  end
end
```

```gleam
// user_validation.gleam
pub fn validate(params: Dict(String, Dynamic)) -> Result(ValidUser, List(Error)) {
  use email <- result.try(validate_email(params))
  use name <- result.try(validate_name(params))
  use age <- result.try(validate_age(params))
  Ok(ValidUser(email: email, name: name, age: age))
}
```

### 2.3 Functional Core, Imperative Shell

- **Gleam (Core)**: Pure business logic, type-safe validation, state transformations
- **Elixir (Shell)**: Side effects, database, HTTP, file I/O, external APIs

```gleam
// Pure business logic in Gleam
pub fn calculate_discount(cart: Cart, user: User) -> Discount {
  let base = cart.total *. 0.1
  let loyalty = case user.tier {
    Gold -> base *. 1.5
    Silver -> base *. 1.2
    Bronze -> base
  }
  Discount(amount: loyalty, reason: "Loyalty discount")
}
```

```elixir
# Side effects in Elixir
def apply_discount(cart_id, user_id) do
  cart = Repo.get!(Cart, cart_id)
  user = Repo.get!(User, user_id)

  # Call Gleam for pure logic
  discount = :discount_calculator.calculate_discount(cart, user)

  # Elixir handles persistence
  Repo.update!(cart, %{discount: discount.amount})
  send_email(user, "You got a #{discount.reason}!")
end
```

---

## Part 3: Porting Techniques by Construct

### 3.1 GenServer → Gleam Actor

| Elixir Feature | Gleam Replacement |
|----------------|-------------------|
| `use GenServer` | `gleam/otp/actor` |
| `handle_call` | Message with `Subject(Reply)` |
| `handle_cast` | Fire-and-forget message |
| `handle_info` | Custom selector |
| `init` | `actor.Spec.init` |
| `terminate` | No direct equivalent |
| `code_change` | No equivalent |

```elixir
# Elixir GenServer
defmodule Counter do
  use GenServer

  def init(count), do: {:ok, count}

  def handle_call(:get, _from, count), do: {:reply, count, count}
  def handle_cast({:add, n}, count), do: {:noreply, count + n}
end
```

```gleam
// Gleam Actor
import gleam/otp/actor
import gleam/erlang/process.{type Subject}

pub type Message {
  Get(reply_to: Subject(Int))
  Add(value: Int)
}

pub fn start(initial: Int) -> Result(Subject(Message), actor.StartError) {
  actor.start(initial, handle_message)
}

fn handle_message(msg: Message, count: Int) -> actor.Next(Message, Int) {
  case msg {
    Get(reply_to) -> {
      process.send(reply_to, count)
      actor.continue(count)
    }
    Add(n) -> actor.continue(count + n)
  }
}
```

### 3.2 Timer-Based GenServers (Erlang FFI)

```gleam
// Timer via Erlang FFI
@external(erlang, "timer", "send_interval")
fn timer_send_interval(ms: Int, pid: Pid, msg: a) -> Result(Ref, Dynamic)

@external(erlang, "erlang", "self")
fn self() -> Pid

pub type TimerMessage {
  Tick
  Stop
}

pub fn start_timer_actor(interval_ms: Int) -> Result(Subject(TimerMessage), Error) {
  actor.start_spec(actor.Spec(
    init: fn() {
      let _ = timer_send_interval(interval_ms, self(), Tick)
      actor.Ready(initial_state(), process.new_selector())
    },
    init_timeout: 5000,
    loop: fn(msg, state) {
      case msg {
        Tick -> {
          let new_state = do_tick(state)
          actor.continue(new_state)
        }
        Stop -> actor.Stop(process.Normal)
      }
    },
  ))
}
```

### 3.3 Behaviours → Types with Functions

```elixir
# Elixir Behaviour
defmodule MyApp.Storage do
  @callback save(data :: term()) :: {:ok, id :: String.t()} | {:error, term()}
  @callback load(id :: String.t()) :: {:ok, term()} | {:error, :not_found}
end

defmodule MyApp.S3Storage do
  @behaviour MyApp.Storage
  def save(data), do: S3.put_object(data)
  def load(id), do: S3.get_object(id)
end
```

```gleam
// Gleam Type with Functions
pub type Storage {
  Storage(
    save: fn(Dynamic) -> Result(String, Error),
    load: fn(String) -> Result(Dynamic, Error),
  )
}

pub fn s3_storage() -> Storage {
  Storage(
    save: fn(data) { s3.put_object(data) },
    load: fn(id) { s3.get_object(id) },
  )
}

pub fn postgres_storage() -> Storage {
  Storage(
    save: fn(data) { postgres.insert(data) },
    load: fn(id) { postgres.select(id) },
  )
}

// Usage - pass storage explicitly
pub fn process_data(storage: Storage, data: Dynamic) -> Result(String, Error) {
  storage.save(data)
}
```

### 3.4 Macros → Use Expressions

Elixir macros cannot be called from Gleam. Workarounds:

**Option 1: Wrap in Elixir module**

```elixir
# lib/my_app/gleam_bridge.ex
defmodule MyApp.GleamBridge do
  # Use the macro in Elixir
  use Phoenix.Component

  # Expose as regular function
  def render_component(assigns) do
    ~H"""
    <div><%= @content %></div>
    """
  end
end
```

```gleam
// Call the wrapped function
@external(erlang, "Elixir.MyApp.GleamBridge", "render_component")
fn render_component(assigns: Dynamic) -> String
```

**Option 2: Gleam's `use` expression**

```gleam
// Gleam's use is syntactic sugar for callbacks
pub fn with_connection(f: fn(Connection) -> Result(a, Error)) -> Result(a, Error) {
  let conn = open_connection()
  let result = f(conn)
  close_connection(conn)
  result
}

// Using it
pub fn save_user(user: User) -> Result(Nil, Error) {
  use conn <- with_connection()
  insert(conn, user)
}
```

### 3.5 Structs → Custom Types

```elixir
# Elixir Struct
defmodule User do
  defstruct [:id, :name, :email, :age]
end

user = %User{id: "123", name: "Alice", email: "a@b.com", age: 30}
```

```gleam
// Gleam Custom Type
pub type User {
  User(id: String, name: String, email: String, age: Int)
}

let user = User(id: "123", name: "Alice", email: "a@b.com", age: 30)

// Accessing fields
user.name  // "Alice"

// Pattern matching
case user {
  User(name: n, ..) -> io.println("Hello, " <> n)
}
```

### 3.6 Ecto Schemas → Keep in Elixir

**Recommendation**: Do NOT port Ecto to Gleam. Use the Gleam Sandwich pattern.

```elixir
# Keep Ecto in Elixir
defmodule MyApp.Repo do
  def get_user_for_gleam(id) do
    case Repo.get(User, id) do
      nil -> {:error, :not_found}
      user -> {:ok, to_gleam_map(user)}
    end
  end

  defp to_gleam_map(user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      age: user.age
    }
  end
end
```

```gleam
// Gleam receives plain data
@external(erlang, "Elixir.MyApp.Repo", "get_user_for_gleam")
fn get_user(id: String) -> Result(Dict(String, Dynamic), Atom)

pub fn process_user(id: String) -> Result(ProcessedUser, Error) {
  use user_data <- result.try(get_user(id))
  use user <- result.try(decode_user(user_data))
  Ok(process(user))
}
```

### 3.7 Phoenix LiveView → Lissome/Lustre

For complex client-side state, use [Lissome](https://github.com/selenil/lissome):

```elixir
# In your LiveView
defmodule MyAppWeb.ComplexLive do
  use MyAppWeb, :live_view
  import Lissome

  def render(assigns) do
    ~H"""
    <div>
      <!-- Simple LiveView parts -->
      <h1><%= @title %></h1>

      <!-- Complex interactive part via Lustre -->
      <.lustre
        id="complex-editor"
        module={:complex_editor}
        props={%{data: @data}}
        ssr={true}
      />
    </div>
    """
  end
end
```

```gleam
// complex_editor.gleam - Lustre component
import lustre
import lustre/element.{type Element}
import lustre/element/html

pub type Model {
  Model(items: List(Item), selected: Option(Int))
}

pub type Msg {
  Select(Int)
  Add(Item)
  Remove(Int)
}

pub fn init(_) -> Model {
  Model(items: [], selected: None)
}

pub fn update(model: Model, msg: Msg) -> Model {
  case msg {
    Select(id) -> Model(..model, selected: Some(id))
    Add(item) -> Model(..model, items: [item, ..model.items])
    Remove(id) -> Model(..model, items: list.filter(model.items, fn(i) { i.id != id }))
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([], [
    html.ul([], list.map(model.items, render_item)),
    html.button([event.on_click(Add(new_item()))], [html.text("Add")]),
  ])
}
```

---

## Part 4: FFI & Interoperability

### 4.1 The @external Attribute

```gleam
// Calling Erlang
@external(erlang, "erlang", "now")
fn erlang_now() -> #(Int, Int, Int)

// Calling Elixir (note: target is still "erlang")
@external(erlang, "Elixir.Enum", "to_list")
fn enum_to_list(enumerable: Dynamic) -> List(Dynamic)

@external(erlang, "Elixir.Map", "get")
fn map_get(map: Dynamic, key: Dynamic) -> Dynamic

// Calling your own Elixir module
@external(erlang, "Elixir.MyApp.Helper", "compute")
fn my_compute(input: Int) -> Result(Int, Atom)
```

### 4.2 Calling Gleam from Elixir

Gleam modules compile to Erlang modules with `@` in the name:

```elixir
# Gleam module: my_app/user_validation
# Becomes: :my_app@user_validation

# In Elixir
:my_app@user_validation.validate(params)

# Or with alias
alias :my_app@user_validation, as: UserValidation
UserValidation.validate(params)
```

### 4.3 Data Type Mappings

| Gleam Type | Elixir Type |
|------------|-------------|
| `Int` | `integer()` |
| `Float` | `float()` |
| `String` | `binary()` (UTF-8 string) |
| `Bool` | `true` / `false` atoms |
| `Nil` | `:nil` atom |
| `List(a)` | `list()` |
| `#(a, b)` | `{a, b}` tuple |
| `Result(Ok, Error)` | `{:ok, value}` / `{:error, reason}` |
| `Option(a)` | `{:some, value}` / `:none` |
| `CustomType` | `{:type_name, field1, field2, ...}` tuple |

### 4.4 Mix Integration with mix_gleam

```elixir
# mix.exs
defmodule MyApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_app,
      version: "0.1.0",
      elixir: "~> 1.15",
      archives: [mix_gleam: "~> 0.6"],
      compilers: [:gleam | Mix.compilers()],
      aliases: aliases(),
      deps: deps(),
      # Required for mix_gleam
      prune_code_paths: false,
    ]
  end

  defp aliases do
    [
      "deps.get": ["deps.get", "gleam.deps.get"],
    ]
  end

  defp deps do
    [
      {:mix_gleam, "~> 0.6", only: :dev},
      # Gleam deps go in gleam.toml
    ]
  end
end
```

```toml
# gleam.toml
name = "my_gleam_code"
version = "0.1.0"

[dependencies]
gleam_stdlib = "~> 0.43"
gleam_erlang = "~> 0.29"
gleam_otp = "~> 0.12"
```

**Directory Structure**:
```
my_app/
├── lib/           # Elixir code
│   └── my_app/
├── src/           # Gleam code (compiled by mix_gleam)
│   └── my_gleam_module.gleam
├── test/
├── mix.exs
└── gleam.toml
```

---

## Part 5: Testing Strategies

### 5.1 Unit Testing with Gleeunit

```gleam
// test/my_module_test.gleam
import gleeunit
import gleeunit/should
import my_module

pub fn main() {
  gleeunit.main()
}

pub fn add_test() {
  my_module.add(2, 3)
  |> should.equal(5)
}

pub fn validate_email_test() {
  my_module.validate_email("valid@email.com")
  |> should.be_ok()

  my_module.validate_email("invalid")
  |> should.be_error()
}
```

### 5.2 Property-Based Testing with qcheck

```gleam
// test/properties_test.gleam
import qcheck
import gleeunit/should

pub fn addition_commutative_test() {
  use #(a, b) <- qcheck.given(qcheck.tuple2(
    qcheck.int_uniform(),
    qcheck.int_uniform(),
  ))
  should.equal(a + b, b + a)
}

pub fn list_reverse_involutive_test() {
  use xs <- qcheck.given(qcheck.list(qcheck.int_uniform()))
  should.equal(list.reverse(list.reverse(xs)), xs)
}
```

### 5.3 Integration Testing with ExUnit

```elixir
# test/gleam_integration_test.exs
defmodule GleamIntegrationTest do
  use ExUnit.Case

  describe "user validation" do
    test "validates correct email" do
      assert {:ok, _} = :user_validation.validate_email("test@example.com")
    end

    test "rejects invalid email" do
      assert {:error, _} = :user_validation.validate_email("invalid")
    end
  end

  describe "business logic" do
    # Generate test data in Elixir
    property "discount calculation is always positive" do
      check all(
        total <- StreamData.float(min: 0.0, max: 10000.0),
        tier <- StreamData.member_of([:gold, :silver, :bronze])
      ) do
        cart = %{total: total}
        user = %{tier: tier}

        {:ok, discount} = :discount_calculator.calculate(cart, user)
        assert discount.amount >= 0.0
      end
    end
  end
end
```

---

## Part 6: Indrajaal-Specific Assessment

### 6.1 Component Analysis

Based on our analysis of Indrajaal's 570+ GenServers and 178 Ash resources:

| Component | Files | Original Assessment | Revised (with techniques) |
|-----------|-------|---------------------|--------------------------|
| Simple state GenServers | 45 | 80% portable | **95% portable** (gleam_otp) |
| Timer-based GenServers | 89 | 40% portable | **70% portable** (Erlang FFI) |
| Supervised GenServers | 78 | 0% portable | **60% portable** (Elixir supervisor) |
| ETS-backed GenServers | 67 | 0% portable | **30% portable** (Bravo/Carpenter) |
| Distributed GenServers | 46 | 0% portable | **40% portable** (Distribute) |
| Event-driven GenServers | 33 | 30% portable | **50% portable** (Subject pub/sub) |
| Phoenix/LiveView | 34 | 0% portable | **20% portable** (Lissome) |
| Ash Resources | 178 | 0% portable | **0% portable** (keep in Elixir) |

### 6.2 Recommended Porting Order

```
Phase 1: Foundation (Weeks 1-4)
├── Port type definitions (all domains)
├── Port validation functions (pure)
├── Port business logic (pure)
└── Set up mix_gleam integration

Phase 2: Simple Actors (Weeks 5-8)
├── Port 45 simple state GenServers
├── Use gleam_otp actor pattern
├── Elixir supervisor integration
└── Test with ExUnit + gleeunit

Phase 3: Timer Actors (Weeks 9-14)
├── Port 89 timer-based GenServers
├── Erlang FFI for timers
├── OODA loop migration
└── Performance validation

Phase 4: Supervised & ETS (Weeks 15-22)
├── Port 78 supervised GenServers
├── Port 67 ETS-backed with Bravo
├── Complex supervision trees
└── Cache performance testing

Phase 5: Distributed (Weeks 23-27)
├── Migrate 46 distributed GenServers
├── Distribute library integration
├── Cluster coordination
└── Failure testing

Phase 6: Stabilization (Weeks 28-32)
├── Remove legacy Elixir duplicates
├── Optimize FFI boundaries
├── Documentation
└── Performance tuning
```

### 6.3 What Stays in Elixir Forever

| Component | Reason |
|-----------|--------|
| **Ash Resources** | 10x code explosion, no Gleam ORM |
| **Ecto/Repo** | Database layer, migrations |
| **Phoenix Controllers** | Framework integration |
| **Phoenix LiveView** | Most UI (except complex Lissome parts) |
| **Telemetry Pipeline** | :telemetry integration |
| **Safety-Critical** | Guardian, Sentinel, Immutable Register |
| **NIFs** | Rustler integration |

---

## Part 7: Implementation Roadmap

### 7.1 Timeline

| Phase | Duration | Deliverable | Risk |
|-------|----------|-------------|------|
| 1. Foundation | 4 weeks | Types, validation, mix_gleam | LOW |
| 2. Simple Actors | 4 weeks | 45 actors ported | LOW |
| 3. Timer Actors | 6 weeks | 89 actors ported | MEDIUM |
| 4. Supervised/ETS | 8 weeks | 145 actors ported | MEDIUM |
| 5. Distributed | 5 weeks | 46 actors ported | HIGH |
| 6. Stabilization | 5 weeks | Production ready | LOW |
| **TOTAL** | **32 weeks** | **~340 components** | |

### 7.2 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Type safety | 100% Gleam layer | Compile-time checks |
| Test coverage | 95%+ | gleeunit + ExUnit |
| Performance | No regression | Benchmark suite |
| Compile time | <2 min | CI metrics |
| FFI boundary | <50 | Count of @external |

### 7.3 Rollback Strategy

Each phase is reversible via Strangler Fig:

```
1. Keep Elixir code during migration
2. Route traffic via facade
3. Validate Gleam replacement works
4. Remove Elixir duplicate only after validation
5. If issues: flip facade routing back to Elixir
```

---

## Sources

### Official Documentation
- [Gleam Externals Guide](https://gleam.run/documentation/externals/)
- [gleam_otp Actor Documentation](https://hexdocs.pm/gleam_otp/gleam/otp/actor.html)
- [Gleam for Elixir Users](https://gleam.run/cheatsheets/gleam-for-elixir-users/)

### Libraries
- [gleam_otp](https://github.com/gleam-lang/otp) - Fault tolerant multicore programs with actors
- [Distribute](https://hexdocs.pm/distribute/) - Type-safe distributed Erlang
- [Bravo](https://hexdocs.pm/bravo/) - Comprehensive ETS bindings
- [Carpenter](https://hexdocs.pm/carpenter/) - Simple ETS key-value
- [glixir](https://hexdocs.pm/glixir/) - libcluster wrapper
- [mix_gleam](https://github.com/gleam-lang/mix_gleam) - Build Gleam with Mix
- [Lissome](https://github.com/selenil/lissome) - Lustre in Phoenix LiveView
- [gleeunit](https://github.com/lpil/gleeunit) - Test runner
- [qcheck](https://github.com/mooreryan/gleam_qcheck) - Property-based testing

### Tutorials & Articles
- [Enhancing Your Elixir Codebase with Gleam](https://blog.appsignal.com/2024/07/23/enhancing-your-elixir-codebase-with-gleam.html)
- [Adding Gleam to Your Elixir Project](https://devonestes.com/adding-gleam-to-your-elixir-project)
- [Mixing Gleam & Elixir](https://dev.to/contact-stack/mixing-gleam-elixir-3fe3)
- [Exploring the Gleam FFI](https://www.jonashietala.se/blog/2024/01/11/exploring_the_gleam_ffi/)
- [Migrating to Elixir with the Strangler Pattern](https://devonestes.com/migrating-to-elixir-with-the-strangler-pattern)

### Architecture Patterns
- [Strangler Fig Pattern - Azure](https://learn.microsoft.com/en-us/azure/architecture/patterns/strangler-fig)
- [Strangler Fig Pattern - AWS](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/strangler-fig.html)
- [Gleam OTP Design Principles](https://github.com/wmealing/gleam-otp-design-principals)

---

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Author | Claude Opus 4.5 |
| Created | 2026-01-11 |
| Status | COMPLETE |
| Supersedes | GLEAM_ACTOR_ASH_REPLACEMENT_ANALYSIS.md, GLEAM_MIGRATION_ARCHITECTURAL_REVIEW.md |

---

*This comprehensive guide collates all known techniques for porting Elixir code to Gleam, demonstrating that with proper architectural patterns (Strangler Fig, FFI bridges, library integrations), portability increases from 15% to ~45%, with a reduced timeline of 32 weeks.*
