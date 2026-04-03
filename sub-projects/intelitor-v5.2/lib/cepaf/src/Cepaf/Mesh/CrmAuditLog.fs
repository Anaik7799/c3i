// =============================================================================
// CrmAuditLog.fs - CRM Field Change Tracking with Audit Log to DuckDB
// =============================================================================
// STAMP: SC-AUDIT-001 (append-only audit trail),
//        SC-XHOLON-035 (DuckDB audit trail immutable, append-only),
//        SC-REG-001 (all state mutations via append-only blocks)
//
// ## Purpose
// Track field-level changes for CRM entities (contact, account, opportunity,
// lead, case) in an append-only audit log.  Each mutation records who changed
// what field, from what value, to what value, and optionally why.
//
// ## Storage
// In-memory ConcurrentDictionary (stub). Production target is DuckDB append-only
// tables per SC-XHOLON-035.  All writes are append-only — entries are NEVER
// mutated or deleted once recorded.
//
// ## Functions
// | Function          | Description                                       |
// |-------------------|---------------------------------------------------|
// | toJson            | JSON serialisation of an AuditReport              |
// | recordChange      | Append field changes for an entity to audit log   |
// | queryAudit        | Filtered query across audit entries               |
// | getEntityHistory  | Full change history for a specific entity         |
// | getFieldHistory   | Single-field history for a specific entity        |
// | renderAuditTable  | ANSI-coloured table of audit entries              |
//
// ## Entity Types
// "contact" | "account" | "opportunity" | "lead" | "case"
//
// ## EntryId Format
// AUD-{yyyyMMddHHmmss}-{guid8}  (e.g. AUD-20260330-142305-a1b2c3d4)
//
// ## Version History
// | Version  | Date       | Author               | Change               |
// |----------|------------|----------------------|----------------------|
// | v21.3.2  | 2026-03-30 | Cybernetic Architect | Initial — W20        |
// =============================================================================

namespace Cepaf.Mesh

open System
open System.Text.Json
open System.Collections.Concurrent

// ---------------------------------------------------------------------------
// Domain Types
// ---------------------------------------------------------------------------

/// A single field-level change within an audit entry.
/// STAMP: SC-AUDIT-001, SC-REG-001
type FieldChange = {
    /// Name of the field that changed (e.g. "email", "status")
    FieldName: string
    /// Previous value, or None for newly-set fields
    OldValue: string option
    /// New value after the change
    NewValue: string
    /// Identity of the actor who made the change (user ID, agent ID, etc.)
    ChangedBy: string
    /// ISO-8601 UTC timestamp of this specific field change
    Timestamp: string
}

/// An immutable audit entry recording one or more field changes for an entity.
/// STAMP: SC-AUDIT-001, SC-XHOLON-035
type AuditEntry = {
    /// Unique audit entry identifier — format: AUD-{yyyyMMddHHmmss}-{guid8}
    EntryId: string
    /// CRM entity type: "contact" | "account" | "opportunity" | "lead" | "case"
    EntityType: string
    /// Primary key of the entity being audited
    EntityId: string
    /// Ordered list of field changes in this audit entry
    Changes: FieldChange list
    /// Optional human-readable reason for the change batch
    Reason: string option
    /// ISO-8601 UTC timestamp at which this entry was recorded
    Timestamp: string
}

/// Query parameters for filtering audit log entries.
/// All filters are optional; omitted filters are not applied.
type AuditQuery = {
    /// Filter by entity type (e.g. "contact")
    EntityType: string option
    /// Filter by entity ID
    EntityId: string option
    /// Filter to entries that contain a change for this field name
    FieldName: string option
    /// ISO-8601 start date (inclusive)
    StartDate: string option
    /// ISO-8601 end date (inclusive)
    EndDate: string option
    /// Maximum number of entries to return (default 100)
    Limit: int
}

/// Query result containing matched audit entries and aggregate counts.
type AuditReport = {
    /// Matched audit entries (up to Limit)
    Entries: AuditEntry list
    /// Total number of matching entries before the Limit was applied
    TotalCount: int
    /// ISO-8601 UTC timestamp at which the query was executed
    QueryTimestamp: string
}

