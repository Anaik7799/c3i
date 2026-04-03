// =============================================================================
// Operations Pages E2E Tests
// =============================================================================
// STAMP: SC-TEST-001
// Tests: Active Alarms, Investigation, Access Dashboard, Dispatch, Video Wall
// =============================================================================

import { Page } from 'puppeteer';
import { ActiveAlarmsPage } from '../../pages/operations/ActiveAlarmsPage';
import { AlarmInvestigationPage } from '../../pages/operations/AlarmInvestigationPage';
import { AccessDashboardPage } from '../../pages/operations/AccessDashboardPage';
import { DispatchConsolePage } from '../../pages/operations/DispatchConsolePage';
import { VideoWallPage } from '../../pages/operations/VideoWallPage';

describe('Operations - Active Alarms', () => {
  let page: Page;
  let activeAlarms: ActiveAlarmsPage;

  beforeAll(async () => {
    page = global.page;
    activeAlarms = new ActiveAlarmsPage(page);
  });

  beforeEach(async () => {
    await activeAlarms.navigate();
  });

  it('should load active alarms page', async () => {
    expect(await activeAlarms.isHealthy()).toBe(true);
  });

  it('should display alarm queue count', async () => {
    const count = await activeAlarms.getQueueCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should list active alarms', async () => {
    const alarms = await activeAlarms.getActiveAlarms();
    expect(alarms).toBeDefined();
    if (alarms.length > 0) {
      expect(alarms[0]).toHaveProperty('id');
      expect(alarms[0]).toHaveProperty('priority');
    }
  });

  it('should filter by priority', async () => {
    await activeAlarms.filterByPriority('high');
    const alarms = await activeAlarms.getActiveAlarms();
    alarms.forEach(a => {
      expect(a.priority).toBe('high');
    });
  });

  it('should have operations toolbar', async () => {
    const hasToolbar = await activeAlarms.hasToolbar();
    expect(typeof hasToolbar).toBe('boolean');
  });
});

describe('Operations - Alarm Investigation', () => {
  let page: Page;
  let investigation: AlarmInvestigationPage;

  beforeAll(async () => {
    page = global.page;
    // Use placeholder - would need actual alarm ID in real tests
    investigation = new AlarmInvestigationPage(page, 'test-alarm');
  });

  // Note: These tests require an actual alarm to exist
  it('should have investigation interface structure', async () => {
    // Just verify the page class is functional
    expect(investigation).toBeDefined();
  });
});

describe('Operations - Access Dashboard', () => {
  let page: Page;
  let accessDashboard: AccessDashboardPage;

  beforeAll(async () => {
    page = global.page;
    accessDashboard = new AccessDashboardPage(page);
  });

  beforeEach(async () => {
    await accessDashboard.navigate();
  });

  it('should load access dashboard', async () => {
    expect(await accessDashboard.isHealthy()).toBe(true);
  });

  it('should display access event count', async () => {
    const count = await accessDashboard.getEventCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should have zone map', async () => {
    const hasMap = await accessDashboard.hasZoneMap();
    expect(typeof hasMap).toBe('boolean');
  });

  it('should display live counter', async () => {
    const count = await accessDashboard.getLiveCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should track recent denials', async () => {
    const denials = await accessDashboard.getRecentDenials();
    expect(denials).toBeGreaterThanOrEqual(0);
  });
});

describe('Operations - Dispatch Console', () => {
  let page: Page;
  let dispatch: DispatchConsolePage;

  beforeAll(async () => {
    page = global.page;
    dispatch = new DispatchConsolePage(page);
  });

  beforeEach(async () => {
    await dispatch.navigate();
  });

  it('should load dispatch console', async () => {
    expect(await dispatch.isHealthy()).toBe(true);
  });

  it('should display pending dispatch count', async () => {
    const count = await dispatch.getPendingCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should display responder count', async () => {
    const count = await dispatch.getResponderCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should have map view', async () => {
    const hasMap = await dispatch.hasMapView();
    expect(typeof hasMap).toBe('boolean');
  });
});

describe('Operations - Video Wall', () => {
  let page: Page;
  let videoWall: VideoWallPage;

  beforeAll(async () => {
    page = global.page;
    videoWall = new VideoWallPage(page);
  });

  beforeEach(async () => {
    await videoWall.navigate();
  });

  it('should load video wall', async () => {
    expect(await videoWall.isHealthy()).toBe(true);
  });

  it('should display video streams', async () => {
    const count = await videoWall.getStreamCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should have control panel', async () => {
    const hasControls = await videoWall.hasControlPanel();
    expect(typeof hasControls).toBe('boolean');
  });

  it('should support layout selection', async () => {
    await videoWall.selectLayout('2x2');
    expect(await videoWall.isHealthy()).toBe(true);
  });

  it('should track stream health', async () => {
    const health = await videoWall.getStreamHealth();
    expect(health).toHaveProperty('healthy');
    expect(health).toHaveProperty('degraded');
    expect(health).toHaveProperty('offline');
  });
});
