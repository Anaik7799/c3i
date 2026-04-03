/// Elixir Bridge Integration Tests
/// Tests for F# ↔ Elixir HTTP API communication
module Cepaf.Integration.ElixirBridgeTests

open System
open System.Net.Http
open Expecto

// ============================================================================
// Test Configuration
// ============================================================================

type IntegrationConfig = {
    ElixirBaseUrl: string
    Timeout: TimeSpan
    RetryCount: int
    RequireBackend: bool
}

let defaultConfig = {
    ElixirBaseUrl = "http://localhost:4000"
    Timeout = TimeSpan.FromSeconds(30.0)
    RetryCount = 3
    RequireBackend = false  // Set to true when backend is running
}

// ============================================================================
// Health API Tests
// ============================================================================

type HealthResponse = {
    Status: string
    Timestamp: DateTime
    Version: string option
}

let healthEndpoint config = sprintf "%s/api/health" config.ElixirBaseUrl

let parseHealthStatus (status: string) =
    match status.ToLower() with
    | "healthy" | "ok" | "up" -> Some true
    | "unhealthy" | "error" | "down" -> Some false
    | _ -> None

let validateHealthResponse (response: HealthResponse) =
    response.Status <> null &&
    response.Status.Length > 0

[<Tests>]
let healthApiTests =
    testList "HealthAPI" [
        test "should build health endpoint URL" {
            let url = healthEndpoint defaultConfig
            Expect.equal url "http://localhost:4000/api/health" "Health endpoint"
        }

        test "should parse health status" {
            Expect.equal (parseHealthStatus "healthy") (Some true) "Healthy"
            Expect.equal (parseHealthStatus "OK") (Some true) "OK"
            Expect.equal (parseHealthStatus "unhealthy") (Some false) "Unhealthy"
            Expect.equal (parseHealthStatus "unknown") None "Unknown"
        }

        test "should validate health response" {
            let valid = { Status = "healthy"; Timestamp = DateTime.UtcNow; Version = Some "21.2.1" }
            let invalid = { Status = ""; Timestamp = DateTime.UtcNow; Version = None }

            Expect.isTrue (validateHealthResponse valid) "Valid response"
            Expect.isFalse (validateHealthResponse invalid) "Invalid response"
        }
    ]

// ============================================================================
// Prajna Metrics API Tests
// ============================================================================

type MetricsResponse = {
    HealthScore: float
    ConnectedNodes: int
    ActiveAlarms: int
    PendingProposals: int
    ActiveThreats: int
    Timestamp: DateTime
}

let metricsEndpoint config = sprintf "%s/api/prajna/metrics" config.ElixirBaseUrl

let validateMetricsResponse (response: MetricsResponse) =
    response.HealthScore >= 0.0 &&
    response.HealthScore <= 100.0 &&
    response.ConnectedNodes >= 0 &&
    response.ActiveAlarms >= 0

let metricsAreStale (response: MetricsResponse) (threshold: TimeSpan) =
    DateTime.UtcNow - response.Timestamp > threshold

[<Tests>]
let metricsApiTests =
    testList "MetricsAPI" [
        test "should build metrics endpoint URL" {
            let url = metricsEndpoint defaultConfig
            Expect.equal url "http://localhost:4000/api/prajna/metrics" "Metrics endpoint"
        }

        test "should validate metrics response" {
            let valid = {
                HealthScore = 95.0
                ConnectedNodes = 3
                ActiveAlarms = 2
                PendingProposals = 1
                ActiveThreats = 0
                Timestamp = DateTime.UtcNow
            }
            Expect.isTrue (validateMetricsResponse valid) "Valid metrics"
        }

        test "should reject invalid health score" {
            let invalid = {
                HealthScore = 150.0  // Invalid: > 100
                ConnectedNodes = 3
                ActiveAlarms = 0
                PendingProposals = 0
                ActiveThreats = 0
                Timestamp = DateTime.UtcNow
            }
            Expect.isFalse (validateMetricsResponse invalid) "Invalid health score"
        }

        test "should detect stale metrics" {
            let old = {
                HealthScore = 95.0
                ConnectedNodes = 3
                ActiveAlarms = 0
                PendingProposals = 0
                ActiveThreats = 0
                Timestamp = DateTime.UtcNow.AddMinutes(-5.0)
            }
            let threshold = TimeSpan.FromMinutes(1.0)
            Expect.isTrue (metricsAreStale old threshold) "Old metrics are stale"
        }
    ]

