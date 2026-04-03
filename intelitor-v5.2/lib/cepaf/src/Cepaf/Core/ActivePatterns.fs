/// CEPAF Active Patterns Module
/// Provides domain-specific pattern matching abstractions for semantic code.
///
/// WHAT: Active patterns for error classification, status evaluation, and domain modeling
/// WHY: Enables declarative, self-documenting pattern matching without exposing implementation
/// CONSTRAINTS: SC-FSH-003 (Active Patterns for Classification), AOR-FSH-001
///
/// STAMP Compliance: SC-FSH-003, SC-FSH-002
/// Version: 1.0.0
module Cepaf.Core.ActivePatterns

open System
open Cepaf.Podman.Domain

// ============================================================================
// ERROR CLASSIFICATION PATTERNS
// ============================================================================

/// Classify errors by recoverability for retry/halt decisions
/// SC-FSH-003: Active pattern for error classification
[<RequireQualifiedAccess>]
module ErrorRecoverability =

    /// Errors that can be recovered by retrying the operation
    let (|Recoverable|Transient|Fatal|) (error: PodmanError) =
        match error with
        // Transient: External conditions that may improve with retry
        | PodmanError.ConnectionTimeout _ -> Transient
        | PodmanError.ConnectionRefused _ -> Transient

        // Fatal: Violations that require immediate halt (STAMP critical)
        | PodmanError.SafetyConstraintViolation _ -> Fatal
        | PodmanError.ValidationFailed _ -> Fatal
        | PodmanError.RegistryNotAllowed _ -> Fatal

        // Recoverable: User/operator can fix and retry
        | PodmanError.ContainerNotFound _ -> Recoverable
        | PodmanError.ImageNotFound _ -> Recoverable
        | PodmanError.VolumeNotFound _ -> Recoverable
        | PodmanError.NetworkNotFound _ -> Recoverable
        | PodmanError.PodNotFound _ -> Recoverable
        | PodmanError.ContainerNotRunning _ -> Recoverable
        | PodmanError.InvalidParameter _ -> Recoverable
        | PodmanError.BadRequest _ -> Recoverable

        // API errors: 5xx are transient, others recoverable
        | PodmanError.ApiError (code, _) when code >= 500 && code < 600 -> Transient

        // Default classification based on retryable check
        | _ when PodmanError.isRetryable error -> Transient
        | _ -> Recoverable


/// Classify errors by domain for routing and logging
[<RequireQualifiedAccess>]
module ErrorDomain =

    /// Domain-based error classification for targeted handling
    let (|NetworkError|ResourceError|SafetyError|ConfigError|SystemError|) (error: PodmanError) =
        match error with
        // Network: Connectivity and communication issues
        | PodmanError.SocketNotFound _ -> NetworkError
        | PodmanError.ConnectionRefused _ -> NetworkError
        | PodmanError.ConnectionTimeout _ -> NetworkError

        // Resource: Missing or conflicting resources
        | PodmanError.ContainerNotFound _ -> ResourceError
        | PodmanError.ContainerAlreadyExists _ -> ResourceError
        | PodmanError.ContainerAlreadyStopped _ -> ResourceError
        | PodmanError.ImageNotFound _ -> ResourceError
        | PodmanError.ImagePullFailed _ -> ResourceError
        | PodmanError.VolumeNotFound _ -> ResourceError
        | PodmanError.VolumeInUse _ -> ResourceError
        | PodmanError.VolumeAlreadyExists _ -> ResourceError
        | PodmanError.NetworkNotFound _ -> ResourceError
        | PodmanError.NetworkInUse _ -> ResourceError
        | PodmanError.NetworkAlreadyExists _ -> ResourceError
        | PodmanError.PodNotFound _ -> ResourceError
        | PodmanError.PodAlreadyExists _ -> ResourceError

        // Safety: STAMP violations and health failures
        | PodmanError.SafetyConstraintViolation _ -> SafetyError
        | PodmanError.HealthCheckFailed _ -> SafetyError
        | PodmanError.HealthCheckTimeout _ -> SafetyError
        | PodmanError.ValidationFailed _ -> SafetyError

        // Config: Invalid parameters or requests
        | PodmanError.InvalidParameter _ -> ConfigError
        | PodmanError.BadRequest _ -> ConfigError
        | PodmanError.NotFound _ -> ConfigError
        | PodmanError.Conflict _ -> ConfigError
        | PodmanError.RegistryNotAllowed _ -> ConfigError

        // System: Internal errors and unexpected conditions
        | _ -> SystemError


