// =============================================================================
// Prajna Devices Page Object
// =============================================================================
// STAMP: SC-TEST-001
// Path: /prajna/devices
// =============================================================================

import { Page } from 'puppeteer';
import { PrajnaBasePage } from '../BasePage';

export class DevicesPage extends PrajnaBasePage {
  private selectors = {
    container: '[data-testid="devices-container"], .devices-container',
    deviceList: '[data-testid="device-list"], .device-list',
    deviceItem: '[data-device-id]',
    healthMatrix: '[data-testid="health-matrix"], .health-matrix',
    uptimePanel: '[data-testid="uptime"], .uptime-panel',
    connectivityMatrix: '[data-testid="connectivity"], .connectivity-matrix',
    filterType: '[data-testid="filter-type"], select[name="type"]',
    filterStatus: '[data-testid="filter-status"], select[name="status"]',
    searchInput: '[data-testid="search"], input[name="search"]'
  };

  constructor(page: Page) {
    super(page, '/devices', 'Device Management');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.deviceList) &&
      await this.hasSidebar()
    );
  }

  /**
   * Get devices
   */
  async getDevices(): Promise<{ id: string; name: string; type: string; status: string }[]> {
    const items = await this.page.$$(this.selectors.deviceItem);
    const result = [];
    for (const item of items) {
      const id = await this.page.evaluate((el) => el.getAttribute('data-device-id') || '', item);
      const name = await this.page.evaluate((el) => el.querySelector('.name')?.textContent || '', item);
      const type = await this.page.evaluate((el) => el.getAttribute('data-type') || '', item);
      const status = await this.page.evaluate((el) => el.getAttribute('data-status') || '', item);
      result.push({ id, name, type, status });
    }
    return result;
  }

  /**
   * Get device counts by status
   */
  async getDeviceCounts(): Promise<{ online: number; offline: number; warning: number }> {
    const devices = await this.getDevices();
    return {
      online: devices.filter(d => d.status === 'online').length,
      offline: devices.filter(d => d.status === 'offline').length,
      warning: devices.filter(d => d.status === 'warning').length
    };
  }

  /**
   * Filter by type
   */
  async filterByType(type: string): Promise<void> {
    await this.page.select(this.selectors.filterType, type);
    await this.waitForUpdate();
  }

  /**
   * Filter by status
   */
  async filterByStatus(status: string): Promise<void> {
    await this.page.select(this.selectors.filterStatus, status);
    await this.waitForUpdate();
  }

  /**
   * Search devices
   */
  async search(query: string): Promise<void> {
    await this.fill(this.selectors.searchInput, query);
  }

  /**
   * Has health matrix view
   */
  async hasHealthMatrix(): Promise<boolean> {
    return await this.exists(this.selectors.healthMatrix);
  }

  /**
   * Has connectivity matrix
   */
  async hasConnectivityMatrix(): Promise<boolean> {
    return await this.exists(this.selectors.connectivityMatrix);
  }
}

export default DevicesPage;
