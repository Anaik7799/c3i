# [zk-9d47c2a8f31e0b65] Cepaf-Only Ignition Startup Evidence

Status: file-backed zettel, pending Smriti ingest
Created: 2026-05-10T21:07:24+02:00
Cluster: journal
Tags: c3i, cepaf-gleam, ignition, zenoh, startup, evidence, journal-artifact

## Claim

When the operator constrains C3I startup evidence to `cepaf_gleam`, ignition should be invoked through the Gleam MoZ/native Zenoh surface and runtime health should be observed through `cepaf_gleam`, not inferred from stale host state.

## Evidence

- `gleam run -m cepaf_gleam/ignition_launch_request` published a launch request to `indrajaal/l5/cog/mcp/req/ignition_launch/177844040259472E536C9B529267B5491`.
- Native Zenoh NIF returned `{"endpoint":"tcp/localhost:7447","status":"connected"}` and `{"status":"ok"}` for the publish.
- `gleam run mesh-status` observed 16/16 healthy containers after the corrected ignition launch request, with post-launch container uptimes around 12-36 seconds.

## Guardrails

- Cite `[zk-3346fc607a1ef9e6]`: startup evidence must not be upgraded to full compliance evidence without the failing verification checks being closed.
- Cite `[zk-bb4de67d97f807ac]`: report observed runtime data, not guessed selector or route state.

## Consequence

This pass supports "swarm started/observed through cepaf_gleam" but does not support "full SIL-6 compliant" because earlier full verification stayed at 15/18 and `c3i-ferriskey.service` remained blocked.

The corrected ignition request also produced `data/logs/ignition_capture.log` activity with duplicate container name and port/network errors. That means the launch path is active but not cleanly idempotent.

## Links

- Journal: `docs/journal/20260510-c3i-swarm-ignition-startup-evidence-journal.md`
- HTML: `docs/journal/20260510-c3i-swarm-ignition-startup-evidence-analysis.html`
- Slides: `docs/journal/20260510-c3i-swarm-ignition-startup-evidence-slides.html`
- Email draft: `docs/journal/20260510-c3i-swarm-ignition-startup-evidence-email.md`
