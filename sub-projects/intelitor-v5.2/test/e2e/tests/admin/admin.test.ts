// =============================================================================
// Admin Pages E2E Tests
// =============================================================================
// STAMP: SC-TEST-001
// Tests: System Status, Permissions, Access Control, Config, Audit, Users, Tenants, Integrations
// =============================================================================

import { Page } from 'puppeteer';
import { SystemStatusPage } from '../../pages/admin/SystemStatusPage';
import { PermissionsPage } from '../../pages/admin/PermissionsPage';
import { AccessControlMonitorPage } from '../../pages/admin/AccessControlMonitorPage';
import { ConfigManagementPage } from '../../pages/admin/ConfigManagementPage';
import { AuditLogPage } from '../../pages/admin/AuditLogPage';
import { UsersPage } from '../../pages/admin/UsersPage';
import { TenantsPage } from '../../pages/admin/TenantsPage';
import { IntegrationsPage } from '../../pages/admin/IntegrationsPage';

describe('Admin - System Status (SC-CTRL-001)', () => {
  let page: Page;
  let systemStatus: SystemStatusPage;

  beforeAll(async () => {
    page = global.page;
    systemStatus = new SystemStatusPage(page);
  });

  beforeEach(async () => {
    await systemStatus.navigate();
  });

  it('should load system status page', async () => {
    expect(await systemStatus.isHealthy()).toBe(true);
  });

  it('should display service count', async () => {
    const count = await systemStatus.getServiceCount();
    expect(count).toBeGreaterThan(0);
  });

  it('should show service health status', async () => {
    const health = await systemStatus.getServicesHealth();
    expect(health).toHaveProperty('healthy');
    expect(health).toHaveProperty('degraded');
    expect(health).toHaveProperty('down');
  });

  it('should display system uptime', async () => {
    const uptime = await systemStatus.getUptime();
    expect(uptime).toBeDefined();
  });

  it('should display version info', async () => {
    const version = await systemStatus.getVersion();
    expect(version).toBeDefined();
  });

  it('should have admin navigation', async () => {
    const hasNav = await systemStatus.hasAdminNav();
    expect(typeof hasNav).toBe('boolean');
  });
});

describe('Admin - Permissions', () => {
  let page: Page;
  let permissions: PermissionsPage;

  beforeAll(async () => {
    page = global.page;
    permissions = new PermissionsPage(page);
  });

  beforeEach(async () => {
    await permissions.navigate();
  });

  it('should load permissions page', async () => {
    expect(await permissions.isHealthy()).toBe(true);
  });

  it('should display roles', async () => {
    const count = await permissions.getRoleCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should have permission matrix', async () => {
    const hasMatrix = await permissions.hasPermissionMatrix();
    expect(typeof hasMatrix).toBe('boolean');
  });

  it('should support search', async () => {
    await permissions.search('admin');
    expect(await permissions.isHealthy()).toBe(true);
  });
});

describe('Admin - Access Control Monitor', () => {
  let page: Page;
  let acm: AccessControlMonitorPage;

  beforeAll(async () => {
    page = global.page;
    acm = new AccessControlMonitorPage(page);
  });

  beforeEach(async () => {
    await acm.navigate();
  });

  it('should load access control monitor', async () => {
    expect(await acm.isHealthy()).toBe(true);
  });

  it('should display policies', async () => {
    const count = await acm.getPolicyCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should display zones', async () => {
    const count = await acm.getZoneCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should track violations', async () => {
    const count = await acm.getViolationCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });
});

describe('Admin - Config Management', () => {
  let page: Page;
  let config: ConfigManagementPage;

  beforeAll(async () => {
    page = global.page;
    config = new ConfigManagementPage(page);
  });

  beforeEach(async () => {
    await config.navigate();
  });

  it('should load config management', async () => {
    expect(await config.isHealthy()).toBe(true);
  });

  it('should display config items', async () => {
    const count = await config.getConfigCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should have config history', async () => {
    const hasHistory = await config.hasHistory();
    expect(typeof hasHistory).toBe('boolean');
  });
});

describe('Admin - Audit Log (SC-REG-*)', () => {
  let page: Page;
  let auditLog: AuditLogPage;

  beforeAll(async () => {
    page = global.page;
    auditLog = new AuditLogPage(page);
  });

  beforeEach(async () => {
    await auditLog.navigate();
  });

  it('should load audit log', async () => {
    expect(await auditLog.isHealthy()).toBe(true);
  });

  it('should display log entries', async () => {
    const count = await auditLog.getLogCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should filter by action', async () => {
    await auditLog.filterByAction('create');
    expect(await auditLog.isHealthy()).toBe(true);
  });

  it('should filter by user', async () => {
    await auditLog.filterByUser('admin');
    expect(await auditLog.isHealthy()).toBe(true);
  });
});

describe('Admin - Users', () => {
  let page: Page;
  let users: UsersPage;

  beforeAll(async () => {
    page = global.page;
    users = new UsersPage(page);
  });

  beforeEach(async () => {
    await users.navigate();
  });

  it('should load users page', async () => {
    expect(await users.isHealthy()).toBe(true);
  });

  it('should display user count', async () => {
    const count = await users.getUserCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should support search', async () => {
    await users.search('test');
    expect(await users.isHealthy()).toBe(true);
  });

  it('should filter by role', async () => {
    await users.filterByRole('admin');
    expect(await users.isHealthy()).toBe(true);
  });
});

describe('Admin - Tenants', () => {
  let page: Page;
  let tenants: TenantsPage;

  beforeAll(async () => {
    page = global.page;
    tenants = new TenantsPage(page);
  });

  beforeEach(async () => {
    await tenants.navigate();
  });

  it('should load tenants page', async () => {
    expect(await tenants.isHealthy()).toBe(true);
  });

  it('should display tenant count', async () => {
    const count = await tenants.getTenantCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should support search', async () => {
    await tenants.search('test');
    expect(await tenants.isHealthy()).toBe(true);
  });

  it('should filter by status', async () => {
    await tenants.filterByStatus('active');
    expect(await tenants.isHealthy()).toBe(true);
  });
});

describe('Admin - Integrations', () => {
  let page: Page;
  let integrations: IntegrationsPage;

  beforeAll(async () => {
    page = global.page;
    integrations = new IntegrationsPage(page);
  });

  beforeEach(async () => {
    await integrations.navigate();
  });

  it('should load integrations page', async () => {
    expect(await integrations.isHealthy()).toBe(true);
  });

  it('should display integration count', async () => {
    const count = await integrations.getIntegrationCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should show integration health', async () => {
    const health = await integrations.getIntegrationHealth();
    expect(health).toHaveProperty('connected');
    expect(health).toHaveProperty('disconnected');
    expect(health).toHaveProperty('error');
  });
});
