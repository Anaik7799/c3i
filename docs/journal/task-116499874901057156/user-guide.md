# FP-Rust Stack — User Guide

Tailscale: https://vm-1.tail55d152.ts.net:4200/task-id/116499874901057156/user-guide.md

> Practical "how do I use this" guide for the 12-library FP-Rust stack adopted in place of the dead `fp-core.rs`. Targets Claude / Pi / Gemini agents authoring Rust under `sub-projects/c3i/native/`.

---

## When to use which library — decision tree

| If you need to... | Use |
|---|---|
| Validate a value at a boundary (smart constructor, refinement) | `nutype` |
| Newtype wrapper with `Display` / `From` / `Add` / `AsRef` derived | `derive_more` |
| Accumulate ALL errors not just the first | `frunk::Validated` |
| Parallel iteration over independent items, **offline only** | `rayon` |
| Lazy iterator combinators (`cartesian_product`, `group_by`, `dedup`) | `itertools` |
| Persistent collection for snapshot-friendly state | `rpds` (+ `archery` for Arc/Rc abstraction) |
| Op shaped as `req → fut → resp` with retry / circuit-break / timeout | `tower::Service` + `Layer` |
| Parse a custom format (markdown, todolist, log line) | `winnow` |
| Deeply nested recursion that may blow the stack | `recursion::Collapsible` |
| Forall-quantified tests with shrinking | `proptest` |
| Formal proof / bounded model-check on a fail-safe path | `kani-verifier` |
| Two heterogeneous return paths in one signature | `either::Either` |

---

## Quick examples

### 1. `nutype` — refined `Priority`

```rust
use nutype::nutype;

#[nutype(
    sanitize(trim),
    validate(predicate = |s: &str| matches!(s, "P0" | "P1" | "P2" | "P3")),
    derive(Debug, Clone, PartialEq, Eq, Hash, AsRef, Display, Serialize, Deserialize)
)]
pub struct Priority(String);

let p = Priority::try_new("P0").unwrap();        // OK
let bad = Priority::try_new("--priority");        // Err — caught at the boundary
```

Replaces the `&'static [&str]` whitelist + manual `validate_priority(&str) -> Result<&'static str>` pair. The validator runs in the smart constructor; raw construction is impossible. Closes the SC-VALUE-GUARD pass-7 incident class at the type level.

### 2. `derive_more` — `TaskUrn` newtype

```rust
use derive_more::{AsRef, Display, From, Into};

#[derive(Debug, Clone, PartialEq, Eq, Hash, AsRef, Display, From, Into)]
#[display(fmt = "{_0}")]
pub struct TaskUrn(String);

let urn: TaskUrn = "urn:c3i:task:misc:1164".to_string().into();
println!("{urn}");                                 // "urn:c3i:task:misc:1164"
let s: &str = urn.as_ref();
```

Replaces 12 lines of `impl Display`, `impl From<String>`, `impl AsRef<str>` boilerplate with one derive list. FP-3 counts each such crate-derived trait toward the newtype-density KPI.

### 3. `frunk::Validated` — collect all SC-VALUE-GUARD violations

```rust
use frunk::validated::Validated;

fn validate_task(t: &RawTask) -> Validated<ValidatedTask, IngestError> {
    let prio = Priority::try_new(&t.priority).map_err(IngestError::Priority);
    let stat = Status::try_new(&t.status).map_err(IngestError::Status);
    let urn  = TaskUrn::try_new(&t.urn).map_err(IngestError::Urn);

    (prio, stat, urn).into_validated()
        .map(|(p, s, u)| ValidatedTask { priority: p, status: s, urn: u })
}
```

Where idiomatic `Result + ?` short-circuits at the first error (operator only sees one of three problems), `Validated` accumulates ALL three. Used in pass-7 ingest path; cuts operator round-trips by ~3x.

### 4. `itertools` — generate 400 simulator scenarios

```rust
use itertools::Itertools;

let categories = (0..20);
let variants   = (0..10);
let channels   = ["telegram", "gchat"];

let scenarios: Vec<Scenario> = categories
    .cartesian_product(variants)
    .cartesian_product(channels)
    .map(|((c, v), ch)| Scenario::new(c, v, ch))
    .collect();
assert_eq!(scenarios.len(), 400);
```

Replaces a triple-nested `for` loop with a single iterator expression. Lazy by default — fine to chain `.take(N)` for partial runs. Replaces the hand-rolled scenario builder in `simulator.rs`.

### 5. `either::Either` — cache hit vs fresh inference

```rust
use either::Either;

async fn answer(q: &Query) -> Either<CachedReply, FreshReply> {
    if let Some(c) = semantic_cache::get(q).await {
        Either::Left(c)
    } else {
        Either::Right(infer_fresh(q).await)
    }
}

// Both arms iterate uniformly — Either implements Iterator when both sides do
```

Replaces `enum Reply { Cached(_), Fresh(_) }` with a generic `Either`. Caller can branch with `.either(left_fn, right_fn)` or treat both arms uniformly. FP-12 counts each such return.

### 6. `rpds` — `ConversationHistory` as persistent map

```rust
use rpds::HashTrieMapSync;

#[derive(Clone)]
pub struct ConversationHistory {
    by_chat: HashTrieMapSync<ChatId, Vec<Message>>,
}

impl ConversationHistory {
    pub fn append(&self, chat: ChatId, msg: Message) -> Self {
        let mut v = self.by_chat.get(&chat).cloned().unwrap_or_default();
        v.push(msg);
        Self { by_chat: self.by_chat.insert(chat, v) }
    }
}
```

