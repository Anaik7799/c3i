# Indrajaal UI/UX Evaluation Framework

**Version:** 1.0.0
**Date:** 2026-04-10
**Status:** EVALUATION CRITERIA
**Compliance:** ISO 9241-11, NASA-TLX, IEC 61508 SIL-6, SC-HMI-001..080

---

## 1. The Seven Dimensions

The Indrajaal Agentic UI is evaluated across seven dimensions, each measuring a fundamentally different quality. No single score captures the whole — all seven must be assessed together.

| # | Dimension | Question It Answers | Weight |
|---|-----------|-------------------|--------|
| D1 | **Cognitive Load** | How much mental effort does the operator spend? | 20% |
| D2 | **Temporal Efficiency** | How fast does the operator reach awareness and action? | 15% |
| D3 | **Situational Fidelity** | How accurately does the UI represent reality? | 15% |
| D4 | **Symbiotic Adaptation** | How well does the system learn the operator? | 15% |
| D5 | **Sensory Richness** | How many perceptual channels carry meaning? | 10% |
| D6 | **Fractal Coherence** | Is the visual language consistent across all scales? | 10% |
| D7 | **Existential Alignment** | Does the system serve the operator's life, not consume it? | 15% |

---

## 2. D1: Cognitive Load (20%)

*The best interface is the one you don't have to think about.*

### Metrics

| Metric | How Measured | Target | Critical Threshold |
|--------|-------------|--------|-------------------|
| **Attention Budget** | Minutes/day spent actively looking at UI | < 5 min/day | > 15 min/day = failure |
| **Decision Latency** | Time from seeing information to making a decision | < 10 seconds | > 60 seconds = friction |
| **Context Switches** | Number of page/lens/depth changes per task | < 3 switches | > 7 switches = maze |
| **Reading Load** | Words read per insight gained | < 20 words | > 100 words = wall of text |
| **Recall Burden** | Information operator must remember between screens | 0 items (system remembers) | > 3 items = cognitive overflow |
| **NASA-TLX Mental Demand** | Subjective rating (1-21 scale) | < 7 | > 14 = overloaded |

### Evaluation Method

- **Whisper Test:** Can the operator assess system health from lock screen in < 2 seconds without opening any app? Score: emoji readability × accuracy.
- **Interruption Recovery:** After being interrupted mid-task, how long to regain context? Target: < 5 seconds (system maintains state).
- **Quiet Day Test:** On a day with zero incidents, how many times does the operator open the app? Target: 0 times. The system's silence IS the status report.

### Scoring

| Score | Cognitive Load Level |
|-------|---------------------|
| 10 | Invisible — operator forgets the system exists when healthy |
| 8 | Ambient — awareness without attention, like knowing the weather |
| 6 | Glanceable — quick look answers the question |
| 4 | Readable — requires reading and interpreting |
| 2 | Studyable — requires analysis and cross-referencing |
| 0 | Overwhelming — operator gives up and ignores the system |

---

## 3. D2: Temporal Efficiency (15%)

*Time is the only non-renewable resource. The system must not waste it.*

### Metrics

| Metric | How Measured | Target | Critical Threshold |
|--------|-------------|--------|-------------------|
| **Time to Awareness (TTA)** | Event occurs → operator knows | < 60 seconds | > 5 minutes = blind |
| **Time to Action (TTTA)** | Event occurs → operator acts | < 120 seconds | > 10 minutes = paralysis |
| **Time to Resolution (TTR)** | Event occurs → resolved | < 300 seconds | > 30 minutes = firefighting |
| **Proactive Lead Time** | System warns → event occurs | > 30 minutes | < 5 minutes = too late |
| **HITL Approval Latency** | Guardian request → human decision | < 5 minutes | > 24 hours = bottleneck |
| **Zero-Tap Insights** | % of insights requiring no interaction | > 80% | < 50% = too manual |

### Evaluation Method

- **Fire Drill:** Inject a simulated P0 incident. Measure time from injection to operator awareness, action, and resolution.
- **Prophecy Accuracy:** Compare predicted events (Prophecy mode) against actual events over 7 days. Precision and recall at various horizons (1h, 6h, 24h).
- **Dark Cockpit Duration:** Hours per day the system correctly stays silent. Target: > 22 hours. Every unnecessary alert is a temporal tax.

