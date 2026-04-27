# Recall/RAG/Context Memory — Pi-Mono Integration Guide

## Overview

This guide documents how to replicate the C3I Recall/RAG/Context Memory system for Pi-mono (TypeScript, 172K LOC, 7 packages). The architecture provides effectively unbounded recall within any context window limit by using a 7-layer memory hierarchy.

## Architecture Summary

```
┌─────────────────────────────────────────────────────────────┐
│                    7-LAYER MEMORY HIERARCHY                  │
├─────────────────────────────────────────────────────────────┤
│ L1: Context Window     │ Model limit (1M tokens)   │ Session│
│ L2: File-Based Memory  │ .claude/memory/ (~30 files)│ Persist│
│ L3: Auto-Recall Hooks  │ 3 hooks fire per prompt   │ Auto   │
│ L4: RAG Pipeline       │ FTS5 + holon search       │ /query │
│ L5: Semantic Cache     │ SQLite, 24h TTL           │ Perm   │
│ L6: Chat History       │ 50-msg sliding window     │ Session│
│ L7: Zettelkasten       │ 3,154+ holons (SQLite)    │ Perm   │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Guide for Pi-Mono

### Layer 1: Context Window (Already exists in Pi)
Pi-mono's `pi-ai` package handles context windows for 15 LLM providers. No changes needed.

### Layer 2: Persistent Memory
**Pi equivalent**: Session branching in `pi-coding-agent`
- Sessions stored as JSONL (production: migrate to SQLite per SC-PI-005)
- Implement: `packages/pi-coding-agent/src/memory/` directory
- Key files: `memory-store.ts`, `memory-index.ts`

### Layer 3: Auto-Recall Hooks
**Pi equivalent**: Extension event hooks in `pi-coding-agent`
```typescript
// In pi-coding-agent/src/extensions/recall-hook.ts
import { Extension } from '../types';

export const recallHook: Extension = {
  name: 'zk-recall',
  events: {
    onPromptSubmit: async (prompt: string) => {
      // Search Zettelkasten before processing
      const results = await searchZK(prompt);
      return { context: formatRAGContext(results) };
    },
    onSessionEnd: async (session) => {
      // Ingest new knowledge
      await ingestToZK(session.interactions);
    }
  }
};
```

### Layer 4: RAG Pipeline
**Pi equivalent**: New module in `pi-ai/src/rag/`
```typescript
// pi-ai/src/rag/pipeline.ts
interface RAGContext {
  holons: Holon[];
  tasks: Task[];
  preferences: Preference[];
}

async function retrieveContext(query: string): Promise<RAGContext> {
  const db = await openSmritiDB();
  
  // FTS5 search
  const holons = await db.all(
    `SELECT uuid, title, snippet(holons_fts, 2, '', '', '...', 64) 
     FROM holons_fts WHERE holons_fts MATCH ? LIMIT 3`,
    [query]
  );
  
  // Task search
  const tasks = await db.all(
    `SELECT title, status, priority FROM Tasks 
     WHERE title LIKE ? LIMIT 5`,
    [`%${query}%`]
  );
  
  return { holons, tasks, preferences: [] };
}
```

### Layer 5: Semantic Cache
**Pi equivalent**: SQLite-backed cache in `pi-ai/src/cache/`
```typescript
// pi-ai/src/cache/semantic-cache.ts
const CACHE_TTL_HOURS = 24;

async function getCached(queryHash: string): Promise<string | null> {
  const row = await db.get(
    `SELECT response FROM semantic_cache 
     WHERE query_hash = ? AND created_at > datetime('now', '-${CACHE_TTL_HOURS} hours')`,
    [queryHash]
  );
  return row?.response ?? null;
}

async function setCached(queryHash: string, response: string): Promise<void> {
  await db.run(
    `INSERT OR REPLACE INTO semantic_cache (query_hash, response, created_at) 
     VALUES (?, ?, datetime('now'))`,
    [queryHash, response]
  );
}
```

### Layer 6: Conversation History
**Pi equivalent**: Already exists in `pi-coding-agent` session management
- 50-message sliding window
- Implement: Trim oldest messages when count exceeds limit

### Layer 7: Zettelkasten
**Pi equivalent**: Shared Smriti.db access via sa-plan-daemon
```typescript
// pi-coding-agent/src/knowledge/zettelkasten.ts
import { execSync } from 'child_process';

function searchZK(query: string): Holon[] {
  const result = execSync(
    `sa-plan-daemon knowledge-search "${query.replace(/"/g, '\\"')}"`,
    { encoding: 'utf-8', timeout: 5000 }
  );
  return parseZKResults(result);
}

