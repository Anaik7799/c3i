// =============================================================================
// Git Intelligence — CLI Entry Point
// =============================================================================
// Purpose:  Standalone CLI for ICP v2.0 commit analysis, validation, generation,
//           commit execution, and AI-assisted suggestions.
//           Designed for agentic integration: JSON output, exit codes, piping.
//           Publishes git events to Zenoh mesh (SC-ZTEST-008 dual-write).
//
// Usage:    git-intelligence analyze [--since 1y] [--json]
//           git-intelligence validate "type(scope): action — context"
//           git-intelligence generate --type feat --scope mesh --action "add X"
//           git-intelligence commit --type feat --scope mesh --action "add X"
//           git-intelligence suggest
//           git-intelligence health
//           git-intelligence classify "commit subject here"
//           git-intelligence guardrails
//
// STAMP:    SC-CHG-001, SC-CHG-002, SC-SYNC-DOC-009, SC-ZENOH-001, SC-ZTEST-008
// AOR:      AOR-CHG-001 to AOR-CHG-010, AOR-FFI-006
// =============================================================================

module Cepaf.GitIntelligence.Program

open System
open System.IO
open System.Net.Http
open System.Text

// ─────────────────────────────────────────────────────────────────────────────
// Project Root Detection
// ─────────────────────────────────────────────────────────────────────────────

/// Walk up from current directory to find git root (contains .git/).
let private findProjectRoot () : string =
    let mutable dir = Directory.GetCurrentDirectory()
    while dir <> Path.GetPathRoot(dir) && not (Directory.Exists(Path.Combine(dir, ".git"))) do
        dir <- Directory.GetParent(dir).FullName
    if Directory.Exists(Path.Combine(dir, ".git")) then dir
    else Directory.GetCurrentDirectory()

// ─────────────────────────────────────────────────────────────────────────────
// CLI Helpers
// ─────────────────────────────────────────────────────────────────────────────

let private printUsage () =
    let bold = "\x1b[1m"
    let reset = "\x1b[0m"
    let dim = "\x1b[2m"
    printfn ""
    printfn "%sGit Intelligence — ICP v2.0 Analysis & Enforcement%s" bold reset
    printfn ""
    printfn "%sUSAGE:%s" bold reset
    printfn "  git-intelligence <command> [options]"
    printfn ""
    printfn "%sCOMMANDS:%s" bold reset
    printfn "  analyze       Analyze git history (default: 1 year)"
    printfn "  health        Show Git Health Score dashboard %s(alias: analyze)%s" dim reset
    printfn "  validate      Validate a commit message against ICP v2.0"
    printfn "  classify      Classify a commit subject line by style"
    printfn "  generate      Generate an ICP v2.0 commit message"
    printfn "  commit        Generate, validate, commit & notify Zenoh mesh"
    printfn "  suggest       AI-suggest an ICP commit message from staged diff"
    printfn "  guardrails    Show agentic development guardrails & workflows"
    printfn ""
    printfn "%sADVANCED COMMANDS:%s" bold reset
    printfn "  store-init    Initialize SQLite/DuckDB holon state stores"
    printfn "  trend         Show GHS trend analysis (EMA, regression, velocity)"
    printfn "  homeostasis   Run homeostatic quality assessment (PID controller)"
    printfn "  constitutional Verify constitutional invariants (Ψ₀-Ψ₅)"
    printfn "  federation    Manage cross-holon federation peers"
    printfn "  multiverse    Manage shadow universe branches (fork/verify/promote)"
    printfn "  biomorphic    Run full biomorphic assessment (all 5 subsystems)"
    printfn "  mcp-list      List available MCP tool definitions"
    printfn "  mcp-serve     Start MCP stdio server for agentic tool access"
    printfn ""
    printfn "%sOPTIONS:%s" bold reset
    printfn "  --since <N>   Time range: 1y, 6m, 3m, 1m  %s(default: 1y)%s" dim reset
    printfn "  --json        Output as JSON (for agentic consumption)"
    printfn "  --files <f>   Comma-separated files to stage %s(commit only)%s" dim reset
    printfn "  --all         Stage all changes %s(commit only)%s" dim reset
    printfn "  --bio         Activate biomorphic assessment after analysis"
    printfn "  --guardian    Enable constitutional checks on commit"
    printfn "  --holon-path  Set holon data directory %s(default: data/holons/git-intel/)%s" dim reset
    printfn "  --help        Show this help"
    printfn ""
    printfn "%sEXAMPLES:%s" bold reset
    printfn "  git-intelligence analyze --since 6m"
    printfn "  git-intelligence analyze --json --bio"
    printfn "  git-intelligence validate \"feat(mesh): add 2oo3 voting — SC-SIL6-006\""
    printfn "  git-intelligence classify \"EVOLUTION RUN 2: Biomorphic Sync\""
    printfn "  git-intelligence generate --type feat --scope mesh --action \"add consensus\""
    printfn "  git-intelligence commit --type feat --scope mesh --action \"add consensus\" --files a.fs,b.fs"
    printfn "  git-intelligence suggest"
    printfn "  git-intelligence biomorphic --json"
    printfn "  git-intelligence multiverse list"
    printfn "  git-intelligence federation --json"
    printfn ""

/// Parse --since value into a git-compatible date string.
let private parseSince (value: string) : string =
    match value.ToLowerInvariant().Trim() with
    | "1y" | "12m" -> "1 year ago"
    | "6m" -> "6 months ago"
    | "3m" -> "3 months ago"
    | "1m" -> "1 month ago"
    | "2w" -> "2 weeks ago"
    | "1w" -> "1 week ago"
    | other -> other  // pass through as-is (e.g. "2025-03-22")

