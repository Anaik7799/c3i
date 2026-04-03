// =============================================================================
// Constraint Synchronization Engine (Compiled F#)
// =============================================================================
// Purpose:  Authoritative constraint census, gap analysis, reconciliation
//           recommendations, and sync health metrics for Claude agents.
//
// STAMP:    SC-SYNC-DOC-001 to SC-SYNC-DOC-016
// AOR:      AOR-SYNC-DOC-001 to AOR-SYNC-DOC-016
//
// Usage:
//   constraint-sync                    # Dashboard
//   constraint-sync --json             # JSON output
//   constraint-sync --gaps             # Show undocumented families
//   constraint-sync --gaps --json      # Gaps as JSON
//   constraint-sync --reconcile        # Reconciliation plan
//   constraint-sync --inventory        # .claude/ inventory
//   constraint-sync --full             # All of the above
//   constraint-sync --record           # Record sync timestamp
//   constraint-sync --analysis         # Full analysis (info theory, FMEA, STAMP, criticality)
//   constraint-sync --cached           # Read cached last-run results (fast, <1ms)
//
// MANDATE:  Claude agents MUST use this tool (and ONLY this tool) for
//           all constraint sync operations. See .claude/rules/constraint-sync-mandatory.md
// =============================================================================

open System
open System.IO
open System.Text
open System.Text.RegularExpressions
open System.Collections.Generic

// ─────────────────────────────────────────────────────────────────────────────
// Project Root Detection
// ─────────────────────────────────────────────────────────────────────────────

/// Walk up from CWD looking for CLAUDE.md to find project root.
let findProjectRoot () : string =
    let mutable dir = Directory.GetCurrentDirectory()
    while not (String.IsNullOrEmpty dir) && not (File.Exists(Path.Combine(dir, "CLAUDE.md"))) do
        let parent = Path.GetDirectoryName(dir)
        if parent = dir then dir <- null  // filesystem root reached
        else dir <- parent
    if String.IsNullOrEmpty dir then
        // Fallback: CWD (best effort)
        Directory.GetCurrentDirectory()
    else
        dir

// ─────────────────────────────────────────────────────────────────────────────
// Configuration
// ─────────────────────────────────────────────────────────────────────────────

let projectRoot = findProjectRoot ()

let codeDirs = [
    Path.Combine(projectRoot, "lib")
    Path.Combine(projectRoot, "test")
]

let docPaths = [
    Path.Combine(projectRoot, "CLAUDE.md")
    Path.Combine(projectRoot, ".claude", "rules")
]

let claudeDir = Path.Combine(projectRoot, ".claude")
let syncTimestampFile = Path.Combine(claudeDir, "last_constraint_sync")
let syncHistoryFile = Path.Combine(projectRoot, "data", "constraint_sync_history.jsonl")
let analysisCacheFile = Path.Combine(claudeDir, "constraint_sync_cache.json")
let lastReconcileFile = Path.Combine(claudeDir, "last_reconcile_date")

let codeExtensions = set [".ex"; ".exs"; ".fs"; ".fsx"; ".fsproj"]
let docExtensions = set [".md"]

// Noise families to exclude (test sentinels, not real constraints)
let noisePatterns = set [
    "SC-NONEXISTENT"; "SC-UNKNOWN"; "SC-ANOTHER"; "SC-OTHER";
    "SC-MISSING"; "SC-NOT"; "SC-ALL"; "SC-XXX"; "SC-YYY"; "SC-ZZZ";
    "AOR-UNKNOWN"
]

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

type Priority = P0_Safety | P1_Core | P2_Domain | P3_Style

type ConstraintFamily = {
    Prefix: string          // e.g., "SC-HOLON"
    UniqueIds: Set<string>  // e.g., {"SC-HOLON-001", "SC-HOLON-002", ...}
    IdCount: int
    MinId: int
    MaxId: int
    InCode: bool
    InDocs: bool
    Priority: Priority
    ExampleFile: string option
}

type SyncMetrics = {
    Date: string
    ScCodeCount: int
    ScCodeFamilies: int
    ScDocsCount: int
    ScDocsFamilies: int
    ScGap: int
    ScGapPct: float
    ScRatio: float
    AorCodeCount: int
    AorCodeFamilies: int
    AorDocsCount: int
    AorDocsFamilies: int
    AorGap: int
    AorGapPct: float
    AorRatio: float
    RulesCount: int
    AgentsCount: int
    CommandsCount: int
    HooksCount: int
    Health: string
    LastSync: string
}

type ReconciliationItem = {
    Family: string
    Priority: Priority
    IdCount: int
    IdRange: string
    Action: string
    Target: string  // Which file to add to
}

// ─────────────────────────────────────────────────────────────────────────────
// File Discovery
// ─────────────────────────────────────────────────────────────────────────────

let rec findFiles (dir: string) (extensions: Set<string>) : string list =
    if not (Directory.Exists(dir)) then []
    else
        let excludeDirs = set ["_build"; "deps"; "node_modules"; ".git"; ".elixir_ls";
                               ".lexical"; "data"; "priv"; "target"]
        try
            let files =
                Directory.EnumerateFiles(dir, "*", SearchOption.TopDirectoryOnly)
                |> Seq.filter (fun f ->
                    let ext = Path.GetExtension(f).ToLowerInvariant()
                    extensions.Contains(ext))
                |> Seq.toList

            let subdirFiles =
                Directory.EnumerateDirectories(dir)
                |> Seq.filter (fun d ->
                    let name = Path.GetFileName(d)
                    not (excludeDirs.Contains(name)))
                |> Seq.collect (fun d -> findFiles d extensions)
                |> Seq.toList

            files @ subdirFiles
        with
        | :? UnauthorizedAccessException -> []
        | :? DirectoryNotFoundException -> []

// ─────────────────────────────────────────────────────────────────────────────
// Constraint Extraction
// ─────────────────────────────────────────────────────────────────────────────

let constraintIdRegex = Regex(@"(SC|AOR)-[A-Z][A-Z0-9]*-\d{1,3}", RegexOptions.Compiled)
let constraintFamilyRegex = Regex(@"(SC|AOR)-[A-Z][A-Z0-9]*", RegexOptions.Compiled)
let idNumberRegex = Regex(@"-(\d{1,3})$", RegexOptions.Compiled)

let extractConstraints (filePath: string) : (string * string) array =
    try
        let content = File.ReadAllText(filePath)
        constraintIdRegex.Matches(content)
        |> Seq.cast<Match>
        |> Seq.map (fun m -> (m.Value, filePath))
        |> Seq.toArray
    with _ -> Array.empty

let extractFamily (constraintId: string) : string =
    let m = constraintFamilyRegex.Match(constraintId)
    if m.Success then m.Value else constraintId

let extractIdNumber (constraintId: string) : int =
    let m = idNumberRegex.Match(constraintId)
    if m.Success then int m.Groups.[1].Value else 0

let isNoise (family: string) = noisePatterns.Contains(family)

// ─────────────────────────────────────────────────────────────────────────────
// Priority Classification
// ─────────────────────────────────────────────────────────────────────────────

let classifyPriority (family: string) : Priority =
    let upper = family.ToUpperInvariant()
    let safetyKeywords = [
        "SIL"; "IMMUNE"; "CONST"; "PRIME"; "GUARD"; "SAFE"; "SAFETY";
        "DMS"; "WATCHDOG"; "CRASH"; "SIMPLEX"; "ENFORCE"; "SEC"; "NEURO"; "NIF"
    ]
    let coreKeywords = [
        "HOLON"; "REG"; "ZENOH"; "ZEN"; "SYNC"; "BOOT"; "FUNC"; "LOG";
        "FSH"; "SMRITI"; "XHOLON"; "FED"; "CONSENSUS"; "QUORUM"; "HA";
        "STATE"; "VER"; "UTLTS"; "PHICS"; "UCR"; "HASH"; "RECONFIG";
        "ORCH"; "CONSOL"; "OPT"; "SWARM"; "MESH"; "FFI"; "MATH";
        "AGENT"; "FRAC"; "VAL"; "OBS"; "CI"; "GDE"; "HLC"; "IKE"
    ]
    let styleKeywords = [
        "STYLE"; "UNUSED"; "DEPR"; "WARN"; "TYPE"; "MACRO"; "SIG";
        "PIN"; "PIPE"; "ATTR"; "ANON"; "CASE"; "BINARY"; "STRUCT";
        "ACCESS"; "DRY"; "ARCH"; "LOGIC"; "IMPORT"; "MOD"; "SPEC";
        "STR"; "MAP"; "MATCH"; "CLAUSE"; "RECEIVE"; "RAISE"; "TRY";
        "WITH"; "BOOL"; "ATOM"; "SIGIL"; "KWLIST"; "BIN"; "PROC";
        "CB"; "PATTERN"; "COMP"
    ]

    // Extract the domain part after SC- or AOR-
    let domain =
        if upper.StartsWith("SC-") then upper.Substring(3)
        elif upper.StartsWith("AOR-") then upper.Substring(4)
        else upper

    if safetyKeywords |> List.exists (fun kw -> domain.StartsWith(kw)) then P0_Safety
    elif coreKeywords |> List.exists (fun kw -> domain.StartsWith(kw)) then P1_Core
    elif styleKeywords |> List.exists (fun kw -> domain = kw) then P3_Style
    else P2_Domain

