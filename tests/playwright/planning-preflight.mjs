#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFileSync, writeFileSync } from 'node:fs';
import { chromium, devices, firefox, webkit } from 'playwright';

const here = dirname(fileURLToPath(import.meta.url));
const baseUrl = process.env.PLANNING_BASE_URL || 'http://vm-1.tail55d152.ts.net:4100';
const reportPath = resolve(here, 'preflight-report.json');
const sandboxFreeEnv = {
  ...process.env,
  MOZ_DISABLE_CONTENT_SANDBOX: '1',
  MOZ_DISABLE_RDD_SANDBOX: '1',
  MOZ_DISABLE_GMP_SANDBOX: '1',
  MOZ_DISABLE_GPU_SANDBOX: '1',
  MOZ_DISABLE_SOCKET_PROCESS_SANDBOX: '1',
  WEBKIT_FORCE_SANDBOX: '0',
  WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS: '1',
};
const chromiumArgs = [
  '--no-sandbox',
  '--disable-setuid-sandbox',
  '--disable-dev-shm-usage',
  '--disable-seccomp-filter-sandbox',
  '--disable-namespace-sandbox',
  '--disable-gpu-sandbox',
];
const firefoxPrefs = {
  'security.sandbox.content.level': 0,
  'security.sandbox.rdd.level': 0,
  'security.sandbox.gpu.level': 0,
  'media.rdd-process.enabled': false,
};
const checks = [];

function toUrl(path) {
  return new URL(path, baseUrl).toString();
}

function compact(value, max = 1400) {
  const text = String(value ?? '');
  return text.length > max ? `${text.slice(0, max)}...` : text;
}

async function check(name, fn) {
  const started = Date.now();
  try {
    const detail = await fn();
    checks.push({ name, ok: true, elapsed_ms: Date.now() - started, detail });
    console.log(`ok  ${name}`);
  } catch (error) {
    checks.push({
      name,
      ok: false,
      elapsed_ms: Date.now() - started,
      error: compact(error?.stack || error?.message || error),
    });
    console.error(`bad ${name}`);
  }
}

function run(command, args) {
  const result = spawnSync(command, args, {
    cwd: here,
    env: sandboxFreeEnv,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (result.status !== 0) {
    throw new Error([
      `${command} ${args.join(' ')} exited ${result.status}`,
      compact(result.stdout),
      compact(result.stderr),
    ].filter(Boolean).join('\n'));
  }
  return compact(result.stdout || result.stderr, 2200);
}

async function fetchJson(path) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10_000);
  try {
    const response = await fetch(toUrl(path), {
      signal: controller.signal,
      headers: { accept: 'application/json' },
    });
    const text = await response.text();
    if (!response.ok) throw new Error(`${path} HTTP ${response.status}: ${compact(text)}`);
    return JSON.parse(text);
  } finally {
    clearTimeout(timeout);
  }
}

async function browserSmoke(project) {
  const browser = await project.type.launch(project.launchOptions);
  try {
    const context = await browser.newContext(project.contextOptions);
    const page = await context.newPage();
    const response = await page.goto(toUrl('/planning?view=grid'), {
      waitUntil: 'domcontentloaded',
      timeout: 20_000,
    });
    if (!response || response.status() !== 200) {
      throw new Error(`${project.name} /planning returned ${response?.status() ?? 'no response'}`);
    }
    await page.waitForFunction(() =>
      Boolean(window.__c3iPlanning) &&
      document.querySelectorAll('[data-view]').length >= 4 &&
      document.querySelectorAll('.chip[data-status]').length >= 5,
      undefined,
      { timeout: 20_000 },
    );
    await page.locator('#grid-status').waitFor({ state: 'visible', timeout: 10_000 });
    const statusText = await page.locator('#grid-status').textContent({ timeout: 10_000 });
    await context.close();
    return { status: response.status(), grid_status: statusText };
  } finally {
    await browser.close().catch(() => undefined);
  }
}

