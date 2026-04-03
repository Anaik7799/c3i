# STPA Analysis Workshop

**Duration:** 8 hours (full day workshop)
**Format:** Hands-on, group-based learning
**Prerequisites:** Module 1 completion or equivalent STAMP knowledge
**Maximum Participants:** 24 (4 groups of 6)

---

## 🎯 Workshop Objectives

By the end of this workshop, participants will:

1. **Complete Full STPA**: Perform comprehensive System-Theoretic Process Analysis
2. **Master STPA Tools**: Use automated tools for STPA documentation and analysis
3. **Apply to Real Systems**: Analyze actual system components from their work
4. **Generate Safety Requirements**: Create actionable safety requirements from STPA
5. **Present Findings**: Communicate STPA results to technical and non-technical stakeholders

## 📋 Workshop Structure

### Pre-Workshop Preparation (1 hour - before workshop)

**Required Reading**:
- [STPA Primer (30 pages)](stpa-primer.pdf)
- [Workshop Case Study Brief](case-study-brief.pdf)

**Preparation Tasks**:
- Install STPA analysis tools
- Review your current project architecture
- Identify a system component for analysis

**System Setup**:
```bash
# Install STPA tools
npm install -g stpa-analyzer
git clone https://github.com/stamp-team/stpa-templates

# Verify installation
stpa-analyzer --version
```

---

## 🏁 Session 1: STPA Kickoff & Team Formation (60 minutes)

### Welcome & Introductions (15 minutes)

**Participant Introductions** (2 minutes each):
- Name and role
- Current project/system responsibility
- STAMP/STPA experience level
- One safety concern from your current work

**Workshop Overview**:
- Full-day STPA analysis experience
- Real system analysis (not toy examples)
- Practical tools and templates
- Presentation to technical panel

### Team Formation & System Selection (30 minutes)

**Team Assignment Strategy**:
- Mix experience levels (1 experienced + 3-4 novices per team)
- Diverse technical backgrounds
- Complementary domain knowledge

**System Selection Criteria**:
- Critical to business operations
- Sufficient complexity for meaningful analysis
- Team has adequate domain knowledge
- Safety implications are non-trivial

**Available System Categories**:
1. **Team Red**: User Authentication & Authorization
2. **Team Blue**: Payment Processing & Financial Transactions
3. **Team Green**: Data Storage & Backup Systems
4. **Team Yellow**: API Gateway & Rate Limiting

**System Selection Process**:
```
1. Teams self-select based on expertise and interest
2. Facilitator ensures balanced team composition
3. Each team receives system-specific briefing materials
4. 15-minute team planning session
```

### STPA Methodology Review (15 minutes)

**Quick STPA Overview**:
```
Step 1: Define Purpose
- Accidents, hazards, safety constraints
- System boundaries and scope

Step 2: Model Control Structure
- Controllers and controlled processes
- Control actions and feedback
- Human and automated elements

Step 3: Identify UCAs
- Not providing when required
- Providing when unsafe
- Wrong timing (too early/late)
- Stopped too soon

Step 4: Generate Loss Scenarios
- How UCAs could occur
- Process model flaws
- Feedback failures
```

**Tools Introduction**:
- STPA Analyzer for documentation
- Lucidchart/Draw.io for control structure diagrams
- Shared Google Docs for collaboration
- Template worksheets for systematic analysis

---

## ⚙️ Session 2: System Analysis & Purpose Definition (90 minutes)

### Step 1: Define Analysis Purpose (45 minutes)

**Individual Brainstorming** (10 minutes):
Each team member independently identifies:
- Potential accidents/losses
- System hazards
- Safety concerns
- Stakeholder concerns

**Team Consolidation** (20 minutes):
```
Facilitated discussion to:
1. Merge individual insights
2. Prioritize most critical concerns
3. Define system boundaries
4. Agree on analysis scope
```

**Purpose Documentation** (15 minutes):
Using provided template, document:

