# Phase 7 — UX / Operator flows (Playwright, 4 flows)

Per **SC-AGUI-UI-001..015** + **SC-VERIFY-VISUAL-001..006**.

Four operator workflows tested end-to-end via Playwright with screenshots + video evidence:

| # | Flow | Path | Success criteria |
|---|---|---|---|
| 1 | **Stale secret reload** | dashboard tile amber → click refresh → sync triggered → tile green | < 30 s wall, screenshot before/after, OTel envelope captured |
| 2 | **Anthropic key rotation** | `sa-plan vault put anthropic_api_key sk-ant-NEW` → Guardian 2oo3 dialogue → confirm → success | < 60 s wall, Guardian dialog visible, dashboard shows v=N+1 within 30 s |
| 3 | **Network outage countdown** | Simulated network drop → dashboard amber + countdown visible → MaxTTL-24h email → MaxTTL-1h alarm → reconnect → green | screenshots at each phase; countdown decrements correctly |
| 4 | **TPM PCR mismatch after kernel update** | Reboot with simulated PCR change → TPM unseal fails → passphrase prompt → operator types passphrase → vault active → run `re-seal-tpm` → next reboot unattended | screenshots of unseal prompt, success page, re-seal confirmation |

## Reference: see diagrams/dot/11-ux-operator-flows.dot for swimlane

## Implementation

```typescript
// tests/playwright/vault.spec.ts
test('flow A: stale secret reload', async ({ page }) => {
  await page.goto('https://localhost:8443/secrets-vault');
  // Force stale state via test endpoint
  await fetch('/test/vault/force-stale/openrouter_api_key');
  await page.reload();
  // Verify amber tile
  await expect(page.locator('[data-secret="openrouter_api_key"][data-state="soft-stale"]')).toBeVisible();
  await page.screenshot({ path: 'docs/journal/task-116494073339521648/screenshots/flow-a-amber.png' });
  // Click refresh
  await page.click('button[data-action="refresh-secret"][data-name="openrouter_api_key"]');
  // Wait for green
  await expect(page.locator('[data-secret="openrouter_api_key"][data-state="fresh"]')).toBeVisible({ timeout: 30000 });
  await page.screenshot({ path: 'docs/journal/task-116494073339521648/screenshots/flow-a-green.png' });
});
```

## Triple-platform parity

Per **SC-PATROL-MCP-005** + **SC-VERIFY-VISUAL-003**: each flow runs on:
- Chromium (desktop 1400×900)
- Firefox (desktop 1400×900)
- mobile-Chromium (375×812)

12 total runs (4 flows × 3 platforms).

## Closure

- ✅ 4 flows × 3 platforms = 12 passing runs
- ✅ Screenshots embedded in `docs/journal/task-116494073339521648/screenshots/`
- ✅ Videos for flows 2, 3, 4 (recorded to `docs/journal/task-116494073339521648/videos/`)
- ✅ All flows complete < operator-acceptable latency (30s for routine, 60s for rotation)
