namespace Cepaf.Smriti

open System
open System.IO
open Markdig // Requires Nuget: Markdig
open Cepaf.Smriti.Domain

// Run 5: Expansion Hardening - TechDocs Indexer

module TechDocs =

    type DocPage = {
        Path: string
        Title: string
        Content: string
        Keywords: string list
    }

    let private pipeline = MarkdownPipelineBuilder().UseAdvancedExtensions().Build()

    /// Extract keywords from YAML frontmatter (between --- delimiters)
    let private extractFrontmatterKeywords (text: string) : string list =
        let lines = text.Split('\n')
        if lines.Length > 0 && lines.[0].Trim() = "---" then
            let mutable inFrontmatter = true
            let mutable idx = 1
            let keywords = ResizeArray<string>()
            while idx < lines.Length && inFrontmatter do
                let line = lines.[idx].Trim()
                if line = "---" then
                    inFrontmatter <- false
                elif line.StartsWith("tags:") || line.StartsWith("keywords:") then
                    // Inline list: tags: [a, b, c] or tags: a, b, c
                    let value = line.Substring(line.IndexOf(':') + 1).Trim().Trim('[', ']')
                    value.Split(',') |> Array.iter (fun k -> keywords.Add(k.Trim().Trim('"', '\'')))
                elif line.StartsWith("- ") && keywords.Count > 0 then
                    // YAML list continuation
                    keywords.Add(line.Substring(2).Trim().Trim('"', '\''))
                idx <- idx + 1
            keywords |> Seq.toList
        else
            []

    let private parseMarkdown (path: string) : DocPage =
        let text = File.ReadAllText(path)
        let _doc = Markdown.Parse(text, pipeline)

        // Simple extraction of plain text for indexing
        let plainText = Markdown.ToPlainText(text, pipeline)
        let keywords = extractFrontmatterKeywords text

        {
            Path = path
            Title = Path.GetFileNameWithoutExtension(path) |> Option.ofObj |> Option.defaultValue "untitled"
            Content = plainText
            Keywords = keywords
        }

    let indexDocs (repoRoot: string) =
        // Look for mkdocs.yaml to confirm this is a TechDocs site
        let mkdocsPath = Path.Combine(repoRoot, "mkdocs.yaml")
        if File.Exists(mkdocsPath) then
            printfn "[TechDocs] Found mkdocs.yaml in %s" repoRoot
            
            // Scan 'docs/' folder
            let docsDir = Path.Combine(repoRoot, "docs")
            if Directory.Exists(docsDir) then
                let files = Directory.GetFiles(docsDir, "*.md", SearchOption.AllDirectories)
                files 
                |> Seq.map parseMarkdown
                |> Seq.iter (fun page ->
                    printfn "[TechDocs] Indexing: %s (%d chars)" page.Title page.Content.Length
                    // Future: Send 'page.Content' to Vector Embedding API
                )
        else
            printfn "[TechDocs] No mkdocs.yaml found."