```markdown
# STPA Analysis Purpose

## System Under Analysis
**Name**: [System name]
**Boundaries**: [What's included/excluded]
**Stakeholders**: [Who cares about this analysis]

## Accidents and Losses
A1: [Primary accident/loss]
A2: [Secondary accident/loss]
A3: [Additional accidents as needed]

## System-Level Hazards
H1: [System state that could lead to A1]
H2: [System state that could lead to A2]
H3: [Additional hazards as needed]

## Safety Constraints
SC1: [Constraint to prevent H1]
SC2: [Constraint to prevent H2]
SC3: [Additional constraints as needed]
```

**Example - Payment Processing Team**:
```markdown
## Accidents and Losses
A1: Financial loss due to fraudulent transactions
A2: Customer financial damage from processing errors
A3: Regulatory violations resulting in penalties

## System-Level Hazards
H1: Fraudulent transactions are processed as legitimate
H2: Legitimate transactions are incorrectly processed
H3: Sensitive payment data is exposed or compromised

## Safety Constraints
SC1: Only authenticated transactions with valid payment methods shall be processed
SC2: All transaction data must be encrypted and access-controlled
SC3: Suspicious transaction patterns must trigger automatic verification
```

### Step 2: System Architecture Mapping (45 minutes)

**Architecture Review** (15 minutes):
Teams review their system's:
- Current architecture diagrams
- Component responsibilities
- Data flows and interfaces
- Human operator roles

**Control Structure Identification** (30 minutes):

**Controllers Identification**:
```
Human Controllers:
- Who makes decisions?
- Who provides inputs?
- Who monitors system state?

Automated Controllers:
- Which components control others?
- What software modules issue commands?
- Which systems monitor and respond?
```

**Controlled Processes**:
```
Physical Processes:
- Hardware components
- External systems
- Physical actions

Software Processes:
- Data processing
- Algorithm execution
- State management
```

**Control Actions & Feedback**:
```
Control Actions:
- Commands issued by controllers
- Data/signal transmission
- Configuration changes

Feedback:
- Status information
- Sensor readings
- Error reports
- Performance metrics
```

**🎮 Team Exercise**: Control Structure Mapping (20 minutes)
Using provided templates, create initial control structure diagram for your assigned system.

---

## 🍕 Lunch Break (60 minutes)

**Networking Lunch**: Continue discussions over provided lunch. Facilitators available for questions.

---

## 🔍 Session 3: Control Structure Modeling (90 minutes)

### Control Structure Deep Dive (60 minutes)

**Systematic Controller Analysis**:
Each team analyzes their controllers using this template:

```markdown
## Controller: [Controller Name]

### Responsibilities
- [Primary responsibility]
- [Secondary responsibility]
- [Additional responsibilities]

### Control Actions Issued
- [Control action 1]: [Description and target]
- [Control action 2]: [Description and target]
- [Control action N]: [Description and target]

### Feedback Received
- [Feedback 1]: [Source and information type]
- [Feedback 2]: [Source and information type]
- [Feedback N]: [Source and information type]

### Process Model
- [What does this controller "know" about the system?]
- [What assumptions does it make?]
- [What could it be wrong about?]

### Failure Modes
- [How could this controller fail?]
- [What if feedback is wrong/missing?]
- [What if control actions are ineffective?]
```

**Example - API Gateway Controller**:
```markdown
## Controller: API Gateway Rate Limiter

### Responsibilities
- Enforce rate limits per user/API key
- Detect and block suspicious traffic patterns
- Maintain service availability under load

### Control Actions Issued
- AllowRequest: Permits API request to proceed
- BlockRequest: Rejects request due to rate limit
- RedirectTraffic: Routes request to different endpoint

### Feedback Received
- RequestCount: Number of requests per time window
- ResponseTime: Backend service response latency
- ErrorRate: Rate of 4xx/5xx responses from backend

### Process Model
- Assumes user tokens are valid and not compromised
- Believes rate limit thresholds prevent service overload
- Expects backend services to handle allowed requests

### Failure Modes
- Rate limit calculations could be incorrect
- Legitimate users could be blocked during traffic spikes
- Malicious users could circumvent rate limiting
```

