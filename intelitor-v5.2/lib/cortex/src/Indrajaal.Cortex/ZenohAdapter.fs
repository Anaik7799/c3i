namespace Indrajaal.Cortex

module ZenohAdapter =
    type Session() =
        member this.Publish(key: string, value: string) =
            printfn "[ZENOH] PUB %s: %s" key value

    let connect () =
        printfn "[ZENOH] CONNECTING..."
        Session()
