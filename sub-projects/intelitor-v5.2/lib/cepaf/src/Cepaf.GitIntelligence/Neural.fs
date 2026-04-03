// =============================================================================
// Git Intelligence — Neural (Cortex/Synapse AI) Subsystem
// =============================================================================
// Purpose:  Wrap OpenRouter AI for commit message quality assessment and
//           suggestion. Provides heuristic fallback when API is unavailable.
//
// Pattern:  Mirror existing Program.fs cmdSuggest for API calls.
//           Cache results in-memory for session lifetime.
//
// STAMP:    SC-NEURO-001, AOR-OPENROUTER-001/005
// =============================================================================

module Cepaf.GitIntelligence.Neural

open System
open System.Collections.Generic

// ─────────────────────────────────────────────────────────────────────────────
// In-memory cache (session lifetime, no persistence needed)
// ─────────────────────────────────────────────────────────────────────────────

let private cache = Dictionary<string, NeuralRecommendation>()

let private cacheKey (message: string) = message.Trim().ToLowerInvariant()

// ─────────────────────────────────────────────────────────────────────────────
// Heuristic Semantic Quality Assessment (no API needed)
// ─────────────────────────────────────────────────────────────────────────────

/// Assess semantic quality of a commit message using heuristics.
/// Returns 0.0 - 1.0 quality score.
let assessSemanticQuality (message: string) : float =
    if String.IsNullOrWhiteSpace(message) then 0.0
    else
        let mutable score = 0.0
        let msg = message.Trim()

        // Length penalty: too short or too long
        let len = msg.Length
        if len >= 20 && len <= 80 then score <- score + 0.20
        elif len >= 10 then score <- score + 0.10

        // Has type prefix (e.g. "feat(scope): ...")
        if Text.RegularExpressions.Regex.IsMatch(msg, @"^(feat|fix|refactor|perf|test|docs|chore|security|evolve)\(") then
            score <- score + 0.25
        elif Text.RegularExpressions.Regex.IsMatch(msg, @"^(feat|fix|refactor|perf|test|docs|chore|security|evolve):") then
            score <- score + 0.15

        // Has scope
        if msg.Contains("(") && msg.Contains(")") && msg.IndexOf("(") < msg.IndexOf(")") then
            score <- score + 0.10

        // Has em-dash context channel
        if msg.Contains(" — ") || msg.Contains(" -- ") then
            score <- score + 0.15

        // Imperative mood (starts with verb after type/scope prefix)
        let actionPart =
            let colonIdx = msg.IndexOf(':')
            if colonIdx >= 0 && colonIdx < msg.Length - 2 then msg.Substring(colonIdx + 1).TrimStart()
            else msg
        let imperativeVerbs = [| "add"; "fix"; "update"; "remove"; "refactor"; "implement"; "create"; "delete"; "move"; "rename"; "extract"; "merge"; "split"; "enable"; "disable"; "correct"; "improve"; "optimize"; "wire"; "resolve" |]
        let firstWord = actionPart.Split([|' '; '\t'|], StringSplitOptions.RemoveEmptyEntries) |> Array.tryHead
        match firstWord with
        | Some w when imperativeVerbs |> Array.exists (fun v -> w.StartsWith(v, StringComparison.OrdinalIgnoreCase)) ->
            score <- score + 0.15
        | _ -> ()

        // Penalize anti-patterns
        if msg.StartsWith("EVOLUTION RUN", StringComparison.OrdinalIgnoreCase) then score <- score - 0.30
        if msg.StartsWith("SINGULARITY", StringComparison.OrdinalIgnoreCase) then score <- score - 0.20
        if msg.Length > 0 && Char.IsUpper(msg.[0]) && msg = msg.ToUpperInvariant() && msg.Length > 10 then
            score <- score - 0.10  // ALL CAPS penalty

        // Word count: prefer 5-15 words
        let wordCount = msg.Split([|' '|], StringSplitOptions.RemoveEmptyEntries).Length
        if wordCount >= 5 && wordCount <= 15 then score <- score + 0.15
        elif wordCount >= 3 then score <- score + 0.05

        Math.Clamp(score, 0.0, 1.0)

