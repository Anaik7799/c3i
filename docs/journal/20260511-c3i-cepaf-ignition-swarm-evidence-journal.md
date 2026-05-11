# C3I Cepaf/Ignition Swarm Evidence

Session: 2026-05-11 Europe/Stockholm
Ignition request: `1778470697947DD3EF4E739E64A766743`
Email intent: `17784707995685E1D598E7DD39DE23826`
Constraint: only `cepaf_gleam` or ignition operations for swarm start, verification, and notification.

## 1. Summary

The swarm was started through the `cepaf_gleam` ignition request path and verified through `cepaf_gleam` mesh status. Native Zenoh NIF accepted both the ignition launch request and the email notification intent. Final mesh verification reported 16/16 healthy containers.

## 2. Intent

Add a journal, HTML report, slide deck, ZK note, and email artifact while using only `cepaf_gleam` or ignition for operational actions.

## 3. Operational Surface

Allowed operational commands used:

- `gleam build`
- `gleam run -m cepaf_gleam/ignition_launch_request`
- `gleam run mesh-status`
- `gleam run -m cepaf_gleam/email_artifact_notify`

No direct `systemctl`, `podman`, `docker`, or `sa-plan` operation was used for this pass.

## 4. Ignition Launch Evidence

Command:

```sh
gleam run -m cepaf_gleam/ignition_launch_request
```

Observed:

```text
Ignition launch request published via cepaf_gleam native Zenoh NIF
request_id=1778470697947DD3EF4E739E64A766743
response_topic=indrajaal/l5/cog/mcp/res/1778470697947DD3EF4E739E64A766743
zenoh_open={"endpoint":"tcp/localhost:7447","status":"connected"}
zenoh_put={"key":"indrajaal/l5/cog/mcp/req/ignition_launch/1778470697947DD3EF4E739E64A766743","status":"ok"}
```

## 5. Mesh Verification Evidence

Command:

```sh
gleam run mesh-status
```

Final observed state:

- Core mesh services were up.
- Full container list showed all 16 containers up.
- SIL-6 health verification reported `Healthy Containers: 16/16`.
- Native Zenoh NIF connected and published `indrajaal/cepaf/gleam/status`.

Stabilization note: early post-launch reads briefly showed `indrajaal-mojo`, then `indrajaal-ex-app-2` and `indrajaal-chaya`, in a `Stopping` transition while the verifier still reported 16/16. The final read showed all 16 up.

## 6. Email Evidence

Command:

```sh
gleam run -m cepaf_gleam/email_artifact_notify
```

Observed:

```text
Email notification intent published via cepaf_gleam native Zenoh NIF
intent_id=17784707995685E1D598E7DD39DE23826
topic=indrajaal/l5/cog/intent/email/17784707995685E1D598E7DD39DE23826
zenoh_open={"endpoint":"tcp/localhost:7447","status":"connected"}
zenoh_put={"key":"indrajaal/l5/cog/intent/email/17784707995685E1D598E7DD39DE23826","status":"ok"}
```

Boundary: this confirms that the email intent was accepted by the Zenoh transport. It is not an SMTP delivery receipt.

## 7. Code Added

- `lib/cepaf_gleam/src/cepaf_gleam/email_artifact_notify.gleam`
- Existing `lib/cepaf_gleam/src/cepaf_gleam/ignition_launch_request.gleam` was used for ignition.

## 8. Artifacts Added

- `docs/journal/20260511-c3i-cepaf-ignition-swarm-evidence-journal.md`
- `docs/journal/20260511-c3i-cepaf-ignition-swarm-evidence-analysis.html`
- `docs/journal/20260511-c3i-cepaf-ignition-swarm-evidence-slides.html`
- `docs/journal/20260511-c3i-cepaf-ignition-swarm-evidence-zk.md`
- `docs/journal/20260511-c3i-cepaf-ignition-swarm-evidence-email.md`
- `docs/journal/20260511-c3i-cepaf-ignition-swarm-evidence-links.json`

## 9. ZK Context

New note: `[zk-178470697947dd3e]`.

Relevant existing recalls:

- `[zk-3346fc607a1ef9e6]` Stub-That-Lies guard: do not turn accepted transport into delivery/compliance claims.
- `[zk-bb4de67d97f807ac]` Selector-guessing guard: report observed mesh reads, including transient states.

## 10. Residual Risks

- Ignition start is operationally active, but repeated launch requests can create transient container states.
- Earlier historical full verification gaps are not automatically closed by this 16/16 container-health pass.
- Email notification was accepted by Zenoh, but SMTP delivery acknowledgement was not observed through a cepaf/ignition-only path.

## 11. Result

Pass for requested operational scope: ignition request accepted, swarm healthy via `cepaf_gleam`, artifacts added, and email notification intent published through `cepaf_gleam`.

## 12. Follow-Up

Close the remaining gap by adding a cepaf-native delivery acknowledgement route for email intents and an idempotence report for repeated ignition launches.

## 13. Closeout

The 2026-05-11 evidence pack was added with current live observations and no direct service/container/task CLI operations outside `cepaf_gleam` or ignition.
