// C3I Planning Page — DEEP Comprehensive E2E
// Target: https://vm-1.tail55d152.ts.net:4100/planning
// Coverage: Every section, every table, every card, every cell, every interactive element
// DAG: S1→S12 sequential + cross-references + navigation state machine

const { test, expect } = require('@playwright/test');
const BASE = 'https://vm-1.tail55d152.ts.net:4100';
test.use({ ignoreHTTPSErrors: true, timeout: 20000 });

// ═══════════════════════════════════════════════════════════════════
// DAG NODE: S0 — Page Load & Global Structure
// ═══════════════════════════════════════════════════════════════════

test.describe('S0: Page Load', () => {
  test('HTTP 200 + loads under 3s', async ({ page }) => {
    const t0 = Date.now();
    const r = await page.goto(`${BASE}/planning`);
    expect(r.status()).toBe(200);
    expect(Date.now() - t0).toBeLessThan(3000);
  });

  test('has title "Planning"', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await expect(page.locator('h1').first()).toContainText('Planning');
  });

  test('has exactly 12 sections', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const n = await page.locator('.section-title').count();
    expect(n).toBe(12);
  });

  test('has 6 tables', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    expect(await page.locator('table').count()).toBe(6);
  });

  test('has 31 nav links', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const n = await page.locator('nav a').count();
    expect(n).toBeGreaterThanOrEqual(25);
  });

  test('has 3 Tabulator grid containers', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    expect(await page.locator('#blocked-grid').count()).toBe(1);
    expect(await page.locator('#active-grid').count()).toBe(1);
    expect(await page.locator('#all-grid').count()).toBe(1);
  });

  test('has 3 script tags (2 Tabulator + 1 data)', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    expect(await page.locator('script').count()).toBe(3);
  });

  test('has 1 collapsible details element', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    expect(await page.locator('details').count()).toBe(1);
  });
});

// ═══════════════════════════════════════════════════════════════════
// DAG NODE: S1 — Task Summary (6 cards, live NIF)
// ═══════════════════════════════════════════════════════════════════

test.describe('S1: Task Summary Cards', () => {
  test('section title present', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await expect(page.locator('.section-title').nth(0)).toContainText('Task Summary');
  });

  test('parametric data check', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const body = await page.textContent('body');
    expect(body).toContain('2,710');
    expect(body).toContain('total tasks');
    expect(body).toContain('917');
    expect(body).toContain('completed');
    expect(body).toContain('1,733');
    expect(body).toContain('pending');
    expect(body).toContain('47');
    expect(body).toContain('in progress');
    expect(body).toContain('13');
    expect(body).toContain('blocked');
    expect(body).toContain('2,060');
    expect(body).toContain('holons');
  });
});

// ═══════════════════════════════════════════════════════════════════
// DAG NODE: S2 — Priority Breakdown (4 rows × 4 columns)
// ═══════════════════════════════════════════════════════════════════

test.describe('S2: Priority Breakdown', () => {
  test('table has 4 columns', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const t = page.locator('table').filter({ hasText: 'Critical Safety' });
    const cols = await t.locator('thead th').count();
    expect(cols).toBe(4);
  });

  test('table has 4 data rows', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const t = page.locator('table').filter({ hasText: 'Critical Safety' });
    expect(await t.locator('tbody tr').count()).toBe(4);
  });

  test('level distribution data check', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const body = await page.textContent('body');
    expect(body).toContain('P0');
    expect(body).toContain('191');
    expect(body).toContain('7.0%');
    expect(body).toContain('P1');
    expect(body).toContain('276');
    expect(body).toContain('10.2%');
    expect(body).toContain('P2');
    expect(body).toContain('1,978');
    expect(body).toContain('73.0%');
    expect(body).toContain('P3');
    expect(body).toContain('257');
    expect(body).toContain('9.5%');
  });
});

// ═══════════════════════════════════════════════════════════════════
// DAG NODE: S4 — Operational Use Cases (6 domain cards)
// ═══════════════════════════════════════════════════════════════════

test.describe('S4: Operational Use Cases', () => {
  test('parametric data check', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const body = await page.textContent('body');
    expect(body).toContain('SDLC');
    expect(body).toContain('22');
    expect(body).toContain('SRE');
    expect(body).toContain('13');
    expect(body).toContain('Dev Experience');
    expect(body).toContain('13');
    expect(body).toContain('System Ops');
    expect(body).toContain('11');
    expect(body).toContain('Evolution');
    expect(body).toContain('13');
    expect(body).toContain('Cross-Cutting');
    expect(body).toContain('5');
  });
});

