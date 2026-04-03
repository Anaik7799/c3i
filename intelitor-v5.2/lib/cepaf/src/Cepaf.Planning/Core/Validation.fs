// =============================================================================
// Validation.fs - Input Validation for Planning System
// =============================================================================
// STAMP: SC-PLAN-004
// AOR: AOR-PLAN-004
// Criticality: Level 1 (CRITICAL) - Foundation
// =============================================================================

namespace Cepaf.Planning.Core

open System
open System.Text.RegularExpressions

/// Validation error with field context
type ValidationError = {
    Field: string
    Message: string
    Value: obj option
}

module ValidationError =
    let create field message =
        { Field = field; Message = message; Value = None }

    let withValue value error =
        { error with Value = Some (box value) }

    let toString error =
        sprintf "%s: %s" error.Field error.Message

/// Validation result that accumulates errors
type ValidationResult<'a> =
    | Valid of 'a
    | Invalid of ValidationError list

module ValidationResult =
    let map f result =
        match result with
        | Valid x -> Valid (f x)
        | Invalid errors -> Invalid errors

    let bind f result =
        match result with
        | Valid x -> f x
        | Invalid errors -> Invalid errors

    let apply fResult xResult =
        match fResult, xResult with
        | Valid f, Valid x -> Valid (f x)
        | Invalid e1, Invalid e2 -> Invalid (e1 @ e2)
        | Invalid e, _ -> Invalid e
        | _, Invalid e -> Invalid e

    let toResult result =
        match result with
        | Valid x -> Ok x
        | Invalid errors ->
            let message = errors |> List.map ValidationError.toString |> String.concat "; "
            Error message

    let ofResult fieldName result =
        match result with
        | Ok x -> Valid x
        | Error msg -> Invalid [ValidationError.create fieldName msg]

/// Validation primitives
module Validate =

    /// Validate that string is not empty
    let notEmpty (fieldName: string) (value: string) : ValidationResult<string> =
        if String.IsNullOrWhiteSpace(value) then
            Invalid [ValidationError.create fieldName "cannot be empty"]
        else
            Valid value

    /// Validate string length
    let maxLength (max: int) (fieldName: string) (value: string) : ValidationResult<string> =
        if value.Length > max then
            Invalid [ValidationError.create fieldName (sprintf "cannot exceed %d characters" max)]
        else
            Valid value

    /// Validate string minimum length
    let minLength (min: int) (fieldName: string) (value: string) : ValidationResult<string> =
        if value.Length < min then
            Invalid [ValidationError.create fieldName (sprintf "must be at least %d characters" min)]
        else
            Valid value

    /// Validate string matches regex
    let matches (pattern: string) (fieldName: string) (value: string) : ValidationResult<string> =
        if Regex.IsMatch(value, pattern) then
            Valid value
        else
            Invalid [ValidationError.create fieldName "has invalid format"]

    /// Validate integer is positive
    let positive (fieldName: string) (value: int) : ValidationResult<int> =
        if value > 0 then
            Valid value
        else
            Invalid [ValidationError.create fieldName "must be positive"]

    /// Validate integer is non-negative
    let nonNegative (fieldName: string) (value: int) : ValidationResult<int> =
        if value >= 0 then
            Valid value
        else
            Invalid [ValidationError.create fieldName "cannot be negative"]

    /// Validate integer is in range
    let inRange (min: int) (max: int) (fieldName: string) (value: int) : ValidationResult<int> =
        if value >= min && value <= max then
            Valid value
        else
            Invalid [ValidationError.create fieldName (sprintf "must be between %d and %d" min max)]

    /// Validate float is in range
    let floatInRange (min: float) (max: float) (fieldName: string) (value: float) : ValidationResult<float> =
        if value >= min && value <= max then
            Valid value
        else
            Invalid [ValidationError.create fieldName (sprintf "must be between %.2f and %.2f" min max)]

    /// Validate date is not in the past
    let notInPast (fieldName: string) (value: DateTimeOffset) : ValidationResult<DateTimeOffset> =
        if value >= DateTimeOffset.UtcNow then
            Valid value
        else
            Invalid [ValidationError.create fieldName "cannot be in the past"]

    /// Validate date is in the future
    let inFuture (fieldName: string) (value: DateTimeOffset) : ValidationResult<DateTimeOffset> =
        if value > DateTimeOffset.UtcNow then
            Valid value
        else
            Invalid [ValidationError.create fieldName "must be in the future"]

    /// Validate option has value
    let required (fieldName: string) (value: 'a option) : ValidationResult<'a> =
        match value with
        | Some x -> Valid x
        | None -> Invalid [ValidationError.create fieldName "is required"]

    /// Validate list is not empty
    let notEmptyList (fieldName: string) (value: 'a list) : ValidationResult<'a list> =
        if List.isEmpty value then
            Invalid [ValidationError.create fieldName "cannot be empty"]
        else
            Valid value

    /// Validate custom predicate
    let satisfies (predicate: 'a -> bool) (message: string) (fieldName: string) (value: 'a) : ValidationResult<'a> =
        if predicate value then
            Valid value
        else
            Invalid [ValidationError.create fieldName message]

    /// Combine validations (AND)
    let andThen (next: 'a -> ValidationResult<'a>) (result: ValidationResult<'a>) : ValidationResult<'a> =
        match result with
        | Valid x -> next x
        | Invalid errors -> Invalid errors

    /// Combine validations, accumulating errors
    let combine (results: ValidationResult<'a> list) : ValidationResult<'a list> =
        let folder state result =
            match state, result with
            | Valid acc, Valid x -> Valid (x :: acc)
            | Invalid e1, Invalid e2 -> Invalid (e1 @ e2)
            | Invalid e, _ -> Invalid e
            | _, Invalid e -> Invalid e
        results |> List.fold folder (Valid []) |> ValidationResult.map List.rev

/// Validation computation expression
type ValidationBuilder() =
    member _.Bind(m: ValidationResult<'a>, f: 'a -> ValidationResult<'b>) : ValidationResult<'b> =
        ValidationResult.bind f m

    member _.Return(x) = Valid x
    member _.ReturnFrom(m) = m
    member _.Zero() = Valid ()

    member _.Combine(a: ValidationResult<unit>, b: ValidationResult<'b>) : ValidationResult<'b> =
        match a with
        | Valid () -> b
        | Invalid errors -> Invalid errors

    member _.Delay(f) = f
    member _.Run(f) = f ()

/// Module containing the global validation builder instance
[<AutoOpen>]
module ValidationBuilderInstance =
    /// Global validation builder instance
    let validation = ValidationBuilder()

/// Applicative validation (accumulates all errors)
module ApplicativeValidation =

    /// Lift a function into validation context
    let lift f = Valid f

    /// Apply validation result to function
    let (<*>) = ValidationResult.apply

    /// Map over validation result
    let (<!>) f x = ValidationResult.map f x

    /// Validate 2 values and combine with function
    let validate2 f v1 v2 =
        lift f <*> v1 <*> v2

    /// Validate 3 values and combine with function
    let validate3 f v1 v2 v3 =
        lift f <*> v1 <*> v2 <*> v3

    /// Validate 4 values and combine with function
    let validate4 f v1 v2 v3 v4 =
        lift f <*> v1 <*> v2 <*> v3 <*> v4

    /// Validate 5 values and combine with function
    let validate5 f v1 v2 v3 v4 v5 =
        lift f <*> v1 <*> v2 <*> v3 <*> v4 <*> v5
