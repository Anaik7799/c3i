#!/usr/bin/env dotnet fsi

// ZkmsProjectStateIngestor.fsx
// Comprehensive Project State Integration for SMRITI
// Ingests: .claude configs, .env files, git/github, operational status
// Creates: Captain's Log for periodic status updates
//
// STAMP Constraints: SC-SMRITI-PROJECT-001 to SC-SMRITI-PROJECT-020
// AOR Rules: AOR-SMRITI-PROJECT-001 to AOR-SMRITI-PROJECT-010
//
// Usage:
//   dotnet fsi ZkmsProjectStateIngestor.fsx --claude       # Ingest .claude folder
//   dotnet fsi ZkmsProjectStateIngestor.fsx --env          # Ingest .env files
//   dotnet fsi ZkmsProjectStateIngestor.fsx --git          # Track git state
//   dotnet fsi ZkmsProjectStateIngestor.fsx --captain-log  # Update Captain's Log
//   dotnet fsi ZkmsProjectStateIngestor.fsx --full         # All of the above
//   dotnet fsi ZkmsProjectStateIngestor.fsx --status       # Show current status

#r "nuget: Microsoft.Data.Sqlite, 9.0.0"
#r "nuget: System.Text.Json, 9.0.0"

open System
open System.IO
open System.Text.Json
open System.Text.RegularExpressions
open System.Security.Cryptography
open Microsoft.Data.Sqlite

// ============================================================================
// Configuration
// ============================================================================

let projectRoot = Environment.CurrentDirectory
let dbPath = Path.Combine(projectRoot, "data", "kms", "smriti.db")
let captainsLogPath = Path.Combine(projectRoot, "data", "kms", "captains_log.json")

// Clusters for different artifact types
let clusters = {|
    ClaudeRules = "claude-rules"
    ClaudeCommands = "claude-commands"
    ClaudeAgents = "claude-agents"
    ClaudePlans = "claude-plans"
    ClaudeHooks = "claude-hooks"
    ClaudePlugins = "claude-plugins"
    EnvConfig = "env-config"
    GitState = "git-state"
    GitHistory = "git-history"
    Operational = "operational"
    CaptainsLog = "captains-log"
|}

// ============================================================================
// Utility Functions
// ============================================================================

let computeHash (content: string) : string =
    use sha256 = SHA256.Create()
    let bytes = System.Text.Encoding.UTF8.GetBytes(content)
    let hash = sha256.ComputeHash(bytes)
    BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant()

let sanitizeForJson (s: string) : string =
    s.Replace("\\", "\\\\")
     .Replace("\"", "\\\"")
     .Replace("\n", "\\n")
     .Replace("\r", "\\r")
     .Replace("\t", "\\t")

let generateUuid () = Guid.NewGuid().ToString()

let getConnection () =
    let conn = new SqliteConnection($"Data Source={dbPath}")
    conn.Open()
    conn

// ============================================================================
// Database Operations
// ============================================================================

let holonExists (conn: SqliteConnection) (contentHash: string) : bool =
    use cmd = conn.CreateCommand()
    cmd.CommandText <- "SELECT COUNT(*) FROM holons WHERE content_hash = @hash"
    cmd.Parameters.AddWithValue("@hash", contentHash) |> ignore
    let count = cmd.ExecuteScalar() :?> int64
    count > 0L