// ─────────────────────────────────────────────────────────────────────────────
// Heuristic Commit Message Suggestion
// ─────────────────────────────────────────────────────────────────────────────

/// Generate a heuristic-based commit message suggestion from a diff summary.
/// Used when OpenRouter API is unavailable (AOR-OPENROUTER-005).
let suggestHeuristic (filesChanged: string list) (linesAdded: int) (linesRemoved: int) : NeuralRecommendation =
    // Infer type from file patterns
    let inferredType =
        if filesChanged |> List.exists (fun f -> f.Contains("test") || f.Contains("Test")) then "test"
        elif filesChanged |> List.exists (fun f -> f.EndsWith(".md") || f.Contains("docs/") || f.Contains("journal/")) then "docs"
        elif linesRemoved > linesAdded * 2 then "refactor"
        elif filesChanged |> List.exists (fun f -> f.Contains("security") || f.Contains("auth")) then "security"
        else "feat"

    // Infer scope from file paths
    let inferredScope =
        let paths = filesChanged |> List.map (fun f -> f.ToLowerInvariant())
        if paths |> List.exists (fun p -> p.Contains("zenoh")) then "zenoh"
        elif paths |> List.exists (fun p -> p.Contains("sentinel")) then "sentinel"
        elif paths |> List.exists (fun p -> p.Contains("cepaf") || p.Contains("fsproj")) then "cepaf"
        elif paths |> List.exists (fun p -> p.Contains("mesh")) then "mesh"
        elif paths |> List.exists (fun p -> p.Contains("prajna")) then "prajna"
        elif paths |> List.exists (fun p -> p.Contains("test")) then "test"
        else "core"

    let message = $"{inferredType}({inferredScope}): update {filesChanged.Length} files — +{linesAdded}/-{linesRemoved} lines"

    { SuggestedMessage = message
      SemanticQuality = assessSemanticQuality message
      Confidence = 0.4  // Low confidence for heuristic
      Model = "heuristic"
      IsHeuristicFallback = true }

// ─────────────────────────────────────────────────────────────────────────────
// Intent Classification
// ─────────────────────────────────────────────────────────────────────────────

/// Classify commit intent and produce a recommendation.
/// Uses cache, then heuristics. API integration deferred to Program.fs wiring.
let classifyIntent (commit: ParsedCommit) : NeuralRecommendation =
    let key = cacheKey commit.Subject
    match cache.TryGetValue(key) with
    | true, cached -> cached
    | false, _ ->
        let quality = assessSemanticQuality commit.Subject

        let recommendation =
            if quality >= 0.7 then
                { SuggestedMessage = commit.Subject  // Already good
                  SemanticQuality = quality
                  Confidence = 0.8
                  Model = "heuristic"
                  IsHeuristicFallback = true }
            else
                // Attempt to improve: add em-dash if missing
                let improved =
                    match commit.CommitType, commit.RawScopes with
                    | Some ct, scopes when not scopes.IsEmpty ->
                        let scopeStr = scopes |> List.head
                        let action =
                            let colonIdx = commit.Subject.IndexOf(':')
                            if colonIdx >= 0 then commit.Subject.Substring(colonIdx + 1).TrimStart()
                            else commit.Subject
                        $"{CommitType.toTag ct}({scopeStr}): {action}"
                    | _ -> commit.Subject

                { SuggestedMessage = improved
                  SemanticQuality = assessSemanticQuality improved
                  Confidence = 0.5
                  Model = "heuristic"
                  IsHeuristicFallback = true }

        cache.[key] <- recommendation
        recommendation

/// Clear the in-memory recommendation cache.
let clearCache () = cache.Clear()

/// Format neural recommendation for display.
let formatRecommendation (rec': NeuralRecommendation) : string =
    let fallbackTag = if rec'.IsHeuristicFallback then " [heuristic]" else ""
    $"Quality: {rec'.SemanticQuality:F2}  Confidence: {rec'.Confidence:F2}  Model: {rec'.Model}{fallbackTag}\nSuggestion: {rec'.SuggestedMessage}"
