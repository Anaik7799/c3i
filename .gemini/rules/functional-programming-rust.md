# Functional Programming Rust Mandate (fp-core + SC-FP-RUST-001..020 + AOR-FP-RUST-001..015)

## Mandate

**All Rust code generated for or modified within C3I MUST use `fp-core = "0.1.9"` as the primary functional abstraction baseline where applicable, follow the supporting FP stack when locally useful, and meet the FP-1..FP-12 mathematical KPIs.** This is the Rust analogue to SC-WIRE (Gleam type-system discipline), SC-VALUE-GUARD (value-domain refinement), and SC-VAULT (sealed-state discipline) — closing the FP-discipline gap on the Rust surface.

ZK lineage: [zk-3346fc607a1ef9e6] Stub-That-Lies (do not claim FP adoption without code evidence) · [zk-bb4de67d97f807ac] selector-guessing → "consult the running system, not a static list" — fp-core + nutype are the type-system answer · [zk-c14e1d23afff486c] implicit-invariant family.

Source-of-truth pack: `docs/journal/task-116499874901057156/` (journal + session-history + analysis HTML + slide deck + 9 diagrams + user guide + way-of-working).

## Scope (4 Rust surfaces)

| Surface | Path | Stack policy |
|---|---|---|
| **planning_daemon** (cortex) | `sub-projects/c3i/native/planning_daemon/` | full stack except rayon-in-tokio paths |
| **c3i_nif** | `lib/cepaf_gleam/native/c3i_nif/` | derive_more + nutype + itertools + either; sync; no rayon, no tower |
| **rusty_vault_nif** | `lib/cepaf_gleam/native/rusty_vault_nif/` | derive_more + nutype + proptest + kani-verifier ONLY |
| **scripts_nif** | `sub-projects/scripts-gleam/native/scripts_nif/` | itertools + either + derive_more |

## Required fp-core Baseline + Supporting 12-library Stack

All touched Rust crates that modify functional logic must add the baseline dependency when dependency changes are allowed:

```toml
[dependencies]
fp-core = "0.1.9"
```

Use `fp_core::{functor, apply, applicative, chain, monad, foldable, semigroup, monoid, setoid, lens, hkt, compose}` traits/modules where they fit the domain. The supporting stack remains available for refinements, services, parsing, persistence, property tests, and proofs.

| Library | Latest | Role | Vault? |
|---|---|---|---|
| `frunk` | 0.4.4 | HList / Coproduct / Validated / Semigroup / Monoid | NO |
| `rpds` + `archery` | 1.2.0 / 1.2.2 | Persistent collections + atomicity strategy | OPTIONAL |
| `winnow` | 1.0.2 | Combinator parsers (1.0 stable) | NO |
| `tower` | 0.5.3 | Service trait = Kleisli arrow | NO |
| `derive_more` | 2.1.1 | Newtype boilerplate (From / Display / Add / Deref / Constructor) | YES |
| `nutype` | 0.7.0 | Refinement types ("parse don't validate") | YES — priority |
| `recursion` | 0.5.4 | Stack-safe catamorphisms | NO |
| `proptest` | 1.11.0 | Property testing with shrinking | YES — priority |
| `kani-verifier` | 0.67.0 | Bounded model checking (CBMC) | YES — priority |
| `itertools` | 0.14.0 | Lazy iterator combinators | YES |
| `rayon` | 1.12.0 | Data-parallel pipelines (offline only) | NO |
| `either` | 1.15.0 | `Either<L,R>` ADT | OPTIONAL |

