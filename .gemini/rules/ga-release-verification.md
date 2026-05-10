---
paths:
- scripts/ga-release/**/*.exs
- docs/verification/**/*.md
- test/features/ga_release*.feature
---
# GA Release v21.2.1-SIL6 Verification Rules
# STAMP/AOR Reference
> SC-GA-001 to SC-GA-010 (all VERIFIED), AOR-GA-001 to AOR-GA-008 — see GEMINI.md §5.0, §9.0
> Key gates: 0 errors/warnings, 0 test failures, F# builds, containers operational, 95%+ coverage
# 5-Order Effects Matrix
# Compile Command (SC-CMD-004)
```
1st ORDER → Erlang/OTP compiler, .beam generation
2nd ORDER → Ash DSL expansion, NIF compilation
3rd ORDER → Phoenix hot reload, IEx integration
4th ORDER → Test/Prod builds enabled, STAMP validation
5th ORDER → CI/CD green, container builds, GA release
```
# Database Command (SC-CMD-021-024)
```
1st ORDER → PostgreSQL database creation
2nd ORDER → TimescaleDB hypertables, Ash schemas
3rd ORDER → Audit tables, holon storage
4th ORDER → Ecto operations, seeds loadable
5th ORDER → Production migration path, backup capability
```
# Test Command (SC-CMD-008)
```
1st ORDER → ExUnit runner, SKIP_ZENOH_NIF=0
2nd ORDER → PropCheck, sandbox, factories
3rd ORDER → Coverage metrics, STAMP validation
4th ORDER → CI/CD gate, TDG compliance
5th ORDER → Deployment confidence, SIL-6 evidence
```
# Quality Command (SC-CMD-006)
```
1st ORDER → mix format, mix credo
2nd ORDER → .formatter.exs, .credo.exs rules
3rd ORDER → Style violations, code smells
4th ORDER → Maintainable code, safe refactoring
5th ORDER → Long-term quality, audit compliance
```
# Current Verification Status
# Elixir Layer: VERIFIED
- Compile: SUCCESS (1,508 files, 2 NIFs, 0 warnings)
- Test: SUCCESS (1,005 test files, 0 failures)
- Quality: SUCCESS (0 Credo issues, 0 format issues)
- Database: SUCCESS (migrations current)
# Container Layer: VERIFIED
- indrajaal-db-prod: RUNNING (PostgreSQL 17 + TimescaleDB)
- indrajaal-obs-prod: RUNNING (OTEL + Prometheus + Grafana + Loki)
- indrajaal-ex-app-1: RUNNING (Phoenix 1.8.3 + Redis)
- zenoh-router: RUNNING (Zenoh control plane)
- Full mesh: 15 containers available via podman-compose-sil6-full-mesh.yml
# F# Layer: VERIFIED
- Cepaf.fsproj: 0 build errors (net10.0 target)
- Zenoh FFI: 42 tests passing (libzenoh_ffi.so built)
- F# test suite: 549+ tests across 47 test files
- F# codebase: 923 files, ~315K lines
# Sprint Progress: COMPLETE (Sprints 47-51)
- Sprint 47: FPPS consensus, Zenoh stubs, SMRITI rename, biological substrate (170+ files)
- Sprint 48: Ed25519→HMAC-SHA512, ConstitutionalChecker, Credo cleanup (1,444 issues resolved)
- Sprint 49: UTLTSFormatter OTP-28 fix, error remediation pipeline, F# stub→real implementations
- Sprint 50: Zenoh dual-write across 21 safety-critical modules (173 tests added)
- Sprint 51: 12 stub→real implementations (Route, KMS.AI, Alarms, SMRITI, Copilot NL)
# Command Reference
```bash
# Quick verification
elixir scripts/ga-release/smart_command_verifier.exs
# Full verification
elixir scripts/ga-release/runtime_command_verifier.exs --full
# Live command execution
elixir scripts/ga-release/smart_command_verifier.exs --live
# E2E Browser verification (Wallaby + Chrome via NixOS)
test-e2e           # Or: WALLABY_ENABLED=true mix test --only wallaby
# Container stack
sa-up              # Start all 4 containers (prod-standalone) or 14 (full-mesh)
sa-status          # Check status
sa-logs            # View logs
```
# TDG Requirements
> Dual property tests (PC. + SD.) mandatory — see GEMINI.md §7.0, EP-GEN-014
# FMEA Mitigations
| Failure Mode | RPN | Mitigation |
|--------------|-----|------------|
| DB not running | 72 | Pre-check with pg_isready |
| Port conflict | 56 | ss -tlnp check before start |
| .NET missing | 54 | dotnet version check |
| F# build fails | 24 | RESOLVED Sprint 49: net10.0 migration complete, 0 build errors |
# Document Control
| Field | Value |
|-------|-------|
| Version | 21.2.1-SIL6 |
| Created | 2026-01-03 |
| Last Updated | 2026-03-19 |
| Author | Claude Opus 4.6 |
| STAMP | SC-GA-001 to SC-GA-010, SC-CMD-001 to SC-CMD-029, 641+ constraints total |