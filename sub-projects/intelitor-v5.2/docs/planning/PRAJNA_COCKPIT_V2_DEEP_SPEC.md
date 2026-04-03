# Prajna Cockpit V2: 5-Level Deep Specification

**Date**: 2026-01-02T23:55:00+01:00
**Author**: Cybernetic Architect (Gemini)
**Status**: Definitive Implementation Spec
**Context**: Expanding `PRAJNA_COCKPIT_V2_SPEC.md` to L5 implementation detail.

---

## 1. L1: The Identity & Access Module (Passport Scanner)

### 1.1 Internet Identity Integration
*   **L5 (Code)**: `assets/js/auth/internet_identity.js` using `@dfinity/auth-client`.
*   **L4 (Container)**: Exposes `/.well-known/ii-alternative-origins` for local dev.
*   **L3 (Agent)**: `IndrajaalWeb.Auth.Web3Controller` handles the delegation callback.
*   **L2 (Module)**: `Indrajaal.Auth.IdentityMap` maps `Principal` (ICP) to `User.id` (Indrajaal).
*   **L1 (Function)**: `verify_delegation(token)` verifies the BLS signature of the chain.

### 1.2 UCAN Resolver Middleware
*   **L5 (Code)**: `IndrajaalWeb.Plugs.UCANAuth` plug.
*   **L4 (Container)**: Nginx configured to pass `Authorization: Bearer` headers.
*   **L3 (Agent)**: `Indrajaal.Auth.CapabilityCache` (ETS) stores validated UCANs.
*   **L2 (Module)**: `Indrajaal.Auth.UCAN.Validator` (Rust NIF) checks signature + time bounds.
*   **L1 (Function)**: `check_attenuation(parent, child)` verifies capability narrowing.

---

## 2. L2: The Metabolic Module (Energy Gauge)

### 2.1 Treasury Widget (LiveView)
*   **L5 (Code)**: `IndrajaalWeb.Live.TreasuryComponent`.
*   **L4 (Container)**: Secure WebSocket channel for real-time balance updates.
*   **L3 (Agent)**: `Indrajaal.Core.Holon.Metabolism` GenServer (the accountant).
*   **L2 (Module)**: `Indrajaal.Finance.Ledger` manages the double-entry book.
*   **L1 (Function)**: `calculate_burn_rate(history)` computes linear regression of cycle usage.

### 2.2 Survival Time Calculator
*   **L5 (Code)**: JS hook `MetabolismChart` (D3.js/Chart.js).
*   **L4 (Container)**: N/A.
*   **L3 (Agent)**: `Indrajaal.Analytics.Forecaster` (Nx-based).
*   **L2 (Module)**: `Indrajaal.Finance.PricingOracle` fetches current ICP/USD rates.
*   **L1 (Function)**: `predict_death(balance, rate)` returns `DateTime` of depletion.

---

## 3. L3: The Governance Module (Council Chamber)

### 3.1 Proposal System
*   **L5 (Code)**: `IndrajaalWeb.Live.Governance.ProposalForm`.
*   **L4 (Container)**: IPFS gateway for storing large proposal payloads (PDFs/Code).
*   **L3 (Agent)**: `Indrajaal.Governance.Parliament` GenServer (manages voting lifecycle).
*   **L2 (Module)**: `Indrajaal.Governance.Proposal` (Ash Resource).
*   **L1 (Function)**: `hash_proposal(payload)` creates the unique ID.

### 3.2 Threshold Voting
*   **L5 (Code)**: `assets/js/crypto/threshold_sign.js` (Client-side signing).
*   **L4 (Container)**: N/A.
*   **L3 (Agent)**: `Indrajaal.Governance.BallotBox` aggregates signatures.
*   **L2 (Module)**: `Indrajaal.Crypto.Threshold` (Rust NIF) combines shares.
*   **L1 (Function)**: `verify_share(share, pubkey)` validates individual votes.

---

## 4. L4: The Immune System Viz (The Radar)

### 4.1 Threat Map (Geospatial/Logical)
*   **L5 (Code)**: `IndrajaalWeb.Live.Immune.ThreatMap` (Leaflet.js + WebGL).
*   **L4 (Container)**: GeoIP database sidecar.
*   **L3 (Agent)**: `Indrajaal.Safety.Sentinel` streams active threats via PubSub.
*   **L2 (Module)**: `Indrajaal.Safety.ThreatIntelligence` correlates local IPs to global reputations.
*   **L1 (Function)**: `score_threat(events)` calculates severity (0-100).

### 4.2 Antibody Controller
*   **L5 (Code)**: `IndrajaalWeb.Live.Immune.AntibodyList`.
*   **L4 (Container)**: N/A.
*   **L3 (Agent)**: `Indrajaal.Safety.Antibody` Supervisor inspection.
*   **L2 (Module)**: `Indrajaal.Safety.ResponseStrategy` defines neutralization rules.
*   **L1 (Function)**: `deploy_antibody(target)` spawns the ephemeral process.

---

## 5. L5: Data Sovereignty Module (The Vault)

### 5.1 Audit Browser (The Time Machine)
*   **L5 (Code)**: `IndrajaalWeb.Live.Audit.TimeLine`.
*   **L4 (Container)**: DuckDB read-only replica connection.
*   **L3 (Agent)**: `Indrajaal.Knowledge.Store.AuditReader`.
*   **L2 (Module)**: `Indrajaal.Knowledge.MerkleTree` allows verification of inclusion.
*   **L1 (Function)**: `verify_path(root, proof, leaf)` allows client-side math proof.

### 5.2 Verifiable Export
*   **L5 (Code)**: `IndrajaalWeb.Controllers.ExportController`.
*   **L4 (Container)**: Temporary file storage for zip generation.
*   **L3 (Agent)**: `Indrajaal.Core.Holon.Archivist`.
*   **L2 (Module)**: `Indrajaal.Crypto.Signer` signs the export bundle.
*   **L1 (Function)**: `stream_zip(data)` generates download stream.

---

## 6. Implementation Dependencies

*   **Frontend**: `esbuild` setup must include `@dfinity/agent` and `ucan-storage`.
*   **Backend**: `rustler` compilation for `indrajaal_crypto` crate.
*   **Infrastructure**: `dfx` (ICP SDK) must be available in the Dev Container (`devcontainer.json`).

*This specification provides the exact blueprint for the engineering team to build Cockpit V2.*
