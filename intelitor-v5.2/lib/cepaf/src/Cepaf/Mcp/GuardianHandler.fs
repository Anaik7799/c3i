// =============================================================================
// GuardianHandler.fs - MCP Tool Handler for Guardian Operations
// =============================================================================
// STAMP: SC-GUARD-001 (Guardian uses Envelope for constraint values),
//        SC-GUARD-002 (Guardian integrates with DeadMansSwitch),
//        SC-GUARD-003 (Guardian integrates with FounderDirective),
//        SC-SAFETY-001 (Guardian pre-approval for planning mutations),
//        SC-GDE-001 (Guardian validation required),
//        SC-XHOLON-001 (isolated database file per subsystem),
//        SC-XHOLON-030 (WAL mode, no data loss on crash),
//        SC-XHOLON-031 (ACID compliance for writes)
// AOR: AOR-GDE-002 (shadow testing mandatory),
//      AOR-CAE-002 (Guardian validation before deploy),
//      AOR-XHOLON-011 (WAL mode mandatory for SQLite)
//
// Implements MCP tool handler functions for the Guardian subsystem.
// Storage: SQLite at data/holons/guardian/proposals.db (WAL mode, ACID).
// In-memory ConcurrentDictionary acts as hot-path cache; all mutations
// are written through to SQLite.  On any SQLite failure the handler
// degrades gracefully to in-memory state so the MCP caller always gets
// a Result<string, string> — never an unhandled exception.
//
// All public functions return Result<string, string>:
//   Ok    — JSON string for MCP TextContent.Text
//   Error — human-readable error message
//
// Version: 21.3.2 | 2026-03-30
// =============================================================================

namespace Cepaf.Mcp

open System
open System.IO
open System.Text.Json
open System.Text.Json.Serialization
open Microsoft.Data.Sqlite

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// Proposal submitted for Guardian evaluation.
[<CLIMutable>]
type GuardianProposal = {
    [<JsonPropertyName("proposal_id")>]  ProposalId  : string
    [<JsonPropertyName("actor")>]        Actor       : string
    [<JsonPropertyName("action")>]       Action      : string
    [<JsonPropertyName("target")>]       Target      : string
    [<JsonPropertyName("payload")>]      Payload     : string
    [<JsonPropertyName("timestamp")>]    Timestamp   : string
    [<JsonPropertyName("stamp_refs")>]   StampRefs   : string list
}

/// Status of a proposal in the Guardian queue.
[<RequireQualifiedAccess>]
type ProposalStatus =
    | Pending
    | Approved
    | Vetoed of reason: string
    | Expired

/// Approval record returned to MCP caller.
[<CLIMutable>]
type GuardianApprovalRecord = {
    [<JsonPropertyName("proposal_id")>] ProposalId : string
    [<JsonPropertyName("status")>]      Status     : string
    [<JsonPropertyName("reason")>]      Reason     : string option
    [<JsonPropertyName("timestamp")>]   Timestamp  : string
}

// ---------------------------------------------------------------------------
// SQLite persistence layer (SC-XHOLON-001, SC-XHOLON-030, SC-XHOLON-031)
// ---------------------------------------------------------------------------

