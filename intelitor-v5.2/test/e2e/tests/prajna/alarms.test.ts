// =============================================================================
// Prajna Alarms E2E Tests
// =============================================================================
// STAMP: SC-TEST-001, SC-MON-006
// Tests: Alarm management, correlation, SLA tracking
// =============================================================================

import { Page } from 'puppeteer';
import { AlarmsPage } from '../../pages/prajna/AlarmsPage';

describe('Prajna Alarms', () => {
  let page: Page;
  let alarms: AlarmsPage;

  beforeAll(async () => {
    page = global.page;
    alarms = new AlarmsPage(page);
  });

  beforeEach(async () => {
    await alarms.navigate();
  });

  describe('Page Loading', () => {
    it('should load alarms page successfully', async () => {
      const isHealthy = await alarms.isHealthy();
      expect(isHealthy).toBe(true);
    });
  });

  describe('Alarm Display', () => {
    it('should display alarm counts', async () => {
      const counts = await alarms.getAlarmCount();
      expect(counts).toHaveProperty('total');
      expect(counts).toHaveProperty('active');
      expect(counts.total).toBeGreaterThanOrEqual(counts.active);
    });

    it('should list alarms with properties', async () => {
      const alarmList = await alarms.getAlarms();
      expect(alarmList).toBeDefined();
      if (alarmList.length > 0) {
        expect(alarmList[0]).toHaveProperty('id');
        expect(alarmList[0]).toHaveProperty('severity');
        expect(alarmList[0]).toHaveProperty('status');
      }
    });
  });

  describe('Storm Detection', () => {
    it('should show storm indicator status', async () => {
      const isStorm = await alarms.isStormDetected();
      expect(typeof isStorm).toBe('boolean');
    });
  });

  describe('Correlation Engine', () => {
    it('should display correlation engine status', async () => {
      const status = await alarms.getCorrelationStatus();
      expect(status).toHaveProperty('active');
      expect(status).toHaveProperty('correlations');
    });
  });

  describe('Filtering', () => {
    it('should filter by severity', async () => {
      await alarms.filterBySeverity('critical');
      const alarmList = await alarms.getAlarms();
      alarmList.forEach(a => {
        expect(a.severity).toBe('critical');
      });
    });

    it('should filter by status', async () => {
      await alarms.filterByStatus('active');
      const alarmList = await alarms.getAlarms();
      alarmList.forEach(a => {
        expect(a.status).toBe('active');
      });
    });

    it('should support search', async () => {
      await alarms.search('test');
      // Just verify search doesn't crash
      const isHealthy = await alarms.isHealthy();
      expect(isHealthy).toBe(true);
    });
  });

  describe('SLA Tracking', () => {
    it('should display SLA status', async () => {
      const sla = await alarms.getSlaStatus();
      expect(sla).toHaveProperty('breached');
      expect(sla).toHaveProperty('warning');
      expect(sla).toHaveProperty('ok');
    });
  });

  describe('Workflow', () => {
    it('should display workflow status', async () => {
      const status = await alarms.getWorkflowStatus();
      expect(status).toBeDefined();
    });
  });
});
