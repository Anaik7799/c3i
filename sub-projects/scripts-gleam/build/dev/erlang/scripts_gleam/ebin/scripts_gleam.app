{application, scripts_gleam, [
    {vsn, "1.0.0"},
    {applications, [argv,
                    envoy,
                    gleam_erlang,
                    gleam_http,
                    gleam_httpc,
                    gleam_json,
                    gleam_stdlib,
                    gleeunit,
                    simplifile]},
    {description, "Isolated gleam-only script host for c3i (SC-SCRIPT-GLEAM-001). Keeps cepaf_gleam and system services uncoupled from script work."},
    {modules, []},
    {registered, []}
]}.
