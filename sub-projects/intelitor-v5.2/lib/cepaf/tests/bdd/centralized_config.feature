# STAMP: SC-CONFIG-001 to SC-CONFIG-003, SC-BOOT-001
# AOR: AOR-FUNC-001, AOR-FUNC-002
# Constraint: Single Source of Truth Configuration

@critical @config @centralized @SC-CONFIG-001
Feature: Centralized Configuration (Single Source of Truth)
  As a system architect
  I want all configuration in a single location
  So that changes only need to be made in one place

  Background:
    Given the centralized configuration is defined in MeshConfig.fs
    And the Elixir mirror is defined in Indrajaal.Startup.Config

  # ============================================================================
  # Port Configuration
  # ============================================================================

  @ports @SC-CONFIG-001
  Scenario: All port numbers come from NetworkConfig.Ports
    When I query port configurations
    Then the following ports should be defined in a single location:
      | Service          | Port  | Module              |
      | Phoenix Primary  | 4000  | NetworkConfig.Ports |
      | Phoenix HA       | 4001  | NetworkConfig.Ports |
      | PostgreSQL       | 5433  | NetworkConfig.Ports |
      | OTEL gRPC        | 4317  | NetworkConfig.Ports |
      | OTEL HTTP        | 4318  | NetworkConfig.Ports |
      | Prometheus       | 9090  | NetworkConfig.Ports |
      | Grafana          | 3000  | NetworkConfig.Ports |
      | Loki             | 3100  | NetworkConfig.Ports |
      | Zenoh Router 1   | 7447  | NetworkConfig.Ports |
      | Zenoh Router 2   | 7448  | NetworkConfig.Ports |
      | Zenoh Router 3   | 7449  | NetworkConfig.Ports |
      | CEPAF Bridge     | 9876  | NetworkConfig.Ports |
      | Cortex           | 9877  | NetworkConfig.Ports |
      | Chaya            | 4002  | NetworkConfig.Ports |
    And no hardcoded port numbers should exist in boot code

  @ports @no-magic-values @SC-CONFIG-002
  Scenario: No magic port values in application code
    When I scan the codebase for hardcoded port numbers
    Then the following patterns should NOT be found:
      | Pattern           | Context                    |
      | :4000             | Hardcoded Phoenix port     |
      | :5433             | Hardcoded PostgreSQL port  |
      | :7447             | Hardcoded Zenoh port       |
    And all port references should use configuration module

  # ============================================================================
  # IP Address Configuration
  # ============================================================================

  @ip-addresses @SC-CONFIG-001
  Scenario: All IP addresses come from NetworkConfig.IpAddresses
    When I query IP address configurations
    Then the following IP addresses should be defined in a single location:
      | Container          | IP Address    | Module                   |
      | indrajaal-ex-app-1 | 172.28.0.10   | NetworkConfig.IpAddresses|
      | indrajaal-db-prod  | 172.28.0.5    | NetworkConfig.IpAddresses|
      | indrajaal-obs-prod | 172.28.0.6    | NetworkConfig.IpAddresses|
      | zenoh-router-1     | 172.28.0.20   | NetworkConfig.IpAddresses|
      | zenoh-router-2     | 172.28.0.21   | NetworkConfig.IpAddresses|
      | zenoh-router-3     | 172.28.0.22   | NetworkConfig.IpAddresses|
      | cepaf-bridge       | 172.28.0.30   | NetworkConfig.IpAddresses|
      | indrajaal-cortex   | 172.28.0.31   | NetworkConfig.IpAddresses|
    And no hardcoded IP addresses should exist in compose files

  # ============================================================================
  # Timeout Configuration
  # ============================================================================

  @timeouts @SC-CONFIG-001
  Scenario: All timeout values come from TimeoutConfig
    When I query timeout configurations
    Then the following timeouts should be defined in a single location:
      | Timeout Type           | Value (ms) | Module        |
      | Health Check           | 10000      | TimeoutConfig |
      | Container Start        | 30000      | TimeoutConfig |
      | Database Connection    | 5000       | TimeoutConfig |
      | Zenoh Session          | 15000      | TimeoutConfig |
      | OODA Cycle             | 100        | TimeoutConfig |
      | FPPS Consensus         | 30000      | TimeoutConfig |
      | Quorum Formation       | 60000      | TimeoutConfig |
      | Boot Total             | 120000     | TimeoutConfig |
    And no hardcoded timeout values should exist in boot code

  # ============================================================================
  # Configuration Consistency
  # ============================================================================

  @consistency @elixir-fsharp @SC-CONFIG-003
  Scenario: F# and Elixir configurations are synchronized
    Given MeshConfig.fs defines the F# configuration
    And Indrajaal.Startup.Config defines the Elixir configuration
    When I compare the two configurations
    Then all port numbers should match
    And all IP addresses should match
    And all timeout values should match
    And all hostname values should match

  @single-change @SC-CONFIG-003
  Scenario: Single location change propagates system-wide
    Given I want to change the Phoenix port from 4000 to 4100
    When I update NetworkConfig.Ports.phoenixPrimary
    Then only 1 file should be modified (MeshConfig.fs)
    And all boot scripts should use the new port
    And all health checks should use the new port
    And no search-and-replace should be needed

  # ============================================================================
  # State Vector Configuration
  # ============================================================================

  @state-vector @SC-CONFIG-001
  Scenario: State vector type is centrally defined
    When I check the state vector definition
    Then the StateVector type should be defined in MeshConfig.fs
    And the type should have exactly 6 components:
      | Component   | Type            | Purpose           |
      | Compile     | StateComponent  | F# build status   |
      | Migrations  | StateComponent  | DB migration status|
      | Containers  | StateComponent  | Infrastructure    |
      | Zenoh       | StateComponent  | Mesh formation    |
      | Health      | StateComponent  | App health        |
      | Quorum      | StateComponent  | Cluster consensus |
    And the validity predicate should be defined

  # ============================================================================
  # STAMP Constraint Configuration
  # ============================================================================

  @stamp @SC-CONFIG-001
  Scenario: STAMP constraints are centrally documented
    When I check the STAMP constraint configuration
    Then the following constraints should be defined:
      | ID             | Severity  | Description                    |
      | SC-BOOT-001    | CRITICAL  | State vector verification      |
      | SC-BOOT-002    | CRITICAL  | Migration check before S3      |
      | SC-BOOT-003    | CRITICAL  | Quorum before S3               |
      | SC-BOOT-004    | CRITICAL  | Transactional boot             |
      | SC-BOOT-005    | HIGH      | Boot time < 120s               |
      | SC-CONFIG-001  | CRITICAL  | Single location config         |
      | SC-CONFIG-002  | HIGH      | No magic values                |
      | SC-CONFIG-003  | HIGH      | Single change point            |

  # ============================================================================
  # FMEA Configuration
  # ============================================================================

  @fmea @SC-CONFIG-001
  Scenario: FMEA failure modes are centrally defined
    When I check the FMEA configuration
    Then the following failure modes should be defined:
      | Failure Mode      | Severity | Occurrence | Detection | RPN | Gate |
      | SDK not installed | 8        | 3          | 9         | 216 | G1   |
      | F# syntax error   | 7        | 4          | 9         | 252 | G2   |
      | Missing migrations| 9        | 5          | 6         | 270 | G3   |
      | Container unhealthy| 8       | 4          | 7         | 224 | G4   |
      | Quorum failure    | 9        | 3          | 7         | 189 | G5   |
      | Oban crash        | 9        | 5          | 5         | 225 | G6   |
      | FPPS disagree     | 7        | 2          | 8         | 112 | G7   |
    And RPN values should match the mathematical formula: RPN = S × O × D

  # ============================================================================
  # Boot Stage Configuration
  # ============================================================================

  @boot-stages @SC-CONFIG-001
  Scenario: Boot stages are centrally defined
    When I check the boot stage configuration
    Then the following stages should be defined:
      | Stage              | Order | Description                    |
      | S0_PREFLIGHT       | 0     | Environment validation         |
      | S1_INFRASTRUCTURE  | 1     | DB + Observability             |
      | S2_ZENOH_MESH      | 2     | Control plane formation        |
      | S3_APP_SEED        | 3     | Application bootstrap          |
      | S4_HOMEOSTASIS     | 4     | Health verification            |
    And stage dependencies should be implicit in order

  # ============================================================================
  # Quorum Configuration
  # ============================================================================

  @quorum @SC-SIL4-011
  Scenario: Quorum configuration is centrally defined
    When I check the quorum configuration
    Then the following should be defined:
      | Parameter         | Value | Formula              |
      | Router count      | 3     | N                    |
      | Minimum healthy   | 2     | floor(N/2) + 1       |
      | Voting mode       | 2oo3  | 2-out-of-3           |
      | Byzantine tolerance| 0    | floor((N-1)/3)       |
    And the quorum formula should be mathematically correct

  # ============================================================================
  # Network Configuration
  # ============================================================================

  @networks @SC-CONFIG-001
  Scenario: Network configuration is centrally defined
    When I check the network configuration
    Then the following networks should be defined:
      | Network    | CIDR          | Purpose         |
      | external   | 172.28.0.0/16 | Public access   |
      | internal   | 172.29.0.0/16 | Inter-container |
    And all container network assignments should reference this config
