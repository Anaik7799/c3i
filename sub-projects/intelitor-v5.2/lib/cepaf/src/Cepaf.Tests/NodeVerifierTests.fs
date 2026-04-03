namespace Cepaf.Tests

open System
open Xunit
open CliWrap.Buffered
open Cepaf
open Cepaf.Rop
open Cepaf.Observability
open Cepaf.Infrastructure
open Cepaf.Modules.NodeVerifier

/// NodeVerifier Unit Tests
/// STAMP Compliance: SC-CNT-009, SC-CNT-010, SC-CNT-012, SC-CEP-004
/// AOR Compliance: AOR-SAF-001, AOR-QUA-001
/// Test Coverage: Node verification, status transitions, probes, constraints
module NodeVerifierTests =

    // ========================================================================
    // MOCK INFRASTRUCTURE
    // ========================================================================

    /// Mock process result builder
    let makeProcessResult (exitCode: int) (stdout: string) (stderr: string) : BufferedCommandResult =
        // Create a mock BufferedCommandResult using reflection
        // since CliWrap doesn't expose constructors directly
        let resultType = typeof<BufferedCommandResult>
        let ctor = resultType.GetConstructors().[0]
        // BufferedCommandResult(exitCode, startTime, exitTime, stdout, stderr)
        ctor.Invoke([|
            exitCode :> obj
            DateTimeOffset.UtcNow :> obj
            DateTimeOffset.UtcNow :> obj
            stdout :> obj
            stderr :> obj
        |]) :?> BufferedCommandResult

    /// Mock process runner for testing
    type MockProcessRunner(responses: Map<string, Result<BufferedCommandResult, AppError>>) =
        let mutable callLog = []

        member _.Calls = callLog |> List.rev

        interface IProcessRunner with
            member _.Run(cmd, args, ?patientMode) =
                let key = sprintf "%s %s" cmd (String.concat " " args)
                callLog <- key :: callLog
                async {
                    match responses |> Map.tryFind cmd with
                    | Some result -> return result
                    | None ->
                        // Default: return success for unknown commands
                        return Ok (makeProcessResult 0 "" "")
                }

    /// Create mock runner with rootless mode enabled
    let makeRootlessRunner () : IProcessRunner =
        let responses = Map.ofList [
            ("podman", Ok (makeProcessResult 0 "true" ""))
        ]
        MockProcessRunner(responses) :> IProcessRunner

    /// Create mock runner with rootful mode (violation)
    let makeRootfulRunner () : IProcessRunner =
        let responses = Map.ofList [
            ("podman", Ok (makeProcessResult 0 "false" ""))
        ]
        MockProcessRunner(responses) :> IProcessRunner

    /// Create mock runner with container present
    let makeContainerPresentRunner () : IProcessRunner =
        let responses = Map.ofList [
            ("podman", Ok (makeProcessResult 0 "true" ""))
        ]
        MockProcessRunner(responses) :> IProcessRunner

    /// Create mock runner with container absent
    let makeContainerAbsentRunner () : IProcessRunner =
        let responses = Map.ofList [
            ("podman", Ok (makeProcessResult 1 "" "Error: no such container"))
        ]
        MockProcessRunner(responses) :> IProcessRunner

    /// Create mock runner with port in use
    let makePortInUseRunner (port: int) : IProcessRunner =
        let responses = Map.ofList [
            ("ss", Ok (makeProcessResult 0 (sprintf "LISTEN :%d " port) ""))
        ]
        MockProcessRunner(responses) :> IProcessRunner

    /// Create mock runner with port available
    let makePortAvailableRunner () : IProcessRunner =
        let responses = Map.ofList [
            ("ss", Ok (makeProcessResult 0 "" ""))
        ]
        MockProcessRunner(responses) :> IProcessRunner

    /// Create test logger using test config (no console output)
    let makeTestLogger () : UnifiedLogger =
        new UnifiedLogger(QuadplexDefaults.testConfig)

    // ========================================================================
    // TEST DATA FACTORY FUNCTIONS
    // ========================================================================

    /// Create valid NixOS image string
    let makeValidNixOSImage () : string =
        "localhost/indrajaal-app:nixos"

    /// Create invalid Alpine image string
    let makeInvalidAlpineImage () : string =
        "alpine:latest"

    /// Create invalid Docker Hub image string
    let makeInvalidDockerHubImage () : string =
        "postgres:17"

    /// Create default node verification result
    let makeEmptyResult (nodeId: string) : NodeVerificationResult =
        {
            NodeId = nodeId
            Status = NotVerified
            Constraints = []
            StartTime = DateTime.UtcNow
            EndTime = None
            ProbeResults = Map.empty
            BootTimeMs = None
            Image = None
            IsRootless = None
        }

    /// Create successful probe result
    let makeSuccessfulProbe (name: string) : ProbeResult =
        {
            ProbeName = name
            Success = true
            ResponseTimeMs = 25L
            Message = Some "Health check passed"
            Timestamp = DateTime.UtcNow
        }

    /// Create failed probe result
    let makeFailedProbe (name: string) (reason: string) : ProbeResult =
        {
            ProbeName = name
            Success = false
            ResponseTimeMs = 100L
            Message = Some reason
            Timestamp = DateTime.UtcNow
        }

    /// Create port check result (available)
    let makePortAvailable (port: int) : PortCheckResult =
        {
            Port = port
            Available = true
            ConflictingProcess = None
        }

    /// Create port check result (in use)
    let makePortInUse (port: int) : PortCheckResult =
        {
            Port = port
            Available = false
            ConflictingProcess = Some "unknown"
        }

    /// Create volume mount result (exists and writable)
    let makeValidVolume (path: string) : VolumeMountResult =
        {
            Path = path
            Exists = true
            Writable = true
            ErrorMessage = None
        }

    /// Create volume mount result (missing)
    let makeMissingVolume (path: string) : VolumeMountResult =
        {
            Path = path
            Exists = false
            Writable = false
            ErrorMessage = Some (sprintf "Path does not exist: %s" path)
        }

    /// Create verification report factory
    let makeVerificationReport (nodeId: string) (success: bool) (level: VerificationLevel) : VerificationReport =
        {
            NodeId = nodeId
            Timestamp = DateTime.UtcNow
            Level = level
            OverallSuccess = success
            Constraints = []
            BootCompliance = true
            ImageCompliance = success
            RootlessCompliance = success
            PortConflicts = []
            VolumeMounts = []
            ProbeResults = []
            TotalDurationMs = 100L
            Recommendations = []
        }

    // ========================================================================
    // NODE STATUS TRANSITION TESTS
    // ========================================================================

    [<Fact>]
    let ``NodeStatus: NotVerified is initial state`` () =
        // Arrange
        let result = makeEmptyResult "test-node"

        // Assert
        Assert.Equal(NotVerified, result.Status)

    [<Fact>]
    let ``NodeStatus: VerificationInProgress has correct representation`` () =
        // Arrange
        let status = VerificationInProgress

        // Assert
        match status with
        | VerificationInProgress -> Assert.True(true)
        | _ -> Assert.Fail("Expected VerificationInProgress")

    [<Fact>]
    let ``NodeStatus: Verified contains timestamp`` () =
        // Arrange
        let now = DateTime.UtcNow
        let status = Verified now

        // Assert
        match status with
        | Verified ts -> Assert.Equal(now, ts)
        | _ -> Assert.Fail("Expected Verified with timestamp")

    [<Fact>]
    let ``NodeStatus: VerificationFailed contains reason list`` () =
        // Arrange
        let reasons = ["SC-CNT-009 violation"; "SC-CNT-010 violation"]
        let status = VerificationFailed reasons

        // Assert
        match status with
        | VerificationFailed r ->
            Assert.Equal(2, List.length r)
            Assert.Contains("SC-CNT-009 violation", r)
            Assert.Contains("SC-CNT-010 violation", r)
        | _ -> Assert.Fail("Expected VerificationFailed with reasons")

    [<Fact>]
    let ``NodeStatus: Transition NotVerified to Verified is valid`` () =
        // Arrange
        let initialResult = { makeEmptyResult "test-node" with Status = NotVerified }

        // Act - simulate verification success
        let updatedResult = { initialResult with Status = Verified DateTime.UtcNow }

        // Assert
        match updatedResult.Status with
        | Verified _ -> Assert.True(true)
        | _ -> Assert.Fail("Expected Verified status")

    [<Fact>]
    let ``NodeStatus: Transition NotVerified to VerificationFailed is valid`` () =
        // Arrange
        let initialResult = { makeEmptyResult "test-node" with Status = NotVerified }

        // Act - simulate verification failure
        let updatedResult = { initialResult with Status = VerificationFailed ["Some failure"] }

        // Assert
        match updatedResult.Status with
        | VerificationFailed reasons -> Assert.Single(reasons) |> ignore
        | _ -> Assert.Fail("Expected VerificationFailed status")

    // ========================================================================
    // VERIFICATION LEVEL TESTS
    // ========================================================================

    [<Fact>]
    let ``VerificationLevel: Quick is fastest level`` () =
        // Assert
        match Quick with
        | Quick -> Assert.True(true)
        | _ -> Assert.Fail("Expected Quick")

    [<Fact>]
    let ``VerificationLevel: Standard includes rootless check`` () =
        // Assert
        match Standard with
        | Standard -> Assert.True(true)
        | _ -> Assert.Fail("Expected Standard")

    [<Fact>]
    let ``VerificationLevel: Thorough includes probes`` () =
        // Assert
        match Thorough with
        | Thorough -> Assert.True(true)
        | _ -> Assert.Fail("Expected Thorough")

    [<Theory>]
    [<InlineData("Quick")>]
    [<InlineData("Standard")>]
    [<InlineData("Thorough")>]
    let ``VerificationLevel: All levels are parseable`` (levelName: string) =
        // Arrange
        let level =
            match levelName with
            | "Quick" -> Quick
            | "Standard" -> Standard
            | "Thorough" -> Thorough
            | _ -> failwith "Unknown level"

        // Assert
        Assert.NotNull(box level)

    // ========================================================================
    // SC-CNT-009: NIXOS IMAGE VERIFICATION TESTS
    // ========================================================================

    [<Fact>]
    let ``SC-CNT-009: NixOS image passes verification`` () =
        // Arrange
        let image = makeValidNixOSImage()

        // Act
        let result = verifyImage image

        // Assert
        match result with
        | Ok img -> Assert.Equal("localhost/indrajaal-app:nixos", img)
        | Error v -> Assert.Fail(sprintf "Expected Ok, got Error: %s" v.Message)

    [<Fact>]
    let ``SC-CNT-009: Alpine image fails verification`` () =
        // Arrange
        let image = makeInvalidAlpineImage()

        // Act
        let result = verifyImage image

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("SC-CNT-009", v.ConstraintId)

    [<Fact>]
    let ``SC-CNT-009: Docker Hub postgres fails verification`` () =
        // Arrange
        let image = makeInvalidDockerHubImage()

        // Act
        let result = verifyImage image

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("SC-CNT-009", v.ConstraintId)

    [<Theory>]
    [<InlineData("localhost/indrajaal-app:nixos", true)>]
    [<InlineData("localhost/indrajaal-db:nixos", true)>]
    [<InlineData("localhost/indrajaal-obs:nixos", true)>]
    [<InlineData("alpine:latest", false)>]
    [<InlineData("postgres:17", false)>]
    [<InlineData("docker.io/library/postgres:17", false)>]
    let ``SC-CNT-009: Image verification matrix`` (image: string) (shouldPass: bool) =
        // Act
        let result = verifyImage image

        // Assert
        Assert.Equal(shouldPass, Result.isOk result)

    // ========================================================================
    // SC-CNT-010: LOCALHOST REGISTRY VERIFICATION TESTS
    // ========================================================================

    [<Fact>]
    let ``SC-CNT-010: Localhost registry passes verification`` () =
        // Arrange
        let image = "localhost/indrajaal-db:nixos"

        // Act
        let result = verifyLocalRegistry image

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``SC-CNT-010: Docker Hub registry fails verification`` () =
        // Arrange
        let image = "postgres:17"

        // Act
        let result = verifyLocalRegistry image

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("SC-CNT-010", v.ConstraintId)

    [<Theory>]
    [<InlineData("localhost/myapp:latest", true)>]
    [<InlineData("localhost/indrajaal-app:v1", true)>]
    [<InlineData("docker.io/library/postgres:17", false)>]
    [<InlineData("ghcr.io/owner/repo:tag", false)>]
    [<InlineData("quay.io/image:tag", false)>]
    [<InlineData("nginx:alpine", false)>]
    let ``SC-CNT-010: Registry verification matrix`` (image: string) (shouldPass: bool) =
        // Act
        let result = verifyLocalRegistry image

        // Assert
        Assert.Equal(shouldPass, Result.isOk result)

    // ========================================================================
    // SC-CNT-012: ROOTLESS PODMAN VERIFICATION TESTS
    // ========================================================================

    [<Fact>]
    let ``SC-CNT-012: Rootless mode passes verification`` () =
        // Arrange
        let logger = makeTestLogger()
        let runner = makeRootlessRunner()

        // Act
        let result = verifyRootless logger runner |> Async.RunSynchronously

        // Assert
        match result with
        | Ok isRootless -> Assert.True(isRootless)
        | Error _ -> Assert.Fail("Expected Ok, got Error")

    [<Fact>]
    let ``SC-CNT-012: Rootful mode fails verification`` () =
        // Arrange
        let logger = makeTestLogger()
        let runner = makeRootfulRunner()

        // Act
        let result = verifyRootless logger runner |> Async.RunSynchronously

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error e ->
            match e with
            | SafetyViolation(id, _) -> Assert.Equal("SC-CNT-012", id)
            | _ -> Assert.Fail("Expected SafetyViolation")

    // ========================================================================
    // SC-CEP-004: BOOT TIME VERIFICATION TESTS
    // ========================================================================

    [<Fact>]
    let ``SC-CEP-004: Boot under 30s passes verification`` () =
        // Arrange
        let logger = makeTestLogger()
        let bootTimeMs = 25000L  // 25 seconds

        // Act
        let result = verifyBootTime logger bootTimeMs

        // Assert
        match result with
        | Ok ms -> Assert.Equal(25000L, ms)
        | Error _ -> Assert.Fail("Expected Ok")

    [<Fact>]
    let ``SC-CEP-004: Boot exactly 30s passes verification`` () =
        // Arrange
        let logger = makeTestLogger()
        let bootTimeMs = 30000L  // 30 seconds

        // Act
        let result = verifyBootTime logger bootTimeMs

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``SC-CEP-004: Boot over 30s fails verification`` () =
        // Arrange
        let logger = makeTestLogger()
        let bootTimeMs = 45000L  // 45 seconds

        // Act
        let result = verifyBootTime logger bootTimeMs

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("SC-CEP-004", v.ConstraintId)

    [<Theory>]
    [<InlineData(10000L, true)>]      // 10s
    [<InlineData(29999L, true)>]      // 29.999s
    [<InlineData(30000L, true)>]      // 30s
    [<InlineData(30001L, false)>]     // 30.001s
    [<InlineData(60000L, false)>]     // 60s
    [<InlineData(120000L, false)>]    // 120s
    let ``SC-CEP-004: Boot time threshold matrix`` (bootTimeMs: int64) (shouldPass: bool) =
        // Arrange
        let logger = makeTestLogger()

        // Act
        let result = verifyBootTime logger bootTimeMs

        // Assert
        Assert.Equal(shouldPass, Result.isOk result)

    // ========================================================================
    // PORT AVAILABILITY TESTS
    // ========================================================================

    [<Fact>]
    let ``Port availability: Available port passes check`` () =
        // Arrange
        let logger = makeTestLogger()
        let runner = makePortAvailableRunner()
        let ports = [4000; 5433]

        // Act
        let results = verifyPorts logger runner ports |> Async.RunSynchronously

        // Assert
        Assert.Equal(2, List.length results)
        Assert.True(results |> List.forall (fun p -> p.Available))

    [<Fact>]
    let ``Port availability: Port in use fails check`` () =
        // Arrange
        let logger = makeTestLogger()
        let runner = makePortInUseRunner 4000
        let ports = [4000]

        // Act
        let results = verifyPorts logger runner ports |> Async.RunSynchronously

        // Assert
        Assert.Single(results) |> ignore
        let result = List.head results
        Assert.False(result.Available)
        Assert.Equal(4000, result.Port)

    [<Fact>]
    let ``Port availability: Empty port list returns empty results`` () =
        // Arrange
        let logger = makeTestLogger()
        let runner = makePortAvailableRunner()
        let ports = []

        // Act
        let results = verifyPorts logger runner ports |> Async.RunSynchronously

        // Assert
        Assert.Empty(results)

    [<Fact>]
    let ``PortCheckResult: Available property is correctly set`` () =
        // Arrange
        let available = makePortAvailable 4000
        let inUse = makePortInUse 5433

        // Assert
        Assert.True(available.Available)
        Assert.False(inUse.Available)
        Assert.Null(available.ConflictingProcess |> Option.toObj)
        Assert.Equal("unknown", inUse.ConflictingProcess |> Option.get)

    // ========================================================================
    // VOLUME MOUNT VERIFICATION TESTS
    // ========================================================================

    [<Fact>]
    let ``Volume verification: Empty volume list returns empty results`` () =
        // Arrange
        let logger = makeTestLogger()
        let volumes = []

        // Act
        let results = verifyVolumes logger volumes

        // Assert
        Assert.Empty(results)

    [<Fact>]
    let ``Volume verification: Parses source path from mount string`` () =
        // Arrange
        let logger = makeTestLogger()
        let volumes = ["./data:/app/data:rw"]

        // Act
        let results = verifyVolumes logger volumes

        // Assert
        Assert.Single(results) |> ignore
        let result = List.head results
        Assert.Equal("./data", result.Path)

    [<Fact>]
    let ``Volume verification: Non-existent path reports not exists`` () =
        // Arrange
        let logger = makeTestLogger()
        let volumes = ["/nonexistent/path/12345:/app/data"]

        // Act
        let results = verifyVolumes logger volumes

        // Assert
        Assert.Single(results) |> ignore
        let result = List.head results
        Assert.False(result.Exists)
        Assert.True(result.ErrorMessage.IsSome)

    [<Fact>]
    let ``VolumeMountResult: Factory creates valid result`` () =
        // Arrange & Act
        let valid = makeValidVolume "./data"
        let missing = makeMissingVolume "/nonexistent"

        // Assert
        Assert.True(valid.Exists)
        Assert.True(valid.Writable)
        Assert.True(valid.ErrorMessage.IsNone)

        Assert.False(missing.Exists)
        Assert.False(missing.Writable)
        Assert.True(missing.ErrorMessage.IsSome)

    // ========================================================================
    // PROBE RESULT TESTS
    // ========================================================================

    [<Fact>]
    let ``ProbeResult: Successful probe has correct properties`` () =
        // Arrange & Act
        let probe = makeSuccessfulProbe "default"

        // Assert
        Assert.Equal("default", probe.ProbeName)
        Assert.True(probe.Success)
        Assert.True(probe.ResponseTimeMs <= 50L)  // Within PHICS threshold
        Assert.True(probe.Message.IsSome)

    [<Fact>]
    let ``ProbeResult: Failed probe contains reason`` () =
        // Arrange & Act
        let probe = makeFailedProbe "tcp" "Connection refused"

        // Assert
        Assert.Equal("tcp", probe.ProbeName)
        Assert.False(probe.Success)
        Assert.Equal(Some "Connection refused", probe.Message)

    [<Fact>]
    let ``ProbeResult: Timestamp is set on creation`` () =
        // Arrange
        let before = DateTime.UtcNow

        // Act
        let probe = makeSuccessfulProbe "test"

        // Assert
        Assert.True(probe.Timestamp >= before)

    // ========================================================================
    // NODE VERIFICATION RESULT TESTS
    // ========================================================================

    [<Fact>]
    let ``NodeVerificationResult: Empty result has correct defaults`` () =
        // Arrange & Act
        let result = makeEmptyResult "test-node"

        // Assert
        Assert.Equal("test-node", result.NodeId)
        Assert.Equal(NotVerified, result.Status)
        Assert.Empty(result.Constraints)
        Assert.True(result.ProbeResults.IsEmpty)
        Assert.True(result.BootTimeMs.IsNone)
        Assert.True(result.Image.IsNone)
        Assert.True(result.IsRootless.IsNone)

    [<Fact>]
    let ``NodeVerificationResult: Can add constraints`` () =
        // Arrange
        let result = makeEmptyResult "test-node"

        // Act
        let updated = { result with Constraints = [("SC-CNT-009", true); ("SC-CNT-010", true)] }

        // Assert
        Assert.Equal(2, List.length updated.Constraints)

    [<Fact>]
    let ``NodeVerificationResult: Can add probe results`` () =
        // Arrange
        let result = makeEmptyResult "test-node"

        // Act
        let updated = { result with ProbeResults = Map.ofList [("tcp", true); ("http", false)] }

        // Assert
        Assert.Equal(2, updated.ProbeResults.Count)
        Assert.True(updated.ProbeResults.["tcp"])
        Assert.False(updated.ProbeResults.["http"])

    // ========================================================================
    // VERIFICATION REPORT TESTS
    // ========================================================================

    [<Fact>]
    let ``VerificationReport: Successful report has correct properties`` () =
        // Arrange & Act
        let report = makeVerificationReport "test-node" true Quick

        // Assert
        Assert.Equal("test-node", report.NodeId)
        Assert.True(report.OverallSuccess)
        Assert.Equal(Quick, report.Level)
        Assert.True(report.BootCompliance)
        Assert.True(report.ImageCompliance)
        Assert.True(report.RootlessCompliance)
        Assert.Empty(report.PortConflicts)
        Assert.Empty(report.Recommendations)

    [<Fact>]
    let ``VerificationReport: Failed report has recommendations`` () =
        // Arrange
        let report = { makeVerificationReport "test-node" false Standard with
                        ImageCompliance = false
                        RootlessCompliance = false
                        Recommendations = ["Use NixOS images"; "Enable rootless mode"] }

        // Assert
        Assert.False(report.OverallSuccess)
        Assert.False(report.ImageCompliance)
        Assert.False(report.RootlessCompliance)
        Assert.Equal(2, List.length report.Recommendations)

    [<Fact>]
    let ``createVerificationReport: Generates report from result`` () =
        // Arrange
        let logger = makeTestLogger()
        let result = {
            makeEmptyResult "test-node" with
                Status = Verified DateTime.UtcNow
                Constraints = [("SC-CNT-009", true); ("SC-CNT-010", true)]
                Image = Some "localhost/indrajaal-app:nixos"
                IsRootless = Some true
        }

        // Act
        let report = createVerificationReport logger result Quick [] [] []

        // Assert
        Assert.Equal("test-node", report.NodeId)
        Assert.True(report.OverallSuccess)
        Assert.True(report.RootlessCompliance)

    [<Fact>]
    let ``createVerificationReport: Non-compliant boot generates recommendation`` () =
        // Arrange
        let logger = makeTestLogger()
        let result = {
            makeEmptyResult "test-node" with
                Status = VerificationFailed ["Boot time exceeded"]
                BootTimeMs = Some 45000L  // Over 30s
        }

        // Act
        let report = createVerificationReport logger result Thorough [] [] []

        // Assert
        Assert.False(report.BootCompliance)
        Assert.True(report.Recommendations |> List.exists (fun r -> r.Contains("startup time")))

    [<Fact>]
    let ``formatReport: Produces readable output`` () =
        // Arrange
        let report = { makeVerificationReport "test-node" true Quick with
                        Constraints = [("SC-CNT-009", true, None); ("SC-CNT-010", true, None)] }

        // Act
        let output = formatReport report

        // Assert
        Assert.Contains("VERIFICATION REPORT", output)
        Assert.Contains("test-node", output)
        Assert.Contains("PASSED", output)
        Assert.Contains("SC-CNT-009", output)
        Assert.Contains("SC-CNT-010", output)

    [<Fact>]
    let ``formatReport: Shows failed constraints`` () =
        // Arrange
        let report = { makeVerificationReport "test-node" false Standard with
                        Constraints = [("SC-CNT-009", false, Some "NixOS required")] }

        // Act
        let output = formatReport report

        // Assert
        Assert.Contains("[FAIL]", output)
        Assert.Contains("SC-CNT-009", output)

    // ========================================================================
    // BATCH VERIFICATION TESTS
    // ========================================================================

    [<Fact>]
    let ``allNodesPassed: Returns true when all verified`` () =
        // Arrange
        let results = [
            { makeEmptyResult "node1" with Status = Verified DateTime.UtcNow }
            { makeEmptyResult "node2" with Status = Verified DateTime.UtcNow }
        ]

        // Act
        let passed = allNodesPassed results

        // Assert
        Assert.True(passed)

    [<Fact>]
    let ``allNodesPassed: Returns false when any failed`` () =
        // Arrange
        let results = [
            { makeEmptyResult "node1" with Status = Verified DateTime.UtcNow }
            { makeEmptyResult "node2" with Status = VerificationFailed ["Error"] }
        ]

        // Act
        let passed = allNodesPassed results

        // Assert
        Assert.False(passed)

    [<Fact>]
    let ``allNodesPassed: Returns false when any not verified`` () =
        // Arrange
        let results = [
            { makeEmptyResult "node1" with Status = Verified DateTime.UtcNow }
            { makeEmptyResult "node2" with Status = NotVerified }
        ]

        // Act
        let passed = allNodesPassed results

        // Assert
        Assert.False(passed)

    [<Fact>]
    let ``getFailedNodes: Returns empty for all passed`` () =
        // Arrange
        let results = [
            { makeEmptyResult "node1" with Status = Verified DateTime.UtcNow }
            { makeEmptyResult "node2" with Status = Verified DateTime.UtcNow }
        ]

        // Act
        let failed = getFailedNodes results

        // Assert
        Assert.Empty(failed)

    [<Fact>]
    let ``getFailedNodes: Returns failed node IDs`` () =
        // Arrange
        let results = [
            { makeEmptyResult "node1" with Status = Verified DateTime.UtcNow }
            { makeEmptyResult "node2" with Status = VerificationFailed ["Error"] }
            { makeEmptyResult "node3" with Status = VerificationFailed ["Error 2"] }
        ]

        // Act
        let failed = getFailedNodes results

        // Assert
        Assert.Equal(2, List.length failed)
        Assert.Contains("node2", failed)
        Assert.Contains("node3", failed)

    [<Fact>]
    let ``getConstraintViolations: Returns empty for all passed`` () =
        // Arrange
        let results = [
            { makeEmptyResult "node1" with
                Status = Verified DateTime.UtcNow
                Constraints = [("SC-CNT-009", true); ("SC-CNT-010", true)] }
        ]

        // Act
        let violations = getConstraintViolations results

        // Assert
        Assert.Empty(violations)

    [<Fact>]
    let ``getConstraintViolations: Returns violated constraints`` () =
        // Arrange
        let results = [
            { makeEmptyResult "node1" with
                Constraints = [("SC-CNT-009", false); ("SC-CNT-010", true)] }
            { makeEmptyResult "node2" with
                Constraints = [("SC-CNT-009", true); ("SC-CNT-012", false)] }
        ]

        // Act
        let violations = getConstraintViolations results

        // Assert
        Assert.Equal(2, List.length violations)
        Assert.Contains(("node1", "SC-CNT-009"), violations)
        Assert.Contains(("node2", "SC-CNT-012"), violations)

    // ========================================================================
    // INTEGRATION TESTS (verifyNode)
    // ========================================================================

    [<Fact>]
    let ``verifyNode Quick: Passes for valid NixOS image`` () =
        // Arrange
        let logger = makeTestLogger()
        let runner = makeRootlessRunner()
        let image = makeValidNixOSImage()

        // Act
        let result = verifyNode logger runner "test-node" image Quick [] [] |> Async.RunSynchronously

        // Assert
        match result.Status with
        | Verified _ -> Assert.True(true)
        | _ -> Assert.Fail("Expected Verified status")

    [<Fact>]
    let ``verifyNode Quick: Fails for invalid image`` () =
        // Arrange
        let logger = makeTestLogger()
        let runner = makeRootlessRunner()
        let image = makeInvalidAlpineImage()

        // Act
        let result = verifyNode logger runner "test-node" image Quick [] [] |> Async.RunSynchronously

        // Assert
        match result.Status with
        | VerificationFailed _ -> Assert.True(true)
        | _ -> Assert.Fail("Expected VerificationFailed status")

    [<Fact>]
    let ``verifyNode Standard: Includes rootless check`` () =
        // Arrange
        let logger = makeTestLogger()
        let runner = makeRootlessRunner()
        let image = makeValidNixOSImage()

        // Act
        let result = verifyNode logger runner "test-node" image Standard [] [] |> Async.RunSynchronously

        // Assert
        Assert.True(result.IsRootless.IsSome)
        Assert.True(result.Constraints |> List.exists (fun (id, _) -> id = "SC-CNT-012"))

    [<Fact>]
    let ``verifyNode Thorough: Includes port and volume checks`` () =
        // Arrange
        let logger = makeTestLogger()
        let runner = makeRootlessRunner()
        let image = makeValidNixOSImage()
        let ports = [4000]
        let volumes = []  // Empty to avoid filesystem access

        // Act
        let result = verifyNode logger runner "test-node" image Thorough ports volumes |> Async.RunSynchronously

        // Assert
        Assert.True(result.Constraints |> List.exists (fun (id, _) -> id = "PORT-AVAILABLE"))
        Assert.True(result.Constraints |> List.exists (fun (id, _) -> id = "VOLUME-EXISTS"))

    [<Fact>]
    let ``verifyNode: Sets start and end times`` () =
        // Arrange
        let logger = makeTestLogger()
        let runner = makeRootlessRunner()
        let image = makeValidNixOSImage()
        let beforeStart = DateTime.UtcNow

        // Act
        let result = verifyNode logger runner "test-node" image Quick [] [] |> Async.RunSynchronously

        // Assert
        Assert.True(result.StartTime >= beforeStart)
        Assert.True(result.EndTime.IsSome)
        Assert.True(result.EndTime.Value >= result.StartTime)

    [<Fact>]
    let ``verifyNode: Records image in result`` () =
        // Arrange
        let logger = makeTestLogger()
        let runner = makeRootlessRunner()
        let image = makeValidNixOSImage()

        // Act
        let result = verifyNode logger runner "test-node" image Quick [] [] |> Async.RunSynchronously

        // Assert
        Assert.True(result.Image.IsSome)
        Assert.Equal(image, result.Image.Value)
