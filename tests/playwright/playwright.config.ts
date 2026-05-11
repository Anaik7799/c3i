// Playwright config for /planning cross-browser sweep
// Authority: SC-PLANNING-EVO-004, SC-AGUI-UI-001..015
import { defineConfig, devices } from '@playwright/test';

const BASE_URL = process.env.PLANNING_BASE_URL || 'http://vm-1.tail55d152.ts.net:4100';
const inheritedEnv = Object.fromEntries(
  Object.entries(process.env).filter((entry): entry is [string, string] => typeof entry[1] === 'string'),
);
const sandboxFreeEnv = {
  ...inheritedEnv,
  MOZ_DISABLE_CONTENT_SANDBOX: '1',
  MOZ_DISABLE_RDD_SANDBOX: '1',
  MOZ_DISABLE_GMP_SANDBOX: '1',
  MOZ_DISABLE_GPU_SANDBOX: '1',
  MOZ_DISABLE_SOCKET_PROCESS_SANDBOX: '1',
  WEBKIT_FORCE_SANDBOX: '0',
  WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS: '1',
};
const chromiumSandboxFreeArgs = [
  '--no-sandbox',
  '--disable-setuid-sandbox',
  '--disable-dev-shm-usage',
  '--disable-seccomp-filter-sandbox',
  '--disable-namespace-sandbox',
  '--disable-gpu-sandbox',
];
const firefoxSandboxFreePrefs = {
  'security.sandbox.content.level': 0,
  'security.sandbox.rdd.level': 0,
  'security.sandbox.gpu.level': 0,
  'media.rdd-process.enabled': false,
};

export default defineConfig({
  testDir: '.',
  timeout: 45_000,
  expect: { timeout: 10_000 },
  workers: Number(process.env.PLAYWRIGHT_WORKERS || '2'),
  retries: 0,
  reporter: [['list'], ['json', { outputFile: 'cross-browser-report.json' }]],
  use: {
    baseURL: BASE_URL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        launchOptions: {
          chromiumSandbox: false,
          env: sandboxFreeEnv,
          args: chromiumSandboxFreeArgs,
        },
      },
    },
    {
      name: 'firefox',
      use: {
        ...devices['Desktop Firefox'],
        launchOptions: { env: sandboxFreeEnv, firefoxUserPrefs: firefoxSandboxFreePrefs },
      },
    },
    {
      name: 'webkit',
      use: {
        ...devices['Desktop Safari'],
        launchOptions: { env: sandboxFreeEnv },
      },
    },
    {
      name: 'mobile-chromium',
      use: {
        ...devices['Pixel 5'],
        launchOptions: {
          chromiumSandbox: false,
          env: sandboxFreeEnv,
          args: chromiumSandboxFreeArgs,
        },
      },
    },
    {
      name: 'mobile-webkit',
      use: {
        ...devices['iPhone 12'],
        launchOptions: { env: sandboxFreeEnv },
      },
    },
  ],
});
