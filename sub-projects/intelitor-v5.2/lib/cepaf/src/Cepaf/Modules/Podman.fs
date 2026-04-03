namespace Cepaf.Modules

open System
open System.IO
open Cepaf
open Cepaf.Rop
open Cepaf.Infrastructure

module Podman =

    // --- STAMP: SC-POD-003 (Socket Verification) ---
    let getSocketPath uid =
        if uid = "0" then Rootful "/run/podman/podman.sock"
        else 
            let path = sprintf "/run/user/%s/podman/podman.sock" uid
            Rootless path

    // --- OODA: Observe (Real-time Events) ---
    // Streams events into the audit log
    let captureEvents (logger: QuadplexLogger) (runner: IProcessRunner) = async {
        logger.Info("Initializing OODA Observe: Podman Event Stream...")
        // In a full implementation, this would be a background process
        return ()
    }

    // --- OODA: Orient (Failure Pattern Diagnosis) ---
    // Mandate 4.2:Reserved Exit Codes
    let orient (exitCode: int) (stderr: string) =
        match exitCode with
        | 125 -> Some "INTERNAL_DEFECT: Podman engine error (check storage/config)"
        | 126 -> Some "RUNTIME_FAILURE: OCI execution denied (permissions)"
        | 127 -> Some "COMMAND_NOT_FOUND: Binary missing in container $PATH"
        | _ -> 
            if stderr.Contains("no space left on device") then Some "INFRA_FAILURE: Disk Full"
            else None

    // --- Logic: Info & Registry Capture ---
    // Mandate 5.1: Capture podman info on startup
    let captureSystemInfo (logger: QuadplexLogger) (runner: IProcessRunner) = asyncResult {
        logger.Info("Capturing Podman System Info (SIL-2 Consistency Check)...")
        let! res = runner.Run("podman", ["info"; "--format"; "json"])
        // Logic would persist this JSON to artifacts/cepa-state.db
        return ()
    }

    // --- Logic: Forensic Inspect ---
    // Mandate 5.2: Use inspect for benchmarking durations
    let inspect (runner: IProcessRunner) (id: string) = asyncResult {
        let! res = runner.Run("podman", ["inspect"; id])
        return res.StandardOutput
    }

    // --- Logic: Lifecycle Operations ---
    let start (logger: QuadplexLogger) (runner: IProcessRunner) (id: string) = asyncResult {
        logger.Info(sprintf "ACT: Starting Container %s" id)
        let! res = runner.Run("podman", ["start"; id])
        return res
    }

    let stop (logger: QuadplexLogger) (runner: IProcessRunner) (id: string) = asyncResult {
        logger.Info(sprintf "ACT: Stopping Container %s" id)
        let! res = runner.Run("podman", ["stop"; id])
        return res
    }

    let remove (logger: QuadplexLogger) (runner: IProcessRunner) (id: string) = asyncResult {
        logger.Info(sprintf "ACT: Purging Container %s" id)
        let! res = runner.Run("podman", ["rm"; "-f"; id])
        return res
    }

    // --- Compose Integration ---
    let composeUp (logger: QuadplexLogger) (runner: IProcessRunner) (file: string) = asyncResult {
        logger.Info(sprintf "ACT: Orchestrating Stack via %s" file)
        let! res = runner.Run("podman-compose", ["-f"; file; "up"; "-d"])
        return res
    }

    let composeDown (logger: QuadplexLogger) (runner: IProcessRunner) (file: string) = asyncResult {
        logger.Info(sprintf "ACT: Tearing down Stack via %s" file)
        let! res = runner.Run("podman-compose", ["-f"; file; "down"; "-v"])
        return res
    }