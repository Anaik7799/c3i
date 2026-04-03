// =============================================================================
// Prajna Sentinel Page Object
// =============================================================================
// STAMP: SC-TEST-001, SC-IMMUNE-001 to SC-IMMUNE-008
// Path: /prajna/sentinel
// =============================================================================

import { Page } from 'puppeteer';
import { PrajnaBasePage } from '../BasePage';

export class SentinelPage extends PrajnaBasePage {
  private selectors = {
    container: '[data-testid="sentinel-container"], .sentinel-container',
    healthScore: '[data-testid="health-score"], .health-score',
    threatList: '[data-testid="threat-list"], .threat-list',
    threatItem: '[data-threat-id]',
    patternHunter: '[data-testid="pattern-hunter"], .pattern-hunter-status',
    quarantineList: '[data-testid="quarantine-list"], .quarantine-list',
    antibodyStatus: '[data-testid="antibody-status"], .antibody-status',
    maraStatus: '[data-testid="mara-status"], .mara-status',
    defenseMetrics: '[data-testid="defense-metrics"], .defense-metrics',
    assessNowButton: '[data-testid="assess-now"], button[phx-click="assess_now"]',
    threatFilter: '[data-testid="threat-filter"], select[name="severity"]',
    timelineView: '[data-testid="timeline"], .threat-timeline'
  };

  constructor(page: Page) {
    super(page, '/sentinel', 'Sentinel Monitor');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.healthScore) &&
      await this.hasSidebar()
    );
  }

  /**
   * Get current health score
   */
  async getHealthScore(): Promise<number> {
    const text = await this.getText(this.selectors.healthScore);
    const match = text.match(/(\d+(?:\.\d+)?)/);
    return match ? parseFloat(match[1]) : 0;
  }

  /**
   * Get active threats
   */
  async getThreats(): Promise<{ id: string; severity: string; type: string; status: string }[]> {
    const items = await this.page.$$(this.selectors.threatItem);
    const result = [];
    for (const item of items) {
      const id = await this.page.evaluate((el) => el.getAttribute('data-threat-id') || '', item);
      const severity = await this.page.evaluate((el) => el.getAttribute('data-severity') || '', item);
      const type = await this.page.evaluate((el) => el.getAttribute('data-type') || '', item);
      const status = await this.page.evaluate((el) => el.getAttribute('data-status') || '', item);
      result.push({ id, severity, type, status });
    }
    return result;
  }

  /**
   * Get threat count by severity
   */
  async getThreatCountBySeverity(): Promise<{ critical: number; high: number; medium: number; low: number }> {
    const threats = await this.getThreats();
    return {
      critical: threats.filter(t => t.severity === 'critical').length,
      high: threats.filter(t => t.severity === 'high').length,
      medium: threats.filter(t => t.severity === 'medium').length,
      low: threats.filter(t => t.severity === 'low').length
    };
  }

  /**
   * Get PatternHunter status
   */
  async getPatternHunterStatus(): Promise<{ active: boolean; patternsDetected: number }> {
    const text = await this.getText(this.selectors.patternHunter);
    const active = text.toLowerCase().includes('active');
    const match = text.match(/(\d+)\s*pattern/i);
    return {
      active,
      patternsDetected: match ? parseInt(match[1]) : 0
    };
  }

  /**
   * Get quarantined processes
   */
  async getQuarantinedProcesses(): Promise<string[]> {
    const items = await this.page.$$(this.selectors.quarantineList + ' [data-process]');
    const result = [];
    for (const item of items) {
      const text = await this.page.evaluate((el) => el.textContent || '', item);
      result.push(text);
    }
    return result;
  }

  /**
   * Get Antibody status
   */
  async getAntibodyStatus(): Promise<{ phase: string; activeCount: number }> {
    const text = await this.getText(this.selectors.antibodyStatus);
    const phaseMatch = text.match(/(search|bind|opsonize|cleanup)/i);
    const countMatch = text.match(/(\d+)\s*active/i);
    return {
      phase: phaseMatch ? phaseMatch[1].toLowerCase() : 'unknown',
      activeCount: countMatch ? parseInt(countMatch[1]) : 0
    };
  }

  /**
   * Get Mara (chaos) status
   */
  async getMaraStatus(): Promise<{ running: boolean; scenario: string }> {
    const text = await this.getText(this.selectors.maraStatus);
    const running = text.toLowerCase().includes('running') || text.toLowerCase().includes('active');
    const scenarioMatch = text.match(/scenario:\s*(.+)/i);
    return {
      running,
      scenario: scenarioMatch ? scenarioMatch[1].trim() : 'none'
    };
  }

  /**
   * Trigger immediate assessment
   */
  async assessNow(): Promise<void> {
    await this.click(this.selectors.assessNowButton);
    await this.waitForUpdate();
  }

  /**
   * Filter threats by severity
   */
  async filterThreats(severity: 'all' | 'critical' | 'high' | 'medium' | 'low'): Promise<void> {
    await this.page.select(this.selectors.threatFilter, severity);
    await this.waitForUpdate();
  }

  /**
   * Get defense metrics
   */
  async getDefenseMetrics(): Promise<{ detectionRate: number; responseTime: number; falsePositiveRate: number }> {
    const text = await this.getText(this.selectors.defenseMetrics);
    const detectionMatch = text.match(/detection[:\s]*(\d+(?:\.\d+)?)/i);
    const responseMatch = text.match(/response[:\s]*(\d+(?:\.\d+)?)/i);
    const fpMatch = text.match(/false.?positive[:\s]*(\d+(?:\.\d+)?)/i);
    return {
      detectionRate: detectionMatch ? parseFloat(detectionMatch[1]) : 0,
      responseTime: responseMatch ? parseFloat(responseMatch[1]) : 0,
      falsePositiveRate: fpMatch ? parseFloat(fpMatch[1]) : 0
    };
  }

  /**
   * Check if timeline view is available
   */
  async hasTimelineView(): Promise<boolean> {
    return await this.exists(this.selectors.timelineView);
  }
}

export default SentinelPage;
