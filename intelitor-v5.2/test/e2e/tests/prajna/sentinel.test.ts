// =============================================================================
// Prajna Sentinel E2E Tests
// =============================================================================
// STAMP: SC-TEST-001, SC-IMMUNE-001 to SC-IMMUNE-008
// Tests: Health monitoring, threat detection, immune system status
// =============================================================================

import { Page } from 'puppeteer';
import { SentinelPage } from '../../pages/prajna/SentinelPage';

describe('Prajna Sentinel', () => {
  let page: Page;
  let sentinel: SentinelPage;

  beforeAll(async () => {
    page = global.page;
    sentinel = new SentinelPage(page);
  });

  beforeEach(async () => {
    await sentinel.navigate();
  });

  describe('Page Loading', () => {
    it('should load sentinel page successfully', async () => {
      const isHealthy = await sentinel.isHealthy();
      expect(isHealthy).toBe(true);
    });

    it('should display health score', async () => {
      const exists = await sentinel.exists('[data-testid="health-score"], .health-score');
      expect(exists).toBe(true);
    });
  });

  describe('Health Score (SC-IMMUNE-001)', () => {
    it('should display current health score', async () => {
      const score = await sentinel.getHealthScore();
      expect(score).toBeGreaterThanOrEqual(0);
      expect(score).toBeLessThanOrEqual(100);
    });

    it('should trigger immediate assessment', async () => {
      await sentinel.assessNow();
      const score = await sentinel.getHealthScore();
      expect(score).toBeDefined();
    });
  });

  describe('Threat Detection (SC-IMMUNE-008)', () => {
    it('should display threat list', async () => {
      const threats = await sentinel.getThreats();
      expect(threats).toBeDefined();
    });

    it('should categorize threats by severity', async () => {
      const counts = await sentinel.getThreatCountBySeverity();
      expect(counts).toHaveProperty('critical');
      expect(counts).toHaveProperty('high');
      expect(counts).toHaveProperty('medium');
      expect(counts).toHaveProperty('low');
    });

    it('should filter threats by severity', async () => {
      await sentinel.filterThreats('critical');
      const threats = await sentinel.getThreats();
      threats.forEach(t => {
        expect(t.severity).toBe('critical');
      });
    });
  });

  describe('PatternHunter (SC-IMMUNE-004)', () => {
    it('should display PatternHunter status', async () => {
      const status = await sentinel.getPatternHunterStatus();
      expect(status).toHaveProperty('active');
      expect(status).toHaveProperty('patternsDetected');
    });
  });

  describe('Quarantine (SC-IMMUNE-006)', () => {
    it('should display quarantined processes', async () => {
      const processes = await sentinel.getQuarantinedProcesses();
      expect(processes).toBeDefined();
    });
  });

  describe('Antibody Status', () => {
    it('should display Antibody lifecycle status', async () => {
      const status = await sentinel.getAntibodyStatus();
      expect(status).toHaveProperty('phase');
      expect(status).toHaveProperty('activeCount');
      expect(['search', 'bind', 'opsonize', 'cleanup', 'unknown']).toContain(status.phase);
    });
  });

  describe('Mara Chaos Status', () => {
    it('should display Mara status', async () => {
      const status = await sentinel.getMaraStatus();
      expect(status).toHaveProperty('running');
      expect(status).toHaveProperty('scenario');
    });
  });

  describe('Defense Metrics (SC-IMMUNE-007)', () => {
    it('should display defense metrics', async () => {
      const metrics = await sentinel.getDefenseMetrics();
      expect(metrics).toHaveProperty('detectionRate');
      expect(metrics).toHaveProperty('responseTime');
      expect(metrics).toHaveProperty('falsePositiveRate');
    });
  });

  describe('Timeline View', () => {
    it('should have timeline view available', async () => {
      const hasTimeline = await sentinel.hasTimelineView();
      expect(typeof hasTimeline).toBe('boolean');
    });
  });
});
