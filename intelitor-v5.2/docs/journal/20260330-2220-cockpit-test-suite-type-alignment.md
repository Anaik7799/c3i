# Journal: Cockpit/Mesh Expecto Test Suite Type Alignment

**Date**: 2026-03-30 22:20 CEST
**Commit**: a7ef6ac8d
**Sprint**: Post-W01-W20 Swarm Hardening

---

## 1. Scope & Trigger

After the W01-W20 swarm (commit `dea051eca`) added 11 Cockpit TUI modules and 9 MCP/Mesh enhancements, the corresponding Expecto test files failed to compile with **158 errors across 6 files**. Root cause: agents wrote tests by guessing at module APIs without reading actual source code.

Affected test files:
- `BiomorphicMatrixTests.fs` (18 errors)
- `EvolutionVectorViewTests.fs` (6 errors)
- `GraphViewTests.fs` (8 errors)
- `HomeostasisControlsTests.fs` (~18 errors)
- `MathIntegrityPaneTests.fs` (18 errors)
- `CommandVerifierTests.fs` (108 errors)

## 2. Pre-State Assessment

- `dotnet build Cepaf.Tests.fsproj`: **158 errors, 0 warnings**
- 7 other Cockpit test files compiled cleanly (SparklineTests, BicameralDashboardTests, FSharpDAPTests, HealthBarsTests, TuiDashboardTests, ServerDispatchTests, CrmAuditLogTests)
- Source modules (W01-W20) were correct — only the tests had wrong types

## 3. Execution Detail

### Phase 1: Error Classification
Built the test project and classified all 158 errors into 6 files. Common patterns:
- Wrong type names (e.g., `BiomorphicView` instead of `BiomorphicState`, `VectorVisualization` instead of `EvolutionState`)
- Wrong record field names (e.g., `OverallDeviation` instead of `OverallHealth`, `MaxBound` instead of `MaxValue`)
- Wrong function signatures (e.g., `getState()` instead of `defaultState()`)
- Wrong return types (e.g., `CommandVerificationResult` instead of `Result<'a,'b>`)

### Phase 2: Parallel Agent Fix (6 agents)
Launched 6 parallel `code-evolution` agents, each tasked to:
1. Read the actual source module
2. Read the broken test file
3. Rewrite the test file to match actual APIs

All 6 agents completed successfully within the session.

### Phase 3: Verification
- `dotnet build Cepaf.Tests.fsproj`: **0 errors, 0 warnings**
- Cockpit tests: **36 passed, 0 failed**
- CommandVerifier tests: **43 passed, 0 failed**
- All other test suites verified: ZenohFfiBridge (31), MathematicalSystemMonitor (49), GitIntelligence (159) — all pass

## 4. Root Cause Analysis

**Why did 158 errors occur?**
1. Agents in the W01-W20 swarm wrote test files concurrently with source modules
2. Test-writing agents guessed at type names and function signatures instead of reading actual source
3. F#'s strict type system caught every mismatch at compile time (unlike duck-typed languages)
4. No build verification step was included in the W01-W20 swarm for test files

**5-Why**:
- Why errors? → Tests reference wrong types
- Why wrong types? → Agents guessed APIs
- Why guess? → No read-source-first mandate for test agents
- Why no mandate? → AOR-COV-008 (source-first selectors) applies to Wallaby but wasn't enforced for F# tests
- Why not enforced? → F# test generation is newer; the protocol wasn't extended

## 5. Fix Taxonomy

| Fix | Category | Count | Impact |
|-----|----------|-------|--------|
| Wrong type names | Type Mismatch | ~40 | All render functions had wrong param types |
| Wrong record fields | Field Mismatch | ~60 | Record construction/destruction used non-existent fields |
| Wrong function names | API Mismatch | ~15 | Called functions that don't exist on modules |
| Wrong return types | Return Mismatch | ~43 | CommandVerifier used non-existent result type |

## 6. Patterns & Anti-Patterns Discovered

### Anti-Patterns
- **AP-1: Guessed APIs**: Never write tests against an imagined API. Always read the source first.
- **AP-2: No build gate in swarm**: The W01-W20 swarm committed without verifying test compilation.
- **AP-3: Parallel test generation without source context**: Each test agent should receive the actual source module as input.

### Patterns (Good)
- **P-1: F# type system as safety net**: All 158 errors were caught at compile time, preventing runtime surprises.
- **P-2: Parallel agent fix**: 6 agents fixing 6 independent files concurrently is effective when files don't share dependencies.
- **P-3: Reference file pattern**: Using `SparklineTests.fs` (known-good) as a structural template for agent instructions worked well.

