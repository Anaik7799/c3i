namespace Semantic.Bridge

open System
open System.IO
open Newtonsoft.Json
open Newtonsoft.Json.Linq

module Program =

    type JsonRpcRequest = {
        [<JsonProperty("jsonrpc")>] JsonRpc: string
        [<JsonProperty("method")>] Method: string
        [<JsonProperty("params")>] Params: JToken
        [<JsonProperty("id")>] Id: JToken
    }

    type JsonRpcResponse = {
        [<JsonProperty("jsonrpc")>] JsonRpc: string
        [<JsonProperty("result", NullValueHandling = NullValueHandling.Ignore)>] Result: obj
        [<JsonProperty("error", NullValueHandling = NullValueHandling.Ignore)>] Error: obj
        [<JsonProperty("id")>] Id: JToken
    }

    let createResponse id result =
        { JsonRpc = "2.0"; Result = result; Error = null; Id = id }

    let createError id code message =
        { JsonRpc = "2.0"; Result = null; Error = {| code = code; message = message |}; Id = id }

    let handleRequest (req: JsonRpcRequest) =
        try
            match req.Method with
            | "system.ping" ->
                createResponse req.Id {| status = "ok" |}
            | "system.stats" ->
                createResponse req.Id {| uptime = 0; requests = 0 |}
            | "triple.add" ->
                match TripleStore.add req.Params with
                | Ok res -> createResponse req.Id res
                | Error err -> createError req.Id -32000 err
            | "vector.similar" ->
                match VectorSearch.findSimilar req.Params with
                | Ok res -> createResponse req.Id res
                | Error err -> createError req.Id -32000 err
            | "zettel.process" ->
                match ZettelProcessor.processZettel req.Params with
                | Ok res -> createResponse req.Id res
                | Error err -> createError req.Id -32000 err
            | _ ->
                createError req.Id -32601 "Method not found"
        with ex ->
            createError req.Id -32603 ex.Message

    [<EntryPoint>]
    let main argv =
        // Set up input/output encoding
        Console.InputEncoding <- System.Text.Encoding.UTF8
        Console.OutputEncoding <- System.Text.Encoding.UTF8

        let mutable running = true
        while running do
            try
                let line = Console.ReadLine()
                if line = null then
                    running <- false
                else
                    let req = JsonConvert.DeserializeObject<JsonRpcRequest>(line)
                    if not (isNull (box req)) then
                        let res = handleRequest req
                        let json = JsonConvert.SerializeObject(res)
                        Console.WriteLine(json)
            with _ ->
                // Ignore errors loop
                ()
        0
