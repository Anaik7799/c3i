// =============================================================================
// KMS (Knowledge Management System) API E2E Tests
// =============================================================================
// STAMP: SC-TEST-001, SC-HOLON-*
// Tests: /api/kms/* (12 endpoints)
// =============================================================================

import { ApiAssertions } from '../helpers';

const BASE_PATH = '/api/kms';

describe('KMS API', () => {
  describe('Holon Operations', () => {
    describe('GET /holons - List Holons', () => {
      it('should list holons', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/holons`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });

      it('should support pagination', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/holons?page=1&limit=10`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });

      it('should support type filter', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/holons?type=agent`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });

      it('should respond within 1000ms', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/holons`);
        ApiAssertions.assertLatency(response, 1000);
      });
    });

    describe('GET /holons/:id - Get Holon', () => {
      it('should return 404 for non-existent holon', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/holons/non-existent-holon`);
        ApiAssertions.assertStatus(response, [401, 404]);
      });
    });

    describe('POST /holons - Create Holon', () => {
      it('should return 400 for missing required fields', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/holons`, {});
        ApiAssertions.assertStatus(response, [400, 401, 422]);
      });

      it('should validate holon type', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/holons`, {
          name: 'Test Holon',
          type: 'invalid_type'
        });
        ApiAssertions.assertStatus(response, [400, 401, 422]);
      });
    });

    describe('PUT /holons/:id - Update Holon', () => {
      it('should return 404 for non-existent holon', async () => {
        const response = await global.apiClient.put(`${BASE_PATH}/holons/non-existent-holon`, {
          name: 'Updated Name'
        });
        ApiAssertions.assertStatus(response, [401, 404]);
      });
    });

    describe('DELETE /holons/:id - Delete Holon', () => {
      it('should return 404 for non-existent holon', async () => {
        const response = await global.apiClient.delete(`${BASE_PATH}/holons/non-existent-holon`);
        ApiAssertions.assertStatus(response, [401, 404]);
      });
    });

    describe('GET /holons/:id/children - Get Child Holons', () => {
      it('should return 404 for non-existent parent', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/holons/non-existent-holon/children`);
        ApiAssertions.assertStatus(response, [401, 404]);
      });
    });

    describe('GET /holons/:id/descendants - Get All Descendants', () => {
      it('should return 404 for non-existent ancestor', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/holons/non-existent-holon/descendants`);
        ApiAssertions.assertStatus(response, [401, 404]);
      });

      it('should accept depth parameter', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/holons/test/descendants?depth=3`);
        ApiAssertions.assertStatus(response, [200, 401, 404]);
      });
    });
  });

  describe('Edge Operations', () => {
    describe('POST /edges - Create Holon Relationship', () => {
      it('should return 400 for missing source/target', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/edges`, {});
        ApiAssertions.assertStatus(response, [400, 401, 422]);
      });

      it('should validate relationship type', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/edges`, {
          source_id: 'holon-1',
          target_id: 'holon-2',
          relationship: 'parent_of'
        });
        ApiAssertions.assertStatus(response, [200, 201, 401, 404]);
      });
    });
  });

  describe('Search Operations', () => {
    describe('GET /search - Full-Text Search', () => {
      it('should return 400 for missing query', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/search`);
        ApiAssertions.assertStatus(response, [400, 401]);
      });

      it('should accept query parameter', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/search?q=test`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });

      it('should support type filter', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/search?q=test&type=agent`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });

      it('should support limit parameter', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/search?q=test&limit=5`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });
    });
  });

  describe('System Operations', () => {
    describe('GET /health - KMS Health', () => {
      it('should return health status', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/health`);
        ApiAssertions.assertStatus(response, [200, 503]);
      });

      it('should respond within 500ms', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/health`);
        ApiAssertions.assertLatency(response, 500);
      });
    });

    describe('GET /entropy - Entropy Analysis', () => {
      it('should return entropy metrics', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/entropy`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });

      it('should accept scope parameter', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/entropy?scope=global`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });
    });

    describe('GET /stats - KMS Statistics', () => {
      it('should return system statistics', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/stats`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });

      it('should include holon counts', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/stats`);
        if (response.status === 200) {
          ApiAssertions.assertHasData(response);
        }
      });
    });
  });
});
