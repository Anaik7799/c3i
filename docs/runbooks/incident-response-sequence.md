# Incident Response Sequence

## 7-Step Response Protocol

### 1. DETECT
**Automated**: Health endpoint failure, SLO violation, Zenoh alert, guard grid Jidoka
**Manual**: User report, operator observation, monitoring dashboard

```bash
# Quick system check
sa-plan-daemon status
curl -sf http://localhost:4100/health | jq .
sa-plan-daemon fitness --gleam-dir lib/cepaf_gleam
```

### 2. TRIAGE
Classify severity using incident-severity-matrix.md.
Identify affected services: which containers, which API endpoints, which users.

```bash
# Check container health
podman ps --format "{{.Names}} {{.Status}}"
# Check Zenoh mesh
sa-plan-daemon dashboard  # TUI view
```

### 3. DECLARE
- Post in Telegram/GChat: "INCIDENT P{N}: {description}"
- Start incident timer
- Assign incident commander (IC)

```bash
sa-plan-daemon gateway --channel telegram --text "INCIDENT P1: [description]. IC: [name]. Status: investigating."
```

### 4. ISOLATE
Contain blast radius. Prevent cascade.

| Component | Isolation Command |
|-----------|------------------|
| Single container | `podman stop <name>` |
| Failing module | Guard grid isolates automatically |
| Database | `sqlite3 Smriti.db ".backup /tmp/smriti-$(date +%s).db"` |
| Full mesh | `sa-down` (graceful teardown) |

### 5. MITIGATE
Apply fix or workaround.

| Scenario | Action |
|----------|--------|
| Bad code deployed | `git revert HEAD && gleam build && sa-plan-daemon hot-reload` |
| Container crash loop | `podman restart <name>` or rebuild image |
| Database corruption | `sa-plan-daemon restore --from <backup>` |
| NIF failure | Restart BEAM: `pkill -f beam.smp && sa-gleam-start -d` |

### 6. RESTORE
Verify health restored. Clear alerts. Monitor for 30 minutes.

```bash
curl -sf http://localhost:4100/health | jq .status  # Must be "ok"
sa-plan-daemon fitness --gleam-dir lib/cepaf_gleam   # Score > 0.4
```

### 7. REVIEW
Blameless post-mortem within 48 hours. Use rca-template.md.
Ingest findings to Zettelkasten: `sa-plan-daemon ingest-docs`
