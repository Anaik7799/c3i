// =============================================================================
// Prajna AI Copilot Page Object
// =============================================================================
// STAMP: SC-TEST-001, SC-PRAJNA-002, AOR-FOUNDER-002
// Path: /prajna/copilot
// =============================================================================

import { Page } from 'puppeteer';
import { PrajnaBasePage } from '../BasePage';

export class CopilotPage extends PrajnaBasePage {
  private selectors = {
    container: '[data-testid="copilot-container"], .copilot-container',
    chatMessages: '[data-testid="chat-messages"], .chat-messages',
    inputField: '[data-testid="chat-input"], input[name="message"], textarea[name="message"]',
    sendButton: '[data-testid="send-btn"], button[type="submit"]',
    suggestionPanel: '[data-testid="suggestions"], .suggestion-panel',
    contextDisplay: '[data-testid="context-display"], .context-display',
    founderDirective: '[data-testid="founder-directive"], .founder-directive-indicator',
    thinkingIndicator: '[data-testid="thinking"], .thinking-indicator',
    clearButton: '[data-testid="clear-chat"], button[phx-click="clear"]',
    modelSelector: '[data-testid="model-select"], select[name="model"]'
  };

  constructor(page: Page) {
    super(page, '/copilot', 'AI Copilot');
  }

  async isHealthy(): Promise<boolean> {
    return (
      await this.exists(this.selectors.container) &&
      await this.exists(this.selectors.inputField) &&
      await this.hasSidebar()
    );
  }

  /**
   * Send a message to the AI copilot
   */
  async sendMessage(message: string): Promise<void> {
    await this.fill(this.selectors.inputField, message);
    await this.click(this.selectors.sendButton);
    await this.waitForResponse();
  }

  /**
   * Wait for AI response
   */
  async waitForResponse(timeout = 30000): Promise<void> {
    // Wait for thinking indicator to appear and disappear
    try {
      await this.page.waitForSelector(this.selectors.thinkingIndicator, { timeout: 5000 });
    } catch {
      // May not show thinking indicator for fast responses
    }
    await this.page.waitForFunction(
      (sel) => !document.querySelector(sel),
      { timeout },
      this.selectors.thinkingIndicator
    );
  }

  /**
   * Get all chat messages
   */
  async getMessages(): Promise<{ role: string; content: string }[]> {
    const messages = await this.page.$$(this.selectors.chatMessages + ' [data-message]');
    const result = [];
    for (const msg of messages) {
      const role = await this.page.evaluate((el) => el.getAttribute('data-role') || 'unknown', msg);
      const content = await this.page.evaluate((el) => el.textContent || '', msg);
      result.push({ role, content });
    }
    return result;
  }

  /**
   * Get last response from AI
   */
  async getLastResponse(): Promise<string> {
    const messages = await this.getMessages();
    const assistantMessages = messages.filter(m => m.role === 'assistant');
    return assistantMessages.length > 0 ? assistantMessages[assistantMessages.length - 1].content : '';
  }

  /**
   * Get available suggestions
   */
  async getSuggestions(): Promise<string[]> {
    const suggestions = await this.page.$$(this.selectors.suggestionPanel + ' [data-suggestion]');
    const result = [];
    for (const sug of suggestions) {
      const text = await this.page.evaluate((el) => el.textContent || '', sug);
      result.push(text);
    }
    return result;
  }

  /**
   * Click a suggestion
   */
  async clickSuggestion(index: number): Promise<void> {
    await this.click(`${this.selectors.suggestionPanel} [data-suggestion]:nth-child(${index + 1})`);
  }

  /**
   * Check Founder's Directive alignment
   */
  async isFounderAligned(): Promise<boolean> {
    const indicator = await this.getText(this.selectors.founderDirective);
    return indicator.toLowerCase().includes('aligned') || indicator.includes('✓');
  }

  /**
   * Clear chat history
   */
  async clearChat(): Promise<void> {
    await this.click(this.selectors.clearButton);
    await this.waitForUpdate();
  }

  /**
   * Select AI model
   */
  async selectModel(model: string): Promise<void> {
    await this.page.select(this.selectors.modelSelector, model);
    await this.waitForUpdate();
  }

  /**
   * Check if AI is thinking
   */
  async isThinking(): Promise<boolean> {
    return await this.exists(this.selectors.thinkingIndicator);
  }

  /**
   * Get current context summary
   */
  async getContextSummary(): Promise<string> {
    return await this.getText(this.selectors.contextDisplay);
  }
}

export default CopilotPage;
