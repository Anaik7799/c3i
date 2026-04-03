// =============================================================================
// Git Intelligence — Parser
// =============================================================================
// Purpose:  Parse git log output, classify commits by ICP v2.0 compliance,
//           detect style, extract type/scope/context, run git commands.
//
// STAMP:    SC-CHG-001, SC-SYNC-DOC-009
// =============================================================================

module Cepaf.GitIntelligence.Parser

open System
open System.Diagnostics
open System.Text.RegularExpressions

// ─────────────────────────────────────────────────────────────────────────────
// Compiled Regex Patterns (performance-critical — compiled once)
// ─────────────────────────────────────────────────────────────────────────────

/// ICP v2.0 full format: type(scope): action — context
let private reIcpFull =
    Regex(@"^(feat|fix|refactor|perf|test|docs|chore|security|evolve)\(([a-z,]+)\):\s+(.+?)\s*\u2014\s*(.+)$",
          RegexOptions.Compiled)

/// Conventional without em-dash: type(scope): action
let private reConventional =
    Regex(@"^(feat|fix|refactor|perf|test|docs|chore|security|evolve)(!?)\(([a-z0-9_,.-]+)\):\s+(.+)$",
          RegexOptions.Compiled)

/// Conventional without scope: type: action
let private reConventionalNoScope =
    Regex(@"^(feat|fix|refactor|perf|test|docs|chore|security|evolve)(!?):\s+(.+)$",
          RegexOptions.Compiled)

/// EVOLUTION RUN pattern
let private reEvolutionRun =
    Regex(@"^EVOLUTION RUN \d+:", RegexOptions.Compiled ||| RegexOptions.IgnoreCase)

/// Hyperbolic patterns
let private reHyperbolic =
    Regex(@"^(SINGULARITY|TOTAL BIOMORPHIC|BIOMORPHIC SINGULARITY|GA RELEASE SINGULARITY)",
          RegexOptions.Compiled ||| RegexOptions.IgnoreCase)

/// Phase/SOP patterns
let private rePhaseSop =
    Regex(@"^(PHASE|SOP|SPRINT|PRAJNA-UNIFIED|BIOMORPHIC-DEPLOYMENT|MESH-CHECKPOINT)",
          RegexOptions.Compiled ||| RegexOptions.IgnoreCase)

/// Emoji prefix detection (BMP symbols + surrogate pairs for supplementary plane)
let private reEmoji =
    Regex(@"^[\u2600-\u27BF\u2B50\u26A1\u2705\u274C\u2728]|^\uD83C[\uDF00-\uDFFF]|^\uD83D[\uDC00-\uDEFF]|^\uD83E[\uDD00-\uDDFF]",
          RegexOptions.Compiled)

/// Em-dash (U+2014)
let private reEmDash =
    Regex(@"\s*\u2014\s*", RegexOptions.Compiled)

/// Stat line from --shortstat: "3 files changed, 10 insertions(+), 2 deletions(-)"
let private reStat =
    Regex(@"(\d+) files? changed(?:,\s+(\d+) insertions?\(\+\))?(?:,\s+(\d+) deletions?\(-\))?",
          RegexOptions.Compiled)

/// Past tense detection (simple heuristic: common past-tense endings)
let private rePastTense =
    Regex(@"^(added|removed|fixed|updated|changed|created|deleted|modified|implemented|refactored|moved)\b",
          RegexOptions.Compiled ||| RegexOptions.IgnoreCase)

/// Scope splitter (for multi-scope: "zenoh,cepaf")
let private scopeSplitter = Regex(@"[,\s]+", RegexOptions.Compiled)

// ─────────────────────────────────────────────────────────────────────────────
// Git Process Execution
// ─────────────────────────────────────────────────────────────────────────────

/// Run a git command and return stdout lines.
let runGit (workDir: string) (args: string) : Result<string[], string> =
    try
        let psi = ProcessStartInfo("git", args)
        psi.WorkingDirectory <- workDir
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        psi.UseShellExecute <- false
        psi.CreateNoWindow <- true
        // Force consistent output
        psi.EnvironmentVariables.["LC_ALL"] <- "C"
        psi.EnvironmentVariables.["GIT_PAGER"] <- ""

        use proc = Process.Start(psi)
        let stdout = proc.StandardOutput.ReadToEnd()
        let stderr = proc.StandardError.ReadToEnd()
        proc.WaitForExit(30_000) |> ignore

        if proc.ExitCode = 0 then
            Ok (stdout.Split('\n', StringSplitOptions.RemoveEmptyEntries))
        else
            Error (sprintf "git %s failed (exit %d): %s" args proc.ExitCode stderr)
    with ex ->
        Error (sprintf "git process error: %s" ex.Message)

