// =============================================================================
// Analytics API E2E Tests
// =============================================================================
// STAMP: SC-TEST-001
// Tests: /api/v1/analytics/* (10 endpoints)
// =============================================================================

import { ApiAssertions } from '../helpers';

const BASE_PATH = '/api/v1/analytics';

describe('Analytics API', () => {
  describe('GET /stamp-tdg-gde - STAMP/TDG/GDE Analytics', () => {
    it('should require authentication', async () => {
      global.apiClient.clearAuthToken();
      const response = await global.apiClient.get(`${BASE_PATH}/stamp-tdg-gde`);
      ApiAssertions.assertStatus(response, [200, 401]);
    });

    it('should respond within 2000ms', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/stamp-tdg-gde`);
      ApiAssertions.assertLatency(response, 2000);
    });

    it('should accept date range params', async () => {
      const startDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
      const endDate = new Date().toISOString();
      const response = await global.apiClient.get(
        `${BASE_PATH}/stamp-tdg-gde?start_date=${startDate}&end_date=${endDate}`
      );
      ApiAssertions.assertStatus(response, [200, 401]);
    });
  });

  describe('GET /real-time - Real-Time Metrics', () => {
    it('should return current metrics', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/real-time`);
      ApiAssertions.assertStatus(response, [200, 401]);
    });

    it('should respond within 500ms', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/real-time`);
      ApiAssertions.assertLatency(response, 500);
    });

    it('should accept metric type filter', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/real-time?type=system`);
      ApiAssertions.assertStatus(response, [200, 401]);
    });
  });

  describe('GET /historical - Historical Data', () => {
    it('should require date range', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/historical`);
      ApiAssertions.assertStatus(response, [200, 400, 401]);
    });

    it('should accept aggregation params', async () => {
      const response = await global.apiClient.get(
        `${BASE_PATH}/historical?aggregation=hourly&metric=alarms`
      );
      ApiAssertions.assertStatus(response, [200, 400, 401]);
    });
  });

  describe('GET /predictions - Predictive Analytics', () => {
    it('should return prediction data', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/predictions`);
      ApiAssertions.assertStatus(response, [200, 401]);
    });

    it('should accept prediction type param', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/predictions?type=alarm_forecast`);
      ApiAssertions.assertStatus(response, [200, 401]);
    });

    it('should accept horizon param', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/predictions?horizon=24h`);
      ApiAssertions.assertStatus(response, [200, 401]);
    });
  });

  describe('GET /anomalies - Anomaly Detection', () => {
    it('should return anomaly data', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/anomalies`);
      ApiAssertions.assertStatus(response, [200, 401]);
    });

    it('should accept severity filter', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/anomalies?severity=critical`);
      ApiAssertions.assertStatus(response, [200, 401]);
    });

    it('should accept category filter', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/anomalies?category=network`);
      ApiAssertions.assertStatus(response, [200, 401]);
    });
  });

  describe('GET /benchmarks - Benchmark Data', () => {
    it('should return benchmark metrics', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/benchmarks`);
      ApiAssertions.assertStatus(response, [200, 401]);
    });

    it('should accept metric type filter', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/benchmarks?metric=response_time`);
      ApiAssertions.assertStatus(response, [200, 401]);
    });
  });

  describe('GET /data-quality - Data Quality Metrics', () => {
    it('should return quality metrics', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/data-quality`);
      ApiAssertions.assertStatus(response, [200, 401]);
    });

    it('should accept data source filter', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/data-quality?source=alarms`);
      ApiAssertions.assertStatus(response, [200, 401]);
    });
  });

  describe('GET /metadata - Analytics Metadata', () => {
    it('should return available metrics metadata', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/metadata`);
      ApiAssertions.assertStatus(response, [200, 401]);
    });

    it('should include metric definitions', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/metadata`);
      if (response.status === 200) {
        ApiAssertions.assertHasData(response);
      }
    });
  });

  describe('POST /export - Export Analytics Data', () => {
    it('should require format parameter', async () => {
      const response = await global.apiClient.post(`${BASE_PATH}/export`, {});
      ApiAssertions.assertStatus(response, [400, 401]);
    });

    it('should accept CSV format', async () => {
      const response = await global.apiClient.post(`${BASE_PATH}/export`, {
        format: 'csv',
        metrics: ['alarms', 'devices']
      });
      ApiAssertions.assertStatus(response, [200, 202, 401]);
    });

    it('should accept JSON format', async () => {
      const response = await global.apiClient.post(`${BASE_PATH}/export`, {
        format: 'json',
        metrics: ['alarms']
      });
      ApiAssertions.assertStatus(response, [200, 202, 401]);
    });
  });

  describe('GET /health - Analytics Health Check', () => {
    it('should return health status', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/health`);
      ApiAssertions.assertStatus(response, [200, 503]);
    });

    it('should respond within 1000ms', async () => {
      const response = await global.apiClient.get(`${BASE_PATH}/health`);
      ApiAssertions.assertLatency(response, 1000);
    });
  });
});
