// =============================================================================
// ZettelView.fs - Markdown Renderer for SMRITI Zettel Notes
// =============================================================================
// STAMP: SC-SMRITI-131 (Full-text search uses FTS5),
//        SC-HMI-010 (vibrant chromatic feedback),
//        SC-SMRITI-078 (Markdown export valid CommonMark),
//        SC-SMRITI-083 (Obsidian notes use YAML frontmatter),
//        SC-VDP-001 (visual data plane)
// AOR: AOR-COV-008 (source-first selectors), AOR-CTX-007 (knowledge queries via Smriti)
//
// Renders SMRITI zettel notes as ANSI-coloured terminal output.
// Supports frontmatter display, heading colour, code blocks, link highlighting,
// list rendering, and tag badges for the Prajna TUI cockpit.
//
// Public API surface:
//   ZettelRenderOptions  — render configuration (width, frontmatter, colour, indent)
//   RenderedZettel       — render result (noteId, title, body, wordCount, renderTimeMs)
//   ZettelView.defaultOptions    — default render options (width=80, color=true)
//   ZettelView.renderHeading     — ANSI heading by level (H1=cyan, H2=green, H3=yellow)
//   ZettelView.renderCodeBlock   — syntax-highlighted code block with border
//   ZettelView.renderList        — bullet or numbered list
//   ZettelView.renderLink        — ANSI underlined link
//   ZettelView.renderBold        — ANSI bold text
//   ZettelView.renderItalic      — ANSI italic text
//   ZettelView.renderMarkdown    — render raw markdown with options
//   ZettelView.renderZettel      — full zettel render with frontmatter + metadata
//   ZettelView.parse             — parse raw markdown into ZettelDocument
//   ZettelView.render            — render a ZettelDocument to string
//
// Pure module — no I/O, no mutable state.
// Version: 21.3.2 | 2026-03-30
// =============================================================================

namespace Cepaf.Cockpit

open System
open System.Text.RegularExpressions

// ---------------------------------------------------------------------------
// ANSI palette (subset of ConsoleChannel.AnsiColors — SC-CONSOL-003)
// ---------------------------------------------------------------------------

module private Ansi =
    let reset     = "\x1b[0m"
    let bold      = "\x1b[1m"
    let dim       = "\x1b[2m"
    let italic    = "\x1b[3m"
    let underline = "\x1b[4m"
    let cyan      = "\x1b[36m"
    let yellow    = "\x1b[33m"
    let green     = "\x1b[32m"
    let blue      = "\x1b[34m"
    let magenta   = "\x1b[35m"
    let white     = "\x1b[97m"
    let grey      = "\x1b[90m"

    let paint (colour: string) (text: string) : string =
        sprintf "%s%s%s" colour text reset

    let boldPaint (colour: string) (text: string) : string =
        sprintf "%s%s%s%s" bold colour text reset

// ---------------------------------------------------------------------------
// Public option and result types (required by task spec)
// ---------------------------------------------------------------------------

/// Configuration for the ZettelView markdown renderer.
type ZettelRenderOptions = {
    /// Maximum rendered line width in characters.
    MaxWidth       : int
    /// Whether to display YAML frontmatter at the top of the output.
    ShowFrontmatter: bool
    /// Whether to emit ANSI colour escape sequences.
    ColorEnabled   : bool
    /// Number of additional spaces to prepend to every line.
    IndentLevel    : int
}

/// The result of rendering a single zettel note.
type RenderedZettel = {
    NoteId      : string
    Title       : string
    RenderedBody: string
    WordCount   : int
    RenderTimeMs: int
}

// ---------------------------------------------------------------------------
// Domain types (internal document model)
// ---------------------------------------------------------------------------

/// Parsed YAML frontmatter from a zettel note.
type ZettelFrontmatter = {
    NoteId    : string
    Title     : string
    Kind      : string
    Tags      : string list
    UpdatedAt : string
}

