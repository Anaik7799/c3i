-module(scripts@probe@public_interface).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/scripts/probe/public_interface.gleam").
-export([cases/0, main/0]).
-export_type(['case'/0, outcome/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " scripts/probe/public_interface — replacement for the HTTP subset of\n"
    " `sub-projects/c3i/scripts/public_interface_test_suite.sh`.\n"
    "\n"
    " SC-SCRIPT-GLEAM-001. Canonical area: lib/cepaf_gleam/src/scripts/probe/.\n"
    "\n"
    " Usage:\n"
    "   gleam run -m scripts/probe/public_interface\n"
    "   gleam run -m scripts/probe/public_interface -- --base http://vm-1.tail55d152.ts.net:4200\n"
    "\n"
    " Exit: success on all-green, panic (non-zero) on any probe failure.\n"
).

-type 'case'() :: {'case', binary(), binary(), binary()}.

-type outcome() :: {outcome, binary(), boolean(), integer(), binary()}.

-file("src/scripts/probe/public_interface.gleam", 30).
-spec cases() -> list('case'()).
cases() ->
    [{'case',
            <<"health.root"/utf8>>,
            <<"/health"/utf8>>,
            <<"\"status\":\"ok\""/utf8>>},
        {'case',
            <<"api.v1.status"/utf8>>,
            <<"/api/v1/status"/utf8>>,
            <<"\"total\""/utf8>>},
        {'case',
            <<"api.v1.health"/utf8>>,
            <<"/api/v1/health"/utf8>>,
            <<"\"system\""/utf8>>},
        {'case',
            <<"api.v1.dashboard"/utf8>>,
            <<"/api/v1/dashboard"/utf8>>,
            <<"\"tasks\""/utf8>>},
        {'case', <<"page.index"/utf8>>, <<"/"/utf8>>, <<"<html"/utf8>>},
        {'case', <<"page.kpi"/utf8>>, <<"/kpi"/utf8>>, <<"<html"/utf8>>},
        {'case', <<"page.session"/utf8>>, <<"/session"/utf8>>, <<"<html"/utf8>>},
        {'case',
            <<"page.pi-symbiosis"/utf8>>,
            <<"/pi-symbiosis"/utf8>>,
            <<"<html"/utf8>>},
        {'case',
            <<"page.ferriskey"/utf8>>,
            <<"/ferriskey"/utf8>>,
            <<"<html"/utf8>>},
        {'case',
            <<"page.task.1a92520c"/utf8>>,
            <<"/task-id/1a92520c"/utf8>>,
            <<"<html"/utf8>>}].

-file("src/scripts/probe/public_interface.gleam", 45).
-spec run_case(binary(), 'case'()) -> outcome().
run_case(Base, C) ->
    Url = <<Base/binary, (erlang:element(3, C))/binary>>,
    R = scripts@common@httpx:get(Url),
    Ok = erlang:element(4, R) andalso scripts@common@httpx:body_contains(
        R,
        erlang:element(4, C)
    ),
    {outcome,
        erlang:element(2, C),
        Ok,
        erlang:element(2, R),
        gleam@string:slice(erlang:element(3, R), 0, 80)}.

-file("src/scripts/probe/public_interface.gleam", 52).
-spec render(outcome()) -> binary().
render(O) ->
    Mark = case erlang:element(3, O) of
        true ->
            <<"OK  "/utf8>>;

        false ->
            <<"FAIL"/utf8>>
    end,
    <<<<<<<<<<<<<<"  "/utf8, Mark/binary>>/binary, " "/utf8>>/binary,
                        (erlang:element(2, O))/binary>>/binary,
                    " code="/utf8>>/binary,
                (erlang:integer_to_binary(erlang:element(4, O)))/binary>>/binary,
            " "/utf8>>/binary,
        (erlang:element(5, O))/binary>>.

-file("src/scripts/probe/public_interface.gleam", 60).
-spec as_json_line(outcome()) -> binary().
as_json_line(O) ->
    <<<<<<<<<<<<<<<<"{\"name\":\""/utf8, (erlang:element(2, O))/binary>>/binary,
                                "\",\"ok\":"/utf8>>/binary,
                            (case erlang:element(3, O) of
                                true ->
                                    <<"true"/utf8>>;

                                false ->
                                    <<"false"/utf8>>
                            end)/binary>>/binary,
                        ",\"code\":"/utf8>>/binary,
                    (erlang:integer_to_binary(erlang:element(4, O)))/binary>>/binary,
                ",\"detail\":\""/utf8>>/binary,
            (gleam@string:replace(
                erlang:element(5, O),
                <<"\""/utf8>>,
                <<"\\\""/utf8>>
            ))/binary>>/binary,
        "\"}"/utf8>>.

-file("src/scripts/probe/public_interface.gleam", 70).
-spec main() -> nil.
main() ->
    A = scripts@common@args:parse(erlang:element(4, argv:load())),
    Base = scripts@common@args:flag(
        A,
        <<"base"/utf8>>,
        <<"http://vm-1.tail55d152.ts.net:4200"/utf8>>
    ),
    Stamp = scripts@common@logx:stamp(),
    Scope = <<"probe/public_interface"/utf8>>,
    scripts@common@logx:info(
        Scope,
        <<<<<<"base="/utf8, Base/binary>>/binary, " stamp="/utf8>>/binary,
            Stamp/binary>>
    ),
    Results = gleam@list:map(
        cases(),
        fun(_capture) -> run_case(Base, _capture) end
    ),
    Passed = gleam@list:count(Results, fun(O) -> erlang:element(3, O) end),
    Total = erlang:length(Results),
    Summary = <<<<<<<<<<"SUMMARY: pass="/utf8,
                        (erlang:integer_to_binary(Passed))/binary>>/binary,
                    "/"/utf8>>/binary,
                (erlang:integer_to_binary(Total))/binary>>/binary,
            " base="/utf8>>/binary,
        Base/binary>>,
    gleam@list:each(
        Results,
        fun(O@1) -> scripts@common@logx:info(Scope, render(O@1)) end
    ),
    scripts@common@logx:info(Scope, Summary),
    case scripts@common@fsx:run_dir(
        <<"probe"/utf8>>,
        <<"public_interface"/utf8>>,
        Stamp
    ) of
        {error, E} ->
            scripts@common@logx:error(Scope, <<"run_dir: "/utf8, E/binary>>);

        {ok, Dir} ->
            Lines = begin
                _pipe = gleam@list:map(Results, fun as_json_line/1),
                gleam@string:join(_pipe, <<"\n"/utf8>>)
            end,
            _ = scripts@common@fsx:write_file(
                Dir,
                <<"result.json"/utf8>>,
                <<<<<<<<<<<<<<<<<<<<"{\"base\":\""/utf8, Base/binary>>/binary,
                                                    "\",\"stamp\":\""/utf8>>/binary,
                                                Stamp/binary>>/binary,
                                            "\",\"passed\":"/utf8>>/binary,
                                        (erlang:integer_to_binary(Passed))/binary>>/binary,
                                    ",\"total\":"/utf8>>/binary,
                                (erlang:integer_to_binary(Total))/binary>>/binary,
                            ",\"results\":["/utf8>>/binary,
                        (gleam@string:join(
                            gleam@list:map(Results, fun as_json_line/1),
                            <<","/utf8>>
                        ))/binary>>/binary,
                    "]}"/utf8>>
            ),
            _ = scripts@common@fsx:write_file(
                Dir,
                <<"stdout.log"/utf8>>,
                <<<<<<(begin
                                _pipe@1 = gleam@list:map(Results, fun render/1),
                                gleam@string:join(_pipe@1, <<"\n"/utf8>>)
                            end)/binary,
                            "\n"/utf8>>/binary,
                        Summary/binary>>/binary,
                    "\n"/utf8>>
            ),
            scripts@common@logx:info(
                Scope,
                <<"outputs written to "/utf8,
                    (scripts@common@paths:join(Dir, <<"result.json"/utf8>>))/binary>>
            ),
            _ = Lines,
            nil
    end,
    case Passed =:= Total of
        true ->
            nil;

        false ->
            scripts@common@logx:error(
                Scope,
                <<"probes failed: "/utf8,
                    (erlang:integer_to_binary(Total - Passed))/binary>>
            ),
            erlang:error(#{gleam_error => panic,
                    message => <<"public_interface probes failed"/utf8>>,
                    file => <<?FILEPATH/utf8>>,
                    module => <<"scripts/probe/public_interface"/utf8>>,
                    function => <<"main"/utf8>>,
                    line => 111})
    end.
