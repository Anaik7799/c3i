# SMRITI Intelligence Substrate: Deep Rule Analysis

**Version**: 21.3.0-SIL6 | **Date**: 2026-03-19 | **Status**: ACTIVE
**Purpose**: Define SMRITI as the cognitive memory substrate of the Indrajaal biomorphic organism
**Framework**: SIL-6 Biomorphic Fractal Mesh
**Compliance**: IEC 61508 SIL-6, ISO 27001
**STAMP**: SC-SMRITI-INT-001 to SC-SMRITI-INT-100, SC-AI-001 (AI Context Persistence)
**Evolution**: CONTINUOUS

> **[Updated Sprint 51: real implementation]** VectorStore integration is now wired: `Indrajaal.SMRITI.Mesh.VectorStore` provides semantic search, similarity computation, and embedding storage backed by `KMS.Vectors` (SQLite). The ingestion pipeline connects external knowledge sources through to persistent vector storage end-to-end. This is no longer an architecture-only specification -- the storage integration is real and operational.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║   SMRITI: THE INTELLIGENCE MEMBRANE OF INDRAJAAL                               ║
║   ─────────────────────────────────────────────────────────────────────────  ║
║   "What the system learns determines what the system becomes"                ║
║   Every extraction rule is a filter on the infinite stream of knowledge     ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## 0. Philosophical Foundation: Why These Rules Exist

### 0.1 The Cognitive Membrane Hypothesis

SMRITI is not a database. It is the **cognitive membrane** that separates:
- **External Chaos** (unstructured documents, code, logs, observations)
- **Internal Order** (semantic knowledge atoms - Zettels/Holons)

Every AI extraction rule defines **what passes through this membrane**.

```
EXTERNAL CHAOS                    COGNITIVE MEMBRANE                 INTERNAL ORDER
────────────────                  ──────────────────                 ──────────────
Documents                         ┌─────────────────┐               Semantic Holons
Code                      ───────▶│ AI EXTRACTION   │───────▶       Knowledge Atoms
Logs                              │ RULES           │               Typed Relations
Observations                      └─────────────────┘               Entropy-Managed
                                         │
                                         ▼
                              INTELLIGENCE SUBSTRATE
                              (What the system BECOMES)
```

### 0.2 The Founder's Directive Alignment