module private GuardianDb =

    /// Database file path — isolated per subsystem (SC-XHOLON-001).
    let private dbPath = "data/holons/guardian/proposals.db"

    /// DDL executed once per connection open.
    let private schemaSql = """
        CREATE TABLE IF NOT EXISTS guardian_proposals (
            proposal_id  TEXT PRIMARY KEY,
            actor        TEXT NOT NULL,
            action       TEXT NOT NULL,
            target       TEXT NOT NULL,
            payload      TEXT NOT NULL DEFAULT '{}',
            stamp_refs   TEXT NOT NULL DEFAULT '[]',
            status       TEXT NOT NULL DEFAULT 'pending',
            veto_reason  TEXT,
            created_at   TEXT NOT NULL,
            updated_at   TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_gp_status
            ON guardian_proposals (status);
    """

    /// Open a WAL-mode SQLite connection and ensure the schema exists.
    /// Returns the open connection, which the caller MUST dispose via `use`.
    /// Raises on failure — callers wrap in try/with.
    let private openConn () : SqliteConnection =
        let dir = Path.GetDirectoryName(dbPath)
        if not (Directory.Exists(dir)) then
            Directory.CreateDirectory(dir) |> ignore

        let connStr = sprintf "Data Source=%s;Mode=ReadWriteCreate" dbPath
        let conn = new SqliteConnection(connStr)
        conn.Open()

        use pragmaCmd = conn.CreateCommand()
        pragmaCmd.CommandText <-
            "PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000; PRAGMA foreign_keys = ON;"
        pragmaCmd.ExecuteNonQuery() |> ignore

        use schemaCmd = conn.CreateCommand()
        schemaCmd.CommandText <- schemaSql
        schemaCmd.ExecuteNonQuery() |> ignore

        conn

    // ------------------------------------------------------------------
    // Read helper: materialise a reader row into typed tuple
    // ------------------------------------------------------------------

    let private readRow (reader: SqliteDataReader) : GuardianProposal * string * string option =
        let stampRefs =
            try JsonSerializer.Deserialize<string list>(reader.GetString(5))
            with _ -> []
        let proposal : GuardianProposal = {
            ProposalId = reader.GetString(0)
            Actor      = reader.GetString(1)
            Action     = reader.GetString(2)
            Target     = reader.GetString(3)
            Payload    = reader.GetString(4)
            StampRefs  = stampRefs
            Timestamp  = reader.GetString(8)
        }
        let vetoReason =
            if reader.IsDBNull(7) then None
            else Some (reader.GetString(7))
        proposal, reader.GetString(6), vetoReason

    // ------------------------------------------------------------------
    // Write: insert a new pending proposal
    // ------------------------------------------------------------------

    let tryInsert (p: GuardianProposal) : unit =
        try
            use conn = openConn()
            use cmd  = conn.CreateCommand()
            cmd.CommandText <- """
                INSERT OR IGNORE INTO guardian_proposals
                    (proposal_id, actor, action, target, payload,
                     stamp_refs, status, created_at, updated_at)
                VALUES
                    ($pid, $actor, $action, $target, $payload,
                     $refs, 'pending', $now, $now)
            """
            let stampJson = JsonSerializer.Serialize(p.StampRefs)
            cmd.Parameters.AddWithValue("$pid",     p.ProposalId) |> ignore
            cmd.Parameters.AddWithValue("$actor",   p.Actor)      |> ignore
            cmd.Parameters.AddWithValue("$action",  p.Action)     |> ignore
            cmd.Parameters.AddWithValue("$target",  p.Target)     |> ignore
            cmd.Parameters.AddWithValue("$payload", p.Payload)    |> ignore
            cmd.Parameters.AddWithValue("$refs",    stampJson)    |> ignore
            cmd.Parameters.AddWithValue("$now",     p.Timestamp)  |> ignore
            cmd.ExecuteNonQuery() |> ignore
        with ex ->
            eprintfn "[GuardianDb] tryInsert failed: %s" ex.Message

    // ------------------------------------------------------------------
    // Write: update proposal status
    // ------------------------------------------------------------------

    let tryUpdateStatus (proposalId: string) (status: string) (vetoReason: string option) : unit =
        try
            use conn = openConn()
            use cmd  = conn.CreateCommand()
            cmd.CommandText <- """
                UPDATE guardian_proposals
                SET    status      = $status,
                       veto_reason = $reason,
                       updated_at  = $now
                WHERE  proposal_id = $pid
            """
            cmd.Parameters.AddWithValue("$status", status)                      |> ignore
            cmd.Parameters.AddWithValue("$reason", vetoReason |> Option.toObj)  |> ignore
            cmd.Parameters.AddWithValue("$now",    DateTimeOffset.UtcNow.ToString("o")) |> ignore
            cmd.Parameters.AddWithValue("$pid",    proposalId)                  |> ignore
            cmd.ExecuteNonQuery() |> ignore
        with ex ->
            eprintfn "[GuardianDb] tryUpdateStatus failed: %s" ex.Message

    // ------------------------------------------------------------------
    // Read: single proposal by ID
    // ------------------------------------------------------------------

    let tryGetById (proposalId: string) : (GuardianProposal * string * string option) option =
        try
            use conn = openConn()
            use cmd  = conn.CreateCommand()
            cmd.CommandText <- """
                SELECT proposal_id, actor, action, target, payload,
                       stamp_refs, status, veto_reason, created_at
                FROM   guardian_proposals
                WHERE  proposal_id = $pid
            """
            cmd.Parameters.AddWithValue("$pid", proposalId) |> ignore
            use reader = cmd.ExecuteReader()
            if reader.Read() then Some (readRow reader)
            else None
        with ex ->
            eprintfn "[GuardianDb] tryGetById failed: %s" ex.Message
            None

    // ------------------------------------------------------------------
    // Read: list proposals by status
    // ------------------------------------------------------------------

    let tryListByStatus (status: string) : (GuardianProposal * string * string option) list =
        try
            use conn = openConn()
            use cmd  = conn.CreateCommand()
            cmd.CommandText <- """
                SELECT proposal_id, actor, action, target, payload,
                       stamp_refs, status, veto_reason, created_at
                FROM   guardian_proposals
                WHERE  status = $status
                ORDER  BY created_at DESC
                LIMIT  200
            """
            cmd.Parameters.AddWithValue("$status", status) |> ignore
            use reader = cmd.ExecuteReader()
            let acc = System.Collections.Generic.List<_>()
            while reader.Read() do
                acc.Add(readRow reader)
            acc |> Seq.toList
        with ex ->
            eprintfn "[GuardianDb] tryListByStatus failed: %s" ex.Message
            []

