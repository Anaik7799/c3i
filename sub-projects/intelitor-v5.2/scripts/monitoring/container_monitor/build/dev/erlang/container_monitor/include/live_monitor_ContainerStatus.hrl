-record(container_status, {
    name :: binary(),
    state :: binary(),
    ip :: binary(),
    ready :: boolean(),
    phase :: binary(),
    details :: binary()
}).
