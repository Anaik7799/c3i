# FY27 Sales Plan Execution Protocol (SC-FY27)
# वित्तीय वर्ष २७ विक्रय योजना कार्यान्वयन प्रोतोकॉल

## Mandate
**ALL FY27 sales planning, account work, and pipeline actions MUST use the FY27 Zettelkasten as institutional memory and the Analytical Verification Protocol as quality gate.**

The FY27-Plan is an EMEA semiconductor services growth plan for InSemi/Infosys.
- **Territory**: Europe (UK, Nordics, DACH, Benelux, France, Ireland, Finland)
- **Key OEMs**: ARM, Nokia, Ericsson, Infinera + new logo acquisition
- **Framework**: Theory of Constraints (TOC) — Throughput Engine
- **Methodology**: MEDDPICC qualification, design-win funnel, TOC Mafia Offer

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-FY27-001 | ALL account/deal work MUST search FY27 ZK BEFORE starting | CRITICAL |
| SC-FY27-002 | ALL analysis outputs MUST pass Analytical Verification Protocol | CRITICAL |
| SC-FY27-003 | Pipeline data MUST be sourced from ZK, NOT fabricated | INFINITE |
| SC-FY27-004 | Account plans MUST use TOC framework (5 Focusing Steps) | HIGH |
| SC-FY27-005 | Deal qualification MUST use MEDDPICC (0-80 scale) | HIGH |
| SC-FY27-006 | Competitive intel MUST be verified against ZK sources | HIGH |
| SC-FY27-007 | Rate cards and pricing MUST reference Draft_Rate_Cards_v2_3 | HIGH |
| SC-FY27-008 | Contact data MUST come from ZK contacts table, NOT invented | INFINITE |
| SC-FY27-009 | All new insights MUST be ingested back to ZK after session | HIGH |
| SC-FY27-010 | Weekly rhythm cadence MUST be maintained (pipeline, accounts, deals) | MEDIUM |

## FY27 Zettelkasten Access
```
export ZK=/home/an/dev/ver/c3i/sub-projects/work/fy27-zk-build/release/fy27-zettelkasten
export ZK_DIR=/home/an/dev/ver/c3i/sub-projects/work/gdrive/1-Work/FY27-Plan/zettelkasten

# Search knowledge base
cd $ZK_DIR && $ZK search "<query>"

# Search contacts
cd $ZK_DIR && $ZK contacts "<name or company>"

# Database stats
cd $ZK_DIR && $ZK stats

# Re-import after adding new documents
cd $ZK_DIR && $ZK import ..
```

## Key Artifact Locations
| Artifact | Path (relative to FY27-Plan/) | Purpose |
|----------|-------------------------------|---------|
| ZK Database | zettelkasten/fy27-plan.db | Authoritative knowledge store |
| ZK Binary | /home/an/dev/ver/c3i/sub-projects/work/fy27-zk-build/release/fy27-zettelkasten | Search/import tool |
| EMEA Business Case | Analysis/v1/out/InSemi_EMEA_Business_Case_v6.xlsx | Revenue model |
| Verification Report | Analysis/v1/out/InSemi_EMEA_Verification_Report.docx | Analysis validation |
| Rate Cards | Analysis/v1/in/4-Draft_Rate_Cards_v2_3_COMPLETE.xlsx | Pricing reference |
| VLSI Funnel Model | Analysis/v1/in/6-InSemi_VLSI_Funnel_Model_v7.xlsx | Pipeline math |
| Semicon Knowledge Base | Analysis/v1/in/3-InSemi_Infosys_Semiconductor_Knowledge_Base.xlsx | Domain reference |
| Europe Strategy Deck | Presentation/1-Europe-Semicon-Strategy-v1.pptx | Master presentation |
| Verification Protocol | Analysis/v1/in/1-Analytical-Verification-Protocol.md | Quality gate |
| TOC Framework | Analysis/v1/in/2-TOC-Account-Planning.md | Strategy framework |
| ARM Account Plan | refs/2-OEMs/ARM/ARM - Account Plan/ | ARM service targeting |
| Nokia Materials | refs/2-OEMs/Nokia/ | Nokia partnership |
| Contact Lists | refs/20250401-Contact-List.xlsx, refs/contacts.csv | People data |
| Opportunity Tracker | refs/3-20260127-Oppty-Tracker.xlsx | Pipeline tracker |
| Biz Plan Template | refs/4-Abhi-Biz Plan Template_ENGNCMT_FY27_SHs_26Nov25.xlsb | Planning template |

