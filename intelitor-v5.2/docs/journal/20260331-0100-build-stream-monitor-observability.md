# Journal: Build Stream Monitor — Real-Time Container Build Observability
**Timestamp**: 20260331-0100 CEST
**Sprint**: 88+ (Post-Evolution Hardening)
**Author**: Claude Opus 4.6

---

## 1. Scope & Trigger

**Trigger**: User directive to eliminate "hung terminal" UX during 10-15 minute container image builds. The existing `SIL6MeshCLI.Exec()` and `PanopticIgnition.exec()` methods use buffered `Process.WaitForExit()` with `ReadToEnd()`, providing zero intermediate feedback. The user specifically requested:
- Real-time build progress with step tracking and ETA
- Zenoh telemetry streaming for every build step
- Heartbeat display during idle periods to show the system is alive
- High-fidelity summary boxes after build completion

**Scope**: New module `BuildStreamMonitor.fs` + integration into 3 call sites across 2 existing files.

---

## 2. Pre-State Assessment

| Component | Pre-State | Issue |
|-----------|-----------|-------|
| `SIL6MeshCLI.Exec()` (line 465) | Buffered `ReadToEnd()` + `WaitForExit()` | Zero feedback during execution |
| `SIL6MeshCLI.ExecVerbose()` (line 488) | Streaming but raw line display only | No step parsing, no ETA, no Zenoh |
| `SIL6MeshCLI.BootContainer()` (line 544) | Static 0%→100% progress bar | No intermediate states, no heartbeat |
| `PanopticIgnition.exec()` (line 92) | Buffered execution | Zero feedback |
| `PanopticIgnition.geneticResynthesis()` | `Thread.Sleep(200)` simulation | No real builds, no streaming |
| `SIL6MeshCLI.Down()` phase 3 | `ExecVerbose` for compose down | Raw output, no Zenoh telemetry |

---

## 3. Execution Detail

### 3.1 BuildStreamMonitor.fs Created (340 lines)

New module at `lib/cepaf/src/Cepaf/Mesh/BuildStreamMonitor.fs` providing:

**Types**:
- `BuildStep` — parsed step metadata (number, total, instruction, cache hit, duration)
- `BuildProgress` — live state (completed steps, ETA, cache hits/misses, errors, warnings)
- `BuildResult` — final result (success, exit code, step durations, image ID, errors)
- `CommandStreamResult` — result for non-build commands (output/error line counts)

**EmaCalculator** — Exponential Moving Average (alpha=0.3) for step duration prediction, enabling dynamic ETA that improves as more steps complete.

**Regex parsers** (compiled, 6 patterns):
- `STEP N/M: instruction` — step progress
- `Using cache / CACHED` — cache hit detection
- `error / COPY failed / RUN returned non-zero` — error detection
- `WARNING / deprecated` — warning detection
- `Successfully built [hash]` — image ID extraction
- `COMMIT [tag]` — final image tag

**Core functions**:
1. `streamBuild` — Full podman build streaming with step parsing, ETA, Zenoh telemetry per step, heartbeat ticker, and summary box. Replaces buffered exec for image builds.
2. `streamCommand` — Lightweight streaming for compose up/down commands with heartbeat, line counting, and Zenoh telemetry.

**Heartbeat mechanism**: Background thread at 5s intervals prints elapsed time and current step when no output received for >4.5s, preventing the "hung terminal" perception.

### 3.2 Integration Points

| Call Site | Change | Impact |
|-----------|--------|--------|
| `SIL6MeshCLI.BootContainer()` | `ExecVerbose` → `BuildStreamMonitor.streamCommand` | Live progress with heartbeat for compose up |
| `SIL6MeshCLI.Down()` phase 3 | `ExecVerbose` → `BuildStreamMonitor.streamCommand` | Live progress with heartbeat for compose down |
| `PanopticIgnition.geneticResynthesis()` | `Thread.Sleep(200)` → `BuildStreamMonitor.streamBuild` | Real podman builds with step tracking + ETA |

### 3.3 Cepaf.fsproj Update

