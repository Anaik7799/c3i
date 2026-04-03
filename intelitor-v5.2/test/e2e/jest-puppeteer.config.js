// =============================================================================
// Puppeteer Configuration for Indrajaal E2E Tests
// =============================================================================
// STAMP: SC-TEST-001, SC-HMI-001
// Standards: Puppeteer best practices, Phoenix LiveView testing
// =============================================================================

module.exports = {
  launch: {
    // Headless mode for CI, headed for local debugging
    headless: process.env.HEADLESS !== 'false',

    // Slow down operations for stability
    slowMo: process.env.SLOWMO ? parseInt(process.env.SLOWMO, 10) : 0,

    // Browser arguments for containerized environments
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
      '--disable-web-security',
      '--window-size=1920,1080'
    ],

    // Default viewport
    defaultViewport: {
      width: 1920,
      height: 1080
    },

    // Timeout for browser operations
    timeout: 30000
  },

  // Browser context per test file for isolation
  browserContext: 'default',

  // Server configuration
  server: {
    // Phoenix server URL (assumes sa-up has been run)
    command: 'echo "Using external Phoenix server at http://localhost:4000"',
    port: 4000,
    launchTimeout: 10000,
    debug: true
  }
};
