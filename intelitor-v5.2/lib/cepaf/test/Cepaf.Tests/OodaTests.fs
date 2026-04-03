namespace Cepaf.Tests

open Expecto
open Cepaf

module OodaTests =
    [<Tests>]
    let tests =
        testList "OodaOrient" [
            testCase "Identifies RUNN typo" <| fun _ ->
                let stderr = "error: unknown instruction: RUNN"
                let action = Operations.classifyError stderr
                match action with
                | Some (Operations.ApplyPatch ("RUNN", "RUN")) -> ()
                | _ -> failwith "Failed to identify patch action"

            testCase "Identifies Port Conflict" <| fun _ ->
                let stderr = "address already in use: 5433"
                let action = Operations.classifyError stderr
                match action with
                | Some (Operations.AbortPipeline _) -> ()
                | _ -> failwith "Failed to identify abort action"

            testCase "Identifies DB Initializing" <| fun _ ->
                let stderr = "database system is starting up"
                let action = Operations.classifyError stderr
                match action with
                | Some (Operations.WaitAndRetry _) -> ()
                | _ -> failwith "Failed to identify retry action"

            testCase "Returns None for unknown error" <| fun _ ->
                let stderr = "segmentation fault"
                let action = Operations.classifyError stderr
                Expect.isNone action "Should not classify unknown error"
        ]
