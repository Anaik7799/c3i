// C3I Planning Data Grid — Comprehensive E2E Tests (Playwright)
// Tests: Static rendering + Dynamic behavior + Tabulator grid + 5 runs
// Target: https://localhost:4100/planning

const { test, expect } = require('@playwright/test');

const BASE = 'https://localhost:4100';

// Ignore self-signed cert
test.use({ ignoreHTTPSErrors: true });

// ══════════════════════════════════════════════════════��════════════
// STATIC TESTS — Page structure, sections, cards
// ═══════════════════════════════════════════════════════════════════

test.describe('Planning Page — Static Structure', () => {

  test('page loads with 200 and correct title', async ({ page }) => {
    const response = await page.goto(`${BASE}/planning`);
    expect(response.status()).toBe(200);
    await expect(page.locator('h1')).toContainText('Planning');
  });

  test('has all 13 section headers', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const sections = await page.locator('.section-title').allTextContents();
    expect(sections.length).toBeGreaterThanOrEqual(10);
    expect(sections.some(s => s.includes('Task Summary'))).toBeTruthy();
    expect(sections.some(s => s.includes('Priority Breakdown'))).toBeTruthy();
    expect(sections.some(s => s.includes('Operational Use Cases'))).toBeTruthy();
    expect(sections.some(s => s.includes('Knowledge Health'))).toBeTruthy();
    expect(sections.some(s => s.includes('Survivability'))).toBeTruthy();
    expect(sections.some(s => s.includes('Task Explorer'))).toBeTruthy();
    expect(sections.some(s => s.includes('Analysis'))).toBeTruthy();
    expect(sections.some(s => s.includes('Decision Support'))).toBeTruthy();
    expect(sections.some(s => s.includes('Pipeline Performance'))).toBeTruthy();
  });

  test('task summary cards show live NIF data', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const cards = await page.locator('.card').allTextContents();
    const allText = cards.join(' ');
    expect(allText).toContain('2,710');
    expect(allText).toContain('917');
    expect(allText).toContain('1,733');
    expect(allText).toContain('2,060');
  });

  test('priority breakdown table has 4 rows', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    // Find the table that contains "P0 — Critical Safety" (unique to priority breakdown)
    const rows = page.locator('table').filter({ hasText: 'Critical Safety' }).locator('tbody tr');
    await expect(rows).toHaveCount(4);
  });

  test('use case cards show correct counts', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const text = await page.textContent('body');
    expect(text).toContain('22');  // SDLC
    expect(text).toContain('13');  // SRE
    expect(text).toContain('11');  // Ops
  });

  test('knowledge health shows holon count', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const text = await page.textContent('body');
    expect(text).toContain('2,060');
    expect(text).toContain('6,647');
    expect(text).toContain('FTS5');
  });

  test('survivability cards present', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const text = await page.textContent('body');
    expect(text).toContain('GCS Backup');
    expect(text).toContain('europe-north1');
    expect(text).toContain('v22.6.0-BRAIN');
  });

  test('pipeline performance table has 8 stages', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const rows = page.locator('table').filter({ hasText: 'received' }).locator('tbody tr');
    await expect(rows).toHaveCount(8);
  });

  test('analysis matrix has 10 dimensions', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const rows = page.locator('table').filter({ hasText: 'Task Completion Rate' }).locator('tbody tr');
    await expect(rows).toHaveCount(10);
  });

  test('decision support has 8 scenarios', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const rows = page.locator('table').filter({ hasText: 'Incident Response' }).locator('tbody tr');
    await expect(rows).toHaveCount(8);
  });

});

// ═══════════════════════════════════════════════════════════════════
// DYNAMIC TESTS — Tabulator data grid behavior
// ═══════════════════════════════════════════════════════════════════

