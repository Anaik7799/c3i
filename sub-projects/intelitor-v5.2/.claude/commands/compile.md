---
description: SIL-6 Patient Mode compilation with Zenoh telemetry and fractal verification
allowed-tools: Bash(mix:*), Bash(NO_TIMEOUT=true:*), mcp__sentinel-zenoh__sentinel, mcp__sentinel-zenoh__zenoh_pub, mcp__sentinel-zenoh__zenoh_query, Read
---

# Compile Command (SC-METRICS-003, SC-FUNC-001, SC-SIL6-001)

SIL-6 Patient Mode compilation with 16-scheduler parallelization, Zenoh telemetry, and health verification.

## Mathematical Foundation

**Compilation Predicate** $\mathcal{C}$:
$$\mathcal{C}(S) \iff \text{Errors}(S) = 0 \wedge \text{Warnings}(S) = 0 \wedge \text{Files}(S) = |\mathcal{F}|$$

**Parallelization Constraint** (SC-METRICS-003):
$$\text{Schedulers} = 16, \quad \text{Partitions} = 8, \quad T_{compile} = O(|\mathcal{F}| / 16)$$

**Functional Invariant** (SC-FUNC-001):
$$\forall t: \mathcal{C}(S_t) \implies \mathcal{C}(S_{t+1})$$

## Execute

```bash
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
mix compile 2>&1 | tee -a ./data/tmp/1-compile.log
```

## Additional Commands

```bash
compile-profile  # Per-file timing with wait analysis
compile-xref     # Dependency graph (nodes, edges, cycles)
```

## Post-Compilation Verification (SIL-6)

1. Report total warnings and errors
2. If errors: show first 5 with file:line references
3. If warnings: categorize by type
4. Verify schedulers: `:erlang.system_info(:schedulers_online)` = 16
5. **Health check**: `sentinel(action: "health")` — verify system stability
6. **Publish telemetry**: `zenoh_pub(key: "indrajaal/compile/status", payload: "{result}")`
7. **Verify FFI**: `zenoh_query(action: "verify")` — ensure bridge intact post-compile

## SIL-6 SDLC Coverage

| Phase | Action | Constraint |
|-------|--------|-----------|
| **Impl** | Parallel compilation | SC-METRICS-003 |
| **Test** | Zero warnings gate | SC-CMP-025 |
| **Runtime** | Health post-check | SC-FUNC-001 |
| **Evolution** | Telemetry publish | SC-OBS-069 |

## STAMP Constraints

| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-METRICS-003 | **Parallelization MANDATORY** | Env var check |
| SC-CMP-025 | 0 warnings | --warnings-as-errors |
| SC-CMP-026 | All files compiled | File count match |
| SC-CMP-028 | No interruption | Patient Mode |
| SC-FUNC-001 | System MUST compile | Pre-commit gate |
