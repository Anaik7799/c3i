-module(scripts_gleam).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/scripts_gleam.gleam").
-export([main/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " scripts_gleam — host module for the c3i gleam-only script application.\n"
    "\n"
    " STAMP: SC-SCRIPT-GLEAM-001\n"
    "\n"
    " This package exists *only* to host runnable scripts under `scripts/`\n"
    " and shared helpers under `scripts/common/`. It is fully isolated from\n"
    " `cepaf_gleam`, `planning_daemon`, `pi-mono`, and every other system\n"
    " service — deliberately so new script work can proceed without any risk\n"
    " of breaking the main application.\n"
    "\n"
    " Runnable scripts are invoked as:\n"
    "\n"
    "     cd sub-projects/scripts-gleam\n"
    "     gleam run -m scripts/<category>/<name> -- [--arg value ...]\n"
).

-file("src/scripts_gleam.gleam", 20).
?DOC(
    " Printed when someone runs the package with no module; directs them to the\n"
    " canonical CLI form.\n"
).
-spec main() -> nil.
main() ->
    gleam_stdlib:println(
        <<<<"scripts_gleam — use `gleam run -m scripts/<category>/<name>`\n"/utf8,
                "Canonical tree: sub-projects/scripts-gleam/src/scripts/{probe,build,ingest,registry,verify,fractal,tls,pi,drift}\n"/utf8>>/binary,
            "See README.md + src/scripts/README.md for conventions."/utf8>>
    ).
