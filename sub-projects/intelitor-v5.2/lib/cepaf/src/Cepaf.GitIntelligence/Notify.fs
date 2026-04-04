// =============================================================================
// Git Intelligence — Zenoh Event Notification & System Integration
// =============================================================================
// Purpose:  Publish git events to Zenoh mesh so the entire system knows what
//           is happening with git in real-time. Dual-write pattern per
//           SC-ZTEST-008: Zenoh FFI + stderr log fallback.
//
// Topics:   indrajaal/git/commit        — commit events (sha, message, type, scope)
//           indrajaal/git/health        — GHS score updates
//           indrajaal/git/validate      — validation results
//           indrajaal/git/suggest       — AI-suggested messages
//           indrajaal/git/homeostasis   — PID state, mode, guidance
//           indrajaal/git/federation    — peer GHS exchange
//           indrajaal/git/constitutional — safety check results
//           indrajaal/git/multiverse    — fork/promote/prune
//           indrajaal/git/biomorphic    — full assessment
//           indrajaal/git/threat        — detected patterns
//           indrajaal/git/homeostatic   — PID + guidance
//           indrajaal/git/neural        — AI recommendation
//           indrajaal/git/vital         — vital signs
//           indrajaal/git/alignment     — Founder alignment
//
// STAMP:    SC-ZENOH-001, SC-ZTEST-008, SC-BUS-001, SC-OBS-069
// AOR:      AOR-ZTEST-008 (log fallback first), AOR-FFI-006 (dual-write)
// =============================================================================

module Cepaf.GitIntelligence.Notify

open System
open System.Runtime.InteropServices
open System.Text

// ─────────────────────────────────────────────────────────────────────────────
// Minimal Zenoh FFI — standalone DllImport (no Cepaf dependency)
// ─────────────────────────────────────────────────────────────────────────────

module private ZenohFfi =

    let [<Literal>] private LibName = "zenoh_ffi"

    [<DllImport(LibName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)>]
    extern nativeint zenoh_ffi_open(byte[] config_json)

    [<DllImport(LibName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)>]
    extern int zenoh_ffi_publish(nativeint handle, byte[] key, byte[] payload, unativeint payload_len)

    [<DllImport(LibName, CallingConvention = CallingConvention.Cdecl)>]
    extern void zenoh_ffi_close(nativeint handle)

// ─────────────────────────────────────────────────────────────────────────────
// Session management — lazy init, single session for CLI lifetime
// ─────────────────────────────────────────────────────────────────────────────

let mutable private session: nativeint = 0n
let mutable private zenohAvailable: bool option = None

/// Try to open a Zenoh session. Returns true if successful.
let private ensureSession () : bool =
    match zenohAvailable with
    | Some v -> v && session <> 0n
    | None ->
        try
            let config = """{"mode":"client","connect":{"endpoints":["tcp/127.0.0.1:7447"]}}"""
            let configBytes = Encoding.UTF8.GetBytes(config)
            session <- ZenohFfi.zenoh_ffi_open(configBytes)
            zenohAvailable <- Some (session <> 0n)
            session <> 0n
        with
        | :? DllNotFoundException ->
            zenohAvailable <- Some false
            false
        | :? EntryPointNotFoundException ->
            zenohAvailable <- Some false
            false
        | _ ->
            zenohAvailable <- Some false
            false

/// Publish a payload to a Zenoh topic. Returns true if published via Zenoh.
let zenohPublish (topic: string) (payload: string) : bool =
    if ensureSession() then
        try
            let keyBytes = Encoding.UTF8.GetBytes(topic + "\x00")
            let payloadBytes = Encoding.UTF8.GetBytes(payload)
            let result = ZenohFfi.zenoh_ffi_publish(session, keyBytes, payloadBytes, unativeint payloadBytes.Length)
            result = 0
        with _ -> false
    else
        false

/// Close the Zenoh session (call on process exit).
let closeSession () =
    if session <> 0n then
        try ZenohFfi.zenoh_ffi_close(session) with _ -> ()
        session <- 0n

// ─────────────────────────────────────────────────────────────────────────────
// JSON helpers — simple string escaping (no dependency on System.Text.Json)
// ─────────────────────────────────────────────────────────────────────────────

let private escapeJson (s: string) : string =
    s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\n", "\\n").Replace("\r", "\\r").Replace("\t", "\\t")

let private jsonArray (items: string list) : string =
    items |> List.map (sprintf "\"%s\"") |> String.concat "," |> sprintf "[%s]"

let private timestamp () = DateTime.UtcNow.ToString("o")

// ─────────────────────────────────────────────────────────────────────────────
// Event publishers — dual-write: log fallback FIRST, then Zenoh (AOR-ZTEST-008)
// ─────────────────────────────────────────────────────────────────────────────

