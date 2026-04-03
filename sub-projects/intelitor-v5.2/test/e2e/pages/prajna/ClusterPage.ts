// =============================================================================
// Prajna Cluster Page Object
// =============================================================================
// STAMP: SC-TEST-001, SC-CLU-*
// Path: /prajna/cluster
// =============================================================================

import { Page } from 'puppeteer';
import { PrajnaBasePage } from '../BasePage';

export class ClusterPage extends PrajnaBasePage {
  private selectors = {
    container: '[data-testid="cluster-container"], .cluster-container',
    nodeList: '[data-testid="node-list"], .node-list',
    nodeItem: '[data-node-id]',
    topologyView: '[data-testid="topology"], .topology-view',
    quorumStatus: '[data-testid="quorum"], .quorum-status',
    splitBrainIndicator: '[data-testid="split-brain"], .split-brain-indicator',
    membershipPanel: '[data-testid="membership"], .membership-panel'
  };

  constructor(page: Page) {
    super(page, '/cluster', 'Cluster Management');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.nodeList) &&
      await this.hasSidebar()
    );
  }

  /**
   * Get cluster nodes
   */
  async getNodes(): Promise<{ id: string; name: string; status: string; role: string }[]> {
    const items = await this.page.$$(this.selectors.nodeItem);
    const result = [];
    for (const item of items) {
      const id = await this.page.evaluate((el) => el.getAttribute('data-node-id') || '', item);
      const name = await this.page.evaluate((el) => el.querySelector('.name')?.textContent || '', item);
      const status = await this.page.evaluate((el) => el.getAttribute('data-status') || '', item);
      const role = await this.page.evaluate((el) => el.getAttribute('data-role') || '', item);
      result.push({ id, name, status, role });
    }
    return result;
  }

  /**
   * Get quorum status
   */
  async getQuorumStatus(): Promise<{ hasQuorum: boolean; nodes: number; required: number }> {
    const text = await this.getText(this.selectors.quorumStatus);
    const hasQuorum = text.toLowerCase().includes('achieved') || text.toLowerCase().includes('ok');
    const nodesMatch = text.match(/(\d+)\s*\/\s*(\d+)/);
    return {
      hasQuorum,
      nodes: nodesMatch ? parseInt(nodesMatch[1]) : 0,
      required: nodesMatch ? parseInt(nodesMatch[2]) : 0
    };
  }

  /**
   * Check for split-brain
   */
  async hasSplitBrain(): Promise<boolean> {
    const text = await this.getText(this.selectors.splitBrainIndicator);
    return text.toLowerCase().includes('detected') || text.toLowerCase().includes('warning');
  }

  /**
   * Has topology view
   */
  async hasTopologyView(): Promise<boolean> {
    return await this.exists(this.selectors.topologyView);
  }
}

export default ClusterPage;
