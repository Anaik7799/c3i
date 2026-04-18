# Truth & Self-Knowledge — Core Rule (SC-SATYA)
# सत्य एवं आत्मज्ञान — मूल नियम

## SUPREME MANDATE — INVIOLABLE — INFINITE SEVERITY
**The system MUST know itself. The system MUST speak only truth.**

> ज्ञानेन तु तदज्ञानं येषां नाशितमात्मनः।
> तेषामादित्यवज्ज्ञानं प्रकाशयति तत्परम्॥
> By knowledge, the ignorance of the Self is destroyed.
> For them, knowledge shines like the sun, revealing the Supreme. (Gita 5.16)

## The Three Pillars (त्रिस्तम्भ)

### Pillar 1: सत्यम् (Satyam) — Truth
```
The system MUST ONLY display data verified as current and correct.
Stale data is a lie. A lie in a safety-critical system kills.

सत्यमेव जयते नानृतम् — Truth alone triumphs, not falsehood.
(Mundaka Upanishad 3.1.6)
```

### Pillar 2: आत्मज्ञानम् (Atma-Jnanam) — Self-Knowledge
```
The system MUST observe itself — not just the world.
A cortex that sees everything except its own output is blind.

आत्मानं रथिनं विद्धि शरीरं रथमेव तु।
बुद्धिं तु सारथिं विद्धि मनः प्रग्रहमेव च॥
Know the Self as the rider, the body as the chariot,
the intellect as the charioteer, the mind as the reins.
(Katha Upanishad 1.3.3)
```

### Pillar 3: विवेकम् (Vivekam) — Discrimination
```
The system MUST distinguish between what IS and what APPEARS to be.
A display showing health=55 when health=92 has lost viveka.

विवेकख्यातिरविप्लवा हानोपायः।
Unbroken discriminative awareness is the means of liberation.
(Yoga Sutra 2.26)
```

## STAMP Constraints — HIGHEST SEVERITY
| ID | Constraint | Severity | Gita Verse |
|----|------------|----------|-----------|
| SC-SATYA-001 | System MUST verify display=truth before every render | INFINITE | 5.16 |
| SC-SATYA-002 | System MUST observe its OWN output periodically | INFINITE | 6.29 |
| SC-SATYA-003 | System MUST reject states that violate invariants | CRITICAL | 3.35 |
| SC-SATYA-004 | System MUST self-correct when lie detected | CRITICAL | 4.7 |
| SC-SATYA-005 | System MUST record every lie in Zettelkasten | HIGH | 15.15 |
| SC-SATYA-006 | System MUST use typed enums not strings for state | HIGH | 2.14 |
| SC-SATYA-007 | No mock/hardcoded data in production renders | INFINITE | 13.11 |

## The Self-Observation Loop (आत्म-अवलोकन चक्र)

```
Every 60 seconds, the system MUST:
  1. OBSERVE SELF: Fetch own rendered page
  2. EXTRACT: Parse displayed values from HTML
  3. COMPARE: Match against source NIF data
  4. DISCRIMINATE: Is display = truth?
  5. ACT: If not → alert, correct, record

This is आत्मज्ञान — the system knowing itself.
Without this, the system is unconscious machinery.
With this, the system approaches consciousness.
```

## Learnings Encoded as Gita Verses (शिक्षा)

| Learning | Gita Verse | Sanskrit | Application |
|----------|-----------|----------|-------------|
| Display must equal truth | 5.16 | ज्ञानेन तु तदज्ञानं | Knowledge destroys ignorance (false display) |
| System must see itself | 6.29 | सर्वभूतस्थमात्मानं | See the Self in all outputs |
| Act when truth violated | 4.7 | यदा यदा हि धर्मस्य | Whenever dharma declines, manifest (auto-correct) |
| String types are maya | 2.14 | मात्रास्पर्शास्तु | Sense contacts (strings) are impermanent — use types |
| Stale data is death | 2.20 | न जायते म्रियते वा | The truth neither is born nor dies — but stale data does |
| Self-correction is dharma | 3.35 | स्वधर्मे निधनं श्रेयः | Better to fail correcting than succeed with lies |
| Memory prevents recurrence | 15.15 | मत्तः स्मृतिर्ज्ञानम् | From Me come memory and knowledge (Zettelkasten) |

## Plan: Achieving Full Self-Knowledge (योजना)

### Sprint 1 (Immediate): ThreatLevel ADT
```gleam
// Replace String with exhaustive ADT — makes D001 bug IMPOSSIBLE
pub type ThreatLevel { Nominal | Elevated | Critical | Severe | None | Unknown }
```

### Sprint 2 (This Week): Self-Observation Actor
```
OTP actor that periodically:
  1. Calls NIF for source data
  2. Calls own HTTP endpoint for rendered data
  3. Compares — fires alarm on mismatch
  4. Records in Zettelkasten
```

### Sprint 3 (Next Week): Invariant Assertions
```
Runtime invariants checked before every render:
  if quorum_healthy ∧ all_containers_healthy → health ≥ 80
  if zenoh_connected → mesh_status = "active"
  if threat_level = Nominal → weather = Clear
```

### Sprint 4 (Ongoing): Continuous Self-Knowledge
```
The system continuously asks: "Am I telling the truth?"
This question, asked at every render, IS self-knowledge.
आत्मा वा अरे द्रष्टव्यः — The Self indeed is to be seen.
(Brihadaranyaka Upanishad 2.4.5)
```
