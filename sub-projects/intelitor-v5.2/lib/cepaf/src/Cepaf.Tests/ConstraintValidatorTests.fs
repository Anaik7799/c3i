namespace Cepaf.Tests

open System
open Xunit
open Cepaf.Modules.ConstraintValidator

/// ConstraintValidator Unit Tests
/// STAMP Compliance: SC-CNT-009, SC-CNT-010, SC-CNT-012, SC-CEP-004, SC-EMR-057
/// AOR Compliance: AOR-SAF-001, AOR-QUA-001, AOR-BATCH-001
/// Test Coverage: All STAMP and AOR constraint validators
module ConstraintValidatorTests =

    // ========================================================================
    // TEST DATA FACTORY FUNCTIONS
    // ========================================================================

    let makeValidNixOSContainer () : ContainerSpec = {
        Name = "indrajaal-app"
        Image = "localhost/indrajaal-app:nixos"
        DependsOn = ["indrajaal-db"]
        IsRootless = true
        Ports = [(4000, 4000); (9568, 9568)]
        VolumeMounts = ["./priv/static:/app/priv/static:ro"]
        Environment = Map.ofList [("MIX_ENV", "dev")]
    }

    let makeInvalidAlpineContainer () : ContainerSpec = {
        Name = "alpine-test"
        Image = "alpine:latest"
        DependsOn = []
        IsRootless = true
        Ports = [(8080, 80)]
        VolumeMounts = []
        Environment = Map.empty
    }

    let makeInvalidDockerHubContainer () : ContainerSpec = {
        Name = "postgres-test"
        Image = "postgres:17"
        DependsOn = []
        IsRootless = true
        Ports = [(5432, 5432)]
        VolumeMounts = []
        Environment = Map.empty
    }

    let makeRootlessRuntime () : RuntimeSpec = {
        Name = "podman"
        IsRootless = true
        Socket = Some "/run/user/1000/podman/podman.sock"
        Version = Some "5.4.1"
    }

    let makeRootfulRuntime () : RuntimeSpec = {
        Name = "podman"
        IsRootless = false
        Socket = Some "/run/podman/podman.sock"
        Version = Some "5.4.1"
    }

    // ========================================================================
    // SC-CNT-009: NixOS Container Tests
    // ========================================================================

    [<Fact>]
    let ``SC-CNT-009: NixOS container passes validation`` () =
        // Arrange
        let container = makeValidNixOSContainer()

        // Act
        let result = validateNixOS container

        // Assert
        match result with
        | Ok c -> Assert.Equal("indrajaal-app", c.Name)
        | Error v -> Assert.Fail($"Expected Ok, got Error: {v.Message}")

    [<Fact>]
    let ``SC-CNT-009: Alpine container fails validation`` () =
        // Arrange
        let container = makeInvalidAlpineContainer()

        // Act
        let result = validateNixOS container

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("SC-CNT-009", v.ConstraintId)
            Assert.Equal(Critical, v.Severity)
            Assert.Contains("alpine", v.Message.ToLowerInvariant())

    [<Fact>]
    let ``SC-CNT-009: Docker Hub postgres fails validation`` () =
        // Arrange
        let container = makeInvalidDockerHubContainer()

        // Act
        let result = validateNixOS container

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("SC-CNT-009", v.ConstraintId)
            Assert.Contains("postgres", v.Message.ToLowerInvariant())

    [<Theory>]
    [<InlineData("localhost/indrajaal-app:nixos", true)>]
    [<InlineData("localhost/indrajaal-db:nixos", true)>]
    [<InlineData("localhost/indrajaal-observability:nixos", true)>]
    [<InlineData("alpine:latest", false)>]
    [<InlineData("postgres:17", false)>]
    [<InlineData("docker.io/library/postgres:17", false)>]
    [<InlineData("ghcr.io/some/image:latest", false)>]
    let ``SC-CNT-009: NixOS image detection matrix`` (image: string) (shouldPass: bool) =
        // Arrange
        let baseContainer = makeValidNixOSContainer()
        let container = { baseContainer with Image = image }

        // Act
        let result = validateNixOS container

        // Assert
        Assert.Equal(shouldPass, Result.isOk result)

    // ========================================================================
    // SC-CNT-010: Localhost Registry Tests
    // ========================================================================

    [<Fact>]
    let ``SC-CNT-010: Localhost registry passes validation`` () =
        // Act
        let result = validateLocalRegistry "localhost/indrajaal-db:nixos"

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``SC-CNT-010: Docker Hub registry fails validation`` () =
        // Act
        let result = validateLocalRegistry "postgres:17"

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("SC-CNT-010", v.ConstraintId)
            Assert.Equal(Critical, v.Severity)

    [<Theory>]
    [<InlineData("localhost/indrajaal-app:nixos", true)>]
    [<InlineData("localhost/myimage:latest", true)>]
    [<InlineData("docker.io/library/postgres:17", false)>]
    [<InlineData("ghcr.io/owner/repo:tag", false)>]
    [<InlineData("quay.io/image:tag", false)>]
    [<InlineData("postgres:17", false)>]
    let ``SC-CNT-010: Registry validation matrix`` (image: string) (shouldPass: bool) =
        // Act
        let result = validateLocalRegistry image

        // Assert
        Assert.Equal(shouldPass, Result.isOk result)

    // ========================================================================
    // SC-CNT-012: Rootless Podman Tests
    // ========================================================================

    [<Fact>]
    let ``SC-CNT-012: Rootless runtime passes validation`` () =
        // Arrange
        let runtime = makeRootlessRuntime()

        // Act
        let result = validateRootless runtime

        // Assert
        match result with
        | Ok r -> Assert.True(r.IsRootless)
        | Error v -> Assert.Fail($"Expected Ok, got Error: {v.Message}")

    [<Fact>]
    let ``SC-CNT-012: Rootful runtime fails validation`` () =
        // Arrange
        let runtime = makeRootfulRuntime()

        // Act
        let result = validateRootless runtime

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("SC-CNT-012", v.ConstraintId)
            Assert.Equal(Critical, v.Severity)
            Assert.Contains("rootless", v.Message.ToLowerInvariant())

    // ========================================================================
    // SC-CNT-014: Volume Mount Tests
    // ========================================================================

    [<Fact>]
    let ``SC-CNT-014: Safe volume mount passes validation`` () =
        // Arrange
        let baseContainer = makeValidNixOSContainer()
        let container = { baseContainer with VolumeMounts = ["./data:/app/data:rw"] }

        // Act
        let result = validateVolumeMounts container

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``SC-CNT-014: Dangerous /etc mount fails validation`` () =
        // Arrange
        let baseContainer = makeValidNixOSContainer()
        let container = { baseContainer with VolumeMounts = ["/etc/passwd:/app/passwd:ro"] }

        // Act
        let result = validateVolumeMounts container

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("SC-CNT-014", v.ConstraintId)
            Assert.Equal(Critical, v.Severity)

    [<Theory>]
    [<InlineData("/etc/passwd:/app/passwd", false)>]
    [<InlineData("/var/run:/run", false)>]
    [<InlineData("/root/.ssh:/app/.ssh", false)>]
    [<InlineData("/home/user/.bashrc:/app/.bashrc", false)>]
    [<InlineData("./data:/app/data", true)>]
    [<InlineData("myvolume:/app/data", true)>]
    let ``SC-CNT-014: Volume mount validation matrix`` (mount: string) (shouldPass: bool) =
        // Arrange
        let baseContainer = makeValidNixOSContainer()
        let container = { baseContainer with VolumeMounts = [mount] }

        // Act
        let result = validateVolumeMounts container

        // Assert
        Assert.Equal(shouldPass, Result.isOk result)

    // ========================================================================
    // SC-CEP-004: Boot Threshold Tests
    // ========================================================================

    [<Fact>]
    let ``SC-CEP-004: Boot under 30s passes validation`` () =
        // Arrange
        let duration = TimeSpan.FromSeconds(25.0)

        // Act
        let result = validateBootThreshold duration

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``SC-CEP-004: Boot exactly 30s passes validation`` () =
        // Arrange
        let duration = TimeSpan.FromSeconds(30.0)

        // Act
        let result = validateBootThreshold duration

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``SC-CEP-004: Boot over 30s fails validation`` () =
        // Arrange
        let duration = TimeSpan.FromSeconds(45.0)

        // Act
        let result = validateBootThreshold duration

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("SC-CEP-004", v.ConstraintId)
            Assert.Equal(High, v.Severity)
            Assert.Contains("30", v.Message)

    [<Theory>]
    [<InlineData(10.0, true)>]
    [<InlineData(29.9, true)>]
    [<InlineData(30.0, true)>]
    [<InlineData(30.1, false)>]
    [<InlineData(60.0, false)>]
    [<InlineData(120.0, false)>]
    let ``SC-CEP-004: Boot threshold validation matrix`` (seconds: float) (shouldPass: bool) =
        // Arrange
        let duration = TimeSpan.FromSeconds(seconds)

        // Act
        let result = validateBootThreshold duration

        // Assert
        Assert.Equal(shouldPass, Result.isOk result)

    // ========================================================================
    // SC-CEP-001: Artifact Locality Tests
    // ========================================================================

    [<Fact>]
    let ``SC-CEP-001: Path within scope passes validation`` () =
        // Arrange
        let basePath = "/home/user/project/lib/cepaf"
        let targetPath = "/home/user/project/lib/cepaf/artifacts/compose.yml"

        // Act
        let result = validateArtifactLocality basePath targetPath

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``SC-CEP-001: Path outside scope fails validation`` () =
        // Arrange
        let basePath = "/home/user/project/lib/cepaf"
        let targetPath = "/tmp/malicious.yml"

        // Act
        let result = validateArtifactLocality basePath targetPath

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("SC-CEP-001", v.ConstraintId)
            Assert.Equal(Critical, v.Severity)

    // ========================================================================
    // SC-CEP-006: VTO Phase Sequence Tests
    // ========================================================================

    [<Fact>]
    let ``SC-CEP-006: Valid VERIFY start passes`` () =
        // Act
        let result = validateVtoPhaseSequence None "VERIFY"

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``SC-CEP-006: Valid VERIFY to TEARDOWN passes`` () =
        // Act
        let result = validateVtoPhaseSequence (Some "VERIFY") "TEARDOWN"

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``SC-CEP-006: Invalid phase skip fails`` () =
        // Act - trying to skip TEARDOWN
        let result = validateVtoPhaseSequence (Some "VERIFY") "ORCHESTRATE"

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("SC-CEP-006", v.ConstraintId)
            Assert.Contains("TEARDOWN", v.Message)

    // ========================================================================
    // SC-PRF-050: Response Time Tests
    // ========================================================================

    [<Fact>]
    let ``SC-PRF-050: Response under 50ms passes`` () =
        // Act
        let result = validateResponseTime 35L

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``SC-PRF-050: Response over 50ms fails`` () =
        // Act
        let result = validateResponseTime 75L

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("SC-PRF-050", v.ConstraintId)
            Assert.Equal(Medium, v.Severity)

    // ========================================================================
    // SC-EMR-057: Emergency Stop Tests
    // ========================================================================

    [<Fact>]
    let ``SC-EMR-057: Stop under 5s passes`` () =
        // Arrange
        let duration = TimeSpan.FromSeconds(3.0)

        // Act
        let result = validateEmergencyStop duration

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``SC-EMR-057: Stop over 5s fails`` () =
        // Arrange
        let duration = TimeSpan.FromSeconds(8.0)

        // Act
        let result = validateEmergencyStop duration

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("SC-EMR-057", v.ConstraintId)
            Assert.Equal(Critical, v.Severity)

    // ========================================================================
    // AOR-SAF-001: Safety Halt Tests
    // ========================================================================

    [<Fact>]
    let ``AOR-SAF-001: Halt under 1s passes`` () =
        // Arrange
        let duration = TimeSpan.FromMilliseconds(500.0)

        // Act
        let result = validateSafetyHalt duration

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``AOR-SAF-001: Halt over 1s fails`` () =
        // Arrange
        let duration = TimeSpan.FromSeconds(2.0)

        // Act
        let result = validateSafetyHalt duration

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("AOR-SAF-001", v.ConstraintId)
            Assert.Equal(Critical, v.Severity)

    // ========================================================================
    // AOR-QUA-001: Zero Warnings Tests
    // ========================================================================

    [<Fact>]
    let ``AOR-QUA-001: Zero errors and warnings passes`` () =
        // Arrange
        let result = { Errors = 0; Warnings = 0; Files = 773 }

        // Act
        let validationResult = validateZeroWarnings result

        // Assert
        Assert.True(Result.isOk validationResult)

    [<Fact>]
    let ``AOR-QUA-001: Any error fails with Critical severity`` () =
        // Arrange
        let result = { Errors = 1; Warnings = 0; Files = 773 }

        // Act
        let validationResult = validateZeroWarnings result

        // Assert
        match validationResult with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("AOR-QUA-001", v.ConstraintId)
            Assert.Equal(Critical, v.Severity)

    [<Fact>]
    let ``AOR-QUA-001: Any warning fails with High severity`` () =
        // Arrange
        let result = { Errors = 0; Warnings = 5; Files = 773 }

        // Act
        let validationResult = validateZeroWarnings result

        // Assert
        match validationResult with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("AOR-QUA-001", v.ConstraintId)
            Assert.Equal(High, v.Severity)

    // ========================================================================
    // AOR-BATCH-001: Batch Size Tests
    // ========================================================================

    [<Fact>]
    let ``AOR-BATCH-001: Batch under 10 passes`` () =
        // Arrange
        let changes = [1..8]

        // Act
        let result = validateBatchSize changes

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``AOR-BATCH-001: Batch exactly 10 passes`` () =
        // Arrange
        let changes = [1..10]

        // Act
        let result = validateBatchSize changes

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``AOR-BATCH-001: Batch over 10 fails`` () =
        // Arrange
        let changes = [1..15]

        // Act
        let result = validateBatchSize changes

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("AOR-BATCH-001", v.ConstraintId)
            Assert.Equal(High, v.Severity)
            Assert.Contains("15", v.Message)

    // ========================================================================
    // Composite Validation Tests
    // ========================================================================

    [<Fact>]
    let ``validateContainer returns Valid for compliant container`` () =
        // Arrange
        let container = makeValidNixOSContainer()

        // Act
        let result = validateContainer container

        // Assert
        Assert.Equal(Valid, result)

    [<Fact>]
    let ``validateContainer returns Invalid for non-NixOS container`` () =
        // Arrange
        let container = makeInvalidAlpineContainer()

        // Act
        let result = validateContainer container

        // Assert
        match result with
        | Valid -> Assert.Fail("Expected Invalid, got Valid")
        | Invalid violations ->
            Assert.True(violations.Length > 0)
            Assert.True(violations |> List.exists (fun v -> v.ConstraintId = "SC-CNT-009"))

    [<Fact>]
    let ``validateContainers validates multiple containers`` () =
        // Arrange
        let validContainer = makeValidNixOSContainer()
        let invalidContainer = makeInvalidAlpineContainer()
        let containers = [validContainer; invalidContainer]

        // Act
        let results = validateContainers containers

        // Assert
        Assert.Equal(2, results.Length)
        Assert.Equal(Valid, snd results.[0])
        match snd results.[1] with
        | Valid -> Assert.Fail("Expected Invalid")
        | Invalid _ -> ()

    [<Fact>]
    let ``hasCriticalViolations returns true for Critical violations`` () =
        // Arrange
        let container = makeInvalidAlpineContainer()
        let result = validateContainer container

        // Act
        let hasCritical = hasCriticalViolations result

        // Assert
        Assert.True(hasCritical)

    [<Fact>]
    let ``hasCriticalViolations returns false for Valid`` () =
        // Act
        let hasCritical = hasCriticalViolations Valid

        // Assert
        Assert.False(hasCritical)

    [<Fact>]
    let ``combineResults aggregates all violations`` () =
        // Arrange
        let validContainer = makeValidNixOSContainer()
        let alpineContainer = makeInvalidAlpineContainer()
        let dockerHubContainer = makeInvalidDockerHubContainer()
        let results = [
            validateContainer validContainer
            validateContainer alpineContainer
            validateContainer dockerHubContainer
        ]

        // Act
        let combined = combineResults results

        // Assert
        match combined with
        | Valid -> Assert.Fail("Expected Invalid")
        | Invalid violations ->
            Assert.True(violations.Length >= 2)

    [<Fact>]
    let ``formatViolation produces readable output`` () =
        // Arrange
        let violation = {
            ConstraintId = "SC-CNT-009"
            Message = "Container must use NixOS image"
            Severity = Critical
            Timestamp = DateTime.UtcNow
            Context = Map.empty
        }

        // Act
        let formatted = formatViolation violation

        // Assert
        Assert.Contains("[CRITICAL]", formatted)
        Assert.Contains("SC-CNT-009", formatted)
        Assert.Contains("NixOS", formatted)

    // ========================================================================
    // Predicate Tests
    // ========================================================================

    [<Theory>]
    [<InlineData("localhost/indrajaal-app:nixos", true)>]
    [<InlineData("localhost/indrajaal-db:nixos", true)>]
    [<InlineData("alpine:latest", false)>]
    [<InlineData("postgres:17", false)>]
    let ``isNixOSImage correctly identifies NixOS images`` (image: string) (expected: bool) =
        Assert.Equal(expected, isNixOSImage image)

    [<Theory>]
    [<InlineData("localhost/test:latest", true)>]
    [<InlineData("docker.io/test:latest", false)>]
    let ``isLocalhostImage correctly identifies localhost images`` (image: string) (expected: bool) =
        Assert.Equal(expected, isLocalhostImage image)

    [<Theory>]
    [<InlineData(25.0, true)>]
    [<InlineData(30.0, true)>]
    [<InlineData(35.0, false)>]
    let ``isBootWithinThreshold correctly checks boot time`` (seconds: float) (expected: bool) =
        Assert.Equal(expected, isBootWithinThreshold seconds)

    [<Theory>]
    [<InlineData(40L, true)>]
    [<InlineData(50L, true)>]
    [<InlineData(55L, false)>]
    let ``isResponseTimeAcceptable correctly checks response time`` (ms: int64) (expected: bool) =
        Assert.Equal(expected, isResponseTimeAcceptable ms)
