/// Cepaf.IndrajaalTest.Config
/// Configuration management for Indrajaal external interface testing
///
/// STAMP Constraints:
/// - SC-CONFIG-001: Configuration must be immutable after initialization
/// - SC-CONFIG-002: Sensitive data must not be logged
module Cepaf.IndrajaalTest.Config

open System
open Cepaf.IndrajaalTest.Types

// =============================================================================
// Default Configurations
// =============================================================================

/// Default development configuration
let defaultDevConfig: ServerConfig = {
    BaseUrl = "http://localhost:4000"
    WebSocketUrl = "ws://localhost:4000/mobile/socket"
    Port = 4000
    UseSsl = false
    Timeout = TimeSpan.FromSeconds(30.0)
    Environment = Development
}

/// Default staging configuration
let defaultStagingConfig: ServerConfig = {
    BaseUrl = "https://staging.indrajaal.local:4000"
    WebSocketUrl = "wss://staging.indrajaal.local:4000/mobile/socket"
    Port = 4000
    UseSsl = true
    Timeout = TimeSpan.FromSeconds(30.0)
    Environment = Staging
}

/// Default test credentials
let defaultTestCredentials: TestCredentials = {
    Username = "test@indrajaal.local"
    Password = "TestPassword123!"
    TenantId = "test-tenant-001"
    DeviceId = Some "test-device-001"
}

// =============================================================================
// Configuration Builder
// =============================================================================

/// Build server config from environment variables
let fromEnvironment () : ServerConfig =
    let getEnvOrDefault key defaultValue =
        match Environment.GetEnvironmentVariable(key) with
        | null | "" -> defaultValue
        | value -> value

    let getEnvIntOrDefault key defaultValue =
        match Environment.GetEnvironmentVariable(key) with
        | null | "" -> defaultValue
        | value ->
            match Int32.TryParse(value) with
            | true, v -> v
            | false, _ -> defaultValue

    let baseUrl = getEnvOrDefault "INDRAJAAL_BASE_URL" "http://localhost:4000"
    let port = getEnvIntOrDefault "INDRAJAAL_PORT" 4000
    let useSsl =
        match getEnvOrDefault "INDRAJAAL_USE_SSL" "false" with
        | "true" | "1" | "yes" -> true
        | _ -> false

    let wsProtocol = if useSsl then "wss" else "ws"
    let host = Uri(baseUrl).Host

    {
        BaseUrl = baseUrl
        WebSocketUrl = sprintf "%s://%s:%d/mobile/socket" wsProtocol host port
        Port = port
        UseSsl = useSsl
        Timeout = TimeSpan.FromSeconds(float (getEnvIntOrDefault "INDRAJAAL_TIMEOUT_SECONDS" 30))
        Environment =
            match getEnvOrDefault "INDRAJAAL_ENV" "development" with
            | "staging" -> Staging
            | "production" -> Production
            | "development" -> Development
            | custom -> Custom custom
    }

/// Build test credentials from environment variables
let credentialsFromEnvironment () : TestCredentials =
    let getEnvOrDefault key defaultValue =
        match Environment.GetEnvironmentVariable(key) with
        | null | "" -> defaultValue
        | value -> value

    {
        Username = getEnvOrDefault "INDRAJAAL_TEST_USER" "test@indrajaal.local"
        Password = getEnvOrDefault "INDRAJAAL_TEST_PASSWORD" "TestPassword123!"
        TenantId = getEnvOrDefault "INDRAJAAL_TEST_TENANT" "test-tenant-001"
        DeviceId =
            match Environment.GetEnvironmentVariable("INDRAJAAL_TEST_DEVICE") with
            | null | "" -> None
            | value -> Some value
    }

// =============================================================================
// Test Session Management
// =============================================================================

/// Create a new test session
let createSession (config: ServerConfig) (credentials: TestCredentials) : TestSession = {
    Config = config
    Credentials = credentials
    Token = None
    StartedAt = DateTime.UtcNow
    TestCount = 0
    PassedCount = 0
    FailedCount = 0
}

/// Update session with test result
let updateSession (passed: bool) (session: TestSession) : TestSession =
    { session with
        TestCount = session.TestCount + 1
        PassedCount = if passed then session.PassedCount + 1 else session.PassedCount
        FailedCount = if not passed then session.FailedCount + 1 else session.FailedCount
    }

/// Set session token
let setToken (token: TokenResponse) (session: TestSession) : TestSession =
    { session with Token = Some token }

// =============================================================================
// Endpoint Definitions
// =============================================================================

