-module(scripts@common@paths).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/scripts/common/paths.gleam").
-export([repo_root/0, output_root/0, output_dir/3, pad2/1, join/2, safe_segment/1, resolve/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " scripts/common/paths — canonical path resolution for gleam-run scripts.\n"
    "\n"
    " SC-SCRIPT-GLEAM-001. Scripts MUST write outputs under the conventional\n"
    " `data/script-output/<category>/<name>/<timestamp>/` tree.\n"
).

-file("src/scripts/common/paths.gleam", 16).
?DOC(
    " Repo root resolved from env (`C3I_REPO_ROOT`) or a sensible default.\n"
    "\n"
    " Convention: developer shell sets `C3I_REPO_ROOT` to the absolute repo root\n"
    " (the directory containing `lib/cepaf_gleam/`). If unset, default to the\n"
    " known absolute path used in this project.\n"
).
-spec repo_root() -> binary().
repo_root() ->
    case envoy_ffi:get(<<"C3I_REPO_ROOT"/utf8>>) of
        {ok, V} ->
            V;

        {error, _} ->
            <<"/home/an/dev/ver/c3i"/utf8>>
    end.

-file("src/scripts/common/paths.gleam", 24).
?DOC(" Base directory for all script outputs.\n").
-spec output_root() -> binary().
output_root() ->
    <<(repo_root())/binary, "/data/script-output"/utf8>>.

-file("src/scripts/common/paths.gleam", 32).
?DOC(
    " Compute the output directory for a specific invocation.\n"
    "\n"
    "   output_dir(\"probe\", \"public_interface\", \"20260421-095500\")\n"
    "   → \"/<root>/data/script-output/probe/public_interface/20260421-095500\"\n"
).
-spec output_dir(binary(), binary(), binary()) -> binary().
output_dir(Category, Name, Stamp) ->
    <<<<<<<<<<<<(output_root())/binary, "/"/utf8>>/binary, Category/binary>>/binary,
                    "/"/utf8>>/binary,
                Name/binary>>/binary,
            "/"/utf8>>/binary,
        Stamp/binary>>.

-file("src/scripts/common/paths.gleam", 38).
?DOC(
    " Deterministic filesystem-safe timestamp string (caller supplies).\n"
    " Provided as a pure helper; scripts typically call `scripts/common/logx.stamp()`.\n"
).
-spec pad2(integer()) -> binary().
pad2(N) ->
    S = erlang:integer_to_binary(N),
    case string:length(S) of
        1 ->
            <<"0"/utf8, S/binary>>;

        _ ->
            S
    end.

-file("src/scripts/common/paths.gleam", 47).
?DOC(" Join two path segments with a single `/`.\n").
-spec join(binary(), binary()) -> binary().
join(A, B) ->
    case gleam_stdlib:string_ends_with(A, <<"/"/utf8>>) of
        true ->
            <<A/binary, B/binary>>;

        false ->
            <<<<A/binary, "/"/utf8>>/binary, B/binary>>
    end.

-file("src/scripts/common/paths.gleam", 55).
?DOC(" Guarantee a string is a valid filesystem segment (no `/` or `:`).\n").
-spec safe_segment(binary()) -> binary().
safe_segment(S) ->
    _pipe = S,
    _pipe@1 = gleam@string:replace(_pipe, <<"/"/utf8>>, <<"_"/utf8>>),
    _pipe@2 = gleam@string:replace(_pipe@1, <<":"/utf8>>, <<"-"/utf8>>),
    gleam@string:replace(_pipe@2, <<"\\"/utf8>>, <<"_"/utf8>>).

-file("src/scripts/common/paths.gleam", 64).
?DOC(
    " Attempt to resolve a relative path against repo root; absolute paths\n"
    " pass through unchanged.\n"
).
-spec resolve(binary()) -> {ok, binary()} | {error, binary()}.
resolve(P) ->
    _pipe = case gleam_stdlib:string_starts_with(P, <<"/"/utf8>>) of
        true ->
            {ok, P};

        false ->
            {ok, <<<<(repo_root())/binary, "/"/utf8>>/binary, P/binary>>}
    end,
    gleam@result:map_error(_pipe, fun(_) -> <<"path resolve failed"/utf8>> end).
