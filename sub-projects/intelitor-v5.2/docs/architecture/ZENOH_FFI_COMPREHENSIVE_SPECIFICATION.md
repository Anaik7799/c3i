# Zenoh FFI Comprehensive Specification — Narrow Waist Rust→F# Integration

**Version**: 1.0.0 | **Date**: 2026-03-18 | **Author**: Claude Opus 4.6
**STAMP**: SC-ZENOH-FFI-001 to SC-ZENOH-FFI-025 | **Compliance**: IEC 61508 SIL-6
**Architecture**: Narrow Waist C ABI — Rust cdylib → csbindgen → F# DllImport

---

## 0. Mathematical Foundations

### 0.1 System Model

Let $\mathcal{Z}$ denote the Zenoh communication subsystem. Define:

$$\mathcal{Z} = (\mathcal{S}, \mathcal{P}, \mathcal{Q}, \mathcal{T}, \mathcal{M})$$

where:
- $\mathcal{S}$ = Session lifecycle state machine
- $\mathcal{P}$ = Publisher set $\{p_1, ..., p_n\}$
- $\mathcal{Q}$ = Subscriber set $\{q_1, ..., q_m\}$
- $\mathcal{T}$ = Topic space (key expressions) $\subseteq \Sigma^*$
- $\mathcal{M}$ = Message space $= \mathcal{T} \times \mathbb{B}^* \times \mathbb{T}$

### 0.2 Session State Machine

$$\mathcal{S} = (Q_S, \Sigma_S, \delta_S, q_0, F_S)$$

where:
- $Q_S = \{Closed, Opening, Connected, Degraded, Closing\}$
- $\Sigma_S = \{open, connect\_ok, connect\_fail, disconnect, close, reconnect\}$
- $q_0 = Closed$
- $F_S = \{Closed\}$

**Transition function** $\delta_S$:

| Current State | Input | Next State | Side Effect |
|---|---|---|---|
| Closed | open | Opening | Create tokio runtime |
| Opening | connect_ok | Connected | Store session handle |
| Opening | connect_fail | Closed | Free runtime |
| Connected | disconnect | Degraded | Set connected=false |
| Connected | close | Closing | Signal subscribers |
| Degraded | reconnect | Opening | Reset stats |
| Degraded | close | Closing | Signal subscribers |
| Closing | * | Closed | Free all handles |

**Invariant**: $\forall t: |\{h \mid h \in Handles_{active}(t)\}| = |\{h \mid h \in Handles_{allocated}(t)\}| - |\{h \mid h \in Handles_{freed}(t)\}|$

(No handle leaks — SC-ZENOH-FFI-002)

### 0.3 Latency Model

**Publish path latency**:
$$L_{pub} = L_{marshal} + L_{runtime} + L_{zenoh} + L_{ack}$$

**Budget allocation** (SC-ZTEST-003: $L_{pub} < 10ms$):

| Component | Symbol | Budget | p99 Target |
|---|---|---|---|
| F# → C marshal | $L_{marshal}$ | 0.5ms | 1.0ms |
| Tokio block_on | $L_{runtime}$ | 0.5ms | 1.0ms |
| Zenoh wire | $L_{zenoh}$ | 3.0ms | 5.0ms |
| Ack/stats | $L_{ack}$ | 0.1ms | 0.2ms |
| **Total** | $L_{pub}$ | **4.1ms** | **7.2ms** |
| **Margin** | | **5.9ms** | **2.8ms** |

**Subscribe path latency** (poll-based):
$$L_{sub} = L_{poll\_interval} + L_{channel} + L_{unmarshal}$$

Where $L_{poll\_interval} \leq 100ms$ (configurable), $L_{channel} < 0.01ms$ (crossbeam bounded).

### 0.4 Channel Capacity Analysis

**Bounded channel capacity**: $C = 1000$ messages (SC-ZENOH-SUB-002)

**Message loss probability** under Poisson arrival rate $\lambda$:

