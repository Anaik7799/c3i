// =============================================================================
// Video Wall Page Object (Operations)
// =============================================================================
// STAMP: SC-TEST-001
// Path: /video/wall
// =============================================================================

import { Page } from 'puppeteer';
import { OperationsBasePage } from '../BasePage';

export class VideoWallPage extends OperationsBasePage {
  private selectors = {
    container: '[data-testid="video-wall"], .video-wall',
    videoGrid: '[data-testid="video-grid"], .video-grid',
    videoTile: '[data-stream-id]',
    layoutSelector: '[data-testid="layout"], select[name="layout"]',
    fullscreenBtn: '[data-testid="fullscreen"], button[phx-click="fullscreen"]',
    streamHealth: '[data-testid="stream-health"], .stream-health',
    controlPanel: '[data-testid="controls"], .control-panel'
  };

  constructor(page: Page) {
    super(page, '/video/wall', 'Video Wall');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.videoGrid)
    );
  }

  async getStreamCount(): Promise<number> {
    const items = await this.page.$$(this.selectors.videoTile);
    return items.length;
  }

  async hasControlPanel(): Promise<boolean> {
    return await this.exists(this.selectors.controlPanel);
  }

  async selectLayout(layout: string): Promise<void> {
    await this.page.select(this.selectors.layoutSelector, layout);
    await this.waitForUpdate();
  }

  async getStreamHealth(): Promise<{ healthy: number; degraded: number; offline: number }> {
    const tiles = await this.page.$$(this.selectors.videoTile);
    let healthy = 0, degraded = 0, offline = 0;
    for (const tile of tiles) {
      const status = await this.page.evaluate((el) => el.getAttribute('data-health') || '', tile);
      if (status === 'healthy') healthy++;
      else if (status === 'degraded') degraded++;
      else offline++;
    }
    return { healthy, degraded, offline };
  }
}

export default VideoWallPage;
