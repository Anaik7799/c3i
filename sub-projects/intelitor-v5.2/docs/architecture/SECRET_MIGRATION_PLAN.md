# SECRET MIGRATION PLAN: From Environment to Sovereignty

**Version**: 1.0.0 | **Status**: DRAFT
**Context**: Moving to SIL-6 Secret Management (GCP)

---

## 1.0 The Mandate
**SC-SEC-053**: No long-lived secrets shall exist in environment variables or configuration files. All secrets must be fetched dynamically from a Hardware-Backed Vault (GCP).

## 2.0 Inventory & Migration Strategy

### 2.1 Infrastructure Secrets (Level 4)
| Secret | Current | Target | Migration Step |
| :--- | :--- | :--- | :--- |
| `TS_AUTHKEY` | ENV | **Secret Manager** | Update `tailscale-entrypoint.sh` to call `gcloud secrets versions access` or Prajna API. |
| `DB_PASSWORD` | ENV | **Secret Manager** | Update `config/runtime.exs` to fetch via `GoogleApi.SecretManager` before Repo start. |

### 2.2 Application Secrets (Level 2/3)
| Secret | Current | Target | Migration Step |
| :--- | :--- | :--- | :--- |
| `OPENROUTER_KEY`| ENV | **Secret Manager** | Update `OpenRouterClient` to fetch on init. |
| `JWT_SECRET` | ENV | **Secret Manager** | Update `Guardian` config in `runtime.exs`. |

### 2.3 Sovereign Keys (Level 1/7)
| Secret | Current | Target | Migration Step |
| :--- | :--- | :--- | :--- |
| `Lineage Key` | Local File | **Cloud KMS (HSM)** | Refactor `LineageAuth` NIF to use KMS API for signing operations (Remote Signing). |

---

## 3.0 Implementation Logic (Elixir)

### 3.1 The Secret Fetcher (runtime.exs)
We cannot use the full `Prajna` app in `runtime.exs` because the app isn't started. We need a lightweight `System.cmd` wrapper or a specialized boot-time fetcher.

```elixir
# config/runtime.exs
defmodule SecretFetcher do
  def get(name) do
    # 1. Try ENV (Dev fallback)
    # 2. Try GCP Secret Manager via curl/gcloud (Prod)
    System.get_env(name) || fetch_from_gcp(name)
  end
end

config :indrajaal, Indrajaal.Repo,
  password: SecretFetcher.get("DB_PASSWORD")
```

### 3.2 The Remote Signer (LineageAuth)
Instead of:
`verify_signature(pubkey, msg, sig)` checking a local key...

The **Founder** (You) signs using KMS. The **System** verifies using the Public Key (which can be public).
*   **Verification**: Does not need secrecy, only Integrity.
*   **Action**: Ensure the Public Key is baked into the immutable `GENOTYPE` or fetched from a trusted KMS public key endpoint.

---

## 4.0 7-Level Impact Analysis

1.  **Cellular**: `LineageAuth` becomes a verifier of KMS signatures.
2.  **Component**: `OpenRouterClient` loses its static config; becomes dynamic.
3.  **Integration**: `tailscale-entrypoint` needs `gcloud` or `curl` access to GCP APIs.
4.  **Operational**: Containers need **Workload Identity** (GCP Service Account linked to K8s SA or credential file).
5.  **Metabolic**: Startup time increases by ~500ms (API calls). OODA loop must account for "Secret Fetch Latency".
6.  **Evolutionary**: Rotating a key in GCP automatically propagates to new container starts.
7.  **Strategic**: **Total Revocation Capability**. Disable a key in KMS -> System stops accepting commands immediately.

## 5.0 Verification (Correctness)
*   **Test**: `mix test` must run with MOCK secrets.
*   **Audit**: `sa-verify-all.fsx` should check that `env | grep KEY` returns NOTHING in production.
