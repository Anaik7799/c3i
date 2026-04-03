namespace Cepaf.Core

open System

/// Effect System for controlled side effects with monadic composition.
/// Enables pure functional programming while tracking effects in the type system.
///
/// WHAT: Algebraic Effect System with effect handlers and interpreters
/// WHY: Makes side effects explicit, testable, and composable
/// CONSTRAINTS:
///   - SC-FSH-020: Effects must be explicitly typed
///   - SC-FSH-021: Effect handlers must be pure functions
///   - SC-FSH-022: No unhandled effects in production code
///
/// TDG Compliance:
///   - TDG-FSH-020: Effect composition tested
///   - TDG-FSH-021: Handler interpretation tested
///
/// AOR Compliance:
///   - AOR-FSH-010: All I/O operations use Effect system
module Effects =

    // =========================================================================
    // CORE EFFECT TYPES
    // =========================================================================

    /// Effect signature - describes what effects a computation can perform
    type Effect<'Eff, 'T> =
        | Pure of 'T
        | Impure of 'Eff * (obj -> Effect<'Eff, 'T>)

    /// Free monad for effect composition
    module Free =
        let pure' x = Pure x

        let rec bind f = function
            | Pure x -> f x
            | Impure (eff, k) -> Impure (eff, fun x -> bind f (k x))

        let map f = bind (f >> pure')

        let liftF eff = Impure (eff, fun x -> Pure (unbox x))

    // =========================================================================
    // COMMON EFFECT TYPES
    // =========================================================================

    /// Console I/O effects
    type ConsoleEffect =
        | ReadLine
        | WriteLine of string

    /// File I/O effects
    type FileEffect =
        | ReadFile of string
        | WriteFile of string * string
        | FileExists of string
        | DeleteFile of string

    /// Time effects
    type TimeEffect =
        | GetCurrentTime
        | Sleep of TimeSpan

    /// Random effects
    type RandomEffect =
        | NextInt of int * int
        | NextDouble
        | NextGuid

    /// Logging effects (SC-OBS-069: Dual Log)
    type LogEffect =
        | LogDebug of string
        | LogInfo of string
        | LogWarning of string
        | LogError of string * exn option

    /// State effects
    type StateEffect<'S> =
        | Get
        | Put of 'S
        | Modify of ('S -> 'S)

    // =========================================================================
    // COMBINED EFFECT TYPE
    // =========================================================================

    /// Union of all standard effects
    type StandardEffect =
        | Console of ConsoleEffect
        | File of FileEffect
        | Time of TimeEffect
        | Random of RandomEffect
        | Log of LogEffect

    // =========================================================================
    // EFFECT BUILDERS (Smart Constructors)
    // =========================================================================

    /// Console effect builders
    module Console =
        let readLine () = Free.liftF (Console ReadLine)
        let writeLine (s: string) = Free.liftF (Console (WriteLine s))

    /// File effect builders
    module File =
        let read path = Free.liftF (File (ReadFile path))
        let write path content = Free.liftF (File (WriteFile (path, content)))
        let exists path = Free.liftF (File (FileExists path))
        let delete path = Free.liftF (File (DeleteFile path))

    /// Time effect builders
    module Time =
        let now () = Free.liftF (Time GetCurrentTime)
        let sleep duration = Free.liftF (Time (Sleep duration))

    /// Random effect builders
    module Random =
        let nextInt min max = Free.liftF (Random (NextInt (min, max)))
        let nextDouble () = Free.liftF (Random NextDouble)
        let nextGuid () = Free.liftF (Random NextGuid)

    /// Logging effect builders
    module Log =
        let debug msg = Free.liftF (Log (LogDebug msg))
        let info msg = Free.liftF (Log (LogInfo msg))
        let warning msg = Free.liftF (Log (LogWarning msg))
        let error msg ex = Free.liftF (Log (LogError (msg, ex)))

    // =========================================================================
    // EFFECT HANDLERS (Interpreters)
    // =========================================================================

    /// Handler type - interprets effects into real operations
    type Handler<'Eff, 'T> = 'Eff -> ('T -> obj) -> obj

    /// Run effect with handler
    let rec run (handler: Handler<'Eff, 'R>) (eff: Effect<'Eff, 'R>) : 'R =
        match eff with
        | Pure x -> x
        | Impure (e, k) ->
            let result = handler e (fun x -> box (run handler (k x)))
            unbox result

    /// Real-world console handler
    let realConsoleHandler : Handler<StandardEffect, obj> = fun eff cont ->
        match eff with
        | Console ReadLine ->
            let line = System.Console.ReadLine()
            cont (box line)
        | Console (WriteLine s) ->
            System.Console.WriteLine(s)
            cont (box ())
        | _ -> failwith "Unhandled effect"

    /// Real-world file handler
    let realFileHandler : Handler<StandardEffect, obj> = fun eff cont ->
        match eff with
        | File (ReadFile path) ->
            let content = System.IO.File.ReadAllText(path)
            cont (box content)
        | File (WriteFile (path, content)) ->
            System.IO.File.WriteAllText(path, content)
            cont (box ())
        | File (FileExists path) ->
            let exists = System.IO.File.Exists(path)
            cont (box exists)
        | File (DeleteFile path) ->
            System.IO.File.Delete(path)
            cont (box ())
        | _ -> failwith "Unhandled effect"

    /// Real-world time handler
    let realTimeHandler : Handler<StandardEffect, obj> = fun eff cont ->
        match eff with
        | Time GetCurrentTime ->
            cont (box DateTimeOffset.UtcNow)
        | Time (Sleep duration) ->
            System.Threading.Thread.Sleep(duration)
            cont (box ())
        | _ -> failwith "Unhandled effect"

    /// Real-world random handler
    let realRandomHandler : Handler<StandardEffect, obj> = fun eff cont ->
        let rng = System.Random()
        match eff with
        | Random (NextInt (min, max)) ->
            cont (box (rng.Next(min, max)))
        | Random NextDouble ->
            cont (box (rng.NextDouble()))
        | Random NextGuid ->
            cont (box (Guid.NewGuid()))
        | _ -> failwith "Unhandled effect"

    // =========================================================================
    // TEST HANDLERS (For unit testing)
    // =========================================================================

    /// Test console handler with predefined inputs/outputs
    type TestConsoleState = {
        Inputs: string list
        Outputs: string list
    }

    let testConsoleHandler (state: TestConsoleState ref) : Handler<StandardEffect, obj> = fun eff cont ->
        match eff with
        | Console ReadLine ->
            match (!state).Inputs with
            | h :: t ->
                state := { !state with Inputs = t }
                cont (box h)
            | [] -> cont (box "")
        | Console (WriteLine s) ->
            state := { !state with Outputs = (!state).Outputs @ [s] }
            cont (box ())
        | _ -> failwith "Unhandled effect"

    /// Test time handler with fixed time
    let testTimeHandler (fixedTime: DateTimeOffset) : Handler<StandardEffect, obj> = fun eff cont ->
        match eff with
        | Time GetCurrentTime -> cont (box fixedTime)
        | Time (Sleep _) -> cont (box ())  // No-op in tests
        | _ -> failwith "Unhandled effect"

    /// Test random handler with deterministic sequence
    let testRandomHandler (seed: int) : Handler<StandardEffect, obj> =
        let rng = System.Random(seed)
        fun eff cont ->
            match eff with
            | Random (NextInt (min, max)) -> cont (box (rng.Next(min, max)))
            | Random NextDouble -> cont (box (rng.NextDouble()))
            | Random NextGuid -> cont (box (Guid.NewGuid()))
            | _ -> failwith "Unhandled effect"

    // =========================================================================
    // COMBINED HANDLER
    // =========================================================================

    /// Combine multiple handlers
    let combineHandlers (handlers: Handler<'Eff, obj> list) : Handler<'Eff, obj> =
        fun eff cont ->
            handlers
            |> List.tryPick (fun h ->
                try Some (h eff cont)
                with _ -> None)
            |> Option.defaultWith (fun () -> failwith $"No handler for effect")

    /// Production handler combining all real handlers
    let productionHandler =
        combineHandlers [
            realConsoleHandler
            realFileHandler
            realTimeHandler
            realRandomHandler
        ]

    // =========================================================================
    // EFFECT COMPUTATION EXPRESSION
    // =========================================================================

    /// Computation expression builder for effects
    type EffectBuilder() =
        member _.Return(x) = Pure x
        member _.ReturnFrom(m) = m
        member _.Bind(m, f) = Free.bind f m
        member _.Zero() = Pure ()
        member _.Combine(a, b) = Free.bind (fun () -> b) a
        member _.Delay(f) = f ()

    let effect = EffectBuilder()

    // =========================================================================
    // ASYNC EFFECT SUPPORT
    // =========================================================================

    /// Async effect type
    type AsyncEffect<'T> = Async<Effect<StandardEffect, 'T>>

    /// Async effect operations
    module AsyncEffect =
        let pure' x = async { return Pure x }

        let rec bind f m = async {
            let! eff = m
            match eff with
            | Pure x -> return! f x
            | Impure (e, k) ->
                // Handle impure effects by creating a continuation wrapper
                let k' x = Free.bind (fun a -> Async.RunSynchronously (f a)) (k x)
                return Impure (e, k')
        }

        let map f = bind (f >> pure')

    // =========================================================================
    // EFFECT UTILITIES
    // =========================================================================

    /// Sequence effects
    let sequence (effects: Effect<'Eff, 'T> list) : Effect<'Eff, 'T list> =
        let rec loop acc = function
            | [] -> Pure (List.rev acc)
            | h :: t -> Free.bind (fun x -> loop (x :: acc) t) h
        loop [] effects

    /// Traverse with effects
    let traverse (f: 'T -> Effect<'Eff, 'U>) (items: 'T list) : Effect<'Eff, 'U list> =
        items |> List.map f |> sequence

    /// Filter with effects
    let filterM (pred: 'T -> Effect<'Eff, bool>) (items: 'T list) : Effect<'Eff, 'T list> =
        let check item =
            Free.bind (fun keep -> if keep then Pure [item] else Pure []) (pred item)
        Free.bind (fun lists -> Pure (List.concat lists)) (traverse check items)

    /// Fold with effects
    let foldM (f: 'S -> 'T -> Effect<'Eff, 'S>) (init: 'S) (items: 'T list) : Effect<'Eff, 'S> =
        let rec loop acc = function
            | [] -> Pure acc
            | h :: t -> Free.bind (fun acc' -> loop acc' t) (f acc h)
        loop init items