$$P_{loss} = P(N > C) = 1 - \sum_{k=0}^{C} \frac{e^{-\lambda T} (\lambda T)^k}{k!}$$

For $\lambda = 100$ msg/s, $T_{poll} = 0.1s$, $C = 1000$:
$$P_{loss} \approx 10^{-2200} \approx 0$$

**Conclusion**: Channel overflow is vanishingly unlikely at expected message rates.

### 0.5 Quorum Mathematics

For 2oo3 voting (SC-SIL6-006):
$$Q(N) = \lfloor N/2 \rfloor + 1$$

Cross-runtime quorum requires Elixir NIF + F# FFI + Formal Model agreement:
$$Quorum_{cross} = |\{r \in \{EX, FS, FM\} : agree(r)\}| \geq 2$$

---

## 1. Fractal Architecture (L0 → L7)

### L0: Runtime — Rust cdylib

**Files**: `native/zenoh_ffi/src/lib.rs`, `Cargo.toml`, `build.rs`

**Formal specification**:
```
∀ fn ∈ FFI_exports:
  fn = extern "C" ∧ #[no_mangle]
  fn wrapped in panic::catch_unwind     (SC-ZENOH-FFI-001)
  null_check(all_pointer_args)          (Precondition)
  return_code ∈ {0, -1, ptr, null}      (Contract)
```

**Functions** (9 total):

| # | Function | Signature | Return | STAMP |
|---|----------|-----------|--------|-------|
| 1 | `zenoh_ffi_open` | `(config_json: *const c_char) → *mut ZenohHandle` | ptr/null | SC-ZENOH-FFI-001 |
| 2 | `zenoh_ffi_close` | `(handle: *mut ZenohHandle) → void` | void | SC-ZENOH-FFI-002 |
| 3 | `zenoh_ffi_is_connected` | `(handle: *const ZenohHandle) → bool` | bool | SC-ZENOH-FFI-003 |
| 4 | `zenoh_ffi_session_stats` | `(handle, out_buf, buf_len) → i32` | bytes/-1 | SC-ZENOH-FFI-003 |
| 5 | `zenoh_ffi_publish` | `(handle, key, payload, len) → i32` | 0/-1 | SC-ZTEST-003 |
| 6 | `zenoh_ffi_subscribe` | `(handle, key_expr) → *mut ZenohSubHandle` | ptr/null | SC-ZENOH-FFI-002 |
| 7 | `zenoh_ffi_poll` | `(sub, out_buf, buf_len, max) → i32` | bytes/0/-1 | SC-ZENOH-FFI-003 |
| 8 | `zenoh_ffi_unsubscribe` | `(sub: *mut ZenohSubHandle) → void` | void | SC-ZENOH-FFI-002 |
| 9 | `zenoh_ffi_get` | `(handle, key, timeout, out_buf, len) → i32` | bytes/0/-1 | SC-ZENOH-FFI-003 |

**Internal types**:
- `ZenohSession`: `Arc<Session>` + `Arc<Runtime>` + `AtomicBool` connected + `SessionStats`
- `ZenohSubscription`: `Receiver<ZenohMessageInternal>` + `Arc<AtomicBool>` active + stats
- `ZenohHandle`: Opaque `Box<ZenohSession>` (C-visible as `*mut`)
- `ZenohSubHandle`: Opaque `Box<ZenohSubscription>` (C-visible as `*mut`)

### L1: Function — C ABI Boundary

**Files**: `native/zenoh_ffi/generated/ZenohFfi.g.cs` (auto-generated by csbindgen)

