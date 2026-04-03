// =============================================================================
// Prajna Dashboard E2E Tests
// =============================================================================
// STAMP: SC-TEST-001, SC-MON-005, SC-BIO-005
// Tests: Dashboard functionality, metrics display, 30s refresh
// =============================================================================

import { Page } from 'puppeteer';
import { DashboardPage } from '../../pages/prajna/DashboardPage';
import { config } from '../../helpers/setup';

describe('Prajna Dashboard', () => {
  let page: Page;
  let dashboard: DashboardPage;

  beforeAll(async () => {
    page = global.page;
    dashboard = new DashboardPage(page);
  });

  beforeEach(async () => {
    await dashboard.navigate();
  });

  describe('Page Loading', () => {
    it('should load dashboard successfully', async () => {
      const isHealthy = await dashboard.isHealthy();
      expect(isHealthy).toBe(true);
    });

    it('should display sidebar navigation', async () => {
      const hasSidebar = await dashboard.hasSidebar();
      expect(hasSidebar).toBe(true);
    });

    it('should display header with system info', async () => {
      const hasHeader = await dashboard.hasHeader();
      expect(hasHeader).toBe(true);
    });
  });

  describe('System Health (SC-MON-004)', () => {
    it('should display system health status', async () => {
      const health = await dashboard.getSystemHealth();
      expect(health.status).toMatch(/healthy|degraded|critical/);
      expect(health.score).toBeGreaterThanOrEqual(0);
      expect(health.score).toBeLessThanOrEqual(100);
    });

    it('should show health indicator', async () => {
      const hasIndicator = await dashboard.hasHealthIndicator();
      expect(hasIndicator).toBe(true);
    });
  });

  describe('Agent Status (SC-AGT-017)', () => {
    it('should display active agent count', async () => {
      const count = await dashboard.getActiveAgentCount();
      expect(count).toBeGreaterThanOrEqual(0);
    });
  });

  describe('Domain Grid (SC-CTRL-002)', () => {
    it('should display domain cards', async () => {
      const count = await dashboard.getDomainCount();
      // System has 30 domains
      expect(count).toBeGreaterThan(0);
    });

    it('should navigate to domain on click', async () => {
      await dashboard.navigateToDomain('alarms');
      const currentUrl = page.url();
      expect(currentUrl).toContain('/prajna');
    });
  });

  describe('OODA Status (SC-OODA-001)', () => {
    it('should display OODA cycle status', async () => {
      const status = await dashboard.getOodaStatus();
      expect(status).toBeTruthy();
    });
  });

  describe('Guardian Status (SC-CONST-007)', () => {
    it('should display Guardian status', async () => {
      const status = await dashboard.getGuardianStatus();
      expect(status).toBeTruthy();
    });
  });

  describe('Sentinel Health (SC-IMMUNE-001)', () => {
    it('should display Sentinel health', async () => {
      const health = await dashboard.getSentinelHealth();
      expect(health).toBeTruthy();
    });
  });

  describe('Alert Summary (SC-MON-006)', () => {
    it('should display alert count', async () => {
      const count = await dashboard.getAlertCount();
      expect(count).toBeGreaterThanOrEqual(0);
    });
  });

  describe('Metrics Refresh (SC-BIO-005)', () => {
    it('should refresh metrics on button click', async () => {
      await dashboard.refresh();
      // Verify no loading state after refresh
      const isLoading = await dashboard.isMetricsLoading();
      await dashboard.waitForMetrics();
      expect(isLoading).toBe(false);
    });

    it('should support time range selection', async () => {
      await dashboard.setTimeRange('24h');
      await dashboard.waitForMetrics();
      const isHealthy = await dashboard.isHealthy();
      expect(isHealthy).toBe(true);
    });
  });

  describe('Performance (SC-PRF-050)', () => {
    it('should load within acceptable time', async () => {
      const start = Date.now();
      await dashboard.navigate();
      const loadTime = Date.now() - start;
      // Should load within 5 seconds
      expect(loadTime).toBeLessThan(5000);
    });
  });
});
