namespace Cepaf.Phases

open Cepaf
open Cepaf.Infrastructure
open Cepaf.Rop

/// Builder phase with OODA-based error correction and SOPv5.11 Patient Mode support
module Builder =

    /// Get Patient Mode aware timeout (longer timeouts when Patient Mode enabled)
    let private getTimeout (config: CepaConfig) : int64 =
        if config.PatientMode then 180000L else 15000L  // 3 min patient, 15s normal

    /// Get retry count based on Patient Mode
    let private getMaxRetries (config: CepaConfig) : int =
        if config.PatientMode then 3 else 1

    let buildWithOoda (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) (image: string) (file: string) = asyncResult {
        let timeout = getTimeout config
        let maxRetries = getMaxRetries config
        let t = createTask (sprintf "BUILD_%s" image) (sprintf "Image Factory: %s" image) "Blueprint available" "Image Layered Successfully" "Absent" "Built" timeout

        if config.PatientMode then
            logger.Info(sprintf "[PATIENT_MODE] Building %s with extended timeout (%dms) and %d retries" image timeout maxRetries)

        do! runTask logger t (fun () -> asyncResult {
            let! res = runner.Run("podman", ["build"; "-t"; image; "-f"; file; "."], true) |> fromAsync
            match res with
            | Ok _ -> return ()
            | Error (ProcessError(_, _, stderr)) ->
                match Operations.classifyError stderr with
                | Some patch ->
                    match patch with
                    | Operations.ApplyPatch (oldStr, newStr) ->
                        logger.Info(sprintf "OODA Corrective Action: Patching %s" file)
                        do! Operations.patchFileAsync file oldStr newStr
                        logger.Emit(OodaTransition("Orient", "Self-Corrected Typo"))
                        let! _ = runner.Run("podman", ["build"; "-t"; image; "-f"; file; "."], true)
                        return ()
                    | Operations.WaitAndRetry reason when config.PatientMode ->
                        // Patient Mode: retry after delay
                        logger.Info(sprintf "[PATIENT_MODE] %s - waiting and retrying" reason)
                        do! Async.Sleep 5000 |> fromAsync
                        let! _ = runner.Run("podman", ["build"; "-t"; image; "-f"; file; "."], true)
                        return ()
                    | _ -> return! fromResult (Error (ProcessError("podman build", 1, stderr)))
                | None -> return! fromResult (Error (ProcessError("podman build", 1, stderr)))
            | Error e -> return! fromResult (Error e)
        })
    }

    let execute (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) = asyncResult {
        logger.Info("PHASE: BUILDER (OODA-based Image Factory)")
        if config.PatientMode then
            logger.Info("[PATIENT_MODE] SOPv5.11 Patient Mode ENABLED - extended timeouts active")
        logger.Emit(PhaseStart "BUILDER")

        for KeyValue(image, file) in config.Registry.Dockerfiles do
            do! buildWithOoda logger runner config image file

        logger.Emit(PhaseComplete("BUILDER", 0L, true))
        return ()
    }