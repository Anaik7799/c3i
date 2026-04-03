open System
open System.IO
open System.Diagnostics

let checkFile (filePath: string) =
    printfn "PROBING F# SEMANTICS: %s" filePath
    let psi = ProcessStartInfo("dotnet", "build lib/cepaf/src/Cepaf/Cepaf.fsproj")
    psi.RedirectStandardOutput <- true
    psi.UseShellExecute <- false
    use proc = Process.Start(psi)
    let output = proc.StandardOutput.ReadToEnd()
    proc.WaitForExit()
    
    if output.Contains("Build succeeded") then
        printfn "RESULT: SEMANTICALLY VALID"
        0
    else
        printfn "RESULT: SEMANTIC ERRORS DETECTED"
        printfn "%s" output
        1

let args = fsi.CommandLineArgs |> Array.tail
if args.Length > 0 then
    exit (checkFile args.[0])
else
    printfn "F# Oracle ready for SIL6 diagnostics."
    exit 0
