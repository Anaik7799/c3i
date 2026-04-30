--------------------------- MODULE PiCircuitBreaker ---------------------------
(***************************************************************************)
(* Pi Runtime Circuit Breaker formal model.                                *)
(* References: bridge/pi_runtime.gleam, SC-PI-RUNTIME-002..007.            *)
(* ZK: [zk-bb4de67d97f807ac], [zk-d8929d43344a292d].                       *)
(*                                                                          *)
(* Models the 3-state circuit breaker protecting Pi-mono Node.js subprocess *)
(* from cascade failures during LLM provider outages.                       *)
(***************************************************************************)
EXTENDS Naturals, TLC

CONSTANTS Threshold,        \* failure threshold before open (=3)
          CooldownPeriod,   \* seconds in Open before HalfOpen (=60)
          MaxTime           \* model checking horizon

ASSUME Threshold = 3
ASSUME CooldownPeriod = 60

VARIABLES state,            \* {Closed, Open, HalfOpen}
          failureCount,     \* consecutive failure counter
          lastFailure,      \* monotonic time of last failure entry to Open
          now               \* abstract clock

vars == <<state, failureCount, lastFailure, now>>

States == {"Closed", "Open", "HalfOpen"}

TypeOK ==
  /\ state \in States
  /\ failureCount \in 0..Threshold
  /\ lastFailure \in 0..MaxTime
  /\ now \in 0..MaxTime

Init ==
  /\ state = "Closed"
  /\ failureCount = 0
  /\ lastFailure = 0
  /\ now = 0

(* Successful Pi RPC call resets counter when Closed/HalfOpen *)
Success ==
  /\ state \in {"Closed", "HalfOpen"}
  /\ state' = "Closed"
  /\ failureCount' = 0
  /\ UNCHANGED <<lastFailure, now>>

(* Failure increments; on Threshold, transitions Closed -> Open *)
FailureClosed ==
  /\ state = "Closed"
  /\ failureCount < Threshold
  /\ failureCount' = failureCount + 1
  /\ IF failureCount + 1 >= Threshold
       THEN /\ state' = "Open"
            /\ lastFailure' = now
       ELSE /\ state' = "Closed"
            /\ UNCHANGED lastFailure
  /\ UNCHANGED now

(* HalfOpen probe failure -> Open again *)
FailureHalfOpen ==
  /\ state = "HalfOpen"
  /\ state' = "Open"
  /\ lastFailure' = now
  /\ UNCHANGED <<failureCount, now>>

(* Cooldown elapses -> Open transitions to HalfOpen for probe *)
CooldownElapsed ==
  /\ state = "Open"
  /\ now - lastFailure >= CooldownPeriod
  /\ state' = "HalfOpen"
  /\ UNCHANGED <<failureCount, lastFailure, now>>

Tick ==
  /\ now < MaxTime
  /\ now' = now + 1
  /\ UNCHANGED <<state, failureCount, lastFailure>>

Next == Success \/ FailureClosed \/ FailureHalfOpen \/ CooldownElapsed \/ Tick

Spec == Init /\ [][Next]_vars /\ WF_vars(CooldownElapsed) /\ WF_vars(Tick)

(* ===== INVARIANTS ===== *)

(* Only valid transitions: Closed->Open, Open->HalfOpen, HalfOpen->{Closed,Open} *)
CircuitBreakerStateTransitions ==
  [][\/ state' = state
     \/ (state = "Closed" /\ state' = "Open")
     \/ (state = "Open" /\ state' = "HalfOpen")
     \/ (state = "HalfOpen" /\ state' \in {"Closed", "Open"})]_vars

(* Open requires threshold breach *)
ThresholdRespected ==
  state = "Open" => failureCount >= Threshold

(* HalfOpen reachable only after cooldown *)
CooldownEnforced ==
  state = "HalfOpen" => now - lastFailure >= CooldownPeriod

(* Liveness: eventually leaves Open *)
NoForeverOpen == <>(state # "Open")

=============================================================================
