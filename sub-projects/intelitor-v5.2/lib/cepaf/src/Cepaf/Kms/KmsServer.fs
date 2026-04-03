namespace Cepaf.Kms

open System
open System.IO
open System.Text.Json
open System.Text.Json.Serialization

// --- SERVER PROTOCOL ---

type KmsRequest =
    | GetHolon of id: string
    | GetHolonByFqun of fqun: string
    | UpsertHolon of holon: HolonDto
    | SearchVectors of query: float[] * limit: int
    | UpsertVector of id: string * vector: float[] * model: string
    // Todo operations
    | GetActiveTasks
    | CreateSystemTask of title: string * priority: string

type KmsResponse<'T> =
    | Success of data: 'T
    | Error of message: string

module KmsServer =

    // Simple JSON-RPC loop
    let run () =
        let stdin = Console.In
        let stdout = Console.Out

        // Ensure DBs are initialized
        HolonRepository.init()
        VectorRepository.init()
        // TodoRepository is likely initialized in its module or needs an init

        let rec loop () =
            let line = stdin.ReadLine()
            if isNull line then ()
            else
                try
                    // Simple dispatch based on "command" field in JSON
                    // Or we deserialize to a specific DTO structure.
                    // For robustness, let's assume the input is:
                    // { "command": "get_holon", "args": { ... } }
                    
                    let doc = JsonDocument.Parse(line)
                    let root = doc.RootElement
                    let cmd = root.GetProperty("command").GetString()
                    
                    let response = 
                        match cmd with
                        | "get_holon" ->
                            let id = root.GetProperty("args").GetProperty("id").GetString()
                            match HolonRepository.getById id with
                            | Some h -> JsonSerializer.Serialize({| status = "ok"; data = h |})
                            | None -> JsonSerializer.Serialize({| status = "error"; reason = "not_found" |})
                            
                        | "upsert_holon" ->
                            let args = root.GetProperty("args")
                            let holon : Holon = JsonSerializer.Deserialize<Holon>(args.GetRawText())
                            HolonRepository.upsert holon
                            JsonSerializer.Serialize({| status = "ok" |})

                        | "search_vectors" ->
                            let args = root.GetProperty("args")
                            let query = JsonSerializer.Deserialize<float[]>(args.GetProperty("query").GetRawText())
                            let limit = args.GetProperty("limit").GetInt32()
                            let results = VectorRepository.search query limit
                            JsonSerializer.Serialize({| status = "ok"; data = results |})

                        | "ping" ->
                            JsonSerializer.Serialize({| status = "ok"; message = "pong" |})

                        | _ ->
                            JsonSerializer.Serialize({| status = "error"; reason = "unknown_command" |})

                    stdout.WriteLine(response)
                    stdout.Flush()
                with ex ->
                    let err = {| status = "error"; reason = ex.Message |}
                    stdout.WriteLine(JsonSerializer.Serialize(err))
                    stdout.Flush()
                
                loop()

        loop()
