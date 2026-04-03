# AEE Operational Runbook and Quick Reference

**Date**: 2025-09-07 09:55:00 CEST  
**Author**: Claude (AEE Autonomous Execution Engine)  
**Purpose**: Operational runbooks and quick reference for daily use  
**Status**: 📖 OPERATIONAL GUIDE FOR IMMEDIATE ACTION

---

## 🚀 Quick Start Checklist

```bash
□ 1. Source environment variables
□ 2. Verify Podman is running  
□ 3. Check PostgreSQL on port 5433
□ 4. Deploy containers
□ 5. Deploy agents
□ 6. Run compilation check
□ 7. Execute autonomous fixes
□ 8. Validate and merge
```

---

## 📋 One-Page Quick Reference

### Essential Commands
```bash
# Environment Setup
source .env.local
devenv shell

# Container Operations
elixir scripts/aee/deploy_phics_containers.exs
elixir scripts/aee/deploy_aee_agents.exs
podman ps -a  # Check all containers

# Compilation & Fixing
mix compile --warnings-as-errors 2>&1 | tee compile.log
elixir scripts/aee/autonomous_fix_execution.exs --log compile.log

# Monitoring
elixir scripts/aee/monitor_agents.exs --real-time
watch -n 5 'podman exec aee-container-1 mix compile --no-compile'

# Git Operations
git add -A && git commit -m "Checkpoint: $(date)"
git reset --hard HEAD~1  # Rollback
```

### Critical Environment Variables
```bash
export NO_TIMEOUT=true
export PATIENT_MODE=enabled
export INFINITE_PATIENCE=true
export BASH_DEFAULT_TIMEOUT_MS=3600000
export BASH_MAX_TIMEOUT_MS=7200000
export TZ="Europe/Berlin"
export USE_LOCAL_TIME=true
```

### Container Distribution
```
Container 1: Supervisor + Helpers 1-2
Container 2-5: Helpers 3-6 + Workers 1-8  
Container 6-10: Workers 9-18
```

---

## 🔧 Operational Runbooks

### Runbook 1: Fresh Session Start
```bash
#!/bin/bash
# runbook_fresh_start.sh

echo "🚀 Starting fresh AEE session..."

# 1. Clean previous session
podman stop $(podman ps -aq) 2>/dev/null
podman rm $(podman ps -aq) 2>/dev/null

# 2. Source environment
source .env.local

# 3. Deploy infrastructure
elixir scripts/aee/deploy_phics_containers.exs
elixir scripts/aee/deploy_aee_agents.exs

# 4. Verify deployment
for i in {1..10}; do
  echo -n "Container $i: "
  podman exec aee-container-$i echo "✅ Healthy" || echo "❌ Failed"
done

echo "✅ AEE infrastructure ready!"
```

### Runbook 2: Compilation Error Fix
```bash
#!/bin/bash
# runbook_fix_compilation.sh

echo "🔧 Starting compilation fix process..."

# 1. Capture current state
git add -A
git commit -m "Pre-fix checkpoint: $(date '+%Y-%m-%d %H:%M:%S %Z')"

# 2. Run compilation and capture output
mix compile --warnings-as-errors 2>&1 | tee compile.log

# 3. Analyze errors
elixir scripts/aee/analyze_compilation_output.exs --input compile.log

# 4. Execute fixes
elixir scripts/aee/autonomous_fix_execution.exs \
  --log compile.log \
  --batch-size 25 \
  --parallel true

# 5. Validate
if mix compile --warnings-as-errors; then
  echo "✅ All compilation issues fixed!"
  git add -A
  git commit -m "Fixed compilation issues: $(date)"
else
  echo "❌ Some issues remain"
  git status
fi
```

