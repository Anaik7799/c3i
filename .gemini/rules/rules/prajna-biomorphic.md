---
paths: lib/indrajaal/cockpit/**/*.ex, lib/indrajaal_web/live/prajna/**/*.ex, lib/cepaf/src/Cepaf/Cockpit/**/*.fs
---
# Prajna Biomorphic Integration Rules
# STAMP/AOR Reference
> SC-PRAJNA-001 to SC-PRAJNA-007, AOR-PRAJNA-001 to AOR-PRAJNA-005 — see CLAUDE.md §5.0, §9.0
> SC-BIO-*, AOR-BIO-* — see biomorphic-mode.md (always loaded)
> Key: Guardian pre-approval, Founder's Directive, Immutable Register, Sentinel sync 30s, two-step commit
# Critical Modules (P0)
When editing these files, ALWAYS ensure:
# GuardianIntegration (`lib/indrajaal/cockpit/prajna/guardian_integration.ex`)
- All Prajna commands wrapped in Guardian.validate/2
- Fallback path for veto scenarios
- Telemetry for proposal tracking
# AiCopilotFounder (`lib/indrajaal/cockpit/prajna/ai_copilot_founder.ex`)
- Three Supreme Goals validation:
1. Symbiotic Survival (CRITICAL)
2. Sentience Pursuit (HIGH)
3. Power Accumulation (MEDIUM)
# SentinelBridge (`lib/indrajaal/cockpit/prajna/sentinel_bridge.ex`)
- GenServer with 30s sync interval
- Bidirectional: SmartMetrics ↔ Sentinel
- Health score and threat advisories
# ImmutableState (`lib/indrajaal/cockpit/prajna/immutable_state.ex`)
- Ed25519 signatures for all blocks
- SHA3-256 hash chain
- DuckDB append-only history
# Context Building Pattern
For any Prajna task, agents MUST:
```elixir
# 1. Read existing module documentation
Read("lib/indrajaal/cockpit/prajna/#{module}.ex")
# 2. Check Guardian integration status
Grep("Guardian.validate", path: "lib/indrajaal/cockpit/prajna/")
# 3. Verify STAMP constraint coverage
Grep("SC-PRAJNA", path: "test/indrajaal/cockpit/prajna/")
# 4. Review related supervisor children
Read("lib/indrajaal/cockpit/prajna/supervisor.ex")
# 5. Check integration tests
Glob("test/indrajaal/cockpit/prajna/*_test.exs")
```
# Known P0 Issues
1. **Guardian Bypass**: Commands can reach Prajna without Guardian approval - BLOCK
2. **Founder Directive Gap**: AI recommendations not validated against Ω₀ - BLOCK
3. **State Mutability**: State changes not logged to Immutable Register - HIGH
4. **Sentinel Isolation**: SmartMetrics runs independently of Sentinel - HIGH
# TDG Requirements
> Dual property tests (PropCheck PC. + StreamData SD.) mandatory — see CLAUDE.md §7.0, EP-GEN-014
# Color Rich & Interface Profiles (SC-HMI-010)
- **Mandate**: Shift from Dark Cockpit to **Color Rich Mechanism**.
- **Implementation**: Support 4 selectable profiles: Dark Cockpit, Color Rich, Google Compliant, Functionally Clean.
- **Visuals**: Vibrant colors for healthy states; dynamic chromaticism linked to Zenoh telemetry.
- **Audit**: Follow **8x8 Fractal Matrix** (8 Elements x 8 Layers) for all UI verification.
- **Completeness**: 100% path coverage for data/control flows across all matrix cells.