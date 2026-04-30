// Playwright config for /planning cross-browser sweep
// Authority: SC-PLANNING-EVO-004, SC-AGUI-UI-001..015
import { defineConfig, devices } from '@playwright/test';

const BASE_URL = process.env.PLANNING_BASE_URL || 'http://vm-1.tail55d152.ts.net:4100';

export default defineConfig({
  testDir: '.',
  timeout: 30_000,
  expect: { timeout: 5_000 },
  retries: 0,
  reporter: [['list'], ['json', { outputFile: 'cross-browser-report.json' }]],
  use: {
    baseURL: BASE_URL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox',  use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit',   use: { ...devices['Desktop Safari'] } },
    { name: 'mobile-chromium', use: { ...devices['Pixel 5'] } },
    { name: 'mobile-webkit',   use: { ...devices['iPhone 12'] } },
  ],
});