### Runbook 3: Emergency Recovery
```bash
#!/bin/bash
# runbook_emergency_recovery.sh

echo "🚨 EMERGENCY RECOVERY INITIATED"

# 1. Stop everything
podman stop -a
killall beam.smp 2>/dev/null

# 2. Backup current state
backup_dir="backups/emergency-$(date +%Y%m%d-%H%M%S)"
mkdir -p $backup_dir
cp -r .git $backup_dir/
cp -r data/tmp $backup_dir/

# 3. Clean up
podman rm -f $(podman ps -aq)
podman network prune -f
podman volume prune -f

# 4. Reset to last known good
last_good=$(git log --format="%H" --grep="✅" -1)
if [ -n "$last_good" ]; then
  git reset --hard $last_good
else
  echo "⚠️  No known good commit found"
fi

# 5. Redeploy
source .env.local
elixir scripts/aee/deploy_phics_containers.exs
elixir scripts/aee/deploy_aee_agents.exs

echo "✅ Emergency recovery complete"
```

### Runbook 4: Daily Health Check
```bash
#!/bin/bash
# runbook_daily_health.sh

echo "🏥 Daily Health Check"
echo "===================="

# 1. Environment check
echo -n "Environment variables: "
if [ "$PATIENT_MODE" = "enabled" ]; then
  echo "✅"
else
  echo "❌ Missing patient mode"
fi

# 2. Container health
echo "Container Health:"
for i in {1..10}; do
  status=$(podman inspect aee-container-$i --format='{{.State.Status}}' 2>/dev/null)
  if [ "$status" = "running" ]; then
    echo "  Container $i: ✅ Running"
  else
    echo "  Container $i: ❌ Not running"
  fi
done

# 3. Compilation status
echo -n "Compilation status: "
if mix compile --warnings-as-errors >/dev/null 2>&1; then
  echo "✅ Clean"
else
  echo "❌ Has warnings/errors"
fi

# 4. Git status
echo -n "Git status: "
if git diff --quiet && git diff --cached --quiet; then
  echo "✅ Clean"
else
  echo "⚠️  Uncommitted changes"
fi

# 5. Disk space
echo -n "Disk space: "
available=$(df -h . | awk 'NR==2 {print $4}')
echo "$available available"
```

---

## 📊 Performance Tuning Guide

### Container Resource Optimization
```bash
# Check current resource usage
for i in {1..10}; do
  echo "Container $i:"
  podman stats --no-stream aee-container-$i
done

# Adjust CPU limits
podman update --cpus 4 aee-container-1  # Supervisor gets more
podman update --cpus 2 aee-container-2  # Helpers get medium
podman update --cpus 1 aee-container-6  # Workers get less

# Adjust memory limits
podman update --memory 4g aee-container-1
podman update --memory 2g aee-container-2
podman update --memory 1g aee-container-6
```

### Compilation Speed Optimization
```elixir
# In scripts/aee/optimize_compilation.exs
defmodule AEE.CompilationOptimizer do
  def optimize do
    # 1. Enable parallel compilation
    System.put_env("ELIXIR_ERL_OPTIONS", "+S 16 +fnu")
    
    # 2. Use compilation cache
    System.cmd("podman", ["volume", "create", "aee-build-cache"])
    
    # 3. Disable non-essential tasks
    System.put_env("MIX_ENV", "dev")
    System.put_env("SKIP_PHOENIX_DIGEST", "true")
    
    # 4. Use incremental compilation
    Mix.Task.run("compile", ["--force", "--warnings-as-errors"])
  end
end
```

---

## 🎯 Common Scenarios

### Scenario 1: "Just fix all the warnings"
```bash
# Quick command sequence
source .env.local
elixir scripts/aee/quick_fix_all.exs
```

### Scenario 2: "I need to fix just one domain"
```bash
# Target specific domain
elixir scripts/aee/fix_domain.exs --domain observability
```

### Scenario 3: "Show me what would be fixed"
```bash
# Dry run mode
elixir scripts/aee/analyze_only.exs --dry-run
```

### Scenario 4: "Fix errors first, then warnings"
```bash
# Prioritized fixing
elixir scripts/aee/fix_by_priority.exs --errors-first
```

---

## 📈 Success Metrics

