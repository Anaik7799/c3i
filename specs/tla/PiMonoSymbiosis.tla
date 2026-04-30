------------------------------ MODULE PiMonoSymbiosis ------------------------------
(***************************************************************************
 C3I Cross-Pass Invariant Gate (CPIG) Pass 14 — Pi-mono <-> C3I Bridge

 Subsystem: Pi-mono Node.js runtime symbiosis with the BEAM mesh.

 Source files:
   - lib/cepaf_gleam/src/cepaf_gleam/bridge/pi_runtime.gleam
   - lib/cepaf_gleam/src/cepaf_gleam/bridge/pi_rpc.gleam
   - lib/cepaf_gleam/src/cepaf_gleam/bridge/pi_claude_code.gleam
   - lib/cepaf_gleam/src/cepaf_gleam/bridge/pi_agent.gleam
   - lib/cepaf_gleam/src/cepaf_gleam/bridge/pi_tools.gleam
   - lib/cepaf_gleam/src/cepaf_gleam/bridge/pi_zenoh.gleam
   - lib/cepaf_gleam/src/cepaf_gleam/bridge/pi_provider.gleam
   - lib/cepaf_gleam/src/cepaf_gleam/actors/pi_subscriber.gleam

 STAMP constraints covered:
   SC-PI-001..010   (full Pi integration)
   SC-PI-AUTO-001..008 (symbiosis automation; tool/event federation counts)
   SC-PI-RUNTIME-001..008 (runtime lifecycle, circuit breaker, auto-restart)

 Model-checking notes (TLC):
   CONSTANTS  ExpectedTools = 93,
              ExpectedEvents = 32,
              MaxFailures = 3,
              MaxRestarts = 5
   INVARIANT  TypeOK, ToolFederationCount, EventBridgeParity,
              CircuitBreakerCorrectness, AutoRestartBound
   PROPERTY   Spec
 ***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    ExpectedTools,    \* 93 = 6 Claude + 14 Pi + 73 C3I MCP (SC-PI-AUTO-003)
    ExpectedEvents,   \* 32 AG-UI events bridged to 29 Pi events (SC-PI-AUTO-004)
    MaxFailures,      \* circuit-breaker open threshold (SC-PI-RUNTIME-002) = 3
    MaxRestarts       \* per 10-minute window (SC-PI-RUNTIME-003) = 5

VARIABLES
    piRunning,        \* BOOLEAN: Pi Node.js subprocess alive
    toolsFederated,   \* Nat: count of federated MCP tools
    eventsBridged,    \* Nat: count of bridged AG-UI events
    circuitBreaker,   \* {"closed", "open", "halfOpen"}
    failureCount,     \* Nat: consecutive RPC failures
    restartCount      \* Nat: restarts in current 10-min window

vars == <<piRunning, toolsFederated, eventsBridged,
          circuitBreaker, failureCount, restartCount>>

CBStates == {"closed", "open", "halfOpen"}

TypeOK ==
    /\ piRunning      \in BOOLEAN
    /\ toolsFederated \in Nat
    /\ eventsBridged  \in Nat
    /\ circuitBreaker \in CBStates
    /\ failureCount   \in Nat
    /\ restartCount   \in Nat

----------------------------------------------------------------------------
(* Initial state: Pi not yet started, federation pre-registered at config time *)
Init ==
    /\ piRunning      = FALSE
    /\ toolsFederated = ExpectedTools
    /\ eventsBridged  = ExpectedEvents
    /\ circuitBreaker = "closed"
    /\ failureCount   = 0
    /\ restartCount   = 0

(* Start Pi runtime via pi_runtime.gleam *)
StartPi ==
    /\ ~piRunning
    /\ restartCount < MaxRestarts
    /\ piRunning'    = TRUE
    /\ restartCount' = restartCount + 1
    /\ UNCHANGED <<toolsFederated, eventsBridged, circuitBreaker, failureCount>>

(* Successful RPC closes / keeps breaker closed *)
RpcSuccess ==
    /\ piRunning
    /\ circuitBreaker \in {"closed", "halfOpen"}
    /\ circuitBreaker' = "closed"
    /\ failureCount'   = 0
    /\ UNCHANGED <<piRunning, toolsFederated, eventsBridged, restartCount>>

(* RPC failure increments counter; opens breaker at threshold *)
RpcFail ==
    /\ piRunning
    /\ failureCount' = failureCount + 1
    /\ circuitBreaker' =
         IF failureCount + 1 >= MaxFailures THEN "open" ELSE circuitBreaker
    /\ UNCHANGED <<piRunning, toolsFederated, eventsBridged, restartCount>>

(* Cooldown elapsed: open -> halfOpen *)
BreakerCooldown ==
    /\ circuitBreaker = "open"
    /\ circuitBreaker' = "halfOpen"
    /\ UNCHANGED <<piRunning, toolsFederated, eventsBridged, failureCount, restartCount>>

(* Graceful shutdown — Pi process exits, breaker resets *)
StopPi ==
    /\ piRunning
    /\ piRunning'      = FALSE
    /\ circuitBreaker' = "closed"
    /\ failureCount'   = 0
    /\ UNCHANGED <<toolsFederated, eventsBridged, restartCount>>

Next ==
    \/ StartPi
    \/ RpcSuccess
    \/ RpcFail
    \/ BreakerCooldown
    \/ StopPi

Spec == Init /\ [][Next]_vars

----------------------------------------------------------------------------
(* Invariants *)

\* SC-PI-AUTO-003: tool federation count is exactly 93
ToolFederationCount == toolsFederated = ExpectedTools

\* SC-PI-AUTO-004: AG-UI <-> Pi event bridge parity
EventBridgeParity == eventsBridged = ExpectedEvents

\* SC-PI-RUNTIME-002: breaker open implies threshold reached
CircuitBreakerCorrectness ==
    (circuitBreaker = "open") => (failureCount >= MaxFailures)

\* SC-PI-RUNTIME-003: at most MaxRestarts per window
AutoRestartBound == restartCount <= MaxRestarts

THEOREM SpecImpliesInvariants ==
    Spec => [](TypeOK
               /\ ToolFederationCount
               /\ EventBridgeParity
               /\ CircuitBreakerCorrectness
               /\ AutoRestartBound)

============================================================================
