# Fractal TPS & Muda Protocol (SC-TPS-FRACTAL)
# भग्नात्मक टीपीएस एवं मुदा प्रोतोकॉल

## Supreme Mandate (सर्वोच्च आदेश)
**Toyota Production System principles MUST be applied at EVERY fractal layer (L0-L7).**
**Muda (waste) MUST be eliminated continuously — a codebase with waste is degraded.**
> "Do nothing which is of no use." — Miyamoto Musashi (五輪書)
> "निष्कामकर्म" — Action without waste (Gita 3.19)

## The 7 Wastes Mapped to Fractal Layers (सात अपव्यय)

| # | Waste (मुदा) | Japanese | Sanskrit | Fractal Mapping | Detection | Elimination |
|---|-------------|----------|----------|-----------------|-----------|-------------|
| 1 | **Overproduction** | 造りすぎ | अतिउत्पादन | L5: Writing speculative code | Files not referenced by tests | Delete unused code immediately |
| 2 | **Waiting** | 手待ち | प्रतीक्षा | L4: Human approval blocking | OODA wait_time > 0 for safe ops | Gita protocol: act autonomously |
| 3 | **Transport** | 運搬 | परिवहन | L6: Unnecessary serialization | HTTP between internal components | Zenoh pub/sub (SC-ZMOF-001) |
| 4 | **Extra Processing** | 加工 | अतिसंस्करण | L3: Redundant parsing/validation | Same data parsed twice | Cache with OnceLock/memoize |
| 5 | **Inventory** | 在庫 | भण्डार | L2: Dead code, unused imports | Compiler warnings | Zero warnings gate (SC-MUDA-001) |
| 6 | **Motion** | 動作 | गति | L1: Agent reads 3671-line file to edit 10 | file_size > 1000 lines | Split files (SC-FILESIZE-001) |
| 7 | **Defects** | 不良品 | दोष | L0: Bugs reaching production | Test failures, regressions | Jidoka: auto-test after every edit |

## Fractal TPS Principles (भग्नात्मक सिद्धान्त)

### 1. Jidoka (自働化) — Stop on Defect (दोष पर रुकें)
```
∀ edit E to .gleam file:
  build(E) must succeed → else STOP
  test(E) should succeed → else WARN
  
Implementation: PostToolUse hook runs gleam build after Write|Edit
Future: Chain gleam test after successful build
```

### 2. Kanban (看板) — Pull System (खींचो प्रणाली)
```
∀ task T:
  T.status ∈ {pending, in_progress, completed, blocked}
  |{T : T.status = in_progress}| ≤ WIP_LIMIT (= 3 for single agent)
  
Implementation: sa-plan-daemon task management
Pull: Agent claims next P0 pending task, never pushes
```

### 3. Kaizen (改善) — Continuous Improvement (निरंतर सुधार)
```
∀ session S:
  quality(S_end) > quality(S_start)
  Where quality = tests_passing × coverage × H_entropy
  
Implementation: Memory records patterns, Zettelkasten stores learnings
Each session MUST produce at least 1 improvement (SC-ZETTEL-001)
```

### 4. Heijunka (平準化) — Load Leveling (भार संतुलन)
```
∀ agent set A = {a₁, a₂, ..., aₙ}:
  workload(aᵢ) ≈ workload(aⱼ) for all i,j
  CPU_total ≤ 85% (SC-CPU-GOV)
  
Implementation: /fast-evolve dispatches 6 agents with balanced work
CPU governor throttles when > 85%
```

### 5. Poka-Yoke (ポカヨケ) — Error Proofing (दोष निवारण)
```
∀ Model type change M:
  wiring_guard.gleam MUST be updated (SC-WIRE-001)
  init() constructors MUST be used in tests (SC-WIRE-007)
  
Implementation: Wiring guard catches ALL constructor breaks at compile time
95 verified connections across 33 pages
```

### 6. Andon (アンドン) — Signal Board (संकेत पट्ट)
```
Dashboard weather bar = system Andon:
  Dark (score ≥ 0.9): All nominal — suppress noise
  Dim (≥ 0.7): Minor issues — subtle alert
  Normal (≥ 0.5): Standard visibility
  Bright (≥ 0.3): High visibility — attention needed
  Emergency (< 0.3): Full alert — Jidoka cord pulled

Implementation: Cockpit mode in dashboard_view + dashboard-grid.js
```

### 7. Genchi Genbutsu (現地現物) — Go and See (जाओ और देखो)
```
∀ decision D:
  D must be based on OBSERVED data, not assumptions
  source(D) ∈ {NIF_data, Zenoh_telemetry, gleam_test_output}
  source(D) ∉ {assumption, cached_from_prior_session, hardcoded}
  
Implementation: Dashboard WS pushes live NIF data every 1s
Memory is verified against current state before use
```

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-TPS-001 | Jidoka: auto-build after every .gleam edit | HIGH |
| SC-TPS-002 | Kanban: WIP limit 3 for single agent operations | MEDIUM |
| SC-TPS-003 | Kaizen: every session MUST improve system quality | HIGH |
| SC-TPS-004 | Heijunka: agent workload balanced across parallel dispatch | MEDIUM |
| SC-TPS-005 | Poka-yoke: wiring guard prevents constructor breaks | CRITICAL |
| SC-TPS-006 | Andon: dashboard weather bar reflects true system state | HIGH |
| SC-TPS-007 | Genchi genbutsu: decisions based on observed data only | HIGH |
| SC-MUDA-F-001 | Zero dead code at every fractal layer | HIGH |
| SC-MUDA-F-002 | Zero unused imports | HIGH |
| SC-MUDA-F-003 | No file > 1000 lines (SC-FILESIZE-001) | HIGH |
| SC-MUDA-F-004 | No redundant parsing (cache or memoize) | MEDIUM |
| SC-MUDA-F-005 | No HTTP between internal components (use Zenoh) | HIGH |
| SC-MUDA-F-006 | No human wait for non-safety operations | HIGH |
| SC-MUDA-F-007 | No speculative code (only implement what's needed) | MEDIUM |

## Velocity Formula (गति सूत्र)
```
V_tps = (value_delivered / time_elapsed) × (1 - waste_ratio)

Where waste_ratio = Σ(waste_time_i) / total_time
  waste_time = waiting + transport + overprocessing + motion + defect_fixing

Target: waste_ratio < 0.15 (85%+ value delivery)
Current estimate: waste_ratio ≈ 0.40 (60% value delivery)
Goal: 2.1x throughput improvement via Muda elimination
```
