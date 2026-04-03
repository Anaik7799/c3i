namespace Cepaf.Observability.Fractal

open System
open System.Text.RegularExpressions

/// Zenoh-style Key Expression Engine for flexible log targeting.
/// Supports wildcards: * (single segment), ** (any path), $* (infix match)
/// STAMP Compliance: SC-LOG-009 (Key aliases pre-registered at startup)
module KeyExpression =

    // ============================================================
    // TYPES
    // ============================================================

    /// Compiled key expression for efficient matching
    type CompiledExpr = {
        /// Original key expression string
        Original: string

        /// Compiled regex pattern
        Regex: Regex

        /// Parsed segments for optimization
        Segments: string list

        /// Has single wildcard (*)
        HasWildcard: bool

        /// Has double wildcard (**)
        HasDoubleWildcard: bool

        /// Has infix wildcard ($*)
        HasInfixWildcard: bool

        /// Is exact match (no wildcards)
        IsExact: bool

        /// Compilation time for diagnostics
        CompiledAt: DateTimeOffset
    }

    /// Key expression parse result
    type ParseResult =
        | Exact of string
        | SingleWildcard of prefix: string * suffix: string
        | DoubleWildcard of prefix: string * suffix: string
        | InfixWildcard of prefix: string * pattern: string * suffix: string
        | Complex of segments: string list

    /// Selector with query parameters (Zenoh-style)
    type Selector = {
        KeyExpr: CompiledExpr
        Parameters: Map<string, string>
        Filters: Map<string, string>
    }

    // ============================================================
    // COMPILATION
    // ============================================================

    /// Escape special regex characters
    let private escapeRegex (s: string) =
        Regex.Escape(s)

    /// Compile a key expression to an optimized matcher
    let compile (expr: string) : Result<CompiledExpr, string> =
        try
            // Validate for invalid wildcard sequences
            if expr.Contains("***") then
                Error $"Invalid wildcard sequence '***' in key expression '{expr}'"
            else

            // Normalize separators (support both . and /)
            let normalized = expr.Replace(".", "/")

            // Check for wildcard types
            let hasWildcard = normalized.Contains("*") && not (normalized.Contains("**"))
            let hasDoubleWildcard = normalized.Contains("**")
            let hasInfixWildcard = normalized.Contains("$*")

            // Build regex pattern by escaping first, then replacing wildcards
            // Use placeholder tokens to avoid double-escaping
            let placeholder_dblwild = "\x00DBLWILD\x00"
            let placeholder_infixwild = "\x00INFIXWILD\x00"
            let placeholder_singlewild = "\x00SINGLEWILD\x00"

            let pattern =
                normalized
                    // Temporarily replace wildcards with placeholders
                    |> fun s -> s.Replace("$*", placeholder_infixwild)
                    |> fun s -> s.Replace("**", placeholder_dblwild)
                    |> fun s -> s.Replace("*", placeholder_singlewild)
                    // Escape all remaining special regex chars
                    |> escapeRegex
                    // Replace placeholders with regex patterns
                    |> fun s -> s.Replace(placeholder_infixwild, "([^/]*)")
                    |> fun s -> s.Replace(placeholder_singlewild, "([^/]+)")
                    // Handle ** patterns with special edge cases
                    // ** at start: match empty or any prefix with /
                    // ** at end: match empty or any suffix starting with /
                    // ** in middle: match empty or any path between slashes
                    |> fun s ->
                        // Pattern: "/**/" in middle -> "(/.*)?" followed by "/" (optionally any path, then /)
                        let s = s.Replace("/" + placeholder_dblwild + "/", "(/.*)?/")
                        // Pattern: "**/" at start -> "(.*/)?" (optionally any path ending with /)
                        let s = if s.StartsWith(placeholder_dblwild + "/") then
                                    "(.*/)?".ToString() + s.Substring(placeholder_dblwild.Length + 1)
                                else s
                        // Pattern: "/**" at end -> "(/.*)?$" (optionally / followed by anything)
                        let s = if s.EndsWith("/" + placeholder_dblwild) then
                                    s.Substring(0, s.Length - placeholder_dblwild.Length - 1) + "(/.*)?"
                                else s
                        // For any remaining standalone **, just use (.*)
                        s.Replace(placeholder_dblwild, "(.*)")

            // Parse segments for optimization
            let segments =
                normalized.Split('/')
                |> Array.toList

            // Compile regex with options for performance
            let regex = Regex(
                $"^{pattern}$",
                RegexOptions.Compiled ||| RegexOptions.Singleline
            )

            Ok {
                Original = expr
                Regex = regex
                Segments = segments
                HasWildcard = hasWildcard
                HasDoubleWildcard = hasDoubleWildcard
                HasInfixWildcard = hasInfixWildcard
                IsExact = not (hasWildcard || hasDoubleWildcard || hasInfixWildcard)
                CompiledAt = DateTimeOffset.UtcNow
            }
        with ex ->
            Error $"Failed to compile key expression '{expr}': {ex.Message}"

    /// Compile a key expression, throwing on error
    let compileOrThrow (expr: string) : CompiledExpr =
        match compile expr with
        | Ok compiled -> compiled
        | Error msg -> failwith msg

    // ============================================================
    // MATCHING
    // ============================================================

    /// Check if a key matches a compiled expression (O(1) for exact, O(n) for regex)
    let matches (compiled: CompiledExpr) (key: string) : bool =
        // Normalize key (support both . and / separators)
        let normalizedKey = key.Replace(".", "/")
        // Also normalize compiled.Original for comparison
        let normalizedOriginal = compiled.Original.Replace(".", "/")

        // Fast path: exact match
        if compiled.IsExact then
            normalizedKey = normalizedOriginal
        else
            compiled.Regex.IsMatch(normalizedKey)

    /// Check if a key matches an expression string (compiles on each call)
    let matchesExpr (expr: string) (key: string) : bool =
        match compile expr with
        | Ok compiled -> matches compiled key
        | Error _ -> false

    /// Check if two expressions could potentially match the same keys
    let intersects (a: CompiledExpr) (b: CompiledExpr) : bool =
        // If either is **, they always intersect
        if a.HasDoubleWildcard || b.HasDoubleWildcard then
            true
        // If both are exact, they intersect only if equal
        elif a.IsExact && b.IsExact then
            a.Original = b.Original
        // Otherwise, check if one could match the other
        else
            matches a b.Original || matches b a.Original

    // ============================================================
    // SELECTORS (Key Expression + Query Parameters)
    // ============================================================

    /// Parse a selector string (key_expr?param=value&filter.key=value)
    let parseSelector (selectorStr: string) : Result<Selector, string> =
        try
            let parts = selectorStr.Split('?')
            let keyExprStr = parts.[0]

            let parameters, filters =
                if parts.Length > 1 then
                    parts.[1].Split('&')
                    |> Array.fold (fun (pars, filts) param ->
                        let kvp = param.Split('=')
                        if kvp.Length = 2 then
                            let key = kvp.[0]
                            let value = kvp.[1]
                            if key.StartsWith("filter.") then
                                (pars, filts |> Map.add (key.Substring(7)) value)
                            else
                                (pars |> Map.add key value, filts)
                        else
                            (pars, filts)
                    ) (Map.empty, Map.empty)
                else
                    (Map.empty, Map.empty)

            match compile keyExprStr with
            | Ok compiled ->
                Ok {
                    KeyExpr = compiled
                    Parameters = parameters
                    Filters = filters
                }
            | Error msg -> Error msg
        with ex ->
            Error $"Failed to parse selector '{selectorStr}': {ex.Message}"

    /// Extract query parameters from selector
    let getParameter (selector: Selector) (key: string) : string option =
        selector.Parameters |> Map.tryFind key

    /// Extract filter from selector
    let getFilter (selector: Selector) (key: string) : string option =
        selector.Filters |> Map.tryFind key

    // ============================================================
    // KEY BUILDING
    // ============================================================

    /// Build a key from module and function
    let buildKey (moduleName: string) (functionName: string) : string =
        $"{moduleName}/{functionName}"

    /// Build a key from module, function, and event type
    let buildKeyWithEvent (moduleName: string) (functionName: string) (eventType: string) : string =
        $"{moduleName}/{functionName}/{eventType}"

    /// Extract module name from key
    let extractModule (key: string) : string option =
        let normalized = key.Replace(".", "/")
        let parts = normalized.Split('/')
        if parts.Length >= 1 then Some parts.[0]
        else None

    /// Extract function name from key
    let extractFunction (key: string) : string option =
        let normalized = key.Replace(".", "/")
        let parts = normalized.Split('/')
        if parts.Length >= 2 then Some parts.[parts.Length - 1]
        else None

    // ============================================================
    // PATTERN EXAMPLES
    // ============================================================

    /// Common key expression patterns for reference
    module Patterns =
        /// Match all events in a module
        let allInModule moduleName = $"{moduleName}/**"

        /// Match all create events anywhere
        let allCreate = "**/create"

        /// Match all errors anywhere
        let allErrors = "**/error"

        /// Match specific function in any module
        let functionInAny funcName = $"**/{funcName}"

        /// Match any Handler suffix
        let anyHandler = "**/$*Handler"

        /// Match Cortex cognitive events
        let cortexCognitive = "Indrajaal/Cortex/**"

        /// Match security audit events
        let securityAudit = "Indrajaal/Security/**"

        /// Match all alarms
        let allAlarms = "Indrajaal/Alarms/**"

    // ============================================================
    // VALIDATION
    // ============================================================

    /// Validate a key expression syntax
    let validate (expr: string) : Result<unit, string list> =
        let errors = ResizeArray<string>()

        // Check for empty
        if String.IsNullOrWhiteSpace(expr) then
            errors.Add("Key expression cannot be empty")

        // Check for invalid characters
        let invalidChars = [| '<'; '>'; '|'; '\\'; '"'; '''|]
        for c in invalidChars do
            if expr.Contains(c) then
                errors.Add($"Invalid character '{c}' in key expression")

        // Check for adjacent wildcards
        if expr.Contains("***") then
            errors.Add("Invalid wildcard sequence '***'")

        // Check for leading/trailing slashes
        if expr.StartsWith("/") || expr.EndsWith("/") then
            errors.Add("Key expression should not start or end with '/'")

        // Try compilation as final check
        match compile expr with
        | Error msg -> errors.Add(msg)
        | Ok _ -> ()

        if errors.Count = 0 then Ok ()
        else Error (errors |> Seq.toList)

    /// Check if an expression is valid
    let isValid (expr: string) : bool =
        match validate expr with
        | Ok _ -> true
        | Error _ -> false