let insertHolon (conn: SqliteConnection) (title: string) (content: string)
                (tags: string list) (cluster: string) (level: string)
                (decayRate: string) : bool =
    let hash = computeHash content
    if holonExists conn hash then
        false
    else
        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            INSERT INTO holons (holon_uuid, title, content, tags, cluster, level, decay_rate, content_hash)
            VALUES (@uuid, @title, @content, @tags, @cluster, @level, @decay_rate, @hash)
        """
        cmd.Parameters.AddWithValue("@uuid", generateUuid()) |> ignore
        cmd.Parameters.AddWithValue("@title", title) |> ignore
        cmd.Parameters.AddWithValue("@content", content) |> ignore
        cmd.Parameters.AddWithValue("@tags", String.Join(",", tags)) |> ignore
        cmd.Parameters.AddWithValue("@cluster", cluster) |> ignore
        cmd.Parameters.AddWithValue("@level", level) |> ignore
        cmd.Parameters.AddWithValue("@decay_rate", decayRate) |> ignore
        cmd.Parameters.AddWithValue("@hash", hash) |> ignore
        cmd.ExecuteNonQuery() |> ignore
        true

// ============================================================================
// .claude Folder Ingestion
// ============================================================================

type ClaudeArtifact = {
    Path: string
    Category: string
    Content: string
    Tags: string list
    Level: string
}

let categorizeClaudeFile (path: string) : string * string list * string =
    let relativePath = path.Replace(projectRoot, "").TrimStart('/', '\\')
    if relativePath.Contains("/rules/") then
        clusters.ClaudeRules, ["claude"; "rules"; "configuration"], "molecular"
    elif relativePath.Contains("/commands/") then
        clusters.ClaudeCommands, ["claude"; "commands"; "skill"], "atomic"
    elif relativePath.Contains("/agents/") then
        clusters.ClaudeAgents, ["claude"; "agents"; "ai"], "organism"
    elif relativePath.Contains("/plans/") then
        clusters.ClaudePlans, ["claude"; "plans"; "sprint"], "molecular"
    elif relativePath.Contains("/hooks/") then
        clusters.ClaudeHooks, ["claude"; "hooks"; "automation"], "atomic"
    elif relativePath.Contains("/plugins/") then
        clusters.ClaudePlugins, ["claude"; "plugins"; "integration"], "molecular"
    else
        "claude-misc", ["claude"; "configuration"], "atomic"

let extractClaudeMetadata (content: string) (filename: string) : string list =
    let baseTags =
        [
            if content.Contains("STAMP") then "stamp"
            if content.Contains("AOR") then "aor"
            if content.Contains("SC-") then "safety-constraint"
            if content.Contains("biomorphic") then "biomorphic"
            if content.Contains("SIL") then "sil"
            if content.Contains("OODA") then "ooda"
            if content.Contains("fractal") then "fractal"
            if content.Contains("holon") then "holon"
            if content.Contains("prajna") then "prajna"
            if content.Contains("zenoh") then "zenoh"
            if content.Contains("guardian") then "guardian"
            if content.Contains("sentinel") then "sentinel"
        ]

    // Extract domain from filename
    let nameTags =
        let name = Path.GetFileNameWithoutExtension(filename).ToLower()
        name.Split([|'-'; '_'|]) |> Array.toList

    baseTags @ nameTags |> List.distinct

let ingestClaudeFolder () =
    printfn "\n╔══════════════════════════════════════════════════════════════╗"
    printfn "║  INGESTING .CLAUDE CONFIGURATION                            ║"
    printfn "╚══════════════════════════════════════════════════════════════╝"

    let claudePath = Path.Combine(projectRoot, ".claude")
    if not (Directory.Exists(claudePath)) then
        printfn "ERROR: .claude folder not found"
        0
    else
        use conn = getConnection()
        let mutable ingested = 0
        let mutable skipped = 0

        let allFiles =
            Directory.GetFiles(claudePath, "*", SearchOption.AllDirectories)
            |> Array.filter (fun f ->
                let ext = Path.GetExtension(f).ToLower()
                [".md"; ".json"; ".sh"; ".log"] |> List.contains ext)

        for file in allFiles do
            try
                let content = File.ReadAllText(file)
                let filename = Path.GetFileName(file)
                let relativePath = file.Replace(projectRoot, "").TrimStart('/', '\\')
                let cluster, baseTags, level = categorizeClaudeFile file
                let tags = (baseTags @ extractClaudeMetadata content filename) |> List.distinct

                let title = $"[Claude] {relativePath}"
                let enrichedContent = $"""# {relativePath}

**Category**: {cluster}
**Level**: {level}
**Tags**: {String.Join(", ", tags)}

---