Inserted `BuildStreamMonitor.fs` after `Artifacts.fs` and before `PanopticIgnition.fs` in the compilation order. F# compiles in file order, so BuildStreamMonitor needs ZenohPublish (compiled earlier) and PanopticIgnition needs BuildStreamMonitor (compiled later).

---

## 4. Root Cause Analysis

**Root cause of "hung terminal" UX**: Two independent buffered execution patterns.

1. `SIL6MeshCLI.Exec()` reads stdout/stderr with `ReadToEnd()` before `WaitForExit()` — standard .NET anti-pattern that blocks until process finishes.
2. `PanopticIgnition.exec()` uses the same pattern.
3. `ExecVerbose` was an improvement (streaming) but lacked parsing — raw lines with no semantic understanding of build steps.

**5-Why**:
1. Why is the terminal hung? → No output for 10-15 minutes during app build
2. Why no output? → `Exec()` buffers everything until process exits
3. Why buffered? → Original implementation prioritized simplicity over UX
4. Why not `ExecVerbose`? → `ExecVerbose` was only used for compose up, not for podman build
5. Why not parse the output? → No build-aware output parser existed

---

## 5. Fix Taxonomy

| Category | Description |
|----------|-------------|
| **New Module** | `BuildStreamMonitor.fs` — 340 lines, 2 public functions, 6 regex parsers, EMA calculator |
| **Integration** | 3 call sites in 2 files replaced with streaming variants |
| **Telemetry** | Zenoh checkpoints per build step (CP-BUILD-{name}-S{N}), start/done events |
| **UX** | ANSI progress bars, cache hit indicators, heartbeat ticker, summary boxes |
| **Compilation Order** | `Cepaf.fsproj` updated — BuildStreamMonitor.fs inserted between Artifacts.fs and PanopticIgnition.fs |

---

## 6. Patterns & Anti-Patterns Discovered

### Patterns (Positive)
- **EMA for ETA**: Using exponential moving average (alpha=0.3) gives responsive ETA that converges quickly — cached steps (~0ms) pull the average down immediately, while slow compilation steps (~60s) don't cause wild swings.
- **Heartbeat thread**: Background thread at 5s intervals solves the "is it hung?" problem universally — works for any long-running subprocess.
- **Dual stderr/stdout parsing**: Podman sends build steps to stderr in some versions and stdout in others; parsing both catches all cases.
- **Compiled regex**: Using `RegexOptions.Compiled` for patterns that match every output line is a significant performance win.

### Anti-Patterns (Avoided)
- **Buffered ReadToEnd**: Never use `proc.StandardOutput.ReadToEnd()` before `WaitForExit()` for long-running processes — it provides zero feedback.
- **Thread.Sleep simulation**: `Thread.Sleep(200)` in geneticResynthesis was a placeholder that gave false confidence — builds looked fast but were never actually happening.
- **Static progress bars**: The 0%→100% jump pattern (`printf "0%%"` ... `printf "100%%"`) is worse than no progress bar — it misleads the operator about actual progress.

---

## 7. Verification Matrix

| Check | Result |
|-------|--------|
| F# Debug build | 0 errors, 0 warnings |
| F# Release build | 0 errors, 0 new warnings (1 pre-existing FS3511 in ZenohQuorum.fs) |
| Compilation order | BuildStreamMonitor.fs correctly positioned after ZenohPublish.fs, before PanopticIgnition.fs |
| Type compatibility | BuildResult/CommandStreamResult types consumed correctly at all 3 call sites |
| Zenoh checkpoint naming | Follows existing CP-BOOT-{id}-{seq} convention with CP-BUILD-{name}-S{N} extension |
| No breaking changes | ExecVerbose still exists for other callers; only BootContainer/Down/geneticResynthesis changed |

---

## 8. Files Modified

| File | Action | Lines Changed |
|------|--------|---------------|
| `lib/cepaf/src/Cepaf/Mesh/BuildStreamMonitor.fs` | **Created** | +340 lines |
| `lib/cepaf/src/Cepaf/Cepaf.fsproj` | Modified | +2 lines (Compile Include + comment) |
| `lib/cepaf/src/Cepaf/Mesh/SIL6MeshCLI.fs` | Modified | 2 call sites changed (BootContainer, Down) |
| `lib/cepaf/src/Cepaf/Mesh/PanopticIgnition.fs` | Modified | 1 call site changed (geneticResynthesis) |

