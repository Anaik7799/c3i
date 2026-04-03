@security @validation @sil6 @phase6
Feature: Security Validation
  As a security-conscious system
  I want comprehensive security validation during startup
  So that the system is protected against common vulnerabilities

  Background:
    Given full swarm is running and healthy
    And all security configurations are loaded
    And the Guardian security kernel is active

  # ==========================================================================
  # SC-SEC-001: TLS certificate validation
  # ==========================================================================
  @critical @tls
  Scenario: All inter-container communication uses valid TLS
    Given the swarm network is configured for TLS
    When I inspect the container network configuration
    Then all API endpoints should enforce HTTPS
    And TLS certificates should be valid and not expired
    And certificate chain should be complete
    And minimum TLS version should be 1.3
    And the following endpoints should be TLS-protected
      | Endpoint                        | Port  |
      | Phoenix API                     | 4000  |
      | Health endpoint                 | 4001  |
      | OTEL collector                  | 4317  |
      | Prometheus                      | 9090  |
      | Grafana                         | 3000  |
      | Zenoh routers                   | 7447+ |

  # ==========================================================================
  # SC-SEC-002: Authentication enforcement
  # ==========================================================================
  @critical @authentication
  Scenario: All protected endpoints require authentication
    Given the authentication system is configured
    When I attempt to access protected API endpoints without credentials
    Then I should receive HTTP 401 Unauthorized responses
    And the following endpoints should require authentication
      | Endpoint                         | Method |
      | /api/prajna/guardian/propose     | POST   |
      | /api/prajna/sentinel/threats     | GET    |
      | /api/prajna/copilot/chat         | POST   |
      | /api/admin/*                     | ALL    |
    And failed authentication attempts should be logged
    And rate limiting should apply after 5 failed attempts

  # ==========================================================================
  # SC-SEC-003: Security header validation
  # ==========================================================================
  @headers @owasp
  Scenario: All HTTP responses include security headers
    Given the Phoenix application is serving requests
    When I make an HTTP request to any endpoint
    Then the response should include the following security headers
      | Header                       | Expected Value                    |
      | X-Content-Type-Options       | nosniff                           |
      | X-Frame-Options              | DENY                              |
      | X-XSS-Protection             | 1; mode=block                     |
      | Strict-Transport-Security    | max-age=31536000; includeSubDomains |
      | Content-Security-Policy      | default-src 'self'                |
      | Referrer-Policy              | strict-origin-when-cross-origin   |
    And no sensitive information should be in response headers

  # ==========================================================================
  # SC-SEC-004: Secrets management validation
  # ==========================================================================
  @critical @secrets
  Scenario: Secrets are properly managed and not exposed
    Given the KMS (Key Management Service) is operational
    When I inspect container environment variables
    Then no plaintext secrets should be present in environment
    And all sensitive values should reference KMS paths
    And the following secrets should be encrypted at rest
      | Secret Type          | Storage Location |
      | Database credentials | KMS              |
      | API keys             | KMS              |
      | TLS private keys     | KMS              |
      | JWT signing keys     | KMS              |
    And secret rotation should be configured
    And access to secrets should be audited

  # ==========================================================================
  # SC-SEC-005: Container isolation validation
  # ==========================================================================
  @container @isolation
  Scenario: Containers are properly isolated from each other
    Given all 15 containers are running
    When I inspect container security configurations
    Then each container should run as non-root user
    And containers should have minimal capabilities
    And no container should have privileged access
    And the following isolation should be enforced
      | Isolation Type       | Enforcement |
      | Network namespace    | Isolated    |
      | PID namespace        | Isolated    |
      | IPC namespace        | Isolated    |
      | User namespace       | Enabled     |
      | Seccomp profile      | Applied     |
      | AppArmor profile     | Applied     |
    And inter-container communication should only use defined networks

  # ==========================================================================
  # SC-SEC-006: Guardian approval for sensitive operations
  # ==========================================================================
  @guardian @approval
  Scenario: Sensitive operations require Guardian approval
    Given the Guardian security kernel is active
    And I am authenticated as an operator
    When I attempt to perform the following sensitive operations
      | Operation                        | Risk Level |
      | Restart all containers           | HIGH       |
      | Access production database       | HIGH       |
      | Modify security configuration    | CRITICAL   |
      | Execute emergency shutdown       | CRITICAL   |
      | Export system state              | MEDIUM     |
    Then Guardian should require approval for HIGH and CRITICAL operations
    And approval requests should be logged to the Immutable Register
    And approved operations should include audit trail
    And denied operations should trigger security alert