let priorityToString = function
    | P0_Safety -> "P0-SAFETY"
    | P1_Core -> "P1-CORE"
    | P2_Domain -> "P2-DOMAIN"
    | P3_Style -> "P3-STYLE"

let priorityToInt = function
    | P0_Safety -> 0
    | P1_Core -> 1
    | P2_Domain -> 2
    | P3_Style -> 3

// ─────────────────────────────────────────────────────────────────────────────
// Census Engine (with parallel file I/O)
// ─────────────────────────────────────────────────────────────────────────────

type CensusResult = {
    CodeConstraints: Map<string, Set<string>>           // family -> set of full IDs
    DocsConstraints: Map<string, Set<string>>
    CodeExamples: Map<string, string>                   // family -> example file
    UndocumentedFamilies: ConstraintFamily list
    DocOnlyFamilies: ConstraintFamily list
    AllFamilies: ConstraintFamily list
}

let runCensus (constraintType: string) : CensusResult =
    // Collect from code — parallel file reading
    let codeFiles =
        codeDirs
        |> List.collect (fun d -> findFiles d codeExtensions)
        |> Array.ofList

    let codeHits =
        codeFiles
        |> Array.Parallel.collect extractConstraints
        |> Array.filter (fun (id, _) ->
            id.StartsWith(constraintType + "-") &&
            not (isNoise (extractFamily id)))

    let codeById =
        codeHits
        |> Array.map fst
        |> Set.ofArray

    let codeByFamily =
        codeHits
        |> Array.groupBy (fun (id, _) -> extractFamily id)
        |> Array.map (fun (fam, hits) -> fam, hits |> Array.map fst |> Set.ofArray)
        |> Map.ofArray

    let codeExamples =
        codeHits
        |> Array.groupBy (fun (id, _) -> extractFamily id)
        |> Array.map (fun (fam, hits) ->
            let exFile = hits.[0] |> snd
            let relPath =
                if exFile.StartsWith(projectRoot) then
                    exFile.Substring(projectRoot.Length + 1)
                else exFile
            fam, relPath)
        |> Map.ofArray

    // Collect from docs — parallel file reading
    let docFiles =
        docPaths
        |> List.collect (fun p ->
            if File.Exists(p) then [p]
            elif Directory.Exists(p) then findFiles p docExtensions
            else [])
        |> Array.ofList

    let docsHits =
        docFiles
        |> Array.Parallel.collect extractConstraints
        |> Array.filter (fun (id, _) ->
            id.StartsWith(constraintType + "-") &&
            not (isNoise (extractFamily id)))

    let docsByFamily =
        docsHits
        |> Array.groupBy (fun (id, _) -> extractFamily id)
        |> Array.map (fun (fam, hits) -> fam, hits |> Array.map fst |> Set.ofArray)
        |> Map.ofArray

    // Build family records
    let allFamilyNames =
        Set.union
            (codeByFamily |> Map.keys |> Set.ofSeq)
            (docsByFamily |> Map.keys |> Set.ofSeq)

    let allFamilies =
        allFamilyNames
        |> Set.toList
        |> List.map (fun fam ->
            let codeIds = codeByFamily |> Map.tryFind fam |> Option.defaultValue Set.empty
            let docsIds = docsByFamily |> Map.tryFind fam |> Option.defaultValue Set.empty
            let allIds = Set.union codeIds docsIds
            let idNumbers = allIds |> Set.map extractIdNumber |> Set.toList
            let minId = if idNumbers.IsEmpty then 0 else List.min idNumbers
            let maxId = if idNumbers.IsEmpty then 0 else List.max idNumbers
            {
                Prefix = fam
                UniqueIds = allIds
                IdCount = allIds.Count
                MinId = minId
                MaxId = maxId
                InCode = not codeIds.IsEmpty
                InDocs = not docsIds.IsEmpty
                Priority = classifyPriority fam
                ExampleFile = codeExamples |> Map.tryFind fam
            })
        |> List.sortBy (fun f -> (priorityToInt f.Priority, -f.IdCount))

    let undocumented =
        allFamilies |> List.filter (fun f -> f.InCode && not f.InDocs)

    let docOnly =
        allFamilies |> List.filter (fun f -> f.InDocs && not f.InCode)

    {
        CodeConstraints = codeByFamily
        DocsConstraints = docsByFamily
        CodeExamples = codeExamples
        UndocumentedFamilies = undocumented
        DocOnlyFamilies = docOnly
        AllFamilies = allFamilies
    }

// ─────────────────────────────────────────────────────────────────────────────
// .claude/ Inventory
// ─────────────────────────────────────────────────────────────────────────────

type ClaudeInventory = {
    Rules: string list
    Agents: string list
    Commands: string list
    Hooks: string list
}

let getClaudeInventory () : ClaudeInventory =
    let listDir subdir ext =
        let dir = Path.Combine(claudeDir, subdir)
        if Directory.Exists(dir) then
            Directory.GetFiles(dir, $"*{ext}")
            |> Array.map Path.GetFileNameWithoutExtension
            |> Array.sort
            |> Array.toList
        else []

    let hooks =
        let dir = Path.Combine(claudeDir, "hooks")
        if Directory.Exists(dir) then
            Directory.GetFiles(dir)
            |> Array.map Path.GetFileName
            |> Array.sort
            |> Array.toList
        else []

    {
        Rules = listDir "rules" ".md"
        Agents = listDir "agents" ".md"
        Commands = listDir "commands" ".md"
        Hooks = hooks
    }

// ─────────────────────────────────────────────────────────────────────────────
// Health Assessment
// ─────────────────────────────────────────────────────────────────────────────

let assessHealth (scRatio: float) (aorRatio: float) : string =
    let maxRatio = max scRatio aorRatio
    if maxRatio <= 1.5 then "HEALTHY"
    elif maxRatio <= 5.0 then "DEGRADED"
    else "CRITICAL"

let computeMetrics (scCensus: CensusResult) (aorCensus: CensusResult) : SyncMetrics =
    let scCodeCount = scCensus.CodeConstraints |> Map.values |> Seq.sumBy Set.count
    let scDocsCount = scCensus.DocsConstraints |> Map.values |> Seq.sumBy Set.count
    let scCodeFamilies = scCensus.CodeConstraints.Count
    let scDocsFamilies = scCensus.DocsConstraints.Count
    let scGap = max 0 (scCodeCount - scDocsCount)
    let scGapPct = if scCodeCount > 0 then (float scGap / float scCodeCount) * 100.0 else 0.0
    let scRatio = if scDocsCount > 0 then float scCodeCount / float scDocsCount else 999.0

    let aorCodeCount = aorCensus.CodeConstraints |> Map.values |> Seq.sumBy Set.count
    let aorDocsCount = aorCensus.DocsConstraints |> Map.values |> Seq.sumBy Set.count
    let aorCodeFamilies = aorCensus.CodeConstraints.Count
    let aorDocsFamilies = aorCensus.DocsConstraints.Count
    let aorGap = max 0 (aorCodeCount - aorDocsCount)
    let aorGapPct = if aorCodeCount > 0 then (float aorGap / float aorCodeCount) * 100.0 else 0.0
    let aorRatio = if aorDocsCount > 0 then float aorCodeCount / float aorDocsCount else 999.0

    let inv = getClaudeInventory ()
    let lastSync =
        if File.Exists(syncTimestampFile) then
            try File.ReadAllText(syncTimestampFile).Trim()
            with _ -> "never"
        else "never"

    {
        Date = DateTime.Now.ToString("yyyy-MM-dd")
        ScCodeCount = scCodeCount
        ScCodeFamilies = scCodeFamilies
        ScDocsCount = scDocsCount
        ScDocsFamilies = scDocsFamilies
        ScGap = scGap
        ScGapPct = Math.Round(scGapPct, 1)
        ScRatio = Math.Round(scRatio, 1)
        AorCodeCount = aorCodeCount
        AorCodeFamilies = aorCodeFamilies
        AorDocsCount = aorDocsCount
        AorDocsFamilies = aorDocsFamilies
        AorGap = aorGap
        AorGapPct = Math.Round(aorGapPct, 1)
        AorRatio = Math.Round(aorRatio, 1)
        RulesCount = inv.Rules.Length
        AgentsCount = inv.Agents.Length
        CommandsCount = inv.Commands.Length
        HooksCount = inv.Hooks.Length
        Health = assessHealth scRatio aorRatio
        LastSync = lastSync
    }