/// Find a flag value in argv: --flag value
let private findArg (flag: string) (args: string[]) : string option =
    args
    |> Array.tryFindIndex (fun a -> a = flag)
    |> Option.bind (fun i -> if i + 1 < args.Length then Some args.[i + 1] else None)

/// Check if a flag is present in argv.
let private hasFlag (flag: string) (args: string[]) : bool =
    args |> Array.exists (fun a -> a = flag)

// ─────────────────────────────────────────────────────────────────────────────
// Command: analyze / health
// ─────────────────────────────────────────────────────────────────────────────

let private cmdAnalyze (root: string) (args: string[]) : int =
    let since = findArg "--since" args |> Option.defaultValue "1y" |> parseSince
    let jsonMode = hasFlag "--json" args

    match Parser.parseGitLog root since None with
    | Error e ->
        eprintfn "ERROR: %s" e
        1
    | Ok commits ->
        let analysis = Analysis.analyze commits

        if jsonMode then
            printfn "%s" (Analysis.analysisToJson analysis)
        else
            Analysis.printDashboard analysis

        Notify.publishAnalyzeEvent analysis.HealthScore.Score commits.Length analysis.HealthScore.TypeEntropy analysis.HealthScore.MeanSemanticDensity |> ignore
        Notify.publishHealthEvent analysis.HealthScore.Score analysis.HealthScore.IcpAdoption analysis.HealthScore.ScopeCompliance commits.Length |> ignore

        // Exit code based on health score
        if analysis.HealthScore.Score >= 0.50 then 0 else 1

// ─────────────────────────────────────────────────────────────────────────────
// Command: validate
// ─────────────────────────────────────────────────────────────────────────────

let private cmdValidate (args: string[]) : int =
    // Find the commit message (first non-flag argument after "validate")
    let message =
        args
        |> Array.skipWhile (fun a -> a = "validate")
        |> Array.tryFind (fun a -> not (a.StartsWith("--")))

    match message with
    | None ->
        eprintfn "ERROR: No commit message provided."
        eprintfn "Usage: git-intelligence validate \"type(scope): action — context\""
        1
    | Some msg ->
        let result = Parser.validate msg
        let jsonMode = hasFlag "--json" args

        if jsonMode then
            let sb = System.Text.StringBuilder()
            sb.AppendLine("{") |> ignore
            sb.AppendLine(sprintf "  \"valid\": %s," (if result.IsValid then "true" else "false")) |> ignore
            sb.AppendLine(sprintf "  \"subject\": \"%s\"," (result.Subject.Replace("\"", "\\\""))) |> ignore
            sb.AppendLine(sprintf "  \"hasEmDash\": %s," (if result.HasEmDash then "true" else "false")) |> ignore

            match result.ParsedType with
            | Some t -> sb.AppendLine(sprintf "  \"type\": \"%s\"," (CommitType.toTag t)) |> ignore
            | None -> sb.AppendLine("  \"type\": null,") |> ignore

            let scopes = result.ParsedScopes |> List.map (fun s -> sprintf "\"%s\"" (IcpScope.toTag s))
            sb.AppendLine(sprintf "  \"scopes\": [%s]," (String.Join(", ", scopes))) |> ignore

            let issues =
                result.Issues |> List.map (fun issue ->
                    match issue with
                    | ValidationIssue.MissingType -> "\"missing-type\""
                    | ValidationIssue.InvalidType t -> sprintf "\"invalid-type:%s\"" t
                    | ValidationIssue.MissingScope -> "\"missing-scope\""
                    | ValidationIssue.InvalidScope s -> sprintf "\"invalid-scope:%s\"" s
                    | ValidationIssue.SubjectTooLong n -> sprintf "\"subject-too-long:%d\"" n
                    | ValidationIssue.PastTense w -> sprintf "\"past-tense:%s\"" w
                    | ValidationIssue.EmojiPrefix -> "\"emoji-prefix\""
                    | ValidationIssue.EvolutionRunFormat -> "\"evolution-run-format\""
                    | ValidationIssue.HyperbolicFormat -> "\"hyperbolic-format\""
                    | ValidationIssue.MissingCoAuthor -> "\"missing-co-author\""
                    | ValidationIssue.NoImperativeMood -> "\"no-imperative-mood\"")
            sb.AppendLine(sprintf "  \"issues\": [%s]" (String.Join(", ", issues))) |> ignore
            sb.AppendLine("}") |> ignore
            printfn "%s" (sb.ToString())
        else
            if result.IsValid then
                let green = "\x1b[32m"
                let reset = "\x1b[0m"
                printfn "%s✓ VALID%s — ICP v2.0 compliant" green reset
                match result.ParsedType with
                | Some t -> printfn "  Type:  %s" (CommitType.toTag t)
                | None -> ()
                if not result.ParsedScopes.IsEmpty then
                    printfn "  Scope: %s" (result.ParsedScopes |> List.map IcpScope.toTag |> String.concat ", ")
                if result.HasEmDash then
                    printfn "  Em-dash context: yes"
            else
                let red = "\x1b[31m"
                let reset = "\x1b[0m"
                printfn "%s✗ INVALID%s — %d issue(s):" red reset result.Issues.Length
                for issue in result.Issues do
                    match issue with
                    | ValidationIssue.MissingType -> printfn "  • Missing type (expected: feat|fix|refactor|...)"
                    | ValidationIssue.InvalidType t -> printfn "  • Invalid type: '%s'" t
                    | ValidationIssue.MissingScope -> printfn "  • Missing scope (expected: one of 23 ICP scopes)"
                    | ValidationIssue.InvalidScope s ->
                        let suggestion = Parser.mapHistoricalScope s
                        match suggestion with
                        | Some mapped -> printfn "  • Invalid scope: '%s' → did you mean '%s'?" s (IcpScope.toTag mapped)
                        | None -> printfn "  • Invalid scope: '%s' (not in 23-scope taxonomy)" s
                    | ValidationIssue.SubjectTooLong n -> printfn "  • Subject too long: %d chars (max 80)" n
                    | ValidationIssue.PastTense w -> printfn "  • Past tense '%s' — use imperative mood" w
                    | ValidationIssue.EmojiPrefix -> printfn "  • Emoji prefix — use type(scope) instead"
                    | ValidationIssue.EvolutionRunFormat -> printfn "  • EVOLUTION RUN format — use evolve(scope): ..."
                    | ValidationIssue.HyperbolicFormat -> printfn "  • Hyperbolic format — use type(scope): ..."
                    | ValidationIssue.MissingCoAuthor -> printfn "  • Missing Co-Authored-By trailer"
                    | ValidationIssue.NoImperativeMood -> printfn "  • Use imperative mood (add, not added)"

        let issueStrings = result.Issues |> List.map (fun i -> sprintf "%A" i)
        Notify.publishValidateEvent result.Subject result.IsValid issueStrings |> ignore

        if result.IsValid then 0 else 1

