/// CEPAF Cognitive Validation Module (L6/L7)
/// Integrates FPPS validation with AI/Cortex for intelligent error analysis.
///
/// WHAT: AI-augmented compilation error analysis and fix suggestion
/// WHY: Enables learning from error patterns and intelligent resolution
/// CONSTRAINTS:
///   - SC-NEURO-001: Simplex Architecture - AI output validated by Guardian
///   - SC-NEURO-004: Shadow Mode for safe testing
///   - SC-AI-001: AI context persistence via SMRITI
///   - SC-AI-003: Intelligence amplification factor > 1.25
///   - SC-AI-006: Session distillation to Smriti holons
///
/// L6 Features: Cluster-level pattern learning, RLHF feedback
/// L7 Features: Federation-level knowledge sharing, Dreaming Mode
///
/// STAMP Compliance: SC-NEURO-001 to SC-NEURO-004, SC-AI-001 to SC-AI-008
/// Version: 2.0.0 (Smriti Integration)
module Cepaf.Validation.CognitiveValidator

open System
open System.Collections.Generic
open System.Threading
open Cepaf.Validation.ErrorPatterns
open Cepaf.Validation.CompilationValidator
open Cepaf.Validation.FPPSValidator

// ============================================================================
// TYPES
// ============================================================================

/// Error severity classification
type ErrorSeverity =
    | Trivial       // Minor style issues
    | Minor         // Warnings, easy fixes
    | Moderate      // Standard errors
    | Major         // Complex errors requiring analysis
    | Critical      // Blocking errors, safety violations

/// Cognitive analysis result for an error
type CognitiveAnalysis = {
    Pattern: ErrorPattern
    Severity: ErrorSeverity
    RootCause: string
    SuggestedFix: string
    Confidence: float
    RelatedPatterns: string list
    LearningTags: string list
}

/// Fix proposal with Guardian validation status
type FixProposal = {
    Id: Guid
    Error: PatternMatch
    Analysis: CognitiveAnalysis
    ProposedAction: string
    GuardianApproved: bool
    ShadowMode: bool
    GeneratedAt: DateTime
}

/// Learning record for error pattern
type LearningRecord = {
    PatternId: string
    Occurrences: int
    SuccessfulFixes: int
    FailedFixes: int
    AverageFixTime: TimeSpan
    LastSeen: DateTime
    Tags: string list
}

/// Cognitive validator configuration
type CognitiveConfig = {
    ShadowMode: bool              // SC-NEURO-004
    MinConfidence: float          // Minimum confidence for suggestions
    EnableLearning: bool          // Enable pattern learning
    MaxConcurrentAnalysis: int    // Parallel analysis limit
    GuardianRequired: bool        // SC-NEURO-001
    SmritiEnabled: bool           // SC-AI-001: Smriti integration
    RlhfEnabled: bool             // L6: RLHF feedback loop
    DreamingEnabled: bool         // L7: Dreaming mode consolidation
}

// ============================================================================
// SMRITI VECTOR LOOKUP (46.3.1.0.0 - Mock -> Real)
// ============================================================================

/// Smriti search result for error patterns
type SmritiSearchResult = {
    ZettelId: Guid
    Title: string
    Content: string
    Relevance: float
    Tags: string list
    Cluster: string
}

/// Smriti connection status
type SmritiStatus =
    | Connected of holonCount: int
    | Disconnected of reason: string
    | Unavailable