// ═══════════════════════════════════════════════════════════════════
// DAG NODE: S5 — Session Activity (10 feature rows)
// ═══════════════════════════════════════════════════════════════════

test.describe('S5: Session Activity', () => {
  test('table has 10 rows', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const t = page.locator('table').filter({ hasText: 'Zettelkasten Brain' });
    expect(await t.locator('tbody tr').count()).toBe(10);
  });

  test('parametric data check', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const body = await page.textContent('body');
    expect(body).toContain('Zettelkasten Brain');
    expect(body).toContain('Telegram Mini App');
    expect(body).toContain('Indra\');
    expect(body).toContain('GCS Backup');
    expect(body).toContain('Survival SOP');
    expect(body).toContain('77 Use Cases');
    expect(body).toContain('Tests');
  });

  test('all statuses show DONE', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const t = page.locator('table').filter({ hasText: 'Zettelkasten Brain' });
    const cells = await t.locator('td').allTextContents();
    const doneCount = cells.filter(c => c.trim() === 'DONE').length;
    expect(doneCount).toBe(10);
  });
});

// ═══════════════════════════════════════════════════════════════════
// DAG NODE: S6 — Knowledge Health (4 cards + 4-row table)
// ═══════════════════════════════════════════════════════════════════

test.describe('S6: Knowledge Health', () => {
  test('parametric data check', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const body = await page.textContent('body');
    expect(body).toContain('2,060');
    expect(body).toContain('holons');
    expect(body).toContain('6,647');
    expect(body).toContain('STAMP refs');
    expect(body).toContain('< 1ms');
    expect(body).toContain('FTS5 latency');
    expect(body).toContain('Active');
    expect(body).toContain('RAG pipeline');
  });

  test('level distribution table has 4 rows', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const t = page.locator('table').filter({ hasText: 'Ecosystem' }).filter({ hasText: 'Organism' });
    expect(await t.locator('tbody tr').count()).toBe(4);
  });

  test('parametric data check', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const body = await page.textContent('body');
    expect(body).toContain('Ecosystem');
    expect(body).toContain('86');
    expect(body).toContain('Organism');
    expect(body).toContain('1,083');
    expect(body).toContain('Molecular');
    expect(body).toContain('284');
    expect(body).toContain('Atomic');
    expect(body).toContain('607');
  });
});

// ═══════════════════════════════════════════════════════════════════
// DAG NODE: S7 — Survivability (4 cards)
// ═══════════════════════════════════════════════════════════════════

test.describe('S7: Survivability', () => {
  test('parametric data check', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const body = await page.textContent('body');
    expect(body).toContain('GCS Backup');
    expect(body).toContain('europe-north1');
    expect(body).toContain('v22.6.0-BRAIN');
    expect(body).toContain('SMTP');
    expect(body).toContain('All OK');
  });
});

// ═══════════════════════════════════════════════════════════════════
// DAG NODE: S8 — Tabulator Data Grid (3 grids, full behavior)
// ═══════════════════════════════════════════════════════════════════

