// =============================================================================
// BicameralDashboard.fs — Bicameral Release Dashboard, Two-Key Protocol
// =============================================================================
// STAMP: SC-SAFETY-001 (Arm & Fire two-step commit),
//        SC-HMI-010 (Color Rich vibrant feedback),
//        SC-GIT-006 (Guardian approval for promote operations)
//
// WHAT: Pure TUI renderer for the Bicameral Release Dashboard.
//       Two independent approval keys are required before any release can be
//       promoted to production — analogous to a nuclear-launch two-key protocol.
//
// WHY:  A single operator error or compromised account must never be able to
//       push untested code to production.  The Bicameral protocol enforces
//       structural separation of duties with an immutable, auditable record.
//
// CONSTRAINTS:
//   - All functions MUST be pure (no I/O, no side effects, no mutable state).
//   - Only System is imported; zero external package dependencies.
//   - [<RequireQualifiedAccess>] is applied to the module and all DU types.
//
// Constitutional Alignment:
//   - Ψ₂ (Evolutionary Continuity): Release history preserved in ReleaseHistory.
//   - Ψ₃ (Verification): Dual-key approval provides numeric, auditable gate.
//   - Ω₄ (Test-Driven Gen): QualityScore and TestsPassed are first-class fields.
//
// Version: 21.3.2 | 2026-03-30
// =============================================================================

namespace Cepaf.Cockpit

open System

// ---------------------------------------------------------------------------
// Private ANSI colour module (BdAnsi prefix — no external dependency)
// ---------------------------------------------------------------------------

module private BdAnsi =
    // Reset / decoration
    let reset   = "\u001b[0m"
    let bold    = "\u001b[1m"
    let dim     = "\u001b[2m"
    let underln = "\u001b[4m"

    // Standard foreground colours
    let black   = "\u001b[30m"
    let red     = "\u001b[31m"
    let green   = "\u001b[32m"
    let yellow  = "\u001b[33m"
    let blue    = "\u001b[34m"
    let magenta = "\u001b[35m"
    let cyan    = "\u001b[36m"
    let white   = "\u001b[37m"

    // Bright foreground colours
    let bBlack   = "\u001b[90m"
    let bRed     = "\u001b[91m"
    let bGreen   = "\u001b[92m"
    let bYellow  = "\u001b[93m"
    let bBlue    = "\u001b[94m"
    let bMagenta = "\u001b[95m"
    let bCyan    = "\u001b[96m"
    let bWhite   = "\u001b[97m"

    // Background colours (used for phase badges)
    let bgRed     = "\u001b[41m"
    let bgGreen   = "\u001b[42m"
    let bgYellow  = "\u001b[43m"
    let bgBlue    = "\u001b[44m"
    let bgMagenta = "\u001b[45m"
    let bgCyan    = "\u001b[46m"
    let bgWhite   = "\u001b[47m"
    let bgBlack   = "\u001b[40m"
    let bgBRed    = "\u001b[101m"
    let bgBGreen  = "\u001b[102m"
    let bgBBlue   = "\u001b[104m"

// ---------------------------------------------------------------------------
// Discriminated Union types
// ---------------------------------------------------------------------------

/// Approval state for a single key holder.
[<RequireQualifiedAccess>]
type ApprovalStatus =
    /// Waiting for the key holder to act.
    | Pending
    /// Key holder has signed off: release may proceed to the next gate.
    | Approved
    /// Key holder has rejected: release is blocked until a new candidate is created.
    | Rejected
    /// Approval window has elapsed without a decision.
    | Expired

/// Lifecycle phase of a release candidate.
[<RequireQualifiedAccess>]
type ReleasePhase =
    /// Candidate is being authored; quality checks may still be running.
    | Draft
    /// Candidate is under review; key holders are being notified.
    | Review
    /// Candidate is deployed to the staging environment.
    | Staging
    /// Both keys are approved; candidate is armed and ready to fire.
    | Armed
    /// Candidate has been promoted to production.
    | Released
    /// Candidate was rolled back after a failed production deployment.
    | Rolled_Back

// ---------------------------------------------------------------------------
// Record types
// ---------------------------------------------------------------------------

/// A single approval key held by one named operator.
type ApprovalKey = {
    /// Full name or handle of the key holder (e.g. "alice@indrajaal").
    KeyHolder  : string
    /// Current approval decision.
    Status     : ApprovalStatus
    /// Wall-clock time at which the decision was recorded (None if still Pending).
    Timestamp  : DateTimeOffset option
    /// Optional free-text note (rejection reason, approval comment, etc.).
    Reason     : string option
}