**Control Structure Diagram Creation** (30 minutes):
Teams create comprehensive control structure diagrams using:
- Standard STAMP notation
- Clear hierarchical relationships
- All identified control actions and feedback
- Human and automated elements distinguished

### Validation & Refinement (30 minutes)

**Peer Review Process** (15 minutes):
- Teams rotate and review other teams' control structures
- Provide feedback using structured checklist
- Identify missing controllers or control actions
- Suggest improvements to process models

**Facilitator Review** (15 minutes):
Expert facilitators provide targeted feedback:
- Completeness of control structure
- Accuracy of controller responsibilities
- Clarity of control action definitions
- Realistic process model assumptions

---

## ⚠️ Session 4: UCA Identification Workshop (120 minutes)

### UCA Methodology Deep Dive (30 minutes)

**The Four UCA Categories**:

**1. Not Providing Control Action**:
```
When is it unsafe for [Controller] to NOT provide [Control Action]?

Template: "[Control Action] not provided when [context] leads to [hazard] because [rationale]"

Example: "AllowRequest not provided when user has valid authentication leads to H3: Legitimate users denied service because rate limiter incorrectly categorizes normal usage as suspicious"
```

**2. Providing Control Action Unsafely**:
```
When is it unsafe for [Controller] to provide [Control Action]?

Template: "[Control Action] provided when [context] leads to [hazard] because [rationale]"

Example: "AllowRequest provided when user token is compromised leads to H1: Unauthorized access to protected resources because rate limiter cannot distinguish legitimate from malicious requests using same token"
```

**3. Wrong Timing**:
```
When is [Control Action] provided too early or too late?

Template: "[Control Action] provided [too early/too late] during [context] leads to [hazard] because [rationale]"

Example: "BlockRequest provided too late after attack has begun leads to H2: Service degradation because rate limiter takes too long to detect and respond to traffic anomalies"
```

**4. Stopped Too Soon**:
```
When is [Control Action] stopped before it should be?

Template: "[Control Action] stopped too soon during [context] leads to [hazard] because [rationale]"

Example: "BlockRequest stopped too soon during ongoing attack leads to H1: Security breach continues because rate limiter prematurely lifts restrictions based on temporary traffic reduction"
```

### Systematic UCA Analysis (75 minutes)

**UCA Generation Process** (45 minutes):
Teams work through each control action systematically:

1. **Choose Control Action** (5 minutes per action)
2. **Apply Four Categories** (10 minutes per action)
3. **Link to Hazards** (5 minutes per action)
4. **Document with Rationale** (5 minutes per action)

**UCA Worksheet Template**:
```markdown
## Control Action: [Action Name]

### Category 1: Not Providing
| Context | Hazard | Rationale | UCA ID |
|---------|--------|-----------|---------|
| [When not providing is unsafe] | [H#] | [Why this leads to hazard] | UCA-001 |

### Category 2: Providing
| Context | Hazard | Rationale | UCA ID |
|---------|--------|-----------|---------|
| [When providing is unsafe] | [H#] | [Why this leads to hazard] | UCA-002 |

### Category 3: Wrong Timing
| Context | Hazard | Rationale | UCA ID |
|---------|--------|-----------|---------|
| [When timing is wrong] | [H#] | [Why this leads to hazard] | UCA-003 |

### Category 4: Stopped Too Soon
| Context | Hazard | Rationale | UCA ID |
|---------|--------|-----------|---------|
| [When stopped prematurely] | [H#] | [Why this leads to hazard] | UCA-004 |
```

**Quality Check Process** (15 minutes):
For each UCA, verify:
- [ ] Clear context specification
- [ ] Direct link to identified hazard
- [ ] Logical rationale provided
- [ ] Realistic scenario
- [ ] Actionable for safety requirements

**Team Consultation** (15 minutes):
Facilitators visit each team to:
- Review UCA quality and completeness
- Help resolve ambiguous scenarios
- Suggest additional contexts to consider
- Ensure systematic coverage