// ---------------------------------------------------------------------------
// In-memory hot-path cache (write-through to SQLite)
// ---------------------------------------------------------------------------

module private GuardianState =

    let private proposals =
        System.Collections.Concurrent.ConcurrentDictionary<string, GuardianProposal * ProposalStatus>()

    let private toStatus (s: string) (vetoReason: string option) : ProposalStatus =
        match s with
        | "approved" -> ProposalStatus.Approved
        | "expired"  -> ProposalStatus.Expired
        | "vetoed"   -> ProposalStatus.Vetoed (vetoReason |> Option.defaultValue "")
        | _          -> ProposalStatus.Pending

    /// Store a new proposal in cache and write-through to SQLite.
    let store (p: GuardianProposal) =
        proposals.TryAdd(p.ProposalId, (p, ProposalStatus.Pending)) |> ignore
        GuardianDb.tryInsert p

    /// Get a proposal by ID — cache first, SQLite on miss.
    let getStatus (id: string) : (GuardianProposal * ProposalStatus) option =
        match proposals.TryGetValue(id) with
        | (true, v) -> Some v
        | _ ->
            match GuardianDb.tryGetById id with
            | None -> None
            | Some (proposal, statusStr, vetoReason) ->
                let status = toStatus statusStr vetoReason
                proposals.TryAdd(proposal.ProposalId, (proposal, status)) |> ignore
                Some (proposal, status)

    /// List all pending proposals, merging SQLite + in-memory cache.
    let allPending () : (GuardianProposal * ProposalStatus) list =
        let fromDb =
            GuardianDb.tryListByStatus "pending"
            |> List.map (fun (p, _, _) -> p.ProposalId, (p, ProposalStatus.Pending))
            |> Map.ofList

        let cacheOnly =
            [ for kv in proposals.Values do
                match kv with
                | (p, ProposalStatus.Pending) when not (Map.containsKey p.ProposalId fromDb) ->
                    yield kv
                | _ -> () ]

        (fromDb |> Map.toList |> List.map snd) @ cacheOnly

    /// Update a proposal's status in cache and write-through to SQLite.
    let updateStatus (id: string) (status: ProposalStatus) =
        match proposals.TryGetValue(id) with
        | (true, (p, _)) -> proposals.[id] <- (p, status)
        | _              -> ()

        let statusStr, vetoReason =
            match status with
            | ProposalStatus.Pending  -> "pending",  None
            | ProposalStatus.Approved -> "approved", None
            | ProposalStatus.Vetoed r -> "vetoed",   Some r
            | ProposalStatus.Expired  -> "expired",  None

        GuardianDb.tryUpdateStatus id statusStr vetoReason

