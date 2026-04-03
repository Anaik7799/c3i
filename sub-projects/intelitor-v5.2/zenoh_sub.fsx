#r "lib/cepaf/src/Cepaf/bin/Debug/net10.0/Cepaf.dll"
open Cepaf.Zenoh.Core
open System.Text
open System.Threading

let topic = fsi.CommandLineArgs.[1]

match ZenohFfiBridge.openSession (SessionConfig.defaultConfig()) with
| Ok h ->
    match ZenohFfiBridge.subscribe h topic with
    | Ok sub ->
        printfn "Subscribed to %s. Waiting 30s..." topic
        let mutable count = 0
        while count < 30 do
            match ZenohFfiBridge.poll sub 10 with
            | Ok samples ->
                for s in samples do
                    printfn "[ZENOH] %s: %s" s.KeyExpr (Encoding.UTF8.GetString(s.Payload))
            | _ -> ()
            Thread.Sleep(1000)
            count <- count + 1
        ZenohFfiBridge.unsubscribe sub
    | Error e -> printfn "Subscribe failed: %A" e
    ZenohFfiBridge.closeSession h
| Error e -> printfn "Session failed: %A" e
