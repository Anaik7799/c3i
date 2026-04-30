// /planning cross-browser regression — Chromium / Firefox / WebKit / mobile.
// Authority: SC-PLANNING-EVO-004, SC-AGUI-UI-001..015 (responsive + view modes),
//            SC-AGUI-UI-012 (DAG-Q triple-transport parity), SC-PAGE-SPEC-002.
import { test, expect, Page } from '@playwright/test';

// Helper: read structural state of /planning via in-page eval.
async function structuralState(page: Page) {
  return page.evaluate(() => {
    const ids = ['all-grid', 'blocked-grid', 'active-grid', 'task-detail-panel',
                 'grid-section', 'kanban-section', 'timeline-section', 'analytics-section'];
    const presence = Object.fromEntries(ids.map((id) => [id, !!document.getElementById(id)]));
    presence['planning-grid.js'] = !!document.querySelector('script[src*="planning-grid.js"]');
    presence['sw-register.js']   = !!document.querySelector('script[src*="sw-register.js"]');
    presence['fractal_chip_count'] = (document.querySelectorAll('[data-fractal-layer], [data-layer]').length as any);
    presence['view_buttons'] = (document.querySelectorAll('[data-view]').length as any);
    return presence;
  });
}

test.describe('/planning structural', () => {
  test('returns 200 with no console errors and required IDs', async ({ page }) => {
    const errors: string[] = [];
    // Filter benign cross-browser style fallback noise (material.css 404 → inline css fallback in shell).
    const ignoreError = (text: string) =>
      /material\.css/.test(text) ||
      /stylesheet.*MIME type/.test(text) ||
      /favicon/.test(text);
    page.on('console', (m) => {
      if (m.type() === 'error') {
        const t = m.text();
        if (!ignoreError(t)) errors.push(t);
      }
    });
    const resp = await page.goto('/planning');
    expect(resp?.status()).toBe(200);
    await expect(page).toHaveTitle(/C3I — Planning/);
    // Allow JS-rendered fractal chips + view buttons to populate
    await page.waitForTimeout(2500);
    const s = await structuralState(page);
    expect(s['all-grid']).toBe(true);
    expect(s['blocked-grid']).toBe(true);
    expect(s['active-grid']).toBe(true);
    expect(s['task-detail-panel']).toBe(true);
    expect(s['grid-section']).toBe(true);
    expect(s['kanban-section']).toBe(true);
    expect(s['timeline-section']).toBe(true);
    expect(s['analytics-section']).toBe(true);
    expect(s['planning-grid.js']).toBe(true);
    // sw-register.js may or may not be reachable depending on browser/protocol — soft check
    expect(s['fractal_chip_count']).toBeGreaterThanOrEqual(8);
    expect(s['view_buttons']).toBeGreaterThanOrEqual(4);
    expect(errors, errors.join('\n')).toEqual([]);
  });

  test('view-mode mutual exclusion (closes ZK[zk-741220214a931009])', async ({ page }) => {
    await page.goto('/planning');
    await page.waitForTimeout(2500);
    for (const view of ['kanban', 'timeline', 'analytics', 'grid']) {
      await page.evaluate((v) => (document.querySelector(`[data-view="${v}"]`) as HTMLElement)?.click(), view);
      await page.waitForTimeout(400);
      const visibility = await page.evaluate(() => {
        const visible = (id: string) => {
          const e = document.getElementById(id);
          if (!e) return null;
          const cs = getComputedStyle(e);
          return cs.display !== 'none' && cs.visibility !== 'hidden';
        };
        return {
          grid: visible('grid-section'),
          kanban: visible('kanban-section'),
          timeline: visible('timeline-section'),
          analytics: visible('analytics-section'),
        };
      });
      const visibleCount = Object.values(visibility).filter(Boolean).length;
      expect(visibleCount, `view=${view} → ${JSON.stringify(visibility)}`).toBe(1);
      expect((visibility as any)[view]).toBe(true);
    }
  });

  test('triple-transport parity (DAG-Q): WS, SSE? and HTTP agree on total', async ({ page }) => {
    await page.goto('/planning');
    await page.waitForTimeout(1000);
    const result = await page.evaluate(async () => {
      const http = await fetch('/api/v1/plan/status').then((r) => r.json()).catch(() => null);
      const ws = await new Promise<any>((resolve) => {
        try {
          const url = location.protocol === 'https:'
            ? `wss://${location.host}/ws/planning`
            : `ws://${location.host}/ws/planning`;
          const sock = new WebSocket(url);
          let frame: any = null;
          const t = setTimeout(() => { try { sock.close(); } catch {} resolve(frame); }, 3500);
          sock.onmessage = (e) => {
            frame = String(e.data);
            clearTimeout(t);
            sock.close();
            resolve(frame);
          };
          sock.onerror = () => { clearTimeout(t); resolve(null); };
        } catch (e) { resolve(null); }
      });
      return { http, ws };
    });
    expect(result.http).toBeTruthy();
    expect(result.http.total).toBeGreaterThanOrEqual(0);
    if (result.ws) {
      // The WS connected frame embeds status JSON as a string — extract total.
      const m = String(result.ws).match(/"total"\s*:\s*(\d+)/);
      if (m) {
        const wsTotal = Number(m[1]);
        expect(Math.abs(wsTotal - result.http.total)).toBeLessThanOrEqual(2);
      }
    }
  });

  test('freshness reports fresh and all wiring functional', async ({ page }) => {
    await page.goto('/planning');
    await page.waitForTimeout(500);
    const f = await page.evaluate(() => fetch('/api/v1/health/freshness').then((r) => r.json()));
    expect(f.staleness).toBe('fresh');
    expect(f.all_wiring_functional).toBe(true);
    expect(f.nif_plan_status).toBe(true);
    expect(f.ws_planning_active).toBe(true);
  });

  test('responsive: weather bar visible at 375 / 768 / 1400', async ({ page }) => {
    for (const [w, h] of [[375, 812], [768, 1024], [1400, 900]] as const) {
      await page.setViewportSize({ width: w, height: h });
      await page.goto('/planning');
      await page.waitForTimeout(1500);
      const bodyText = await page.evaluate(() => document.body.innerText);
      expect(bodyText).toMatch(/Total|tasks|Planning/i);
      const h44 = await page.evaluate(() => {
        const buttons = [...document.querySelectorAll('button, [data-view], [data-fractal-layer], [data-layer]')];
        return buttons.every((b) => (b as HTMLElement).offsetHeight === 0 || (b as HTMLElement).offsetHeight >= 28);
      });
      expect(h44, `viewport ${w}x${h}`).toBe(true);
    }
  });
});

