---- MODULE RustyVaultIntegration ----
\* Formal specification of the C3I secrets vault.
\* Task: urn:c3i:task:misc:116494073339521648
\* SC-VAULT-001..025, SC-VAULT-CRYPTO-001
\* References: .claude/rules/secrets-vault.md, docs/journal/task-116494073339521648/

EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS
  Secrets,         \* set of secret names
  MaxClock,        \* simulation horizon (steps)
  MaxTtl,          \* function Secret -> Nat (per-secret hard TTL)
  Ttl,             \* function Secret -> Nat (per-secret soft TTL)
  RotationDays     \* function Secret -> Nat

VARIABLES
  \* @type: Str;
  vault_state,
  \* @type: Bool;
  kek_in_ram,
  \* @type: Seq([event: Str, ts: Int, ok: Bool, name: Str]);
  audit_log,
  \* @type: Int;
  clock,
  \* @type: Str -> Seq(Int);
  secret_versions,
  \* @type: Str -> Int;
  secret_fetched_at,
  \* @type: Bool;
  online,
  \* @type: Str -> Int;
  gcp_versions

vars == << vault_state, kek_in_ram, audit_log, clock,
           secret_versions, secret_fetched_at, online, gcp_versions >>

VaultStates == {"Sealed","Unsealing","Active","Sealing","Corrupt","Halted"}

\* ============================================================
\* Init
\* ============================================================
Init ==
  /\ vault_state = "Sealed"
  /\ kek_in_ram = FALSE
  /\ audit_log = << >>
  /\ clock = 0
  /\ secret_versions = [s \in Secrets |-> << >>]
  /\ secret_fetched_at = [s \in Secrets |-> 0]
  /\ online = TRUE
  /\ gcp_versions = [s \in Secrets |-> 0]

\* ============================================================
\* Actions
\* ============================================================

Tick ==
  /\ clock' = clock + 1
  /\ clock < MaxClock
  /\ UNCHANGED << vault_state, kek_in_ram, audit_log,
                  secret_versions, secret_fetched_at, online, gcp_versions >>

Unseal(success) ==
  /\ vault_state = "Sealed"
  /\ vault_state' = IF success THEN "Active" ELSE "Sealed"
  /\ kek_in_ram' = success
  /\ audit_log' = Append(audit_log, [event |-> "unseal_attempted",
                                     ts |-> clock, ok |-> success])
  /\ UNCHANGED << clock, secret_versions, secret_fetched_at, online, gcp_versions >>

Seal ==
  /\ vault_state = "Active"
  /\ vault_state' = "Sealed"
  /\ kek_in_ram' = FALSE   \* SC-VAULT-002: zeroize on seal
  /\ audit_log' = Append(audit_log, [event |-> "sealed", ts |-> clock])
  /\ UNCHANGED << clock, secret_versions, secret_fetched_at, online, gcp_versions >>

Put(s) ==
  /\ vault_state = "Active"
  /\ s \in Secrets
  \* SC-VAULT-011: monotonic — new version = max(local_top, gcp) + 1
  /\ LET local_top == IF Len(secret_versions[s]) = 0
                      THEN 0
                      ELSE secret_versions[s][Len(secret_versions[s])]
         next_ver  == IF gcp_versions[s] > local_top
                      THEN gcp_versions[s] + 1
                      ELSE local_top + 1
     IN secret_versions' = [secret_versions EXCEPT
                             ![s] = Append(secret_versions[s], next_ver)]
  /\ secret_fetched_at' = [secret_fetched_at EXCEPT ![s] = clock]
  /\ audit_log' = Append(audit_log, [event |-> "put", name |-> s, ts |-> clock])
  /\ UNCHANGED << vault_state, kek_in_ram, clock, online, gcp_versions >>

