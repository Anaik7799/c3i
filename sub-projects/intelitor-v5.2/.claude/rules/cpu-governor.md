---
paths: "**/*"
---

# CPU Governor Protocol (SC-CPU-GOV)

## SUPREME MANDATE

**Total system CPU utilization MUST NOT exceed 85% during ANY agent-initiated operation.**

This rule applies to ALL commands executed by agents: compilation, testing, builds, scripts,
container operations, and any compute-intensive task. Violations trigger automatic throttling.

---

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-CPU-GOV-001 | CPU utilization MUST NOT exceed 85% during agent operations | CRITICAL |
| SC-CPU-GOV-002 | ALL mix compile/test MUST use cpu-governor wrapper | CRITICAL |
| SC-CPU-GOV-003 | Pre-execution CPU check MANDATORY before heavy commands | HIGH |
| SC-CPU-GOV-004 | Automatic throttling when CPU > 80% (reduce parallelism) | HIGH |
| SC-CPU-GOV-005 | Automatic wait-loop when CPU > 85% (pause until < 75%) | CRITICAL |
| SC-CPU-GOV-006 | Scheduler count MUST adapt: 16 < 60%, 12 < 70%, 10 < 80%, 6 >= 80% | HIGH |
| SC-CPU-GOV-007 | Mix --jobs MUST adapt: 16 < 60%, 12 < 70%, 10 < 80%, 6 >= 80% | HIGH |
| SC-CPU-GOV-008 | nice level MUST be >=10 for all agent-spawned compilations | MEDIUM |
| SC-CPU-GOV-009 | CPU check interval: 2 seconds during wait-loop | MEDIUM |
| SC-CPU-GOV-010 | Maximum wait time: 120 seconds before proceeding with minimum parallelism | HIGH |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-CPU-GOV-001 | ALWAYS source cpu-governor.sh before running heavy commands |
| AOR-CPU-GOV-002 | ALWAYS use `governed_compile` instead of raw `mix compile` |
| AOR-CPU-GOV-003 | ALWAYS use `governed_test` instead of raw `mix test` |
| AOR-CPU-GOV-004 | NEVER use `+S 16:16` when CPU > 80% — use adaptive scheduler count |
| AOR-CPU-GOV-005 | NEVER use `--jobs 16` when CPU > 80% — use adaptive job count |
| AOR-CPU-GOV-006 | Log CPU utilization before and after heavy operations |
| AOR-CPU-GOV-007 | Report throttling events to session output |
| AOR-CPU-GOV-008 | ALWAYS set HEALTH_PORT=4051 in governed test/wallaby commands |
| AOR-CPU-GOV-009 | CPU measurement MUST use /proc/stat differential (NOT load average) |
| AOR-CPU-GOV-010 | NEVER use `mpstat` or `/proc/loadavg` — they conflate I/O wait with CPU |

---

## Adaptive Parallelism Table

| CPU % | Schedulers (+S) | Dirty IO (+SDio) | Mix --jobs | nice | Action |
|-------|-----------------|-------------------|------------|------|--------|
| < 60% | 16:16 | 16 | 16 | 10 | Full speed |
| 60-70% | 12:12 | 12 | 12 | 10 | Slight reduction |
| 70-80% | 10:10 | 10 | 10 | 15 | Moderate throttle |
| 80-85% | 6:6 | 6 | 6 | 19 | Heavy throttle |
| > 85% | WAIT | WAIT | WAIT | — | Pause until < 75% |

---

## CPU Measurement Method (CRITICAL)

CPU measurement MUST use `/proc/stat` differential, NOT `/proc/loadavg` or `mpstat`:

```bash
# CORRECT: /proc/stat differential (100ms accuracy)
cpu_usage_fast() {
    # Read /proc/stat twice, 100ms apart, compute actual CPU %
    read -r _ u1 n1 s1 i1 w1 q1 r1 _ < /proc/stat
    c1=$((u1 + n1 + s1 + w1 + q1 + r1))
    sleep 0.1
    read -r _ u2 n2 s2 i2 w2 q2 r2 _ < /proc/stat
    c2=$((u2 + n2 + s2 + w2 + q2 + r2))
    td=$(( (c2 + i2) - (c1 + i1) ))
    id=$((i2 - i1))
    echo $(( (td - id) * 100 / td ))
}
```

**Why NOT load average**: `/proc/loadavg` includes I/O-waiting processes (e.g., DuckDB C++
compilation, container builds). A system with 42% actual CPU can show 133% load average.
This causes false throttling.

---

## Port Assignments (Updated 2026-03-31)

| Port | Service | Notes |
|------|---------|-------|
| 4000-4010 | 16-container SIL-6 mesh | RESERVED — Phoenix, health, Chaya, Cortex, etc. |
| 4050 | Phoenix Wallaby test endpoint | config/wallaby.exs |
| 4051 | FoundationSupervisor health plug (test) | Set via HEALTH_PORT env |
| 4052 | Dashboard monitoring port (test) | config/test.exs |
| 5433 | PostgreSQL | indrajaal-db-prod container |
| 7447 | Zenoh router | zenoh-router container |