// ---------------------------------------------------------------------------
// GuardianHandler — MCP tool functions
// ---------------------------------------------------------------------------

/// MCP tool handler for Guardian approval operations.
/// Backed by SQLite (data/holons/guardian/proposals.db) with in-memory
/// hot-path cache. All IO uses graceful degradation via try/with so that
/// every function always returns a Result<string, string>.
///
/// STAMP: SC-GUARD-001, SC-GUARD-002, SC-GUARD-003, SC-SAFETY-001,
///        SC-GDE-001, SC-XHOLON-001, SC-XHOLON-030, SC-XHOLON-031
/// AOR:   AOR-GDE-002, AOR-CAE-002, AOR-XHOLON-011
module GuardianHandler =

    let private statusString (s: ProposalStatus) : string =
        match s with
        | ProposalStatus.Pending   -> "pending"
        | ProposalStatus.Approved  -> "approved"
        | ProposalStatus.Vetoed _  -> "vetoed"
        | ProposalStatus.Expired   -> "expired"

    let private toApprovalRecord (p: GuardianProposal) (s: ProposalStatus) : GuardianApprovalRecord =
        { ProposalId = p.ProposalId
          Status     = statusString s
          Reason     = match s with ProposalStatus.Vetoed r -> Some r | _ -> None
          Timestamp  = DateTimeOffset.UtcNow.ToString("o") }

    let private serialise<'T> (v: 'T) : string =
        JsonSerializer.Serialize(v)

    // -----------------------------------------------------------------------
    // Public MCP tool functions
    // -----------------------------------------------------------------------

    /// Creates a new Guardian proposal and persists it to SQLite.
    ///
    /// Parameters:
    ///   actor      — identity of the requesting agent (required, non-empty)
    ///   action     — operation to be performed, e.g. "deploy", "mutate" (required)
    ///   target     — resource being acted upon
    ///   payload    — JSON string describing the change
    ///   stamp_refs — list of STAMP constraint IDs this proposal satisfies
    ///
    /// Returns: JSON object { proposal_id, status, timestamp, message, storage }
    ///
    /// STAMP: SC-SAFETY-001 (Guardian pre-approval for mutations)
    let submitProposal
        (actor     : string)
        (action    : string)
        (target    : string)
        (payload   : string)
        (stampRefs : string list) : Result<string, string> =

        if String.IsNullOrWhiteSpace actor then
            Error "actor must not be empty"
        elif String.IsNullOrWhiteSpace action then
            Error "action must not be empty"
        else
            try
                let proposalId =
                    sprintf "GRD-%s-%s"
                        (DateTimeOffset.UtcNow.ToString("yyyyMMddHHmmss"))
                        (Guid.NewGuid().ToString("N").[..7])
                let proposal : GuardianProposal = {
                    ProposalId = proposalId
                    Actor      = actor
                    Action     = action
                    Target     = if String.IsNullOrWhiteSpace target then "(unspecified)" else target
                    Payload    = if String.IsNullOrWhiteSpace payload then "{}" else payload
                    Timestamp  = DateTimeOffset.UtcNow.ToString("o")
                    StampRefs  = stampRefs
                }
                GuardianState.store proposal
                eprintfn "[GuardianHandler] proposal queued: %s actor=%s action=%s target=%s"
                    proposalId actor action target
                let result = {|
                    proposal_id = proposalId
                    status      = "pending"
                    timestamp   = proposal.Timestamp
                    message     =
                        sprintf "Proposal %s queued for Guardian evaluation (SC-SAFETY-001)"
                            proposalId
                    storage     = "sqlite+cache"
                |}
                Ok (serialise result)
            with ex ->
                Error (sprintf "submitProposal failed: %s" ex.Message)

    /// Queries the current approval status of a proposal by ID.
    /// Cache-first lookup with SQLite fallback.
    ///
    /// Returns: JSON object { proposal_id, status, reason?, timestamp }
    ///
    /// STAMP: SC-GUARD-001 (Guardian Envelope for constraint values)
    let queryStatus (proposalId: string) : Result<string, string> =
        if String.IsNullOrWhiteSpace proposalId then
            Error "proposal_id must not be empty"
        else
            try
                match GuardianState.getStatus proposalId with
                | None ->
                    Error (sprintf "Proposal '%s' not found in Guardian store" proposalId)
                | Some (proposal, status) ->
                    Ok (serialise (toApprovalRecord proposal status))
            with ex ->
                Error (sprintf "queryStatus failed: %s" ex.Message)

    /// Lists all proposals currently in Pending state.
    /// Merges SQLite rows with in-memory cache (SQLite is authoritative).
    ///
    /// Returns: JSON object { count, pending: [...], source }
    ///
    /// STAMP: SC-GDE-001 (Guardian validation required)
    let listPending () : Result<string, string> =
        try
            let pending =
                GuardianState.allPending ()
                |> List.map (fun (p, s) -> toApprovalRecord p s)
            let result = {|
                count   = pending.Length
                pending = pending
                source  = "sqlite+cache"
            |}
            Ok (serialise result)
        with ex ->
            Error (sprintf "listPending failed: %s" ex.Message)

    /// Approves a pending proposal (Guardian decision).
    /// Persists the approved state to SQLite.
    ///
    /// STAMP: SC-GUARD-002 (Guardian integrates with DeadMansSwitch, fail closed)
    let approveProposal (proposalId: string) : Result<string, string> =
        if String.IsNullOrWhiteSpace proposalId then
            Error "proposal_id must not be empty"
        else
            try
                match GuardianState.getStatus proposalId with
                | None ->
                    Error (sprintf "Proposal '%s' not found in Guardian store" proposalId)
                | Some (proposal, ProposalStatus.Pending) ->
                    GuardianState.updateStatus proposalId ProposalStatus.Approved
                    eprintfn "[GuardianHandler] APPROVED: %s actor=%s action=%s"
                        proposalId proposal.Actor proposal.Action
                    Ok (serialise (toApprovalRecord proposal ProposalStatus.Approved))
                | Some (_proposal, status) ->
                    Error (sprintf "Proposal '%s' is not pending (current: %s)"
                               proposalId (statusString status))
            with ex ->
                Error (sprintf "approveProposal failed: %s" ex.Message)

    /// Vetoes a pending proposal with a reason.
    /// Veto reason is persisted to SQLite for audit trail (SC-REG-001).
    ///
    /// STAMP: SC-GUARD-003 (Guardian integrates with FounderDirective),
    ///        SC-REG-001 (all state mutations via append-only blocks)
    let vetoProposal (proposalId: string) (reason: string) : Result<string, string> =
        if String.IsNullOrWhiteSpace proposalId then
            Error "proposal_id must not be empty"
        else
            try
                let vetoReason =
                    if String.IsNullOrWhiteSpace reason then "No reason given" else reason
                match GuardianState.getStatus proposalId with
                | None ->
                    Error (sprintf "Proposal '%s' not found in Guardian store" proposalId)
                | Some (proposal, ProposalStatus.Pending) ->
                    let status = ProposalStatus.Vetoed vetoReason
                    GuardianState.updateStatus proposalId status
                    eprintfn "[GuardianHandler] VETOED: %s reason=%s actor=%s action=%s"
                        proposalId vetoReason proposal.Actor proposal.Action
                    Ok (serialise (toApprovalRecord proposal status))
                | Some (_proposal, status) ->
                    Error (sprintf "Proposal '%s' is not pending (current: %s)"
                               proposalId (statusString status))
            with ex ->
                Error (sprintf "vetoProposal failed: %s" ex.Message)
