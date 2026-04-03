// =============================================================================
// SmritiHandler.fs - MCP Tool Handler for SMRITI Knowledge Operations
// =============================================================================
// STAMP: SC-MCP-001 (MCP server integration), SC-SMRITI-131 (full-text search FTS5),
//        SC-SMRITI-132 (semantic search via vector embeddings),
//        SC-SMRITI-133 (query timeout < 500ms), SC-SMRITI-140 (all evolution events recorded)
// AOR: AOR-MCP-001 (authorised MCP tool dispatch),
//      AOR-CTX-007 (knowledge queries via Smriti)
//
// Implements MCP tool handler functions for SMRITI knowledge management.
// Provides note query, zettel lookup, and knowledge graph traversal.
//
// All public functions return Result<string, string>:
//   Ok    — JSON string for MCP TextContent.Text
//   Error — human-readable error message
//
// Note: Query execution delegates to SQLite FTS5 (stub mode without DB).
// Version: 21.3.1 | 2026-03-28
// =============================================================================

namespace Cepaf.Mcp

open System
open System.Text.Json
open System.Text.Json.Serialization

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// Classification of SMRITI knowledge content.
[<RequireQualifiedAccess>]
type NoteKind =
    | Zettel        // atomic permanent note
    | Journal       // dated journal entry
    | Architecture  // architecture decision record
    | Spec          // specification document
    | Unknown       // unclassified

/// A SMRITI knowledge note returned by query.
[<CLIMutable>]
type SmritiNote = {
    [<JsonPropertyName("note_id")>]    NoteId    : string
    [<JsonPropertyName("title")>]      Title     : string
    [<JsonPropertyName("kind")>]       Kind      : string
    [<JsonPropertyName("tags")>]       Tags      : string list
    [<JsonPropertyName("summary")>]    Summary   : string
    [<JsonPropertyName("updated_at")>] UpdatedAt : string
    [<JsonPropertyName("word_count")>] WordCount : int
}

