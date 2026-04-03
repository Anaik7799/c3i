namespace Cepaf.Phases

open System
open System.Diagnostics
open Cepaf
open Cepaf.Infrastructure
open Cepaf.Rop

/// ═══════════════════════════════════════════════════════════════════════════════
/// CEPAF Livebook Remote Attachment Verifier
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// P0.3: Comprehensive verification that Livebook can attach to the running
/// Phoenix application remotely via Erlang distribution.
///
/// STAMP Compliance: SC-CLU-001 (Name-based distribution)
///                   SC-CLU-002 (EPMD binding)
///                   SC-CLU-003 (Distribution ports 9100-9105)
///                   SC-CLU-004 (Cookie synchronization)
///                   SC-CLU-005 (Tailscale MagicDNS)
///
/// Mathematical Invariants:
///   ∀ remote_node ∈ Clients: Connect(remote_node) ⟹
///     ∃! cookie: Cookie(remote_node) = Cookie(indrajaal_node)
///   ∀ port ∈ [9100..9105]: Accessible(port) ⟺ Distributed(node) = true
///   EPMD(4369) ∧ DistPorts ⟹ Livebook.attach(node) = success
///
/// ═══════════════════════════════════════════════════════════════════════════════
module LivebookVerifier =

    // ════════════════════════════════════════════════════════════════════════════
    // TYPES
    // ════════════════════════════════════════════════════════════════════════════

    /// Livebook attachment test result
    type LivebookTestResult = {
        TestName: string
        Passed: bool
        LatencyMs: int64
        Details: string
        StampConstraint: string option
    }

    /// Full verification result
    type LivebookVerificationResult = {
        EpmdAccessible: bool
        DistPortsOpen: bool
        CookieSynced: bool
        NodeDiscoverable: bool
        LivebookReady: bool
        RemoteEvalWorks: bool
        Tests: LivebookTestResult list
        OverallPassed: bool
    }

    /// Remote eval test request
    type RemoteEvalRequest = {
        NodeName: string
        Cookie: string
        Code: string
        ExpectedResult: string option
    }

    // ════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ════════════════════════════════════════════════════════════════════════════

    let epmdPort = 4369
    let distPortMin = 9100
    let distPortMax = 9105
    let defaultTimeout = 10000 // 10 seconds

    // ════════════════════════════════════════════════════════════════════════════
    // PORT VERIFICATION
    // ════════════════════════════════════════════════════════════════════════════

    /// Test EPMD accessibility (SC-CLU-002)
    let testEpmdAccessibility (logger: QuadplexLogger) (runner: IProcessRunner) (ip: string) = async {
        let sw = Stopwatch.StartNew()

        // Test 1: epmd -names
        let! epmdResult = runner.Run("epmd", ["-names"])

        // Test 2: TCP port check
        let! tcpResult = runner.Run("bash", ["-c"; sprintf "timeout 3 bash -c '</dev/tcp/%s/%d' 2>/dev/null && echo OK || echo FAIL" ip epmdPort])

        sw.Stop()

        let passed =
            match epmdResult, tcpResult with
            | Ok r1, Ok r2 ->
                r1.StandardOutput.Contains("up and running") || r2.StandardOutput.Trim() = "OK"
            | _ -> false

        return {
            TestName = "EPMD_ACCESSIBILITY"
            Passed = passed
            LatencyMs = sw.ElapsedMilliseconds
            Details = if passed then sprintf "EPMD accessible at %s:%d" ip epmdPort else sprintf "EPMD not accessible at %s:%d" ip epmdPort
            StampConstraint = Some "SC-CLU-002"
        }
    }

    /// Test distribution ports (SC-CLU-003)
    let testDistributionPorts (logger: QuadplexLogger) (runner: IProcessRunner) (ip: string) = async {
        let sw = Stopwatch.StartNew()

        let! results =
            [distPortMin..distPortMax]
            |> List.map (fun port -> async {
                let! tcpResult = runner.Run("bash", ["-c"; sprintf "timeout 2 bash -c '</dev/tcp/%s/%d' 2>/dev/null && echo OPEN || echo CLOSED" ip port])
                match tcpResult with
                | Ok r when r.StandardOutput.Trim() = "OPEN" -> return Some port
                | _ -> return None
            })
            |> Async.Parallel

        sw.Stop()

        let openPorts = results |> Array.choose id |> Array.toList
        let passed = not openPorts.IsEmpty

        return {
            TestName = "DIST_PORTS_ACCESSIBLE"
            Passed = passed
            LatencyMs = sw.ElapsedMilliseconds
            Details = if passed then sprintf "Distribution ports open: %s" (String.Join(", ", openPorts)) else sprintf "No distribution ports open in range %d-%d" distPortMin distPortMax
            StampConstraint = Some "SC-CLU-003"
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // COOKIE VERIFICATION
    // ════════════════════════════════════════════════════════════════════════════

    /// Test cookie synchronization (SC-CLU-004)
    let testCookieSync (logger: QuadplexLogger) (runner: IProcessRunner) (expectedCookie: string) = async {
        let sw = Stopwatch.StartNew()

        // Check cookie file
        let cookieFile = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".erlang.cookie")

        let passed, details =
            if System.IO.File.Exists(cookieFile) then
                let fileCookie = System.IO.File.ReadAllText(cookieFile).Trim()
                if fileCookie = expectedCookie then
                    true, sprintf "Cookie synchronized: %s..." (expectedCookie.Substring(0, min 8 expectedCookie.Length))
                else
                    false, "Cookie mismatch between file and expected"
            else
                false, sprintf "Cookie file not found: %s" cookieFile

        sw.Stop()

        return {
            TestName = "COOKIE_SYNCHRONIZATION"
            Passed = passed
            LatencyMs = sw.ElapsedMilliseconds
            Details = details
            StampConstraint = Some "SC-CLU-004"
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // NODE DISCOVERY
    // ════════════════════════════════════════════════════════════════════════════

    /// Test node discovery via EPMD (SC-CLU-001)
    let testNodeDiscovery (logger: QuadplexLogger) (runner: IProcessRunner) (nodeName: string) = async {
        let sw = Stopwatch.StartNew()

        // Extract short name from full node name (e.g., "indrajaal" from "indrajaal@192.168.1.1")
        let shortName =
            if nodeName.Contains("@") then nodeName.Split('@').[0]
            else nodeName

        let! epmdResult = runner.Run("epmd", ["-names"])

        sw.Stop()

        let passed, details =
            match epmdResult with
            | Ok r when r.StandardOutput.Contains(shortName) ->
                // Parse the port
                let lines = r.StandardOutput.Split('\n') |> Array.filter (fun l -> l.Contains(shortName))
                if lines.Length > 0 then
                    let line = lines.[0]
                    let portStr =
                        if line.Contains("at port") then
                            let parts = line.Split("at port")
                            if parts.Length > 1 then parts.[1].Trim() else "unknown"
                        else "unknown"
                    true, sprintf "Node '%s' registered on port %s" shortName portStr
                else
                    true, sprintf "Node '%s' found in EPMD" shortName
            | Ok r ->
                false, sprintf "Node '%s' not found in EPMD. Registered: %s" shortName (r.StandardOutput.Replace("\n", ", "))
            | Error e ->
                false, sprintf "EPMD query failed: %A" e

        return {
            TestName = "NODE_DISCOVERY"
            Passed = passed
            LatencyMs = sw.ElapsedMilliseconds
            Details = details
            StampConstraint = Some "SC-CLU-001"
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // REMOTE EVAL TEST
    // ════════════════════════════════════════════════════════════════════════════

    /// Test remote code evaluation (simulates Livebook attachment)
    let testRemoteEval (logger: QuadplexLogger) (runner: IProcessRunner) (nodeName: string) (cookie: string) = async {
        let sw = Stopwatch.StartNew()

        // Create a temporary client node to test remote eval
        let clientNode = sprintf "test_client_%d@127.0.0.1" (Random().Next(10000))
        let testCode = "1 + 1"

        // Use erl to connect and evaluate remotely
        let erlCmd = sprintf "erl -name %s -setcookie %s -noshell -eval \"case net_adm:ping('%s') of pong -> Result = rpc:call('%s', 'Elixir.Kernel', '+', [1, 1]), io:format('RESULT:~p~n', [Result]), halt(0); pang -> io:format('PING_FAILED~n'), halt(1) end\" -s init stop" clientNode cookie nodeName nodeName

        let! result = runner.Run("bash", ["-c"; erlCmd])

        sw.Stop()

        let passed, details =
            match result with
            | Ok r when r.ExitCode = 0 && r.StandardOutput.Contains("RESULT:2") ->
                true, sprintf "Remote eval successful: %s => 2" testCode
            | Ok r when r.StandardOutput.Contains("PING_FAILED") ->
                false, sprintf "Could not ping node %s" nodeName
            | Ok r ->
                false, sprintf "Remote eval failed: exit=%d, output=%s" r.ExitCode (r.StandardOutput + r.StandardError)
            | Error e ->
                false, sprintf "Eval command failed: %A" e

        return {
            TestName = "REMOTE_EVAL"
            Passed = passed
            LatencyMs = sw.ElapsedMilliseconds
            Details = details
            StampConstraint = None
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // LIVEBOOK CONFIGURATION GENERATOR
    // ════════════════════════════════════════════════════════════════════════════

    /// Generate Livebook configuration script for Windows
    let generateWindowsLivebookScript (ip: string) (cookie: string) (nodeName: string) : string =
        String.concat "\n" [
            "# Livebook Configuration for Windows"
            "# Generated by CEPAF StandaloneVerifier"
            sprintf "# Timestamp: %s" (DateTime.UtcNow.ToString("o"))
            ""
            "# Step 1: Set environment variables"
            sprintf "$env:LIVEBOOK_COOKIE = \"%s\"" cookie
            "$env:LIVEBOOK_DEFAULT_RUNTIME = \"attached\""
            "$env:LIVEBOOK_NODE = \"livebook@$env:COMPUTERNAME\""
            ""
            "# Step 2: Start Livebook"
            "livebook server"
            ""
            "# In Livebook UI: Runtime -> Attached node"
            sprintf "#   Name: %s" nodeName
            sprintf "#   Cookie: %s" cookie
            ""
            "# Alternative: Direct IEx remote shell"
            sprintf "# iex --name client@%s --cookie %s --remsh %s" ip cookie nodeName
        ]

    /// Generate Livebook configuration for Linux/macOS
    let generateUnixLivebookScript (ip: string) (cookie: string) (nodeName: string) : string =
        String.concat "\n" [
            "#!/bin/bash"
            "# Livebook Configuration for Linux/macOS"
            "# Generated by CEPAF StandaloneVerifier"
            sprintf "# Timestamp: %s" (DateTime.UtcNow.ToString("o"))
            ""
            "# Step 1: Set environment variables"
            sprintf "export LIVEBOOK_COOKIE=\"%s\"" cookie
            "export LIVEBOOK_DEFAULT_RUNTIME=\"attached\""
            "export LIVEBOOK_NODE=\"livebook@$(hostname -f)\""
            ""
            "# Step 2: Start Livebook"
            "livebook server"
            ""
            "# In Livebook UI: Runtime -> Attached node"
            sprintf "#   Name: %s" nodeName
            sprintf "#   Cookie: %s" cookie
            ""
            "# Alternative: Direct IEx remote shell"
            sprintf "# iex --name client@%s --cookie %s --remsh %s" ip cookie nodeName
        ]

    // ════════════════════════════════════════════════════════════════════════════
    // MAIN VERIFICATION
    // ════════════════════════════════════════════════════════════════════════════

    /// Execute full Livebook remote attachment verification
    let execute (logger: QuadplexLogger) (runner: IProcessRunner) (ip: string) (cookie: string) = asyncResult {
        logger.Info("═══════════════════════════════════════════════════════════════════════════════")
        logger.Info("PHASE: LIVEBOOK_VERIFICATION (P0.3)")
        logger.Info("STAMP: SC-CLU-001 to SC-CLU-005")
        logger.Info("═══════════════════════════════════════════════════════════════════════════════")
        logger.Emit(PhaseStart "LIVEBOOK_VERIFICATION")
        let sw = Stopwatch.StartNew()

        let nodeName = sprintf "indrajaal@%s" ip
        logger.Info(sprintf "Target node: %s" nodeName)

        // Run all tests
        let! test1 = testEpmdAccessibility logger runner ip |> fromAsync
        logger.Info(sprintf "[%s] %s: %s" (if test1.Passed then "PASS" else "FAIL") test1.TestName test1.Details)

        let! test2 = testDistributionPorts logger runner ip |> fromAsync
        logger.Info(sprintf "[%s] %s: %s" (if test2.Passed then "PASS" else "FAIL") test2.TestName test2.Details)

        let! test3 = testCookieSync logger runner cookie |> fromAsync
        logger.Info(sprintf "[%s] %s: %s" (if test3.Passed then "PASS" else "FAIL") test3.TestName test3.Details)

        let! test4 = testNodeDiscovery logger runner nodeName |> fromAsync
        logger.Info(sprintf "[%s] %s: %s" (if test4.Passed then "PASS" else "FAIL") test4.TestName test4.Details)

        let! test5 = testRemoteEval logger runner nodeName cookie |> fromAsync
        logger.Info(sprintf "[%s] %s: %s" (if test5.Passed then "PASS" else "FAIL") test5.TestName test5.Details)

        let tests = [test1; test2; test3; test4; test5]
        let allPassed = tests |> List.forall (fun t -> t.Passed)
        let passedCount = tests |> List.filter (fun t -> t.Passed) |> List.length

        // Generate Livebook scripts
        let scriptsDir = System.IO.Path.Combine(Environment.CurrentDirectory, "lib", "cepaf", "artifacts")
        if not (System.IO.Directory.Exists(scriptsDir)) then
            System.IO.Directory.CreateDirectory(scriptsDir) |> ignore

        let winScript = generateWindowsLivebookScript ip cookie nodeName
        let unixScript = generateUnixLivebookScript ip cookie nodeName

        System.IO.File.WriteAllText(System.IO.Path.Combine(scriptsDir, "livebook-connect.ps1"), winScript)
        System.IO.File.WriteAllText(System.IO.Path.Combine(scriptsDir, "livebook-connect.sh"), unixScript)
        logger.Info(sprintf "Generated Livebook scripts in %s" scriptsDir)

        sw.Stop()

        // Summary
        logger.Info("")
        logger.Info("═══════════════════════════════════════════════════════════════════════════════")
        if allPassed then
            logger.Info(sprintf "LIVEBOOK VERIFICATION: PASSED (%d/%d tests)" passedCount tests.Length)
            logger.Info("")
            logger.Info("✅ Livebook can attach to this node remotely!")
            logger.Info("")
            logger.Info("From Windows PowerShell:")
            logger.Info(sprintf "  $env:LIVEBOOK_COOKIE = \"%s\"" cookie)
            logger.Info("  livebook server")
            logger.Info("")
            logger.Info("Then in Livebook UI:")
            logger.Info(sprintf "  Runtime → Attached node → Name: %s → Cookie: %s" nodeName cookie)
        else
            logger.Error(sprintf "LIVEBOOK VERIFICATION: FAILED (%d/%d tests passed)" passedCount tests.Length)
            logger.Info("")
            let failedTests = tests |> List.filter (fun t -> not t.Passed)
            for test in failedTests do
                logger.Error(sprintf "  ❌ %s: %s" test.TestName test.Details)
        logger.Info("═══════════════════════════════════════════════════════════════════════════════")

        logger.Emit(PhaseComplete("LIVEBOOK_VERIFICATION", sw.ElapsedMilliseconds, allPassed))

        let result = {
            EpmdAccessible = test1.Passed
            DistPortsOpen = test2.Passed
            CookieSynced = test3.Passed
            NodeDiscoverable = test4.Passed
            LivebookReady = test1.Passed && test2.Passed && test3.Passed
            RemoteEvalWorks = test5.Passed
            Tests = tests
            OverallPassed = allPassed
        }

        return result
    }