/// Get the current branch name.
let currentBranch (workDir: string) : string =
    match runGit workDir "rev-parse --abbrev-ref HEAD" with
    | Ok lines when lines.Length > 0 -> lines.[0].Trim()
    | _ -> "unknown"

/// Get staged diff --shortstat for commit message context.
let stagedShortstat (workDir: string) : string =
    match runGit workDir "diff --cached --shortstat" with
    | Ok lines when lines.Length > 0 -> lines.[0].Trim()
    | _ -> ""

// ─────────────────────────────────────────────────────────────────────────────
// Style Classification
// ─────────────────────────────────────────────────────────────────────────────

/// Classify a commit subject into one of 7 historical styles.
let classifyStyle (subject: string) : CommitStyle =
    if reIcpFull.IsMatch(subject) then
        CommitStyle.IcpConventional
    elif reEvolutionRun.IsMatch(subject) then
        CommitStyle.EvolutionRun
    elif reHyperbolic.IsMatch(subject) then
        CommitStyle.Hyperbolic
    elif reEmoji.IsMatch(subject) then
        CommitStyle.Emoji
    elif rePhaseSop.IsMatch(subject) then
        CommitStyle.PhaseSop
    elif reConventional.IsMatch(subject) || reConventionalNoScope.IsMatch(subject) then
        // Has em-dash but didn't match IcpFull? Still conventional.
        if reEmDash.IsMatch(subject) then CommitStyle.IcpConventional
        else CommitStyle.ConventionalNoEmDash
    else
        CommitStyle.Other

// ─────────────────────────────────────────────────────────────────────────────
// Historical Scope Mapping (must precede parseIcpSubject for F# compilation order)
// ─────────────────────────────────────────────────────────────────────────────

/// Map historical scope strings to ICP 23-scope taxonomy.
/// Returns the closest ICP scope for drift correction.
let mapHistoricalScope (raw: string) : IcpScope option =
    match raw.ToLowerInvariant().Trim() with
    // Direct matches (already valid ICP scopes)
    | s when IcpScope.fromTag s <> None -> IcpScope.fromTag s

    // ── Cross-cutting → core ────────────────────────────────────────────────
    | s when s.StartsWith "sprint-" || s.StartsWith "sprint" -> Some IcpScope.Core
    | "config" | "devenv" | "nix" | "env" | "build" | "deps" -> Some IcpScope.Core
    | ".claude" | "rules" | "agents" | "cleanup" | "version" -> Some IcpScope.Core
    | "architecture" | "arch" | "system" | "shared" | "evolution" -> Some IcpScope.Core
    | "singularity" | "autonomic" | "autonomous" | "cosmic" | "holon" -> Some IcpScope.Core
    | "sop" | "ga" | "compiler" | "compilation" | "credo" | "research" -> Some IcpScope.Core
    | "journal" -> Some IcpScope.Core

    // ── App / Phoenix → app ─────────────────────────────────────────────────
    | "ash" | "ash3" | "phoenix" | "liveview" | "heex" -> Some IcpScope.App
    | "webui" | "video_controller" | "catalog" | "mobile-api" -> Some IcpScope.App

    // ── Database → db ───────────────────────────────────────────────────────
    | "database" | "migration" | "naming" -> Some IcpScope.Db

    // ── KMS → kms ───────────────────────────────────────────────────────────
    | "crypto" | "encryption" -> Some IcpScope.Kms

    // ── Mesh / Infrastructure → mesh ────────────────────────────────────────
    | "infrastructure" | "infra" | "container" | "podman" | "compose" -> Some IcpScope.Mesh
    | "sil4" | "sil6" | "sil" | "startup" | "runtime" | "ha" -> Some IcpScope.Mesh
    | "biomorphic" | "fractal" | "distributed" | "ucr" | "consensus" -> Some IcpScope.Mesh
    | "robustness" | "orchestration" -> Some IcpScope.Mesh

    // ── CEPAF / F# → cepaf ──────────────────────────────────────────────────
    | "fsharp" | "cafe" -> Some IcpScope.Cepaf

    // ── Zenoh → zenoh ───────────────────────────────────────────────────────
    | "nif" | "rustler" | "ffi" | "zenoh-ffi" -> Some IcpScope.Zenoh

    // ── Sentinel / Security → sentinel ──────────────────────────────────────
    | "sentinel-mcp" | "immune-system" | "security" | "safety" -> Some IcpScope.Sentinel

    // ── Immune → immune ─────────────────────────────────────────────────────
    | "capsid" | "nervous" | "immune-nervous" -> Some IcpScope.Immune

    // ── Smriti / Knowledge → smriti ─────────────────────────────────────────
    | "knowledge" | "zkms" | "ark" -> Some IcpScope.Smriti

    // ── Prajna / Cockpit → prajna ───────────────────────────────────────────
    | "cockpit" | "cockpit-f" | "cockpit-web" | "dark-ui" -> Some IcpScope.Prajna

    // ── Cortex / AI → cortex ────────────────────────────────────────────────
    | "openrouter" | "ai" | "cortex-ai" | "ml" | "intelligence" -> Some IcpScope.Cortex
    | "ooda" | "cae" | "ace" -> Some IcpScope.Cortex

    // ── Plan / Planning → plan ──────────────────────────────────────────────
    | "planning" | "chaya" | "todolist" | "workflow" -> Some IcpScope.Plan

    // ── Observability → obs ─────────────────────────────────────────────────
    | "otel" | "grafana" | "prometheus" | "loki" -> Some IcpScope.Obs
    | "reporting" -> Some IcpScope.Obs

    // ── VSM → vsm ───────────────────────────────────────────────────────────
    | "cybernetic" | "tricameral" | "governance" -> Some IcpScope.Vsm

    // ── Math → math ─────────────────────────────────────────────────────────
    | "graph" | "graphiti" | "fame" | "rs" -> Some IcpScope.Math

    // ── Federation → fed ────────────────────────────────────────────────────
    | "federation" | "cluster" | "jain" -> Some IcpScope.Fed

    // ── Formal → formal ─────────────────────────────────────────────────────
    | "formal-specs" | "formal-spec" | "quint" | "agda" | "specs" -> Some IcpScope.Formal
    | "formal-verification" | "graph-verification" | "verify" | "verification" -> Some IcpScope.Formal

    // ── Test → test ─────────────────────────────────────────────────────────
    | "testing" | "tests" | "test-infra" | "validation" | "coverage" | "demo" -> Some IcpScope.Test

    // ── Sync → sync ─────────────────────────────────────────────────────────
    | "constraint-sync" | "constraints" | "stamp" -> Some IcpScope.Sync

    // ── Phase-based (historical) → core ─────────────────────────────────────
    | s when s.StartsWith "phase" -> Some IcpScope.Core

    | _ -> None

