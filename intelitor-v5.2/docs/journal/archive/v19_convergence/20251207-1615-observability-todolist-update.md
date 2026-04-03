# PROJECT_TODOLIST.md Observability Enhancement Update

**Date**: 2025-12-07 16:15 CET
**Author**: Claude Code (Opus 4.5)
**Status**: COMPLETED

## Overview

Extensively updated PROJECT_TODOLIST.md with comprehensive observability enhancement tasks as defined in the observability plan (docs/plans/20251207-observability-enhancement-plan.md).

## New Task Section Added

### 14.0 - Comprehensive Observability Enhancement (P1 - Critical)

Added complete hierarchical task structure with 6 major phases and 17 subtasks:

| Phase | Description | Priority | Subtasks |
|-------|-------------|----------|----------|
| 14.1 | Critical Domain Instrumentation | P1 | 3 (integration, intelligence, shifts) |
| 14.2 | Web Layer Instrumentation | P1 | 3 (API controllers, WebSocket channels, LiveView) |
| 14.3 | Background Job Instrumentation | P1 | 1 (Oban workers) |
| 14.4 | Infrastructure Instrumentation | P2 | 4 (HTTP client, circuit breaker, rate limiter, cache) |
| 14.5 | Advanced Observability Features | P3 | 3 (business metrics, correlation, predictive) |
| 14.6 | Testing & Validation | P1 | 2 (per-instrumentation, integration) |

## Task Statistics

- **Total New Tasks Added**: 22 (1 parent + 6 phases + 15 subtasks)
- **P1 Critical Tasks**: 10
- **P2 High Tasks**: 7
- **P3 Medium Tasks**: 5

## Coverage Targets

| Component | Current | Target | Gap |
|-----------|---------|--------|-----|
| Domain Logic (instrumented) | 100% | 100% | 0% |
| Domain Logic (missing) | 0% | 100% | 100% |
| API Controllers | 28% | 95% | 67% |
| WebSocket Channels | 43% | 95% | 52% |
| LiveView Components | 40% | 95% | 55% |
| Background Jobs | 33% | 100% | 67% |
| HTTP Clients | 0% | 100% | 100% |
| Infrastructure | 50% | 95% | 45% |

## Telemetry Events Specified

### Domain Events (27 events)
- Integration domain: 9 events
- Intelligence domain: 8 events
- Shifts domain: 9 events

### Web Layer Events (16 events)
- API endpoints: 5 events per controller
- WebSocket channels: 6 events per channel
- LiveView components: 5 events per component

### Infrastructure Events (17 events)
- HTTP client: 5 events
- Circuit breaker: 5 events
- Rate limiter: 4 events
- Response cache: 4 events

### Background Job Events (6 events)
- Oban worker lifecycle: 6 events

## STAMP Compliance

- **Constraints Covered**: SC-OBS-065 to SC-OBS-072
- **Reference**: CLAUDE.md Section 6.0 Category I

## Related Documentation

- Plan: `docs/plans/20251207-observability-enhancement-plan.md`
- Previous: `docs/journal/20251207-1542-scripts-docs-artifacts-cleanup.md`
- CLAUDE.md: Section 13.0 (Dual Logging System), Section 45.0 (OpenTelemetry)

---

**Document Status**: Verified complete as of 2025-12-07 16:15 CET