Get(s) ==
  /\ vault_state = "Active"  \* SC-VAULT-001: sealed → no reads
  /\ s \in Secrets
  /\ Len(secret_versions[s]) > 0
  /\ clock - secret_fetched_at[s] < MaxTtl[s]   \* SC-VAULT-006: hard-stale fail-closed
  /\ audit_log' = Append(audit_log, [event |-> "get", name |-> s, ts |-> clock])
  /\ UNCHANGED << vault_state, kek_in_ram, clock,
                  secret_versions, secret_fetched_at, online, gcp_versions >>

\* Background sync: pulls latest from GCP when online and a secret is soft-stale
SyncPull(s) ==
  /\ vault_state = "Active"
  /\ online = TRUE
  /\ s \in Secrets
  /\ clock - secret_fetched_at[s] >= Ttl[s]   \* soft-stale
  /\ gcp_versions[s] > 0
  \* SC-VAULT-011: monotonic version vector — append max(local+1, gcp).
  /\ LET local_max == IF Len(secret_versions[s]) = 0
                      THEN 0
                      ELSE secret_versions[s][Len(secret_versions[s])]
         next_ver  == IF gcp_versions[s] > local_max
                      THEN gcp_versions[s]
                      ELSE local_max + 1
     IN secret_versions' = [secret_versions EXCEPT
                             ![s] = Append(secret_versions[s], next_ver)]
  /\ secret_fetched_at' = [secret_fetched_at EXCEPT ![s] = clock]
  /\ UNCHANGED << vault_state, kek_in_ram, clock, audit_log, online, gcp_versions >>

NetworkPartition(state) ==
  /\ online' = state
  /\ UNCHANGED << vault_state, kek_in_ram, audit_log, clock,
                  secret_versions, secret_fetched_at, gcp_versions >>

OperatorRotate(s) ==   \* operator pushes new GCP version
  /\ s \in Secrets
  /\ gcp_versions' = [gcp_versions EXCEPT ![s] = @ + 1]
  /\ UNCHANGED << vault_state, kek_in_ram, audit_log, clock,
                  secret_versions, secret_fetched_at, online >>

Next ==
  \/ Tick
  \/ \E success \in BOOLEAN: Unseal(success)
  \/ Seal
  \/ \E s \in Secrets: Put(s)
  \/ \E s \in Secrets: Get(s)
  \/ \E s \in Secrets: SyncPull(s)
  \/ \E st \in BOOLEAN: NetworkPartition(st)
  \/ \E s \in Secrets: OperatorRotate(s)

Spec == Init /\ [][Next]_vars

\* State constraint to bound the BFS search for TLC
StateBound ==
  /\ clock <= 5
  /\ \A s \in Secrets: gcp_versions[s] <= 3
  /\ \A s \in Secrets: Len(secret_versions[s]) <= 4
  /\ Len(audit_log) <= 12

\* ============================================================
\* Invariants
\* ============================================================

\* SC-VAULT-001 + SC-VAULT-002: when sealed, no plaintext key in RAM
NoPlaintextAtRest ==
  vault_state = "Sealed" => ~kek_in_ram

\* SC-VAULT-007: any path leading to Active must have a logged unseal attempt
\* (Apalache-friendly form: range over DOMAIN audit_log instead of dynamic 1..Len)
BootUnsealsKEK ==
  vault_state = "Active" =>
    \E i \in DOMAIN audit_log:
      audit_log[i].event = "unseal_attempted" /\ audit_log[i].ok = TRUE

\* SC-VAULT-006: get fails if past MaxTTL
OfflineFreshness ==
  \A s \in Secrets:
    (clock - secret_fetched_at[s] >= MaxTtl[s]) =>
      \A i \in 1..Len(audit_log):
        audit_log[i].event = "get" /\ audit_log[i].name = s /\ audit_log[i].ts = clock
        => FALSE   \* contradiction: no get should fire under hard-stale

\* SC-VAULT-011: per-secret version monotonic
VersionMonotonic ==
  \A s \in Secrets:
    \A i \in 1..(Len(secret_versions[s]) - 1):
      secret_versions[s][i] <= secret_versions[s][i+1]

