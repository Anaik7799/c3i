// =============================================================================
// CrmAuditView.fs - CEPAF Cockpit TUI CRM Audit Log Visualisation
// =============================================================================
// STAMP: SC-AUDIT-001 (append-only audit trail), SC-HMI-010 (Color Rich),
//        SC-REG-001 (all state mutations via immutable register)
// Version: 21.3.2 | 2026-03-30
//
// Pure VIEW layer — defines CRM field-change audit record types and ANSI
// rendering for the Prajna Cockpit TUI.
//
// No I/O, no side effects, no DuckDB access.  All data is passed in.
// Callers are responsible for fetching records and calling render functions.
//
// ## Constitutional Alignment
// - Ψ₁ (Regeneration):  Audit entries are reconstructed from DuckDB state
// - Ψ₂ (History):       Change log is append-only; no mutation of past entries
// - Ψ₃ (Verification):  Every field change carries actor, timestamp, session
//
// ## STAMP Compliance
// - SC-AUDIT-001:  Field-level change tracking for all CRM entities
// - SC-HMI-010:   Vibrant chromatic badges per ChangeKind (Created/Updated/…)
// - SC-REG-001:   Append-only semantics; rendering must not imply mutability
// =============================================================================

namespace Cepaf.Cockpit

open System

// ---------------------------------------------------------------------------
// ANSI colour helpers — inline, no external dependency
// Prefix: CaAnsi  (Ca = CrmAudit, distinct from SparkAnsi / MiAnsi / etc.)
// ---------------------------------------------------------------------------

[<RequireQualifiedAccess>]
module private CaAnsi =
    // --- Reset & decoration ---
    let reset   = "\u001b[0m"
    let bold    = "\u001b[1m"
    let dim     = "\u001b[2m"
    let italic  = "\u001b[3m"

    // --- Standard palette ---
    let black   = "\u001b[30m"
    let red     = "\u001b[31m"
    let green   = "\u001b[32m"
    let yellow  = "\u001b[33m"
    let blue    = "\u001b[34m"
    let magenta = "\u001b[35m"
    let cyan    = "\u001b[36m"
    let white   = "\u001b[37m"

    // --- Bright palette ---
    let bRed     = "\u001b[91m"
    let bGreen   = "\u001b[92m"
    let bYellow  = "\u001b[93m"
    let bBlue    = "\u001b[94m"
    let bMagenta = "\u001b[95m"
    let bCyan    = "\u001b[96m"
    let bWhite   = "\u001b[97m"

    // --- Background colours used for badges ---
    let bgRed     = "\u001b[41m"
    let bgGreen   = "\u001b[42m"
    let bgYellow  = "\u001b[43m"
    let bgCyan    = "\u001b[46m"
    let bgMagenta = "\u001b[45m"
    let bgBlack   = "\u001b[40m"

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// The kind of change that occurred on a CRM entity.
type ChangeKind =
    /// A new entity was created from scratch.
    | Created
    /// One or more fields on an existing entity were modified.
    | Updated
    /// The entity was soft-deleted (marked inactive).
    | Deleted
    /// A previously deleted entity was brought back to active state.
    | Restored
    /// Two entity records were merged into a single canonical record.
    | Merged

/// The data type of a CRM field, used to select value display formatting.
type FieldType =
    /// Free-form text (names, descriptions, notes).
    | Text
    /// Whole or decimal numeric value (counts, scores).
    | Number
    /// Monetary amount (prices, revenue, budget).
    | Currency
    /// Calendar date or datetime value.
    | Date
    /// One value from a fixed enumeration (status, priority, stage).
    | Enum
    /// Foreign-key reference to another CRM entity.
    | Relation

/// Captures a single field-level change within an audit entry.
type FieldChange = {
    /// Name of the field that changed (e.g. "owner_id", "stage", "amount").
    FieldName  : string
    /// Data type of the field, used for display formatting.
    FieldType  : FieldType
    /// Previous value of the field; None for newly-set fields (Created rows).
    OldValue   : string option
    /// New value of the field after the change.
    NewValue   : string
    /// Identity of the user or system that made the change.
    ChangedBy  : string
    /// Wall-clock time at which the change was committed.
    ChangedAt  : DateTimeOffset
}

/// A single atomic change event for one CRM entity.
type AuditEntry = {
    /// Stable identifier of the entity that was changed.
    EntityId   : string
    /// Human-readable entity type (e.g. "Contact", "Opportunity", "Account").
    EntityType : string
    /// The high-level kind of mutation that was performed.
    ChangeKind : ChangeKind
    /// Ordered list of field-level diffs included in this change event.
    Changes    : FieldChange list
    /// Wall-clock time at which the audit entry was recorded.
    Timestamp  : DateTimeOffset
    /// Session identifier that produced this change (for correlation).
    SessionId  : string
}

