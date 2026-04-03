// =============================================================================
// ZettelView.fs - Markdown Renderer for SMRITI Zettelkasten Client
// =============================================================================
// STAMP: SC-SMRITI-131 (FTS5 search), SC-SMRITI-132 (semantic search),
//        SC-HMI-010 (Color Rich), SC-COCKPIT-002 (F# Bolero)
// AOR: AOR-CTX-007 (knowledge queries via Smriti)
//
// Renders SMRITI zettel notes as ANSI-coloured terminal output.
// Parses a minimal subset of Markdown (headings, bold, code, links,
// lists, blockquotes) into styled TUI text.
//
// All functions are PURE — no I/O, no side effects.
// Version: 21.3.2 | 2026-03-30
// =============================================================================

namespace Cepaf.Cockpit

open System
open System.Text.RegularExpressions

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// A rendered zettel note ready for TUI display.
type ZettelDisplay = {
    /// Note identifier (e.g. "ZTL-001", "JRN-20260322")
    NoteId      : string
    /// Note title
    Title       : string
    /// Classification kind (zettel, journal, architecture, spec)
    Kind        : string
    /// Tags associated with the note
    Tags        : string list
    /// Rendered ANSI-coloured body text
    RenderedBody : string
    /// Word count of the original content
    WordCount   : int
    /// Last modification timestamp
    UpdatedAt   : string
}

// ---------------------------------------------------------------------------
// ANSI colour helpers
// ---------------------------------------------------------------------------

module private ZAnsi =
    let reset    = "\u001b[0m"
    let bold     = "\u001b[1m"
    let dim      = "\u001b[2m"
    let italic   = "\u001b[3m"
    let underline = "\u001b[4m"
    let green    = "\u001b[32m"
    let yellow   = "\u001b[33m"
    let cyan     = "\u001b[36m"
    let magenta  = "\u001b[35m"
    let white    = "\u001b[97m"
    let bGreen   = "\u001b[92m"
    let bCyan    = "\u001b[96m"
    let bYellow  = "\u001b[93m"
    let bMagenta = "\u001b[95m"
    let bgGrey   = "\u001b[48;5;236m"

// ---------------------------------------------------------------------------
// ZettelView — pure markdown rendering for TUI
// ---------------------------------------------------------------------------

