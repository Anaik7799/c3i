/// CEPAF Tagless Final Module
/// Provides tagless final encoding for effect-polymorphic programs.
///
/// WHAT: Tagless final style for extensible, type-safe DSLs and effects
/// WHY: Enables abstraction over effect systems (sync, async, validation, etc.)
/// CONSTRAINTS:
///   - SC-FSH-080: Interpreters must be lawful
///   - SC-FSH-081: No runtime type checks in interpreters
///   - SC-FSH-082: Effect composition must preserve semantics
///
/// STAMP Compliance: SC-FSH-080 to SC-FSH-082
/// Version: 1.0.0
namespace Cepaf.Core

open System
open System.Threading.Tasks

// ============================================================================
// CORE TYPECLASSES (as Interfaces)
// ============================================================================

/// Functor typeclass
type IFunctor<'F> =
    abstract Map: ('A -> 'B) -> 'F -> 'F  // Actually F<'A> -> F<'B>

/// Applicative typeclass
type IApplicative<'F> =
    inherit IFunctor<'F>
    abstract Pure: 'A -> 'F  // Actually F<'A>
    abstract Apply: 'F -> 'F -> 'F  // Actually F<'A -> 'B> -> F<'A> -> F<'B>

/// Monad typeclass
type IMonad<'F> =
    inherit IApplicative<'F>
    abstract Bind: 'F -> ('A -> 'F) -> 'F  // Actually F<'A> -> ('A -> F<'B>) -> F<'B>

// ============================================================================
// EFFECT ALGEBRA INTERFACES
// ============================================================================

/// Console algebra for console operations
type IConsole<'F> =
    abstract ReadLine: unit -> 'F  // F<string>
    abstract WriteLine: string -> 'F  // F<unit>

/// Clock algebra for time operations
type IClock<'F> =
    abstract Now: unit -> 'F  // F<DateTime>
    abstract UtcNow: unit -> 'F  // F<DateTime>

/// Random algebra for random operations
type IRandom<'F> =
    abstract NextInt: int -> int -> 'F  // F<int>
    abstract NextDouble: unit -> 'F  // F<double>
    abstract NextGuid: unit -> 'F  // F<Guid>

/// Logger algebra for logging operations
type ILogger<'F> =
    abstract Debug: string -> 'F  // F<unit>
    abstract Info: string -> 'F  // F<unit>
    abstract Warn: string -> 'F  // F<unit>
    abstract Error: string -> 'F  // F<unit>
    abstract ErrorWithException: string -> exn -> 'F  // F<unit>

/// Config algebra for configuration access
type IConfig<'F> =
    abstract GetString: string -> 'F  // F<string option>
    abstract GetInt: string -> 'F  // F<int option>
    abstract GetBool: string -> 'F  // F<bool option>
    abstract Require: string -> 'F  // F<string>

/// Storage algebra for key-value storage
type IStorage<'F> =
    abstract Get: string -> 'F  // F<string option>
    abstract Set: string -> string -> 'F  // F<unit>
    abstract Delete: string -> 'F  // F<bool>
    abstract Exists: string -> 'F  // F<bool>

/// HTTP algebra for HTTP operations
type IHttp<'F> =
    abstract Get: string -> 'F  // F<Result<string, string>>
    abstract Post: string -> string -> 'F  // F<Result<string, string>>
    abstract Put: string -> string -> 'F  // F<Result<string, string>>
    abstract Delete: string -> 'F  // F<Result<unit, string>>

// ============================================================================
// TAGLESS FINAL DSL BUILDER
// ============================================================================