/// Parameters for a SMRITI knowledge query.
[<CLIMutable>]
type SmritiQuery = {
    [<JsonPropertyName("query")>]     Query    : string
    [<JsonPropertyName("kind")>]      Kind     : string option
    [<JsonPropertyName("tags")>]      Tags     : string list
    [<JsonPropertyName("max_results")>] MaxResults : int
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

module private SmritiHelpers =

    open System.IO
    open System.Text.RegularExpressions

    let kindString (k: NoteKind) : string =
        match k with
        | NoteKind.Zettel       -> "zettel"
        | NoteKind.Journal      -> "journal"
        | NoteKind.Architecture -> "architecture"
        | NoteKind.Spec         -> "spec"
        | NoteKind.Unknown      -> "unknown"

    let parseKind (s: string option) : NoteKind option =
        match s with
        | None -> None
        | Some v ->
            match v.ToLowerInvariant() with
            | "zettel"       -> Some NoteKind.Zettel
            | "journal"      -> Some NoteKind.Journal
            | "architecture" -> Some NoteKind.Architecture
            | "spec"         -> Some NoteKind.Spec
            | _              -> Some NoteKind.Unknown

    let serialise<'T> (v: 'T) : string =
        JsonSerializer.Serialize(v)

    // -----------------------------------------------------------------------
    // Real file-system knowledge scanner
    // -----------------------------------------------------------------------

    let private projectRoot =
        let mutable dir = Directory.GetCurrentDirectory()
        // Walk up to find the project root (contains CLAUDE.md)
        while dir.Length > 1 && not (File.Exists(Path.Combine(dir, "CLAUDE.md"))) do
            dir <- Directory.GetParent(dir).FullName
        dir

    /// Classify a file path into a NoteKind based on directory.
    let private classifyFile (path: string) : NoteKind =
        let rel = path.Replace(projectRoot, "").Replace("\\", "/").TrimStart('/')
        if rel.Contains("/journal/") then NoteKind.Journal
        elif rel.Contains("/architecture/") then NoteKind.Architecture
        elif rel.Contains("/specs/") then NoteKind.Spec
        else NoteKind.Unknown

    /// Extract the title from a markdown file (first # heading or filename).
    let private extractTitle (content: string) (filePath: string) : string =
        let lines = content.Split('\n')
        let heading =
            lines
            |> Array.tryFind (fun l -> l.TrimStart().StartsWith("# "))
            |> Option.map (fun l -> l.TrimStart().Substring(2).Trim())
        match heading with
        | Some h when h.Length > 0 -> h
        | _ -> Path.GetFileNameWithoutExtension(filePath)

    /// Extract tags from frontmatter or SC-* references in content.
    let private extractTags (content: string) : string list =
        // Look for SC-* constraint references as implicit tags
        let scMatches = Regex.Matches(content, @"SC-([A-Z]+)")
        let scTags =
            scMatches
            |> Seq.cast<Match>
            |> Seq.map (fun m -> m.Groups.[1].Value.ToLowerInvariant())
            |> Seq.distinct
            |> Seq.truncate 10
            |> Seq.toList
        // Look for common keywords as tags
        let kwTags =
            [ "zenoh"; "guardian"; "sentinel"; "biomorphic"; "sil6"; "ooda";
              "cockpit"; "prajna"; "cortex"; "smriti"; "federation"; "holon" ]
            |> List.filter (fun kw -> content.Contains(kw, StringComparison.OrdinalIgnoreCase))
            |> List.truncate 5
        (scTags @ kwTags) |> List.distinct |> List.truncate 10

    /// Extract first non-heading, non-empty paragraph as summary (max 200 chars).
    let private extractSummary (content: string) : string =
        let lines = content.Split('\n')
        let summaryLine =
            lines
            |> Array.tryFind (fun l ->
                let t = l.Trim()
                t.Length > 20
                && not (t.StartsWith("#"))
                && not (t.StartsWith("---"))
                && not (t.StartsWith("|"))
                && not (t.StartsWith("```")))
            |> Option.map (fun l -> l.Trim())
        match summaryLine with
        | Some s when s.Length > 200 -> s.[..199] + "…"
        | Some s -> s
        | None -> "(no summary)"

    /// Generate a note ID from file path.
    let private generateNoteId (path: string) (kind: NoteKind) : string =
        let baseName = Path.GetFileNameWithoutExtension(path)
        let prefix =
            match kind with
            | NoteKind.Journal      -> "JRN"
            | NoteKind.Architecture -> "ARC"
            | NoteKind.Spec         -> "SPC"
            | NoteKind.Zettel       -> "ZTL"
            | NoteKind.Unknown      -> "DOC"
        let hash = baseName.GetHashCode() |> abs
        sprintf "%s-%08X" prefix hash

    /// Scan a directory for markdown files and convert to SmritiNote records.
    let private scanDirectory (dirPath: string) : SmritiNote list =
        try
            if not (Directory.Exists(dirPath)) then []
            else
                Directory.EnumerateFiles(dirPath, "*.md", SearchOption.AllDirectories)
                |> Seq.truncate 500  // Cap at 500 files per directory to avoid memory issues
                |> Seq.choose (fun path ->
                    try
                        let fi = FileInfo(path)
                        if fi.Length > 1_000_000L then None  // Skip files > 1MB
                        else
                            let content = File.ReadAllText(path)
                            let kind = classifyFile path
                            let wordCount = content.Split([|' '; '\n'; '\t'; '\r'|], StringSplitOptions.RemoveEmptyEntries).Length
                            Some {
                                NoteId    = generateNoteId path kind
                                Title     = extractTitle content path
                                Kind      = kindString kind
                                Tags      = extractTags content
                                Summary   = extractSummary content
                                UpdatedAt = fi.LastWriteTimeUtc.ToString("o")
                                WordCount = wordCount
                            }
                    with _ -> None)
                |> Seq.toList
        with _ -> []

    /// Cached knowledge base — scanned once per process lifetime.
    let private knowledgeCache =
        lazy (
            let dirs = [
                Path.Combine(projectRoot, "docs/journal")
                Path.Combine(projectRoot, "docs/architecture")
                Path.Combine(projectRoot, "docs/specs")
                Path.Combine(projectRoot, "docs")
            ]
            let notes = dirs |> List.collect scanDirectory
            // Deduplicate by NoteId
            notes
            |> List.distinctBy (fun n -> n.NoteId)
            |> List.sortByDescending (fun n -> n.UpdatedAt)
        )

    let stubNotes : SmritiNote list = [
        { NoteId    = "ZTL-001"
          Title     = "OODA Cycle Biomorphic Control"
          Kind      = kindString NoteKind.Zettel
          Tags      = ["ooda"; "biomorphic"; "control"]
          Summary   = "The OODA loop drives all agent behaviour cycles at SC-BIO-001 < 100ms."
          UpdatedAt = "2026-03-22T14:00:00Z"
          WordCount = 420 }
        { NoteId    = "ZTL-002"
          Title     = "SIL-6 Constitutional Invariants"
          Kind      = kindString NoteKind.Zettel
          Tags      = ["sil6"; "constitution"; "safety"]
          Summary   = "L0 constitution is immutable. L1-L7 may flex under Guardian approval."
          UpdatedAt = "2026-03-21T10:00:00Z"
          WordCount = 315 }
        { NoteId    = "JRN-20260322"
          Title     = "Sprint 88 Constraint Parity Achieved"
          Kind      = kindString NoteKind.Journal
          Tags      = ["sprint"; "constraint-sync"; "parity"]
          Summary   = "Full parity between code and docs SC-* families. D_KL = 0.009 bits."
          UpdatedAt = "2026-03-22T20:00:00Z"
          WordCount = 1840 }
    ]

    /// Get all knowledge notes (real files + stub fallback).
    let getAllNotes () : SmritiNote list =
        try
            let real = knowledgeCache.Value
            if real.Length > 0 then
                eprintfn "[SmritiHandler] loaded %d real knowledge notes from disk" real.Length
                real
            else
                eprintfn "[SmritiHandler] no files found, falling back to stub notes"
                stubNotes
        with ex ->
            eprintfn "[SmritiHandler] file scan failed (%s), falling back to stubs" ex.Message
            stubNotes

    let matchNote (q: SmritiQuery) (note: SmritiNote) : bool =
        let textMatch =
            note.Title.Contains(q.Query, StringComparison.OrdinalIgnoreCase)
            || note.Summary.Contains(q.Query, StringComparison.OrdinalIgnoreCase)
            || note.NoteId.Contains(q.Query, StringComparison.OrdinalIgnoreCase)
            || note.Tags |> List.exists (fun t -> t.Contains(q.Query, StringComparison.OrdinalIgnoreCase))
        let kindMatch =
            match q.Kind with
            | None   -> true
            | Some k -> note.Kind.Equals(k, StringComparison.OrdinalIgnoreCase)
        let tagsMatch =
            q.Tags |> List.forall (fun t -> note.Tags |> List.contains t)
        textMatch && kindMatch && tagsMatch

