# GA Release Verification Checklist

> Version: 21.3.1-SIL6 | Date: 2026-03-28 | STAMP: SC-CI-005, SC-CI-007, SC-FUNC-006

## Overview

This checklist defines the 15 mandatory verification steps that MUST pass before any
Indrajaal release is promoted to General Availability. Each step maps to a STAMP
constraint and has a clear pass/fail criterion.

## Gate 1: Compilation & Build (Steps 1-4)

| # | Step | Command | Pass Criteria | Checked |
|---|------|---------|---------------|---------|
| 1 | Elixir compilation | `NO_TIMEOUT=true PATIENT_MODE=enabled SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" mix compile --jobs 16` | 0 errors, 0 warnings | [ ] |
| 2 | F# compilation | `dotnet build lib/cepaf/src/Cepaf/Cepaf.fsproj` | 0 errors, 0 warnings | [ ] |
| 3 | Rust cdylib build | `cargo build --release -p zenoh_ffi` | 0 errors | [ ] |
| 4 | Container images build | `podman build` for all 4 images | All succeed | [ ] |

## Gate 2: Test Suite (Steps 5-8)

| # | Step | Command | Pass Criteria | Checked |
|---|------|---------|---------------|---------|
| 5 | Elixir unit tests | `MIX_ENV=test mix test` | 0 failures | [ ] |
| 6 | F# Expecto tests | `dotnet run --project Cepaf.Tests -- --summary` | 549+ pass, 0 fail | [ ] |
| 7 | Wallaby E2E tests | `MIX_ENV=test mix test --only wallaby` | All pass | [ ] |
| 8 | Coverage threshold | `mix test --cover` | >= 95% overall | [ ] |

## Gate 3: Code Quality (Steps 9-11)

| # | Step | Command | Pass Criteria | Checked |
|---|------|---------|---------------|---------|
| 9 | Formatting | `mix format --check-formatted` | No changes needed | [ ] |
| 10 | Credo strict | `mix credo --strict` | 0 issues | [ ] |
| 11 | Sobelow security | `mix sobelow` | 0 findings | [ ] |

## Gate 4: Integration & Safety (Steps 12-15)

| # | Step | Command | Pass Criteria | Checked |
|---|------|---------|---------------|---------|
| 12 | Container boot | `./sa-up && ./sa-status` | All 15 nodes healthy | [ ] |
| 13 | 2oo3 voting | `./sa-verify` | PASS | [ ] |
| 14 | Constraint sync | `dotnet exec constraint-sync.dll` | Gap ratio <= 1.5:1 | [ ] |
| 15 | SIL-6 checklist | See sil6_compliance_checklist.md | All 20 items pass | [ ] |

## Version Bump Protocol

```bash
# After all 15 steps pass:
# 1. Update version in mix.exs
# 2. Update CLAUDE.md header version
# 3. Update lib/indrajaal/version.ex @version
# 4. Create CHANGELOG.md entry
# 5. Tag release
git tag -a v21.3.1 -m "GA release v21.3.1-SIL6"
```

## Release Artifact Checklist

| Artifact | Location | Verified |
|----------|----------|----------|
| Container images (4) | `localhost/` registry | [ ] |
| CHANGELOG.md updated | Root directory | [ ] |
| Release notes | docs/releases/ | [ ] |
| STAMP master list current | docs/safety/ | [ ] |
| Journal entry | docs/journal/ | [ ] |

## Abort Criteria

The release MUST be aborted if any of the following occur:
- Any compilation error or warning
- Any test failure
- Credo issue count > 0
- Coverage < 95%
- Container boot fails
- 2oo3 voting fails
- Constraint sync gap > 1.5:1

## Sign-Off

| Role | Name | Date | All 15 Steps Pass |
|------|------|------|--------------------|
| Release Engineer | | | [ ] |
| QA Lead | | | [ ] |
| Safety Officer | | | [ ] |

## Related Documents

- CLAUDE.md Section 1.0 (Axiom 3: Zero-Defect)
- docs/operations/sil6_compliance_checklist.md
- docs/safety/BICAMERAL_RELEASE_PROTOCOL.md
- .claude/rules/functional-invariant.md