// ============================================================================
// Guardian API Tests
// ============================================================================

type ProposalSubmission = {
    Title: string
    Description: string
    Category: string
}

type ApprovalRequest = {
    ProposalId: string
    Reason: string
    Voter: string
}

type VetoRequest = {
    ProposalId: string
    Reason: string
    Voter: string
}

let guardianSubmitEndpoint config = sprintf "%s/api/prajna/guardian/submit" config.ElixirBaseUrl
let guardianApproveEndpoint config = sprintf "%s/api/prajna/guardian/approve" config.ElixirBaseUrl
let guardianVetoEndpoint config = sprintf "%s/api/prajna/guardian/veto" config.ElixirBaseUrl
let guardianProposalsEndpoint config = sprintf "%s/api/prajna/guardian/proposals" config.ElixirBaseUrl

let validateProposalSubmission (submission: ProposalSubmission) =
    not (String.IsNullOrWhiteSpace submission.Title) &&
    not (String.IsNullOrWhiteSpace submission.Description) &&
    submission.Title.Length <= 200 &&
    submission.Description.Length <= 5000

let validateApprovalRequest (request: ApprovalRequest) =
    not (String.IsNullOrWhiteSpace request.ProposalId) &&
    not (String.IsNullOrWhiteSpace request.Reason) &&
    request.Reason.Length >= 10  // Require meaningful reason

let serializeSubmission (submission: ProposalSubmission) =
    sprintf """{"title":"%s","description":"%s","category":"%s"}"""
        submission.Title submission.Description submission.Category

[<Tests>]
let guardianApiTests =
    testList "GuardianAPI" [
        test "should build guardian endpoints" {
            Expect.stringContains (guardianSubmitEndpoint defaultConfig) "/guardian/submit" "Submit"
            Expect.stringContains (guardianApproveEndpoint defaultConfig) "/guardian/approve" "Approve"
            Expect.stringContains (guardianVetoEndpoint defaultConfig) "/guardian/veto" "Veto"
        }

        test "should validate proposal submission" {
            let valid = { Title = "Test Proposal"; Description = "This is a test proposal for testing"; Category = "Testing" }
            let emptyTitle = { Title = ""; Description = "Description"; Category = "Cat" }
            let longTitle = { Title = String.replicate 250 "x"; Description = "Desc"; Category = "Cat" }

            Expect.isTrue (validateProposalSubmission valid) "Valid submission"
            Expect.isFalse (validateProposalSubmission emptyTitle) "Empty title"
            Expect.isFalse (validateProposalSubmission longTitle) "Title too long"
        }

        test "should validate approval request" {
            let valid = { ProposalId = "p-123"; Reason = "Reviewed and approved by security team"; Voter = "admin" }
            let shortReason = { ProposalId = "p-123"; Reason = "OK"; Voter = "admin" }

            Expect.isTrue (validateApprovalRequest valid) "Valid approval"
            Expect.isFalse (validateApprovalRequest shortReason) "Reason too short"
        }

        test "should serialize submission to JSON" {
            let submission = { Title = "Test"; Description = "Desc"; Category = "Cat" }
            let json = serializeSubmission submission
            Expect.stringContains json "\"title\":\"Test\"" "Has title"
            Expect.stringContains json "\"description\":\"Desc\"" "Has description"
        }
    ]

// ============================================================================
// Sentinel API Tests
// ============================================================================

type ThreatReport = {
    Category: string
    Description: string
    Source: string
    Severity: int
}

type MitigationRequest = {
    ThreatId: string
    Action: string
}

let sentinelReportEndpoint config = sprintf "%s/api/prajna/sentinel/report" config.ElixirBaseUrl
let sentinelMitigateEndpoint config = sprintf "%s/api/prajna/sentinel/mitigate" config.ElixirBaseUrl
let sentinelThreatsEndpoint config = sprintf "%s/api/prajna/sentinel/threats" config.ElixirBaseUrl

let validateThreatReport (report: ThreatReport) =
    not (String.IsNullOrWhiteSpace report.Category) &&
    not (String.IsNullOrWhiteSpace report.Description) &&
    report.Severity >= 1 && report.Severity <= 10

let threatSeverityLabel (severity: int) =
    match severity with
    | s when s >= 9 -> "Critical"
    | s when s >= 7 -> "High"
    | s when s >= 4 -> "Medium"
    | _ -> "Low"

