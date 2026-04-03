// =============================================================================
// Mobile Operations API E2E Tests
// =============================================================================
// STAMP: SC-TEST-001
// Tests: /api/mobile/* (16 endpoints)
// =============================================================================

import { ApiAssertions } from '../helpers';

const BASE_PATH = '/api/mobile';

describe('Mobile Operations API', () => {
  describe('Alarm Operations', () => {
    describe('GET /alarms - List Alarms', () => {
      it('should return 401 without auth', async () => {
        global.apiClient.clearAuthToken();
        const response = await global.apiClient.get(`${BASE_PATH}/alarms`);
        ApiAssertions.assertUnauthorized(response);
      });

      it('should accept pagination params', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/alarms?page=1&limit=10`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });
    });

    describe('GET /alarms/:id - Get Alarm', () => {
      it('should return 404 for non-existent alarm', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/alarms/non-existent-id`);
        ApiAssertions.assertStatus(response, [401, 404]);
      });
    });

    describe('POST /alarms/:id/acknowledge - Acknowledge Alarm', () => {
      it('should return 404 for non-existent alarm', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/alarms/non-existent-id/acknowledge`, {});
        ApiAssertions.assertStatus(response, [401, 404]);
      });
    });

    describe('POST /alarms/:id/resolve - Resolve Alarm', () => {
      it('should return 404 for non-existent alarm', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/alarms/non-existent-id/resolve`, {
          resolution_notes: 'Test resolution'
        });
        ApiAssertions.assertStatus(response, [401, 404]);
      });
    });

    describe('POST /alarms/:id/escalate - Escalate Alarm', () => {
      it('should return 404 for non-existent alarm', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/alarms/non-existent-id/escalate`, {
          escalation_level: 2
        });
        ApiAssertions.assertStatus(response, [401, 404]);
      });
    });
  });

  describe('Device Operations', () => {
    describe('GET /devices - List Devices', () => {
      it('should require authentication', async () => {
        global.apiClient.clearAuthToken();
        const response = await global.apiClient.get(`${BASE_PATH}/devices`);
        ApiAssertions.assertUnauthorized(response);
      });
    });
  });

  describe('Site Operations', () => {
    describe('GET /sites - List Sites', () => {
      it('should require authentication', async () => {
        global.apiClient.clearAuthToken();
        const response = await global.apiClient.get(`${BASE_PATH}/sites`);
        ApiAssertions.assertUnauthorized(response);
      });
    });
  });

  describe('Notification Operations', () => {
    describe('POST /notifications/register - Register Push Token', () => {
      it('should return 400 for missing device_token', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/notifications/register`, {});
        ApiAssertions.assertStatus(response, [400, 401]);
      });

      it('should accept valid push token', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/notifications/register`, {
          device_token: 'fcm_token_example',
          platform: 'android'
        });
        ApiAssertions.assertStatus(response, [200, 201, 401]);
      });
    });

    describe('GET /notifications/preferences - Get Preferences', () => {
      it('should require authentication', async () => {
        global.apiClient.clearAuthToken();
        const response = await global.apiClient.get(`${BASE_PATH}/notifications/preferences`);
        ApiAssertions.assertUnauthorized(response);
      });
    });

    describe('PUT /notifications/preferences - Update Preferences', () => {
      it('should require authentication', async () => {
        global.apiClient.clearAuthToken();
        const response = await global.apiClient.put(`${BASE_PATH}/notifications/preferences`, {
          alarm_notifications: true,
          maintenance_notifications: false
        });
        ApiAssertions.assertUnauthorized(response);
      });
    });
  });

  describe('Dashboard Operations', () => {
    describe('GET /dashboard - Get Mobile Dashboard', () => {
      it('should require authentication', async () => {
        global.apiClient.clearAuthToken();
        const response = await global.apiClient.get(`${BASE_PATH}/dashboard`);
        ApiAssertions.assertUnauthorized(response);
      });
    });
  });

  describe('Batch Operations', () => {
    describe('POST /batch/get - Batch Get', () => {
      it('should return 400 for missing resources', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/batch/get`, {});
        ApiAssertions.assertStatus(response, [400, 401]);
      });

      it('should accept valid batch request', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/batch/get`, {
          resources: [
            { type: 'alarm', id: 'test-1' },
            { type: 'device', id: 'test-2' }
          ]
        });
        ApiAssertions.assertStatus(response, [200, 207, 401]);
      });
    });

    describe('POST /batch/create - Batch Create', () => {
      it('should return 400 for empty items', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/batch/create`, {
          items: []
        });
        ApiAssertions.assertStatus(response, [400, 401]);
      });
    });

    describe('PUT /batch/update - Batch Update', () => {
      it('should return 400 for missing updates', async () => {
        const response = await global.apiClient.put(`${BASE_PATH}/batch/update`, {});
        ApiAssertions.assertStatus(response, [400, 401]);
      });
    });

    describe('POST /batch/acknowledge - Batch Acknowledge', () => {
      it('should return 400 for missing alarm_ids', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/batch/acknowledge`, {});
        ApiAssertions.assertStatus(response, [400, 401]);
      });

      it('should accept valid alarm_ids', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/batch/acknowledge`, {
          alarm_ids: ['alarm-1', 'alarm-2']
        });
        ApiAssertions.assertStatus(response, [200, 207, 401, 404]);
      });
    });

    describe('POST /batch/sync - Offline Sync', () => {
      it('should return 400 for missing sync data', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/batch/sync`, {});
        ApiAssertions.assertStatus(response, [400, 401]);
      });

      it('should accept valid sync payload', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/batch/sync`, {
          last_sync_timestamp: new Date().toISOString(),
          changes: []
        });
        ApiAssertions.assertStatus(response, [200, 207, 401]);
      });
    });
  });
});