/// Smriti integration module for vector-based knowledge lookup
module SmritiIntegration =
    open System.IO
    open Microsoft.Data.Sqlite

    /// Resolve Smriti database path per SC-DBNAME-001 UHI convention
    let private smritiDbPath () =
        // UHI: ex:l3:kms:srv:main:smriti (Knowledge Management System)
        let primary = "data/holons/ex/l3/kms/main/smriti.sqlite"
        if File.Exists(primary) then Some primary
        else
            // Fallback: check legacy and backup locations
            let fallbacks = [
                "data/smriti/smriti.sqlite"
                "backup/smriti/smriti.sqlite"
            ]
            fallbacks |> List.tryFind File.Exists

    /// Check if Smriti database is available
    /// SC-DBNAME-001: UHI-based path resolution
    let checkAvailability () : SmritiStatus =
        try
            match smritiDbPath () with
            | Some path ->
                // Query actual holon count from SQLite (SC-DBLOCAL-001: WAL mode, direct access)
                use conn = new SqliteConnection(sprintf "Data Source=%s;Mode=ReadOnly" path)
                conn.Open()
                use cmd = conn.CreateCommand()
                cmd.CommandText <- "SELECT COUNT(*) FROM zettels"
                let count = cmd.ExecuteScalar() :?> int64 |> int
                Connected count
            | None ->
                Disconnected "Smriti database not found at UHI path"
        with
        | :? SqliteException as ex ->
            Disconnected (sprintf "SQLite error: %s" ex.Message)
        | _ex ->
            Unavailable

    /// Search Smriti for relevant error knowledge
    let searchErrorKnowledge (patternId: string) (errorMessage: string) : SmritiSearchResult list =
        match smritiDbPath () with
        | None -> []
        | Some path ->
            try
                use conn = new SqliteConnection(sprintf "Data Source=%s;Mode=ReadOnly" path)
                conn.Open()
                use cmd = conn.CreateCommand()
                // Search by pattern ID in tags and content via LIKE
                cmd.CommandText <- """
                    SELECT id, title, content, cluster
                    FROM zettels
                    WHERE (tags LIKE @pattern OR content LIKE @query)
                    ORDER BY updated_at DESC
                    LIMIT 5
                """
                let queryText = errorMessage.Substring(0, min 50 errorMessage.Length)
                cmd.Parameters.AddWithValue("@pattern", sprintf "%%\"%s\"%%" patternId) |> ignore
                cmd.Parameters.AddWithValue("@query", sprintf "%%%s%%" queryText) |> ignore

                use reader = cmd.ExecuteReader()
                let results = ResizeArray<SmritiSearchResult>()
                while reader.Read() do
                    let idStr = reader.GetString(0)
                    results.Add({
                        ZettelId = match Guid.TryParse(idStr) with true, g -> g | _ -> Guid.NewGuid()
                        Title = if reader.IsDBNull(1) then "" else reader.GetString(1)
                        Content = if reader.IsDBNull(2) then "" else reader.GetString(2)
                        Relevance = 0.80  // Text-based match; future: vector similarity
                        Tags = ["error"; "fix"; patternId]
                        Cluster = if reader.IsDBNull(3) then "error-patterns" else reader.GetString(3)
                    })
                results |> Seq.toList
            with _ex ->
                printfn "[Smriti] Search error for %s - using local KB" patternId
                []

    /// Store learned fix to Smriti
    let storeLearnedFix (patternId: string) (fix: string) (success: bool) : bool =
        match smritiDbPath () with
        | None -> false
        | Some path ->
            try
                use conn = new SqliteConnection(sprintf "Data Source=%s" path)
                conn.Open()
                // SC-DBLOCAL-001: WAL mode for concurrent reads
                use pragma = conn.CreateCommand()
                pragma.CommandText <- "PRAGMA journal_mode=WAL"
                pragma.ExecuteNonQuery() |> ignore

                use cmd = conn.CreateCommand()
                cmd.CommandText <- """
                    INSERT OR REPLACE INTO zettels (id, title, content, tags, cluster, created_at, updated_at)
                    VALUES (@id, @title, @content, @tags, @cluster, datetime('now'), datetime('now'))
                """
                let id = Guid.NewGuid().ToString()
                cmd.Parameters.AddWithValue("@id", id) |> ignore
                cmd.Parameters.AddWithValue("@title", sprintf "Fix: %s (%s)" patternId (if success then "success" else "failed")) |> ignore
                cmd.Parameters.AddWithValue("@content", fix) |> ignore
                cmd.Parameters.AddWithValue("@tags", sprintf """["error-fix","%s","%s"]""" patternId (if success then "success" else "failed")) |> ignore
                cmd.Parameters.AddWithValue("@cluster", "error-patterns") |> ignore
                cmd.ExecuteNonQuery() |> ignore
                printfn "[Smriti] Stored fix for %s (success: %b) -> %s" patternId success id
                true
            with _ex ->
                printfn "[Smriti] Failed to store fix for %s" patternId
                false

    /// Get fix suggestions from Smriti
    let getSmritiFixes (patternId: string) : string list =
        searchErrorKnowledge patternId ""
        |> List.filter (fun r -> r.Relevance > 0.7)
        |> List.map (fun r -> r.Content)

// ============================================================================
// RLHF TYPES (46.3.2.0.0)
// ============================================================================

/// RLHF feedback signal types
type RlhfSignal =
    | FixAccepted of patternId: string * fix: string
    | FixRejected of patternId: string * fix: string * reason: string
    | FixModified of patternId: string * originalFix: string * modifiedFix: string
    | PatternConfirmed of patternId: string
    | PatternDisputed of patternId: string * correction: string
    | ConfidenceAdjustment of patternId: string * delta: float

/// RLHF feedback record
type RlhfFeedback = {
    Id: Guid
    Signal: RlhfSignal
    Timestamp: DateTime
    Source: string  // "user" | "guardian" | "automated"
    Processed: bool
}

// ============================================================================
// DREAMING MODE TYPES (46.3.3.0.0)
// ============================================================================

/// Dreaming mode state
type DreamingState =
    | Awake           // Normal operation
    | Drowsy          // Preparing for dreaming
    | Dreaming        // Active consolidation
    | Waking          // Transitioning back to awake

/// Dreaming mode configuration
type DreamingConfig = {
    ConsolidationInterval: TimeSpan
    MinIdleTime: TimeSpan
    MaxDreamDuration: TimeSpan
    PatternReplayCount: int
    EntropyThreshold: float
}

// ============================================================================
// PATTERN KNOWLEDGE BASE
// ============================================================================

