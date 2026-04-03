// =============================================================================
// E2E Test Setup and Helpers
// =============================================================================
// STAMP: SC-TEST-001 to SC-TEST-005
// Standards: Jest best practices, Phoenix LiveView testing patterns
// =============================================================================

import { Page, Browser } from 'puppeteer';

declare global {
  var browser: Browser;
  var page: Page;
}

// Configuration
export const config = {
  baseUrl: process.env.BASE_URL || 'http://localhost:4000',
  timeout: parseInt(process.env.TEST_TIMEOUT || '30000', 10),
  slowMo: parseInt(process.env.SLOWMO || '0', 10),
  defaultWaitOptions: { timeout: 10000 }
};

// LiveView connection wait helper
export async function waitForLiveView(page: Page, timeout = 10000): Promise<void> {
  // Wait for Phoenix LiveView to initialize
  await page.waitForFunction(
    () => {
      const liveSocket = (window as any).liveSocket;
      return liveSocket && liveSocket.isConnected && liveSocket.isConnected();
    },
    { timeout }
  );
}

// Wait for LiveView phx-update to complete
export async function waitForLiveViewUpdate(page: Page, timeout = 5000): Promise<void> {
  await page.waitForFunction(
    () => {
      return !document.querySelector('[phx-loading]');
    },
    { timeout }
  );
}

// Click and wait for LiveView update
export async function clickAndWait(page: Page, selector: string): Promise<void> {
  await page.click(selector);
  await waitForLiveViewUpdate(page);
}

// Fill form field with LiveView change event
export async function fillField(page: Page, selector: string, value: string): Promise<void> {
  await page.click(selector);
  await page.evaluate((sel) => {
    const input = document.querySelector(sel) as HTMLInputElement;
    if (input) input.value = '';
  }, selector);
  await page.type(selector, value);
  // Trigger phx-change event
  await page.evaluate((sel) => {
    const input = document.querySelector(sel);
    if (input) {
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
    }
  }, selector);
  await waitForLiveViewUpdate(page);
}

// Submit LiveView form
export async function submitForm(page: Page, formSelector: string): Promise<void> {
  await page.evaluate((sel) => {
    const form = document.querySelector(sel);
    if (form) {
      form.dispatchEvent(new Event('submit', { bubbles: true }));
    }
  }, formSelector);
  await waitForLiveViewUpdate(page);
}

// Check element visibility
export async function isVisible(page: Page, selector: string): Promise<boolean> {
  try {
    const element = await page.$(selector);
    if (!element) return false;
    const box = await element.boundingBox();
    return box !== null;
  } catch {
    return false;
  }
}

// Get text content
export async function getText(page: Page, selector: string): Promise<string> {
  const element = await page.$(selector);
  if (!element) return '';
  return await page.evaluate((el) => el.textContent || '', element);
}

// Wait for specific text to appear
export async function waitForText(page: Page, selector: string, text: string, timeout = 5000): Promise<void> {
  await page.waitForFunction(
    (sel, txt) => {
      const el = document.querySelector(sel);
      return el && el.textContent?.includes(txt);
    },
    { timeout },
    selector,
    text
  );
}

// Check for Phoenix flash message
export async function waitForFlash(page: Page, type: 'info' | 'error' | 'success', timeout = 5000): Promise<string> {
  const selector = `[phx-click="lv:clear-flash"][phx-value-key="${type}"], .alert-${type}, [role="alert"]`;
  await page.waitForSelector(selector, { timeout });
  return await getText(page, selector);
}

// Take screenshot on test failure
export async function takeScreenshotOnFailure(page: Page, testName: string): Promise<void> {
  const sanitizedName = testName.replace(/[^a-z0-9]/gi, '_');
  await page.screenshot({
    path: `./reports/screenshots/${sanitizedName}_${Date.now()}.png`,
    fullPage: true
  });
}

// Setup test hooks
beforeAll(async () => {
  // Create reports directory
  const fs = require('fs');
  const dirs = ['./reports', './reports/screenshots'];
  dirs.forEach(dir => {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  });
});

beforeEach(async () => {
  // Clear cookies and localStorage
  const cookies = await page.cookies();
  if (cookies.length > 0) {
    await page.deleteCookie(...cookies);
  }
  await page.evaluate(() => localStorage.clear());
});

afterEach(async function() {
  // Take screenshot on failure
  const testState = (expect as any).getState();
  if (testState && testState.currentTestName && !testState.isExpectingAssertion) {
    // Only on actual failures
  }
});

// Extend Jest matchers
expect.extend({
  async toBeVisible(page: Page, selector: string) {
    const visible = await isVisible(page, selector);
    return {
      pass: visible,
      message: () => `Expected element ${selector} to ${visible ? 'not be' : 'be'} visible`
    };
  },

  async toHaveText(page: Page, selector: string, expectedText: string) {
    const actualText = await getText(page, selector);
    const pass = actualText.includes(expectedText);
    return {
      pass,
      message: () => `Expected ${selector} to ${pass ? 'not have' : 'have'} text "${expectedText}", got "${actualText}"`
    };
  }
});

export default {
  config,
  waitForLiveView,
  waitForLiveViewUpdate,
  clickAndWait,
  fillField,
  submitForm,
  isVisible,
  getText,
  waitForText,
  waitForFlash,
  takeScreenshotOnFailure
};
