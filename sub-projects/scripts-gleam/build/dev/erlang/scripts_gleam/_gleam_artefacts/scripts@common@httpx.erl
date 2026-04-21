-module(scripts@common@httpx).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/scripts/common/httpx.gleam").
-export([get/1, body_contains/2]).
-export_type([http_result/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " scripts/common/httpx — small HTTP helper for probes.\n"
    "\n"
    " SC-SCRIPT-GLEAM-001. Wraps gleam_httpc with a uniform result type.\n"
).

-type http_result() :: {http_result, integer(), binary(), boolean(), binary()}.

-file("src/scripts/common/httpx.gleam", 15).
-spec get(binary()) -> http_result().
get(Url) ->
    case gleam@http@request:to(Url) of
        {error, _} ->
            {http_result,
                0,
                <<""/utf8>>,
                false,
                <<"invalid url: "/utf8, Url/binary>>};

        {ok, Req} ->
            Req@1 = gleam@http@request:set_method(Req, get),
            case gleam@httpc:send(Req@1) of
                {error, _} ->
                    {http_result,
                        0,
                        <<""/utf8>>,
                        false,
                        <<"send error: "/utf8, Url/binary>>};

                {ok, Resp} ->
                    R = Resp,
                    {http_result,
                        erlang:element(2, R),
                        erlang:element(4, R),
                        erlang:element(2, R) =:= 200,
                        <<"ok"/utf8>>}
            end
    end.

-file("src/scripts/common/httpx.gleam", 32).
?DOC(" Check if `want` is a substring of response body; empty `want` = accept anything.\n").
-spec body_contains(http_result(), binary()) -> boolean().
body_contains(R, Want) ->
    case Want of
        <<""/utf8>> ->
            true;

        S ->
            gleam_stdlib:contains_string(erlang:element(3, R), S)
    end.