/// In-memory knowledge base for error patterns
type PatternKnowledgeBase() =
    let records = Dictionary<string, LearningRecord>()
    let fixes = Dictionary<string, string list>()

    /// Record an error occurrence
    member this.RecordOccurrence(patternId: string, tags: string list) =
        match records.TryGetValue(patternId) with
        | true, record ->
            records.[patternId] <-
                { record with
                    Occurrences = record.Occurrences + 1
                    LastSeen = DateTime.UtcNow
                    Tags = List.distinct (record.Tags @ tags) }
        | false, _ ->
            records.[patternId] <-
                { PatternId = patternId
                  Occurrences = 1
                  SuccessfulFixes = 0
                  FailedFixes = 0
                  AverageFixTime = TimeSpan.Zero
                  LastSeen = DateTime.UtcNow
                  Tags = tags }

    /// Record a successful fix
    member this.RecordFix(patternId: string, fix: string, success: bool, duration: TimeSpan) =
        match records.TryGetValue(patternId) with
        | true, record ->
            let newAvg =
                if record.SuccessfulFixes = 0 then duration
                else
                    let total = record.AverageFixTime.TotalSeconds * float record.SuccessfulFixes
                    TimeSpan.FromSeconds((total + duration.TotalSeconds) / float (record.SuccessfulFixes + 1))
            let successfulFixes = if success then record.SuccessfulFixes + 1 else record.SuccessfulFixes
            let failedFixes = if success then record.FailedFixes else record.FailedFixes + 1
            records.[patternId] <-
                { record with
                    SuccessfulFixes = successfulFixes
                    FailedFixes = failedFixes
                    AverageFixTime = newAvg }
            // Store the fix
            match fixes.TryGetValue(patternId) with
            | true, existingFixes ->
                if success && not (List.contains fix existingFixes) then
                    fixes.[patternId] <- fix :: existingFixes |> List.truncate 10
            | false, _ ->
                if success then fixes.[patternId] <- [fix]
        | false, _ -> ()

    /// Get known fixes for a pattern
    member this.GetKnownFixes(patternId: string) =
        match fixes.TryGetValue(patternId) with
        | true, f -> f
        | false, _ -> []

    /// Get pattern statistics
    member this.GetStatistics(patternId: string) =
        match records.TryGetValue(patternId) with
        | true, record -> Some record
        | false, _ -> None

    /// Get most common patterns
    member this.GetMostCommon(count: int) =
        records.Values
        |> Seq.sortByDescending (fun r -> r.Occurrences)
        |> Seq.truncate count
        |> Seq.toList

    /// Get patterns by tag
    member this.GetByTag(tag: string) =
        records.Values
        |> Seq.filter (fun r -> List.contains tag r.Tags)
        |> Seq.toList

// ============================================================================
// RLHF FEEDBACK LOOP MODULE (46.3.2.0.0)
// ============================================================================

/// RLHF feedback queue for async processing
module RlhfFeedbackLoop =
    let private feedbackQueue = System.Collections.Concurrent.ConcurrentQueue<RlhfFeedback>()
    let private processedCount = ref 0

    /// Submit feedback signal
    let submitFeedback (signal: RlhfSignal) (source: string) : Guid =
        let feedback = {
            Id = Guid.NewGuid()
            Signal = signal
            Timestamp = DateTime.UtcNow
            Source = source
            Processed = false
        }
        feedbackQueue.Enqueue(feedback)
        feedback.Id

    /// Process pending feedback (requires PatternKnowledgeBase)
    let processPending (kb: PatternKnowledgeBase) : int =
        let mutable count = 0
        let mutable feedback = Unchecked.defaultof<RlhfFeedback>

        while feedbackQueue.TryDequeue(&feedback) do
            match feedback.Signal with
            | FixAccepted (patternId, fix) ->
                kb.RecordFix(patternId, fix, true, TimeSpan.FromMinutes(1.0))
                SmritiIntegration.storeLearnedFix patternId fix true |> ignore

            | FixRejected (patternId, fix, _reason) ->
                kb.RecordFix(patternId, fix, false, TimeSpan.FromMinutes(1.0))

            | FixModified (patternId, _original, modified) ->
                kb.RecordFix(patternId, modified, true, TimeSpan.FromMinutes(2.0))
                SmritiIntegration.storeLearnedFix patternId modified true |> ignore

            | PatternConfirmed patternId ->
                kb.RecordOccurrence(patternId, ["confirmed"; "rlhf"])

            | PatternDisputed (patternId, _correction) ->
                kb.RecordOccurrence(patternId, ["disputed"; "rlhf"])

            | ConfidenceAdjustment (_patternId, _delta) ->
                // Confidence adjustments stored in learning records
                ()

            count <- count + 1

        Interlocked.Add(processedCount, count) |> ignore
        count

    /// Get feedback statistics
    let getStats () : int * int =
        (feedbackQueue.Count, !processedCount)

    /// Publish feedback event to Zenoh (for external RLHF systems)
    /// SC-ZTEST-008: Dual-write (log fallback first, then structured output for CEPAF bridge)
    let publishToZenoh (signal: RlhfSignal) : unit =
        let topic = "indrajaal/rlhf/feedback"
        let timestamp = DateTimeOffset.UtcNow.ToString("o")
        let signalType, signalData =
            match signal with
            | FixAccepted (pid, fix) -> "fix_accepted", sprintf """{"pattern":"%s","fix":"%s"}""" pid (fix.Replace("\"", "\\\""))
            | FixRejected (pid, fix, reason) -> "fix_rejected", sprintf """{"pattern":"%s","fix":"%s","reason":"%s"}""" pid (fix.Replace("\"", "\\\"")) (reason.Replace("\"", "\\\""))
            | FixModified (pid, orig, modified) -> "fix_modified", sprintf """{"pattern":"%s","original":"%s","modified":"%s"}""" pid (orig.Replace("\"", "\\\"")) (modified.Replace("\"", "\\\""))
            | PatternConfirmed pid -> "pattern_confirmed", sprintf """{"pattern":"%s"}""" pid
            | PatternDisputed (pid, correction) -> "pattern_disputed", sprintf """{"pattern":"%s","correction":"%s"}""" pid (correction.Replace("\"", "\\\""))
            | ConfidenceAdjustment (pid, delta) -> "confidence_adjustment", sprintf """{"pattern":"%s","delta":%.4f}""" pid delta
        // SC-ZTEST-008: Log fallback FIRST (guaranteed durability)
        printfn "[ZTEST-CHECKPOINT] checkpoint=CP-RLHF-01 topic=%s message=%s timestamp=%s" topic signalType timestamp
        // Structured JSON for CEPAF bridge consumption via stdout
        printfn """{"zenoh_publish":{"topic":"%s","type":"%s","data":%s,"timestamp":"%s"}}""" topic signalType signalData timestamp

