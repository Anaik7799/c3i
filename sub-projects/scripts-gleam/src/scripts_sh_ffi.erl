%%% scripts_sh_ffi — minimal Erlang FFI for running external binaries from
%%% the isolated `scripts-gleam` subproject.
%%%
%%% SC-SCRIPT-GLEAM-001 — thin binary invocation is allowed; this FFI is the
%%% only place in scripts-gleam that spawns OS processes. No shell-script
%%% logic is authored here; we use `open_port/2` with `{spawn_executable, ...}`
%%% to avoid a shell entirely.

-module(scripts_sh_ffi).
-export([run_capture/2]).

%% Run the binary at Path with Args, capturing combined stdout+stderr.
%% Returns {Output :: string(), ExitCode :: integer()}.
%%
%% Path may be an absolute path (used as-is), a project-relative path starting
%% with `/` that is passed through, or a plain program name which is resolved
%% via `os:find_executable/1` (PATH lookup). This avoids authoring any shell.
run_capture(Path, Args) when is_list(Path), is_list(Args) ->
    PathStr = resolve(Path),
    case PathStr of
        false -> {"[scripts_sh_ffi] executable not found: " ++ Path, 127};
        Resolved ->
            ArgsStr = [to_charlist(A) || A <- Args],
            Port = open_port(
                {spawn_executable, Resolved},
                [exit_status, binary, stderr_to_stdout, {args, ArgsStr}]
            ),
            collect(Port, <<>>)
    end.

%% Resolve Path: absolute paths are returned unchanged, bare program names
%% are looked up via os:find_executable/1.
resolve(Path) ->
    case Path of
        [$/ | _] -> Path;
        _ -> os:find_executable(Path)
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

to_charlist(X) when is_list(X) -> X;
to_charlist(X) when is_binary(X) -> binary_to_list(X).
