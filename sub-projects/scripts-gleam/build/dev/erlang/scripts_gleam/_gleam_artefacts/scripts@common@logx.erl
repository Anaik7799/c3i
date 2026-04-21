-module(scripts@common@logx).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/scripts/common/logx.gleam").
-export([stamp/0, iso_now/0, log/3, info/2, warn/2, error/2]).
-export_type([level/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " scripts/common/logx — structured logging + timestamp for gleam-run scripts.\n"
    "\n"
    " SC-SCRIPT-GLEAM-001. Minimal, dependency-light.\n"
).

-type level() :: info | warn | error | debug.

-file("src/scripts/common/logx.gleam", 13).
-spec pad2(integer()) -> binary().
pad2(N) ->
    S = erlang:integer_to_binary(N),
    case string:length(S) of
        1 ->
            <<"0"/utf8, S/binary>>;

        _ ->
            S
    end.

-file("src/scripts/common/logx.gleam", 22).
?DOC(" Filesystem-safe timestamp: `YYYYMMDD-HHMMSS` in UTC.\n").
-spec stamp() -> binary().
stamp() ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:universal_time(),
    <<<<<<<<<<<<(erlang:integer_to_binary(Y))/binary, (pad2(Mo))/binary>>/binary,
                        (pad2(D))/binary>>/binary,
                    "-"/utf8>>/binary,
                (pad2(H))/binary>>/binary,
            (pad2(Mi))/binary>>/binary,
        (pad2(S))/binary>>.

-file("src/scripts/common/logx.gleam", 34).
?DOC(" ISO-ish UTC time for headers: `YYYY-MM-DDTHH:MM:SSZ`.\n").
-spec iso_now() -> binary().
iso_now() ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:universal_time(),
    <<<<<<<<<<<<<<<<<<<<<<(erlang:integer_to_binary(Y))/binary, "-"/utf8>>/binary,
                                            (pad2(Mo))/binary>>/binary,
                                        "-"/utf8>>/binary,
                                    (pad2(D))/binary>>/binary,
                                "T"/utf8>>/binary,
                            (pad2(H))/binary>>/binary,
                        ":"/utf8>>/binary,
                    (pad2(Mi))/binary>>/binary,
                ":"/utf8>>/binary,
            (pad2(S))/binary>>/binary,
        "Z"/utf8>>.

-file("src/scripts/common/logx.gleam", 52).
-spec level_str(level()) -> binary().
level_str(L) ->
    case L of
        info ->
            <<"INFO"/utf8>>;

        warn ->
            <<"WARN"/utf8>>;

        error ->
            <<"ERROR"/utf8>>;

        debug ->
            <<"DEBUG"/utf8>>
    end.

-file("src/scripts/common/logx.gleam", 65).
?DOC(
    " Emit a single structured log line to stdout.\n"
    "\n"
    " Example:\n"
    "   logx.log(logx.Info, \"public_interface\", \"probe complete pass=10/10\")\n"
).
-spec log(level(), binary(), binary()) -> nil.
log(Level, Scope, Msg) ->
    Line = <<<<<<<<<<<<<<"["/utf8, (iso_now())/binary>>/binary, "] "/utf8>>/binary,
                        (level_str(Level))/binary>>/binary,
                    " "/utf8>>/binary,
                Scope/binary>>/binary,
            " "/utf8>>/binary,
        Msg/binary>>,
    gleam_stdlib:println(Line),
    _ = erlang:binary_to_atom(<<"scripts."/utf8, Scope/binary>>),
    nil.

-file("src/scripts/common/logx.gleam", 77).
-spec info(binary(), binary()) -> nil.
info(Scope, Msg) ->
    log(info, Scope, Msg).

-file("src/scripts/common/logx.gleam", 81).
-spec warn(binary(), binary()) -> nil.
warn(Scope, Msg) ->
    log(warn, Scope, Msg).

-file("src/scripts/common/logx.gleam", 85).
-spec error(binary(), binary()) -> nil.
error(Scope, Msg) ->
    log(error, Scope, Msg).
