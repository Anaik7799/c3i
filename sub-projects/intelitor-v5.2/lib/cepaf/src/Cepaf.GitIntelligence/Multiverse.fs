// =============================================================================
// Git Intelligence — L9 Multiverse Fork/Shadow Operations
// =============================================================================
// Purpose:  Create shadow branches for experimental commits, verify GHS
//           impact, promote successful experiments, prune failed ones.
//           Mirrors sa-multiverse.fsx registry pattern.
//
// STAMP:    SC-GIT-006 (Guardian approval for promote)
// =============================================================================

module Cepaf.GitIntelligence.Multiverse

open System
open System.Diagnostics
open System.IO

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a shadow universe (branch).
type Universe =
    { UniverseId: string
      BranchName: string
      ParentBranch: string
      CreatedAt: DateTimeOffset
      Status: UniverseStatus
      Ghs: float option
      ParentGhs: float option }

/// Status of a shadow universe.
and UniverseStatus =
    | Active
    | Verified
    | Promoted
    | Pruned
    | Failed

// ─────────────────────────────────────────────────────────────────────────────
// In-Memory Registry
// ─────────────────────────────────────────────────────────────────────────────

/// Registry of shadow universes (session lifetime).
let private registry = System.Collections.Concurrent.ConcurrentDictionary<string, Universe>()

/// Get all universes.
let listUniverses () : Universe list =
    registry.Values |> Seq.toList |> List.sortByDescending (fun u -> u.CreatedAt)

/// Get a specific universe.
let getUniverse (universeId: string) : Universe option =
    match registry.TryGetValue(universeId) with
    | true, u -> Some u
    | false, _ -> None

/// Get active universes only.
let activeUniverses () : Universe list =
    listUniverses () |> List.filter (fun u -> u.Status = Active || u.Status = Verified)

/// Clear registry (for testing).
let clearRegistry () : unit =
    registry.Clear()

// ─────────────────────────────────────────────────────────────────────────────
// Git Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Run a git command and return stdout.
let private runGit (repoPath: string) (args: string) : Result<string, string> =
    try
        let psi = ProcessStartInfo("git", args)
        psi.WorkingDirectory <- repoPath
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        psi.UseShellExecute <- false
        psi.CreateNoWindow <- true
        let proc = Process.Start(psi)
        let stdout = proc.StandardOutput.ReadToEnd()
        let stderr = proc.StandardError.ReadToEnd()
        proc.WaitForExit(10000) |> ignore
        if proc.ExitCode = 0 then
            Ok (stdout.Trim())
        else
            Error (stderr.Trim())
    with ex ->
        Error ex.Message

/// Get current branch name.
let private getCurrentBranch (repoPath: string) : string option =
    match runGit repoPath "rev-parse --abbrev-ref HEAD" with
    | Ok branch -> Some branch
    | Error _ -> None

// ─────────────────────────────────────────────────────────────────────────────
// Fork Operations
// ─────────────────────────────────────────────────────────────────────────────

/// Generate a unique universe ID.
let private generateId () : string =
    let ts = DateTimeOffset.UtcNow.ToString("yyyyMMddHHmmss")
    let rnd = Random().Next(1000, 9999)
    $"mv-{ts}-{rnd}"

/// Fork a new shadow universe (create a branch from current HEAD).
let forkUniverse (repoPath: string) (currentGhs: float option) : Result<Universe, string> =
    match getCurrentBranch repoPath with
    | None -> Error "Cannot determine current branch"
    | Some parentBranch ->
        let uid = generateId ()
        let branchName = $"shadow/{uid}"
        match runGit repoPath $"checkout -b {branchName}" with
        | Error e -> Error $"Failed to create branch: {e}"
        | Ok _ ->
            // Switch back to parent branch immediately
            runGit repoPath $"checkout {parentBranch}" |> ignore
            let universe =
                { UniverseId = uid
                  BranchName = branchName
                  ParentBranch = parentBranch
                  CreatedAt = DateTimeOffset.UtcNow
                  Status = Active
                  Ghs = None
                  ParentGhs = currentGhs }
            registry.TryAdd(uid, universe) |> ignore
            Notify.publishMultiverseEvent "fork" uid branchName currentGhs |> ignore
            Ok universe

