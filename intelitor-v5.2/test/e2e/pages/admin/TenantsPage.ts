// =============================================================================
// Tenants Page Object (Admin)
// =============================================================================
// STAMP: SC-TEST-001
// Path: /admin/tenants
// =============================================================================

import { Page } from 'puppeteer';
import { AdminBasePage } from '../BasePage';

export class TenantsPage extends AdminBasePage {
  private selectors = {
    container: '[data-testid="tenants"], .tenants-container',
    tenantList: '[data-testid="tenant-list"], .tenant-list',
    tenantItem: '[data-tenant-id]',
    createBtn: '[data-testid="create-btn"], button[phx-click="create"]',
    searchInput: '[data-testid="search"], input[name="search"]',
    statusFilter: '[data-testid="filter-status"], select[name="status"]'
  };

  constructor(page: Page) {
    super(page, '/admin/tenants', 'Tenants');
  }

  async isHealthy(): Promise<boolean> {
    return await this.exists(this.selectors.container);
  }

  async getTenantCount(): Promise<number> {
    const items = await this.page.$$(this.selectors.tenantItem);
    return items.length;
  }

  async search(query: string): Promise<void> {
    await this.fill(this.selectors.searchInput, query);
  }

  async filterByStatus(status: string): Promise<void> {
    await this.page.select(this.selectors.statusFilter, status);
    await this.waitForUpdate();
  }
}

export default TenantsPage;