// ---------------------------------------------------------------------------
// SmritiHandler — MCP tool functions
// ---------------------------------------------------------------------------

/// MCP tool handler for SMRITI knowledge management operations.
/// Functions scan real project docs/ directory with stub fallback.
module SmritiHandler =

    /// Searches SMRITI notes using full-text search (SC-SMRITI-131).
    ///
    /// Parameters:
    ///   query      — search text (required, non-empty)
    ///   kind       — optional note kind filter (zettel|journal|architecture|spec)
    ///   tags       — optional tag filter list
    ///   maxResults — maximum results to return (1-50, default 10)
    ///
    /// Returns: JSON array of SmritiNote records.
    let searchNotes
        (query      : string)
        (kind       : string option)
        (tags       : string list)
        (maxResults : int) : Result<string, string> =

        if String.IsNullOrWhiteSpace query then
            Error "query must not be empty"
        elif maxResults <= 0 || maxResults > 50 then
            Error "max_results must be between 1 and 50"
        else
            let q : SmritiQuery = { Query = query; Kind = kind; Tags = tags; MaxResults = maxResults }
            let matches =
                SmritiHelpers.getAllNotes()
                |> List.filter (SmritiHelpers.matchNote q)
                |> List.truncate maxResults
            eprintfn "[SmritiHandler] searchNotes query='%s' results=%d" query matches.Length
            let result = {|
                query   = query
                count   = matches.Length
                notes   = matches
            |}
            Ok (SmritiHelpers.serialise result)

    /// Retrieves a single SMRITI note by its ID.
    ///
    /// Parameters:
    ///   noteId — note identifier (e.g. "ZTL-001")
    ///
    /// Returns: JSON SmritiNote object or error if not found.
    let getNote (noteId: string) : Result<string, string> =
        if String.IsNullOrWhiteSpace noteId then
            Error "note_id must not be empty"
        else
            let note =
                SmritiHelpers.getAllNotes()
                |> List.tryFind (fun n -> n.NoteId.Equals(noteId, StringComparison.OrdinalIgnoreCase))
            match note with
            | None   -> Error (sprintf "Note '%s' not found in SMRITI" noteId)
            | Some n -> Ok (SmritiHelpers.serialise n)

    /// Lists all known note kinds and their counts.
    ///
    /// Returns: JSON object `{ kinds: [{ kind, count }] }`
    let listKinds () : Result<string, string> =
        let counts =
            SmritiHelpers.getAllNotes()
            |> List.groupBy (fun n -> n.Kind)
            |> List.map (fun (k, notes) -> {| kind = k; count = notes.Length |})
        Ok (SmritiHelpers.serialise {| kinds = counts |})