Each `append` returns a NEW history (structural sharing keeps it O(log n)). Cheap snapshots for the OODA Orient phase — no `Mutex<HashMap>` needed. Replaces `Arc<RwLock<HashMap<_, _>>>` with cleaner equational reasoning.

### 7. `tower` — Layer stack for Gemini Direct tier

```rust
use tower::{ServiceBuilder, ServiceExt};
use std::time::Duration;

let svc = ServiceBuilder::new()
    .rate_limit(60, Duration::from_secs(60))     // 60/min
    .timeout(Duration::from_millis(900))
    .layer(CircuitBreakerLayer::new(3, Duration::from_secs(60)))
    .layer(RetryLayer::new(ExpBackoff::new(2)))
    .service(GeminiDirect::new(api_key));

let reply = svc.oneshot(request).await?;
```

Replaces five hand-rolled wrappers with one declarative stack. Layer order matters: timeout OUTSIDE retry (each retry has its own deadline), circuit-breaker OUTSIDE timeout (open circuit short-circuits before clock starts). Canonicalised in `cortex.rs`.

### 8. `winnow` — parse markdown task line

```rust
use winnow::prelude::*;
use winnow::ascii::{alphanumeric1, space1};
use winnow::combinator::{preceded, separated_pair};

fn task_line<'i>(input: &mut &'i str) -> PResult<(TaskUrn, Priority, &'i str)> {
    let _ = "- [".parse_next(input)?;
    let _ = take_until(0.., "] ").parse_next(input)?;
    let urn = preceded("urn:c3i:task:", alphanumeric1).parse_next(input)?;
    let _ = space1.parse_next(input)?;
    let prio = alt(("P0", "P1", "P2", "P3")).parse_next(input)?;
    let _ = space1.parse_next(input)?;
    let title = winnow::ascii::till_line_ending.parse_next(input)?;
    Ok((TaskUrn::try_new(urn)?, Priority::try_new(prio)?, title))
}
```

Replaces hand-rolled regex + `split` chain that broke on every edge case. Composable, gives precise error positions, round-trips cleanly with proptest.

### 9. `recursion` — fold a ruliology causal graph

```rust
use recursion::{Collapsible, MappableFrame};

enum CausalNode {
    Leaf(NodeId),
    Branch(NodeId, Vec<Box<CausalNode>>),
}

let depth: usize = root.collapse_frames(|frame| match frame {
    CausalNodeFrame::Leaf(_) => 1,
    CausalNodeFrame::Branch(_, children) => 1 + children.into_iter().max().unwrap_or(0),
});
```

`collapse_frames` runs the recursion on the heap, not the call stack. Causal graphs in `ruliology.rs` reach 10k+ nodes in chaos scenarios; native recursion blew the 8 MB stack. FP-8 counts each such conversion.

### 10. `proptest` — `pii::scrub` idempotence

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn scrub_is_idempotent(s in ".*") {
        let once  = pii::scrub(&s);
        let twice = pii::scrub(&once);
        prop_assert_eq!(once, twice);
    }

    #[test]
    fn scrub_never_grows(s in ".*") {
        prop_assert!(pii::scrub(&s).len() <= s.len());
    }
}
```

Two properties capture what 50 hand-written test cases couldn't. Shrinking finds the smallest failing input automatically. FP-10 weighs proptest density on safety-critical modules.

---

## Forbidden patterns (anti-patterns)

| Forbidden | Why | Use instead |
|---|---|---|
| `rayon` inside a `tokio` async path | Steals async runtime threads → BEAM stalls | tokio task pool |
| `rayon` inside any NIF | Steals BEAM scheduler threads → mesh apoptosis | sync `iter` |
| New `tower::Service` inside vault NIF | Crate budget violation (SC-FP-RUST-014) | direct fn call |
| `mut` long-lived state where `rpds` snapshot fits | Loses snapshot-ability | `rpds::HashTrieMapSync` |
| `String` for value-domain enum | SC-VALUE-GUARD-001 violation | `nutype` |
| `Box<dyn Trait>` where finite enum suffices | Heap + dyn-dispatch + Send/Sync fights | `enum` + match |
| `panic!` in pure-marked function | Breaks FP-1 invariant | `Result` |
| Direct field construction of refined newtype | Bypasses validator | smart constructor `try_new` |

---

## Daily checklist (every new Rust function)

Run before marking ANY Rust function complete:

1. Function pure (no `&mut`, no I/O, no time, no random)? If yes, mark — adds to FP-1.
2. New `String` / `u32` / `i64` in domain? Wrap in `derive_more` newtype.
3. Value-domain enum? Use `nutype`, not `&'static [&str]`.
4. Returns `Result`? Chain `?` rather than `match`.
5. Multi-error accumulation? Use `frunk::Validated`.
6. Long-lived state? Use `rpds`, not `Vec` / `HashMap` behind a lock.
7. Service-shaped (`req → fut → resp`)? Use `tower`.
8. Custom recursion deeper than 100 frames? Use `recursion` crate.
9. New `pub fn` in safety-critical module? Add at least one `proptest` property.
10. SIL-4 fail-safe path? Add a `kani` harness alongside.

If any item answers "no" with no justification, the function is incomplete by SC-FP-RUST-001.
