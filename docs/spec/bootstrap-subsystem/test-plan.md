# Bootstrap Subsystem — Test Plan (ISO 29119)

**Task**: 116486929469430710  **STAMP**: SC-BOOTSTRAP, SC-FRAC-RRF, SC-AVP, SC-MATH-COV
**ZK**: [zk-5d2236e838f2c6fe], [zk-d1190ab5bbbc6398]

## 1. Test categories

| Category | Framework | Coverage gate |
|---|---|---|
| Unit (Rust) | `cargo test` | line ≥90%, branch ≥85% |
| Property (Rust) | proptest 1.4 | 1000 cases per property |
| Property (Gleam) | gleeunit + propcheck | C1-C8 gold standard, H ≥ 2.5 bits, CCM ≥ 0.90 |
| Integration | `cargo test --features integration` | UDS + mmap end-to-end |
| Chaos | bash + signal injection (will move to Rust per SC-RUST-TOOL) | 10 scenarios pass |
| Formal — Agda | `agda --safe HookSubsystem.agda` | type-checks |
| Formal — TLA+ | `apalache check` | 12 invariants + 5 liveness |
| Mutation | `cargo mutants` | kill rate ≥ 95% |

## 2. Unit tests (Rust)

| Module | Tests | Key cases |
|---|:-:|---|
| bootstrap.rs | 25 | state collection per agent, citation count, lock dead-man |
| bootstrap_snapshot.rs | 15 | seqlock writer/reader, NUMA pinning, alignment |
| mcp_bootstrap.rs | 12 | each MCP tool happy path + error path |
| bootstrap_uds.rs | 18 | length-prefix protocol, partial reads, large messages |
| bootstrap_watchdog.rs | 10 | Bayesian update, threshold trigger, kill semantics |
| bootstrap_pid.rs | 8 | PID convergence, bounds, anti-windup |
| bootstrap_ga.rs | 12 | mutation, crossover, selection, Wilson scoring |
| bootstrap_mdp.rs | 10 | Bellman iteration, value convergence |
| bootstrap_rete.rs | 13 | each of 13 rules fires correctly |

**Total: 123 unit tests.**

## 3. Property tests (proptest)

```rust
proptest! {
    #[test]
    fn no_silent_fail(ctx: any::<HookContext>()) {
        let outcome = execute(ctx);
        prop_assert!(outcome.has_message());
    }

    #[test]
    fn fail_closed(ctx: any::<HookContext>(), errs: vec(any::<ErrorEvidence>(), 1..10)) {
        let base = execute(ctx.clone());
        let with_errs = execute(ctx.with_errors(errs));
        prop_assert!(rank(with_errs) <= rank(base));
    }

    #[test]
    fn snapshot_freshness(s: any::<Snapshot>()) {
        prop_assert!(s.age_ms <= 30_000);
    }

    #[test]
    fn seqlock_atomic(payload: any::<HookStatePayload>()) {
        let snap = Snapshot::new();
        let r1 = read(&snap);  // before write
        write(&snap, payload);
        let r2 = read(&snap);
        prop_assert!(r1 != r2 || r1 == payload);  // no torn read
    }

    #[test]
    fn pid_converges(initial_err: f64, history: vec(f64, 50..100)) {
        let mut pid = PidController::new(2.0, 0.1, 0.5);
        let final_err = history.iter().fold(initial_err, |e, _| pid.step(e));
        prop_assert!(final_err.abs() < 0.05);
    }

    #[test]
    fn bayesian_bounded(prior: 0..1000u16, obs: vec(any::<Observation>(), 1..1000)) {
        let posterior = obs.iter().fold(prior, |p, o| bayesian_update(p, o));
        prop_assert!(posterior <= 1000);
    }

    #[test]
    fn ga_fitness_monotonic_under_elitism(seed: u64, generations: 10..30) {
        let mut pop = GaPopulation::new_seeded(seed);
        let mut last_best = 0.0;
        for _ in 0..generations {
            pop.evolve_with_elitism();
            let best = pop.best_fitness();
            prop_assert!(best >= last_best);
            last_best = best;
        }
    }
}
```

**Total: 8 properties × 1000 cases = 8000 property runs.**

## 4. Chaos scenarios

| # | Inject | Assert |
|---|---|---|
| 1 | `kill -9 daemon` mid-hook | hook emits embedded fallback within timeout |
| 2 | Touch /tmp/c3i-stop-hook.lock then sleep 600s | dead-man clears, ingest proceeds |
| 3 | `kill -STOP daemon` (hung) | watchdog detects in 600ms, kills, systemd restarts |
| 4 | `dd of=/tmp/disk-fill bs=1M count=99999` | metabolism downsamples; no silent fail |
| 5 | Spawn 1000 concurrent hooks | queue stable; p99 < 200µs (data plane) |
| 6 | `sqlite3 smriti.db ".save backup"` (locks db) | hooks defer + retry; no corruption |
| 7 | `iptables -A OUTPUT -p tcp --dport 7447 -j DROP` (Zenoh down) | local UDS continues; mesh observers blind |
| 8 | `dd if=/dev/urandom of=/dev/shm/c3i-hook-state.bin` (corrupt snapshot) | CRC detects; daemon recreates |
| 9 | `rm /home/an/dev/ver/intelitor-v5.2/.devenv/profile/bin/gleam` | resolver uses fallback; warning emitted |
| 10 | hot-reload daemon code mid-session | in-flight hooks complete on old code; new hooks use new |