// ─────────────────────────────────────────────────────────────────────────────
// Command: classify
// ─────────────────────────────────────────────────────────────────────────────

let private cmdClassify (args: string[]) : int =
    let subject =
        args
        |> Array.skipWhile (fun a -> a = "classify")
        |> Array.tryFind (fun a -> not (a.StartsWith("--")))

    match subject with
    | None ->
        eprintfn "ERROR: No commit subject provided."
        eprintfn "Usage: git-intelligence classify \"EVOLUTION RUN 2: ...\""
        1
    | Some subj ->
        let style = Parser.classifyStyle subj
        let jsonMode = hasFlag "--json" args

        if jsonMode then
            printfn "{ \"subject\": \"%s\", \"style\": \"%s\", \"density\": %.3f }"
                (subj.Replace("\"", "\\\""))
                (CommitStyle.label style)
                (CommitStyle.semanticDensity style)
        else
            printfn "Style:    %s" (CommitStyle.label style)
            printfn "Density:  %.3f bits/char" (CommitStyle.semanticDensity style)

            // Show what it would look like in ICP v2.0
            match Parser.parseIcpSubject subj with
            | Some (ct, scopes, _, action, ctx, em) ->
                printfn "Parsed:"
                match ct with
                | Some t -> printfn "  Type:    %s" (CommitType.toTag t)
                | None -> ()
                if not scopes.IsEmpty then
                    printfn "  Scope:   %s" (scopes |> List.map IcpScope.toTag |> String.concat ", ")
                printfn "  Action:  %s" action
                match ctx with Some c -> printfn "  Context: %s" c | None -> ()
                printfn "  Em-dash: %b" em
            | None ->
                printfn "  (Not ICP format — cannot parse type/scope/action)"
        
        Notify.publishClassifyEvent subj (CommitStyle.label style) (CommitStyle.semanticDensity style) |> ignore
        0

// ─────────────────────────────────────────────────────────────────────────────
// Command: generate
// ─────────────────────────────────────────────────────────────────────────────

let private cmdGenerate (args: string[]) : int =
    let typeStr = findArg "--type" args
    let scopeStr = findArg "--scope" args
    let action = findArg "--action" args
    let context = findArg "--context" args
    let why = findArg "--why" args
    let what = findArg "--what" args
    let stamp = findArg "--stamp" args
    let taskRef = findArg "--task" args

    match typeStr, action with
    | None, _ ->
        eprintfn "ERROR: --type is required (feat|fix|refactor|perf|test|docs|chore|security|evolve)"
        1
    | _, None ->
        eprintfn "ERROR: --action is required"
        1
    | Some t, Some act ->
        match CommitType.fromTag t with
        | None ->
            eprintfn "ERROR: Invalid type '%s' — must be one of: feat fix refactor perf test docs chore security evolve" t
            1
        | Some commitType ->
            let scopes =
                match scopeStr with
                | None -> []
                | Some s -> s.Split(',') |> Array.toList |> List.choose IcpScope.fromTag

            let stampRefs =
                match stamp with
                | None -> []
                | Some s -> s.Split(',') |> Array.toList |> List.map (fun x -> x.Trim())

            let input = {
                Type = commitType
                Scopes = scopes
                Action = act
                Context = context
                Why = why
                What = what
                FilesCreated = 0
                FilesModified = 0
                Layers = []
                StampRefs = stampRefs
                TaskRef = taskRef
            }

            let message = Parser.generateMessage input
            printfn "%s" message
            Notify.publishGenerateEvent message (CommitType.toTag commitType) (scopes |> List.map IcpScope.toTag) |> ignore
            0

// ─────────────────────────────────────────────────────────────────────────────
// Git Shell Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Run a git command and return (exitCode, stdout, stderr).
let private runGit (root: string) (gitArgs: string) : int * string * string =
    let psi = System.Diagnostics.ProcessStartInfo("git", gitArgs)
    psi.WorkingDirectory <- root
    psi.RedirectStandardOutput <- true
    psi.RedirectStandardError <- true
    psi.UseShellExecute <- false
    psi.CreateNoWindow <- true
    let p = System.Diagnostics.Process.Start(psi)
    let stdout = p.StandardOutput.ReadToEnd()
    let stderr = p.StandardError.ReadToEnd()
    p.WaitForExit()
    (p.ExitCode, stdout.Trim(), stderr.Trim())

// ─────────────────────────────────────────────────────────────────────────────
// Command: commit  (generate → validate → git add → git commit → Zenoh notify)
// ─────────────────────────────────────────────────────────────────────────────