// ─────────────────────────────────────────────────────────────────────────────
// Reconciliation Plan
// ─────────────────────────────────────────────────────────────────────────────

let generateReconciliationPlan (scCensus: CensusResult) (aorCensus: CensusResult) : ReconciliationItem list =
    let items = ResizeArray<ReconciliationItem>()

    let addItems (census: CensusResult) =
        for family in census.UndocumentedFamilies do
            let target =
                match family.Priority with
                | P0_Safety -> "CLAUDE.md §5.0 (Safety Constraints)"
                | P1_Core -> "CLAUDE.md §5.0 (Core Constraints)"
                | P2_Domain ->
                    let domain = family.Prefix.Replace("SC-", "").Replace("AOR-", "").ToLowerInvariant()
                    $".claude/rules/{domain}.md or CLAUDE.md §5.0"
                | P3_Style -> ".claude/rules/fsharp-validation.md"

            let idRange =
                if family.MinId = family.MaxId then $"{family.MinId:D3}"
                else $"{family.MinId:D3}–{family.MaxId:D3}"

            items.Add({
                Family = family.Prefix
                Priority = family.Priority
                IdCount = family.IdCount
                IdRange = idRange
                Action = $"Add {family.Prefix}-{idRange} ({family.IdCount} IDs)"
                Target = target
            })

    addItems scCensus
    addItems aorCensus

    items
    |> Seq.toList
    |> List.sortBy (fun i -> (priorityToInt i.Priority, -i.IdCount))

// ─────────────────────────────────────────────────────────────────────────────
// Output Formatters
// ─────────────────────────────────────────────────────────────────────────────

let escapeJson (s: string) =
    s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\n", "\\n")

let printDashboard (m: SyncMetrics) =
    printfn "CONSTRAINT SYNC STATUS (SC-SYNC-DOC)          [%s]" m.Date
    printfn "  SC-* Constraints:"
    printfn "    Code:     %d unique across %d families" m.ScCodeCount m.ScCodeFamilies
    printfn "    Docs:     %d unique across %d families" m.ScDocsCount m.ScDocsFamilies
    printfn "    Gap:      %d undocumented (%.1f%%)" m.ScGap m.ScGapPct
    printfn "    Ratio:    %.1f:1 (target: 1.0:1)" m.ScRatio
    printfn "  AOR-* Rules:"
    printfn "    Code:     %d unique across %d families" m.AorCodeCount m.AorCodeFamilies
    printfn "    Docs:     %d unique across %d families" m.AorDocsCount m.AorDocsFamilies
    printfn "    Gap:      %d undocumented (%.1f%%)" m.AorGap m.AorGapPct
    printfn "    Ratio:    %.1f:1 (target: 1.0:1)" m.AorRatio
    printfn "  .claude/ Inventory:"
    printfn "    Rules:    %d files | Agents: %d | Commands: %d | Hooks: %d" m.RulesCount m.AgentsCount m.CommandsCount m.HooksCount
    printfn "  Sync Health: %s | Last Full Sync: %s" m.Health m.LastSync

let printGaps (scCensus: CensusResult) (aorCensus: CensusResult) =
    let printFamilyTable (title: string) (families: ConstraintFamily list) =
        if families.IsEmpty then
            printfn "  (none)"
        else
            printfn ""
            printfn "  %s (%d families):" title (families.Length)
            printfn "  %-20s %-10s %-12s %-12s %s" "Family" "IDs" "Range" "Priority" "Example File"
            printfn "  %-20s %-10s %-12s %-12s %s" (String.replicate 20 "-") (String.replicate 10 "-") (String.replicate 12 "-") (String.replicate 12 "-") (String.replicate 40 "-")
            for f in families do
                let range =
                    if f.MinId = f.MaxId then $"{f.MinId:D3}"
                    else $"{f.MinId:D3}-{f.MaxId:D3}"
                let example = f.ExampleFile |> Option.defaultValue "—"
                let shortExample =
                    if example.Length > 40 then "..." + example.Substring(example.Length - 37)
                    else example
                printfn "  %-20s %-10d %-12s %-12s %s" f.Prefix f.IdCount range (priorityToString f.Priority) shortExample

    printfn ""
    printfn "UNDOCUMENTED CONSTRAINT FAMILIES (in code, not in CLAUDE.md)"
    printfn "============================================================"

    // Group by priority
    let scByPriority = scCensus.UndocumentedFamilies |> List.groupBy (fun f -> f.Priority)
    let aorByPriority = aorCensus.UndocumentedFamilies |> List.groupBy (fun f -> f.Priority)

    for priority in [P0_Safety; P1_Core; P2_Domain; P3_Style] do
        let scFams = scByPriority |> List.tryFind (fun (p,_) -> p = priority) |> Option.map snd |> Option.defaultValue []
        let aorFams = aorByPriority |> List.tryFind (fun (p,_) -> p = priority) |> Option.map snd |> Option.defaultValue []
        let allFams = (scFams @ aorFams) |> List.sortByDescending (fun f -> f.IdCount)
        if not allFams.IsEmpty then
            printFamilyTable (priorityToString priority) allFams

    // Summary
    let totalSc = scCensus.UndocumentedFamilies.Length
    let totalAor = aorCensus.UndocumentedFamilies.Length
    let totalScIds = scCensus.UndocumentedFamilies |> List.sumBy (fun f -> f.IdCount)
    let totalAorIds = aorCensus.UndocumentedFamilies |> List.sumBy (fun f -> f.IdCount)
    printfn ""
    printfn "  TOTAL: %d undocumented families (%d SC-* + %d AOR-*), %d undocumented IDs (%d SC-* + %d AOR-*)"
        (totalSc + totalAor) totalSc totalAor (totalScIds + totalAorIds) totalScIds totalAorIds

let printReconciliationPlan (plan: ReconciliationItem list) =
    printfn ""
    printfn "RECONCILIATION PLAN"
    printfn "==================="
    printfn ""

    let byPriority = plan |> List.groupBy (fun i -> i.Priority)
    for priority in [P0_Safety; P1_Core; P2_Domain; P3_Style] do
        let items = byPriority |> List.tryFind (fun (p,_) -> p = priority) |> Option.map snd |> Option.defaultValue []
        if not items.IsEmpty then
            printfn "  %s (%d items, %d total IDs):" (priorityToString priority) items.Length (items |> List.sumBy (fun i -> i.IdCount))
            for item in items |> List.take (min 20 items.Length) do
                printfn "    [%s] %s -> %s" (priorityToString item.Priority) item.Action item.Target
            if items.Length > 20 then
                printfn "    ... and %d more" (items.Length - 20)
            printfn ""

    printfn "  EXECUTION ORDER:"
    printfn "    1. Add P0-SAFETY families to CLAUDE.md §5.0 first"
    printfn "    2. Add P1-CORE families to CLAUDE.md §5.0"
    printfn "    3. Add P2-DOMAIN families to domain-specific .claude/rules/ files"
    printfn "    4. Add P3-STYLE families to .claude/rules/fsharp-validation.md"
    printfn "    5. Run this tool with --record to update sync timestamp"

let printInventory (inv: ClaudeInventory) =
    printfn ""
    printfn ".claude/ DIRECTORY INVENTORY"
    printfn "==========================="
    printfn ""
    printfn "  Rules (%d):" inv.Rules.Length
    for r in inv.Rules do printfn "    - %s.md" r
    printfn ""
    printfn "  Agents (%d):" inv.Agents.Length
    for a in inv.Agents do printfn "    - %s.md" a
    printfn ""
    printfn "  Commands (%d):" inv.Commands.Length
    for c in inv.Commands do printfn "    - %s.md" c
    printfn ""
    printfn "  Hooks (%d):" inv.Hooks.Length
    for h in inv.Hooks do printfn "    - %s" h

// ─────────────────────────────────────────────────────────────────────────────
// Information Theory Analysis
// ─────────────────────────────────────────────────────────────────────────────

/// Shannon entropy: H(X) = -Σ p(x) log₂ p(x)
let shannonEntropy (distribution: float list) : float =
    distribution
    |> List.filter (fun p -> p > 0.0)
    |> List.sumBy (fun p -> -p * Math.Log(p, 2.0))

