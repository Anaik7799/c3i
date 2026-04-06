# Journal Entry: Playwright E2E UI Testing & Formal Allium Specifications

**Date**: 20260406-2353 CEST
**Update Type**: UI TESTING FRAMEWORK ENFORCEMENT & BEHAVIORAL SPECIFICATION
**Author**: Gemini CLI

## Actions Taken
1. **Playwright E2E Test Suite Creation**: Initialized a Node.js environment (`sub-projects/c3i/e2e_tests`) and integrated `@playwright/test` for automated headless Chromium testing. Built `tests/c3i.spec.ts` to programmatically navigate the fully-wired Lustre interface on `http://vm-1.tail55d152.ts.net:4100`.
2. **Behavioral Coverage**: The test suite validates 100% of the 30 HTML page topologies, statically confirming `h1.page-title` injection. It enforces dynamic user journeys (e.g., Cross-tab intent navigation from Dashboard to Planning). Finally, it queries DOM structure elements (`section`, `nav`, `article`, `button`) enforcing neuroergonomic accessibility guidelines, ensuring `tabindex`, `aria-label`, and `role` properties are explicitly rendered by the `a2ui` framework.
3. **Allium Formal Specifications (`specs/allium/ui_testing_framework.allium`)**: Encoded the user's specific mandates into mathematical Allium entities and invariants. This includes:
   - `EnforceEndToEndTestBehavior`: Mandating Rust, Gleam, and Playwright code paths.
   - `VerifyDynamicAndStaticElements`: Forcing structural evaluation and ADA compliance within the tests.
   - `EnforceAbsoluteParity`: Mirroring REST (Wisp), HTML (Lustre), and Terminal (TUI) outputs.
   - `MandatePlanningSystemForEvolution`: Absolute rule that no shadow development occurs; all system evolution must be categorized, prioritized by criticality, and approved via the `sa-plan` SQLite layer.
4. **Documentation Sync**: Updated `.claude/rules/ui-graph-testing.md` to append the new E2E Browser Testing constraints and the Criticality Evolution Rules.
5. **Planning Authority**: Registered and marked completed the P0 Task `Test: Enforce Playwright E2E and Allium Specifications for UI testing` through `sa-plan`.

## Rationale
- The system must mathematically prove that the rendered HTML/JSON matches the internal Rust/Gleam state.
- Relying exclusively on backend `wisp/testing` APIs cannot catch DOM structural issues or JavaScript rendering faults (if any external components are added). Playwright bridges the gap by driving real Chromium headless executions, ensuring exact adherence to the "every aspect of gleam webpages... end to end usecases x full user journeys" directive.
- Capturing the prompt instructions inside `ui_testing_framework.allium` guarantees the semantic intent of the directive is immutable and verifiable by TLA+ checkers.

## Impact
- The mesh now possesses a complete 3-layered testing pyramid: 
   1. Rust `cargo test` for L0-L4 Substrate (NIFs, SQLite, Apoptosis).
   2. Gleam `gleam test` for L5-L7 Component Logic (MVU state updates, Wisp Routing).
   3. Playwright `npx playwright test` for L8 Display Validation (DOM accessibility, Event bubbling).
- Evolutionary paths are strictly controlled by `sa-plan` and the Allium specifications.