# Matrix Protocol Compliance (SC-MATRIX)

## MANDATE
Every endpoint must return spec-compliant JSON. Every response must include correct Content-Type and CORS headers.

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-MATRIX-001 | 159/159 endpoints must respond | CRITICAL |
| SC-MATRIX-002 | Error responses use {errcode, error} format | CRITICAL |
| SC-MATRIX-003 | Auth endpoints return 401 M_MISSING_TOKEN without token | CRITICAL |
| SC-MATRIX-004 | Login returns access_token + device_id + user_id + well_known | CRITICAL |
| SC-MATRIX-005 | Sync returns next_batch + rooms + device_lists + device_one_time_keys_count | CRITICAL |
| SC-MATRIX-006 | keys/upload returns one_time_key_counts matching uploaded count | CRITICAL |
| SC-MATRIX-007 | keys/query returns device keys in correct format (no extra nesting) | CRITICAL |
| SC-MATRIX-008 | device_signing/upload requires UIA (401 then 200) | HIGH |
| SC-MATRIX-009 | Username whitespace must be trimmed before lookup | HIGH |
| SC-MATRIX-010 | Transaction IDs should be idempotent for PUT send endpoints | MEDIUM |
