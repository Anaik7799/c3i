# SC-SCHED-TELE-MANDATORY — Subprocess + Job Telemetry Is Non-Optional

## Summary

Every subprocess launched anywhere in C3I (Rust daemon, gleam scripts,
pi-mono agent) **MUST** publish full lifecycle telemetry on Zenoh, and
**MUST** be wrapped in a timeout guard. Every plan, task, job, run and
process has a canonical URN. This rule is enforced on every new feature.

## Authoritative references

- `docs/architecture/JOB_TELEMETRY_NAMING_TAXONOMY.md` — URN grammar, topics, payload envelope.
- `sub-projects/c3i/native/planning_daemon/src/sched_telemetry.rs` — Rust publisher.
- `sub-projects/c3i/native/planning_daemon/src/process_runner.rs` — timeout/heartbeat/stdout runner.
- `sub-projects/scripts-gleam/src/scripts/common/zenoh.gleam` — gleam publisher.

## Hard rules

1. **No direct `Command::output()`/`Command::status()`/`Command::spawn()` in workers.**
   Every subprocess spawn MUST go through `process_runner::run(RunSpec{..})`.
2. **Every lifecycle transition publishes on Zenoh** with:
   - at (ISO-8601 UTC)
   - source (`sa-plan | scripts-gleam | pi-mono | cepaf-gleam`)
   - urn (canonical URN of entity)
   - id, run_id, pid where applicable
3. **Plan/Task/Job/Run/Proc are all URN-addressable** — no naked integer IDs in cross-system messages.
4. **Hot-path telemetry is non-blocking.** Publishers MUST use bounded channels with drop-on-overflow (`try_send`).
5. **Durable log + Zenoh mirror**: ProcessRunner writes `docs/cache/builds/<stamp>-<name>-job<id>.log` AND publishes stdout/stderr events.

## CI gate

A feature is blocked from release if any of the following are true in the diff:

- New `Command::new(...)` call paths that don't route through `process_runner`.
- New `tokio::process::Command` use outside `process_runner.rs`.
- Worker code that calls `std::process::Command::output()` for non-short-lived trivial shell helpers (`which`, `hostname`, `date`).
- New Zenoh `put` of custom payload without the required envelope keys.
- New sa-plan task that doesn't emit a URN in its meta JSON.

## Agent enforcement

- `code-reviewer` rejects PRs introducing direct Command calls without runner use.
- `fractal-architect` verifies L0..L7 coverage per new feature.
- `coverage-audit-agent` ensures feature-evolution journals include URNs, diagrams, fractal map.

## Per-feature checklist (add to every feature-evolution journal)

- [ ] URN allocated for the feature's primary entities (task/job/run/proc).
- [ ] Subprocess spawns via ProcessRunner with explicit timeout.
- [ ] Zenoh events published on `indrajaal/l4/sched/**` using canonical vocab.
- [ ] Gleam / Pi subscriber verified (optional, strongly encouraged).
- [ ] RETE-UL rule considered for any new failure mode.
- [ ] FMEA table updated with new failure modes + containment.

## Rationale (why this rule exists)

Prior to this rule, worker subprocess state was invisible outside daemon
logs. Hung subprocesses could stay `executing` indefinitely, scheduled
jobs could fail silently due to daemon PATH differences, and Pi / cepaf-gleam
could not react in real time. The combination of URN identity + unified
Zenoh event vocabulary + timeout guard eliminates these failure classes.

## Governance parity

Mirrored at `.gemini/rules/sched-telemetry-mandatory.md`.
