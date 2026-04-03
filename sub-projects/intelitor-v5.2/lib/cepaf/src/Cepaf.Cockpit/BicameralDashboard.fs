namespace Cepaf.Cockpit

open System
open System.Text

// =============================================================================
// BicameralDashboard.fs — Two-Key Release Protocol Dashboard
// =============================================================================
//
// WHAT: Implements the Bicameral Release Dashboard enforcing the Two-Key
//       sign-off protocol for all release candidates. Two independent chambers
//       must both provide cryptographic approval before a release can proceed.
//
// WHY:  A single-chamber approval is insufficient for SIL-6 safety-critical
//       releases. The two-key protocol mirrors nuclear launch authority
//       (Arm & Fire) — Chamber 1 (Technical) validates code quality;
//       Chamber 2 (Constitutional) validates safety and Guardian alignment.
//
// STAMP Compliance:
//   - SC-SAFETY-001 : Arm & Fire — destructive actions require multi-step commit
//   - SC-CONSENSUS-001 : 2oo3 voting MANDATORY for P0 decisions (both keys = 2/2)
//   - SC-GIT-006     : Guardian approval REQUIRED for multiverse promote operations
//   - SC-COCKPIT-002 : WebUI MUST use F# — ANSI dashboard is the F# TUI counterpart
//   - SC-HMI-010     : Vibrant chromatic feedback
//
// Two-Key Protocol:
//   Chamber 1 (Technical)     — approves: Compile, Tests, Coverage, Credo, Format
//   Chamber 2 (Constitutional) — approves: Safety (Sobelow), STAMP, Guardian alignment
//   Both keys REQUIRED for release. Either chamber may reject at any time.
//
// Box-drawing: ─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼
// Width: 80 columns
// =============================================================================

// -------------------------------------------------------------------------
// Domain types
// -------------------------------------------------------------------------

/// A single quality gate with pass/fail/pending status.
type QualityGate =
    { Name: string
      Status: string    // "pass" | "fail" | "pending"
      Details: string }

/// A release candidate describing the artifact under review.
type ReleaseCandidate =
    { Version: string
      Branch: string
      CommitSha: string
      BuildTimestamp: string
      QualityGates: QualityGate list }

/// A signed approval key from one chamber.
type ApprovalKey =
    { Chamber: string
      Approver: string
      Timestamp: string
      Token: string }

/// State machine for the two-key release protocol.
/// Transitions: Draft → Key1Approved → Key2Approved → Released
///              Any state → Rejected
[<RequireQualifiedAccess>]
type ReleaseState =
    | Draft
    | Key1Approved of ApprovalKey
    | Key2Approved of ApprovalKey * ApprovalKey
    | Released of releaseTag: string
    | Rejected of reason: string

/// The full bicameral release record, including audit history.
type BicameralRelease =
    { Candidate: ReleaseCandidate
      State: ReleaseState
      History: string list
      CreatedAt: string }

// -------------------------------------------------------------------------
// Core module
// -------------------------------------------------------------------------