## Analytical Verification Protocol (SC-FY27-002)
Every analysis output MUST pass this 4-phase gate:

### Phase 1: Journalism (Provenance & Fact-Checking)
- Source identified? ZK holon UUID traceable?
- Data current? (check decay_rate, verified_at)
- Multiple sources corroborate? (cross-reference ZK holons)

### Phase 2: Law (Interrogation & Stress-Testing)
- Assumptions explicit and testable?
- Counter-arguments considered?
- Edge cases explored?

### Phase 3: Intelligence (Structural Logic)
- Logical chain: evidence -> inference -> conclusion?
- No gaps in reasoning?
- Confidence levels stated?

### Phase 4: Math (Quantitative Evaluation)
- Numbers add up? Revenue bridges balance?
- Growth rates realistic vs market data?
- Pipeline coverage sufficient? (3x+ for committed, 4x+ for H2)

## TOC Sales Framework — The Throughput Engine
Every account plan MUST follow the 5 Focusing Steps:

1. **IDENTIFY** the constraint — What blocks this account from buying more?
2. **EXPLOIT** the constraint — Get maximum throughput from current state
3. **SUBORDINATE** everything — Align all activities to the constraint
4. **ELEVATE** the constraint — Invest to remove it (new contacts, new services, new pricing)
5. **REPEAT** — Find the new constraint after elevation

### Mafia Offer Construction
For each key account, construct an offer so good the customer can't refuse:
- What is the customer's core problem?
- What is the current cost of NOT solving it?
- How does our offer eliminate the problem?
- What is the risk to the customer of accepting? (must be near-zero)

## Design Win Funnel Stages
| Stage | Definition | Probability | Actions |
|-------|-----------|-------------|---------|
| Awareness | Customer knows us | 5% | Marketing, events, LinkedIn |
| Evaluation | Customer evaluating our capability | 15% | Technical demo, PoC proposal |
| Design-In | Customer designing with our team | 35% | SOW, resource allocation |
| Prototype | Silicon/IP in prototype phase | 55% | Execution, weekly syncs |
| Qualification | Customer qualifying our deliverable | 75% | Testing support, issue resolution |
| Production | Volume production, revenue recognized | 95% | Account management, upsell |

## Weekly Execution Rhythm
| Day | Activity | Tool |
|-----|----------|------|
| Monday | Pipeline review — stale deals, new opportunities | /fy27-pipeline-review |
| Tuesday | Account sprint — deep work on #1 priority account | /fy27-account-sprint |
| Wednesday | Competitive intel update — monitor threats | /competitive-intel |
| Thursday | Outreach execution — emails, LinkedIn, calls | /sales-email, /linkedin-outreach |
| Friday | Weekly rhythm — metrics, ZK ingest, next week plan | /fy27-weekly-rhythm |

## OEM Playbooks

### ARM
- **Relationship**: Service targeting partnership (v6 updated)
- **Key Services**: Neoverse verification, Cloud/AI infrastructure, CPU subsystem
- **Data**: ARM_Cloud_AI infographic, service targeting matrix
- **Contacts**: Search ZK with contacts "arm.com"

### Nokia
- **Relationship**: Partnership (MOU with VMO2)
- **Key Services**: 5G/6G verification, RAN software, network infrastructure
- **Data**: Partnership presentation drafts, competitive intel
- **Contacts**: Search ZK with contacts "nokia.com"

### Ericsson
- **Relationship**: Existing account (historical plans from 2021-2022)
- **Key Services**: Telecom infrastructure verification
- **Contacts**: Search ZK with contacts "ericsson.com"

### Infinera
- **Relationship**: Optical networking account
- **Key Services**: ASIC/SoC verification, optical transceiver design
- **Contacts**: Search ZK with contacts "infinera.com"

## MEDDPICC Quick Reference
| Letter | Meaning | Key Questions |
|--------|---------|---------------|
| M | Metrics | What measurable outcome does the customer need? |
| E | Economic Buyer | Who signs the PO? Have we met them? |
| D | Decision Criteria | Technical and business criteria for vendor selection? |
| D | Decision Process | What are the steps from eval to PO? Timeline? |
| P | Paper Process | Legal, procurement, MSA/SOW process? |
| I | Implicate Pain | What happens if they do NOTHING? Cost of inaction? |
| C | Champion | Who inside is selling for us? Do they have power? |
| C | Competition | Who else is in the deal? Our differentiation? |

**Scoring**: Each criterion 0-10. Composite /80. >=60 strong, 40-59 at risk, <40 in trouble.
