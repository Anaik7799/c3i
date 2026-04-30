# E2EE Protocol (SC-E2EE-SUTRA)

## MANDATE
E2EE key operations must be correct to the byte. The Matrix SDK does strict validation — any format deviation causes "Upload key failed".

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-E2EE-001 | keys/upload must store device keys in KV store | CRITICAL |
| SC-E2EE-002 | keys/upload response signed_curve25519 must equal uploaded OTK count | CRITICAL |
| SC-E2EE-003 | keys/query format: {userId: {deviceId: {user_id,device_id,algorithms,keys,signatures}}} | CRITICAL |
| SC-E2EE-004 | device_signing/upload must implement UIA (401 then 200) | CRITICAL |
| SC-E2EE-005 | /sync must include device_lists.changed with users who uploaded keys | CRITICAL |
| SC-E2EE-006 | Cross-signing keys must be stored and retrievable | HIGH |
| SC-E2EE-007 | OTKs must be consumable via keys/claim (pop semantics) | HIGH |

## FluffyChat Bootstrap Sequence
```
1. POST /login → token + device_id
2. SDK creates Olm account
3. POST /keys/upload → MUST return matching OTK count
4. GET /sync → MUST include device_one_time_keys_count + device_lists
5. POST /keys/query → SDK verifies stored keys
6. POST /keys/device_signing/upload → UIA 401 then 200
7. SDK checks masterKey in userDeviceKeys from sync
8. Bootstrap complete (or error if any step fails)
```

## SDK Source Reference
- `~/.pub-cache/hosted/pub.dev/matrix-6.2.0/lib/encryption/olm_manager.dart` — uploadKeys(), line 274 OTK count check
- `~/.pub-cache/hosted/pub.dev/matrix-6.2.0/lib/encryption/utils/bootstrap.dart` — BootstrapState machine
- `~/.pub-cache/hosted/pub.dev/matrix-6.2.0/lib/matrix_api_lite/generated/api.dart` — line 2587 response parsing
