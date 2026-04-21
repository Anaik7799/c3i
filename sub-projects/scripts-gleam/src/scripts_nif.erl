%%% scripts_nif — Erlang loader for the scripts_nif.so Rust NIF.
%%%
%%% SC-SCRIPT-GLEAM-001 + SC-NIF-001..005.
%%%
%%% This module follows the same loader pattern as cepaf_gleam/src/c3i_nif.erl
%%% but loads from this subproject's own priv/ so there is zero coupling to
%%% cepaf_gleam. Every function has a pure-Erlang stub so the subproject still
%%% builds if the NIF is not present.

-module(scripts_nif).

-export([
    %% Utility (3)
    now_nanos/0,
    uuid_v7/0,
    sha256_hex/1,
    %% Smriti (4)
    smriti_get_pref/2,
    smriti_set_pref/4,
    smriti_get_task/2,
    smriti_pool_stats/0,
    %% Zenoh (5)
    zenoh_open_session/0,
    zenoh_put/2,
    zenoh_put_prio/4,
    zenoh_get/2,
    zenoh_session_info/0,
    %% Fractal (1)
    fractal_span_emit/6,
    %% Gemini (1)
    gemini_generate/4,
    %% OpenRouter (1)
    openrouter_generate/4,
    %% Ollama (1)
    ollama_generate/4,
    %% MCP (2)
    mcp_invoke_moz/3,
    mcp_serve_one/2,
    %% Metrics (3)
    metrics_counter_inc/3,
    metrics_histogram_observe/3,
    metrics_snapshot/0
]).

-on_load(init/0).

init() ->
    PrivDir = case code:priv_dir(scripts_gleam) of
        {error, _} -> "priv";
        P -> P
    end,
    Arch = erlang:system_info(system_architecture),
    %% Prefer a per-arch .so if present, fall back to the generic name.
    %% This lets cross-arch builds (e.g. aarch64 for Raspberry Pi) coexist.
    ArchSuffix = arch_suffix(Arch),
    PerArch = filename:join(PrivDir, "scripts_nif-" ++ ArchSuffix),
    Generic = filename:join(PrivDir, "scripts_nif"),
    Candidates = [PerArch, Generic],
    LoadRes = try_load(Candidates),
    case LoadRes of
        ok -> ok;
        {error, {reload, _}} -> ok;
        {error, Reason} ->
            io:format("[scripts_nif] NIF load failed: ~p (arch: ~s, tried: ~p)~n",
                      [Reason, Arch, Candidates]),
            ok
    end.

arch_suffix(Arch) ->
    %% Normalise triple to something filesystem-friendly.
    case string:split(Arch, "-", leading) of
        [Cpu | _] -> Cpu;
        _ -> Arch
    end.

try_load([]) ->
    {error, {nofile, "no NIF .so found"}};
try_load([Path | Rest]) ->
    case filelib:is_regular(Path ++ ".so") of
        false -> try_load(Rest);
        true ->
            case erlang:load_nif(Path, 0) of
                ok -> ok;
                {error, {reload, _}} -> ok;
                {error, Reason} ->
                    io:format("[scripts_nif] tried ~s: ~p~n", [Path, Reason]),
                    try_load(Rest)
            end
    end.

%% ── Pure-Erlang stubs (replaced by Rust at load time) ────────────────

now_nanos() -> 0.
uuid_v7() -> <<"00000000-0000-0000-0000-000000000000">>.
sha256_hex(_) -> <<"0000000000000000000000000000000000000000000000000000000000000000">>.

smriti_get_pref(_, _) -> {ok, <<"">>}.
smriti_set_pref(_, _, _, _) -> {ok, <<"stub">>}.
smriti_get_task(_, _) -> {ok, <<"">>}.
smriti_pool_stats() -> {ok, <<"{\"open_connections\":0,\"paths\":[]}">>}.

zenoh_open_session() -> {ok, <<"stub">>}.
zenoh_put(_, _) -> {ok, <<"stub">>}.
zenoh_put_prio(_, _, _, _) -> {ok, <<"stub">>}.
zenoh_get(_, _) -> {ok, []}.
zenoh_session_info() -> {ok, <<"{\"session_open\":false}">>}.

fractal_span_emit(_, _, _, _, _, _) -> {ok, <<"{}">>}.

gemini_generate(_, _, _, _) -> {ok, <<"stub">>}.

mcp_invoke_moz(_, _, _) -> {ok, <<"stub">>}.
mcp_serve_one(_, _) -> {ok, <<"stub">>}.
openrouter_generate(_, _, _, _) -> {ok, <<"stub">>}.
ollama_generate(_, _, _, _) -> {ok, <<"stub">>}.

metrics_counter_inc(_, _, _) -> {ok, 0}.
metrics_histogram_observe(_, _, _) -> {ok, 0}.
metrics_snapshot() -> {ok, <<"{\"counters\":{},\"histograms\":{}}">>}.
