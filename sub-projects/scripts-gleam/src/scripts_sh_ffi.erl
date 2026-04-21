%%% scripts_sh_ffi — minimal Erlang FFI for running external binaries from
%%% the isolated `scripts-gleam` subproject.
%%%
%%% SC-SCRIPT-GLEAM-001. Port-spawn only (no shell). Two public functions:
%%%   run_capture/2       — run binary with args
%%%   run_capture_in/3    — run binary with args in a specific CWD

-module(scripts_sh_ffi).
-export([run_capture/2, run_capture_in/3]).

run_capture(Path, Args) when is_list(Path), is_list(Args) ->
    run_capture_in(Path, Args, []).

run_capture_in(Path, Args, Cwd) when is_list(Path), is_list(Args) ->
    PathStr = resolve(Path),
    case PathStr of
        false -> {"[scripts_sh_ffi] executable not found: " ++ Path, 127};
        Resolved ->
            ArgsStr = [to_charlist(A) || A <- Args],
            Opts0 = [exit_status, binary, stderr_to_stdout, {args, ArgsStr}],
            Opts = case Cwd of
                [] -> Opts0;
                _  -> [{cd, to_charlist(Cwd)} | Opts0]
            end,
            Port = open_port({spawn_executable, Resolved}, Opts),
            collect(Port, <<>>)
    end.

collect(Port, Acc) ->
    receive
        {Port, {data, Bin}} ->
            collect(Port, <<Acc/binary, Bin/binary>>);
        {Port, {exit_status, RC}} ->
            {binary_to_list(Acc), RC}
    after
        60000 ->
            catch port_close(Port),
            {binary_to_list(Acc) ++ "\n[timeout 60s]\n", 124}
    end.

resolve(Path) ->
    case Path of
        [$/ | _] -> Path;
        _ -> os:find_executable(Path)
    end.

to_charlist(X) when is_list(X) -> X;
to_charlist(X) when is_binary(X) -> binary_to_list(X).