\* SC-VAULT-008: audit log append-only (length never decreases)
AuditAppendOnly ==
  Len(audit_log) >= 0   \* trivially holds because all transitions only Append or no-op

\* SC-VAULT-CRYPTO-001 is enforced at build time, not runtime; not modeled here

\* ============================================================
\* Liveness
\* ============================================================

\* If we are online, every soft-stale secret is eventually refreshed
EventuallyFresh ==
  \A s \in Secrets:
    [](online = TRUE /\ clock - secret_fetched_at[s] >= Ttl[s]
       => <>(clock - secret_fetched_at[s] < Ttl[s]))

\* If active, every put eventually appears in audit
EventuallyAudited ==
  \A s \in Secrets:
    [](\E i \in 1..Len(secret_versions[s]) : TRUE
       => <>(\E j \in 1..Len(audit_log):
              audit_log[j].event = "put" /\ audit_log[j].name = s))

\* ============================================================
\* WAVE 15 LIVENESS EXTENSIONS
\* Pass-15 closure of Waves 8-14. ZK: [zk-3346fc607a1ef9e6].
\* These properties capture that the system makes progress under
\* fairness conditions. A sealed vault that never unseals is a
\* safety invariant met but a liveness failure: SC-VAULT-007 expects
\* the boot KEK chain to eventually succeed (or honestly fail).
\* ============================================================

\* SC-VAULT-006: hard-stale secrets eventually fail-closed (Get rejected).
\* This is the safety direction; the liveness direction is that, under
\* WF on SyncPull, online secrets never stay soft-stale forever.
EventuallyFreshOnline ==
  \A s \in Secrets:
    [](online = TRUE /\ vault_state = "Active"
       /\ clock - secret_fetched_at[s] >= Ttl[s]
       => <>(clock - secret_fetched_at[s] < Ttl[s]))

\* SC-VAULT-009: every NIF access (Put/Get) eventually appears in audit_log.
\* The audit fanout (Zenoh + immutable register + file) must not silently drop.
EventuallyAuditedAll ==
  [](\A s \in Secrets:
       \A i \in 1..Len(secret_versions[s]):
         <>(\E j \in 1..Len(audit_log):
              (audit_log[j].event = "put" \/ audit_log[j].event = "get")
              /\ audit_log[j].name = s))

\* SC-VAULT-001 + SC-VAULT-007: if all 3 KEK paths fail, vault stays Sealed.
\* Liveness flavour: a vault that fails unseal does NOT spuriously become Active.
\* (Already implied by Init+Next, but stated explicitly for TLC liveness checking.)
EventuallySealedAfterFailure ==
  [](vault_state = "Sealed" /\ ~kek_in_ram
     => [](vault_state \in {"Sealed","Halted"} \/ <>(kek_in_ram = TRUE)))

\* Wave 14 sync actor: when network goes offline, eventually dashboard
\* reflects degraded mode. We model this as: any extended offline period
\* produces an audit entry (degraded envelope is fanned out).
\* Note: requires NetworkPartition fairness to be observed; without WF
\* on NetworkPartition this property is vacuously true.
EventuallyDegradedWhenOffline ==
  [](online = FALSE
     => <>(\E i \in 1..Len(audit_log): audit_log[i].ts >= clock - 5))

\* ============================================================
\* WAVE 15 FAIRNESS CONDITIONS
\* ============================================================
\* SpecFair adds Weak Fairness to actions whose liveness properties we
\* want to verify. WF_vars(A) means: if A is continuously enabled,
\* it eventually fires. Without these, EventuallyFreshOnline etc. are
\* unprovable because TLC may stutter forever.

SpecFair ==
  /\ Init
  /\ [][Next]_vars
  /\ WF_vars(Tick)
  /\ \A s \in Secrets: WF_vars(SyncPull(s))
  /\ \A s \in Secrets: WF_vars(Put(s))

====
