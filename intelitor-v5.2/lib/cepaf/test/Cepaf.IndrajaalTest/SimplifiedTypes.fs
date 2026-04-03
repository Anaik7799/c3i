/// Cepaf.IndrajaalTest.Types
/// Simplified types for external interface testing
///
/// STAMP Constraints:
/// - SC-TEST-001: Type definitions must be complete
/// - SC-TEST-002: All fields must be documented
module Cepaf.IndrajaalTest.Types

open System

// =============================================================================
// Server Configuration
// =============================================================================

/// Environment type for deployment targeting
type Environment =
    | Development
    | Staging
    | Production

/// Server configuration for test targeting
type ServerConfig = {
    Host: string
    Port: int
    UseSsl: bool
    Timeout: TimeSpan
    Environment: Environment
}
with
    member this.BaseUrl =
        let scheme = if this.UseSsl then "https" else "http"
        sprintf "%s://%s:%d" scheme this.Host this.Port

    member this.WebSocketUrl =
        let scheme = if this.UseSsl then "wss" else "ws"
        sprintf "%s://%s:%d/socket/websocket" scheme this.Host this.Port

/// Test credentials
type TestCredentials = {
    Username: string
    Password: string
    DeviceId: string
}

// =============================================================================
// API Response Types
// =============================================================================

/// Generic API response wrapper
type ApiResponse<'T> = {
    Success: bool
    StatusCode: int
    Data: 'T option
    Error: string option
    Headers: Map<string, string>
    ElapsedMs: int64
}

/// Health check response
type HealthResponse = {
    Status: string
    Version: string option
    Uptime: int64 option
}

/// Authentication response
type AuthResponse = {
    AccessToken: string
    RefreshToken: string
    ExpiresIn: int
    TokenType: string
}

/// Pagination info
type Pagination = {
    Page: int
    PageSize: int
    TotalCount: int
    TotalPages: int
}

/// List response with pagination
type ListResponse<'T> = {
    Items: 'T list
    Pagination: Pagination option
}

// =============================================================================
// API Endpoints
// =============================================================================

/// All API endpoint paths
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
        let refresh = "/api/mobile/auth/refresh"
        let logout = "/api/mobile/auth/logout"
        let verify = "/api/mobile/auth/verify"
        let forgotPassword = "/api/mobile/auth/forgot-password"
        let resetPassword = "/api/mobile/auth/reset-password"

    /// Alarm endpoints
    module Alarms =
        let list = "/api/mobile/alarms"
        let get id = sprintf "/api/mobile/alarms/%s" id
        let acknowledge id = sprintf "/api/mobile/alarms/%s/acknowledge" id
        let resolve id = sprintf "/api/mobile/alarms/%s/resolve" id
        let escalate id = sprintf "/api/mobile/alarms/%s/escalate" id

    /// Device endpoints
    module Devices =
        let list = "/api/mobile/devices"
        let get id = sprintf "/api/mobile/devices/%s" id
        let status id = sprintf "/api/mobile/devices/%s/status" id
        let command id = sprintf "/api/mobile/devices/%s/command" id

    /// Site endpoints
    module Sites =
        let list = "/api/mobile/sites"
        let get id = sprintf "/api/mobile/sites/%s" id
        let zones id = sprintf "/api/mobile/sites/%s/zones" id
        let accessPoints id = sprintf "/api/mobile/sites/%s/access-points" id

    /// Video endpoints
    module Video =
        let streams = "/api/mobile/video/streams"
        let getStream id = sprintf "/api/mobile/video/streams/%s" id
        let cameras = "/api/mobile/video/cameras"
        let getCamera id = sprintf "/api/mobile/video/cameras/%s" id
        let recordings = "/api/mobile/video/recordings"

    /// Configuration endpoints
    module Config =
        let alarmTypes = "/api/mobile/config/alarms/types"
        let alarmRules = "/api/mobile/config/alarms/rules"
        let workflows = "/api/mobile/config/alarms/workflows"
        let escalationPolicies = "/api/mobile/config/alarms/escalation-policies"
        let templates = "/api/mobile/config/alarms/templates"

    /// Batch operation endpoints
    module Batch =
        let get = "/api/mobile/batch/get"
        let create = "/api/mobile/batch/create"
        let update = "/api/mobile/batch/update"
        let acknowledge = "/api/mobile/batch/acknowledge"
        let sync = "/api/mobile/batch/sync"

    /// Analytics endpoints
    module Analytics =
        let dashboard = "/api/mobile/analytics/dashboard"
        let alarmStats = "/api/mobile/analytics/alarms"
        let deviceStats = "/api/mobile/analytics/devices"
        let siteStats = "/api/mobile/analytics/sites"
        let reports = "/api/mobile/analytics/reports"

    /// WebSocket/Channel topics
    module Channels =
        let alarm = "alarm:lobby"
        let device = "device:lobby"
        let site = "site:lobby"
        let notification = "notification:lobby"
        let presence = "presence:lobby"
        let dashboard = "dashboard:lobby"
        let video = "video:lobby"
        let command = "command:lobby"

    /// LiveView pages
    module Pages =
        let dashboard = "/dashboard"
        let alarms = "/alarms"
        let devices = "/devices"
        let sites = "/sites"
        let video = "/video"
        let analytics = "/analytics"
        let settings = "/settings"
        let users = "/users"
        let profile = "/profile"
        let login = "/login"