// ─────────────────────────────────────────────────────────────────────────────
// ICP v2.0 Commit Parsing
// ─────────────────────────────────────────────────────────────────────────────

/// Extract type, scopes, action, context from a subject line.
let parseIcpSubject (subject: string) =
    // Try full ICP first: type(scope): action — context
    let m = reIcpFull.Match(subject)
    if m.Success then
        let typeStr = m.Groups.[1].Value
        let scopeStr = m.Groups.[2].Value
        let action = m.Groups.[3].Value.Trim()
        let context = m.Groups.[4].Value.Trim()
        let commitType = CommitType.fromTag typeStr
        let rawScopes = scopeSplitter.Split(scopeStr) |> Array.toList
        let parsedScopes = rawScopes |> List.choose (fun s ->
            match IcpScope.fromTag s with
            | Some _ as v -> v
            | None -> mapHistoricalScope s)
        Some (commitType, parsedScopes, rawScopes, action, Some context, true)
    else
        // Try conventional with scope: type(scope): action
        let m2 = reConventional.Match(subject)
        if m2.Success then
            let typeStr = m2.Groups.[1].Value
            let scopeStr = m2.Groups.[3].Value
            let action = m2.Groups.[4].Value.Trim()
            let commitType = CommitType.fromTag typeStr
            let rawScopes = scopeSplitter.Split(scopeStr) |> Array.toList
            let parsedScopes = rawScopes |> List.choose (fun s ->
                match IcpScope.fromTag s with
                | Some _ as v -> v
                | None -> mapHistoricalScope s)
            // Check for em-dash in the action part
            let hasEmDash = reEmDash.IsMatch(action)
            let context = if hasEmDash then
                              let parts = reEmDash.Split(action, 2)
                              if parts.Length > 1 then Some (parts.[1].Trim()) else None
                          else None
            Some (commitType, parsedScopes, rawScopes, action, context, hasEmDash)
        else
            // Try scopeless: type: action
            let m3 = reConventionalNoScope.Match(subject)
            if m3.Success then
                let typeStr = m3.Groups.[1].Value
                let action = m3.Groups.[3].Value.Trim()
                let commitType = CommitType.fromTag typeStr
                let hasEmDash = reEmDash.IsMatch(action)
                let context = if hasEmDash then
                                  let parts = reEmDash.Split(action, 2)
                                  if parts.Length > 1 then Some (parts.[1].Trim()) else None
                              else None
                Some (commitType, [], [], action, context, hasEmDash)
            else
                None

