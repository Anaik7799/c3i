// =============================================================================
// Prajna Mesh Page Object
// =============================================================================
// STAMP: SC-TEST-001, SC-BRIDGE-*
// Path: /prajna/mesh
// =============================================================================

import { Page } from 'puppeteer';
import { PrajnaBasePage } from '../BasePage';

export class MeshPage extends PrajnaBasePage {
  private selectors = {
    container: '[data-testid="mesh-container"], .mesh-container',
    agentList: '[data-testid="agent-list"], .agent-list',
    agentItem: '[data-agent-id]',
    zenohStatus: '[data-testid="zenoh-status"], .zenoh-status',
    publisherList: '[data-testid="publishers"], .publisher-list',
    subscriberList: '[data-testid="subscribers"], .subscriber-list',
    messageRate: '[data-testid="message-rate"], .message-rate',
    latencyMetrics: '[data-testid="latency"], .latency-metrics'
  };

  constructor(page: Page) {
    super(page, '/mesh', 'Agent Mesh');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.agentList) &&
      await this.hasSidebar()
    );
  }

  /**
   * Get mesh agents
   */
  async getAgents(): Promise<{ id: string; type: string; status: string }[]> {
    const items = await this.page.$$(this.selectors.agentItem);
    const result = [];
    for (const item of items) {
      const id = await this.page.evaluate((el) => el.getAttribute('data-agent-id') || '', item);
      const type = await this.page.evaluate((el) => el.getAttribute('data-type') || '', item);
      const status = await this.page.evaluate((el) => el.getAttribute('data-status') || '', item);
      result.push({ id, type, status });
    }
    return result;
  }

  /**
   * Get Zenoh connection status
   */
  async getZenohStatus(): Promise<{ connected: boolean; session: string }> {
    const text = await this.getText(this.selectors.zenohStatus);
    return {
      connected: text.toLowerCase().includes('connected'),
      session: text.match(/session[:\s]*(\w+)/i)?.[1] || ''
    };
  }

  /**
   * Get message rate
   */
  async getMessageRate(): Promise<number> {
    const text = await this.getText(this.selectors.messageRate);
    const match = text.match(/(\d+(?:\.\d+)?)/);
    return match ? parseFloat(match[1]) : 0;
  }

  /**
   * Get latency metrics
   */
  async getLatency(): Promise<{ p50: number; p99: number }> {
    const text = await this.getText(this.selectors.latencyMetrics);
    const p50Match = text.match(/p50[:\s]*(\d+(?:\.\d+)?)/i);
    const p99Match = text.match(/p99[:\s]*(\d+(?:\.\d+)?)/i);
    return {
      p50: p50Match ? parseFloat(p50Match[1]) : 0,
      p99: p99Match ? parseFloat(p99Match[1]) : 0
    };
  }
}

export default MeshPage;