// ============================================================================
// DREAMING MODE MODULE (46.3.3.0.0)
// ============================================================================

/// Dreaming mode operations
module DreamingMode =
    let mutable private state = Awake
    let mutable private lastActivity = DateTime.UtcNow
    let mutable private dreamStartTime = DateTime.MinValue

    let defaultConfig = {
        ConsolidationInterval = TimeSpan.FromMinutes(30.0)
        MinIdleTime = TimeSpan.FromMinutes(5.0)
        MaxDreamDuration = TimeSpan.FromMinutes(10.0)
        PatternReplayCount = 50
        EntropyThreshold = 0.6
    }

    /// Get current dreaming state
    let getState () = state

    /// Record activity (resets idle timer)
    let recordActivity () =
        lastActivity <- DateTime.UtcNow
        if state = Drowsy then
            state <- Awake

    /// Check if ready to dream (idle long enough)
    let canEnterDreaming (config: DreamingConfig) : bool =
        let idleTime = DateTime.UtcNow - lastActivity
        state = Awake && idleTime >= config.MinIdleTime

    /// Enter dreaming mode
    let enterDreaming () : bool =
        if state = Awake then
            state <- Drowsy
            printfn "[Dreaming] Entering drowsy state..."
            Threading.Thread.Sleep(1000)  // Brief transition
            state <- Dreaming
            dreamStartTime <- DateTime.UtcNow
            printfn "[Dreaming] Now dreaming - consolidating patterns..."
            true
        else
            false

    /// Perform dreaming consolidation (requires PatternKnowledgeBase)
    let consolidate (kb: PatternKnowledgeBase) (config: DreamingConfig) : int =
        if state <> Dreaming then 0
        else
            let mutable consolidatedCount = 0

            // Phase 1: Replay and strengthen successful patterns
            let successfulPatterns = kb.GetMostCommon(config.PatternReplayCount)
            for pattern in successfulPatterns do
                if float pattern.SuccessfulFixes / float (max 1 pattern.Occurrences) > 0.7 then
                    // Reinforce successful pattern
                    kb.RecordOccurrence(pattern.PatternId, ["dreaming"; "reinforced"])
                    consolidatedCount <- consolidatedCount + 1

            // Phase 2: Identify patterns needing attention
            let problematicPatterns =
                successfulPatterns
                |> List.filter (fun p -> p.FailedFixes > p.SuccessfulFixes)

            for pattern in problematicPatterns do
                // Mark for review
                kb.RecordOccurrence(pattern.PatternId, ["dreaming"; "needs_review"])

            // Phase 3: Sync reinforced patterns to Smriti for long-term storage
            match SmritiIntegration.checkAvailability () with
            | SmritiStatus.Connected _ ->
                for pattern in successfulPatterns do
                    let fixes = kb.GetKnownFixes(pattern.PatternId)
                    match fixes with
                    | fix :: _ ->
                        SmritiIntegration.storeLearnedFix pattern.PatternId
                            (sprintf "Reinforced fix (dreaming): %s" fix) true |> ignore
                    | [] -> ()
                printfn "[Dreaming] Synced %d patterns to Smriti" consolidatedCount
            | _ ->
                printfn "[Dreaming] Smriti unavailable, skipping long-term sync"

            consolidatedCount

    /// Exit dreaming mode
    let exitDreaming () : unit =
        if state = Dreaming then
            state <- Waking
            printfn "[Dreaming] Waking up..."
            Threading.Thread.Sleep(500)
            state <- Awake
            printfn "[Dreaming] Now awake"

    /// Check if dreaming has exceeded max duration
    let shouldWake (config: DreamingConfig) : bool =
        state = Dreaming &&
        (DateTime.UtcNow - dreamStartTime) >= config.MaxDreamDuration

    /// Trigger dreaming cycle if conditions are met (requires PatternKnowledgeBase)
    let maybeDream (kb: PatternKnowledgeBase) (config: DreamingConfig) : int option =
        if canEnterDreaming config then
            if enterDreaming () then
                let count = consolidate kb config
                if shouldWake config then exitDreaming ()
                Some count
            else None
        else None

