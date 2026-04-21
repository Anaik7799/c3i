-module(scripts@common@args).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/scripts/common/args.gleam").
-export([new/0, parse/1, flag/3, bool/2, keys/1]).
-export_type([args/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " scripts/common/args — minimal typed argument parser for gleam-run scripts.\n"
    "\n"
    " SC-SCRIPT-GLEAM-001. Not runnable on its own.\n"
).

-type args() :: {args,
        gleam@dict:dict(binary(), binary()),
        gleam@dict:dict(binary(), boolean())}.

-file("src/scripts/common/args.gleam", 13).
-spec new() -> args().
new() ->
    {args, maps:new(), maps:new()}.

-file("src/scripts/common/args.gleam", 27).
-spec loop(list(binary()), args()) -> args().
loop(Argv, Acc) ->
    case Argv of
        [] ->
            Acc;

        [Head | Rest] ->
            case gleam_stdlib:string_starts_with(Head, <<"--"/utf8>>) of
                false ->
                    loop(Rest, Acc);

                true ->
                    Key = gleam@string:drop_start(Head, 2),
                    case Rest of
                        [Next | Tail] ->
                            case gleam_stdlib:string_starts_with(
                                Next,
                                <<"--"/utf8>>
                            ) of
                                true ->
                                    loop(
                                        Rest,
                                        {args,
                                            erlang:element(2, Acc),
                                            gleam@dict:insert(
                                                erlang:element(3, Acc),
                                                Key,
                                                true
                                            )}
                                    );

                                false ->
                                    loop(
                                        Tail,
                                        {args,
                                            gleam@dict:insert(
                                                erlang:element(2, Acc),
                                                Key,
                                                Next
                                            ),
                                            erlang:element(3, Acc)}
                                    )
                            end;

                        [] ->
                            {args,
                                erlang:element(2, Acc),
                                gleam@dict:insert(
                                    erlang:element(3, Acc),
                                    Key,
                                    true
                                )}
                    end
            end
    end.

-file("src/scripts/common/args.gleam", 23).
?DOC(
    " Parse a CLI argv list into (flags, booleans).\n"
    "\n"
    "   parse([\"--base\",\"http://x\",\"--insecure\",\"--out\",\"/tmp\"])\n"
    "\n"
    " * `--key value` → flags[\"key\"] = value\n"
    " * `--key` (next starts with `--` or is empty) → booleans[\"key\"] = true\n"
).
-spec parse(list(binary())) -> args().
parse(Argv) ->
    loop(Argv, new()).

-file("src/scripts/common/args.gleam", 51).
-spec flag(args(), binary(), binary()) -> binary().
flag(A, Name, Default) ->
    case gleam_stdlib:map_get(erlang:element(2, A), Name) of
        {ok, V} ->
            V;

        {error, _} ->
            Default
    end.

-file("src/scripts/common/args.gleam", 58).
-spec bool(args(), binary()) -> boolean().
bool(A, Name) ->
    case gleam_stdlib:map_get(erlang:element(3, A), Name) of
        {ok, V} ->
            V;

        {error, _} ->
            false
    end.

-file("src/scripts/common/args.gleam", 65).
-spec keys(args()) -> list(binary()).
keys(A) ->
    Flag_keys = maps:keys(erlang:element(2, A)),
    Bool_keys = maps:keys(erlang:element(3, A)),
    lists:append(Flag_keys, Bool_keys).
