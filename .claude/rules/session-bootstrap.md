# Session Bootstrap Protocol (SC-BOOTSTRAP)
# सत्र प्रारम्भ प्रोतोकॉल

## Mandate (आदेश)
**Every Claude session MUST bootstrap in ≤ 10 seconds.** No redundant file reads, no full codebase scans. Memory-first, verify-second.

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-BOOTSTRAP-001 | Session MUST check memory BEFORE reading any code files | HIGH |
| SC-BOOTSTRAP-002 | Session MUST verify `gleam build` passes in first 30 seconds | HIGH |
| SC-BOOTSTRAP-003 | Session MUST NOT re-read CLAUDE.md sections already in rules/ | MEDIUM |
| SC-BOOTSTRAP-004 | Session MUST check server status via /health before restart | MEDIUM |

## Fast Bootstrap Sequence (त्वरित प्रारम्भ अनुक्रम)

### Second 0-3: Memory Check (स्मृति जाँच)
```
1. Read MEMORY.md — understand prior session context
2. Check for active tasks: `./sa-plan status`
3. Check git status: any uncommitted changes?
```

### Second 3-7: System Status (तन्त्र स्थिति)
```
4. curl -s https://localhost:4100/health — is server running?
5. gleam build 2>&1 | tail -3 — does code compile?
6. If server down + build passes → start (don't ask)
```

### Second 7-10: Orient (अभिविन्यास)
```
7. Map user's request to SC-ULTRA-001 focus areas
8. Check Zettelkasten for prior patterns
9. Begin execution — no preamble, no "let me read the codebase"
```

## Anti-Patterns (दोष निवारण)
- ❌ Reading the entire CLAUDE.md (it's 40K+ tokens — rules/ already loaded)
- ❌ Listing all files in the repository
- ❌ Reading files "just to understand the structure"
- ❌ Asking "what would you like me to do?" (read the request, act)
- ❌ Summarizing what you're about to do (just do it — Gita protocol)

## Mathematical Optimization
```
T_bootstrap = T_memory + T_verify + T_orient
Target: T_bootstrap ≤ 10s
Current: T_bootstrap ≈ 60s (reading CLAUDE.md + scanning files)
Improvement: 6x faster startup

Context savings per session:
  Before: ~80K tokens consumed on bootstrap reads
  After: ~15K tokens (memory + rules only)
  Savings: 65K tokens/session = 32.5% of 200K budget
```