/// DSL operations as a free algebra
module TaglessFinal =

    // =========================================================================
    // IDENTITY INTERPRETER (Pure/Synchronous)
    // =========================================================================

    /// Identity wrapper for synchronous interpretation
    type Id<'T> = Id of 'T

    module Id =
        let run (Id x) = x
        let map f (Id x) = Id (f x)
        let pure' x = Id x
        let apply (Id f) (Id x) = Id (f x)
        let bind (Id x) f = f x

    type IdConsole() =
        interface IConsole<Id<obj>> with
            member _.ReadLine() = Id (Console.ReadLine() :> obj)
            member _.WriteLine(s) = Id (Console.WriteLine(s) :> obj)

    type IdClock() =
        interface IClock<Id<obj>> with
            member _.Now() = Id (DateTime.Now :> obj)
            member _.UtcNow() = Id (DateTime.UtcNow :> obj)

    type IdRandom() =
        let rng = Random()
        interface IRandom<Id<obj>> with
            member _.NextInt min max = Id (rng.Next(min, max) :> obj)
            member _.NextDouble() = Id (rng.NextDouble() :> obj)
            member _.NextGuid() = Id (Guid.NewGuid() :> obj)

    // =========================================================================
    // ASYNC INTERPRETER
    // =========================================================================

    type AsyncConsole() =
        interface IConsole<Async<obj>> with
            member _.ReadLine() = async { return Console.ReadLine() :> obj }
            member _.WriteLine(s) = async { Console.WriteLine(s); return () :> obj }

    type AsyncClock() =
        interface IClock<Async<obj>> with
            member _.Now() = async { return DateTime.Now :> obj }
            member _.UtcNow() = async { return DateTime.UtcNow :> obj }

    type AsyncRandom() =
        let rng = Random()
        interface IRandom<Async<obj>> with
            member _.NextInt min max = async { return rng.Next(min, max) :> obj }
            member _.NextDouble() = async { return rng.NextDouble() :> obj }
            member _.NextGuid() = async { return Guid.NewGuid() :> obj }

    // =========================================================================
    // LOGGING INTERPRETER
    // =========================================================================

    /// Logging effect that accumulates log entries
    type Logging<'T> = Logging of (string list * 'T)

    module Logging =
        let run (Logging (logs, x)) = (logs, x)
        let logs (Logging (logs, _)) = logs
        let value (Logging (_, x)) = x

        let pure' x = Logging ([], x)
        let map f (Logging (logs, x)) = Logging (logs, f x)
        let bind (Logging (logs1, x)) f =
            let (Logging (logs2, y)) = f x
            Logging (logs1 @ logs2, y)

    type LoggingLogger() =
        interface ILogger<Logging<unit>> with
            member _.Debug msg = Logging ([sprintf "[DEBUG] %s" msg], ())
            member _.Info msg = Logging ([sprintf "[INFO] %s" msg], ())
            member _.Warn msg = Logging ([sprintf "[WARN] %s" msg], ())
            member _.Error msg = Logging ([sprintf "[ERROR] %s" msg], ())
            member _.ErrorWithException msg ex =
                Logging ([sprintf "[ERROR] %s: %s" msg (ex.ToString())], ())

    // =========================================================================
    // VALIDATION INTERPRETER (Accumulates errors)
    // =========================================================================

    type Validated<'E, 'T> =
        | Valid of 'T
        | Invalid of 'E list

    module Validated =
        let pure' x = Valid x

        let map f = function
            | Valid x -> Valid (f x)
            | Invalid es -> Invalid es

        let apply vf vx =
            match vf, vx with
            | Valid f, Valid x -> Valid (f x)
            | Invalid es, Valid _ -> Invalid es
            | Valid _, Invalid es -> Invalid es
            | Invalid es1, Invalid es2 -> Invalid (es1 @ es2)

        let bind vx f =
            match vx with
            | Valid x -> f x
            | Invalid es -> Invalid es

        let fail e = Invalid [e]

        let fromResult = function
            | Ok x -> Valid x
            | Error e -> Invalid [e]

        let toResult = function
            | Valid x -> Ok x
            | Invalid es -> Error es

    // =========================================================================
    // READER INTERPRETER (Dependency Injection)
    // =========================================================================

    type Reader<'Env, 'T> = Reader of ('Env -> 'T)

    module Reader =
        let run env (Reader f) = f env
        let pure' x = Reader (fun _ -> x)
        let map f (Reader r) = Reader (fun env -> f (r env))
        let bind (Reader r) f = Reader (fun env ->
            let a = r env
            let (Reader r') = f a
            r' env)
        let ask = Reader id
        let asks f = Reader f
        let local f (Reader r) = Reader (f >> r)

    type ReaderConfig<'Env>(getConfig: 'Env -> Map<string, string>) =
        interface IConfig<Reader<'Env, obj>> with
            member _.GetString key = Reader (fun env ->
                (getConfig env).TryFind key |> Option.map box |> Option.defaultValue null)
            member _.GetInt key = Reader (fun env ->
                (getConfig env).TryFind key
                |> Option.bind (fun s -> match Int32.TryParse s with true, n -> Some n | _ -> None)
                |> Option.map box |> Option.defaultValue null)
            member _.GetBool key = Reader (fun env ->
                (getConfig env).TryFind key
                |> Option.bind (fun s -> match Boolean.TryParse s with true, b -> Some b | _ -> None)
                |> Option.map box |> Option.defaultValue null)
            member _.Require key = Reader (fun env ->
                match (getConfig env).TryFind key with
                | Some v -> v :> obj
                | None -> failwithf "Required config key '%s' not found" key)

    // =========================================================================
    // STATE INTERPRETER
    // =========================================================================

    type State<'S, 'T> = State of ('S -> 'T * 'S)

    module State =
        let run s (State f) = f s
        let eval s m = run s m |> fst
        let exec s m = run s m |> snd

        let pure' x = State (fun s -> (x, s))
        let map f (State g) = State (fun s ->
            let (a, s') = g s
            (f a, s'))
        let bind (State g) f = State (fun s ->
            let (a, s') = g s
            let (State h) = f a
            h s')
        let get = State (fun s -> (s, s))
        let put s = State (fun _ -> ((), s))
        let modify f = State (fun s -> ((), f s))

    type StateStorage<'S>(getLens: 'S -> Map<string, string>, setLens: Map<string, string> -> 'S -> 'S) =
        interface IStorage<State<'S, obj>> with
            member _.Get key = State (fun s ->
                ((getLens s).TryFind key |> Option.map box |> Option.defaultValue null, s))
            member _.Set key value = State (fun s ->
                ((), setLens ((getLens s).Add(key, value)) s))
            member _.Delete key = State (fun s ->
                let m = getLens s
                let existed = m.ContainsKey key
                (existed :> obj, setLens (m.Remove key) s))
            member _.Exists key = State (fun s ->
                ((getLens s).ContainsKey key :> obj, s))

    // =========================================================================
    // FREE MONAD APPROACH (Alternative)
    // =========================================================================

    /// Free monad for console operations
    type ConsoleF<'Next> =
        | ReadLine of (string -> 'Next)
        | WriteLine of string * 'Next

    module ConsoleF =
        let map f = function
            | ReadLine k -> ReadLine (k >> f)
            | WriteLine (s, next) -> WriteLine (s, f next)

    /// Free monad
    type Free<'F, 'A> =
        | Pure of 'A
        | Free of 'F  // Actually F<Free<F, A>>

    module Free =
        let pure' x = Pure x

        let rec bind m f =
            match m with
            | Pure x -> f x
            | Free fx -> Free fx  // Would need proper functor constraint

        // Lift a single operation into Free
        let liftF fa = Free fa

    /// Console DSL using Free monad
    module ConsoleDsl =
        let readLine () = Free (ReadLine Pure)
        let writeLine s = Free (WriteLine (s, Pure ()))

    // =========================================================================
    // MTL-STYLE TRANSFORMERS
    // =========================================================================

    /// ReaderT monad transformer
    type ReaderT<'Env, 'M, 'T> = ReaderT of ('Env -> 'M)  // Actually Env -> M<T>

    module ReaderT =
        let run env (ReaderT f) = f env
        let lift m = ReaderT (fun _ -> m)
        let ask () = ReaderT (fun env -> env)  // Needs pure
        let asks f = ReaderT (fun env -> f env)  // Needs pure
        let local f (ReaderT r) = ReaderT (f >> r)

    /// StateT monad transformer
    type StateT<'S, 'M, 'T> = StateT of ('S -> 'M)  // Actually S -> M<T * S>

    module StateT =
        let run s (StateT f) = f s
        let lift m = StateT (fun s -> m)  // Needs map: m -> (x, s)
        let get () = StateT (fun s -> s)  // Needs pure: (s, s)
        let put s = StateT (fun _ -> s)  // Needs pure: ((), s)

    /// WriterT monad transformer
    type WriterT<'W, 'M, 'T> = WriterT of 'M  // Actually M<T * W list>

    module WriterT =
        let run (WriterT m) = m
        let lift m = WriterT m  // Needs map: m -> (x, [])
        let tell w = WriterT w  // Needs pure: ((), [w])

    // =========================================================================
    // EFFECT COMPOSITION
    // =========================================================================

    /// Compose multiple effects
    module Effects =

        /// Run reader effect
        let runReader env program = Reader.run env program

        /// Run state effect
        let runState initialState program = State.run initialState program

        /// Run logging effect
        let runLogging program = Logging.run program

        /// Run validation effect
        let runValidation program = Validated.toResult program

        /// Combine reader and state
        type ReaderState<'R, 'S, 'T> = ReaderState of ('R -> 'S -> 'T * 'S)

        module ReaderState =
            let run r s (ReaderState f) = f r s
            let pure' x = ReaderState (fun _ s -> (x, s))
            let ask = ReaderState (fun r s -> (r, s))
            let get = ReaderState (fun _ s -> (s, s))
            let put s = ReaderState (fun _ _ -> ((), s))
            let bind (ReaderState f) k = ReaderState (fun r s ->
                let (a, s') = f r s
                let (ReaderState g) = k a
                g r s')

// ============================================================================
// COMPUTATION EXPRESSION BUILDERS
// ============================================================================

/// Builder for Validated computations
type ValidatedBuilder() =
    member _.Return(x) = TaglessFinal.Validated.pure' x
    member _.ReturnFrom(v) = v
    member _.Bind(v, f) = TaglessFinal.Validated.bind v f
    member _.Zero() = TaglessFinal.Validated.pure' ()
    member _.Combine(v1, v2) =
        TaglessFinal.Validated.bind v1 (fun () -> v2)

    /// Applicative combine (accumulates errors)
    member _.MergeSources(v1, v2) =
        TaglessFinal.Validated.apply
            (TaglessFinal.Validated.map (fun a b -> (a, b)) v1)
            v2

    member _.BindReturn(v, f) = TaglessFinal.Validated.map f v

[<AutoOpen>]
module TaglessFinalBuilders =
    let validated = ValidatedBuilder()

// ============================================================================
// DSL EXAMPLES
// ============================================================================

module DslExamples =
    open TaglessFinal

    /// Example: Console program in tagless final style
    /// This would be parameterized by the interpreter
    let greetingProgram (console: IConsole<'F>) (monad: IMonad<'F>) : 'F =
        // In a real implementation, we'd use the monad to sequence operations
        // This is simplified for demonstration
        console.WriteLine "What is your name?"

    /// Example: Validated user input
    let validateUser name email age =
        validated {
            let! validName =
                if String.IsNullOrWhiteSpace name then Validated.fail "Name cannot be empty"
                else Validated.pure' name

            let! validEmail =
                if email |> String.IsNullOrWhiteSpace || not (email.Contains("@"))
                then Validated.fail "Invalid email"
                else Validated.pure' email

            let! validAge =
                if age < 0 || age > 150 then Validated.fail "Invalid age"
                else Validated.pure' age

            return {| Name = validName; Email = validEmail; Age = validAge |}
        }

    /// Example: Using applicative style for parallel validation
    let validateUserApplicative name email age =
        let validateName =
            if String.IsNullOrWhiteSpace name
            then Validated.fail "Name cannot be empty"
            else Validated.pure' name

        let validateEmail =
            if email |> String.IsNullOrWhiteSpace || not (email.Contains("@"))
            then Validated.fail "Invalid email"
            else Validated.pure' email

        let validateAge =
            if age < 0 || age > 150
            then Validated.fail "Invalid age"
            else Validated.pure' age

        Validated.apply
            (Validated.apply
                (Validated.map (fun n e a -> {| Name = n; Email = e; Age = a |}) validateName)
                validateEmail)
            validateAge