{content}"""

                if insertHolon conn title enrichedContent tags cluster level "slow" then
                    ingested <- ingested + 1
                    printfn "  ✓ Ingested: %s" relativePath
                else
                    skipped <- skipped + 1
            with ex ->
                printfn "  ✗ Error processing %s: %s" file ex.Message

        printfn "\n  Claude Ingestion Complete:"
        printfn "    Ingested: %d" ingested
        printfn "    Skipped (duplicates): %d" skipped
        ingested

// ============================================================================
// .env Files Ingestion (Sanitized)
// ============================================================================

let sanitizeEnvContent (content: string) : string =
    // Remove actual secret values, keep structure
    let lines = content.Split('\n')
    let sanitized =
        lines
        |> Array.map (fun line ->
            if String.IsNullOrWhiteSpace(line) || line.TrimStart().StartsWith("#") then
                line
            elif line.Contains("=") then
                let parts = line.Split('=', 2)
                let key = parts.[0]
                // Sanitize sensitive keys
                let sensitivePatterns =
                    ["KEY"; "SECRET"; "PASSWORD"; "TOKEN"; "CREDENTIAL"; "AUTH"; "API_KEY"]
                let isSensitive =
                    sensitivePatterns
                    |> List.exists (fun p -> key.ToUpper().Contains(p))
                if isSensitive then
                    $"{key}=<REDACTED>"
                else
                    line
            else
                line
        )
    String.Join("\n", sanitized)

let ingestEnvFiles () =
    printfn "\n╔══════════════════════════════════════════════════════════════╗"
    printfn "║  INGESTING ENVIRONMENT CONFIGURATIONS (SANITIZED)           ║"
    printfn "╚══════════════════════════════════════════════════════════════╝"

    use conn = getConnection()
    let mutable ingested = 0

    let envFiles =
        [
            ".env"
            ".env.example"
            ".envrc"
            ".envrc.local"
            ".envrc.patient"
            ".env.sopv51"
            ".env.standalone.template"
            "tailscale.env"
        ]
        |> List.map (fun f -> Path.Combine(projectRoot, f))
        |> List.filter File.Exists

    for file in envFiles do
        try
            let content = File.ReadAllText(file)
            let sanitized = sanitizeEnvContent content
            let filename = Path.GetFileName(file)

            let tags =
                [
                    "env"; "configuration"; "environment"
                    if filename.Contains("patient") then "patient-mode"
                    if filename.Contains("standalone") then "standalone"
                    if filename.Contains("tailscale") then "tailscale"; "vpn"
                    if filename.Contains("sopv51") then "sopv51"
                ]

            let title = $"[Env] {filename}"
            let enrichedContent = $"""# Environment Configuration: {filename}

**Type**: Environment Variables
**Sanitized**: Yes (secrets redacted)
**Purpose**: Runtime configuration

---

```env
{sanitized}
```

## Configuration Categories