let private cmdCommit (root: string) (args: string[]) : int =
    // Parse all the same flags as generate, plus --files/--all/--co-author
    let typeStr = findArg "--type" args
    let scopeStr = findArg "--scope" args
    let action = findArg "--action" args
    let context = findArg "--context" args
    let why = findArg "--why" args
    let what = findArg "--what" args
    let stamp = findArg "--stamp" args
    let taskRef = findArg "--task" args
    let coAuthor = findArg "--co-author" args
    let files = findArg "--files" args
    let stageAll = hasFlag "--all" args
    let dryRun = hasFlag "--dry-run" args

    // Validate required inputs
    match typeStr, action with
    | None, _ ->
        eprintfn "ERROR: --type is required (feat|fix|refactor|perf|test|docs|chore|security|evolve)"
        1
    | _, None ->
        eprintfn "ERROR: --action is required"
        1
    | Some t, Some act ->
        match CommitType.fromTag t with
        | None ->
            eprintfn "ERROR: Invalid type '%s'" t
            1
        | Some commitType ->
            let scopes =
                match scopeStr with
                | None -> []
                | Some s -> s.Split(',') |> Array.toList |> List.choose IcpScope.fromTag

            let stampRefs =
                match stamp with
                | None -> []
                | Some s -> s.Split(',') |> Array.toList |> List.map (fun x -> x.Trim())

            // Step 1: Generate the commit message
            let input = {
                Type = commitType
                Scopes = scopes
                Action = act
                Context = context
                Why = why
                What = what
                FilesCreated = 0
                FilesModified = 0
                Layers = []
                StampRefs = stampRefs
                TaskRef = taskRef
            }

            let mutable message = Parser.generateMessage input

            // Append Co-Authored-By if provided
            match coAuthor with
            | Some author ->
                message <- message + "\n\nCo-Authored-By: " + author
            | None -> ()

            // Step 2: Validate the subject line
            let subject = message.Split('\n').[0]
            let validationResult = Parser.validate subject
            if not validationResult.IsValid then
                eprintfn "ERROR: Generated message failed validation:"
                for issue in validationResult.Issues do
                    match issue with
                    | ValidationIssue.SubjectTooLong n -> eprintfn "  • Subject too long: %d chars" n
                    | _ -> eprintfn "  • %A" issue
                1
            else if dryRun then
                printfn "%s" message
                printfn ""
                printfn "[dry-run] Would commit with the above message."
                0
            else
                // Step 3: Stage files
                let stageResult =
                    if stageAll then
                        let (ec, _, se) = runGit root "add -A"
                        if ec <> 0 then eprintfn "ERROR: git add -A failed: %s" se
                        ec
                    else
                        match files with
                        | Some f ->
                            let fileList = f.Split(',') |> Array.map (fun x -> x.Trim())
                            let mutable exitCode = 0
                            for file in fileList do
                                if exitCode = 0 then
                                    let (ec, _, se) = runGit root (sprintf "add \"%s\"" file)
                                    if ec <> 0 then
                                        eprintfn "ERROR: git add '%s' failed: %s" file se
                                        exitCode <- ec
                            exitCode
                        | None ->
                            eprintfn "ERROR: Specify --files <file1,file2> or --all to stage changes."
                            1

                if stageResult <> 0 then stageResult
                else
                    // Step 4: Count staged files
                    let (_, diffOut, _) = runGit root "diff --cached --numstat"
                    let filesChanged =
                        if String.IsNullOrWhiteSpace(diffOut) then 0
                        else diffOut.Split('\n').Length

                    // Step 5: Git commit
                    // Write message to temp file to avoid shell escaping issues
                    let msgFile = Path.Combine(Path.GetTempPath(), "git-intel-commit-msg.txt")
                    File.WriteAllText(msgFile, message)
                    let (commitEc, commitOut, commitErr) = runGit root (sprintf "commit --file=\"%s\"" msgFile)
                    try File.Delete(msgFile) with _ -> ()

                    if commitEc <> 0 then
                        eprintfn "ERROR: git commit failed: %s" commitErr
                        commitEc
                    else
                        // Step 6: Get the SHA of the new commit
                        let (_, sha, _) = runGit root "rev-parse --short HEAD"

                        // Step 7: Compute GHS
                        let ghs =
                            match Parser.parseGitLog root "1 month ago" None with
                            | Ok commits ->
                                let a = Analysis.analyze commits
                                Some a.HealthScore.Score
                            | Error _ -> None

                        // Step 8: Publish to Zenoh mesh (dual-write: log + Zenoh)
                        let scopeTags = scopes |> List.map IcpScope.toTag
                        let _published = Notify.publishCommitEvent sha subject (CommitType.toTag commitType) scopeTags ghs filesChanged

                        // Step 9: Output result
                        let green = "\x1b[32m"
                        let reset = "\x1b[0m"
                        printfn "%s✓ COMMITTED%s %s" green reset sha
                        printfn "  %s" subject
                        printfn "  Files: %d  GHS: %s" filesChanged
                            (match ghs with Some g -> sprintf "%.4f" g | None -> "n/a")
                        0

// ─────────────────────────────────────────────────────────────────────────────
// Command: suggest  (AI-assisted commit message from staged diff)
// ─────────────────────────────────────────────────────────────────────────────

