# KMS Wireframes - Safety-Critical Rich TUI Cockpit
**Version**: 2.0.0-INTEGRATED | **Date**: 2025-12-30 | **Status**: ACTIVE
**Compliance**: NASA-STD-3000, NUREG-0700, IEC 61508 SIL-2, Dark Cockpit Philosophy
**Master Spec**: [PRAJNA_TUI_MASTER_SPECIFICATION.md](../prajna/PRAJNA_TUI_MASTER_SPECIFICATION.md)

---

## Document Navigation & Cross-References

### Related Specifications
| Document | Path | Description |
|----------|------|-------------|
| **TUI Master Spec** | [PRAJNA_TUI_MASTER_SPECIFICATION.md](../prajna/PRAJNA_TUI_MASTER_SPECIFICATION.md) | Complete TUI requirements, STAMP, TDG, FMEA, BDD, formal methods |
| **User Guide** | [PRAJNA_USER_GUIDE.md](../prajna/PRAJNA_USER_GUIDE.md) | End-user documentation |
| **Dark UI Components** | [PRAJNA_DARK_UI_COMPONENTS.md](../prajna/PRAJNA_DARK_UI_COMPONENTS.md) | 156 UI components, color system |
| **Safety Critical** | [PRAJNA_SAFETY_CRITICAL_IMPLEMENTATION.md](../prajna/PRAJNA_SAFETY_CRITICAL_IMPLEMENTATION.md) | Safety standards, HMI compliance |
| **Biomorphic Blueprint** | [PRAJNA_BIOMORPHIC_BLUEPRINT.md](../prajna/PRAJNA_BIOMORPHIC_BLUEPRINT.md) | Bio-inspired architecture |
| **TUI Design Guide** | [PRAJNA_TUI_DESIGN_GUIDE.md](../prajna/PRAJNA_TUI_DESIGN_GUIDE.md) | UX/CX/DX integration |
| **Theme Ergonomics** | [PRAJNA_THEME_ERGONOMICS_5LEVEL_SPEC.md](../prajna/PRAJNA_THEME_ERGONOMICS_5LEVEL_SPEC.md) | Theme system, responsive design |
| **Information Architecture** | [PRAJNA_TUI_INFORMATION_ARCHITECTURE.md](../prajna/PRAJNA_TUI_INFORMATION_ARCHITECTURE.md) | Information element taxonomy |
| **Component System** | [PRAJNA_TUI_COMPONENT_SYSTEM.md](../prajna/PRAJNA_TUI_COMPONENT_SYSTEM.md) | Fractal holon renderer |
| **5-Level Spec** | [PRAJNA_5LEVEL_SPECIFICATION.md](../prajna/PRAJNA_5LEVEL_SPECIFICATION.md) | Complete system specification |

### F# Cockpit Implementation
| Document | Path | Description |
|----------|------|-------------|
| **CEPAF User Guide** | [PRAJNA_CEPAF_USER_GUIDE.md](../../lib/cepaf/docs/PRAJNA_CEPAF_USER_GUIDE.md) | F# API reference |
| **F# Capability Rules** | [FSHARP_CAPABILITY_RULES.md](../../lib/cepaf/docs/FSHARP_CAPABILITY_RULES.md) | F# implementation rules |
| **Integrated Architecture** | [CEPAF_INTEGRATED_ARCHITECTURE.md](../../lib/cepaf/docs/CEPAF_INTEGRATED_ARCHITECTURE.md) | CEPAF architecture |

### Use Cases & Operations
| Document | Path | Description |
|----------|------|-------------|
| **Fractal Use Cases** | [FRACTAL_COCKPIT_USE_CASES.md](../cockpit/FRACTAL_COCKPIT_USE_CASES.md) | Operational scenarios |
| **Commands Reference** | [PRAJNA_COMMANDS.md](../prajna/PRAJNA_COMMANDS.md) | Quick command reference |

### Testing & Evaluation
| Resource | Path | Description |
|----------|------|-------------|
| **Dark Cockpit Tests** | [dark_cockpit_test.exs](../../test/indrajaal/cockpit/prajna/dark_cockpit_test.exs) | Elixir UI tests |
| **UX Evaluator** | [CockpitUXEvaluator.fsx](../../lib/cepaf/scripts/CockpitUXEvaluator.fsx) | Nielsen heuristics evaluation |
| **Runtime Tests** | [ComprehensiveRuntimeTests.fsx](../../lib/cepaf/scripts/ComprehensiveRuntimeTests.fsx) | 75+ test scenarios |
| **Cockpit Operations** | [CockpitOperations.fsx](../../lib/cepaf/scripts/CockpitOperations.fsx) | Unified operations script |

### Formal Specifications
| Spec | Path | Domain |
|------|------|--------|
| **Arm & Fire FSM** | [arm_fire_fsm.wl](../formal_specs/arm_fire_fsm.wl) | Mathematica |
| **Color Safety** | [color_safety.agda](../formal_specs/color_safety.agda) | Agda proof |
| **Zone Layout** | [zone_layout.qnt](../formal_specs/zone_layout.qnt) | Quint model |
| **KMS Verification** | [kms_verification.qnt](../formal_specs/kms_verification.qnt) | Quint model |

### KMS Implementation
| Module | Path | Description |
|--------|------|-------------|
| **KMS Holon** | [holon.ex](../../lib/indrajaal/kms/holon.ex) | Core holon structure |
| **KMS Store** | [store.ex](../../lib/indrajaal/kms/store.ex) | SQLite + DuckDB store |
| **KMS AI** | [ai.ex](../../lib/indrajaal/kms/ai.ex) | AI classification, embeddings |
| **Graphiti Bridge** | [graphiti_bridge.ex](../../lib/indrajaal/kms/graphiti_bridge.ex) | Graphiti integration |
| **Developer Domain** | [developer.ex](../../lib/indrajaal/kms/developer.ex) | Developer artifacts |
| **Product Domain** | [product.ex](../../lib/indrajaal/kms/product.ex) | Product artifacts |
| **SRE Domain** | [sre.ex](../../lib/indrajaal/kms/sre.ex) | SRE artifacts |
| **Technical Leadership** | [technical_leadership.ex](../../lib/indrajaal/kms/technical_leadership.ex) | ADRs, Tech Specs |
| **Zenoh Publisher** | [zenoh_kms_publisher.ex](../../lib/indrajaal/kms/zenoh_kms_publisher.ex) | Real-time sync |
| **F# KMS Panel** | [KmsPanel.fs](../../lib/cepaf/src/Cepaf/Cockpit/KmsPanel.fs) | F# TUI panel |
| **F# KMS Subscriber** | [KmsSubscriber.fs](../../lib/cepaf/src/Cepaf/Zenoh/KmsSubscriber.fs) | F# Zenoh subscriber |

### LiveView Screens
| Screen | Path | Route |
|--------|------|-------|
| **Main Dashboard** | [knowledge_live.ex](../../lib/indrajaal_web/live/prajna/knowledge_live.ex) | `/prajna/knowledge` |
| **Developer Portal** | [developer_live.ex](../../lib/indrajaal_web/live/prajna/knowledge/developer_live.ex) | `/prajna/knowledge/developer` |
| **Product Portal** | [product_live.ex](../../lib/indrajaal_web/live/prajna/knowledge/product_live.ex) | `/prajna/knowledge/product` |
| **SRE Portal** | [sre_live.ex](../../lib/indrajaal_web/live/prajna/knowledge/sre_live.ex) | `/prajna/knowledge/sre` |

