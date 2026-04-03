# Journal Entry: API Token and Secret Mapping Audit

**Date**: 2026-03-22 14:45 CET
**Author**: Gemini (Cybernetic Architect)
**Status**: COMPLETE

## WHAT
A comprehensive audit of API tokens and secrets used across the Indrajaal/Intelitor system.

## WHY
The audit was performed to map the external integration surface and ensure all required credentials for AI, observability, and infrastructure are identified and correctly referenced in the codebase.

## CHANGES MADE
- None (Informational audit only).

## FINDINGS
The system utilizes a multi-tier token strategy across four primary domains:

### 1. External AI & LLM Plane
- **OpenRouter (`OPENROUTER_API_KEY`)**: Primary gateway for multi-model synthesis (Claude, Gemini, Grok).
- **Direct Providers**: `GEMINI_API_KEY`, `ANTHROPIC_API_KEY`, `XAI_API_KEY`, `OPENAI_API_KEY`.
- **Logic**: Synapse defaults to OpenRouter if specific provider keys are missing.

### 2. Infrastructure & Distributed Compute
- **Fly.io (`FLY_API_TOKEN`)**: Used for FLAME (Fly.io) runners and distributed compute scaling.
- **Proxmox (`PVE_API_TOKEN`)**: Capability management for local virtualization.

### 3. Observability & Quality
- **SigNoz (`SIGNOZ_API_KEY`)**: Mandatory for dashboard generation and telemetry ingestion.
- **Grafana (`GRAFANA_TOKEN`)**: Integrated reporting and visualization.
- **CI/CD**: `COVERALLS_REPO_TOKEN`, `GITHUB_TOKEN`.

### 4. Internal Security & Verification
- **JWT (`TOKEN_SIGNING_SECRET`)**: Used by Ash Authentication.
- **Prometheus (`PROOF TOKEN`)**: Part of the SC-SYNC-007 formal verification sync.
- **Federation (`FEDERATION TRUST TOKEN`)**: L7 cross-holon trust mechanism.

## IMPACT
- **Security**: Confirmed that tokens are managed via environment variables (`.env`, `.envrc`) and never hardcoded in source.
- **Resilience**: Identified the fallback mechanisms in AI interfaces (Mock -> OpenRouter -> Direct).
- **Governance**: Provided a clear map for future credential rotation and auditing.

## VERIFICATION
- Verified references in `lib/indrajaal/cortex/ai/`
- Verified references in `lib/indrajaal/observability/`
- Verified presence in `.env.example` and current environment templates.
