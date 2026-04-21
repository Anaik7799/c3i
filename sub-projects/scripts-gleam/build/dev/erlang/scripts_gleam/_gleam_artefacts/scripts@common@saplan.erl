-module(scripts@common@saplan).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/scripts/common/saplan.gleam").
-export([binary/0, invoke/1, add_task/2, update_task/2, set_pref/3, enqueue/4, queue_list/0, send_email/4, available/0, render/1]).
-export_type([run/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " scripts/common/saplan — uniform wrapper around the `sa-plan` binary, the\n"
    " single system-integration surface for gleam scripts.\n"
    "\n"
    " SC-SCRIPT-GLEAM-001 — thin binary invocation is explicitly allowed.\n"
    " SC-SCHED-WORK-001 — workers::dispatch in the Rust daemon is the only\n"
    " runtime executor; we integrate with it by calling `./sa-plan ...`.\n"
    "\n"
    " This helper hides the correct CWD + binary path so every script uses the\n"
    " system's real, running authority.\n"
).

-type run() :: {run, integer(), binary(), binary()}.

-file("src/scripts/common/saplan.gleam", 18).
?DOC(
    " Path to the sa-plan binary. Prefers env `SAPLAN_BIN`, then the known\n"
    " release layout inside the c3i sub-project.\n"
).
-spec binary() -> binary().
binary() ->
    case envoy_ffi:get(<<"SAPLAN_BIN"/utf8>>) of
        {ok, V} ->
            V;

        {error, _} ->
            Root = case envoy_ffi:get(<<"C3I_REPO_ROOT"/utf8>>) of
                {ok, V@1} ->
                    V@1;

                {error, _} ->
                    <<"/home/an/dev/ver/c3i"/utf8>>
            end,
            <<Root/binary, "/sub-projects/c3i/sa-plan"/utf8>>
    end.

-file("src/scripts/common/saplan.gleam", 43).
-spec to_cl(binary()) -> gleam@erlang@charlist:charlist().
to_cl(S) ->
    unicode:characters_to_list(S).

-file("src/scripts/common/saplan.gleam", 49).
?DOC(
    " Invoke `sa-plan <args>` and return a `Run`. Stdout+stderr are merged into\n"
    " the `stdout` field (system's binary itself prints to stdout).\n"
).
-spec invoke(list(binary())) -> run().
invoke(Args) ->
    {Out, Rc} = scripts_sh_ffi:run_capture(
        to_cl(binary()),
        gleam@list:map(Args, fun to_cl/1)
    ),
    {run, Rc, unicode:characters_to_binary(Out), <<""/utf8>>}.

-file("src/scripts/common/saplan.gleam", 57).
?DOC(
    " Typed helper: add a task. Returns the run object; callers parse the id\n"
    " from stdout or rely on state snapshots from other calls.\n"
).
-spec add_task(binary(), binary()) -> run().
add_task(Title, Priority) ->
    invoke([<<"add"/utf8>>, Title, Priority]).

-file("src/scripts/common/saplan.gleam", 62).
?DOC(" Mark an existing task as completed (or any status string the CLI accepts).\n").
-spec update_task(binary(), binary()) -> run().
update_task(Id, Status) ->
    invoke([<<"update"/utf8>>, Id, Status]).

-file("src/scripts/common/saplan.gleam", 67).
?DOC(" Set a Smriti preference under a category.\n").
-spec set_pref(binary(), binary(), binary()) -> run().
set_pref(Category, Key, Value) ->
    invoke(
        [<<"set-pref"/utf8>>,
            <<"--category"/utf8>>,
            Category,
            <<"--key"/utf8>>,
            Key,
            <<"--value"/utf8>>,
            Value]
    ).

-file("src/scripts/common/saplan.gleam", 75).
?DOC(" Enqueue an Oban-style job through `sa-plan job-enqueue`.\n").
-spec enqueue(binary(), binary(), binary(), binary()) -> run().
enqueue(Queue, Worker, Args_json, Unique_key) ->
    invoke(
        [<<"job-enqueue"/utf8>>,
            <<"--queue"/utf8>>,
            Queue,
            <<"--worker"/utf8>>,
            Worker,
            <<"--args"/utf8>>,
            Args_json,
            <<"--priority"/utf8>>,
            <<"0"/utf8>>,
            <<"--max-attempts"/utf8>>,
            <<"2"/utf8>>,
            <<"--unique-key"/utf8>>,
            Unique_key]
    ).

-file("src/scripts/common/saplan.gleam", 93).
?DOC(" Request a queue state snapshot (JSON on stdout).\n").
-spec queue_list() -> run().
queue_list() ->
    invoke([<<"queue-list"/utf8>>, <<"--json"/utf8>>]).

-file("src/scripts/common/saplan.gleam", 98).
?DOC(" Thin wrapper for sending email with attachments (absolute paths required).\n").
-spec send_email(binary(), binary(), binary(), list(binary())) -> run().
send_email(To, Subject, Body, Attachments) ->
    Base = [<<"send-email"/utf8>>,
        <<"--to"/utf8>>,
        To,
        <<"--subject"/utf8>>,
        Subject,
        <<"--body"/utf8>>,
        Body],
    Attach_args = gleam@list:flat_map(
        Attachments,
        fun(A) -> [<<"--attach"/utf8>>, A] end
    ),
    invoke(lists:append(Base, Attach_args)).

-file("src/scripts/common/saplan.gleam", 113).
?DOC(" Smoke: true if `sa-plan --help` exits 0.\n").
-spec available() -> boolean().
available() ->
    {run, Rc, _, _} = invoke([<<"--help"/utf8>>]),
    Rc =:= 0.

-file("src/scripts/common/saplan.gleam", 119).
?DOC(" Debug-render of a Run's first 200 chars (for logs).\n").
-spec render(run()) -> binary().
render(R) ->
    <<<<<<"rc="/utf8, (case erlang:element(2, R) of
                    0 ->
                        <<"0"/utf8>>;

                    _ ->
                        <<"nonzero"/utf8>>
                end)/binary>>/binary, " out="/utf8>>/binary, (gleam@string:slice(
            erlang:element(3, R),
            0,
            200
        ))/binary>>.