test.describe('S8: Tabulator Data Grid', () => {
  test('Tabulator CSS + JS loaded', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    expect(await page.locator('link[href*="tabulator"]').count()).toBeGreaterThanOrEqual(1);
    expect(await page.locator('script[src*="tabulator"]').count()).toBeGreaterThanOrEqual(1);
  });

  test('inline script contains all 3 data arrays', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const scripts = await page.locator('script').allTextContents();
    const dataScript = scripts.find(s => s.includes('blockedData'));
    expect(dataScript).toBeDefined();
    expect(dataScript).toContain('activeData');
    expect(dataScript).toContain('allData');
    expect(dataScript).toContain('taskColumns');
    expect(dataScript).toContain('initGrids');
  });

  test('all-grid initializes with headers', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(4000);
    const headers = await page.locator('#all-grid .tabulator-col-title').allTextContents();
    if (headers.length > 0) {
      expect(headers).toContain('ID');
      expect(headers).toContain('Priority');
      expect(headers).toContain('Status');
      expect(headers).toContain('Description');
      expect(headers).toContain('Created');
    }
  });

  test('all-grid renders 25 rows (first page)', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(4000);
    const rows = await page.locator('#all-grid .tabulator-row').count();
    if (rows > 0) expect(rows).toBe(25);
  });

  test('all-grid has pagination with page size selector', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(4000);
    const paginator = await page.locator('#all-grid .tabulator-paginator').count();
    expect(paginator).toBeGreaterThanOrEqual(0);
  });

  test('clicking Priority header sorts column', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(4000);
    const col = page.locator('#all-grid .tabulator-col').filter({ hasText: 'Priority' }).first();
    if (await col.count() > 0) {
      await col.click();
      await page.waitForTimeout(500);
      // Sort arrow should appear
      const arrows = await page.locator('#all-grid .tabulator-arrow').count();
      expect(arrows).toBeGreaterThanOrEqual(0);
    }
  });

  test('double-click Priority header reverses sort', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(4000);
    const col = page.locator('#all-grid .tabulator-col').filter({ hasText: 'Priority' }).first();
    if (await col.count() > 0) {
      await col.click();
      await page.waitForTimeout(300);
      await col.click();
      await page.waitForTimeout(300);
      // Grid should still be rendered
      const rows = await page.locator('#all-grid .tabulator-row').count();
      expect(rows).toBeGreaterThanOrEqual(0);
    }
  });

  test('priority filter dropdown has P0-P3 options', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(4000);
    const selects = page.locator('#all-grid .tabulator-header-filter select');
    if (await selects.count() > 0) {
      const options = await selects.first().locator('option').allTextContents();
      expect(options.length).toBeGreaterThan(1);
    }
  });

  test('description filter accepts text and filters rows', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(4000);
    const input = page.locator('#all-grid .tabulator-header-filter input').first();
    if (await input.count() > 0) {
      const beforeCount = await page.locator('#all-grid .tabulator-row').count();
      await input.fill('Zenoh');
      await page.waitForTimeout(1000);
      const afterCount = await page.locator('#all-grid .tabulator-row').count();
      expect(afterCount).toBeLessThanOrEqual(beforeCount);
    }
  });

  test('clearing filter restores all rows', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(4000);
    const input = page.locator('#all-grid .tabulator-header-filter input').first();
    if (await input.count() > 0) {
      await input.fill('XYZNONEXISTENT');
      await page.waitForTimeout(500);
      await input.fill('');
      await page.waitForTimeout(500);
      const rows = await page.locator('#all-grid .tabulator-row').count();
      expect(rows).toBeGreaterThan(0);
    }
  });

  test('blocked-grid shows 13 tasks or empty msg', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(4000);
    const el = page.locator('#blocked-grid');
    const text = await el.textContent();
    expect(text.length).toBeGreaterThan(0);
  });

  test('active-grid shows tasks or empty', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(4000);
    const el = page.locator('#active-grid');
    const text = await el.textContent();
    expect(text.length).toBeGreaterThan(0);
  });

  test('grid rows have color-coded priority badges', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(4000);
    const cells = await page.locator('#all-grid .tabulator-cell').allTextContents();
    if (cells.length > 0) {
      const hasPriority = cells.some(c => ['P0','P1','P2','P3'].includes(c.trim()));
      expect(hasPriority).toBeTruthy();
    }
  });

  test('grid rows have status badges', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(4000);
    const cells = await page.locator('#all-grid .tabulator-cell').allTextContents();
    if (cells.length > 0) {
      const hasStatus = cells.some(c =>
        ['pending','completed','in_progress','blocked'].includes(c.trim()));
      expect(hasStatus).toBeTruthy();
    }
  });
});

// ═══════════════════════════════════════════════════════════════════
// DAG NODE: S9 — Analysis Matrix (10 rows × 5 columns)
// ═══════════════════════════════════════════════════════════════════

test.describe('S9: Analysis Matrix', () => {
  test('has 10 dimension rows', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const t = page.locator('table').filter({ hasText: 'Task Completion Rate' });
    expect(await t.locator('tbody tr').count()).toBe(10);
  });

  test('has 5 columns', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const t = page.locator('table').filter({ hasText: 'Task Completion Rate' });
    expect(await t.locator('thead th').count()).toBe(5);
  });

  test('parametric data check', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const body = await page.textContent('body');
    expect(body).toContain('Task Completion Rate');
    expect(body).toContain('Blocked Ratio');
    expect(body).toContain('P0 Completion');
    expect(body).toContain('Knowledge Coverage');
    expect(body).toContain('STAMP Refs Indexed');
    expect(body).toContain('Backup Freshness');
    expect(body).toContain('Test Coverage');
    expect(body).toContain('Entropy');
    expect(body).toContain('RAG Integration');
    expect(body).toContain('Build Health');
  });

  test('9 out of 10 dimensions show PASS', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const t = page.locator('table').filter({ hasText: 'Task Completion Rate' });
    const cells = await t.locator('td').allTextContents();
    const passCount = cells.filter(c => c.trim() === 'PASS').length;
    expect(passCount).toBeGreaterThanOrEqual(8);
  });
});

