-module(zenoh_ffi).
-export([
    zenoh_open/1,
    zenoh_put/2,
    zenoh_is_open/0,
    zenoh_publish_span/4,
    zenoh_get_stats/0,
    zenoh_publish_batch/1
]).
-nifs([
    zenoh_open/1,
    zenoh_put/2,
    zenoh_is_open/0,
    zenoh_publish_span/4,
    zenoh_get_stats/0,
    zenoh_publish_batch/1
]).
-on_load(init/0).

init() ->
    PrivDir = code:priv_dir(sutra_server),
    erlang:load_nif(filename:join(PrivDir, "zenoh_nif"), 0).

zenoh_open(_) -> erlang:nif_error(nif_not_loaded).
zenoh_put(_, _) -> erlang:nif_error(nif_not_loaded).
zenoh_is_open() -> erlang:nif_error(nif_not_loaded).
zenoh_publish_span(_, _, _, _) -> erlang:nif_error(nif_not_loaded).
zenoh_get_stats() -> erlang:nif_error(nif_not_loaded).
zenoh_publish_batch(_) -> erlang:nif_error(nif_not_loaded).
