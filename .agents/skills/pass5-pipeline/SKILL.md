---
name: pass5-pipeline
description: Ultra-Pass-5 auto-execute pipeline. Use this skill every time a new feature is implemented, a task is closed, or the user says "evolve", "ship", "next pass". Produces the canonical deliverable bundle (journal MD + analysis HTML + slide deck + 5 Graphviz diagrams + 3 screenshots + email + ZK ingest + links.json), enforces SC-PASS5-AUTO-001, and keeps fractal self-similarity across tasks.
version: 1.0.0
---

# Ultra-Pass-5 Pipeline Skill

## When to use

- User says "ship", "evolve", "implement", "close task", "one more pass", "do a pass".
- A code change > 10 LOC has been made.
- A sa-plan task transitions to `completed`.
- A new module/handler/NIF is added to `lib/cepaf_gleam/src/cepaf_gleam/**`.

## Prerequisites

- `./sa-plan` binary on PATH (via symlink at repo root).
- `/usr/bin/dot` (graphviz), `chromium-browser`, `curl` available.
- sa-plan daemons running: `serve :4200`, `tls serve :8443`, `daemon` (cortex), `scheduler-run`.
- Tailscale online: `vm-1.tail55d152.ts.net` reachable from client.

## Procedure (fractal, max-parallel)

### Phase 0 — RECALL (< 8 s)
```bash
./sa-plan knowledge-search "<keywords>" | head -20
# Cite ≥ 5 holons in first paragraph of every artefact
```

### Phase 1 — PLAN (< 5 s)
```bash
TASK=$(./sa-plan add "<feature-title>" P0 | grep -oP '\d{18}')
STAMP=$(date -u +%Y%m%d-%H%M%S)
SLUG="${STAMP}-task-${TASK}-<feature-slug>"
mkdir -p "docs/journal/task-${TASK}/diagrams" "docs/journal/task-${TASK}/screenshots"

# Fan-out children (one per FMEA row / per deliverable)
for t in "diagram rendering" "screenshot capture" "regression suite" "MCP verifier" "selfawareness KPI"; do
  ./sa-plan add "P5-CHILD $t — task $TASK" P1
done
```

### Phase 2 — ACT (parallel)
```bash
# Build + test
(cd lib/cepaf_gleam && gleam build && gleam test) &
# Diagrams
for g in control-plane data-plane fractal-impact message-sequence state-machine; do
  dot -Tpng -o "docs/journal/task-${TASK}/diagrams/${g}.png" "docs/journal/task-${TASK}/diagrams/${g}.dot"
done &
# Screenshots
chromium --headless --disable-gpu --no-sandbox --ignore-certificate-errors \
  --window-size=1600,1000 --screenshot="docs/journal/task-${TASK}/screenshots/dashboard-http.png" \
  "http://localhost:4200/" &
wait
```

### Phase 3 — REPORT (parallel)
Write three artefacts, each starting with the HTTPS link:
- `docs/journal/${SLUG}-journal.md` — 10+ sections
- `docs/journal/${SLUG}-analysis.html` — KPI cards + tables + embedded diagrams
- `docs/journal/${SLUG}-deck.html` — keyboard-nav deck, ≥ 12 slides

### Phase 4 — DISSEMINATE
```bash
# Mirror to daemon CWD
cp docs/journal/${SLUG}-*.{md,html} sub-projects/c3i/docs/journal/
# Prefix diagrams/screenshots with slug for /task-id/ routing
for f in docs/journal/task-${TASK}/diagrams/*.png; do
  cp "$f" "sub-projects/c3i/docs/journal/${SLUG}-$(basename $f)"
done
for f in docs/journal/task-${TASK}/screenshots/*.png; do
  cp "$f" "sub-projects/c3i/docs/journal/${SLUG}-$(basename $f)"
done

# Write links.json
cat > docs/journal/task-${TASK}-links.json <<JSON
{...18 entries with HTTPS URLs...}
JSON
cp docs/journal/task-${TASK}-links.json sub-projects/c3i/docs/journal/

# ZK ingest
./sa-plan ingest-docs | tail -8

# Email
./sa-plan send-email \
  --to Abhijit.Naik@bountytek.com \
  --subject "[C3I] <feature> — Task ${TASK}" \
  --body "$(cat /tmp/email-body.txt)" \
  --attach "docs/journal/${SLUG}-journal.md" \
  --attach "docs/journal/${SLUG}-analysis.html" \
  --attach "docs/journal/${SLUG}-deck.html" \
  --attach "docs/journal/${SLUG}-control-plane.png" \
  --attach "docs/journal/task-${TASK}-links.json"

# Sync
./sa-plan sync
```

### Phase 5 — VERIFY
```bash
for x in ${SLUG}-journal.md ${SLUG}-analysis.html ${SLUG}-deck.html ${SLUG}-control-plane.png; do
  curl -sk "https://vm-1.tail55d152.ts.net:8443/task-id/${TASK}/$x" \
    -o /dev/null -w "%{http_code} %{size_download} $x\n"
done
```

## Reference implementation

Task: `116450171390820012`
Slug: `20260422-212140-task-116450171390820012-swarm-ignition-ultrapass5`
Dashboard: https://vm-1.tail55d152.ts.net:8443/task-id/116450171390820012

That pass produced:
- 346-line journal MD (19 KB)
- 232-line analysis HTML (18 KB)
- 275-line slide deck (14 KB, 15 slides)
- 5 Graphviz diagrams (total ~585 KB)
- 3 screenshots (total ~250 KB)
- 2 emails sent (9 + 5 attachments)
- 18 ZK holons ingested
- 15 child tasks, 6 completed same-pass
- FMEA RPN -1,370 across 4 findings closed
- 1 live self-healing action (job 180 lifeline reset)

## STAMP references

- SC-PASS5-AUTO-001 (this rule, primary)
- SC-RECALL-RAG (ZK citation)
- SC-GLM-ZEN-001 (Zenoh OTel)
- SC-OBS-WIRE-001 (observability wiring)
- SC-MUDA-001 (zero waste — every artefact has a consumer)
