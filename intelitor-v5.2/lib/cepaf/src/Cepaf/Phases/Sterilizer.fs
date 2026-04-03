namespace Cepaf.Phases

open Cepaf
open Cepaf.Infrastructure
open Cepaf.Rop

module Sterilizer =

    let verifySterilization (logger: QuadplexLogger) (runner: IProcessRunner) = asyncResult {
        logger.Info("Verifying Sterilization (Ensuring no project artifacts remain)...")
        let! result = runner.Run("podman", ["ps"; "-a"; "--filter"; "label=project=indrajaal"; "--format"; "{{.ID}}"])
        if result.StandardOutput.Trim().Length > 0 then
            return! fromResult (Error (ValidationFailed("Sterilization", "Project containers still exist after VTO")))
        else
            logger.Info("Sterilization VERIFIED.")
            return ()
    }

    let execute (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) = asyncResult {
        logger.Info("Starting Phase: VTO (Sterilization / Clean Slate)")
        logger.Emit(PhaseStart "VTO")
        
        for env in config.Environments do
            let file = 
                match env with
                | DEV -> "podman-compose-3container.yml"
                | TEST -> "podman-compose-testing.yml"
                | DEMO -> "podman-compose.yml"
                | PROD -> "podman-compose-secure.yml"
                | SYSTEM_STANDALONE_DB_TEST -> "lib/cepaf/artifacts/podman-compose-db-standalone.yml"
                | SYSTEM_STANDALONE_OBS_TEST -> "lib/cepaf/artifacts/podman-compose-obs-standalone.yml"
                | MESH -> "podman-compose-cluster.yml"
                | SIL6 -> "lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml"
                | SHADOW_MODE_EVAL -> "podman-compose-cluster.yml"

            let! _ = runner.Run("podman-compose", ["-f"; file; "down"; "-v"])
            ()

        // Wipe data temp directory (Safe Cleanup)
        logger.Info("Wiping temporary artifacts...")
        if System.IO.Directory.Exists("./data/tmp") then
            System.IO.Directory.GetFiles("./data/tmp") |> Array.iter System.IO.File.Delete

        do! verifySterilization logger runner
        
        logger.Emit(PhaseComplete("VTO", 0L, true))
        return ()
    }