/// A paginated / filtered view over a CRM entity's change history.
type AuditLog = {
    /// All audit entries in this view, ordered newest-first.
    Entries        : AuditEntry list
    /// Total number of field-level changes across all entries.
    TotalChanges   : int
    /// Count of distinct EntityId values represented in this log.
    UniqueEntities : int
    /// Human-readable description of the date range (e.g. "2026-03-01 → 2026-03-30").
    DateRange      : string
}

// ---------------------------------------------------------------------------
// CrmAuditView — pure rendering functions
// ---------------------------------------------------------------------------

/// Renders CRM audit records as ANSI-coloured TUI strings.
/// All functions are pure (no I/O).  Callers print the returned strings.
[<RequireQualifiedAccess>]
module CrmAuditView =

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /// Returns the ANSI foreground colour string for a given ChangeKind.
    /// Created=bright-green  Updated=bright-yellow  Deleted=bright-red
    /// Restored=bright-cyan  Merged=bright-magenta
    let changeKindColour (kind: ChangeKind) : string =
        match kind with
        | Created  -> CaAnsi.bGreen
        | Updated  -> CaAnsi.bYellow
        | Deleted  -> CaAnsi.bRed
        | Restored -> CaAnsi.bCyan
        | Merged   -> CaAnsi.bMagenta

    /// Short label used inside the change-kind badge (5 chars fixed width).
    let private changeKindLabel (kind: ChangeKind) : string =
        match kind with
        | Created  -> "CRTD "
        | Updated  -> "UPDT "
        | Deleted  -> "DEL  "
        | Restored -> "REST "
        | Merged   -> "MRGD "

    /// Background colour string matched to the ChangeKind badge.
    let private changeKindBg (kind: ChangeKind) : string =
        match kind with
        | Created  -> CaAnsi.bgGreen
        | Updated  -> CaAnsi.bgYellow
        | Deleted  -> CaAnsi.bgRed
        | Restored -> CaAnsi.bgCyan
        | Merged   -> CaAnsi.bgMagenta

    /// Renders a coloured inline badge: "[ CRTD ]"
    let private badge (kind: ChangeKind) : string =
        let fg = CaAnsi.bWhite
        let bg = changeKindBg kind
        let lbl = changeKindLabel kind
        sprintf "%s%s%s%s%s" CaAnsi.bold bg fg lbl CaAnsi.reset

    /// Prefixes a FieldType-appropriate icon (single ASCII glyph).
    let private fieldTypeIcon (ft: FieldType) : string =
        match ft with
        | Text     -> "T"
        | Number   -> "#"
        | Currency -> "$"
        | Date     -> "D"
        | Enum     -> "E"
        | Relation -> "→"

    /// Formats an optional old value: "—" when absent (field was newly set).
    let private fmtOldValue (v: string option) : string =
        match v with
        | None   -> sprintf "%s—%s" CaAnsi.dim CaAnsi.reset
        | Some s -> sprintf "%s%s%s" CaAnsi.bRed s CaAnsi.reset

    /// Formats the new value in green to signal the current live state.
    let private fmtNewValue (v: string) : string =
        sprintf "%s%s%s" CaAnsi.bGreen v CaAnsi.reset

    /// Compact ISO-8601 timestamp (no milliseconds).
    let private fmtTimestamp (dto: DateTimeOffset) : string =
        dto.ToString("yyyy-MM-dd HH:mm:ss zzz")

    /// Horizontal rule using box-drawing dashes.
    let private hrThin  (width: int) : string = String.replicate width "─"
    let private hrThick (width: int) : string = String.replicate width "═"

    // -----------------------------------------------------------------------
    // Public rendering API
    // -----------------------------------------------------------------------

    /// Renders a single field-level diff line.
    ///
    /// Format:
    ///   [T] field_name          OldValue → NewValue   (changed-by @ timestamp)
    let renderFieldChange (fc: FieldChange) : string =
        let icon    = fieldTypeIcon fc.FieldType
        let name    = fc.FieldName.PadRight(24)
        let oldStr  = fmtOldValue fc.OldValue
        let newStr  = fmtNewValue fc.NewValue
        let arrow   = sprintf "%s→%s" CaAnsi.dim CaAnsi.reset
        let actor   = sprintf "%s%s%s" CaAnsi.cyan fc.ChangedBy CaAnsi.reset
        let ts      = sprintf "%s%s%s" CaAnsi.dim (fmtTimestamp fc.ChangedAt) CaAnsi.reset
        sprintf "    %s[%s]%s %s%s%s  %s %s %s  %s@%s %s"
            CaAnsi.dim icon CaAnsi.reset
            CaAnsi.white name CaAnsi.reset
            oldStr arrow newStr
            actor CaAnsi.dim ts

    /// Renders a single audit entry with badge, entity info, and all field diffs.
    ///
    /// Format:
    ///   [ UPDT ] Contact · 8f3a12d9    2026-03-29 14:05:00 +01:00   session:abc
    ///   ──────────────────────────────────────────────────────────────────────
    ///     [T] stage                    Prospect → Customer   (admin @ ...)
    ///     [$] amount                   —        → 12000.00   (admin @ ...)
    let renderEntry (entry: AuditEntry) : string =
        let kindCol   = changeKindColour entry.ChangeKind
        let bdg       = badge entry.ChangeKind
        let entityLbl =
            sprintf "%s%s%s %s· %s%s%s"
                CaAnsi.bold CaAnsi.bWhite entry.EntityType CaAnsi.reset
                CaAnsi.dim entry.EntityId CaAnsi.reset
        let ts   = sprintf "%s%s%s" CaAnsi.dim (fmtTimestamp entry.Timestamp) CaAnsi.reset
        let sess = sprintf "%ssession:%s%s%s" CaAnsi.dim CaAnsi.white entry.SessionId CaAnsi.reset
        let sep  = sprintf "%s%s%s" kindCol (hrThin 72) CaAnsi.reset
        let header =
            sprintf "  %s  %s    %s  %s"
                bdg entityLbl ts sess
        let fieldLines =
            entry.Changes
            |> List.map renderFieldChange
            |> String.concat "\n"
        sprintf "%s\n%s\n%s" header sep fieldLines

    /// Renders the full bordered audit log pane with header statistics and all entries.
    ///
    /// Format:
    ///   ╔══ CRM AUDIT LOG ════════════════════════════════════════════════╗
    ///   ║  Total changes: 12   Unique entities: 4   Range: 2026-03-01 → …  ║
    ///   ╠══════════════════════════════════════════════════════════════════╣
    ///   … entries …
    ///   ╚══════════════════════════════════════════════════════════════════╝
    let renderLog (log: AuditLog) : string =
        let innerWidth = 72

        let topBorder =
            sprintf "%s%s╔═ CRM AUDIT LOG %s%s╗%s"
                CaAnsi.bold CaAnsi.bCyan
                (String.replicate (innerWidth - String.length "╔═ CRM AUDIT LOG " - 1) "═")
                CaAnsi.reset CaAnsi.reset

        let statsLine =
            sprintf "  %sTotal changes:%s %s%d%s   %sUnique entities:%s %s%d%s   %sRange:%s %s%s%s"
                CaAnsi.dim CaAnsi.reset
                CaAnsi.bWhite log.TotalChanges CaAnsi.reset
                CaAnsi.dim CaAnsi.reset
                CaAnsi.bWhite log.UniqueEntities CaAnsi.reset
                CaAnsi.dim CaAnsi.reset
                CaAnsi.white log.DateRange CaAnsi.reset

        let divider =
            sprintf "%s%s╠%s╣%s"
                CaAnsi.bCyan CaAnsi.bold
                (hrThick innerWidth)
                CaAnsi.reset

        let bottomBorder =
            sprintf "%s%s╚%s╝%s"
                CaAnsi.bold CaAnsi.bCyan
                (hrThick innerWidth)
                CaAnsi.reset

        let entryBlocks =
            log.Entries
            |> List.map renderEntry
            |> String.concat (sprintf "\n%s%s%s\n" CaAnsi.dim (hrThin innerWidth) CaAnsi.reset)

        sprintf "%s\n%s\n%s\n%s\n%s"
            topBorder statsLine divider entryBlocks bottomBorder

    /// Renders a compact one-liner summary of the audit log.
    ///
    /// Example:
    ///   AuditLog: 12 changes | 4 entities | 5 entries | 2026-03-01 → 2026-03-30
    let renderCompact (log: AuditLog) : string =
        let entryCount = List.length log.Entries
        sprintf "%sAuditLog:%s %s%d changes%s | %s%d entities%s | %s%d entries%s | %s%s%s"
            CaAnsi.bold CaAnsi.reset
            CaAnsi.bGreen log.TotalChanges CaAnsi.reset
            CaAnsi.bYellow log.UniqueEntities CaAnsi.reset
            CaAnsi.bCyan entryCount CaAnsi.reset
            CaAnsi.dim log.DateRange CaAnsi.reset

    /// Returns a sample AuditLog with 5 entries spanning different entity types,
    /// change kinds, and field types.  Useful for TUI preview and unit tests.
    let defaultLog () : AuditLog =
        let now    = DateTimeOffset(2026, 3, 30, 10, 0, 0, TimeSpan.FromHours 1.0)
        let sess1  = "s-4f2a"
        let sess2  = "s-9c1b"
        let sess3  = "s-7d3e"

        let entry1 = {
            EntityId   = "cnt-001"
            EntityType = "Contact"
            ChangeKind = Created
            Changes    = [
                { FieldName = "full_name";  FieldType = Text;     OldValue = None;             NewValue = "Riya Sharma";      ChangedBy = "admin";    ChangedAt = now.AddMinutes -60.0 }
                { FieldName = "email";      FieldType = Text;     OldValue = None;             NewValue = "riya@example.com"; ChangedBy = "admin";    ChangedAt = now.AddMinutes -60.0 }
                { FieldName = "stage";      FieldType = Enum;     OldValue = None;             NewValue = "Lead";             ChangedBy = "admin";    ChangedAt = now.AddMinutes -60.0 }
            ]
            Timestamp  = now.AddMinutes -60.0
            SessionId  = sess1
        }

        let entry2 = {
            EntityId   = "opp-042"
            EntityType = "Opportunity"
            ChangeKind = Updated
            Changes    = [
                { FieldName = "stage";      FieldType = Enum;     OldValue = Some "Prospect";  NewValue = "Qualified";       ChangedBy = "sales-bot"; ChangedAt = now.AddMinutes -45.0 }
                { FieldName = "amount";     FieldType = Currency; OldValue = Some "8000.00";   NewValue = "12000.00";        ChangedBy = "sales-bot"; ChangedAt = now.AddMinutes -45.0 }
                { FieldName = "close_date"; FieldType = Date;     OldValue = Some "2026-04-01"; NewValue = "2026-03-28";     ChangedBy = "sales-bot"; ChangedAt = now.AddMinutes -45.0 }
            ]
            Timestamp  = now.AddMinutes -45.0
            SessionId  = sess2
        }

        let entry3 = {
            EntityId   = "acct-007"
            EntityType = "Account"
            ChangeKind = Deleted
            Changes    = [
                { FieldName = "status";     FieldType = Enum;     OldValue = Some "Active";    NewValue = "Inactive";        ChangedBy = "admin";    ChangedAt = now.AddMinutes -30.0 }
                { FieldName = "reason";     FieldType = Text;     OldValue = None;             NewValue = "Duplicate record"; ChangedBy = "admin";   ChangedAt = now.AddMinutes -30.0 }
            ]
            Timestamp  = now.AddMinutes -30.0
            SessionId  = sess1
        }

        let entry4 = {
            EntityId   = "acct-007"
            EntityType = "Account"
            ChangeKind = Restored
            Changes    = [
                { FieldName = "status";     FieldType = Enum;     OldValue = Some "Inactive";  NewValue = "Active";          ChangedBy = "supervisor"; ChangedAt = now.AddMinutes -15.0 }
                { FieldName = "note";       FieldType = Text;     OldValue = None;             NewValue = "Restored after manual review"; ChangedBy = "supervisor"; ChangedAt = now.AddMinutes -15.0 }
            ]
            Timestamp  = now.AddMinutes -15.0
            SessionId  = sess3
        }

        let entry5 = {
            EntityId   = "cnt-099"
            EntityType = "Contact"
            ChangeKind = Merged
            Changes    = [
                { FieldName = "canonical_id"; FieldType = Relation; OldValue = Some "cnt-099"; NewValue = "cnt-001";         ChangedBy = "dedup-agent"; ChangedAt = now }
                { FieldName = "phone";         FieldType = Text;    OldValue = Some "+49-000"; NewValue = "+49-800-555-0100"; ChangedBy = "dedup-agent"; ChangedAt = now }
                { FieldName = "lead_score";    FieldType = Number;  OldValue = Some "42";      NewValue = "78";              ChangedBy = "dedup-agent"; ChangedAt = now }
            ]
            Timestamp  = now
            SessionId  = sess2
        }

        let entries = [ entry1; entry2; entry3; entry4; entry5 ]

        {
            Entries        = entries
            TotalChanges   = entries |> List.sumBy (fun e -> List.length e.Changes)
            UniqueEntities = entries |> List.map (fun e -> e.EntityId) |> List.distinct |> List.length
            DateRange      = "2026-03-30 09:00 → 2026-03-30 10:00"
        }
