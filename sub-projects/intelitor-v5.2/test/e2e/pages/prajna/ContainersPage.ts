// =============================================================================
// Prajna Containers Page Object
// =============================================================================
// STAMP: SC-TEST-001, SC-CNT-009, SC-CNT-010
// Path: /prajna/containers
// =============================================================================

import { Page } from 'puppeteer';
import { PrajnaBasePage } from '../BasePage';

export class ContainersPage extends PrajnaBasePage {
  private selectors = {
    container: '[data-testid="containers-container"], .containers-container',
    containerList: '[data-testid="container-list"], .container-list',
    containerItem: '[data-container-id]',
    statusIndicator: '[data-testid="status"], .status-indicator',
    startButton: '[data-testid="start-btn"], button[phx-click="start"]',
    stopButton: '[data-testid="stop-btn"], button[phx-click="stop"]',
    restartButton: '[data-testid="restart-btn"], button[phx-click="restart"]',
    logsButton: '[data-testid="logs-btn"], button[phx-click="logs"]',
    resourceMetrics: '[data-testid="resources"], .resource-metrics',
    healthCheck: '[data-testid="health-check"], .health-check'
  };

  constructor(page: Page) {
    super(page, '/containers', 'Container Management');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.containerList) &&
      await this.hasSidebar()
    );
  }

  /**
   * Get list of containers
   */
  async getContainers(): Promise<{ id: string; name: string; status: string; health: string }[]> {
    const items = await this.page.$$(this.selectors.containerItem);
    const result = [];
    for (const item of items) {
      const id = await this.page.evaluate((el) => el.getAttribute('data-container-id') || '', item);
      const name = await this.page.evaluate((el) => el.querySelector('.name')?.textContent || '', item);
      const status = await this.page.evaluate((el) => el.getAttribute('data-status') || '', item);
      const health = await this.page.evaluate((el) => el.getAttribute('data-health') || '', item);
      result.push({ id, name, status, health });
    }
    return result;
  }

  /**
   * Start a container
   */
  async startContainer(containerId: string): Promise<void> {
    await this.click(`[data-container-id="${containerId}"] ${this.selectors.startButton}`);
    await this.waitForUpdate();
  }

  /**
   * Stop a container
   */
  async stopContainer(containerId: string): Promise<void> {
    await this.click(`[data-container-id="${containerId}"] ${this.selectors.stopButton}`);
    await this.waitForUpdate();
  }

  /**
   * Restart a container
   */
  async restartContainer(containerId: string): Promise<void> {
    await this.click(`[data-container-id="${containerId}"] ${this.selectors.restartButton}`);
    await this.waitForUpdate();
  }

  /**
   * View container logs
   */
  async viewLogs(containerId: string): Promise<void> {
    await this.click(`[data-container-id="${containerId}"] ${this.selectors.logsButton}`);
    await this.waitForUpdate();
  }

  /**
   * Get container resource usage
   */
  async getResourceUsage(containerId: string): Promise<{ cpu: number; memory: number }> {
    const text = await this.getText(`[data-container-id="${containerId}"] ${this.selectors.resourceMetrics}`);
    const cpuMatch = text.match(/cpu[:\s]*(\d+(?:\.\d+)?)/i);
    const memMatch = text.match(/mem(?:ory)?[:\s]*(\d+(?:\.\d+)?)/i);
    return {
      cpu: cpuMatch ? parseFloat(cpuMatch[1]) : 0,
      memory: memMatch ? parseFloat(memMatch[1]) : 0
    };
  }

  /**
   * Get count by status
   */
  async getContainerCounts(): Promise<{ running: number; stopped: number; unhealthy: number }> {
    const containers = await this.getContainers();
    return {
      running: containers.filter(c => c.status === 'running').length,
      stopped: containers.filter(c => c.status === 'stopped' || c.status === 'exited').length,
      unhealthy: containers.filter(c => c.health === 'unhealthy').length
    };
  }
}

export default ContainersPage;
