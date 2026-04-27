# Authentication & IAM Constraints (SC-AUTH, SC-IAM)

## FerrisKey IAM Integration
FerrisKey is the centralized Identity and Access Management provider for C3I.
Container #17 in the SIL-6 Biomorphic Mesh.

## SC-AUTH (Authentication)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-AUTH-001 | Mutation endpoints MUST require valid OIDC JWT | CRITICAL |
| SC-AUTH-002 | JWT signature MUST be validated against JWKS | CRITICAL |
| SC-AUTH-003 | Token expiration MUST be enforced | CRITICAL |
| SC-AUTH-004 | JWKS cache TTL MUST NOT exceed 5 minutes | HIGH |
| SC-AUTH-005 | Auth failures MUST fail-safe (deny access) | CRITICAL |
| SC-AUTH-006 | Static token fallback MUST be disabled in production | CRITICAL |
| SC-AUTH-007 | Refresh tokens MUST be stored encrypted | HIGH |
| SC-AUTH-008 | Service accounts MUST use client credentials flow | HIGH |

## SC-IAM (Identity & Access Management)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-IAM-001 | FerrisKey MUST be healthy before app containers start | CRITICAL |
| SC-IAM-002 | Realm per environment MANDATORY (dev/staging/prod) | HIGH |
| SC-IAM-003 | RBAC mapping to fractal layers MUST be exhaustive | CRITICAL |
| SC-IAM-004 | MFA MUST be enforced for L0 Constitutional operations | CRITICAL |
| SC-IAM-005 | Webhook events MUST be published to Zenoh mesh | HIGH |
| SC-IAM-006 | Auth audit events MUST be OTel spans | HIGH |
| SC-IAM-007 | FerrisKey deploys MUST NOT invalidate existing sessions | CRITICAL |
| SC-IAM-008 | Admin console accessible only to c3i-admin role | CRITICAL |

## RBAC → Fractal Layer Mapping
| FerrisKey Role | Permission | Layers | MFA |
|---|---|---|---|
| c3i-admin | FullAccess | L0-L7 | Required for L0 |
| c3i-operator | OperatorAccess | L1-L7 | No |
| c3i-viewer | ViewerAccess | L4-L7 | No |
| c3i-service | ServiceAccount | L3-L6 | N/A |

## Files
| File | Purpose |
|------|---------|
| `auth/oidc.gleam` | OIDC JWT validation, JWKS, claims extraction |
| `auth/rbac.gleam` | Fractal layer RBAC mapping |
| `auth/token_exchange.gleam` | Telegram identity federation |
| `ui/wisp/auth.gleam` | Auth middleware (static + OIDC) |
| `ui/wisp/auth_api.gleam` | Auth REST API endpoints |
| `ui/lustre/auth.gleam` | Auth management page (SSR) |
| `ui/tui/auth_view.gleam` | Auth status TUI view |
| `sub-projects/ferriskey/` | FerrisKey bridge + config |
