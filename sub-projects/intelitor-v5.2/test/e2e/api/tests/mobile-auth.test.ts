// =============================================================================
// Mobile Auth API E2E Tests
// =============================================================================
// STAMP: SC-TEST-001, SC-SEC-044
// Tests: /api/mobile/auth/* (8 endpoints)
// =============================================================================

import { ApiAssertions } from '../helpers';

const BASE_PATH = '/api/mobile/auth';

describe('Mobile Auth API', () => {
  describe('POST /auth/login - Username/Password Login', () => {
    it('should return 401 for invalid credentials', async () => {
      const response = await global.apiClient.post(`${BASE_PATH}/login`, {
        username: 'invalid@test.com',
        password: 'wrongpassword'
      });
      ApiAssertions.assertUnauthorized(response);
    });

    it('should return 400 for missing username', async () => {
      const response = await global.apiClient.post(`${BASE_PATH}/login`, {
        password: 'somepassword'
      });
      ApiAssertions.assertBadRequest(response);
    });

    it('should return 400 for missing password', async () => {
      const response = await global.apiClient.post(`${BASE_PATH}/login`, {
        username: 'test@example.com'
      });
      ApiAssertions.assertBadRequest(response);
    });

    it('should respond within 2000ms', async () => {
      const response = await global.apiClient.post(`${BASE_PATH}/login`, {
        username: 'test@example.com',
        password: 'password'
      });
      ApiAssertions.assertLatency(response, 2000);
    });
  });

  describe('POST /auth/login/biometric - Biometric Login', () => {
    it('should return 401 for invalid biometric token', async () => {
      const response = await global.apiClient.post(`${BASE_PATH}/login/biometric`, {
        biometric_token: 'invalid_token'
      });
      ApiAssertions.assertStatus(response, [400, 401]);
    });

    it('should return 400 for missing biometric_token', async () => {
      const response = await global.apiClient.post(`${BASE_PATH}/login/biometric`, {});
      ApiAssertions.assertBadRequest(response);
    });
  });

  describe('POST /auth/refresh - Token Refresh', () => {
    it('should return 401 for invalid refresh token', async () => {
      const response = await global.apiClient.post(`${BASE_PATH}/refresh`, {
        refresh_token: 'invalid_refresh_token'
      });
      ApiAssertions.assertUnauthorized(response);
    });

    it('should return 400 for missing refresh_token', async () => {
      const response = await global.apiClient.post(`${BASE_PATH}/refresh`, {});
      ApiAssertions.assertBadRequest(response);
    });
  });

  describe('POST /auth/password/reset - Password Reset Request', () => {
    it('should accept valid email format', async () => {
      const response = await global.apiClient.post(`${BASE_PATH}/password/reset`, {
        email: 'test@example.com'
      });
      // Should return success even for non-existent email (security)
      ApiAssertions.assertStatus(response, [200, 202, 404]);
    });

    it('should return 400 for invalid email format', async () => {
      const response = await global.apiClient.post(`${BASE_PATH}/password/reset`, {
        email: 'invalid-email'
      });
      ApiAssertions.assertBadRequest(response);
    });
  });

  describe('POST /auth/mfa/verify - MFA Verification', () => {
    it('should return 400 for missing code', async () => {
      const response = await global.apiClient.post(`${BASE_PATH}/mfa/verify`, {
        session_token: 'some_token'
      });
      ApiAssertions.assertBadRequest(response);
    });

    it('should return 401 for invalid session token', async () => {
      const response = await global.apiClient.post(`${BASE_PATH}/mfa/verify`, {
        session_token: 'invalid_token',
        code: '123456'
      });
      ApiAssertions.assertUnauthorized(response);
    });
  });

  describe('POST /auth/logout - Logout (Authenticated)', () => {
    it('should return 401 without auth token', async () => {
      const tempClient = global.apiClient;
      tempClient.clearAuthToken();
      const response = await tempClient.post(`${BASE_PATH}/logout`, {});
      ApiAssertions.assertUnauthorized(response);
    });
  });

  describe('GET /auth/session - Session Info (Authenticated)', () => {
    it('should return 401 without auth token', async () => {
      const tempClient = global.apiClient;
      tempClient.clearAuthToken();
      const response = await tempClient.get(`${BASE_PATH}/session`);
      ApiAssertions.assertUnauthorized(response);
    });
  });

  describe('POST /auth/mfa/enroll - MFA Enrollment (Authenticated)', () => {
    it('should return 401 without auth token', async () => {
      const tempClient = global.apiClient;
      tempClient.clearAuthToken();
      const response = await tempClient.post(`${BASE_PATH}/mfa/enroll`, {});
      ApiAssertions.assertUnauthorized(response);
    });
  });
});