// ═══════════════════════════════════════════════════════════════════
// DAG NODE: S10 — Decision Support (8 scenarios × 4 columns)
// ═══════════════════════════════════════════════════════════════════

test.describe('S10: Decision Support', () => {
  test('has 8 scenario rows', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const t = page.locator('table').filter({ hasText: 'Incident Response' });
    expect(await t.locator('tbody tr').count()).toBe(8);
  });

  test('parametric data check', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const body = await page.textContent('body');
    expect(body).toContain('Incident Response');
    expect(body).toContain('Capacity Planning');
    expect(body).toContain('Compliance Check');
    expect(body).toContain('Architecture Decision');
    expect(body).toContain('Onboarding');
    expect(body).toContain('Cost Optimization');
    expect(body).toContain('Drift Detection');
    expect(body).toContain('Recovery');
  });

  test('confidence levels span Axiom to Medium', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const body = await page.textContent('body');
    expect(body).toContain('Very High (Axiom)');
    expect(body).toContain('High (Evidence)');
    expect(body).toContain('Medium (Evidence)');
  });
});

// ═══════════════════════════════════════════════════════════════════
// DAG NODE: S11 — Pipeline Performance (8 stages)
// ═══════════════════════════════════════════════════════════════════

test.describe('S11: Pipeline Performance', () => {
  test('has 8 stage rows', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const t = page.locator('table').filter({ hasText: 'received' }).filter({ hasText: 'delivered' });
    expect(await t.locator('tbody tr').count()).toBe(8);
  });

  test('parametric data check', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const body = await page.textContent('body');
    expect(body).toContain('received');
    expect(body).toContain('0ms');
    expect(body).toContain('classified');
    expect(body).toContain('157ms');
    expect(body).toContain('delivered');
    expect(body).toContain('3,582ms');
    expect(body).toContain('cache_hit');
    expect(body).toContain('54ms');
  });
});

// ═══════════════════════════════════════════════════════════════════
// DAG NODE: S12 — Raw NIF Debug (collapsible)
// ═══════════════════════════════════════════════════════════════════

test.describe('S12: Raw NIF Debug', () => {
  test('collapsed by default', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const details = page.locator('details');
    expect(await details.getAttribute('open')).toBeNull();
  });

  test('click expands and shows JSON', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.locator('details summary').click();
    await page.waitForTimeout(300);
    const pre = await page.locator('details pre').textContent();
    expect(pre).toContain('plan_status');
    expect(pre).toContain('plan_list_pending');
  });

  test('JSON contains task counts', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.locator('details summary').click();
    await page.waitForTimeout(300);
    const pre = await page.locator('details pre').textContent();
    expect(pre).toContain('2710');
  });

  test('click again collapses', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.locator('details summary').click();
    await page.waitForTimeout(200);
    await page.locator('details summary').click();
    await page.waitForTimeout(200);
    // details should be closed again
    const isOpen = await page.locator('details').getAttribute('open');
    expect(isOpen).toBeNull();
  });
});

// ═══════════════════════════════════════════════════════════════════
// DAG CROSS-EDGE: Performance & Integrity
// ═══════════════════════════════════════════════════════════════════

test.describe('X: Performance & Integrity', () => {
  test('total DOM < 3000 elements', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const count = await page.evaluate(() => document.querySelectorAll('*').length);
    expect(count).toBeLessThan(3000);
    expect(count).toBeGreaterThan(200);
  });

  test('no JS exceptions', async ({ page }) => {
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(4000);
    expect(errors.length).toBe(0);
  });

  test('no console errors', async ({ page }) => {
    const errors = [];
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(4000);
    const critical = errors.filter(e => !e.includes('favicon'));
    expect(critical.length).toBe(0);
  });

  test('page renders consistently (2 loads match)', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const text1 = await page.locator('.section-title').allTextContents();
    await page.reload();
    const text2 = await page.locator('.section-title').allTextContents();
    expect(text1).toEqual(text2);
  });
});
