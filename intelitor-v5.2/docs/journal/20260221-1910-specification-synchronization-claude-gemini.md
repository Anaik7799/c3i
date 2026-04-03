# Specification Synchronization: CLAUDE.md & GEMINI.md

**Date**: 2026-02-21 19:10 CET
**Status**: COMPLETE
**Version**: 21.3.0-SIL6 (Synced)
**Author**: Gemini CLI (Cybernetic Architect)

## Executive Summary
Synchronization of the two primary agent specification files (`CLAUDE.md` and `GEMINI.md`) was executed to ensure parity in safety constraints, operational commands, and Agent Operating Rules (AOR). `CLAUDE.md` was identified as the lead specification containing the latest architectural updates (Holon Database Naming, Zenoh Test Messaging).

## Rationale
Agent specifications had diverged by approximately 39 lines. `CLAUDE.md` contained several critical safety constraint categories and commands that were missing from `GEMINI.md`. To maintain system integrity and ensure that Gemini agents operate with the full set of constraints defined for the Indrajaal SIL-6 ecosystem, a full synchronization was mandatory.

## Changes Made

### 1. Lead Specification Identification
- Confirmed `CLAUDE.md` (1537 lines) as the authoritative source relative to the previous `GEMINI.md` (1498 lines).

### 2. Full Content Sync
- Replaced `GEMINI.md` content with `CLAUDE.md` to capture all missing sections:
    - **SC-DBNAME**: Holon Database Naming (UHI compliance).
    - **SC-DBLOCAL**: Local Database Access (WAL mode, pooling).
    - **SC-DBCROSS**: Cross-Holon Database Access (Zenoh queries).
    - **SC-ZTEST**: Zenoh Test Messaging (Boot/Smoke checkpoints).
    - **AOR-DBNAME/DBLOCAL/DBCROSS/ZTEST**: Corresponding agent operational rules.
    - Updated command references for Zenoh messaging.

### 3. Header Localization
- Updated `GEMINI.md` header:
    - Title: `# GEMINI.md - Indrajaal Safety-Critical System Optimized Spec`
    - Origin: `CLAUDE.md v21.3.0`
    - Mandate: Restored specific Gemini mandate (token-efficient context for Gemini agents synced with CLAUDE.md).

## Verification Results

| Metric | CLAUDE.md | GEMINI.md | Result |
|--------|-----------|-----------|--------|
| Version| 21.3.0-SIL6| 21.3.0-SIL6| **PASS** |
| Line Count| 1537 | 1537 | **PASS** |
| Integrity | Verified | Verified | **PASS** |

### Post-Sync Integrity Check
- Checked for accidental string contamination.
- Verified presence of `SC-ZTEST` and `SC-DBNAME` blocks in both files.
- Confirmed port registry and container architecture tables match (indrajaal-app-prod vs ex-app-1 discrepancy resolved in favor of prod).

## Impact
Gemini agents now have full visibility into the latest Zenoh and Database naming constraints, reducing the risk of architectural drift during autonomous code generation.

## STAMP Compliance
- **SC-VAL-005**: Maintained complete audit trail of specification change.
- **SC-GEM-002**: Modified core specs only under explicit user directive.
