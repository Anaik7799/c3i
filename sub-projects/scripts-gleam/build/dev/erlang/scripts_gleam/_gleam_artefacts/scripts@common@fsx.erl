-module(scripts@common@fsx).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/scripts/common/fsx.gleam").
-export([ensure_dir/1, run_dir/3, write_file/3]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " scripts/common/fsx — filesystem helpers for gleam-run scripts.\n"
    "\n"
    " SC-SCRIPT-GLEAM-001. Uses `simplifile` for clean Result semantics.\n"
    " Scripts MUST write outputs under `data/script-output/<category>/<name>/<stamp>/`.\n"
).

-file("src/scripts/common/fsx.gleam", 10).
-spec err_to_string(simplifile:file_error()) -> binary().
err_to_string(_) ->
    <<"fs error"/utf8>>.

-file("src/scripts/common/fsx.gleam", 15).
?DOC(" Ensure a directory path exists (recursive).\n").
-spec ensure_dir(binary()) -> {ok, nil} | {error, binary()}.
ensure_dir(P) ->
    case simplifile_erl:is_directory(P) of
        {ok, true} ->
            {ok, nil};

        _ ->
            _pipe = simplifile:create_directory_all(P),
            gleam@result:map_error(_pipe, fun err_to_string/1)
    end.

-file("src/scripts/common/fsx.gleam", 28).
?DOC(
    " Prepare the run directory for a script invocation and return its path.\n"
    "\n"
    "   run_dir(\"probe\", \"public_interface\", \"20260421-100000\")\n"
    "   → \"/<root>/data/script-output/probe/public_interface/20260421-100000\"\n"
).
-spec run_dir(binary(), binary(), binary()) -> {ok, binary()} |
    {error, binary()}.
run_dir(Category, Name, Stamp) ->
    Dir = scripts@common@paths:output_dir(Category, Name, Stamp),
    gleam@result:'try'(
        ensure_dir(Dir),
        fun(_) ->
            gleam@result:'try'(
                ensure_dir(<<Dir/binary, "/artifacts"/utf8>>),
                fun(_) -> {ok, Dir} end
            )
        end
    ).

-file("src/scripts/common/fsx.gleam", 36).
?DOC(" Write a UTF-8 string to `<dir>/<file>`; creates parent dirs.\n").
-spec write_file(binary(), binary(), binary()) -> {ok, nil} | {error, binary()}.
write_file(Dir, File, Body) ->
    gleam@result:'try'(
        ensure_dir(Dir),
        fun(_) ->
            Full = <<<<Dir/binary, "/"/utf8>>/binary, File/binary>>,
            _pipe = simplifile:write(Full, Body),
            gleam@result:map_error(_pipe, fun err_to_string/1)
        end
    ).