**Required dependency baseline**: `fp-core = "0.1.9"` for generated/modified functional Rust where applicable. **Confirmed gaps with no replacement**: algebraic effects, STM, and free monads — do NOT author replacements; lean on existing C3I constraint families instead.

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-FP-RUST-001 | All new Rust functions in `planning_daemon/` MUST be marked pure (no `&mut self`, no `unsafe`, no I/O, no static-mut) UNLESS justified in a `// IMPURE: <reason>` comment | HIGH |
| SC-FP-RUST-002 | Touched Rust crates with functional logic MUST include `fp-core = "0.1.9"` and import `fp_core` traits/modules where applicable; value-domain enums continue to use `nutype` refinement instead of `&'static [&str]` whitelists | CRITICAL |
| SC-FP-RUST-003 | Domain primitives (`String`, `i64`, `u64`) carrying semantic meaning (TaskUrn, ChatId, RegionId, SecretName, Ttl) MUST be `derive_more` + `nutype` newtypes | CRITICAL |
| SC-FP-RUST-004 | Multi-error validation paths MUST use `frunk::Validated`, not first-error `Result` | HIGH |
| SC-FP-RUST-005 | Long-lived shared state in cortex MUST use `rpds` persistent collections + `arc-swap` for read-mostly | HIGH |
| SC-FP-RUST-006 | Service-shaped operations (request → future → response) MUST use `tower::Service` + `Layer` | HIGH |
| SC-FP-RUST-007 | Custom recursion over tree-shaped data MUST use `recursion::Collapsible` (stack-safe) | HIGH |
| SC-FP-RUST-008 | Pub fns in safety-critical modules (`pii`, `db` validators, `rule_engine`, `trace`, `gateway`) MUST have `proptest!` properties | CRITICAL |
| SC-FP-RUST-009 | SIL-4 fail-safe paths (`errors`, `apoptosis`, `ha_election`, vault sealed-on-boot) MUST have `#[kani::proof]` harnesses | CRITICAL |
| SC-FP-RUST-010 | `rayon` MUST NEVER appear inside any tokio-async path; MUST NEVER appear in any NIF (steals BEAM threads). Quarantined to offline batch tooling. | CRITICAL |
| SC-FP-RUST-011 | `tower::Service` and `frunk` types MUST NOT appear in `rusty_vault_nif/` (vault attack-surface budget) | CRITICAL |
| SC-FP-RUST-012 | Heterogeneous return paths (cache hit vs miss, simple vs complex, channel route) MUST use `either::Either`, not hand-rolled enum | MEDIUM |
| SC-FP-RUST-013 | Result-returning fns MUST use `?` chains (mean depth ≥ 2.0), not nested `match`/`if let` | HIGH |
| SC-FP-RUST-014 | Cyclomatic complexity in pure-marked fns MUST be ≤ 10 (McCabe) | HIGH |
| SC-FP-RUST-015 | Mutation density per surface MUST be ≤ 30 `&mut` per 1k LOC | HIGH |
| SC-FP-RUST-016 | Criterion benches MUST run on every PR touching hot-path; FP-9 alloc Δ > +20% blocks merge | CRITICAL |
| SC-FP-RUST-017 | After every FP-stack adoption, `cargo tree \| grep -iE 'tongsuo\|sm[234]'` MUST remain empty in `rusty_vault_nif/` | CRITICAL |
| SC-FP-RUST-018 | `wiring_guard.gleam` MUST be updated in same commit as any newtype that crosses the BEAM boundary (sister rule to SC-WIRE-002) | CRITICAL |
| SC-FP-RUST-019 | FP-1..FP-12 atomic + 4 composite KPIs MUST be measured via `gleam run -m scripts/verify/fp_purity` and published on `indrajaal/l5/cog/fp/{kpi}/**` | HIGH |
| SC-FP-RUST-020 | FP_TOTAL drift λ < 0 over 3-pass window triggers P1 RCA task; FP_VAULT < 0.85 triggers P0 + halts vault feature merges | CRITICAL |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-FP-RUST-001 | ALWAYS allow `fp-core = "0.1.9"` for touched functional Rust; NEVER add `lens-rs`, `pl-lens`, `effing-mad`, `eff`, `stm`, `tramp`, `momo`, `hkt`, `fp-rs`, `nougat`, `shrinkwraprs`, or `lazy_static` (legacy) as new dependencies |
| AOR-FP-RUST-002 | NEVER use `Box<dyn Trait>` where `enum_dispatch` would do |
| AOR-FP-RUST-003 | NEVER write a recursive function over a tree-shaped data structure without `recursion::Collapsible` |
| AOR-FP-RUST-004 | NEVER author a generic optics/effects/STM/free-monad library inside C3I |
| AOR-FP-RUST-005 | NEVER store a refined value (nutype) by bypassing the validator |
| AOR-FP-RUST-006 | ALWAYS adopt `nutype` for vault types BEFORE adopting any other FP library on `rusty_vault_nif` |
| AOR-FP-RUST-007 | ALWAYS run criterion bench before adopting `rpds` on a hot-path module |
| AOR-FP-RUST-008 | ALWAYS test refinement validators with `proptest` (both valid AND invalid inputs — predicate asserted both ways per [zk-139840e16ed2b21e]) |
| AOR-FP-RUST-009 | ALWAYS update `pi_claude_code.gleam` MCP tool federation count if FP-* MCP tools are added (sister to SC-PI-AUTO-002) |
| AOR-FP-RUST-010 | ALWAYS run `cargo tree \| grep -iE 'tongsuo\|sm[234]'` after every dep change in vault-adjacent crates |
| AOR-FP-RUST-011 | ALWAYS write the `// IMPURE:` justification comment when a function legitimately needs `&mut self`, `unsafe`, or I/O |
| AOR-FP-RUST-012 | ALWAYS use `tower::ServiceBuilder` for outbound calls that need timeout + retry + circuit-breaker (uniform Layer stack, not hand-coded) |
| AOR-FP-RUST-013 | ALWAYS use `frunk::Validated` when reporting multiple ingest errors per row to the operator |
| AOR-FP-RUST-014 | ALWAYS pin `kani-verifier` version in `Cargo.toml` (not range) — proof staleness via toolchain skew is a known FMEA row (RPN 192) |
| AOR-FP-RUST-015 | ALWAYS write the journal closure pack (per SC-FEAT-EVO + SC-FRAC-RRF) on each pass adoption |