This file defines environment variables for:
- Application runtime settings
- Service endpoints
- Feature flags
- Integration configuration
"""

            if insertHolon conn title enrichedContent tags clusters.EnvConfig "atomic" "slow" then
                ingested <- ingested + 1
                printfn "  ✓ Ingested: %s" filename
        with ex ->
            printfn "  ✗ Error processing %s: %s" file ex.Message

    printfn "\n  Env Ingestion Complete: %d files" ingested
    ingested

// ============================================================================
// Git State Tracking
// ============================================================================

let runGitCommand (args: string) : string option =
    try
        let startInfo =
            System.Diagnostics.ProcessStartInfo(
                FileName = "git",
                Arguments = args,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                WorkingDirectory = projectRoot
            )
        use proc = System.Diagnostics.Process.Start(startInfo)
        let output = proc.StandardOutput.ReadToEnd()
        proc.WaitForExit()
        if proc.ExitCode = 0 then Some output else None
    with _ -> None

type GitState = {
    Branch: string
    LastCommit: string
    CommitHash: string
    Author: string
    Timestamp: string
    RemoteUrl: string
    UncommittedChanges: int
    AheadBehind: string
}

let captureGitState () : GitState option =
    let branch = runGitCommand "rev-parse --abbrev-ref HEAD" |> Option.map (fun s -> s.Trim())
    let lastCommit = runGitCommand "log -1 --pretty=format:%s" |> Option.map (fun s -> s.Trim())
    let commitHash = runGitCommand "rev-parse HEAD" |> Option.map (fun s -> s.Trim().Substring(0, 8))
    let author = runGitCommand "log -1 --pretty=format:%an" |> Option.map (fun s -> s.Trim())
    let timestamp = runGitCommand "log -1 --pretty=format:%ci" |> Option.map (fun s -> s.Trim())
    let remoteUrl = runGitCommand "remote get-url origin" |> Option.map (fun s -> s.Trim())
    let status = runGitCommand "status --porcelain" |> Option.map (fun s -> s.Split('\n').Length - 1)
    let aheadBehind = runGitCommand "rev-list --left-right --count HEAD...@{u}" |> Option.defaultValue "unknown"

    match branch, lastCommit, commitHash with
    | Some b, Some lc, Some ch ->
        Some {
            Branch = b
            LastCommit = lc
            CommitHash = ch
            Author = author |> Option.defaultValue "unknown"
            Timestamp = timestamp |> Option.defaultValue "unknown"
            RemoteUrl = remoteUrl |> Option.defaultValue "unknown"
            UncommittedChanges = status |> Option.defaultValue 0
            AheadBehind = aheadBehind.Trim()
        }
    | _ -> None

let ingestGitState () =
    printfn "\n╔══════════════════════════════════════════════════════════════╗"
    printfn "║  TRACKING GIT/GITHUB STATE                                  ║"
    printfn "╚══════════════════════════════════════════════════════════════╝"

    use conn = getConnection()

    match captureGitState() with
    | None ->
        printfn "  ✗ Failed to capture git state"
        0
    | Some state ->
        // Get recent commits
        let recentCommits =
            runGitCommand "log --oneline -20"
            |> Option.defaultValue ""

        // Get branch list
        let branches =
            runGitCommand "branch -a --format='%(refname:short)'"
            |> Option.defaultValue ""

        // Get file statistics
        let fileStats =
            runGitCommand "diff --stat HEAD~5 2>/dev/null"
            |> Option.defaultValue "No recent changes"

        let tags =
            ["git"; "version-control"; "github"; state.Branch; "evolution"]

        let nowStr = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
        let title = $"[Git] State at {nowStr}"
        let content = $"""# Git Repository State

**Captured**: {nowStr}
**Branch**: {state.Branch}
**Last Commit**: {state.CommitHash} - {state.LastCommit}
**Author**: {state.Author}
**Timestamp**: {state.Timestamp}
**Remote**: {state.RemoteUrl}
**Uncommitted Changes**: {state.UncommittedChanges}
**Ahead/Behind**: {state.AheadBehind}

---

## Recent Commits (Last 20)

```
{recentCommits}
```

## Active Branches

```
{branches}
```

## Recent File Changes (Last 5 commits)

```
{fileStats}
```

## Repository Metadata

- **Organization**: Anaik7799
- **Repository**: intelitor
- **Type**: Private/Public
- **Primary Language**: Elixir, F#

## Evolution Tracking

