// =============================================================================
// Zenoh Test Setup
// =============================================================================
// STAMP: SC-TEST-001, SC-BRIDGE-*
// Setup for Zenoh pub/sub interface tests
// =============================================================================

import { ApiClient } from '../../api/helpers/client';

declare global {
  var apiClient: ApiClient;
  var zenohClient: ZenohTestClient;
  var testContext: ZenohTestContext;
}

interface ZenohTestContext {
  sessionId?: string;
  subscriptions: string[];
}

export interface ZenohMessage {
  topic: string;
  payload: any;
  timestamp: number;
  correlationId?: string;
}

// Zenoh test client that uses the Prajna API to interact with Zenoh
export class ZenohTestClient {
  private api: ApiClient;
  private receivedMessages: ZenohMessage[] = [];

  constructor(apiClient: ApiClient) {
    this.api = apiClient;
  }

  async subscribe(topic: string): Promise<boolean> {
    const response = await this.api.post('/api/v1/prajna/zenoh/subscribe', {
      topic,
      handler: 'test_collector'
    });
    return response.status === 200;
  }

  async publish(topic: string, payload: any): Promise<boolean> {
    const response = await this.api.post('/api/v1/prajna/zenoh/publish', {
      topic,
      payload
    });
    return response.status === 200;
  }

  async getMessages(topic?: string): Promise<ZenohMessage[]> {
    if (topic) {
      return this.receivedMessages.filter(m => m.topic.includes(topic));
    }
    return this.receivedMessages;
  }

  clearMessages(): void {
    this.receivedMessages = [];
  }
}

const config = {
  baseUrl: process.env.API_BASE_URL || 'http://localhost:4000',
  timeout: 30000, // Longer timeout for Zenoh
  retries: 2,
  adminUsername: process.env.TEST_ADMIN_USER || 'admin@indrajaal.local',
  adminPassword: process.env.TEST_ADMIN_PASS || 'AdminP@ss123!'
};

beforeAll(async () => {
  global.apiClient = new ApiClient(config);
  global.zenohClient = new ZenohTestClient(global.apiClient);
  global.testContext = { subscriptions: [] };

  // Authenticate
  try {
    const authResponse = await global.apiClient.post('/api/mobile/auth/login', {
      username: config.adminUsername,
      password: config.adminPassword
    });
    if (authResponse.data?.token) {
      global.apiClient.setAuthToken(authResponse.data.token);
    }
  } catch {
    console.warn('Admin authentication failed - some tests may fail');
  }
});

afterAll(async () => {
  // Cleanup subscriptions
  for (const sub of global.testContext.subscriptions) {
    try {
      await global.apiClient.post('/api/v1/prajna/zenoh/unsubscribe', { topic: sub });
    } catch {
      // Ignore errors
    }
  }
});

export { config, ZenohTestClient };