### Scoring

| Score | Temporal Quality |
|-------|-----------------|
| 10 | Precognitive — operator knows before it happens |
| 8 | Instantaneous — operator knows within seconds |
| 6 | Prompt — operator knows within minutes |
| 4 | Delayed — operator knows within the hour |
| 2 | Retrospective — operator learns after the fact |
| 0 | Oblivious — operator never learns |

---

## 4. D3: Situational Fidelity (15%)

*The map must match the territory. Every lie the UI tells is a risk.*

### Metrics

| Metric | How Measured | Target | Critical Threshold |
|--------|-------------|--------|-------------------|
| **Data Freshness** | Age of oldest displayed data point | < 10 seconds | > 60 seconds = stale |
| **State Accuracy** | % of displayed states matching actual system state | > 99% | < 95% = untrustworthy |
| **False Positive Rate** | % of alerts/conversations that were unnecessary | < 5% | > 20% = cry wolf |
| **False Negative Rate** | % of real incidents the system failed to communicate | 0% | > 0% = dangerous |
| **Completeness** | % of system state accessible through the UI | 100% | < 80% = blind spots |
| **Allium Drift** | Divergence between spec (what SHOULD be) and reality (what IS) | < 5% | > 15% = spec rot |

### Evaluation Method

- **Snapshot Audit:** At a random moment, freeze the UI and compare every displayed value against direct database/Zenoh queries. Score = % matching.
- **Phantom Test:** Inject a known anomaly and verify the UI reflects it within the freshness target.
- **Trust Calibration:** After 30 days of use, does the operator trust the system's reports enough to act without independent verification? Survey on 1-10 scale.

### Scoring

| Score | Fidelity Level |
|-------|---------------|
| 10 | Ground truth — the UI IS the system, not a representation of it |
| 8 | Mirror — accurate reflection with < 10s lag |
| 6 | Report — accurate but possibly delayed |
| 4 | Estimate — mostly right but occasionally wrong |
| 2 | Approximation — directionally correct but quantitatively off |
| 0 | Fiction — the UI tells a story that isn't true |

---

## 5. D4: Symbiotic Adaptation (15%)

*The system should know the operator better each day.*

### Metrics

| Metric | How Measured | Target | Critical Threshold |
|--------|-------------|--------|-------------------|
| **Personalization Depth** | # of operator-specific adaptations active | > 20 | < 5 = generic |
| **Prediction Accuracy** | % of operator's next action correctly anticipated | > 60% | < 30% = random |
| **Communication Precision** | % of proactive messages the operator reads fully | > 80% | < 40% = ignored |
| **Adaptation Speed** | Days to learn a new operator preference | < 7 days | > 30 days = rigid |
| **Graceful Forgetting** | Stale preferences auto-decay after disuse | Yes (30-day TTL) | Never = calcified |
| **Symbiosis Score** | Composite: helpfulness + efficiency + trust | > 85/100 | < 60/100 = parasitic |

### Evaluation Method

- **New Operator Test:** Fresh operator uses the system for 14 days. Measure how quickly the UI adapts: Day 1 (generic) → Day 7 (somewhat personalized) → Day 14 (highly personalized).
- **Preference Shift Test:** Operator changes their behavior (e.g., starts caring about inference cost instead of task velocity). Measure how many days until the system's proactive messages shift to match.
- **A/B Personality:** Two operators use the same system. After 30 days, compare their UI configurations. They should be significantly different (proving adaptation, not convergence to a default).

### Scoring

| Score | Adaptation Level |
|-------|-----------------|
| 10 | Telepathic — anticipates needs before the operator feels them |
| 8 | Intuitive — adapts quickly, rarely wrong, feels personal |
| 6 | Learning — visibly improving, occasionally surprising |
| 4 | Responsive — reacts to explicit settings, doesn't learn implicitly |
| 2 | Configurable — operator must manually tune everything |
| 0 | Rigid — one-size-fits-all, no adaptation |

---

## 6. D5: Sensory Richness (10%)

*Humans have five senses. Most dashboards use one (sight, reading text). Each additional channel multiplies comprehension.*

### Metrics