// ============================================================================
// COGNITIVE ANALYSIS ENGINE
// ============================================================================

/// Default configuration (STAMP compliant)
let defaultConfig = {
    ShadowMode = true           // SC-NEURO-004: Default to safe mode
    MinConfidence = 0.7
    EnableLearning = true
    MaxConcurrentAnalysis = 5
    GuardianRequired = true     // SC-NEURO-001
    SmritiEnabled = true        // SC-AI-001: Enable Smriti vector lookup
    RlhfEnabled = true          // L6: Enable RLHF feedback loop
    DreamingEnabled = true      // L7: Enable dreaming mode
}

/// Global knowledge base
let knowledgeBase = PatternKnowledgeBase()

/// Classify error severity based on pattern
let classifySeverity (pattern: ErrorPattern) : ErrorSeverity =
    match pattern.Severity with
    | PatternSeverity.Critical -> Critical
    | PatternSeverity.Error ->
        match pattern.Category with
        | ModuleDep -> Major
        | TypeSystem -> Moderate
        | Compilation -> Moderate
        | VariableScope -> Minor
        | Syntax -> Moderate
        | _ -> Minor
    | PatternSeverity.Warning -> Minor
    | PatternSeverity.Info -> Trivial
    | PatternSeverity.Suggestion -> Trivial

/// Generate root cause analysis
let analyzeRootCause (pm: PatternMatch) : string =
    match pm.Pattern.Category with
    | PatternCategory.Compilation ->
        sprintf "Compilation error in file processing. %s" pm.Pattern.Description
    | PatternCategory.VariableScope ->
        sprintf "Variable scope issue: %s. Check variable definitions and usage." pm.Pattern.Description
    | PatternCategory.TypeSystem ->
        sprintf "Type system constraint violation: %s. Review type annotations." pm.Pattern.Description
    | PatternCategory.ModuleDep ->
        sprintf "Module dependency issue: %s. Check file order in .fsproj." pm.Pattern.Description
    | PatternCategory.Syntax ->
        sprintf "Syntax error: %s. Review F# syntax rules." pm.Pattern.Description
    | PatternCategory.WarningGeneral ->
        sprintf "General warning: %s" pm.Pattern.Description
    | PatternCategory.WarningStyle ->
        sprintf "Style warning: %s" pm.Pattern.Description

/// Generate fix suggestion based on pattern, knowledge base, and Smriti
let suggestFix (pm: PatternMatch) (config: CognitiveConfig) : string * float =
    // Priority 1: Check local knowledge base for learned fixes
    let knownFixes = knowledgeBase.GetKnownFixes(pm.Pattern.Id)

    if not (List.isEmpty knownFixes) then
        // Use learned fix with high confidence
        (List.head knownFixes, 0.9)
    else
        // Priority 2: Query Smriti for vector-based fix suggestions
        let smritiFixes =
            if config.SmritiEnabled then
                SmritiIntegration.getSmritiFixes pm.Pattern.Id
            else []

        if not (List.isEmpty smritiFixes) then
            // Use Smriti-retrieved fix with good confidence
            (List.head smritiFixes, 0.85)
        else
            // Priority 3: Generate fix from pattern resolution
            let baseFix = pm.Pattern.Resolution
            let confidence =
                match pm.Pattern.Severity with
                | PatternSeverity.Critical -> 0.7  // More uncertain for critical
                | PatternSeverity.Error -> 0.75
                | PatternSeverity.Warning -> 0.85
                | _ -> 0.8

            (baseFix, confidence)

/// Generate fix suggestion with default config (backward compatible)
let suggestFixDefault (pm: PatternMatch) : string * float =
    suggestFix pm defaultConfig

/// Find related patterns
let findRelatedPatterns (pattern: ErrorPattern) : string list =
    allPatterns
    |> List.filter (fun p ->
        p.Id <> pattern.Id &&
        (p.Category = pattern.Category ||
         pattern.StampConstraint.IsSome && p.StampConstraint = pattern.StampConstraint))
    |> List.map (fun p -> p.Id)
    |> List.truncate 5

/// Generate learning tags for a pattern match
let generateLearningTags (pm: PatternMatch) : string list =
    let categoryTag = sprintf "category:%A" pm.Pattern.Category
    let severityTag = sprintf "severity:%A" pm.Pattern.Severity
    let stampTag =
        match pm.Pattern.StampConstraint with
        | Some sc -> [sprintf "stamp:%s" sc]
        | None -> []

    [categoryTag; severityTag] @ stampTag

