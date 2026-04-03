namespace Cepaf.Testing

open System
open System.Security.Cryptography
open System.Text

/// PROMETHEUS verification gate for test execution.
///
/// ## What
/// Validates test configuration before allowing test_fsharp_start, generates
/// cryptographic proof tokens, and verifies level execution DAG acyclicity.
///
/// ## Why
/// SC-PROM-001 requires proof tokens before state-mutating actions.
/// SC-PROM-004 requires DAG acyclicity verification before scheduling.
/// SC-PROM-005 requires verification latency < 5ms.
///
/// ## Constraints
/// - STAMP: SC-PROM-001 (proof token), SC-PROM-004 (DAG acyclic), SC-PROM-005 (<5ms)
/// - AOR: AOR-PROM-004 (autonomous verify), AOR-SYNC-005 (proof token for mutations)
module PrometheusGate =

    // ═══════════════════════════════════════════════════════════════════
    // PROOF TOKEN
    // ═══════════════════════════════════════════════════════════════════

    /// Cryptographic proof token authorizing a test execution.
    type ProofToken = {
        /// Unique token identifier
        TokenId: string
        /// When the token was issued (UTC)
        IssuedAt: DateTime
        /// Action being authorized (e.g., "test_fsharp_start")
        Action: string
        /// HMAC-SHA256 hash of (action + timestamp + config)
        Hash: string
    }

    /// Machine-local HMAC key derived from hostname + process ID.
    /// Not meant for cross-machine verification — just local proof of gate passage.
    let private hmacKey : byte[] =
        let seed = sprintf "%s-%d" (Environment.MachineName) (Environment.ProcessId)
        SHA256.HashData(Encoding.UTF8.GetBytes(seed))

    /// Generate HMAC-SHA256 hash for a proof token
    let private computeHash (action: string) (timestamp: string) (configSummary: string) : string =
        use hmac = new HMACSHA256(hmacKey)
        let data = Encoding.UTF8.GetBytes(sprintf "%s|%s|%s" action timestamp configSummary)
        let hash = hmac.ComputeHash(data)
        Convert.ToHexStringLower(hash)

    /// Create a proof token for a given action and config summary
    let createToken (action: string) (configSummary: string) : ProofToken =
        let now = DateTime.UtcNow
        let timestamp = now.ToString("o")
        let tokenId = sprintf "PT-%s-%s" (now.ToString("yyyyMMddHHmmssfff")) (Guid.NewGuid().ToString("N").Substring(0, 8))
        {
            TokenId = tokenId
            IssuedAt = now
            Action = action
            Hash = computeHash action timestamp configSummary
        }

    // ═══════════════════════════════════════════════════════════════════
    // DAG VERIFICATION (Kahn's Algorithm)
    // ═══════════════════════════════════════════════════════════════════

    /// Level dependency edges: (prerequisite, dependent)
    /// L1 (Compile) -> L2 (Tests) -> L3 (SIL6)
    /// L1 (Compile) -> L4 (Quality) [parallel with L2/L3]
    /// L3 (SIL6) -> L5 (Health)
    /// L4 (Quality) -> L5 (Health)
    let private levelDependencies : (int * int) list =
        [ (1, 2)  // L1 -> L2
          (2, 3)  // L2 -> L3
          (1, 4)  // L1 -> L4 (parallel with L2)
          (3, 5)  // L3 -> L5
          (4, 5)  // L4 -> L5
        ]

    /// Verify DAG acyclicity using Kahn's algorithm (topological sort).
    /// Returns Ok with sorted order if acyclic, Error if cycle detected.
    /// SC-PROM-004: All execution DAGs MUST be proven acyclic.
    let verifyDagAcyclic (levels: int list) : Result<int list, string> =
        if levels.IsEmpty then Ok []
        else
            // Build adjacency and in-degree for requested levels only
            let levelSet = Set.ofList levels
            let edges =
                levelDependencies
                |> List.filter (fun (a, b) -> Set.contains a levelSet && Set.contains b levelSet)

            let mutable inDegree = levels |> List.map (fun l -> l, 0) |> Map.ofList
            let mutable adjacency = levels |> List.map (fun l -> l, []) |> Map.ofList

            for (src, dst) in edges do
                adjacency <- adjacency |> Map.add src (dst :: (Map.find src adjacency))
                inDegree <- inDegree |> Map.add dst ((Map.find dst inDegree) + 1)

            // Kahn's: start with nodes having in-degree 0
            let mutable queue = levels |> List.filter (fun l -> Map.find l inDegree = 0)
            let mutable sorted = []
            let mutable processed = 0

            while not queue.IsEmpty do
                let node = queue.Head
                queue <- queue.Tail
                sorted <- node :: sorted
                processed <- processed + 1

                for neighbor in Map.find node adjacency do
                    let newDeg = (Map.find neighbor inDegree) - 1
                    inDegree <- inDegree |> Map.add neighbor newDeg
                    if newDeg = 0 then
                        queue <- queue @ [neighbor]

            if processed = levels.Length then
                Ok (List.rev sorted)
            else
                Error (sprintf "Cycle detected in level dependencies (processed %d of %d levels)" processed levels.Length)

    // ═══════════════════════════════════════════════════════════════════
    // CONFIG VALIDATION
    // ═══════════════════════════════════════════════════════════════════

    /// Validate test parameters before allowing test execution.
    /// Uses plain parameters to avoid circular dependency with TestAgent.
    /// Returns Ok ProofToken if valid, Error with violation details.
    ///
    /// Parameters:
    ///   levels - test levels to run (1-5)
    ///   timeoutSeconds - execution timeout
    ///   verbose - verbose output flag
    ///   isRunning - whether a test is currently running
    let verifyTestStart (levels: int list) (timeoutSeconds: int) (verbose: bool) (isRunning: bool) : Result<ProofToken, string> =
        // 1. No concurrent run (SC-PROM-001)
        if isRunning then
            Error "PROMETHEUS violation: concurrent run detected (SC-PROM-001)"

        // 2. Levels are valid (1-5)
        else
            let invalidLevels = levels |> List.filter (fun l -> l < 1 || l > 5)
            if not invalidLevels.IsEmpty then
                Error (sprintf "PROMETHEUS violation: invalid levels %A (must be 1-5)" invalidLevels)

            // 3. Timeout is reasonable (>0, <7200)
            elif timeoutSeconds <= 0 then
                Error "PROMETHEUS violation: timeout must be > 0"
            elif timeoutSeconds > 7200 then
                Error "PROMETHEUS violation: timeout must be <= 7200s (2 hours)"

            // 4. DAG acyclicity (SC-PROM-004)
            else
                match verifyDagAcyclic levels with
                | Error cycleErr ->
                    Error (sprintf "PROMETHEUS violation: %s" cycleErr)
                | Ok _sortedOrder ->
                    // All checks passed — issue proof token
                    let configSummary = sprintf "levels=%A;timeout=%d;verbose=%b" levels timeoutSeconds verbose
                    let token = createToken "test_fsharp_start" configSummary
                    Ok token
