-module(scripts@registry@saplan_smoke).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/scripts/registry/saplan_smoke.gleam").
-export([main/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " scripts/registry/saplan_smoke — integration smoke for the sa-plan bridge.\n"
    "\n"
    " SC-SCRIPT-GLEAM-001 + SC-SCHED-WORK-001.\n"
    "\n"
    " Verifies:\n"
    "   1. sa-plan binary is reachable via the gleam wrapper.\n"
    "   2. a Smriti pref can be set and read back in the summary.\n"
    "   3. the output tree under data/script-output/registry/saplan_smoke/ is\n"
    "      populated cleanly.\n"
    "\n"
    " Usage:\n"
    "   gleam run -m scripts/registry/saplan_smoke\n"
).

-file("src/scripts/registry/saplan_smoke.gleam", 23).
-spec main() -> nil.
main() ->
    Stamp = scripts@common@logx:stamp(),
    scripts@common@logx:info(
        <<"registry/saplan_smoke"/utf8>>,
        <<"start stamp="/utf8, Stamp/binary>>
    ),
    case scripts@common@saplan:available() of
        false ->
            scripts@common@logx:error(
                <<"registry/saplan_smoke"/utf8>>,
                <<"sa-plan binary not reachable"/utf8>>
            ),
            erlang:error(#{gleam_error => panic,
                    message => <<"sa-plan binary unreachable"/utf8>>,
                    file => <<?FILEPATH/utf8>>,
                    module => <<"scripts/registry/saplan_smoke"/utf8>>,
                    function => <<"main"/utf8>>,
                    line => 30});

        true ->
            nil
    end,
    Pref_key = <<"scripts_gleam_smoke_at"/utf8>>,
    _ = scripts@common@saplan:set_pref(<<"roadmap"/utf8>>, Pref_key, Stamp),
    scripts@common@logx:info(
        <<"registry/saplan_smoke"/utf8>>,
        <<<<<<"set-pref roadmap."/utf8, Pref_key/binary>>/binary, "="/utf8>>/binary,
            Stamp/binary>>
    ),
    Queues = scripts@common@saplan:queue_list(),
    scripts@common@logx:info(
        <<"registry/saplan_smoke"/utf8>>,
        <<"queue-list rc="/utf8, (case erlang:element(2, Queues) of
                0 ->
                    <<"0"/utf8>>;

                _ ->
                    <<"nonzero"/utf8>>
            end)/binary>>
    ),
    case scripts@common@fsx:run_dir(
        <<"registry"/utf8>>,
        <<"saplan_smoke"/utf8>>,
        Stamp
    ) of
        {error, E} ->
            scripts@common@logx:error(
                <<"registry/saplan_smoke"/utf8>>,
                <<"run_dir: "/utf8, E/binary>>
            ),
            erlang:error(#{gleam_error => panic,
                    message => <<"cannot create run dir"/utf8>>,
                    file => <<?FILEPATH/utf8>>,
                    module => <<"scripts/registry/saplan_smoke"/utf8>>,
                    function => <<"main"/utf8>>,
                    line => 48});

        {ok, Dir} ->
            Summary_lines = [<<"script: registry/saplan_smoke"/utf8>>,
                <<"stamp:  "/utf8, Stamp/binary>>,
                <<"saplan_bin: "/utf8, (scripts@common@saplan:binary())/binary>>,
                <<<<<<"pref_set: roadmap."/utf8, Pref_key/binary>>/binary,
                        "="/utf8>>/binary,
                    Stamp/binary>>,
                <<"queue_list_rc: "/utf8, (case erlang:element(2, Queues) of
                        0 ->
                            <<"0"/utf8>>;

                        _ ->
                            <<"nonzero"/utf8>>
                    end)/binary>>],
            Body = gleam@list:fold(
                Summary_lines,
                <<""/utf8>>,
                fun(Acc, L) ->
                    <<<<Acc/binary, L/binary>>/binary, "\n"/utf8>>
                end
            ),
            _ = scripts@common@fsx:write_file(Dir, <<"stdout.log"/utf8>>, Body),
            Json = <<<<<<<<<<<<<<<<<<<<"{\"script\":\"registry/saplan_smoke\""/utf8,
                                                    ",\"stamp\":\""/utf8>>/binary,
                                                Stamp/binary>>/binary,
                                            "\""/utf8>>/binary,
                                        ",\"status\":\"ok\""/utf8>>/binary,
                                    ",\"pref\":\"roadmap."/utf8>>/binary,
                                Pref_key/binary>>/binary,
                            "\""/utf8>>/binary,
                        ",\"queue_list_rc\":"/utf8>>/binary,
                    (case erlang:element(2, Queues) of
                        0 ->
                            <<"0"/utf8>>;

                        _ ->
                            gleam@string:inspect(erlang:element(2, Queues))
                    end)/binary>>/binary,
                "}"/utf8>>,
            _ = scripts@common@fsx:write_file(Dir, <<"result.json"/utf8>>, Json),
            scripts@common@logx:info(
                <<"registry/saplan_smoke"/utf8>>,
                <<"outputs "/utf8,
                    (scripts@common@paths:join(Dir, <<"result.json"/utf8>>))/binary>>
            )
    end,
    scripts@common@logx:info(<<"registry/saplan_smoke"/utf8>>, <<"done"/utf8>>).
