// =============================================================================
// REST API Client
// =============================================================================
// STAMP: SC-TEST-001
// HTTP client wrapper for API E2E tests
// =============================================================================

import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse } from 'axios';

export interface ApiConfig {
  baseUrl: string;
  timeout: number;
  retries: number;
}

export interface ApiResponse<T = any> {
  status: number;
  data: T;
  headers: Record<string, string>;
  duration: number;
}

export class ApiClient {
  private client: AxiosInstance;
  private retries: number;
  private authToken: string | null = null;

  constructor(config: ApiConfig) {
    this.retries = config.retries;
    this.client = axios.create({
      baseURL: config.baseUrl,
      timeout: config.timeout,
      validateStatus: () => true, // Don't throw on any status
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'Indrajaal-E2E-Test/1.0'
      }
    });
  }

  setAuthToken(token: string): void {
    this.authToken = token;
    this.client.defaults.headers.common['Authorization'] = `Bearer ${token}`;
  }

  clearAuthToken(): void {
    this.authToken = null;
    delete this.client.defaults.headers.common['Authorization'];
  }

  private async request<T>(
    method: string,
    url: string,
    data?: any,
    config?: AxiosRequestConfig
  ): Promise<ApiResponse<T>> {
    const startTime = Date.now();
    let lastError: Error | null = null;

    for (let attempt = 0; attempt <= this.retries; attempt++) {
      try {
        const response: AxiosResponse<T> = await this.client.request({
          method,
          url,
          data,
          ...config
        });

        return {
          status: response.status,
          data: response.data,
          headers: response.headers as Record<string, string>,
          duration: Date.now() - startTime
        };
      } catch (error) {
        lastError = error as Error;
        if (attempt < this.retries) {
          await this.delay(Math.pow(2, attempt) * 100);
        }
      }
    }

    throw lastError;
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async get<T = any>(url: string, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>('GET', url, undefined, config);
  }

  async post<T = any>(url: string, data?: any, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>('POST', url, data, config);
  }

  async put<T = any>(url: string, data?: any, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>('PUT', url, data, config);
  }

  async patch<T = any>(url: string, data?: any, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>('PATCH', url, data, config);
  }

  async delete<T = any>(url: string, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>('DELETE', url, undefined, config);
  }

  // Convenience methods for common patterns
  async healthCheck(): Promise<boolean> {
    try {
      const response = await this.get('/healthz');
      return response.status === 200;
    } catch {
      return false;
    }
  }

  async readinessCheck(): Promise<boolean> {
    try {
      const response = await this.get('/ready');
      return response.status === 200;
    } catch {
      return false;
    }
  }
}

// Response assertions helper
export class ApiAssertions {
  static assertStatus(response: ApiResponse, expected: number | number[]): void {
    const expectedStatuses = Array.isArray(expected) ? expected : [expected];
    expect(expectedStatuses).toContain(response.status);
  }

  static assertSuccess(response: ApiResponse): void {
    expect(response.status).toBeGreaterThanOrEqual(200);
    expect(response.status).toBeLessThan(300);
  }

  static assertCreated(response: ApiResponse): void {
    expect(response.status).toBe(201);
  }

  static assertNoContent(response: ApiResponse): void {
    expect(response.status).toBe(204);
  }

  static assertBadRequest(response: ApiResponse): void {
    expect(response.status).toBe(400);
  }

  static assertUnauthorized(response: ApiResponse): void {
    expect(response.status).toBe(401);
  }

  static assertForbidden(response: ApiResponse): void {
    expect(response.status).toBe(403);
  }

  static assertNotFound(response: ApiResponse): void {
    expect(response.status).toBe(404);
  }

  static assertConflict(response: ApiResponse): void {
    expect(response.status).toBe(409);
  }

  static assertHasData(response: ApiResponse): void {
    expect(response.data).toBeDefined();
  }

  static assertHasProperty(response: ApiResponse, property: string): void {
    expect(response.data).toHaveProperty(property);
  }

  static assertLatency(response: ApiResponse, maxMs: number): void {
    expect(response.duration).toBeLessThanOrEqual(maxMs);
  }

  static assertPagination(response: ApiResponse): void {
    expect(response.data).toHaveProperty('data');
    expect(response.data).toHaveProperty('meta');
  }
}

export default ApiClient;
