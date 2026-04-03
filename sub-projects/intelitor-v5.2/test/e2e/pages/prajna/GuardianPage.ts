// =============================================================================
// Prajna Guardian Page Object
// =============================================================================
// STAMP: SC-TEST-001, SC-PRAJNA-001, SC-CONST-007
// Path: /prajna/guardian
// =============================================================================

import { Page } from 'puppeteer';
import { PrajnaBasePage } from '../BasePage';

export class GuardianPage extends PrajnaBasePage {
  private selectors = {
    container: '[data-testid="guardian-container"], .guardian-container',
    proposalList: '[data-testid="proposal-list"], .proposal-list',
    proposalItem: '[data-proposal-id]',
    approveButton: '[data-testid="approve-btn"], button[phx-click="approve"]',
    vetoButton: '[data-testid="veto-btn"], button[phx-click="veto"]',
    constraintViolations: '[data-testid="violations"], .constraint-violations',
    vetoHistory: '[data-testid="veto-history"], .veto-history',
    constitutionalStatus: '[data-testid="constitutional-status"], .constitutional-status',
    pendingCount: '[data-testid="pending-count"], .pending-count',
    approvalRate: '[data-testid="approval-rate"], .approval-rate',
    filterStatus: '[data-testid="filter-status"], select[name="status"]'
  };

  constructor(page: Page) {
    super(page, '/guardian', 'Guardian Control');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.proposalList) &&
      await this.hasSidebar()
    );
  }

  /**
   * Get pending proposal count
   */
  async getPendingCount(): Promise<number> {
    const text = await this.getText(this.selectors.pendingCount);
    const match = text.match(/(\d+)/);
    return match ? parseInt(match[1]) : 0;
  }

  /**
   * Get list of proposals
   */
  async getProposals(): Promise<{ id: string; type: string; status: string }[]> {
    const items = await this.page.$$(this.selectors.proposalItem);
    const result = [];
    for (const item of items) {
      const id = await this.page.evaluate((el) => el.getAttribute('data-proposal-id') || '', item);
      const type = await this.page.evaluate((el) => el.getAttribute('data-type') || '', item);
      const status = await this.page.evaluate((el) => el.getAttribute('data-status') || '', item);
      result.push({ id, type, status });
    }
    return result;
  }

  /**
   * Approve a proposal
   */
  async approveProposal(proposalId: string): Promise<void> {
    await this.click(`[data-proposal-id="${proposalId}"] ${this.selectors.approveButton}`);
    await this.waitForUpdate();
  }

  /**
   * Veto a proposal
   */
  async vetoProposal(proposalId: string, reason?: string): Promise<void> {
    await this.click(`[data-proposal-id="${proposalId}"] ${this.selectors.vetoButton}`);
    if (reason) {
      await this.fill('[data-testid="veto-reason"], textarea[name="reason"]', reason);
      await this.click('[data-testid="confirm-veto"], button[type="submit"]');
    }
    await this.waitForUpdate();
  }

  /**
   * Get constraint violations
   */
  async getViolations(): Promise<string[]> {
    const violations = await this.page.$$(this.selectors.constraintViolations + ' [data-violation]');
    const result = [];
    for (const v of violations) {
      const text = await this.page.evaluate((el) => el.textContent || '', v);
      result.push(text);
    }
    return result;
  }

  /**
   * Get veto history
   */
  async getVetoHistory(): Promise<{ proposalId: string; reason: string; timestamp: string }[]> {
    const items = await this.page.$$(this.selectors.vetoHistory + ' [data-veto]');
    const result = [];
    for (const item of items) {
      const proposalId = await this.page.evaluate((el) => el.getAttribute('data-proposal-id') || '', item);
      const reason = await this.page.evaluate((el) => el.querySelector('.reason')?.textContent || '', item);
      const timestamp = await this.page.evaluate((el) => el.querySelector('.timestamp')?.textContent || '', item);
      result.push({ proposalId, reason, timestamp });
    }
    return result;
  }

  /**
   * Get constitutional status
   */
  async getConstitutionalStatus(): Promise<{ invariant: string; status: string }[]> {
    const items = await this.page.$$(this.selectors.constitutionalStatus + ' [data-invariant]');
    const result = [];
    for (const item of items) {
      const invariant = await this.page.evaluate((el) => el.getAttribute('data-invariant') || '', item);
      const status = await this.page.evaluate((el) => el.textContent || '', item);
      result.push({ invariant, status });
    }
    return result;
  }

  /**
   * Get approval rate
   */
  async getApprovalRate(): Promise<number> {
    const text = await this.getText(this.selectors.approvalRate);
    const match = text.match(/(\d+(?:\.\d+)?)/);
    return match ? parseFloat(match[1]) : 0;
  }

  /**
   * Filter proposals by status
   */
  async filterByStatus(status: 'all' | 'pending' | 'approved' | 'vetoed'): Promise<void> {
    await this.page.select(this.selectors.filterStatus, status);
    await this.waitForUpdate();
  }

  /**
   * Check if Guardian has veto authority
   */
  async hasVetoAuthority(): Promise<boolean> {
    return await this.exists(this.selectors.vetoButton);
  }
}

export default GuardianPage;
