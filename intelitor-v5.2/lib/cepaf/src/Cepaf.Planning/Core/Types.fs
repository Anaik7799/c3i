// =============================================================================
// Types.fs - Core Fundamental Types for Planning System
// =============================================================================
// STAMP: SC-PLAN-001, SC-FUNC-001
// AOR: AOR-PLAN-001
// Criticality: Level 1 (CRITICAL) - Foundation
// =============================================================================

namespace Cepaf.Planning.Core

open System

/// Timestamp with timezone awareness (UTC preferred)
type Timestamp = DateTimeOffset

/// Non-empty string with validation
type NonEmptyString = private NonEmptyString of string

module NonEmptyString =
    let create (s: string) =
        if String.IsNullOrWhiteSpace(s) then
            Error "String cannot be empty or whitespace"
        else
            Ok (NonEmptyString s)

    let value (NonEmptyString s) = s

    let tryCreate (s: string) =
        if String.IsNullOrWhiteSpace(s) then None
        else Some (NonEmptyString s)

/// Positive integer (> 0) with validation
type PositiveInt = private PositiveInt of int

module PositiveInt =
    let create (n: int) =
        if n > 0 then Ok (PositiveInt n)
        else Error "Integer must be positive (> 0)"

    let value (PositiveInt n) = n

    let tryCreate (n: int) =
        if n > 0 then Some (PositiveInt n)
        else None

/// Non-negative integer (>= 0) with validation
type NonNegativeInt = private NonNegativeInt of int

module NonNegativeInt =
    let create (n: int) =
        if n >= 0 then Ok (NonNegativeInt n)
        else Error "Integer must be non-negative (>= 0)"

    let value (NonNegativeInt n) = n

/// Percentage (0.0-100.0) with validation
type Percentage = private Percentage of float

module Percentage =
    let create (p: float) =
        if p >= 0.0 && p <= 100.0 then Ok (Percentage p)
        else Error "Percentage must be between 0 and 100"

    let value (Percentage p) = p

    let zero = Percentage 0.0
    let full = Percentage 100.0

/// Unit interval (0.0-1.0) for probabilities, confidence, etc.
type UnitInterval = private UnitInterval of float

module UnitInterval =
    let create (v: float) =
        if v >= 0.0 && v <= 1.0 then Ok (UnitInterval v)
        else Error "Value must be between 0.0 and 1.0"

    let value (UnitInterval v) = v

    let zero = UnitInterval 0.0
    let one = UnitInterval 1.0

/// Email address with basic validation
type EmailAddress = private EmailAddress of string

module EmailAddress =
    let create (s: string) =
        if String.IsNullOrWhiteSpace(s) then
            Error "Email cannot be empty"
        elif s.Contains("@") && s.Contains(".") then
            Ok (EmailAddress s)
        else
            Error "Invalid email format"

    let value (EmailAddress s) = s

/// URL with basic validation
type Url = private Url of string

module Url =
    let create (s: string) =
        if String.IsNullOrWhiteSpace(s) then
            Error "URL cannot be empty"
        elif s.StartsWith("http://") || s.StartsWith("https://") then
            Ok (Url s)
        else
            Error "URL must start with http:// or https://"

    let value (Url s) = s

/// Duration in milliseconds
type DurationMs = private DurationMs of int64

module DurationMs =
    let create (ms: int64) =
        if ms >= 0L then Ok (DurationMs ms)
        else Error "Duration cannot be negative"

    let value (DurationMs ms) = ms

    let fromTimeSpan (ts: TimeSpan) =
        DurationMs (int64 ts.TotalMilliseconds)

    let toTimeSpan (DurationMs ms) =
        TimeSpan.FromMilliseconds(float ms)

    let zero = DurationMs 0L

/// Semantic version
type SemanticVersion = {
    Major: int
    Minor: int
    Patch: int
    Prerelease: string option
}

module SemanticVersion =
    let create major minor patch =
        { Major = major; Minor = minor; Patch = patch; Prerelease = None }

    let toString (v: SemanticVersion) =
        match v.Prerelease with
        | Some pre -> sprintf "%d.%d.%d-%s" v.Major v.Minor v.Patch pre
        | None -> sprintf "%d.%d.%d" v.Major v.Minor v.Patch

    let parse (s: string) =
        try
            let parts = s.Split([|'-'|], 2)
            let versionParts = parts.[0].Split([|'.'|])
            let version = {
                Major = Int32.Parse(versionParts.[0])
                Minor = if versionParts.Length > 1 then Int32.Parse(versionParts.[1]) else 0
                Patch = if versionParts.Length > 2 then Int32.Parse(versionParts.[2]) else 0
                Prerelease = if parts.Length > 1 then Some parts.[1] else None
            }
            Ok version
        with ex ->
            Error (sprintf "Invalid version format: %s" ex.Message)

/// Error with context
type DomainError = {
    Code: string
    Message: string
    Context: Map<string, string>
    Timestamp: Timestamp
    InnerError: DomainError option
}

module DomainError =
    let create code message =
        {
            Code = code
            Message = message
            Context = Map.empty
            Timestamp = DateTimeOffset.UtcNow
            InnerError = None
        }

    let withContext key value error =
        { error with Context = error.Context |> Map.add key value }

    let withInner inner error =
        { error with InnerError = Some inner }

    let toString error =
        sprintf "[%s] %s" error.Code error.Message