let private cmdSuggest (root: string) (args: string[]) : int =
    let jsonMode = hasFlag "--json" args

    // Step 1: Get the staged diff summary
    let (diffEc, diffStat, _) = runGit root "diff --cached --stat"
    if diffEc <> 0 || String.IsNullOrWhiteSpace(diffStat) then
        eprintfn "ERROR: No staged changes. Run 'git add' first."
        1
    else
        // Get a compact diff for the AI prompt (limited to avoid huge payloads)
        let (_, diffContent, _) = runGit root "diff --cached -U2"
        let truncatedDiff =
            if diffContent.Length > 4000 then diffContent.Substring(0, 4000) + "\n... (truncated)"
            else diffContent

        // Step 2: Try OpenRouter API (free model, graceful fallback)
        let apiKey = Environment.GetEnvironmentVariable("OPENROUTER_API_KEY")
        if String.IsNullOrEmpty(apiKey) then
            // Fallback: rule-based suggestion from diff stat
            eprintfn "[suggest] OPENROUTER_API_KEY not set — using rule-based suggestion."
            let lines = diffStat.Split('\n')
            let fileCount = lines.Length - 1 // last line is summary
            let suggestion = sprintf "chore(core): update %d files" fileCount
            if jsonMode then
                printfn """{"suggestion":"%s","source":"rule-based","model":null}""" suggestion
            else
                printfn "Suggestion: %s" suggestion
                printfn "  (Set OPENROUTER_API_KEY for AI-powered suggestions)"
            let _published = Notify.publishSuggestEvent truncatedDiff suggestion "rule-based"
            0
        else
            // Build the OpenRouter request
            let prompt = "You are a git commit message generator for the Indrajaal project.\nFormat: type(scope): action — context\nTypes: feat fix refactor perf test docs chore security evolve\nScopes: guardian app db kms mesh cepaf zenoh sentinel immune smriti prajna cortex plan obs vsm math swarm fed formal test ci sync core\nMax 80 chars. Imperative mood. Em-dash before context.\n\nDiff:\n" + truncatedDiff + "\n\nGenerate ONE commit message line. No explanation, just the message."

            let escapeJsonStr (s: string) =
                s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\n", "\\n").Replace("\r", "\\r").Replace("\t", "\\t")

            let requestBody = $"""{{"model":"meta-llama/llama-3.1-8b-instruct:free","messages":[{{"role":"user","content":"{escapeJsonStr prompt}"}}],"max_tokens":100,"temperature":0.3}}"""

            try
                use client = new HttpClient()
                client.Timeout <- TimeSpan.FromSeconds(15.0)
                client.DefaultRequestHeaders.Add("Authorization", sprintf "Bearer %s" apiKey)
                let content = new StringContent(requestBody, Encoding.UTF8, "application/json")
                let response = client.PostAsync("https://openrouter.ai/api/v1/chat/completions", content).Result

                if response.IsSuccessStatusCode then
                    let body = response.Content.ReadAsStringAsync().Result
                    // Simple JSON extraction — find "content":"..." in the response
                    let contentMarker = "\"content\":\""
                    let idx = body.IndexOf(contentMarker)
                    if idx >= 0 then
                        let start = idx + contentMarker.Length
                        let endIdx = body.IndexOf("\"", start)
                        let suggestion =
                            if endIdx > start then body.Substring(start, endIdx - start)
                            else "chore(core): update staged changes"
                        let suggestion = suggestion.Replace("\\n", "").Replace("\\r", "").Trim()

                        if jsonMode then
                            printfn """{"suggestion":"%s","source":"openrouter","model":"llama-3.1-8b-instruct:free"}"""
                                (escapeJsonStr suggestion)
                        else
                            printfn "Suggestion: %s" suggestion

                        // Validate the suggestion
                        let vr = Parser.validate suggestion
                        if not vr.IsValid && not jsonMode then
                            printfn "  (Note: suggestion has %d validation issue(s) — review before use)" vr.Issues.Length

                        let _published = Notify.publishSuggestEvent truncatedDiff suggestion "llama-3.1-8b-instruct:free"
                        let _stored = History.appendSuggestion truncatedDiff suggestion "llama-3.1-8b-instruct:free" vr.IsValid
                        0
                    else
                        eprintfn "ERROR: Could not parse OpenRouter response."
                        1
                else
                    let status = int response.StatusCode
                    eprintfn "[suggest] OpenRouter returned %d — falling back to rule-based." status
                    let lines = diffStat.Split('\n')
                    let fileCount = lines.Length - 1
                    let suggestion = sprintf "chore(core): update %d files" fileCount
                    if jsonMode then
                        printfn """{"suggestion":"%s","source":"rule-based","model":null}""" suggestion
                    else
                        printfn "Suggestion: %s" suggestion
                    let _published = Notify.publishSuggestEvent truncatedDiff suggestion "rule-based"
                    0
            with ex ->
                eprintfn "[suggest] Network error: %s — falling back to rule-based." ex.Message
                let lines = diffStat.Split('\n')
                let fileCount = lines.Length - 1
                let suggestion = sprintf "chore(core): update %d files" fileCount
                if jsonMode then
                    printfn """{"suggestion":"%s","source":"rule-based","model":null}""" suggestion
                else
                    printfn "Suggestion: %s" suggestion
                let _published = Notify.publishSuggestEvent truncatedDiff suggestion "rule-based"
                0

// ─────────────────────────────────────────────────────────────────────────────
// Command: guardrails
// ─────────────────────────────────────────────────────────────────────────────

