// =============================================================================
// System Status Page Object (Admin)
// =============================================================================
// STAMP: SC-TEST-001, SC-CTRL-001
// Path: /admin/system
// =============================================================================

import { Page } from 'puppeteer';
import { AdminBasePage } from '../BasePage';

export class SystemStatusPage extends AdminBasePage {
  private selectors = {
    container: '[data-testid="system-status"], .system-status',
    healthOverview: '[data-testid="health-overview"], .health-overview',
    serviceList: '[data-testid="service-list"], .service-list',
    serviceItem: '[data-service-id]',
    metricsPanel: '[data-testid="metrics"], .metrics-panel',
    uptimeDisplay: '[data-testid="uptime"], .uptime-display',
    versionInfo: '[data-testid="version"], .version-info'
  };

  constructor(page: Page) {
    super(page, '/admin/system', 'System Status');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.healthOverview)
    );
  }

  async getServiceCount(): Promise<number> {
    const items = await this.page.$$(this.selectors.serviceItem);
    return items.length;
  }

  async getServicesHealth(): Promise<{ healthy: number; degraded: number; down: number }> {
    const items = await this.page.$$(this.selectors.serviceItem);
    let healthy = 0, degraded = 0, down = 0;
    for (const item of items) {
      const status = await this.page.evaluate((el) => el.getAttribute('data-status') || '', item);
      if (status === 'healthy') healthy++;
      else if (status === 'degraded') degraded++;
      else down++;
    }
    return { healthy, degraded, down };
  }

  async getUptime(): Promise<string> {
    return await this.getText(this.selectors.uptimeDisplay);
  }

  async getVersion(): Promise<string> {
    return await this.getText(this.selectors.versionInfo);
  }
}

export default SystemStatusPage;