## RETE-UL Rules — Domain 14 `fp_discipline` (6 rules)

These rules join the existing 52 GRL rules in `lib/cepaf_gleam/src/cepaf_gleam/rules/engine.gleam` (and the Rust mirror in `rule_engine.rs`) → **58 rules across 14 domains**.

| Rule | Salience | When | Then |
|---|---:|---|---|
| `FpPurityBelowFloor` | 100 | `FP_TOTAL < 0.70` | hard block release; emit `[SC-FP-RUST-020 VIOLATION]`; P0 task |
| `FpVaultBelowFloor` | 100 | `FP_VAULT < 0.85` | P0 task; halt vault feature merges; page operator |
| `FpDriftNegative` | 95 | `λ(FP_TOTAL, 3 passes) < 0` | P1 RCA task; pause new FP-stack adoptions until investigated |
| `FpHotpathRegression` | 95 | criterion bench `alloc Δ > +20%` | block PR; require revert OR proven justification |
| `FpKaniCounterexample` | 100 | `cargo kani` returns non-empty counter-example on harness | P0; halt merge of harness's module; open RCA |
| `FpNutypeRejectStorm` | 80 | refinement-rejection rate > 100/min on a live ingest path | P2 advisory; operator likely has malformed input source |

## Mathematical KPI Framework

### 12 atomic KPIs (FP-1..FP-12)

| ID | KPI | Definition | Threshold |
|---|---|---|---|
| FP-1 | Pure-fn ratio | `|fns: no &mut self ∧ no unsafe ∧ no I/O ∧ no static-mut| / |total fns|` | ≥ 0.70 daemon, ≥ 0.85 vault, ≥ 0.50 NIFs |
| FP-2 | Mutation density | `&mut` per 1k LOC (excluding tests) | ≤ 30 |
| FP-3 | `?` chain depth | mean `?` count per `Result`-returning fn | ≥ 2.0 |
| FP-4 | Newtype coverage | `|nutype-wrapped fields| / |total primitive fields in domain types|` | ≥ 0.80 vault, ≥ 0.60 daemon |
| FP-5 | Persistent ratio | `|rpds:: in long-lived state| / |Vec/HashMap in same|` | ≥ 0.50 cortex |
| FP-6 | Catamorphism coverage | `|fns using recursion::Collapsible| / |fns with explicit recursion|` | ≥ 0.50 |
| FP-7 | Property-test coverage | `|proptest! macros| / |pub fn count|` | ≥ 0.30 safety-critical |
| FP-8 | Kleisli stack depth | mean `tower::Layer` count per outbound Service | tracked, not gated |
| FP-9 | Allocation per pure call | criterion + dhat regression | +20% blocks PR |
| FP-10 | Cyclomatic complexity in pure-marked fns | McCabe via `rust-code-analysis` | ≤ 10 |
| FP-11 | Shannon entropy of FP-stack usage | `H = -Σ p_i log₂ p_i` over 12 lib import-frequencies × 4 surfaces | ≥ 2.5 bits |
| FP-12 | Kani proof coverage | `|fns with #[kani::proof]| / |fns marked SIL-4 fail-safe|` | ≥ 0.80 vault |