/// A zettel note with separated frontmatter and body.
type ZettelDocument = {
    Frontmatter : ZettelFrontmatter option
    Body        : string
    WordCount   : int
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

module private ZettelHelpers =

    /// Apply inline markdown spans to a plain text fragment.
    /// Handles: **bold**, *italic*, `code`, [text](url)
    let applyInlineMarkdown (text: string) (colorEnabled: bool) : string =
        if not colorEnabled then
            // Strip markdown syntax, leave plain text
            let t = Regex.Replace(text, @"\*\*(.+?)\*\*", "$1")
            let t = Regex.Replace(t,    @"\*(.+?)\*",     "$1")
            let t = Regex.Replace(t,    @"`(.+?)`",       "$1")
            let t = Regex.Replace(t,    @"\[(.+?)\]\(.+?\)", "$1")
            t
        else
            // Bold: **text**
            let t = Regex.Replace(text, @"\*\*(.+?)\*\*",
                        fun (m: Match) -> sprintf "%s%s%s" Ansi.bold m.Groups.[1].Value Ansi.reset)
            // Italic: *text* (not preceded by another *)
            let t = Regex.Replace(t, @"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)",
                        fun (m: Match) -> sprintf "%s%s%s" Ansi.italic m.Groups.[1].Value Ansi.reset)
            // Inline code: `code`
            let t = Regex.Replace(t, @"`(.+?)`",
                        fun (m: Match) -> sprintf "%s%s%s" Ansi.dim m.Groups.[1].Value Ansi.reset)
            // Links: [text](url)
            let t = Regex.Replace(t, @"\[(.+?)\]\((.+?)\)",
                        fun (m: Match) ->
                            sprintf "%s%s%s (%s)" Ansi.underline m.Groups.[1].Value Ansi.reset m.Groups.[2].Value)
            t

    /// Parse a minimal YAML frontmatter block (lines between --- delimiters).
    let parseFrontmatter (lines: string array) : ZettelFrontmatter option * int =
        if lines.Length < 2 || lines.[0].Trim() <> "---" then
            None, 0
        else
            // Find the closing "---" (index > 0 to skip the opening delimiter)
            let endIdx =
                lines
                |> Array.tryFindIndex (fun l -> l.Trim() = "---")
                |> Option.bind (fun i ->
                    lines.[i+1..]
                    |> Array.tryFindIndex (fun l -> l.Trim() = "---")
                    |> Option.map (fun j -> i + 1 + j))
            match endIdx with
            | None     -> None, 0
            | Some idx ->
                let fmLines = lines.[1..idx-1]
                let get (key: string) =
                    fmLines
                    |> Array.tryFind (fun l -> l.StartsWith(key + ":", StringComparison.OrdinalIgnoreCase))
                    |> Option.map (fun l -> l.Substring(l.IndexOf(':') + 1).Trim())
                    |> Option.defaultValue ""
                let tags =
                    get "tags"
                    |> fun s -> s.Trim('[', ']').Split(',')
                    |> Array.map (fun t -> t.Trim().Trim('"', '\''))
                    |> Array.filter (fun t -> t.Length > 0)
                    |> Array.toList
                let fm : ZettelFrontmatter = {
                    NoteId    = get "note_id"
                    Title     = get "title"
                    Kind      = get "kind"
                    Tags      = tags
                    UpdatedAt = get "updated_at"
                }
                Some fm, idx + 1

    /// Render a single markdown line as ANSI-coloured terminal text.
    let renderLine (line: string) (opts: ZettelRenderOptions) : string =
        let indent = String.replicate opts.IndentLevel " "
        let c = opts.ColorEnabled
        let rendered =
            if line.StartsWith("# ", StringComparison.Ordinal) then
                let content = line.Substring(2)
                if c then Ansi.boldPaint Ansi.cyan content
                else content
            elif line.StartsWith("## ", StringComparison.Ordinal) then
                let content = line.Substring(3)
                if c then Ansi.boldPaint Ansi.green content
                else content
            elif line.StartsWith("### ", StringComparison.Ordinal) then
                let content = line.Substring(4)
                if c then Ansi.boldPaint Ansi.yellow content
                else content
            elif line.StartsWith("#### ", StringComparison.Ordinal) then
                let content = line.Substring(5)
                if c then Ansi.paint Ansi.yellow content
                else content
            elif line.StartsWith("- ", StringComparison.Ordinal) || line.StartsWith("* ", StringComparison.Ordinal) then
                let content = applyInlineMarkdown (line.Substring(2)) c
                if c then sprintf "  %s %s" (Ansi.paint Ansi.green "•") content
                else sprintf "  • %s" content
            elif line.StartsWith("> ", StringComparison.Ordinal) then
                let content = applyInlineMarkdown (line.Substring(2)) c
                if c then Ansi.paint Ansi.grey (sprintf "│ %s" content)
                else sprintf "│ %s" content
            elif line.StartsWith("```", StringComparison.Ordinal) then
                if c then Ansi.paint Ansi.dim line
                else line
            elif line.StartsWith("---", StringComparison.Ordinal) then
                if c then Ansi.paint Ansi.grey (String.replicate (min opts.MaxWidth 60) "─")
                else String.replicate (min opts.MaxWidth 60) "─"
            else
                applyInlineMarkdown line c
        sprintf "%s%s" indent rendered

    let renderFrontmatter (fm: ZettelFrontmatter) (opts: ZettelRenderOptions) : string =
        let indent = String.replicate opts.IndentLevel " "
        let c = opts.ColorEnabled
        let width = min opts.MaxWidth 60
        let tagBadges =
            fm.Tags
            |> List.map (fun t ->
                if c then Ansi.paint Ansi.magenta (sprintf "[%s]" t)
                else sprintf "[%s]" t)
            |> String.concat " "
        let sep = if c then Ansi.paint Ansi.grey (String.replicate width "─")
                  else String.replicate width "─"
        let lines = [
            indent + sep
            if c then
                sprintf "%s%s %s" indent (Ansi.paint Ansi.grey "Note:") (Ansi.boldPaint Ansi.white fm.NoteId)
                sprintf "%s%s %s" indent (Ansi.paint Ansi.grey "Title:") (Ansi.boldPaint Ansi.cyan fm.Title)
                sprintf "%s%s %s" indent (Ansi.paint Ansi.grey "Kind:") (Ansi.paint Ansi.green fm.Kind)
                sprintf "%s%s %s" indent (Ansi.paint Ansi.grey "Tags:") tagBadges
                sprintf "%s%s %s" indent (Ansi.paint Ansi.grey "Updated:") (Ansi.paint Ansi.blue fm.UpdatedAt)
            else
                sprintf "%sNote: %s" indent fm.NoteId
                sprintf "%sTitle: %s" indent fm.Title
                sprintf "%sKind: %s" indent fm.Kind
                sprintf "%sTags: %s" indent tagBadges
                sprintf "%sUpdated: %s" indent fm.UpdatedAt
            indent + sep
        ]
        lines |> String.concat "\n"

// ---------------------------------------------------------------------------
// ZettelView — public render functions
// ---------------------------------------------------------------------------

/// ANSI markdown renderer for SMRITI zettel notes in the Prajna TUI cockpit.
///
/// STAMP Compliance:
///   SC-SMRITI-131 — full-text rendering for FTS5-indexed notes
///   SC-HMI-010    — vibrant chromatic feedback in ANSI terminal
module ZettelView =

    // -----------------------------------------------------------------------
    // Primitive ANSI renderers (spec-required public API)
    // -----------------------------------------------------------------------

    /// Returns the default ZettelRenderOptions (MaxWidth=80, ShowFrontmatter=true,
    /// ColorEnabled=true, IndentLevel=0).
    let defaultOptions () : ZettelRenderOptions =
        { MaxWidth        = 80
          ShowFrontmatter = true
          ColorEnabled    = true
          IndentLevel     = 0 }

    /// Renders a heading at the given level (1-3) with ANSI colour.
    /// H1 = cyan bold, H2 = green bold, H3 = yellow bold.
    ///
    /// Parameters:
    ///   level — heading level 1..3 (clamped to 3)
    ///   text  — heading content
    let renderHeading (level: int) (text: string) : string =
        match level with
        | 1 -> Ansi.boldPaint Ansi.cyan text
        | 2 -> Ansi.boldPaint Ansi.green text
        | _ -> Ansi.boldPaint Ansi.yellow text

    /// Renders a fenced code block with a dim border and language label.
    ///
    /// Parameters:
    ///   lang — language identifier (e.g. "fsharp", "elixir") or empty string
    ///   code — code content
    let renderCodeBlock (lang: string) (code: string) : string =
        let label = if lang.Length > 0 then sprintf " %s" lang else ""
        let border = Ansi.paint Ansi.dim (String.replicate 40 "─")
        let header = Ansi.paint Ansi.dim (sprintf "┌%s[%s]" (String.replicate (max 0 (38 - label.Length)) "─") label)
        let footer = Ansi.paint Ansi.dim "└" + border
        let body   = Ansi.paint Ansi.dim code
        sprintf "%s\n%s\n%s" header body footer

    /// Renders a list of items as bullet or numbered ANSI-formatted lines.
    ///
    /// Parameters:
    ///   items   — list items
    ///   ordered — true for numbered list, false for bullet list
    let renderList (items: string list) (ordered: bool) : string =
        items
        |> List.mapi (fun i item ->
            let bullet =
                if ordered then Ansi.paint Ansi.cyan (sprintf "%d." (i + 1))
                else Ansi.paint Ansi.green "•"
            sprintf "  %s %s" bullet item)
        |> String.concat "\n"

    /// Renders a hyperlink as underlined text with the URL in parentheses.
    ///
    /// Parameters:
    ///   text — link display text
    ///   url  — link target URL
    let renderLink (text: string) (url: string) : string =
        sprintf "%s%s%s (%s)" Ansi.underline text Ansi.reset url

    /// Renders text in ANSI bold.
    let renderBold (text: string) : string =
        sprintf "%s%s%s" Ansi.bold text Ansi.reset

    /// Renders text in ANSI italic.
    let renderItalic (text: string) : string =
        sprintf "%s%s%s" Ansi.italic text Ansi.reset

    // -----------------------------------------------------------------------
    // Document-level rendering
    // -----------------------------------------------------------------------

    /// Renders a raw markdown string to an ANSI-formatted terminal string.
    ///
    /// Parameters:
    ///   markdown — raw markdown content
    ///   options  — ZettelRenderOptions controlling width, colour, indentation
    ///
    /// Returns: ANSI-formatted string.
    let renderMarkdown (markdown: string) (options: ZettelRenderOptions) : string =
        if String.IsNullOrWhiteSpace markdown then ""
        else
            markdown.Split('\n')
            |> Array.map (fun line -> ZettelHelpers.renderLine line options)
            |> String.concat "\n"

    /// Renders a full zettel note (frontmatter + body) into a RenderedZettel.
    ///
    /// Parameters:
    ///   noteId  — unique note identifier
    ///   title   — note title
    ///   body    — raw markdown body
    ///   tags    — list of tag strings
    ///   options — ZettelRenderOptions
    ///
    /// Returns: RenderedZettel with ANSI-formatted body and metadata.
    let renderZettel
            (noteId : string)
            (title  : string)
            (body   : string)
            (tags   : string list)
            (options: ZettelRenderOptions)
            : RenderedZettel =
        let sw = Diagnostics.Stopwatch.StartNew()
        let indent = String.replicate options.IndentLevel " "
        let wordCount =
            body.Split([|' '; '\n'; '\t'|], StringSplitOptions.RemoveEmptyEntries).Length

        // Build frontmatter section if requested
        let fmSection =
            if options.ShowFrontmatter then
                let fm : ZettelFrontmatter = {
                    NoteId    = noteId
                    Title     = title
                    Kind      = "note"
                    Tags      = tags
                    UpdatedAt = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
                }
                ZettelHelpers.renderFrontmatter fm options
            else ""

        // Render body
        let renderedBody = renderMarkdown body options

        // Footer: word count
        let footer =
            if options.ColorEnabled then
                Ansi.paint Ansi.grey (sprintf "\n%s%d words" indent wordCount)
            else sprintf "\n%s%d words" indent wordCount

        let parts =
            [ if fmSection.Length > 0 then yield fmSection
              yield renderedBody
              yield footer ]

        sw.Stop()
        { NoteId       = noteId
          Title        = title
          RenderedBody = parts |> String.concat "\n"
          WordCount    = wordCount
          RenderTimeMs = int sw.ElapsedMilliseconds }

    // -----------------------------------------------------------------------
    // Low-level document API (legacy surface, kept for compatibility)
    // -----------------------------------------------------------------------

    /// Parses a raw markdown string (optionally with YAML frontmatter) into a
    /// ZettelDocument with separated frontmatter and body.
    ///
    /// Parameters:
    ///   markdown — raw zettel content
    ///
    /// Returns: Ok(ZettelDocument) or Error(message).
    let parse (markdown: string) : Result<ZettelDocument, string> =
        if String.IsNullOrWhiteSpace markdown then
            Error "markdown content must not be empty"
        else
            let lines = markdown.Split('\n')
            let fm, bodyStart = ZettelHelpers.parseFrontmatter lines
            let bodyLines = lines.[bodyStart..]
            let body = bodyLines |> String.concat "\n"
            let wordCount =
                body.Split([|' '; '\n'; '\t'|], StringSplitOptions.RemoveEmptyEntries).Length
            Ok { Frontmatter = fm; Body = body; WordCount = wordCount }

    /// Renders a ZettelDocument as ANSI-coloured terminal output using default options.
    ///
    /// Parameters:
    ///   doc — parsed ZettelDocument
    ///
    /// Returns: Ok(ANSI string) or Error(message).
    let render (doc: ZettelDocument) : Result<string, string> =
        let opts = defaultOptions()
        let fmSection =
            doc.Frontmatter
            |> Option.map (fun fm -> ZettelHelpers.renderFrontmatter fm opts)
            |> Option.defaultValue ""
        let bodyLines =
            doc.Body.Split('\n')
            |> Array.map (fun line -> ZettelHelpers.renderLine line opts)
        let body = bodyLines |> String.concat "\n"
        let footer =
            Ansi.paint Ansi.grey (sprintf "\n%d words" doc.WordCount)
        let parts =
            [ if fmSection.Length > 0 then yield fmSection
              yield body
              yield footer ]
        Ok (parts |> String.concat "\n")