/// Classify errors by severity for logging and alerting
[<RequireQualifiedAccess>]
module ErrorSeverity =

    /// Severity levels aligned with observability standards
    type Severity =
        | Critical  // Immediate action required, potential system halt
        | High      // Action required soon, degraded operation
        | Medium    // Should be addressed, normal operation continues
        | Low       // Informational, no immediate action needed

    let (|CriticalError|HighError|MediumError|LowError|) (error: PodmanError) =
        match error with
        // Critical: STAMP violations, safety failures
        | PodmanError.SafetyConstraintViolation _ -> CriticalError
        | PodmanError.ValidationFailed _ -> CriticalError

        // High: Health failures, start failures, connection issues
        | PodmanError.HealthCheckFailed _ -> HighError
        | PodmanError.HealthCheckTimeout _ -> HighError
        | PodmanError.ContainerStartFailed _ -> HighError
        | PodmanError.ImagePullFailed _ -> HighError
        | PodmanError.ImageBuildFailed _ -> HighError
        | PodmanError.ConnectionRefused _ -> HighError
        | PodmanError.ConnectionTimeout _ -> HighError
        | PodmanError.ApiError (code, _) when code >= 500 -> HighError

        // Medium: Resource conflicts, not found errors
        | PodmanError.ContainerNotFound _ -> MediumError
        | PodmanError.ImageNotFound _ -> MediumError
        | PodmanError.VolumeNotFound _ -> MediumError
        | PodmanError.NetworkNotFound _ -> MediumError
        | PodmanError.Conflict _ -> MediumError
        | PodmanError.NotFound _ -> MediumError

        // Low: Configuration issues, informational
        | _ -> LowError


// ============================================================================
// HEALTH STATUS PATTERNS
// ============================================================================

/// Health status classification for operational decisions
[<RequireQualifiedAccess>]
module HealthClassification =

    /// Operational health classification
    let (|Operational|Degraded|Failed|Unknown|) (status: HealthStatus) =
        match status with
        | HealthStatus.Healthy -> Operational
        | HealthStatus.Starting -> Degraded
        | HealthStatus.Unhealthy _ -> Failed
        | HealthStatus.NoHealthcheck -> Unknown
        | HealthStatus.Unknown _ -> Unknown


/// Container status classification for lifecycle management
[<RequireQualifiedAccess>]
module ContainerState =

    /// Lifecycle state classification
    let (|Running|Stopped|Transitioning|Error|) (status: ContainerStatus) =
        match status with
        | ContainerStatus.Running -> Running
        | ContainerStatus.Exited _ -> Stopped
        | ContainerStatus.Dead _ -> Stopped
        | ContainerStatus.Created -> Transitioning
        | ContainerStatus.Paused -> Transitioning
        | ContainerStatus.Restarting -> Transitioning
        | ContainerStatus.Removing -> Transitioning
        | ContainerStatus.Unknown _ -> Error


// ============================================================================
// STRING PARSING PATTERNS
// ============================================================================

/// Active patterns for parsing common string formats
[<RequireQualifiedAccess>]
module StringParsing =

    /// Parse integer from string
    let (|Int|_|) (str: string) =
        match Int32.TryParse(str) with
        | true, value -> Some value
        | false, _ -> None

    /// Parse int64 from string
    let (|Int64|_|) (str: string) =
        match Int64.TryParse(str) with
        | true, value -> Some value
        | false, _ -> None

    /// Parse float from string
    let (|Float|_|) (str: string) =
        match Double.TryParse(str) with
        | true, value -> Some value
        | false, _ -> None

    /// Parse boolean from string
    let (|Bool|_|) (str: string) =
        match Boolean.TryParse(str) with
        | true, value -> Some value
        | false, _ -> None

    /// Parse GUID from string
    let (|Guid|_|) (str: string) =
        match Guid.TryParse(str) with
        | true, value -> Some value
        | false, _ -> None

    /// Check if string is null or empty
    let (|NullOrEmpty|NonEmpty|) (str: string) =
        if String.IsNullOrEmpty(str) then NullOrEmpty
        else NonEmpty str

    /// Check if string is null, empty, or whitespace
    let (|NullOrWhitespace|HasContent|) (str: string) =
        if String.IsNullOrWhiteSpace(str) then NullOrWhitespace
        else HasContent (str.Trim())