/// KL Divergence: D_KL(P||Q) = Σ P(x) log₂(P(x)/Q(x))
let klDivergence (p: float list) (q: float list) : float =
    List.zip p q
    |> List.filter (fun (pi, qi) -> pi > 0.0 && qi > 0.0)
    |> List.sumBy (fun (pi, qi) -> pi * Math.Log(pi / qi, 2.0))

/// Cross-entropy: H(P,Q) = -Σ P(x) log₂ Q(x)
let crossEntropy (p: float list) (q: float list) : float =
    List.zip p q
    |> List.filter (fun (_, qi) -> qi > 0.0)
    |> List.sumBy (fun (pi, qi) -> -pi * Math.Log(qi, 2.0))

type InfoTheoryMetrics = {
    CodeEntropy: float          // H(code distribution across families)
    DocsEntropy: float          // H(docs distribution across families)
    CrossEntropy: float         // H(code, docs) — cost of encoding code with docs model
    KLDivergence: float         // D_KL(code || docs) — divergence of docs from code
    MutualInformation: float    // I(code; docs) = H(code) + H(docs) - H(code,docs)
    CoverageRatio: float        // |documented families| / |total families|
    ConstraintDensity: float    // constraints per file
    DocumentationDebt: float    // weighted gap score (P0=16x, P1=8x, P2=4x, P3=1x)
}

let computeInfoTheory (scCensus: CensusResult) (aorCensus: CensusResult) : InfoTheoryMetrics =
    let allFamilies = scCensus.AllFamilies @ aorCensus.AllFamilies
    if allFamilies.IsEmpty then
        { CodeEntropy = 0.0; DocsEntropy = 0.0; CrossEntropy = 0.0;
          KLDivergence = 0.0; MutualInformation = 0.0; CoverageRatio = 0.0;
          ConstraintDensity = 0.0; DocumentationDebt = 0.0 }
    else

    // Build probability distributions over families
    let totalCodeIds = allFamilies |> List.sumBy (fun f -> if f.InCode then f.IdCount else 0) |> float
    let totalDocsIds = allFamilies |> List.sumBy (fun f -> if f.InDocs then f.IdCount else 0) |> float

    let epsilon = 1e-10  // Laplace smoothing to avoid log(0)

    let codeDist =
        allFamilies
        |> List.map (fun f ->
            if totalCodeIds > 0.0 then
                (float (if f.InCode then f.IdCount else 0) + epsilon) / (totalCodeIds + epsilon * float allFamilies.Length)
            else epsilon)

    let docsDist =
        allFamilies
        |> List.map (fun f ->
            if totalDocsIds > 0.0 then
                (float (if f.InDocs then f.IdCount else 0) + epsilon) / (totalDocsIds + epsilon * float allFamilies.Length)
            else epsilon)

    let hCode = shannonEntropy codeDist
    let hDocs = shannonEntropy docsDist
    let hCross = crossEntropy codeDist docsDist
    let dKL = klDivergence codeDist docsDist

    // Coverage ratio
    let totalFamilies = allFamilies.Length |> float
    let documentedFamilies = allFamilies |> List.filter (fun f -> f.InDocs) |> List.length |> float
    let coverage = if totalFamilies > 0.0 then documentedFamilies / totalFamilies else 0.0

    // Constraint density (code constraints per code file scanned)
    let codeFileCount =
        codeDirs
        |> List.collect (fun d -> findFiles d codeExtensions)
        |> List.length |> float
    let totalConstraints = totalCodeIds
    let density = if codeFileCount > 0.0 then totalConstraints / codeFileCount else 0.0

    // Documentation debt = priority-weighted sum of undocumented IDs
    let priorityWeight = function
        | P0_Safety -> 16.0
        | P1_Core -> 8.0
        | P2_Domain -> 4.0
        | P3_Style -> 1.0

    let debt =
        allFamilies
        |> List.filter (fun f -> f.InCode && not f.InDocs)
        |> List.sumBy (fun f -> float f.IdCount * priorityWeight f.Priority)

    { CodeEntropy = Math.Round(hCode, 4)
      DocsEntropy = Math.Round(hDocs, 4)
      CrossEntropy = Math.Round(hCross, 4)
      KLDivergence = Math.Round(dKL, 4)
      MutualInformation = Math.Round(max 0.0 (hCode + hDocs - hCross), 4)
      CoverageRatio = Math.Round(coverage, 4)
      ConstraintDensity = Math.Round(density, 2)
      DocumentationDebt = Math.Round(debt, 0) }

// ─────────────────────────────────────────────────────────────────────────────
// FMEA Analysis (Failure Mode and Effects Analysis)
// ─────────────────────────────────────────────────────────────────────────────

type FmeaEntry = {
    Family: string
    FailureMode: string
    Severity: int          // 1-10
    Occurrence: int        // 1-10
    Detection: int         // 1-10 (higher = harder to detect)
    RPN: int               // Risk Priority Number = S × O × D
    Priority: Priority
    Mitigation: string
}

let computeFmea (scCensus: CensusResult) (aorCensus: CensusResult) : FmeaEntry list =
    let allUndoc = scCensus.UndocumentedFamilies @ aorCensus.UndocumentedFamilies

    allUndoc
    |> List.map (fun f ->
        let severity = match f.Priority with P0_Safety -> 9 | P1_Core -> 7 | P2_Domain -> 5 | P3_Style -> 3
        let occurrence =
            if f.IdCount >= 20 then 8
            elif f.IdCount >= 10 then 6
            elif f.IdCount >= 5 then 4
            else 2
        let detection = match f.Priority with P0_Safety -> 9 | P1_Core -> 7 | P2_Domain -> 5 | P3_Style -> 3
        let rpn = severity * occurrence * detection
        let failureMode = $"Undocumented {f.Prefix} ({f.IdCount} IDs) — constraint violations may go unnoticed"
        let mitigation =
            match f.Priority with
            | P0_Safety -> $"IMMEDIATE: Add {f.Prefix} to CLAUDE.md §5.0 and .claude/rules/reconciled-p0-safety.md"
            | P1_Core -> $"HIGH: Add {f.Prefix} to CLAUDE.md §5.0 and .claude/rules/reconciled-p1-core.md"
            | P2_Domain -> $"MEDIUM: Add {f.Prefix} to .claude/rules/ domain file"
            | P3_Style -> $"LOW: Add {f.Prefix} to .claude/rules/fsharp-validation.md"

        { Family = f.Prefix; FailureMode = failureMode; Severity = severity;
          Occurrence = occurrence; Detection = detection; RPN = rpn;
          Priority = f.Priority; Mitigation = mitigation })
    |> List.sortByDescending (fun e -> e.RPN)

// ─────────────────────────────────────────────────────────────────────────────
// STAMP Control Structure Analysis
// ─────────────────────────────────────────────────────────────────────────────

type StampAnalysis = {
    ControlActions: int
    FeedbackLoops: int
    UnsafeControlActions: int
    MissingFeedback: int
    ControlStructureCompleteness: float
    SafetyGapByPriority: Map<Priority, int * int>
    TopUnsafeControlActions: string list
}

let computeStamp (scCensus: CensusResult) (aorCensus: CensusResult) (metrics: SyncMetrics) : StampAnalysis =
    let safetyGaps =
        [P0_Safety; P1_Core; P2_Domain; P3_Style]
        |> List.map (fun p ->
            let scFams = scCensus.UndocumentedFamilies |> List.filter (fun f -> f.Priority = p)
            let aorFams = aorCensus.UndocumentedFamilies |> List.filter (fun f -> f.Priority = p)
            let totalFams = scFams.Length + aorFams.Length
            let totalIds = (scFams |> List.sumBy (fun f -> f.IdCount)) + (aorFams |> List.sumBy (fun f -> f.IdCount))
            p, (totalFams, totalIds))
        |> Map.ofList

    let topUnsafe =
        (scCensus.UndocumentedFamilies @ aorCensus.UndocumentedFamilies)
        |> List.filter (fun f -> f.Priority = P0_Safety || f.Priority = P1_Core)
        |> List.sortByDescending (fun f -> f.IdCount)
        |> List.truncate 10
        |> List.map (fun f -> $"{f.Prefix} ({f.IdCount} IDs, {priorityToString f.Priority})")

    { ControlActions = metrics.ScCodeCount
      FeedbackLoops = metrics.AorCodeCount
      UnsafeControlActions = metrics.ScGap
      MissingFeedback = metrics.AorGap
      ControlStructureCompleteness =
        let total = float (metrics.ScCodeCount + metrics.AorCodeCount)
        let documented = float (metrics.ScDocsCount + metrics.AorDocsCount)
        if total > 0.0 then Math.Round(documented / total, 4) else 0.0
      SafetyGapByPriority = safetyGaps
      TopUnsafeControlActions = topUnsafe }