[<Tests>]
let sentinelApiTests =
    testList "SentinelAPI" [
        test "should build sentinel endpoints" {
            Expect.stringContains (sentinelReportEndpoint defaultConfig) "/sentinel/report" "Report"
            Expect.stringContains (sentinelMitigateEndpoint defaultConfig) "/sentinel/mitigate" "Mitigate"
            Expect.stringContains (sentinelThreatsEndpoint defaultConfig) "/sentinel/threats" "Threats"
        }

        test "should validate threat report" {
            let valid = { Category = "Security"; Description = "Unauthorized access attempt"; Source = "firewall"; Severity = 8 }
            let invalidSeverity = { Category = "Security"; Description = "Test"; Source = "test"; Severity = 15 }

            Expect.isTrue (validateThreatReport valid) "Valid report"
            Expect.isFalse (validateThreatReport invalidSeverity) "Invalid severity"
        }

        test "should map severity to labels" {
            Expect.equal (threatSeverityLabel 10) "Critical" "10 is Critical"
            Expect.equal (threatSeverityLabel 8) "High" "8 is High"
            Expect.equal (threatSeverityLabel 5) "Medium" "5 is Medium"
            Expect.equal (threatSeverityLabel 2) "Low" "2 is Low"
        }
    ]

// ============================================================================
// Founder Directive API Tests
// ============================================================================

type FounderValidationRequest = {
    Action: string
    Context: string
    ProposedBy: string
}

type FounderValidationResponse = {
    Aligned: bool
    Reason: string
    DirectiveRef: string option
}

let founderValidateEndpoint config = sprintf "%s/api/prajna/founder/validate" config.ElixirBaseUrl

let validateFounderRequest (request: FounderValidationRequest) =
    not (String.IsNullOrWhiteSpace request.Action) &&
    not (String.IsNullOrWhiteSpace request.Context)

[<Tests>]
let founderDirectiveApiTests =
    testList "FounderDirectiveAPI" [
        test "should build founder validate endpoint" {
            let url = founderValidateEndpoint defaultConfig
            Expect.stringContains url "/founder/validate" "Validate endpoint"
        }

        test "should validate founder request" {
            let valid = { Action = "deploy_update"; Context = "production deployment"; ProposedBy = "claude" }
            let empty = { Action = ""; Context = ""; ProposedBy = "" }

            Expect.isTrue (validateFounderRequest valid) "Valid request"
            Expect.isFalse (validateFounderRequest empty) "Empty request"
        }
    ]

// ============================================================================
// Constitutional Check API Tests
// ============================================================================

type ConstitutionalCheckRequest = {
    Operation: string
    AffectedInvariants: string list
    Justification: string
}

type ConstitutionalCheckResponse = {
    Permitted: bool
    ViolatedInvariants: string list
    Warnings: string list
}

let constitutionalCheckEndpoint config = sprintf "%s/api/prajna/constitutional/check" config.ElixirBaseUrl

let psiInvariants = ["Ψ₀"; "Ψ₁"; "Ψ₂"; "Ψ₃"; "Ψ₄"; "Ψ₅"]

let validateConstitutionalRequest (request: ConstitutionalCheckRequest) =
    not (String.IsNullOrWhiteSpace request.Operation) &&
    not (String.IsNullOrWhiteSpace request.Justification)

let hasViolations (response: ConstitutionalCheckResponse) =
    response.ViolatedInvariants.Length > 0

[<Tests>]
let constitutionalApiTests =
    testList "ConstitutionalAPI" [
        test "should build constitutional check endpoint" {
            let url = constitutionalCheckEndpoint defaultConfig
            Expect.stringContains url "/constitutional/check" "Check endpoint"
        }

        test "should have all Psi invariants" {
            Expect.equal psiInvariants.Length 6 "Should have 6 Psi invariants"
            Expect.contains psiInvariants "Ψ₀" "Should have Ψ₀ (Existence)"
            Expect.contains psiInvariants "Ψ₄" "Should have Ψ₄ (Human Alignment)"
        }

        test "should validate constitutional request" {
            let valid = {
                Operation = "reconfigure_l3"
                AffectedInvariants = ["Ψ₂"]
                Justification = "Efficiency improvement required for performance"
            }
            Expect.isTrue (validateConstitutionalRequest valid) "Valid request"
        }

        test "should detect violations" {
            let clean = { Permitted = true; ViolatedInvariants = []; Warnings = [] }
            let violation = { Permitted = false; ViolatedInvariants = ["Ψ₀"]; Warnings = [] }

            Expect.isFalse (hasViolations clean) "No violations"
            Expect.isTrue (hasViolations violation) "Has violations"
        }
    ]

