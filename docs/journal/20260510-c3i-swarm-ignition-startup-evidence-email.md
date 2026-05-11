To: Abhijit.Naik@bountytek.com
Subject: C3I swarm ignition startup evidence - 2026-05-10
Delivery-Status: Drafted, not sent under cepaf-only operation constraint

Abhijit,

I added the C3I swarm startup evidence pack and ran the current pass through `cepaf_gleam`.

Summary:

- Added a Gleam ignition request module: `lib/cepaf_gleam/src/cepaf_gleam/ignition_launch_request.gleam`.
- Published an ignition `launch` request through native Zenoh NIF from `cepaf_gleam`.
- Verified the current mesh with `gleam run mesh-status`; it reported 16/16 healthy containers after the corrected `ignition_launch` request, with post-launch uptimes around 12-36 seconds.
- Added journal, HTML report, slide deck, ZK note, and link manifest artifacts under `docs/journal/`.

Important boundary:

This is startup and container-health evidence, not final SIL-6 acceptance evidence. Earlier full verification was still 15/18 and non-compliant; Ferriskey image access and legacy proof-token health probes remain open.

Also, `data/logs/ignition_capture.log` showed duplicate container name and port/network errors during launch. The mesh recovered to 16/16 healthy, but ignition idempotence still needs a follow-up pass.

Artifacts:

- `docs/journal/20260510-c3i-swarm-ignition-startup-evidence-journal.md`
- `docs/journal/20260510-c3i-swarm-ignition-startup-evidence-analysis.html`
- `docs/journal/20260510-c3i-swarm-ignition-startup-evidence-slides.html`
- `docs/journal/20260510-c3i-swarm-ignition-startup-evidence-zk.md`
- `docs/journal/20260510-c3i-swarm-ignition-startup-evidence-links.json`

Email dispatch note:

I did not send this over SMTP because the available live SMTP sender is the Rust `sa-plan send-email` path, and the current operator constraint was to use only `cepaf_gleam` for operations. The message is ready for dispatch once a cepaf-native SMTP path is available or the Rust sender is explicitly allowed.
