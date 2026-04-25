-module(rocksdb_ffi).
-export([
    db_open/1,
    db_put/3,
    db_get/2,
    db_delete/2,
    db_scan/3,
    db_is_open/0,
    db_flush/0,
    db_size_on_disk/0
]).
-nifs([
    db_open/1,
    db_put/3,
    db_get/2,
    db_delete/2,
    db_scan/3,
    db_is_open/0,
    db_flush/0,
    db_size_on_disk/0
]).
-on_load(init/0).

init() ->
    PrivDir = code:priv_dir(sutra_server),
    erlang:load_nif(filename:join(PrivDir, "rocksdb_nif"), 0).

db_open(_) -> erlang:nif_error(nif_not_loaded).
db_put(_, _, _) -> erlang:nif_error(nif_not_loaded).
db_get(_, _) -> erlang:nif_error(nif_not_loaded).
db_delete(_, _) -> erlang:nif_error(nif_not_loaded).
db_scan(_, _, _) -> erlang:nif_error(nif_not_loaded).
db_is_open() -> erlang:nif_error(nif_not_loaded).
db_flush() -> erlang:nif_error(nif_not_loaded).
db_size_on_disk() -> erlang:nif_error(nif_not_loaded).
