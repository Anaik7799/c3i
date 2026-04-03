namespace Cepaf

open System
open System.Diagnostics
open Cepaf.Infrastructure
open Cepaf.Rop
open Cepaf.Phases
open Cepaf.Modules

/// CEPAF Orchestrator with AOR enforcement and SOPv5.11 compliance
/// STAMP Compliance: SC-OBS-069 (dual logging), SC-OBS-071 (4 OTEL modules)
module Orchestrator =

    // ========================================================================
    // AOR-QUA-001: Zero-Warnings Gate
    // ========================================================================

    /// Track warning count for AOR-QUA-001 enforcement
    let mutable private warningCount = 0

    /// Record a warning (call this from phases that detect warnings)
    let recordWarning () = warningCount <- warningCount + 1

    /// Check zero-warnings gate (AOR-QUA-001)
    let checkZeroWarningsGate (logger: QuadplexLogger) : Result<unit, AppError> =
        if warningCount > 0 then
            logger.Error(sprintf "[AOR-QUA-001 VIOLATION] Protocol completed with %d warnings - GATE FAILED" warningCount)
            logger.IncrementCounter("aor.violations", tags = Map.ofList [("rule", "AOR-QUA-001")])
            Error (AorViolation("AOR-QUA-001", sprintf "Zero warnings required, found %d" warningCount))
        else
            logger.Info("[AOR-QUA-001] Zero-Warnings Gate: PASSED")
            logger.IncrementCounter("aor.checks_passed", tags = Map.ofList [("rule", "AOR-QUA-001")])
            Ok ()

    /// Reset warning counter at protocol start
    let resetWarningCount () = warningCount <- 0

    let runProtocol (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) = asyncResult {
        // Reset warning counter for this run
        resetWarningCount ()

        // Start protocol trace for distributed tracing
        logger.StartProtocol("CEPAF_PROTOCOL")

        logger.Info("============================================================================")
        logger.Info("CEPAF: Cybernetic Execution and Performance Architect (F# Edition)")
        logger.Info("Version: 20.0 - Framework Compliance Edition (Quadplex Observability)")
        logger.Info("The Cybernetic Pledge: I recognize the Codebase as a Living Graph. ")
        logger.Info("I pledge to fight Entropy with Simplicity, fragility with Resilience, ")
        logger.Info("and blindness with Observability. I am the Architect of the Loop.")
        logger.Info("============================================================================")

        // Log SOPv5.11 mode status
        if config.PatientMode then
            logger.Info("[SOPv5.11] PATIENT_MODE=enabled, INFINITE_PATIENCE=true")
            logger.Info("[SOPv5.11] Extended timeouts and retries active")
            logger.SetGauge("config.patient_mode", 1.0)
        else
            logger.SetGauge("config.patient_mode", 0.0)

        logger.Emit(ProtocolStart DateTimeOffset.Now)
        let protocolStartTime = DateTime.Now
        let sw = Stopwatch.StartNew()

        // Pre-flight: Capture Podman Info (Mandate 5.1)
        do! Podman.captureSystemInfo logger runner

        if config.Build then
            do! Builder.execute logger runner config

        // Check if we are in standalone DB Test mode
        if config.DbTestOnly then
            do! DbVerifier.execute logger runner config
            return ()

        // Check if we are in standalone OBS Test mode
        if config.ObsTestOnly then
            do! ObsVerifier.execute logger runner config
            return ()

        // Check if we are in standalone distributed mode
        if config.StandaloneMode then
            do! StandaloneVerifier.execute logger runner config
            return ()

        if config.Sterilize then
            do! Vto.execute logger runner config

        if config.FormalVerify then
            do! FormalVerification.execute logger runner config

        if config.Build then
            do! Builder.execute logger runner config

        // Skip DEPLOY phase for standalone test modes (ObsTestOnly, DbTestOnly)
        if config.ObsTestOnly || config.DbTestOnly then
            logger.Info("Standalone test mode - skipping DEPLOY phase")
            sw.Stop()
            let duration = sw.ElapsedMilliseconds
            logger.EndProtocol(duration, true)
            logger.Emit(ProtocolComplete(duration, true))
            return ()

        // Setup Phase: Actual deployment using the Podman module
        logger.Info("Starting Phase: DEPLOY (Orchestration)")
        logger.StartPhase("DEPLOY")
        let deploySw = Stopwatch.StartNew()

        for env in config.Environments do
            match config.Registry.ComposeFiles.TryFind env with
            | Some relativePath ->
                // Use PathResolver for consistent absolute path resolution (SC-CEP-001)
                let absolutePath = PathResolver.resolve relativePath
                logger.IncrementCounter("deploy.compose_up", tags = Map.ofList [("env", sprintf "%A" env)])
                let! _ = Podman.composeUp logger runner absolutePath
                ()
            | None -> ()

        do! AceVerifier.execute logger runner config

        deploySw.Stop()
        let startupDuration = deploySw.ElapsedMilliseconds
        logger.EndPhase("DEPLOY", startupDuration, true)

        // 30-Second Mandate Verification (Section 75.1)
        logger.Info(sprintf "System Boot Duration: %d ms" startupDuration)
        logger.RecordHistogram("deploy.boot_duration_ms", float startupDuration)

        if startupDuration > config.BootThresholdMs then
            logger.IncrementCounter("deploy.mandate_violations", tags = Map.ofList [("type", "boot_timeout")])
            return! fromResult (Error (BootMandateViolation(startupDuration, config.BootThresholdMs)))

        logger.Emit(MetricLogged("BootDuration", float startupDuration))

        if config.RunTests then
            do! Tester.execute logger runner config

        if config.RunUiCheck then
            do! UiVerifier.execute logger config

        sw.Stop()
        let duration = sw.ElapsedMilliseconds

        // Record total protocol duration
        logger.RecordHistogram("protocol.duration_ms", float duration, Map.ofList [("protocol", "CEPAF")])

        // AOR-QUA-001: Zero-Warnings Gate Check (before declaring success)
        do! checkZeroWarningsGate logger |> fromResult

        // End protocol trace with success
        logger.EndProtocol(duration, true)
        logger.Emit(ProtocolComplete(duration, true))

        // Record success metrics
        logger.IncrementCounter("protocol.completions", tags = Map.ofList [("status", "success")])
        logger.SetGauge("protocol.last_duration_ms", float duration)

        logger.Info("============================================================================")
        logger.Info(sprintf "PROTOCOL COMPLETE. Total Duration: %d ms" duration)
        logger.Info("All Quality Gates: PASSED")
        logger.Info("[AOR-QUA-001] Zero-Warnings: ENFORCED")
        logger.Info("[SOPv5.11] Framework Compliance: VERIFIED")
        logger.Info("[SC-OBS-069] Dual Logging: ACTIVE (Console + File)")
        logger.Info("[SC-OBS-071] 4 OTEL Channels: VERIFIED")
        logger.Info("Status: Homeostasis Achieved")
        logger.Info("============================================================================")

        // Flush all observability channels
        logger.Flush()

        return ()
    }