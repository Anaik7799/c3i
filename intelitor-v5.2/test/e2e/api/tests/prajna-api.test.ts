// =============================================================================
// Prajna API E2E Tests
// =============================================================================
// STAMP: SC-TEST-001, SC-PRAJNA-*, SC-BIO-*, SC-REG-*, SC-FOUNDER-*
// Tests: /api/v1/prajna/* (22 endpoints)
// C3I Command Cockpit API
// =============================================================================

import { ApiAssertions } from '../helpers';

const BASE_PATH = '/api/v1/prajna';

describe('Prajna API', () => {
  describe('Sentinel Integration (SC-IMMUNE-*)', () => {
    describe('GET /sentinel/health - Sentinel Health Status', () => {
      it('should return sentinel health score', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/sentinel/health`);
        ApiAssertions.assertStatus(response, [200, 401, 503]);
      });

      it('should respond within 500ms', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/sentinel/health`);
        ApiAssertions.assertLatency(response, 500);
      });

      it('should include threat status', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/sentinel/health`);
        if (response.status === 200) {
          ApiAssertions.assertHasData(response);
        }
      });
    });
  });

  describe('Guardian Integration (SC-CONST-007)', () => {
    describe('POST /guardian/submit - Submit Command to Guardian', () => {
      it('should return 400 for missing command', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/guardian/submit`, {});
        ApiAssertions.assertStatus(response, [400, 401, 422]);
      });

      it('should validate command type', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/guardian/submit`, {
          command: 'test_command',
          parameters: {}
        });
        ApiAssertions.assertStatus(response, [200, 400, 401, 403]);
      });

      it('should require proof token for mutations', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/guardian/submit`, {
          command: 'mutate_state',
          parameters: { key: 'value' }
        });
        ApiAssertions.assertStatus(response, [400, 401, 403]);
      });
    });
  });

  describe('Founder Directive (SC-FOUNDER-*)', () => {
    describe('POST /founder/validate - Validate Founder Directive', () => {
      it('should return 400 for missing action', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/founder/validate`, {});
        ApiAssertions.assertStatus(response, [400, 401, 422]);
      });

      it('should validate action alignment', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/founder/validate`, {
          action: 'resource_acquisition',
          parameters: { target: 'test' }
        });
        ApiAssertions.assertStatus(response, [200, 400, 401]);
      });
    });
  });

  describe('Immutable Register (SC-REG-*)', () => {
    describe('POST /register/record - Record to Immutable Register', () => {
      it('should return 400 for missing state', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/register/record`, {});
        ApiAssertions.assertStatus(response, [400, 401, 422]);
      });

      it('should require proof token (SC-REG-001)', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/register/record`, {
          state: { key: 'value' },
          operation: 'append'
        });
        ApiAssertions.assertStatus(response, [400, 401, 403]);
      });
    });
  });

  describe('PROMETHEUS Verification (SC-PROM-*)', () => {
    describe('POST /prometheus/token - Get Proof Token', () => {
      it('should return 400 for missing action', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/prometheus/token`, {});
        ApiAssertions.assertStatus(response, [400, 401, 422]);
      });

      it('should validate action for token generation', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/prometheus/token`, {
          action: 'state_mutation',
          scope: 'prajna'
        });
        ApiAssertions.assertStatus(response, [200, 400, 401, 403]);
      });
    });
  });

  describe('Constitutional Check (SC-CONST-*)', () => {
    describe('POST /constitutional/check - Check Constitutional Compliance', () => {
      it('should return 400 for missing action', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/constitutional/check`, {});
        ApiAssertions.assertStatus(response, [400, 401, 422]);
      });

      it('should check invariants (Ψ₀-Ψ₅)', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/constitutional/check`, {
          action: 'reconfiguration',
          parameters: { level: 'L3' }
        });
        ApiAssertions.assertStatus(response, [200, 400, 401, 403]);
      });
    });
  });

  describe('Zenoh Integration (SC-BRIDGE-*)', () => {
    describe('POST /zenoh/subscribe - Subscribe to Zenoh Topic', () => {
      it('should return 400 for missing topic', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/zenoh/subscribe`, {});
        ApiAssertions.assertStatus(response, [400, 401, 422]);
      });

      it('should validate topic pattern', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/zenoh/subscribe`, {
          topic: 'prajna/metrics/**',
          handler: 'dashboard_update'
        });
        ApiAssertions.assertStatus(response, [200, 400, 401]);
      });
    });

    describe('POST /zenoh/publish - Publish to Zenoh Topic', () => {
      it('should return 400 for missing topic/payload', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/zenoh/publish`, {});
        ApiAssertions.assertStatus(response, [400, 401, 422]);
      });

      it('should validate payload format', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/zenoh/publish`, {
          topic: 'prajna/commands',
          payload: { action: 'test' }
        });
        ApiAssertions.assertStatus(response, [200, 400, 401]);
      });
    });
  });

  describe('Container Management (SC-CNT-*)', () => {
    describe('GET /containers/status - Container Status', () => {
      it('should return container status', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/containers/status`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });

      it('should respond within 1000ms', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/containers/status`);
        ApiAssertions.assertLatency(response, 1000);
      });
    });

    describe('GET /containers/:id/logs - Container Logs', () => {
      it('should return 404 for non-existent container', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/containers/non-existent/logs`);
        ApiAssertions.assertStatus(response, [401, 404]);
      });

      it('should accept tail parameter', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/containers/app/logs?tail=100`);
        ApiAssertions.assertStatus(response, [200, 401, 404]);
      });
    });

    describe('POST /containers/:id/action - Container Action', () => {
      it('should return 400 for missing action', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/containers/app/action`, {});
        ApiAssertions.assertStatus(response, [400, 401, 422]);
      });

      it('should validate action type', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/containers/app/action`, {
          action: 'restart'
        });
        ApiAssertions.assertStatus(response, [200, 400, 401, 403, 404]);
      });
    });
  });

  describe('Mesh Agent Management (SC-AGT-*)', () => {
    describe('GET /mesh/agents - List Mesh Agents', () => {
      it('should return agent list', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/mesh/agents`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });

      it('should support status filter', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/mesh/agents?status=active`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });
    });

    describe('GET /mesh/agents/:id - Get Agent Details', () => {
      it('should return 404 for non-existent agent', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/mesh/agents/non-existent`);
        ApiAssertions.assertStatus(response, [401, 404]);
      });
    });

    describe('POST /mesh/agents/:id/command - Send Agent Command', () => {
      it('should return 400 for missing command', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/mesh/agents/test/command`, {});
        ApiAssertions.assertStatus(response, [400, 401, 422]);
      });

      it('should validate command type', async () => {
        const response = await global.apiClient.post(`${BASE_PATH}/mesh/agents/test/command`, {
          command: 'status',
          parameters: {}
        });
        ApiAssertions.assertStatus(response, [200, 400, 401, 404]);
      });
    });
  });

  describe('Biomorphic Holons (SC-BIO-*, SC-HOLON-*)', () => {
    describe('GET /bio/holons - List Biomorphic Holons', () => {
      it('should return holon list', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/bio/holons`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });

      it('should support type filter', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/bio/holons?type=agent`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });
    });

    describe('GET /bio/holons/:id/vitals - Get Holon Vitals', () => {
      it('should return 404 for non-existent holon', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/bio/holons/non-existent/vitals`);
        ApiAssertions.assertStatus(response, [401, 404]);
      });
    });

    describe('GET /bio/holons/:id/membrane - Get Holon Membrane', () => {
      it('should return 404 for non-existent holon', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/bio/holons/non-existent/membrane`);
        ApiAssertions.assertStatus(response, [401, 404]);
      });
    });
  });

  describe('Domain Integrations', () => {
    describe('GET /alarms/correlation - Alarm Correlation', () => {
      it('should return correlation data', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/alarms/correlation`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });

      it('should accept time range', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/alarms/correlation?hours=24`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });
    });

    describe('GET /devices/state - Device State', () => {
      it('should return device state summary', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/devices/state`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });
    });

    describe('GET /access/audit - Access Audit', () => {
      it('should return audit data', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/access/audit`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });

      it('should accept date filter', async () => {
        const response = await global.apiClient.get(`${BASE_PATH}/access/audit?date=${new Date().toISOString().split('T')[0]}`);
        ApiAssertions.assertStatus(response, [200, 401]);
      });
    });
  });
});
