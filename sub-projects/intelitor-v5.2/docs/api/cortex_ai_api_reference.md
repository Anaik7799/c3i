# Cortex AI API Reference

> Version: 21.3.1-SIL6 | Date: 2026-03-28 | STAMP: SC-ACE-001, SC-SEM-001, SC-MODEL-001

## Overview

Cortex is Indrajaal's AI subsystem providing inference, guided decoding, and
knowledge graph capabilities. It integrates OpenRouter for model access, SMRITI
for knowledge persistence, and Zenoh for real-time telemetry. All AI operations
are gated by Guardian approval and constitutional safety constraints.

## Architecture

```
Cortex AI Subsystem
  |
  +-- Synapse (Inference Pipeline)
  |     +-- ModelRegistry (OpenRouter provider catalog)
  |     +-- InferenceWorker (async inference with timeout)
  |     +-- ResponseValidator (hallucination detection)
  |
  +-- GDE (Guided Decoding Engine)
  |     +-- ConstraintDecoder (grammar-constrained output)
  |     +-- SchemaValidator (JSON schema enforcement)
  |     +-- TokenThrottler (KL divergence gate)
  |
  +-- Knowledge Graph (SMRITI Integration)
        +-- ConceptLinker (entity extraction + linking)
        +-- EmbeddingStore (vector similarity search)
        +-- GraphTraverser (relationship queries)
```

## 1. Synapse -- Inference Pipeline

Synapse manages the full inference lifecycle from prompt construction through
response validation.

### API

```elixir
# Run inference with model selection
Indrajaal.Cortex.Synapse.infer(prompt, opts \\ [])

# Options:
#   model: atom     -- :claude_opus | :claude_sonnet | :claude_haiku (default :claude_haiku)
#   timeout: integer -- milliseconds (default 30_000)
#   temperature: float -- 0.0-1.0 (default 0.3)
#   max_tokens: integer -- (default 4096)
#   system: string  -- system prompt override
#   stream: boolean -- enable SSE streaming (default false)

# Returns:
{:ok, %{content: string, model: string, tokens: %{input: int, output: int}}}
{:error, :timeout | :rate_limited | :guardian_veto | term}
```

### Model Registry (SC-MODEL-001 to SC-MODEL-020)

| Model ID | Provider | Use Case | Cost Tier |
|----------|----------|----------|-----------|
| `:claude_opus` | OpenRouter | Complex reasoning, architecture | High |
| `:claude_sonnet` | OpenRouter | Balanced tasks, code generation | Medium |
| `:claude_haiku` | OpenRouter | Fast classification, triage | Low |

Model selection follows AOR-API-005: workers use haiku, supervisors use sonnet,
executive decisions use opus.

## 2. GDE -- Guided Decoding Engine

GDE constrains model output to match predefined schemas, preventing hallucination
and enforcing type safety.

### API

```elixir
# Decode with JSON schema constraint
Indrajaal.Cortex.GDE.decode(prompt, schema, opts \\ [])

# schema: map -- JSON Schema definition for output
# Options:
#   model: atom       -- model selection (default :claude_sonnet)
#   max_retries: int  -- retry on schema violation (default 3)
#   kl_threshold: float -- KL divergence gate (default 0.2, SC-IKE-002)

# Returns:
{:ok, decoded_map}    -- parsed, validated output matching schema
{:error, :schema_violation, details}
{:error, :kl_exceeded, divergence_value}
```

### Schema Example

```elixir
schema = %{
  "type" => "object",
  "properties" => %{
    "severity" => %{"type" => "string", "enum" => ["critical", "high", "medium", "low"]},
    "summary" => %{"type" => "string", "maxLength" => 200},
    "recommended_action" => %{"type" => "string"}
  },
  "required" => ["severity", "summary"]
}

{:ok, result} = Indrajaal.Cortex.GDE.decode(
  "Analyze this alarm: sensor_timeout on node-3",
  schema,
  model: :claude_sonnet
)
# => %{"severity" => "high", "summary" => "Sensor timeout on node-3 ...", ...}
```

### KL Divergence Gate (SC-EVO-001)

All GDE outputs are measured for KL divergence from the expected distribution.
If D_KL > 0.2, the output is blocked and retried with a more constrained prompt.
This prevents drift in automated evolution pipelines.

## 3. Knowledge Graph -- SMRITI Integration

The Knowledge Graph provides entity extraction, semantic search, and relationship
traversal over the SMRITI knowledge base.

### API

```elixir
# Semantic search (vector similarity)
Indrajaal.Cortex.KnowledgeGraph.search(query, opts \\ [])
# Options: limit (default 10), threshold (default 0.7), namespace
# Returns: {:ok, [%{id, content, score, metadata}]}

# Entity linking
Indrajaal.Cortex.KnowledgeGraph.link_concepts(text, opts \\ [])
# Returns: {:ok, [%{entity, type, confidence, relations}]}

# Graph traversal
Indrajaal.Cortex.KnowledgeGraph.traverse(entity_id, depth \\ 2)
# Returns: {:ok, %{nodes: [...], edges: [...]}}

# Ingest document into knowledge graph
Indrajaal.Cortex.KnowledgeGraph.ingest(content, metadata)
# Returns: {:ok, %{id, entities_extracted, embeddings_created}}
```

### Storage

- **Entities**: SQLite FTS5 (SC-SMRITI-131) for full-text search
- **Embeddings**: DuckDB append-only (SC-SMRITI-142) for vector similarity
- **Relations**: SQLite with version vectors (SC-SMRITI-113) for causality

### Query Latency Targets

| Operation | Target | Constraint |
|-----------|--------|------------|
| FTS5 search | < 50ms | SC-SMRITI-133 |
| Vector search | < 200ms | SC-SMRITI-132 |
| Graph traversal (depth 2) | < 500ms | SC-SMRITI-133 |
| Document ingestion | < 5s | SC-SMRITI-074 |

## Telemetry

All Cortex operations publish metrics to Zenoh:

| Topic | Payload |
|-------|---------|
| `indrajaal/cortex/inference` | model, latency_ms, tokens, status |
| `indrajaal/cortex/gde` | schema_id, retries, kl_divergence |
| `indrajaal/cortex/knowledge` | operation, latency_ms, result_count |

## Safety Constraints

- SC-ACE-001 to SC-ACE-039: Agent collaboration and task allocation
- SC-SEM-001 to SC-SEM-072: Semantic analysis pipeline integrity
- SC-MODEL-001 to SC-MODEL-020: Model registry and selection rules
- SC-IKE-002: Entropy gating (KL > 0.2 blocked)
- SC-SAFETY-001: Guardian pre-approval for mutations triggered by AI
