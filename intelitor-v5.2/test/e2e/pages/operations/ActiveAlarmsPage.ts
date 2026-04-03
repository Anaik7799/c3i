// =============================================================================
// Active Alarms Page Object (Operations)
// =============================================================================
// STAMP: SC-TEST-001, SC-MON-006
// Path: /alarms/active
// =============================================================================

import { Page } from 'puppeteer';
import { OperationsBasePage } from '../BasePage';

export class ActiveAlarmsPage extends OperationsBasePage {
  private selectors = {
    container: '[data-testid="active-alarms"], .active-alarms-container',
    alarmQueue: '[data-testid="alarm-queue"], .alarm-queue',
    alarmItem: '[data-alarm-id]',
    priorityFilter: '[data-testid="priority-filter"], select[name="priority"]',
    acknowledgeBtn: '[data-testid="ack-btn"], button[phx-click="acknowledge"]',
    resolveBtn: '[data-testid="resolve-btn"], button[phx-click="resolve"]',
    slaTimer: '[data-testid="sla-timer"], .sla-timer',
    queueCount: '[data-testid="queue-count"], .queue-count'
  };

  constructor(page: Page) {
    super(page, '/alarms/active', 'Active Alarms');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.alarmQueue)
    );
  }

  async getQueueCount(): Promise<number> {
    const text = await this.getText(this.selectors.queueCount);
    const match = text.match(/(\d+)/);
    return match ? parseInt(match[1]) : 0;
  }

  async getActiveAlarms(): Promise<{ id: string; priority: string; status: string }[]> {
    const items = await this.page.$$(this.selectors.alarmItem);
    const result = [];
    for (const item of items) {
      const id = await this.page.evaluate((el) => el.getAttribute('data-alarm-id') || '', item);
      const priority = await this.page.evaluate((el) => el.getAttribute('data-priority') || '', item);
      const status = await this.page.evaluate((el) => el.getAttribute('data-status') || '', item);
      result.push({ id, priority, status });
    }
    return result;
  }

  async filterByPriority(priority: string): Promise<void> {
    await this.page.select(this.selectors.priorityFilter, priority);
    await this.waitForUpdate();
  }

  async acknowledgeAlarm(alarmId: string): Promise<void> {
    await this.click(`[data-alarm-id="${alarmId}"] ${this.selectors.acknowledgeBtn}`);
    await this.waitForUpdate();
  }

  async resolveAlarm(alarmId: string): Promise<void> {
    await this.click(`[data-alarm-id="${alarmId}"] ${this.selectors.resolveBtn}`);
    await this.waitForUpdate();
  }
}

export default ActiveAlarmsPage;