| Metric | How Measured | Target | Critical Threshold |
|--------|-------------|--------|-------------------|
| **Active Channels** | # of sensory channels carrying distinct information | >= 4 | < 2 = text-only |
| **Cross-Modal Consistency** | Do all channels agree? (color=red AND sound=dissonant AND haptic=warning) | 100% | < 80% = confusing |
| **Channel Independence** | Each channel carries unique information not redundant with others | > 50% unique per channel | < 20% = wasteful |
| **Peripheral Awareness** | Can operator detect anomalies without focused attention? | Yes (via color/sound/haptic) | No = requires staring |
| **Sensory Fatigue** | Does any channel become annoying over time? | No channel triggers muting | Any channel muted = failed |

### Channel Inventory

| Channel | What It Carries | Always-On? |
|---------|----------------|------------|
| **Visual: Color** | Health state (luminance, saturation) | Yes |
| **Visual: Motion** | Activity level (shimmer, pulse, orbit speed) | Yes |
| **Visual: Spatial** | Relationships (proximity, reflections, ripple) | On investigation |
| **Visual: Temporal** | History (trails, timeline, waveforms) | On investigation |
| **Auditory: Tone** | System chord (harmony=healthy, dissonance=degraded) | Optional |
| **Auditory: Rhythm** | OODA frequency, event cadence | Optional |
| **Haptic: Impact** | UI interaction feedback | On touch |
| **Haptic: Notification** | Alert severity (light/medium/heavy/warning/error) | On event |
| **Textual: Emoji** | Compressed system state (single glyph) | Always (Whisper) |
| **Textual: Narrative** | Natural language explanation (Character lens) | On request |

### Scoring

| Score | Sensory Level |
|-------|--------------|
| 10 | Synesthetic — operator perceives system through body, not just eyes |
| 8 | Multi-modal — 4+ channels, cross-modal consistency, peripheral awareness |
| 6 | Enhanced — color + motion + haptic carry meaning |
| 4 | Visual — color coding and layout carry meaning, but text-dependent |
| 2 | Textual — must read words to understand state |
| 0 | Numeric — must read numbers and mentally compare to thresholds |

---

## 7. D6: Fractal Coherence (10%)

*One visual language at every scale. Learn once, read everywhere.*

### Metrics

| Metric | How Measured | Target | Critical Threshold |
|--------|-------------|--------|-------------------|
| **Primitive Count** | # of distinct visual primitives the operator must learn | 1 (the Jewel) | > 5 = fragmented |
| **Cross-Scale Consistency** | Same visual language at Depth 0, 1, 2, 3, 4? | 100% | < 80% = each level is a new UI |
| **Navigation Predictability** | Can operator predict what they'll see before zooming? | > 90% | < 60% = surprising |
| **Zoom Losslessness** | Information visible at Depth N available at Depth N+1? | Yes (plus more detail) | No = hidden state |
| **Reflection Accuracy** | Do jewel facets correctly show connected jewels? | 100% | < 90% = misleading |
| **Self-Similarity Score** | Statistical similarity of visual structure at each depth | > 0.85 | < 0.60 = not fractal |

### Evaluation Method

- **Depth Traversal Test:** Operator zooms from Depth 0 to Depth 4 on a random path. At each level, they narrate what they see. Score = consistency of vocabulary used (same words at each level = high coherence).
- **Transfer Test:** After learning to read Jewels at L4 (containers), can the operator immediately read Jewels at L5 (inference) without instruction? Score = accuracy on first attempt.
- **Reconstruction Test:** Zoom into Depth 3. Then zoom out to Depth 0. Does the single jewel's color/luminance/size match what was observed at Depth 3? Score = consistency.

### Scoring

| Score | Coherence Level |
|-------|----------------|
| 10 | Perfectly fractal — one language, infinite depth, zero learning at each new level |
| 8 | Highly consistent — minor variations at different depths, quickly understood |
| 6 | Mostly consistent — some levels use different patterns, requires brief learning |
| 4 | Partially consistent — core concepts shared but each level has unique elements |
| 2 | Loosely related — different levels feel like different apps |
| 0 | Disconnected — no relationship between views at different scales |

---

## 8. D7: Existential Alignment (15%)

*Does the system serve the operator's life, or consume it?*