// ─────────────────────────────────────────────────────────────────────────────
// Git Log Parsing
// ─────────────────────────────────────────────────────────────────────────────

/// Record separator for git log format (bell character, unlikely in commits)
let private separator = "\x07"

/// Parse git log into structured commits.
/// Uses --format with record separator for reliable multi-line parsing.
let parseGitLog (workDir: string) (since: string) (until: string option) : Result<ParsedCommit[], string> =
    let untilArg = match until with Some u -> sprintf " --until=\"%s\"" u | None -> ""
    let format = sprintf "%%H%s%%h%s%%an%s%%aI%s%%s%s%%b%s" separator separator separator separator separator separator
    let args = sprintf "log --format=\"%s\" --shortstat --since=\"%s\"%s" format since untilArg

    match runGit workDir args with
    | Error e -> Error e
    | Ok rawLines ->
        // Join all lines back into one string and split by the format boundary
        let fullOutput = String.Join("\n", rawLines)
        // Each commit produces: hash\x07shorthash\x07author\x07date\x07subject\x07body\x07\n[shortstat]\n
        // We need to parse this carefully since body can contain newlines

        let commits = System.Collections.Generic.List<ParsedCommit>()
        let mutable i = 0
        let lines = fullOutput.Split('\n')

        while i < lines.Length do
            let line = lines.[i]
            if line.Contains(separator) then
                let parts = line.Split(separator.[0])
                if parts.Length >= 6 then
                    let hash = parts.[0].Trim('"')
                    let shortHash = parts.[1]
                    let author = parts.[2]
                    let dateStr = parts.[3]
                    let subject = parts.[4]
                    let bodyStart = parts.[5]

                    // Collect body lines until we hit a stat line or next commit
                    let bodyLines = System.Collections.Generic.List<string>()
                    if not (String.IsNullOrWhiteSpace bodyStart) then
                        bodyLines.Add(bodyStart)
                    let mutable j = i + 1
                    let mutable filesChanged = 0
                    let mutable insertions = 0
                    let mutable deletions = 0

                    while j < lines.Length && not (lines.[j].Contains(separator)) do
                        let statMatch = reStat.Match(lines.[j])
                        if statMatch.Success then
                            filesChanged <- Int32.Parse(statMatch.Groups.[1].Value)
                            if statMatch.Groups.[2].Success then
                                insertions <- Int32.Parse(statMatch.Groups.[2].Value)
                            if statMatch.Groups.[3].Success then
                                deletions <- Int32.Parse(statMatch.Groups.[3].Value)
                        elif not (String.IsNullOrWhiteSpace lines.[j]) then
                            bodyLines.Add(lines.[j])
                        j <- j + 1

                    let date =
                        match DateTimeOffset.TryParse(dateStr) with
                        | true, d -> d
                        | _ -> DateTimeOffset.MinValue

                    let style = classifyStyle subject

                    let (commitType, parsedScopes, rawScopes, hasEmDash, context) =
                        match parseIcpSubject subject with
                        | Some (ct, ps, rs, _, ctx, em) -> (ct, ps, rs, em, ctx)
                        | None -> (None, [], [], false, None)

                    commits.Add({
                        Hash = hash
                        ShortHash = shortHash
                        Author = author
                        Date = date
                        Subject = subject
                        Body = String.Join("\n", bodyLines)
                        FilesChanged = filesChanged
                        Insertions = insertions
                        Deletions = deletions
                        Style = style
                        CommitType = commitType
                        Scopes = parsedScopes
                        RawScopes = rawScopes
                        HasEmDash = hasEmDash
                        SubjectLength = subject.Length
                        ContextAfterEmDash = context
                    })

                    i <- j
                else
                    i <- i + 1
            else
                i <- i + 1

        Ok (commits.ToArray())

// ─────────────────────────────────────────────────────────────────────────────
// Validation
// ─────────────────────────────────────────────────────────────────────────────

