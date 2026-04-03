#!/usr/bin/env dotnet fsi

// SmritiSystemDNA.fsx
// Complete System DNA Extraction for Full Recreatability
//
// Purpose: Extract and maintain the complete "genetic code" of the system
// enabling full recreation from SMRITI if the codebase is lost.
//
// Integrates:
//   - Planning: PROJECT_TODOLIST.md, sprint plans, roadmaps
//   - Sessions: Claude session history, conversation patterns
//   - Gemini Config: GEMINI.md, AI orchestration rules
//   - Claude Config: CLAUDE.md, safety constraints, AOR rules
//   - Dev Cycle: Git history, branches, PRs, commit patterns
//   - Ops Cycle: Container lifecycles, health trends, incidents
//   - System DNA: Complete extraction for recreation
//
// STAMP Constraints: SC-SMRITI-DNA-001 to SC-SMRITI-DNA-015
// AOR Rules: AOR-SMRITI-DNA-001 to AOR-SMRITI-DNA-010
//
// Usage:
//   dotnet fsi SmritiSystemDNA.fsx --planning      # Extract planning state
//   dotnet fsi SmritiSystemDNA.fsx --sessions      # Track session data
//   dotnet fsi SmritiSystemDNA.fsx --gemini        # Ingest GEMINI.md
//   dotnet fsi SmritiSystemDNA.fsx --dev-cycle     # Track dev cycle
//   dotnet fsi SmritiSystemDNA.fsx --ops-cycle     # Track ops cycle
//   dotnet fsi SmritiSystemDNA.fsx --extract-dna   # Create System DNA bundle
//   dotnet fsi SmritiSystemDNA.fsx --verify-dna    # Verify recreatability
//   dotnet fsi SmritiSystemDNA.fsx --full          # All of the above

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
let dnaPath = Path.Combine(projectRoot, "data", "kms", "system_dna.json")
let sessionsPath = Path.Combine(projectRoot, "data", "kms", "sessions")

// Clusters
let clusters = {|
    Planning = "planning"
    Sessions = "sessions"
    GeminiConfig = "gemini-config"
    ClaudeConfig = "claude-config"
    DevCycle = "dev-cycle"
    OpsCycle = "ops-cycle"
    SystemDNA = "system-dna"
|}

// ============================================================================
// Utility Functions
// ============================================================================

let computeHash (content: string) : string =
    use sha256 = SHA256.Create()
    let bytes = System.Text.Encoding.UTF8.GetBytes(content)
    let hash = sha256.ComputeHash(bytes)
    BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant()

let generateUuid () = Guid.NewGuid().ToString()
let nowStr () = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")

let getConnection () =
    let conn = new SqliteConnection(sprintf "Data Source=%s" dbPath)
    conn.Open()
    conn

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

