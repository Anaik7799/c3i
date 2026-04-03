namespace Cepaf.Cockpit.Cortex

open System
open Cepaf.Cockpit.AI

// =============================================================================
// MemoryAgent.fs - Long-Term Memory Manager
// =============================================================================
// Phase: 5 (Cognitive Fabric)
// Criticality: P1
// =============================================================================

module Memory =

    type MemoryMsg =
        | Remember of string * string list
        | Recall of RecallRequest * AsyncReplyChannel<MemoryItem list>
        | GetStats of AsyncReplyChannel<int64>

    type MemoryAgent() =
        
        // MVP: In-Memory Store (Vector Mock)
        // In Phase 7, replace this with SQLite VSS or Qdrant
        let store = ResizeArray<MemoryItem>()

        // Mock Embedding: Simple hash-based vector for demonstration
        let generateEmbedding (text: string) =
            let hash = text.GetHashCode()
            [| float hash; float (hash * 2); float (hash / 2) |]

        // Mock Similarity: Text containment + Tag matching
        let calculateRelevance (query: string) (item: MemoryItem) =
            let contentMatch = if item.Content.Contains(query, StringComparison.OrdinalIgnoreCase) then 0.8 else 0.0
            let tagMatch = if item.Tags |> List.exists (fun t -> query.Contains(t, StringComparison.OrdinalIgnoreCase)) then 0.2 else 0.0
            contentMatch + tagMatch

        let agent = MailboxProcessor.Start(fun inbox ->
            let rec loop () = async {
                let! msg = inbox.Receive()
                match msg with
                | Remember (content, tags) ->
                    let item = {
                        Id = Guid.NewGuid()
                        Content = content
                        Embedding = generateEmbedding content
                        Tags = tags
                        Created = DateTime.UtcNow
                        AccessCount = 0
                        Relevance = 0.0
                    }
                    store.Add(item)
                    return! loop ()

                | Recall (req, reply) ->
                    let results = 
                        store
                        |> Seq.map (fun item -> { item with Relevance = calculateRelevance req.Query item })
                        |> Seq.filter (fun item -> item.Relevance >= req.MinRelevance)
                        |> Seq.sortByDescending (fun item -> item.Relevance)
                        |> Seq.truncate req.Limit
                        |> Seq.toList
                    
                    reply.Reply(results)
                    return! loop ()

                | GetStats reply ->
                    reply.Reply(int64 store.Count)
                    return! loop ()
            }
            loop ()
        )

        member this.Remember(content, tags) = agent.Post(Remember(content, tags))
        member this.Recall(query, ?limit, ?threshold) = 
            let req = {
                Query = query
                Limit = defaultArg limit 5
                MinRelevance = defaultArg threshold 0.1
            }
            agent.PostAndAsyncReply(fun r -> Recall(req, r))
            
        member this.Count() = agent.PostAndAsyncReply(GetStats)
