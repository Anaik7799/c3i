---- MODULE SchedTele_TTrace_1776797950 ----
EXTENDS Sequences, TLCExt, Toolbox, Naturals, TLC, SchedTele

_expression ==
    LET SchedTele_TEExpression == INSTANCE SchedTele_TEExpression
    IN SchedTele_TEExpression!expression
----

_trace ==
    LET SchedTele_TETrace == INSTANCE SchedTele_TETrace
    IN SchedTele_TETrace!trace
----

_inv ==
    ~(
        TLCGet("level") = Len(_TETrace)
        /\
        run_id = (<<1, 2>>)
        /\
        proc_state = (<<"exited_ok", "running">>)
        /\
        tele_dropped = (7)
        /\
        proc_started_at = (<<0, 0>>)
        /\
        zenoh_up = (TRUE)
        /\
        tele_buf = (<<1, 2, 1, 2>>)
        /\
        clock = (2)
        /\
        job_state = (<<"completed", "executing">>)
        /\
        attempt = (<<1, 1>>)
    )
----

_init ==
    /\ tele_buf = _TETrace[1].tele_buf
    /\ job_state = _TETrace[1].job_state
    /\ zenoh_up = _TETrace[1].zenoh_up
    /\ tele_dropped = _TETrace[1].tele_dropped
    /\ clock = _TETrace[1].clock
    /\ proc_state = _TETrace[1].proc_state
    /\ proc_started_at = _TETrace[1].proc_started_at
    /\ run_id = _TETrace[1].run_id
    /\ attempt = _TETrace[1].attempt
----

_next ==
    /\ \E i,j \in DOMAIN _TETrace:
        /\ \/ /\ j = i + 1
              /\ i = TLCGet("level")
        /\ tele_buf  = _TETrace[i].tele_buf
        /\ tele_buf' = _TETrace[j].tele_buf
        /\ job_state  = _TETrace[i].job_state
        /\ job_state' = _TETrace[j].job_state
        /\ zenoh_up  = _TETrace[i].zenoh_up
        /\ zenoh_up' = _TETrace[j].zenoh_up
        /\ tele_dropped  = _TETrace[i].tele_dropped
        /\ tele_dropped' = _TETrace[j].tele_dropped
        /\ clock  = _TETrace[i].clock
        /\ clock' = _TETrace[j].clock
        /\ proc_state  = _TETrace[i].proc_state
        /\ proc_state' = _TETrace[j].proc_state
        /\ proc_started_at  = _TETrace[i].proc_started_at
        /\ proc_started_at' = _TETrace[j].proc_started_at
        /\ run_id  = _TETrace[i].run_id
        /\ run_id' = _TETrace[j].run_id
        /\ attempt  = _TETrace[i].attempt
        /\ attempt' = _TETrace[j].attempt

\* Uncomment the ASSUME below to write the states of the error trace
\* to the given file in Json format. Note that you can pass any tuple
\* to `JsonSerialize`. For example, a sub-sequence of _TETrace.
    \* ASSUME
    \*     LET J == INSTANCE Json
    \*         IN J!JsonSerialize("SchedTele_TTrace_1776797950.json", _TETrace)

=============================================================================

 Note that you can extract this module `SchedTele_TEExpression`
  to a dedicated file to reuse `expression` (the module in the 
  dedicated `SchedTele_TEExpression.tla` file takes precedence 
  over the module `SchedTele_TEExpression` below).

---- MODULE SchedTele_TEExpression ----
EXTENDS Sequences, TLCExt, Toolbox, Naturals, TLC, SchedTele

expression == 
    [
        \* To hide variables of the `SchedTele` spec from the error trace,
        \* remove the variables below.  The trace will be written in the order
        \* of the fields of this record.
        tele_buf |-> tele_buf
        ,job_state |-> job_state
        ,zenoh_up |-> zenoh_up
        ,tele_dropped |-> tele_dropped
        ,clock |-> clock
        ,proc_state |-> proc_state
        ,proc_started_at |-> proc_started_at
        ,run_id |-> run_id
        ,attempt |-> attempt
        
        \* Put additional constant-, state-, and action-level expressions here:
        \* ,_stateNumber |-> _TEPosition
        \* ,_tele_bufUnchanged |-> tele_buf = tele_buf'
        
        \* Format the `tele_buf` variable as Json value.
        \* ,_tele_bufJson |->
        \*     LET J == INSTANCE Json
        \*     IN J!ToJson(tele_buf)
        
        \* Lastly, you may build expressions over arbitrary sets of states by
        \* leveraging the _TETrace operator.  For example, this is how to
        \* count the number of times a spec variable changed up to the current
        \* state in the trace.
        \* ,_tele_bufModCount |->
        \*     LET F[s \in DOMAIN _TETrace] ==
        \*         IF s = 1 THEN 0
        \*         ELSE IF _TETrace[s].tele_buf # _TETrace[s-1].tele_buf
        \*             THEN 1 + F[s-1] ELSE F[s-1]
        \*     IN F[_TEPosition - 1]
    ]

=============================================================================



Parsing and semantic processing can take forever if the trace below is long.
 In this case, it is advised to uncomment the module below to deserialize the
 trace from a generated binary file.

\*
\*---- MODULE SchedTele_TETrace ----
\*EXTENDS IOUtils, TLC, SchedTele
\*
\*trace == IODeserialize("SchedTele_TTrace_1776797950.bin", TRUE)
\*
\*=============================================================================
\*

---- MODULE SchedTele_TETrace ----
EXTENDS TLC, SchedTele

trace == 
    <<
    ([run_id |-> <<0, 0>>,proc_state |-> <<"idle", "idle">>,tele_dropped |-> 0,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<>>,clock |-> 0,job_state |-> <<"available", "available">>,attempt |-> <<0, 0>>]),
    ([run_id |-> <<1, 0>>,proc_state |-> <<"running", "idle">>,tele_dropped |-> 0,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1>>,clock |-> 0,job_state |-> <<"executing", "available">>,attempt |-> <<1, 0>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"running", "running">>,tele_dropped |-> 0,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2>>,clock |-> 0,job_state |-> <<"executing", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 0,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1>>,clock |-> 0,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 0,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1>>,clock |-> 1,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 0,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 0,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 1,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 2,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 3,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 4,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 5,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 6,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 7,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>])
    >>
----


=============================================================================

---- CONFIG SchedTele_TTrace_1776797950 ----
CONSTANTS
    MaxJobs = 2
    MaxAttempts = 2
    TelemetryBufCap = 4
    TimeoutTicks = 3
    HeartbeatTicks = 2
    MaxTicks = 6

INVARIANT
    _inv

CHECK_DEADLOCK
    \* CHECK_DEADLOCK off because of PROPERTY or INVARIANT above.
    FALSE

INIT
    _init

NEXT
    _next

CONSTANT
    _TETrace <- _trace

ALIAS
    _expression
=============================================================================
\* Generated on Tue Apr 21 20:59:51 CEST 2026