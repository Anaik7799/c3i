/// CEPAF Advanced Validation Module
/// Provides comprehensive validation with error accumulation and composition.
///
/// WHAT: Type-safe validation with applicative error accumulation
/// WHY: Enables collecting all validation errors instead of failing fast
/// CONSTRAINTS:
///   - SC-FSH-110: Validators must be pure functions
///   - SC-FSH-111: Errors must be composable
///   - SC-FSH-112: Validation rules must be declarative
///
/// STAMP Compliance: SC-FSH-110 to SC-FSH-112
/// Version: 1.0.0
namespace Cepaf.Core

open System
open System.Text.RegularExpressions

// ============================================================================
// VALIDATION ERROR TYPES
// ============================================================================

/// Path through a data structure (for nested validation)
type ValidationPath =
    | Root
    | Field of string * ValidationPath
    | Index of int * ValidationPath

module ValidationPath =
    let rec toString = function
        | Root -> ""
        | Field (name, Root) -> name
        | Field (name, parent) -> sprintf "%s.%s" (toString parent) name
        | Index (i, Root) -> sprintf "[%d]" i
        | Index (i, parent) -> sprintf "%s[%d]" (toString parent) i

    let field name parent = Field (name, parent)
    let index i parent = Index (i, parent)

/// Validation error with context
type ValidationError = {
    Path: ValidationPath
    Message: string
    Code: string option
    Details: Map<string, obj>
}

module ValidationError =
    let create path message =
        { Path = path; Message = message; Code = None; Details = Map.empty }

    let withCode code error =
        { error with Code = Some code }

    let withDetail key value error =
        { error with Details = error.Details.Add(key, box value) }

    let format error =
        let path = ValidationPath.toString error.Path
        let location = if path = "" then "" else sprintf " at '%s'" path
        sprintf "%s%s" error.Message location

// ============================================================================
// VALIDATED TYPE
// ============================================================================

/// Validation result - accumulates errors applicatively
type Validated<'E, 'T> =
    | Valid of 'T
    | Invalid of 'E list

