# Indrajaal NIF Safety Framework (v1.0.0)

**Classification**: SIL-2 COMPLIANT CONTROLS
**Mandate**: ZERO TOLERANCE FOR SCHEDULER STARVATION
**Scope**: All Rustler/C/C++ Native Implemented Functions

## 1. STAMP Safety Constraints (SC-NIF)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-NIF-001 | NIFs SHALL NOT execute for >1ms without yielding. | CRITICAL | Dirty Schedulers / Time Tracing |
| SC-NIF-002 | All memory MUST be managed via Rustler/BEAM ownership. | CRITICAL | Valgrind / Miri |
| SC-NIF-003 | NIF loading failure MUST trigger deterministic Elixir fallback. | HIGH | Load Handshake |
| SC-NIF-004 | Native panics MUST be caught and converted to Elixir errors. | CRITICAL | UnwindSafe / catch_unwind |
| SC-NIF-005 | I/O-bound native tasks MUST use `DirtyIo` schedulers. | HIGH | Rustler Attribute Check |
| SC-NIF-006 | CPU-bound tasks >1ms MUST use `DirtyCpu` schedulers. | HIGH | Rustler Attribute Check |

## 2. Agent Operating Rules (AOR-NIF)

| ID | Rule | Natural Language |
|----|------|------------------|
| AOR-NIF-001 | **Atomic Verification** | Agent MUST verify NIF symbol matching before code delivery. |
| AOR-NIF-002 | **Safe Defaults** | Agent MUST provide a pure-Elixir fallback for every NIF module. |
| AOR-NIF-003 | **Zero-Copy Mandate** | Agent MUST use `Binary` or `OwnedBinary` for data > 64 bytes. |
| AOR-NIF-004 | **Leak Prevention** | Agent MUST run memory leak checks after any NIF logic change. |

## 3. FMEA: Failure Mode & Effects Analysis (Zenoh NIF)

| Mode | Cause | Effect | S | O | D | RPN | Mitigation |
|------|-------|--------|---|---|---|-----|------------|
| bad_lib | Symbol Mismatch | NIF fails to load, system blind | 10 | 5 | 2 | 100 | `on_load` diagnostic handshake |
| Starvation | Synchronous Block | BEAM scheduler hangs, latency spike | 9 | 3 | 4 | 108 | Mandatory Dirty Schedulers |
| Segfault | Raw pointer error | Entire BEAM node crashes | 10 | 2 | 5 | 100 | Rust Safe-Abstractions only |
| Buffer Bloat | No backpressure | OOM in native memory | 8 | 4 | 3 | 96 | Zenoh Flow Control + Bounded Channels |

## 4. TDG (Test-Driven Generation) Requirements

1. **Panic Resistance**: Test that passing `nil` or malformed binary doesn't crash the VM.
2. **Timeout Invariant**: Verify that the NIF returns control within its allocated time slice.
3. **Fallback Invariant**: If `priv/native/library.so` is missing, the Elixir module must continue in `stub` mode.
