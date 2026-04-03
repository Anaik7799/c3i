namespace Cepaf.Phases

open System.Diagnostics
open Cepaf
open Cepaf.Infrastructure
open Cepaf.Rop
open Cepaf.Modules

/// VTO (Verify-Terminate-Orchestrate) Phase for container sterilization.
/// STAMP Compliance: SC-CNT-009 (NixOS containers), SC-OBS-069 (dual logging)
module Vto =

    let verifySterilization (logger: QuadplexLogger) (runner: IProcessRunner) = asyncResult {
        let! (result: CliWrap.Buffered.BufferedCommandResult) = runner.Run("podman", ["ps"; "-a"; "--filter"; "label=project=indrajaal"; "--format"; "{{.ID}}"])
        if result.StandardOutput.Trim().Length > 0 then
            logger.IncrementCounter("vto.sterilization_failures")
            return! fromResult (Error (ValidationFailed("Sterilization", "Project containers still exist after VTO")))
        else
            logger.IncrementCounter("vto.sterilization_success")
            return ()
    }

    let execute (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) = asyncResult {
        logger.Info("PHASE: VTO (Sterilization / Clean Slate)")
        logger.StartPhase("VTO")
        logger.Emit(PhaseStart "VTO")
        let sw = Stopwatch.StartNew()

        let t1 = createTask
                    "VTO_CLEANUP"
                    "Recursive Container & Volume Sterilization"
                    "Registry context available"
                    "No project containers exist"
                    "Dirty"
                    "Sterilized"
                    10000L

        do! runTask logger t1 (fun () -> asyncResult {
            for env in config.Environments do
                match config.Registry.ComposeFiles.TryFind env with
                | Some relativePath ->
                    // Use PathResolver for consistent absolute path resolution (SC-CEP-001)
                    let absolutePath = PathResolver.resolve relativePath
                    logger.IncrementCounter("vto.compose_down", tags = Map.ofList [("env", sprintf "%A" env)])
                    let! _ = Podman.composeDown logger runner absolutePath
                    ()
                | None -> ()

            if System.IO.Directory.Exists(config.Registry.TempDir) then
                let files = System.IO.Directory.GetFiles(config.Registry.TempDir)
                logger.SetGauge("vto.temp_files_cleaned", float files.Length)
                files |> Array.iter System.IO.File.Delete

            do! verifySterilization logger runner
            return ()
        })

        sw.Stop()
        logger.RecordHistogram("phase.duration_ms", float sw.ElapsedMilliseconds, Map.ofList [("phase", "VTO")])
        logger.EndPhase("VTO", sw.ElapsedMilliseconds, true)
        logger.Emit(PhaseComplete("VTO", sw.ElapsedMilliseconds, true))
        return ()
    }