**Generated binding contract**:
```csharp
namespace Cepaf.Zenoh.Native {
    public static unsafe partial class ZenohFfi {
        [DllImport("zenoh_ffi")] public static extern IntPtr zenoh_ffi_open(byte* config_json);
        [DllImport("zenoh_ffi")] public static extern void zenoh_ffi_close(IntPtr handle);
        [DllImport("zenoh_ffi")] public static extern bool zenoh_ffi_is_connected(IntPtr handle);
        [DllImport("zenoh_ffi")] public static extern int zenoh_ffi_session_stats(IntPtr handle, byte* out_buf, nuint buf_len);
        [DllImport("zenoh_ffi")] public static extern int zenoh_ffi_publish(IntPtr handle, byte* key, byte* payload, nuint payload_len);
        [DllImport("zenoh_ffi")] public static extern IntPtr zenoh_ffi_subscribe(IntPtr handle, byte* key_expr);
        [DllImport("zenoh_ffi")] public static extern int zenoh_ffi_poll(IntPtr sub, byte* out_buf, nuint buf_len, uint max_messages);
        [DllImport("zenoh_ffi")] public static extern void zenoh_ffi_unsubscribe(IntPtr sub);
        [DllImport("zenoh_ffi")] public static extern int zenoh_ffi_get(IntPtr handle, byte* key_expr, uint timeout_ms, byte* out_buf, nuint buf_len);
    }
}
```

**Invariants**:
- $\forall$ `IntPtr` returned: must be freed exactly once by corresponding `close`/`unsubscribe`
- $\forall$ `byte*` output: caller owns buffer, callee writes up to `buf_len` bytes
- Return < 0 ⟹ error; Return = 0 ⟹ empty/success; Return > 0 ⟹ bytes written

### L2: Component — F# Safe Wrapper (`ZenohFfiBridge.fs`)

**File**: `lib/cepaf/src/Cepaf/Zenoh/Core/ZenohFfiBridge.fs` (NEW)

**Module structure**:

```fsharp
namespace Cepaf.Zenoh.Core

module ZenohFfiBridge =
    // P/Invoke declarations (manual, since csbindgen generates C# not F#)
    [<DllImport("zenoh_ffi", CallingConvention = CallingConvention.Cdecl)>]
    extern IntPtr zenoh_ffi_open(byte[] config_json)

    // Safe wrappers returning ZenohResult<'T>
    let openSession (config: SessionConfig) : ZenohResult<nativeint> = ...
    let closeSession (handle: nativeint) : unit = ...
    let isConnected (handle: nativeint) : bool = ...
    let publish (handle: nativeint) (key: string) (payload: byte[]) : ZenohResult<unit> = ...
    let subscribe (handle: nativeint) (keyExpr: string) : ZenohResult<nativeint> = ...
    let poll (subHandle: nativeint) (maxMessages: int) : ZenohResult<ZenohSample list> = ...
    let unsubscribe (subHandle: nativeint) : unit = ...
    let get (handle: nativeint) (keyExpr: string) (timeoutMs: int) : ZenohResult<ZenohSample list> = ...
    let sessionStats (handle: nativeint) : ZenohResult<ZenohHealth> = ...
```

**Type safety invariants**:
- All `nativeint` handles wrapped in `IDisposable` containers
- All FFI calls wrapped in `try...with` returning `ZenohResult<'T>`
- JSON deserialization uses manual `JsonDocument` parsing (NOT `JsonSerializer.Deserialize<T>`) — required because `System.Text.Json` on .NET 10 cannot construct F# record types in `module private` scope even with `[<CLIMutable>]`. See `RELEASE_NOTE_20260320_SENTINEL_MCP_FIX.md`.
- Null pointer returns mapped to `ZenohError.NativeError(-1, "FFI returned null")`

### L3: Holon — Session Management (`ZenohNative.fs` modifications)

**File**: `lib/cepaf/src/Cepaf/Zenoh/Core/ZenohNative.fs` (MODIFY)

**Changes**:
1. `SafeSession.OpenAsync()` — add FFI path when `ZENOH_USE_NATIVE=true`
2. `SafePublisher.PutAsync()` — add FFI publish when session is not simulated
3. `SafeSubscriber.Create()` — add FFI subscribe + poll loop

