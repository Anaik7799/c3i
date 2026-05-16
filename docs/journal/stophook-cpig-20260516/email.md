# Email draft (per SC-NOTIFY-JOURNAL-001)

**Status**: DRAFT — not yet sent. Send via `sa-plan-daemon send-email` after operator approval.

---

**To**: Abhijit.Naik@bountytek.com
**Subject**: Diagnostic: Stop-hook regression + CPIG Pass-15 readiness (60/65 actual, not 62/65)

**Body**:

```
Operator handoff: https://vm-1.tail55d152.ts.net:4200/task-id/stophook-cpig-20260516/

This session opened with "improve symbiosis with the system" and across four turns
revealed two findings that warrant next-session action:

1. ACTIVE REGRESSION on Stop hook (canonical OODA Learn phase).
   Citations grew 50 -> 104 -> 156 -> 255 in this session alone, with slope
   accelerating (+53, +52, +99/turn). Classified as Wolfram Rule 30 chaos
   emergence per .claude/rules/cross-pass-invariant-gate.md sec.8. Mechanical
   root cause: ingest.rs:192-203 dedup queries content_hash on a 272 MB
   SQLite DB with NO index on that column. 37,828 holons. Sequential C3I+FY27
   ingest in 88-line gleam orchestrator. Stub-That-Lies anti-pattern at the
   institutional layer (zk-bd82645aedcb5ef4, RPN 729).

2. CPIG matrix OVERSTATES by 2 gates. cpig-matrix.json v1.4.0 (2026-05-01)
   claims 62/65 (95.4 %), but mechanical SQL queries against Smriti.db show:
     - 0 holons tagged 'fractal' (despite Fractal G4 scored 1)
     - 0 holons tagged 'dart' or 'mcp' (Dart G4 honestly scored 0)
     - Fractal G5 evidence string says "gap" but score is 1
   True CPIG: 60/65 (92.3 %). Pattern: matrix needs a Wiring-Guard analogue
   (SC-WIRE for type-domain, SC-VALUE-GUARD for value-domain, this would be
   the third sibling for score-evidence consistency).

RECOMMENDED NEXT-SESSION SEQUENCE (~8h to 65/65):
  A. Stop-hook incremental ingest         ~2-3h    P0     L2-L3 only
  E. CPIG matrix recount                  ~10 min  P1     independent
  B. Dart MCP G4 (ZK ingest 16 tools)     ~30 min  P2     requires A
  C. Fractal L0-L7 G4+G5                  ~1.5h    P2     requires A
  D. Cortex 6-tier G4+G5                  ~4h      P3     requires A

Sequencing rule: B/C/D MUST follow A. If ingest is broken, their closure
packs themselves silently fail to ingest -- Stub-That-Lies trap.

DELIVERABLES (this pass, investigation-only):
  - docs/journal/diagnostic-stophook-cpig-20260516-072912.md (prior turn)
  - docs/journal/stophook-cpig-20260516/journal.md (13-section, this turn)
  - docs/journal/stophook-cpig-20260516/analysis.html (operator dashboard)
  - docs/journal/stophook-cpig-20260516/deck.html (8-slide deck)
  - docs/journal/stophook-cpig-20260516/fractal-matrix.md (L0-L7 × STAMP × RPN)
  - docs/journal/stophook-cpig-20260516/links.json (registry)
  - docs/journal/stophook-cpig-20260516/email.md (this draft)
  - /home/an/.claude/plans/check-the-current-state-fluffy-crown.md (approved plan)

No code changes. No commits. No CPIG matrix update. No sa-plan task created.
Awaiting operator decision on next-session scope (Option A alone, A+E,
A+E+B, or A+E+B+C+D for full Pass-15 100 %).

Tailscale operator URL:
  https://vm-1.tail55d152.ts.net:4200/task-id/stophook-cpig-20260516/

ZK lineage: zk-dbd0d3a6d840784d, zk-bf18d04e2ea3542f, zk-bd82645aedcb5ef4,
zk-c14e1d23afff486c, zk-5f7ea54b788cf845, zk-cb6a46df870c8f6c

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

**Attachments** (per SC-NOTIFY-JOURNAL-001 / SC-NOTIFY-HANDOFF-001):

```
-a docs/journal/stophook-cpig-20260516/journal.md
-a docs/journal/stophook-cpig-20260516/analysis.html
-a docs/journal/stophook-cpig-20260516/deck.html
-a docs/journal/stophook-cpig-20260516/fractal-matrix.md
-a docs/journal/stophook-cpig-20260516/links.json
-a docs/journal/diagnostic-stophook-cpig-20260516-072912.md
```

**Send command** (after operator approval):

```bash
sa-plan-daemon send-email \
  --to Abhijit.Naik@bountytek.com \
  --subject "Diagnostic: Stop-hook regression + CPIG Pass-15 readiness (60/65 actual)" \
  --body "$(cat /home/an/dev/ver/c3i/docs/journal/stophook-cpig-20260516/email.md | sed -n '/^```$/,/^```$/p' | sed '1d;$d')" \
  -a /home/an/dev/ver/c3i/docs/journal/stophook-cpig-20260516/journal.md \
  -a /home/an/dev/ver/c3i/docs/journal/stophook-cpig-20260516/analysis.html \
  -a /home/an/dev/ver/c3i/docs/journal/stophook-cpig-20260516/deck.html \
  -a /home/an/dev/ver/c3i/docs/journal/stophook-cpig-20260516/fractal-matrix.md \
  -a /home/an/dev/ver/c3i/docs/journal/stophook-cpig-20260516/links.json \
  -a /home/an/dev/ver/c3i/docs/journal/diagnostic-stophook-cpig-20260516-072912.md
```
