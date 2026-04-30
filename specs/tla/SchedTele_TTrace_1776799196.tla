---- MODULE SchedTele_TTrace_1776799196 ----
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
        tele_dropped = (501)
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
    \*         IN J!JsonSerialize("SchedTele_TTrace_1776799196.json", _TETrace)

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
\*trace == IODeserialize("SchedTele_TTrace_1776799196.bin", TRUE)
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
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 7,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 8,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 9,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 10,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 11,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 12,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 13,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 14,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 15,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 16,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 17,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 18,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 19,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 20,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 21,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 22,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 23,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 24,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 25,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 26,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 27,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 28,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 29,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 30,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 31,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 32,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 33,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 34,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 35,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 36,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 37,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 38,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 39,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 40,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 41,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 42,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 43,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 44,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 45,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 46,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 47,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 48,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 49,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 50,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 51,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 52,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 53,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 54,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 55,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 56,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 57,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 58,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 59,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 60,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 61,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 62,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 63,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 64,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 65,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 66,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 67,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 68,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 69,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 70,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 71,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 72,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 73,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 74,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 75,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 76,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 77,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 78,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 79,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 80,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 81,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 82,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 83,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 84,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 85,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 86,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 87,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 88,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 89,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 90,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 91,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 92,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 93,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 94,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 95,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 96,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 97,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 98,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 99,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 100,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 101,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 102,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 103,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 104,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 105,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 106,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 107,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 108,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 109,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 110,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 111,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 112,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 113,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 114,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 115,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 116,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 117,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 118,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 119,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 120,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 121,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 122,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 123,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 124,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 125,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 126,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 127,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 128,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 129,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 130,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 131,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 132,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 133,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 134,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 135,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 136,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 137,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 138,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 139,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 140,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 141,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 142,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 143,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 144,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 145,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 146,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 147,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 148,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 149,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 150,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 151,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 152,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 153,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 154,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 155,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 156,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 157,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 158,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 159,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 160,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 161,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 162,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 163,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 164,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 165,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 166,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 167,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 168,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 169,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 170,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 171,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 172,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 173,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 174,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 175,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 176,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 177,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 178,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 179,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 180,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 181,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 182,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 183,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 184,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 185,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 186,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 187,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 188,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 189,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 190,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 191,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 192,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 193,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 194,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 195,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 196,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 197,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 198,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 199,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 200,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 201,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 202,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 203,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 204,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 205,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 206,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 207,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 208,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 209,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 210,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 211,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 212,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 213,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 214,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 215,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 216,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 217,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 218,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 219,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 220,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 221,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 222,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 223,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 224,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 225,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 226,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 227,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 228,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 229,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 230,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 231,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 232,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 233,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 234,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 235,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 236,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 237,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 238,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 239,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 240,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 241,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 242,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 243,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 244,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 245,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 246,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 247,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 248,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 249,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 250,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 251,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 252,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 253,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 254,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 255,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 256,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 257,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 258,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 259,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 260,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 261,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 262,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 263,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 264,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 265,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 266,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 267,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 268,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 269,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 270,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 271,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 272,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 273,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 274,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 275,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 276,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 277,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 278,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 279,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 280,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 281,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 282,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 283,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 284,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 285,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 286,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 287,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 288,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 289,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 290,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 291,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 292,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 293,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 294,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 295,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 296,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 297,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 298,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 299,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 300,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 301,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 302,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 303,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 304,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 305,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 306,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 307,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 308,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 309,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 310,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 311,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 312,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 313,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 314,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 315,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 316,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 317,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 318,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 319,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 320,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 321,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 322,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 323,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 324,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 325,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 326,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 327,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 328,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 329,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 330,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 331,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 332,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 333,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 334,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 335,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 336,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 337,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 338,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 339,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 340,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 341,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 342,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 343,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 344,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 345,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 346,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 347,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 348,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 349,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 350,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 351,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 352,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 353,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 354,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 355,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 356,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 357,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 358,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 359,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 360,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 361,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 362,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 363,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 364,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 365,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 366,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 367,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 368,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 369,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 370,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 371,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 372,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 373,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 374,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 375,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 376,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 377,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 378,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 379,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 380,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 381,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 382,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 383,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 384,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 385,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 386,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 387,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 388,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 389,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 390,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 391,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 392,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 393,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 394,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 395,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 396,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 397,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 398,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 399,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 400,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 401,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 402,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 403,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 404,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 405,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 406,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 407,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 408,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 409,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 410,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 411,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 412,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 413,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 414,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 415,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 416,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 417,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 418,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 419,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 420,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 421,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 422,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 423,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 424,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 425,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 426,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 427,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 428,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 429,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 430,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 431,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 432,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 433,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 434,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 435,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 436,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 437,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 438,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 439,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 440,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 441,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 442,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 443,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 444,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 445,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 446,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 447,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 448,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 449,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 450,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 451,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 452,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 453,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 454,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 455,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 456,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 457,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 458,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 459,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 460,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 461,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 462,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 463,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 464,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 465,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 466,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 467,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 468,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 469,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 470,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 471,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 472,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 473,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 474,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 475,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 476,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 477,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 478,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 479,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 480,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 481,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 482,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 483,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 484,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 485,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 486,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 487,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 488,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 489,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 490,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 491,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 492,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 493,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 494,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 495,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 496,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 497,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 498,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 499,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 500,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>]),
    ([run_id |-> <<1, 2>>,proc_state |-> <<"exited_ok", "running">>,tele_dropped |-> 501,proc_started_at |-> <<0, 0>>,zenoh_up |-> TRUE,tele_buf |-> <<1, 2, 1, 2>>,clock |-> 2,job_state |-> <<"completed", "executing">>,attempt |-> <<1, 1>>])
    >>
----


=============================================================================

---- CONFIG SchedTele_TTrace_1776799196 ----
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
\* Generated on Tue Apr 21 23:29:53 CEST 2026