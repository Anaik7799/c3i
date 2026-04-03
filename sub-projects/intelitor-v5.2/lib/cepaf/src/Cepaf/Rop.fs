namespace Cepaf

open System

module Rop =
    type AsyncResult<'T, 'E> = Async<Result<'T, 'E>>

    let map f x = async {
        let! res = x
        return Result.map f res
    }

    let bind f x = async {
        let! res = x
        match res with
        | Ok v -> return! f v
        | Error e -> return Error e
    }

    let tee f x = async {
        let! res = x
        match res with
        | Ok v -> f v
        | Error _ -> ()
        return res
    }

    let teeError f x = async {
        let! res = x
        match res with
        | Ok _ -> ()
        | Error e -> f e
        return res
    }

    type AsyncResultBuilder() =
        member _.Bind(x, f) = bind f x
        member _.Return(v) = async { return Ok v }
        member _.ReturnFrom(x) = x
        member _.Delay(f) = async { return! f() }
        member _.Zero() = async { return Ok () }
        
        member _.Combine(a, b) = 
            bind (fun () -> b) a
            
        member _.For(xs: 'a seq, f: 'a -> AsyncResult<unit, 'b>) = 
            let rec loop (enumerator: Collections.Generic.IEnumerator<'a>) =
                if enumerator.MoveNext() then
                    bind (fun () -> loop enumerator) (f enumerator.Current)
                else
                    async { return Ok () }
            loop (xs.GetEnumerator())

        member _.TryWith(m, h) = async {
            try return! m
            with ex -> return! h ex
        }
        
        member _.TryFinally(m, compensation) = async {
            try return! m
            finally compensation()
        }

    let asyncResult = AsyncResultBuilder()

    let fromAsync x = async {
        let! v = x
        return Ok v
    }

    let fromResult x = async { return x }

    let sequence x = async {
        let! results = x |> Async.Parallel
        let ok = results |> Array.choose (function Ok v -> Some v | _ -> None)
        let errors = results |> Array.choose (function Error e -> Some e | _ -> None)
        if errors.Length > 0 then return Error (errors |> Array.head)
        else return Ok (ok |> Array.toList)
    }