/// Validate a commit message against ICP v2.0 rules.
let validate (message: string) : ValidationResult =
    let lines = message.Split('\n')
    let subject = if lines.Length > 0 then lines.[0] else ""
    let issues = System.Collections.Generic.List<ValidationIssue>()

    // Check for emoji prefix
    if reEmoji.IsMatch(subject) then
        issues.Add(ValidationIssue.EmojiPrefix)

    // Check for EVOLUTION RUN
    if reEvolutionRun.IsMatch(subject) then
        issues.Add(ValidationIssue.EvolutionRunFormat)

    // Check for hyperbolic
    if reHyperbolic.IsMatch(subject) then
        issues.Add(ValidationIssue.HyperbolicFormat)

    // Check length
    if subject.Length > 80 then
        issues.Add(ValidationIssue.SubjectTooLong subject.Length)

    // Try to parse ICP format
    let (parsedType, parsedScopes, hasEmDash) =
        match parseIcpSubject subject with
        | Some (ct, ps, rs, action, _, em) ->
            // Check past tense
            if rePastTense.IsMatch(action) then
                let word = rePastTense.Match(action).Groups.[1].Value
                issues.Add(ValidationIssue.PastTense word)

            match ct with
            | None ->
                let typeMatch = reConventional.Match(subject)
                if typeMatch.Success then
                    issues.Add(ValidationIssue.InvalidType typeMatch.Groups.[1].Value)
                else
                    issues.Add(ValidationIssue.MissingType)
            | _ -> ()

            // Check invalid scopes
            for raw in rs do
                if IcpScope.fromTag raw = None && raw <> "" then
                    issues.Add(ValidationIssue.InvalidScope raw)

            if rs.IsEmpty && ps.IsEmpty then
                // Scopeless is allowed for cross-cutting, not an issue
                ()

            (ct, ps, em)
        | None ->
            // Not ICP format at all
            issues.Add(ValidationIssue.MissingType)
            (None, [], false)

    // Check for Co-Authored-By in body (for AI-assisted commits)
    let hasCoAuthor = lines |> Array.exists (fun l -> l.StartsWith("Co-Authored-By:"))

    {
        IsValid = issues.Count = 0
        Issues = issues |> Seq.toList
        ParsedType = parsedType
        ParsedScopes = parsedScopes
        Subject = subject
        HasEmDash = hasEmDash
    }

// ─────────────────────────────────────────────────────────────────────────────
// Commit Message Generation
// ─────────────────────────────────────────────────────────────────────────────

/// Generate an ICP v2.0 commit message from structured input.
let generateMessage (input: CommitInput) : string =
    let typeTag = CommitType.toTag input.Type
    let scopeTag =
        match input.Scopes with
        | [] -> ""
        | scopes ->
            let tags = scopes |> List.map IcpScope.toTag |> String.concat ","
            sprintf "(%s)" tags

    let subject =
        match input.Context with
        | Some ctx ->
            sprintf "%s%s: %s \u2014 %s" typeTag scopeTag input.Action ctx
        | None ->
            sprintf "%s%s: %s" typeTag scopeTag input.Action

    // Truncate subject to 80 chars if needed
    let subject =
        if subject.Length > 80 then subject.Substring(0, 77) + "..."
        else subject

    let body = System.Text.StringBuilder()

    // WHY/WHAT for L2+ changes
    match input.Why with
    | Some why -> body.AppendLine(sprintf "\nWHY: %s" why) |> ignore
    | None -> ()
    match input.What with
    | Some what -> body.AppendLine(sprintf "WHAT: %s" what) |> ignore
    | None -> ()

    // File stats
    if input.FilesCreated > 0 || input.FilesModified > 0 then
        let parts = [
            if input.FilesCreated > 0 then yield sprintf "%d created" input.FilesCreated
            if input.FilesModified > 0 then yield sprintf "%d modified" input.FilesModified
        ]
        body.AppendLine(sprintf "Files: %s" (String.Join(", ", parts))) |> ignore

    // Layer info
    if not input.Layers.IsEmpty then
        let layerStr = input.Layers |> List.map (fun (l, n) -> sprintf "%s(%d)" l n) |> String.concat ", "
        body.AppendLine(sprintf "Layer: %s" layerStr) |> ignore

    // STAMP refs
    if not input.StampRefs.IsEmpty then
        body.AppendLine(sprintf "STAMP: %s" (String.Join(", ", input.StampRefs))) |> ignore

    // Task ref
    match input.TaskRef with
    | Some t -> body.AppendLine(sprintf "Task: %s" t) |> ignore
    | None -> ()

    // Co-Authored-By
    body.AppendLine("\nCo-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>") |> ignore

    let bodyStr = body.ToString().TrimEnd()
    if String.IsNullOrWhiteSpace bodyStr || bodyStr = "\nCo-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>" then
        sprintf "%s\n\nCo-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>" subject
    else
        sprintf "%s\n%s" subject bodyStr
