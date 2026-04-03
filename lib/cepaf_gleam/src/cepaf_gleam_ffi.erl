-module(cepaf_gleam_ffi).
-export([hackney_request/5, hackney_http_request/4, get_uid/0, sha256/1, sqrt/1]).
-export([system_time_nanos/0]).
-export([sqlite_open/1, sqlite_exec/2, sqlite_q/3, sqlite_close/1]).
-export([duckdb_open/1, duckdb_connection/1, duckdb_query/2, duckdb_fetch_all/1, duckdb_columns/1]).
-export([zenoh_open/1, zenoh_put/3, zenoh_get/2, zenoh_subscribe/3, try_load_zenoh_nif/0]).
-export([file_read/1, file_write/2, file_rename/2]).
-export([generate_id/0, os_cmd/1, identity/1]).
-export([to_string/1, to_int/1, to_float/1, to_bool/1]).

identity(X) -> X.

to_string(X) when is_binary(X) -> {ok, X};
to_string(_) -> {error, nil}.

to_int(X) when is_integer(X) -> {ok, X};
to_int(_) -> {error, nil}.

to_float(X) when is_float(X) -> {ok, X};
to_float(_) -> {error, nil}.

to_bool(X) when is_boolean(X) -> {ok, X};
to_bool(_) -> {error, nil}.

%% [C3I-SIL6] sqrt: F# System.Math.Sqrt -> Erlang math:sqrt
%% Morphism: surjective (NaN/negative domain lost on BEAM)
%% Mitigation: Guard clause + Result wrapping
sqrt(X) when is_number(X), X >= 0 ->
    {ok, math:sqrt(X)};
sqrt(_X) ->
    {error, <<"Domain error: sqrt requires non-negative input">>}.

%% [C3I-SIL6] os_cmd: F# Process.Start -> Erlang os:cmd
%% Morphism: surjective (exit codes lost)
%% Mitigation: try/catch + Result wrapping
os_cmd(Cmd) ->
    try
        Result = os:cmd(binary_to_list(Cmd)),
        {ok, list_to_binary(Result)}
    catch
        _:Reason ->
            {error, list_to_binary(io_lib:format("os_cmd failed: ~p", [Reason]))}
    end.

file_rename(Old, New) ->
    case file:rename(Old, New) of
        ok -> {ok, nil};
        {error, Reason} -> {error, atom_to_binary(Reason, utf8)}
    end.

%% DuckDB FFI via Duckdbex
duckdb_open(Path) ->
    'Elixir.Duckdbex':open(Path).

duckdb_connection(Db) ->
    'Elixir.Duckdbex':connection(Db).

duckdb_query(Conn, Sql) ->
    'Elixir.Duckdbex':query(Conn, Sql).

duckdb_fetch_all(Result) ->
    Rows = 'Elixir.Duckdbex':fetch_all(Result),
    %% Normalize tuples to lists for Gleam
    {ok, [case Row of T when is_tuple(T) -> tuple_to_list(T); L when is_list(L) -> L end || Row <- Rows]}.

duckdb_columns(Result) ->
    {ok, 'Elixir.Duckdbex':columns(Result)}.


sha256(Data) ->
    Hash = crypto:hash(sha256, Data),
    binary:encode_hex(Hash).

generate_id() ->
    Now = erlang:system_time(millisecond),
    Random = crypto:strong_rand_bytes(10),
    %% Simple hex encoding for now, could be base32 later
    RandHex = binary:encode_hex(Random),
    list_to_binary(integer_to_list(Now) ++ binary_to_list(RandHex)).

hackney_request(Method, Url, Headers, Body, SocketPath) ->
    %% Ensure hackney is started (SC-FFI-002)
    {ok, _} = application:ensure_all_started(hackney),
    
    %% Use list for SocketPath
    L_SocketPath = binary_to_list(SocketPath),
    
    %% Use binary for Method if it's an atom
    L_Method = case Method of
        get -> get;
        post -> post;
        put -> put;
        delete -> delete;
        _ -> Method
    end,

    Options = [
        {connect_timeout, 5000},
        {recv_timeout, 30000},
        {pool, default},
        {connect_options, [{local_socket, L_SocketPath}]}
    ],
    
    %% [C3I-SIL6] Debug logging REMOVED for production (SC-PERF-001)
    case hackney:request(L_Method, Url, Headers, Body, Options) of
        {ok, StatusCode, RespHeaders, ClientRef} ->
            case hackney:body(ClientRef) of
                {ok, RespBody} ->
                    {ok, {StatusCode, RespHeaders, RespBody}};
                {error, Reason} ->
                    {error, atom_to_binary(Reason, utf8)}
            end;
        {error, Reason} ->
            {error, atom_to_binary(Reason, utf8)}
    end.

