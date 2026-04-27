# Post-Feature Evolution Protocol (SC-FEAT-EVO)

## MANDATE
**After EVERY new feature implementation, the following pipeline MUST execute automatically.**

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-FEAT-EVO-001 | Feature MUST pass gleam build + gleam test before analysis | CRITICAL |
| SC-FEAT-EVO-002 | Fractal analysis MUST cover all 8 layers (L0-L7) | HIGH |
| SC-FEAT-EVO-003 | HTML dashboard MUST be generated and served via sa-plan-daemon | HIGH |
| SC-FEAT-EVO-004 | Journal MUST follow 13-section protocol (SC-JOURNAL) | CRITICAL |
| SC-FEAT-EVO-005 | Journal MUST be emailed as attachment (SC-NOTIFY-JOURNAL-001) | CRITICAL |
| SC-FEAT-EVO-006 | ZK MUST be updated with new holons (SC-ZETTEL-001) | HIGH |
| SC-FEAT-EVO-007 | Wiring guard MUST be updated for new types (SC-WIRE-002) | CRITICAL |
| SC-FEAT-EVO-008 | Tailscale link MUST be emailed for HTML dashboard access | HIGH |

## Pipeline Steps (Execute in order)

### Step 1: Build Verification
```bash
cd lib/cepaf_gleam && gleam build  # 0 errors, 0 warnings
cd lib/cepaf_gleam && gleam test   # 0 failures
```

### Step 2: Fractal Analysis
- Identify ALL fractal layers impacted by the feature
- For each layer: list components, use cases, data flows, control flows
- Calculate fractal tensor coverage (feature x layer matrix)
- Document improvements expected per layer

### Step 3: HTML Dashboard Generation
- Create responsive HTML (mobile-first, dark theme, glassmorphism)
- Include: overview stats, fractal tensor, RBAC matrix (if auth), layer details, architecture flows, metrics
- Copy to `sub-projects/c3i/native/planning_daemon/web_static/`
- Add route to sa-plan-daemon web server
- Dashboard accessible at `https://vm-1.tail55d152.ts.net:4200/{feature-name}`

### Step 4: SVG Diagram Generation
- Architecture diagram showing integration points
- Data flow diagrams for key flows
- RBAC/access matrix (if auth-related)
- Save to `docs/journal/diagrams/`

### Step 5: Journal Entry (13-section)
1. Scope & Trigger
2. Pre-State Assessment
3. Execution Detail
4. Root Cause Analysis
5. Fix Taxonomy
6. Patterns & Anti-Patterns Discovered
7. Verification Matrix
8. Files Modified
9. Architectural Observations
10. Remaining Gaps
11. Metrics Summary
12. STAMP & Constitutional Alignment
13. Conclusion

### Step 6: Email Dispatch
```bash
sa-plan-daemon send-email \
  --to Abhijit.Naik@bountytek.com \
  --subject "Feature: {name} — {summary}" \
  --body "Dashboard: https://vm-1.tail55d152.ts.net:4200/{feature-name}
  {1-2 sentence summary}" \
  -a docs/journal/{journal-file}.md \
  -a docs/journal/{html-file}.html
```

### Step 7: ZK Ingest
```bash
sa-plan-daemon ingest-docs
```

### Step 8: STAMP Constraint Registration
- Add new SC-* constraints to `.claude/rules/` if applicable
- Update constraint registry

## Tailscale Dashboard Access
All HTML dashboards served by sa-plan-daemon at port 4200 are accessible via Tailscale:
- `https://vm-1.tail55d152.ts.net:4200/` — main dashboard
- `https://vm-1.tail55d152.ts.net:4200/ferriskey` — FerrisKey IAM analysis
- `https://vm-1.tail55d152.ts.net:4200/kpi` — KPI tracking

## Integration Points
- **RETE-UL**: New features should add GRL rules if they introduce decision logic
- **Ruliology**: Wolfram CA analysis if the feature affects system dynamics
- **Allium**: Behavioral spec update in `specs/allium/`
- **FMEA**: Failure mode analysis for safety-critical features
- **Guard Grid**: New guard grid cells if the feature adds verifiable components