await check('node runtime has fetch and AbortController', () => {
  if (typeof fetch !== 'function' || typeof AbortController !== 'function') {
    throw new Error('Node 18+ runtime required');
  }
  return { node: process.version };
});

await check('Playwright config is sandbox-free and low-fanout', () => {
  const config = readFileSync(resolve(here, 'playwright.config.ts'), 'utf8');
  for (const token of [
    'chromiumSandbox: false',
    'MOZ_DISABLE_CONTENT_SANDBOX',
    'WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS',
    "workers: Number(process.env.PLAYWRIGHT_WORKERS || '2')",
  ]) {
    if (!config.includes(token)) throw new Error(`missing ${token}`);
  }
  return { workers: process.env.PLAYWRIGHT_WORKERS || '2' };
});

await check('WebKit dependency closure', () => run('./setup-webkit-libs.sh', []));

await check('planning HTML shell', async () => {
  const response = await fetch(toUrl('/planning?view=grid'), { headers: { accept: 'text/html' } });
  const text = await response.text();
  if (response.status !== 200) throw new Error(`/planning HTTP ${response.status}: ${compact(text)}`);
  if (!text.includes('planning-grid.bundled.js')) throw new Error('planning bundle missing from shell');
  return { status: response.status, bytes: text.length };
});

await check('NIF-backed status API', async () => {
  const status = await fetchJson('/api/v1/plan/status');
  for (const key of ['total', 'pending', 'blocked', 'completed']) {
    if (typeof status[key] !== 'number') throw new Error(`status.${key} is not numeric`);
  }
  if (typeof (status.in_progress ?? status.active) !== 'number') {
    throw new Error('status.in_progress/status.active is not numeric');
  }
  return status;
});

await check('freshness API', async () => {
  const freshness = await fetchJson('/api/v1/health/freshness');
  if (freshness.staleness !== 'fresh') throw new Error(`staleness=${freshness.staleness}`);
  if (freshness.all_wiring_functional !== true) throw new Error('all_wiring_functional is not true');
  return freshness;
});

await check('planning page spec API', async () => {
  const spec = await fetchJson('/api/v1/page-spec/planning');
  if (spec.alignment_status !== 'ALIGNED') throw new Error(`alignment=${spec.alignment_status}`);
  if (spec.alignment_score_pct !== 100) throw new Error(`alignment_score_pct=${spec.alignment_score_pct}`);
  return { alignment_status: spec.alignment_status, alignment_score_pct: spec.alignment_score_pct };
});

if (process.env.PLANNING_PREFLIGHT_BROWSER !== '0') {
  const browserProjects = [
    {
      name: 'chromium',
      type: chromium,
      launchOptions: { chromiumSandbox: false, env: sandboxFreeEnv, args: chromiumArgs },
      contextOptions: devices['Desktop Chrome'],
    },
    {
      name: 'firefox',
      type: firefox,
      launchOptions: { env: sandboxFreeEnv, firefoxUserPrefs: firefoxPrefs },
      contextOptions: devices['Desktop Firefox'],
    },
    {
      name: 'webkit',
      type: webkit,
      launchOptions: { env: sandboxFreeEnv },
      contextOptions: devices['Desktop Safari'],
    },
    {
      name: 'mobile-chromium',
      type: chromium,
      launchOptions: { chromiumSandbox: false, env: sandboxFreeEnv, args: chromiumArgs },
      contextOptions: devices['Pixel 5'],
    },
    {
      name: 'mobile-webkit',
      type: webkit,
      launchOptions: { env: sandboxFreeEnv },
      contextOptions: devices['iPhone 12'],
    },
  ];
  for (const project of browserProjects) {
    await check(`${project.name} launch + planning runtime smoke`, () => browserSmoke(project));
  }
}

const ok = checks.every((entry) => entry.ok);
writeFileSync(reportPath, JSON.stringify({
  ok,
  base_url: baseUrl,
  generated_at: new Date().toISOString(),
  checks,
}, null, 2));

if (!ok) {
  console.error(`Preflight failed. Report: ${reportPath}`);
  process.exit(1);
}

console.log(`Preflight passed. Report: ${reportPath}`);
