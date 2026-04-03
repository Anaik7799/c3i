// =============================================================================
// Config Management Page Object (Admin)
// =============================================================================
// STAMP: SC-TEST-001
// Path: /admin/config
// =============================================================================

import { Page } from 'puppeteer';
import { AdminBasePage } from '../BasePage';

export class ConfigManagementPage extends AdminBasePage {
  private selectors = {
    container: '[data-testid="config-management"], .config-management',
    configList: '[data-testid="config-list"], .config-list',
    configItem: '[data-config-key]',
    saveBtn: '[data-testid="save-btn"], button[phx-click="save"]',
    revertBtn: '[data-testid="revert-btn"], button[phx-click="revert"]',
    historyPanel: '[data-testid="history"], .config-history'
  };

  constructor(page: Page) {
    super(page, '/admin/config', 'Config Management');
  }

  async isHealthy(): Promise<boolean> {
    return await this.exists(this.selectors.container);
  }

  async getConfigCount(): Promise<number> {
    const items = await this.page.$$(this.selectors.configItem);
    return items.length;
  }

  async hasHistory(): Promise<boolean> {
    return await this.exists(this.selectors.historyPanel);
  }
}

export default ConfigManagementPage;
