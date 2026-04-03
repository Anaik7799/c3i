#r "lib/cepaf/src/Cepaf/bin/Debug/net10.0/Cepaf.dll"
open Cepaf.Zenoh.Core
open System.Text

let handle = 
    match ZenohFfiBridge.openSession (SessionConfig.defaultConfig()) with
    | Ok h -> h
    | Error _ -> nativeint 0

match ZenohFfiBridge.get handle "indrajaal/health/sentinel" 5000 with
| Ok samples ->
    for s in samples do
        printfn "Got: %s" (Encoding.UTF8.GetString(s.Payload))
| Error e -> printfn "Get failed: %A" e

ZenohFfiBridge.closeSession handle
