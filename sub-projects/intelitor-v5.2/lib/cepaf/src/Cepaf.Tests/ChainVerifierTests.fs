namespace Cepaf.Tests

open System
open Xunit
open Cepaf.Modules.ServiceDAG
open Cepaf.Modules.ChainVerifier

/// ChainVerifier Unit Tests
/// STAMP Compliance: SC-AGT-018, SC-CEP-003, SC-VAL-003
/// AOR Compliance: AOR-SAF-001, AOR-CNT-001, AOR-QUA-001
/// Test Coverage: Chain status, FPPS consensus, cycle detection,
///                boot sequence, layer health, node aggregation, readiness
module ChainVerifierTests =

    // ========================================================================
    // TEST DATA FACTORY FUNCTIONS
    // Factories avoid xUnit initialization issues with module-level values
    // ========================================================================

    // --- Container Factories ---

    /// Database container - Layer 0 (no dependencies)
    let makeDbContainer () : ContainerDef = {
        Name = "indrajaal-db"
        Image = "localhost/indrajaal-db:nixos"
        DependsOn = []
        DependencyTypes = Map.empty
        Layer = Some 0
    }

    /// Application container - Layer 1 (depends on db)
    let makeAppContainer () : ContainerDef = {
        Name = "indrajaal-app"
        Image = "localhost/indrajaal-app:nixos"
        DependsOn = ["indrajaal-db"]
        DependencyTypes = Map.ofList [("indrajaal-db", Mandatory)]
        Layer = Some 1
    }

    /// Observability container - Layer 2 (depends on app)
    let makeObsContainer () : ContainerDef = {
        Name = "indrajaal-obs"
        Image = "localhost/indrajaal-obs:nixos"
        DependsOn = ["indrajaal-app"]
        DependencyTypes = Map.ofList [("indrajaal-app", Optional)]
        Layer = Some 2
    }

    /// Cache container - no dependencies
    let makeCacheContainer () : ContainerDef = {
        Name = "cache"
        Image = "localhost/cache:nixos"
        DependsOn = []
        DependencyTypes = Map.empty
        Layer = None
    }

    /// Container A in a cycle (a -> b)
    let makeCyclicContainerA () : ContainerDef = {
        Name = "container-a"
        Image = "localhost/container-a:nixos"
        DependsOn = ["container-b"]
        DependencyTypes = Map.ofList [("container-b", Mandatory)]
        Layer = None
    }

    /// Container B in a cycle (b -> c)
    let makeCyclicContainerB () : ContainerDef = {
        Name = "container-b"
        Image = "localhost/container-b:nixos"
        DependsOn = ["container-c"]
        DependencyTypes = Map.ofList [("container-c", Mandatory)]
        Layer = None
    }

    /// Container C in a cycle (c -> a) - completes the cycle
    let makeCyclicContainerC () : ContainerDef = {
        Name = "container-c"
        Image = "localhost/container-c:nixos"
        DependsOn = ["container-a"]
        DependencyTypes = Map.ofList [("container-a", Mandatory)]
        Layer = None
    }

    // --- DAG Factories ---

    /// Build standard 3-container chain DAG (db -> app -> obs)
    let makeStandardChainDAG () : ServiceDAG =
        let containers = [
            makeDbContainer ()
            makeAppContainer ()
            makeObsContainer ()
        ]
        buildDAG containers

    /// Build cyclic DAG (a -> b -> c -> a)
    let makeCyclicDAG () : ServiceDAG =
        let containers = [
            makeCyclicContainerA ()
            makeCyclicContainerB ()
            makeCyclicContainerC ()
        ]
        buildDAG containers

    /// Build DAG with layered assignment
    let makeLayeredDAG () : ServiceDAG =
        makeStandardChainDAG () |> assignLayers

    // --- ChainVerifierConfig Factories ---

    /// Default chain verification config
    let makeChainConfig () : ChainVerifierConfig =
        defaultConfig "test-chain" (makeStandardChainDAG ())

    /// Chain config with custom settings
    let makeCustomChainConfig (chainId: string) (dag: ServiceDAG) : ChainVerifierConfig = {
        ChainId = chainId
        DAG = dag
        HealthEndpointPath = "/health"
        HealthTimeoutMs = 5000
        LogErrorPatterns = ["ERROR"; "FATAL"; "CRITICAL"]
        LogTailLines = 50
        RequireAllMethods = true
        AllowDegradedOptional = true
    }

    /// Chain config that does not require all methods (majority only)
    let makeLenientChainConfig (dag: ServiceDAG) : ChainVerifierConfig = {
        ChainId = "lenient-chain"
        DAG = dag
        HealthEndpointPath = "/health"
        HealthTimeoutMs = 3000
        LogErrorPatterns = ["ERROR"]
        LogTailLines = 20
        RequireAllMethods = false
        AllowDegradedOptional = true
    }

    /// Chain config that does not allow degraded optional deps
    let makeStrictChainConfig (dag: ServiceDAG) : ChainVerifierConfig = {
        ChainId = "strict-chain"
        DAG = dag
        HealthEndpointPath = "/healthz"
        HealthTimeoutMs = 2000
        LogErrorPatterns = ["ERROR"; "FATAL"; "CRITICAL"; "panic"]
        LogTailLines = 100
        RequireAllMethods = true
        AllowDegradedOptional = false
    }

    // --- FPPS Result Factories ---

    /// Create passing FPPS result
    let makeFPPSResultPass (method: ConsensusMethod) (nodeId: string) : FPPSResult = {
        Method = method
        NodeId = nodeId
        Passed = true
        Timestamp = DateTime.UtcNow
        Details = Some "Check passed"
    }

    /// Create failing FPPS result
    let makeFPPSResultFail (method: ConsensusMethod) (nodeId: string) (reason: string) : FPPSResult = {
        Method = method
        NodeId = nodeId
        Passed = false
        Timestamp = DateTime.UtcNow
        Details = Some reason
    }

    /// Create all 5 passing FPPS results for a node
    let makeAllPassingFPPS (nodeId: string) : FPPSResult list = [
        makeFPPSResultPass PodmanStatus nodeId
        makeFPPSResultPass HealthEndpoint nodeId
        makeFPPSResultPass PortProbe nodeId
        makeFPPSResultPass ProcessCheck nodeId
        makeFPPSResultPass LogAnalysis nodeId
    ]

    /// Create all 5 failing FPPS results for a node
    let makeAllFailingFPPS (nodeId: string) : FPPSResult list = [
        makeFPPSResultFail PodmanStatus nodeId "Container not running"
        makeFPPSResultFail HealthEndpoint nodeId "HTTP 503"
        makeFPPSResultFail PortProbe nodeId "Port closed"
        makeFPPSResultFail ProcessCheck nodeId "No process"
        makeFPPSResultFail LogAnalysis nodeId "Found ERROR in logs"
    ]

    /// Create mixed FPPS results (3 pass, 2 fail) for majority tests
    let makeMixedFPPS_3Pass2Fail (nodeId: string) : FPPSResult list = [
        makeFPPSResultPass PodmanStatus nodeId
        makeFPPSResultPass HealthEndpoint nodeId
        makeFPPSResultPass PortProbe nodeId
        makeFPPSResultFail ProcessCheck nodeId "Process check failed"
        makeFPPSResultFail LogAnalysis nodeId "Log errors found"
    ]

    /// Create mixed FPPS results (2 pass, 3 fail) for majority tests
    let makeMixedFPPS_2Pass3Fail (nodeId: string) : FPPSResult list = [
        makeFPPSResultPass PodmanStatus nodeId
        makeFPPSResultPass HealthEndpoint nodeId
        makeFPPSResultFail PortProbe nodeId "Port closed"
        makeFPPSResultFail ProcessCheck nodeId "Process check failed"
        makeFPPSResultFail LogAnalysis nodeId "Log errors found"
    ]

    /// Create FPPS result with single method passing
    let makeSinglePassFPPS (passingMethod: ConsensusMethod) (nodeId: string) : FPPSResult list = [
        if passingMethod = PodmanStatus then makeFPPSResultPass PodmanStatus nodeId
        else makeFPPSResultFail PodmanStatus nodeId "Failed"

        if passingMethod = HealthEndpoint then makeFPPSResultPass HealthEndpoint nodeId
        else makeFPPSResultFail HealthEndpoint nodeId "Failed"

        if passingMethod = PortProbe then makeFPPSResultPass PortProbe nodeId
        else makeFPPSResultFail PortProbe nodeId "Failed"

        if passingMethod = ProcessCheck then makeFPPSResultPass ProcessCheck nodeId
        else makeFPPSResultFail ProcessCheck nodeId "Failed"

        if passingMethod = LogAnalysis then makeFPPSResultPass LogAnalysis nodeId
        else makeFPPSResultFail LogAnalysis nodeId "Failed"
    ]

    // --- NodeVerificationResult Factories ---

    /// Create healthy node verification result
    let makeHealthyNodeResult (nodeId: string) : NodeVerificationResult = {
        NodeId = nodeId
        IsHealthy = true
        FPPSResults = makeAllPassingFPPS nodeId
        ConsensusAchieved = true
        VerificationTimeMs = 150L
        FailureReason = None
    }

    /// Create unhealthy node verification result
    let makeUnhealthyNodeResult (nodeId: string) (reason: string) : NodeVerificationResult = {
        NodeId = nodeId
        IsHealthy = false
        FPPSResults = makeAllFailingFPPS nodeId
        ConsensusAchieved = false
        VerificationTimeMs = 250L
        FailureReason = Some reason
    }

    /// Create degraded node result (some methods failed)
    let makeDegradedNodeResult (nodeId: string) : NodeVerificationResult = {
        NodeId = nodeId
        IsHealthy = false
        FPPSResults = makeMixedFPPS_2Pass3Fail nodeId
        ConsensusAchieved = false
        VerificationTimeMs = 200L
        FailureReason = Some "Consensus not achieved: 2/5 methods passed"
    }

    // --- ChainVerificationResult Factories ---

    /// Create healthy chain verification result
    let makeHealthyChainResult () : ChainVerificationResult = {
        ChainId = "healthy-chain"
        Status = ChainHealthy
        NodeResults = Map.ofList [
            ("indrajaal-db", makeHealthyNodeResult "indrajaal-db")
            ("indrajaal-app", makeHealthyNodeResult "indrajaal-app")
            ("indrajaal-obs", makeHealthyNodeResult "indrajaal-obs")
        ]
        ConsensusResults =
            (makeAllPassingFPPS "indrajaal-db") @
            (makeAllPassingFPPS "indrajaal-app") @
            (makeAllPassingFPPS "indrajaal-obs")
        CycleDetected = false
        BootOrderValid = true
        TotalVerificationTimeMs = 450L
        VerifiedAt = DateTime.UtcNow
        LayerResults = Map.ofList [(0, true); (1, true); (2, true)]
    }

    /// Create failed chain verification result
    let makeFailedChainResult (failedNodes: string list) : ChainVerificationResult = {
        ChainId = "failed-chain"
        Status = ChainFailed failedNodes
        NodeResults = Map.ofList [
            ("indrajaal-db", makeUnhealthyNodeResult "indrajaal-db" "Container not running")
            ("indrajaal-app", makeUnhealthyNodeResult "indrajaal-app" "Health check failed")
        ]
        ConsensusResults =
            (makeAllFailingFPPS "indrajaal-db") @
            (makeAllFailingFPPS "indrajaal-app")
        CycleDetected = false
        BootOrderValid = true
        TotalVerificationTimeMs = 500L
        VerifiedAt = DateTime.UtcNow
        LayerResults = Map.ofList [(0, false); (1, false)]
    }

    /// Create degraded chain verification result
    let makeDegradedChainResult (degradedNodes: string list) : ChainVerificationResult = {
        ChainId = "degraded-chain"
        Status = ChainDegraded degradedNodes
        NodeResults = Map.ofList [
            ("indrajaal-db", makeHealthyNodeResult "indrajaal-db")
            ("indrajaal-app", makeHealthyNodeResult "indrajaal-app")
            ("indrajaal-obs", makeDegradedNodeResult "indrajaal-obs")
        ]
        ConsensusResults =
            (makeAllPassingFPPS "indrajaal-db") @
            (makeAllPassingFPPS "indrajaal-app") @
            (makeMixedFPPS_2Pass3Fail "indrajaal-obs")
        CycleDetected = false
        BootOrderValid = true
        TotalVerificationTimeMs = 600L
        VerifiedAt = DateTime.UtcNow
        LayerResults = Map.ofList [(0, true); (1, true); (2, false)]
    }

    /// Create chain result with cycle detected
    let makeCycleDetectedResult () : ChainVerificationResult = {
        ChainId = "cyclic-chain"
        Status = ChainFailed []
        NodeResults = Map.empty
        ConsensusResults = []
        CycleDetected = true
        BootOrderValid = false
        TotalVerificationTimeMs = 10L
        VerifiedAt = DateTime.UtcNow
        LayerResults = Map.empty
    }

    /// Create not verified chain result
    let makeNotVerifiedResult () : ChainVerificationResult = {
        ChainId = "unverified-chain"
        Status = ChainNotVerified
        NodeResults = Map.empty
        ConsensusResults = []
        CycleDetected = false
        BootOrderValid = false
        TotalVerificationTimeMs = 0L
        VerifiedAt = DateTime.UtcNow
        LayerResults = Map.empty
    }

    // ========================================================================
    // CHAIN VERIFICATION STATUS TESTS
    // ========================================================================

    [<Fact>]
    let ``ChainNotVerified is initial state`` () =
        // Arrange
        let result = makeNotVerifiedResult ()

        // Assert
        Assert.Equal(ChainNotVerified, result.Status)

    [<Fact>]
    let ``ChainHealthy indicates all nodes healthy`` () =
        // Arrange
        let result = makeHealthyChainResult ()

        // Assert
        Assert.Equal(ChainHealthy, result.Status)
        Assert.True(result.NodeResults |> Map.forall (fun _ r -> r.IsHealthy))

    [<Fact>]
    let ``ChainDegraded contains list of degraded nodes`` () =
        // Arrange
        let degradedNodes = ["indrajaal-obs"]
        let result = makeDegradedChainResult degradedNodes

        // Assert
        match result.Status with
        | ChainDegraded nodes ->
            Assert.Contains("indrajaal-obs", nodes)
        | _ -> Assert.Fail("Expected ChainDegraded status")

    [<Fact>]
    let ``ChainFailed contains list of failed nodes`` () =
        // Arrange
        let failedNodes = ["indrajaal-db"; "indrajaal-app"]
        let result = makeFailedChainResult failedNodes

        // Assert
        match result.Status with
        | ChainFailed nodes ->
            Assert.Equal(2, nodes.Length)
            Assert.Contains("indrajaal-db", nodes)
            Assert.Contains("indrajaal-app", nodes)
        | _ -> Assert.Fail("Expected ChainFailed status")

    [<Fact>]
    let ``ChainVerifying is transient state`` () =
        // Arrange
        let status = ChainVerifying

        // Assert
        match status with
        | ChainVerifying -> Assert.True(true)
        | _ -> Assert.Fail("Expected ChainVerifying status")

    // ========================================================================
    // FPPS CONSENSUS METHOD TESTS (SC-CEP-003)
    // ========================================================================

    [<Fact>]
    let ``ConsensusMethod has exactly 5 methods`` () =
        // Arrange
        let methods = [PodmanStatus; HealthEndpoint; PortProbe; ProcessCheck; LogAnalysis]

        // Assert
        Assert.Equal(5, methods.Length)

    [<Fact>]
    let ``PodmanStatus is first consensus method`` () =
        // Arrange
        let result = makeFPPSResultPass PodmanStatus "node1"

        // Assert
        Assert.Equal(PodmanStatus, result.Method)

    [<Fact>]
    let ``HealthEndpoint checks HTTP health`` () =
        // Arrange
        let result = makeFPPSResultPass HealthEndpoint "node1"

        // Assert
        Assert.Equal(HealthEndpoint, result.Method)

    [<Fact>]
    let ``PortProbe checks TCP connectivity`` () =
        // Arrange
        let result = makeFPPSResultPass PortProbe "node1"

        // Assert
        Assert.Equal(PortProbe, result.Method)

    [<Fact>]
    let ``ProcessCheck verifies process running`` () =
        // Arrange
        let result = makeFPPSResultPass ProcessCheck "node1"

        // Assert
        Assert.Equal(ProcessCheck, result.Method)

    [<Fact>]
    let ``LogAnalysis checks for error patterns`` () =
        // Arrange
        let result = makeFPPSResultPass LogAnalysis "node1"

        // Assert
        Assert.Equal(LogAnalysis, result.Method)

    [<Fact>]
    let ``FPPSResult includes timestamp`` () =
        // Arrange
        let before = DateTime.UtcNow.AddSeconds(-1.0)
        let result = makeFPPSResultPass PodmanStatus "node1"
        let after = DateTime.UtcNow.AddSeconds(1.0)

        // Assert
        Assert.True(result.Timestamp >= before)
        Assert.True(result.Timestamp <= after)

    [<Fact>]
    let ``FPPSResult includes optional details`` () =
        // Arrange
        let result = makeFPPSResultFail PodmanStatus "node1" "Container not running"

        // Assert
        Assert.True(result.Details.IsSome)
        Assert.Equal("Container not running", result.Details.Value)

    // ========================================================================
    // CONSENSUS AGREEMENT CALCULATION TESTS (SC-VAL-003)
    // ========================================================================

    [<Fact>]
    let ``checkConsensusAgreement requires all 5 methods when requireAll is true`` () =
        // Arrange
        let results = makeAllPassingFPPS "node1"

        // Act
        let consensus = checkConsensusAgreement results true

        // Assert (SC-VAL-003: 100% consensus required)
        Assert.True(consensus)

    [<Fact>]
    let ``checkConsensusAgreement fails with 4 of 5 when requireAll is true`` () =
        // Arrange
        let results = [
            makeFPPSResultPass PodmanStatus "node1"
            makeFPPSResultPass HealthEndpoint "node1"
            makeFPPSResultPass PortProbe "node1"
            makeFPPSResultPass ProcessCheck "node1"
            makeFPPSResultFail LogAnalysis "node1" "Error found"
        ]

        // Act
        let consensus = checkConsensusAgreement results true

        // Assert
        Assert.False(consensus)

    [<Fact>]
    let ``checkConsensusAgreement accepts majority 3 of 5 when requireAll is false`` () =
        // Arrange
        let results = makeMixedFPPS_3Pass2Fail "node1"

        // Act
        let consensus = checkConsensusAgreement results false

        // Assert
        Assert.True(consensus)

    [<Fact>]
    let ``checkConsensusAgreement fails majority with 2 of 5 when requireAll is false`` () =
        // Arrange
        let results = makeMixedFPPS_2Pass3Fail "node1"

        // Act
        let consensus = checkConsensusAgreement results false

        // Assert
        Assert.False(consensus)

    [<Fact>]
    let ``checkConsensusAgreement fails with all methods failing`` () =
        // Arrange
        let results = makeAllFailingFPPS "node1"

        // Act
        let consensusStrict = checkConsensusAgreement results true
        let consensusLenient = checkConsensusAgreement results false

        // Assert
        Assert.False(consensusStrict)
        Assert.False(consensusLenient)

    [<Fact>]
    let ``checkConsensusAgreement handles empty result list`` () =
        // Arrange
        let results : FPPSResult list = []

        // Act
        let consensus = checkConsensusAgreement results true

        // Assert - empty list should be considered as all passing (vacuous truth)
        Assert.True(consensus)

    [<Theory>]
    [<InlineData(0, false)>]
    [<InlineData(1, false)>]
    [<InlineData(2, false)>]
    [<InlineData(3, true)>]
    [<InlineData(4, true)>]
    [<InlineData(5, true)>]
    let ``checkConsensusAgreement majority threshold is 3 of 5`` (passCount: int) (expectedResult: bool) =
        // Arrange
        let methods = [PodmanStatus; HealthEndpoint; PortProbe; ProcessCheck; LogAnalysis]
        let results =
            methods
            |> List.mapi (fun i m ->
                if i < passCount then makeFPPSResultPass m "node1"
                else makeFPPSResultFail m "node1" "Failed")

        // Act
        let consensus = checkConsensusAgreement results false

        // Assert
        Assert.Equal(expectedResult, consensus)

    [<Theory>]
    [<InlineData(0, false)>]
    [<InlineData(1, false)>]
    [<InlineData(2, false)>]
    [<InlineData(3, false)>]
    [<InlineData(4, false)>]
    [<InlineData(5, true)>]
    let ``checkConsensusAgreement strict requires all 5`` (passCount: int) (expectedResult: bool) =
        // Arrange
        let methods = [PodmanStatus; HealthEndpoint; PortProbe; ProcessCheck; LogAnalysis]
        let results =
            methods
            |> List.mapi (fun i m ->
                if i < passCount then makeFPPSResultPass m "node1"
                else makeFPPSResultFail m "node1" "Failed")

        // Act
        let consensus = checkConsensusAgreement results true

        // Assert
        Assert.Equal(expectedResult, consensus)

    // ========================================================================
    // CYCLIC DEPENDENCY DETECTION TESTS (SC-AGT-018)
    // ========================================================================

    [<Fact>]
    let ``checkCyclicDependencies returns Ok for acyclic DAG`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = checkCyclicDependencies dag

        // Assert (SC-AGT-018: Deadlock prevention)
        match result with
        | Ok () -> Assert.True(true)
        | Error msgs ->
            let errMsg = String.concat "; " msgs
            Assert.Fail(sprintf "Expected Ok, got Error: %s" errMsg)

    [<Fact>]
    let ``checkCyclicDependencies returns Error for cyclic DAG`` () =
        // Arrange
        let dag = makeCyclicDAG ()

        // Act
        let result = checkCyclicDependencies dag

        // Assert
        match result with
        | Error msgs ->
            Assert.True(msgs.Length > 0)
            Assert.True(msgs |> List.exists (fun m -> m.Contains("SC-AGT-018")))
        | Ok () -> Assert.Fail("Expected Error for cyclic DAG")

    [<Fact>]
    let ``checkCyclicDependencies error message lists involved nodes`` () =
        // Arrange
        let dag = makeCyclicDAG ()

        // Act
        let result = checkCyclicDependencies dag

        // Assert
        match result with
        | Error msgs ->
            let fullMsg = String.concat " " msgs
            Assert.True(fullMsg.Contains("container-a") || fullMsg.Contains("container-b") || fullMsg.Contains("container-c"))
        | Ok () -> Assert.Fail("Expected Error")

    [<Fact>]
    let ``hasNoCycles returns true for valid DAG`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = hasNoCycles dag

        // Assert
        Assert.True(result)

    [<Fact>]
    let ``hasNoCycles returns false for cyclic DAG`` () =
        // Arrange
        let dag = makeCyclicDAG ()

        // Act
        let result = hasNoCycles dag

        // Assert
        Assert.False(result)

    [<Fact>]
    let ``hasNoCycles returns true for empty DAG`` () =
        // Arrange
        let dag = empty

        // Act
        let result = hasNoCycles dag

        // Assert
        Assert.True(result)

    [<Fact>]
    let ``hasNoCycles returns true for single node DAG`` () =
        // Arrange
        let dag = buildDAG [makeDbContainer ()]

        // Act
        let result = hasNoCycles dag

        // Assert
        Assert.True(result)

    // ========================================================================
    // BOOT SEQUENCE VERIFICATION TESTS
    // ========================================================================

    [<Fact>]
    let ``verifyBootSequence returns Ok with correct order`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let result = verifyBootSequence dag

        // Assert
        match result with
        | Ok order ->
            Assert.Equal(3, order.Length)
            let dbIdx = List.findIndex ((=) "indrajaal-db") order
            let appIdx = List.findIndex ((=) "indrajaal-app") order
            let obsIdx = List.findIndex ((=) "indrajaal-obs") order
            Assert.True(dbIdx < appIdx)
            Assert.True(appIdx < obsIdx)
        | Error msg -> Assert.Fail(sprintf "Expected Ok, got Error: %s" msg)

    [<Fact>]
    let ``verifyBootSequence returns Error for cyclic DAG`` () =
        // Arrange
        let dag = makeCyclicDAG ()

        // Act
        let result = verifyBootSequence dag

        // Assert
        match result with
        | Error msg ->
            Assert.Contains("SC-AGT-018", msg)
        | Ok _ -> Assert.Fail("Expected Error for cyclic DAG")

    [<Fact>]
    let ``verifyBootSequence returns empty order for empty DAG`` () =
        // Arrange
        let dag = empty

        // Act
        let result = verifyBootSequence dag

        // Assert
        match result with
        | Ok order -> Assert.Empty(order)
        | Error msg -> Assert.Fail(sprintf "Expected Ok, got Error: %s" msg)

    // ========================================================================
    // LAYER HEALTH VERIFICATION TESTS
    // ========================================================================

    [<Fact>]
    let ``verifyLayerHealth returns true for healthy layer`` () =
        // Arrange
        let dag = makeLayeredDAG ()
        let nodeResults = Map.ofList [
            ("indrajaal-db", makeHealthyNodeResult "indrajaal-db")
        ]

        // Act
        let (healthy, unhealthy) = verifyLayerHealth 0 dag nodeResults

        // Assert
        Assert.True(healthy)
        Assert.Empty(unhealthy)

    [<Fact>]
    let ``verifyLayerHealth returns false for unhealthy layer`` () =
        // Arrange
        let dag = makeLayeredDAG ()
        let nodeResults = Map.ofList [
            ("indrajaal-db", makeUnhealthyNodeResult "indrajaal-db" "Failed")
        ]

        // Act
        let (healthy, unhealthy) = verifyLayerHealth 0 dag nodeResults

        // Assert
        Assert.False(healthy)
        Assert.Contains("indrajaal-db", unhealthy)

    [<Fact>]
    let ``verifyLayerHealth returns unhealthy for unverified nodes`` () =
        // Arrange
        let dag = makeLayeredDAG ()
        let nodeResults = Map.empty  // No verification results

        // Act
        let (healthy, unhealthy) = verifyLayerHealth 0 dag nodeResults

        // Assert
        Assert.False(healthy)
        Assert.Contains("indrajaal-db", unhealthy)

    [<Fact>]
    let ``verifyAllLayers returns map of layer health status`` () =
        // Arrange
        let dag = makeLayeredDAG ()
        let nodeResults = Map.ofList [
            ("indrajaal-db", makeHealthyNodeResult "indrajaal-db")
            ("indrajaal-app", makeHealthyNodeResult "indrajaal-app")
            ("indrajaal-obs", makeUnhealthyNodeResult "indrajaal-obs" "Failed")
        ]

        // Act
        let layerResults = verifyAllLayers dag nodeResults

        // Assert
        Assert.True(layerResults.[0])   // db layer healthy
        Assert.True(layerResults.[1])   // app layer healthy
        Assert.False(layerResults.[2])  // obs layer unhealthy

    [<Fact>]
    let ``verifyAllLayers handles empty DAG`` () =
        // Arrange
        let dag = empty
        let nodeResults = Map.empty

        // Act
        let layerResults = verifyAllLayers dag nodeResults

        // Assert
        Assert.Equal(1, layerResults.Count)  // Only layer 0
        Assert.True(layerResults.[0])  // Empty layer is healthy

    // ========================================================================
    // NODE VERIFICATION RESULTS AGGREGATION TESTS
    // ========================================================================

    [<Fact>]
    let ``getFailedNodes returns only unhealthy nodes`` () =
        // Arrange
        let result = makeFailedChainResult ["indrajaal-db"; "indrajaal-app"]

        // Act
        let failedNodes = getFailedNodes result

        // Assert
        Assert.Equal(2, failedNodes.Length)
        Assert.Contains("indrajaal-db", failedNodes)
        Assert.Contains("indrajaal-app", failedNodes)

    [<Fact>]
    let ``getFailedNodes returns empty for healthy chain`` () =
        // Arrange
        let result = makeHealthyChainResult ()

        // Act
        let failedNodes = getFailedNodes result

        // Assert
        Assert.Empty(failedNodes)

    [<Fact>]
    let ``getHealthyNodes returns only healthy nodes`` () =
        // Arrange
        let result = makeHealthyChainResult ()

        // Act
        let healthyNodes = getHealthyNodes result

        // Assert
        Assert.Equal(3, healthyNodes.Length)

    [<Fact>]
    let ``getHealthyNodes returns empty for failed chain`` () =
        // Arrange
        let result = makeFailedChainResult ["indrajaal-db"; "indrajaal-app"]

        // Act
        let healthyNodes = getHealthyNodes result

        // Assert
        Assert.Empty(healthyNodes)

    [<Fact>]
    let ``methodPassedForNode returns true for passing method`` () =
        // Arrange
        let result = makeHealthyChainResult ()

        // Act
        let passed = methodPassedForNode PodmanStatus "indrajaal-db" result

        // Assert
        Assert.True(passed)

    [<Fact>]
    let ``methodPassedForNode returns false for failing method`` () =
        // Arrange
        let result = makeFailedChainResult ["indrajaal-db"]

        // Act
        let passed = methodPassedForNode PodmanStatus "indrajaal-db" result

        // Assert
        Assert.False(passed)

    [<Fact>]
    let ``methodPassedForNode returns false for unknown node`` () =
        // Arrange
        let result = makeHealthyChainResult ()

        // Act
        let passed = methodPassedForNode PodmanStatus "unknown-node" result

        // Assert
        Assert.False(passed)

    [<Fact>]
    let ``getConsensusStats returns stats for all 5 methods`` () =
        // Arrange
        let result = makeHealthyChainResult ()

        // Act
        let stats = getConsensusStats result

        // Assert
        Assert.Equal(5, stats.Count)
        Assert.True(stats.ContainsKey(PodmanStatus))
        Assert.True(stats.ContainsKey(HealthEndpoint))
        Assert.True(stats.ContainsKey(PortProbe))
        Assert.True(stats.ContainsKey(ProcessCheck))
        Assert.True(stats.ContainsKey(LogAnalysis))

    [<Fact>]
    let ``getConsensusStats counts passed and total correctly`` () =
        // Arrange
        let result = makeHealthyChainResult ()

        // Act
        let stats = getConsensusStats result

        // Assert
        let (passed, total) = stats.[PodmanStatus]
        Assert.Equal(3, total)  // 3 nodes
        Assert.Equal(3, passed) // All passed

    // ========================================================================
    // CHAIN READINESS CALCULATION TESTS
    // ========================================================================

    [<Fact>]
    let ``calculateChainReadiness returns true when all nodes healthy`` () =
        // Arrange
        let dag = makeStandardChainDAG ()
        let nodeResults = Map.ofList [
            ("indrajaal-db", makeHealthyNodeResult "indrajaal-db")
            ("indrajaal-app", makeHealthyNodeResult "indrajaal-app")
            ("indrajaal-obs", makeHealthyNodeResult "indrajaal-obs")
        ]

        // Act
        let ready = calculateChainReadiness dag nodeResults

        // Assert
        Assert.True(ready)

    [<Fact>]
    let ``calculateChainReadiness returns false when mandatory dep unhealthy`` () =
        // Arrange
        let dag = makeStandardChainDAG ()
        let nodeResults = Map.ofList [
            ("indrajaal-db", makeUnhealthyNodeResult "indrajaal-db" "Failed")
            ("indrajaal-app", makeHealthyNodeResult "indrajaal-app")
            ("indrajaal-obs", makeHealthyNodeResult "indrajaal-obs")
        ]

        // Act
        let ready = calculateChainReadiness dag nodeResults

        // Assert
        Assert.False(ready)

    [<Fact>]
    let ``calculateChainReadiness returns true when only optional dep unhealthy`` () =
        // Arrange
        let dag = makeStandardChainDAG ()
        let nodeResults = Map.ofList [
            ("indrajaal-db", makeHealthyNodeResult "indrajaal-db")
            ("indrajaal-app", makeHealthyNodeResult "indrajaal-app")
            ("indrajaal-obs", makeUnhealthyNodeResult "indrajaal-obs" "Failed")  // Optional
        ]

        // Act
        let ready = calculateChainReadiness dag nodeResults

        // Assert
        // Note: obs depends on app with Optional dependency type
        // Since obs is a leaf (no one depends on it), its health doesn't affect readiness
        // The chain is still ready because db and app are healthy
        Assert.True(ready)

    [<Fact>]
    let ``calculateChainReadiness returns false for cyclic DAG`` () =
        // Arrange
        let dag = makeCyclicDAG ()
        let nodeResults = Map.ofList [
            ("container-a", makeHealthyNodeResult "container-a")
            ("container-b", makeHealthyNodeResult "container-b")
            ("container-c", makeHealthyNodeResult "container-c")
        ]

        // Act
        let ready = calculateChainReadiness dag nodeResults

        // Assert
        Assert.False(ready)

    [<Fact>]
    let ``calculateChainReadiness returns false when node not verified`` () =
        // Arrange
        let dag = makeStandardChainDAG ()
        let nodeResults = Map.ofList [
            ("indrajaal-db", makeHealthyNodeResult "indrajaal-db")
            // app not in results
        ]

        // Act
        let ready = calculateChainReadiness dag nodeResults

        // Assert
        Assert.False(ready)

    // ========================================================================
    // DEFAULT CONFIGURATION TESTS
    // ========================================================================

    [<Fact>]
    let ``defaultConfig sets correct default values`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let config = defaultConfig "my-chain" dag

        // Assert
        Assert.Equal("my-chain", config.ChainId)
        Assert.Equal("/health", config.HealthEndpointPath)
        Assert.Equal(5000, config.HealthTimeoutMs)
        Assert.True(config.RequireAllMethods)
        Assert.True(config.AllowDegradedOptional)
        Assert.Equal(50, config.LogTailLines)

    [<Fact>]
    let ``defaultConfig includes standard error patterns`` () =
        // Arrange
        let dag = makeStandardChainDAG ()

        // Act
        let config = defaultConfig "my-chain" dag

        // Assert
        Assert.Contains("ERROR", config.LogErrorPatterns)
        Assert.Contains("FATAL", config.LogErrorPatterns)
        Assert.Contains("CRITICAL", config.LogErrorPatterns)

    // ========================================================================
    // CHAIN VERIFICATION REPORT TESTS
    // ========================================================================

    [<Fact>]
    let ``generateChainReport includes chain ID`` () =
        // Arrange
        let result = makeHealthyChainResult ()

        // Act
        let report = generateChainReport result

        // Assert
        Assert.Contains("healthy-chain", report)

    [<Fact>]
    let ``generateChainReport includes status`` () =
        // Arrange
        let result = makeHealthyChainResult ()

        // Act
        let report = generateChainReport result

        // Assert
        Assert.Contains("HEALTHY", report)

    [<Fact>]
    let ``generateChainReport includes STAMP compliance`` () =
        // Arrange
        let result = makeHealthyChainResult ()

        // Act
        let report = generateChainReport result

        // Assert
        Assert.Contains("SC-AGT-018", report)
        Assert.Contains("SC-CEP-003", report)
        Assert.Contains("SC-VAL-003", report)

    [<Fact>]
    let ``generateChainReport includes layer information`` () =
        // Arrange
        let result = makeHealthyChainResult ()

        // Act
        let report = generateChainReport result

        // Assert
        Assert.Contains("Layer", report)

    [<Fact>]
    let ``generateChainReport shows degraded nodes`` () =
        // Arrange
        let result = makeDegradedChainResult ["indrajaal-obs"]

        // Act
        let report = generateChainReport result

        // Assert
        Assert.Contains("DEGRADED", report)
        Assert.Contains("indrajaal-obs", report)

    [<Fact>]
    let ``generateChainReport shows failed nodes`` () =
        // Arrange
        let result = makeFailedChainResult ["indrajaal-db"; "indrajaal-app"]

        // Act
        let report = generateChainReport result

        // Assert
        Assert.Contains("FAILED", report)
        Assert.Contains("indrajaal-db", report)

    [<Fact>]
    let ``generateChainReport shows cycle detection status`` () =
        // Arrange
        let result = makeCycleDetectedResult ()

        // Act
        let report = generateChainReport result

        // Assert
        Assert.Contains("Cycle Detected: true", report)

    // ========================================================================
    // NODE VERIFICATION RESULT TESTS
    // ========================================================================

    [<Fact>]
    let ``NodeVerificationResult captures all FPPS results`` () =
        // Arrange
        let nodeResult = makeHealthyNodeResult "test-node"

        // Assert
        Assert.Equal(5, nodeResult.FPPSResults.Length)

    [<Fact>]
    let ``NodeVerificationResult includes verification time`` () =
        // Arrange
        let nodeResult = makeHealthyNodeResult "test-node"

        // Assert
        Assert.True(nodeResult.VerificationTimeMs > 0L)

    [<Fact>]
    let ``NodeVerificationResult includes failure reason when unhealthy`` () =
        // Arrange
        let nodeResult = makeUnhealthyNodeResult "test-node" "Container crashed"

        // Assert
        Assert.True(nodeResult.FailureReason.IsSome)
        Assert.Contains("Container crashed", nodeResult.FailureReason.Value)

    [<Fact>]
    let ``NodeVerificationResult has no failure reason when healthy`` () =
        // Arrange
        let nodeResult = makeHealthyNodeResult "test-node"

        // Assert
        Assert.True(nodeResult.FailureReason.IsNone)

    // ========================================================================
    // CHAIN VERIFICATION RESULT STRUCTURE TESTS
    // ========================================================================

    [<Fact>]
    let ``ChainVerificationResult includes verification timestamp`` () =
        // Arrange
        let before = DateTime.UtcNow.AddSeconds(-1.0)
        let result = makeHealthyChainResult ()
        let after = DateTime.UtcNow.AddSeconds(1.0)

        // Assert
        Assert.True(result.VerifiedAt >= before)
        Assert.True(result.VerifiedAt <= after)

    [<Fact>]
    let ``ChainVerificationResult includes total verification time`` () =
        // Arrange
        let result = makeHealthyChainResult ()

        // Assert
        Assert.True(result.TotalVerificationTimeMs > 0L)

    [<Fact>]
    let ``ChainVerificationResult includes boot order validity`` () =
        // Arrange
        let healthyResult = makeHealthyChainResult ()
        let cycleResult = makeCycleDetectedResult ()

        // Assert
        Assert.True(healthyResult.BootOrderValid)
        Assert.False(cycleResult.BootOrderValid)

    // ========================================================================
    // ADDITIONAL EDGE CASE TESTS
    // ========================================================================

    [<Fact>]
    let ``FPPS results can have None for details`` () =
        // Arrange
        let result : FPPSResult = {
            Method = PodmanStatus
            NodeId = "node1"
            Passed = true
            Timestamp = DateTime.UtcNow
            Details = None
        }

        // Assert
        Assert.True(result.Details.IsNone)

    [<Fact>]
    let ``Multiple nodes can be verified independently`` () =
        // Arrange
        let db = makeHealthyNodeResult "indrajaal-db"
        let app = makeHealthyNodeResult "indrajaal-app"
        let obs = makeUnhealthyNodeResult "indrajaal-obs" "Failed"

        // Assert
        Assert.True(db.IsHealthy)
        Assert.True(app.IsHealthy)
        Assert.False(obs.IsHealthy)
        Assert.True(db.ConsensusAchieved)
        Assert.True(app.ConsensusAchieved)
        Assert.False(obs.ConsensusAchieved)

    [<Fact>]
    let ``Consensus results aggregate all node FPPS results`` () =
        // Arrange
        let result = makeHealthyChainResult ()

        // Assert - 3 nodes x 5 methods = 15 results
        Assert.Equal(15, result.ConsensusResults.Length)

    [<Fact>]
    let ``Layer results cover all layers in DAG`` () =
        // Arrange
        let result = makeHealthyChainResult ()

        // Assert - Layers 0, 1, 2
        Assert.Equal(3, result.LayerResults.Count)
        Assert.True(result.LayerResults.ContainsKey(0))
        Assert.True(result.LayerResults.ContainsKey(1))
        Assert.True(result.LayerResults.ContainsKey(2))

    [<Theory>]
    [<InlineData("indrajaal-db", 0)>]
    [<InlineData("indrajaal-app", 1)>]
    [<InlineData("indrajaal-obs", 2)>]
    let ``Nodes are verified at correct layers`` (nodeId: string) (expectedLayer: int) =
        // Arrange
        let dag = makeLayeredDAG ()

        // Act
        let nodesAtLayer = getNodesAtLayer expectedLayer dag

        // Assert
        Assert.Contains(nodeId, nodesAtLayer)

    [<Fact>]
    let ``Chain with only optional dependencies can be degraded`` () =
        // Arrange
        let result = makeDegradedChainResult ["indrajaal-obs"]

        // Assert
        match result.Status with
        | ChainDegraded nodes -> Assert.Single(nodes) |> ignore
        | _ -> Assert.Fail("Expected ChainDegraded")

    [<Fact>]
    let ``Failed chain with no nodes lists empty`` () =
        // Arrange
        let result = makeCycleDetectedResult ()

        // Assert
        match result.Status with
        | ChainFailed nodes -> Assert.Empty(nodes)
        | _ -> Assert.Fail("Expected ChainFailed")
