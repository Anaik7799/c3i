// =============================================================================
// Alarm Investigation Page Object (Operations)
// =============================================================================
// STAMP: SC-TEST-001
// Path: /alarms/:id/investigate
// =============================================================================

import { Page } from 'puppeteer';
import { OperationsBasePage } from '../BasePage';

export class AlarmInvestigationPage extends OperationsBasePage {
  private selectors = {
    container: '[data-testid="investigation"], .investigation-container',
    alarmDetails: '[data-testid="alarm-details"], .alarm-details',
    timeline: '[data-testid="timeline"], .event-timeline',
    correlatedAlarms: '[data-testid="correlated"], .correlated-alarms',
    actionLog: '[data-testid="action-log"], .action-log',
    notesPanel: '[data-testid="notes"], .notes-panel',
    escalateBtn: '[data-testid="escalate-btn"], button[phx-click="escalate"]',
    closeBtn: '[data-testid="close-btn"], button[phx-click="close"]'
  };

  constructor(page: Page, alarmId: string = ':id') {
    super(page, `/alarms/${alarmId}/investigate`, 'Alarm Investigation');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.alarmDetails)
    );
  }

  async getAlarmDetails(): Promise<string> {
    return await this.getText(this.selectors.alarmDetails);
  }

  async hasTimeline(): Promise<boolean> {
    return await this.exists(this.selectors.timeline);
  }

  async getCorrelatedCount(): Promise<number> {
    const items = await this.page.$$(this.selectors.correlatedAlarms + ' [data-alarm-id]');
    return items.length;
  }

  async escalate(): Promise<void> {
    await this.click(this.selectors.escalateBtn);
    await this.waitForUpdate();
  }
}

export default AlarmInvestigationPage;
