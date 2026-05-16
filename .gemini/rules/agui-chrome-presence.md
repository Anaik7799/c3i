# AGUI Chrome Structural Presence Protocol (SC-AGUI-UI-CHROME-PRESENCE)

## Mandate

**The 5 structural element IDs that `agui-chrome.js` targets MUST be present in the rendered HTML of every page in the C3I navigation graph, AND every page MUST carry ≥ 9 `fractal-chip` elements (L0-L7 + All).** Substring class-name presence (SC-AGUI-UI-CONFORMANCE) is necessary but not sufficient — a stub div with `class="gemma chat-widget"` but no `<form class="chat-panel-form">` would pass class-substring but fail JS wiring.

This rule closes the gap between Layer 1 (class names) and Layer 3 (JS handler signatures) per [zk-bd82645aedcb5ef4] anti-Stub-That-Lies (RPN 729).

## Three-layer defense-in-depth

| Layer | Constraint family | Validator | Probes |
|---|---|---|---|
| 1 | SC-AGUI-UI-CONFORMANCE | `agui_conformance` | HTML class-name substrings × 11 components × 32 pages |
| 2 | **SC-AGUI-UI-CHROME-PRESENCE** (this) | `agui_chrome_presence` | DOM element IDs × 5 + fractal-chip count × 32 pages |
| 3 | SC-AGUI-UI-WIRING-DEPTH | `agui_js_depth` | JS handler signatures × 10 in agui-chrome.js |

A stub div with only class names passes Layer 1 but fails Layer 2.
A stub JS file with only function names fails Layer 3.
A page that doesn't load agui-chrome.js fails Layer 1 (UI-WIRED check).

## Required structural IDs

| ID | Component | Used by JS |
|---|---|---|
| `ai-search-input` | UI-003 search input | `searchInputs.forEach(input.addEventListener)` |
| `agui-detail-body` | UI-004 drill-down body | `getElementById('agui-detail-body').textContent = ...` |
| `chat-panel-form` | UI-005 gemma chat form | `document.querySelector('.chat-panel-form').addEventListener('submit')` |
| `agui-chat-input` | UI-005 chat input | `getElementById('agui-chat-input').value` |
| `change-log-feed` | UI-007 event feed | `document.querySelector('.change-log-feed').insertBefore(...)` |

Plus 9 `fractal-chip` elements (L0-L7 + All) for UI-002 filter.

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-AGUI-UI-CHROME-PRESENCE-001 | Validator MUST probe live HTML at base URL via curl per page | CRITICAL |
| SC-AGUI-UI-CHROME-PRESENCE-002 | All 5 required IDs MUST be present in every page's rendered HTML | CRITICAL |
| SC-AGUI-UI-CHROME-PRESENCE-003 | ≥ 9 fractal-chip elements MUST be rendered per page | HIGH |
| SC-AGUI-UI-CHROME-PRESENCE-004 | Adding a chrome component MUST append a new required ID in the SAME commit | HIGH |
| SC-AGUI-UI-CHROME-PRESENCE-005 | Renaming a chrome element ID MUST update the constant | CRITICAL |
| SC-AGUI-UI-CHROME-PRESENCE-006 | Validator MUST be invokable with `argv[1]` base URL override (for meta-tests) | HIGH |
| SC-AGUI-UI-CHROME-PRESENCE-007 | Validator MUST be in `learn_loop_healthcheck` 8-validator aggregator | HIGH |
| SC-AGUI-UI-CHROME-PRESENCE-008 | Validator MUST have a meta-test row in `validators_meta_test` proving it trips on bad input | HIGH |

## Reference implementation

`sub-projects/scripts-gleam/src/scripts/verify/agui_chrome_presence.gleam` (~120 LOC) — per-page curl probe + 5 ID checks + chip counter + classification.

```
$ gleam run -m scripts/verify/agui_chrome_presence
══ SC-AGUI-UI-CHROME-PRESENCE — Per-page structural probe ══
base: http://vm-1.tail55d152.ts.net:4100

✓ all 32 pages carry the 5 structural chrome IDs + ≥9 fractal chips
```

Synthetic-bad meta-test (per SC-VALIDATORS-META-TEST):
```
$ gleam run -m scripts/verify/agui_chrome_presence -- http://...:4100/api/v1/pages
✗ 32 pages with structural chrome gaps:
  • /  missing_ids=5  chips=0
  • /dashboard  missing_ids=5  chips=0
  …
hint: sa-plan add --priority P0 'Restore AGUI chrome structural IDs ...'
```

## Cross-references

- `.claude/rules/agui-conformance.md` — SC-AGUI-UI-CONFORMANCE (class-substring sibling, Layer 1)
- `.claude/rules/agui-js-depth.md` — SC-AGUI-UI-WIRING-DEPTH (JS-signature sibling, Layer 3)
- `.claude/rules/agentic-ui-responsive-design.md` — parent SC-AGUI-UI-001..015
- `.claude/rules/learn-loop-healthcheck.md` — 8-validator aggregator host
- `.claude/rules/validators-meta-test.md` — meta-test requirement
- `sub-projects/scripts-gleam/src/scripts/verify/agui_chrome_presence.gleam` — implementation
- `lib/cepaf_gleam/src/cepaf_gleam/ui/web/page_helpers.gleam` — chrome element source

## Governance parity

Mirror at `.gemini/rules/agui-chrome-presence.md` per SC-SYNC-DOC-007.
