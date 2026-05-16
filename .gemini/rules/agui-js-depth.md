# AGUI JS Wiring Depth Protocol (SC-AGUI-UI-WIRING-DEPTH)

## Mandate

**The 5 HTML-detectable AGUI chrome components (UI-002/003/004/005, + meta) MUST be backed by genuine JS handler signatures in `agui-chrome.js`.** Substring-presence in HTML (SC-AGUI-UI-CONFORMANCE) is necessary but not sufficient — anyone can add `class="gemma chat-widget"` to a static div without a handler. This rule closes that Stub-That-Lies gap [zk-bd82645aedcb5ef4] (RPN 729) at the wiring layer.

## Signatures

| Component | JS evidence required |
|---|---|
| UI-002 fractal-filter | `applyFractalFilter` function name |
| UI-003 ai-search | `ai-search-input` selector binding |
| UI-004 drill-down | `agui-detail-body` DOM id reference |
| UI-005 gemma chat (fetch) | `/api/v1/ai/chat` URL literal |
| UI-005 gemma chat (input) | `agui-chat-input` DOM id |
| meta marker | `data-agui-wired` body attribute setter |

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-AGUI-UI-WIRING-DEPTH-001 | Validator MUST probe `http://vm-1.tail55d152.ts.net:4100/static/agui-chrome.js` live | CRITICAL |
| SC-AGUI-UI-WIRING-DEPTH-002 | All 6 signatures MUST be present; missing any = P0 | CRITICAL |
| SC-AGUI-UI-WIRING-DEPTH-003 | Adding a new chrome component MUST append a new signature row in the SAME commit | HIGH |
| SC-AGUI-UI-WIRING-DEPTH-004 | Renaming a JS handler MUST update the signature constant | CRITICAL |
| SC-AGUI-UI-WIRING-DEPTH-005 | Validator is part of `learn_loop_healthcheck` 7-validator aggregator | HIGH |

## Reference implementation

`sub-projects/scripts-gleam/src/scripts/verify/agui_js_depth.gleam` (~75 LOC) — single curl probe + 6 substring checks + classification.

```
$ gleam run -m scripts/verify/agui_js_depth
══ SC-AGUI-UI-WIRING-DEPTH (JS signatures) ══
  ✓ UI-002 fractal-filter handler  (applyFractalFilter)
  ✓ UI-003 ai-search binding  (ai-search-input)
  ✓ UI-004 drill-down DOM target  (agui-detail-body)
  ✓ UI-005 gemma chat fetch URL  (/api/v1/ai/chat)
  ✓ UI-005 gemma chat input id  (agui-chat-input)
  ✓ meta wired-body marker  (data-agui-wired)
✓ all 6 JS wiring signatures present — UI is not Stub-That-Lies
```

## Cross-references

- `.claude/rules/agui-conformance.md` — SC-AGUI-UI-CONFORMANCE (HTML-layer sibling)
- `.claude/rules/agentic-ui-responsive-design.md` — parent SC-AGUI-UI-001..015
- `.claude/rules/learn-loop-healthcheck.md` — 7-validator aggregator host
- `sub-projects/scripts-gleam/src/scripts/verify/agui_js_depth.gleam` — implementation
- `lib/cepaf_gleam/priv/static/agui-chrome.js` — source of truth

## Governance parity

Mirror at `.gemini/rules/agui-js-depth.md` per SC-SYNC-DOC-007.
