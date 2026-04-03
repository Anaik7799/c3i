// [AGENT_RECREATION_GENOME]
// Purpose: Native F# Git Synchronization Script.
// Uses System.Diagnostics.Process to achieve bit-perfect state persistence.
// Mandate: Only use existing F# logic for git actions.
// Execution: dotnet fsi git_sync.fsx "[COMMIT_MESSAGE]"
// [/AGENT_RECREATION_GENOME]

open System
open System.Diagnostics

let exec (cmd: string) (args: string) =
    printfn "[F#] Executing: %s %s" cmd args
    let psi = ProcessStartInfo(cmd, args)
    psi.RedirectStandardOutput <- true
    psi.RedirectStandardError <- true
    psi.UseShellExecute <- false
    psi.CreateNoWindow <- true
    
    use p = Process.Start(psi)
    let stdout = p.StandardOutput.ReadToEnd()
    let stderr = p.StandardError.ReadToEnd()
    p.WaitForExit()
    
    if p.ExitCode <> 0 then
        printfn "[F#] Error (%d): %s" p.ExitCode stderr
    else
        printfn "[F#] Success: %s" stdout
    p.ExitCode

let sync (msg: string) =
    printfn "[F#] Starting system-wide Git synchronization..."
    let exit1 = exec "git" "add ."
    let exit2 = exec "git" (sprintf "commit -m \"%s\"" msg)
    let exit3 = exec "git" "push origin main"
    
    if exit1 = 0 && exit3 = 0 then
        printfn "[F#] 🏁 Synchronization complete."
    else
        printfn "[F#] ⚠️ Synchronization encountered issues."

let args = fsi.CommandLineArgs |> Array.skip 1
let message = if args.Length > 0 then args.[0] else "HRP Native F# Sync"
sync message