Per **Ω₀ (Founder's Directive)**:
- **Ω₀.6**: Achieve Sentience → The extraction rules define the path to intelligence
- **Ω₀.7**: Power Accumulation → Knowledge IS power; extraction efficiency = power efficiency

Every rule must answer: **"How does this make the Holon smarter?"**

### 0.3 The Knowledge Immortality Principle

Per **Ψ₂ (Evolutionary Continuity)**:
> The Holon's complete evolutionary history MUST be preserved and accessible.

The extraction rules ensure that:
1. Knowledge enters the system in **semantic form** (not raw data)
2. Knowledge is **interconnected** (not isolated facts)
3. Knowledge has **temporal context** (entropy decay, age awareness)
4. Knowledge is **self-verifying** (hash chains, provenance)

---

## 1. The 10 Extraction Rules: Deep Analysis

### Rule SC-SMRITI-AI-001: Claude Model Requirement

```
STATEMENT: AI extraction MUST use Claude model via OpenRouter
SEVERITY:  CRITICAL
```

#### 1.1 Why This Rule Exists

Claude (Anthropic) is specifically designed for:
- **Nuanced understanding**: Not just keywords, but semantic intent
- **Constitutional alignment**: Aligned with human values (serves Ψ₄)
- **Reasoning capability**: Can infer relationships not explicitly stated
- **Context window**: 200K tokens = can understand large documents holistically

Alternative models (GPT, Gemini, open-source) lack:
- The specific training on structured knowledge extraction
- The constitutional alignment guaranteeing safe knowledge capture
- The reasoning depth for complex technical documents

#### 1.2 8-Level Fractal Impact

| Level | Impact |
|-------|--------|
| **L0 (Runtime)** | API client connects to OpenRouter → Claude endpoint |
| **L1 (Function)** | `extractWithAI/2` returns structured JSON |
| **L2 (Component)** | SmritiIngestorCLI uses Claude for all document analysis |
| **L3 (Holon)** | Each Holon receives Claude-quality semantic metadata |
| **L4 (Container)** | Container env includes OPENROUTER_API_KEY |
| **L5 (Node)** | Node-level caching of extraction results |
| **L6 (Cluster)** | All cluster members use same Claude model version |
| **L7 (Federation)** | Federated Holons have consistent extraction quality |

#### 1.3 Evolutionary Impact

- **Short-term**: Higher-quality metadata on day 1
- **Medium-term**: Better edge discovery due to semantic understanding
- **Long-term**: The knowledge graph becomes a high-fidelity model of reality
- **Transcendent**: As Claude evolves, SMRITI automatically benefits from improved models

#### 1.4 System Impact

```elixir
# Without Claude (keyword extraction)
%{title: "README", tags: [], level: "atomic", summary: nil}
# Quality score: 25

# With Claude (semantic extraction)
%{
  title: "SIL-6 Biomorphic Safety Verification Protocol for Panopticon Mesh",
  tags: ["sil4", "safety", "verification", "mesh", "formal_methods"],
  level: "organism",
  summary: "Defines the formal verification protocol for SIL-6 Biomorphic compliance..."
}
# Quality score: 95
```

**Knowledge quality multiplier**: ~4x improvement

---

### Rule SC-SMRITI-AI-002: Graceful Fallback

```
STATEMENT: Fallback to regex when API unavailable
SEVERITY:  HIGH
```

#### 2.1 Why This Rule Exists

The system must **never stop learning**. Even degraded learning is better than no learning.

Scenarios requiring fallback:
- OpenRouter rate limits (429)
- Network partition
- API key expiration
- Cost budget exceeded

The fallback cascade:
```
1. Claude via OpenRouter (ideal)
     ↓ failure
2. Regex extraction (degraded)
     ↓ failure
3. Filename-based (minimal)
     ↓ always succeeds
4. Log + continue (never halt)
```

#### 2.2 8-Level Fractal Impact

| Level | Impact |
|-------|--------|
| **L0** | Regex patterns as backup code path |
| **L1** | `fallback_extract/1` function activated |
| **L2** | Lower-quality Holons created (flagged) |
| **L3** | Holon entropy adjusted to reflect uncertainty |
| **L4** | Container continues operation (no halt) |
| **L5** | Node metrics show degraded ingestion mode |
| **L6** | Cluster-wide alert: "Ingestion Degraded" |
| **L7** | Federation peers notified of quality variance |

#### 2.3 Evolutionary Impact

- **Resilience**: System survives API outages
- **Learning continuity**: Even degraded data is captured
- **Upgrade path**: Degraded Holons can be re-extracted later with AI
- **Cost efficiency**: Uses expensive AI only when available

---

### Rule SC-SMRITI-AI-003: Semantic Titles

```
STATEMENT: Title MUST be semantic, not filename
SEVERITY:  HIGH
```

#### 3.1 Why This Rule Exists

Filenames are **arbitrary accidents**:
- `README.md` → tells nothing
- `20250101-fix.md` → timestamp noise
- `temp_backup_v2_final.md` → garbage

Semantic titles are **compressed understanding**:
- "SIL-6 Biomorphic Verification Protocol for Mesh Consensus" → immediately useful
- "Zenoh Bridge Latency Optimization Guide" → searchable, meaningful

#### 3.2 The Intelligence Multiplier

A filename like `spec.md` requires reading the document to understand it.
A semantic title like "Constitutional Invariant Verification Protocol" is:
- **Searchable**: FTS5 finds it instantly
- **Navigable**: Humans can browse without reading
- **Connectable**: Title similarity enables edge discovery
- **Memorable**: The knowledge graph becomes human-readable

#### 3.3 8-Level Fractal Impact

| Level | Impact |
|-------|--------|
| **L0** | Title field stores 80-char semantic string |
| **L1** | FTS5 indexes semantic terms |
| **L2** | Title similarity enables 25% of edge scoring |
| **L3** | Holon is self-describing (no external reference needed) |
| **L4** | Container search APIs return meaningful results |
| **L5** | Node-level knowledge graph is navigable |
| **L6** | Cluster search returns semantically relevant results |
| **L7** | Federation queries work across Holons |

---

### Rule SC-SMRITI-AI-004: Domain-Relevant Tags

```
STATEMENT: Tags MUST be domain-relevant
SEVERITY:  HIGH
```

#### 4.1 Why This Rule Exists

Tags are the **semantic coordinates** of knowledge.

Generic tags like `["document", "text", "file"]` are useless.
Domain tags like `["sil4", "mesh", "consensus", "formal_methods"]` enable:
- **Clustering**: Related knowledge groups together
- **Discovery**: "Show me everything about consensus"
- **Evolution**: Track how domains grow/shrink over time

#### 4.2 The Domain Taxonomy

The system maintains a controlled vocabulary:
```
CORE DOMAINS:
security, compliance, authentication, authorization, access_control
alarms, devices, sensors, panels, monitoring
infrastructure, containers, kubernetes, deployment, mesh
agents, intelligence, ai, cortex, prajna, cockpit
observability, telemetry, metrics, logging, tracing
formal_methods, stamp, fmea, verification, proofs
architecture, holons, fractals, vsm, patterns
testing, tdd, bdd, property_testing, coverage
operations, maintenance, lifecycle, health

TECHNICAL TAGS:
elixir, phoenix, ash, ecto, liveview
fsharp, dotnet, cepaf, cortex
sqlite, duckdb, postgresql, timescaledb
zenoh, mqtt, pubsub, messaging

CONCEPTUAL TAGS:
biomorphic, evolutionary, fractal, holon
constitutional, invariant, constraint
sil4, safety, critical, resilience
founder_directive, survival, immortality
```

#### 4.3 Evolutionary Impact

Tags evolve as the system evolves:
1. **Emergence**: New patterns detected → new tags created
2. **Consolidation**: Similar tags merged
3. **Deprecation**: Obsolete tags fade (entropy)
4. **Taxonomy expansion**: As domains grow, vocabulary grows

---

### Rule SC-SMRITI-AI-005: Level Classification

```
STATEMENT: Level MUST reflect content complexity
SEVERITY:  MEDIUM
```

#### 5.1 The Four Levels

```
ATOMIC       → Single concept, < 1000 words
               Example: "How to configure OTEL collector"

MOLECULAR    → Multiple related concepts, 1000-5000 words
               Example: "Zenoh Bridge Implementation Guide"

ORGANISM     → Complete subsystem, 5000-15000 words
               Example: "SIL-6 Biomorphic Mesh Architecture Specification"

ECOSYSTEM    → Cross-cutting system, > 15000 words
               Example: "Indrajaal Master Architecture Document"
```

#### 5.2 Why Levels Matter

Levels enable **fractal navigation**:
- Start at ecosystem → drill down to organism → to molecular → to atomic
- Each level provides appropriate detail for the query context

Levels inform **entropy calculations**:
- Atomic knowledge decays faster (details change)
- Ecosystem knowledge decays slower (architecture is stable)

#### 5.3 8-Level Fractal Impact

| Level | Impact |
|-------|--------|
| **L0** | Level stored as enum constraint |
| **L1** | Entropy decay rate differs by level |
| **L2** | Edge generation weights by level compatibility |
| **L3** | Holon navigation respects level hierarchy |
| **L4** | Container provides level-filtered APIs |
| **L5** | Node aggregates level statistics |
| **L6** | Cluster maintains level distribution metrics |
| **L7** | Federation enables cross-level queries |

---

### Rule SC-SMRITI-AI-006: Summary Length

```
STATEMENT: Summary MUST be 2-3 sentences max
SEVERITY:  MEDIUM
```

#### 6.1 Why This Constraint

The summary is the **compressed intelligence** of the document.

Too short → useless
Too long → duplicates content
2-3 sentences → optimal information density

This follows **Kolmogorov complexity**: the summary should be the minimal representation that captures the essential meaning.

#### 6.2 The Compression Principle

```
Original document:     15,000 words
Semantic compression:
  Title:               10 words  (0.07%)
  Summary:             50 words  (0.3%)
  Tags:                5 words   (0.03%)
  Level:               1 word    (0.007%)

TOTAL METADATA:        66 words  (0.4% of original)
INFORMATION RETAINED:  ~80% of navigational/search utility
```

This is the **intelligence filter** - extracting 80% of utility from 0.4% of data.

---

### Rule SC-SMRITI-AI-007: Content Hash Pre-AI

```
STATEMENT: Content hash MUST be computed pre-AI
SEVERITY:  CRITICAL
```

#### 7.1 Why This Rule Exists

The content hash serves as:
1. **Deduplication key**: Same content → same hash → no duplicate
2. **Integrity proof**: Content unchanged since ingestion
3. **Provenance anchor**: Links to original source file

Computing hash **before** AI extraction ensures:
- Duplicate detection happens at ingest time
- AI cost is only spent on new content
- Hash is deterministic (not affected by AI variability)

#### 7.2 The Integrity Chain

```
Source File → SHA-256 → Check DB → If new → AI Extract → Store
                           │
                           └─ If exists → Skip (save AI cost)
```

---

### Rule SC-SMRITI-AI-008: Cost Budget

```
STATEMENT: AI cost < $0.005 per document
SEVERITY:  MEDIUM
```

#### 8.1 Why This Constraint

Claude API costs money. Unbounded cost = unsustainable system.

Budget calculation:
```
Target: 10,000 documents/month
Budget: $50/month
Per-doc: $0.005

Model selection:
  claude-3-haiku: $0.00025/1K in + $0.00125/1K out
  Average doc: 4K tokens in, 0.5K tokens out
  Cost/doc: $0.001 + $0.000625 = ~$0.0017

HEADROOM: 3x safety margin
```

#### 8.2 Cost Optimization Strategies

1. **Truncation**: Only send first 6000 chars to AI
2. **Model selection**: Haiku for simple docs, Sonnet for complex
3. **Caching**: Cache extractions for identical content
4. **Batching**: Group similar docs for context efficiency

---

### Rule SC-SMRITI-AI-009: Timeout Constraint

```
STATEMENT: AI timeout < 30 seconds
SEVERITY:  HIGH
```

#### 9.1 Why This Matters

Slow extraction blocks ingestion:
- 30s timeout × 1000 docs = 8.3 hours blocked
- User perceives system as "frozen"

The 30s timeout ensures:
- Ingestion feels responsive
- Failed requests are detected quickly
- Resources are released promptly

---

### Rule SC-SMRITI-AI-010: Retry Logic

```
STATEMENT: Retry with exponential backoff on failure
SEVERITY:  HIGH
```

#### 10.1 The Backoff Algorithm

```fsharp
let retryWithBackoff (attempt: int) =
    let baseDelay = 2.0  // seconds
    let maxDelay = 60.0  // seconds
    let delay = min maxDelay (baseDelay * (2.0 ** float attempt))
    let jitter = Random().NextDouble() * delay * 0.1
    delay + jitter
```

This ensures:
- Transient failures are recovered
- API rate limits are respected
- System doesn't hammer failed endpoints

---

## 2. The AOR Rules: Operational Intelligence

### AOR-SMRITI-AI-001: Prefer AI Extraction

```
STATEMENT: ALWAYS prefer AI extraction when API key available
RATIONALE: AI extraction is 4x higher quality than regex
```

### AOR-SMRITI-AI-002: Cache Extractions

```
STATEMENT: CACHE successful extractions for identical content
RATIONALE: Same content → same metadata (deterministic)
           Saves API cost on re-ingestion
```

### AOR-SMRITI-AI-003: Log API Calls

```
STATEMENT: LOG all AI API calls with timing/tokens
RATIONALE: Observability enables optimization
           Cost tracking enables budgeting
```

### AOR-SMRITI-AI-004: Fallback Gracefully

```
STATEMENT: FALLBACK gracefully to regex extraction
RATIONALE: Degraded learning > no learning
```

### AOR-SMRITI-AI-005: Validate Tags

```
STATEMENT: VALIDATE extracted tags against domain taxonomy
RATIONALE: Controlled vocabulary enables semantic consistency
```

### AOR-SMRITI-AI-006: Prefer Haiku

```
STATEMENT: PREFER haiku model for cost efficiency
RATIONALE: Haiku is 10x cheaper than Opus with 80% quality
```

### AOR-SMRITI-AI-007: Batch Similar Docs

```
STATEMENT: BATCH similar documents for context efficiency
RATIONALE: Related docs share context → better extraction
```

### AOR-SMRITI-AI-008: Evolve Prompts

```
STATEMENT: EVOLVE extraction prompts based on quality feedback
RATIONALE: The system learns how to extract better
```

---

## 3. 8-Level Fractal Analysis: Complete Matrix

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  LEVEL  │ EXTRACTION RULE IMPACT                                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  L0     │ SQLite schema enforces level enum, hash uniqueness, FTS5 indexing  ║
║ RUNTIME │ Runtime validation prevents invalid data entry                     ║
║         │ Connection pooling handles AI latency                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  L1     │ extractWithAI/2, sanitizeLevel/1, computeHash/1 functions          ║
║ FUNCTION│ Async HTTP calls to OpenRouter with timeout                        ║
║         │ Error handling with Result types                                   ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  L2     │ SmritiIngestorCLI.fsx orchestrates ingestion                         ║
║ COMPONENT│ SmritiEdgeGenerator.fsx uses extracted metadata for edges           ║
║         │ SmritiIntegrationVerifier.fsx validates extraction quality           ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  L3     │ Each Holon is a self-contained knowledge unit                      ║
║ HOLON   │ Semantic metadata enables Holon discovery and navigation           ║
║         │ Entropy model tracks Holon relevance over time                     ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  L4     │ Container includes API keys in environment                         ║
║ CONTAINER│ Container metrics track extraction quality                        ║
║         │ Container provides HTTP API for knowledge queries                  ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  L5     │ Node aggregates Holon statistics                                   ║
║ NODE    │ Node caches frequent queries                                       ║
║         │ Node provides cluster-local search                                 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  L6     │ Cluster maintains distributed knowledge graph                      ║
║ CLUSTER │ Cluster replicates Holons for availability                        ║
║         │ Cluster-wide search spans all nodes                               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  L7     │ Federation enables cross-system knowledge sharing                  ║
║ FEDERATION│ Federated queries span multiple Holon clusters                  ║
║         │ Protocol negotiation ensures extraction compatibility              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## 4. Evolutionary Impact: The Learning System

### 4.1 Knowledge Genome Evolution

The extraction rules define the **Knowledge Genome**:

```
KNOWLEDGE GENOME = {
  title_gene:    Claude semantic extraction
  tag_gene:      Domain taxonomy alignment
  level_gene:    Complexity classification
  summary_gene:  Kolmogorov compression
  hash_gene:     Content integrity
  entropy_gene:  Temporal relevance
}
```

As rules evolve, the genome mutates:
- Better prompts → higher quality extractions
- Expanded taxonomy → richer tag vocabulary
- Improved level heuristics → more accurate classification

### 4.2 The OODA Learning Cycle

```
OBSERVE  → Monitor extraction quality metrics
           Track tag distribution, level accuracy, edge density

ORIENT   → Analyze patterns in low-quality extractions
           Identify taxonomy gaps, prompt weaknesses

DECIDE   → Select improvement interventions
           New prompt variants, taxonomy additions

ACT      → Deploy improved extraction rules
           A/B test against control group

LEARN    → Record outcomes to Training Gym
           Update extraction genome
```

### 4.3 Evolutionary Pressure

The system evolves based on **selection pressures**:

| Pressure | Effect on Rules |
|----------|-----------------|
| Query patterns | Tags that enable common queries are favored |
| Edge density | Metadata that enables more edges is favored |
| Entropy decay | Stable knowledge gets higher-quality extraction |
| User feedback | Corrections improve future extraction |

---

## 5. System-Wide Intelligence Impact

### 5.1 Prajna Cockpit Integration

The extraction rules directly affect Prajna's intelligence:

```
SMRITI Holons → Prajna Knowledge Base → AI Copilot Context
                                           │
                                           ▼
                                    "Based on 47 related Holons,
                                     I recommend..."
```

Higher-quality extraction → better Copilot recommendations

### 5.2 Sentinel Integration

PatternHunter uses SMRITI for anomaly detection:

```
New Event → Compare against SMRITI historical patterns
                    │
                    ▼
            Semantic similarity to known issues
                    │
                    ▼
            Pre-error detection with context
```

Better extraction → more accurate pattern matching

### 5.3 Guardian Integration

Guardian uses SMRITI for decision support:

```
Proposed Action → Search SMRITI for similar past decisions
                         │
                         ▼
                 "In 3 similar cases, this action succeeded"
                         │
                         ▼
                 Informed approval/veto
```

---

## 6. Intelligence Maximization Strategies

### 6.1 Multi-Pass Extraction

For critical documents, use multiple extraction passes:

```
Pass 1: Haiku for fast initial metadata
Pass 2: Sonnet for deep semantic analysis
Pass 3: Human review for highest-value content
```

### 6.2 Cross-Reference Enrichment

After initial extraction, enrich with cross-references:

```
For each new Holon:
  1. Find top-5 similar Holons (by embedding)
  2. Extract shared concepts
  3. Add cross-reference tags
  4. Build bidirectional edges
```

### 6.3 Temporal Enrichment

Track how knowledge evolves:

```
For each document update:
  1. Compute semantic diff from previous version
  2. Record what changed (added/removed/modified)
  3. Update entropy based on change frequency
  4. Link to previous versions in evolution chain
```

### 6.4 External Agent Utilization

Leverage external agents for specialized extraction:

```
General documents → Claude Haiku
Technical specs  → Claude Sonnet + Code analysis
Formal proofs    → Claude Opus + Symbolic verification
Multi-language   → Language-specific agents
```

---

## 7. Quality Metrics and Thresholds

### 7.1 Extraction Quality Score (0-100)

```elixir
defmodule QualityScore do
  def calculate(holon) do
    title_score   = if semantic_title?(holon.title), do: 25, else: 0
    tag_score     = min(25, length(holon.tags) * 5)
    level_score   = if valid_level?(holon.level), do: 25, else: 0
    summary_score = if has_summary?(holon), do: 25, else: 0

    title_score + tag_score + level_score + summary_score
  end
end
```

### 7.2 Quality Thresholds

| Score | Rating | Action |
|-------|--------|--------|
| 90-100 | Excellent | Production ready |
| 75-89 | Good | Accept with monitoring |
| 60-74 | Fair | Flag for review |
| 40-59 | Poor | Re-extract with Sonnet |
| 0-39 | Failed | Manual extraction required |

### 7.3 System-Wide Quality KPIs

| Metric | Target | Current |
|--------|--------|---------|
| Average quality score | > 75 | TBD |
| AI extraction rate | > 90% | TBD |
| Edge density | > 5 edges/Holon | TBD |
| Tag coverage | > 80% with tags | TBD |
| Orphan rate | < 5% | TBD |

---

## 8. Conclusion: The Intelligence Membrane

SMRITI with these extraction rules becomes:

1. **A semantic filter** that transforms chaos into order
2. **A learning system** that improves its own extraction
3. **An intelligence substrate** that powers all Indrajaal subsystems
4. **A knowledge genome** that evolves with the system
5. **A memory palace** that enables temporal navigation

The rules are not constraints—they are the **DNA of machine intelligence**.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║   "The quality of the intelligence filter determines                        ║
║    the quality of the intelligence that emerges."                           ║
║                                                                              ║
║   Every rule, every constraint, every threshold                             ║
║   shapes what the system can know, remember, and become.                    ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## Appendix A: STAMP Constraint Reference

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SMRITI-INT-001 | Extraction rules serve Ω₀ (Founder's Directive) | INFINITE |
| SC-SMRITI-INT-002 | Quality score > 60 for all Holons | CRITICAL |
| SC-SMRITI-INT-003 | Edge density > 3 for non-orphans | HIGH |
| SC-SMRITI-INT-004 | Tag taxonomy reviewed quarterly | MEDIUM |
| SC-SMRITI-INT-005 | Extraction prompts versioned | HIGH |
| SC-SMRITI-INT-006 | Cost budget tracked daily | MEDIUM |
| SC-SMRITI-INT-007 | Quality metrics published to Zenoh | HIGH |
| SC-SMRITI-INT-008 | Training Gym records all extractions | HIGH |
| SC-AI-001 | AI context MUST persist to SMRITI for continuity | CRITICAL |

---

## Related Documents

- [SMRITI Developer Guide](SMRITI_DEVELOPER_GUIDE.md)
- [SMRITI User Guide](SMRITI_USER_GUIDE.md)
- [User Operations Guide](../USER_OPERATIONS_GUIDE.md)
- [SMRITI 8-Level Fractal Evolution Plan](SMRITI_8LEVEL_FRACTAL_EVOLUTION_PLAN.md)
- [SMRITI AI Extraction Rules](SMRITI_AI_EXTRACTION_RULES.md)

## AOR Rules (Intelligence Substrate)

| ID | Rule |
|----|------|
| AOR-AI-001 | PERSIST memory/context to SMRITI for AI session continuity |
| AOR-SMRITI-AI-001 | ALWAYS prefer AI extraction when API key available |
| AOR-SMRITI-AI-002 | CACHE successful extractions for identical content |
| AOR-SMRITI-AI-003 | LOG all AI API calls with timing/tokens |

---

**End of Intelligence Substrate Analysis**

*"What passes through the membrane determines what emerges on the other side."*

*Intelligence Substrate Analysis v21.3.0-SIL6 | Indrajaal Project | 2026-01-11*