### 4 composite KPIs (CPIG-style)

```
FP_TOTAL    = mean(FP-1..FP-7, FP-10, FP-12) across surfaces       Target ≥ 0.80
FP_VAULT    = 0.30·FP-4 + 0.20·FP-7 + 0.30·FP-12 + 0.20·FP-1       Target ≥ 0.90
FP_HOTPATH  = (inv FP-2 + FP-9 trend + FP-3) over hot modules       Target ≥ 0.75
FP_DRIFT    = (FP_TOTAL[t] − FP_TOTAL[t−3]) / 3                     λ ≥ 0  (Lyapunov, mirrors SC-CPIG-008)

FP_FRACTAL  = (Π L_i)^(1/8)   geometric mean over 8 fractal layer scores
              Target ≥ 0.83 at Pass-5 close
```

### Per-fractal-layer composite weights

```
L0 = 0.30·FP-12 + 0.25·FP-7  + 0.25·FP-1  + 0.20·FP-4
L1 = 0.30·FP-4  + 0.30·FP-7  + 0.20·FP-1  + 0.20·FP-2
L2 = 0.30·FP-7  + 0.25·FP-1  + 0.25·FP-10 + 0.20·FP-4
L3 = 0.30·FP-4  + 0.25·FP-7  + 0.25·FP-3  + 0.20·FP-1
L4 = 0.30·FP-1  + 0.25·FP-2  + 0.25·FP-7  + 0.20·FP-3
L5 = 0.30·FP-1  + 0.25·FP-3  + 0.25·FP-6  + 0.20·FP-7
L6 = 0.30·FP-5  + 0.25·FP-3  + 0.25·FP-1  + 0.20·FP-7
L7 = 0.30·FP-7  + 0.25·FP-12 + 0.25·FP-1  + 0.20·FP-4
```

Geometric mean (not arithmetic) intentional: a single layer collapsing to 0.50 drops the system score visibly, preventing one healthy layer from masking another's regression.

## 5-Pass Adoption Sequence

| Pass | Action | ΔFP_TOTAL | ΔFP_VAULT | ΔFP_HOTPATH | Risk |
|---|---|---|---|---|---|
| 1 | `derive_more` + `itertools` + `either` (planning_daemon) | +0.10 | +0.05 | +0.05 | LOW |
| 2 | `nutype` (vault first) + `frunk` + `bon` + `parking_lot` | +0.20 | +0.30 | +0.10 | MEDIUM |
| 3 | `rpds` + `archery` + `arc-swap` + `bytes` formalize | +0.15 | +0.05 | +0.20 | HIGH |
| 4 | `tower` deepen + `winnow` + `recursion` + `rayon` (offline) + `snafu` | +0.15 | +0.05 | +0.10 | MEDIUM |
| 5 | `kani-verifier` + `proptest` deepen | +0.10 | +0.15 | +0.05 | proof-debt |
| **Closing** | **end-of-Pass-5** | **≈0.85** | **≈0.92** | **≈0.78** | all gates met |

### Per-pass go/no-go gates

| Pass | Gate |
|---|---|
| 1 | All 4 surfaces compile. wiring_guard updated. FP_TOTAL ≥ 0.55. Email closure. ZK ingest. |
| 2 | Vault `nutype` complete. SC-VALUE-GUARD lifted to type level. CI tongsuo grep empty. FP_VAULT ≥ 0.75. |
| 3 | Cortex `rpds` migration. criterion ≤ +2% inference latency on hedged path (else revert). FP_HOTPATH ≥ 0.70. |
| 4 | tower Layer stack on `mcp_inference.rs`. winnow on markdown roundtrip. FP-3 ≥ 2.0. FP-6 ≥ 0.50. |
| 5 | kani harness on vault sealed-on-boot, ha_election. First run surfaces ≥ 1 real bug. FP_VAULT ≥ 0.90. FP_TOTAL ≥ 0.83. |

