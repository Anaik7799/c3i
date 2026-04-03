# Zenoh FFI Architecture Reference

> Version: 21.3.1-SIL6 | Date: 2026-03-28 | STAMP: SC-ZENOH-001, SC-FSH-016

## Overview

The Zenoh FFI layer provides native Zenoh protocol access from F# and Elixir runtimes
via a Rust cdylib (C ABI). This document describes the three-tier bridge architecture,
concurrency model, and observability instrumentation.

## Architecture Diagram

```
+------------------------------------------------------------------+
|                    ELIXIR / PHOENIX LIVEVIEW                      |
|  ZenohTelemetrySubscriber  |  ZenohNIF (Rustler)                |
+----------------------------+---------+---------------------------+
                                       |
                              Erlang NIF calls
                                       |
+----------------------------+---------+---------------------------+
|                    RUST CDYLIB (libzenoh_ffi.so)                 |
|                                                                   |
|  +-------------+  +-------------+  +-----------+  +----------+  |
|  | Session Mgmt|  | Pub/Sub     |  | Query     |  | Metrics  |  |
|  | open/close  |  | pub/sub/    |  | get/reply |  | 27 atomic|  |
|  | health      |  | unsub       |  |           |  | counters |  |
|  +------+------+  +------+------+  +-----+-----+  +----+-----+  |
|         |                |                |              |        |
|  +------+----------------+----------------+--------------+-----+ |
|  |              Tokio Runtime (async)                          | |
|  |  Semaphore(2) | spawn+channel | ffi_guard! panic catch     | |
|  +-----+--------------------------------------------------+---+ |
|        |                                                   |     |
|  +-----+---+                                        +-----+---+ |
|  | zenoh    |                                        | csbindgen| |
|  | 1.7 SDK  |                                        | 1.9 gen  | |
|  +----------+                                        +----------+ |
+------------------------------------------------------------------+
         |
    TCP/7447 (Zenoh wire protocol)
         |
+------------------------------------------------------------------+
|                    ZENOH ROUTER                                   |
|  zenoh-router container | port 7447 | mesh coordinator           |
+------------------------------------------------------------------+
```

## F# DllImport Bridge

```
+------------------------------------------------------------------+
|                    F# (.NET 10)                                   |
|                                                                   |
|  ZenohTypes.fs          ZenohFfiBridge.fs                        |
|  +------------------+   +------------------------------------+   |
|  | SessionConfig    |   | [<DllImport("libzenoh_ffi")>]      |   |
|  | PublisherConfig  |   | zenoh_session_open(cfg) -> handle  |   |
|  | SubscriberConfig |   | zenoh_session_close(h)             |   |
|  | QueryConfig      |   | zenoh_publish(h, key, payload)     |   |
|  | MetricsSnapshot  |   | zenoh_subscribe(h, key, cb)        |   |
|  +------------------+   | zenoh_unsubscribe(h, sub_id)       |   |
|                         | zenoh_get(h, key, cb)              |   |
|  Cepaf.Sentinel.MCP     | zenoh_queryable(h, key, cb)        |   |
|  +------------------+   | zenoh_metrics_snapshot() -> json   |   |
|  | 5 MCP Tools      |   | zenoh_is_available() -> bool       |   |
|  | zenoh_session    |   | ... (13 functions total)           |   |
|  | zenoh_pub        |   +------------------------------------+   |
|  | zenoh_sub        |                                            |
|  | zenoh_query      |   Environment:                             |
|  | sentinel         |     LD_LIBRARY_PATH=$PWD/target/release    |
|  +------------------+     ZENOH_USE_NATIVE=true                  |
+------------------------------------------------------------------+
```

## 13 C ABI Functions

| # | Function | Direction | Purpose |
|---|----------|-----------|---------|
| 1 | `zenoh_session_open` | F#/Elixir -> Rust | Open session to router |
| 2 | `zenoh_session_close` | F#/Elixir -> Rust | Close session gracefully |
| 3 | `zenoh_session_info` | F#/Elixir -> Rust | Session metadata |
| 4 | `zenoh_publish` | F#/Elixir -> Rust | Publish to key expression |
| 5 | `zenoh_subscribe` | F#/Elixir -> Rust | Subscribe with callback |
| 6 | `zenoh_unsubscribe` | F#/Elixir -> Rust | Remove subscription |
| 7 | `zenoh_get` | F#/Elixir -> Rust | Query key expression |
| 8 | `zenoh_queryable` | F#/Elixir -> Rust | Register queryable |
| 9 | `zenoh_delete` | F#/Elixir -> Rust | Delete key expression |
| 10 | `zenoh_is_available` | F#/Elixir -> Rust | Health check |
| 11 | `zenoh_metrics_snapshot` | F#/Elixir -> Rust | Get 27 atomic counters |
| 12 | `zenoh_reset_metrics` | F#/Elixir -> Rust | Reset counters |
| 13 | `zenoh_version` | F#/Elixir -> Rust | Library version string |

## Observability (27 Counters)

| Category | Counters | Type |
|----------|----------|------|
| Session | open_count, close_count, active_sessions | AtomicU64 (SeqCst) |
| Publish | pub_count, pub_bytes, pub_errors | AtomicU64 (SeqCst) |
| Subscribe | sub_count, unsub_count, msg_received | AtomicU64 (SeqCst) |
| Query | get_count, reply_count, query_errors | AtomicU64 (SeqCst) |
| Latency | pub_max_us, get_max_us, sub_max_us, open_max_us | AtomicU64 (CAS) |
| Histogram | 4 buckets per operation (< 1ms, < 10ms, < 100ms, >= 100ms) | AtomicU64 |

## 12 Runtime Invariants

| ID | Invariant | Verification |
|----|-----------|-------------|
| INV-1 | Session handle is non-null after open | Null check |
| INV-2 | Close on null handle returns error (no crash) | ffi_guard! |
| INV-3 | Publish requires open session | Handle validation |
| INV-4 | Subscribe callback is invoked on message | Channel pattern |
| INV-5 | Metrics counters are monotonically increasing | SeqCst ordering |
| INV-6 | Concurrent publishes do not corrupt state | Tokio semaphore(2) |
| INV-7 | Panic in callback does not crash runtime | ffi_guard! macro |
| INV-8 | Session close drains pending operations | Tokio join |
| INV-9 | Metrics snapshot is consistent | Atomic snapshot |
| INV-10 | Version string is valid UTF-8 | CStr conversion |
| INV-11 | Max latency uses lock-free CAS update | compare_exchange |
| INV-12 | Available check completes < 100ms | Timeout guard |

## Build Commands

```bash
# Build Rust cdylib
cargo build --release -p zenoh_ffi
# Output: target/release/libzenoh_ffi.so (6.1 MB)

# Build F# bridge
dotnet build lib/cepaf/src/Cepaf/Cepaf.fsproj

# Run F# tests (31 tests)
dotnet run --project lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj \
  --filter-test-list "ZenohFfiBridge" --summary
```

## Related Documents

- CLAUDE.md (Zenoh FFI Architecture section in MEMORY)
- docs/architecture/ZENOH_FFI_COMPREHENSIVE_SPECIFICATION.md
- docs/architecture/NIF_7_LEVEL_FRACTAL_ARCHITECTURE.md
- native/zenoh_ffi/src/lib.rs
- lib/cepaf/src/Cepaf/Zenoh/Core/ZenohFfiBridge.fs