/// Publish a commit event after successful git commit.
let publishCommitEvent
    (sha: string)
    (message: string)
    (commitType: string)
    (scopes: string list)
    (ghs: float option)
    (filesChanged: int)
    : bool =
    let ghsStr = match ghs with Some g -> sprintf "%.4f" g | None -> "null"
    let scopeArr = jsonArray (scopes |> List.map escapeJson)
    let ts = timestamp()
    let payload = $"""{{"event":"commit","sha":"{escapeJson sha}","message":"{escapeJson message}","type":"{escapeJson commitType}","scopes":{scopeArr},"ghs":{ghsStr},"filesChanged":{filesChanged},"timestamp":"{ts}"}}"""

    // SC-ZTEST-008: Log fallback FIRST (always succeeds)
    eprintfn "[GIT-EVENT] topic=indrajaal/git/commit %s" payload
    // Then try Zenoh (may fail gracefully)
    zenohPublish "indrajaal/git/commit" payload

/// Publish a health score update (Analysis).
let publishHealthEvent (ghs: float) (icpAdoption: float) (scopeCompliance: float) (totalCommits: int) : bool =
    let ts = timestamp()
    let payload = $"""{{"event":"health","ghs":{sprintf "%.4f" ghs},"icpAdoption":{sprintf "%.1f" icpAdoption},"scopeCompliance":{sprintf "%.1f" scopeCompliance},"totalCommits":{totalCommits},"timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/health %s" payload
    zenohPublish "indrajaal/git/health" payload

/// Publish an analysis event with full metrics.
let publishAnalyzeEvent (ghs: float) (commitsAnalyzed: int) (typeEntropy: float) (semanticDensity: float) : bool =
    let ts = timestamp()
    let payload = $"""{{"event":"analyze","ghs":{sprintf "%.4f" ghs},"commitsAnalyzed":{commitsAnalyzed},"typeEntropy":{sprintf "%.4f" typeEntropy},"semanticDensity":{sprintf "%.4f" semanticDensity},"timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/analyze %s" payload
    zenohPublish "indrajaal/git/analyze" payload

/// Publish a classification event.
let publishClassifyEvent (subject: string) (style: string) (density: float) : bool =
    let ts = timestamp()
    let payload = $"""{{"event":"classify","subject":"{escapeJson subject}","style":"{escapeJson style}","density":{sprintf "%.4f" density},"timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/classify %s" payload
    zenohPublish "indrajaal/git/classify" payload

/// Publish a generation event.
let publishGenerateEvent (message: string) (commitType: string) (scopes: string list) : bool =
    let scopeArr = jsonArray (scopes |> List.map escapeJson)
    let ts = timestamp()
    let payload = $"""{{"event":"generate","message":"{escapeJson message}","type":"{escapeJson commitType}","scopes":{scopeArr},"timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/generate %s" payload
    zenohPublish "indrajaal/git/generate" payload

/// Publish a validation result.
let publishValidateEvent (message: string) (valid: bool) (issues: string list) : bool =
    let validStr = if valid then "true" else "false"
    let issueArr = jsonArray (issues |> List.map escapeJson)
    let ts = timestamp()
    let payload = $"""{{"event":"validate","message":"{escapeJson message}","valid":{validStr},"issues":{issueArr},"timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/validate %s" payload
    zenohPublish "indrajaal/git/validate" payload

/// Publish an AI suggestion event.
let publishSuggestEvent (diff: string) (suggestion: string) (model: string) : bool =
    let diffLines = diff.Split('\n').Length
    let ts = timestamp()
    let payload = $"""{{"event":"suggest","diffLines":{diffLines},"suggestion":"{escapeJson suggestion}","model":"{escapeJson model}","timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/suggest %s" payload
    zenohPublish "indrajaal/git/suggest" payload

// ─────────────────────────────────────────────────────────────────────────────
// Infrastructure event publishers (L3/L7/L8/L9)
// ─────────────────────────────────────────────────────────────────────────────

/// Publish a homeostasis event (PID state, mode, guidance).
let publishHomeostasisEvent (mode: string) (ghs: float) (target: float) (pidOutput: float) (guidance: string list) : bool =
    let guidanceArr = jsonArray (guidance |> List.map escapeJson)
    let ts = timestamp()
    let payload = $"""{{"event":"homeostasis","mode":"{escapeJson mode}","ghs":{sprintf "%.4f" ghs},"target":{sprintf "%.4f" target},"pidOutput":{sprintf "%.4f" pidOutput},"guidance":{guidanceArr},"timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/homeostasis %s" payload
    zenohPublish "indrajaal/git/homeostasis" payload

/// Publish a federation event (peer GHS exchange).
let publishFederationEvent (peerId: string) (peerGhs: float option) (protocolVersion: string) (attested: bool) : bool =
    let ghsStr = match peerGhs with Some g -> sprintf "%.4f" g | None -> "null"
    let attestedStr = if attested then "true" else "false"
    let ts = timestamp()
    let payload = $"""{{"event":"federation","peerId":"{escapeJson peerId}","peerGhs":{ghsStr},"protocol":"{escapeJson protocolVersion}","attested":{attestedStr},"timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/federation %s" payload
    zenohPublish "indrajaal/git/federation" payload

/// Publish a constitutional invariant check result.
let publishConstitutionalEvent (invariantId: string) (passed: bool) (score: float) (details: string) : bool =
    let passedStr = if passed then "true" else "false"
    let ts = timestamp()
    let payload = $"""{{"event":"constitutional","invariantId":"{escapeJson invariantId}","passed":{passedStr},"score":{sprintf "%.4f" score},"details":"{escapeJson details}","timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/constitutional %s" payload
    zenohPublish "indrajaal/git/constitutional" payload

/// Publish a multiverse event (fork, promote, prune).
let publishMultiverseEvent (action: string) (universeId: string) (branchName: string) (ghs: float option) : bool =
    let ghsStr = match ghs with Some g -> sprintf "%.4f" g | None -> "null"
    let ts = timestamp()
    let payload = $"""{{"event":"multiverse","action":"{escapeJson action}","universeId":"{escapeJson universeId}","branch":"{escapeJson branchName}","ghs":{ghsStr},"timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/multiverse %s" payload
    zenohPublish "indrajaal/git/multiverse" payload

// ─────────────────────────────────────────────────────────────────────────────
// Biomorphic event publishers (5 subsystems)
// ─────────────────────────────────────────────────────────────────────────────

/// Publish a full biomorphic assessment event.
let publishBiomorphicEvent (overallHealth: float) (immunityScore: float) (threatLevel: string) (shouldHalt: bool) : bool =
    let haltStr = if shouldHalt then "true" else "false"
    let ts = timestamp()
    let payload = $"""{{"event":"biomorphic","overallHealth":{sprintf "%.4f" overallHealth},"immunityScore":{sprintf "%.4f" immunityScore},"threatLevel":"{escapeJson threatLevel}","shouldHalt":{haltStr},"timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/biomorphic %s" payload
    zenohPublish "indrajaal/git/biomorphic" payload

/// Publish a threat detection event from the immune system.
let publishThreatEvent (threatLevel: string) (patternCount: int) (patterns: string list) (immunityScore: float) : bool =
    let patternArr = jsonArray (patterns |> List.map escapeJson)
    let ts = timestamp()
    let payload = $"""{{"event":"threat","threatLevel":"{escapeJson threatLevel}","patternCount":{patternCount},"patterns":{patternArr},"immunityScore":{sprintf "%.4f" immunityScore},"timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/threat %s" payload
    zenohPublish "indrajaal/git/threat" payload

/// Publish a homeostatic PID controller event with guidance.
let publishHomeostaticEvent (mode: string) (pidOutput: float) (integral: float) (error: float) : bool =
    let ts = timestamp()
    let payload = $"""{{"event":"homeostatic","mode":"{escapeJson mode}","pidOutput":{sprintf "%.4f" pidOutput},"integral":{sprintf "%.4f" integral},"error":{sprintf "%.4f" error},"timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/homeostatic %s" payload
    zenohPublish "indrajaal/git/homeostatic" payload

/// Publish a neural/AI recommendation event.
let publishNeuralEvent (suggestedMessage: string) (semanticQuality: float) (confidence: float) (model: string) (isHeuristic: bool) : bool =
    let heuristicStr = if isHeuristic then "true" else "false"
    let ts = timestamp()
    let payload = $"""{{"event":"neural","suggestedMessage":"{escapeJson suggestedMessage}","semanticQuality":{sprintf "%.4f" semanticQuality},"confidence":{sprintf "%.4f" confidence},"model":"{escapeJson model}","isHeuristic":{heuristicStr},"timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/neural %s" payload
    zenohPublish "indrajaal/git/neural" payload

/// Publish vital signs from the regenerative system.
let publishVitalEvent (healthIndex: float) (stressIndex: float) (energyIndex: float) (actions: string list) : bool =
    let actionArr = jsonArray (actions |> List.map escapeJson)
    let ts = timestamp()
    let payload = $"""{{"event":"vital","healthIndex":{sprintf "%.4f" healthIndex},"stressIndex":{sprintf "%.4f" stressIndex},"energyIndex":{sprintf "%.4f" energyIndex},"actions":{actionArr},"timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/vital %s" payload
    zenohPublish "indrajaal/git/vital" payload

/// Publish Founder's Directive alignment scores from the symbiotic system.
let publishAlignmentEvent (survivalScore: float) (sentienceScore: float) (powerScore: float) (overallAlignment: float) : bool =
    let ts = timestamp()
    let payload = $"""{{"event":"alignment","survivalScore":{sprintf "%.4f" survivalScore},"sentienceScore":{sprintf "%.4f" sentienceScore},"powerScore":{sprintf "%.4f" powerScore},"overallAlignment":{sprintf "%.4f" overallAlignment},"timestamp":"{ts}"}}"""

    eprintfn "[GIT-EVENT] topic=indrajaal/git/alignment %s" payload
    zenohPublish "indrajaal/git/alignment" payload