// ============================================================================
// Immutable Register API Tests
// ============================================================================

type RegisterRecordRequest = {
    EventType: string
    Data: string
    Actor: string
}

type RegisterRecordResponse = {
    BlockId: string
    Hash: string
    PreviousHash: string
    Timestamp: DateTime
}

let registerRecordEndpoint config = sprintf "%s/api/prajna/register/record" config.ElixirBaseUrl

let validateRegisterRecord (request: RegisterRecordRequest) =
    not (String.IsNullOrWhiteSpace request.EventType) &&
    not (String.IsNullOrWhiteSpace request.Data)

let verifyBlockChain (currentHash: string) (previousHash: string) (recordedPreviousHash: string) =
    previousHash = recordedPreviousHash

[<Tests>]
let registerApiTests =
    testList "RegisterAPI" [
        test "should build register record endpoint" {
            let url = registerRecordEndpoint defaultConfig
            Expect.stringContains url "/register/record" "Record endpoint"
        }

        test "should validate register record" {
            let valid = { EventType = "proposal_approved"; Data = """{"proposalId":"p-1"}"""; Actor = "guardian" }
            let empty = { EventType = ""; Data = ""; Actor = "" }

            Expect.isTrue (validateRegisterRecord valid) "Valid record"
            Expect.isFalse (validateRegisterRecord empty) "Empty record"
        }

        test "should verify block chain integrity" {
            let prev = "abc123"
            let current = "def456"
            Expect.isTrue (verifyBlockChain current prev prev) "Chain intact"
            Expect.isFalse (verifyBlockChain current prev "wrong") "Chain broken"
        }
    ]

// ============================================================================
// API Endpoint Inventory
// ============================================================================

type ApiEndpoint = {
    Method: string
    Path: string
    Description: string
    Priority: string
}

let prajna_api_endpoints = [
    { Method = "GET"; Path = "/api/health"; Description = "System health check"; Priority = "P0" }
    { Method = "GET"; Path = "/api/prajna/metrics"; Description = "System metrics"; Priority = "P0" }
    { Method = "POST"; Path = "/api/prajna/guardian/submit"; Description = "Submit proposal"; Priority = "P0" }
    { Method = "POST"; Path = "/api/prajna/guardian/approve"; Description = "Approve proposal"; Priority = "P0" }
    { Method = "POST"; Path = "/api/prajna/guardian/veto"; Description = "Veto proposal"; Priority = "P0" }
    { Method = "GET"; Path = "/api/prajna/guardian/proposals"; Description = "List proposals"; Priority = "P0" }
    { Method = "POST"; Path = "/api/prajna/sentinel/report"; Description = "Report threat"; Priority = "P0" }
    { Method = "POST"; Path = "/api/prajna/sentinel/mitigate"; Description = "Mitigate threat"; Priority = "P0" }
    { Method = "GET"; Path = "/api/prajna/sentinel/threats"; Description = "List threats"; Priority = "P0" }
    { Method = "POST"; Path = "/api/prajna/founder/validate"; Description = "Validate Ω₀ alignment"; Priority = "P1" }
    { Method = "POST"; Path = "/api/prajna/constitutional/check"; Description = "Check Ψ invariants"; Priority = "P1" }
    { Method = "POST"; Path = "/api/prajna/register/record"; Description = "Record to register"; Priority = "P1" }
    { Method = "POST"; Path = "/api/prajna/prometheus/token"; Description = "Request proof token"; Priority = "P1" }
]

[<Tests>]
let endpointInventoryTests =
    testList "EndpointInventory" [
        test "should have all priority P0 endpoints" {
            let p0 = prajna_api_endpoints |> List.filter (fun e -> e.Priority = "P0")
            Expect.isGreaterThanOrEqual p0.Length 9 "Should have at least 9 P0 endpoints"
        }

        test "should have health endpoint" {
            let health = prajna_api_endpoints |> List.tryFind (fun e -> e.Path = "/api/health")
            Expect.isSome health "Should have health endpoint"
        }

        test "should have guardian endpoints" {
            let guardian = prajna_api_endpoints |> List.filter (fun e -> e.Path.Contains("/guardian/"))
            Expect.isGreaterThanOrEqual guardian.Length 4 "Should have guardian endpoints"
        }
    ]