This holon tracks the evolutionary state of the codebase at a point in time.
It enables:
- Temporal navigation through code evolution
- Change impact analysis
- Regression detection
- Pattern recognition in development
"""

        if insertHolon conn title content tags clusters.GitState "organism" "medium" then
            printfn "  ✓ Git state captured"
            printfn "    Branch: %s" state.Branch
            printfn "    Commit: %s" state.CommitHash
            printfn "    Author: %s" state.Author
            printfn "    Uncommitted: %d files" state.UncommittedChanges
            1
        else
            printfn "  ○ Git state unchanged (duplicate)"
            0

// ============================================================================
// Captain's Log System
// ============================================================================

type CaptainsLogEntry = {
    Timestamp: DateTime
    Stardate: string
    Status: string
    Health: Map<string, string>
    Metrics: Map<string, int>
    Notes: string list
    GitState: GitState option
}

type CaptainsLog = {
    Version: string
    StartDate: DateTime
    Entries: CaptainsLogEntry list
}

let computeStardate () =
    // Stardate format: YYYY.DDD.HH (Year.DayOfYear.Hour)
    let now = DateTime.Now
    $"{now.Year}.{now.DayOfYear:D3}.{now.Hour:D2}"

let checkContainerHealth () : Map<string, string> =
    let check container =
        let result = runGitCommand $"-c core.fileMode=false status" // dummy, replace with actual
        try
            let startInfo =
                System.Diagnostics.ProcessStartInfo(
                    FileName = "podman",
                    Arguments = $"inspect --format '{{{{.State.Health.Status}}}}' {container}",
                    RedirectStandardOutput = true,
                    UseShellExecute = false
                )
            use proc = System.Diagnostics.Process.Start(startInfo)
            let output = proc.StandardOutput.ReadToEnd().Trim()
            proc.WaitForExit()
            if proc.ExitCode = 0 && not (String.IsNullOrEmpty(output)) then
                output
            else
                "not-running"
        with _ -> "unknown"

    [
        "indrajaal-db-prod", check "indrajaal-db-prod"
        "indrajaal-obs-prod", check "indrajaal-obs-prod"
        "indrajaal-ex-app-1", check "indrajaal-ex-app-1"
    ] |> Map.ofList

let collectMetrics () : Map<string, int> =
    use conn = getConnection()

    // Count holons
    let holonCount =
        use cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT COUNT(*) FROM holons"
        cmd.ExecuteScalar() :?> int64 |> int

    // Count edges
    let edgeCount =
        use cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT COUNT(*) FROM holon_edges"
        try
            cmd.ExecuteScalar() :?> int64 |> int
        with _ -> 0

    // Count clusters
    let clusterCount =
        use cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT COUNT(DISTINCT cluster) FROM holons"
        cmd.ExecuteScalar() :?> int64 |> int

    [
        "holons", holonCount
        "edges", edgeCount
        "clusters", clusterCount
    ] |> Map.ofList

let loadCaptainsLog () : CaptainsLog =
    if File.Exists(captainsLogPath) then
        try
            let json = File.ReadAllText(captainsLogPath)
            JsonSerializer.Deserialize<CaptainsLog>(json)
        with _ ->
            { Version = "1.0"; StartDate = DateTime.Now; Entries = [] }
    else
        { Version = "1.0"; StartDate = DateTime.Now; Entries = [] }

let saveCaptainsLog (log: CaptainsLog) =
    let options = JsonSerializerOptions(WriteIndented = true)
    let json = JsonSerializer.Serialize(log, options)
    File.WriteAllText(captainsLogPath, json)

let updateCaptainsLog () =
    printfn "\n╔══════════════════════════════════════════════════════════════╗"
    printfn "║  CAPTAIN'S LOG - SYSTEM STATUS UPDATE                       ║"
    printfn "╚══════════════════════════════════════════════════════════════╝"

    let stardate = computeStardate()
    let health = checkContainerHealth()
    let metrics = collectMetrics()
    let gitState = captureGitState()

    // Determine overall status
    let healthyContainers =
        health |> Map.filter (fun _ v -> v = "healthy") |> Map.count
    let status =
        match healthyContainers with
        | 3 -> "OPERATIONAL"
        | 2 -> "DEGRADED"
        | 1 -> "CRITICAL"
        | _ -> "OFFLINE"

    let holonCount = metrics.["holons"]
    let clusterCount = metrics.["clusters"]
    let edgeCount = metrics.["edges"]
    let notes =
        [
            sprintf "SMRITI contains %d holons across %d clusters" holonCount clusterCount
            sprintf "Edge network: %d connections" edgeCount
            match gitState with
            | Some gs -> sprintf "Git: %s @ %s" gs.Branch gs.CommitHash
            | None -> "Git state unavailable"
        ]

    let entry = {
        Timestamp = DateTime.Now
        Stardate = stardate
        Status = status
        Health = health
        Metrics = metrics
        Notes = notes
        GitState = gitState
    }

    // Load, update, save
    let log = loadCaptainsLog()
    let updatedLog = { log with Entries = entry :: log.Entries |> List.truncate 1000 }
    saveCaptainsLog updatedLog

    // Also insert into SMRITI
    use conn = getConnection()

    // Extract values to avoid interpolation issues
    let nowStr2 = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
    let dbHealth = health.["indrajaal-db-prod"]
    let obsHealth = health.["indrajaal-obs-prod"]
    let appHealth = health.["indrajaal-ex-app-1"]

    let gitStateStr =
        match gitState with
        | Some gs ->
            sprintf "- Branch: %s\n- Commit: %s - %s\n- Author: %s\n- Uncommitted: %d files"
                gs.Branch gs.CommitHash gs.LastCommit gs.Author gs.UncommittedChanges
        | None -> "Git state unavailable"

    let notesStr = notes |> List.map (sprintf "- %s") |> String.concat "\n"

    let title = sprintf "[Captain's Log] Stardate %s" stardate

    // Build content using StringBuilder to avoid sprintf limitations
    let sb = System.Text.StringBuilder()
    sb.AppendLine(sprintf "# Captain's Log - Stardate %s" stardate) |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine(sprintf "**Timestamp**: %s" nowStr2) |> ignore
    sb.AppendLine(sprintf "**Status**: %s" status) |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("---") |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("## Container Health") |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("| Container | Status |") |> ignore
    sb.AppendLine("|-----------|--------|") |> ignore
    sb.AppendLine(sprintf "| indrajaal-db-prod | %s |" dbHealth) |> ignore
    sb.AppendLine(sprintf "| indrajaal-obs-prod | %s |" obsHealth) |> ignore
    sb.AppendLine(sprintf "| indrajaal-ex-app-1 | %s |" appHealth) |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("## SMRITI Metrics") |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("| Metric | Value |") |> ignore
    sb.AppendLine("|--------|-------|") |> ignore
    sb.AppendLine(sprintf "| Holons | %d |" holonCount) |> ignore
    sb.AppendLine(sprintf "| Edges | %d |" edgeCount) |> ignore
    sb.AppendLine(sprintf "| Clusters | %d |" clusterCount) |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("## Git State") |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine(gitStateStr) |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("## Notes") |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine(notesStr) |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("---") |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("*This log entry is automatically generated as part of the SMRITI operational tracking system.*") |> ignore
    sb.AppendLine("*SC-SMRITI-CAPTAIN-001: Periodic status updates for system awareness*") |> ignore

    let content = sb.ToString()

    let tags = ["captains-log"; "status"; "operational"; status.ToLower()]
    insertHolon conn title content tags clusters.CaptainsLog "atomic" "fast" |> ignore

    printfn "\n  ╔════════════════════════════════════════════════════════╗"
    printfn "  ║  CAPTAIN'S LOG - STARDATE %s                      ║" stardate
    printfn "  ╠════════════════════════════════════════════════════════╣"
    printfn "  ║  Status: %-44s  ║" status
    printfn "  ║  Containers:                                           ║"
    for kvp in health do
        printfn "  ║    %-20s: %-28s  ║" kvp.Key kvp.Value
    printfn "  ║  SMRITI: %d holons, %d edges                            ║" holonCount edgeCount
    printfn "  ╚════════════════════════════════════════════════════════╝"

    printfn "\n  Log saved to: %s" captainsLogPath
    1

// ============================================================================
// Status Display
// ============================================================================

let showStatus () =
    printfn "\n╔══════════════════════════════════════════════════════════════╗"
    printfn "║  SMRITI PROJECT STATE STATUS                                  ║"
    printfn "╚══════════════════════════════════════════════════════════════╝"

    use conn = getConnection()

    // Holon counts by cluster
    printfn "\n  Holon Distribution:"
    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        SELECT cluster, COUNT(*) as cnt
        FROM holons
        GROUP BY cluster
        ORDER BY cnt DESC
        LIMIT 20
    """
    use reader = cmd.ExecuteReader()
    while reader.Read() do
        let cluster = reader.GetString(0)
        let count = reader.GetInt32(1)
        printfn "    %-30s: %5d" cluster count

    // Claude config stats
    printfn "\n  Claude Configuration:"
    let claudeClusters =
        ["claude-rules"; "claude-commands"; "claude-agents"; "claude-plans"; "claude-hooks"]
    for cluster in claudeClusters do
        use cmd2 = conn.CreateCommand()
        cmd2.CommandText <- "SELECT COUNT(*) FROM holons WHERE cluster = @cluster"
        cmd2.Parameters.AddWithValue("@cluster", cluster) |> ignore
        let count = cmd2.ExecuteScalar() :?> int64
        printfn "    %-30s: %5d" cluster count

    // Git state
    printfn "\n  Git State:"
    match captureGitState() with
    | Some state ->
        printfn "    Branch: %s" state.Branch
        printfn "    Commit: %s" state.CommitHash
        printfn "    Author: %s" state.Author
        printfn "    Uncommitted: %d files" state.UncommittedChanges
    | None ->
        printfn "    Git state unavailable"

    // Container health
    printfn "\n  Container Health:"
    let health = checkContainerHealth()
    for kvp in health do
        printfn "    %-25s: %s" kvp.Key kvp.Value

    // Captain's Log
    printfn "\n  Captain's Log:"
    if File.Exists(captainsLogPath) then
        let log = loadCaptainsLog()
        printfn "    Entries: %d" log.Entries.Length
        match log.Entries with
        | latest :: _ ->
            printfn "    Latest: Stardate %s - %s" latest.Stardate latest.Status
        | [] -> ()
    else
        printfn "    No log entries yet"

    printfn ""

