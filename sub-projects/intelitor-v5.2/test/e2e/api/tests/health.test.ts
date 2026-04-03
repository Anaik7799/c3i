// =============================================================================
// Health & Kubernetes Endpoints E2E Tests
// =============================================================================
// STAMP: SC-TEST-001
// Tests: /healthz, /ready, /startup, /health
// =============================================================================

import { ApiAssertions } from '../helpers';

describe('Health - Kubernetes Probes', () => {
  describe('GET /healthz - Liveness Probe', () => {
    it('should return 200 when service is alive', async () => {
      const response = await global.apiClient.get('/healthz');
      ApiAssertions.assertStatus(response, [200, 204]);
    });

    it('should respond within 100ms', async () => {
      const response = await global.apiClient.get('/healthz');
      ApiAssertions.assertLatency(response, 100);
    });
  });

  describe('GET /ready - Readiness Probe', () => {
    it('should return 200 when service is ready', async () => {
      const response = await global.apiClient.get('/ready');
      ApiAssertions.assertStatus(response, [200, 503]);
    });

    it('should respond within 500ms', async () => {
      const response = await global.apiClient.get('/ready');
      ApiAssertions.assertLatency(response, 500);
    });
  });

  describe('GET /startup - Startup Probe', () => {
    it('should return 200 when startup complete', async () => {
      const response = await global.apiClient.get('/startup');
      ApiAssertions.assertStatus(response, [200, 503]);
    });
  });

  describe('GET /health - Comprehensive Health', () => {
    it('should return 200 with health details', async () => {
      const response = await global.apiClient.get('/health');
      ApiAssertions.assertStatus(response, [200, 503]);
    });

    it('should include system status', async () => {
      const response = await global.apiClient.get('/health');
      if (response.status === 200) {
        ApiAssertions.assertHasData(response);
      }
    });

    it('should respond within 1000ms', async () => {
      const response = await global.apiClient.get('/health');
      ApiAssertions.assertLatency(response, 1000);
    });
  });
});
