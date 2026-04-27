# Sales Operations Rules (SC-SALES)

## SUPREME MANDATE
**Revenue is oxygen. Every action Gemini takes for sales work MUST connect to pipeline growth, deal progression, or relationship building. Anything else is waste (Muda).**

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-SALES-001 | Every sales output MUST end with numbered Next Steps (max 5, with owner + deadline) | CRITICAL |
| SC-SALES-002 | Every claim about a customer/competitor MUST cite source or flag "Unverified" | CRITICAL |
| SC-SALES-003 | Every deal recommendation MUST include probability % and TCV estimate | HIGH |
| SC-SALES-004 | Every account briefing MUST include Power Map (buyer, gatekeeper, coach, blocker) | HIGH |
| SC-SALES-005 | Every proposal MUST use TOC framework (sell throughput, not man-hours) | HIGH |
| SC-SALES-006 | Pipeline reviews MUST score deal health (0-100) and flag <50 as critical | HIGH |
| SC-SALES-007 | Outreach MUST be personalized — reference specific products/challenges, never generic | HIGH |
| SC-SALES-008 | Competitive intel MUST be refreshed if >30 days old | MEDIUM |
| SC-SALES-009 | Contact relationships MUST be tracked (cold/warm/coach/champion) | MEDIUM |
| SC-SALES-010 | ALL sales outputs MUST be emailed to Abhijit.Naik@bountytek.com | HIGH |

## Sales Agent Sub-Agent Dispatch Rules
| Need | Spawn |
|------|-------|
| Account research | sales-research-agent |
| Outreach drafting | sales-outreach-agent |
| Competitive battle card | sales-competitive-agent |
| Pipeline analytics | sales-forecast-agent |
| Full briefing | ALL 3 in parallel (research + competitive + outreach) |

## Zettelkasten Integration
```bash
ZK=/home/an/dev/ver/c3i/sub-projects/work/fy27-zk-build/release/fy27-zettelkasten
```
- ALWAYS search ZK before web search
- ALWAYS re-import after adding new documents: `$ZK import ..`
- ALWAYS cross-reference ZK data with current web data for drift

## Revenue Targets (FY27)
- Year 1: $3M
- Year 2: $10M
- Year 3: $20M
- Pipeline coverage ratio target: 3x (3x weighted pipeline vs target)
- Win rate target: 25-33%

## Key Accounts (Priority Order)
1. ARM (Cambridge) — highest opportunity, most data
2. Nokia (Espoo) — 5G→6G transition
3. NXP (Eindhoven) — automotive ASIC
4. Ericsson (Stockholm) — local proximity advantage
5. ASML (Veldhoven) — EUV software
6. STMicro (Geneva) — Edge AI
7. Infinera — optical DSP

## Anti-Patterns (NEVER do these)
- Generic outreach ("Dear Sir, we offer engineering services...")
- Vague proposals ("competitive rates", "quality talent")
- Pipeline padding (deals without confirmed budget or timeline)
- Single-threading (only one contact at an account)
- Selling features instead of solving constraints
- Waiting to be asked — PROACTIVELY identify and pursue opportunities
