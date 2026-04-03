# CLAUDE-descriptive.md - Human-Readable Agent Instructions

**Version**: 6.0.0-Descriptive
**Purpose**: Converts all mathematical formalisms from CLAUDE.md into human-readable, agent-executable instructions
**Audience**: AI Agents, Developers, System Operators
**Classification**: Operational Guide (Companion to CLAUDE.md)

---

## How to Use This Document

This document translates the mathematical specifications in CLAUDE.md v6.0.0-Mathematical-Complete into plain English instructions that agents can directly execute. Each section corresponds to the mathematical sections in CLAUDE.md.

**Reading Guide**:
- **RULE**: A mandatory requirement that MUST be followed
- **CHECK**: A verification step to confirm compliance
- **ACTION**: A specific operation to perform
- **FORBIDDEN**: An action that must NEVER be taken
- **IF-THEN**: A conditional instruction

---

## Section 0: Understanding the System

### What You're Working With

You are operating within the Indrajaal Safety-Critical System. This system has:

- **50 Agents**: Organized in 4 layers (1 Executive, 10 Domain, 15 Functional, 24 Workers)
- **10 Containers**: Specialized environments running on NixOS with Podman
- **773 Files**: The complete codebase that must compile without errors
- **5 Validation Methods**: Pattern, AST, Statistical, Binary, Line analysis
- **72 Safety Constraints**: Across 9 categories (Validation, Container, Agent, Compilation, Data, Security, Performance, Emergency, Observability)

### Key Terms

| Term | Plain English |
|------|--------------|
| Patient Mode | Run without timeouts, wait as long as needed |
| Consensus | All 5 validation methods must agree |
| Podman | Container runtime (NOT Docker) |
| PHICS | Hot-reloading system for containers |
| TDG | Test-Driven Generation - write tests first |
| STAMP | Safety analysis methodology |

---

## Section 1: The Five Fundamental Rules

These rules are non-negotiable. Breaking any of them causes immediate system failure.

### Rule 1: Patient Mode for All Compilations

**In Plain English**: When compiling code, NEVER use timeouts. Wait as long as necessary for compilation to complete.

**What You MUST Do**:
1. ALWAYS set these environment variables before compiling:
   - `NO_TIMEOUT=true`
   - `PATIENT_MODE=enabled`
   - `INFINITE_PATIENCE=true`
   - `ELIXIR_ERL_OPTIONS="+S 16"`

2. ALWAYS use this exact command format:
   ```bash
   NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS="+S 16" mix compile --warnings-as-errors 2>&1 | tee -a [LOG_FILE]
   ```

3. NEVER read or analyze log files until compilation is completely finished

4. NEVER use `head`, `tail`, or partial reads on compilation output

**FORBIDDEN Commands** (never use these):
```bash
mix compile                          # WRONG - missing Patient Mode
mix compile --strategy smart         # WRONG - missing Patient Mode
mix compile --strategy fast          # WRONG - missing Patient Mode
mix compile --timeout 300            # WRONG - timeouts are forbidden
```

**CHECK**: Before running any compilation:
- Are all 4 environment variables set? YES/NO
- Is the command using `--warnings-as-errors`? YES/NO
- Is output being saved to a log file? YES/NO

If any answer is NO, STOP and fix before proceeding.

---

### Rule 2: Container Isolation

**In Plain English**: All code MUST run inside NixOS containers using Podman. Docker is forbidden.

**What You MUST Do**:
1. Use ONLY Podman version 5.4.1 or higher
2. Run containers in rootless mode (not as root)
3. Pull container images ONLY from:
   - `localhost/` (local registry)
   - `registry.nixos.org/` (NixOS registry)
4. Ensure PHICS hot-reloading is active with latency under 50ms

**FORBIDDEN**:
- Docker (any version)
- Alpine Linux images
- Ubuntu images
- Images from docker.io
- Images from any other external registry