/// Fork a universe without actually creating a git branch (for testing/offline).
let forkVirtual (parentBranch: string) (currentGhs: float option) : Universe =
    let uid = generateId ()
    let branchName = $"shadow/{uid}"
    let universe =
        { UniverseId = uid
          BranchName = branchName
          ParentBranch = parentBranch
          CreatedAt = DateTimeOffset.UtcNow
          Status = Active
          Ghs = None
          ParentGhs = currentGhs }
    registry.TryAdd(uid, universe) |> ignore
    Notify.publishMultiverseEvent "fork" uid branchName currentGhs |> ignore
    universe

// ─────────────────────────────────────────────────────────────────────────────
// Verify Operations
// ─────────────────────────────────────────────────────────────────────────────

/// Verify a shadow universe by running analysis on it.
/// Compares GHS of shadow branch against parent.
let verifyUniverse (repoPath: string) (universeId: string) (since: string) : Result<Universe, string> =
    match getUniverse universeId with
    | None -> Error $"Universe {universeId} not found"
    | Some universe when universe.Status <> Active -> Error $"Universe {universeId} is not Active (status: {universe.Status})"
    | Some universe ->
        // Parse commits on shadow branch
        let ghs =
            match Parser.parseGitLog repoPath since None with
            | Error _ -> None
            | Ok commits when commits.Length = 0 -> None
            | Ok commits ->
                let analysis = Analysis.analyze commits
                Some analysis.HealthScore.Score
        let updated =
            { universe with
                Status = Verified
                Ghs = ghs }
        registry.TryUpdate(universeId, updated, universe) |> ignore
        Notify.publishMultiverseEvent "verify" universeId universe.BranchName ghs |> ignore
        Ok updated

/// Set GHS on a universe directly (for virtual/test mode).
let setUniverseGhs (universeId: string) (ghs: float) : Universe option =
    match getUniverse universeId with
    | None -> None
    | Some universe ->
        let updated = { universe with Ghs = Some ghs; Status = Verified }
        registry.TryUpdate(universeId, updated, universe) |> ignore
        Some updated

// ─────────────────────────────────────────────────────────────────────────────
// Promote Operations (requires Guardian approval per SC-GIT-006)
// ─────────────────────────────────────────────────────────────────────────────

/// Check if a universe has improved GHS compared to parent.
let hasImprovedGhs (universe: Universe) : bool =
    match universe.Ghs, universe.ParentGhs with
    | Some shadowGhs, Some parentGhs -> shadowGhs > parentGhs
    | Some _, None -> true  // No parent baseline, any GHS is improvement
    | _ -> false

/// Promote a verified universe by merging shadow branch into parent.
/// In standalone mode, this performs the git merge.
let promoteUniverse (repoPath: string) (universeId: string) : Result<Universe, string> =
    match getUniverse universeId with
    | None -> Error $"Universe {universeId} not found"
    | Some universe when universe.Status <> Verified -> Error $"Universe {universeId} is not Verified (status: {universe.Status})"
    | Some universe ->
        if not (hasImprovedGhs universe) then
            Error "GHS has not improved — promotion blocked (SC-GIT-006)"
        else
            // Guardian approval check (simplified — log intent)
            eprintfn "[GUARDIAN] Promote request for %s (GHS: %s → %s)"
                universe.UniverseId
                (match universe.ParentGhs with Some g -> $"{g:F4}" | None -> "N/A")
                (match universe.Ghs with Some g -> $"{g:F4}" | None -> "N/A")
            match runGit repoPath $"merge {universe.BranchName} --no-ff -m \"Promote shadow universe {universe.UniverseId}\"" with
            | Error e -> Error $"Merge failed: {e}"
            | Ok _ ->
                let updated = { universe with Status = Promoted }
                registry.TryUpdate(universeId, updated, universe) |> ignore
                Notify.publishMultiverseEvent "promote" universeId universe.BranchName universe.Ghs |> ignore
                Ok updated