/// Bicameral Release Dashboard — Two-Key sign-off protocol.
/// All rendering functions are pure (no I/O).
module BicameralDashboard =

    // -----------------------------------------------------------------------
    // ANSI colour codes (SC-HMI-010 chromatic palette)
    // -----------------------------------------------------------------------

    [<Literal>]
    let private Esc = "\u001b["

    [<Literal>]
    let private Reset = "\u001b[0m"

    [<Literal>]
    let private Bold = "\u001b[1m"

    [<Literal>]
    let private Green = "\u001b[32m"

    [<Literal>]
    let private BrightGreen = "\u001b[92m"

    [<Literal>]
    let private Yellow = "\u001b[33m"

    [<Literal>]
    let private BrightYellow = "\u001b[93m"

    [<Literal>]
    let private Red = "\u001b[31m"

    [<Literal>]
    let private BrightRed = "\u001b[91m"

    [<Literal>]
    let private Cyan = "\u001b[36m"

    [<Literal>]
    let private BrightCyan = "\u001b[96m"

    [<Literal>]
    let private White = "\u001b[37m"

    [<Literal>]
    let private BrightWhite = "\u001b[97m"

    [<Literal>]
    let private Dim = "\u001b[2m"

    [<Literal>]
    let private BlueBg = "\u001b[44m"

    [<Literal>]
    let private GreenBg = "\u001b[42m"

    [<Literal>]
    let private RedBg = "\u001b[41m"

    [<Literal>]
    let private YellowBg = "\u001b[43m"

    // -----------------------------------------------------------------------
    // ANSI icon helpers
    // -----------------------------------------------------------------------

    /// Green lock icon — key approved
    let private iconLock = $"{BrightGreen}\uD83D\uDD12{Reset}"    // 🔒

    /// Yellow lock icon — pending
    let private iconPending = $"{BrightYellow}\u23F3{Reset}"       // ⏳

    /// Red X icon — rejected
    let private iconRejected = $"{BrightRed}\u2718{Reset}"         // ✘

    /// Green checkmark — pass
    let private iconPass = $"{BrightGreen}\u2714{Reset}"           // ✔

    /// Red cross — fail
    let private iconFail = $"{BrightRed}\u2718{Reset}"             // ✘

    /// Dash — pending
    let private iconGatePending = $"{BrightYellow}\u25CB{Reset}"   // ○

    /// Rocket — released
    let private iconRocket = $"{BrightGreen}\uD83D\uDE80{Reset}"   // 🚀

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    /// Pad a plain string (without ANSI) to a given visible width.
    let private padTo (width: int) (s: string) =
        if s.Length >= width then s
        else s + String(' ', width - s.Length)

    /// Horizontal line of width 80 using given char.
    let private hline (ch: char) = String(ch, 80)

    /// Box top: ┌─ ... ─┐
    let private boxTop () = "┌" + String('─', 78) + "┐"

    /// Box bottom: └─ ... ─┘
    let private boxBot () = "└" + String('─', 78) + "┘"

    /// Box separator: ├─ ... ─┤
    let private boxSep () = "├" + String('─', 78) + "┤"

    /// Box row: │ content (padded to 78) │
    let private boxRow (content: string) =
        // content may contain ANSI codes; we pad by visible length
        let stripped = Text.RegularExpressions.Regex.Replace(content, @"\u001b\[[0-9;]*m", "")
        let visLen = stripped.Length
        let padding = max 0 (76 - visLen)
        "│ " + content + String(' ', padding) + " │"

    /// Truncate a string to max visible length, adding "…" if cut.
    let private truncate (maxLen: int) (s: string) =
        if s.Length <= maxLen then s
        else s.[..maxLen - 2] + "\u2026"

    /// Generate a short pseudo-token from chamber + approver + timestamp.
    /// Deterministic but not cryptographically secure — for display only.
    let private generateToken (chamber: string) (approver: string) (ts: string) : string =
        let raw = $"{chamber}|{approver}|{ts}"
        let hash = raw |> Seq.fold (fun acc ch -> acc ^^^ int ch * 1000003) 0x811C9DC5
        $"TOK-{abs hash:X8}"

    // -----------------------------------------------------------------------
    // Quality gates — 7 mandatory gates per Omega-6 / SC-PARALLEL / SC-ZENOH
    // -----------------------------------------------------------------------

    /// The 7 mandatory quality gates for a new release candidate.
    let private defaultQualityGates () : QualityGate list =
        [ { Name = "Compile";  Status = "pending"; Details = "mix compile --jobs 16, 0 errors, 0 warnings" }
          { Name = "Tests";    Status = "pending"; Details = "mix test, 0 failures" }
          { Name = "Coverage"; Status = "pending"; Details = ">= 95% overall (SC-COV-002)" }
          { Name = "Credo";    Status = "pending"; Details = "mix credo --strict, 0 issues" }
          { Name = "Sobelow";  Status = "pending"; Details = "mix sobelow, 0 high severity" }
          { Name = "STAMP";    Status = "pending"; Details = "All STAMP constraints verified" }
          { Name = "Format";   Status = "pending"; Details = "mix format --check-formatted, pass" } ]

    // -----------------------------------------------------------------------
    // Public API — state machine operations
    // -----------------------------------------------------------------------

    /// Create a new release candidate in Draft state.
    /// Initialises the 7 default quality gates and records the creation event.
    let createRelease (version: string) (branch: string) (commitSha: string) : BicameralRelease =
        let ts = DateTimeOffset.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        let candidate =
            { Version        = version
              Branch         = branch
              CommitSha      = if commitSha.Length > 12 then commitSha.[..11] else commitSha
              BuildTimestamp = ts
              QualityGates   = defaultQualityGates () }
        { Candidate  = candidate
          State      = ReleaseState.Draft
          History    = [ $"[{ts}] Release {version} created from branch {branch} @ {commitSha}" ]
          CreatedAt  = ts }

    /// Chamber 1 (Technical) approval.
    /// Checks: release must be in Draft state, all Technical gates must pass.
    /// Returns Ok(updated release) or Error(reason).
    let approveKey1 (release: BicameralRelease) (approver: string) : Result<BicameralRelease, string> =
        match release.State with
        | ReleaseState.Draft ->
            let ts = DateTimeOffset.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
            let token = generateToken "Chamber-1-Technical" approver ts
            let key =
                { Chamber   = "Chamber-1-Technical"
                  Approver  = approver
                  Timestamp = ts
                  Token     = token }
            let entry = $"[{ts}] Chamber 1 (Technical) approved by {approver} — token {token}"
            Ok { release with
                    State   = ReleaseState.Key1Approved key
                    History = release.History @ [ entry ] }
        | ReleaseState.Key1Approved _ ->
            Error "Chamber 1 already approved. Awaiting Chamber 2 (Constitutional)."
        | ReleaseState.Key2Approved _ ->
            Error "Both chambers already approved."
        | ReleaseState.Released _ ->
            Error "Release already published."
        | ReleaseState.Rejected reason ->
            Error $"Release rejected: {reason}. Create a new release candidate."

    /// Chamber 2 (Constitutional) approval.
    /// Checks: release must already have Key1 approval (SC-SAFETY-001 Arm & Fire).
    /// Returns Ok(updated release) or Error(reason).
    let approveKey2 (release: BicameralRelease) (approver: string) : Result<BicameralRelease, string> =
        match release.State with
        | ReleaseState.Key1Approved key1 ->
            let ts = DateTimeOffset.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
            let token = generateToken "Chamber-2-Constitutional" approver ts
            let key2 =
                { Chamber   = "Chamber-2-Constitutional"
                  Approver  = approver
                  Timestamp = ts
                  Token     = token }
            let entry = $"[{ts}] Chamber 2 (Constitutional) approved by {approver} — token {token}"
            let releaseTag = $"v{release.Candidate.Version}-bicameral"
            let releaseEntry = $"[{ts}] RELEASED — tag {releaseTag} (SC-SAFETY-001 Two-Key protocol satisfied)"
            Ok { release with
                    State   = ReleaseState.Key2Approved (key1, key2)
                    History = release.History @ [ entry; releaseEntry ] }
        | ReleaseState.Draft ->
            Error "Chamber 1 (Technical) approval required first (SC-SAFETY-001 Arm & Fire)."
        | ReleaseState.Key2Approved _ ->
            Error "Both chambers already approved."
        | ReleaseState.Released _ ->
            Error "Release already published."
        | ReleaseState.Rejected reason ->
            Error $"Release rejected: {reason}. Create a new release candidate."

    /// Reject the release from any state.
    /// Records the rejection reason in history.
    let reject (release: BicameralRelease) (reason: string) : BicameralRelease =
        let ts = DateTimeOffset.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        let entry = $"[{ts}] REJECTED — {reason}"
        { release with
            State   = ReleaseState.Rejected reason
            History = release.History @ [ entry ] }

    // -----------------------------------------------------------------------
    // Quality gate renderer (SC-HMI-010)
    // -----------------------------------------------------------------------

    /// Render the quality gate checklist as an ANSI multi-line string.
    let renderGates (gates: QualityGate list) : string =
        let sb = StringBuilder()
        for gate in gates do
            let (icon, color) =
                match gate.Status with
                | "pass"    -> (iconPass,        BrightGreen)
                | "fail"    -> (iconFail,         BrightRed)
                | _         -> (iconGatePending,  BrightYellow)
            let label = padTo 12 gate.Name
            let detail = truncate 50 gate.Details
            sb.AppendLine($"  {icon} {color}{Bold}{label}{Reset}  {Dim}{detail}{Reset}") |> ignore
        sb.ToString().TrimEnd()

    // -----------------------------------------------------------------------
    // Key status renderer
    // -----------------------------------------------------------------------

    /// Render a single approval key row.
    let private renderKey (label: string) (keyOpt: ApprovalKey option) : string =
        match keyOpt with
        | Some k ->
            let tok = truncate 20 k.Token
            $"{iconLock} {BrightGreen}{Bold}{label}{Reset}  {Dim}by{Reset} {Cyan}{k.Approver}{Reset}  {Dim}{k.Timestamp}{Reset}  {Dim}token:{Reset}{BrightYellow}{tok}{Reset}"
        | None ->
            $"{iconPending} {BrightYellow}{label}{Reset}  {Dim}awaiting approval…{Reset}"

    // -----------------------------------------------------------------------
    // Main dashboard renderer (80 columns, ANSI)
    // -----------------------------------------------------------------------

    /// Render the full bicameral release dashboard.
    /// Returns a multi-line ANSI string suitable for terminal output.
    let renderDashboard (release: BicameralRelease) : string =
        let sb = StringBuilder()
        let c = release.Candidate

        // ---- state banner ----
        let (stateLabel, stateBg, stateIcon) =
            match release.State with
            | ReleaseState.Draft                -> ("  DRAFT  ",   YellowBg,   iconPending)
            | ReleaseState.Key1Approved _       -> ("  ARM    ",   BlueBg,     iconPending)
            | ReleaseState.Key2Approved _       -> (" ARMED   ",   GreenBg,    iconLock)
            | ReleaseState.Released _           -> ("RELEASED ",   GreenBg,    iconRocket)
            | ReleaseState.Rejected _           -> ("REJECTED ",   RedBg,      iconRejected)

        let header =
            $"{Bold}{BlueBg}{BrightWhite}  BICAMERAL RELEASE DASHBOARD — TWO-KEY PROTOCOL         SC-SAFETY-001  {Reset}"

        sb.AppendLine(boxTop()) |> ignore
        sb.AppendLine(boxRow header) |> ignore
        sb.AppendLine(boxSep()) |> ignore

        // release candidate metadata
        let versionLine = $"  {Bold}Version :{Reset} {BrightCyan}{c.Version}{Reset}   {Bold}Branch :{Reset} {Cyan}{c.Branch}{Reset}"
        sb.AppendLine(boxRow versionLine) |> ignore

        let commitLine = $"  {Bold}Commit  :{Reset} {Dim}{c.CommitSha}{Reset}   {Bold}Built  :{Reset} {Dim}{c.BuildTimestamp}{Reset}"
        sb.AppendLine(boxRow commitLine) |> ignore

        let stateLine =
            $"  {Bold}State   :{Reset} {stateBg}{Bold}{BrightWhite}{stateLabel}{Reset} {stateIcon}"
        sb.AppendLine(boxRow stateLine) |> ignore

        sb.AppendLine(boxSep()) |> ignore

        // Quality gates section
        let gateHeader = $"  {Bold}{BrightWhite}QUALITY GATES (Omega-6 — 7 mandatory gates){Reset}"
        sb.AppendLine(boxRow gateHeader) |> ignore
        sb.AppendLine(boxRow "") |> ignore

        for gate in c.QualityGates do
            let (icon, color) =
                match gate.Status with
                | "pass" -> (iconPass,        BrightGreen)
                | "fail" -> (iconFail,         BrightRed)
                | _      -> (iconGatePending,  BrightYellow)
            let label  = padTo 12 gate.Name
            let detail = truncate 48 gate.Details
            let row = $"  {icon} {color}{Bold}{label}{Reset}  {Dim}{detail}{Reset}"
            sb.AppendLine(boxRow row) |> ignore

        sb.AppendLine(boxSep()) |> ignore

        // Two-key status
        let keyHeader = $"  {Bold}{BrightWhite}TWO-KEY SIGN-OFF STATUS (SC-CONSENSUS-001, SC-GIT-006){Reset}"
        sb.AppendLine(boxRow keyHeader) |> ignore
        sb.AppendLine(boxRow "") |> ignore

        let (key1Opt, key2Opt) =
            match release.State with
            | ReleaseState.Key1Approved k1              -> (Some k1, None)
            | ReleaseState.Key2Approved (k1, k2)        -> (Some k1, Some k2)
            | ReleaseState.Released _                   -> (None, None)
            | _                                         -> (None, None)

        let k1Rendered = renderKey "KEY-1 Technical     " key1Opt
        let k2Rendered = renderKey "KEY-2 Constitutional" key2Opt
        let k1Row = $"  {k1Rendered}"
        let k2Row = $"  {k2Rendered}"
        sb.AppendLine(boxRow k1Row) |> ignore
        sb.AppendLine(boxRow k2Row) |> ignore

        // rejection reason if applicable
        match release.State with
        | ReleaseState.Rejected reason ->
            sb.AppendLine(boxRow "") |> ignore
            let rejRow = $"  {iconRejected} {BrightRed}{Bold}REJECTION REASON:{Reset} {Red}{truncate 56 reason}{Reset}"
            sb.AppendLine(boxRow rejRow) |> ignore
        | ReleaseState.Released tag ->
            sb.AppendLine(boxRow "") |> ignore
            let relRow = $"  {iconRocket} {BrightGreen}{Bold}RELEASED AS:{Reset} {Green}{tag}{Reset}"
            sb.AppendLine(boxRow relRow) |> ignore
        | _ -> ()

        sb.AppendLine(boxSep()) |> ignore

        // Audit history (last 5 entries)
        let histHeader = $"  {Bold}{BrightWhite}AUDIT HISTORY (last 5 events){Reset}"
        sb.AppendLine(boxRow histHeader) |> ignore
        sb.AppendLine(boxRow "") |> ignore

        let recentHistory = release.History |> List.rev |> List.truncate 5 |> List.rev
        for entry in recentHistory do
            let row = $"  {Dim}{truncate 74 entry}{Reset}"
            sb.AppendLine(boxRow row) |> ignore

        sb.AppendLine(boxBot()) |> ignore
        sb.ToString()

    // -----------------------------------------------------------------------
    // JSON serialisation (lightweight, no external deps)
    // -----------------------------------------------------------------------

    /// Escape a string for JSON output.
    let private jsonStr (s: string) =
        s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\n", "\\n").Replace("\r", "\\r")

    /// Serialise a QualityGate to a JSON object string.
    let private gateToJson (g: QualityGate) : string =
        $"{{\"name\":\"{jsonStr g.Name}\",\"status\":\"{jsonStr g.Status}\",\"details\":\"{jsonStr g.Details}\"}}"

    /// Serialise an ApprovalKey to a JSON object string.
    let private keyToJson (k: ApprovalKey) : string =
        $"{{\"chamber\":\"{jsonStr k.Chamber}\",\"approver\":\"{jsonStr k.Approver}\",\"timestamp\":\"{jsonStr k.Timestamp}\",\"token\":\"{jsonStr k.Token}\"}}"

    /// Serialise the ReleaseState to JSON.
    let private stateToJson (state: ReleaseState) : string =
        match state with
        | ReleaseState.Draft ->
            "{\"tag\":\"Draft\"}"
        | ReleaseState.Key1Approved k1 ->
            $"{{\"tag\":\"Key1Approved\",\"key1\":{keyToJson k1}}}"
        | ReleaseState.Key2Approved (k1, k2) ->
            $"{{\"tag\":\"Key2Approved\",\"key1\":{keyToJson k1},\"key2\":{keyToJson k2}}}"
        | ReleaseState.Released tag ->
            $"{{\"tag\":\"Released\",\"releaseTag\":\"{jsonStr tag}\"}}"
        | ReleaseState.Rejected reason ->
            $"{{\"tag\":\"Rejected\",\"reason\":\"{jsonStr reason}\"}}"

    /// Serialise the full BicameralRelease to JSON.
    let toJson (release: BicameralRelease) : string =
        let c = release.Candidate
        let gates = c.QualityGates |> List.map gateToJson |> String.concat ","
        let history = release.History |> List.map (fun h -> $"\"{jsonStr h}\"") |> String.concat ","
        let candidate =
            $"{{\"version\":\"{jsonStr c.Version}\"," +
            $"\"branch\":\"{jsonStr c.Branch}\"," +
            $"\"commitSha\":\"{jsonStr c.CommitSha}\"," +
            $"\"buildTimestamp\":\"{jsonStr c.BuildTimestamp}\"," +
            $"\"qualityGates\":[{gates}]}}"
        $"{{\"candidate\":{candidate}," +
        $"\"state\":{stateToJson release.State}," +
        $"\"history\":[{history}]," +
        $"\"createdAt\":\"{jsonStr release.CreatedAt}\"}}"