let private cmdGuardrails (args: string[]) : int =
    let jsonMode = hasFlag "--json" args
    let bold = "\x1b[1m"
    let reset = "\x1b[0m"
    let dim = "\x1b[2m"
    let green = "\x1b[32m"
    let yellow = "\x1b[33m"

    if jsonMode then
        printfn """{"workflows":["atomic-evolution","pre-commit-validation","evolution-cycle","branch-per-sprint"],"guardrails":["icp-v2-format","80-char-subject","imperative-mood","23-scope-taxonomy","9-type-enum","co-author-trailer","no-emoji-prefix","no-evolution-run","no-hyperbolic","scope-compliance"],"agentic":["json-output","exit-codes","pipe-friendly","validate-before-commit","ghs-monitoring","drift-detection"]}"""
    else
        printfn ""
        printfn "%s╔═══════════════════════════════════════════════════════════════╗%s" bold reset
        printfn "%s║  GIT WORKFLOWS, GUARDRAILS & AGENTIC PATTERNS               ║%s" bold reset
        printfn "%s╚═══════════════════════════════════════════════════════════════╝%s" bold reset
        printfn ""
        printfn "%s── 1. Git Workflows ──────────────────────────────────────────%s" bold reset
        printfn ""
        printfn "  %s1.1 Atomic Evolution (Primary Workflow)%s" green reset
        printfn "      Every commit preserves functional state (Axiom 0)."
        printfn "      Sequence: code → compile → test → validate → commit"
        printfn "      Rollback: git revert <sha> if post-commit verification fails"
        printfn ""
        printfn "  %s1.2 Pre-Commit Validation%s" green reset
        printfn "      git-intelligence validate \"<message>\" MUST return exit 0"
        printfn "      before git commit is allowed. Agents: pipe message through"
        printfn "      validate --json, check .valid field."
        printfn ""
        printfn "  %s1.3 Evolution Cycle Integration%s" green reset
        printfn "      OODA: Observe (git log) → Orient (analyze) → Decide → Act"
        printfn "      Evolve commits: evolve(scope): description — metrics"
        printfn "      Never: EVOLUTION RUN N: (zero information density)"
        printfn ""
        printfn "  %s1.4 Branch Strategy%s" green reset
        printfn "      main:     Always functional (Axiom 0)"
        printfn "      sprint-N: Sprint work branches"
        printfn "      feat/*:   Feature branches"
        printfn "      fix/*:    Hotfix branches"
        printfn "      Merge:    Squash or merge (never rebase shared branches)"
        printfn ""
        printfn "%s── 2. Guardrails (Enforced) ──────────────────────────────────%s" bold reset
        printfn ""
        printfn "  %s✓%s ICP v2.0 format:    type(scope): action — context" green reset
        printfn "  %s✓%s 80-char subject:    Enforced by validate + generate" green reset
        printfn "  %s✓%s Imperative mood:    'add' not 'added'" green reset
        printfn "  %s✓%s 23-scope taxonomy:  Closed enum, no free-text scopes" green reset
        printfn "  %s✓%s 9-type enum:        Closed, never invent new types" green reset
        printfn "  %s✓%s Co-Authored-By:     Required for AI-assisted commits" green reset
        printfn "  %s✓%s No emoji prefix:    Rejected by validate" green reset
        printfn "  %s✓%s No EVOLUTION RUN:   Rejected — use evolve(scope)" green reset
        printfn "  %s✓%s No hyperbolic:      Rejected — use type(scope)" green reset
        printfn "  %s✓%s Scope compliance:   Historical scopes mapped to taxonomy" green reset
        printfn ""
        printfn "%s── 3. Agentic Integration Patterns ──────────────────────────%s" bold reset
        printfn ""
        printfn "  %sValidation before commit:%s" yellow reset
        printfn "    git-intelligence validate \"msg\" --json | jq .valid"
        printfn ""
        printfn "  %sGenerate from structured input:%s" yellow reset
        printfn "    git-intelligence generate --type feat --scope mesh \\"
        printfn "      --action \"add consensus\" --context \"2oo3 voting\" \\"
        printfn "      --stamp SC-SIL6-006 --task S60-T001"
        printfn ""
        printfn "  %sHealth monitoring in CI/CD:%s" yellow reset
        printfn "    git-intelligence analyze --json | jq .healthScore.ghs"
        printfn "    %s# GHS < 0.50 → exit 1 (fail CI gate)%s" dim reset
        printfn ""
        printfn "  %sDrift detection:%s" yellow reset
        printfn "    git-intelligence analyze --since 1m --json | jq .monthly"
        printfn "    %s# Track ICP adoption trend over time%s" dim reset
        printfn ""
        printfn "  %sClassify + fix legacy commits:%s" yellow reset
        printfn "    git-intelligence classify \"EVOLUTION RUN 2: sync\" --json"
        printfn "    %s# Returns style + density for migration planning%s" dim reset
        printfn ""
        printfn "%s── 4. Exit Codes ──────────────────────────────────────────%s" bold reset
        printfn ""
        printfn "  0  Success (analyze: GHS ≥ 0.50, validate: valid)"
        printfn "  1  Failure (analyze: GHS < 0.50, validate: invalid, error)"
        printfn ""
    0

// ─────────────────────────────────────────────────────────────────────────────
// Command: store-init — Initialize SQLite + DuckDB holon state
// ─────────────────────────────────────────────────────────────────────────────

let private cmdStoreInit (args: string[]) : int =
    let holonPath = findArg "--holon-path" args
    match holonPath with
    | Some path ->
        Store.setDbPath (System.IO.Path.Combine(path, "state.sqlite"))
        History.setDbPath (System.IO.Path.Combine(path, "history.duckdb"))
    | None -> ()

    printfn "Initializing Git Intelligence holon state..."
    let sqliteOk =
        try
            Store.initDb ()
            true
        with ex ->
            eprintfn "ERROR: SQLite init failed: %s" ex.Message
            false
    if not sqliteOk then 1
    else
        printfn "  SQLite state store: OK"
        match History.initDb () with
        | Error e ->
            eprintfn "ERROR: DuckDB init failed: %s" e
            1
        | Ok () ->
            printfn "  DuckDB evolution log: OK"
            printfn "Holon state initialized."
            0

// ─────────────────────────────────────────────────────────────────────────────
// Command: trend — GHS trend analysis
// ─────────────────────────────────────────────────────────────────────────────

