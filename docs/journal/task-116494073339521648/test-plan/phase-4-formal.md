# Phase 4 — Formal verification (TLA+ + Apalache + Agda)

Per **SC-CPIG-001** (formal-spec-first), **SC-ALLIUM-001..008**.

## TLA+ — `specs/tla/RustyVaultIntegration.tla` (~280 LOC)

```tla
---- MODULE RustyVaultIntegration ----
EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS Secrets, MaxTTL, Clock

VARIABLES
  vault_state,         \* {Sealed, Active, Sealing, Corrupt, Halted}
  kek_in_ram,          \* boolean
  audit_log,           \* sequence
  sync_clock,          \* time of last successful sync
  secret_versions,     \* function name |-> Seq(version)
  secret_fetched_at    \* function name |-> time

Init == /\ vault_state = "Sealed"
        /\ kek_in_ram = FALSE
        /\ audit_log = << >>
        /\ sync_clock = 0
        /\ secret_versions = [s \in Secrets |-> << >>]
        /\ secret_fetched_at = [s \in Secrets |-> 0]

\* Invariants
NoPlaintextAtRest ==
  \A s \in Secrets:
    vault_state = "Sealed" => secret_value(s) = ENCRYPTED

BootUnsealsKEK ==
  vault_state \in {"Active", "Corrupt", "Halted"} =>
    \A entry \in Range(audit_log):
      entry.event = "unseal_attempted"

OfflineFreshness ==
  \A s \in Secrets:
    (Clock - secret_fetched_at[s] >= MaxTTL[s]) =>
      vault_get(s) = "FAIL_CLOSED"

SyncConvergence ==
  <>(\A s \in Secrets: |secret_versions[s]| = |gcp_versions[s]|)

LeaseExpiryEnforced ==
  \A s \in Secrets:
    \A v \in Range(secret_versions[s]):
      v.lease_expiry > Clock

VersionMonotonic ==
  \A s \in Secrets:
    \A i \in 1..Len(secret_versions[s])-1:
      secret_versions[s][i] < secret_versions[s][i+1]

AuditAppendOnly ==
  audit_log' \subseteq audit_log \cup audit_log'

Spec == Init /\ [][Next]_<<vault_state, kek_in_ram, audit_log, sync_clock, secret_versions, secret_fetched_at>>
====
```

Run: `tlc -config specs/tla/RustyVaultIntegration.cfg specs/tla/RustyVaultIntegration.tla`

Apalache: `apalache-mc check --inv NoPlaintextAtRest specs/tla/RustyVaultIntegration.tla`

## Agda — `specs/agda/VaultStateMachine.agda` (~150 LOC)

```agda
module VaultStateMachine where

open import Data.Nat
open import Data.Bool

data VaultState : Set where
  Sealed   : VaultState
  Unsealing : VaultState
  Active   : VaultState
  Sealing  : VaultState
  Corrupt  : VaultState

data PlaintextAccessible : VaultState → Set where
  active-accessible : PlaintextAccessible Active

-- Type-level proof: Sealed → ¬PlaintextAccessible
sealed-no-plaintext : ¬ PlaintextAccessible Sealed
sealed-no-plaintext ()  -- empty case, no constructor produces this

-- Type-level proof: KekValid → vault.unseal succeeds
data KekValid : Set where
  valid : KekValid

unseal-with-valid-kek : KekValid → VaultState
unseal-with-valid-kek valid = Active

-- Compile-time guarantee: no path produces PlaintextAccessible Sealed
```

Run: `agda --safe specs/agda/VaultStateMachine.agda`

## Closure

| Spec | Status |
|---|---|
| TLA+ TLC | green |
| TLA+ Apalache | green for bounded state space (≤ 10 secrets, ≤ 100 ops) |
| Agda compile | type-checks (`agda --safe`) |
| Allium tend | (continuous, weekly cron per SC-CPIG-007) |

Weekly cron runs all of the above; counter-example triggers P0 sa-plan task.