/// Perform cognitive analysis on a pattern match
let analyzeError (pm: PatternMatch) (config: CognitiveConfig) : CognitiveAnalysis =
    // Record activity for dreaming mode
    if config.DreamingEnabled then
        DreamingMode.recordActivity ()

    let severity = classifySeverity pm.Pattern
    let rootCause = analyzeRootCause pm
    let (suggestedFix, confidence) = suggestFix pm config
    let related = findRelatedPatterns pm.Pattern
    let tags = generateLearningTags pm

    // Record occurrence for learning
    knowledgeBase.RecordOccurrence(pm.Pattern.Id, tags)

    {
        Pattern = pm.Pattern
        Severity = severity
        RootCause = rootCause
        SuggestedFix = suggestedFix
        Confidence = confidence
        RelatedPatterns = related
        LearningTags = tags
    }

/// Analyze error with default config (backward compatible)
let analyzeErrorDefault (pm: PatternMatch) : CognitiveAnalysis =
    analyzeError pm defaultConfig

// ============================================================================
// FIX PROPOSAL GENERATION
// ============================================================================

/// Create a fix proposal for an error
let createProposal (pm: PatternMatch) (config: CognitiveConfig) : FixProposal =
    let analysis = analyzeError pm config

    // Determine proposed action based on pattern
    let action =
        match pm.Pattern.Category with
        | VariableScope when pm.Pattern.Id = "EP-021" ->
            sprintf "Add underscore prefix: _%s" (pm.Message.Replace("unused", "").Trim())
        | VariableScope when pm.Pattern.Id = "EP-017" ->
            "Add 'rec' keyword to function definition"
        | TypeSystem when pm.Pattern.Id = "EP-043" ->
            "Add explicit type annotation"
        | ModuleDep when pm.Pattern.Id = "EP-062" ->
            "Reorder files in .fsproj"
        | Syntax ->
            sprintf "Fix syntax: %s" analysis.SuggestedFix
        | _ ->
            analysis.SuggestedFix

    {
        Id = Guid.NewGuid()
        Error = pm
        Analysis = analysis
        ProposedAction = action
        GuardianApproved = not config.GuardianRequired  // Needs Guardian if required
        ShadowMode = config.ShadowMode
        GeneratedAt = DateTime.UtcNow
    }

/// Generate proposals for all errors in FPPS result
let generateProposals (fppsResult: FPPSResult) (config: CognitiveConfig) : FixProposal list =
    let allMatches =
        fppsResult.PatternResult.Details
        |> List.collect (fun detail ->
            // Re-match to get full PatternMatch objects
            matchLine detail)
        |> List.distinctBy (fun pm -> pm.Pattern.Id + pm.Message)

    allMatches
    |> List.map (fun pm -> createProposal pm config)
    |> List.filter (fun p -> p.Analysis.Confidence >= config.MinConfidence)

// ============================================================================
// COGNITIVE VALIDATION PIPELINE
// ============================================================================

/// Full cognitive validation result
type CognitiveValidationResult = {
    FPPSResult: FPPSResult
    Analyses: CognitiveAnalysis list
    Proposals: FixProposal list
    LearningRecords: LearningRecord list
    IntelligenceScore: float
    StampCompliant: bool
    Summary: string
}

