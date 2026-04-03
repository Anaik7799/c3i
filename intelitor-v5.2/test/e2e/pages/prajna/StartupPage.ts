// =============================================================================
// Prajna Startup Page Object
// =============================================================================
// STAMP: SC-TEST-001
// Path: /prajna/startup
// =============================================================================

import { Page } from 'puppeteer';
import { PrajnaBasePage } from '../BasePage';

export class StartupPage extends PrajnaBasePage {
  private selectors = {
    container: '[data-testid="startup-container"], .startup-container',
    sequenceList: '[data-testid="sequence-list"], .sequence-list',
    stepItem: '[data-step-id]',
    startButton: '[data-testid="start-btn"], button[phx-click="start"]',
    progressBar: '[data-testid="progress"], .progress-bar',
    statusPanel: '[data-testid="status"], .status-panel',
    prerequisiteCheck: '[data-testid="prerequisites"], .prerequisites'
  };

  constructor(page: Page) {
    super(page, '/startup', 'System Startup');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.hasSidebar()
    );
  }

  /**
   * Get startup steps
   */
  async getSteps(): Promise<{ id: string; name: string; status: string }[]> {
    const items = await this.page.$$(this.selectors.stepItem);
    const result = [];
    for (const item of items) {
      const id = await this.page.evaluate((el) => el.getAttribute('data-step-id') || '', item);
      const name = await this.page.evaluate((el) => el.querySelector('.name')?.textContent || '', item);
      const status = await this.page.evaluate((el) => el.getAttribute('data-status') || '', item);
      result.push({ id, name, status });
    }
    return result;
  }

  /**
   * Start startup sequence
   */
  async start(): Promise<void> {
    await this.click(this.selectors.startButton);
    await this.waitForUpdate();
  }

  /**
   * Get progress percentage
   */
  async getProgress(): Promise<number> {
    const text = await this.getText(this.selectors.progressBar);
    const match = text.match(/(\d+)/);
    return match ? parseInt(match[1]) : 0;
  }

  /**
   * Check prerequisites
   */
  async arePrerequisitesMet(): Promise<boolean> {
    const text = await this.getText(this.selectors.prerequisiteCheck);
    return text.toLowerCase().includes('met') || text.toLowerCase().includes('pass');
  }
}

export default StartupPage;
