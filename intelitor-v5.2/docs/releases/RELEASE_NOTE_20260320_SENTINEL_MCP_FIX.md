# RELEASE NOTE: Sentinel MCP Server — FFI JSON Deserialization Fix
**Tag**: SENTINEL-MCP-FIX-20260320
**Date**: 2026-03-20
**Status**: VERIFIED (15/15 MCP calls pass)
**Severity**: P1 (2 tools broken — poll, stats)

---

## 1.0 SUMMARY

Fixed JSON deserialization failures in the `sentinel-zenoh` MCP server that prevented
`zenoh_sub poll` and `zenoh_session stats` from returning data. The Sentinel MCP server
now passes all 15 tool invocations across its 5 tools.

## 2.0 ROOT CAUSE

`System.Text.Json` on .NET 10 cannot construct F# record types via
`JsonSerializer.Deserialize<T>()` even when annotated with `[<CLIMutable>]`, if the
types reside inside a `module private`. The reflection-based deserializer fails with:

```
Deserialization of types without a parameterless constructor, a singular parameterized
constructor, or a parameterized constructor annotated with 'JsonConstructorAttribute'
is not supported. Type 'Cepaf.Zenoh.Core.FfiJson+FfiMessage'.
```

**Affected functions**: `ZenohFfiBridge.poll`, `ZenohFfiBridge.get`, `ZenohFfiBridge.sessionStats`

## 3.0 FIX APPLIED

Replaced reflection-based `JsonSerializer.Deserialize<T>` with manual `JsonDocument`
parsing — the same robust pattern already used in `SentinelTools.fs`.

### 3.1 Files Modified

| File | Change |
|------|--------|
| `lib/cepaf/src/Cepaf/Zenoh/Core/ZenohFfiBridge.fs` | Replaced `FfiMessage`/`FfiStats` record deserialization with `JsonDocument`-based tuple extraction |

### 3.2 Before (broken)

```fsharp
module private FfiJson =
    [<CLIMutable>]
    type FfiMessage = { key: string; payload: string; timestamp: Nullable<int64>; encoding: string }
    [<CLIMutable>]
    type FfiStats = { connected: bool; messages_sent: uint64; ... }

// Call sites used:
let messages = JsonSerializer.Deserialize<FfiJson.FfiMessage[]>(json)  // FAILS
let stats = JsonSerializer.Deserialize<FfiJson.FfiStats>(json)        // FAILS
```

### 3.3 After (fixed)

```fsharp
module private FfiJson =
    let parseMessage (elem: JsonElement) : (string * string * int64 option * string) =
        let s (name: string) = match elem.TryGetProperty(name) with | true, p -> try p.GetString() with _ -> "" | _ -> ""
        let ts = match elem.TryGetProperty("timestamp") with | true, p when p.ValueKind = JsonValueKind.Number -> Some (p.GetInt64()) | _ -> None
        (s "key", s "payload", ts, s "encoding")

    let parseMessages (json: string) : (string * string * int64 option * string) list =
        use doc = JsonDocument.Parse(json)
        [ for elem in doc.RootElement.EnumerateArray() -> parseMessage elem ]

    let parseStats (json: string) : (bool * uint64 * uint64 * uint64 * uint64 * string) =
        use doc = JsonDocument.Parse(json)
        let r = doc.RootElement
        let b (name: string) = match r.TryGetProperty(name) with | true, p -> try p.GetBoolean() with _ -> false | _ -> false
        let u (name: string) = match r.TryGetProperty(name) with | true, p -> try p.GetUInt64() with _ -> 0UL | _ -> 0UL
        let s (name: string) = match r.TryGetProperty(name) with | true, p -> try p.GetString() with _ -> "" | _ -> ""
        (b "connected", u "messages_sent", u "messages_received", u "uptime_seconds", u "last_publish_latency_us", s "session_id")
```

## 4.0 VERIFICATION

### 4.1 MCP Protocol Test (15/15 PASS)