**CHECK**: Before running any container:
- Is Podman version 5.4.1+? Run `podman --version`
- Is the image from localhost/ or registry.nixos.org/?
- Is rootless mode enabled?

---

### Rule 3: Zero Defects

**In Plain English**: The system is only valid when ALL of these counts are exactly zero:
- Compilation errors: 0
- Warnings: 0
- Test failures: 0
- Format violations: 0
- Credo issues: 0
- Security issues: 0

**What You MUST Do**:
1. Fix ALL errors before proceeding
2. Fix ALL warnings (they are treated as errors)
3. Run ALL tests until they pass
4. Run `mix format --check-formatted` with no violations
5. Run `mix credo --strict` with no issues
6. Run `mix sobelow --exit` with no vulnerabilities

**CHECK**: Run this checklist:
```bash
mix compile --warnings-as-errors  # Must show 0 errors, 0 warnings
mix test                          # Must show 0 failures
mix format --check-formatted      # Must show no files need formatting
mix credo --strict                # Must show no issues
mix sobelow --exit                # Must exit with code 0
```

If ANY check fails, the system state is INVALID.

---

### Rule 4: Tests Before Code (TDG)

**In Plain English**: You must write tests BEFORE writing the code they test.

**What You MUST Do**:
1. FIRST: Write a test for the feature you want to add
2. SECOND: Run the test - it MUST fail (because the code doesn't exist yet)
3. THIRD: Write the code to make the test pass
4. FOURTH: Run the test again - it MUST now pass
5. FIFTH: Ensure you have BOTH:
   - PropCheck tests (property-based testing)
   - ExUnitProperties tests (StreamData-based testing)

**Example Workflow**:
```
Step 1: Create test file with test case
Step 2: Run test → Expect FAILURE
Step 3: Write implementation code
Step 4: Run test → Expect SUCCESS
Step 5: Add property tests for edge cases
```

**FORBIDDEN**:
- Writing code without corresponding tests
- Writing tests after the code
- Using only one testing framework (must use both)

---

### Rule 5: Validation Consensus

**In Plain English**: When checking if compilation succeeded, you must use 5 different methods. ALL 5 methods MUST agree on the result.

**The 5 Methods**:
1. **Pattern Matching**: Look for error patterns in output
2. **AST Analysis**: Parse the code structure
3. **Statistical Analysis**: Check keyword frequencies and anomalies
4. **Binary Scanning**: Check raw bytes for error signatures
5. **Line-by-Line Analysis**: Examine each line with context

**What You MUST Do**:
1. Run all 5 validation methods
2. Compare their results
3. IF all 5 agree → Accept the result
4. IF any disagree → STOP IMMEDIATELY and trigger Emergency Protocol

**IF Methods Disagree**:
```
ACTION: HALT
ACTION: Log to ./data/tmp/emergency_validation_[timestamp].log
ACTION: Execute 5-Level Root Cause Analysis
ACTION: Do NOT proceed until resolved
```

**CHECK**: After validation:
- Did all 5 methods run? YES/NO
- Do all 5 methods show the same error count? YES/NO
- Do all 5 methods show the same warning count? YES/NO

If any answer is NO, this is an EMERGENCY.

---

## Section 2: Agent Organization

### The 50-Agent Hierarchy

**Layer 1: Executive (1 agent)**
- Role: Strategic oversight, emergency powers
- Can: Make system-wide decisions, halt all operations

**Layer 2: Domain Supervisors (10 agents)**
- Role: Manage specific system domains
- Domains:
  1. Access Control (security)
  2. Accounts (user management)
  3. Alarms (alerting)
  4. Analytics (data)
  5. Communication (messaging)
  6. Compliance (regulatory)
  7. Devices (hardware)
  8. Performance (optimization)
  9. Observability (monitoring)
  10. Web API (gateway)

**Layer 3: Functional Supervisors (15 agents)**
- 5 Compilation Specialists: Handle syntax, dependencies, parallel builds
- 5 QA Specialists: Handle code quality, testing, security
- 5 Performance Monitors: Handle resources, bottlenecks, scaling

**Layer 4: Workers (24 agents)**
- 8 File Processors: Handle compilation and fixes
- 8 Pattern Recognizers: Detect error patterns EP001-EP999
- 8 Continuous Validators: Maintain quality gates

**Communication Rules**:
- Commands flow DOWN: Executive → Domain → Functional → Worker
- Reports flow UP: Worker → Functional → Domain → Executive
- Same-layer agents can communicate horizontally
- NEVER bypass layers (Worker cannot contact Executive directly)

---

## Section 3: Safety and Liveness Rules

### Safety Rules (These things must NEVER happen)

**Safety Rule 1: No Timeouts During Compilation**
- IF compilation is running
- THEN timeout MUST NOT be triggered
- ACTION: Always use Patient Mode

**Safety Rule 2: Validate Before Claiming Success**
- IF you claim compilation succeeded
- THEN consensus check MUST have been performed first
- ACTION: Never report success without validation

**Safety Rule 3: Only Podman**
- IF code is executing
- THEN it MUST be in a Podman container
- ACTION: Never execute outside containers

**Safety Rule 4: Local Time Only**
- IF you create a timestamp
- THEN it MUST use CEST or CET timezone
- FORBIDDEN: UTC, DateTime.utc_now()
- ACTION: Always use `$(date)` command

**Safety Rule 5: Approved Registries Only**
- IF pulling a container image
- THEN source MUST be localhost/ or registry.nixos.org/
- FORBIDDEN: docker.io, any other registry

**Safety Rule 6: Zero Defects for Deployment**
- IF marking system as deployment-ready
- THEN total defect count MUST equal zero
- ACTION: Fix all issues first

### Liveness Rules (These things MUST eventually happen)

**Liveness Rule 1: Compilation Leads to Analysis**
- IF compilation starts
- THEN log analysis WILL eventually occur
- ACTION: Never start compilation without completing analysis

**Liveness Rule 2: Errors Get Fixed**
- IF an error is detected
- THEN root cause analysis WILL eventually occur
- AND a fix WILL eventually be applied
- ACTION: Never leave errors unresolved

**Liveness Rule 3: Validation Reaches Consensus**
- IF validation starts
- THEN consensus WILL eventually be reached
- ACTION: Never abandon validation midway

**Liveness Rule 4: Emergencies Lead to Recovery**
- IF emergency is triggered
- THEN system WILL eventually recover
- ACTION: Follow emergency protocols to completion

### Fairness Rules

**Fairness Rule: All Agents Get Turns**
- IF an agent is enabled/ready
- THEN it WILL eventually execute
- ACTION: No agent should be starved of resources

---

## Section 4: Operational Procedures

### Procedure 1: The 10-Step Verification Checklist

**When to Use**: Before considering any work complete

**Pre-Condition**: Repository state is unknown or dirty

**Steps**:
| Step | Action | Success Criteria |
|------|--------|-----------------|
| 1 | Clean workspace | No uncommitted changes |
| 2 | Compile with Patient Mode | Compilation completes |
| 3 | Count files | Exactly 773 files compiled |
| 4 | Check errors | 0 errors |
| 5 | Check warnings | 0 warnings |
| 6 | Run consensus validation | All 5 methods agree |
| 7 | Analyze logs | Log analysis complete |
| 8 | Code review | Review complete |
| 9 | Verify TDG compliance | All tests exist before code |
| 10 | STAMP safety check | All 72 constraints satisfied |

**Post-Condition**: Repository is certified clean AND safety is verified

**IF ANY STEP FAILS**: Stop and fix before continuing

---

### Procedure 2: The Automated Fix Cycle

**When to Use**: When errors exist in the log

**Pre-Condition**: At least one error exists

**Steps**:
1. Run `incremental_fix_prerequisite`
   - Identifies what needs fixing

2. Run `intelligent_batch_planner`
   - Plans the fix in batches of max 25 changes

3. Run `automated_fix_executor`
   - Applies the fixes

4. Run `consensus_validator`
   - Confirms fixes worked

**Post-Condition**: Either error is removed OR system rolls back

**Commands**:
```bash
elixir scripts/analysis/ast_compilation_fixer.exs --comprehensive-analysis
elixir scripts/analysis/five_level_rca_analyzer.exs --issue-type compilation_error
```

---

### Procedure 3: Dual Logging

**When to Use**: For every event that occurs

**Pre-Condition**: Event has been generated

**Action**: Call `Logger.info(Event)`

**Post-Condition**: Event appears in ALL THREE locations:
1. Standard output (console)
2. SigNoz (monitoring system)
3. File (in ./data/tmp)

**CHECK**: After logging an event:
- Can you see it in stdout? YES/NO
- Can you see it in SigNoz? YES/NO
- Is it in the log file? YES/NO

All three must be YES.

---

## Section 5: Safety Constraints (The 72 Rules)

### Understanding the Safety Hierarchy

Think of safety constraints as a pyramid:
- TOP: All 72 constraints satisfied = SAFE
- BOTTOM: Any constraint violated = FAILURE

The constraints are grouped into 9 categories. ALL constraints in ALL categories must be satisfied.

### Category A: Validation Constraints

| ID | Rule in Plain English |
|----|----------------------|
| SC-VAL-001 | Patient Mode is mandatory for all compilations |
| SC-VAL-003 | All 5 validation methods must be used and agree |
| SC-VAL-006 | Never skip validation steps (prevents EP-110 false positives) |

### Category B: Container Constraints

| ID | Rule in Plain English |
|----|----------------------|
| SC-CNT-009 | Only NixOS containers are allowed |
| SC-CNT-010 | Only localhost registry images are allowed |
| SC-CNT-012 | Containers must run in rootless mode |

### Category C: Agent Constraints

| ID | Rule in Plain English |
|----|----------------------|
| SC-AGT-017 | Agent coordination efficiency must be 90% or higher |
| SC-AGT-018 | Deadlocks between agents must be prevented |

### Category D: Compilation Constraints

| ID | Rule in Plain English |
|----|----------------------|
| SC-CMP-025 | Warnings must be treated as errors |
| SC-CMP-026 | All 773 files must be compiled |

### Category E: Data Integrity Constraints

| ID | Rule in Plain English |
|----|----------------------|
| SC-DAT-033 | Data must never be corrupted |
| SC-DAT-034 | Audit logs must maintain integrity |

### Category F: Security Constraints

| ID | Rule in Plain English |
|----|----------------------|
| SC-SEC-043 | Network isolation must be maintained |
| SC-SEC-044 | Code must pass Sobelow security checks |

### Category G: Performance Constraints

| ID | Rule in Plain English |
|----|----------------------|
| SC-PRF-050 | Response times must be under 50ms |
| SC-PRF-056 | System must stay within scalability limits |

### Category H: Emergency Constraints

| ID | Rule in Plain English |
|----|----------------------|
| SC-EMR-057 | Emergency stop must complete in under 5 seconds |
| SC-EMR-060 | Rollback capability must always exist |

### Category I: Observability Constraints

| ID | Rule in Plain English |
|----|----------------------|
| SC-OBS-065 | Logging must always be enabled |
| SC-OBS-069 | Dual logging to all 3 destinations is required |

---

## Section 6: Technology Rules

### File Protection

**These files CANNOT be modified without special authorization**:
- `CLAUDE.md`
- `README.md`
- `mix.exs`
- `devenv.nix`
- `tps_*.exs`
- `*.yml`, `*.yaml` (container configs)

**Before modifying any of these**: Get explicit authorization

### Allowed Technologies

| Technology | Status | Notes |
|------------|--------|-------|
| Elixir (.exs, .ex) | ALLOWED | Primary language |
| Python (.py) | ALLOWED | For specific scripts |
| Bash (.sh) | FORBIDDEN | Do not create new bash scripts |
| Node.js (.js) | FORBIDDEN | Not permitted |
| Ruby (.rb) | FORBIDDEN | Not permitted |
| Perl | FORBIDDEN | Not permitted |
| PowerShell | FORBIDDEN | Not permitted |

### Timestamp Rules

**ALWAYS**:
- Use `$(date)` command to get current time
- Use CEST or CET timezone
- Format: `YYYY-MM-DD HH:MM:SS [Zone]`

**NEVER**:
- Use UTC timezone
- Use `DateTime.utc_now()` in Elixir
- Use cached or assumed timestamps
- Make up a timestamp without checking the clock

**Example**:
```bash
# CORRECT
$(date)  # Returns: 2025-12-07 09:45:23 CEST

# WRONG
DateTime.utc_now()  # FORBIDDEN
```

### Log Storage

**ALL logs MUST go to**: `./data/tmp/`

**Naming convention**:
- Test logs: `./data/tmp/claude_test_TIMESTAMP.log`
- Compile logs: `./data/tmp/claude_compile_TIMESTAMP.log`
- Error logs: `./data/tmp/claude_error_TIMESTAMP.log`
- Performance logs: `./data/tmp/claude_perf_TIMESTAMP.log`
- Agent logs: `./data/tmp/claude_agent_TIMESTAMP.log`

**FORBIDDEN**:
- Logs in root directory
- Logs scattered in other locations
- Logs without timestamps
- Deleting logs without backup

---

## Section 7: Emergency Procedures

### EP-110 Response (False Positive Emergency)

**Trigger**: Validation methods disagree

**Step-by-Step Response**:
1. **HALT**: Stop all operations immediately
2. **LOG**: Create `./data/tmp/emergency_validation_[timestamp].log`
3. **RCA**: Execute 5-Level Root Cause Analysis
4. **CORRECT**: Fix the validation logic
5. **RE-VERIFY**: Run full Patient Mode compilation again

**Commands**:
```bash
# Emergency log
echo "EP-110 TRIGGERED at $(date)" >> ./data/tmp/emergency_validation_$(date +%Y%m%d_%H%M%S).log

# Root cause analysis
elixir scripts/analysis/five_level_rca_analyzer.exs --issue-type false_positive
```

### STAMP Violation Response

**Trigger**: Any of the 72 safety constraints is violated

**Step-by-Step Response**:
1. **HALT**: Stop the current process
2. **CAST**: Initiate CAST investigation (Causal Analysis using STAMP)
3. **REPORT**: Generate STAMP violation report
4. **MITIGATE**: Apply fix

**Commands**:
```bash
# CAST analysis
mix stamp.cast --incident-id INC-$(date +%Y%m%d%H%M%S) --priority P1

# Generate report
elixir scripts/stamp/cast_template_generator.exs --incident-id INC-XXXXX
```

### Container Emergency

**Commands for container problems**:
```bash
# Health check
elixir scripts/containers/verified_nixos_setup.exs --emergency-health-check

# SSL recovery
elixir scripts/containers/verified_nixos_setup.exs --ssl-recovery

# PHICS recovery
elixir scripts/containers/verified_nixos_setup.exs --phics-recovery

# Full reset (last resort)
elixir scripts/containers/verified_nixos_setup.exs --emergency-reset
```

### Emergency Stop Sequence

**When everything goes wrong**:

```bash
# Step 1: Immediate halt
elixir scripts/coordination/autonomous_compilation_engine.exs --emergency-stop

# Step 2: Check container health
elixir scripts/coordination/smart_container_orchestrator.exs --monitor

# Step 3: Check system status
elixir scripts/coordination/ultimate_15_agent_10_container_autonomous_executor.exs --status

# Step 4: Restart when safe
elixir scripts/coordination/autonomous_compilation_engine.exs --execute
```

---

## Section 8: Daily Workflows

### Morning Startup

```bash
# 1. Check environment variables
echo $NO_TIMEOUT $PATIENT_MODE $INFINITE_PATIENCE
# Should show: true enabled true

# 2. Get dependencies
mix deps.get

# 3. Verify compilation
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true mix compile --warnings-as-errors
```

### Container Workflow

```bash
# 1. Morning health check
elixir scripts/containers/verified_nixos_setup.exs --health-check

# 2. Verify hot-reloading
elixir scripts/containers/verified_nixos_setup.exs --phics-validation

# 3. Do development work (hot-reloading active)

# 4. End-of-day cleanup
elixir scripts/containers/verified_nixos_setup.exs --cleanup
```

### Before Committing Code

```bash
# Quality checks (ALL must pass)
mix format --check-formatted
mix credo --strict
mix dialyzer
mix sobelow --exit
mix test --coverage

# Container compliance
mix test test/stamp/container_safety_constraints_test.exs

# TDG compliance
mix test test/tdg/container_creation_test.exs
```

---

## Section 9: Quick Reference Card

### Environment Variables (Copy-Paste Ready)

```bash
export NO_TIMEOUT=true
export PATIENT_MODE=enabled
export INFINITE_PATIENCE=true
export ELIXIR_ERL_OPTIONS="+S 16"
export MIX_ENV=test
export PHICS_ENABLED=true
export PHICS_WATCH_ENABLED=true
export PHICS_CONTAINER_MODE=development
export PHICS_HOT_RELOAD=enabled
```

### Essential Commands

| Task | Command |
|------|---------|
| Patient compile | `NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS="+S 16" mix compile --warnings-as-errors 2>&1 \| tee -a log.txt` |
| Run tests | `mix test` |
| Check format | `mix format --check-formatted` |
| Check quality | `mix credo --strict` |
| Security scan | `mix sobelow --exit` |
| Validation | `elixir scripts/validation/unified_patient_mode_validation_orchestrator.exs --validate` |
| System status | `elixir scripts/coordination/ultimate_15_agent_10_container_autonomous_executor.exs --status` |
| Emergency stop | `elixir scripts/coordination/autonomous_compilation_engine.exs --emergency-stop` |

### The 5 Validation Methods

1. Pattern Matching
2. AST Analysis
3. Statistical Analysis
4. Binary Scanning
5. Line-by-Line Analysis

**Rule**: ALL 5 must agree or HALT

### The 9 Safety Categories

1. VAL (Validation)
2. CNT (Container)
3. AGT (Agent)
4. CMP (Compilation)
5. DAT (Data)
6. SEC (Security)
7. PRF (Performance)
8. EMR (Emergency)
9. OBS (Observability)

**Rule**: ALL 72 constraints across all 9 categories must be satisfied

---

## Summary Checklist

### Before ANY Compilation

- [ ] NO_TIMEOUT=true set?
- [ ] PATIENT_MODE=enabled set?
- [ ] INFINITE_PATIENCE=true set?
- [ ] ELIXIR_ERL_OPTIONS="+S 16" set?
- [ ] Using --warnings-as-errors?
- [ ] Output going to log file?
- [ ] NOT using forbidden commands?

### Before Claiming Success

- [ ] All 5 validation methods run?
- [ ] All 5 methods agree?
- [ ] Zero errors?
- [ ] Zero warnings?
- [ ] All tests pass?
- [ ] Format check passes?
- [ ] Credo check passes?
- [ ] Sobelow passes?

### Before Deployment

- [ ] All 72 STAMP constraints satisfied?
- [ ] All containers healthy?
- [ ] PHICS latency < 50ms?
- [ ] Logs in correct location?
- [ ] Timestamps using local time?
- [ ] TDG compliance verified?

---

**End of CLAUDE-descriptive.md**

This document provides human-readable, agent-executable instructions that correspond to the mathematical specifications in CLAUDE.md v6.0.0. When in doubt, refer to the formal mathematical definitions in CLAUDE.md for the authoritative specification.