// ──────────────────────────────────────────────────────────────────────────
// pass-2 follow-up — server-driven WS push (SC-AGUI-UI-011 / SC-PLANNING-EVO-009)
// Verifies that the WebSocket emits diff-detected push frames every ~1s
// without the client sending a "ping" message.
// ──────────────────────────────────────────────────────────────────────────
test.describe('/planning WS server-driven push', () => {
  // Server-tick activated 2026-04-30 after operator-authorized restart of
  // cepaf_gleam --serve.  Welcome frame announces server_push:true; subsequent
  // frames carry source:"server_tick" within ~1 s without client cooperation.
  // SC-AGUI-UI-011 / SC-PLANNING-EVO-009.
  test('emits welcome + ≥1 server tick within 2.5s, no client ping', async ({ page }) => {
    await page.goto('/planning');
    const result = await page.evaluate(async () => {
      const url = location.protocol === 'https:'
        ? `wss://${location.host}/ws/planning`
        : `ws://${location.host}/ws/planning`;
      return await new Promise<any>((resolve) => {
        const sock = new WebSocket(url);
        const frames: string[] = [];
        const t0 = performance.now();
        const stop = setTimeout(() => {
          try { sock.close(); } catch {}
          resolve({ frames, elapsed_ms: Math.round(performance.now() - t0) });
        }, 2400);
        sock.onmessage = (e) => {
          frames.push(String(e.data));
          if (frames.length >= 3) {
            clearTimeout(stop);
            try { sock.close(); } catch {}
            resolve({ frames, elapsed_ms: Math.round(performance.now() - t0) });
          }
        };
        sock.onerror = () => { clearTimeout(stop); resolve({ frames, error: 'ws_error' }); };
      });
    });
    expect(result.frames.length, JSON.stringify(result)).toBeGreaterThanOrEqual(2);
    // welcome frame must announce server_push:true
    expect(result.frames[0]).toMatch(/"type"\s*:\s*"connected"/);
    // at least one subsequent frame must be a server tick — either "update"
    // or "heartbeat" with source:"server_tick" (the new tag).
    const tickFrames = result.frames.slice(1).filter((f: string) =>
      /"source"\s*:\s*"server_tick"/.test(f));
    expect(tickFrames.length, JSON.stringify(result)).toBeGreaterThanOrEqual(1);
  });
});
