# Build, Test & CPU Governance

## 1. Mandatory Compile Environment (SC-ENV-COMPILE)

**ALL mix compile/test MUST include the full mandatory environment.** No exceptions.

### Canonical Compile
```bash
NO_TIMEOUT=true PATIENT_MODE=enabled SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
mix compile --jobs 16
```

### Canonical Test
```bash
SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 MIX_ENV=test mix test "$@"
```

### Canonical Wallaby E2E
```bash
WALLABY_ENABLED=true SKIP_ZENOH_NIF=0 NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" HEALTH_PORT=4051 \
POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 MIX_ENV=test mix test --only wallaby "$@"
```

### Wallaby Config Requirements (config/wallaby.exs)
| Setting | Value | Why |
|---------|-------|-----|
| base_url | `http://localhost:4050` | Chrome target |
| server | true | Phoenix must serve HTTP |
| http port | 4050 | Ports 4000-4010 reserved for mesh |
| Oban plugins | false | Stager crashes without Ecto sandbox |
| Oban queues | false | No background jobs during E2E |

### Gleam Build/Test
```bash
cd lib/cepaf_gleam && gleam build   # or: gleam test
```

**Why each flag**: SKIP_ZENOH_NIF=0 (real telemetry, SC-ZENOH-001) | WALLABY_ENABLED=true (E2E config loaded) | +S 16:16 +SDio 16 (16 scheduler + 16 dirty IO threads) | --jobs 16 (parallel compilation) | NO_TIMEOUT/PATIENT_MODE (Omega-1)

**Forbidden**: `mix compile` without --jobs 16 | SKIP_ZENOH_NIF=1 | +S 16 or +S 10:10 (missing dirty IO) | mix test without WALLABY_ENABLED

## 2. CPU Governor (SC-CPU-GOV)

**Total CPU MUST NOT exceed 85% during agent operations.**

### Adaptive Parallelism
| CPU % | Schedulers | Dirty IO | --jobs | nice | Action |
|-------|-----------|----------|--------|------|--------|
| < 60% | 16:16 | 16 | 16 | 10 | Full speed |
| 60-70% | 12:12 | 12 | 12 | 10 | Slight reduction |
| 70-80% | 10:10 | 10 | 10 | 15 | Moderate throttle |
| 80-85% | 6:6 | 6 | 6 | 19 | Heavy throttle |
| > 85% | WAIT | WAIT | WAIT | - | Pause until < 75% |

### Usage
```bash
source scripts/cpu-governor.sh
governed_compile          # Adaptive mix compile
governed_test [args]      # Adaptive mix test (includes HEALTH_PORT=4051)
governed_wallaby [args]   # Adaptive Wallaby E2E
governed_exec <cmd>       # Any command with CPU pre-check
cpu_governor_status       # Dashboard
```

**CPU measurement**: MUST use /proc/stat differential (NOT load average or mpstat -- those conflate I/O wait).

### Port Assignments
| Port | Service |
|------|---------|
| 4000-4010 | 16-container SIL-6 mesh (RESERVED) |
| 4050 | Phoenix Wallaby test endpoint |
| 4051 | FoundationSupervisor health plug (test) -- MUST set HEALTH_PORT=4051 |
| 4052 | Dashboard monitoring port (test) |
| 5433 | PostgreSQL |
| 7447 | Zenoh router |

**Authoritative source**: `devenv.nix` scripts section. All other files MUST mirror these patterns.

**SC-CPU-GOV overrides SC-PARALLEL when CPU > 80%**. The 85% hard limit is non-negotiable.
