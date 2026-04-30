---- MODULE SyncProtocol ----
(*
 * Matrix Client-Server Sync Protocol
 * Ref: https://spec.matrix.org/v1.13/client-server-api/#syncing
 *
 * Models /sync with initial sync, incremental sync, long-polling.
 * Properties: no skips, no duplicates, order preserved.
 *)

EXTENDS Integers, Sequences, FiniteSets, TLC

CONSTANTS MaxEvents, TimeoutMs

ASSUME MaxEvents >= 1
ASSUME TimeoutMs > 0

EventIds == 1..MaxEvents
Tokens == 0..MaxEvents

VARIABLES
    serverEvents, nextEvent,
    clientToken, clientReceived,
    syncPhase

vars == <<serverEvents, nextEvent, clientToken, clientReceived, syncPhase>>

TypeOK ==
    /\ serverEvents  \in Seq(EventIds)
    /\ nextEvent     \in 1..MaxEvents+1
    /\ clientToken   \in Tokens
    /\ clientReceived \in Seq(EventIds)
    /\ syncPhase     \in {"idle", "pending", "responding", "timeout"}
    /\ Len(serverEvents) <= MaxEvents
    /\ Len(clientReceived) <= MaxEvents

EventsAfter(token) ==
    IF token >= Len(serverEvents) THEN <<>>
    ELSE SubSeq(serverEvents, token + 1, Len(serverEvents))

Init ==
    /\ serverEvents   = <<>>
    /\ nextEvent      = 1
    /\ clientToken    = 0
    /\ clientReceived = <<>>
    /\ syncPhase      = "idle"

ProduceEvent ==
    /\ nextEvent <= MaxEvents
    /\ serverEvents' = Append(serverEvents, nextEvent)
    /\ nextEvent'    = nextEvent + 1
    /\ UNCHANGED <<clientToken, clientReceived, syncPhase>>

ClientRequestSync ==
    /\ syncPhase = "idle"
    /\ syncPhase' = "pending"
    /\ UNCHANGED <<serverEvents, nextEvent, clientToken, clientReceived>>

ServerRespondImmediate ==
    /\ syncPhase = "pending"
    /\ Len(EventsAfter(clientToken)) > 0
    /\ LET batch == EventsAfter(clientToken)
       IN
       /\ clientReceived' = clientReceived \o batch
       /\ clientToken'    = Len(serverEvents)
    /\ syncPhase' = "responding"
    /\ UNCHANGED <<serverEvents, nextEvent>>

ServerLongPollTimeout ==
    /\ syncPhase = "pending"
    /\ Len(EventsAfter(clientToken)) = 0
    /\ syncPhase'  = "timeout"
    /\ UNCHANGED <<serverEvents, nextEvent, clientToken, clientReceived>>

ClientAckResponse ==
    /\ syncPhase = "responding"
    /\ syncPhase' = "idle"
    /\ UNCHANGED <<serverEvents, nextEvent, clientToken, clientReceived>>

ClientRetryAfterTimeout ==
    /\ syncPhase = "timeout"
    /\ syncPhase' = "pending"
    /\ UNCHANGED <<serverEvents, nextEvent, clientToken, clientReceived>>

Next ==
    \/ ProduceEvent
    \/ ClientRequestSync
    \/ ServerRespondImmediate
    \/ ServerLongPollTimeout
    \/ ClientAckResponse
    \/ ClientRetryAfterTimeout

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

\* No event delivered that server doesn't have
ClientOnlyReceivesKnownEvents ==
    \A i \in 1..Len(clientReceived) :
        \E j \in 1..Len(serverEvents) :
            clientReceived[i] = serverEvents[j]

\* No duplicates
NoDuplicateDelivery ==
    \A i \in 1..Len(clientReceived) :
        \A j \in 1..Len(clientReceived) :
            i # j => clientReceived[i] # clientReceived[j]

\* Order preserved
DeliveryOrderPreserved ==
    \A i \in 1..Len(clientReceived) :
        \A j \in 1..Len(clientReceived) :
            i < j =>
                \E si \in 1..Len(serverEvents) :
                \E sj \in 1..Len(serverEvents) :
                    /\ serverEvents[si] = clientReceived[i]
                    /\ serverEvents[sj] = clientReceived[j]
                    /\ si < sj

\* Token never ahead of server
TokenNeverAheadOfServer == clientToken <= Len(serverEvents)

\* Prefix coverage
PrefixCoverage == Len(clientReceived) = clientToken

\* Liveness: every event eventually delivered
EventualDelivery ==
    \A e \in 1..MaxEvents :
        (nextEvent > e) ~> (\E i \in 1..Len(clientReceived) : clientReceived[i] = e)

INVARIANT TypeOK
INVARIANT ClientOnlyReceivesKnownEvents
INVARIANT NoDuplicateDelivery
INVARIANT DeliveryOrderPreserved
INVARIANT TokenNeverAheadOfServer
INVARIANT PrefixCoverage

PROPERTY EventualDelivery

====