**State machine enforcement**:
```
SafeSession states:
  Created → Opened(simulated) → Active → Disposed
  Created → Opened(native:handle) → Active → Disposed

Transition invariant:
  ∀ state_change: log to LifecycleEvent
  ∀ Disposed: all child publishers/subscribers disposed first
```

### L4: Container — Library Deployment

**Build artifacts**:
- `native/zenoh_ffi/target/release/libzenoh_ffi.so` (Linux, ~8MB with zenoh 1.7)
- `native/zenoh_ffi/generated/ZenohFfi.g.cs` (auto-generated)

**Container integration** (`podman-compose-sil6-full-mesh.yml`):
```yaml
indrajaal-ex-app-1:
  volumes:
    - ./native/zenoh_ffi/target/release/libzenoh_ffi.so:/usr/local/lib/libzenoh_ffi.so:ro
  environment:
    - LD_LIBRARY_PATH=/usr/local/lib
    - ZENOH_USE_NATIVE=true
```

### L5: Node — devenv Integration

**devenv.nix changes**:
```nix
enterShell = ''
  # Build zenoh_ffi if not present
  if [ ! -f native/zenoh_ffi/target/release/libzenoh_ffi.so ]; then
    cargo build --release --manifest-path native/zenoh_ffi/Cargo.toml
  fi
  export LD_LIBRARY_PATH="$PWD/native/zenoh_ffi/target/release:$LD_LIBRARY_PATH"
'';
```

### L6: Cluster — Cross-Runtime Wire Compatibility

**Critical constraint**: F# FFI uses `zenoh = "1.7"` (same as Elixir NIF `native/zenoh_nif/Cargo.toml`).

**Wire protocol verification**:
$$\forall m \in \mathcal{M}: encode_{FFI}(m) \equiv_{wire} encode_{NIF}(m)$$

**Cross-runtime pub/sub**:
```
F# FFI publishes "indrajaal/cepaf/health" → Zenoh Router → Elixir NIF subscribes "indrajaal/**"
Elixir NIF publishes "indrajaal/test/result" → Zenoh Router → F# FFI subscribes "indrajaal/test/**"
```

### L7: Federation — Protocol Negotiation

For federation mode, both runtimes must agree on protocol version:
$$\forall (h_{ex}, h_{fs}) \in Federation: version(h_{ex}) = version(h_{fs})$$

This is guaranteed by using same `zenoh = "1.7"` crate.

---

## 2. STAMP Constraints (SC-ZENOH-FFI-*)

