// =============================================================================
// Permissions Page Object (Admin)
// =============================================================================
// STAMP: SC-TEST-001
// Path: /admin/permissions
// =============================================================================

import { Page } from 'puppeteer';
import { AdminBasePage } from '../BasePage';

export class PermissionsPage extends AdminBasePage {
  private selectors = {
    container: '[data-testid="permissions"], .permissions-container',
    roleList: '[data-testid="role-list"], .role-list',
    roleItem: '[data-role-id]',
    permissionMatrix: '[data-testid="permission-matrix"], .permission-matrix',
    createRoleBtn: '[data-testid="create-role"], button[phx-click="create_role"]',
    searchInput: '[data-testid="search"], input[name="search"]'
  };

  constructor(page: Page) {
    super(page, '/admin/permissions', 'Permissions');
  }

  async isHealthy(): Promise<boolean> {
    return await this.exists(this.selectors.container);
  }

  async getRoleCount(): Promise<number> {
    const items = await this.page.$$(this.selectors.roleItem);
    return items.length;
  }

  async hasPermissionMatrix(): Promise<boolean> {
    return await this.exists(this.selectors.permissionMatrix);
  }

  async search(query: string): Promise<void> {
    await this.fill(this.selectors.searchInput, query);
  }
}

export default PermissionsPage;