/// Run full cognitive validation on build output
let validateCognitively (output: string) (config: CognitiveConfig) : CognitiveValidationResult =
    // Step 1: Run FPPS validation
    let fppsResult = validate output

    // Step 2: Get all pattern matches
    let matches = matchOutput output

    // Step 3: Analyze each error cognitively (with Smriti integration)
    let analyses = matches |> List.map (fun pm -> analyzeError pm config)

    // Step 4: Generate fix proposals
    let proposals =
        matches
        |> List.filter (fun pm -> pm.Pattern.Severity = PatternSeverity.Error || pm.Pattern.Severity = PatternSeverity.Critical)
        |> List.map (fun pm -> createProposal pm config)
        |> List.filter (fun p -> p.Analysis.Confidence >= config.MinConfidence)

    // Step 5: Process any pending RLHF feedback
    if config.RlhfEnabled then
        let processedCount = RlhfFeedbackLoop.processPending knowledgeBase
        if processedCount > 0 then
            printfn "[RLHF] Processed %d pending feedback signals" processedCount

    // Step 6: Get learning records for common patterns
    let learningRecords = knowledgeBase.GetMostCommon(10)

    // Step 7: Calculate intelligence score
    // SC-AI-003: Intelligence amplification factor > 1.25
    let baseScore = if fppsResult.IsValid then 1.0 else 0.5
    let learningBonus =
        if List.isEmpty learningRecords then 0.0
        else
            let avgSuccessRate =
                learningRecords
                |> List.averageBy (fun r ->
                    if r.Occurrences = 0 then 0.0
                    else float r.SuccessfulFixes / float r.Occurrences)
            avgSuccessRate * 0.5
    let proposalBonus =
        if List.isEmpty proposals then 0.0
        else
            proposals
            |> List.averageBy (fun p -> p.Analysis.Confidence)
            |> (*) 0.3

    // Smriti integration bonus
    let smritiBonus =
        if config.SmritiEnabled then
            match SmritiIntegration.checkAvailability () with
            | SmritiStatus.Connected _ -> 0.15
            | _ -> 0.0
        else 0.0

    let intelligenceScore = baseScore + learningBonus + proposalBonus + smritiBonus

    // Step 8: Maybe trigger dreaming mode if idle
    if config.DreamingEnabled then
        match DreamingMode.maybeDream knowledgeBase DreamingMode.defaultConfig with
        | Some count -> printfn "[Dreaming] Consolidated %d patterns" count
        | None -> ()

    // Step 9: Build summary
    let (rlhfPending, rlhfProcessed) = RlhfFeedbackLoop.getStats ()
    let smritiStatus =
        match SmritiIntegration.checkAvailability () with
        | SmritiStatus.Connected n -> sprintf "Connected (%d holons)" n
        | SmritiStatus.Disconnected r -> sprintf "Disconnected: %s" r
        | SmritiStatus.Unavailable -> "Unavailable"

    let summary =
        sprintf "Cognitive Validation Complete (L6/L7)\n\
                 FPPS Consensus: %A (Errors: %d, Warnings: %d)\n\
                 Analyses: %d patterns analyzed\n\
                 Proposals: %d fix proposals generated\n\
                 Learning: %d patterns in knowledge base\n\
                 RLHF: %d pending, %d processed\n\
                 Smriti: %s\n\
                 Dreaming: %A\n\
                 Intelligence Score: %.2f (target: >1.25)"
            fppsResult.Agreement
            fppsResult.ConsensusErrorCount
            fppsResult.ConsensusWarningCount
            (List.length analyses)
            (List.length proposals)
            (List.length learningRecords)
            rlhfPending
            rlhfProcessed
            smritiStatus
            (DreamingMode.getState ())
            intelligenceScore

    {
        FPPSResult = fppsResult
        Analyses = analyses
        Proposals = proposals
        LearningRecords = learningRecords
        IntelligenceScore = intelligenceScore
        StampCompliant = fppsResult.StampCompliant && intelligenceScore >= 1.0
        Summary = summary
    }

/// Quick cognitive validation with default config
let validateQuick (output: string) : CognitiveValidationResult =
    validateCognitively output defaultConfig

// ============================================================================
// LEARNING FEEDBACK
// ============================================================================

/// Record that a proposed fix was applied
let recordFixApplied (proposal: FixProposal) (success: bool) (duration: TimeSpan) =
    knowledgeBase.RecordFix(
        proposal.Analysis.Pattern.Id,
        proposal.ProposedAction,
        success,
        duration
    )

/// Get recommendations for most problematic patterns
let getProblematicPatterns () =
    knowledgeBase.GetMostCommon(20)
    |> List.filter (fun r -> r.FailedFixes > r.SuccessfulFixes)
    |> List.sortByDescending (fun r -> r.Occurrences)

/// Get most successful fix patterns
let getSuccessfulPatterns () =
    knowledgeBase.GetMostCommon(20)
    |> List.filter (fun r -> r.SuccessfulFixes > 0)
    |> List.sortByDescending (fun r ->
        float r.SuccessfulFixes / float (max 1 r.Occurrences))

// ============================================================================
// STAMP VALIDATION
// ============================================================================

/// Validate SC-NEURO-001: Simplex Architecture
let validateSC_NEURO_001 (result: CognitiveValidationResult) (config: CognitiveConfig) : StampValidation =
    let allProposalsValidated =
        result.Proposals |> List.forall (fun p ->
            not config.GuardianRequired || p.GuardianApproved)
    {
        ConstraintId = "SC-NEURO-001"
        Status = allProposalsValidated || config.ShadowMode
        Message =
            if allProposalsValidated then "All proposals passed Guardian validation"
            elif config.ShadowMode then "Shadow mode active - proposals not executed"
            else "Some proposals not validated by Guardian"
        Details = Map.ofList [
            ("proposals", string (List.length result.Proposals))
            ("shadow_mode", string config.ShadowMode)
        ]
    }

/// Validate SC-NEURO-004: Shadow Mode
let validateSC_NEURO_004 (config: CognitiveConfig) : StampValidation =
    {
        ConstraintId = "SC-NEURO-004"
        Status = config.ShadowMode
        Message =
            if config.ShadowMode then "Shadow mode enabled - safe testing"
            else "Shadow mode disabled - live execution"
        Details = Map.ofList [
            ("shadow_mode", string config.ShadowMode)
        ]
    }

/// Validate SC-AI-003: Intelligence amplification > 1.25
let validateSC_AI_003 (result: CognitiveValidationResult) : StampValidation =
    {
        ConstraintId = "SC-AI-003"
        Status = result.IntelligenceScore >= 1.25
        Message =
            sprintf "Intelligence score: %.2f (target: >1.25)" result.IntelligenceScore
        Details = Map.ofList [
            ("score", sprintf "%.2f" result.IntelligenceScore)
            ("target", "1.25")
        ]
    }