// ============================================================================
// Main Entry Point
// ============================================================================

let printUsage () =
    printfn """
╔══════════════════════════════════════════════════════════════╗
║  SMRITI Project State Ingestor                                ║
╠══════════════════════════════════════════════════════════════╣
║  Usage:                                                      ║
║    --claude        Ingest .claude folder                    ║
║    --env           Ingest .env files (sanitized)            ║
║    --git           Track git/github state                   ║
║    --captain-log   Update Captain's Log                     ║
║    --full          All of the above                         ║
║    --status        Show current status                      ║
║    --help          Show this help                           ║
╚══════════════════════════════════════════════════════════════╝
"""

let main args =
    printfn "\n═══════════════════════════════════════════════════════════════"
    printfn "  SMRITI PROJECT STATE INGESTOR v1.0"
    printfn "  Comprehensive Project Integration for Knowledge Management"
    printfn "═══════════════════════════════════════════════════════════════"

    if not (File.Exists(dbPath)) then
        printfn "ERROR: SMRITI database not found at %s" dbPath
        1
    else
        let args = fsi.CommandLineArgs |> Array.skip 1

        if args.Length = 0 || args |> Array.contains "--help" then
            printUsage()
            0
        else
            let mutable totalIngested = 0

            if args |> Array.contains "--claude" || args |> Array.contains "--full" then
                totalIngested <- totalIngested + ingestClaudeFolder()

            if args |> Array.contains "--env" || args |> Array.contains "--full" then
                totalIngested <- totalIngested + ingestEnvFiles()

            if args |> Array.contains "--git" || args |> Array.contains "--full" then
                totalIngested <- totalIngested + ingestGitState()

            if args |> Array.contains "--captain-log" || args |> Array.contains "--full" then
                totalIngested <- totalIngested + updateCaptainsLog()

            if args |> Array.contains "--status" then
                showStatus()

            printfn "\n═══════════════════════════════════════════════════════════════"
            printfn "  Total Items Processed: %d" totalIngested
            printfn "═══════════════════════════════════════════════════════════════\n"

            0

main (fsi.CommandLineArgs |> Array.skip 1)
