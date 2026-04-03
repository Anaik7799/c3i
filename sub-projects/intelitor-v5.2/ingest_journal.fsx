// [AGENT_RECREATION_GENOME]
// Purpose: Hardened Native F# Bulk Journal Ingester v4.0 (sa-plan Integration).
// Function: Imports journal files using the F# planning system CLI.
// Protocol: SC-REGEN-004, SC-DB-CONCUR-001
// [/AGENT_RECREATION_GENOME]

open System
open System.IO
open System.Diagnostics

let rootDir = "/home/an/dev/ver/intelitor-v5.2"

let execSaPlan (file: string) =
    let fileName = Path.GetFileName(file)
    let psi = ProcessStartInfo("sa-plan")
    psi.ArgumentList.Add("add")
    psi.ArgumentList.Add(sprintf "JOURNAL: %s" fileName)
    
    psi.RedirectStandardOutput <- true
    psi.RedirectStandardError <- true
    psi.UseShellExecute <- false
    psi.CreateNoWindow <- true
    
    use p = Process.Start(psi)
    p.WaitForExit()
    p.ExitCode

let ingestAll () =
    printfn ">>> INDRAJAAL JOURNAL INGESTION v4.0 (SA-PLAN INTEGRATED) <<<"
    let journalPath = Path.Combine(rootDir, "docs/journal")
    let journalFiles = Directory.GetFiles(journalPath, "*.md", SearchOption.AllDirectories)
    printfn "[F#] Identified %d artifacts." journalFiles.Length
    
    let mutable successCount = 0
    let mutable failCount = 0
    let syncRoot = obj()
    
    // Process in parallel. sa-plan will use DuckDBHub to serialize writes.
    Array.Parallel.iter (fun file ->
        let exitCode = execSaPlan file
        
        if exitCode = 0 then
            lock syncRoot (fun () -> 
                successCount <- successCount + 1
                if successCount % 10 = 0 then printfn "[F#] Progress: %d ingested..." successCount
            )
        else
            lock syncRoot (fun () -> 
                failCount <- failCount + 1
            )
    ) journalFiles

    printfn ">>> INGESTION SUMMARY <<<"
    printfn "[F#] Success: %d" successCount
    printfn "[F#] Failed:  %d" failCount

ingestAll ()