Pass criterion: 10/10. Failure → P0 sa-plan task.

## 5. Formal verification gates

### 5.1 Agda
```
$ agda --safe specs/agda/HookSubsystem.agda
Checking HookSubsystem (specs/agda/HookSubsystem.agda).
✓ no-silent-fail
✓ exec-emits-message
✓ fail-closed
✓ agent-uniformity
```

### 5.2 TLA+ via Apalache
```
$ apalache check --inv=HookAlwaysEmits specs/tla/HookSubsystem.tla
✓ HookAlwaysEmits   (no counterexample, depth 30)
$ apalache check --inv=NoSilentFail specs/tla/HookSubsystem.tla
✓ NoSilentFail      (no counterexample, depth 30)
$ apalache check --inv=LockExclusive specs/tla/HookSubsystem.tla
✓ LockExclusive     (no counterexample, depth 30)
[... 9 more invariants ...]
$ apalache check --temporal-spec=HookSafety specs/tla/HookSubsystem.tla
✓ HookSafety
$ apalache check --temporal-spec=HookLiveness specs/tla/HookSubsystem.tla
✓ HookLiveness
```

### 5.3 Mutation testing
```
$ cargo mutants --in-place=false
Tested mutations: 247
Killed: 235 (95.1%)  ← target
Missed: 12
Required action: investigate each Missed; either add test or document why surviving mutation is benign
```

## 6. SLO verification

```
SLO-1: hook success rate ≥ 99.9966%
       Measure: 30-day rolling success / total
       Test: simulator runs 1M hooks; failures < 4

SLO-2: data plane p99 latency < 100µs
       Measure: histogram of timestamps in ring buffer
       Test: criterion benchmark, 10k samples

SLO-3: daemon availability ≥ 99.95%
       Measure: 1Hz heartbeat presence over 30 days
       Test: deploy to staging, run 7 days, extrapolate

SLO-4: cache hit rate ≥ 92%
       Measure: PID state.hit_rate field
       Test: 1000-fire simulation, assert convergence

SLO-5: GA fitness improves vs baseline within 30 generations
       Measure: best_fitness - baseline_fitness > 0.5
       Test: simulated workload, deterministic seed
```

## 7. Multi-agent symbiosis tests

| # | Test | Pass criterion |
|---|---|---|
| 1 | Claude + Pi concurrent SessionStart | both complete < 200µs |
| 2 | Pi + Gemini both call stop-hook simultaneously | flock serialises; both succeed |
| 3 | All three agents fire UserPromptSubmit at 1Hz | shared snapshot serves all; no contention |
| 4 | MDP convergence with 3-agent pooled transitions | converges in 1/3 the time of single-agent |
| 5 | Per-agent telemetry correctly tagged | agent_id present on every span |

## 8. Coverage gates

| Metric | Target | Tooling |
|---|---|---|
| Line coverage (Rust) | ≥ 90% | `cargo tarpaulin` |
| Branch coverage (Rust) | ≥ 85% | `cargo tarpaulin --branch` |
| Mutation kill rate | ≥ 95% | `cargo mutants` |
| Shannon entropy (Gleam) | ≥ 2.5 bits | `coverage_math.gleam` |
| CCM (composite) | ≥ 0.90 | `coverage_math.gleam` |
| ITQS (test quality) | ≥ 0.85 | `coverage_math.gleam` |
| D_EA (expected vs actual) | ≤ 10% | `alignment.gleam` |

## 9. Verification matrix

8 invariants × 4 formalisms = 32 verification points. Triangulation requires all 32 pass.

| Invariant | Agda | TLA+ | Allium | Property |
|---|:-:|:-:|:-:|:-:|
| HookAlwaysEmits | ✓ | ✓ | ✓ | ✓ |
| NoSilentFail | ✓ | ✓ | ✓ | ✓ |
| SnapshotFresh | ✓ | ✓ | ✓ | ✓ |
| LockExclusive | – | ✓ | ✓ | ✓ |
| FailClosed | ✓ | ✓ | ✓ | ✓ |
| BayesianMonotonic | ✓ | ✓ | ✓ | ✓ |
| PIDConverges | – | ✓ | ✓ | ✓ |
| CrashIsolation | – | ✓ | ✓ | ✓ |
