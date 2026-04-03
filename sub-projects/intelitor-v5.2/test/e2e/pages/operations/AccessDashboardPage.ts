// =============================================================================
// Access Dashboard Page Object (Operations)
// =============================================================================
// STAMP: SC-TEST-001
// Path: /access/dashboard
// =============================================================================

import { Page } from 'puppeteer';
import { OperationsBasePage } from '../BasePage';

export class AccessDashboardPage extends OperationsBasePage {
  private selectors = {
    container: '[data-testid="access-dashboard"], .access-dashboard',
    accessEvents: '[data-testid="access-events"], .access-events',
    eventItem: '[data-event-id]',
    zoneMap: '[data-testid="zone-map"], .zone-map',
    recentGrantsPanel: '[data-testid="recent-grants"], .recent-grants',
    denyList: '[data-testid="deny-list"], .deny-list',
    liveCounter: '[data-testid="live-counter"], .live-counter'
  };

  constructor(page: Page) {
    super(page, '/access/dashboard', 'Access Dashboard');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.accessEvents)
    );
  }

  async getEventCount(): Promise<number> {
    const items = await this.page.$$(this.selectors.eventItem);
    return items.length;
  }

  async hasZoneMap(): Promise<boolean> {
    return await this.exists(this.selectors.zoneMap);
  }

  async getLiveCount(): Promise<number> {
    const text = await this.getText(this.selectors.liveCounter);
    const match = text.match(/(\d+)/);
    return match ? parseInt(match[1]) : 0;
  }

  async getRecentDenials(): Promise<number> {
    const items = await this.page.$$(this.selectors.denyList + ' [data-denial]');
    return items.length;
  }
}

export default AccessDashboardPage;
