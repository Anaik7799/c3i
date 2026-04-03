#r "lib/cepaf/src/Cepaf/bin/Debug/net10.0/Cepaf.dll"
open Cepaf.Zenoh.Core
open System.Text
open System.Threading

let keyControl = "indrajaal/control/mesh"
let keyStatus = "indrajaal/control/mesh/status"

match ZenohFfiBridge.openSession (SessionConfig.defaultConfig()) with
| Ok h ->
    match ZenohFfiBridge.subscribe h keyStatus with
    | Ok sub ->
        printfn "[PROBE] Dispatching MV_LIST signal..."
        ZenohFfiBridge.publish h keyControl (Encoding.UTF8.GetBytes("mv_list")) |> ignore
        
        let mutable found = false
        let mutable count = 0
        while not found && count < 10 do
            match ZenohFfiBridge.poll sub 10 with
            | Ok samples ->
                for s in samples do
                    let payload = Encoding.UTF8.GetString(s.Payload)
                    printfn "[RECV] %s" payload
                    if payload.Contains("COMPLETE: MULTIVERSE LIST") then found <- true
            | _ -> ()
            Thread.Sleep(1000)
            count <- count + 1
        
        if found then printfn "\n✅ MULTIVERSE CONTROL PLANE: VERIFIED"
        else printfn "\n✗ MULTIVERSE CONTROL PLANE: TIMEOUT"
        
        ZenohFfiBridge.unsubscribe sub
    | _ -> ()
    ZenohFfiBridge.closeSession h
| _ -> ()