This is the most important and most neglected dimension. A system can score perfectly on D1-D6 and still fail D7 if it creates anxiety, dependency, or compulsive checking.

### Metrics

| Metric | How Measured | Target | Critical Threshold |
|--------|-------------|--------|-------------------|
| **Anxiety Delta** | Operator's stress level WITH system vs WITHOUT | Lower with system | Higher with system = toxic |
| **Compulsive Checking** | App opens per day not triggered by system | 0 | > 5 = addictive |
| **Sleep Impact** | Does the system wake the operator unnecessarily? | Never for < P0 | Any non-critical night wake = harmful |
| **Trust Without Verification** | Does operator act on system's word without double-checking? | > 80% of the time | < 50% = distrust |
| **Delegation Confidence** | Can operator go offline for 24h trusting the system will alert if needed? | Yes | No = leash |
| **Joy** | Does the operator enjoy interacting with the system? | Positive sentiment | Negative = dread |
| **Meaning Amplification** | Does the system help the operator do MORE meaningful work? | Yes (time saved → redirected to high-value tasks) | No (time saved → filled with more monitoring) |

### Evaluation Method

- **Vacation Test:** Operator goes offline for 48 hours. The system handles everything autonomously via RETE-UL rules + pre-approved policies. On return, operator reviews what happened. Score = % of decisions they agree with.
- **Mood Tracking:** Before and after each session, operator rates mood (1-5). System should leave mood unchanged or improved, never worse.
- **Life Integration:** Does the system fit into the operator's day naturally (like weather awareness) or demand separate dedicated time (like a second job)?
- **Founder's Directive Test (Omega-0):** Is the relationship between operator and system genuinely symbiotic? Does each make the other more capable? Or is one exploiting the other?

### Scoring

| Score | Existential Quality |
|-------|-------------------|
| 10 | Liberating — operator is more free, more capable, more at peace because of the system |
| 8 | Empowering — operator feels in control, system is a trusted ally |
| 6 | Helpful — system saves time and reduces errors, net positive |
| 4 | Neutral — system is a tool, neither enriching nor diminishing |
| 2 | Burdensome — system creates work, anxiety, or dependency |
| 0 | Parasitic — system consumes more life than it produces |

---

## 9. Composite Scoring

### Weighted Formula

```
UI Score = (D1 × 0.20) + (D2 × 0.15) + (D3 × 0.15) + (D4 × 0.15) 
         + (D5 × 0.10) + (D6 × 0.10) + (D7 × 0.15)

Scale: 0-10
```

### Grade Thresholds

| Grade | Score | Meaning |
|-------|-------|---------|
| **S** | >= 9.0 | Transcendent — the operator and system are one |
| **A** | >= 8.0 | Excellent — genuinely better than any existing tool |
| **B** | >= 7.0 | Good — competitive with best-in-class dashboards |
| **C** | >= 6.0 | Adequate — functional but unremarkable |
| **D** | >= 5.0 | Below average — operator tolerates rather than enjoys |
| **F** | < 5.0 | Failing — operator actively avoids the system |

### Minimum Thresholds (ALL must pass)

| Dimension | Minimum Score | Rationale |
|-----------|--------------|-----------|
| D1 Cognitive Load | >= 6 | If it takes effort to use, it won't be used |
| D2 Temporal Efficiency | >= 6 | If it's slow, operators will find workarounds |
| D3 Situational Fidelity | >= 8 | If it lies, trust is destroyed permanently |
| D7 Existential Alignment | >= 6 | If it hurts the operator's life, it's immoral to ship |

A system scoring 10 on D2-D6 but 3 on D7 is **rejected.** Speed and beauty mean nothing if the system creates anxiety.

---

## 10. Comparison Benchmarks

### Against Traditional Dashboards (Grafana, Datadog, PagerDuty)