### UCA Refinement & Prioritization (15 minutes)

**UCA Prioritization Criteria**:
```
High Priority:
- Directly leads to major accidents
- Likely to occur in normal operations
- Difficult to detect or recover from

Medium Priority:
- Contributes to accidents with other factors
- Moderately likely under stress conditions
- Some detection/recovery mechanisms exist

Low Priority:
- Requires multiple simultaneous failures
- Very unlikely given current safeguards
- Easy to detect and mitigate
```

**Priority Assignment Process**:
Teams assign priority levels and justify rankings based on:
- Likelihood of occurrence
- Severity of consequences
- Current system protections
- Detection capabilities

---

## 📊 Session 5: Loss Scenario Development (90 minutes)

### Scenario Generation Methodology (30 minutes)

**Scenario Development Process**:
```
1. Select High-Priority UCAs
2. Analyze Controller Behavior
3. Identify Process Model Flaws
4. Examine Feedback Failures
5. Consider Environmental Factors
6. Document Complete Scenarios
```

**Scenario Template Structure**:
```markdown
## Loss Scenario: [Scenario Name]

### UCA Reference
**UCA ID**: [UCA-XXX]
**UCA Description**: [Brief UCA summary]

### Scenario Description
**Initial Conditions**: [System state when scenario begins]
**Trigger Event**: [What initiates the unsafe behavior]
**Controller Behavior**: [How controller acts unsafely]
**Process Model Flaw**: [What controller believes vs reality]
**Feedback Failure**: [Missing/incorrect feedback]
**Resulting State**: [Unsafe system condition]
**Accident Connection**: [How this leads to identified accident]

### Contributing Factors
- [Factor 1: Technical/design issue]
- [Factor 2: Human/operational issue]
- [Factor 3: Environmental/external issue]

### Current Safeguards
- [Existing protection 1]
- [Existing protection 2]
- [Safeguard gaps identified]

### Safety Requirements
- [Requirement 1: What system must do]
- [Requirement 2: What system must not do]
- [Requirement 3: How system must respond]
```

### Hands-On Scenario Development (45 minutes)

**Team Scenario Work** (30 minutes):
Each team develops 3-5 detailed loss scenarios for their highest-priority UCAs.

**Example Scenario - Payment Processing**:
```markdown
## Loss Scenario: Fraudulent Transaction Approval

### UCA Reference
**UCA ID**: UCA-005
**UCA Description**: PaymentProcessor provides "ApproveTransaction" when transaction shows suspicious patterns

### Scenario Description
**Initial Conditions**: High transaction volume during Black Friday sale
**Trigger Event**: Fraudster uses stolen credit card with normal purchase patterns
**Controller Behavior**: Payment processor approves transaction based on amount/merchant being within normal ranges
**Process Model Flaw**: Controller believes transaction patterns indicate legitimacy, but doesn't account for stolen card usage with deliberate pattern mimicking
**Feedback Failure**: Fraud detection system overloaded and delayed in providing risk assessment
**Resulting State**: Fraudulent transaction processed, customer charged, attacker receives goods
**Accident Connection**: Leads to A1 (financial loss) and A2 (customer financial damage)

### Contributing Factors
- Fraud detection system not sized for peak load
- Process model doesn't weight real-time behavioral analysis heavily enough
- No secondary validation for high-risk periods

### Current Safeguards
- Basic amount and merchant validation
- Post-transaction fraud monitoring
- Customer dispute process

### Safety Requirements
- REQ-001: Payment system must validate transaction patterns in real-time even under peak load
- REQ-002: System must not approve transactions when fraud detection feedback is unavailable
- REQ-003: System must implement secondary validation during high-risk periods
```

**Peer Review Process** (15 minutes):
- Teams exchange scenarios for review
- Use provided quality checklist
- Provide constructive feedback
- Identify scenario improvements

### Safety Requirements Generation (15 minutes)