| ID | Constraint | Severity | Layer | Verification | Mathematical Basis |
|----|------------|----------|-------|--------------|-------------------|
| SC-ZENOH-FFI-001 | All extern "C" fns wrapped in catch_unwind | CRITICAL | L0 | Code review | $\neg\exists$ panic across FFI |
| SC-ZENOH-FFI-002 | All handles freed exactly once | CRITICAL | L0 | ASAN/Miri | Handle count invariant |
| SC-ZENOH-FFI-003 | JSON serialization for cross-FFI messages | HIGH | L1 | Schema test | $\forall m: valid_{JSON}(m)$ |
| SC-ZENOH-FFI-004 | Null check on all pointer arguments | CRITICAL | L0 | Code review | $\forall ptr: check(ptr \neq null)$ |
| SC-ZENOH-FFI-005 | Buffer overflow prevention | CRITICAL | L0 | Bounds check | $write\_len \leq buf\_len$ |
| SC-ZENOH-FFI-006 | Tokio runtime created with 2 worker threads | HIGH | L0 | Config | Worker count = 2 |
| SC-ZENOH-FFI-007 | Bounded channel capacity = 1000 | HIGH | L0 | Config | $C = 1000$ |
| SC-ZENOH-FFI-008 | Poll max capped at 100 messages | MEDIUM | L0 | Code | $max \leq 100$ |
| SC-ZENOH-FFI-009 | UTF-8 validation on all C strings | HIGH | L0 | Code | $\forall s: valid_{UTF8}(s)$ |
| SC-ZENOH-FFI-010 | Same zenoh version as NIF (1.7) | CRITICAL | L6 | Cargo.toml | Wire compatibility |
| SC-ZENOH-FFI-011 | IDisposable pattern on all F# handles | HIGH | L2 | Code review | Deterministic cleanup |
| SC-ZENOH-FFI-012 | Thread-safety of all FFI calls | HIGH | L0 | Arc/Atomic | Lock-free reads |
| SC-ZENOH-FFI-013 | Error logging to stderr (not panic) | HIGH | L0 | Code review | Graceful degradation |
| SC-ZENOH-FFI-014 | Simulated fallback when ZENOH_USE_NATIVE=false | HIGH | L2 | Integration test | Dev mode works |
| SC-ZENOH-FFI-015 | Publish latency < 10ms (SC-ZTEST-003) | HIGH | L0 | Benchmark | $L_{pub} < 10ms$ |
| SC-ZENOH-FFI-016 | SC-ZTEST-008 dual-write preserved | CRITICAL | L3 | Integration test | Log fallback first |
| SC-ZENOH-FFI-017 | F# compilation order preserved | HIGH | L2 | fsproj | ZenohFfiBridge after ZenohTypes |
| SC-ZENOH-FFI-018 | csbindgen generates correct C# bindings | HIGH | L1 | Build test | Generated code compiles |
| SC-ZENOH-FFI-019 | No memory leaks under normal operation | HIGH | L0 | Valgrind/ASAN | $\Delta_{mem} \approx 0$ over time |
| SC-ZENOH-FFI-020 | Subscriber cleanup on unsubscribe | HIGH | L0 | Test | Active flag → false |
| SC-ZENOH-FFI-021 | Session stats include latency metrics | MEDIUM | L0 | Unit test | Stats JSON schema |
| SC-ZENOH-FFI-022 | Base64 encoding for non-UTF-8 payloads | MEDIUM | L0 | Unit test | Binary safety |
| SC-ZENOH-FFI-023 | LD_LIBRARY_PATH configured in devenv | HIGH | L5 | Integration | Library found at runtime |
| SC-ZENOH-FFI-024 | Container volume mount for .so | HIGH | L4 | Compose test | File accessible |
| SC-ZENOH-FFI-025 | F# project compiles with FFI bridge | CRITICAL | L2 | dotnet build | 0 errors |

---

## 3. FMEA Risk Analysis

| ID | Failure Mode | Severity (S) | Occurrence (O) | Detection (D) | RPN | Mitigation | Residual RPN |
|----|---|---|---|---|---|---|---|
| FM-FFI-001 | Panic across FFI boundary | 10 | 2 | 2 | 40 | catch_unwind on ALL extern fns | 20 |
| FM-FFI-002 | Handle double-free | 10 | 3 | 4 | 120 | IDisposable + disposed flag | 40 |
| FM-FFI-003 | Handle leak (not freed) | 7 | 4 | 5 | 140 | Finalizer + log warning | 49 |
| FM-FFI-004 | Buffer overflow in write_to_buffer | 10 | 2 | 2 | 40 | min(data.len, buf_len) | 20 |
| FM-FFI-005 | Zenoh router unreachable | 7 | 5 | 3 | 105 | Simulated fallback + SC-ZTEST-008 | 35 |
| FM-FFI-006 | Tokio runtime creation fails | 9 | 1 | 3 | 27 | Return null + log error | 18 |
| FM-FFI-007 | JSON deserialization failure | 5 | 3 | 3 | 45 | Error type + default config | 15 |
| FM-FFI-008 | Channel overflow (1000 msgs) | 3 | 2 | 6 | 36 | Drop + increment counter | 18 |
| FM-FFI-009 | Invalid UTF-8 in C string | 6 | 2 | 3 | 36 | cstr_to_str returns None | 18 |
| FM-FFI-010 | Wire version mismatch (NIF≠FFI) | 9 | 1 | 2 | 18 | Same Cargo.toml version | 9 |
| FM-FFI-011 | .so not found at runtime | 8 | 4 | 4 | 128 | LD_LIBRARY_PATH + devenv | 32 |
| FM-FFI-012 | csbindgen type mismatch | 7 | 2 | 3 | 42 | Manual DllImport fallback | 21 |
| FM-FFI-013 | Subscriber task stuck | 6 | 2 | 5 | 60 | 100ms timeout in select! | 24 |
| FM-FFI-014 | Memory leak in long sessions | 7 | 3 | 6 | 126 | Stats tracking + monitoring | 42 |
| FM-FFI-015 | Publish latency > 10ms | 5 | 3 | 3 | 45 | Async + latency metrics | 15 |

