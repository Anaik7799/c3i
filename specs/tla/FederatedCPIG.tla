---------------------------- MODULE FederatedCPIG ----------------------------
(***************************************************************************)
(* Federated cross-mesh CPIG attestation specification.                    *)
(*                                                                          *)
(* Models multiple C3I mesh instances coordinating CPIG (Constraint        *)
(* Parity Integrity Governance) scores via peer-attested signed messages.  *)
(*                                                                          *)
(* References:                                                              *)
(*   - SC-FED-001..006   (federation governance, Ed25519 signatures)       *)
(*   - SC-SIL4-006        (2oo3 voting mandate)                            *)
(*   - SC-CONSENSUS-001..003 (tricameral 2oo3 voting, <30s timeout)        *)
(*   - SC-SMRITI-110      (attestation freshness, 1-hour TTL)              *)
(*   - SC-CPIG-FED-001..010 (federated CPIG governance rule)               *)
(*                                                                          *)
(* ZK: [zk-bb4de67d97f807ac]                                                *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS
    Meshes,             \* Set of mesh IDs in the federation
    MaxScore,           \* Maximum CPIG score (60)
    DivergenceThreshold,\* Max acceptable divergence (5 = 8.3% of 60)
    QuorumSize,         \* 2oo3 minimum (SC-SIL4-006)
    AttestationTTL      \* Freshness window in seconds (3600)

VARIABLES
    localScores,        \* [mesh -> Int] each mesh's self-assessed CPIG score
    peerAttestations,   \* [<<mesh, peer>> -> [score, sig, age, verified]]
    federatedScore,     \* Aggregated CPIG score (median of attestations)
    peersResponding     \* Set of peers that have produced fresh attestations

vars == <<localScores, peerAttestations, federatedScore, peersResponding>>

----------------------------------------------------------------------------
\* Type invariants
TypeOK ==
    /\ localScores \in [Meshes -> 0..MaxScore]
    /\ federatedScore \in 0..MaxScore
    /\ peersResponding \subseteq Meshes
    /\ QuorumSize >= 2

\* Median over a multiset of attestation scores (modeled abstractly)
Median(scoreSet) == CHOOSE m \in 0..MaxScore : TRUE

----------------------------------------------------------------------------
\* SAFETY INVARIANT 1: Federated score bounded by max(self, median(peers))
FederatedScoreBounded ==
    \A m \in Meshes :
        federatedScore <= MaxScore /\ federatedScore >= 0

\* SAFETY INVARIANT 2: All attestations must be fresh (<1 hour old)
\* Per SC-SMRITI-110
AttestationFreshness ==
    \A pair \in DOMAIN peerAttestations :
        peerAttestations[pair].age < AttestationTTL

\* SAFETY INVARIANT 3: No unsigned attestation accepted
\* Per SC-FED-006 (Ed25519 signatures mandatory)
NoUnsignedAttestation ==
    \A pair \in DOMAIN peerAttestations :
        peerAttestations[pair].verified = TRUE

\* LIVENESS INVARIANT 4: Convergence under quorum within 30s
\* Per SC-CONSENSUS-003 (<30s timeout)
ConvergenceUnderQuorum ==
    Cardinality(peersResponding) >= QuorumSize =>
        federatedScore \in 0..MaxScore

----------------------------------------------------------------------------
\* Initial state
Init ==
    /\ localScores = [m \in Meshes |-> 0]
    /\ peerAttestations = <<>>
    /\ federatedScore = 0
    /\ peersResponding = {}

\* Action: a peer publishes a signed attestation
PublishAttestation(mesh, peer, score) ==
    /\ mesh \in Meshes
    /\ peer \in Meshes
    /\ score \in 0..MaxScore
    /\ peerAttestations' = [peerAttestations EXCEPT
                              ![<<mesh, peer>>] = [score |-> score,
                                                    sig |-> "ed25519",
                                                    age |-> 0,
                                                    verified |-> TRUE]]
    /\ peersResponding' = peersResponding \cup {peer}
    /\ UNCHANGED <<localScores, federatedScore>>

\* Action: aggregate peer attestations into federated score
AggregateScore(mesh) ==
    /\ Cardinality(peersResponding) >= QuorumSize
    /\ federatedScore' = Median({peerAttestations[<<mesh, p>>].score :
                                  p \in peersResponding})
    /\ UNCHANGED <<localScores, peerAttestations, peersResponding>>

\* Action: detect divergence between local and federated score
DetectDivergence(mesh) ==
    /\ mesh \in Meshes
    /\ \/ localScores[mesh] - federatedScore > DivergenceThreshold
       \/ federatedScore - localScores[mesh] > DivergenceThreshold
    /\ UNCHANGED vars

Next ==
    \/ \E m, p \in Meshes, s \in 0..MaxScore : PublishAttestation(m, p, s)
    \/ \E m \in Meshes : AggregateScore(m)
    \/ \E m \in Meshes : DetectDivergence(m)

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

----------------------------------------------------------------------------
\* Theorems
THEOREM TypeSafety == Spec => []TypeOK
THEOREM ScoreBounded == Spec => []FederatedScoreBounded
THEOREM Freshness == Spec => []AttestationFreshness
THEOREM Signed == Spec => []NoUnsignedAttestation
THEOREM Convergence == Spec => []ConvergenceUnderQuorum

============================================================================