// ---------------------------------------------------------------------------
// CrmAuditLog Module
// ---------------------------------------------------------------------------

/// <summary>
/// CRM field change tracking module — append-only audit log.
///
/// STAMP: SC-AUDIT-001, SC-XHOLON-035, SC-REG-001
/// Production target: DuckDB append-only tables.
/// Current implementation: in-memory ConcurrentDictionary (stub).
/// </summary>
[<RequireQualifiedAccess>]
module CrmAuditLog =

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// Valid CRM entity types.
    let private validEntityTypes =
        Set.ofList [ "contact"; "account"; "opportunity"; "lead"; "case" ]

    // -------------------------------------------------------------------------
    // Private state — in-memory store (stub for DuckDB)
    // -------------------------------------------------------------------------

    /// In-memory append-only audit log.
    /// Key   = EntryId (globally unique)
    /// Value = AuditEntry (immutable once inserted)
    /// Production: replaced by DuckDB append-only table (SC-XHOLON-035)
    let private store = ConcurrentDictionary<string, AuditEntry>(StringComparer.Ordinal)

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /// Generate a new EntryId in the form AUD-{yyyyMMddHHmmss}-{guid8}.
    let private generateEntryId () : string =
        let ts   = DateTimeOffset.UtcNow.ToString("yyyyMMddHHmmss")
        let guid = Guid.NewGuid().ToString("N").[..7]
        sprintf "AUD-%s-%s" ts guid

    /// Current UTC timestamp in ISO-8601 format.
    let private nowIso () : string =
        DateTimeOffset.UtcNow.ToString("o")

    /// Validate that the entity type is one of the supported CRM types.
    let private validateEntityType (entityType: string) : Result<string, string> =
        let t = entityType.Trim().ToLowerInvariant()
        if Set.contains t validEntityTypes then
            Ok t
        else
            Error (sprintf "Invalid entity type '%s'. Must be one of: %s"
                       entityType
                       (String.concat ", " (Set.toList validEntityTypes)))

    /// Return all entries as a list sorted by Timestamp descending.
    let private allEntriesDescending () : AuditEntry list =
        store.Values
        |> Seq.toList
        |> List.sortByDescending (fun e -> e.Timestamp)

    /// Apply AuditQuery filters to a list of entries.
    let private applyFilters (q: AuditQuery) (entries: AuditEntry list) : AuditEntry list =
        entries
        |> List.filter (fun e ->
            let typeOk =
                match q.EntityType with
                | Some t -> String.Equals(e.EntityType, t.Trim().ToLowerInvariant(), StringComparison.Ordinal)
                | None   -> true
            let idOk =
                match q.EntityId with
                | Some id -> String.Equals(e.EntityId, id.Trim(), StringComparison.Ordinal)
                | None    -> true
            let fieldOk =
                match q.FieldName with
                | Some fn ->
                    e.Changes |> List.exists (fun c ->
                        String.Equals(c.FieldName, fn.Trim(), StringComparison.OrdinalIgnoreCase))
                | None -> true
            let startOk =
                match q.StartDate with
                | Some s -> String.Compare(e.Timestamp, s, StringComparison.Ordinal) >= 0
                | None   -> true
            let endOk =
                match q.EndDate with
                | Some en -> String.Compare(e.Timestamp, en, StringComparison.Ordinal) <= 0
                | None    -> true
            typeOk && idOk && fieldOk && startOk && endOk)

    // -------------------------------------------------------------------------
    // ANSI colour helpers (mirrors ConsoleChannel conventions)
    // -------------------------------------------------------------------------

    let private ansiGreen  = "\u001b[32m"
    let private ansiYellow = "\u001b[33m"
    let private ansiCyan   = "\u001b[36m"
    let private ansiReset  = "\u001b[0m"
    let private ansiBold   = "\u001b[1m"

    // -------------------------------------------------------------------------
    // Public API
    // (Ordered so each function only references previously-defined functions)
    // -------------------------------------------------------------------------

    /// <summary>
    /// Serialise an AuditReport to a JSON string.
    ///
    /// Uses System.Text.Json with camelCase naming.
    ///
    /// STAMP: SC-SER-001
    /// </summary>
    let toJson (report: AuditReport) : string =
        let opts = JsonSerializerOptions(PropertyNamingPolicy = JsonNamingPolicy.CamelCase)
        let serializeChange (c: FieldChange) =
            {|
                fieldName  = c.FieldName
                oldValue   = c.OldValue |> Option.defaultValue null
                newValue   = c.NewValue
                changedBy  = c.ChangedBy
                timestamp  = c.Timestamp
            |}
        let serializeEntry (e: AuditEntry) =
            {|
                entryId    = e.EntryId
                entityType = e.EntityType
                entityId   = e.EntityId
                changes    = e.Changes |> List.map serializeChange
                reason     = e.Reason |> Option.defaultValue null
                timestamp  = e.Timestamp
            |}
        let payload = {|
            entries        = report.Entries |> List.map serializeEntry
            totalCount     = report.TotalCount
            queryTimestamp = report.QueryTimestamp
        |}
        JsonSerializer.Serialize(payload, opts)

    /// <summary>
    /// Append a batch of field changes for a CRM entity to the audit log.
    ///
    /// Returns Ok(entryId) on success, Error(reason) on failure.
    ///
    /// STAMP: SC-AUDIT-001 (append-only), SC-REG-001 (immutable mutations)
    /// </summary>
    let recordChange
            (entityType : string)
            (entityId   : string)
            (changes    : FieldChange list)
            (reason     : string option)
            : Result<string, string> =
        try
            match validateEntityType entityType with
            | Error e -> Error e
            | Ok validType ->
                if String.IsNullOrWhiteSpace entityId then
                    Error "entityId must not be empty"
                elif changes.IsEmpty then
                    Error "changes list must contain at least one FieldChange"
                else
                    let entryId = generateEntryId ()
                    let ts      = nowIso ()
                    let entry : AuditEntry = {
                        EntryId    = entryId
                        EntityType = validType
                        EntityId   = entityId.Trim()
                        Changes    = changes
                        Reason     = reason
                        Timestamp  = ts
                    }
                    // Append-only: do not overwrite existing key (UUID collision is practically impossible)
                    if store.TryAdd(entryId, entry) then
                        eprintfn "[CrmAuditLog] AUDIT recorded: %s entity=%s/%s fields=%d"
                            entryId validType entityId changes.Length
                        Ok entryId
                    else
                        Error (sprintf "Duplicate EntryId collision: %s" entryId)
        with ex ->
            eprintfn "[CrmAuditLog] ERROR in recordChange: %s" ex.Message
            Error (sprintf "recordChange failed: %s" ex.Message)

    /// <summary>
    /// Query the audit log with optional filters.
    ///
    /// Returns Ok(json) containing an AuditReport, or Error(reason).
    ///
    /// STAMP: SC-AUDIT-001, SC-XHOLON-035
    /// </summary>
    let queryAudit (query: AuditQuery) : Result<string, string> =
        try
            let all      = allEntriesDescending ()
            let filtered = applyFilters query all
            let total    = filtered.Length
            let limited  = filtered |> List.truncate (max 1 query.Limit)
            let report : AuditReport = {
                Entries        = limited
                TotalCount     = total
                QueryTimestamp = nowIso ()
            }
            eprintfn "[CrmAuditLog] queryAudit matched=%d limited=%d" total limited.Length
            Ok (toJson report)
        with ex ->
            eprintfn "[CrmAuditLog] ERROR in queryAudit: %s" ex.Message
            Error (sprintf "queryAudit failed: %s" ex.Message)

    /// <summary>
    /// Retrieve the full change history for a specific CRM entity.
    ///
    /// Returns Ok(json) containing an AuditReport, or Error(reason).
    ///
    /// STAMP: SC-XHOLON-035
    /// </summary>
    let getEntityHistory (entityType: string) (entityId: string) : Result<string, string> =
        let query = {
            EntityType = Some entityType
            EntityId   = Some entityId
            FieldName  = None
            StartDate  = None
            EndDate    = None
            Limit      = Int32.MaxValue
        }
        queryAudit query

    /// <summary>
    /// Retrieve the change history for a single field on a specific CRM entity.
    ///
    /// Only audit entries that include a FieldChange for the specified field
    /// are returned.  The FieldChange list on each entry is NOT filtered —
    /// the full entry is returned so callers can see co-changed fields.
    ///
    /// Returns Ok(json) containing an AuditReport, or Error(reason).
    ///
    /// STAMP: SC-XHOLON-035
    /// </summary>
    let getFieldHistory
            (entityType : string)
            (entityId   : string)
            (fieldName  : string)
            : Result<string, string> =
        let query = {
            EntityType = Some entityType
            EntityId   = Some entityId
            FieldName  = Some fieldName
            StartDate  = None
            EndDate    = None
            Limit      = Int32.MaxValue
        }
        queryAudit query

    /// <summary>
    /// Render a list of AuditEntry values as an ANSI-coloured CLI table.
    ///
    /// Each row shows: EntryId | Entity | Field | OldValue | NewValue | ChangedBy | Timestamp
    ///
    /// STAMP: SC-HMI-010 (vibrant chromatic feedback)
    /// </summary>
    let renderAuditTable (entries: AuditEntry list) : string =
        if entries.IsEmpty then
            sprintf "%s[CrmAuditLog] No audit entries to display.%s" ansiYellow ansiReset
        else
            let sb = System.Text.StringBuilder()
            // Header row
            sb.AppendLine(
                sprintf "%s%s%-26s %-22s %-20s %-20s %-20s %-16s %-24s%s"
                    ansiBold ansiCyan
                    "EntryId" "Entity" "Field" "OldValue" "NewValue" "ChangedBy" "Timestamp"
                    ansiReset) |> ignore
            sb.AppendLine(String.replicate 150 "-") |> ignore
            // One row group per AuditEntry; expand to one line per FieldChange
            for entry in entries do
                let entityCell = sprintf "%s/%s" entry.EntityType entry.EntityId
                match entry.Changes with
                | [] ->
                    sb.AppendLine(
                        sprintf "%s%-26s %-22s %-20s %-20s %-20s %-16s %-24s%s"
                            ansiGreen
                            entry.EntryId entityCell "(none)" "-" "-" "-" entry.Timestamp
                            ansiReset) |> ignore
                | first :: rest ->
                    let truncate n (s: string) = if s.Length > n then s.[..n-3] + ".." else s
                    // First field change shares the EntryId cell
                    sb.AppendLine(
                        sprintf "%s%-26s %-22s %-20s %-20s %-20s %-16s %-24s%s"
                            ansiGreen
                            entry.EntryId entityCell
                            (truncate 20 first.FieldName)
                            (first.OldValue |> Option.defaultValue "(none)" |> truncate 20)
                            (truncate 20 first.NewValue)
                            (truncate 16 first.ChangedBy)
                            entry.Timestamp
                            ansiReset) |> ignore
                    // Additional field changes indented under the same entry
                    for c in rest do
                        sb.AppendLine(
                            sprintf "  %-24s %-22s %-20s %-20s %-20s %-16s"
                                "" ""
                                (truncate 20 c.FieldName)
                                (c.OldValue |> Option.defaultValue "(none)" |> truncate 20)
                                (truncate 20 c.NewValue)
                                (truncate 16 c.ChangedBy)) |> ignore
                    // Optional reason line
                    match entry.Reason with
                    | Some r ->
                        sb.AppendLine(sprintf "%s  Reason: %s%s" ansiYellow r ansiReset) |> ignore
                    | None -> ()
            sb.AppendLine(String.replicate 150 "-") |> ignore
            sb.AppendLine(sprintf "%sTotal: %d entries%s" ansiBold entries.Length ansiReset) |> ignore
            sb.ToString()