### REST API
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/kms/holons` | GET | List holons (with filters) |
| `/api/kms/holons/:id` | GET | Get single holon |
| `/api/kms/holons` | POST | Create holon |
| `/api/kms/holons/:id` | PUT | Update holon |
| `/api/kms/holons/:id` | DELETE | Delete holon |
| `/api/kms/search` | GET | Full-text search |
| `/api/kms/health` | GET | Health report |
| `/api/kms/entropy` | GET | Entropy report |
| `/api/kms/edges` | POST | Create relationship |

---

## STAMP Constraints (KMS-Specific)

### SC-KMS Safety Constraints
```
SC-KMS-001: SQLite + DuckDB only (no external dependencies)
SC-KMS-002: Cross-runtime access (Elixir & F# share databases)
SC-KMS-003: Portable holons (directory copy = full backup)
SC-KMS-004: OODA <100ms (SQLite hot path optimization)
SC-KMS-005: Zenoh cross-runtime sync (real-time state broadcasting)
SC-KMS-007: Decision traceability (ADR-to-code links required)
SC-KMS-008: Architecture coherence (impact analysis on changes)
SC-KMS-010: Graphiti bidirectional sync (fact ↔ holon mapping)
SC-KMS-013: AI classification confidence (>=0.75 threshold)
SC-KMS-014: Embedding dimensions (1024, ada-002 compatible)
SC-KMS-015: Gardening frequency (max once per hour)
SC-KMS-016: Gardening approval (human approval for destructive)
```

### SC-HMI Constraints (Display)
```
SC-HMI-001: Dark Cockpit default (low-contrast gray)
SC-HMI-002: Alarm color reservation (Red/Amber)
SC-HMI-003: Arm & Fire for destructive actions
SC-HMI-004: Data staling indication (>2s old)
SC-HMI-005: Minimum 80x24 resolution support
SC-HMI-006: Keyboard accessibility (all functions)
SC-HMI-007: Annunciator always visible
```

---

## Design Principles

### Dark Cockpit Philosophy
- **Default State**: Low contrast, Dark Grey (#1a1a2e) / Blue (#16213e) background
- **Silence is Normal**: Green indicators only for confirmed healthy states
- **Alarm State**: High contrast Red (#FF0000) or Amber (#FFA500) - theme override
- **Data Staling**: Desaturation filter when update frequency < 0.5Hz

### Tiered Rendering
- **Tier 1 (GPU/Rich)**: Kitty Graphics, Unicode charts, full color
- **Tier 2 (Text/Safe)**: Braille characters (⣿⣇), Nerd Fonts
- **Tier 3 (Emergency)**: Pure ASCII (|, +, -)

### Layout Zones (Strict Tiling)
```
┌─────────────────────────────────────────────────────────────────────────┐
│ ZONE A: Annunciator Panel (Fixed Height - Status Icons Only)            │
├─────────────────────────────────────────┬───────────────────────────────┤
│ ZONE B: Primary Display                 │ ZONE C: Message Log           │
│ (High-res sparklines, trends)           │ (Scrolling, pause indicator)  │
│                                         │                               │
├─────────────────────────────────────────┴───────────────────────────────┤
│ ZONE D: Control Surface (Interaction prompts only)                      │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 1. MAIN KNOWLEDGE DASHBOARD

### 1.1 Primary View (Tree + Detail)
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ZONE A: ANNUNCIATOR                                                              │
│ ┌────────┬────────┬────────┬────────┬────────┬────────┬─────────────────────────┐│
│ │ ● KMS  │ ○ SYNC │ ○ AI   │ ○ GRPH │ ○ ZENOH│ ⚠ DEBT │  HLC: 1735570800.00042 ││
│ │ ONLINE │ IDLE   │ READY  │ LINKED │ CONN   │ 12 ITEM│  2025-12-30 18:00:00   ││
│ └────────┴────────┴────────┴────────┴────────┴────────┴─────────────────────────┘│
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE B: PRIMARY DISPLAY                                                          │
│ ┌─────────────────────────────┬──────────────────────────────────────────────────┤
│ │ HOLON TREE                  │ DETAIL PANEL                                     │
│ │ ─────────────────────────── │ ──────────────────────────────────────────────── │
│ │ [─] 📁 root                 │ ┌────────────────────────────────────────────┐   │
│ │  ├─[+] 📚 knowledge (47)    │ │ HOLON: authentication-flow-adr             │   │
│ │  ├─[─] ⚙ process (23)       │ │ TYPE:  decision    STATUS: accepted        │   │
│ │  │  ├── workflow-deploy     │ │ FQUN:  kms/l3/decision/default/auth@n1#a3  │   │
│ │  │  ├── workflow-review     │ ├────────────────────────────────────────────┤   │
│ │  │  └── workflow-onboard    │ │ VITAL SIGNS                                │   │
│ │  ├─[+] 🤖 agent (8)         │ │ Health:    [████████████████░░░░] 82%      │   │
│ │  ├─[─] 📝 decision (31)     │ │ Stress:    [████░░░░░░░░░░░░░░░░] 18%      │   │
│ │  │  ├── auth-flow-adr  ◀──  │ │ Energy:    [██████████████░░░░░░] 71%      │   │
│ │  │  ├── cache-strategy      │ │ Coherence: [██████████████████░░] 94%      │   │
│ │  │  └── api-versioning      │ ├────────────────────────────────────────────┤   │
│ │  ├─[+] 🏗 architecture (12) │ │ PAYLOAD                                    │   │
│ │  ├─[+] ⚠ debt (12)          │ │ {                                          │   │
│ │  └─[+] 📡 radar (6)         │ │   "title": "JWT Auth Flow",                │   │
│ │                             │ │   "status": "accepted",                    │   │
│ │ ─────────────────────────── │ │   "context": "Need stateless auth...",     │   │
│ │ QUICK STATS                 │ │   "decision": "Use RS256 JWT with...",     │   │
│ │ Total: 139  Stale: 4        │ │   "consequences": ["Token refresh..."]     │   │
│ │ Orphans: 2  Entropy: 0.23   │ │ }                                          │   │
│ └─────────────────────────────┴──────────────────────────────────────────────────┤
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE C: MESSAGE LOG (Right panel when enabled)                                   │
│ ┌────────────────────────────────────────────────────────────────────────────────┤
│ │ 18:00:01 [INFO]  Holon created: workflow-deploy                               │
│ │ 18:00:03 [INFO]  Zenoh sync: 3 holons published                               │
│ │ 17:59:45 [WARN]  Stale holon detected: legacy-api-spec (92 days)              │
│ │ 17:59:30 [INFO]  AI classification: cache-strategy → architecture             │
│ │ ─ PAUSED ─ Press [Space] to resume ─────────────────────────────────────────  │
│ └────────────────────────────────────────────────────────────────────────────────┤
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE D: CONTROL SURFACE                                                          │
│ ┌────────────────────────────────────────────────────────────────────────────────┤
│ │ [T]ree  [G]raph  [L]ist  [S]earch  │  [N]ew Holon  [E]dit  [D]elete  │ [?]Help│
│ └────────────────────────────────────────────────────────────────────────────────┤
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Graph View (Relationships)
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ZONE A: ANNUNCIATOR                                                              │
│ [●KMS] [○SYNC] [○AI] [○GRPH] [○ZENOH] [⚠DEBT:12]        HLC: 1735570800.00042  │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE B: GRAPH VISUALIZATION                                                      │
│                                                                                  │
│                            ┌─────────────┐                                       │
│                            │ 🏗 C4-Model │                                       │
│                            │  Container  │                                       │
│                            └──────┬──────┘                                       │
│                          IMPACTS  │                                              │
│                    ┌──────────────┼──────────────┐                               │
│                    ▼              ▼              ▼                               │
│            ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                       │
│            │ 📝 ADR-001  │ │ 📝 ADR-002  │ │ 📝 ADR-003  │                       │
│            │  Auth Flow  │ │  Caching    │ │  API Ver    │                       │
│            └──────┬──────┘ └──────┬──────┘ └─────────────┘                       │
│           GUIDES  │       GUIDES  │                                              │
│                   ▼               ▼                                              │
│            ┌─────────────┐ ┌─────────────┐                                       │
│            │ ⚙ Process   │ │ 📦 Artifact │                                       │
│            │  Deploy     │ │  API Spec   │                                       │
│            └─────────────┘ └─────────────┘                                       │
│                                                                                  │
│ ─────────────────────────────────────────────────────────────────────────────── │
│ LEGEND: ──▶ IMPACTS  ─ ─▶ GUIDES  ···▶ RELATED_TO  ═══▶ PRODUCES                │
│ FILTERS: [x] Decisions  [x] Architecture  [ ] Knowledge  [ ] Process            │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE D: [T]ree  [G]raph  [L]ist  [S]earch  │  Zoom[+][-]  [F]ilter  │  [?]Help  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 1.3 Search View
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ZONE A: ANNUNCIATOR                                                              │
│ [●KMS] [○SYNC] [●AI:SEARCH] [○GRPH] [○ZENOH]           HLC: 1735570800.00042   │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE B: SEARCH INTERFACE                                                         │
│ ┌────────────────────────────────────────────────────────────────────────────────┤
│ │ 🔍 Query: [authentication jwt refresh________________] [ENTER to search]      │
│ │                                                                               │
│ │ FACETS                    │ RESULTS (17 matches, 0.042s)                      │
│ │ ───────────────────────── │ ──────────────────────────────────────────────── │
│ │ TYPE                      │                                                   │
│ │ [x] decision      (8)     │ 1. 📝 authentication-flow-adr                     │
│ │ [x] knowledge     (5)     │    TYPE: decision  SCORE: 0.97  ★ SEMANTIC       │
│ │ [ ] architecture  (2)     │    "JWT Auth Flow with RS256 signing..."         │
│ │ [ ] process       (2)     │    ─────────────────────────────────────────────  │
│ │                           │                                                   │
│ │ DOMAIN                    │ 2. 📚 jwt-token-refresh-strategy                  │
│ │ [x] developer     (6)     │    TYPE: knowledge  SCORE: 0.91                   │
│ │ [ ] sre           (4)     │    "Token refresh best practices for SPAs..."    │
│ │ [ ] product       (3)     │    ─────────────────────────────────────────────  │
│ │ [ ] leadership    (4)     │                                                   │
│ │                           │ 3. 📝 session-management-adr                      │
│ │ STATUS                    │    TYPE: decision  SCORE: 0.87  ★ SEMANTIC       │
│ │ [x] accepted      (5)     │    "Stateless session handling..."               │
│ │ [ ] proposed      (3)     │    ─────────────────────────────────────────────  │
│ │ [ ] deprecated    (1)     │                                                   │
│ │                           │ 4. ⚙ auth-token-validation-process                │
│ │ HEALTH                    │    TYPE: process  SCORE: 0.82                     │
│ │ [████████░░] >80%  (12)   │    "Step-by-step JWT validation flow..."         │
│ │ [████░░░░░░] 50-80% (4)   │                                                   │
│ │ [██░░░░░░░░] <50%   (1)   │ ──────────── Page 1 of 2 ────────────            │
│ └───────────────────────────┴────────────────────────────────────────────────────┤
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE D: [ESC] Clear  [TAB] Facets  [↑↓] Navigate  [ENTER] Select  │  [?]Help    │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 1.4 Analytics/Health View
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ZONE A: ANNUNCIATOR                                                              │
│ [●KMS] [●SYNC] [○AI] [○GRPH] [●ZENOH]  [●ANALYTICS]    HLC: 1735570800.00042   │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE B: HEALTH ANALYTICS                                                         │
│ ┌─────────────────────────────────┬──────────────────────────────────────────────┤
│ │ SYSTEM HEALTH                   │ VITAL SIGNS BY TYPE                          │
│ │ ─────────────────────────────── │ ──────────────────────────────────────────── │
│ │                                 │                                              │
│ │ Overall:  [████████████████░░░] │ knowledge  [████████████████░░░░] 82%       │
│ │           85% HEALTHY           │ process    [██████████████░░░░░░] 71%       │
│ │                                 │ agent      [████████████████████] 98%       │
│ │ ┌─────────────────────────────┐ │ decision   [██████████████████░░] 89%       │
│ │ │ HEALTH TREND (7 days)       │ │ architect  [████████████░░░░░░░░] 64%  ⚠    │
│ │ │                        ╭──  │ │ debt       [████████░░░░░░░░░░░░] 45%  ⚠    │
│ │ │  90% ┤               ╭─╯    │ │ artifact   [██████████████████░░] 91%       │
│ │ │      │            ╭──╯      │ │                                              │
│ │ │  80% ┤     ╭─────╯          │ │ ──────────────────────────────────────────── │
│ │ │      │  ╭──╯                │ │ ENTROPY REPORT                               │
│ │ │  70% ┤╭─╯                   │ │                                              │
│ │ │      └────┬────┬────┬────┬─ │ │ Stale Holons (>90 days):           4        │
│ │ │        Mon Tue Wed Thu Fri  │ │  • legacy-api-spec        (92 days)         │
│ │ └─────────────────────────────┘ │  • old-deployment-guide   (104 days)        │
│ │                                 │  • deprecated-auth-flow   (127 days)        │
│ │ EVENT STATISTICS (24h)          │  • v1-migration-notes     (156 days)        │
│ │ Created:  23  Updated: 45       │                                              │
│ │ Deleted:   2  Synced:  68       │ Orphaned Holons:                   2        │
│ │                                 │  • standalone-note-1                         │
│ │ AI Activity:                    │  • unlinked-diagram-2                        │
│ │ Classifications: 12             │                                              │
│ │ Embeddings:      34             │ [G]arden Now  [R]eview Stale  [L]ink Orphans│
│ │ Similar Found:    8             │                                              │
│ └─────────────────────────────────┴──────────────────────────────────────────────┤
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE D: [T]ree  [G]raph  [A]nalytics  [S]earch  │  [R]efresh  [E]xport  │ [?]   │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. DEVELOPER PORTAL

### 2.1 Decisions View (ADRs/RFCs)
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ZONE A: DEVELOPER KNOWLEDGE                                                      │
│ [●DEV] [📝DECISIONS] [⚙PATTERNS] [🔍DEBUG] [🔗CODE] [📋REVIEWS]   HLC: ...042  │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE B: ARCHITECTURE DECISIONS                                                   │
│ ┌────────────────────────────────────────────────────────────────────────────────┤
│ │ FILTER: [All ▼] [proposed ▼] [Q4-2025 ▼]              [+ New Decision]        │
│ │                                                                               │
│ │ ┌────────────────────────────────────────────────────────────────────────────┐│
│ │ │ #  │ STATUS     │ TITLE                          │ AUTHOR   │ DATE        ││
│ │ ├────┼────────────┼────────────────────────────────┼──────────┼─────────────┤│
│ │ │ 42 │ ● PROPOSED │ GraphQL Federation Strategy    │ @alice   │ 2025-12-28  ││
│ │ │ 41 │ ● PROPOSED │ Event Sourcing for Audit       │ @bob     │ 2025-12-25  ││
│ │ │ 40 │ ✓ ACCEPTED │ JWT Auth Flow (RS256)          │ @charlie │ 2025-12-20  ││
│ │ │ 39 │ ✓ ACCEPTED │ Redis Caching Strategy         │ @alice   │ 2025-12-15  ││
│ │ │ 38 │ ○ DEPREC.  │ Session-based Auth             │ @dave    │ 2025-11-01  ││
│ │ │ 37 │ ✓ ACCEPTED │ API Versioning (URL-based)     │ @eve     │ 2025-10-20  ││
│ │ │ 36 │ ⊘ SUPERSED │ Basic Auth (see #40)           │ @frank   │ 2025-09-15  ││
│ │ └────┴────────────┴────────────────────────────────┴──────────┴─────────────┘│
│ │                                                                               │
│ │ ─────────────────────────── SELECTED: ADR-042 ─────────────────────────────  │
│ │                                                                               │
│ │ ┌─ CONTEXT ──────────────────────────────────────────────────────────────────┐│
│ │ │ We need to scale our GraphQL API across multiple services while            ││
│ │ │ maintaining a unified schema for clients. Current monolithic approach      ││
│ │ │ is becoming a bottleneck for team autonomy.                                ││
│ │ └────────────────────────────────────────────────────────────────────────────┘│
│ │ ┌─ DECISION ─────────────────────────────────────────────────────────────────┐│
│ │ │ Adopt Apollo Federation 2.0 with:                                          ││
│ │ │ • Subgraph per domain (Users, Orders, Products)                            ││
│ │ │ • Supergraph composition via Rover CLI                                     ││
│ │ │ • Gateway with query planning optimization                                 ││
│ │ └────────────────────────────────────────────────────────────────────────────┘│
│ │ ┌─ LINKED CODE ──────────────────────────────────────────────────────────────┐│
│ │ │ 📄 lib/indrajaal_web/schema.ex:1-50          [IMPLEMENTS]                  ││
│ │ │ 📄 lib/indrajaal/graphql/federation.ex:1-200 [IMPLEMENTS]                  ││
│ │ │ 📄 test/graphql/federation_test.exs:1-100    [TESTS]                       ││
│ │ └────────────────────────────────────────────────────────────────────────────┘│
│ └────────────────────────────────────────────────────────────────────────────────┤
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE D: [V]iew  [E]dit  [L]ink Code  [A]pprove  [D]eprecate  │  [←][→] Nav     │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Patterns Library
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ZONE A: DEVELOPER KNOWLEDGE                                                      │
│ [○DEV] [○DECISIONS] [●PATTERNS] [○DEBUG] [○CODE] [○REVIEWS]      HLC: ...042   │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE B: PATTERN LIBRARY                                                          │
│ ┌─────────────────────────────┬──────────────────────────────────────────────────┤
│ │ CATEGORIES                  │ PATTERN DETAIL                                   │
│ │ ─────────────────────────── │ ──────────────────────────────────────────────── │
│ │ [▼] structural      (12)    │ ┌────────────────────────────────────────────┐   │
│ │     ├─ adapter              │ │ CIRCUIT BREAKER                            │   │
│ │     ├─ facade               │ │ Category: resilience  Uses: 47             │   │
│ │     └─ repository           │ ├────────────────────────────────────────────┤   │
│ │ [▼] behavioral      (8)     │ │ PROBLEM                                    │   │
│ │     ├─ strategy             │ │ External service calls can fail or hang,   │   │
│ │     └─ observer             │ │ causing cascading failures in the system.  │   │
│ │ [▼] resilience      (6)     │ ├────────────────────────────────────────────┤   │
│ │     ├─ circuit-breaker ◀──  │ │ SOLUTION                                   │   │
│ │     ├─ retry                │ │ Wrap external calls in a circuit breaker   │   │
│ │     ├─ bulkhead             │ │ that tracks failures and "opens" to fail   │   │
│ │     └─ timeout              │ │ fast when threshold is exceeded.           │   │
│ │ [▶] security        (5)     │ ├────────────────────────────────────────────┤   │
│ │ [▶] performance     (4)     │ │ TEMPLATE                                   │   │
│ │ [▶] testing         (3)     │ │ ```elixir                                  │   │
│ │                             │ │ defmodule MyApp.ExternalService do         │   │
│ │ ─────────────────────────── │ │   use Fuse, strategy: :random              │   │
│ │ SEARCH                      │ │                                            │   │
│ │ [circuit breaker_____]      │ │   def call(params) do                      │   │
│ │                             │ │     Fuse.check(:external_api)              │   │
│ │ MOST USED                   │ │     |> handle_fuse_result(params)          │   │
│ │ 1. circuit-breaker (47)     │ │   end                                      │   │
│ │ 2. repository      (42)     │ │ end                                        │   │
│ │ 3. adapter         (38)     │ │ ```                                        │   │
│ │ 4. retry           (31)     │ │                                            │   │
│ │ 5. factory         (28)     │ │ EXAMPLES: [View 3 implementations →]       │   │
│ └─────────────────────────────┴──────────────────────────────────────────────────┤
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE D: [S]earch  [N]ew Pattern  [E]dit  [C]opy Template  │  [↑↓] Navigate      │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Debug Sessions
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ZONE A: DEVELOPER KNOWLEDGE                                                      │
│ [○DEV] [○DECISIONS] [○PATTERNS] [●DEBUG] [○CODE] [○REVIEWS]      HLC: ...042   │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE B: DEBUG SESSIONS                                                           │
│ ┌────────────────────────────────────────────────────────────────────────────────┤
│ │ ACTIVE SESSION: Memory leak in WebSocket handler                  [⏱ 02:34:12]│
│ │                                                                               │
│ │ ┌─ SYMPTOM ──────────────────────────────────────────────────────────────────┐│
│ │ │ Memory usage grows unbounded when clients disconnect without proper        ││
│ │ │ close handshake. Observer shows ETS table growth.                          ││
│ │ └────────────────────────────────────────────────────────────────────────────┘│
│ │                                                                               │
│ │ ┌─ INVESTIGATION STEPS ──────────────────────────────────────────────────────┐│
│ │ │ [✓] 1. Reproduced issue with 100 abrupt disconnects                        ││
│ │ │ [✓] 2. Identified ETS table :socket_registry growing                       ││
│ │ │ [✓] 3. Found missing cleanup in terminate/2 callback                       ││
│ │ │ [●] 4. Testing fix with load simulation  ←── CURRENT                       ││
│ │ │ [ ] 5. Verify memory stable after 1 hour                                   ││
│ │ └────────────────────────────────────────────────────────────────────────────┘│
│ │                                                                               │
│ │ ┌─ FILES INVOLVED ───────────────────────────────────────────────────────────┐│
│ │ │ 📄 lib/indrajaal_web/channels/socket.ex:45-67                              ││
│ │ │ 📄 lib/indrajaal/presence/tracker.ex:112-145                               ││
│ │ │ 📄 test/channels/socket_cleanup_test.exs:1-50  [NEW]                       ││
│ │ └────────────────────────────────────────────────────────────────────────────┘│
│ │                                                                               │
│ │ ┌─ ROOT CAUSE (DRAFT) ───────────────────────────────────────────────────────┐│
│ │ │ Missing ETS entry cleanup when Process.monitor/1 DOWN message received     ││
│ │ │ without corresponding WebSocket close frame.                               ││
│ │ └────────────────────────────────────────────────────────────────────────────┘│
│ │                                                                               │
│ │ PAST SESSIONS                                                                 │
│ │ ├─ 2025-12-28: GenServer timeout in AuthCache (✓ RESOLVED, 1h 23m)           │
│ │ ├─ 2025-12-25: Race condition in job queue (✓ RESOLVED, 3h 45m)              │
│ │ └─ 2025-12-20: SSL handshake failure (✓ RESOLVED, 0h 45m)                    │
│ └────────────────────────────────────────────────────────────────────────────────┤
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE D: [N]ew Step  [R]oot Cause  [S]olution  [C]lose Session  │  [?] Help      │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. PRODUCT MANAGER PORTAL

### 3.1 Features Pipeline (Kanban)
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ZONE A: PRODUCT KNOWLEDGE                                                        │
│ [●PROD] [●FEATURES] [○RELEASES] [○FEEDBACK] [○EXPERIMENTS] [○KPIS] HLC: ...042 │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE B: FEATURE PIPELINE                                      Q4 2025           │
│ ┌────────────────────────────────────────────────────────────────────────────────┤
│ │ IDEATION(3)    │ PLANNING(4)   │ IN PROGRESS(2)│ TESTING(1)    │ RELEASED(8) │
│ │ ───────────────│───────────────│───────────────│───────────────│─────────────│
│ │ ┌────────────┐ │ ┌────────────┐│ ┌────────────┐│ ┌────────────┐│ ┌─────────┐ │
│ │ │ 🔴 CRIT    │ │ │ 🟠 HIGH    ││ │ 🟠 HIGH    ││ │ 🟡 MED     ││ │ ✓ Done  │ │
│ │ │ AI Copilot │ │ │ SSO SAML   ││ │ Dark Mode  ││ │ Export CSV ││ │ Auth 2FA│ │
│ │ │ @alice     │ │ │ @bob       ││ │ @charlie   ││ │ @dave      ││ │ v2.3.0  │ │
│ │ │ ████░░ 40% │ │ │ ██████ 60% ││ │ ████████80%││ │ ██████████ ││ └─────────┘ │
│ │ └────────────┘ │ └────────────┘│ └────────────┘│ └────────────┘│ ┌─────────┐ │
│ │ ┌────────────┐ │ ┌────────────┐│ ┌────────────┐│               │ │ ✓ Done  │ │
│ │ │ 🟡 MED     │ │ │ 🟡 MED     ││ │ 🟢 LOW     ││               │ │ Webhooks│ │
│ │ │ Mobile App │ │ │ Audit Logs ││ │ Help Tips  ││               │ │ v2.2.0  │ │
│ │ │ @eve       │ │ │ @frank     ││ │ @grace     ││               │ └─────────┘ │
│ │ │ ██░░░░ 20% │ │ │ ████░░ 45% ││ │ ██████ 65% ││               │     ...     │
│ │ └────────────┘ │ └────────────┘│ └────────────┘│               │             │
│ │ ┌────────────┐ │ ┌────────────┐│               │               │             │
│ │ │ 🟢 LOW     │ │ │ 🟢 LOW     ││               │               │             │
│ │ │ Themes     │ │ │ i18n DE/FR ││               │               │             │
│ │ │ @unassign  │ │ │ @henry     ││               │               │             │
│ │ │ ░░░░░░ 0%  │ │ │ ██░░░░ 25% ││               │               │             │
│ │ └────────────┘ │ └────────────┘│               │               │             │
│ │                │               │               │               │             │
│ └────────────────┴───────────────┴───────────────┴───────────────┴─────────────┘│
│                                                                                  │
│ VELOCITY: 4.2 features/sprint  │  CYCLE TIME: 18 days avg  │  WIP: 6/8 limit   │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE D: [N]ew Feature  [D]rag  [F]ilter  [Q]uarter  │  [←][→] Scroll  │ [?]     │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Feedback Sentiment Dashboard
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ZONE A: PRODUCT KNOWLEDGE                                                        │
│ [○PROD] [○FEATURES] [○RELEASES] [●FEEDBACK] [○EXPERIMENTS] [○KPIS] HLC: ...042 │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE B: CUSTOMER FEEDBACK                                                        │
│ ┌─────────────────────────────┬──────────────────────────────────────────────────┤
│ │ SENTIMENT OVERVIEW          │ FEEDBACK STREAM                                  │
│ │ ─────────────────────────── │ ──────────────────────────────────────────────── │
│ │                             │                                                  │
│ │    ┌───────────────────┐    │ ┌────────────────────────────────────────────┐   │
│ │    │     POSITIVE      │    │ │ 😊 "Love the new dashboard!"              │   │
│ │    │  ████████████████ │    │ │    Source: App Review  │  2h ago          │   │
│ │    │       67%         │    │ │    Feature: Dashboard Redesign            │   │
│ │    ├───────────────────┤    │ └────────────────────────────────────────────┘   │
│ │    │     NEUTRAL       │    │ ┌────────────────────────────────────────────┐   │
│ │    │  ████████░░░░░░░░ │    │ │ 😐 "Export takes too long for large..."   │   │
│ │    │       21%         │    │ │    Source: Support  │  5h ago              │   │
│ │    ├───────────────────┤    │ │    Feature: Export CSV  [LINKED]          │   │
│ │    │     NEGATIVE      │    │ └────────────────────────────────────────────┘   │
│ │    │  ████░░░░░░░░░░░░ │    │ ┌────────────────────────────────────────────┐   │
│ │    │       12%   ⚠     │    │ │ 😞 "SSO login broken after update"        │   │
│ │    └───────────────────┘    │ │    Source: Zendesk #4521  │  1d ago        │   │
│ │                             │ │    Feature: SSO SAML  [INCIDENT CREATED]   │   │
│ │ TREND (30 days)             │ └────────────────────────────────────────────┘   │
│ │ ┌─────────────────────────┐ │ ┌────────────────────────────────────────────┐   │
│ │ │ 😊 ────────────╮        │ │ │ 😊 "Finally proper keyboard shortcuts!"   │   │
│ │ │ 😐 ─────╮      ╰───     │ │ │    Source: Twitter  │  2d ago              │   │
│ │ │ 😞 ─────╰──────────     │ │ │    Feature: Accessibility                 │   │
│ │ │    W1  W2  W3  W4       │ │ └────────────────────────────────────────────┘   │
│ │ └─────────────────────────┘ │                                                  │
│ │                             │ FILTERS: [All Sources ▼] [All Features ▼]        │
│ │ TOP REQUESTED               │                                                  │
│ │ 1. Dark Mode        (47)    │ ─────────────────────────────────────────────── │
│ │ 2. Mobile App       (32)    │ Total: 234  │  Linked: 189  │  Unlinked: 45     │
│ │ 3. API Improvements (28)    │                                                  │
│ └─────────────────────────────┴──────────────────────────────────────────────────┤
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE D: [L]ink to Feature  [C]reate Incident  [T]ag  [A]rchive  │  [?] Help     │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. SRE PORTAL

### 4.1 Runbooks Dashboard
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ZONE A: SRE KNOWLEDGE                                                            │
│ [●SRE] [●RUNBOOKS] [○SLOS] [○POSTMORT] [○CHAOS] [○CHANGES] [○TOIL] HLC: ...042 │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE B: OPERATIONAL RUNBOOKS                                                     │
│ ┌─────────────────────────────┬──────────────────────────────────────────────────┤
│ │ CATEGORIES                  │ RUNBOOK: Database Failover                       │
│ │ ─────────────────────────── │ ──────────────────────────────────────────────── │
│ │ [▼] incident_response (12)  │ ┌────────────────────────────────────────────┐   │
│ │     ├─ high-cpu-alert       │ │ AUTOMATION: ████████░░ 80% SEMI-AUTO       │   │
│ │     ├─ memory-exhaustion    │ │ EST. TIME:  15 min  │  EXECUTIONS: 23       │   │
│ │     └─ db-failover     ◀──  │ │ LAST RUN:   2025-12-15 (SUCCESS)            │   │
│ │ [▼] maintenance      (8)    │ └────────────────────────────────────────────┘   │
│ │     ├─ cert-rotation        │                                                  │
│ │     └─ log-rotation         │ ┌─ STEPS ──────────────────────────────────────┐ │
│ │ [▼] deployment       (6)    │ │ [1] ● Verify replica sync status            │ │
│ │     └─ blue-green-deploy    │ │     $ pg_stat_replication                   │ │
│ │ [▼] scaling          (4)    │ │     ⚠ LAG MUST BE < 10s                     │ │
│ │ [▼] recovery         (5)    │ │                                              │ │
│ │ [▼] debugging        (7)    │ │ [2] ○ Pause application traffic             │ │
│ │ [▼] security         (3)    │ │     $ ./scripts/pause_traffic.sh            │ │
│ │                             │ │     🤖 AUTO: Can be automated                │ │
│ │ ─────────────────────────── │ │                                              │ │
│ │ QUICK ACCESS                │ │ [3] ○ Promote replica to primary            │ │
│ │ [F1] High CPU Alert         │ │     $ pg_ctl promote -D /var/lib/pg         │ │
│ │ [F2] DB Failover            │ │     ⚠ POINT OF NO RETURN                    │ │
│ │ [F3] SSL Cert Rotation      │ │                                              │ │
│ │ [F4] Service Restart        │ │ [4] ○ Update DNS/connection strings         │ │
│ │                             │ │     $ ./scripts/update_dns.sh               │ │
│ │ LINKED ALERTS               │ │     🤖 AUTO: Can be automated                │ │
│ │ • PostgresReplicaLag        │ │                                              │ │
│ │ • DatabaseConnectionPool    │ │ [5] ○ Resume traffic & verify               │ │
│ │ • DiskSpaceCritical         │ │     $ ./scripts/health_check.sh             │ │
│ │                             │ └────────────────────────────────────────────────┘│
│ └─────────────────────────────┴──────────────────────────────────────────────────┤
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE D: [E]xecute  [S]imulate  [H]istory  [A]utomate Step  │  [ESC] Back        │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 SLO Dashboard
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ZONE A: SRE KNOWLEDGE                                                            │
│ [○SRE] [○RUNBOOKS] [●SLOS] [○POSTMORT] [○CHAOS] [○CHANGES] [○TOIL] HLC: ...042 │
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE B: SERVICE LEVEL OBJECTIVES                        Window: Rolling 28d     │
│ ┌────────────────────────────────────────────────────────────────────────────────┤
│ │ SERVICE        │ INDICATOR      │ TARGET  │ CURRENT │ ERROR BUDGET │ STATUS   │
│ │ ───────────────┼────────────────┼─────────┼─────────┼──────────────┼──────────│
│ │ API Gateway    │ Availability   │ 99.95%  │ 99.97%  │ ████████ 73% │ ● HEALTHY│
│ │                │ Latency P99    │ <200ms  │ 156ms   │ ██████████100│ ● HEALTHY│
│ │ ───────────────┼────────────────┼─────────┼─────────┼──────────────┼──────────│
│ │ Auth Service   │ Availability   │ 99.99%  │ 99.98%  │ ████░░░░ 45% │ ⚠ WARN   │
│ │                │ Latency P99    │ <100ms  │ 87ms    │ ████████ 82% │ ● HEALTHY│
│ │ ───────────────┼────────────────┼─────────┼─────────┼──────────────┼──────────│
│ │ Database       │ Availability   │ 99.99%  │ 100.0%  │ ██████████100│ ● HEALTHY│
│ │                │ Query P99      │ <50ms   │ 42ms    │ ████████ 78% │ ● HEALTHY│
│ │ ───────────────┼────────────────┼─────────┼─────────┼──────────────┼──────────│
│ │ Background     │ Success Rate   │ 99.9%   │ 99.2%   │ ██░░░░░░ 22% │ 🔴 BREACH│
│ │ Jobs           │ Latency P95    │ <5min   │ 4.2min  │ ████████ 84% │ ● HEALTHY│
│ │                                                                               │
│ │ ─────────────────────── ERROR BUDGET BURN RATE ───────────────────────────── │
│ │                                                                               │
│ │ Background Jobs - ALERT: Budget exhausting 3.2x faster than expected         │
│ │ ┌─────────────────────────────────────────────────────────────────────────┐  │
│ │ │ Budget    │████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░│ 22%     │  │
│ │ │ Expected  │███████████████████████████████████████████████░░░│ 89%     │  │
│ │ │           Day 1        Day 7        Day 14       Day 21       Day 28   │  │
│ │ └─────────────────────────────────────────────────────────────────────────┘  │
│ │                                                                               │
│ │ RECENT INCIDENTS AFFECTING SLOs:                                              │
│ │ • 2025-12-28 14:32 - Job queue backlog (Budget: -8%)                         │
│ │ • 2025-12-25 09:15 - Auth service restart (Budget: -2%)                      │
│ └────────────────────────────────────────────────────────────────────────────────┤
├──────────────────────────────────────────────────────────────────────────────────┤
│ ZONE D: [D]etail  [A]lert Config  [B]udget Forecast  [H]istory  │  [?] Help     │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. F# COCKPIT KMS PANEL

### 5.1 Main KMS Panel (Tier 1 - Rich)
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│ ▓  INDRAJAAL KMS COCKPIT                              F# CEPAF v20.0.0         ▓│
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
├──────────────────────────────────────────────────────────────────────────────────┤
│ ANNUNCIATOR                                                                      │
│ ┌────┬────┬────┬────┬────┬────┬────┬─────────────────────────────────────────────┤
│ │●KMS│●ZNH│○AI │○GRP│⚠DBT│○SYN│●HLC│  1735570800.42  │  2025-12-30 18:00:00    │
│ └────┴────┴────┴────┴────┴────┴────┴─────────────────────────────────────────────┤
├──────────────────────────────────────────────────────────────────────────────────┤
│ [F1:Tree] [F2:List] [F3:Health] [F4:Entropy] [F5:Graph]      VIEW: TREE         │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   📁 root                                                                        │
│   ├── 📚 knowledge (47)                    ┌─────────────────────────────────┐   │
│   │   ├── auth-best-practices              │ SELECTED: auth-flow-adr        │   │
│   │   ├── caching-strategies               │ Type: decision                 │   │
│   │   └── ...                              │ Health: ████████████░░░░ 78%   │   │
│   ├── ⚙ process (23)                       │ Stress: ████░░░░░░░░░░░░ 22%   │   │
│   │   ├── deploy-workflow                  │ Energy: ██████████████░░ 88%   │   │
│   │   └── review-workflow                  │ Cohere: ████████████████ 96%   │   │
│   ├── 📝 decision (31) ◀                   ├─────────────────────────────────┤   │
│   │   ├── auth-flow-adr ●                  │ PAYLOAD PREVIEW                │   │
│   │   ├── cache-strategy                   │ {                              │   │
│   │   └── api-versioning                   │   "title": "JWT Auth Flow",   │   │
│   ├── 🏗 architecture (12)                 │   "status": "accepted",       │   │
│   ├── ⚠ debt (12)                          │   "decision": "Use RS256..."  │   │
│   └── 📡 radar (6)                         │ }                              │   │
│                                            └─────────────────────────────────┘   │
│                                                                                  │
│ ─────────────────────────────────────────────────────────────────────────────── │
│ STATS: Total: 139 │ Stale: 4 │ Orphans: 2 │ Events/hr: 23 │ Zenoh: CONNECTED    │
├──────────────────────────────────────────────────────────────────────────────────┤
│ [N]ew [E]dit [D]el [S]earch [R]efresh │ [↑↓] Navigate [←→] Expand │ [Q]uit      │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Health View (Tier 1 - Rich)
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ▓▓▓  KMS HEALTH DASHBOARD  ▓▓▓                                   F# CEPAF      ▓│
├──────────────────────────────────────────────────────────────────────────────────┤
│ ANNUNCIATOR: [●KMS] [●ZNH] [○AI] [⚠DBT:12] [●HLC]      2025-12-30 18:00:00      │
├──────────────────────────────────────────────────────────────────────────────────┤
│ [F1:Tree] [F2:List] [F3:Health]● [F4:Entropy] [F5:Graph]     VIEW: HEALTH       │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  🏥 SYSTEM HEALTH                                                                │
│  ──────────────────────────────────────────                                      │
│                                                                                  │
│  Overall:       [████████████████████░░░░░░░░░░] 68%                            │
│                                                                                  │
│  VITAL SIGNS BY TYPE                                                             │
│  ────────────────────────────────────────────────────────────────────────────── │
│                                                                                  │
│  knowledge      [████████████████░░░░] 82%   ●                                   │
│  process        [██████████████░░░░░░] 71%   ●                                   │
│  agent          [████████████████████] 98%   ●                                   │
│  decision       [██████████████████░░] 89%   ●                                   │
│  architecture   [████████████░░░░░░░░] 64%   ⚠  LOW                              │
│  debt           [████████░░░░░░░░░░░░] 45%   ⚠  LOW                              │
│  artifact       [██████████████████░░] 91%   ●                                   │
│  radar          [████████████████░░░░] 81%   ●                                   │
│                                                                                  │
│  ─────────────────────────────────────────────────────────────────────────────  │
│                                                                                  │
│  📊 HEALTH TREND (7 days)                                                        │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │  90%│                                        ╭───────────────────          │ │
│  │     │                              ╭────────╯                              │ │
│  │  80%│                    ╭────────╯                                        │ │
│  │     │          ╭────────╯                                                  │ │
│  │  70%│╭────────╯                                                            │ │
│  │     │                                                                      │ │
│  │  60%└────────┬────────┬────────┬────────┬────────┬────────┬────────        │ │
│  │             Mon      Tue      Wed      Thu      Fri      Sat      Sun      │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
├──────────────────────────────────────────────────────────────────────────────────┤
│ [R]efresh [G]arden [E]xport │ Auto-refresh: ON (10s) │ [Q]uit                    │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Entropy View (Tier 1 - Rich)
```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ▓▓▓  KMS ENTROPY REPORT  ▓▓▓                                     F# CEPAF      ▓│
├──────────────────────────────────────────────────────────────────────────────────┤
│ ANNUNCIATOR: [●KMS] [●ZNH] [⚠ENTROPY:HIGH] [●HLC]      2025-12-30 18:00:00      │
├──────────────────────────────────────────────────────────────────────────────────┤
│ [F1:Tree] [F2:List] [F3:Health] [F4:Entropy]● [F5:Graph]     VIEW: ENTROPY      │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ⚠ ENTROPY ANALYSIS                           Entropy Score: 0.34 (ELEVATED)    │
│  ──────────────────────────────────────────                                      │
│                                                                                  │
│  ┌─ STALE HOLONS (>90 days) ───────────────────────────────────────────────────┐│
│  │ #  │ NAME                      │ TYPE       │ AGE      │ LAST UPDATE        ││
│  │────┼───────────────────────────┼────────────┼──────────┼────────────────────││
│  │ 1  │ legacy-api-spec           │ artifact   │ 156 days │ 2025-07-27         ││
│  │ 2  │ old-deployment-guide      │ knowledge  │ 127 days │ 2025-08-25         ││
│  │ 3  │ deprecated-auth-flow      │ decision   │ 104 days │ 2025-09-17         ││
│  │ 4  │ v1-migration-notes        │ knowledge  │  92 days │ 2025-09-29         ││
│  └────┴───────────────────────────┴────────────┴──────────┴────────────────────┘│
│                                                                                  │
│  ┌─ ORPHANED HOLONS (no parent, no children) ─────────────────────────────────┐ │
│  │ #  │ NAME                      │ TYPE       │ CREATED                       │ │
│  │────┼───────────────────────────┼────────────┼───────────────────────────────│ │
│  │ 1  │ standalone-note-1         │ knowledge  │ 2025-11-15                    │ │
│  │ 2  │ unlinked-diagram-2        │ artifact   │ 2025-10-30                    │ │
│  └────┴───────────────────────────┴────────────┴───────────────────────────────┘ │
│                                                                                  │
│  ┌─ RECOMMENDED ACTIONS ──────────────────────────────────────────────────────┐ │
│  │ • Archive 4 stale holons to reduce entropy                                 │ │
│  │ • Link 2 orphaned holons to appropriate parents                            │ │
│  │ • Review decision "deprecated-auth-flow" - consider superseding           │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
├──────────────────────────────────────────────────────────────────────────────────┤
│ [G]arden All  [A]rchive Selected  [L]ink Orphan  │  [↑↓] Select │ [Q]uit        │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 5.4 Tier 3 Fallback (ASCII Only)
```
+------------------------------------------------------------------------------+
| KMS COCKPIT - EMERGENCY MODE (ASCII)                         CEPAF v20.0.0   |
+------------------------------------------------------------------------------+
| STATUS: [*KMS] [*ZNH] [ AI] [!DBT:12] [*HLC]       2025-12-30 18:00:00       |
+------------------------------------------------------------------------------+
| [F1:Tree] [F2:List] [F3:Health] [F4:Entropy]                  VIEW: TREE     |
+------------------------------------------------------------------------------+
|                                                                              |
|   [+] root                                                                   |
|   |-- [+] knowledge (47)                                                     |
|   |-- [-] process (23)                                                       |
|   |   |-- deploy-workflow                                                    |
|   |   +-- review-workflow                                                    |
|   |-- [-] decision (31)                                                      |
|   |   |-- auth-flow-adr    <-- SELECTED                                      |
|   |   +-- cache-strategy                                                     |
|   |-- [+] architecture (12)                                                  |
|   |-- [+] debt (12)                                                          |
|   +-- [+] radar (6)                                                          |
|                                                                              |
|   DETAIL: auth-flow-adr                                                      |
|   Type: decision    Health: [========..] 78%                                 |
|   Status: accepted  Stress: [==........] 22%                                 |
|                                                                              |
+------------------------------------------------------------------------------+
| [N]ew [E]dit [D]el [S]earch | [Up/Dn] Navigate | [Q]uit                      |
+------------------------------------------------------------------------------+
```

---

## 6. ARM & FIRE PROTOCOL - DESTRUCTIVE ACTIONS

### 6.1 Delete Holon FSM
```
STATE 1: IDLE (Default)
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ZONE D: CONTROL SURFACE                                                          │
│ ┌────────────────────────────────────────────────────────────────────────────────┤
│ │ [N]ew Holon  [E]dit  [D]elete  [S]earch  │  Selected: auth-flow-adr           │
│ └────────────────────────────────────────────────────────────────────────────────┤
└──────────────────────────────────────────────────────────────────────────────────┘

STATE 2: ARMED (After pressing [D])
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│ ▓                              ⚠ DELETE ARMED ⚠                               ▓│
│ ▓                                                                              ▓│
│ ▓   Holon: auth-flow-adr                                                       ▓│
│ ▓   Type:  decision                                                            ▓│
│ ▓   Children: 3 (will be orphaned)                                             ▓│
│ ▓                                                                              ▓│
│ ▓   ┌────────────────────────────────────────────────────────────────────┐     ▓│
│ ▓   │                    READY TO FIRE                                   │     ▓│
│ ▓   │         Hold [SPACE] for 3 seconds to confirm delete               │     ▓│
│ ▓   │                                                                    │     ▓│
│ ▓   │   [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░]  0%        │     ▓│
│ ▓   │                                                                    │     ▓│
│ ▓   │         [ESC] to cancel    Auto-cancel in: 10s                     │     ▓│
│ ▓   └────────────────────────────────────────────────────────────────────┘     ▓│
│ ▓                                                                              ▓│
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
└──────────────────────────────────────────────────────────────────────────────────┘

STATE 3: FIRING (Holding [SPACE])
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│ ▓                              🔴 FIRING 🔴                                    ▓│
│ ▓                                                                              ▓│
│ ▓   Holon: auth-flow-adr                                                       ▓│
│ ▓                                                                              ▓│
│ ▓   ┌────────────────────────────────────────────────────────────────────┐     ▓│
│ ▓   │                       DELETING...                                  │     ▓│
│ ▓   │                                                                    │     ▓│
│ ▓   │   [████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░]  52%       │     ▓│
│ ▓   │                                                                    │     ▓│
│ ▓   │         Keep holding [SPACE] - release to cancel                   │     ▓│
│ ▓   └────────────────────────────────────────────────────────────────────┘     ▓│
│ ▓                                                                              ▓│
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
└──────────────────────────────────────────────────────────────────────────────────┘

STATE 4: ENGAGED (Action executed)
┌──────────────────────────────────────────────────────────────────────────────────┐
│ █████████████████████████████████████████████████████████████████████████████████│
│ █                            ✓ DELETED                                         █│
│ █                                                                              █│
│ █   Holon "auth-flow-adr" has been permanently deleted.                        █│
│ █   3 children have been orphaned.                                             █│
│ █                                                                              █│
│ █   Press any key to continue...                                               █│
│ █████████████████████████████████████████████████████████████████████████████████│
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. USER JOURNEYS

### 7.1 Developer Journey: Creating an ADR
```
FLOW: Developer creates Architecture Decision Record

[1] Navigate to Developer Portal
    └─→ Press [D] or click "DECISIONS" tab

[2] Create New Decision
    └─→ Press [N] for "New Decision"
    └─→ Select type: [ADR ▼]

[3] Fill Decision Form
    ┌─────────────────────────────────────────────────────┐
    │ NEW ARCHITECTURE DECISION RECORD                    │
    │ ─────────────────────────────────────────────────── │
    │ Title:    [GraphQL Federation Strategy_________]    │
    │ Status:   [proposed ▼]                              │
    │ Author:   [@alice - auto]                           │
    │ ─────────────────────────────────────────────────── │
    │ Context:                                            │
    │ [We need to scale our GraphQL API across______]     │
    │ [multiple services while maintaining a unified]     │
    │ [schema for clients._________________________]      │
    │ ─────────────────────────────────────────────────── │
    │ Decision:                                           │
    │ [Adopt Apollo Federation 2.0 with subgraph___]      │
    │ [per domain (Users, Orders, Products)._______]      │
    │ ─────────────────────────────────────────────────── │
    │ Consequences:                                       │
    │ [+ Team autonomy for schema changes__________]      │
    │ [- Additional operational complexity_________]      │
    │ ─────────────────────────────────────────────────── │
    │         [Cancel]  [Save Draft]  [Submit for Review] │
    └─────────────────────────────────────────────────────┘

[4] Link to Code (Optional)
    └─→ Press [L] for "Link Code"
    └─→ Enter file path: lib/indrajaal/graphql/federation.ex
    └─→ Select link type: [IMPLEMENTS ▼]

[5] Submit for Review
    └─→ Press [S] or click "Submit"
    └─→ Zenoh broadcasts: indrajaal/kms/holons/created
    └─→ F# Cockpit receives update in <100ms
```

### 7.2 SRE Journey: Executing Runbook
```
FLOW: SRE executes database failover runbook

[1] Alert Triggers
    ┌─────────────────────────────────────────────────────┐
    │ 🔴 ALERT: PostgresReplicaLag > 30s                  │
    │    Service: indrajaal-db                            │
    │    Current: 45s  │  Threshold: 30s                  │
    │                                                     │
    │    [View Runbook]  [Acknowledge]  [Silence]         │
    └─────────────────────────────────────────────────────┘

[2] Navigate to Runbook
    └─→ Click "View Runbook" or press [F2]
    └─→ Runbook: "Database Failover" auto-selected

[3] Execute Runbook
    └─→ Press [E] for "Execute"
    └─→ ARM & FIRE protocol activates

[4] Step-by-Step Execution
    ┌─────────────────────────────────────────────────────┐
    │ RUNBOOK EXECUTION: Database Failover                │
    │ ─────────────────────────────────────────────────── │
    │ [✓] Step 1: Verify replica sync status              │
    │     Output: Lag = 0.5s (ACCEPTABLE)                 │
    │                                                     │
    │ [●] Step 2: Pause application traffic      RUNNING  │
    │     ████████████░░░░░░░░ 60%                        │
    │                                                     │
    │ [ ] Step 3: Promote replica to primary              │
    │ [ ] Step 4: Update DNS/connection strings           │
    │ [ ] Step 5: Resume traffic & verify                 │
    │ ─────────────────────────────────────────────────── │
    │ [Pause]  [Skip Step]  [Abort Runbook]               │
    └─────────────────────────────────────────────────────┘

[5] Completion
    └─→ All steps completed
    └─→ Execution logged to KMS
    └─→ Incident auto-created if errors occurred
```

### 7.3 Product Manager Journey: Analyzing Feedback
```
FLOW: PM analyzes customer feedback sentiment

[1] Navigate to Product Portal
    └─→ Press [P] or click "PRODUCT" tab
    └─→ Select "FEEDBACK" view

[2] Review Sentiment Overview
    └─→ See pie chart: 67% Positive, 21% Neutral, 12% Negative
    └─→ Notice trend: Negative ↑ 3% this week

[3] Filter Negative Feedback
    └─→ Click sentiment filter: [Negative only]
    └─→ Sort by: [Most Recent ▼]

[4] Link Feedback to Feature
    ┌─────────────────────────────────────────────────────┐
    │ FEEDBACK: "SSO login broken after update"           │
    │ ─────────────────────────────────────────────────── │
    │ Source:   Zendesk #4521                             │
    │ Sentiment: 😞 Negative                               │
    │ ─────────────────────────────────────────────────── │
    │ Link to Feature:                                    │
    │ [Search features...____________]                    │
    │                                                     │
    │ Suggested matches:                                  │
    │ ● SSO SAML Integration (92% match)                  │
    │ ○ Authentication 2FA (45% match)                    │
    │ ─────────────────────────────────────────────────── │
    │         [Cancel]  [Link Selected]  [Create Incident]│
    └─────────────────────────────────────────────────────┘

[5] Create Incident (if critical)
    └─→ Press [I] for "Create Incident"
    └─→ Incident auto-populates from feedback
    └─→ Linked to feature: "SSO SAML Integration"
    └─→ SRE notified via Zenoh broadcast
```

---

## 8. TESTING SPECIFICATIONS

### 8.1 Property-Based Tests (FsCheck)
```fsharp
// KMS State Machine Properties

[<Property>]
let ``Arm & Fire: Cannot transition from Idle to Engaged directly``
    (inputs: ActionInput list) =
    let finalState = inputs |> List.fold applyAction Idle
    match finalState with
    | Engaged ->
        inputs |> List.exists (fun i -> i = ArmAction)  // Must have armed first
    | _ -> true

[<Property>]
let ``Holon health is always between 0 and 1``
    (holons: Holon list) =
    holons |> List.forall (fun h ->
        h.VitalSigns.Health >= 0.0 && h.VitalSigns.Health <= 1.0)

[<Property>]
let ``Search results are sorted by score descending``
    (query: string) =
    let results = KmsSearch.execute query
    let scores = results |> List.map (fun r -> r.Score)
    scores = (scores |> List.sortDescending)
```

### 8.2 Visual Regression (VHS Script)
```tape
# KMS Dashboard Visual Test
Output kms_dashboard_test.gif

Set Shell "bash"
Set FontSize 14
Set Width 1200
Set Height 800

Type "dotnet fsi lib/cepaf/scripts/CockpitOperations.fsx status"
Enter
Sleep 2s

# Navigate to KMS Panel
Type "k"
Sleep 500ms

# Expand tree
Type "j"  # Down
Sleep 200ms
Type "l"  # Expand
Sleep 200ms

# Switch to Health view
Type "3"  # F3 equivalent
Sleep 1s

# Screenshot checkpoint
Screenshot kms_health_view.png

# Switch to Entropy view
Type "4"  # F4 equivalent
Sleep 1s

Screenshot kms_entropy_view.png
```

### 8.3 Chaos Tests (Elixir)
```elixir
# Test KMS GenServer resilience

defmodule Indrajaal.KMS.ChaosTest do
  use ExUnit.Case, async: false

  describe "Supervisor resilience" do
    test "KMS Store restarts within 50ms after crash" do
      pid = Process.whereis(Indrajaal.KMS.Store)
      ref = Process.monitor(pid)

      # Kill the process
      Process.exit(pid, :kill)

      # Wait for DOWN message
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 100

      # Verify restart
      :timer.sleep(50)
      new_pid = Process.whereis(Indrajaal.KMS.Store)
      assert new_pid != nil
      assert new_pid != pid
    end

    test "Zenoh publisher reconnects after network partition" do
      # Simulate network partition
      :ok = ZenohTestHelper.simulate_partition(5_000)

      # Verify recovery
      assert {:ok, _} = Indrajaal.KMS.ZenohKmsPublisher.health_check()
    end
  end
end
```

---

## Document Control

| Version | Date       | Author    | Changes                          |
|---------|------------|-----------|----------------------------------|
| 1.0.0   | 2025-12-30 | Claude    | Initial wireframes document      |

**Compliance**: SC-HMI-001, SC-KMS-005, NASA-STD-3000, NUREG-0700
**Framework**: SOPv5.11 + STAMP + TDG + Dark Cockpit Philosophy