/// Promote a universe virtually (no git merge, for testing).
let promoteVirtual (universeId: string) : Result<Universe, string> =
    match getUniverse universeId with
    | None -> Error $"Universe {universeId} not found"
    | Some universe when universe.Status <> Verified -> Error $"Universe is not Verified"
    | Some universe when not (hasImprovedGhs universe) -> Error "GHS not improved"
    | Some universe ->
        let updated = { universe with Status = Promoted }
        registry.TryUpdate(universeId, updated, universe) |> ignore
        Notify.publishMultiverseEvent "promote" universeId universe.BranchName universe.Ghs |> ignore
        Ok updated

// ─────────────────────────────────────────────────────────────────────────────
// Prune Operations
// ─────────────────────────────────────────────────────────────────────────────

/// Prune (delete) a shadow branch that is no longer needed.
let pruneUniverse (repoPath: string) (universeId: string) : Result<Universe, string> =
    match getUniverse universeId with
    | None -> Error $"Universe {universeId} not found"
    | Some universe when universe.Status = Pruned -> Error "Already pruned"
    | Some universe ->
        // Delete the shadow branch
        match runGit repoPath $"branch -D {universe.BranchName}" with
        | Error e -> eprintfn "Warning: branch delete failed: %s" e  // Non-fatal
        | Ok _ -> ()
        let updated = { universe with Status = Pruned }
        registry.TryUpdate(universeId, updated, universe) |> ignore
        Notify.publishMultiverseEvent "prune" universeId universe.BranchName universe.Ghs |> ignore
        Ok updated

/// Prune all universes older than TTL hours.
let pruneStale (repoPath: string) (ttlHours: float) : int =
    let cutoff = DateTimeOffset.UtcNow.AddHours(-ttlHours)
    let stale =
        listUniverses ()
        |> List.filter (fun u ->
            (u.Status = Active || u.Status = Failed) && u.CreatedAt < cutoff)
    stale |> List.iter (fun u -> pruneUniverse repoPath u.UniverseId |> ignore)
    stale.Length

/// Mark a universe as failed (without deleting the branch).
let failUniverse (universeId: string) : Universe option =
    match getUniverse universeId with
    | None -> None
    | Some universe ->
        let updated = { universe with Status = Failed }
        registry.TryUpdate(universeId, updated, universe) |> ignore
        Some updated

// ─────────────────────────────────────────────────────────────────────────────
// Reporting
// ─────────────────────────────────────────────────────────────────────────────

/// Format universe status as a text report.
let formatReport () : string =
    let sb = System.Text.StringBuilder()
    sb.AppendLine("Multiverse Status") |> ignore
    let all = listUniverses ()
    sb.AppendLine($"  Total: {all.Length}") |> ignore
    let byStatus =
        all |> List.groupBy (fun u -> u.Status)
    for (status, universes) in byStatus do
        sb.AppendLine($"  {status}: {universes.Length}") |> ignore
    sb.AppendLine("") |> ignore
    for u in all |> List.truncate 20 do
        let ghsStr = match u.Ghs with Some g -> $"{g:F4}" | None -> "N/A"
        let parentStr = match u.ParentGhs with Some g -> $"{g:F4}" | None -> "N/A"
        sb.AppendLine($"  [{u.UniverseId}] {u.Status} branch={u.BranchName} GHS={ghsStr} (parent={parentStr})") |> ignore
    sb.ToString()

/// Output universe registry as JSON.
let toJson () : string =
    let all = listUniverses ()
    let universesJson =
        all
        |> List.map (fun u ->
            let ghsStr = match u.Ghs with Some g -> $"{g:F4}" | None -> "null"
            let parentStr = match u.ParentGhs with Some g -> $"{g:F4}" | None -> "null"
            $"""{{ "id": "{u.UniverseId}", "branch": "{u.BranchName}", "parent": "{u.ParentBranch}", "status": "{u.Status}", "ghs": {ghsStr}, "parentGhs": {parentStr}, "created": "{u.CreatedAt:O}" }}""")
        |> String.concat ", "
    $"""{{ "total": {all.Length}, "universes": [{universesJson}] }}"""
