# 2026-03-22 10:35 — Constraint Sync Compiled Binary Optimization

## Context
- Branch: main
- Recent commits: 95f7fbea5 EVOLUTION RUN 2: Biomorphic Synchronization Complete
- Task: Performance optimization of constraint sync engine (SC-SYNC-DOC-011)
- Trigger: User directive to eliminate ~2s JIT overhead from `dotnet fsi` invocations

## Summary

Compiled the F# constraint sync script (`constraint_sync.fsx`) into a standalone binary (`constraint-sync.dll`), achieving **5-35x speedup** across all operation modes. The JIT compilation overhead (~2s per invocation) was the dominant cost — the actual census logic runs in ~500ms even on 2,257+ constraints across 393 families.

### Transformation Summary

| Mode | fsx (JIT) | Compiled | Speedup |
|------|-----------|----------|---------|
| `--cached` | 2.0s | 57ms | **35x** |
| `--inventory` | 2.1s | 84ms | **25x** |
| Dashboard | 2.5s | 500ms | **5x** |
| `--analysis` | 2.7s | 506ms | **5x** |
| `--full` | 2.9s | 517ms | **5.6x** |
| SessionStart hook | ~1.0s (bash rg) | ~449ms | **2.2x** |

## Technical Details

### Files Created/Modified

| File | Action | Description |
|------|--------|-------------|
| `lib/cepaf/src/Cepaf.ConstraintSync/Program.fs` | Created | Compiled version (~1,350 lines) |
| `lib/cepaf/src/Cepaf.ConstraintSync/Cepaf.ConstraintSync.fsproj` | Created | net10.0 project file |
| `scripts/verification/constraint_sync_check.sh` | Rewritten | SessionStart hook: binary-first, bash fallback |
| `.claude/rules/constraint-sync-mandatory.md` | Updated | §7.1: compiled binary preferred path |
| `CLAUDE.md` | Updated | AOR-SYNC-DOC-011, devenv command section |
| `devenv.nix` | Updated | `constraint-sync` alias with auto-build |

### Key Adaptations (fsx → compiled)

1. **Entry point**: `[<EntryPoint>] let main (argv: string[]) : int` replaces `System.Environment.GetCommandLineArgs()`
2. **Project root discovery**: Walk-up algorithm (`findProjectRoot`) finds root from any CWD, replacing fsx's `__SOURCE_DIRECTORY__`
3. **Parallel I/O**: `Array.Parallel.collect` for file scanning across 16 cores
4. **Return codes**: `int` returns instead of `exit()` calls for clean shutdown
5. **Assembly name**: `constraint-sync` (produces `constraint-sync.dll`, 153KB)

### SessionStart Hook Architecture

```
Session Start
    │
    ├─ Try compiled binary (dotnet exec constraint-sync.dll)
    │   └─ Success (~449ms) → exit 0
    │   └─ Failure → fall through
    │
    └─ Bash rg fallback (~1s)
        └─ rg-based counting of SC-*/AOR-* in code vs docs
        └─ Always works, no .NET dependency
```

### Devenv Integration

```nix
scripts.constraint-sync.exec = ''
  DLL="lib/cepaf/src/Cepaf.ConstraintSync/bin/Release/net10.0/constraint-sync.dll"
  if [ ! -f "$DLL" ]; then
    echo "Building constraint-sync binary..."
    dotnet build ... -c Release -v q
  fi
  dotnet exec "$DLL" "$@"
'';
```

### Why `dotnet exec` not raw binary

The compiled `constraint-sync` binary is framework-dependent (not self-contained). On NixOS with devenv, .NET runtime is installed in a non-standard Nix store path. Running the binary directly fails with "Download the .NET runtime". `dotnet exec` uses the SDK's runtime, which is always available in devenv shell.

## STAMP Compliance

| ID | Status | Notes |
|----|--------|-------|
| SC-SYNC-DOC-011 | ✅ UPDATED | F# engine sole authority — compiled binary preferred |
| SC-SYNC-DOC-003 | ✅ FASTER | SessionStart hook now ~449ms (was ~1s) |
| SC-SYNC-DOC-015 | ✅ | Cache auto-written, `--cached` mode 57ms |
| SC-SYNC-DOC-016 | ✅ | Cached retrieval 35x faster than fsx |
| SC-NET-001 | ✅ | net10.0 target framework |

### 4-Layer Impact Analysis
| Layer | Impact | Score |
|-------|--------|-------|
| L1-CODE | New fsproj + Program.fs, hook rewrite | 2 |
| L2-DOMAIN | No domain logic changes | 0 |
| L3-SYSTEM | SessionStart hook faster, devenv alias added | 1 |
| L4-ECOSYSTEM | Rule file + CLAUDE.md documentation updated | 1 |
| **Total** | | **4 (LOW RISK)** |

## Architecture Decision Records

### ADR-001: Compiled Binary vs Self-Contained Publish
**Decision**: Use framework-dependent `dotnet exec` invocation, not self-contained publish.
**Rationale**: Self-contained publish would produce a ~70MB binary (includes .NET runtime). Framework-dependent DLL is 153KB and uses the devenv SDK runtime. NixOS non-standard paths make raw binary execution unreliable.
**Trade-off**: Requires `dotnet` on PATH (always true in devenv shell).

### ADR-002: Bash Fallback in SessionStart Hook
**Decision**: Keep bash `rg`-based fallback when compiled binary not available.
**Rationale**: First-time setup or clean builds may not have the compiled binary. The bash fallback ensures the hook never fails, providing metrics even without .NET. Cost is ~1s vs ~449ms — acceptable degradation.

### ADR-003: Auto-Build in Devenv Alias
**Decision**: `constraint-sync` devenv alias auto-builds if DLL missing.
**Rationale**: Eliminates manual build step. First invocation takes ~3s (build) + ~500ms (run), subsequent invocations skip build. Transparent to user.

## Next Steps

1. **Commit changes** — 6 files created/modified
2. **Maintain binary** — Rebuild after Program.fs changes (`dotnet build -c Release`)
3. **Consider CI integration** — Add compiled binary build to CI pipeline
4. **Monitor SessionStart times** — Target < 500ms consistently

## KPIs

- Files changed: 6 (2 created, 4 modified)
- Lines added: ~1,400+ (Program.fs) + ~30 (hook/config/docs)
- Lines removed: ~15 (replaced hook logic)
- Tests: N/A (binary produces same output as fsx — verified via benchmark)
- Warnings: 0
- SessionStart improvement: ~1s → ~449ms (2.2x)
- Cached mode improvement: 2.0s → 57ms (35x)
- Full analysis improvement: 2.9s → 517ms (5.6x)
- Binary size: 153KB (constraint-sync.dll)
- Execution time: ~15 minutes (create, build, benchmark, integrate)

## Knowledge Density

$$\rho_K = \frac{3 \text{ ADRs} + 5 \text{ constraints} + 9 \text{ KPIs}}{117 \text{ lines}} = 0.15$$
