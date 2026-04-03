// =============================================================================
// Prajna Dashboard Page Object
// =============================================================================
// STAMP: SC-TEST-001, SC-PRAJNA-001, SC-MON-005
// Path: /prajna
// =============================================================================

import { Page } from 'puppeteer';
import { PrajnaBasePage } from '../BasePage';

export class DashboardPage extends PrajnaBasePage {
  // Selectors
  private selectors = {
    dashboard: '[data-testid="prajna-dashboard"], .prajna-dashboard',
    systemHealth: '[data-testid="system-health"], .system-health-card',
    agentStatus: '[data-testid="agent-status"], .agent-status-panel',
    domainGrid: '[data-testid="domain-grid"], .domain-grid',
    alertSummary: '[data-testid="alert-summary"], .alert-summary',
    metricsPanel: '[data-testid="metrics-panel"], .metrics-panel',
    oodaIndicator: '[data-testid="ooda-indicator"], .ooda-cycle-status',
    guardianStatus: '[data-testid="guardian-status"], .guardian-status',
    sentinelHealth: '[data-testid="sentinel-health"], .sentinel-health',
    refreshButton: '[data-testid="refresh-btn"], button[phx-click="refresh"]',
    timeRange: '[data-testid="time-range"], select[name="time_range"]'
  };

  constructor(page: Page) {
    super(page, '', 'Prajna Dashboard');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.dashboard) &&
      await this.exists(this.selectors.systemHealth) &&
      await this.hasSidebar()
    );
  }

  /**
   * Get system health status
   */
  async getSystemHealth(): Promise<{ status: string; score: number }> {
    const statusText = await this.getText(this.selectors.systemHealth);
    const scoreMatch = statusText.match(/(\d+)%/);
    return {
      status: statusText.includes('healthy') ? 'healthy' : 'degraded',
      score: scoreMatch ? parseInt(scoreMatch[1]) : 0
    };
  }

  /**
   * Get active agent count
   */
  async getActiveAgentCount(): Promise<number> {
    const text = await this.getText(this.selectors.agentStatus);
    const match = text.match(/(\d+)\s*active/i);
    return match ? parseInt(match[1]) : 0;
  }

  /**
   * Get domain health summary
   */
  async getDomainCount(): Promise<number> {
    return await this.countElements(`${this.selectors.domainGrid} [data-domain]`);
  }

  /**
   * Get OODA cycle status
   */
  async getOodaStatus(): Promise<string> {
    return await this.getText(this.selectors.oodaIndicator);
  }

  /**
   * Get Guardian status
   */
  async getGuardianStatus(): Promise<string> {
    return await this.getText(this.selectors.guardianStatus);
  }

  /**
   * Get Sentinel health score
   */
  async getSentinelHealth(): Promise<string> {
    return await this.getText(this.selectors.sentinelHealth);
  }

  /**
   * Get alert count
   */
  async getAlertCount(): Promise<number> {
    const text = await this.getText(this.selectors.alertSummary);
    const match = text.match(/(\d+)/);
    return match ? parseInt(match[1]) : 0;
  }

  /**
   * Refresh dashboard data
   */
  async refresh(): Promise<void> {
    await this.click(this.selectors.refreshButton);
  }

  /**
   * Set time range filter
   */
  async setTimeRange(range: '1h' | '6h' | '24h' | '7d'): Promise<void> {
    await this.page.select(this.selectors.timeRange, range);
    await this.waitForUpdate();
  }

  /**
   * Navigate to specific domain
   */
  async navigateToDomain(domainName: string): Promise<void> {
    await this.click(`[data-domain="${domainName}"]`);
  }

  /**
   * Check if metrics are loading
   */
  async isMetricsLoading(): Promise<boolean> {
    return await this.exists('[phx-loading]');
  }

  /**
   * Wait for metrics to load
   */
  async waitForMetrics(): Promise<void> {
    await this.page.waitForFunction(
      () => !document.querySelector('[phx-loading]'),
      { timeout: 10000 }
    );
  }
}

export default DashboardPage;