**Total**: 1 file created, 3 files modified, ~350 lines added, ~15 lines replaced.

---

## 9. Architectural Observations

- **Triple-write pattern preserved**: BuildStreamMonitor uses `ZenohPublish.publish` which internally does stderr log + native Zenoh FFI + stdout JSON, maintaining the SC-ZTEST-008 invariant.
- **EMA alpha tuning**: 0.3 balances responsiveness (new data weighted 30%) with stability (history weighted 70%). For builds where early steps are fast (FROM, COPY) and later steps are slow (RUN mix compile), this gives useful ETA by step 3-4.
- **No MCP daemon in this PR**: The MCP daemon lifecycle (start/stop/status) is a separate concern that requires the Cepaf.Mcp.Server to be refactored for persistent operation. Deferred to a follow-up task.
- **Heartbeat CancellationToken**: Using `CancellationTokenSource` + `Thread.Sleep` in heartbeat thread rather than `Task.Delay` because the F# codebase convention uses threads over async tasks for background monitoring.

---

## 10. Remaining Gaps

| Gap | Priority | Description |
|-----|----------|-------------|
| MCP daemon lifecycle | P2 | `Mcp` command in SIL6MeshCLI is still a stub — needs persistent MCP server mode |
| OTEL integration | P2 | BuildStreamMonitor doesn't emit OpenTelemetry spans (only Zenoh + console) |
| Build cache analysis | P3 | Could track cache hit ratio trends over time in DuckDB |
| Multi-stage build parsing | P3 | Multi-stage Docker builds (`FROM ... AS builder`) have nested step numbering |
| Parallel build streams | P3 | When building multiple containers simultaneously, interleaved output needs multiplexing |

---

## 11. Metrics Summary

| Metric | Value |
|--------|-------|
| New module size | 340 lines |
| Public API surface | 2 functions (`streamBuild`, `streamCommand`) |
| Regex patterns | 6 compiled |
| Zenoh checkpoints added | 4 new patterns (BUILD-START, BUILD-S{N}, BUILD-DONE, CMD-START/DONE) |
| Call sites replaced | 3 (BootContainer, Down, geneticResynthesis) |
| Build time impact | +0s (no new dependencies) |
| F# compilation order | Verified correct (after Artifacts.fs, before PanopticIgnition.fs) |

---

## 12. STAMP & Constitutional Alignment

| Constraint | Status | Notes |
|------------|--------|-------|
| SC-IGNITE-004 | **SATISFIED** | High-fidelity dashboard shows "Thinking" and real-time synthesis progress |
| SC-HMI-010 | **SATISFIED** | Vibrant chromatic feedback — color-coded progress bars (blue→cyan→green) |
| SC-CTRL-007 | **SATISFIED** | Telemetry for all operations via Zenoh checkpoints |
| SC-ZENOH-001 | **SATISFIED** | Zenoh publish on every build step + start/complete |
| SC-FUNC-001 | **VERIFIED** | System compiles (0 errors, 0 warnings) |
| Omega-1 (Patient Mode) | **HONORED** | 15-minute timeout for app builds, heartbeat prevents premature kill |
| Psi-3 (Verification) | **SATISFIED** | Build results include step durations, cache hits, errors — all verifiable |

---

## 13. Conclusion

BuildStreamMonitor eliminates the "hung terminal" anti-pattern by replacing buffered `Process.WaitForExit()` with streaming output parsing at 3 critical call sites. The EMA-based ETA calculator provides increasingly accurate time estimates as builds progress. Every build step emits a Zenoh checkpoint, enabling external monitoring via the Sentinel MCP server. The heartbeat thread ensures the operator always sees activity, even during long compilation steps within the container.

**Key UX improvement**: An operator watching a 15-minute app image build now sees `STEP 12/28: RUN mix compile --jobs 16 | ETA: 4m 22s` instead of a blank terminal for 15 minutes.