// =============================================================================
// Default Configurations
// =============================================================================

/// Default development configuration
let defaultDevConfig: ServerConfig = {
    Host = "localhost"
    Port = 4000
    UseSsl = false
    Timeout = TimeSpan.FromSeconds(30.0)
    Environment = Development
}

/// Default staging configuration
let defaultStagingConfig: ServerConfig = {
    Host = "staging.indrajaal.local"
    Port = 443
    UseSsl = true
    Timeout = TimeSpan.FromSeconds(30.0)
    Environment = Staging
}

/// Default test credentials
let defaultTestCredentials: TestCredentials = {
    Username = "test@indrajaal.com"
    Password = "test123"
    DeviceId = "test-device-001"
}

/// Load configuration from environment
let fromEnvironment () : ServerConfig =
    let host = Environment.GetEnvironmentVariable("INDRAJAAL_HOST") |> Option.ofObj |> Option.defaultValue "localhost"
    let port =
        Environment.GetEnvironmentVariable("INDRAJAAL_PORT")
        |> Option.ofObj
        |> Option.bind (fun s -> match Int32.TryParse(s) with | true, v -> Some v | _ -> None)
        |> Option.defaultValue 4000
    let useSsl =
        Environment.GetEnvironmentVariable("INDRAJAAL_SSL")
        |> Option.ofObj
        |> Option.map (fun s -> s.ToLowerInvariant() = "true")
        |> Option.defaultValue false
    let timeout =
        Environment.GetEnvironmentVariable("INDRAJAAL_TIMEOUT")
        |> Option.ofObj
        |> Option.bind (fun s -> match Int32.TryParse(s) with | true, v -> Some v | _ -> None)
        |> Option.defaultValue 30
    {
        Host = host
        Port = port
        UseSsl = useSsl
        Timeout = TimeSpan.FromSeconds(float timeout)
        Environment = Development
    }

/// Load credentials from environment
let credentialsFromEnvironment () : TestCredentials =
    let username = Environment.GetEnvironmentVariable("INDRAJAAL_TEST_USER") |> Option.ofObj |> Option.defaultValue "test@indrajaal.com"
    let password = Environment.GetEnvironmentVariable("INDRAJAAL_TEST_PASS") |> Option.ofObj |> Option.defaultValue "test123"
    let deviceId = Environment.GetEnvironmentVariable("INDRAJAAL_TEST_DEVICE") |> Option.ofObj |> Option.defaultValue "test-device-001"
    {
        Username = username
        Password = password
        DeviceId = deviceId
    }