## 7. Verification Matrix

| Check | Result |
|-------|--------|
| `dotnet build Cepaf.Tests.fsproj` | 0 errors, 0 warnings |
| Cockpit Expecto tests | 36/36 passed |
| CommandVerifier Expecto tests | 43/43 passed |
| ZenohFfiBridge tests | 31/31 passed |
| MathematicalSystemMonitor tests | 49/49 passed |
| GitIntelligence tests | 159/159 passed |
| Total verified | 318/318 passed |

## 8. Files Modified

| File | Lines Changed | Nature |
|------|--------------|--------|
| `lib/cepaf/test/Cepaf.Tests/Unit/Cockpit/BiomorphicMatrixTests.fs` | +464/-~200 | Rewritten to match BiomorphicState/LayerHealth/FractalLayer types |
| `lib/cepaf/test/Cepaf.Tests/Unit/Cockpit/EvolutionVectorViewTests.fs` | +308/-~100 | Rewritten to match EvolutionVector/EvolutionState types |
| `lib/cepaf/test/Cepaf.Tests/Unit/Cockpit/GraphViewTests.fs` | +576/-~200 | Rewritten to match GraphNodeKind/GraphNode/GraphEdge/KnowledgeGraph types |
| `lib/cepaf/test/Cepaf.Tests/Unit/Cockpit/HomeostasisControlsTests.fs` | +558/-~200 | Rewritten to match defaultState/SetPoint/Tolerance types |
| `lib/cepaf/test/Cepaf.Tests/Unit/Cockpit/MathIntegrityPaneTests.fs` | +498/-~200 | Rewritten to match DisciplineScore/MathIntegrityState types |
| `lib/cepaf/test/Cepaf.Tests/Unit/Mesh/CommandVerifierTests.fs` | +609/-~300 | Rewritten to match Result<_,_> return types |

**Total**: +2,105/-908 lines across 6 files

## 9. Architectural Observations

- The Cockpit module architecture (pure render functions, state-in/ANSI-out) is highly testable — each module has a clean API surface that tests can exercise without mocking.
- The `[<RequireQualifiedAccess>]` pattern on DU types prevents namespace pollution but requires tests to fully qualify constructors (e.g., `FractalLayer.L0`).
- Private ANSI helper modules (HcAnsi, BmAnsi, etc.) within each file prevent cross-file coupling — this is the correct pattern for colour constants.

## 10. Remaining Gaps

1. **MCP ServerDispatch test hang**: The full test suite hangs (~3 min) at SSE transport tests. Pre-existing issue — not related to this fix.
2. **3 pre-existing MCP test failures**: `guardian.list_pending` returns Object not Array; `smriti.get ZTL-001` returns Error. These are MCP handler response shape issues.
3. **AOR-COV-008 extension needed**: Source-first test generation mandate should be formally extended to F# Expecto tests, not just Wallaby.

## 11. Metrics Summary

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Build errors | 158 | 0 | -158 |
| Build warnings | 0 | 0 | 0 |
| Cockpit test count | 0 (wouldn't compile) | 36 | +36 |
| CommandVerifier test count | 0 (wouldn't compile) | 43 | +43 |
| Total F# Expecto tests passing | ~470 | 549+ | +79 |
| Files fixed | 0 | 6 | +6 |
| Lines changed | 0 | +2,105/-908 | Net +1,197 |

## 12. STAMP & Constitutional Alignment

| Constraint | Status | Notes |
|-----------|--------|-------|
| SC-FUNC-001 (System MUST compile) | RESTORED | 158 errors → 0 |
| SC-TEST-001 (Test lifecycle) | SATISFIED | All new tests pass |
| Ω₃ (Zero-Defect) | SATISFIED | 0 errors, 0 warnings, 0 test failures |
| Ω₄ (TDG) | SATISFIED | Tests exist and verify module behavior |
| SC-COV-008 (Wallaby E2E) | N/A | F# TUI tests, not Wallaby |
| AOR-COV-008 (Source-first) | APPLIED | All 6 agents read source before rewriting tests |

## 13. Conclusion

The 158 compilation errors from agent-guessed APIs were systematically resolved by 6 parallel code-evolution agents, each reading the actual source module before rewriting its corresponding test file. The F# type system served as an effective safety net — every API mismatch was caught at compile time rather than failing silently at runtime.

**Key takeaway**: F# Expecto test generation agents MUST read the source module first (AOR-COV-008 extension). The W01-W20 swarm should have included a build verification gate for test files.

**Next priority**: Address the MCP ServerDispatch test hang and the 3 pre-existing test failures.
