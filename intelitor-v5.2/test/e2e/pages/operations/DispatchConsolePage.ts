// =============================================================================
// Dispatch Console Page Object (Operations)
// =============================================================================
// STAMP: SC-TEST-001
// Path: /dispatch/console
// =============================================================================

import { Page } from 'puppeteer';
import { OperationsBasePage } from '../BasePage';

export class DispatchConsolePage extends OperationsBasePage {
  private selectors = {
    container: '[data-testid="dispatch-console"], .dispatch-console',
    dispatchQueue: '[data-testid="dispatch-queue"], .dispatch-queue',
    dispatchItem: '[data-dispatch-id]',
    responderList: '[data-testid="responders"], .responder-list',
    mapView: '[data-testid="map-view"], .dispatch-map',
    assignBtn: '[data-testid="assign-btn"], button[phx-click="assign"]',
    completeBtn: '[data-testid="complete-btn"], button[phx-click="complete"]',
    slaStatus: '[data-testid="sla-status"], .sla-status'
  };

  constructor(page: Page) {
    super(page, '/dispatch/console', 'Dispatch Console');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.dispatchQueue)
    );
  }

  async getPendingCount(): Promise<number> {
    const items = await this.page.$$(this.selectors.dispatchItem + '[data-status="pending"]');
    return items.length;
  }

  async getResponderCount(): Promise<number> {
    const items = await this.page.$$(this.selectors.responderList + ' [data-responder-id]');
    return items.length;
  }

  async hasMapView(): Promise<boolean> {
    return await this.exists(this.selectors.mapView);
  }

  async assignDispatch(dispatchId: string): Promise<void> {
    await this.click(`[data-dispatch-id="${dispatchId}"] ${this.selectors.assignBtn}`);
    await this.waitForUpdate();
  }
}

export default DispatchConsolePage;
