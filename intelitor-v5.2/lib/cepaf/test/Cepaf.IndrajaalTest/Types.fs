/// Cepaf.IndrajaalTest.Types
/// Common types and domain models for Indrajaal external interface testing
///
/// STAMP Constraints:
/// - SC-TEST-001: All test types must be immutable
/// - SC-TEST-002: Use Result types for fallible operations
/// - SC-API-001: Validate tenant isolation in all requests
module Cepaf.IndrajaalTest.Types

open System

// =============================================================================
// Test Configuration Types
// =============================================================================

/// Test environment configuration
type TestEnvironment =
    | Development
    | Staging
    | Production
    | Custom of string

/// Indrajaal server configuration
type ServerConfig = {
    BaseUrl: string
    WebSocketUrl: string
    Port: int
    UseSsl: bool
    Timeout: TimeSpan
    Environment: TestEnvironment
}

/// Authentication credentials for testing
type TestCredentials = {
    Username: string
    Password: string
    TenantId: string
    DeviceId: string option
}

/// JWT token response
type TokenResponse = {
    AccessToken: string
    RefreshToken: string
    ExpiresIn: int
    TokenType: string
}

/// Test session state
type TestSession = {
    Config: ServerConfig
    Credentials: TestCredentials
    Token: TokenResponse option
    StartedAt: DateTime
    TestCount: int
    PassedCount: int
    FailedCount: int
}

// =============================================================================
// Health Check Types
// =============================================================================

/// Health check status
type HealthStatus =
    | Healthy
    | Unhealthy
    | Degraded
    | Unknown

/// Individual component health
type ComponentHealth = {
    Name: string
    Status: HealthStatus
    Message: string option
    Duration: TimeSpan option
}

/// Health check response
type HealthResponse = {
    Status: HealthStatus
    Timestamp: DateTime
    Checks: ComponentHealth list
    Version: string option
}

// =============================================================================
// API Response Types
// =============================================================================

/// Generic API response wrapper
type ApiResponse<'T> = {
    Success: bool
    Data: 'T option
    Error: string option
    StatusCode: int
    Headers: Map<string, string>
    Duration: TimeSpan
}

/// Pagination info
type PaginationInfo = {
    Page: int
    PageSize: int
    TotalCount: int
    TotalPages: int
    HasNext: bool
    HasPrevious: bool
}

/// Paginated response
type PaginatedResponse<'T> = {
    Items: 'T list
    Pagination: PaginationInfo
}

// =============================================================================
// Alarm Types
// =============================================================================

/// Alarm severity levels
type AlarmSeverity =
    | Critical
    | High
    | Medium
    | Low
    | Info

/// Alarm status
type AlarmStatus =
    | Active
    | Acknowledged
    | Resolved
    | Escalated

/// Alarm data
type Alarm = {
    Id: Guid
    TenantId: string
    DeviceId: string option
    SiteId: string option
    Severity: AlarmSeverity
    Status: AlarmStatus
    Title: string
    Description: string option
    CreatedAt: DateTime
    UpdatedAt: DateTime
    AcknowledgedAt: DateTime option
    ResolvedAt: DateTime option
    AcknowledgedBy: string option
    ResolvedBy: string option
}

// =============================================================================
// Device Types
// =============================================================================

/// Device status
type DeviceStatus =
    | Online
    | Offline
    | Maintenance
    | Error
    | Unknown

/// Device type
type DeviceType =
    | Camera
    | Sensor
    | Controller
    | Panel
    | Reader
    | Other of string

/// Device data
type Device = {
    Id: Guid
    TenantId: string
    SiteId: string option
    Name: string
    DeviceType: DeviceType
    Status: DeviceStatus
    IpAddress: string option
    MacAddress: string option
    FirmwareVersion: string option
    LastSeen: DateTime option
}

// =============================================================================
// Site Types
// =============================================================================

/// Site data
type Site = {
    Id: Guid
    TenantId: string
    Name: string
    Address: string option
    Latitude: float option
    Longitude: float option
    TimeZone: string
    IsActive: bool
}

/// Location within a site
type Location = {
    Id: Guid
    SiteId: Guid
    Name: string
    Floor: int option
    Description: string option
}

// =============================================================================
// WebSocket/Channel Types
// =============================================================================

/// Channel join result
type ChannelJoinResult =
    | Joined of payload: Map<string, obj>
    | Denied of reason: string
    | Timeout
    | Error of exn

/// Channel message
type ChannelMessage = {
    Topic: string
    Event: string
    Payload: Map<string, obj>
    Ref: string option
    JoinRef: string option
}

/// Channel event types
type ChannelEvent =
    | AlarmCreated of Alarm
    | AlarmUpdated of Alarm
    | AlarmResolved of Alarm
    | AlarmEscalated of Alarm
    | DeviceStatusChanged of Device
    | NotificationReceived of Map<string, obj>
    | Custom of event: string * payload: Map<string, obj>

// =============================================================================
// Test Result Types
// =============================================================================

/// Individual test result
type TestResult = {
    Name: string
    Category: string
    Passed: bool
    Duration: TimeSpan
    Error: string option
    StackTrace: string option
    Timestamp: DateTime
}

/// Test suite result
type TestSuiteResult = {
    SuiteName: string
    Tests: TestResult list
    TotalTests: int
    Passed: int
    Failed: int
    Skipped: int
    Duration: TimeSpan
    StartedAt: DateTime
    CompletedAt: DateTime
}

/// Test run summary
type TestRunSummary = {
    Suites: TestSuiteResult list
    TotalSuites: int
    TotalTests: int
    TotalPassed: int
    TotalFailed: int
    TotalSkipped: int
    TotalDuration: TimeSpan
    Environment: TestEnvironment
    ServerUrl: string
}

// =============================================================================
// Error Types
// =============================================================================

/// Test error types
type TestError =
    | ConnectionError of message: string
    | AuthenticationError of message: string
    | AuthorizationError of message: string
    | ValidationError of field: string * message: string
    | NotFoundError of resource: string
    | TimeoutError of operation: string * timeout: TimeSpan
    | ServerError of statusCode: int * message: string
    | ParseError of message: string
    | UnexpectedError of exn

/// Result alias for tests
type TestOperationResult<'T> = Result<'T, TestError>

// =============================================================================
// STAMP Constraint Validation Types
// =============================================================================

/// STAMP constraint check result
type ConstraintCheckResult = {
    ConstraintId: string
    Description: string
    Passed: bool
    Details: string option
}

/// API contract validation
type ContractValidation = {
    Endpoint: string
    Method: string
    ExpectedStatusCode: int
    ActualStatusCode: int
    ResponseTimeMs: float
    MaxResponseTimeMs: float
    Passed: bool
}