**Risk Classification**:
- CRITICAL ($RPN > 200$): None after mitigation
- HIGH ($100 < RPN \leq 200$): FM-FFI-002 (120→40), FM-FFI-003 (140→49), FM-FFI-011 (128→32), FM-FFI-014 (126→42)
- MEDIUM ($50 < RPN \leq 100$): FM-FFI-005 (105→35), FM-FFI-013 (60→24)
- LOW ($RPN \leq 50$): All others

---

## 4. AOR Rules (AOR-ZENOH-FFI-*)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-FFI-001 | NEVER pass unvalidated pointers to FFI | Null check wrapper |
| AOR-FFI-002 | ALWAYS dispose FFI handles in finally/using blocks | IDisposable |
| AOR-FFI-003 | NEVER block on FFI calls from UI thread | Async wrapper |
| AOR-FFI-004 | ALWAYS check return code before using output buffer | Result type |
| AOR-FFI-005 | ALWAYS build Rust crate before F# compilation | Build dependency |
| AOR-FFI-006 | ALWAYS preserve SC-ZTEST-008 dual-write pattern | Integration test |
| AOR-FFI-007 | ALWAYS set LD_LIBRARY_PATH before running F# with native | devenv shell |
| AOR-FFI-008 | NEVER assume Zenoh router is available | Simulated fallback |
| AOR-FFI-009 | ALWAYS use same zenoh crate version as NIF | Cargo.toml audit |
| AOR-FFI-010 | ALWAYS log FFI errors to stderr (not swallow) | Error handling |

---

## 5. Test Plan — 5-Level Fractal Coverage

### Level 1: Unit Tests (Rust)

| Test ID | Description | STAMP | Property |
|---------|-------------|-------|----------|
| UT-FFI-001 | open with null config uses defaults | SC-ZENOH-FFI-004 | $open(null) \neq null$ |
| UT-FFI-002 | open with invalid JSON returns null | SC-ZENOH-FFI-009 | $open(\text{"{"}) = null$ |
| UT-FFI-003 | close(null) is safe no-op | SC-ZENOH-FFI-002 | $close(null)$ terminates |
| UT-FFI-004 | publish with null handle returns -1 | SC-ZENOH-FFI-004 | $publish(null, ...) = -1$ |
| UT-FFI-005 | poll with empty channel returns 0 | SC-ZENOH-FFI-003 | $poll(empty) = 0$ |
| UT-FFI-006 | write_to_buffer respects buf_len | SC-ZENOH-FFI-005 | $\forall d,b: write(d,b) \leq b$ |
| UT-FFI-007 | base64_encode roundtrips | SC-ZENOH-FFI-022 | $decode(encode(x)) = x$ |
| UT-FFI-008 | session_stats returns valid JSON | SC-ZENOH-FFI-021 | $valid_{JSON}(stats)$ |
| UT-FFI-009 | subscribe with invalid key returns null | SC-ZENOH-FFI-004 | $subscribe(h, null) = null$ |
| UT-FFI-010 | cstr_to_str handles invalid UTF-8 | SC-ZENOH-FFI-009 | Returns None |

