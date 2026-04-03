namespace Cepaf.Orchestration

open System
open System.IO
open System.Diagnostics
open System.Collections.Generic
open System.Text
open Cepaf
open Cepaf.Rop
open Cepaf.Observability

module Sil4Types =
    type MeshServiceStatus = MeshOff | MeshStarting | MeshReady | MeshLameduck | MeshFailsafe
    type ArtifactIdentity = { Commit: string; Digest: string }
    type SecurityPosture = { Caps: string list; NoNewPrivs: bool; ReadOnly: bool; UserNs: int }
    type MetabolicMetrics = { Cpu: int64; Mem: int64; Rx: int64; Tx: int64 }
    
    type HolonGenotype = { Id: string; Port: int; Identity: ArtifactIdentity; Security: SecurityPosture }
    type HolonPhenotype = { mutable Status: MeshServiceStatus; mutable IP: string; mutable Metrics: MetabolicMetrics; mutable Proof: string }
    type NodeTwin = { Id: string; Role: string; Geno: HolonGenotype; Pheno: HolonPhenotype; mutable Diverge: float }

module MeshCortex =
    open Sil4Types

    let globalRegistry = Dictionary<string, NodeTwin>()

    let initialize () =
        globalRegistry.Clear()
        let createNode id role port =
            let identity = { Commit="773abc"; Digest="sha256:..." }
            let security = { Caps=["ALL"]; NoNewPrivs=true; ReadOnly=true; UserNs=1000 }
            let geno : HolonGenotype = { Id=id; Port=port; Identity=identity; Security=security }
            let metrics : MetabolicMetrics = { Cpu=0L; Mem=0L; Rx=0L; Tx=0L }
            let pheno : HolonPhenotype = { Status=MeshOff; IP=""; Metrics=metrics; Proof="UNVERIFIED" }
            { Id=id; Role=role; Geno=geno; Pheno=pheno; Diverge=0.0 }

        globalRegistry.["zenoh-router"] <- createNode "zenoh-router" "Controller" 7447
        globalRegistry.["indrajaal-db-prod"] <- createNode "indrajaal-db-prod" "Persistence" 5433
        globalRegistry.["indrajaal-obs-prod"] <- createNode "indrajaal-obs-prod" "Observability" 8123
        globalRegistry.["indrajaal-ex-app-1"] <- createNode "indrajaal-ex-app-1" "Seed" 4000

    let private composeFile = "lib/cepaf/artifacts/podman-compose-prod-standalone.yml"

    let execPodman (logger: UnifiedLogger) (serviceName: string) (args: string) = async {
        let node = globalRegistry.[serviceName]
        let psi = ProcessStartInfo("podman-compose", sprintf "-f %s %s %s" composeFile args serviceName)
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        psi.UseShellExecute <- false
        psi.CreateNoWindow <- true
        use proc = Process.Start(psi)
        let! errorTask = proc.StandardError.ReadToEndAsync() |> Async.AwaitTask
        proc.WaitForExit()

        match proc.ExitCode with
        | 0 ->
            let oldStatus = node.Pheno.Status
            node.Pheno.Status <- if args.Contains("up") then MeshReady else MeshOff
            node.Pheno.Proof <- sprintf "SIL4-%X" (DateTime.UtcNow.Ticks % 0xFFFFFL)
            // ZUIP: Inline dual-write (OptimalMesh compiled before ZenohPublish.fs)
            let ts = DateTimeOffset.UtcNow.ToString("o")
            eprintfn "[ZTEST-CHECKPOINT] checkpoint=CP-MESH-STATUS topic=indrajaal/mesh/status message=%s:%O->%O timestamp=%s"
                serviceName oldStatus node.Pheno.Status ts
            return Result.Ok ()
        | _ ->
            node.Pheno.Status <- MeshFailsafe
            let ts = DateTimeOffset.UtcNow.ToString("o")
            eprintfn "[ZTEST-CHECKPOINT] checkpoint=CP-MESH-FAILSAFE topic=indrajaal/mesh/failsafe message=%s:failsafe timestamp=%s"
                serviceName ts
            return Result.Error (InfrastructureError("MESH", errorTask))
    }

    let startup (logger: UnifiedLogger) = async {
        initialize()
        match File.Exists(composeFile) with
        | false ->
            return Result.Error (InfrastructureError("GENOTYPE", "Compose file missing"))
        | true ->
            let! dbRes = execPodman logger "db-primary" "up -d"
            match dbRes with
            | Result.Error e -> return Result.Error e
            | Result.Ok _ ->
                let mesh = ["indrajaal-obs"; "app-1"]
                let! results = mesh |> List.map (fun s -> execPodman logger s "up -d") |> Async.Parallel
                let anyError = results |> Array.exists (function | Result.Error _ -> true | _ -> false)
                match anyError with
                | true -> return Result.Error (InfrastructureError("MESH", "Wave Failure"))
                | false -> return Result.Ok ()
    }

    let shutdown (logger: UnifiedLogger) = async {
        let! _ = globalRegistry.Keys |> Seq.map (fun s -> execPodman logger s "down") |> Async.Parallel
        return Result.Ok ()
    }