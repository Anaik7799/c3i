---
paths: "**/*"
---

# Mandatory Compile & Test Environment (SC-ENV-COMPILE)

## SUPREME MANDATE

**ALL `mix compile` and `mix test` invocations MUST include the full mandatory environment.**

No exceptions. No shortcuts. Every agent, script, skill, and documentation example MUST use
these exact flags. Violations break Zenoh telemetry, Wallaby E2E coverage, and SIL-6 compliance.

---

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-ENV-COMPILE-001 | ALL `mix compile` MUST include `--jobs 16` | CRITICAL |
| SC-ENV-COMPILE-002 | ALL `mix compile` MUST set `SKIP_ZENOH_NIF=0` | CRITICAL |
| SC-ENV-COMPILE-003 | ALL `mix compile` MUST set `WALLABY_ENABLED=true` | HIGH |
| SC-ENV-COMPILE-004 | ALL `mix compile` MUST set `ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"` | CRITICAL |
| SC-ENV-COMPILE-005 | ALL `mix test` MUST set `SKIP_ZENOH_NIF=0` | CRITICAL |
| SC-ENV-COMPILE-006 | ALL `mix test` MUST set `WALLABY_ENABLED=true` | HIGH |
| SC-ENV-COMPILE-007 | ALL `mix test` MUST set `ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"` | CRITICAL |
| SC-ENV-COMPILE-008 | ALL `mix compile` MUST set `NO_TIMEOUT=true PATIENT_MODE=enabled` | HIGH |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-ENV-COMPILE-001 | NEVER run `mix compile` without `--jobs 16` |
| AOR-ENV-COMPILE-002 | NEVER run `mix compile` or `mix test` with `SKIP_ZENOH_NIF=1` |
| AOR-ENV-COMPILE-003 | NEVER omit `WALLABY_ENABLED=true` from compile/test env |
| AOR-ENV-COMPILE-004 | NEVER use `+S 10:10` or `+S 16` — ALWAYS `+S 16:16 +SDio 16` |
| AOR-ENV-COMPILE-005 | Documentation examples MUST use full env (no abbreviated forms) |

---

## Canonical Compile Command

```bash
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
SKIP_ZENOH_NIF=0 \
WALLABY_ENABLED=true \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
mix compile --jobs 16
```

## Canonical Test Command

```bash
SKIP_ZENOH_NIF=0 \
WALLABY_ENABLED=true \
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
POSTGRES_USER=postgres \
POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
MIX_ENV=test mix test "$@"
```

## Canonical Wallaby E2E Test Command

```bash
WALLABY_ENABLED=true \
SKIP_ZENOH_NIF=0 \
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
POSTGRES_USER=postgres \
POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
MIX_ENV=test mix test --only wallaby "$@"
```

---

## Why Each Flag Is Mandatory

| Flag | Why |
|------|-----|
| `SKIP_ZENOH_NIF=0` | Enables Zenoh FFI native integration. Without it, telemetry is simulated, not real. SC-ZENOH-001. |
| `WALLABY_ENABLED=true` | Loads Wallaby browser test config. Without it, E2E tests are excluded and `config/wallaby.exs` never imports. SC-COV-008. |
| `ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"` | 16 scheduler threads + 16 dirty IO threads. `+S 16` alone misses dirty IO. SC-PARALLEL-001. |
| `--jobs 16` | Parallel Elixir compilation across 16 cores. SC-PARALLEL-002. |
| `NO_TIMEOUT=true` | Prevents compilation timeouts on large modules. Omega-1 Patient Mode. |
| `PATIENT_MODE=enabled` | Extended patience for BEAM compilation. Omega-1. |

## Forbidden Patterns

```bash
# FORBIDDEN: Missing --jobs 16
mix compile                                    # VIOLATION SC-ENV-COMPILE-001

# FORBIDDEN: Zenoh NIF disabled
SKIP_ZENOH_NIF=1 mix compile                  # VIOLATION SC-ENV-COMPILE-002

# FORBIDDEN: Old scheduler format
ELIXIR_ERL_OPTIONS="+S 16" mix compile        # VIOLATION SC-ENV-COMPILE-004
ELIXIR_ERL_OPTIONS="+S 10:10" mix compile     # VIOLATION SC-ENV-COMPILE-004

# FORBIDDEN: Missing Wallaby
mix test                                       # VIOLATION SC-ENV-COMPILE-006
SKIP_ZENOH_NIF=0 MIX_ENV=test mix test       # VIOLATION SC-ENV-COMPILE-006 (no WALLABY)
```

## Authoritative Source

The `devenv.nix` file is the canonical implementation. All other files (rules, agents,
commands, scripts, plans) MUST mirror the patterns defined in `devenv.nix` scripts section.

## Incident Reference

On 2026-03-28, an ITQS audit task was compiled with `SKIP_ZENOH_NIF=1`, causing the Zenoh
NIF to be unavailable and breaking telemetry integration. This rule prevents recurrence.

---

## Related Documents

- CLAUDE.md §1.0 Omega-1 (Patient Mode)
- CLAUDE.md §5.0 SC-PARALLEL-001, SC-PARALLEL-002
- `.claude/rules/zenoh-telemetry-mandatory.md` (SC-ZENOH-001)
- `devenv.nix` — authoritative compile/test script definitions