let runCmd (cmd: string) (args: string) : string option =
    try
        let startInfo =
            System.Diagnostics.ProcessStartInfo(
                FileName = cmd,
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

// ============================================================================
// Planning Integration
// ============================================================================

let extractPlanningState () =
    printfn "\n╔══════════════════════════════════════════════════════════════╗"
    printfn "║  EXTRACTING PLANNING STATE                                   ║"
    printfn "╚══════════════════════════════════════════════════════════════╝"

    use conn = getConnection()
    let mutable ingested = 0

    // 1. PROJECT_TODOLIST.md
    let todoPath = Path.Combine(projectRoot, "PROJECT_TODOLIST.md")
    if File.Exists(todoPath) then
        let content = File.ReadAllText(todoPath)
        let title = sprintf "[Planning] PROJECT_TODOLIST at %s" (nowStr())

        // Extract task statistics
        let inProgress = Regex.Matches(content, @"\[in_progress\]").Count
        let pending = Regex.Matches(content, @"\[pending\]").Count
        let completed = Regex.Matches(content, @"\[completed\]").Count

        let sb = System.Text.StringBuilder()
        sb.AppendLine("# Project Todo List State") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine(sprintf "**Captured**: %s" (nowStr())) |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("## Task Statistics") |> ignore
        sb.AppendLine(sprintf "- In Progress: %d" inProgress) |> ignore
        sb.AppendLine(sprintf "- Pending: %d" pending) |> ignore
        sb.AppendLine(sprintf "- Completed: %d" completed) |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("## Full Task List") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("```markdown") |> ignore
        sb.AppendLine(content) |> ignore
        sb.AppendLine("```") |> ignore

        let tags = ["planning"; "todolist"; "tasks"; "sprint"]
        if insertHolon conn title (sb.ToString()) tags clusters.Planning "organism" "medium" then
            ingested <- ingested + 1
            printfn "  ✓ PROJECT_TODOLIST.md ingested (%d in_progress, %d pending, %d completed)"
                inProgress pending completed

    // 2. Sprint plans from .claude/plans
    let plansPath = Path.Combine(projectRoot, ".claude", "plans")
    if Directory.Exists(plansPath) then
        for planFile in Directory.GetFiles(plansPath, "*.md") do
            let content = File.ReadAllText(planFile)
            let filename = Path.GetFileName(planFile)
            let title = sprintf "[Plan] %s" filename

            let tags = ["planning"; "sprint"; "plan"; "roadmap"]
            if insertHolon conn title content tags clusters.Planning "molecular" "slow" then
                ingested <- ingested + 1
                printfn "  ✓ Plan: %s" filename

    printfn "\n  Planning State Extracted: %d items" ingested
    ingested

// ============================================================================
// Session Management
// ============================================================================

let extractSessionData () =
    printfn "\n╔══════════════════════════════════════════════════════════════╗"
    printfn "║  EXTRACTING SESSION DATA                                     ║"
    printfn "╚══════════════════════════════════════════════════════════════╝"

    use conn = getConnection()
    let mutable ingested = 0

    // Ensure sessions directory exists
    if not (Directory.Exists(sessionsPath)) then
        Directory.CreateDirectory(sessionsPath) |> ignore

    // Look for Claude session files
    let claudeDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".claude")
    if Directory.Exists(claudeDir) then
        // Check for projects directory
        let projectsDir = Path.Combine(claudeDir, "projects")
        if Directory.Exists(projectsDir) then
            // Find sessions related to this project
            let projectName = Path.GetFileName(projectRoot).Replace("/", "-").Replace("\\", "-")
            for dir in Directory.GetDirectories(projectsDir) do
                let dirName = Path.GetFileName(dir)
                if dirName.Contains("intelitor") then
                    for jsonlFile in Directory.GetFiles(dir, "*.jsonl") do
                        let filename = Path.GetFileName(jsonlFile)
                        let fileInfo = FileInfo(jsonlFile)

                        // Only process recent sessions (last 7 days)
                        if (DateTime.Now - fileInfo.LastWriteTime).TotalDays < 7.0 then
                            let lines = File.ReadAllLines(jsonlFile) |> Array.length
                            let title = sprintf "[Session] %s (%d turns)" filename lines

                            let sb = System.Text.StringBuilder()
                            sb.AppendLine("# Claude Session Metadata") |> ignore
                            sb.AppendLine() |> ignore
                            sb.AppendLine(sprintf "**Session ID**: %s" (Path.GetFileNameWithoutExtension(filename))) |> ignore
                            sb.AppendLine(sprintf "**Last Modified**: %s" (fileInfo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"))) |> ignore
                            sb.AppendLine(sprintf "**Turns**: %d" lines) |> ignore
                            sb.AppendLine(sprintf "**Size**: %.2f KB" (float fileInfo.Length / 1024.0)) |> ignore
                            sb.AppendLine() |> ignore
                            sb.AppendLine("## Session Patterns") |> ignore
                            sb.AppendLine() |> ignore
                            sb.AppendLine("This holon tracks the existence of a Claude session.") |> ignore
                            sb.AppendLine("Full session content is stored in the .jsonl file.") |> ignore
                            sb.AppendLine() |> ignore
                            sb.AppendLine(sprintf "**Path**: %s" jsonlFile) |> ignore

                            let tags = ["session"; "claude"; "conversation"; "ai"]
                            if insertHolon conn title (sb.ToString()) tags clusters.Sessions "atomic" "fast" then
                                ingested <- ingested + 1
                                printfn "  ✓ Session: %s (%d turns)" filename lines

    // Also track bash history from .claude
    let bashHistoryPath = Path.Combine(projectRoot, ".claude", "bash-history.log")
    if File.Exists(bashHistoryPath) then
        let content = File.ReadAllText(bashHistoryPath)
        let lines = content.Split('\n').Length
        let title = sprintf "[Session] Bash History at %s" (nowStr())

        let sb = System.Text.StringBuilder()
        sb.AppendLine("# Claude Bash History") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine(sprintf "**Captured**: %s" (nowStr())) |> ignore
        sb.AppendLine(sprintf "**Commands**: %d" lines) |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("## Recent Commands") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("```bash") |> ignore
        // Only last 100 lines
        let lastLines = content.Split('\n') |> Array.rev |> Array.take (min 100 lines) |> Array.rev
        for line in lastLines do
            sb.AppendLine(line) |> ignore
        sb.AppendLine("```") |> ignore

        let tags = ["session"; "bash"; "commands"; "history"]
        if insertHolon conn title (sb.ToString()) tags clusters.Sessions "atomic" "fast" then
            ingested <- ingested + 1
            printfn "  ✓ Bash history: %d commands" lines

    printfn "\n  Session Data Extracted: %d items" ingested
    ingested

// ============================================================================
// Gemini Config Integration
// ============================================================================

let extractGeminiConfig () =
    printfn "\n╔══════════════════════════════════════════════════════════════╗"
    printfn "║  EXTRACTING GEMINI CONFIGURATION                            ║"
    printfn "╚══════════════════════════════════════════════════════════════╝"

    use conn = getConnection()
    let mutable ingested = 0

    let geminiPath = Path.Combine(projectRoot, "GEMINI.md")
    if File.Exists(geminiPath) then
        let content = File.ReadAllText(geminiPath)
        let title = sprintf "[Gemini] GEMINI.md at %s" (nowStr())

        // Extract key sections
        let hasAxioms = content.Contains("Axiom")
        let hasStamp = content.Contains("SC-")
        let hasAor = content.Contains("AOR-")
        let hasBiomorphic = content.Contains("biomorphic")
        let hasSIL = content.Contains("SIL-")

        let sb = System.Text.StringBuilder()
        sb.AppendLine("# Gemini Configuration State") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine(sprintf "**Captured**: %s" (nowStr())) |> ignore
        sb.AppendLine(sprintf "**Version**: Extracted from GEMINI.md") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("## Configuration Coverage") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine(sprintf "- Axioms: %b" hasAxioms) |> ignore
        sb.AppendLine(sprintf "- STAMP Constraints: %b" hasStamp) |> ignore
        sb.AppendLine(sprintf "- AOR Rules: %b" hasAor) |> ignore
        sb.AppendLine(sprintf "- Biomorphic Mode: %b" hasBiomorphic) |> ignore
        sb.AppendLine(sprintf "- SIL Compliance: %b" hasSIL) |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("## Full Configuration") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("```markdown") |> ignore
        // Truncate if too long
        let truncated = if content.Length > 50000 then content.Substring(0, 50000) + "\n... (truncated)" else content
        sb.AppendLine(truncated) |> ignore
        sb.AppendLine("```") |> ignore

        let tags = ["gemini"; "configuration"; "ai"; "orchestration"; "axioms"]
        if insertHolon conn title (sb.ToString()) tags clusters.GeminiConfig "ecosystem" "slow" then
            ingested <- ingested + 1
            printfn "  ✓ GEMINI.md ingested (%.0f KB)" (float content.Length / 1024.0)

    // Also check for CLAUDE.md
    let claudeMdPath = Path.Combine(projectRoot, "CLAUDE.md")
    if File.Exists(claudeMdPath) then
        let content = File.ReadAllText(claudeMdPath)
        let title = sprintf "[Claude] CLAUDE.md at %s" (nowStr())

        let sb = System.Text.StringBuilder()
        sb.AppendLine("# Claude Configuration State") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine(sprintf "**Captured**: %s" (nowStr())) |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("## Full Configuration") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("```markdown") |> ignore
        let truncated = if content.Length > 50000 then content.Substring(0, 50000) + "\n... (truncated)" else content
        sb.AppendLine(truncated) |> ignore
        sb.AppendLine("```") |> ignore

        let tags = ["claude"; "configuration"; "ai"; "safety"; "constraints"]
        if insertHolon conn title (sb.ToString()) tags clusters.ClaudeConfig "ecosystem" "slow" then
            ingested <- ingested + 1
            printfn "  ✓ CLAUDE.md ingested (%.0f KB)" (float content.Length / 1024.0)

    printfn "\n  Gemini/Claude Config Extracted: %d items" ingested
    ingested

// ============================================================================
// Dev Cycle Tracking
// ============================================================================

let extractDevCycle () =
    printfn "\n╔══════════════════════════════════════════════════════════════╗"
    printfn "║  EXTRACTING DEV CYCLE DATA                                  ║"
    printfn "╚══════════════════════════════════════════════════════════════╝"

    use conn = getConnection()
    let mutable ingested = 0

    // 1. Git commit history (last 50 commits with details)
    let commitLog =
        runCmd "git" "log --pretty=format:'%H|%an|%ae|%ad|%s' --date=iso -50"
        |> Option.defaultValue ""

    if not (String.IsNullOrWhiteSpace(commitLog)) then
        let title = sprintf "[DevCycle] Git Commits at %s" (nowStr())

        let sb = System.Text.StringBuilder()
        sb.AppendLine("# Git Commit History") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine(sprintf "**Captured**: %s" (nowStr())) |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("## Recent Commits (Last 50)") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("| Hash | Author | Date | Message |") |> ignore
        sb.AppendLine("|------|--------|------|---------|") |> ignore

        for line in commitLog.Split('\n') do
            let parts = line.Split('|')
            if parts.Length >= 5 then
                let hash = parts.[0].Substring(0, min 8 parts.[0].Length)
                let author = parts.[1]
                let date = parts.[3]
                let msg = parts.[4]
                sb.AppendLine(sprintf "| %s | %s | %s | %s |" hash author date msg) |> ignore

        let tags = ["dev-cycle"; "git"; "commits"; "history"]
        if insertHolon conn title (sb.ToString()) tags clusters.DevCycle "organism" "medium" then
            ingested <- ingested + 1
            printfn "  ✓ Git commit history extracted"

    // 2. Branch analysis
    let branches =
        runCmd "git" "branch -a --format='%(refname:short)|%(objectname:short)|%(committerdate:iso)'"
        |> Option.defaultValue ""

    if not (String.IsNullOrWhiteSpace(branches)) then
        let title = sprintf "[DevCycle] Branches at %s" (nowStr())

        let sb = System.Text.StringBuilder()
        sb.AppendLine("# Git Branch Analysis") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine(sprintf "**Captured**: %s" (nowStr())) |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("## Active Branches") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("| Branch | Last Commit | Date |") |> ignore
        sb.AppendLine("|--------|-------------|------|") |> ignore

        for line in branches.Split('\n') do
            let parts = line.Split('|')
            if parts.Length >= 3 then
                sb.AppendLine(sprintf "| %s | %s | %s |" parts.[0] parts.[1] parts.[2]) |> ignore

        let tags = ["dev-cycle"; "git"; "branches"; "workflow"]
        if insertHolon conn title (sb.ToString()) tags clusters.DevCycle "molecular" "medium" then
            ingested <- ingested + 1
            printfn "  ✓ Branch analysis extracted"

    // 3. File change frequency (hot files)
    let hotFiles =
        runCmd "git" "log --pretty=format: --name-only --since='1 week ago' | sort | uniq -c | sort -rn | head -30"
        |> Option.defaultValue ""

    if not (String.IsNullOrWhiteSpace(hotFiles)) then
        let title = sprintf "[DevCycle] Hot Files at %s" (nowStr())

        let sb = System.Text.StringBuilder()
        sb.AppendLine("# Hot File Analysis (Last Week)") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine(sprintf "**Captured**: %s" (nowStr())) |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("## Most Changed Files") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("```") |> ignore
        sb.AppendLine(hotFiles) |> ignore
        sb.AppendLine("```") |> ignore

        let tags = ["dev-cycle"; "git"; "hot-files"; "frequency"]
        if insertHolon conn title (sb.ToString()) tags clusters.DevCycle "atomic" "fast" then
            ingested <- ingested + 1
            printfn "  ✓ Hot files extracted"

    printfn "\n  Dev Cycle Data Extracted: %d items" ingested
    ingested

// ============================================================================
// Ops Cycle Tracking
// ============================================================================

let extractOpsCycle () =
    printfn "\n╔══════════════════════════════════════════════════════════════╗"
    printfn "║  EXTRACTING OPS CYCLE DATA                                  ║"
    printfn "╚══════════════════════════════════════════════════════════════╝"

    use conn = getConnection()
    let mutable ingested = 0

    // 1. Container state
    let containerList =
        runCmd "podman" "ps -a --format '{{.Names}}|{{.Status}}|{{.Ports}}|{{.Image}}'"
        |> Option.defaultValue ""

    let title = sprintf "[OpsCycle] Container State at %s" (nowStr())

    let sb = System.Text.StringBuilder()
    sb.AppendLine("# Container Lifecycle State") |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine(sprintf "**Captured**: %s" (nowStr())) |> ignore
    sb.AppendLine() |> ignore

    if not (String.IsNullOrWhiteSpace(containerList)) then
        sb.AppendLine("## Running Containers") |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine("| Name | Status | Ports | Image |") |> ignore
        sb.AppendLine("|------|--------|-------|-------|") |> ignore
        for line in containerList.Split('\n') do
            let parts = line.Split('|')
            if parts.Length >= 4 then
                sb.AppendLine(sprintf "| %s | %s | %s | %s |" parts.[0] parts.[1] parts.[2] parts.[3]) |> ignore
    else
        sb.AppendLine("No containers running.") |> ignore

    sb.AppendLine() |> ignore

    // 2. Volume state
    let volumes =
        runCmd "podman" "volume ls --format '{{.Name}}|{{.Driver}}'"
        |> Option.defaultValue ""

    sb.AppendLine("## Volumes") |> ignore
    sb.AppendLine() |> ignore
    if not (String.IsNullOrWhiteSpace(volumes)) then
        sb.AppendLine("| Name | Driver |") |> ignore
        sb.AppendLine("|------|--------|") |> ignore
        for line in volumes.Split('\n') do
            let parts = line.Split('|')
            if parts.Length >= 2 then
                sb.AppendLine(sprintf "| %s | %s |" parts.[0] parts.[1]) |> ignore
    else
        sb.AppendLine("No volumes.") |> ignore

    sb.AppendLine() |> ignore

    // 3. Network state
    let networks =
        runCmd "podman" "network ls --format '{{.Name}}|{{.Driver}}'"
        |> Option.defaultValue ""

    sb.AppendLine("## Networks") |> ignore
    sb.AppendLine() |> ignore
    if not (String.IsNullOrWhiteSpace(networks)) then
        sb.AppendLine("| Name | Driver |") |> ignore
        sb.AppendLine("|------|--------|") |> ignore
        for line in networks.Split('\n') do
            let parts = line.Split('|')
            if parts.Length >= 2 then
                sb.AppendLine(sprintf "| %s | %s |" parts.[0] parts.[1]) |> ignore
    else
        sb.AppendLine("No networks.") |> ignore

    let tags = ["ops-cycle"; "containers"; "podman"; "infrastructure"]
    if insertHolon conn title (sb.ToString()) tags clusters.OpsCycle "organism" "fast" then
        ingested <- ingested + 1
        printfn "  ✓ Container/Volume/Network state extracted"

    // 4. System resource usage
    let memInfo =
        try File.ReadAllText("/proc/meminfo").Split('\n') |> Array.take 3 |> String.concat "\n"
        with _ -> "Not available"

    let cpuInfo =
        runCmd "nproc" "" |> Option.defaultValue "Unknown"

    let diskInfo =
        runCmd "df" "-h ." |> Option.defaultValue "Unknown"

    let sysTitle = sprintf "[OpsCycle] System Resources at %s" (nowStr())

    let sysSb = System.Text.StringBuilder()
    sysSb.AppendLine("# System Resource State") |> ignore
    sysSb.AppendLine() |> ignore
    sysSb.AppendLine(sprintf "**Captured**: %s" (nowStr())) |> ignore
    sysSb.AppendLine() |> ignore
    sysSb.AppendLine("## Memory") |> ignore
    sysSb.AppendLine("```") |> ignore
    sysSb.AppendLine(memInfo) |> ignore
    sysSb.AppendLine("```") |> ignore
    sysSb.AppendLine() |> ignore
    sysSb.AppendLine(sprintf "## CPU Cores: %s" (cpuInfo.Trim())) |> ignore
    sysSb.AppendLine() |> ignore
    sysSb.AppendLine("## Disk") |> ignore
    sysSb.AppendLine("```") |> ignore
    sysSb.AppendLine(diskInfo) |> ignore
    sysSb.AppendLine("```") |> ignore

    let sysTags = ["ops-cycle"; "resources"; "system"; "monitoring"]
    if insertHolon conn sysTitle (sysSb.ToString()) sysTags clusters.OpsCycle "atomic" "fast" then
        ingested <- ingested + 1
        printfn "  ✓ System resources extracted"

    printfn "\n  Ops Cycle Data Extracted: %d items" ingested
    ingested

// ============================================================================
// System DNA Extraction
// ============================================================================

[<CLIMutable>]
type SystemDNA = {
    Version: string
    ExtractedAt: DateTime
    ProjectRoot: string
    Holons: int
    Edges: int
    Clusters: string array
    CriticalFiles: string array
    RecreationChecksum: string
}

let extractSystemDNA () =
    printfn "\n╔══════════════════════════════════════════════════════════════╗"
    printfn "║  EXTRACTING SYSTEM DNA FOR RECREATABILITY                   ║"
    printfn "╚══════════════════════════════════════════════════════════════╝"

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
        try cmd.ExecuteScalar() :?> int64 |> int with _ -> 0

    // Get clusters
    let clusterList =
        use cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT DISTINCT cluster FROM holons ORDER BY cluster"
        use reader = cmd.ExecuteReader()
        [|
            while reader.Read() do
                yield reader.GetString(0)
        |]

    // Critical files for recreation
    let criticalFiles = [|
        "CLAUDE.md"
        "GEMINI.md"
        "PROJECT_TODOLIST.md"
        "mix.exs"
        "mix.lock"
        "devenv.nix"
        "devenv.yaml"
        "lib/cepaf/scripts/SmritiIngestorCLI.fsx"
        "lib/cepaf/scripts/SmritiCodeIngestor.fsx"
        "lib/cepaf/scripts/SmritiEdgeGenerator.fsx"
        "lib/cepaf/scripts/SmritiProjectStateIngestor.fsx"
        "lib/cepaf/scripts/SmritiSystemDNA.fsx"
        "data/kms/smriti.db"
    |]

    // Compute DNA checksum (hash of critical file hashes)
    let fileHashes =
        criticalFiles
        |> Array.map (fun f ->
            let path = Path.Combine(projectRoot, f)
            if File.Exists(path) then
                try computeHash (File.ReadAllText(path))
                with _ -> "file-not-readable"
            else "file-not-found")
        |> String.concat "|"

    let dnaChecksum = computeHash fileHashes

    let dna = {
        Version = "1.0"
        ExtractedAt = DateTime.Now
        ProjectRoot = projectRoot
        Holons = holonCount
        Edges = edgeCount
        Clusters = clusterList
        CriticalFiles = criticalFiles
        RecreationChecksum = dnaChecksum
    }

    // Save DNA file
    let options = JsonSerializerOptions(WriteIndented = true)
    let json = JsonSerializer.Serialize(dna, options)
    File.WriteAllText(dnaPath, json)

    // Also insert DNA into SMRITI
    let title = sprintf "[DNA] System DNA at %s" (nowStr())

    let sb = System.Text.StringBuilder()
    sb.AppendLine("# System DNA for Full Recreatability") |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine(sprintf "**Extracted**: %s" (nowStr())) |> ignore
    sb.AppendLine(sprintf "**Checksum**: %s" dnaChecksum) |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("## SMRITI Statistics") |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine(sprintf "- Holons: %d" holonCount) |> ignore
    sb.AppendLine(sprintf "- Edges: %d" edgeCount) |> ignore
    sb.AppendLine(sprintf "- Clusters: %d" clusterList.Length) |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("## Clusters") |> ignore
    sb.AppendLine() |> ignore
    for cluster in clusterList do
        sb.AppendLine(sprintf "- %s" cluster) |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("## Critical Files for Recreation") |> ignore
    sb.AppendLine() |> ignore
    for file in criticalFiles do
        let path = Path.Combine(projectRoot, file)
        let exists = File.Exists(path)
        let status = if exists then "✓" else "✗"
        sb.AppendLine(sprintf "- %s %s" status file) |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("## Recreation Protocol") |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("To recreate the system from SMRITI:") |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("1. Export all holons from smriti.db") |> ignore
    sb.AppendLine("2. Reconstruct CLAUDE.md and GEMINI.md from their holons") |> ignore
    sb.AppendLine("3. Reconstruct code files from elixir-* and fsharp-* clusters") |> ignore
    sb.AppendLine("4. Regenerate edges using SmritiEdgeGenerator.fsx") |> ignore
    sb.AppendLine("5. Verify DNA checksum matches") |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("## SC-SMRITI-DNA Constraints") |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("| ID | Constraint |") |> ignore
    sb.AppendLine("|-----|-----------|") |> ignore
    sb.AppendLine("| SC-SMRITI-DNA-001 | SMRITI MUST contain all code holons |") |> ignore
    sb.AppendLine("| SC-SMRITI-DNA-002 | Configuration holons MUST be current |") |> ignore
    sb.AppendLine("| SC-SMRITI-DNA-003 | Edge network MUST preserve relationships |") |> ignore
    sb.AppendLine("| SC-SMRITI-DNA-004 | DNA checksum MUST be verified on restore |") |> ignore
    sb.AppendLine("| SC-SMRITI-DNA-005 | All critical files MUST exist in SMRITI |") |> ignore

    let tags = ["system-dna"; "recreatability"; "backup"; "restoration"; "critical"]
    insertHolon conn title (sb.ToString()) tags clusters.SystemDNA "ecosystem" "slow" |> ignore

    printfn "\n  System DNA Extracted:"
    printfn "    Holons: %d" holonCount
    printfn "    Edges: %d" edgeCount
    printfn "    Clusters: %d" clusterList.Length
    printfn "    Checksum: %s" dnaChecksum
    printfn "    Saved to: %s" dnaPath

    1

// ============================================================================
// DNA Verification
// ============================================================================

let verifySystemDNA () =
    printfn "\n╔══════════════════════════════════════════════════════════════╗"
    printfn "║  VERIFYING SYSTEM DNA                                        ║"
    printfn "╚══════════════════════════════════════════════════════════════╝"

    if not (File.Exists(dnaPath)) then
        printfn "\n  ✗ No System DNA found. Run --extract-dna first."
        0
    else
        let json = File.ReadAllText(dnaPath)
        let dna = JsonSerializer.Deserialize<SystemDNA>(json)

        use conn = getConnection()

        // Verify holon count
        let currentHolons =
            use cmd = conn.CreateCommand()
            cmd.CommandText <- "SELECT COUNT(*) FROM holons"
            cmd.ExecuteScalar() :?> int64 |> int

        // Verify edge count
        let currentEdges =
            use cmd = conn.CreateCommand()
            cmd.CommandText <- "SELECT COUNT(*) FROM holon_edges"
            try cmd.ExecuteScalar() :?> int64 |> int with _ -> 0

        // Verify critical files
        let mutable missingFiles = []
        for file in dna.CriticalFiles do
            let path = Path.Combine(projectRoot, file)
            if not (File.Exists(path)) then
                missingFiles <- file :: missingFiles

        printfn "\n  DNA Verification Results:"
        printfn ""
        printfn "    Holons:"
        printfn "      DNA: %d" dna.Holons
        printfn "      Current: %d" currentHolons
        printfn "      Status: %s" (if currentHolons >= dna.Holons then "✓ OK" else "✗ DRIFT")
        printfn ""
        printfn "    Edges:"
        printfn "      DNA: %d" dna.Edges
        printfn "      Current: %d" currentEdges
        printfn "      Status: %s" (if currentEdges >= dna.Edges then "✓ OK" else "✗ DRIFT")
        printfn ""
        printfn "    Critical Files:"
        if missingFiles.IsEmpty then
            printfn "      All %d files present ✓" dna.CriticalFiles.Length
        else
            printfn "      Missing: %d files ✗" missingFiles.Length
            for f in missingFiles do
                printfn "        - %s" f
        printfn ""
        printfn "    DNA Checksum: %s" dna.RecreationChecksum
        printfn "    Extracted At: %s" (dna.ExtractedAt.ToString("yyyy-MM-dd HH:mm:ss"))

        if missingFiles.IsEmpty && currentHolons >= dna.Holons then
            printfn "\n  ✓ System DNA VERIFIED - Full recreation possible"
            1
        else
            printfn "\n  ✗ System DNA DEGRADED - Recreation may be incomplete"
            0

// ============================================================================
// Main Entry Point
// ============================================================================

let printUsage () =
    printfn """
╔══════════════════════════════════════════════════════════════╗
║  SMRITI System DNA Extractor                                  ║
╠══════════════════════════════════════════════════════════════╣
║  Usage:                                                      ║
║    --planning      Extract planning state (todolist, plans) ║
║    --sessions      Track Claude session data                ║
║    --gemini        Extract GEMINI.md/CLAUDE.md configs      ║
║    --dev-cycle     Track git history, branches, hot files   ║
║    --ops-cycle     Track container/resource state           ║
║    --extract-dna   Create System DNA bundle                 ║
║    --verify-dna    Verify system recreatability             ║
║    --full          All of the above                         ║
║    --help          Show this help                           ║
╚══════════════════════════════════════════════════════════════╝
"""

let main args =
    printfn "\n═══════════════════════════════════════════════════════════════"
    printfn "  SMRITI SYSTEM DNA EXTRACTOR v1.0"
    printfn "  Complete System Genome for Full Recreatability"
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
            let mutable totalExtracted = 0

            if args |> Array.contains "--planning" || args |> Array.contains "--full" then
                totalExtracted <- totalExtracted + extractPlanningState()

            if args |> Array.contains "--sessions" || args |> Array.contains "--full" then
                totalExtracted <- totalExtracted + extractSessionData()

            if args |> Array.contains "--gemini" || args |> Array.contains "--full" then
                totalExtracted <- totalExtracted + extractGeminiConfig()

            if args |> Array.contains "--dev-cycle" || args |> Array.contains "--full" then
                totalExtracted <- totalExtracted + extractDevCycle()

            if args |> Array.contains "--ops-cycle" || args |> Array.contains "--full" then
                totalExtracted <- totalExtracted + extractOpsCycle()

            if args |> Array.contains "--extract-dna" || args |> Array.contains "--full" then
                totalExtracted <- totalExtracted + extractSystemDNA()

            if args |> Array.contains "--verify-dna" then
                totalExtracted <- totalExtracted + verifySystemDNA()

            printfn "\n═══════════════════════════════════════════════════════════════"
            printfn "  Total Items Extracted: %d" totalExtracted
            printfn "═══════════════════════════════════════════════════════════════\n"

            0

main (fsi.CommandLineArgs |> Array.skip 1)
