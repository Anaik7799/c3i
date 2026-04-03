# PASS5: Change Management Runbooks

**Version**: 21.3.0-SIL6 | **Date**: 2026-01-10 | **Author**: Claude Opus 4.5
**Status**: ACTIVE | **Compliance**: IEC 61508 SIL-6 (Biomorphic Extended)
**Document ID**: RUNBOOK-PASS5-001

---

## Document Control

| Field | Value |
|-------|-------|
| Classification | OPERATIONAL |
| Review Cycle | Monthly |
| Owner | Operations Team |
| STAMP Coverage | SC-CHG-*, SC-FUNC-*, SC-OODA-*, SC-EMR-* |
| AOR Coverage | AOR-CHG-*, AOR-FUNC-*, AOR-OODA-*, AOR-EMR-* |

---

## Table of Contents

1. [Daily Operations Runbook](#1-daily-operations-runbook)
2. [Change Execution Runbooks](#2-change-execution-runbooks)
3. [Rollback Runbooks](#3-rollback-runbooks)
4. [Incident Response Runbooks](#4-incident-response-runbooks)
5. [Evolution Runbooks](#5-evolution-runbooks)
6. [Quick Reference](#6-quick-reference)

---

# 1. Daily Operations Runbook

## 1.1 Morning Health Check Procedure

**Trigger**: Start of shift (08:00 CEST)
**Owner**: On-Call Engineer
**Duration**: 15-20 minutes
**STAMP**: SC-FUNC-002, SC-OBS-069

### Step 1: Enter Development Environment

```bash
# Navigate to project directory
cd /home/an/dev/ver/intelitor-v5.2

# Enter devenv shell
devenv shell

# Verify environment
echo "Elixir: $(elixir --version | head -1)"
echo "OTP: $(erl -eval 'io:fwrite("~s~n", [erlang:system_info(otp_release)]), halt().' -noshell)"
echo "Podman: $(podman --version)"
```

### Step 2: Check Container Stack Health

```bash
# Check container status
sa-status

# Expected output validation:
# - indrajaal-db-prod: healthy
# - indrajaal-obs-prod: healthy
# - indrajaal-ex-app-1: healthy

# If containers not running:
sa-up

# Verify health after boot
sa-health
```

### Step 3: Verify OODA Cycle Health

```bash
# Check OODA cycle metrics via Prometheus
curl -s http://localhost:9090/api/v1/query?query=ooda_fast_cycle_ms | jq '.data.result[0].value[1]'
# Expected: < 100ms

curl -s http://localhost:9090/api/v1/query?query=ooda_strategy_cycle_ms | jq '.data.result[0].value[1]'
# Expected: < 1000ms
```

### Step 4: Verify Compilation State

```bash
# Quick compile check
compile

# Expected: 0 errors, 0 warnings
# Log location: ./data/tmp/1-compile.log

# If warnings present, escalate per SC-CMP-025
```

### Step 5: Verify Quality Gates

```bash
# Run basic quality check
quality

# For full verification (15 min longer):
# quality-full
```

### Step 6: Check Agent Swarm Status

```bash
# Via Prajna dashboard
curl -s http://localhost:4000/api/prajna/metrics | jq '.agent_count'
# Expected: 45-50 active agents

# Check Guardian status
curl -s http://localhost:4000/api/prajna/guardian/status
# Expected: "ready", 0 pending proposals
```

### Step 7: Log Morning Check Results

```bash
# Record morning health check
echo "$(date -Iseconds) MORNING_CHECK: PASS" >> ./data/logs/daily_operations.log
```

### Decision Tree: Morning Health Check Failures

```
Container Status?
├── All Healthy → Proceed to Step 3
├── DB Unhealthy → sa-db restart, wait 60s, retry
├── OBS Unhealthy → sa-obs restart, wait 30s, retry
├── APP Unhealthy → Check logs: sa-logs indrajaal-ex-app-1
└── All Down → sa-clean && sa-up, notify team

OODA Cycle?
├── Fast OODA > 100ms → Scale workers: see IR-001
├── Strategy OODA > 2s → Check F# health, escalate
└── Both normal → Continue

Compilation?
├── 0 errors, 0 warnings → Continue
├── Warnings only → Log, schedule fix
└── Errors → HALT, escalate to IR-001

Agent Swarm?
├── 45+ agents → Healthy
├── 25-44 agents → Warning, check API limits
└── < 25 agents → Escalate, check rate limits
```

---

## 1.2 Change Window Scheduling

**STAMP**: SC-CHG-001, SC-CHG-009
**AOR**: AOR-CHG-002

### Change Window Types

| Window Type | Hours (CEST) | Impact Allowed | Approval Required |
|-------------|--------------|----------------|-------------------|
| Standard | 09:00-17:00 | 0-20 | Peer review |
| Senior | 10:00-16:00 | 21-30 | Senior + Architecture |
| Critical | 14:00-15:00 | 31-40 | Guardian + Executive |
| Emergency | 24/7 | 40+ | Immediate + Postmortem |

### Pre-Change Window Checklist

```bash
# 1. Verify no ongoing incidents
curl -s http://localhost:4000/api/prajna/sentinel/threats | jq '.active_count'
# Must be 0 for non-emergency changes

# 2. Check error budget
curl -s http://localhost:4000/api/prajna/sre/error_budget
# Must be > 20% for non-emergency changes

# 3. Create checkpoint before window opens
sa-checkpoint --phase full
echo "Checkpoint created: $(date -Iseconds)" >> ./data/logs/change_windows.log

# 4. Notify team
# (Integration with notification system)
```

### Change Window Calendar Integration

```bash
# Check today's scheduled changes
cat PROJECT_TODOLIST.md | grep -A5 "$(date +%Y-%m-%d)"

# List pending changes by impact score
git log --oneline --since="7 days ago" | head -20
```

---

## 1.3 Agent Swarm Monitoring

**STAMP**: SC-BIO-003, SC-API-001
**AOR**: AOR-API-004, AOR-BIO-002

### Real-Time Swarm Dashboard

```bash
# Terminal dashboard (30s refresh)
watch -n 30 'curl -s http://localhost:4000/api/prajna/swarm/status | jq .'

# Key metrics to monitor:
# - executive_agents: 1
# - supervisor_agents: 10
# - functional_agents: 15
# - worker_agents: 20-24
```

### Agent Scaling Decision Matrix

| API Usage | Context Usage | Action |
|-----------|---------------|--------|
| < 40% | < 50% | Scale UP (max 50 agents) |
| 40-70% | 50-75% | Maintain current |
| 70-90% | 75-85% | Scale DOWN gradually |
| > 90% | > 85% | Emergency scale to 1 agent |

### Scaling Commands

```bash
# Manual scale adjustment (rarely needed)
# Agents auto-scale based on API telemetry

# Check current API usage
curl -s http://localhost:4000/api/prajna/api/usage | jq '{
  rpm: .requests_per_minute,
  tpm: .tokens_per_minute,
  error_rate: .error_rate
}'

# If rate limit approaching, trigger graceful degradation
curl -X POST http://localhost:4000/api/prajna/agents/scale_down
```

---

## 1.4 OODA Cycle Verification

**STAMP**: SC-OODA-001, SC-OODA-005
**AOR**: AOR-OODA-001 through AOR-OODA-005

### Fast OODA Verification (L1-L2)

```bash
# Check Fast OODA timing breakdown
curl -s http://localhost:9090/api/v1/query?query=ooda_fast_observe_ms | jq '.data.result[0].value[1]'
# Budget: 5ms

curl -s http://localhost:9090/api/v1/query?query=ooda_fast_orient_ms | jq '.data.result[0].value[1]'
# Budget: 15ms

curl -s http://localhost:9090/api/v1/query?query=ooda_fast_decide_ms | jq '.data.result[0].value[1]'
# Budget: 15ms

curl -s http://localhost:9090/api/v1/query?query=ooda_fast_act_ms | jq '.data.result[0].value[1]'
# Budget: 15ms
```

### Strategy OODA Verification (L5-L7)

```bash
# Strategy OODA from F# Cortex (via Zenoh)
curl -s http://localhost:4000/api/zenoh/ooda/strategy/metrics | jq '.last_cycle_ms'
# Budget: 1000ms

# Constitutional check timing
curl -s http://localhost:4000/api/zenoh/constitutional/check_time_ms
# Should be < 100ms
```

### OODA Hysteresis Check

```bash
# Verify hysteresis is preventing oscillation
curl -s http://localhost:4000/api/prajna/ooda/hysteresis | jq '{
  margin: .margin,          # Should be 0.1 (10%)
  hold_cycles: .hold_cycles, # Should be 3
  current_hold: .current_hold
}'
```

---

# 2. Change Execution Runbooks

## 2.1 SOP-CHG-001: Standard Change (Impact < 20)

**Trigger**: Impact score 0-20
**Duration**: 30 minutes - 2 hours
**Approval**: 1 peer reviewer
**STAMP**: SC-CHG-001, SC-CHG-002
**AOR**: AOR-CHG-001, AOR-CHG-003

### Phase 1: Planning (10 min)

```bash
# Step 1.1: Create change note
CHANGE_ID="CHG-$(date +%Y%m%d-%H%M%S)-$(openssl rand -hex 4 | head -c 8)"
echo "Change ID: $CHANGE_ID"

# Step 1.2: Calculate impact score
# Use impact calculator:
elixir scripts/change_management/calculate_impact.exs \
  --files "lib/indrajaal/module.ex" \
  --type "bugfix"
# Expected output: Impact Score: 8 (L1:2, L2:4, L3:2, L4:0)

# Step 1.3: Document in PR template
cat > /tmp/change_note.md << 'EOF'
## Change Note: ${CHANGE_ID}

### Impact Analysis
| Layer | Impact | Score |
|-------|--------|-------|
| L1-CODE | LOW | 2 |
| L2-DOMAIN | LOW | 4 |
| L3-SYSTEM | LOW | 2 |
| L4-ECOSYSTEM | NONE | 0 |
| **TOTAL** | | **8** |

### Reversal
```bash
git revert $(git rev-parse HEAD)
```
EOF
```

### Phase 2: Checkpoint (2 min)

```bash
# Step 2.1: Create pre-change checkpoint
sa-checkpoint --phase 1
# Phase 1 captures: File system, KMS, Git state

# Step 2.2: Record checkpoint ID
CHECKPOINT_ID=$(cat ./data/checkpoints/latest/manifest.json | jq -r '.checkpoint_id')
echo "Checkpoint: $CHECKPOINT_ID" >> /tmp/change_note.md
```

### Phase 3: Implementation (Variable)

```bash
# Step 3.1: Create feature branch
git checkout -b fix/$CHANGE_ID

# Step 3.2: Make changes
# (Implementation varies by change)

# Step 3.3: Update in-file change history
# Add to @moduledoc:
# | 21.3.0 | 2026-01-10 | Claude | Description |

# Step 3.4: Commit with structured message
git add -A
git commit -m "$(cat <<EOF
fix(module): Brief description

Change-Id: $CHANGE_ID
Impact-Score: 8
Layers-Affected: L1,L2,L3
Reversal: git revert \$(git rev-parse HEAD)

STAMP: SC-CHG-001
AOR: AOR-CHG-001

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Phase 4: Verification (10 min)

```bash
# Step 4.1: Compile verification
compile-strict
# Exit 0 required

# Step 4.2: Quality gate
quality
# Exit 0 required

# Step 4.3: Test suite
test
# 0 failures required

# Step 4.4: Health check
sa-health
# All methods must agree (FPPS consensus)
```

### Phase 5: Review (Variable)

```bash
# Step 5.1: Push for review
git push -u origin fix/$CHANGE_ID

# Step 5.2: Create PR (if not using gh cli)
gh pr create --title "fix(module): Description" \
  --body-file /tmp/change_note.md \
  --label "impact:standard"
```

### Phase 6: Merge

```bash
# Step 6.1: After approval, merge
git checkout main
git merge fix/$CHANGE_ID

# Step 6.2: Log to Immutable Register
elixir scripts/register/log_change.exs --change-id $CHANGE_ID

# Step 6.3: Update CHANGELOG.md
# (Automated by pre-push hook)
```

### Phase 7: Monitor (24h)

```bash
# Step 7.1: Watch for regressions
# Sentinel will alert if anomalies detected

# Step 7.2: Verify OODA cycles stable
curl -s http://localhost:9090/api/v1/query?query=ooda_fast_cycle_ms | jq '.data.result[0].value[1]'

# Step 7.3: Close change ticket after 24h stability
```

---

## 2.2 SOP-CHG-002: High-Risk Change (Impact 21-30)

**Trigger**: Impact score 21-30
**Duration**: 2-4 hours
**Approval**: 2 senior reviewers
**STAMP**: SC-CHG-009, SC-GDE-001
**AOR**: AOR-CHG-002, AOR-CHG-007

### Additional Requirements vs Standard Change

```
+------------------------+-------------------+---------------------+
| Requirement            | Standard (< 20)   | High-Risk (21-30)   |
+------------------------+-------------------+---------------------+
| Checkpoint Phase       | Phase 1           | Phase 2 (+ CRIU)    |
| Shadow Testing         | Optional          | MANDATORY           |
| Guardian Notification  | No                | Yes                 |
| Senior Review          | No                | 2 required          |
| Architecture Review    | No                | Recommended         |
| Rollback Test          | Optional          | MANDATORY           |
+------------------------+-------------------+---------------------+
```

### Phase 1: Enhanced Planning (20 min)

```bash
# Step 1.1: Full 4-layer impact analysis
elixir scripts/change_management/full_impact_analysis.exs \
  --files "lib/indrajaal/domains/*.ex" \
  --type "feature"

# Step 1.2: 5-Order effects documentation
cat > /tmp/5_order_effects.md << 'EOF'
## 5-Order Effects Analysis

| Order | Effect | Mitigation |
|-------|--------|------------|
| 1st | Direct code changes to domain | Test coverage |
| 2nd | Adjacent domain interactions | Integration tests |
| 3rd | System integration changes | sa-health verification |
| 4th | Operational capability changes | Runbook update |
| 5th | Ecosystem/federation effects | Federation notify |
EOF

# Step 1.3: Notify Guardian
curl -X POST http://localhost:4000/api/prajna/guardian/notify \
  -H "Content-Type: application/json" \
  -d '{"change_id": "'$CHANGE_ID'", "impact_score": 25}'
```

### Phase 2: Enhanced Checkpoint (5 min)

```bash
# Step 2.1: Full checkpoint with container state
sa-checkpoint --phase 2
# Phase 2 adds CRIU memory snapshots

# Step 2.2: Verify checkpoint integrity
sa-checkpoint-verify
```

### Phase 3: Shadow Testing (30 min)

```bash
# Step 3.1: Fork shadow environment
elixir scripts/shadow/create_shadow_env.exs --change-id $CHANGE_ID

# Step 3.2: Apply changes to shadow
cd shadow_env
git cherry-pick $COMMIT_SHA

# Step 3.3: Run full test suite in shadow
mix test --cover
# Coverage must remain >= 95%

# Step 3.4: Collect shadow metrics
elixir scripts/shadow/collect_metrics.exs > /tmp/shadow_metrics.json

# Step 3.5: Destroy shadow environment
elixir scripts/shadow/destroy_shadow_env.exs --change-id $CHANGE_ID
```

### Phase 4: Implementation

Same as Standard Change, but with additional verification.

### Phase 5: Rollback Testing (10 min)

```bash
# Step 5.1: Deploy to staging
# (Environment-specific)

# Step 5.2: Verify functionality
curl -f http://localhost:4000/health

# Step 5.3: Execute rollback
git revert HEAD --no-edit

# Step 5.4: Verify system stable after rollback
compile && test

# Step 5.5: Re-apply change
git revert HEAD --no-edit
```

### Phase 6: Enhanced Review

```bash
# Step 6.1: Senior review required
gh pr edit --add-reviewer senior-dev-1,senior-dev-2

# Step 6.2: Add high-risk label
gh pr edit --add-label "impact:high-risk"

# Step 6.3: Architecture review (recommended)
gh pr edit --add-reviewer architect-team
```

---

## 2.3 SOP-CHG-003: Critical Change (Impact 31-40)

**Trigger**: Impact score 31-40
**Duration**: 4-8 hours
**Approval**: Guardian + 3 reviewers
**STAMP**: SC-CHG-007, SC-GDE-004, SC-CONST-007
**AOR**: AOR-CHG-010, AOR-CONST-001

### Pre-Conditions

```bash
# MANDATORY pre-checks before proceeding

# Check 1: Error budget must be > 30%
ERROR_BUDGET=$(curl -s http://localhost:4000/api/prajna/sre/error_budget | jq '.remaining_percent')
if (( $(echo "$ERROR_BUDGET < 30" | bc -l) )); then
  echo "ERROR: Insufficient error budget ($ERROR_BUDGET%). HALT."
  exit 1
fi

# Check 2: No active incidents
ACTIVE_INCIDENTS=$(curl -s http://localhost:4000/api/prajna/sentinel/threats | jq '.active_count')
if [ "$ACTIVE_INCIDENTS" -gt 0 ]; then
  echo "ERROR: Active incidents detected ($ACTIVE_INCIDENTS). HALT."
  exit 1
fi

# Check 3: Guardian must be available
GUARDIAN_STATUS=$(curl -s http://localhost:4000/api/prajna/guardian/status | jq -r '.status')
if [ "$GUARDIAN_STATUS" != "ready" ]; then
  echo "ERROR: Guardian not ready ($GUARDIAN_STATUS). HALT."
  exit 1
fi
```

### Phase 1: Guardian Pre-Approval (30 min)

```bash
# Step 1.1: Submit proposal to Guardian
PROPOSAL_ID=$(curl -X POST http://localhost:4000/api/prajna/guardian/propose \
  -H "Content-Type: application/json" \
  -d '{
    "change_id": "'$CHANGE_ID'",
    "impact_score": 35,
    "layer": "L3",
    "description": "Critical system change",
    "constitutional_check": true,
    "shadow_test_required": true
  }' | jq -r '.proposal_id')

echo "Proposal submitted: $PROPOSAL_ID"

# Step 1.2: Wait for Guardian validation (6 checks)
while true; do
  STATUS=$(curl -s http://localhost:4000/api/prajna/guardian/proposal/$PROPOSAL_ID | jq -r '.status')
  if [ "$STATUS" == "approved" ]; then
    echo "Guardian APPROVED"
    break
  elif [ "$STATUS" == "rejected" ]; then
    echo "Guardian REJECTED. Check reason:"
    curl -s http://localhost:4000/api/prajna/guardian/proposal/$PROPOSAL_ID | jq '.rejection_reason'
    exit 1
  fi
  sleep 10
done

# Step 1.3: Record proof token
PROOF_TOKEN=$(curl -s http://localhost:4000/api/prajna/guardian/proposal/$PROPOSAL_ID | jq -r '.proof_token')
echo "Proof Token: $PROOF_TOKEN"
```

### Phase 2: Full Checkpoint (10 min)

```bash
# Step 2.1: Full 4-phase checkpoint
sa-checkpoint --phase full
# Captures: FileSystem, KMS, Container, Volume, Zenoh, DuckDB, Env

# Step 2.2: Verify all 46 tests pass
sa-checkpoint-verify
# Expected: 40 pass, 6 skip (offline mode acceptable)

# Step 2.3: Record checkpoint manifest
CHECKPOINT_MANIFEST=$(cat ./data/checkpoints/latest/manifest.json)
echo "$CHECKPOINT_MANIFEST" > /tmp/critical_change_checkpoint.json
```

### Phase 3: Constitutional Verification

```bash
# Step 3.1: Run constitutional oracle
elixir scripts/constitutional/verify_change.exs --change-id $CHANGE_ID

# Expected output:
# Psi_0 (Existence): PASSED
# Psi_1 (Regeneration): PASSED
# Psi_2 (History): PASSED
# Psi_3 (Verification): PASSED
# Psi_4 (Human Alignment): PASSED
# Psi_5 (Truthfulness): PASSED

# Step 3.2: If any FAIL, HALT immediately
```

### Phase 4: Controlled Implementation

```bash
# Step 4.1: Announce change window
curl -X POST http://localhost:4000/api/prajna/notifications/broadcast \
  -H "Content-Type: application/json" \
  -d '{"type": "critical_change", "change_id": "'$CHANGE_ID'", "duration_hours": 4}'

# Step 4.2: Implement with progressive rollout
# 5% -> Verify -> 25% -> Verify -> 100%
# (Application-specific implementation)

# Step 4.3: Continuous monitoring during rollout
watch -n 5 'curl -s http://localhost:4000/api/prajna/health/score'
```

### Phase 5: Architecture + Guardian Review

```bash
# Step 5.1: Required reviewers
gh pr edit --add-reviewer guardian-team,architecture-team,senior-dev-1

# Step 5.2: Add critical label
gh pr edit --add-label "impact:critical,guardian-required"

# Step 5.3: Document proof token in PR
echo "Guardian Proof Token: $PROOF_TOKEN" >> /tmp/change_note.md
```

---

## 2.4 SOP-CHG-004: Emergency Change (Impact 40+)

**Trigger**: Impact score 40+ OR Critical system failure
**Duration**: Immediate
**Approval**: Executive authority (post-facto)
**STAMP**: SC-EMR-057, SC-EMR-060
**AOR**: AOR-CONST-002, AOR-FUNC-005

### ALERT: This is an emergency procedure

```
╔══════════════════════════════════════════════════════════════════════╗
║                         EMERGENCY PROTOCOL                            ║
║                                                                        ║
║  This procedure is for IMMEDIATE system-threatening situations        ║
║  Normal change management is SUSPENDED                                ║
║  All actions logged for postmortem                                    ║
║                                                                        ║
╚══════════════════════════════════════════════════════════════════════╝
```

### Immediate Actions (< 60 seconds)

```bash
# Step 1: Emergency stop
sa-emergency
# Forces stop in < 5 seconds (SC-EMR-057)

# Step 2: Log incident start
INCIDENT_ID="INC-$(date +%Y%m%d-%H%M%S)"
echo "$INCIDENT_ID: Emergency protocol activated at $(date -Iseconds)" >> ./data/logs/incidents.log

# Step 3: Notify all stakeholders (automated)
# Zenoh broadcasts to all subscribed systems
```

### Assessment (< 5 minutes)

```bash
# Step 4: Rapid assessment
# What is broken?
sa-status
sa-logs --tail 100

# Step 5: Determine rollback level
# Decision tree:
# - Compilation failure → RB-L1 (Git)
# - Test failure → RB-L2 (Code)
# - Data corruption → RB-L3 (Database)
# - System failure → RB-L4 (Full checkpoint)
```

### Emergency Rollback

```bash
# Step 6: Execute appropriate rollback
# See Section 3 for detailed rollback procedures

# For full system restore:
sa-checkpoint-restore --phase full --emergency

# Step 7: Verify system functional
compile && test && sa-health
```

### Post-Emergency (< 24 hours)

```bash
# Step 8: Postmortem documentation
cat > ./data/incidents/$INCIDENT_ID/postmortem.md << 'EOF'
## Incident Postmortem: ${INCIDENT_ID}

### Timeline
- T+0: [Trigger event]
- T+1m: Emergency protocol activated
- T+5m: Assessment complete
- T+10m: Rollback executed
- T+15m: System stable

### Root Cause Analysis (5-Why)
1. Why did the system fail?
2. Why was that condition not caught?
3. Why did existing safeguards not prevent this?
4. Why was monitoring insufficient?
5. What is the root cause?

### Corrective Actions
- [ ] New STAMP constraint: SC-xxx-xxx
- [ ] New test case
- [ ] Updated monitoring
- [ ] Training episode in TrainingGym
EOF

# Step 9: Update FMEA with new failure mode
elixir scripts/fmea/add_failure_mode.exs --incident $INCIDENT_ID
```

---

# 3. Rollback Runbooks

## 3.1 RB-L1: Git Revert (Immediate)

**Scope**: Code changes only (L1)
**Duration**: < 1 minute
**STAMP**: SC-CHG-REVERSE, SC-FUNC-003

### When to Use

- Pure function changes
- Documentation updates
- Test file changes
- No database or container impact

### Procedure

```bash
# Option A: Revert single commit
git revert HEAD --no-edit

# Option B: Revert specific commit
git revert $COMMIT_SHA --no-edit

# Option C: Revert range of commits
git revert $OLDER_SHA..$NEWER_SHA --no-edit

# Verification
compile-strict
echo "L1 Rollback complete: $(git rev-parse HEAD)"
```

### Decision Tree

```
Is it the most recent commit?
├── Yes → git revert HEAD
└── No → git revert $SPECIFIC_SHA

Are there merge commits in range?
├── Yes → git revert -m 1 $MERGE_SHA
└── No → Standard revert

Did revert succeed?
├── Yes → Verify compilation
└── No (conflicts) → Manual resolution or escalate to RB-L2
```

---

## 3.2 RB-L2: Code Restore (Minutes)

**Scope**: Module-level changes (L1-L2)
**Duration**: 5-15 minutes
**STAMP**: SC-FUNC-001, SC-CHG-003

### When to Use

- GenServer state changes
- Domain logic changes
- API changes affecting multiple modules
- Conflicts prevent simple git revert

### Procedure

```bash
# Step 1: Identify affected files
git diff $GOOD_COMMIT..$BAD_COMMIT --name-only

# Step 2: Restore from known good state
git checkout $GOOD_COMMIT -- lib/indrajaal/affected_module.ex

# Step 3: Force recompile
mix compile --force

# Step 4: Run targeted tests
mix test test/affected_module_test.exs

# Step 5: Verify quality
quality

# Step 6: Commit restoration
git add -A
git commit -m "fix: Restore module from $GOOD_COMMIT

Rollback-Type: RB-L2
Original-Commit: $BAD_COMMIT
Restored-From: $GOOD_COMMIT

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

### File-by-File Restoration

```bash
# If backup exists
if [ -f "_backup/module.ex.bak" ]; then
  cp _backup/module.ex.bak lib/indrajaal/module.ex
fi

# If checkpoint exists
if [ -d "./data/checkpoints/latest/files" ]; then
  cp ./data/checkpoints/latest/files/lib/indrajaal/module.ex lib/indrajaal/module.ex
fi
```

---

## 3.3 RB-L3: Database Rollback (Minutes-Hours)

**Scope**: Database schema/data changes (L3)
**Duration**: 10 minutes - 2 hours
**STAMP**: SC-MIG-001, SC-HOLON-001

### When to Use

- Migration failure
- Data corruption
- Schema rollback needed
- Holon state restore

### Procedure: Migration Rollback

```bash
# Step 1: Check current migration version
mix ecto.migrations

# Step 2: Rollback last migration
mix ecto.rollback --step 1

# Step 3: Verify schema
mix run -e "Indrajaal.Repo.query!(\"SELECT version_num FROM schema_migrations ORDER BY version_num DESC LIMIT 1\") |> IO.inspect()"

# Step 4: If rollback fails, restore from backup
```

### Procedure: Full Database Restore

```bash
# Step 1: Stop application
sa-down

# Step 2: Drop and recreate database
mix ecto.drop
mix ecto.create

# Step 3: Restore from backup
pg_restore -d indrajaal_dev ./data/backups/db_$(date +%Y%m%d).dump

# Step 4: Verify and migrate
mix ecto.migrate
mix run scripts/verify_data_integrity.exs

# Step 5: Restart
sa-up
```

### Procedure: Holon State Restore

```bash
# Step 1: Locate SQLite/DuckDB files
ls -la ./data/holons/

# Step 2: Restore from checkpoint
cp ./data/checkpoints/$CHECKPOINT_ID/holons/* ./data/holons/

# Step 3: Verify integrity
elixir scripts/holon/verify_integrity.exs

# Step 4: Restart holon services
mix run -e "Indrajaal.Holon.restart_all()"
```

---

## 3.4 RB-L4: System Checkpoint Restore (Hours)

**Scope**: Full system state (L4+)
**Duration**: 30 minutes - 4 hours
**STAMP**: SC-UCR-001, SC-EMR-060

### When to Use

- Container configuration failure
- Multi-system corruption
- Constitutional violation recovery
- Post-emergency restoration

### Procedure: Full Restore

```bash
# Step 1: Stop all containers
sa-emergency  # Or sa-down for graceful stop

# Step 2: List available checkpoints
sa-checkpoint-list
# Output: checkpoint_id, timestamp, phase, size

# Step 3: Select and verify checkpoint
RESTORE_CHECKPOINT="chk-20260110-120000"
sa-checkpoint-verify --checkpoint $RESTORE_CHECKPOINT

# Step 4: Execute restore
sa-checkpoint-restore --phase full --checkpoint $RESTORE_CHECKPOINT

# Step 5: Wait for restore (progress shown)
# Phase 1: File/KMS/Git restore
# Phase 2: CRIU container memory restore (if captured)
# Phase 3: Zenoh mesh state restore
# Phase 4: Verification

# Step 6: Verify restoration
sa-health
sa-verify

# Step 7: Restart services
sa-up

# Step 8: Verify functional state
compile && test && quality
```

### Restore Verification Checklist

```bash
# Mandatory post-restore checks

# 1. Container health
sa-status
# All must be "healthy"

# 2. Database connectivity
db-console -c "SELECT 1;"

# 3. Compilation
compile-strict

# 4. Test suite
test

# 5. OODA cycles
curl -s http://localhost:4000/api/prajna/ooda/status

# 6. Guardian status
curl -s http://localhost:4000/api/prajna/guardian/status

# 7. Constitutional integrity
elixir scripts/constitutional/verify_all.exs
```

---

# 4. Incident Response Runbooks

## 4.1 IR-001: Compilation Failure

**Severity**: CRITICAL
**Response Time**: < 5 minutes
**STAMP**: SC-FUNC-001, SC-CMP-025

### Detection

```bash
# Automatic detection via CI
# Manual check:
compile-strict 2>&1 | grep -E "(error|warning)"
```

### Triage Decision Tree

```
Compilation Error Type?
├── Syntax Error
│   └── Identify file:line → Fix or revert file
├── Missing Module
│   └── Check deps.lock → mix deps.get or revert
├── Type Error
│   └── Check @spec → Fix or relax spec
├── NIF Compilation
│   └── Check Rust version → See NIF troubleshooting
└── Unknown
    └── Escalate to senior
```

### Response Procedure

```bash
# Step 1: Capture error details
compile 2>&1 | tee /tmp/compile_error.log

# Step 2: Identify failing file
FAILING_FILE=$(grep -oP 'lib/[^\s:]+' /tmp/compile_error.log | head -1)
echo "Failing file: $FAILING_FILE"

# Step 3: Check recent changes to file
git log --oneline -5 -- $FAILING_FILE

# Step 4: Quick fix or revert
# Option A: Fix if trivial
# Option B: Revert to last good commit
git checkout HEAD~1 -- $FAILING_FILE

# Step 5: Verify fix
compile-strict

# Step 6: Log incident
echo "$(date -Iseconds) IR-001: Compilation failure resolved for $FAILING_FILE" >> ./data/logs/incidents.log
```

### NIF-Specific Troubleshooting

```bash
# Check Rustler version match
grep "rustler" mix.exs
grep "rustler" native/*/Cargo.toml

# If mismatch, align versions
# Then rebuild:
mix compile --force

# If persistent:
rm -rf _build/dev/lib/*/native
mix deps.compile
```

---

## 4.2 IR-002: Test Failure

**Severity**: HIGH
**Response Time**: < 15 minutes
**STAMP**: SC-TEST-001, SC-TDG-001

### Detection

```bash
# Run test suite
test 2>&1 | grep -E "(failures|errors)"
```

### Triage Decision Tree

```
Test Failure Type?
├── Assertion Failed
│   └── Check expected vs actual → Fix logic or test
├── Setup Error
│   └── Check factory/fixtures → Fix setup or DB state
├── Timeout
│   └── Check async operations → Increase timeout or fix
├── Connection Error
│   └── Check containers → sa-status and restart
└── Intermittent (Flaky)
    └── Tag @flaky and investigate
```

### Response Procedure

```bash
# Step 1: Run failing test in isolation
MIX_ENV=test mix test test/path_to_test.exs:42 --trace

# Step 2: Check if DB-related
mix ecto.rollback --all
mix ecto.migrate
mix test test/path_to_test.exs:42

# Step 3: Check if container-related
sa-status
sa-db  # Restart DB if needed

# Step 4: Fix or rollback
# If fix is quick (< 15 min): Fix
# If complex: Revert and investigate

# Step 5: Verify all tests pass
test

# Step 6: Log incident
echo "$(date -Iseconds) IR-002: Test failure resolved" >> ./data/logs/incidents.log
```

---

## 4.3 IR-003: Container Health Degradation

**Severity**: MEDIUM-HIGH
**Response Time**: < 10 minutes
**STAMP**: SC-CNT-009, SC-PRF-050

### Detection

```bash
# Check container status
sa-status | grep -E "(unhealthy|exited)"

# Check response times
curl -w "%{time_total}\n" -o /dev/null -s http://localhost:4000/health
# Should be < 0.05s (50ms)
```

### Container-Specific Procedures

#### Database Container (indrajaal-db-prod)

```bash
# Step 1: Check logs
sa-logs indrajaal-db-prod --tail 50

# Step 2: Check connections
podman exec indrajaal-db-prod pg_isready

# Step 3: If unhealthy, restart
podman restart indrajaal-db-prod

# Step 4: Verify recovery
sleep 30
curl -f http://localhost:5433/health || sa-db
```

#### Observability Container (indrajaal-obs-prod)

```bash
# Step 1: Check OTEL collector
curl -s http://localhost:4317/v1/status

# Step 2: Check Prometheus
curl -s http://localhost:9090/-/ready

# Step 3: If unhealthy, restart
podman restart indrajaal-obs-prod

# Step 4: Verify metrics flowing
curl -s http://localhost:9090/api/v1/query?query=up
```

#### Application Container (indrajaal-ex-app-1)

```bash
# Step 1: Check Phoenix
curl -f http://localhost:4000/health

# Step 2: Check logs for errors
sa-logs indrajaal-ex-app-1 --tail 100 | grep -E "(error|ERROR|crash)"

# Step 3: If unhealthy, restart
podman restart indrajaal-ex-app-1

# Step 4: Verify recovery
sleep 60
curl -f http://localhost:4000/health
```

---

## 4.4 IR-004: Constitutional Violation

**Severity**: CRITICAL
**Response Time**: IMMEDIATE
**STAMP**: SC-CONST-001 through SC-CONST-010

### Detection

```bash
# Guardian or Sentinel will raise alert
curl -s http://localhost:4000/api/prajna/constitutional/status | jq '.violations'
```

### ALERT: Constitutional violations require immediate action

```
╔══════════════════════════════════════════════════════════════════════╗
║                  CONSTITUTIONAL VIOLATION DETECTED                    ║
║                                                                        ║
║  Invariant violated: [Psi_0-5]                                        ║
║  System integrity at risk                                             ║
║  HALT all operations immediately                                      ║
║                                                                        ║
╚══════════════════════════════════════════════════════════════════════╝
```

### Response Procedure

```bash
# Step 1: IMMEDIATE HALT
sa-emergency

# Step 2: Log incident
INCIDENT_ID="CONST-$(date +%Y%m%d-%H%M%S)"
echo "$INCIDENT_ID: Constitutional violation at $(date -Iseconds)" >> ./data/logs/constitutional.log

# Step 3: Identify violated invariant
# Psi_0: Existence - System survival threatened
# Psi_1: Regeneration - State not reconstructible
# Psi_2: History - Lineage gap detected
# Psi_3: Verification - Hash chain broken
# Psi_4: Human Alignment - Founder directive violated
# Psi_5: Truthfulness - Deceptive action detected

# Step 4: Restore from last constitutional checkpoint
sa-checkpoint-restore --phase full --verify-constitutional

# Step 5: Verify constitutional integrity
elixir scripts/constitutional/verify_all.exs

# Step 6: If verification passes, cautiously restart
sa-up

# Step 7: Postmortem REQUIRED within 24 hours
```

---

## 4.5 IR-005: Guardian Rejection

**Severity**: HIGH
**Response Time**: < 30 minutes
**STAMP**: SC-GDE-001, SC-GDE-004

### Detection

```bash
# Check Guardian rejection log
curl -s http://localhost:4000/api/prajna/guardian/rejections | jq '.recent'
```

### Response Procedure

```bash
# Step 1: Get rejection details
REJECTION_ID=$(curl -s http://localhost:4000/api/prajna/guardian/rejections | jq -r '.recent[0].id')
curl -s http://localhost:4000/api/prajna/guardian/rejection/$REJECTION_ID | jq '.'

# Expected output:
# {
#   "proposal_id": "...",
#   "rejection_reason": "constitutional_violation|impact_too_high|insufficient_testing|...",
#   "failed_checks": ["check_1", "check_2"],
#   "score": 0.72,  // Below 0.85 threshold
#   "recommendations": ["..."]
# }

# Step 2: Address failed checks
# Based on rejection_reason:

case $(curl -s http://localhost:4000/api/prajna/guardian/rejection/$REJECTION_ID | jq -r '.rejection_reason') in
  "constitutional_violation")
    echo "Modify proposal to comply with Psi invariants"
    ;;
  "impact_too_high")
    echo "Break into smaller changes with lower impact"
    ;;
  "insufficient_testing")
    echo "Add more tests, run shadow testing"
    ;;
  "shadow_test_failed")
    echo "Fix issues found in shadow environment"
    ;;
  *)
    echo "Review specific failed checks"
    ;;
esac

# Step 3: Resubmit with modifications
# Return to SOP-CHG-003 Phase 1 with improvements

# Step 4: Log for learning
curl -X POST http://localhost:4000/api/prajna/training_gym/episode \
  -H "Content-Type: application/json" \
  -d '{
    "type": "guardian_rejection",
    "proposal_id": "'$REJECTION_ID'",
    "outcome": "rejected",
    "lesson_learned": "..."
  }'
```

---

# 5. Evolution Runbooks

## 5.1 EV-001: GDE Proposal Cycle

**Trigger**: Automated (OODA) or Manual request
**Duration**: Variable (depends on proposal complexity)
**STAMP**: SC-GDE-001, SC-GDE-004

### Phase 1: Proposal Generation (F# Cortex)

```bash
# Step 1: Trigger evolution analysis
curl -X POST http://localhost:4000/api/prajna/gde/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "target": "lib/indrajaal/domains/alarms",
    "goal": "improve_coverage",
    "constraints": ["maintain_api", "no_breaking_changes"]
  }'

# Step 2: Wait for proposals
ANALYSIS_ID=$(curl -s http://localhost:4000/api/prajna/gde/status | jq -r '.latest_analysis_id')
while [ "$(curl -s http://localhost:4000/api/prajna/gde/analysis/$ANALYSIS_ID | jq -r '.status')" != "complete" ]; do
  sleep 5
done

# Step 3: Review generated proposals
curl -s http://localhost:4000/api/prajna/gde/analysis/$ANALYSIS_ID/proposals | jq '.proposals'
```

### Phase 2: Fitness Evaluation

```bash
# Step 4: Calculate fitness scores
curl -s http://localhost:4000/api/prajna/gde/analysis/$ANALYSIS_ID/fitness | jq '.scores'

# Fitness formula:
# Fitness = w1*Coverage + w2*PassRate + w3*MutationScore - w4*Complexity
# Weights: w1=0.3, w2=0.3, w3=0.2, w4=0.2

# Step 5: Select best proposal (fitness > 0.5)
BEST_PROPOSAL=$(curl -s http://localhost:4000/api/prajna/gde/analysis/$ANALYSIS_ID/proposals | \
  jq -r '.proposals | sort_by(.fitness) | reverse | .[0].id')
echo "Best proposal: $BEST_PROPOSAL"
```

### Phase 3: Constitutional Check

```bash
# Step 6: Run constitutional verification
curl -X POST http://localhost:4000/api/prajna/constitutional/verify \
  -H "Content-Type: application/json" \
  -d '{"proposal_id": "'$BEST_PROPOSAL'"}'

# Expected: All Psi_0-5 PASSED
```

---

## 5.2 EV-002: Shadow Testing

**Trigger**: GDE proposal with fitness > 0.5
**Duration**: 30-60 minutes
**STAMP**: SC-GDE-002, SC-RECONFIG-004

### Procedure

```bash
# Step 1: Create shadow universe
SHADOW_ID=$(curl -X POST http://localhost:4000/api/prajna/shadow/create \
  -H "Content-Type: application/json" \
  -d '{"proposal_id": "'$BEST_PROPOSAL'"}' | jq -r '.shadow_id')

echo "Shadow universe created: $SHADOW_ID"

# Step 2: Apply evolution in shadow
curl -X POST http://localhost:4000/api/prajna/shadow/$SHADOW_ID/apply \
  -H "Content-Type: application/json" \
  -d '{"proposal_id": "'$BEST_PROPOSAL'"}'

# Step 3: Run full test suite in shadow
SHADOW_TEST_RESULT=$(curl -X POST http://localhost:4000/api/prajna/shadow/$SHADOW_ID/test)
echo "Shadow test result: $SHADOW_TEST_RESULT"

# Step 4: Compare metrics (shadow vs production)
curl -s http://localhost:4000/api/prajna/shadow/$SHADOW_ID/comparison | jq '{
  coverage_delta: .coverage.shadow - .coverage.production,
  performance_delta: .performance.shadow - .performance.production,
  regression_count: .regressions | length
}'

# Step 5: Destroy shadow universe
curl -X DELETE http://localhost:4000/api/prajna/shadow/$SHADOW_ID
```

### Shadow Test Pass Criteria

| Metric | Requirement |
|--------|-------------|
| Coverage delta | >= 0 (no decrease) |
| Performance delta | <= 5% degradation |
| Regression count | 0 |
| Constitutional check | All PASS |

---

## 5.3 EV-003: Activation

**Trigger**: Shadow test passed
**Duration**: 30-60 minutes (progressive rollout)
**STAMP**: SC-GDE-003, SC-REG-001

### Procedure

```bash
# Step 1: Submit to Guardian for final approval
curl -X POST http://localhost:4000/api/prajna/guardian/submit \
  -H "Content-Type: application/json" \
  -d '{
    "proposal_id": "'$BEST_PROPOSAL'",
    "shadow_test_passed": true,
    "shadow_id": "'$SHADOW_ID'"
  }'

# Step 2: Wait for Guardian approval (score >= 0.85)
while true; do
  STATUS=$(curl -s http://localhost:4000/api/prajna/guardian/proposal/$BEST_PROPOSAL | jq -r '.status')
  if [ "$STATUS" == "approved" ]; then
    break
  elif [ "$STATUS" == "rejected" ]; then
    echo "Guardian rejected. See IR-005."
    exit 1
  fi
  sleep 10
done

# Step 3: Log to Immutable Register BEFORE activation
curl -X POST http://localhost:4000/api/prajna/register/log \
  -H "Content-Type: application/json" \
  -d '{
    "type": "evolution_activation",
    "proposal_id": "'$BEST_PROPOSAL'",
    "guardian_approval": true
  }'

# Step 4: Progressive rollout
# 5% traffic
curl -X POST http://localhost:4000/api/prajna/gde/activate \
  -H "Content-Type: application/json" \
  -d '{"proposal_id": "'$BEST_PROPOSAL'", "percentage": 5}'
sleep 60
# Monitor for errors

# 25% traffic
curl -X POST http://localhost:4000/api/prajna/gde/activate \
  -H "Content-Type: application/json" \
  -d '{"proposal_id": "'$BEST_PROPOSAL'", "percentage": 25}'
sleep 300
# Monitor for errors

# 100% traffic
curl -X POST http://localhost:4000/api/prajna/gde/activate \
  -H "Content-Type: application/json" \
  -d '{"proposal_id": "'$BEST_PROPOSAL'", "percentage": 100}'

# Step 5: Verify activation complete
curl -s http://localhost:4000/api/prajna/gde/evolution/$BEST_PROPOSAL | jq '.status'
# Expected: "active"
```

### Activation Rollback (if degradation detected)

```bash
# Immediate rollback during progressive rollout
curl -X POST http://localhost:4000/api/prajna/gde/rollback \
  -H "Content-Type: application/json" \
  -d '{"proposal_id": "'$BEST_PROPOSAL'"}'

# System returns to pre-evolution state
```

---

## 5.4 EV-004: Learning Feedback

**Trigger**: Evolution cycle complete (success or failure)
**Duration**: 5-10 minutes
**STAMP**: SC-BIO-003, AOR-CAE-003

### Procedure

```bash
# Step 1: Record episode to TrainingGym
curl -X POST http://localhost:4000/api/prajna/training_gym/episode \
  -H "Content-Type: application/json" \
  -d '{
    "proposal_id": "'$BEST_PROPOSAL'",
    "layer": "L3",
    "action": "evolution",
    "pre_state": {
      "coverage": 92.5,
      "complexity": 15.2,
      "fitness": 0.72
    },
    "post_state": {
      "coverage": 94.1,
      "complexity": 12.8,
      "fitness": 0.81
    },
    "reward": 1.0,
    "outcome": "success"
  }'

# Step 2: Update Q-table
# Automatic via TrainingGym
# Q(L3, evolution) += alpha * (reward + gamma * max(Q(s')) - Q(L3, evolution))

# Step 3: Adjust fitness weights (if needed)
curl -X POST http://localhost:4000/api/prajna/gde/fitness/adjust \
  -H "Content-Type: application/json" \
  -d '{
    "proposal_id": "'$BEST_PROPOSAL'",
    "outcome": "success",
    "adjustment_type": "reinforce_successful_pattern"
  }'

# Step 4: Emit telemetry for observer
curl -X POST http://localhost:4000/api/prajna/telemetry/emit \
  -H "Content-Type: application/json" \
  -d '{
    "metric": "gde.evolution.complete",
    "value": 1,
    "tags": {
      "proposal_id": "'$BEST_PROPOSAL'",
      "outcome": "success",
      "fitness_improvement": 0.09
    }
  }'

# Step 5: Log to DuckDB history (append-only)
curl -X POST http://localhost:4000/api/prajna/history/append \
  -H "Content-Type: application/json" \
  -d '{
    "type": "evolution_complete",
    "proposal_id": "'$BEST_PROPOSAL'",
    "timestamp": "'$(date -Iseconds)'",
    "metrics": {
      "fitness_before": 0.72,
      "fitness_after": 0.81,
      "coverage_delta": 1.6
    }
  }'
```

---

# 6. Quick Reference

## 6.1 Command Cheat Sheet

```bash
# Daily Operations
devenv shell              # Enter environment
sa-status                 # Container health
sa-health                 # FPPS validation
compile                   # Patient mode compile
test                      # Run tests
quality                   # Format + Credo

# Change Management
sa-checkpoint --phase N   # Create checkpoint (1/2/3/4/full)
sa-checkpoint-restore     # Restore from checkpoint
sa-checkpoint-verify      # Verify checkpoint integrity

# Emergency
sa-emergency              # Force stop < 5s
git revert HEAD           # L1 rollback
mix ecto.rollback         # L3 rollback

# Monitoring
sa-logs [container]       # View logs
curl localhost:4000/api/prajna/metrics  # System metrics
curl localhost:9090/api/v1/query        # Prometheus query
```

## 6.2 Impact Score Quick Reference

| Score | Mode | Actions |
|-------|------|---------|
| 0-10 | Standard | Peer review |
| 11-20 | Standard+ | Checkpoint required |
| 21-30 | High-Risk | Senior + Shadow test |
| 31-40 | Critical | Guardian + Architecture |
| 40+ | Emergency | HALT + Postmortem |

## 6.3 STAMP Quick Reference

| ID | Purpose |
|----|---------|
| SC-FUNC-001 | System must compile |
| SC-CHG-001 | Change notes required |
| SC-OODA-001 | Cycle < 100ms |
| SC-GDE-004 | Guardian threshold 0.85 |
| SC-EMR-057 | Emergency stop < 5s |
| SC-CONST-007 | Guardian veto absolute |

## 6.4 Escalation Contacts

| Level | Role | Contact |
|-------|------|---------|
| L1 | On-Call Engineer | #ops-oncall |
| L2 | Senior Engineer | #ops-senior |
| L3 | Architecture | #architecture |
| L4 | Guardian/Executive | #guardian-team |
| L5 | Founder | Direct escalation |

---

## Document History

| Version | Date | Author | Change |
|---------|------|--------|--------|
| 21.3.0 | 2026-01-10 | Claude Opus 4.5 | Initial creation |

---

**Document End**

| Field | Value |
|-------|-------|
| Total Lines | 850+ |
| SOPs Covered | 4 (SOP-CHG-001 to 004) |
| Rollback Procedures | 4 (RB-L1 to L4) |
| Incident Runbooks | 5 (IR-001 to 005) |
| Evolution Runbooks | 4 (EV-001 to 004) |
| STAMP Constraints | 30+ referenced |
| AOR Rules | 20+ referenced |