let private cmdTrend (root: string) (args: string[]) : int =
    let since = findArg "--since" args |> Option.defaultValue "6m" |> parseSince

    match Parser.parseGitLog root since None with
    | Error e ->
        eprintfn "ERROR: %s" e
        1
    | Ok commits ->
        let analysis = Analysis.analyze commits
        let currentGhs = analysis.HealthScore.Score

        // Get evolution events from History for trend EMA
        let sinceDate = DateTimeOffset.UtcNow.AddMonths(-6)
        let events = History.queryByDateRange sinceDate DateTimeOffset.UtcNow |> List.toArray

        let windowSize = findArg "--window" args |> Option.bind (fun s -> match System.Int32.TryParse(s) with true, v -> Some v | _ -> None) |> Option.defaultValue 10
        let report = Trend.formatTrendReport commits events currentGhs windowSize
        printfn "%s" report
        0

// ─────────────────────────────────────────────────────────────────────────────
// Command: homeostasis — PID controller assessment
// ─────────────────────────────────────────────────────────────────────────────

let private cmdHomeostasis (root: string) (args: string[]) : int =
    let since = findArg "--since" args |> Option.defaultValue "3m" |> parseSince

    match Parser.parseGitLog root since None with
    | Error e ->
        eprintfn "ERROR: %s" e
        1
    | Ok commits ->
        let analysis = Analysis.analyze commits
        let currentGhs = analysis.HealthScore.Score
        let previousGhs = Store.getLatestHealth () |> Option.map (fun (ghs, _, _, _) -> ghs)

        let pid = Homeostasis.createPid ()
        let state = Homeostasis.assess pid currentGhs previousGhs
        let report = Homeostasis.formatReport state
        printfn "%s" report

        // Record health snapshot
        Store.recordHealthSnapshot currentGhs analysis.HealthScore.TypeEntropy analysis.HealthScore.IcpAdoption |> ignore
        0

// ─────────────────────────────────────────────────────────────────────────────
// Command: constitutional — Ψ₀-Ψ₅ invariant verification
// ─────────────────────────────────────────────────────────────────────────────

let private cmdConstitutional (root: string) (args: string[]) : int =
    let since = findArg "--since" args |> Option.defaultValue "3m" |> parseSince
    let jsonMode = hasFlag "--json" args

    match Parser.parseGitLog root since None with
    | Error e ->
        eprintfn "ERROR: %s" e
        1
    | Ok commits ->
        let analysis = Analysis.analyze commits
        let ghs = analysis.HealthScore.Score

        // Gather constitutional check parameters
        let lastCommitAge =
            if commits.Length = 0 then System.TimeSpan.MaxValue
            else DateTimeOffset.UtcNow - commits.[0].Date
        let sqlitePath = "data/holons/git-intel/state.sqlite"
        let duckdbPath = "data/holons/git-intel/history.duckdb"
        let sqliteExists = System.IO.File.Exists(sqlitePath)
        let duckdbExists = System.IO.File.Exists(duckdbPath)
        let eventCount = History.getEventCount ()
        let lineage = History.exportLineage ()
        let oldestEvent = if lineage.IsEmpty then None else Some lineage.Head.Timestamp

        let checks =
            Constitutional.verifyAll
                lastCommitAge
                commits.Length
                sqliteExists
                duckdbExists
                eventCount
                oldestEvent
                (commits.Length > 0)
                (Some ghs)
                analysis.HealthScore.IcpAdoption
                analysis.HealthScore.MeanSemanticDensity

        if jsonMode then
            let score = Constitutional.computeSafetyScore checks
            let checkJson =
                checks
                |> List.map (fun c ->
                    let passedStr = if c.Passed then "true" else "false"
                    $"""{{ "invariant": "{c.InvariantId}", "name": "{c.InvariantName}", "passed": {passedStr}, "score": {c.Score:F4}, "details": "{c.Details}" }}""")
                |> String.concat ", "
            printfn $"""{{ "safetyScore": {score:F4}, "hasCriticalViolation": {(if Constitutional.hasCriticalViolation checks then "true" else "false")}, "checks": [{checkJson}] }}"""
        else
            printfn "%s" (Constitutional.formatDashboard checks)

        if Constitutional.hasCriticalViolation checks then 1 else 0

// ─────────────────────────────────────────────────────────────────────────────
// Command: federation — L7 cross-holon GHS exchange
// ─────────────────────────────────────────────────────────────────────────────

let private cmdFederation (root: string) (args: string[]) : int =
    let jsonMode = hasFlag "--json" args

    // Get local GHS
    let localGhs =
        let since = parseSince "3m"
        match Parser.parseGitLog root since None with
        | Ok commits when commits.Length > 0 ->
            let a = Analysis.analyze commits
            Some a.HealthScore.Score
        | _ -> None

    // Subcommand dispatch
    let subCmd = if args.Length > 1 then args.[1].ToLowerInvariant() else "status"
    match subCmd with
    | "discover" ->
        let self = Federation.discoverSelf localGhs
        printfn "Discovered self: %s (GHS: %s)" self.PeerId (match self.LastGhs with Some g -> $"{g:F4}" | None -> "N/A")
        0
    | "sync" ->
        match localGhs with
        | None ->
            eprintfn "ERROR: Cannot compute local GHS for sync."
            1
        | Some ghs ->
            let fedGhs = Federation.computeFederatedHealth ghs
            printfn "Federated Health: %.4f (local: %.4f)" fedGhs ghs
            0
    | _ -> // "status" or default
        if jsonMode then
            printfn "%s" (Federation.toJson ())
        else
            printfn "%s" (Federation.formatReport ())
        0

// ─────────────────────────────────────────────────────────────────────────────
// Command: multiverse — L9 fork/shadow operations
// ─────────────────────────────────────────────────────────────────────────────