| Dimension | Traditional | Indra's Net Target |
|-----------|------------|-------------------|
| D1 Cognitive Load | 3-4 (requires reading, cross-referencing) | 8+ (ambient, glanceable) |
| D2 Temporal Efficiency | 4-5 (reactive, requires checking) | 8+ (proactive, system finds you) |
| D3 Situational Fidelity | 7-8 (accurate when checked) | 9+ (always accurate, never stale) |
| D4 Symbiotic Adaptation | 1-2 (manual configuration only) | 7+ (learns operator preferences) |
| D5 Sensory Richness | 2-3 (visual text + color coding) | 7+ (color + motion + haptic + sound) |
| D6 Fractal Coherence | 2-3 (different views for different levels) | 8+ (one jewel language at all scales) |
| D7 Existential Alignment | 3-4 (creates alert fatigue, compulsive checking) | 8+ (liberating, respects attention) |

### Against Chat-Based Ops (Slack + PagerDuty bot)

| Dimension | Chat-Based | Indra's Net Target |
|-----------|-----------|-------------------|
| D1 Cognitive Load | 5 (natural language but noisy) | 8+ (three voices, significance filter) |
| D2 Temporal Efficiency | 6 (fast alerts but no prediction) | 8+ (prophecy mode) |
| D3 Situational Fidelity | 5 (text descriptions of metrics) | 9+ (live jewel state) |
| D4 Symbiotic Adaptation | 2 (same messages for everyone) | 7+ (personalized communication) |
| D5 Sensory Richness | 2 (text only) | 7+ (multi-modal) |
| D6 Fractal Coherence | 1 (flat text, no hierarchy) | 8+ (fractal zoom) |
| D7 Existential Alignment | 4 (alert fatigue in chat channels) | 8+ (dark cockpit silence) |

---

## 11. Anti-Patterns (Automatic Score Penalties)

| Anti-Pattern | Penalty | Dimension Affected |
|-------------|---------|-------------------|
| Alert fatigue (> 20 notifications/day with < 30% actionable) | -3 | D1, D7 |
| Stale data displayed without staleness indicator | -3 | D3 |
| Operator must remember information between screens | -2 | D1 |
| Different visual languages at different depths | -2 | D6 |
| System wakes operator for non-critical events | -3 | D7 |
| UI requires > 3 clicks to reach any piece of information | -2 | D2 |
| Text-only status (no color, no motion, no haptics) | -2 | D5 |
| System cannot explain WHY it sent a notification | -2 | D3, D4 |
| One-size-fits-all — no personalization after 30 days | -3 | D4 |
| Operator checks system more than 5x/day with no incidents | -2 | D7 |
| Dashboard requires dedicated monitoring time ("dashboard duty") | -3 | D7 |
| System creates anxiety about what MIGHT be happening | -3 | D7 |

---

## 12. Evaluation Protocol

### 12.1 Automated (Continuous)

Collected automatically by the system itself and stored in Smriti:

| Metric | Collection Method | Frequency |
|--------|------------------|-----------|
| App open count | Mini App analytics | Per session |
| Time in app | Session duration tracking | Per session |
| Interaction depth | Max fractal depth reached | Per session |
| Lens switching | Count of lens changes | Per session |
| Proactive message read rate | Telegram read receipts | Per message |
| HITL approval latency | Guardian timestamp delta | Per approval |
| Prophecy accuracy | Predicted vs actual comparison | Daily |
| Cache hit rate evolution | Smriti SemanticCache stats | Hourly |
| Component fitness scores | Evolutionary membrane tracking | Weekly |

### 12.2 Periodic (Human-Evaluated)

Conducted monthly with the operator:

| Assessment | Method | Duration |
|-----------|--------|----------|
| NASA-TLX workload | 6-item questionnaire after representative tasks | 5 minutes |
| Trust calibration | "Would you act on this without verifying?" for 10 scenarios | 10 minutes |
| Mood impact | Before/after session mood rating (1-5) over 5 sessions | Passive |
| Vacation test | 48h offline, review decisions on return | 30 minutes |
| Joy assessment | "What do you like? What frustrates you?" open interview | 15 minutes |

### 12.3 Milestone (Design Phase)

At each implementation phase completion:

| Phase | Key Evaluation |
|-------|---------------|
| Phase 1 (Live Data) | D3 Situational Fidelity — is the data accurate? |
| Phase 2 (Three Voices) | D2 Temporal Efficiency — is the operator aware faster? |
| Phase 3 (Jewel + Fractal) | D6 Fractal Coherence — is one language enough? |
| Phase 4 (Six Lenses) | D5 Sensory Richness — do multiple channels help? |
| Phase 5 (Three Times) | D2 Temporal Efficiency — does prophecy add value? |
| Phase 6 (Evolution) | D4 Symbiotic Adaptation — does the UI actually adapt? |
| Phase 7 (Song) | D5 Sensory Richness — does sonification aid awareness? |