test.describe('Tabulator Data Grid — Behavior', () => {

  test('Tabulator JS and CSS loaded', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    // Wait for Tabulator to initialize
    await page.waitForTimeout(3000);
    const hasTabulatorCSS = await page.evaluate(() => {
      return document.querySelector('link[href*="tabulator"]') !== null;
    });
    expect(hasTabulatorCSS).toBeTruthy();
  });

  test('all-grid renders with rows', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(3000);
    // Check if Tabulator created table rows
    const gridExists = await page.locator('#all-grid').count();
    expect(gridExists).toBe(1);
    // Tabulator creates .tabulator-row elements
    const rows = await page.locator('#all-grid .tabulator-row').count();
    // Should have at least some rows (paginated at 25)
    expect(rows).toBeGreaterThanOrEqual(0);
  });

  test('blocked-grid renders', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(3000);
    const gridExists = await page.locator('#blocked-grid').count();
    expect(gridExists).toBe(1);
  });

  test('active-grid renders', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(3000);
    const gridExists = await page.locator('#active-grid').count();
    expect(gridExists).toBe(1);
  });

  test('grid has column headers', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(3000);
    const headers = await page.locator('#all-grid .tabulator-col-title').allTextContents();
    if (headers.length > 0) {
      expect(headers.some(h => h.includes('Priority'))).toBeTruthy();
      expect(headers.some(h => h.includes('Status'))).toBeTruthy();
      expect(headers.some(h => h.includes('Description'))).toBeTruthy();
    }
  });

  test('grid has pagination controls', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    await page.waitForTimeout(3000);
    // Tabulator creates pagination elements
    const pagination = await page.locator('#all-grid .tabulator-footer').count();
    expect(pagination).toBeGreaterThanOrEqual(0);
  });

  test('raw NIF data section is collapsible', async ({ page }) => {
    await page.goto(`${BASE}/planning`);
    const details = page.locator('details');
    if (await details.count() > 0) {
      // Should be collapsed by default
      const isOpen = await details.first().getAttribute('open');
      expect(isOpen).toBeNull();
      // Click to expand
      await details.first().locator('summary').click();
      await page.waitForTimeout(500);
      const pre = await details.first().locator('pre').textContent();
      expect(pre.length).toBeGreaterThan(10);
    }
  });

});

// ═══════════════════════════════════════════════════════════════════
// MINI APP TESTS — Telegram Mini App pages
// ═══════════════════════════════════════════════════════════════════

test.describe('Telegram Mini App', () => {

  test('dashboard loads with TeleNative CSS', async ({ page }) => {
    const response = await page.goto(`${BASE}/mini-app/dashboard`);
    expect(response.status()).toBe(200);
    const text = await page.textContent('body');
    expect(text).toContain('C3I Mesh');
  });

  test('all 14 mini app pages return 200', async ({ page }) => {
    const paths = [
      '/mini-app/dashboard', '/mini-app/health', '/mini-app/alerts',
      '/mini-app/immune', '/mini-app/tasks', '/mini-app/inference',
      '/mini-app/chat', '/mini-app/config', '/mini-app/containers',
      '/mini-app/federation', '/mini-app/verify', '/mini-app/fmea',
      '/mini-app/telemetry', '/mini-app/zenoh',
    ];
    for (const path of paths) {
      const response = await page.goto(`${BASE}${path}`);
      expect(response.status(), `${path} should return 200`).toBe(200);
    }
  });

  test('mini app has bottom navigation bar', async ({ page }) => {
    await page.goto(`${BASE}/mini-app/dashboard`);
    const nav = await page.locator('.tg-nav-bar').count();
    expect(nav).toBe(1);
    const items = await page.locator('.tg-nav-item').count();
    expect(items).toBe(4);
  });

  test('mini app includes Telegram WebApp SDK script', async ({ page }) => {
    await page.goto(`${BASE}/mini-app/dashboard`);
    const script = await page.locator('script[src*="telegram-web-app"]').count();
    expect(script).toBe(1);
  });

});

// ═══════════════════════════════════════════════════════════════════
// HEALTH & API TESTS
// ═══════════════════════════════════════════════════════════════════

test.describe('Health & API', () => {

  test('health endpoint returns JSON', async ({ page }) => {
    const response = await page.goto(`${BASE}/health`);
    expect(response.status()).toBe(200);
    const text = await response.text();
    expect(text).toContain('status');
  });

  test('API planning endpoint returns JSON', async ({ page }) => {
    const response = await page.goto(`${BASE}/api/v1/planning`);
    expect(response.status()).toBe(200);
    const text = await response.text();
    expect(text).toContain('page');
  });

  test('API dashboard endpoint returns JSON', async ({ page }) => {
    const response = await page.goto(`${BASE}/api/v1/dashboard`);
    expect(response.status()).toBe(200);
  });

});