/// A release candidate awaiting dual-key promotion.
type ReleaseCandidate = {
    /// Human-readable version string (e.g. "21.3.2-rc.1").
    Version      : string
    /// Source branch name (e.g. "main" or "multiverse/feat-xyz").
    Branch       : string
    /// Full git commit SHA (40 hex chars).
    CommitSha    : string
    /// Current lifecycle phase.
    Phase        : ReleasePhase
    /// First independent approval key.
    Key1         : ApprovalKey
    /// Second independent approval key.
    Key2         : ApprovalKey
    /// Composite quality gate score 0.0–1.0 (compile + credo + test coverage).
    QualityScore : float
    /// Number of test cases that passed.
    TestsPassed  : int
    /// Total number of test cases in the suite.
    TestsTotal   : int
    /// Creation timestamp for the candidate record.
    CreatedAt    : DateTimeOffset
}

/// Append-only list of release candidates (most-recent first).
type ReleaseHistory = {
    Releases : ReleaseCandidate list
}

// ---------------------------------------------------------------------------
// BicameralDashboard — pure rendering module
// ---------------------------------------------------------------------------

/// Pure TUI renderer for the Bicameral Release Dashboard.
/// No I/O is performed; every function returns a string for the caller to display.
[<RequireQualifiedAccess>]
module BicameralDashboard =

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /// Width of the inner content area (between the border pipes).
    let private innerWidth = 66

    /// Pads or truncates a string to exactly `width` visible characters.
    /// (Assumes the input contains no ANSI escapes.)
    let private padTo (width: int) (s: string) : string =
        if s.Length >= width then s.[..width - 1]
        else s + String.replicate (width - s.Length) " "

    /// Formats an optional DateTimeOffset as "yyyy-MM-dd HH:mm zzz" or "—" if absent.
    let private fmtTimestamp (ts: DateTimeOffset option) : string =
        match ts with
        | None    -> "—"
        | Some t  -> t.ToString("yyyy-MM-dd HH:mm zzz")

    /// Renders a quality bar (20 chars) proportional to `score` (0.0–1.0).
    let private qualityBar (score: float) : string =
        let filled = int (score * 20.0) |> max 0 |> min 20
        let empty  = 20 - filled
        let colour =
            if score >= 0.90 then BdAnsi.bGreen
            elif score >= 0.70 then BdAnsi.bYellow
            else BdAnsi.bRed
        sprintf "%s%s%s%s" colour (String.replicate filled "█") (String.replicate empty "░") BdAnsi.reset

    // -----------------------------------------------------------------------
    // Public: phaseColour
    // -----------------------------------------------------------------------

    /// Returns the ANSI foreground colour escape code for the given release phase.
    let phaseColour (phase: ReleasePhase) : string =
        match phase with
        | ReleasePhase.Draft       -> BdAnsi.dim
        | ReleasePhase.Review      -> BdAnsi.bBlue
        | ReleasePhase.Staging     -> BdAnsi.bCyan
        | ReleasePhase.Armed       -> BdAnsi.bYellow
        | ReleasePhase.Released    -> BdAnsi.bGreen
        | ReleasePhase.Rolled_Back -> BdAnsi.bRed

    /// Returns the phase label string used in badges.
    let private phaseLabel (phase: ReleasePhase) : string =
        match phase with
        | ReleasePhase.Draft       -> "DRAFT      "
        | ReleasePhase.Review      -> "REVIEW     "
        | ReleasePhase.Staging     -> "STAGING    "
        | ReleasePhase.Armed       -> "ARMED      "
        | ReleasePhase.Released    -> "RELEASED   "
        | ReleasePhase.Rolled_Back -> "ROLLED-BACK"

    // -----------------------------------------------------------------------
    // Public: isReleasable
    // -----------------------------------------------------------------------

    /// Returns true only when both approval keys carry the Approved status.
    /// This is the gate that the release pipeline must check before firing.
    let isReleasable (rc: ReleaseCandidate) : bool =
        rc.Key1.Status = ApprovalStatus.Approved &&
        rc.Key2.Status = ApprovalStatus.Approved

    // -----------------------------------------------------------------------
    // Internal: status badge helpers
    // -----------------------------------------------------------------------

    /// Produces a padded, coloured badge for a single ApprovalStatus.
    let private statusBadge (status: ApprovalStatus) : string =
        match status with
        | ApprovalStatus.Pending  ->
            sprintf "%s PENDING  %s" BdAnsi.bBlack BdAnsi.reset
        | ApprovalStatus.Approved ->
            sprintf "%s%s APPROVED %s" BdAnsi.bold BdAnsi.bGreen BdAnsi.reset
        | ApprovalStatus.Rejected ->
            sprintf "%s REJECTED %s" BdAnsi.bRed BdAnsi.reset
        | ApprovalStatus.Expired  ->
            sprintf "%s EXPIRED  %s" BdAnsi.yellow BdAnsi.reset

    // -----------------------------------------------------------------------
    // Public: renderKeyStatus
    // -----------------------------------------------------------------------

    /// Renders a single key approval line:
    ///   KEY-N  holder@name        [ APPROVED ]   2026-03-30 14:01 +00:00
    let renderKeyStatus (key: ApprovalKey) : string =
        let badge = statusBadge key.Status
        let ts    = fmtTimestamp key.Timestamp
        let holder = padTo 24 key.KeyHolder
        sprintf "  %s%-24s%s  [%s]  %s%s%s"
            BdAnsi.white
            holder
            BdAnsi.reset
            badge
            BdAnsi.dim ts BdAnsi.reset

    // -----------------------------------------------------------------------
    // Public: renderRelease
    // -----------------------------------------------------------------------

    /// Renders a full bordered pane for a release candidate.
    /// The pane shows version, branch, commit SHA, phase badge, both key
    /// approval statuses, quality score bar, and test result counts.
    let renderRelease (rc: ReleaseCandidate) : string =
        let topBar    = sprintf "%s╔%s╗%s" BdAnsi.cyan (String.replicate innerWidth "═") BdAnsi.reset
        let botBar    = sprintf "%s╚%s╝%s" BdAnsi.cyan (String.replicate innerWidth "═") BdAnsi.reset
        let midBar    = sprintf "%s╠%s╣%s" BdAnsi.cyan (String.replicate innerWidth "─") BdAnsi.reset

        let pipe l  = sprintf "%s║%s %s%s" BdAnsi.cyan BdAnsi.reset l BdAnsi.reset

        // Title row
        let titleText =
            sprintf "  %s%s BICAMERAL RELEASE DASHBOARD %s%s"
                BdAnsi.bold BdAnsi.bCyan BdAnsi.reset BdAnsi.reset
        let titleRow  = pipe (padTo (innerWidth - 2) titleText)

        // Phase badge row
        let phCol     = phaseColour rc.Phase
        let phBadge   = sprintf "%s%s%s%s%s" BdAnsi.bold phCol (phaseLabel rc.Phase) BdAnsi.reset BdAnsi.reset
        let phaseRow  = pipe (padTo (innerWidth - 2) (sprintf "  Phase:   %s" phBadge))

        // Version / branch / sha rows
        let verRow    =
            pipe (padTo (innerWidth - 2)
                (sprintf "  Version: %s%s%s   Branch: %s%s%s"
                    BdAnsi.bWhite rc.Version BdAnsi.reset
                    BdAnsi.bCyan  rc.Branch  BdAnsi.reset))
        let shaRow    =
            pipe (padTo (innerWidth - 2)
                (sprintf "  Commit:  %s%s%s" BdAnsi.dim rc.CommitSha BdAnsi.reset))
        let createdRow =
            let ts = rc.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss zzz")
            pipe (padTo (innerWidth - 2) (sprintf "  Created: %s%s%s" BdAnsi.dim ts BdAnsi.reset))

        // Quality score row
        let scoreCol  =
            if rc.QualityScore >= 0.90 then BdAnsi.bGreen
            elif rc.QualityScore >= 0.70 then BdAnsi.bYellow
            else BdAnsi.bRed
        let qBar      = qualityBar rc.QualityScore
        let qRow      =
            pipe (padTo (innerWidth - 2)
                (sprintf "  Quality: %s  %s%.2f%s  (%.0f%%)"
                    qBar scoreCol rc.QualityScore BdAnsi.reset (rc.QualityScore * 100.0)))

        // Test result row
        let testPct   = if rc.TestsTotal > 0 then float rc.TestsPassed / float rc.TestsTotal * 100.0 else 0.0
        let testCol   = if testPct >= 99.0 then BdAnsi.bGreen elif testPct >= 90.0 then BdAnsi.bYellow else BdAnsi.bRed
        let testRow   =
            pipe (padTo (innerWidth - 2)
                (sprintf "  Tests:   %s%d / %d%s  (%.1f%% passing)"
                    testCol rc.TestsPassed rc.TestsTotal BdAnsi.reset testPct))

        // Approval key header
        let keyHdr    =
            pipe (padTo (innerWidth - 2)
                (sprintf "  %sAPPROVAL KEYS  (both required to ARM → FIRE)%s"
                    BdAnsi.bold BdAnsi.reset))

        // Key rows
        let key1Label = sprintf "  %sKEY-1%s  " BdAnsi.bMagenta BdAnsi.reset
        let key2Label = sprintf "  %sKEY-2%s  " BdAnsi.bMagenta BdAnsi.reset
        let key1Row   = pipe (padTo (innerWidth - 2) (key1Label + renderKeyStatus rc.Key1))
        let key2Row   = pipe (padTo (innerWidth - 2) (key2Label + renderKeyStatus rc.Key2))

        // Reason rows (shown only when a reason is present)
        let reasonRows =
            let fmt keyLbl (key: ApprovalKey) =
                match key.Reason with
                | None   -> []
                | Some r ->
                    [ pipe (padTo (innerWidth - 2)
                        (sprintf "         %s%s  Note: %s%s%s%s" BdAnsi.dim keyLbl BdAnsi.reset BdAnsi.white r BdAnsi.reset)) ]
            fmt "KEY-1" rc.Key1 @ fmt "KEY-2" rc.Key2

        // Releasable summary row
        let readyCol, readyLabel =
            if isReleasable rc then BdAnsi.bGreen, "RELEASABLE — both keys approved. Ready to FIRE."
            else BdAnsi.bRed,    "NOT RELEASABLE — awaiting one or both approvals."
        let readyRow =
            pipe (padTo (innerWidth - 2)
                (sprintf "  %s%s%s" readyCol readyLabel BdAnsi.reset))

        // Assemble pane
        [ topBar
          titleRow
          midBar
          phaseRow
          verRow
          shaRow
          createdRow
          midBar
          qRow
          testRow
          midBar
          keyHdr
          key1Row
          key2Row ]
        @ reasonRows
        @ [ midBar
            readyRow
            botBar ]
        |> String.concat "\n"

    // -----------------------------------------------------------------------
    // Public: renderHistory
    // -----------------------------------------------------------------------

    /// Renders a compact list of recent release candidates, newest first.
    /// Each line shows phase badge, version, commit short-sha, and releasable indicator.
    let renderHistory (history: ReleaseHistory) : string =
        let sep = sprintf "%s%s%s" BdAnsi.dim (String.replicate innerWidth "·") BdAnsi.reset

        let headerLine =
            sprintf "  %s%-11s  %-20s  %-10s  %-9s  %s%s"
                BdAnsi.bold "PHASE" "VERSION" "SHORT-SHA" "QUALITY" "RELEASABLE" BdAnsi.reset

        let renderLine (rc: ReleaseCandidate) =
            let phCol    = phaseColour rc.Phase
            let phaseLbl = padTo 11 (phaseLabel rc.Phase)
            let shortSha = if rc.CommitSha.Length >= 8 then rc.CommitSha.[..7] else rc.CommitSha
            let qPct     = sprintf "%.0f%%" (rc.QualityScore * 100.0)
            let relFlag, relCol =
                if isReleasable rc then "YES", BdAnsi.bGreen
                else "NO ", BdAnsi.bRed
            sprintf "  %s%s%s  %-20s  %-10s  %-9s  %s%s%s"
                phCol phaseLbl BdAnsi.reset
                rc.Version
                shortSha
                qPct
                relCol relFlag BdAnsi.reset

        let title =
            sprintf "  %s%sRECENT RELEASES%s" BdAnsi.bold BdAnsi.bCyan BdAnsi.reset

        let lines =
            if List.isEmpty history.Releases then
                [ "  (no releases recorded)" ]
            else
                history.Releases |> List.map renderLine

        ([ ""
           sep
           title
           sep
           headerLine
           sep ]
         @ lines
         @ [ sep; "" ])
        |> String.concat "\n"

    // -----------------------------------------------------------------------
    // Public: defaultCandidate
    // -----------------------------------------------------------------------

    /// Returns a representative release candidate for use in tests, demos, and
    /// smoke-test renders.  Phase is Armed with Key-1 approved and Key-2 pending.
    let defaultCandidate () : ReleaseCandidate =
        let now = DateTimeOffset.UtcNow
        {
            Version      = "21.3.2-rc.1"
            Branch       = "main"
            CommitSha    = "b5dacba70f3e1c2d9a08b47e6c50f312a9d38e1f"
            Phase        = ReleasePhase.Armed
            Key1         = {
                KeyHolder  = "alice@indrajaal"
                Status     = ApprovalStatus.Approved
                Timestamp  = Some (now.AddHours(-1.0))
                Reason     = Some "All quality gates green; staging soak passed."
            }
            Key2         = {
                KeyHolder  = "bob@indrajaal"
                Status     = ApprovalStatus.Pending
                Timestamp  = None
                Reason     = None
            }
            QualityScore = 0.97
            TestsPassed  = 1041
            TestsTotal   = 1043
            CreatedAt    = now.AddHours(-3.0)
        }