/// Renders SMRITI zettel notes as ANSI-coloured terminal text.
/// Supports: headings (#-####), **bold**, `code`, [links], lists (- *),
/// blockquotes (>), and horizontal rules (---).
[<RequireQualifiedAccess>]
module ZettelView =

    // -----------------------------------------------------------------------
    // Internal markdown line rendering
    // -----------------------------------------------------------------------

    /// Apply inline formatting to a single line of text.
    let private renderInline (line: string) : string =
        line
        // Bold: **text** or __text__
        |> fun s -> Regex.Replace(s, @"\*\*(.+?)\*\*", sprintf "%s%s$1%s" ZAnsi.bold ZAnsi.white ZAnsi.reset)
        |> fun s -> Regex.Replace(s, @"__(.+?)__", sprintf "%s%s$1%s" ZAnsi.bold ZAnsi.white ZAnsi.reset)
        // Inline code: `code`
        |> fun s -> Regex.Replace(s, @"`([^`]+)`", sprintf "%s%s$1%s" ZAnsi.bgGrey ZAnsi.bCyan ZAnsi.reset)
        // Links: [text](url)
        |> fun s -> Regex.Replace(s, @"\[([^\]]+)\]\([^\)]+\)", sprintf "%s%s$1%s" ZAnsi.underline ZAnsi.bCyan ZAnsi.reset)
        // SC-* constraint references highlighted
        |> fun s -> Regex.Replace(s, @"(SC-[A-Z]+-\d+)", sprintf "%s$1%s" ZAnsi.bYellow ZAnsi.reset)

    /// Render a single markdown line with block-level formatting.
    let private renderLine (line: string) : string =
        let trimmed = line.TrimStart()
        if trimmed.StartsWith("#### ") then
            sprintf "    %s%s%s%s" ZAnsi.bold ZAnsi.cyan (trimmed.Substring(5)) ZAnsi.reset
        elif trimmed.StartsWith("### ") then
            sprintf "   %s%s%s%s" ZAnsi.bold ZAnsi.bCyan (trimmed.Substring(4)) ZAnsi.reset
        elif trimmed.StartsWith("## ") then
            sprintf "  %s%s%s%s" ZAnsi.bold ZAnsi.bMagenta (trimmed.Substring(3)) ZAnsi.reset
        elif trimmed.StartsWith("# ") then
            sprintf "%s%s%s%s" ZAnsi.bold ZAnsi.bMagenta (trimmed.Substring(2)) ZAnsi.reset
        elif trimmed.StartsWith("---") || trimmed.StartsWith("***") || trimmed.StartsWith("___") then
            sprintf "%s%s%s" ZAnsi.dim (String.replicate 50 "─") ZAnsi.reset
        elif trimmed.StartsWith("> ") then
            sprintf "  %s│%s %s" ZAnsi.green ZAnsi.reset (renderInline (trimmed.Substring(2)))
        elif trimmed.StartsWith("- ") || trimmed.StartsWith("* ") then
            sprintf "  %s•%s %s" ZAnsi.bGreen ZAnsi.reset (renderInline (trimmed.Substring(2)))
        elif trimmed.StartsWith("```") then
            sprintf "%s%s%s" ZAnsi.dim "───── code ─────" ZAnsi.reset
        elif String.IsNullOrWhiteSpace trimmed then
            ""
        else
            sprintf "  %s" (renderInline trimmed)

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// Renders raw markdown content as ANSI-coloured text for the TUI.
    let renderMarkdown (content: string) : string =
        content.Split('\n')
        |> Array.map renderLine
        |> String.concat "\n"

    /// Renders a full zettel note with header, metadata, and body.
    let renderZettel (display: ZettelDisplay) : string =
        let sep = sprintf "%s%s%s" ZAnsi.cyan (String.replicate 60 "─") ZAnsi.reset

        // Kind badge
        let kindColour =
            match display.Kind.ToLowerInvariant() with
            | "zettel"       -> ZAnsi.bGreen
            | "journal"      -> ZAnsi.bCyan
            | "architecture" -> ZAnsi.bMagenta
            | "spec"         -> ZAnsi.bYellow
            | _              -> ZAnsi.dim
        let kindBadge = sprintf "%s[%s]%s" kindColour (display.Kind.ToUpperInvariant()) ZAnsi.reset

        // Tags
        let tagsLine =
            if display.Tags.IsEmpty then ""
            else
                let rendered =
                    display.Tags
                    |> List.map (fun t -> sprintf "%s#%s%s" ZAnsi.bYellow t ZAnsi.reset)
                    |> String.concat " "
                sprintf "  Tags: %s" rendered

        // Metadata line
        let metaLine =
            sprintf "  %s%s%s  %s  %s%d words%s  %sUpdated: %s%s"
                ZAnsi.dim display.NoteId ZAnsi.reset
                kindBadge
                ZAnsi.dim display.WordCount ZAnsi.reset
                ZAnsi.dim display.UpdatedAt ZAnsi.reset

        [ ""
          sep
          sprintf "  %s%s%s%s" ZAnsi.bold ZAnsi.white display.Title ZAnsi.reset
          sep
          metaLine
          tagsLine
          sep
          display.RenderedBody
          sep
          "" ]
        |> List.filter (fun s -> not (String.IsNullOrEmpty s) || s = "")
        |> String.concat "\n"

    /// Renders a list of zettel notes as a compact index.
    let renderIndex (notes: ZettelDisplay list) : string =
        let sep = sprintf "%s%s%s" ZAnsi.cyan (String.replicate 60 "─") ZAnsi.reset
        let hdr = sprintf "  %s%s SMRITI KNOWLEDGE INDEX %s(%d notes)%s"
                      ZAnsi.bold ZAnsi.bMagenta ZAnsi.dim (List.length notes) ZAnsi.reset

        let noteLines =
            notes
            |> List.mapi (fun i n ->
                let kindCol =
                    match n.Kind.ToLowerInvariant() with
                    | "zettel"       -> ZAnsi.bGreen
                    | "journal"      -> ZAnsi.bCyan
                    | "architecture" -> ZAnsi.bMagenta
                    | "spec"         -> ZAnsi.bYellow
                    | _              -> ZAnsi.dim
                sprintf "  %s%2d.%s %s%-6s%s %s%-40s%s %s%d w%s"
                    ZAnsi.dim (i + 1) ZAnsi.reset
                    kindCol n.Kind ZAnsi.reset
                    ZAnsi.white n.Title ZAnsi.reset
                    ZAnsi.dim n.WordCount ZAnsi.reset)

        [ ""; sep; hdr; sep ]
        @ noteLines
        @ [ sep; "" ]
        |> String.concat "\n"

    /// Renders a search result highlight — shows matching context.
    let renderSearchResult (noteId: string) (title: string) (matchContext: string) (score: float) : string =
        let scoreCol =
            if score >= 0.8 then ZAnsi.bGreen
            elif score >= 0.5 then ZAnsi.bYellow
            else ZAnsi.dim
        sprintf "  %s%s%s %s%s%s %sscore:%.2f%s\n    %s"
            ZAnsi.dim noteId ZAnsi.reset
            ZAnsi.white title ZAnsi.reset
            scoreCol score ZAnsi.reset
            (renderInline matchContext)
