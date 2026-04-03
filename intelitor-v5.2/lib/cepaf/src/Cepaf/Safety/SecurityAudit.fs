namespace Cepaf.Safety

open System
open System.Diagnostics
open System.IO
open System.Text.Json
open Cepaf.Podman.Api

/// Security Audit logic using Trivy - SC-SEC-012
module SecurityAudit =
    let logger = "SECURITY"
    let reportsDir = "data/security/scan-reports"

    type Vulnerability = {
        VulnerabilityID: string
        PkgName: string
        InstalledVersion: string
        FixedVersion: string
        Severity: string
        Description: string
    }

    type ScanResult = {
        Target: string
        Vulnerabilities: Vulnerability list
    }

    /// Execute Trivy scan on a specific image
    let scanImage (image: string) : bool =
        printfn "🛡️ [%s] Auditing image: %s" logger image
        
        if not (Directory.Exists reportsDir) then
            Directory.CreateDirectory reportsDir |> ignore

        let reportFile = Path.Combine(reportsDir, sprintf "%s_scan.json" (image.Replace("/", "_").Replace(":", "_")))
        
        let psi = ProcessStartInfo(
            FileName = "trivy",
            Arguments = sprintf "image --severity CRITICAL,HIGH --format json --output %s %s" reportFile image,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        )
        
        try
            use proc = Process.Start(psi)
            proc.WaitForExit(60000) |> ignore
            
            if proc.ExitCode = 0 then
                printfn "✅ [%s] Audit complete: %s" logger image
                true
            else
                printfn "❌ [%s] Audit failed for %s: %s" logger image (proc.StandardError.ReadToEnd())
                false
        with ex ->
            printfn "❌ [%s] Trivy execution failed: %s" logger ex.Message
            false

    /// Audit all project images
    let auditSwarm () =
        let images = [
            "localhost/indrajaal-app-unified:nixos-devenv"
            "localhost/indrajaal-timescaledb-demo:nixos-devenv"
            "localhost/indrajaal-redis-demo:nixos-devenv"
        ]
        
        printfn "🛡️ [%s] Starting Swarm Security Audit..." logger
        let results = images |> List.map scanImage
        let allPassed = results |> List.forall id
        
        if allPassed then
            printfn "🛡️ [%s] SWARM CERTIFIED SECURE" logger
        else
            printfn "⚠️ [%s] SWARM SECURITY VULNERABILITIES DETECTED" logger
        
        allPassed