### Level 2: Integration Tests (F# → Rust)

| Test ID | Description | STAMP | Requires |
|---------|-------------|-------|----------|
| IT-FFI-001 | F# opens session to zenoh-router | SC-ZENOH-FFI-001 | zenoh-router container |
| IT-FFI-002 | F# publishes and poll receives | SC-ZTEST-003 | Active session |
| IT-FFI-003 | F# subscribe pattern matching | SC-ZTEST-001 | Active session |
| IT-FFI-004 | Session stats returns valid health | SC-ZENOH-FFI-021 | Active session |
| IT-FFI-005 | IDisposable cleanup frees handle | SC-ZENOH-FFI-002 | Active session |
| IT-FFI-006 | Simulated fallback works without router | SC-ZENOH-FFI-014 | No router |
| IT-FFI-007 | Dual-write preserved with native | SC-ZENOH-FFI-016 | Active session |
| IT-FFI-008 | Large payload (64KB boundary) | SC-ZTEST-016 | Active session |
| IT-FFI-009 | Binary payload base64 encoding | SC-ZENOH-FFI-022 | Active session |
| IT-FFI-010 | Multiple concurrent publishers | SC-ZENOH-FFI-012 | Active session |

### Level 3: Cross-Runtime Tests (F# ↔ Elixir)

| Test ID | Description | STAMP | Requires |
|---------|-------------|-------|----------|
| XR-FFI-001 | F# publish → Elixir NIF subscribe | SC-ZENOH-FFI-010 | Full mesh |
| XR-FFI-002 | Elixir NIF publish → F# FFI subscribe | SC-ZENOH-FFI-010 | Full mesh |
| XR-FFI-003 | Bidirectional message exchange | SC-ZENOH-FFI-010 | Full mesh |
| XR-FFI-004 | JSON message format compatibility | SC-ZENOH-FFI-003 | Full mesh |
| XR-FFI-005 | Boot checkpoint cross-runtime | SC-ZTEST-009 | Full mesh |

### Level 4: Performance Tests (Benchmarks)

| Test ID | Description | Target | STAMP |
|---------|-------------|--------|-------|
| PF-FFI-001 | Publish latency (single message) | < 10ms p99 | SC-ZTEST-003 |
| PF-FFI-002 | Publish throughput (sustained) | > 1000 msg/s | SC-ZENOH-FFI-015 |
| PF-FFI-003 | Subscribe poll latency | < 1ms p99 | SC-ZENOH-FFI-003 |
| PF-FFI-004 | Session open/close cycle | < 500ms | SC-ZENOH-FFI-001 |
| PF-FFI-005 | Memory under sustained load | < 50MB growth/hr | SC-ZENOH-FFI-019 |
| PF-FFI-006 | Channel saturation recovery | No crash | SC-ZENOH-FFI-007 |

### Level 5: FMEA Chaos Tests

| Test ID | Description | Failure Mode | STAMP |
|---------|-------------|--------------|-------|
| CH-FFI-001 | Kill zenoh-router mid-session | FM-FFI-005 | SC-ZTEST-008 |
| CH-FFI-002 | Double-free handle | FM-FFI-002 | SC-ZENOH-FFI-002 |
| CH-FFI-003 | Publish to closed session | FM-FFI-002 | SC-ZENOH-FFI-004 |
| CH-FFI-004 | Buffer too small for stats JSON | FM-FFI-004 | SC-ZENOH-FFI-005 |
| CH-FFI-005 | Subscriber overflow (> 1000 msgs) | FM-FFI-008 | SC-ZENOH-FFI-007 |
| CH-FFI-006 | Concurrent open/close from threads | FM-FFI-002 | SC-ZENOH-FFI-012 |
| CH-FFI-007 | Network partition during publish | FM-FFI-005 | SC-ZTEST-008 |

---

## 6. Implementation Phases

