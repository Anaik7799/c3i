#!/usr/bin/env -S dotnet fsi
// sa-genotype.fsx - Cryptographic DNA Generator
// Version: 1.0.0
// Purpose: Calculate Merkle Hash of the codebase for deterministic builds.

#load "lib/cepaf/scripts/Governance.fsx"
open Cepaf.Scripts
open System
open System.IO
open System.Security.Cryptography
open System.Text

let computeHash (input: string) : string =
    using (SHA256.Create()) (fun sha256 ->
        let bytes: byte[] = Encoding.UTF8.GetBytes(input)
        let hash: byte[] = sha256.ComputeHash(bytes)
        BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant()
    )

let getFileHash (path: string) : string =
    if File.Exists(path) then
        using (SHA256.Create()) (fun sha256 ->
            using (File.OpenRead(path)) (fun stream ->
                let hash: byte[] = sha256.ComputeHash(stream)
                BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant()
            )
        )
    else ""

let calculateGenotype () : string =
    Governance.Info "GENOTYPE" "Scanning Genome (lib/, mix.lock, Dockerfile)..."
    
    let criticalFiles: string list = 
        Directory.GetFiles("lib", "*.ex", SearchOption.AllDirectories)
        |> Seq.append (Directory.GetFiles("lib", "*.fs", SearchOption.AllDirectories))
        |> Seq.append ["mix.lock"; "Dockerfile.sopv51-app"; "Dockerfile.cortex"]
        |> Seq.sort
        |> Seq.toList

    let sb: StringBuilder = StringBuilder()
    for file in criticalFiles do
        let h: string = getFileHash file
        if h <> "" then
            sb.Append(file).Append(":").Append(h).Append("|") |> ignore
    
    let genotype: string = computeHash (sb.ToString())
    Governance.Success "GENOTYPE" (sprintf "Ω_GEN: %s" genotype)
    
    // Persist to KMS
    File.WriteAllText("data/kms/current_genotype", genotype)
    genotype

let main () =
    let args: string[] = Environment.GetCommandLineArgs()

    if args |> Array.exists (fun a -> a = "--generate") then
        calculateGenotype() |> ignore
        0
    else
        0

main()
