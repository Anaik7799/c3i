// =============================================================================
// Integrations Page Object (Admin)
// =============================================================================
// STAMP: SC-TEST-001
// Path: /admin/integrations
// =============================================================================

import { Page } from 'puppeteer';
import { AdminBasePage } from '../BasePage';

export class IntegrationsPage extends AdminBasePage {
  private selectors = {
    container: '[data-testid="integrations"], .integrations-container',
    integrationList: '[data-testid="integration-list"], .integration-list',
    integrationItem: '[data-integration-id]',
    addBtn: '[data-testid="add-btn"], button[phx-click="add"]',
    testBtn: '[data-testid="test-btn"], button[phx-click="test"]',
    healthPanel: '[data-testid="health"], .integration-health'
  };

  constructor(page: Page) {
    super(page, '/admin/integrations', 'Integrations');
  }

  async isHealthy(): Promise<boolean> {
    return await this.exists(this.selectors.container);
  }

  async getIntegrationCount(): Promise<number> {
    const items = await this.page.$$(this.selectors.integrationItem);
    return items.length;
  }

  async getIntegrationHealth(): Promise<{ connected: number; disconnected: number; error: number }> {
    const items = await this.page.$$(this.selectors.integrationItem);
    let connected = 0, disconnected = 0, error = 0;
    for (const item of items) {
      const status = await this.page.evaluate((el) => el.getAttribute('data-status') || '', item);
      if (status === 'connected') connected++;
      else if (status === 'disconnected') disconnected++;
      else error++;
    }
    return { connected, disconnected, error };
  }

  async testIntegration(integrationId: string): Promise<void> {
    await this.click(`[data-integration-id="${integrationId}"] ${this.selectors.testBtn}`);
    await this.waitForUpdate();
  }
}

export default IntegrationsPage;
