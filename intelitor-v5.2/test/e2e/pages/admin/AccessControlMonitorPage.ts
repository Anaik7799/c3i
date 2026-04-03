// =============================================================================
// Access Control Monitor Page Object (Admin)
// =============================================================================
// STAMP: SC-TEST-001
// Path: /admin/access-control
// =============================================================================

import { Page } from 'puppeteer';
import { AdminBasePage } from '../BasePage';

export class AccessControlMonitorPage extends AdminBasePage {
  private selectors = {
    container: '[data-testid="access-control-monitor"], .access-control-monitor',
    policyList: '[data-testid="policies"], .policy-list',
    zoneList: '[data-testid="zones"], .zone-list',
    auditLog: '[data-testid="audit"], .audit-log',
    violationList: '[data-testid="violations"], .violation-list'
  };

  constructor(page: Page) {
    super(page, '/admin/access-control', 'Access Control Monitor');
  }

  async isHealthy(): Promise<boolean> {
    return await this.exists(this.selectors.container);
  }

  async getPolicyCount(): Promise<number> {
    const items = await this.page.$$(this.selectors.policyList + ' [data-policy-id]');
    return items.length;
  }

  async getZoneCount(): Promise<number> {
    const items = await this.page.$$(this.selectors.zoneList + ' [data-zone-id]');
    return items.length;
  }

  async getViolationCount(): Promise<number> {
    const items = await this.page.$$(this.selectors.violationList + ' [data-violation]');
    return items.length;
  }
}

export default AccessControlMonitorPage;
