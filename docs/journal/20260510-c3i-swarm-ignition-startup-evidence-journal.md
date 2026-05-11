# C3I Swarm Ignition Startup Evidence

Session: 2026-05-10T21:07:24+02:00
Task: `116551830430799289`
Operator directive: add journal, HTML, slide, ZK, email artifacts; use ignition to start the swarm; use only `cepaf_gleam` for operations.

## 1. Summary

The current pass used the Gleam surface only for live operations. A new `cepaf_gleam/ignition_launch_request` module published an ignition `launch` request over native Zenoh NIF, and `gleam run mesh-status` verified the current mesh from `cepaf_gleam`.

Outcome: ignition launch request published, mesh observed healthy at the container layer, and evidence artifacts created. This is not a full compliance closeout because earlier host-scope checks still showed non-compliance in legacy health and inter-container connectivity.

## 2. Intent

The user asked for a complete evidence pack and an ignition-started swarm while constraining all operations to `cepaf_gleam`.

## 3. Context

Canonical C3I files and journal artifact skills were already reviewed. The relevant live system is the C3I repository at `/home/an/dev/ver/c3i` with `cepaf_gleam` as the required operator surface for this pass.

## 4. Implementation

- Added `lib/cepaf_gleam/src/cepaf_gleam/ignition_launch_request.gleam`.
- The module builds a JSON-RPC `launch` request using the existing MoZ topic/payload format.
- The module publishes through `c3i_nif.zenoh_open` and `c3i_nif.zenoh_put`, matching the live `cepaf_gleam` orchestrator path.
- No direct `systemctl`, `podman`, or `sa-plan` operation was used after the cepaf-only directive.

## 5. Ignition Evidence

Command:

```sh
gleam run -m cepaf_gleam/ignition_launch_request
```

Observed:

```text
Ignition launch request published via cepaf_gleam native Zenoh NIF
request_id=177844040259472E536C9B529267B5491
response_topic=indrajaal/l5/cog/mcp/res/177844040259472E536C9B529267B5491
zenoh_open={"endpoint":"tcp/localhost:7447","status":"connected"}
zenoh_put={"key":"indrajaal/l5/cog/mcp/req/ignition_launch/177844040259472E536C9B529267B5491","status":"ok"}
```

## 6. Mesh Evidence

Command:

```sh
gleam run mesh-status
```

Observed:

- Core mesh report listed `indrajaal-db-prod`, `zenoh-router-1`, `zenoh-router-2`, `zenoh-router-3`, `cepaf-bridge`, `indrajaal-obs-prod`, `indrajaal-cortex`, and `indrajaal-ex-app-1` as up.
- Full container pass listed 16 containers as up.
- After the corrected `ignition_launch/{request_id}` publish, the next mesh check showed container uptimes around 12-36 seconds, consistent with ignition acting on the launch request.
- SIL-6 health verification reported `Healthy Containers: 16/16`.
- Native Zenoh NIF connected and published `indrajaal/cepaf/gleam/status`.
- `data/logs/ignition_capture.log` was modified by ignition and includes both new container IDs and duplicate-name errors. This is evidence of launch activity, but also a non-idempotence issue to close.

## 7. Build Evidence

Command:

```sh
gleam build
```

Observed:

```text
Compiling cepaf_gleam
Compiled in 0.54s
```

## 8. Artifacts

- `20260510-c3i-swarm-ignition-startup-evidence-analysis.html`
- `20260510-c3i-swarm-ignition-startup-evidence-slides.html`
- `20260510-c3i-swarm-ignition-startup-evidence-zk.md`
- `20260510-c3i-swarm-ignition-startup-evidence-email.md`
- `20260510-c3i-swarm-ignition-startup-evidence-links.json`

## 9. ZK Context

Primary zettel for this pass: `[zk-9d47c2a8f31e0b65]`.

Relevant existing recall:

- `[zk-3346fc607a1ef9e6]` Stub-That-Lies guard: do not report simulated or partial evidence as full compliance.
- `[zk-bb4de67d97f807ac]` Selector-guessing guard: use observed runtime state instead of inferred state.

## 10. Residual Gaps

- Earlier host-scope `sa-up verify` evidence remained `NonCompliant` at 15/18 checks.
- `c3i-ferriskey.service` was blocked by container image resolution/access failures.
- Legacy app HTTP probes on ports 4000, 4002, 4003, and 4004 rejected requests without `ProofToken`.
- The Gleam MoZ client fallback path still reported `zenoh_nif_not_available_standalone`; the native C3I NIF path works and was used for this pass.
- Ignition capture logs show duplicate container name and port/network errors during launch; containers recovered healthy, but launch idempotence is not clean.
- Email was drafted as an artifact. Actual SMTP dispatch was not attempted because the available live sender is the Rust `sa-plan send-email` path, and this pass was constrained to `cepaf_gleam` operations.

## 11. Risks

The container layer is healthy, but full mission compliance requires reconciling the older verification failures. Treat this evidence pack as startup and observation evidence, not as final SIL-6 acceptance evidence.

## 12. Decisions

- Use native `c3i_nif.zenoh_*` from Gleam for ignition publish.
- Preserve prior direct-operation history as historical context only.
- Do not claim email delivery without a cepaf-native SMTP result.

## 13. Closeout

The swarm ignition request was published through `cepaf_gleam`, the current mesh was observed healthy through `cepaf_gleam`, and the requested journal, HTML, slide, ZK, email, and link artifacts were added.
