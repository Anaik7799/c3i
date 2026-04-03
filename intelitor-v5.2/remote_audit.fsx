// [AGENT_RECREATION_GENOME]
// Purpose: Native F# Remote Git Auditor.
// Verifies that the local head is reflected on the GitHub server.
// Protocol: SC-REGEN-002 (Information Parity)
// Execution: dotnet fsi remote_audit.fsx
// [/AGENT_RECREATION_GENOME]

open System
open System.Diagnostics

let exec (cmd: string) (args: string) =
    let psi = ProcessStartInfo(cmd, args)
    psi.RedirectStandardOutput <- true
    psi.RedirectStandardError <- true
    psi.UseShellExecute <- false
    psi.CreateNoWindow <- true
    use p = Process.Start(psi)
    let stdout = p.StandardOutput.ReadToEnd().Trim()
    p.WaitForExit()
    (p.ExitCode, stdout)

let verifyRemote () =
    printfn ">>> INDRAJAAL REMOTE SYNC AUDIT (F# NATIVE) <<<"
    
    // 1. Get local head
    let (_, localHead) = exec "git" "rev-parse HEAD"
    printfn "[F#] Local Head:  %s" localHead
    
    // 2. Query remote head (ls-remote)
    printfn "[F#] Querying GitHub origin/main..."
    let (exitCode, remoteInfo) = exec "git" "ls-remote origin refs/heads/main"
    
    if exitCode = 0 && remoteInfo.Contains(localHead) then
        printfn "[F#] 🟢 REMOTE VERIFIED: GitHub main matches local head (%s)." (localHead.Substring(0, 9))
        printfn "[F#] Remote State: %s" remoteInfo
    else
        printfn "[F#] 🔴 REMOTE DRIFT: GitHub head does not match local (%s)." (localHead.Substring(0, 9))
        printfn "[F#] Remote Info: %s" remoteInfo

verifyRemote ()
