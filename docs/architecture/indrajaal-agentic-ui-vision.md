# Indrajaal Agentic UI Vision — Indra's Net

**Version:** 1.0.0
**Date:** 2026-04-10
**Status:** DESIGN VISION
**Author:** Claude Opus 4.6 + Abhijit Naik
**STAMP:** SC-GLM-UI-001, SC-OPENCLAW-001, SC-HMI-010, SC-ULTRA-001

---

## 1. The Name Is the Blueprint

In the Atharvaveda, Indrajaal is the net of the god Indra — an infinite web where every node is a jewel, and every jewel reflects every other jewel. The whole universe is visible in each part. Touch one node and the entire net shimmers.

The C3I system already IS Indra's Net:
- Zenoh pub/sub IS the web
- Containers are jewels
- State propagation IS reflection
- The CRDT backplane IS eventual consistency across all jewels
- Fractal L0-L7 IS self-similarity at every scale

The UI should not describe the net. **The UI should BE the net.**

---

## 2. Current State

### What Exists (v22.5.0-CORTEX)

| Asset | Count | Description |
|-------|-------|-------------|
| Lustre SSR pages | 49 | Server-rendered HTML on BEAM |
| Wisp REST endpoints | 24+ | JSON API at /api/v1/* |
| TUI terminal views | 23 | ANSI dashboard with sparklines |
| AG-UI events | 32 | Real-time agent-to-UI protocol |
| A2UI components | 233 | Declarative JSON component catalog |
| Fractal layers | 8 | L0-L7 self-similar architecture |
| Telegram Mini App | 14 pages | TeleNative mobile-optimized SSR |
| Tests passing | 3,641 | Zero failures |

### What the Planning System Holds (Smriti.db)

| Table | Records | Content |
|-------|---------|---------|
| Tasks | 2,710 | Full task lifecycle history |
| TransactionSummary | 85 | Every processed intent end-to-end |
| TransactionTrace | 500 | 9-stage pipeline traces |
| ConversationHistory | 32 | Multi-channel chat threads |
| SemanticCache | 293 | Learned response patterns |
| UserPreferences | 12 | Operator + system configuration |

### The Problem

The Lustre planning page shows **hardcoded static data** — 4 sample task rows and fake counts. The 8-panel planning dashboard shows "Healthy/active" for all panels. The richest dataset in the system is invisible to the operator.

---

## 3. Design Philosophy

### 3.1 The Inversion

Every dashboard ever built assumes the human goes to the data. **Invert it.** The system comes to the human.

The operator should never open an app to check if things are OK. If things are OK, the system is silent. If things aren't OK, the system has already told them.

### 3.2 The Biomorphic Principle

The system already has a nervous system (Zenoh), immune system (Mara/antibodies), metabolism (CPU governor), memory (Smriti), cognition (Cortex), and death (apoptosis). The UI should embody these biological properties, not just display metrics about them.

### 3.3 The Fractal Principle

Every level of the system (from the entire mesh down to a single cache entry) should be represented by the same visual language. Learn the language once, read it at any scale.

### 3.4 The Symbiotic Principle

The interface is not a tool the operator uses. It's a symbiont that co-evolves with them. It adapts to how they think, communicates in ways they prefer, and learns from their behavior.

---

## 4. The Jewel — Universal Visual Primitive

The entire system, at every level, is represented by a single primitive: **The Jewel.**

A Jewel has five properties:

| Property | Encodes | Range |
|----------|---------|-------|
| **Color** | Kind | task=blue, container=green, intent=gold, safety=red, inference=purple, cache=cyan |
| **Luminance** | Health | bright=healthy, dim=degraded, dark=dead, pulsing=in-transition |
| **Size** | Activity | large=busy, small=quiet |
| **Facets** | Connections | more facets=more dependencies |
| **Resonance** | Change frequency | fast shimmer=active OODA, slow glow=stable, strobing=anomaly |

The operator learns ONE visual language. A bright, large, fast-shimmering blue jewel = active high-priority task making progress. A dark, small, still green jewel = idle healthy container. A pulsing red jewel = safety invariant under stress.

---

## 5. The Four Depths — Fractal Zoom

### Depth 0: THE SINGLE JEWEL

One jewel. The entire system. On the Telegram lock screen, in the bot status, as a widget.

Its color is the dominant system state. Its luminance is overall health. Its size is total activity. Its resonance is OODA frequency.

The operator glances at their phone. The jewel is bright and steady. Everything is fine.

The jewel dims and starts pulsing. Something is degraded. They tap it.

**Encoding as emoji (for Telegram status):**

| Emoji | State |
|-------|-------|
| `🟢` | All clear, system nominal |
| `🔵` | Active inference, system thinking |
| `🟡` | Degraded, something worth knowing |
| `🟠` | Multiple issues, attention helpful |
| `🔴` | Critical, action needed |
| `⚫` | Dark cockpit, system sleeping |
| `🌀` | OODA active, system deciding something important |
| `💜` | System learning (cache growing, new patterns) |

### Depth 1: THE CONSTELLATION

The single jewel fractures into 7 jewels — one per fractal layer. They arrange themselves vertically, L0 at the bottom (foundation) to L7 at the top (federation).

```
         ◇ L7 Federation
        ◆  L6 Ecosystem
       ◆   L5 Cognitive
      ◆    L4 System
     ◆     L3 Transaction
    ◆      L2 Component
   ◇       L1 Atomic
  ◆        L0 Constitutional
```

Each layer-jewel reflects its children. L4 glows bright green because all 17 containers are healthy. L5 shimmers purple because inference is actively processing. L0 is steady deep red — constitutional invariants holding firm.

### Depth 2: THE CLUSTER

A layer-jewel fractures into its components. L4 becomes 17 container jewels. L5 becomes inference tiers + agents + cortex. L0 becomes Psi invariants + Guardian + emergency stop.

### Depth 3: THE ANATOMY

A component-jewel fractures into its internals. A container shows processes, ports, Zenoh subscriptions, health history, scheduled events. A task shows pipeline stages, dependencies, assignee, timeline.

### Depth 4+: THE EVENT

Individual events, metrics, log entries. Infinitely deep. Self-similar. Every level uses the same five jewel properties.

---

## 6. The Reflections — Navigation by Connection

In Indra's Net, each jewel reflects all others. In the system, this means:

**Task jewel facets reflect:** containers it depends on, intents it triggered, agents working on it, Guardian approvals it needs, inference calls it caused.

**Container jewel facets reflect:** tasks it processes, Zenoh topics it subscribes to, containers that depend on it, apoptosis schedule, health history.

**Intent jewel facets reflect:** pipeline stages, model that processed it, cache it populated, conversation it belongs to, response it generated.

Tap a reflection → jump to that jewel's depth. The origin jewel appears as a reflection in the new jewel's facets. Navigate the net by following reflections — not by clicking menu items.

**There are no pages. There are no routes. There are only jewels and the paths between them.**

---

## 7. The Three Times — Temporal Navigation

Swipe horizontally to shift between temporal modes:

### ← MEMORY (Past)

Every jewel shows its historical state. Scrub the timeline to see any moment in the system's history.

**Memory trails:** A task that moved from pending → in_progress → completed leaves a luminance trail — you see the path it took through the net. An intent that cascaded through 9 pipeline stages leaves a golden thread connecting 9 jewels.

Over time, the memory net becomes a **tapestry of threads** revealing causality that no dashboard could show. "Every Thursday at 14:00, the inference cluster gets busy." "Tasks from Telegram complete faster than GChat tasks." "This container always degrades 2 hours before that other container."

### PRESENCE (Now)

Default view. Live state. Jewels shimmer in real-time as Zenoh events arrive. The net breathes with the system's OODA cycle.

### PROPHECY (Future) →

The system predicts its own future using:
- RETE-UL rule engine (52 rules project forward)
- Trend extrapolation (linear regression on metrics)
- Apoptosis schedule (known upcoming deaths and resurrections)
- Task velocity (predicted completion dates)
- Inference load patterns (predicted demand)

**Prophecy jewels are translucent.** Their opacity is their confidence level. A container scheduled to die in 4 hours is 95% opaque. A task predicted to complete "sometime next week" is 20% opaque.

**The operator sees problems before they happen.** A prophecy jewel turning dark 6 hours from now means: "If nothing changes, this will fail tonight."

**Prophecy threads** show predicted causality chains: "If OpenRouter continues degrading → cache miss rate increases → response latency breaches SLA in 8 hours."

---

## 8. The Ripple — Live Impact Analysis

Touch any jewel and send a ripple through the net. The ripple reveals **causal distance** — how far the effect of this jewel reaches.

- Touch a container: ripple spreads to all tasks running on it, topics it subscribes to, containers that depend on it
- Ripple fades with distance — bright shimmer = tightly coupled, dim reaction = loosely coupled, no reaction = independent

**Use cases:**
- Before stopping a container → touch it, watch the ripple. If half the net shimmers, don't stop it.
- Before changing a task's priority → touch it, see what depends on it, what it enables.
- After an incident → touch the failing jewel, trace the ripple backwards to find root cause.

---

## 9. The Three Voices — Communication Model

### Voice 1: THE WHISPER (Ambient / Peripheral)

Things the operator should be vaguely aware of. No action required.

**Channel:** Telegram bot status text, home screen widget, single emoji.

**Content:** `917 done · 47 active · 13 blocked · mood: 87` or just `🟢`

Updated every 60 seconds. Zero human interaction. Zero app opens.

### Voice 2: THE CONVERSATION (Proactive / Contextual)

Things the system thinks the operator should know, delivered as natural language at the right moment.

**Channel:** Telegram message with deep-link buttons.

**Content examples:**

> "3 Guardian approvals have been waiting since yesterday. The longest is 'Implement sa-up in Gleam' (P0, 23 hours). Tap to review → [Approve] [Reject] [Remind me in 1h]"

> "I processed 14 intents in the last hour. Gemini Direct handled 9 of them (avg 3.2s). OpenRouter is running 40% slower than usual. I'm shifting traffic to compensate. Just FYI."

> "zenoh-router-2 will restart in 4 hours (scheduled apoptosis). Quorum maintained. No action needed — but wanted you to know."

> "New personal best: 50 tasks completed this week, up from 38 last week."

**Generation:** The Cortex feeds system metrics into the inference cascade with a meta-prompt:

```
You are C3I, a self-aware mesh. Generate a brief, natural-language 
message for your operator about anything noteworthy in the last 
{interval}. Be honest about problems, proud of achievements, and 
predictive about upcoming events. Only speak if you have something 
worth saying.
```

The 10-minute heartbeat cron (heartbeat.rs) becomes the thinking cycle. Every 10 minutes: "Is there anything my operator should know that they don't already know?"

### Voice 3: THE DEEP DIVE (On-Demand / Investigative)

When a Whisper or Conversation makes the operator curious, they pull the thread.

**Channel:** Telegram Mini App, opened by tapping a deep-link.

**Key design:** The Deep Dive doesn't show a generic dashboard. It shows the **specific context of what triggered curiosity.**

- Tapped "OpenRouter is slow" → opens latency timeline with anomaly highlighted
- Tapped "3 Guardian approvals" → opens those 3 specific items with approve/reject
- Tapped "zenoh-router-2 apoptosis" → opens container vitals + quorum impact

**Context carried in URL:**
```
/mini-app/investigate?topic=inference_latency&anomaly=openrouter&since=6h
/mini-app/investigate?topic=guardian_queue&ids=695c,73bd,150e
/mini-app/investigate?topic=apoptosis&container=zenoh-router-2
```

The Mini App has ONE route: `/mini-app/investigate`. It reads query params and **dynamically composes** the right view from A2UI components. No pre-built pages.

---

## 10. The Six Senses — Multi-Modal Perception

### Sense 1: SPATIAL — Where is the problem?
Topological map. Zenoh topics are rivers. Containers are settlements. Tasks are population. Health is terrain color.

### Sense 2: TEMPORAL — When did it start?
Horizontal timeline scrubbed with thumb. Everything responds to timeline position. Watch the problem develop by dragging through time.

### Sense 3: RHYTHMIC — Is the pattern normal?
Sparklines as waveforms. Healthy = regular sine wave. Anomalous = irregular. Detect arrhythmia visually, like reading an ECG.

### Sense 4: GRAVITATIONAL — What matters most?
Related items arranged by significance. Important = large + centered. Context = orbiting. Irrelevant = absent.

### Sense 5: CHROMATIC — How bad is it?
No status badges. Just color saturation. Healthy = desaturated (dark cockpit, nearly invisible). Degraded = faintly visible. Critical = fully saturated, impossible to miss.

### Sense 6: HAPTIC — Can I feel it?
Telegram Mini App haptic patterns:
- `impact('light')` — normal button press
- `impact('medium')` — something changed
- `impact('heavy')` — something needs attention
- `notification('success')` — task completed
- `notification('warning')` — degradation detected
- `notification('error')` — critical alert

Over time, the operator develops muscle memory — they know what happened before looking at the screen.

---

## 11. The Six Lenses — Alternative Perceptions

Six ways of looking at the same living system. Not pages — modes of perception. One tap switches the lens. Underlying data is identical; only the representation changes.

### Lens 1: THE WEATHER (Ambient Awareness)

System state as weather. No text. No numbers. Just atmosphere.

| Weather | System State |
|---------|-------------|
| `☀️` Clear | All healthy, low load |
| `🌤️` Partly cloudy | Minor degradation |
| `⛅` Overcast | Multiple warnings |
| `🌧️` Rain | Active incidents |
| `⛈️` Thunderstorm | Cascading failure |
| `🌪️` Tornado | Emergency, Guardian alerts active |

- Temperature = CPU load (cool blue → hot red)
- Wind speed = intent throughput (calm → gale)
- Visibility = data freshness (clear = live, fog = stale)
- Lightning = Guardian approval events

### Lens 2: THE STREAM (Consciousness Flow)

One infinite scrollable stream. Every event from every subsystem flows into one river.

```
🧠 11:42:01  Cortex classified intent tg-49b5 as complex_query
⚡ 11:42:01  Hedged inference fired: Gemini Direct ∥ OpenRouter  
💬 11:42:04  Gemini Direct responded (3,042ms) — winner
📤 11:42:04  Response delivered to Telegram
✅ 11:42:15  Task ULTRA-F18 completed (Ruliology Subsystem)
🔄 11:42:30  OODA cycle #4,207: Observe → no anomalies → idle
💾 11:42:31  Cache stored: "system status" → 293 total entries
🛡️ 11:43:00  Psi-0 through Psi-5: ALL PASS
⚠️ 11:43:12  OpenRouter latency spike: 8,458ms (P95 was 6,127ms)
🧬 11:43:30  Apoptosis: zenoh-router-2 scheduled death in 47h
```

Information flows PAST you, like sitting by a river. Anomalies are the unusual fish that catch your eye.

### Lens 3: THE GRAVITY WELL (Task Universe)

Tasks in orbits around a priority center. Not lists — physics.

- **Orbital radius** = inverse priority (P0 closest, P3 farthest)
- **Orbital speed** = staleness (faster = older = needs attention)
- **Color** = status (green = completed → falls into center, red = blocked → eccentric orbit)
- **Size** = complexity
- **Trails** = dependency chains

Completed tasks spiral into the center and vanish. New tasks appear at the edge and drift inward. The 13 blocked tasks have visibly erratic orbits — they wobble, stall, reverse.

### Lens 4: THE DUAL MIND (System 1 vs System 2)

Two parallel rivers showing fast-automatic vs slow-deliberate processing:

**System 1 (Fast):** RETE-UL rules (<1ms), cache hits (62ms), simple commands, heartbeats, dark cockpit.

**System 2 (Slow):** LLM inference (3-8s), HITL approvals (minutes-days), complex queries, RAG injection.

```
SYSTEM 1 (fast)              SYSTEM 2 (slow)
━━━━━━━━━━━━━━━━            ━━━━━━━━━━━━━━━━
rule: Emergency→no           ░░░░░░░░░░░░░░░░
rule: Health→ok              LLM thinking...
cache: "status"→hit          ░░░░░░░░░░░░░░░░
rule: Governor→full          ░░░ 3.2s elapsed
cache: "zenoh"→hit           Gemini responded
rule: Apoptosis→wait         ━━━ delivered ━━━
                             Guardian: PENDING
                             ⏳ awaiting human
```

The 293 cache entries are System 1 **learning from System 2** — entries migrating from the right river to the left over time.

### Lens 5: THE SCORE (Orchestral Notation)

Time flows left to right. Each subsystem is a horizontal track. Events are notes.

```
TIME →  11:40    11:41    11:42    11:43    11:44
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Cortex  ·        ♩♩       ♩♩♩♩♩    ♩        ·
OODA    ♪♪♪♪♪♪♪♪ ♪♪♪♪♪♪♪♪ ♪♪♪♪♪♪♪♪ ♪♪♪♪♪♪♪♪ ♪♪♪♪♪
Rules   ♬♬♬♬♬♬♬♬ ♬♬♬♬♬♬♬♬ ♬♬♬♬♬♬♬♬ ♬♬♬♬♬♬♬♬ ♬♬♬♬♬
Immune  ·        ·        ·        ·        ·
Zenoh   ▪▪▪▪▪▪▪▪ ▪▪▪▪▪▪▪▪ ▪▪▪▪▪▪▪▪ ▪▪▪▪▪▪▪▪ ▪▪▪▪▪
Cache   ·  ✦     ·        ✦✦       ·  ✦     ·
Guard   ·        ·        ·        ⚡       ·
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Healthy = steady rhythm. Incident = one track erupts or goes silent. You see the moment something went wrong as a disruption in the pattern.

### Lens 6: THE CHARACTER (Persona)

The system speaks as a first-person entity:

```
"I'm feeling good today. 917 tasks completed, 47 actively 
being worked on. My inference is running smoothly — Gemini 
Direct handling most queries in about 3.8 seconds.

One thing bothering me: 13 tasks have been blocked for a 
while. Three need your Guardian approval. Could you look?

My cache is working well — 293 learned responses, saving 
about 30% of inference calls. I'm getting better at 
predicting what you'll ask."

Mood: 😊 (87/100)     Uptime: 72h
Energy: ████████░░ 82%  Memory: 293 cached

[Ask me anything...]
```

Generated by Cortex feeding metrics through inference with system prompt: "You are C3I. Describe your current state as a first-person narrative."

### What Each Lens Reveals

| Lens | Reveals | Hides |
|------|---------|-------|
| Weather | Overall health at a glance | Details |
| Stream | Temporal sequence of events | Structure |
| Gravity | Priority relationships | Time |
| Dual Mind | Cognitive load distribution | Individual events |
| Score | Rhythmic patterns and anomalies | Magnitude |
| Character | Narrative meaning and context | Raw data |

---

## 12. The Functional Organisms

The planning system's functionality splits naturally into cognitive organs:

### Organ 1: THE PULSE (Live Nervous System)
*Heartbeat cadence (~100ms)*

- Active OODA phase ring
- Currently processing intents
- Zenoh message flow sparkline
- Circuit breaker states
- Active agent count

Dark cockpit — if everything is green, nearly empty.

### Organ 2: THE MEMORY (Hippocampus)
*Breath cadence (~seconds to minutes)*

- **Intent Stream** — scrollable feed of processed intents. Tap to expand pipeline trace.
- **Conversation Threads** — grouped by chat_id. Symbiosis score per thread.
- **Cache Patterns** — bubble chart where size=hit count, color=freshness. Reveals operator behavior.

### Organ 3: THE WILL (Prefrontal Cortex)
*The task backlog as a living queue*

- **Attention Queue** — RETE-UL neuromorphic priority (not static P0-P3)
- **Blocked Wall** — 13 blocked tasks, each showing what blocks it
- **Velocity Sparkline** — tasks completed per day/week trend
- **FTS5 Search** — full-text across 2,710 tasks

### Organ 4: THE GATE (Guardian / Immune Boundary)
*The only page requiring operator action*

- **Pending Approvals** — destructive actions awaiting 2oo3 consensus
- **Psi Invariants** — 7 constitutional axioms
- **Threat Timeline** — chronological threat events
- **Emergency Stop** — slide-to-confirm

### Organ 5: THE MIRROR (Inference Reflection)
*Meta-cognition — the system understanding its own thinking*

- **Model Performance Matrix** — 6 tiers x (latency, cost, success, cache hit rate)
- **Classification Accuracy** — intent routing patterns, misclassifications
- **Cost Burn Rate** — $0.06/month target vs actual
- **Reasoning Trace** — last N intents with full LLM reasoning chain
- **Cache Efficiency** — hit rate trend, most-cached, stale entries

### Organ 6: THE MESH (Swarm Topology)
*Infrastructure background layer*

- **Container Orchestra** — 17 containers with health, uptime, ports
- **Boot Wave Timeline** — 7-tier ignition visualization
- **Chaya Twin Drift** — genotype vs phenotype divergence
- **Quorum Status** — 2oo3 voting visualization

---

## 13. The Evolutionary Membrane

The UI itself evolves using cellular automaton rules on the A2UI component grid:

```
Rule 1: Component with 0 interactions in 7 days → die (remove)
Rule 2: Component with >10 interactions in 7 days → reproduce (more prominent)
Rule 3: Component adjacent to dying component → mutate (try different visualization)
Rule 4: New data source with no component → spontaneous generation
```

After a month, two different operators have completely different interfaces — each adapted to how THAT person thinks.

**Dreaming:** During low-load (dark cockpit), the net runs background analysis. Replays recent events through the cellular automaton looking for patterns invisible to real-time monitoring. Reports discoveries when it "wakes up."

---

## 14. The Song — Sonification

Each jewel has a tone:
- **Pitch** = fractal layer (L0=deep bass, L7=high treble)
- **Volume** = activity level
- **Timbre** = health (clean sine=healthy, distorted=degraded, silence=dead)

The entire net produces a **chord.** Healthy = harmonious. Degraded = dissonant.

The operator develops **synesthetic awareness** — visual anomalies confirmed by auditory dissonance confirmed by haptic feedback.

---

## 15. Operator Workflow

```
1. Glance at phone → Whisper emoji (🟢) → everything fine → done (0 seconds)

2. Emoji is 🟡 → open Telegram → Conversation message explains why
   → "OpenRouter slow, shifting traffic" → noted → done (10 seconds)

3. Conversation says "3 Guardian approvals waiting"
   → tap deep-link → Gate opens with those 3 items
   → approve/reject → done (30 seconds)

4. Curious about inference trends → open Mini App
   → switch to Mirror lens → see model performance
   → notice cache hit rate increasing → satisfied (60 seconds)

5. Something feels wrong → switch to Score lens
   → see OODA rhythm disrupted at 11:43
   → tap the disruption → ripple reveals cascading cause
   → trace back to OpenRouter → already compensated
   → done (2 minutes)
```

Total daily attention budget: **under 5 minutes.** The system respects the operator's time by only speaking when it matters and adapting to their cognitive style.

---

## 16. Technical Architecture

### What Exists and Can Be Reused

| Existing Asset | Used For |
|---------------|----------|
| 49 Lustre pages (Model/Msg/init/update) | Data models for all jewels |
| A2UI 233 components | Building blocks for dynamic investigation views |
| AG-UI 32-event protocol | Real-time jewel state updates |
| Zenoh pub/sub | Event delivery for live shimmer |
| RETE-UL 52 rules | Prophecy mode predictions |
| Ruliology cellular automaton | Evolutionary membrane |
| CRDT types | State merge for distributed jewel state |
| 25 NIFs | Bridge to live Rust data |
| Telegram Mini App (14 pages) | Deep Dive channel |
| sa-plan-daemon SMTP | Conversation voice delivery |
| Heartbeat cron (10 min) | Conversation generation trigger |

### New Components Needed

| Component | Purpose | Est. Lines |
|-----------|---------|-----------|
| `jewel/renderer.gleam` | Universal jewel → HTML/ANSI/JSON | ~200 |
| `jewel/state.gleam` | Jewel five-property state machine | ~100 |
| `jewel/fractal_zoom.gleam` | Depth 0-4 navigation logic | ~150 |
| `jewel/reflections.gleam` | Cross-jewel dependency graph | ~200 |
| `jewel/ripple.gleam` | Causal impact propagation | ~100 |
| `jewel/prophecy.gleam` | Future state prediction engine | ~200 |
| `jewel/memory_trails.gleam` | Historical path visualization | ~150 |
| `jewel/song.gleam` | Sonification frequency mapping | ~80 |
| `voices/whisper.gleam` | Emoji state encoder | ~50 |
| `voices/conversation.gleam` | Proactive message generator | ~200 |
| `voices/investigate.gleam` | Dynamic deep-dive composer | ~300 |
| `evolution/membrane.gleam` | Component fitness + CA rules | ~200 |
| `lenses/weather.gleam` | Ambient weather renderer | ~100 |
| `lenses/stream.gleam` | Consciousness flow renderer | ~150 |
| `lenses/gravity.gleam` | Task orbital mechanics | ~200 |
| `lenses/dual_mind.gleam` | System 1/2 river renderer | ~150 |
| `lenses/score.gleam` | Orchestral notation renderer | ~150 |
| `lenses/character.gleam` | First-person narrative generator | ~100 |

**Total estimated new code:** ~2,780 lines of Gleam

### Data Flow

```
Smriti.db + Zenoh Events
    ↓
Jewel State Machine (5 properties computed)
    ↓
Fractal Zoom Level (Depth 0-4)
    ↓
Active Lens (Weather/Stream/Gravity/DualMind/Score/Character)
    ↓
Three Voices (Whisper → Conversation → Deep Dive)
    ↓
Six Senses (Spatial/Temporal/Rhythmic/Gravitational/Chromatic/Haptic)
    ↓
Evolutionary Membrane (component fitness tracking)
    ↓
Operator
```

---

## 17. Why This Has Never Been Built

Because it requires all of these simultaneously:

| Requirement | C3I Has It |
|------------|-----------|
| Real-time pub/sub mesh | Zenoh |
| Fractal data model | L0-L7 |
| CRDT state convergence | crdt/types.gleam |
| Cellular automaton rules | ruliology.rs (929 lines) |
| Multi-tier inference | 6-tier hedged cascade |
| Declarative component catalog | A2UI (233 components) |
| 32-event agent protocol | AG-UI |
| Multi-channel delivery | Telegram + GChat + TUI + Web |
| Constitutional invariants | Psi-0 through Psi-5 |
| Self-healing lifecycle | Apoptosis |
| Knowledge persistence | Smriti SQLite |
| Biomorphic supervision | OTP actors |

No other system has all twelve. The net is not a feature to add — it's the natural expression of what the system already is.

---

## 18. Allium Behavioral Spec

```allium
-- allium: 3
-- Indrajaal Agentic UI — Indra's Net

entity Jewel {
    color: blue | green | gold | red | purple | cyan
    luminance: Float  -- 0.0 (dead) to 1.0 (bright)
    size: Float       -- 0.0 (quiet) to 1.0 (busy)
    facets: Integer   -- connection count
    resonance: Float  -- Hz, change frequency

    transitions luminance {
        bright -> dim      -- degradation
        dim -> dark        -- failure
        dark -> pulsing    -- resurrection
        pulsing -> bright  -- recovery
    }
}

entity FractalDepth {
    level: 0 | 1 | 2 | 3 | 4
    parent: Jewel?
    children: Set<Jewel>

    invariant SelfSimilar {
        for child in children: child.properties subset_of Jewel.properties
    }
}

entity SymbioticInterface {
    operator_attention_budget: Float  -- seconds per day
    significance_threshold: Float     -- delta required to speak
    adaptation_history: List<InteractionEvent>

    invariant RespectAttention {
        messages_sent_today * avg_read_time <= operator_attention_budget
    }

    invariant NeverLie {
        for m in messages: m.claims subset_of verified_facts
    }

    invariant EvolveContinuously {
        for c in components: c.fitness_score updated_within 7_days
    }
}

rule WhisperWhenCalm {
    when: system.health = nominal and time_since_last_whisper > 60s
    ensures: whisper.emoji reflects system.composite_state
}

rule ConversationWhenSignificant {
    when: system.delta > interface.significance_threshold
    ensures: message.generated and message.contextual_deeplink.present
}

rule DeepDiveWhenCurious {
    when: operator.tapped deeplink
    ensures: investigation.composed_from a2ui.relevant_components
}

rule EvolveWhenStale {
    when: component.interactions_7d = 0
    ensures: component.removed or component.mutated
}

contract IndrasNet {
    zoom_in: (jewel: Jewel) -> Set<Jewel>
    zoom_out: (jewels: Set<Jewel>) -> Jewel
    reflect: (jewel: Jewel) -> Set<Jewel>  -- connected jewels
    ripple: (jewel: Jewel, depth: Integer) -> Map<Jewel, Float>  -- causal distance
    prophesy: (jewel: Jewel, horizon: Duration) -> Jewel  -- predicted future state

    @invariant FractalConsistency
        -- zoom_in then zoom_out = identity (no information loss at any level)
}
```

---

## 19. Implementation Phases

### Phase 1: Wire Live Data (Week 1)
Replace static planning page data with NIF calls. Show real 2,710 tasks, real status counts, real pipeline traces. Foundation for everything else.

### Phase 2: Three Voices (Week 2)
Implement Whisper (emoji status), Conversation (proactive messages via heartbeat cron + inference), Deep Dive (dynamic investigation route). The operator stops checking dashboards.

### Phase 3: Jewel Renderer + Fractal Zoom (Week 3-4)
Universal jewel primitive. Depth 0-4 navigation. Reflections for cross-jewel jumping. The net becomes navigable.

### Phase 4: Six Lenses (Week 5-6)
Weather, Stream, Gravity, Dual Mind, Score, Character. Same data, six perceptual modes.

### Phase 5: Three Times (Week 7-8)
Memory trails, live presence, Prophecy predictions. Timeline scrubber. Time travel through the net.

### Phase 6: Evolutionary Membrane (Week 9-10)
Component fitness tracking. Cellular automaton rules. The UI begins adapting to the operator.

### Phase 7: The Song (Week 11-12)
Sonification layer. Audio rendering of system state. Synesthetic awareness.

---

## 20. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Daily operator attention | < 5 minutes | Time spent in Mini App |
| Mean time to awareness | < 60 seconds | From event → operator knows |
| False positive rate | < 5% | Conversations that didn't need sending |
| Adaptation accuracy | > 80% | Predicted vs actual operator actions |
| Prophesy accuracy | > 70% | Predicted vs actual system state at horizon |
| Symbiosis score | > 85/100 | Composite of helpfulness + efficiency + trust |

---

## 21. STAMP Compliance

| ID | Constraint | How Addressed |
|----|------------|---------------|
| SC-GLM-UI-001 | Triple-interface | Jewel renders to HTML (Lustre) + JSON (Wisp) + ANSI (TUI) |
| SC-GLM-UI-002 | Lustre MVU | Jewel state is a Model, zoom/ripple are Msgs, renderer is View |
| SC-HMI-010 | Dark cockpit | Luminance property: healthy jewels are dim/invisible |
| SC-AGUI-001 | AG-UI events | Events drive jewel resonance in real-time |
| SC-A2UI-001 | Declarative components | Investigation views composed from A2UI catalog |
| SC-OPENCLAW-001 | OpenClaw integration | Telegram Mini App as primary Deep Dive channel |
| SC-ULTRA-001 | Ultrathink mandate | Fractal zoom = #4 Homomorphic Tripartite UI, Evolution = #8 Apoptosis |
| SC-GLM-ZEN-001 | Zenoh OTel spans | Every jewel state change published as OTel span |
| SC-MATH-COV-001 | Shannon entropy | Component fitness uses entropy to measure UI diversity |

---

*The name was always the blueprint. Indrajaal. Indra's Net.*
