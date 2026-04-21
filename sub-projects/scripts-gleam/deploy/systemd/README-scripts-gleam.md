# scripts-gleam systemd units (SC-SCRIPT-GLEAM-001)

Template unit + timer that schedule any registered gleam-run script on a host.

## Naming convention

Instance suffix `<category>-<name>` maps to module `scripts/<category>/<name>`.
The unit replaces the first `-` with `/` when invoking `gleam run`.

Examples:

| Systemd instance | Module invoked |
|---|---|
| `scripts-gleam@verify-symbiosis_smoke.service` | `scripts/verify/symbiosis_smoke` |
| `scripts-gleam@probe-public_interface.service` | `scripts/probe/public_interface` |
| `scripts-gleam@tools-retain.service` | `scripts/tools/retain` |
| `scripts-gleam@tools-list.service` | `scripts/tools/list` |
| `scripts-gleam@tools-metrics_dump.service` | `scripts/tools/metrics_dump` |

## Install

```bash
# System-wide (one-time)
sudo cp deploy/systemd/scripts-gleam@.service /etc/systemd/system/
sudo cp deploy/systemd/scripts-gleam@.timer   /etc/systemd/system/
sudo systemctl daemon-reload

# Schedule specific scripts
sudo systemctl enable --now scripts-gleam@verify-symbiosis_smoke.timer
sudo systemctl enable --now scripts-gleam@probe-public_interface.timer
sudo systemctl enable --now scripts-gleam@tools-retain.timer
```

## Tuning per script

Each script declares its own retention + fractal layer in `manifest/0`.
The unit applies uniform resource caps:

| Setting | Value | Rationale |
|---|---|---|
| TimeoutStartSec | 900s | cap runaway runs |
| MemoryMax | 2G | dimension #5 (resource governance) |
| CPUQuota | 200% | up to 2 cores |
| ReadWritePaths | `data/`, `build/` only | filesystem write-fence |
| NoNewPrivileges | true | no privilege escalation |
| ProtectSystem | strict | read-only root |

Override per-instance with a drop-in:

```bash
sudo systemctl edit scripts-gleam@verify-symbiosis_smoke.service
```

## Observability

- stdout + stderr are journaled by systemd (`journalctl -u scripts-gleam@...`).
- Every run writes a full `result.json` and `stdout.log` under
  `/home/an/dev/ver/c3i/data/script-output/<category>/<name>/<stamp>/`.
- Fractal spans publish on Zenoh `indrajaal/<layer>/scripts/<name>`.
- Metrics counters + histograms publish on `indrajaal/metrics/scripts/**`.

## Retention

`scripts-gleam@tools-retain.timer` runs daily and prunes run directories older
than each script's `manifest.retention_days`.