---

## 13. The Ultimate Test

After all seven dimensions are scored, there is one final question that overrides everything:

> **"If the system disappeared tomorrow, would the operator feel a loss?"**

If yes → the system has become a genuine extension of the operator's cognition. It has achieved symbiosis. Grade S.

If no → the system is still a tool. Useful perhaps, but not transformative. Maximum grade B regardless of dimension scores.

The goal is not to build a good dashboard. The goal is to build something the operator cannot imagine living without — not because it creates dependency, but because it makes them fundamentally more capable.

That is the difference between a tool and a symbiont. That is what Indra's Net aims to be.

---

## 14. STAMP Compliance

| ID | Constraint | Evaluation Dimension |
|----|------------|---------------------|
| SC-HMI-010 | Dark cockpit | D1 (cognitive load), D7 (existential alignment) |
| SC-HMI-001..080 | HMI standards | D5 (sensory richness), D6 (fractal coherence) |
| SC-MATH-COV-001 | Shannon entropy >= 2.5 | D5 (channel independence diversity) |
| SC-GLM-UI-008 | Auto-hide when healthy | D1 (attention budget), D7 (compulsive checking) |
| SC-SAFETY-022 | Emergency stop < 5s | D2 (time to action) |
| SC-HINT-005 | Human intent correlation >= 0.70 | D3 (situational fidelity) |
| SC-SIL4-006 | 2oo3 voting for actuations | D3 (no false approvals) |
| SC-FUNC-001 | System must compile at all times | D3 (fidelity — UI reflects real state) |

---

## 15. Mathematical Foundation

### Shannon Entropy of Sensory Channels

```
H_sensory = -Σ p_i × log2(p_i)

where p_i = fraction of total information carried by channel i

Target: H >= 2.5 bits (information distributed across channels, not concentrated in text)

Example:
  Text carries 40% → p_text = 0.40
  Color carries 25% → p_color = 0.25
  Motion carries 15% → p_motion = 0.15
  Haptic carries 10% → p_haptic = 0.10
  Sound carries 10% → p_sound = 0.10
  
  H = -(0.40×log2(0.40) + 0.25×log2(0.25) + 0.15×log2(0.15) 
       + 0.10×log2(0.10) + 0.10×log2(0.10))
  H = -(−0.529 + −0.500 + −0.411 + −0.332 + −0.332)
  H = 2.10 bits → BELOW TARGET (too text-heavy)
  
  Redistribute to equalize → H = log2(5) = 2.32 bits (maximum for 5 channels)
```

### Adaptation Convergence Rate

```
A(t) = 1 - e^(-λt)

where:
  A(t) = adaptation accuracy at time t (days)
  λ = learning rate parameter
  
Target: A(7) >= 0.50 (50% adapted in one week)
         A(30) >= 0.85 (85% adapted in one month)

Implies: λ >= 0.099 (half-life ≈ 7 days)
```

### Attention Budget Utilization

```
U_attention = Σ(t_i × s_i) / B

where:
  t_i = time spent on message i (seconds)
  s_i = significance of message i (0-1)
  B = daily attention budget (300 seconds = 5 minutes)
  
Target: U <= 1.0 (never exceed budget)
Quality: Σ(s_i) / count(messages) > 0.8 (80%+ messages are significant)
```

### Symbiosis Score

```
S = α × H_helpful + β × E_efficient + γ × T_trust - δ × A_anxiety

where:
  H_helpful = fraction of proactive messages rated helpful (0-1)
  E_efficient = time saved / time invested ratio
  T_trust = fraction of decisions acted on without verification (0-1)
  A_anxiety = compulsive check frequency normalized (0-1)
  
  α = 0.30, β = 0.25, γ = 0.25, δ = 0.20
  
  S scaled to 0-100
  Target: S >= 85
```

---

*A system that scores 10/10 on features but 3/10 on existential alignment is not a good system. It is a beautiful cage.*
