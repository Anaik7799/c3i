namespace Cepaf.Tests

open Expecto
open Cepaf.Rop

module RopTests =

    let successTask = async { return Ok 42 }
    let errorTask = async { return Error (Cepaf.InfrastructureError("test", "fail")) }

    [<Tests>]
    let tests =
        testList "ROP.AsyncResult" [
            testCaseAsync "bind should handle success" <| async {
                let! res = bind (fun v -> async { return Ok (v + 1) }) successTask
                Expect.equal res (Ok 43) "Success should be transformed"
            }

            testCaseAsync "bind should handle failure" <| async {
                let! res = bind (fun v -> async { return Ok (v + 1) }) errorTask
                match res with
                | Error (Cepaf.InfrastructureError("test", _)) -> ()
                | _ -> failwith "Should have returned the error"
            }

            testCaseAsync "asyncResult builder success" <| async {
                let! res = asyncResult {
                    let! v1 = successTask
                    let! v2 = async { return Ok 8 }
                    return v1 + v2
                }
                Expect.equal res (Ok 50) "Builder should compose successes"
            }

            testCaseAsync "asyncResult builder failure" <| async {
                let! res = asyncResult {
                    let! v1 = successTask
                    let! _ = errorTask
                    return v1
                }
                match res with
                | Error (Cepaf.InfrastructureError("test", _)) -> ()
                | _ -> failwith "Builder should short-circuit on error"
            }

            testCaseAsync "sequence should aggregate results" <| async {
                let tasks = [ successTask; async { return Ok 10 } ]
                let! res = sequence tasks
                Expect.equal res (Ok [42; 10]) "Sequence should return all successes"
            }

            testCaseAsync "sequence should return first error" <| async {
                let tasks = [ successTask; errorTask; async { return Ok 10 } ]
                let! res = sequence tasks
                match res with
                | Error (Cepaf.InfrastructureError("test", _)) -> ()
                | _ -> failwith "Sequence should fail if any task fails"
            }
        ]
