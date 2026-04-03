#r "lib/cepaf/src/Cepaf/bin/Debug/net10.0/Cepaf.dll"
open Cepaf.Zenoh.Core
open System.Text
open System.Threading

let keyControl = "indrajaal/control/mesh"
let keyStatus = "indrajaal/control/mesh/status"

match ZenohFfiBridge.openSession (SessionConfig.defaultConfig()) with
| Ok h ->
    printfn "--- CONTROL PLANE VERIFICATION ---"
    
    // Subscribe to status
    match ZenohFfiBridge.subscribe h keyStatus with
    | Ok sub ->
        let sendAndVerify cmd =
            printfn "\n[SENT] Command: %s" cmd
            ZenohFfiBridge.publish h keyControl (Encoding.UTF8.GetBytes(cmd)) |> ignore
            
            // Poll for ACK
            Thread.Sleep(2000)
            match ZenohFfiBridge.poll sub 10 with
            | Ok samples ->
                for s in samples do
                    printfn "[RECV] %s: %s" s.KeyExpr (Encoding.UTF8.GetString(s.Payload))
            | _ -> printfn "[WARN] No status received"

        sendAndVerify "status"
        sendAndVerify "mv_list"
        sendAndVerify "checkpoint_quick"
        
        Thread.Sleep(5000)
        ZenohFfiBridge.unsubscribe sub
    | _ -> printfn "Failed to subscribe"
    
    ZenohFfiBridge.closeSession h
| Error e -> printfn "Failed: %A" e