module Validated =
    /// Lift a value into Valid
    let pure' x = Valid x

    /// Lift an error into Invalid
    let fail e = Invalid [e]

    /// Fail with multiple errors
    let failMany es = Invalid es

    /// Map over a validated value
    let map f = function
        | Valid x -> Valid (f x)
        | Invalid es -> Invalid es

    /// Apply (applicative) - accumulates errors
    let apply vf vx =
        match vf, vx with
        | Valid f, Valid x -> Valid (f x)
        | Invalid es, Valid _ -> Invalid es
        | Valid _, Invalid es -> Invalid es
        | Invalid es1, Invalid es2 -> Invalid (es1 @ es2)

    /// Bind (monadic) - fails fast, use sparingly
    let bind f = function
        | Valid x -> f x
        | Invalid es -> Invalid es

    /// Map2 using applicative
    let map2 f v1 v2 =
        apply (map f v1) v2

    /// Map3 using applicative
    let map3 f v1 v2 v3 =
        apply (apply (map f v1) v2) v3

    /// Map4 using applicative
    let map4 f v1 v2 v3 v4 =
        apply (apply (apply (map f v1) v2) v3) v4

    /// Map5 using applicative
    let map5 f v1 v2 v3 v4 v5 =
        apply (apply (apply (apply (map f v1) v2) v3) v4) v5

    /// Sequence a list of validated values
    let sequence validatedList =
        List.foldBack (map2 (fun h t -> h :: t)) validatedList (pure' [])

    /// Traverse a list with a validation function
    let traverse f list =
        list |> List.map f |> sequence

    /// Convert from Result
    let fromResult = function
        | Ok x -> Valid x
        | Error e -> Invalid [e]

    /// Convert to Result
    let toResult = function
        | Valid x -> Ok x
        | Invalid es -> Error es

    /// Convert from Option with error
    let fromOption error = function
        | Some x -> Valid x
        | None -> Invalid [error]

    /// Combine multiple validated values into a tuple
    let zip2 v1 v2 = map2 (fun a b -> (a, b)) v1 v2
    let zip3 v1 v2 v3 = map3 (fun a b c -> (a, b, c)) v1 v2 v3
    let zip4 v1 v2 v3 v4 = map4 (fun a b c d -> (a, b, c, d)) v1 v2 v3 v4

    /// Filter with validation
    let filter predicate error validated =
        bind (fun x -> if predicate x then pure' x else fail error) validated

    /// Recover from errors
    let orElse fallback = function
        | Valid x -> Valid x
        | Invalid _ -> fallback

    /// Recover with function
    let orElseWith f = function
        | Valid x -> Valid x
        | Invalid es -> f es

// ============================================================================
// VALIDATOR TYPE
// ============================================================================

/// A validator is a function that produces a Validated result
type Validator<'E, 'A, 'B> = 'A -> Validated<'E, 'B>

module Validator =
    /// Identity validator
    let id: Validator<'E, 'A, 'A> = Validated.pure'

    /// Compose validators sequentially
    let andThen (v2: Validator<'E, 'B, 'C>) (v1: Validator<'E, 'A, 'B>) : Validator<'E, 'A, 'C> =
        v1 >> Validated.bind v2

    /// Compose validators in parallel (accumulates errors)
    let andAlso (v2: Validator<'E, 'A, 'C>) (v1: Validator<'E, 'A, 'B>) : Validator<'E, 'A, 'B * 'C> =
        fun a -> Validated.zip2 (v1 a) (v2 a)

    /// Map the output of a validator
    let map f (v: Validator<'E, 'A, 'B>) : Validator<'E, 'A, 'C> =
        v >> Validated.map f

    /// Map the error of a validator
    let mapError f (v: Validator<'E1, 'A, 'B>) : Validator<'E2, 'A, 'B> =
        v >> function
        | Valid x -> Valid x
        | Invalid es -> Invalid (List.map f es)

    /// Contramap the input of a validator
    let contramap (f: 'B -> 'A) (v: Validator<'E, 'A, 'C>) : Validator<'E, 'B, 'C> =
        f >> v

    /// Optional validator - passes None through
    let optional (v: Validator<'E, 'A, 'B>) : Validator<'E, 'A option, 'B option> =
        function
        | None -> Valid None
        | Some a -> v a |> Validated.map Some

    /// Required - convert None to error
    let required error : Validator<'E, 'A option, 'A> =
        function
        | Some a -> Valid a
        | None -> Invalid [error]

// ============================================================================
// COMMON VALIDATORS
// ============================================================================

/// String validators
module StringValidators =
    open Validated

    let notEmpty path : Validator<ValidationError, string, string> =
        fun s ->
            if String.IsNullOrEmpty(s)
            then fail (ValidationError.create path "Must not be empty" |> ValidationError.withCode "NOT_EMPTY")
            else pure' s

    let notWhitespace path : Validator<ValidationError, string, string> =
        fun s ->
            if String.IsNullOrWhiteSpace(s)
            then fail (ValidationError.create path "Must not be blank" |> ValidationError.withCode "NOT_BLANK")
            else pure' s

    let minLength min path : Validator<ValidationError, string, string> =
        fun s ->
            if s.Length < min
            then fail (ValidationError.create path (sprintf "Must be at least %d characters" min)
                      |> ValidationError.withCode "MIN_LENGTH"
                      |> ValidationError.withDetail "min" min)
            else pure' s

    let maxLength max path : Validator<ValidationError, string, string> =
        fun s ->
            if s.Length > max
            then fail (ValidationError.create path (sprintf "Must be at most %d characters" max)
                      |> ValidationError.withCode "MAX_LENGTH"
                      |> ValidationError.withDetail "max" max)
            else pure' s

    let lengthBetween min max path : Validator<ValidationError, string, string> =
        fun s ->
            if s.Length < min || s.Length > max
            then fail (ValidationError.create path (sprintf "Must be between %d and %d characters" min max)
                      |> ValidationError.withCode "LENGTH_RANGE")
            else pure' s

    let matches pattern path : Validator<ValidationError, string, string> =
        fun s ->
            if Regex.IsMatch(s, pattern)
            then pure' s
            else fail (ValidationError.create path "Does not match required pattern"
                      |> ValidationError.withCode "PATTERN")

    let email path : Validator<ValidationError, string, string> =
        let emailPattern = @"^[^@\s]+@[^@\s]+\.[^@\s]+$"
        fun s ->
            if Regex.IsMatch(s, emailPattern)
            then pure' s
            else fail (ValidationError.create path "Must be a valid email address"
                      |> ValidationError.withCode "EMAIL")

    let url path : Validator<ValidationError, string, Uri> =
        fun s ->
            match Uri.TryCreate(s, UriKind.Absolute) with
            | true, uri when uri.Scheme = "http" || uri.Scheme = "https" -> pure' uri
            | _ -> fail (ValidationError.create path "Must be a valid URL"
                        |> ValidationError.withCode "URL")

/// Numeric validators
module NumericValidators =
    open Validated

    let min minVal path : Validator<ValidationError, 'T, 'T> when 'T : comparison =
        fun n ->
            if n < minVal
            then fail (ValidationError.create path (sprintf "Must be at least %A" minVal)
                      |> ValidationError.withCode "MIN")
            else pure' n

    let max maxVal path : Validator<ValidationError, 'T, 'T> when 'T : comparison =
        fun n ->
            if n > maxVal
            then fail (ValidationError.create path (sprintf "Must be at most %A" maxVal)
                      |> ValidationError.withCode "MAX")
            else pure' n

    let between minVal maxVal path : Validator<ValidationError, 'T, 'T> when 'T : comparison =
        fun n ->
            if n < minVal || n > maxVal
            then fail (ValidationError.create path (sprintf "Must be between %A and %A" minVal maxVal)
                      |> ValidationError.withCode "RANGE")
            else pure' n

    let positive path : Validator<ValidationError, int, int> =
        min 1 path

    let nonNegative path : Validator<ValidationError, int, int> =
        min 0 path

/// Collection validators
module CollectionValidators =
    open Validated

    let notEmpty path : Validator<ValidationError, 'T list, 'T list> =
        fun xs ->
            if List.isEmpty xs
            then fail (ValidationError.create path "Must not be empty"
                      |> ValidationError.withCode "NOT_EMPTY")
            else pure' xs

    let minLength min path : Validator<ValidationError, 'T list, 'T list> =
        fun xs ->
            if List.length xs < min
            then fail (ValidationError.create path (sprintf "Must have at least %d items" min)
                      |> ValidationError.withCode "MIN_LENGTH")
            else pure' xs

    let maxLength max path : Validator<ValidationError, 'T list, 'T list> =
        fun xs ->
            if List.length xs > max
            then fail (ValidationError.create path (sprintf "Must have at most %d items" max)
                      |> ValidationError.withCode "MAX_LENGTH")
            else pure' xs

    let each (itemValidator: int -> Validator<ValidationError, 'A, 'B>) path : Validator<ValidationError, 'A list, 'B list> =
        fun xs ->
            xs
            |> List.mapi (fun i x ->
                let itemPath = ValidationPath.index i path
                itemValidator i x)
            |> Validated.sequence

    let all (predicate: 'A -> bool) message path : Validator<ValidationError, 'A list, 'A list> =
        fun xs ->
            if List.forall predicate xs
            then pure' xs
            else fail (ValidationError.create path message
                      |> ValidationError.withCode "ALL")

    let distinct keyFn path : Validator<ValidationError, 'A list, 'A list> =
        fun xs ->
            let keys = List.map keyFn xs
            let unique = List.distinct keys
            if List.length keys = List.length unique
            then pure' xs
            else fail (ValidationError.create path "All items must be unique"
                      |> ValidationError.withCode "DISTINCT")

/// Date validators
module DateValidators =
    open Validated

    let notInPast path : Validator<ValidationError, DateTime, DateTime> =
        fun dt ->
            if dt < DateTime.UtcNow
            then fail (ValidationError.create path "Must not be in the past"
                      |> ValidationError.withCode "NOT_PAST")
            else pure' dt

    let notInFuture path : Validator<ValidationError, DateTime, DateTime> =
        fun dt ->
            if dt > DateTime.UtcNow
            then fail (ValidationError.create path "Must not be in the future"
                      |> ValidationError.withCode "NOT_FUTURE")
            else pure' dt

    let after minDate path : Validator<ValidationError, DateTime, DateTime> =
        fun dt ->
            if dt <= minDate
            then fail (ValidationError.create path (sprintf "Must be after %s" (minDate.ToString("o")))
                      |> ValidationError.withCode "AFTER")
            else pure' dt

    let before maxDate path : Validator<ValidationError, DateTime, DateTime> =
        fun dt ->
            if dt >= maxDate
            then fail (ValidationError.create path (sprintf "Must be before %s" (maxDate.ToString("o")))
                      |> ValidationError.withCode "BEFORE")
            else pure' dt

// ============================================================================
// VALIDATION BUILDER
// ============================================================================

/// Computation expression for validation
type ValidationBuilder() =
    member _.Return(x) = Validated.pure' x
    member _.ReturnFrom(v) = v
    member _.Bind(v, f) = Validated.bind f v
    member _.Zero() = Validated.pure' ()
    member _.Combine(v1, v2) = Validated.bind (fun () -> v2) v1
    member _.Delay(f) = f ()

    /// Applicative merge (accumulates errors)
    member _.MergeSources(v1, v2) =
        Validated.zip2 v1 v2

    member _.MergeSources3(v1, v2, v3) =
        Validated.zip3 v1 v2 v3

    member _.BindReturn(v, f) = Validated.map f v

    member _.Source(v: Validated<'E, 'T>) = v
    member _.Source(r: Result<'T, 'E>) = Validated.fromResult r
    member _.Source(o: 'T option) = match o with Some x -> Valid x | None -> Invalid []

[<AutoOpen>]
module ValidationBuilders =
    let validated = ValidationBuilder()

// ============================================================================
// VALIDATION SCHEMA
// ============================================================================

/// Schema-based validation for complex objects
module Schema =

    /// Field definition
    type Field<'Record, 'Field, 'ValidatedField> = {
        Name: string
        Get: 'Record -> 'Field
        Validator: Validator<ValidationError, 'Field, 'ValidatedField>
    }

    /// Create a field
    let field name getter validator = {
        Name = name
        Get = getter
        Validator = validator
    }

    /// Validate a field
    let validateField path record field =
        let value = field.Get record
        let fieldPath = ValidationPath.field field.Name path
        field.Validator value
        |> Validated.map (fun v -> (field.Name, box v))

    /// Combine validated fields into a record
    let build (constructor: Map<string, obj> -> 'Output) validatedFields =
        validatedFields
        |> Validated.sequence
        |> Validated.map (Map.ofList >> constructor)

// ============================================================================
// VALIDATION COMBINATORS
// ============================================================================

module ValidatorCombinators =
    open Validated

    /// Validate and transform
    let (|>>) input validator = validator input

    /// Compose validators
    let (>=>) v1 v2 = Validator.andThen v2 v1

    /// Parallel compose
    let (<&>) v1 v2 = Validator.andAlso v2 v1

    /// Validate condition
    let ensure condition errorFn value =
        if condition value then pure' value
        else fail (errorFn value)

    /// Validate with custom logic
    let custom f = f

    /// When condition, apply validator
    let when' condition validator value =
        if condition then validator value
        else pure' value

    /// Unless condition, apply validator
    let unless condition validator = when' (not condition) validator

    /// One of - value must be in list
    let oneOf validValues path : Validator<ValidationError, 'T, 'T> when 'T : equality =
        fun value ->
            if List.contains value validValues
            then pure' value
            else fail (ValidationError.create path "Must be one of the allowed values"
                      |> ValidationError.withCode "ONE_OF"
                      |> ValidationError.withDetail "allowed" validValues)

    /// Not one of - value must not be in list
    let notOneOf invalidValues path : Validator<ValidationError, 'T, 'T> when 'T : equality =
        fun value ->
            if not (List.contains value invalidValues)
            then pure' value
            else fail (ValidationError.create path "Must not be one of the disallowed values"
                      |> ValidationError.withCode "NOT_ONE_OF")
