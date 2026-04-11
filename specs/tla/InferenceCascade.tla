---- MODULE InferenceCascade ----
\* TLA+ specification for the 6-tier hedged inference cascade
\* STAMP: SC-COG-001
\* Version: v22.5.0-CORTEX

EXTENDS Integers, Sequences, FiniteSets

CONSTANTS Tiers, MaxFailures, CooldownSecs

VARIABLES activeTier, circuitStates, tiersTried, response

TypeOK ==
    /\ activeTier \in 1..6
    /\ circuitStates \in [Tiers -> {"closed", "open", "half_open"}]
    /\ tiersTried \subseteq Tiers
    /\ response \in {"pending", "success", "failure"}

Init ==
    /\ activeTier = 1
    /\ circuitStates = [t \in Tiers |-> "closed"]
    /\ tiersTried = {}
    /\ response = "pending"

\* Tier succeeds: response delivered
TierSuccess(t) ==
    /\ response = "pending"
    /\ circuitStates[t] # "open"
    /\ response' = "success"
    /\ activeTier' = t
    /\ tiersTried' = tiersTried \cup {t}
    /\ UNCHANGED circuitStates

\* Tier fails: try next tier
TierFailure(t) ==
    /\ response = "pending"
    /\ circuitStates[t] # "open"
    /\ tiersTried' = tiersTried \cup {t}
    /\ UNCHANGED <<activeTier, response>>
    /\ circuitStates' = [circuitStates EXCEPT ![t] =
        IF circuitStates[t] = "closed" THEN "open" ELSE circuitStates[t]]

\* Circuit breaker reset after cooldown
CircuitReset(t) ==
    /\ circuitStates[t] = "open"
    /\ circuitStates' = [circuitStates EXCEPT ![t] = "half_open"]
    /\ UNCHANGED <<activeTier, tiersTried, response>>

\* Rule fallback always succeeds (tier 5)
RuleFallback ==
    /\ response = "pending"
    /\ Cardinality(tiersTried) >= 4
    /\ response' = "success"
    /\ activeTier' = 5
    /\ tiersTried' = tiersTried \cup {5}
    /\ UNCHANGED circuitStates

Next ==
    \/ \E t \in Tiers : TierSuccess(t)
    \/ \E t \in Tiers : TierFailure(t)
    \/ \E t \in Tiers : CircuitReset(t)
    \/ RuleFallback

\* SAFETY: Every message eventually gets a response (no blackhole)
NoBlackhole == <>(response = "success")

\* SAFETY: Circuit breakers prevent wasted timeouts
CircuitProtection == \A t \in Tiers :
    circuitStates[t] = "open" => t \notin tiersTried

====
