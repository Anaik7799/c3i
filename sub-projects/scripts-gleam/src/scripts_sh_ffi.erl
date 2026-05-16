%%% scripts_sh_ffi — minimal Erlang FFI for running external binaries from
%%% the isolated `scripts-gleam` subproject.
%%%
%%% SC-SCRIPT-GLEAM-001. Port-spawn only (no shell).
%%%
%%% Functions:
%%%   run_capture/2       — run binary with args, collect all stdout until exit
%%%   run_capture_in/3    — run binary with args in a specific CWD
%%%   run_stream/4        — SC-SCHED-TELE-PI-STREAM-FFI-001: streaming variant
%%%                         that collects up to MaxLines or until TimeoutMs
%%%                         elapses, then returns early without killing the
%%%                         port (caller can keep reading).
%%%   run_stream_bounded/5 — run with CWD + line-bounded capture + timeout.

-module(scripts_sh_ffi).
-export([
    run_capture/2,
    run_capture_in/3,
    run_capture_timeout/3,
    run_stream/4,
    run_stream_bounded/5
]).

%% ─────────────────────────────────────────────────────────────────────────────
%% Existing blocking-collect variants
%% ─────────────────────────────────────────────────────────────────────────────

run_capture(Path, Args) when is_list(Path), is_list(Args) ->
    run_capture_in(Path, Args, []).

%% Like run_capture_in but with configurable timeout (ms).
%% Routes stdin from /dev/null so child processes don't hang waiting for input.
%% Critical for Pi --print mode which exits after one response.
run_capture_timeout(Path, Args, TimeoutMs) when is_list(Path), is_list(Args),
        is_integer(TimeoutMs), TimeoutMs >= 0 ->
    %% Build a shell command that redirects stdin from /dev/null
    PathStr = resolve(Path),
    case PathStr of
        false -> {"[scripts_sh_ffi] executable not found: " ++ Path, 127};
        Resolved ->
            ArgsStr = [shell_escape(to_charlist(A)) || A <- Args],
            Cmd = Resolved ++ " " ++ string:join(ArgsStr, " ") ++ " </dev/null",
            Port = open_port({spawn, Cmd}, [exit_status, binary, stderr_to_stdout]),
            collect_timed(Port, <<>>, TimeoutMs)
    end.

shell_escape(S) ->
    %% Wrap in single quotes, escaping existing single quotes
    "'" ++ re:replace(S, "'", "'\\\\''", [global, {return, list}]) ++ "'".

collect_timed(Port, Acc, TimeoutMs) ->
    receive
        {Port, {data, Bin}} ->
            collect_timed(Port, <<Acc/binary, Bin/binary>>, TimeoutMs);
        {Port, {exit_status, RC}} ->
            {binary_to_list(Acc), RC}
    after
        TimeoutMs ->
            catch port_close(Port),
            {binary_to_list(Acc) ++ "\n[timeout]\n", 124}
    end.

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

%% ─────────────────────────────────────────────────────────────────────────────
%% Streaming variant — SC-SCHED-TELE-PI-STREAM-FFI-001
%%
%% Spawns the subprocess in `{line, 8192}` mode so the port emits one message
%% per newline-terminated chunk. We return as soon as EITHER:
%%   * `MaxLines` lines have been observed, OR
%%   * `TimeoutMs` milliseconds have elapsed since the first byte.
%%
%% The returned tuple is `{Lines, Status}`:
%%   Lines  :: [string()]       — line-oriented stdout
%%   Status :: {exited, RC} | ongoing | timeout
%%
%% The port is closed at the end of every call. For continuous-tail behaviour
%% callers simply invoke repeatedly; each call captures a fresh window of
%% subprocess output.
%% ─────────────────────────────────────────────────────────────────────────────

run_stream(Path, Args, MaxLines, TimeoutMs) when is_list(Path), is_list(Args),
        is_integer(MaxLines), MaxLines >= 0, is_integer(TimeoutMs), TimeoutMs >= 0 ->
    run_stream_bounded(Path, Args, [], MaxLines, TimeoutMs).

run_stream_bounded(Path, Args, Cwd, MaxLines, TimeoutMs) when is_list(Path),
        is_list(Args), is_integer(MaxLines), is_integer(TimeoutMs) ->
    PathStr = resolve(Path),
    case PathStr of
        false -> {[], {error, "executable not found: " ++ Path}};
        Resolved ->
            ArgsStr = [to_charlist(A) || A <- Args],
            Opts0 = [exit_status, binary, stderr_to_stdout,
                     {args, ArgsStr}, {line, 8192}],
            Opts = case Cwd of
                [] -> Opts0;
                _  -> [{cd, to_charlist(Cwd)} | Opts0]
            end,
            Port = open_port({spawn_executable, Resolved}, Opts),
            Deadline = erlang:monotonic_time(millisecond) + TimeoutMs,
            collect_stream(Port, Deadline, MaxLines, [])
    end.

collect_stream(Port, _Deadline, 0, Acc) ->
    %% Reached the line cap; close port and return.
    catch port_close(Port),
    {lists:reverse(Acc), ongoing};
collect_stream(Port, Deadline, Remaining, Acc) ->
    Now = erlang:monotonic_time(millisecond),
    WaitFor = max(0, Deadline - Now),
    receive
        {Port, {data, {eol, Bin}}} ->
            collect_stream(Port, Deadline, Remaining - 1,
                           [binary_to_list(Bin) | Acc]);
        {Port, {data, {noeol, Bin}}} ->
            %% Partial line; append without decrementing the line budget.
            case Acc of
                [] -> collect_stream(Port, Deadline, Remaining,
                                     [binary_to_list(Bin)]);
                [H | T] -> collect_stream(Port, Deadline, Remaining,
                                          [H ++ binary_to_list(Bin) | T])
            end;
        {Port, {exit_status, RC}} ->
            {lists:reverse(Acc), {exited, RC}}
    after
        WaitFor ->
            catch port_close(Port),
            {lists:reverse(Acc), timeout}
    end.

%% ─────────────────────────────────────────────────────────────────────────────

%% SC-NIF-LOAD-006 / Phase A2 robustness: existence-check absolute paths so
%% `open_port({spawn_executable, ...})` cannot raise badarg on missing binary.
%% Returns Path if executable+regular, else false (caller emits rc=127).
resolve(Path) ->
    case Path of
        [$/ | _] ->
            case filelib:is_regular(Path) of
                true ->
                    %% Best-effort exec-bit probe; on POSIX we don't need
                    %% file:read_file_info just to check bits — open_port will
                    %% fail-soft if bit not set. is_regular is the necessary
                    %% pre-condition that fixes the missing-binary crash class.
                    Path;
                false -> false
            end;
        _ -> os:find_executable(Path)
    end.

to_charlist(X) when is_list(X) -> X;
to_charlist(X) when is_binary(X) -> binary_to_list(X).
