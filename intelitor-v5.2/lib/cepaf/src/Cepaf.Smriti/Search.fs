namespace Cepaf.Smriti

open System
open System.Collections.Generic
open Cepaf.Smriti.Domain

// Run 3: Search & Indexing - Unified Search Module
// Handles Full-Text Search (Catalog) + Semantic Search (Vectors)

module Search =

    type SearchResult = {
        EntityRef: string
        Score: float
        Highlight: string
        Type: string // "entity", "docs", "tool"
    }

    // Abstract Search Backend (Mocked for SIL-6 F# prototype)
    type ISearchBackend =
        abstract member Index: CatalogEntity -> unit
        abstract member Query: string -> SearchResult list

    // Simple In-Memory implementation to satisfy compilation
    // Real implementation would wrap SQLite-FTS5 and SQLite-VSS
    type InMemoryBackend() =
        // Use ResizeArray (List<T>) for mutable list
        let index = new ResizeArray<CatalogEntity>()

        interface ISearchBackend with
            member this.Index(e) = index.Add(e)
            
            member this.Query(q) =
                index
                |> Seq.filter (fun e -> e.Metadata.Name.Contains(q) || (defaultArg e.Metadata.Description "").Contains(q))
                |> Seq.map (fun e -> {
                    EntityRef = EntityHelper.getRef e
                    Score = 1.0
                    Highlight = e.Metadata.Name
                    Type = "entity"
                })
                |> Seq.toList

    let indexEntity (backend: ISearchBackend) (entity: CatalogEntity) =
        backend.Index(entity)
        // Future: Extract text for vectors here

    let query (backend: ISearchBackend) (term: string) =
        backend.Query(term)