**Requirements Derivation Process**:
```
From each loss scenario, derive:
1. Functional requirements (what system must do)
2. Performance requirements (timing, accuracy)
3. Interface requirements (information needed)
4. Constraint requirements (what system must not do)
```

**Requirements Quality Criteria**:
- [ ] Specific and measurable
- [ ] Directly addresses scenario
- [ ] Implementable in system design
- [ ] Testable and verifiable
- [ ] Traceable to specific UCA/scenario

---

## 🎤 Session 6: Presentation Preparation & Delivery (90 minutes)

### Presentation Structure & Preparation (45 minutes)

**Presentation Template** (15 minutes):
```
1. Executive Summary (2 minutes)
   - System analyzed
   - Key findings overview
   - Critical recommendations

2. STPA Process Summary (3 minutes)
   - Analysis purpose and scope
   - Control structure overview
   - UCA methodology applied

3. Key Findings (8 minutes)
   - Most critical UCAs identified
   - Detailed loss scenarios
   - Safety requirement priorities

4. Recommendations (5 minutes)
   - Implementation priorities
   - Required system changes
   - Monitoring and validation

5. Q&A (7 minutes)
   - Technical questions
   - Implementation challenges
   - Stakeholder concerns
```

**Slide Preparation Guidelines**:
- Maximum 10 slides total
- Use provided template
- Include control structure diagram
- Highlight 2-3 most critical findings
- Focus on actionable recommendations

**Team Preparation Time** (30 minutes):
- Assign presentation roles
- Create slide deck
- Practice timing and transitions
- Prepare for expected questions
- Rehearse key messages

### Team Presentations (40 minutes)

**Presentation Schedule** (10 minutes per team):
- 7 minutes presentation
- 3 minutes Q&A from panel and peers

**Expert Panel**:
- Senior Safety Engineer
- System Architect
- Product Manager
- STAMP/STPA Subject Matter Expert

**Evaluation Criteria**:
- Technical accuracy of STPA analysis
- Quality of UCAs and scenarios identified
- Practicality of safety requirements
- Clarity of presentation and recommendations

### Debrief & Next Steps (5 minutes)

**Workshop Wrap-Up**:
- Key insights and learning highlights
- Common patterns across team analyses
- Best practices observed
- Areas for continued development

**Follow-Up Actions**:
- Individual team reports due within 1 week
- Schedule follow-up consultation sessions
- Plan implementation support
- Certification pathway guidance

---

## 📋 Workshop Materials

### Required Tools
- [ ] Laptop with STPA analysis software
- [ ] Access to system documentation
- [ ] Drawing/diagramming tools
- [ ] Collaborative document access

### Provided Materials
- [ ] STPA worksheets and templates
- [ ] System case study briefs
- [ ] Reference materials and guides
- [ ] Presentation template
- [ ] Quality checklists

### Deliverables
- [ ] Completed STPA analysis document
- [ ] Control structure diagram
- [ ] UCA analysis spreadsheet
- [ ] Loss scenarios report
- [ ] Safety requirements list
- [ ] Team presentation slides

---

## 🎯 Success Criteria

### Individual Learning Outcomes
- [ ] Can perform complete STPA analysis independently
- [ ] Understands when and how to apply STPA
- [ ] Can generate actionable safety requirements
- [ ] Able to communicate STPA findings effectively

### Team Deliverables
- [ ] Comprehensive STPA analysis completed
- [ ] High-quality UCAs and scenarios identified
- [ ] Practical safety requirements derived
- [ ] Professional presentation delivered

### Workshop Evaluation
- [ ] Participant satisfaction > 4.5/5
- [ ] Learning objectives met for 90%+ participants
- [ ] Follow-up implementation rate > 80%
- [ ] Expert panel satisfaction with quality

---

**Workshop Facilitators**: [Facilitator names and contact info]
**Expert Panel**: [Panel member names and backgrounds]
**Technical Support**: [Support contact information]

**Questions during workshop?**
- Raise hand for immediate help
- Use #stpa-workshop Slack channel
- Email: workshop-support@indrajaal.dev

**Post-workshop support available for 30 days**