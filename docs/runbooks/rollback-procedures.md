# Rollback Procedures

## Per-Component Rollback

### Gleam Server (port 4100)
```bash
# 1. Hot reload (no downtime — preferred)
git revert HEAD
cd lib/cepaf_gleam && gleam build
sa-plan-daemon hot-reload --port 4100

# 2. Full restart (if hot reload fails)
pkill -f beam.smp
rm -rf lib/cepaf_gleam/build/dev/erlang/cepaf_gleam
cd lib/cepaf_gleam && gleam build
sa-gleam-start -d
```

### Rust Planning Daemon
```bash
# 1. Revert and rebuild
git revert HEAD -- sub-projects/c3i/native/planning_daemon/
cd sub-projects/c3i/native/planning_daemon && cargo build --release

# 2. Restart daemon
pkill -f "sa-plan-daemon daemon"
./sub-projects/c3i/target/release/sa-plan-daemon daemon &
```

### Database (Smriti.db)
```bash
# ALWAYS backup before changes
sqlite3 data/smriti/Smriti.db ".backup /tmp/smriti-$(date +%s).db"

# Restore from backup
cp /tmp/smriti-<timestamp>.db data/smriti/Smriti.db

# Restore from GCS (disaster recovery)
sa-plan-daemon restore --from latest
```

### Container Mesh (16 containers)
```bash
# Graceful teardown + restart
sa-down
git checkout main -- docker-compose.yml
sa-up

# Single container restart
podman restart <container-name>
```

### Full System Rollback
```bash
# 1. Checkpoint current state
sa-plan-daemon backup

# 2. Revert to known-good commit
git log --oneline -10  # find target
git revert HEAD~N..HEAD  # revert N commits

# 3. Rebuild everything
cd lib/cepaf_gleam && gleam build
cd sub-projects/c3i/native/planning_daemon && cargo build --release

# 4. Restart
pkill -f beam.smp
sa-gleam-start -d
sa-plan-daemon daemon &

# 5. Verify
curl -sf http://localhost:4100/health | jq .
sa-plan-daemon status
```

## Pre-Rollback Checklist
- [ ] Backup current Smriti.db
- [ ] Note current git SHA
- [ ] Verify rollback target builds clean
- [ ] Notify team via gateway
- [ ] Monitor for 30 min after rollback
