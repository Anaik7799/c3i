#r "lib/cepaf/src/Cepaf/bin/Debug/net10.0/Cepaf.dll"
#load "lib/cepaf/src/Cepaf.Cockpit/PanopticonTui.fs"

open Cepaf.Cockpit

printfn ">>> TESTING CEPAF TUI SINGULARITY VIEW <<<"

try
    PanopticonTui.showSingularity()
    printfn ">>> TUI RENDER SUCCESSFUL"
with ex ->
    printfn ">>> TUI RENDER FAILED: %s" ex.Message
    System.Environment.Exit(1)