%% [C3I-SIL6] SC-OTEL-002: Standard TCP HTTP request (no UDS socket).
%% Used by the OTel exporter to POST spans to the collector.
hackney_http_request(Method, Url, Headers, Body) ->
    {ok, _} = application:ensure_all_started(hackney),
    L_Method = case Method of
        get -> get;
        post -> post;
        put -> put;
        delete -> delete;
        _ -> Method
    end,
    Options = [
        {connect_timeout, 5000},
        {recv_timeout, 10000},
        {pool, default}
    ],
    case hackney:request(L_Method, Url, Headers, Body, Options) of
        {ok, StatusCode, RespHeaders, ClientRef} ->
            case hackney:body(ClientRef) of
                {ok, RespBody} ->
                    {ok, {StatusCode, RespHeaders, RespBody}};
                {error, Reason} ->
                    {error, list_to_binary(io_lib:format("~p", [Reason]))}
            end;
        {error, Reason} ->
            {error, list_to_binary(io_lib:format("~p", [Reason]))}
    end.

%% [C3I-SIL6] SC-OTEL-002: Nanosecond wall-clock for OTLP timestamps.
system_time_nanos() ->
    erlang:system_time(nanosecond).

%% [C3I-SIL6] get_uid: Reads UID from OS env with fallback
%% Note: Falls back to id -u shell command if UID env var is missing
get_uid() ->
    case os:getenv("UID") of
        false ->
            %% Fallback: query OS directly
            Result = string:trim(os:cmd("id -u")),
            list_to_binary(Result);
        Val -> list_to_binary(Val)
    end.

%% SQLite FFI via esqlite
sqlite_open(Path) ->
    case esqlite3:open(Path) of
        {ok, Conn} -> {ok, Conn};
        {error, Reason} -> {error, atom_to_binary(Reason, utf8)}
    end.

sqlite_exec(Conn, Sql) ->
    case esqlite3:exec(Conn, Sql) of
        ok -> {ok, 0};
        {ok, Rows} -> {ok, length(Rows)};
        {error, Reason} -> {error, atom_to_binary(Reason, utf8)}
    end.

sqlite_q(Conn, Sql, Params) ->
    case esqlite3:q(Conn, Sql, Params) of
        Rows when is_list(Rows) -> {ok, Rows};
        {error, Reason} -> {error, atom_to_binary(Reason, utf8)}
    end.

sqlite_close(Conn) ->
    esqlite3:close(Conn).

%% [C3I-SIL6] Zenoh FFI with three-tier fallback:
%%   1. Elixir module (umbrella app running)
%%   2. Direct NIF load (standalone Gleam)
%%   3. Graceful degradation (no Zenoh available)
%%
%% SC-GLM-NIF-001: Rust NIFs for Zenoh FFI
%% SC-GLM-NIF-002: NIF calls through cepaf_gleam_ffi.erl wrapper

try_load_zenoh_nif() ->
    NifPath = "/home/an/dev/ver/c3i/intelitor-v5.2/target/release/libzenoh_nif",
    case erlang:load_nif(NifPath, 0) of
        ok -> ok;
        {error, {reload, _}} -> ok;  %% Already loaded
        {error, Reason} -> {error, Reason}
    end.

zenoh_open(ConfigJson) ->
    try 'Elixir.Indrajaal.Native.Zenoh':zenoh_open_session(ConfigJson)
    catch
        error:undef ->
            %% Elixir module not loaded, try direct NIF
            try_load_zenoh_nif(),
            try zenoh_nif:open_session(ConfigJson)
            catch
                _:_ -> {error, <<"zenoh_not_available: NIF not loaded">>}
            end
    end.

zenoh_put(Session, Key, Payload) ->
    try 'Elixir.Indrajaal.Native.Zenoh':put(Session, Key, Payload)
    catch
        error:undef ->
            try_load_zenoh_nif(),
            try zenoh_nif:put(Session, Key, Payload)
            catch
                _:_ -> {error, <<"zenoh_not_available: NIF not loaded">>}
            end
    end.

zenoh_get(Session, Key) ->
    try 'Elixir.Indrajaal.Native.Zenoh':get(Session, Key)
    catch
        error:undef ->
            try_load_zenoh_nif(),
            try zenoh_nif:get(Session, Key)
            catch
                _:_ -> {error, <<"zenoh_not_available: NIF not loaded">>}
            end
    end.

zenoh_subscribe(Session, Key, Pid) ->
    try 'Elixir.Indrajaal.Native.Zenoh':subscribe(Session, Key, Pid)
    catch
        error:undef ->
            try_load_zenoh_nif(),
            try zenoh_nif:subscribe(Session, Key, Pid)
            catch
                _:_ -> {error, <<"zenoh_not_available: NIF not loaded">>}
            end
    end.

%% File FFI
file_read(Path) ->
    case file:read_file(Path) of
        {ok, Binary} -> {ok, Binary};
        {error, Reason} -> {error, atom_to_binary(Reason, utf8)}
    end.

file_write(Path, Content) ->
    case file:write_file(Path, Content) of
        ok -> {ok, nil};
        {error, Reason} -> {error, atom_to_binary(Reason, utf8)}
    end.
