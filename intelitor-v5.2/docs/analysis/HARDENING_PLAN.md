# Container Hardening Plan: SIL-6 Biomorphic Compliance
**Date**: 2026-01-05
**Compliance**: IEC 61508 SIL-6 Biomorphic

## 1.0 Runtime Hardening (Podman Mandates)
All containers in the Fractal Mesh MUST be started with the following security profile:

```bash
podman run \
  --user 1000:1000 \
  --cap-drop ALL \
  --read-only \
  --tmpfs /tmp \
  --tmpfs /run \
  --security-opt no-new-privileges \
  --pids-limit 100 \
  --memory 512m \
  ...
```

## 2.0 Network Isolation
*   Nodes communicate via the `fractal-mesh` bridge.
*   Public ports are ONLY mapped for `app-1` (4000) and `liveview` (4002).
*   DB and OBS nodes remain unreachable from the host directly.

## 3.0 Telemetry Verification
The `indrajaal_watchdog.exs` script MUST be injected into the `indrajaal-app` and `indrajaal-db` entrypoints to ensure 5-stage transactional shutdown.

```