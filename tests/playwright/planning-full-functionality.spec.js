// Full planning page behavior coverage.
// Authority: SC-PLANNING-EVO-004, SC-AGUI-UI-001..015, SC-A2UI-001,
// SC-PAGE-SPEC-002, SC-AGUI-UI-011/012.
import { test, expect } from '@playwright/test';
import { execFileSync } from 'node:child_process';

const views = ['grid', 'kanban', 'timeline', 'analytics'];
const statuses = ['all', 'pending', 'in_progress', 'blocked', 'completed'];
const layers = ['all', 'L0', 'L1', 'L2', 'L3', 'L4', 'L5', 'L6', 'L7'];

async function waitForPlanning(page) {
  await expect(page).toHaveTitle(/C3I — Planning/);
  await page.waitForFunction(() =>
    Boolean(window.__c3iPlanning) &&
    document.querySelectorAll('[data-view]').length >= 4 &&
    document.querySelectorAll('.chip[data-status]').length >= 5 &&
    document.querySelectorAll('.fractal-chip[data-layer]').length >= 9);
  await expect(page.locator('#grid-status')).toContainText('Loaded', { timeout: 15_000 });
  await page.waitForTimeout(300);
}

async function openPlanning(page, path = '/planning?view=grid') {
  const resp = await page.goto(path, { waitUntil: 'domcontentloaded' });
  expect(resp?.status()).toBe(200);
  await waitForPlanning(page);
  const url = new URL(path, 'http://c3i.local');
  const view = url.searchParams.get('view');
  const status = url.searchParams.get('status');
  if (view) await expect(page.locator(`[data-view="${view}"]`)).toHaveAttribute('aria-pressed', 'true');
  if (status) await expect(page.locator(`.chip[data-status="${status}"]`)).toHaveClass(/chip-active/);
}

async function activeView(page) {
  return page.evaluate(() =>
    [...document.querySelectorAll('[data-view].active, [data-view].view-btn-active')]
      .map((e) => e.getAttribute('data-view')));
}

async function activeStatus(page) {
  return page.evaluate(() =>
    document.querySelector('.chip[data-status].chip-active')?.getAttribute('data-status') ?? null);
}

async function rowState(page) {
  return page.evaluate(() => {
    const rows = [...document.querySelectorAll('.c3i-task-row[data-task-id], .tabulator-row[data-task-id]')];
    const ids = rows.map((row) => row.getAttribute('data-task-id')).filter(Boolean);
    return {
      count: rows.length,
      uniqueCount: new Set(ids).size,
      ids,
      gridStatus: document.querySelector('#grid-status')?.textContent ?? '',
      hasHorizontalOverflow: document.documentElement.scrollWidth > window.innerWidth + 1,
    };
  });
}

async function chipCounts(page) {
  return page.evaluate(() => Object.fromEntries(
    [...document.querySelectorAll('.chip[data-status]')].map((chip) => {
      const key = chip.getAttribute('data-status');
      const count = Number(chip.querySelector('.chip-count')?.textContent?.trim() ?? 'NaN');
      return [key, count];
    })));
}

async function fetchJson(page, path) {
  return page.evaluate(async (p) => {
    const resp = await fetch(p, { headers: { accept: 'application/json' } });
    return { ok: resp.ok, status: resp.status, json: await resp.json() };
  }, path);
}