function ingestDocument(path: string): void {
  execSync(`sa-plan-daemon ingest-docs`, { timeout: 30000 });
}
```

## Gleam Type System → TypeScript Types

```typescript
// Gleam HolonLevel → TypeScript
type HolonLevel = 'atomic' | 'molecular' | 'organism' | 'ecosystem';

// Gleam RhetoricalFunction → TypeScript  
type RhetoricalFunction = 'axiom' | 'hypothesis' | 'evidence' | 'anecdote';

// Gleam KnowledgeSource → TypeScript
type KnowledgeSource = 
  | { type: 'document'; path: string }
  | { type: 'code'; modulePath: string; language: string }
  | { type: 'git_commit'; sha: string }
  | { type: 'pipeline_trace'; intentId: string }
  | { type: 'interaction'; chatId: string; intentId: string }
  | { type: 'ooda_decision'; cycleId: string }
  | { type: 'cache_learning'; promptHash: string }
  | { type: 'session_summary'; sessionId: string }
  | { type: 'manual'; author: string };

// Gleam Holon → TypeScript
interface Holon {
  uuid: string;
  title: string;
  content: string;
  tags: string[];
  level: HolonLevel;
  rhetorical: RhetoricalFunction;
  entropy: number;
  decayRate: 'slow' | 'medium' | 'fast';
  source: KnowledgeSource;
  contentHash: string;
  cluster?: string;
  stampRefs: string[];
  createdAt: string;
  updatedAt: string;
  verifiedAt?: string;
}

// Trust scoring
const TRUST_SCORES: Record<RhetoricalFunction, number> = {
  axiom: 1.0,
  evidence: 0.9,
  hypothesis: 0.5,
  anecdote: 0.3,
};
```

## Zenoh Integration for Pi

Pi events should be published to Zenoh for C3I observability:

```typescript
// Topics for Pi recall/RAG events
const ZENOH_TOPICS = {
  ragQuery: 'indrajaal/pi/rag/query',
  ragResult: 'indrajaal/pi/rag/result',
  cacheHit: 'indrajaal/pi/cache/hit',
  cacheMiss: 'indrajaal/pi/cache/miss',
  zkIngest: 'indrajaal/pi/zk/ingest',
  hookFire: 'indrajaal/pi/hook/fire',
};
```

## Bridge: Pi ↔ C3I Tool Federation

The existing bridge (`pi_claude_code.gleam`) already maps:
- 6 Claude tools → Pi equivalents
- 14 Pi tools → C3I MCP
- 73 C3I MCP tools → available to Pi

For recall/RAG specifically, Pi should use:
- `knowledge_search` MCP tool (searches C3I ZK)
- `knowledge_ingest` MCP tool (ingests to C3I ZK)
- Direct SQLite access to Smriti.db for low-latency RAG

## STAMP Constraints for Pi Integration

| ID | Constraint | Pi Implementation |
|----|------------|-------------------|
| SC-PI-001 | Events to Zenoh | Publish RAG/ZK events |
| SC-PI-003 | Sessions in Smriti.db | Use sa-plan-daemon API |
| SC-PI-004 | Circuit breakers | Implement per-provider |
| SC-PI-010 | PII compliance | Regex scrubber before ZK ingest |

## Testing Checklist

1. `npm run build` in pi-mono → 0 errors
2. RAG pipeline returns results for known queries
3. Semantic cache stores and retrieves correctly
4. ZK search returns relevant holons
5. Hook fires on prompt submit
6. Session ingest creates new holons
7. Zenoh events published correctly
8. Trust scores compute correctly
9. Entropy decay works over time
10. PII scrubbing removes sensitive data

## Files to Create in Pi-Mono

| File | Purpose | Lines (est) |
|------|---------|-------------|
| `packages/pi-ai/src/rag/pipeline.ts` | RAG retrieval | ~150 |
| `packages/pi-ai/src/rag/types.ts` | Holon types | ~80 |
| `packages/pi-ai/src/cache/semantic-cache.ts` | 24h TTL cache | ~100 |
| `packages/pi-coding-agent/src/extensions/recall-hook.ts` | Auto-recall | ~80 |
| `packages/pi-coding-agent/src/knowledge/zettelkasten.ts` | ZK access | ~120 |
| `packages/pi-coding-agent/src/knowledge/ingest.ts` | Doc ingestion | ~100 |

Total estimated: ~630 lines of TypeScript