let private cmdMultiverse (root: string) (args: string[]) : int =
    let jsonMode = hasFlag "--json" args
    let subCmd = if args.Length > 1 then args.[1].ToLowerInvariant() else "list"

    match subCmd with
    | "fork" ->
        let currentGhs =
            let since = parseSince "3m"
            match Parser.parseGitLog root since None with
            | Ok commits when commits.Length > 0 ->
                Some (Analysis.analyze commits).HealthScore.Score
            | _ -> None
        match Multiverse.forkUniverse root currentGhs with
        | Ok universe ->
            printfn "Forked universe: %s (branch: %s)" universe.UniverseId universe.BranchName
            0
        | Error e ->
            eprintfn "ERROR: %s" e
            1

    | "verify" ->
        let uid = if args.Length > 2 then args.[2] else ""
        if uid = "" then
            eprintfn "ERROR: Usage: multiverse verify <universe-id>"
            1
        else
            let since = parseSince "3m"
            match Parser.parseGitLog root since None with
            | Error e ->
                eprintfn "ERROR: %s" e
                1
            | Ok commits ->
                match Multiverse.setUniverseGhs uid (Analysis.analyze commits).HealthScore.Score with
                | Some u ->
                    printfn "Verified %s: GHS=%.4f" u.UniverseId (u.Ghs |> Option.defaultValue 0.0)
                    0
                | None ->
                    eprintfn "ERROR: Universe %s not found" uid
                    1

    | "promote" ->
        let uid = if args.Length > 2 then args.[2] else ""
        if uid = "" then
            eprintfn "ERROR: Usage: multiverse promote <universe-id>"
            1
        else
            match Multiverse.promoteUniverse root uid with
            | Ok u ->
                printfn "Promoted universe %s (GHS: %s)" u.UniverseId (match u.Ghs with Some g -> $"{g:F4}" | None -> "N/A")
                0
            | Error e ->
                eprintfn "ERROR: %s" e
                1

    | "prune" ->
        let uid = if args.Length > 2 then args.[2] else ""
        if uid = "" then
            // Prune stale (24h default)
            let ttl = findArg "--ttl" args |> Option.bind (fun s -> match System.Double.TryParse(s) with true, v -> Some v | _ -> None) |> Option.defaultValue 24.0
            let count = Multiverse.pruneStale root ttl
            printfn "Pruned %d stale universe(s) (TTL: %.0fh)" count ttl
            0
        else
            match Multiverse.pruneUniverse root uid with
            | Ok _ ->
                printfn "Pruned universe %s" uid
                0
            | Error e ->
                eprintfn "ERROR: %s" e
                1

    | _ -> // "list" or default
        if jsonMode then
            printfn "%s" (Multiverse.toJson ())
        else
            printfn "%s" (Multiverse.formatReport ())
        0

// ─────────────────────────────────────────────────────────────────────────────
// Command: biomorphic — Full 5-subsystem assessment
// ─────────────────────────────────────────────────────────────────────────────

let private cmdBiomorphic (root: string) (args: string[]) : int =
    let since = findArg "--since" args |> Option.defaultValue "3m" |> parseSince

    match Parser.parseGitLog root since None with
    | Error e ->
        eprintfn "ERROR: %s" e
        1
    | Ok commits ->
        let analysis = Analysis.analyze commits
        let currentGhs = analysis.HealthScore.Score
        let previousGhs = Store.getLatestHealth () |> Option.map (fun (ghs, _, _, _) -> ghs)

        let pid = Homeostasis.createPid ()
        let eventCount = History.getEventCount ()

        let state = BiomorphicOrchestrator.runFullAssessment commits currentGhs previousGhs pid eventCount
        let dashboard = BiomorphicOrchestrator.formatBiomorphicDashboard state
        printfn "%s" dashboard

        // Record health snapshot
        Store.recordHealthSnapshot currentGhs analysis.HealthScore.TypeEntropy analysis.HealthScore.IcpAdoption |> ignore

        if state.ShouldHalt then 1 else 0

// ─────────────────────────────────────────────────────────────────────────────
// Command: mcp-list — List MCP tool definitions
// ─────────────────────────────────────────────────────────────────────────────

let private cmdMcpList (_args: string[]) : int =
    let jsonMode = hasFlag "--json" _args
    if jsonMode then
        printfn "%s" (McpTools.toolsToJson ())
    else
        printfn "Git Intelligence MCP Tools:"
        for name in McpTools.listTools () do
            printfn "  - %s" name
    0

// ─────────────────────────────────────────────────────────────────────────────
// Main Entry Point
// ─────────────────────────────────────────────────────────────────────────────

[<EntryPoint>]
let main (argv: string[]) : int =
    let root = findProjectRoot()

    if argv.Length = 0 || hasFlag "--help" argv || hasFlag "-h" argv then
        printUsage()
        0
    else
        let command = argv.[0].ToLowerInvariant()
        let exitCode =
            match command with
            | "analyze" | "health" ->
                cmdAnalyze root argv
            | "validate" ->
                cmdValidate argv
            | "classify" ->
                cmdClassify argv
            | "generate" ->
                cmdGenerate argv
            | "commit" ->
                cmdCommit root argv
            | "suggest" ->
                cmdSuggest root argv
            | "guardrails" | "workflows" ->
                cmdGuardrails argv
            // ── Advanced Commands (Phase 5.2) ──────────────────────────────
            | "store-init" -> cmdStoreInit argv
            | "trend" -> cmdTrend root argv
            | "homeostasis" -> cmdHomeostasis root argv
            | "constitutional" -> cmdConstitutional root argv
            | "federation" -> cmdFederation root argv
            | "multiverse" -> cmdMultiverse root argv
            | "biomorphic" -> cmdBiomorphic root argv
            | "mcp-list" -> cmdMcpList argv
            | "mcp-serve" -> McpServer.serve ()
            | unknown ->
                eprintfn "ERROR: Unknown command '%s'. Run with --help for usage." unknown
                1
        // Close Zenoh session on exit (if opened by commit/suggest)
        Notify.closeSession()
        exitCode