**CRITICAL**: `HEALTH_PORT=4051` MUST be set in all governed test commands. Without it,
FoundationSupervisor tries port 4001 (occupied by mesh) → `:eaddrinuse` crash → app fails to boot.

---

## Governor Script

The authoritative implementation is `scripts/cpu-governor.sh` (zsh compatible). It provides:

- `cpu_usage()` — accurate CPU % over 1 second (for precise measurement)
- `cpu_usage_fast()` — accurate CPU % over 100ms (for pre-checks)
- `cpu_wait_if_high()` — blocks until CPU < 75% (max 120s)
- `adaptive_env()` — exports ELIXIR_ERL_OPTIONS and MIX_JOBS based on current CPU
- `governed_compile` — full Patient Mode compile with CPU governance
- `governed_test` — full Patient Mode test with CPU governance + HEALTH_PORT=4051
- `governed_wallaby` — full Wallaby E2E test with CPU governance + HEALTH_PORT=4051
- `governed_exec` — run any command with CPU pre-check
- `cpu_governor_status` — display status dashboard

### Usage

```bash
# Source the governor (MUST be sourced, not executed)
source scripts/cpu-governor.sh

# Governed compilation (adapts parallelism to CPU load)
governed_compile

# Governed test run
governed_test test/some_test.exs --only wallaby

# Governed Wallaby E2E
governed_wallaby test/indrajaal_web/live/navigation_portal_live_wallaby_test.exs --trace

# Governed arbitrary command
governed_exec dotnet build lib/cepaf/src/Cepaf/Cepaf.fsproj

# Status dashboard
cpu_governor_status
```

---

## Wallaby E2E Integration

The `governed_wallaby` function includes ALL required env vars for E2E tests:

```bash
governed_wallaby() {
    cpu_wait_if_high && adaptive_env
    nice -n "$GOVERNOR_NICE" env \
        WALLABY_ENABLED=true \
        SKIP_ZENOH_NIF=0 \
        NO_TIMEOUT=true \
        PATIENT_MODE=enabled \
        HEALTH_PORT=4051 \          # Avoids mesh port range 4000-4010
        ELIXIR_ERL_OPTIONS="$ELIXIR_ERL_OPTIONS" \
        POSTGRES_USER="${POSTGRES_USER:-postgres}" \
        POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}" \
        DATABASE_URL="${DATABASE_URL:-ecto://postgres:postgres@localhost:5433/indrajaal_test}" \
        MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
        MIX_ENV=test mix test --only wallaby "$@"
}
```

### Wallaby Config Requirements (config/wallaby.exs)

| Setting | Value | Why |
|---------|-------|-----|
| `base_url` | `http://localhost:4050` | Chrome needs to know where Phoenix is running |
| `server` | `true` | Phoenix must serve HTTP for browser tests |
| `http port` | `4050` | Ports 4000-4010 reserved for 16-container mesh |
| `Oban plugins` | `false` | Stager crashes without Ecto sandbox ownership |
| `Oban queues` | `false` | No background jobs during E2E tests |

---

## Integration with Existing Rules

| This rule | Related rule | Relationship |
|-----------|-------------|--------------|
| SC-CPU-GOV-001 | SC-PARALLEL-001 | Overrides fixed +S 16:16 with adaptive scheduler count |
| SC-CPU-GOV-007 | SC-PARALLEL-002 | Overrides fixed --jobs 16 with adaptive job count |
| SC-CPU-GOV-001 | SC-ENV-COMPILE-004 | CPU governor TAKES PRECEDENCE over fixed scheduler config |
| AOR-CPU-GOV-002 | AOR-ENV-COMPILE-001 | governed_compile replaces raw mix compile |
| AOR-CPU-GOV-008 | SC-COV-008 | HEALTH_PORT=4051 required for Wallaby E2E |

**Precedence**: When CPU > 80%, SC-CPU-GOV-001 OVERRIDES SC-PARALLEL-001 and SC-ENV-COMPILE-004.
The 85% hard limit is non-negotiable. Parallelism is a means, not an end.

---

## Sentinel-Zenoh Integration

When the Sentinel MCP server is available, the CPU governor publishes utilization metrics:

- **Key expression**: `indrajaal/cpu/governor/status`
- **Payload**: JSON `{"cpu_pct": N, "mode": "full|throttle|wait", "schedulers": N, "jobs": N, "nice": N}`
- **Tool**: `mcp__sentinel-zenoh__zenoh_pub`
- **Frequency**: Before and after each governed operation

---

## Constitutional Alignment

- **Omega-1 (Patient Mode)**: Patience includes not overloading the hardware
- **SC-FUNC-001**: System must remain responsive — CPU saturation degrades all operations
- **Psi-0 (Existence)**: Thermal throttling or OOM kills threaten system survival
- **SC-COV-008**: Wallaby E2E tests require healthy system (HEALTH_PORT=4051)