### Key Performance Indicators
```
✅ Compilation Success Rate: Target 100%
✅ Fix Success Rate: Target >95%
✅ Container Uptime: Target >99%
✅ Agent Efficiency: Target >90%
✅ Batch Success Rate: Target 100%
✅ Git History Clean: Target 100%
```

### Monitoring Commands
```bash
# Overall health score
elixir scripts/aee/health_score.exs

# Performance metrics
elixir scripts/aee/performance_metrics.exs

# Success rate tracking
elixir scripts/aee/success_tracker.exs
```

---

## 🔍 Troubleshooting Decision Tree

```
Compilation fails?
├─ Timeout issue?
│  └─ Check PATIENT_MODE variables
├─ Container issue?
│  └─ Run health check runbook
├─ Git issue?
│  └─ Check for conflicts, run git status
└─ Unknown issue?
   └─ Run emergency recovery runbook
```

---

## 📝 Daily Operation Log Template

```markdown
## AEE Operation Log - [DATE]

### Session Start
- Time: [HH:MM CEST]
- Containers deployed: 10/10
- Agents deployed: 25/25
- Initial compilation status: [X errors, Y warnings]

### Execution Summary
- Batches executed: [N]
- Files modified: [N]
- Errors fixed: [N]
- Warnings fixed: [N]
- Git commits: [N]

### Issues Encountered
- [ ] None
- [ ] Container failures
- [ ] Compilation timeouts
- [ ] Git conflicts
- [ ] Other: ___

### Session End
- Time: [HH:MM CEST]
- Final compilation status: ✅ Zero warnings/errors
- Git status: Clean
- Merged to main: Yes/No

### Notes
[Any additional observations or improvements]
```

---

## 🚨 Emergency Contacts

### System Resources
- **Container Issues**: Check Podman logs
- **Compilation Issues**: Check compile.log
- **Git Issues**: Check .git/logs
- **Agent Issues**: Check data/tmp/aee-*.log

### Quick Fixes
```bash
# Container won't start
podman system prune -a
devenv shell

# Compilation hangs
export NO_TIMEOUT=true
pkill -f "mix compile"

# Git confused
git reflog
git reset --hard HEAD@{1}

# Everything broken
./runbook_emergency_recovery.sh
```

---

## 🎓 Training New Operators

### Day 1: Basic Operations
1. Read comprehensive setup guide
2. Run fresh start runbook
3. Execute simple fix scenario
4. Practice monitoring

### Day 2: Advanced Operations
1. Read advanced patterns guide
2. Handle emergency recovery
3. Optimize performance
4. Multi-container coordination

### Day 3: Expert Operations
1. Custom error patterns
2. Scaling strategies
3. Integration with CI/CD
4. Troubleshooting mastery

---

## 🏁 Final Checklist

Before ending any session:
```
□ All compilation warnings/errors fixed
□ All tests passing
□ Git history clean and organized
□ Containers properly stopped
□ Logs archived to data/tmp
□ Journal entry created
□ Todo list updated
```

---

*Remember: When in doubt, run the emergency recovery runbook!* 🚨

---

## Quick Command Card (Print and Keep)

```
╔══════════════════════════════════════════════╗
║           AEE QUICK COMMAND CARD             ║
╠══════════════════════════════════════════════╣
║ Setup:                                       ║
║   source .env.local                          ║
║   devenv shell                               ║
║                                              ║
║ Deploy:                                      ║
║   elixir scripts/aee/deploy_phics_*.exs      ║
║                                              ║
║ Fix All:                                     ║
║   mix compile 2>&1 | tee compile.log         ║
║   elixir scripts/aee/autonomous_fix_*.exs    ║
║                                              ║
║ Emergency:                                   ║
║   ./runbook_emergency_recovery.sh            ║
║                                              ║
║ Monitor:                                     ║
║   podman ps -a                               ║
║   podman logs aee-container-1                ║
╚══════════════════════════════════════════════╝
```

---

*Operational excellence through systematic execution* 📊