/// API endpoint paths
module Endpoints =

    /// Health check endpoints
    module Health =
        let healthz = "/healthz"
        let ready = "/ready"
        let startup = "/startup"
        let health = "/health"

    /// Authentication endpoints
    module Auth =
        let login = "/api/mobile/auth/login"
        let loginBiometric = "/api/mobile/auth/login/biometric"
        let refresh = "/api/mobile/auth/refresh"
        let logout = "/api/mobile/auth/logout"
        let session = "/api/mobile/auth/session"
        let mfaVerify = "/api/mobile/auth/mfa/verify"
        let mfaEnroll = "/api/mobile/auth/mfa/enroll"
        let passwordReset = "/api/mobile/auth/password/reset"

    /// Alarm endpoints
    module Alarms =
        let list = "/api/mobile/alarms"
        let get id = sprintf "/api/mobile/alarms/%s" id
        let acknowledge id = sprintf "/api/mobile/alarms/%s/acknowledge" id
        let resolve id = sprintf "/api/mobile/alarms/%s/resolve" id
        let escalate id = sprintf "/api/mobile/alarms/%s/escalate" id

    /// Alarm configuration endpoints
    module AlarmConfig =
        let types = "/api/mobile/config/alarms/types"
        let rules = "/api/mobile/config/alarms/rules"
        let workflows = "/api/mobile/config/alarms/workflows"
        let escalationPolicies = "/api/mobile/config/alarms/escalation-policies"
        let templates = "/api/mobile/config/alarms/templates"
        let bulk = "/api/mobile/config/alarms/bulk"
        let export = "/api/mobile/config/alarms/export"
        let import = "/api/mobile/config/alarms/import"

    /// Device endpoints
    module Devices =
        let list = "/api/mobile/devices"
        let get id = sprintf "/api/mobile/config/devices/%s" id
        let create = "/api/mobile/config/devices"
        let update id = sprintf "/api/mobile/config/devices/%s" id
        let delete id = sprintf "/api/mobile/config/devices/%s" id
        let types = "/api/mobile/config/devices/types"
        let register = "/api/mobile/config/devices/register"
        let parameters id = sprintf "/api/mobile/config/devices/%s/parameters" id
        let firmwareUpdate id = sprintf "/api/mobile/config/devices/%s/firmware-update" id

    /// Site endpoints
    module Sites =
        let list = "/api/mobile/sites"
        let get id = sprintf "/api/mobile/config/sites/%s" id
        let create = "/api/mobile/config/sites"
        let locations siteId = sprintf "/api/mobile/config/sites/%s/locations" siteId
        let zones siteId = sprintf "/api/mobile/config/sites/%s/zones" siteId
        let mapUpload id = sprintf "/api/mobile/config/sites/%s/maps/upload" id
        let operatingHours id = sprintf "/api/mobile/config/sites/%s/operating-hours" id

    /// Video endpoints
    module Video =
        let list = "/api/mobile/config/video"
        let streams = "/api/mobile/config/video/streams"
        let analytics = "/api/mobile/config/video/analytics"
        let recordingPolicies = "/api/mobile/config/video/recording-policies"
        let retentionPolicies = "/api/mobile/config/video/retention-policies"
        let privacyMasks = "/api/mobile/config/video/privacy-masks"

    /// Batch endpoints
    module Batch =
        let get = "/api/mobile/batch/get"
        let create = "/api/mobile/batch/create"
        let update = "/api/mobile/batch/update"
        let acknowledge = "/api/mobile/batch/acknowledge"
        let sync = "/api/mobile/batch/sync"

    /// Analytics endpoints
    module Analytics =
        let stampTdgGde = "/api/v1/analytics/stamp-tdg-gde"
        let realTime = "/api/v1/analytics/real-time"
        let historical = "/api/v1/analytics/historical"
        let predictions = "/api/v1/analytics/predictions"
        let anomalies = "/api/v1/analytics/anomalies"
        let benchmarks = "/api/v1/analytics/benchmarks"
        let export = "/api/v1/analytics/export"
        let health = "/api/v1/health"

    /// Dashboard
    module Dashboard =
        let mobile = "/api/mobile/dashboard"

    /// Notifications
    module Notifications =
        let register = "/api/mobile/notifications/register"
        let preferences = "/api/mobile/notifications/preferences"

/// WebSocket channel topics
module Channels =
    let alarmTenant tenantId = sprintf "alarm:tenant:%s" tenantId
    let alarm alarmId = sprintf "alarm:%s" alarmId
    let device deviceId = sprintf "device:%s" deviceId
    let site siteId = sprintf "site:%s" siteId
    let config resourceType = sprintf "config:%s" resourceType
    let notification userId = sprintf "notification:%s" userId
    let videoTenant tenantId = sprintf "video:tenant:%s" tenantId
    let videoStream streamId = sprintf "video:stream:%s" streamId
    let videoCamera cameraId = sprintf "video:camera:%s" cameraId
    let sync deviceId = sprintf "sync:%s" deviceId
    let patrol patrolId = sprintf "patrol:%s" patrolId

/// LiveView page paths
module Pages =
    let home = "/"
    let analyticsStampTdgGde = "/analytics/stamp-tdg-gde-advanced"
    let analyticsDashboard = "/analytics/dashboard"
    let performance = "/performance"
    let monitoring = "/monitoring"

    module Cockpit =
        let main = "/cockpit"
        let dashboard = "/cockpit/dashboard"
        let startup = "/cockpit/startup"
        let containers = "/cockpit/containers"
        let commands = "/cockpit/commands"
        let mesh = "/cockpit/mesh"
        let alarms = "/cockpit/alarms"
        let aiCopilot = "/cockpit/ai-copilot"
        let cluster = "/cockpit/cluster"
        let settings = "/cockpit/settings"
        let diagnostics = "/cockpit/diagnostics"
        let shutdown = "/cockpit/shutdown"
        let observability = "/cockpit/observability"

    module Operations =
        let alarms = "/operations/alarms"
        let alarmDetail id = sprintf "/operations/alarms/%s" id
        let access = "/operations/access"
        let video = "/operations/video"
        let dispatch = "/operations/dispatch"

    module Admin =
        let permissions = "/admin/permissions"
        let accessControl = "/admin/access_control"
        let config = "/admin/config"
        let systemStatus = "/admin/system-status"
