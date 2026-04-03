// =============================================================================
// REST API Test Setup
// =============================================================================
// STAMP: SC-TEST-001
// Global setup for API E2E tests
// =============================================================================

import { ApiClient } from './client';

declare global {
  var apiClient: ApiClient;
  var authToken: string | null;
  var testContext: TestContext;
}

interface TestContext {
  userId?: string;
  tenantId?: string;
  siteId?: string;
  deviceId?: string;
  alarmId?: string;
}

const config = {
  baseUrl: process.env.API_BASE_URL || 'http://localhost:4000',
  timeout: parseInt(process.env.API_TIMEOUT || '10000'),
  retries: parseInt(process.env.API_RETRIES || '3'),
  adminUsername: process.env.TEST_ADMIN_USER || 'admin@indrajaal.local',
  adminPassword: process.env.TEST_ADMIN_PASS || 'AdminP@ss123!'
};

beforeAll(async () => {
  global.apiClient = new ApiClient(config);
  global.authToken = null;
  global.testContext = {};

  // Authenticate with admin credentials for protected endpoints
  try {
    const authResponse = await global.apiClient.post('/api/mobile/auth/login', {
      username: config.adminUsername,
      password: config.adminPassword
    });
    if (authResponse.data?.token) {
      global.authToken = authResponse.data.token;
      global.apiClient.setAuthToken(authResponse.data.token);
    }
  } catch {
    console.warn('Admin authentication failed - some tests may fail');
  }
});

afterAll(async () => {
  // Cleanup test data if needed
  if (global.authToken) {
    try {
      await global.apiClient.post('/api/mobile/auth/logout', {});
    } catch {
      // Ignore logout errors
    }
  }
});

export { config };