// ─────────────────────────────────────────────────────────────────────────────
// Criticality & Operational Analysis
// ─────────────────────────────────────────────────────────────────────────────

type CriticalityAnalysis = {
    OverallRiskScore: float
    CriticalFamiliesAtRisk: int
    HighFamiliesAtRisk: int
    MeanRPN: float
    MaxRPN: int
    P0Coverage: float
    P1Coverage: float
    EstimatedRemediationEffort: string
    TrendDirection: string
}

let computeCriticality (scCensus: CensusResult) (aorCensus: CensusResult)
                       (fmea: FmeaEntry list) (metrics: SyncMetrics) : CriticalityAnalysis =
    let allFamilies = scCensus.AllFamilies @ aorCensus.AllFamilies

    let p0Total = allFamilies |> List.filter (fun f -> f.Priority = P0_Safety) |> List.length |> float
    let p0Documented = allFamilies |> List.filter (fun f -> f.Priority = P0_Safety && f.InDocs) |> List.length |> float
    let p1Total = allFamilies |> List.filter (fun f -> f.Priority = P1_Core) |> List.length |> float
    let p1Documented = allFamilies |> List.filter (fun f -> f.Priority = P1_Core && f.InDocs) |> List.length |> float

    let p0Cov = if p0Total > 0.0 then p0Documented / p0Total else 1.0
    let p1Cov = if p1Total > 0.0 then p1Documented / p1Total else 1.0

    let meanRpn = if fmea.IsEmpty then 0.0 else fmea |> List.averageBy (fun e -> float e.RPN)
    let maxRpn = if fmea.IsEmpty then 0 else fmea |> List.map (fun e -> e.RPN) |> List.max

    let riskScore =
        (1.0 - p0Cov) * 40.0 +
        (1.0 - p1Cov) * 30.0 +
        (float metrics.ScGapPct / 100.0) * 20.0 +
        (float metrics.AorGapPct / 100.0) * 10.0

    let trend =
        if File.Exists(syncHistoryFile) then
            let lines = File.ReadAllLines(syncHistoryFile)
            if lines.Length >= 2 then
                let lastLine = lines.[lines.Length - 1]
                let prevLine = lines.[lines.Length - 2]
                let extractRatio (line: string) =
                    let m = Regex.Match(line, @"""sc_ratio"":(\d+\.?\d*)")
                    if m.Success then float m.Groups.[1].Value else 999.0
                let lastRatio = extractRatio lastLine
                let prevRatio = extractRatio prevLine
                if lastRatio < prevRatio - 0.1 then "IMPROVING"
                elif lastRatio > prevRatio + 0.1 then "DEGRADING"
                else "STABLE"
            else "UNKNOWN"
        else "UNKNOWN"

    let undocP0 = allFamilies |> List.filter (fun f -> f.Priority = P0_Safety && f.InCode && not f.InDocs) |> List.length
    let undocP1 = allFamilies |> List.filter (fun f -> f.Priority = P1_Core && f.InCode && not f.InDocs) |> List.length

    let effort =
        let totalUndocIds =
            allFamilies
            |> List.filter (fun f -> f.InCode && not f.InDocs)
            |> List.sumBy (fun f -> f.IdCount)
        if totalUndocIds > 1000 then "LARGE (multiple sessions, 4+ hours)"
        elif totalUndocIds > 200 then "MEDIUM (1-2 sessions, 2-4 hours)"
        elif totalUndocIds > 50 then "SMALL (single session, 1-2 hours)"
        else "MINIMAL (< 1 hour)"

    { OverallRiskScore = Math.Round(riskScore, 1)
      CriticalFamiliesAtRisk = undocP0
      HighFamiliesAtRisk = undocP1
      MeanRPN = Math.Round(meanRpn, 0)
      MaxRPN = maxRpn
      P0Coverage = Math.Round(p0Cov * 100.0, 1)
      P1Coverage = Math.Round(p1Cov * 100.0, 1)
      EstimatedRemediationEffort = effort
      TrendDirection = trend }

// ─────────────────────────────────────────────────────────────────────────────
// Analysis Output
// ─────────────────────────────────────────────────────────────────────────────

let printAnalysis (info: InfoTheoryMetrics) (fmea: FmeaEntry list) (stamp: StampAnalysis) (crit: CriticalityAnalysis) =
    printfn ""
    printfn "╔═══════════════════════════════════════════════════════════════╗"
    printfn "║  COMPREHENSIVE CONSTRAINT SYNC ANALYSIS                      ║"
    printfn "╚═══════════════════════════════════════════════════════════════╝"

    printfn ""
    printfn "┌─── INFORMATION THEORY ─────────────────────────────────────────"
    printfn "│  H(code)  = %.4f bits  (entropy of code constraint distribution)" info.CodeEntropy
    printfn "│  H(docs)  = %.4f bits  (entropy of docs constraint distribution)" info.DocsEntropy
    printfn "│  H(P,Q)   = %.4f bits  (cross-entropy: code→docs model cost)" info.CrossEntropy
    printfn "│  D_KL     = %.4f bits  (KL divergence: code║docs)" info.KLDivergence
    printfn "│  I(X;Y)   = %.4f bits  (mutual information: code↔docs)" info.MutualInformation
    printfn "│  Coverage = %.1f%%       (families documented / total)" (info.CoverageRatio * 100.0)
    printfn "│  Density  = %.2f        (constraints per source file)" info.ConstraintDensity
    printfn "│  Doc Debt = %.0f        (priority-weighted gap score)" info.DocumentationDebt
    let debtGrade =
        if info.DocumentationDebt < 500.0 then "A (Low risk)"
        elif info.DocumentationDebt < 2000.0 then "B (Moderate)"
        elif info.DocumentationDebt < 5000.0 then "C (Significant)"
        elif info.DocumentationDebt < 10000.0 then "D (Critical)"
        else "F (Extreme)"
    printfn "│  Grade    = %s" debtGrade
    printfn "└─────────────────────────────────────────────────────────────────"

    printfn ""
    printfn "┌─── STAMP CONTROL STRUCTURE ────────────────────────────────────"
    printfn "│  Control Actions (SC-*):   %d total, %d undocumented" stamp.ControlActions stamp.UnsafeControlActions
    printfn "│  Feedback Loops (AOR-*):   %d total, %d missing" stamp.FeedbackLoops stamp.MissingFeedback
    printfn "│  Completeness:             %.1f%%" (stamp.ControlStructureCompleteness * 100.0)
    printfn "│"
    printfn "│  Safety Gap by Priority:"
    for p in [P0_Safety; P1_Core; P2_Domain; P3_Style] do
        match stamp.SafetyGapByPriority |> Map.tryFind p with
        | Some (fams, ids) when fams > 0 ->
            printfn "│    %s: %d families, %d IDs undocumented" (priorityToString p) fams ids
        | _ ->
            printfn "│    %s: ✓ fully documented" (priorityToString p)
    printfn "│"
    if not stamp.TopUnsafeControlActions.IsEmpty then
        printfn "│  Top Unsafe Control Actions (Undocumented P0/P1):"
        for action in stamp.TopUnsafeControlActions |> List.take (min 5 stamp.TopUnsafeControlActions.Length) do
            printfn "│    ⚠ %s" action
    printfn "└─────────────────────────────────────────────────────────────────"

    printfn ""
    printfn "┌─── FMEA TOP 10 (by RPN) ──────────────────────────────────────"
    printfn "│  %-16s  S   O   D   RPN   Priority" "Family"
    printfn "│  %-16s  ─── ─── ─── ───── ────────" (String.replicate 16 "─")
    for entry in fmea |> List.take (min 10 fmea.Length) do
        printfn "│  %-16s  %d   %d   %d   %-5d %s" entry.Family entry.Severity entry.Occurrence entry.Detection entry.RPN (priorityToString entry.Priority)
    if fmea.Length > 10 then
        printfn "│  ... and %d more families" (fmea.Length - 10)
    printfn "│"
    printfn "│  Mean RPN: %.0f | Max RPN: %d | Total entries: %d" crit.MeanRPN crit.MaxRPN fmea.Length
    let rpnAbove200 = fmea |> List.filter (fun e -> e.RPN >= 200) |> List.length
    let rpnAbove100 = fmea |> List.filter (fun e -> e.RPN >= 100) |> List.length
    printfn "│  RPN ≥ 200: %d (critical) | RPN ≥ 100: %d (high)" rpnAbove200 rpnAbove100
    printfn "└─────────────────────────────────────────────────────────────────"

    printfn ""
    printfn "┌─── CRITICALITY & OPERATIONAL ──────────────────────────────────"
    printfn "│  Overall Risk Score:  %.1f / 100" crit.OverallRiskScore
    let riskLevel =
        if crit.OverallRiskScore < 20.0 then "LOW"
        elif crit.OverallRiskScore < 40.0 then "MODERATE"
        elif crit.OverallRiskScore < 60.0 then "HIGH"
        else "CRITICAL"
    printfn "│  Risk Level:          %s" riskLevel
    printfn "│  P0 Coverage:         %.1f%% (%d families at risk)" crit.P0Coverage crit.CriticalFamiliesAtRisk
    printfn "│  P1 Coverage:         %.1f%% (%d families at risk)" crit.P1Coverage crit.HighFamiliesAtRisk
    printfn "│  Trend:               %s" crit.TrendDirection
    printfn "│  Remediation Effort:  %s" crit.EstimatedRemediationEffort
    printfn "└─────────────────────────────────────────────────────────────────"

let buildAnalysisJson (sb: StringBuilder) (info: InfoTheoryMetrics) (fmea: FmeaEntry list) (stamp: StampAnalysis) (crit: CriticalityAnalysis) =
    sb.AppendLine("  \"analysis\": {") |> ignore
    sb.AppendLine("    \"information_theory\": {") |> ignore
    sb.AppendLine(sprintf "      \"code_entropy\": %.4f," info.CodeEntropy) |> ignore
    sb.AppendLine(sprintf "      \"docs_entropy\": %.4f," info.DocsEntropy) |> ignore
    sb.AppendLine(sprintf "      \"cross_entropy\": %.4f," info.CrossEntropy) |> ignore
    sb.AppendLine(sprintf "      \"kl_divergence\": %.4f," info.KLDivergence) |> ignore
    sb.AppendLine(sprintf "      \"mutual_information\": %.4f," info.MutualInformation) |> ignore
    sb.AppendLine(sprintf "      \"coverage_ratio\": %.4f," info.CoverageRatio) |> ignore
    sb.AppendLine(sprintf "      \"constraint_density\": %.2f," info.ConstraintDensity) |> ignore
    sb.AppendLine(sprintf "      \"documentation_debt\": %.0f" info.DocumentationDebt) |> ignore
    sb.AppendLine("    },") |> ignore
    sb.AppendLine("    \"stamp\": {") |> ignore
    sb.AppendLine(sprintf "      \"control_actions\": %d," stamp.ControlActions) |> ignore
    sb.AppendLine(sprintf "      \"feedback_loops\": %d," stamp.FeedbackLoops) |> ignore
    sb.AppendLine(sprintf "      \"unsafe_control_actions\": %d," stamp.UnsafeControlActions) |> ignore
    sb.AppendLine(sprintf "      \"missing_feedback\": %d," stamp.MissingFeedback) |> ignore
    sb.AppendLine(sprintf "      \"completeness\": %.4f" stamp.ControlStructureCompleteness) |> ignore
    sb.AppendLine("    },") |> ignore
    sb.AppendLine("    \"fmea\": {") |> ignore
    sb.AppendLine(sprintf "      \"mean_rpn\": %.0f," crit.MeanRPN) |> ignore
    sb.AppendLine(sprintf "      \"max_rpn\": %d," crit.MaxRPN) |> ignore
    sb.AppendLine(sprintf "      \"entries_above_200\": %d," (fmea |> List.filter (fun e -> e.RPN >= 200) |> List.length)) |> ignore
    sb.AppendLine(sprintf "      \"entries_above_100\": %d," (fmea |> List.filter (fun e -> e.RPN >= 100) |> List.length)) |> ignore
    sb.AppendLine(sprintf "      \"total_entries\": %d" fmea.Length) |> ignore
    sb.AppendLine("    },") |> ignore
    sb.AppendLine("    \"criticality\": {") |> ignore
    sb.AppendLine(sprintf "      \"risk_score\": %.1f," crit.OverallRiskScore) |> ignore
    sb.AppendLine(sprintf "      \"p0_coverage_pct\": %.1f," crit.P0Coverage) |> ignore
    sb.AppendLine(sprintf "      \"p1_coverage_pct\": %.1f," crit.P1Coverage) |> ignore
    sb.AppendLine(sprintf "      \"p0_at_risk\": %d," crit.CriticalFamiliesAtRisk) |> ignore
    sb.AppendLine(sprintf "      \"p1_at_risk\": %d," crit.HighFamiliesAtRisk) |> ignore
    sb.AppendLine(sprintf "      \"trend\": \"%s\"," crit.TrendDirection) |> ignore
    sb.AppendLine(sprintf "      \"remediation_effort\": \"%s\"" crit.EstimatedRemediationEffort) |> ignore
    sb.AppendLine("    }") |> ignore
    sb.AppendLine("  }") |> ignore

// ─────────────────────────────────────────────────────────────────────────────
// Sync Recording
// ─────────────────────────────────────────────────────────────────────────────

let recordSync (metrics: SyncMetrics) =
    let timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
    File.WriteAllText(syncTimestampFile, timestamp)

    let historyDir = Path.GetDirectoryName(syncHistoryFile)
    if not (Directory.Exists(historyDir)) then
        Directory.CreateDirectory(historyDir) |> ignore

    let entry = sprintf "{\"ts\":\"%s\",\"sc_code\":%d,\"sc_docs\":%d,\"sc_ratio\":%.1f,\"aor_code\":%d,\"aor_docs\":%d,\"aor_ratio\":%.1f,\"health\":\"%s\"}"
                    timestamp metrics.ScCodeCount metrics.ScDocsCount metrics.ScRatio
                    metrics.AorCodeCount metrics.AorDocsCount metrics.AorRatio metrics.Health
    File.AppendAllText(syncHistoryFile, entry + "\n")
    printfn "Sync recorded: %s" timestamp
    printfn "History: %s" syncHistoryFile

// ─────────────────────────────────────────────────────────────────────────────
// Cache & Weekly Gate
// ─────────────────────────────────────────────────────────────────────────────

let writeAnalysisCache (metrics: SyncMetrics) (info: InfoTheoryMetrics)
                       (fmea: FmeaEntry list) (stamp: StampAnalysis) (crit: CriticalityAnalysis) =
    let ts = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
    let fmeaTop = fmea |> List.truncate 15
    let fmeaJson =
        fmeaTop
        |> List.map (fun e ->
            sprintf "      {\"family\":\"%s\",\"severity\":%d,\"occurrence\":%d,\"detection\":%d,\"rpn\":%d,\"priority\":\"%s\"}"
                e.Family e.Severity e.Occurrence e.Detection e.RPN (priorityToString e.Priority))
        |> String.concat ",\n"
    let safetyGapJson =
        [P0_Safety; P1_Core; P2_Domain; P3_Style]
        |> List.map (fun p ->
            match stamp.SafetyGapByPriority |> Map.tryFind p with
            | Some (fams, ids) -> sprintf "      \"%s\": {\"families\": %d, \"ids\": %d}" (priorityToString p) fams ids
            | None -> sprintf "      \"%s\": {\"families\": 0, \"ids\": 0}" (priorityToString p))
        |> String.concat ",\n"
    let sb = StringBuilder()
    sb.AppendLine("{") |> ignore
    sb.AppendLine(sprintf "  \"cached_at\": \"%s\"," ts) |> ignore
    sb.AppendLine("  \"metrics\": {") |> ignore
    sb.AppendLine(sprintf "    \"sc_code\": %d, \"sc_docs\": %d, \"sc_ratio\": %.1f," metrics.ScCodeCount metrics.ScDocsCount metrics.ScRatio) |> ignore
    sb.AppendLine(sprintf "    \"sc_code_families\": %d, \"sc_docs_families\": %d," metrics.ScCodeFamilies metrics.ScDocsFamilies) |> ignore
    sb.AppendLine(sprintf "    \"aor_code\": %d, \"aor_docs\": %d, \"aor_ratio\": %.1f," metrics.AorCodeCount metrics.AorDocsCount metrics.AorRatio) |> ignore
    sb.AppendLine(sprintf "    \"aor_code_families\": %d, \"aor_docs_families\": %d," metrics.AorCodeFamilies metrics.AorDocsFamilies) |> ignore
    sb.AppendLine(sprintf "    \"health\": \"%s\"" metrics.Health) |> ignore
    sb.AppendLine("  },") |> ignore
    sb.AppendLine("  \"analysis\": {") |> ignore
    sb.AppendLine("    \"information_theory\": {") |> ignore
    sb.AppendLine(sprintf "      \"code_entropy\": %.4f, \"docs_entropy\": %.4f," info.CodeEntropy info.DocsEntropy) |> ignore
    sb.AppendLine(sprintf "      \"cross_entropy\": %.4f, \"kl_divergence\": %.4f," info.CrossEntropy info.KLDivergence) |> ignore
    sb.AppendLine(sprintf "      \"mutual_information\": %.4f, \"coverage_ratio\": %.4f," info.MutualInformation info.CoverageRatio) |> ignore
    sb.AppendLine(sprintf "      \"constraint_density\": %.2f, \"documentation_debt\": %.0f" info.ConstraintDensity info.DocumentationDebt) |> ignore
    sb.AppendLine("    },") |> ignore
    sb.AppendLine("    \"stamp\": {") |> ignore
    sb.AppendLine(sprintf "      \"control_actions\": %d, \"feedback_loops\": %d," stamp.ControlActions stamp.FeedbackLoops) |> ignore
    sb.AppendLine(sprintf "      \"unsafe_control_actions\": %d, \"missing_feedback\": %d," stamp.UnsafeControlActions stamp.MissingFeedback) |> ignore
    sb.AppendLine(sprintf "      \"completeness\": %.4f," stamp.ControlStructureCompleteness) |> ignore
    sb.AppendLine("      \"safety_gap\": {") |> ignore
    sb.AppendLine(safetyGapJson) |> ignore
    sb.AppendLine("      }") |> ignore
    sb.AppendLine("    },") |> ignore
    sb.AppendLine("    \"fmea\": {") |> ignore
    sb.AppendLine(sprintf "      \"mean_rpn\": %.0f, \"max_rpn\": %d," crit.MeanRPN crit.MaxRPN) |> ignore
    sb.AppendLine(sprintf "      \"entries_above_200\": %d, \"entries_above_100\": %d," (fmea |> List.filter (fun e -> e.RPN >= 200) |> List.length) (fmea |> List.filter (fun e -> e.RPN >= 100) |> List.length)) |> ignore
    sb.AppendLine(sprintf "      \"total_entries\": %d," fmea.Length) |> ignore
    sb.AppendLine("      \"top_entries\": [") |> ignore
    sb.AppendLine(fmeaJson) |> ignore
    sb.AppendLine("      ]") |> ignore
    sb.AppendLine("    },") |> ignore
    sb.AppendLine("    \"criticality\": {") |> ignore
    sb.AppendLine(sprintf "      \"risk_score\": %.1f, \"p0_coverage_pct\": %.1f, \"p1_coverage_pct\": %.1f," crit.OverallRiskScore crit.P0Coverage crit.P1Coverage) |> ignore
    sb.AppendLine(sprintf "      \"p0_at_risk\": %d, \"p1_at_risk\": %d," crit.CriticalFamiliesAtRisk crit.HighFamiliesAtRisk) |> ignore
    sb.AppendLine(sprintf "      \"trend\": \"%s\", \"remediation_effort\": \"%s\"" crit.TrendDirection crit.EstimatedRemediationEffort) |> ignore
    sb.AppendLine("    }") |> ignore
    sb.AppendLine("  }") |> ignore
    sb.Append("}") |> ignore
    File.WriteAllText(analysisCacheFile, sb.ToString())

let readAnalysisCache () : bool =
    if File.Exists(analysisCacheFile) then
        let content = File.ReadAllText(analysisCacheFile)
        printfn "%s" content
        true
    else
        eprintfn "No cache found at %s. Run --analysis first." analysisCacheFile
        false

let isReconciliationDue () : bool =
    if File.Exists(lastReconcileFile) then
        let lastDate = File.ReadAllText(lastReconcileFile).Trim()
        match DateTime.TryParse(lastDate) with
        | true, dt -> (DateTime.Now - dt).TotalDays >= 7.0
        | _ -> true
    else true

let recordReconciliation () =
    File.WriteAllText(lastReconcileFile, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"))

// ─────────────────────────────────────────────────────────────────────────────
// JSON Builders (for unified JSON envelope)
// ─────────────────────────────────────────────────────────────────────────────

let buildDashboardJson (sb: StringBuilder) (m: SyncMetrics) =
    sb.AppendLine("  \"date\": \"" + m.Date + "\",") |> ignore
    sb.AppendLine("  \"sc\": {") |> ignore
    sb.AppendLine(sprintf "    \"code_count\": %d, \"code_families\": %d," m.ScCodeCount m.ScCodeFamilies) |> ignore
    sb.AppendLine(sprintf "    \"docs_count\": %d, \"docs_families\": %d," m.ScDocsCount m.ScDocsFamilies) |> ignore
    sb.AppendLine(sprintf "    \"gap\": %d, \"gap_pct\": %.1f, \"ratio\": %.1f" m.ScGap m.ScGapPct m.ScRatio) |> ignore
    sb.AppendLine("  },") |> ignore
    sb.AppendLine("  \"aor\": {") |> ignore
    sb.AppendLine(sprintf "    \"code_count\": %d, \"code_families\": %d," m.AorCodeCount m.AorCodeFamilies) |> ignore
    sb.AppendLine(sprintf "    \"docs_count\": %d, \"docs_families\": %d," m.AorDocsCount m.AorDocsFamilies) |> ignore
    sb.AppendLine(sprintf "    \"gap\": %d, \"gap_pct\": %.1f, \"ratio\": %.1f" m.AorGap m.AorGapPct m.AorRatio) |> ignore
    sb.AppendLine("  },") |> ignore
    sb.AppendLine("  \"claude_inventory\": {") |> ignore
    sb.AppendLine(sprintf "    \"rules\": %d, \"agents\": %d, \"commands\": %d, \"hooks\": %d" m.RulesCount m.AgentsCount m.CommandsCount m.HooksCount) |> ignore
    sb.AppendLine("  },") |> ignore
    sb.AppendLine(sprintf "  \"health\": \"%s\"," m.Health) |> ignore
    sb.AppendLine(sprintf "  \"last_sync\": \"%s\"" m.LastSync) |> ignore

let buildGapsJson (sb: StringBuilder) (scCensus: CensusResult) (aorCensus: CensusResult) =
    let allUndoc = scCensus.UndocumentedFamilies @ aorCensus.UndocumentedFamilies
    sb.AppendLine("  \"undocumented_families\": [") |> ignore
    for (i, f) in allUndoc |> List.mapi (fun i x -> (i, x)) do
        let range = if f.MinId = f.MaxId then $"{f.MinId:D3}" else $"{f.MinId:D3}-{f.MaxId:D3}"
        let example = f.ExampleFile |> Option.defaultValue ""
        let comma = if i < allUndoc.Length - 1 then "," else ""
        sb.AppendLine(sprintf "    {\"family\": \"%s\", \"ids\": %d, \"range\": \"%s\", \"priority\": \"%s\", \"example\": \"%s\"}%s"
            f.Prefix f.IdCount range (priorityToString f.Priority) (escapeJson example) comma) |> ignore
    sb.AppendLine("  ],") |> ignore
    sb.AppendLine(sprintf "  \"total_undocumented_families\": %d," allUndoc.Length) |> ignore
    sb.AppendLine(sprintf "  \"total_undocumented_ids\": %d" (allUndoc |> List.sumBy (fun f -> f.IdCount))) |> ignore

let buildInventoryJson (sb: StringBuilder) (inv: ClaudeInventory) =
    sb.AppendLine("  \"inventory\": {") |> ignore
    sb.AppendLine("    \"rules\": [") |> ignore
    for (i, r) in inv.Rules |> List.mapi (fun i x -> (i, x)) do
        let comma = if i < inv.Rules.Length - 1 then "," else ""
        sb.AppendLine(sprintf "      \"%s\"%s" r comma) |> ignore
    sb.AppendLine("    ],") |> ignore
    sb.AppendLine("    \"agents\": [") |> ignore
    for (i, a) in inv.Agents |> List.mapi (fun i x -> (i, x)) do
        let comma = if i < inv.Agents.Length - 1 then "," else ""
        sb.AppendLine(sprintf "      \"%s\"%s" a comma) |> ignore
    sb.AppendLine("    ],") |> ignore
    sb.AppendLine("    \"commands\": [") |> ignore
    for (i, c) in inv.Commands |> List.mapi (fun i x -> (i, x)) do
        let comma = if i < inv.Commands.Length - 1 then "," else ""
        sb.AppendLine(sprintf "      \"%s\"%s" c comma) |> ignore
    sb.AppendLine("    ],") |> ignore
    sb.AppendLine("    \"hooks\": [") |> ignore
    for (i, h) in inv.Hooks |> List.mapi (fun i x -> (i, x)) do
        let comma = if i < inv.Hooks.Length - 1 then "," else ""
        sb.AppendLine(sprintf "      \"%s\"%s" h comma) |> ignore
    sb.AppendLine("    ]") |> ignore
    sb.AppendLine("  }") |> ignore

let buildReconcileJson (sb: StringBuilder) (plan: ReconciliationItem list) (skipped: bool) (lastDate: string) =
    sb.AppendLine("  \"reconciliation\": {") |> ignore
    if skipped then
        sb.AppendLine(sprintf "    \"status\": \"skipped\",") |> ignore
        sb.AppendLine(sprintf "    \"last_run\": \"%s\"," lastDate) |> ignore
        let dt = match DateTime.TryParse(lastDate) with true, d -> d | _ -> DateTime.Now
        let remaining = max 0.0 (7.0 - (DateTime.Now - dt).TotalDays)
        sb.AppendLine(sprintf "    \"next_due_days\": %.1f" remaining) |> ignore
    else
        sb.AppendLine(sprintf "    \"status\": \"executed\",") |> ignore
        sb.AppendLine(sprintf "    \"total_items\": %d," plan.Length) |> ignore
        sb.AppendLine(sprintf "    \"total_ids\": %d" (plan |> List.sumBy (fun i -> i.IdCount))) |> ignore
    sb.AppendLine("  }") |> ignore

let emitUnifiedJson (sb: StringBuilder) =
    let mutable json = sb.ToString().TrimEnd()
    if json.EndsWith(",") then json <- json.Substring(0, json.Length - 1)
    json <- json + "\n}"
    printfn "%s" json

// ─────────────────────────────────────────────────────────────────────────────
// Entry Point
// ─────────────────────────────────────────────────────────────────────────────

[<EntryPoint>]
let main (argv: string array) : int =
    let args = argv |> Array.toList

    let hasFlag flag = args |> List.exists (fun a -> a = flag)
    let jsonMode = hasFlag "--json"
    let gapsMode = hasFlag "--gaps"
    let reconcileMode = hasFlag "--reconcile"
    let inventoryMode = hasFlag "--inventory"
    let fullMode = hasFlag "--full"
    let recordMode = hasFlag "--record"
    let analysisMode = hasFlag "--analysis"
    let cachedMode = hasFlag "--cached"
    let helpMode = hasFlag "--help" || hasFlag "-h"

    // --help: print usage and exit
    if helpMode then
        printfn "Constraint Synchronization Engine"
        printfn ""
        printfn "Usage: constraint-sync [FLAGS]"
        printfn ""
        printfn "FLAGS:"
        printfn "  (none)        Dashboard with sync status (default)"
        printfn "  --json        Output in JSON format (combinable with other flags)"
        printfn "  --gaps        Show undocumented constraint families"
        printfn "  --reconcile   Generate reconciliation plan (weekly gate: 7-day minimum)"
        printfn "  --inventory   List .claude/ directory contents"
        printfn "  --analysis    Full analysis: info theory, FMEA, STAMP, criticality (auto-caches)"
        printfn "  --cached      Read last --analysis results from cache (<1ms, no census)"
        printfn "  --full        All of the above combined"
        printfn "  --record      Record sync timestamp to history"
        printfn "  --help, -h    Show this help"
        printfn ""
        printfn "Examples:"
        printfn "  constraint-sync                  # Quick dashboard"
        printfn "  constraint-sync --json           # Dashboard as JSON"
        printfn "  constraint-sync --gaps           # Show gaps by priority"
        printfn "  constraint-sync --analysis       # Deep analysis (writes cache)"
        printfn "  constraint-sync --cached         # Read cached analysis (fast)"
        printfn "  constraint-sync --full --json    # Everything as single JSON"
        0

    else

    let dashboardMode = not gapsMode && not reconcileMode && not inventoryMode && not fullMode && not recordMode && not analysisMode && not cachedMode

    // Fast path: --cached reads last analysis from file (<1ms, no census)
    if cachedMode && not fullMode && not analysisMode then
        if readAnalysisCache () then 0
        else
            eprintfn "No cache found. Run --analysis first to populate cache."
            1

    else

    // Determine if census is needed (avoid unnecessary filesystem scan)
    let needsCensus = dashboardMode || gapsMode || reconcileMode || fullMode || analysisMode || cachedMode
    let needsInventoryOnly = inventoryMode && not needsCensus && not recordMode

    // Inventory-only fast path (no census needed)
    if needsInventoryOnly then
        let inv = getClaudeInventory ()
        if jsonMode then
            let sb = StringBuilder()
            sb.AppendLine("{") |> ignore
            buildInventoryJson sb inv
            emitUnifiedJson sb
        else
            printInventory inv
        0

    else

    // Run census for all modes that need it
    let emptyCensus = { CodeConstraints = Map.empty; DocsConstraints = Map.empty; CodeExamples = Map.empty; UndocumentedFamilies = []; DocOnlyFamilies = []; AllFamilies = [] }
    let emptyMetrics = { Date = ""; ScCodeCount = 0; ScCodeFamilies = 0; ScDocsCount = 0; ScDocsFamilies = 0; ScGap = 0; ScGapPct = 0.0; ScRatio = 0.0; AorCodeCount = 0; AorCodeFamilies = 0; AorDocsCount = 0; AorDocsFamilies = 0; AorGap = 0; AorGapPct = 0.0; AorRatio = 0.0; Health = "UNKNOWN"; LastSync = ""; RulesCount = 0; AgentsCount = 0; CommandsCount = 0; HooksCount = 0 }

    let scCensus = if needsCensus || recordMode then runCensus "SC" else emptyCensus
    let aorCensus = if needsCensus || recordMode then runCensus "AOR" else emptyCensus
    let metrics = if needsCensus || recordMode then computeMetrics scCensus aorCensus else emptyMetrics

    // JSON mode: build a single unified JSON object
    if jsonMode then
        let sb = StringBuilder()
        sb.AppendLine("{") |> ignore

        if dashboardMode || fullMode then
            buildDashboardJson sb metrics
            sb.AppendLine(",") |> ignore

        if gapsMode || fullMode then
            buildGapsJson sb scCensus aorCensus
            sb.AppendLine(",") |> ignore

        if reconcileMode || fullMode then
            let lastDate = if File.Exists(lastReconcileFile) then File.ReadAllText(lastReconcileFile).Trim() else "unknown"
            if isReconciliationDue () then
                let plan = generateReconciliationPlan scCensus aorCensus
                buildReconcileJson sb plan false lastDate
                recordReconciliation ()
            else
                buildReconcileJson sb [] true lastDate
            sb.AppendLine(",") |> ignore

        if inventoryMode || fullMode then
            let inv = getClaudeInventory ()
            buildInventoryJson sb inv
            sb.AppendLine(",") |> ignore

        if analysisMode || fullMode then
            let infoMetrics = computeInfoTheory scCensus aorCensus
            let fmeaEntries = computeFmea scCensus aorCensus
            let stampAnalysis = computeStamp scCensus aorCensus metrics
            let critAnalysis = computeCriticality scCensus aorCensus fmeaEntries metrics
            buildAnalysisJson sb infoMetrics fmeaEntries stampAnalysis critAnalysis
            writeAnalysisCache metrics infoMetrics fmeaEntries stampAnalysis critAnalysis

        emitUnifiedJson sb

    else
        // Plain text mode: print each section

        if dashboardMode || fullMode then
            printDashboard metrics

        if gapsMode || fullMode then
            printGaps scCensus aorCensus

        if reconcileMode || fullMode then
            if isReconciliationDue () then
                let plan = generateReconciliationPlan scCensus aorCensus
                printReconciliationPlan plan
                recordReconciliation ()
            else
                let lastDate = if File.Exists(lastReconcileFile) then File.ReadAllText(lastReconcileFile).Trim() else "unknown"
                printfn ""
                printfn "RECONCILIATION: Skipped (last run: %s, next due in %s days)"
                    lastDate
                    (let dt = match DateTime.TryParse(lastDate) with true, d -> d | _ -> DateTime.Now
                     let remaining = 7.0 - (DateTime.Now - dt).TotalDays
                     sprintf "%.1f" (max 0.0 remaining))

        if inventoryMode || fullMode then
            let inv = getClaudeInventory ()
            printInventory inv

        if analysisMode || fullMode then
            let infoMetrics = computeInfoTheory scCensus aorCensus
            let fmeaEntries = computeFmea scCensus aorCensus
            let stampAnalysis = computeStamp scCensus aorCensus metrics
            let critAnalysis = computeCriticality scCensus aorCensus fmeaEntries metrics
            printAnalysis infoMetrics fmeaEntries stampAnalysis critAnalysis
            writeAnalysisCache metrics infoMetrics fmeaEntries stampAnalysis critAnalysis

    // Record sync (works in both JSON and text modes)
    if recordMode then
        recordSync metrics

    // Exit code based on health
    match metrics.Health with
    | "HEALTHY" -> 0
    | "DEGRADED" -> 0
    | _ -> 0