| ID | Tool | Action | Status | Response |
|----|------|--------|--------|----------|
| 1 | `initialize` | handshake | PASS | v21.3.0, protocol 2025-03-26 |
| 2 | `tools/list` | discovery | PASS | 5 tools registered |
| 3 | `zenoh_query` | metrics | PASS | 27 atomic counters |
| 4 | `zenoh_query` | verify | PASS | 12/12 invariants, all_pass=true |
| 5 | `sentinel` | status | PASS | no session (expected offline) |
| 6 | `sentinel` | health | PASS | zeroed metrics (no data source) |
| 7 | `sentinel` | threats | PASS | 0 threats |
| 10 | `zenoh_session` | open | PASS | connected, peer mode |
| 11 | `zenoh_pub` | publish | PASS | 47 bytes to indrajaal/test/mcp |
| 12 | `zenoh_sub` | subscribe | PASS | sub_1 on indrajaal/test/** |
| 13 | `zenoh_pub` | publish | PASS | 14 bytes to indrajaal/test/mcp2 |
| 14 | `zenoh_sub` | **poll** | **PASS** | 1 message received (was FAIL) |
| 15 | `zenoh_session` | **stats** | **PASS** | connected=true, published=2, latency=0.03ms (was FAIL) |
| 16 | `zenoh_sub` | unsubscribe | PASS | removed sub_1 |
| 17 | `zenoh_session` | close | PASS | closed cleanly |

### 4.2 F# Unit Tests (31/31 PASS)

```
ZenohFfiBridge test suite: 31 passed, 0 failed, 0 errored
  - 9 Metrics tests
  - 12 Verify/invariant tests
  - 2 Availability tests
  - 8 Null safety tests
```

### 4.3 Build Verification

| Project | Errors | Warnings |
|---------|--------|----------|
| Cepaf.fsproj | 0 | 12 (pre-existing) |
| Cepaf.Sentinel.MCP.fsproj | 0 | 25 (pre-existing) |

## 5.0 STAMP CONSTRAINTS ADDRESSED

| ID | Constraint | Status |
|----|------------|--------|
| SC-ZENOH-FFI-003 | JSON serialization for cross-FFI messages | FIXED |
| SC-ZENOH-FFI-021 | Session stats include latency metrics | FIXED |
| SC-PRAJNA-004 | Sentinel integration | VERIFIED |
| SC-ZEN-001 | Zenoh unified IPC | VERIFIED |

## 6.0 FMEA

| Failure Mode | Severity | Occurrence | Detection | RPN | Status |
|--------------|----------|------------|-----------|-----|--------|
| JsonSerializer fails on F# records in private module (.NET 10) | 7 | 8 | 3 | 168 | MITIGATED — manual JsonDocument parsing |
| Poll returns 0 messages (timing) | 3 | 4 | 8 | 96 | ACCEPTED — async nature of pub/sub |

## 7.0 5-ORDER EFFECTS

| Order | Effect |
|-------|--------|
| 1st | `poll` and `sessionStats` return data instead of errors |
| 2nd | Sentinel MCP server fully functional — all 5 tools operational |
| 3rd | Claude Code can use sentinel-zenoh MCP for live Zenoh pub/sub and health monitoring |
| 4th | Prajna cockpit integration enabled via MCP — real-time threat/health data accessible |
| 5th | Full MCP-mediated observability stack operational for SIL-6 compliance |

## 8.0 KNOWN LIMITATIONS

- Sentinel `health`/`threats` return zeroed data when Zenoh router is not running (expected)
- Poll may return 0 messages if publish→subscribe→poll sequence is too fast (async timing)
- Pre-existing F# warnings (25) unrelated to this fix

## 9.0 ROLLBACK

```bash
# Git revert
git revert <commit-sha>

# Rebuild
dotnet build lib/cepaf/src/Cepaf/Cepaf.fsproj
dotnet build lib/cepaf/src/Cepaf.Sentinel.MCP/Cepaf.Sentinel.MCP.fsproj -c Release
```
