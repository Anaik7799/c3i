// =============================================================================
// Prajna Register Page Object (Immutable Register)
// =============================================================================
// STAMP: SC-TEST-001, SC-REG-001 to SC-REG-015
// Path: /prajna/register
// =============================================================================

import { Page } from 'puppeteer';
import { PrajnaBasePage } from '../BasePage';

export class RegisterPage extends PrajnaBasePage {
  private selectors = {
    container: '[data-testid="register-container"], .register-container',
    blockList: '[data-testid="block-list"], .block-list',
    blockItem: '[data-block-id]',
    chainIntegrity: '[data-testid="chain-integrity"], .chain-integrity',
    latestBlock: '[data-testid="latest-block"], .latest-block',
    verifyButton: '[data-testid="verify-btn"], button[phx-click="verify"]',
    blockDetail: '[data-testid="block-detail"], .block-detail',
    signatureStatus: '[data-testid="signature"], .signature-status',
    hashChain: '[data-testid="hash-chain"], .hash-chain'
  };

  constructor(page: Page) {
    super(page, '/register', 'Immutable Register');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.blockList) &&
      await this.hasSidebar()
    );
  }

  /**
   * Get chain integrity status
   */
  async getChainIntegrity(): Promise<{ valid: boolean; blocks: number }> {
    const text = await this.getText(this.selectors.chainIntegrity);
    const valid = text.toLowerCase().includes('valid') || text.toLowerCase().includes('intact');
    const match = text.match(/(\d+)\s*block/i);
    return {
      valid,
      blocks: match ? parseInt(match[1]) : 0
    };
  }

  /**
   * Get latest block info
   */
  async getLatestBlock(): Promise<{ id: string; hash: string; timestamp: string }> {
    const text = await this.getText(this.selectors.latestBlock);
    return {
      id: text.match(/id[:\s]*(\w+)/i)?.[1] || '',
      hash: text.match(/hash[:\s]*(\w+)/i)?.[1] || '',
      timestamp: text.match(/time[:\s]*([^\n]+)/i)?.[1]?.trim() || ''
    };
  }

  /**
   * Verify chain integrity
   */
  async verifyChain(): Promise<void> {
    await this.click(this.selectors.verifyButton);
    await this.waitForUpdate();
  }

  /**
   * Get blocks
   */
  async getBlocks(): Promise<{ id: string; type: string; hash: string }[]> {
    const items = await this.page.$$(this.selectors.blockItem);
    const result = [];
    for (const item of items) {
      const id = await this.page.evaluate((el) => el.getAttribute('data-block-id') || '', item);
      const type = await this.page.evaluate((el) => el.getAttribute('data-type') || '', item);
      const hash = await this.page.evaluate((el) => el.getAttribute('data-hash') || '', item);
      result.push({ id, type, hash });
    }
    return result;
  }

  /**
   * View block detail
   */
  async viewBlock(blockId: string): Promise<void> {
    await this.click(`[data-block-id="${blockId}"]`);
    await this.waitForUpdate();
  }

  /**
   * Get signature verification status
   */
  async isSignatureValid(): Promise<boolean> {
    const text = await this.getText(this.selectors.signatureStatus);
    return text.toLowerCase().includes('valid') || text.includes('✓');
  }
}

export default RegisterPage;