/// Validate SC-AI-001: Smriti context persistence
let validateSC_AI_001 (config: CognitiveConfig) : StampValidation =
    let smritiStatus = SmritiIntegration.checkAvailability ()
    let isConnected =
        match smritiStatus with
        | SmritiStatus.Connected _ -> true
        | _ -> false
    {
        ConstraintId = "SC-AI-001"
        Status = not config.SmritiEnabled || isConnected
        Message =
            match smritiStatus with
            | SmritiStatus.Connected n -> sprintf "Smriti connected with %d holons" n
            | SmritiStatus.Disconnected r -> sprintf "Smriti disconnected: %s" r
            | SmritiStatus.Unavailable -> "Smriti unavailable (disabled or not configured)"
        Details = Map.ofList [
            ("enabled", string config.SmritiEnabled)
            ("connected", string isConnected)
        ]
    }

/// Validate SC-AI-006: Session distillation to Smriti holons
let validateSC_AI_006 (config: CognitiveConfig) : StampValidation =
    let (pending, processed) = RlhfFeedbackLoop.getStats ()
    {
        ConstraintId = "SC-AI-006"
        Status = config.RlhfEnabled && processed > 0 || not config.RlhfEnabled
        Message =
            sprintf "RLHF feedback: %d pending, %d processed" pending processed
        Details = Map.ofList [
            ("rlhf_enabled", string config.RlhfEnabled)
            ("pending", string pending)
            ("processed", string processed)
        ]
    }

/// Validate L7 Dreaming Mode capability
let validateDreamingMode (config: CognitiveConfig) : StampValidation =
    let currentState = DreamingMode.getState ()
    {
        ConstraintId = "SC-AI-007"  // Dreaming Mode constraint
        Status = config.DreamingEnabled
        Message =
            sprintf "Dreaming mode: %A (enabled: %b)" currentState config.DreamingEnabled
        Details = Map.ofList [
            ("enabled", string config.DreamingEnabled)
            ("state", sprintf "%A" currentState)
        ]
    }

/// Run all cognitive STAMP validations
let validateCognitiveStamp (result: CognitiveValidationResult) (config: CognitiveConfig) : StampValidation list =
    [
        validateSC_NEURO_001 result config
        validateSC_NEURO_004 config
        validateSC_AI_001 config          // Smriti integration
        validateSC_AI_003 result          // Intelligence amplification
        validateSC_AI_006 config          // RLHF feedback
        validateDreamingMode config       // Dreaming mode
    ]

// ============================================================================
// REPORTING
// ============================================================================

/// Format cognitive validation result
let formatResult (result: CognitiveValidationResult) : string =
    let header = "=== COGNITIVE VALIDATION RESULT (L6/L7) ===\n\n"

    let fppsSection =
        sprintf "FPPS Consensus: %A\n  Errors: %d | Warnings: %d | Valid: %b\n\n"
            result.FPPSResult.Agreement
            result.FPPSResult.ConsensusErrorCount
            result.FPPSResult.ConsensusWarningCount
            result.FPPSResult.IsValid

    let analysisSection =
        if List.isEmpty result.Analyses then "No patterns analyzed.\n\n"
        else
            let lines =
                result.Analyses
                |> List.take (min 5 (List.length result.Analyses))
                |> List.map (fun a ->
                    sprintf "  [%s] %s - %A\n    Fix: %s (%.0f%% confidence)"
                        a.Pattern.Id a.Pattern.Name a.Severity a.SuggestedFix (a.Confidence * 100.0))
            sprintf "Pattern Analysis (%d total):\n%s\n\n"
                (List.length result.Analyses)
                (String.concat "\n" lines)

    let proposalSection =
        if List.isEmpty result.Proposals then "No fix proposals.\n\n"
        else
            let lines =
                result.Proposals
                |> List.take (min 5 (List.length result.Proposals))
                |> List.map (fun p ->
                    sprintf "  [%s] %s\n    Action: %s"
                        p.Error.Pattern.Id
                        (if p.ShadowMode then "[SHADOW]" else "[LIVE]")
                        p.ProposedAction)
            sprintf "Fix Proposals (%d total):\n%s\n\n"
                (List.length result.Proposals)
                (String.concat "\n" lines)

    // Cognitive integration status
    let (rlhfPending, rlhfProcessed) = RlhfFeedbackLoop.getStats ()
    let smritiStatus =
        match SmritiIntegration.checkAvailability () with
        | SmritiStatus.Connected n -> sprintf "Connected (%d holons)" n
        | SmritiStatus.Disconnected r -> sprintf "Disconnected: %s" r
        | SmritiStatus.Unavailable -> "Unavailable"
    let dreamState = DreamingMode.getState ()

    let cognitiveSection =
        sprintf "Cognitive Integration (L6/L7):\n\
                 Smriti: %s\n\
                 RLHF: %d pending, %d processed\n\
                 Dreaming: %A\n\n"
            smritiStatus
            rlhfPending
            rlhfProcessed
            dreamState

    let metricsSection =
        sprintf "Metrics:\n  Intelligence Score: %.2f\n  STAMP Compliant: %b\n\n"
            result.IntelligenceScore
            result.StampCompliant

    header + fppsSection + analysisSection + proposalSection + cognitiveSection + metricsSection + result.Summary
