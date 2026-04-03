// =============================================================================
// Prajna Shutdown Page Object
// =============================================================================
// STAMP: SC-TEST-001, SC-EMR-057
// Path: /prajna/shutdown
// =============================================================================

import { Page } from 'puppeteer';
import { PrajnaBasePage } from '../BasePage';

export class ShutdownPage extends PrajnaBasePage {
  private selectors = {
    container: '[data-testid="shutdown-container"], .shutdown-container',
    gracefulButton: '[data-testid="graceful-btn"], button[phx-click="graceful"]',
    emergencyButton: '[data-testid="emergency-btn"], button[phx-click="emergency"]',
    confirmDialog: '[data-testid="confirm-dialog"], .confirm-dialog',
    confirmButton: '[data-testid="confirm-btn"], button[phx-click="confirm"]',
    cancelButton: '[data-testid="cancel-btn"], button[phx-click="cancel"]',
    statusPanel: '[data-testid="status"], .status-panel',
    checklistItems: '[data-testid="checklist"], .shutdown-checklist'
  };

  constructor(page: Page) {
    super(page, '/shutdown', 'System Shutdown');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.hasSidebar()
    );
  }

  /**
   * Initiate graceful shutdown
   */
  async gracefulShutdown(): Promise<void> {
    await this.click(this.selectors.gracefulButton);
    await this.waitForUpdate();
  }

  /**
   * Initiate emergency shutdown (SC-EMR-057: < 5s)
   */
  async emergencyShutdown(): Promise<void> {
    await this.click(this.selectors.emergencyButton);
    await this.waitForUpdate();
  }

  /**
   * Confirm shutdown
   */
  async confirmShutdown(): Promise<void> {
    await this.click(this.selectors.confirmButton);
    await this.waitForUpdate();
  }

  /**
   * Cancel shutdown
   */
  async cancelShutdown(): Promise<void> {
    await this.click(this.selectors.cancelButton);
    await this.waitForUpdate();
  }

  /**
   * Check if confirmation dialog is shown
   */
  async isConfirmDialogShown(): Promise<boolean> {
    return await this.exists(this.selectors.confirmDialog);
  }

  /**
   * Get shutdown checklist status
   */
  async getChecklistStatus(): Promise<{ complete: number; total: number }> {
    const items = await this.page.$$(this.selectors.checklistItems + ' [data-item]');
    let complete = 0;
    for (const item of items) {
      const status = await this.page.evaluate((el) => el.getAttribute('data-complete') === 'true', item);
      if (status) complete++;
    }
    return { complete, total: items.length };
  }
}

export default ShutdownPage;
