// =============================================================================
// Prajna Alarms Page Object
// =============================================================================
// STAMP: SC-TEST-001, SC-MON-006
// Path: /prajna/alarms
// =============================================================================

import { Page } from 'puppeteer';
import { PrajnaBasePage } from '../BasePage';

export class AlarmsPage extends PrajnaBasePage {
  private selectors = {
    container: '[data-testid="alarms-container"], .alarms-container',
    alarmList: '[data-testid="alarm-list"], .alarm-list',
    alarmItem: '[data-alarm-id]',
    stormIndicator: '[data-testid="storm-indicator"], .storm-indicator',
    correlationEngine: '[data-testid="correlation-engine"], .correlation-engine',
    workflowStatus: '[data-testid="workflow-status"], .workflow-status',
    acknowledgeButton: '[data-testid="ack-btn"], button[phx-click="acknowledge"]',
    resolveButton: '[data-testid="resolve-btn"], button[phx-click="resolve"]',
    filterSeverity: '[data-testid="filter-severity"], select[name="severity"]',
    filterStatus: '[data-testid="filter-status"], select[name="status"]',
    searchInput: '[data-testid="search"], input[name="search"]',
    totalCount: '[data-testid="total-count"], .total-count',
    activeCount: '[data-testid="active-count"], .active-count',
    slaTimer: '[data-testid="sla-timer"], .sla-timer'
  };

  constructor(page: Page) {
    super(page, '/alarms', 'Alarm Management');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.alarmList) &&
      await this.hasSidebar()
    );
  }

  /**
   * Get alarm count
   */
  async getAlarmCount(): Promise<{ total: number; active: number }> {
    const totalText = await this.getText(this.selectors.totalCount);
    const activeText = await this.getText(this.selectors.activeCount);
    const totalMatch = totalText.match(/(\d+)/);
    const activeMatch = activeText.match(/(\d+)/);
    return {
      total: totalMatch ? parseInt(totalMatch[1]) : 0,
      active: activeMatch ? parseInt(activeMatch[1]) : 0
    };
  }

  /**
   * Get list of alarms
   */
  async getAlarms(): Promise<{ id: string; severity: string; status: string; message: string }[]> {
    const items = await this.page.$$(this.selectors.alarmItem);
    const result = [];
    for (const item of items) {
      const id = await this.page.evaluate((el) => el.getAttribute('data-alarm-id') || '', item);
      const severity = await this.page.evaluate((el) => el.getAttribute('data-severity') || '', item);
      const status = await this.page.evaluate((el) => el.getAttribute('data-status') || '', item);
      const message = await this.page.evaluate((el) => el.querySelector('.message')?.textContent || '', item);
      result.push({ id, severity, status, message });
    }
    return result;
  }

  /**
   * Check if alarm storm is detected
   */
  async isStormDetected(): Promise<boolean> {
    const text = await this.getText(this.selectors.stormIndicator);
    return text.toLowerCase().includes('storm') || text.toLowerCase().includes('active');
  }

  /**
   * Get correlation engine status
   */
  async getCorrelationStatus(): Promise<{ active: boolean; correlations: number }> {
    const text = await this.getText(this.selectors.correlationEngine);
    const active = text.toLowerCase().includes('active');
    const match = text.match(/(\d+)\s*correlation/i);
    return {
      active,
      correlations: match ? parseInt(match[1]) : 0
    };
  }

  /**
   * Acknowledge an alarm
   */
  async acknowledgeAlarm(alarmId: string): Promise<void> {
    await this.click(`[data-alarm-id="${alarmId}"] ${this.selectors.acknowledgeButton}`);
    await this.waitForUpdate();
  }

  /**
   * Resolve an alarm
   */
  async resolveAlarm(alarmId: string): Promise<void> {
    await this.click(`[data-alarm-id="${alarmId}"] ${this.selectors.resolveButton}`);
    await this.waitForUpdate();
  }

  /**
   * Filter by severity
   */
  async filterBySeverity(severity: 'all' | 'critical' | 'high' | 'medium' | 'low'): Promise<void> {
    await this.page.select(this.selectors.filterSeverity, severity);
    await this.waitForUpdate();
  }

  /**
   * Filter by status
   */
  async filterByStatus(status: 'all' | 'active' | 'acknowledged' | 'resolved'): Promise<void> {
    await this.page.select(this.selectors.filterStatus, status);
    await this.waitForUpdate();
  }

  /**
   * Search alarms
   */
  async search(query: string): Promise<void> {
    await this.fill(this.selectors.searchInput, query);
  }

  /**
   * Get SLA timer status
   */
  async getSlaStatus(): Promise<{ breached: number; warning: number; ok: number }> {
    const text = await this.getText(this.selectors.slaTimer);
    const breachedMatch = text.match(/breached[:\s]*(\d+)/i);
    const warningMatch = text.match(/warning[:\s]*(\d+)/i);
    const okMatch = text.match(/ok[:\s]*(\d+)/i);
    return {
      breached: breachedMatch ? parseInt(breachedMatch[1]) : 0,
      warning: warningMatch ? parseInt(warningMatch[1]) : 0,
      ok: okMatch ? parseInt(okMatch[1]) : 0
    };
  }

  /**
   * Get workflow status
   */
  async getWorkflowStatus(): Promise<string> {
    return await this.getText(this.selectors.workflowStatus);
  }
}

export default AlarmsPage;
