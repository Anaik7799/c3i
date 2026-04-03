// =============================================================================
// Prajna Commands Page Object
// =============================================================================
// STAMP: SC-TEST-001, SC-CTRL-006
// Path: /prajna/commands
// =============================================================================

import { Page } from 'puppeteer';
import { PrajnaBasePage } from '../BasePage';

export class CommandsPage extends PrajnaBasePage {
  private selectors = {
    container: '[data-testid="commands-container"], .commands-container',
    commandInput: '[data-testid="command-input"], input[name="command"]',
    executeButton: '[data-testid="execute-btn"], button[phx-click="execute"]',
    commandHistory: '[data-testid="command-history"], .command-history',
    resultPanel: '[data-testid="result-panel"], .result-panel',
    domainSelector: '[data-testid="domain-select"], select[name="domain"]',
    guardianApproval: '[data-testid="guardian-approval"], .guardian-approval',
    effectsPreview: '[data-testid="effects-preview"], .effects-preview'
  };

  constructor(page: Page) {
    super(page, '/commands', 'Command Center');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.commandInput) &&
      await this.hasSidebar()
    );
  }

  /**
   * Execute a command
   */
  async executeCommand(command: string): Promise<void> {
    await this.fill(this.selectors.commandInput, command);
    await this.click(this.selectors.executeButton);
    await this.waitForUpdate();
  }

  /**
   * Get command result
   */
  async getResult(): Promise<string> {
    return await this.getText(this.selectors.resultPanel);
  }

  /**
   * Get command history
   */
  async getHistory(): Promise<string[]> {
    const items = await this.page.$$(this.selectors.commandHistory + ' [data-command]');
    const result = [];
    for (const item of items) {
      const text = await this.page.evaluate((el) => el.textContent || '', item);
      result.push(text);
    }
    return result;
  }

  /**
   * Select target domain
   */
  async selectDomain(domain: string): Promise<void> {
    await this.page.select(this.selectors.domainSelector, domain);
    await this.waitForUpdate();
  }

  /**
   * Check if Guardian approval is required
   */
  async requiresGuardianApproval(): Promise<boolean> {
    return await this.exists(this.selectors.guardianApproval);
  }

  /**
   * Get 5-order effects preview
   */
  async getEffectsPreview(): Promise<string> {
    return await this.getText(this.selectors.effectsPreview);
  }
}

export default CommandsPage;