// ============================================================================
// HTTP STATUS CODE PATTERNS
// ============================================================================

/// HTTP status code classification
[<RequireQualifiedAccess>]
module HttpStatus =

    /// Classify HTTP status codes by category
    let (|Informational|Success|Redirect|ClientError|ServerError|Invalid|) (code: int) =
        match code with
        | c when c >= 100 && c < 200 -> Informational
        | c when c >= 200 && c < 300 -> Success
        | c when c >= 300 && c < 400 -> Redirect
        | c when c >= 400 && c < 500 -> ClientError
        | c when c >= 500 && c < 600 -> ServerError
        | _ -> Invalid

    /// Check for specific common status codes (partial active pattern)
    let (|OK|_|) code = if code = 200 then Some () else None
    let (|NotFound|_|) code = if code = 404 then Some () else None
    let (|BadRequest|_|) code = if code = 400 then Some () else None
    let (|Unauthorized|_|) code = if code = 401 then Some () else None
    let (|Forbidden|_|) code = if code = 403 then Some () else None
    let (|Conflict|_|) code = if code = 409 then Some () else None
    let (|InternalError|_|) code = if code = 500 then Some () else None


// ============================================================================
// RESULT PATTERNS
// ============================================================================

/// Active patterns for Result type
[<RequireQualifiedAccess>]
module ResultPatterns =

    /// Check if result is success with predicate
    let (|OkWhen|_|) predicate result =
        match result with
        | Ok value when predicate value -> Some value
        | _ -> None

    /// Check if result is error with predicate
    let (|ErrorWhen|_|) predicate result =
        match result with
        | Error err when predicate err -> Some err
        | _ -> None


// ============================================================================
// OPTION PATTERNS
// ============================================================================

/// Active patterns for Option type
[<RequireQualifiedAccess>]
module OptionPatterns =

    /// Check if option has value matching predicate
    let (|SomeWhen|_|) predicate opt =
        match opt with
        | Some value when predicate value -> Some value
        | _ -> None

    /// Default value pattern
    let (|ValueOr|) defaultValue opt =
        match opt with
        | Some v -> v
        | None -> defaultValue


// ============================================================================
// CONVENIENCE COMBINATORS
// ============================================================================

/// Compose error classification for comprehensive handling
let classifyError (error: PodmanError) =
    let recoverability =
        match error with
        | ErrorRecoverability.Recoverable -> "Recoverable"
        | ErrorRecoverability.Transient -> "Transient"
        | ErrorRecoverability.Fatal -> "Fatal"

    let domain =
        match error with
        | ErrorDomain.NetworkError -> "Network"
        | ErrorDomain.ResourceError -> "Resource"
        | ErrorDomain.SafetyError -> "Safety"
        | ErrorDomain.ConfigError -> "Config"
        | ErrorDomain.SystemError -> "System"

    let severity =
        match error with
        | ErrorSeverity.CriticalError -> "Critical"
        | ErrorSeverity.HighError -> "High"
        | ErrorSeverity.MediumError -> "Medium"
        | ErrorSeverity.LowError -> "Low"

    {|
        Recoverability = recoverability
        Domain = domain
        Severity = severity
        Message = PodmanError.toMessage error
        IsRetryable = PodmanError.isRetryable error
    |}

/// Get recommended action based on error classification
let getRecommendedAction (error: PodmanError) =
    match error with
    | ErrorRecoverability.Fatal ->
        "HALT: Safety violation detected. Immediate system halt required."
    | ErrorRecoverability.Transient ->
        "RETRY: Transient error. Retry with exponential backoff."
    | ErrorRecoverability.Recoverable ->
        "FIX: Recoverable error. Review configuration and retry."