test.describe('/planning full functionality', () => {
  test.describe.configure({ timeout: 120_000 });

  test('deep-link matrix renders every view and status combination', async ({ page }) => {
    for (const view of views) {
      for (const status of statuses) {
        await openPlanning(page, `/planning?view=${view}&status=${status}`);
        await expect(page.locator(`#${view}-section`)).toBeVisible();
        expect(await activeView(page), `${view}/${status}`).toEqual([view]);
        expect(await activeStatus(page), `${view}/${status}`).toBe(status);
        await expect(page.locator('body')).not.toContainText('No route matched');
      }
    }
  });

  test('history navigation restores status filter and rendered rows', async ({ page }) => {
    await openPlanning(page, '/planning?view=grid&status=all');
    await page.locator('.chip[data-status="blocked"]').click();
    await expect(page.locator('.chip[data-status="blocked"]')).toHaveClass(/chip-active/);
    await expect(page.locator('#grid-status')).toContainText('blocked');
    const blockedRows = await rowState(page);

    await page.locator('.chip[data-status="completed"]').click();
    await expect(page.locator('.chip[data-status="completed"]')).toHaveClass(/chip-active/);
    await expect(page.locator('#grid-status')).toContainText('completed');

    await page.goBack();
    await expect(page.locator('.chip[data-status="blocked"]')).toHaveClass(/chip-active/);
    await expect(page.locator('#grid-status')).toContainText('blocked');
    const restoredRows = await rowState(page);
    expect(restoredRows.count).toBe(blockedRows.count);
    expect(restoredRows.ids.slice(0, 5)).toEqual(blockedRows.ids.slice(0, 5));
  });

  test('keyboard focus, aria state, and accessible controls stay coherent', async ({ page }, testInfo) => {
    await openPlanning(page, '/planning?view=grid&status=all');
    const searchInput = page.locator('#ai-search-input');
    await expect(searchInput).toBeVisible();
    if (testInfo.project.name.startsWith('mobile-')) {
      await searchInput.fill('fractal layer');
      await expect(searchInput).toHaveValue('fractal layer');
    } else {
      await page.locator('body').click({ position: { x: 10, y: 10 } });
      await page.keyboard.press(process.platform === 'darwin' ? 'Meta+K' : 'Control+K');
      await expect(searchInput).toBeFocused();
      await page.keyboard.press('Escape');
      await expect(searchInput).not.toBeFocused();
    }

    await page.locator('[data-view="analytics"]').click();
    expect(await activeView(page)).toEqual(['analytics']);
    await expect(page.locator('[data-view="analytics"]')).toHaveAttribute('aria-pressed', 'true');
    await expect(page.locator('[data-view="grid"]')).toHaveAttribute('aria-pressed', 'false');

    const badControls = await page.evaluate(() =>
      [...document.querySelectorAll('button, [role="button"], [data-view], .chip, .fractal-chip')]
        .filter((el) => {
          const box = el.getBoundingClientRect();
          return box.width > 0 && box.height > 0 && (box.height < 28 || box.width < 28);
        })
        .map((el) => el.outerHTML.slice(0, 120)));
    expect(badControls).toEqual([]);
  });

  test('status chip counts match live NIF-backed planning status', async ({ page }) => {
    await openPlanning(page);
    const status = (await fetchJson(page, '/api/v1/plan/status')).json;
    const chips = await chipCounts(page);
    expect(chips.all).toBe(status.total);
    expect(chips.pending).toBe(status.pending);
    expect(chips.in_progress).toBe(status.in_progress ?? status.active ?? 0);
    expect(chips.blocked).toBe(status.blocked);
    expect(chips.completed).toBe(status.completed);
  });

  test('fractal chips and matrix cards are equivalent for every layer', async ({ page }) => {
    await openPlanning(page);
    for (const layer of layers) {
      await page.locator(`#fractal-filter-chips [data-layer="${layer}"]`).click();
      await expect(page.locator(`#fractal-filter-chips [data-layer="${layer}"]`)).toHaveClass(/chip-active/);
      const chipRows = await rowState(page);
      if (layer !== 'all') {
        await page.locator(`#fractal-component-matrix [data-layer="${layer}"]`).click();
        await expect(page.locator(`#fractal-filter-chips [data-layer="${layer}"]`)).toHaveClass(/chip-active/);
        const matrixRows = await rowState(page);
        expect(matrixRows.count, layer).toBe(chipRows.count);
      }
      expect(chipRows.hasHorizontalOverflow, layer).toBe(false);
    }
  });

  test('detail actions work across blocked, active, and completed rows', async ({ page }) => {
    await openPlanning(page);
    for (const status of ['blocked', 'in_progress', 'completed']) {
      await page.locator(`.chip[data-status="${status}"]`).click();
      await expect(page.locator('#grid-status')).toContainText(status);
      const row = page.locator('.c3i-task-row[data-task-id], .tabulator-row[data-task-id]').first();
      await expect(row).toBeVisible();
      await row.click();
      await expect(page.locator('#task-detail-panel [data-detail-action="stamp"]')).toBeVisible();
      for (const action of ['knowledge', 'related', 'stamp', 'subtasks', 'analysis']) {
        await page.locator(`#task-detail-panel [data-detail-action="${action}"]`).click();
        await expect(page.locator('#detail-results')).not.toContainText('Evidence panel ready');
      }
    }
  });

  test('API failure handling keeps UI functional without runtime exceptions', async ({ page }) => {
    const pageErrors = [];
    page.on('pageerror', (error) => pageErrors.push(error.message));
    await page.route('**/api/v1/zk/search**', (route) =>
      route.fulfill({ status: 503, contentType: 'application/json', body: '{"error":"forced"}' }));
    await page.route('**/api/v1/planning/page?status=blocked**', (route) =>
      route.fulfill({ status: 503, contentType: 'application/json', body: '{"error":"forced"}' }));

    await openPlanning(page);
    await page.locator('#ai-search-input').fill('planning failure path');
    await page.waitForTimeout(700);
    await page.locator('.chip[data-status="blocked"]').click();
    await page.waitForTimeout(700);
    expect(pageErrors).toEqual([]);
    await expect(page.locator('#grid-section')).toBeVisible();
    await expect(page.locator('.chip[data-status="blocked"]')).toHaveClass(/chip-active/);
  });

  test('responsive screenshots render without overflow at mobile tablet desktop', async ({ page }, testInfo) => {
    for (const viewport of [
      { name: 'mobile', width: 375, height: 812 },
      { name: 'tablet', width: 768, height: 1024 },
      { name: 'desktop', width: 1400, height: 900 },
    ]) {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await openPlanning(page, '/planning?view=grid&status=all');
      const state = await rowState(page);
      expect(state.hasHorizontalOverflow, viewport.name).toBe(false);
      const image = await page.screenshot({ path: testInfo.outputPath(`planning-${viewport.name}.png`), fullPage: true });
      expect(image.byteLength, viewport.name).toBeGreaterThan(10_000);
    }
  });

  test('AG-UI and A2UI protocol endpoints expose valid planning integration contracts', async ({ page }) => {
    await openPlanning(page);
    const health = await fetchJson(page, '/ag-ui/health');
    expect(health.ok).toBe(true);
    expect(health.json.protocol).toBe('ag-ui');
    expect(health.json.status).toBe('ok');
    expect(health.json.capabilities.streaming).toBe(true);
    expect(health.json.sil_level).toBe('SIL-6');

    const state = await fetchJson(page, '/ag-ui/state');
    expect(state.ok).toBe(true);
    expect(state.json.thread_id).toBe('thread-001');
    expect(typeof state.json.version).toBe('number');

    const pending = await fetchJson(page, '/ag-ui/hitl/pending');
    expect(pending.ok).toBe(true);
    expect(Array.isArray(pending.json)).toBe(true);

    const spec = await fetchJson(page, '/api/v1/page-spec/planning');
    expect(spec.json.alignment_status).toBe('ALIGNED');
    expect(spec.json.alignment_score_pct).toBe(100);
  });

  test('repeated interactions do not create duplicate ids, failed requests, or layout drift', async ({ page }) => {
    const failed = [];
    page.on('requestfailed', (req) => {
      if (new URL(req.url()).origin === new URL(page.url()).origin) failed.push(req.url());
    });
    await openPlanning(page);
    const started = Date.now();
    for (let i = 0; i < 3; i += 1) {
      for (const view of views) await page.locator(`[data-view="${view}"]`).click();
      await page.locator('[data-view="grid"]').click();
      for (const status of statuses) await page.locator(`.chip[data-status="${status}"]`).click();
      for (const layer of ['L0', 'L3', 'L7', 'all']) await page.locator(`#fractal-filter-chips [data-layer="${layer}"]`).click();
    }
    const state = await rowState(page);
    const duplicateIds = await page.evaluate(() => {
      const ids = [...document.querySelectorAll('[id]')].map((el) => el.id);
      return ids.filter((id, idx) => ids.indexOf(id) !== idx);
    });
    expect(Date.now() - started).toBeLessThan(25_000);
    expect(state.count).toBeGreaterThan(0);
    expect(state.hasHorizontalOverflow).toBe(false);
    expect(duplicateIds).toEqual([]);
    expect(failed).toEqual([]);
  });

  test('planning WebSocket accepts a new connection after service restart (opt-in)', async ({ page }) => {
    test.skip(process.env.PLANNING_ENABLE_SERVICE_RESTART !== '1',
      'Set PLANNING_ENABLE_SERVICE_RESTART=1 to allow this test to restart c3i-gleam-server.service.');
    await openPlanning(page);
    execFileSync('systemctl', ['--user', 'restart', 'c3i-gleam-server.service'], { stdio: 'inherit' });
    await page.waitForTimeout(1500);
    await openPlanning(page);
    const frame = await page.evaluate(async () => new Promise((resolve) => {
      const url = location.protocol === 'https:'
        ? `wss://${location.host}/ws/planning`
        : `ws://${location.host}/ws/planning`;
      const ws = new WebSocket(url);
      const timeout = setTimeout(() => { try { ws.close(); } catch {} resolve(null); }, 3000);
      ws.onmessage = (event) => {
        clearTimeout(timeout);
        try { ws.close(); } catch {}
        resolve(String(event.data));
      };
      ws.onerror = () => { clearTimeout(timeout); resolve(null); };
    }));
    expect(frame).toMatch(/"type"\s*:\s*"connected"/);
  });
});
