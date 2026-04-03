// =============================================================================
// Users Page Object (Admin)
// =============================================================================
// STAMP: SC-TEST-001
// Path: /admin/users
// =============================================================================

import { Page } from 'puppeteer';
import { AdminBasePage } from '../BasePage';

export class UsersPage extends AdminBasePage {
  private selectors = {
    container: '[data-testid="users"], .users-container',
    userList: '[data-testid="user-list"], .user-list',
    userItem: '[data-user-id]',
    createBtn: '[data-testid="create-btn"], button[phx-click="create"]',
    searchInput: '[data-testid="search"], input[name="search"]',
    filterRole: '[data-testid="filter-role"], select[name="role"]'
  };

  constructor(page: Page) {
    super(page, '/admin/users', 'Users');
  }

  async isHealthy(): Promise<boolean> {
    return await this.exists(this.selectors.container);
  }

  async getUserCount(): Promise<number> {
    const items = await this.page.$$(this.selectors.userItem);
    return items.length;
  }

  async search(query: string): Promise<void> {
    await this.fill(this.selectors.searchInput, query);
  }

  async filterByRole(role: string): Promise<void> {
    await this.page.select(this.selectors.filterRole, role);
    await this.waitForUpdate();
  }
}

export default UsersPage;
