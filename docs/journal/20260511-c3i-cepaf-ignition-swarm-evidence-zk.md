# [zk-178470697947dd3e] Cepaf/Ignition-Only Swarm Start Evidence

Status: file-backed zettel, pending Smriti ingest
Created: 2026-05-11
Cluster: journal
Tags: c3i, cepaf-gleam, ignition, zenoh, swarm, email, evidence

## Claim

For a cepaf/ignition-only operator pass, the acceptable evidence is: launch request accepted through the ignition MoZ topic, mesh health observed through `cepaf_gleam`, and notification intent published through `cepaf_gleam`.

## Evidence

- Ignition launch request `1778470697947DD3EF4E739E64A766743` published to `indrajaal/l5/cog/mcp/req/ignition_launch/1778470697947DD3EF4E739E64A766743`.
- Final `gleam run mesh-status` reported all 16 containers up and `Healthy Containers: 16/16`.
- Email notification intent `17784707995685E1D598E7DD39DE23826` published to `indrajaal/l5/cog/intent/email/17784707995685E1D598E7DD39DE23826`.

## Guardrails

- `[zk-3346fc607a1ef9e6]`: do not claim SMTP delivery or full SIL-6 acceptance from publish acceptance alone.
- `[zk-bb4de67d97f807ac]`: include transient observations instead of smoothing them out.

## Consequence

This pass supports "swarm start requested through ignition and final mesh observed healthy through cepaf_gleam." It does not prove email delivery or full historical verification closure.

## Links

- Journal: `docs/journal/20260511-c3i-cepaf-ignition-swarm-evidence-journal.md`
- HTML: `docs/journal/20260511-c3i-cepaf-ignition-swarm-evidence-analysis.html`
- Slides: `docs/journal/20260511-c3i-cepaf-ignition-swarm-evidence-slides.html`
- Email artifact: `docs/journal/20260511-c3i-cepaf-ignition-swarm-evidence-email.md`
