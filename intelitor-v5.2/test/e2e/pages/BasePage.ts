// =============================================================================
// Base Page Object for Indrajaal LiveView Pages
// =============================================================================
// STAMP: SC-TEST-001, SC-HMI-001
// Standards: Page Object Pattern, Phoenix LiveView testing
// =============================================================================

import { Page } from 'puppeteer';
import { config, waitForLiveView, waitForLiveViewUpdate, clickAndWait, fillField } from '../helpers/setup';

/**
 * Base Page Object providing common functionality for all LiveView pages.
 * All page objects should extend this class.
 */
export abstract class BasePage {
  protected page: Page;
  protected path: string;
  protected expectedTitle: string;

  constructor(page: Page, path: string, expectedTitle: string = '') {
    this.page = page;
    this.path = path;
    this.expectedTitle = expectedTitle;
  }

  /**
   * Navigate to the page and wait for LiveView connection
   */
  async navigate(): Promise<void> {
    const url = `${config.baseUrl}${this.path}`;
    await this.page.goto(url, { waitUntil: 'networkidle2' });
    await waitForLiveView(this.page);
  }

  /**
   * Get the full URL for this page
   */
  getUrl(): string {
    return `${config.baseUrl}${this.path}`;
  }

  /**
   * Check if currently on this page
   */
  async isOnPage(): Promise<boolean> {
    const currentUrl = this.page.url();
    return currentUrl.includes(this.path);
  }

  /**
   * Wait for page-specific element to be visible
   */
  async waitForPageLoad(selector: string, timeout = 10000): Promise<void> {
    await this.page.waitForSelector(selector, { visible: true, timeout });
  }

  /**
   * Click an element and wait for LiveView update
   */
  async click(selector: string): Promise<void> {
    await clickAndWait(this.page, selector);
  }

  /**
   * Fill a form field
   */
  async fill(selector: string, value: string): Promise<void> {
    await fillField(this.page, selector, value);
  }

  /**
   * Get text content of an element
   */
  async getText(selector: string): Promise<string> {
    const element = await this.page.$(selector);
    if (!element) return '';
    return await this.page.evaluate((el) => el.textContent || '', element);
  }

  /**
   * Check if element exists
   */
  async exists(selector: string): Promise<boolean> {
    const element = await this.page.$(selector);
    return element !== null;
  }

  /**
   * Check if element is visible
   */
  async isVisible(selector: string): Promise<boolean> {
    const element = await this.page.$(selector);
    if (!element) return false;
    const box = await element.boundingBox();
    return box !== null;
  }

  /**
   * Wait for LiveView update to complete
   */
  async waitForUpdate(): Promise<void> {
    await waitForLiveViewUpdate(this.page);
  }

  /**
   * Get all elements matching selector
   */
  async getElements(selector: string): Promise<any[]> {
    return await this.page.$$(selector);
  }

  /**
   * Count elements matching selector
   */
  async countElements(selector: string): Promise<number> {
    const elements = await this.page.$$(selector);
    return elements.length;
  }

  /**
   * Take screenshot for debugging
   */
  async screenshot(name: string): Promise<void> {
    await this.page.screenshot({
      path: `./reports/screenshots/${name}_${Date.now()}.png`,
      fullPage: true
    });
  }

  /**
   * Abstract method for page-specific health check
   */
  abstract isHealthy(): Promise<boolean>;
}

/**
 * Base class for Prajna cockpit pages with common navigation
 */
export abstract class PrajnaBasePage extends BasePage {
  constructor(page: Page, subPath: string, expectedTitle: string = '') {
    super(page, `/prajna${subPath}`, expectedTitle);
  }

  /**
   * Check sidebar navigation is present
   */
  async hasSidebar(): Promise<boolean> {
    return await this.exists('[data-testid="prajna-sidebar"], .prajna-sidebar, nav.sidebar');
  }

  /**
   * Navigate using sidebar link
   */
  async navigateTo(linkText: string): Promise<void> {
    await this.click(`a:has-text("${linkText}"), [data-nav="${linkText.toLowerCase()}"]`);
  }

  /**
   * Check header is present
   */
  async hasHeader(): Promise<boolean> {
    return await this.exists('[data-testid="prajna-header"], .prajna-header, header');
  }

  /**
   * Get current user display
   */
  async getCurrentUser(): Promise<string> {
    return await this.getText('[data-testid="current-user"], .user-display');
  }

  /**
   * Check if system health indicator is present
   */
  async hasHealthIndicator(): Promise<boolean> {
    return await this.exists('[data-testid="system-health"], .health-indicator');
  }
}

/**
 * Base class for operations pages
 */
export abstract class OperationsBasePage extends BasePage {
  constructor(page: Page, subPath: string, expectedTitle: string = '') {
    super(page, subPath, expectedTitle);
  }

  /**
   * Check operations toolbar is present
   */
  async hasToolbar(): Promise<boolean> {
    return await this.exists('[data-testid="ops-toolbar"], .operations-toolbar');
  }
}

/**
 * Base class for admin pages
 */
export abstract class AdminBasePage extends BasePage {
  constructor(page: Page, subPath: string, expectedTitle: string = '') {
    super(page, subPath, expectedTitle);
  }

  /**
   * Check admin navigation is present
   */
  async hasAdminNav(): Promise<boolean> {
    return await this.exists('[data-testid="admin-nav"], .admin-navigation');
  }
}

export default BasePage;
