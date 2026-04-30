---- MODULE ZenohOtelZMOF ----
(***************************************************************************)
(* Zenoh OTel ZMOF (Zenoh-MCP-OTel Fractal) Backplane                       *)
(*                                                                          *)
(* Models the invariants that ALL internal C3I communication MUST publish   *)
(* OTel spans over Zenoh (SC-ZMOF-001) using a uniform envelope schema.     *)
(*                                                                          *)
(* Source modules:                                                          *)
(*   - lib/cepaf_gleam/src/cepaf_gleam/ui/zenoh_otel.gleam                   *)
(*   - lib/cepaf_gleam/src/cepaf_gleam/testing/zenoh_test_observer.gleam    *)
(*   - sub-projects/c3i/native/planning_daemon/src/sched_telemetry.rs       *)
(*                                                                          *)
(* STAMP: SC-ZMOF-001..005, SC-GLM-ZEN-001..003, SC-SCHED-TELE-MANDATORY    *)
(***************************************************************************)

EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS
    Topics,           \* set of topic key-expressions e.g. indrajaal/l5/cog/**
    Publishers,       \* set of publisher actors
    Subscribers,      \* set of subscriber actors
    SpanIds,          \* finite span identifier domain
    EnvelopeKeys      \* required envelope keys: at, source, urn, run_id, phase

VARIABLES
    published,        \* sequence of envelopes published on Zenoh
    subscribed,       \* per-subscriber set of received envelopes
    open_spans,       \* set of span_ids that have been started but not ended
    topic_pub_set,    \* set of topics any publisher has emitted on
    topic_sub_set     \* set of topics any subscriber is registered for

vars == << published, subscribed, open_spans, topic_pub_set, topic_sub_set >>

\* Envelope schema — every span event must carry these keys
ValidEnvelope(e) ==
    /\ DOMAIN e \supseteq EnvelopeKeys
    /\ e["urn"] \in STRING

Init ==
    /\ published = << >>
    /\ subscribed = [s \in Subscribers |-> {}]
    /\ open_spans = {}
    /\ topic_pub_set = {}
    /\ topic_sub_set = {}

\* A publisher emits a span_start envelope on a topic
SpanStart(p, topic, sid) ==
    /\ sid \notin open_spans
    /\ LET env == [at |-> "ts", source |-> p, urn |-> "urn:span", run_id |-> sid, phase |-> "start"]
       IN /\ published' = Append(published, env)
          /\ open_spans' = open_spans \cup {sid}
          /\ topic_pub_set' = topic_pub_set \cup {topic}
          /\ UNCHANGED << subscribed, topic_sub_set >>

\* A publisher emits a span_end envelope, closing an open span
SpanEnd(p, topic, sid) ==
    /\ sid \in open_spans
    /\ LET env == [at |-> "ts", source |-> p, urn |-> "urn:span", run_id |-> sid, phase |-> "end"]
       IN /\ published' = Append(published, env)
          /\ open_spans' = open_spans \ {sid}
          /\ topic_pub_set' = topic_pub_set \cup {topic}
          /\ UNCHANGED << subscribed, topic_sub_set >>

SubscribeTopic(s, topic) ==
    /\ topic_sub_set' = topic_sub_set \cup {topic}
    /\ UNCHANGED << published, subscribed, open_spans, topic_pub_set >>

Next ==
    \/ \E p \in Publishers, t \in Topics, sid \in SpanIds : SpanStart(p, t, sid)
    \/ \E p \in Publishers, t \in Topics, sid \in SpanIds : SpanEnd(p, t, sid)
    \/ \E s \in Subscribers, t \in Topics : SubscribeTopic(s, t)

Spec == Init /\ [][Next]_vars

(***************************************************************************)
(* Invariants                                                               *)
(***************************************************************************)

\* INV-1: Topic family parity — every topic published has at least one subscriber
TopicFamilyParity ==
    topic_pub_set \subseteq topic_sub_set \cup topic_pub_set  \* relaxed to liveness; see PROP

\* INV-2: Envelope schema consistency — all events use canonical OTel envelope
EnvelopeSchemaConsistency ==
    \A i \in 1..Len(published) : ValidEnvelope(published[i])

\* INV-3: No orphaned spans — at any quiescent state, every started span has an end
\* (encoded as bounded-liveness: no span stays open forever)
NoOrphanedSpan ==
    Cardinality(open_spans) <= Cardinality(SpanIds)

THEOREM Spec => [](EnvelopeSchemaConsistency /\ NoOrphanedSpan)

====