### Phase 1: Rust cdylib (COMPLETE)
- [x] `native/zenoh_ffi/Cargo.toml`
- [x] `native/zenoh_ffi/build.rs`
- [x] `native/zenoh_ffi/src/lib.rs` (9 extern "C" functions, ~680 lines)
- [ ] `cargo build --release` (in progress)
- [ ] `native/zenoh_ffi/generated/ZenohFfi.g.cs` (auto-generated)

### Phase 2: F# FFI Bridge (NEXT)
- [ ] Create `lib/cepaf/src/Cepaf/Zenoh/Core/ZenohFfiBridge.fs`
- [ ] Add to `Cepaf.fsproj` (after ZenohSerialization.fs, before ZenohNative.fs)
- [ ] Modify `ZenohNative.fs` SafeSession.OpenAsync to use FFI
- [ ] Modify `ZenohNative.fs` SafePublisher.PutAsync to use FFI
- [ ] Upgrade `ZenohPublish.fs` with real Zenoh step

### Phase 3: Build Integration
- [ ] Update `devenv.nix` with Rust build step + LD_LIBRARY_PATH
- [ ] Update `podman-compose-sil6-full-mesh.yml` with volume mount
- [ ] Verify `dotnet build` with FFI bridge compiles

### Phase 4: Testing & Verification
- [ ] Rust unit tests (`cargo test`)
- [ ] F# integration tests (Expecto)
- [ ] Cross-runtime tests (F# ↔ Elixir)
- [ ] Performance benchmarks
- [ ] FMEA chaos tests

---

## 7. 5-Order Effects Analysis

### Change: Add native Zenoh FFI to F# runtime

| Order | Time | Effect | Verification |
|---|---|---|---|
| 1st | Immediate | F# publishes reach Zenoh router (not just stderr/stdout) | IT-FFI-001 |
| 2nd | Seconds | Elixir subscribers receive F# messages, dashboards update | XR-FFI-001 |
| 3rd | Seconds-Minutes | Real-time cross-runtime test orchestration works | XR-FFI-005 |
| 4th | Minutes | Prajna cockpit shows live F# health, planning events flow | IT-FFI-004 |
| 5th | Minutes-Hours | Full SIL-6 mesh with F# as first-class Zenoh participant | PF-FFI-001 |

---

## 8. Dependencies

### Build-time
- `rustc` >= 1.75 (for zenoh 1.7 crate)
- `cargo` (Rust build system)
- `csbindgen` 2.0 (C# binding generator)
- `dotnet-sdk` 10.0 (F# compiler)

### Runtime
- `libzenoh_ffi.so` in LD_LIBRARY_PATH
- Zenoh router on port 7447 (or simulated fallback)
- `ZENOH_USE_NATIVE=true` environment variable

### Wire Protocol
- zenoh 1.7 (must match `native/zenoh_nif/Cargo.toml`)
- JSON message format (cross-FFI boundary)

---

## 9. Performance Optimization

### Publish Path (Hot Path)
1. **Zero-copy key**: F# pins string bytes, passes pointer directly
2. **Minimal allocation**: Reuse buffer for stats/poll output
3. **No JSON on publish**: Payload bytes pass through directly
4. **Tokio block_on**: Synchronous call into async runtime (< 1ms overhead)

### Subscribe Path (Warm Path)
1. **Crossbeam bounded channel**: Lock-free MPSC queue
2. **Batch poll**: Retrieve up to 100 messages per call (amortize FFI overhead)
3. **JSON only on poll output**: Messages serialized only when retrieved
4. **try_recv non-blocking**: No wait, immediate return if empty

### Memory
1. **Single tokio runtime**: 2 worker threads, shared across all sessions
2. **Bounded channels**: Max 1000 messages × ~1KB = ~1MB per subscription
3. **Drop on overflow**: No unbounded growth
4. **Arc sharing**: Session shared between subscribers without copying

---

## 10. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-03-18 | Claude Opus 4.6 | Initial comprehensive specification |
