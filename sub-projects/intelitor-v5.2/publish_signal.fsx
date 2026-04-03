#r "lib/cepaf/src/Cepaf/bin/Debug/net10.0/Cepaf.dll"
open Cepaf.Zenoh.Core
open System.Text

let key = fsi.CommandLineArgs.[1]
let payload = fsi.CommandLineArgs.[2]

match ZenohFfiBridge.openSession (SessionConfig.defaultConfig()) with
| Ok h ->
    printfn "Publishing to %s: %s" key payload
    ZenohFfiBridge.publish h key (Encoding.UTF8.GetBytes(payload)) |> ignore
    System.Threading.Thread.Sleep(500)
    ZenohFfiBridge.closeSession h
| Error e -> printfn "Failed: %A" e
