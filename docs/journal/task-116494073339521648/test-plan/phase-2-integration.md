# Phase 2 — Integration tests (50+ tests, < 5 min wall)

End-to-end flows across NIF + Gleam + storage + sync, but with mocks for GCP.

| Flow | Files | Test count |
|---|---|---:|
| Boot → unseal → put → get → seal | `test/vault_integration_test.gleam` | 8 |
| Lease renewal at boundary | same | 4 |
| Soft-stale → background sync → fresh transition | same | 6 |
| GCP Secret Manager mock pull/push (wiremock) | `test/vault_gcp_mock_test.gleam` | 12 |
| KEK unseal: TPM mock, passphrase, KMS mock | `test/vault_kek_chain_test.gleam` | 9 |
| Cloud KMS error injection (503, 429, 401) | same | 6 |
| Wisp REST endpoint round-trip with OIDC | `test/secret_api_e2e_test.gleam` | 8 |

**Total**: 53 tests.

Run: `gleam test -- --module vault_integration_test`
