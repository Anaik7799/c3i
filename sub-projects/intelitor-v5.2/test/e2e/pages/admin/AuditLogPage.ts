// =============================================================================
// Audit Log Page Object (Admin)
// =============================================================================
// STAMP: SC-TEST-001, SC-REG-*
// Path: /admin/audit
// =============================================================================

import { Page } from 'puppeteer';
import { AdminBasePage } from '../BasePage';

export class AuditLogPage extends AdminBasePage {
  private selectors = {
    container: '[data-testid="audit-log"], .audit-log-container',
    logList: '[data-testid="log-list"], .log-list',
    logItem: '[data-log-id]',
    filterAction: '[data-testid="filter-action"], select[name="action"]',
    filterUser: '[data-testid="filter-user"], input[name="user"]',
    dateRange: '[data-testid="date-range"], .date-range',
    exportBtn: '[data-testid="export-btn"], button[phx-click="export"]'
  };

  constructor(page: Page) {
    super(page, '/admin/audit', 'Audit Log');
  }

  async isHealthy(): Promise<boolean> {
    return await this.exists(this.selectors.container);
  }

  async getLogCount(): Promise<number> {
    const items = await this.page.$$(this.selectors.logItem);
    return items.length;
  }

  async filterByAction(action: string): Promise<void> {
    await this.page.select(this.selectors.filterAction, action);
    await this.waitForUpdate();
  }

  async filterByUser(user: string): Promise<void> {
    await this.fill(this.selectors.filterUser, user);
  }
}

export default AuditLogPage;