## Anti-pattern catalog

1. **Checkbox fp-core** — adding `fp-core` but not using `fp_core` traits/modules or functional Rust structure. The discipline is `fp-core` usage plus the supporting stack, KPIs, and RETE rules.
2. **Stub-That-Lies** — claiming FP adoption without runtime verification (proptest + criterion). Every adoption MUST have a property test or bench backing it.
3. **rayon-in-tokio** — embarrassingly parallel offline work mixed with async I/O. Steals threads. RPN 210. Quarantined.
4. **Hand-rolled retry/timeout** — every outbound call should use `tower::Layer<Retry>` / `tower::Layer<Timeout>`, not ad-hoc loops.
5. **String for value-domain enums** — use `nutype`. SC-VALUE-GUARD-001..008 already mandates this; SC-FP-RUST-002 makes it type-system-enforced.
6. **`Box<dyn Trait>` for closed sums** — use `enum_dispatch` or `frunk::Coproduct`.
7. **Direct `Cargo.toml` add without journal** — every adoption is a feature evolution; SC-FEAT-EVO + SC-FRAC-RRF + SC-CPIG closure pack is mandatory per pass.

## Operator surfaces

- **Verifier**: `cd sub-projects/scripts-gleam && gleam run -m scripts/verify/fp_purity` — measures FP-1..FP-12, prints summary, publishes Zenoh topics.
- **Bench**: `cd sub-projects/c3i/native/planning_daemon && cargo bench --bench fp_kpi` — captures FP-9 alloc-per-pure-call baseline.
- **Dashboard**: `https://vm-1.tail55d152.ts.net:4100/fp-kpi` (Lustre + Wisp + TUI per SC-GLM-UI-001) — Pass-3 deliverable.
- **MCP tool**: `fp_score(scope: planning_daemon|c3i_nif|rusty_vault_nif|scripts_nif|composite)` — federation count rises 93→97 (SC-PI-AUTO-003).
- **Zenoh topics**: `indrajaal/l5/cog/fp/{kpi}/**` per atomic KPI.

## CPIG integration

New CPIG subsystem **#13 fp_discipline** with G1..G5 gates:

| Gate | Verifier | Status |
|---|---|---|
| G1 Formal Spec | `specs/allium/fp_rust.allium` (Pass-2) + `specs/tla/FpRustDiscipline.tla` (Pass-2) | 0/1 |
| G2 Wiring Guard | sister-rule SC-WIRE-002 (newtypes crossing BEAM boundary) | 0/1 (Pass-1) |
| G3 sa-plan tracking | tasks tagged `urn:c3i:task:fp-rust:*` | 1/1 (today) |
| G4 ZK ingestion | journal + spec + diagrams ingested with `subsystem:fp-rust` tag | 1/1 (today) |
| G5 Email Closure | `sa-plan-daemon send-email -a` with FP closure pack | 1/1 (today) |

System-wide CPIG total: 13 subsystems × 5 gates = **65** (was 60). Pass-15 target: 65/65.

## Cross-references

- `.claude/rules/wiring-guard.md` (SC-WIRE-001..007) — type-domain sibling
- `.claude/rules/value-guard.md` (SC-VALUE-GUARD-001..008) — value-domain sibling
- `.claude/rules/secrets-vault.md` (SC-VAULT-001..025) — sealed-state sibling
- `.claude/rules/cross-pass-invariant-gate.md` (SC-CPIG-001..015) — composite-gate sibling
- `.claude/rules/mistral-rust-api-mandate.md` (SC-INFER-RUST-API-001..008) — reinforced by tower adoption
- `.claude/rules/planning-daemon-rust-only-tests.md` (SC-PD-RUST-ONLY-001..010) — proptest + kani further enforce
- `.claude/rules/zenoh-telemetry-mandatory.md` (SC-GLM-ZEN-001..003) — `indrajaal/l5/cog/fp/**` extends the ZMOF
- `docs/journal/task-116499874901057156/` — full source-of-truth pack (journal, session-history, analysis HTML, slide deck, 9 diagrams)

## Governance parity

Mirror at `.gemini/rules/functional-programming-rust.md` per SC-SYNC-DOC-007.
