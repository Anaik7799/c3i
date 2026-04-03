# Master Setup & Operations Manual: Homeostatic External Observation
**Date**: 2026-03-25 14:00 CEST
**Classification**: SIL-6 Biomorphic / SUPREME
**Role**: YOLO External Observer (Gemini)
**Compliance**: Ω₀ Founder's Directive, SC-AUDIT-001 through 004

## 1.0 Infrastructure Initialization (The Heart)
Before initiating evolution, the Zenoh heart MUST be structuraly sound.

### 1.1 Zenoh Gossip Repair (MANDATORY)
Ensure all `config/zenoh/*.json5` files use the structured Gossip object. Boolean `true` values will trigger a panic.
- **Action**: Replace `gossip: true` or `gossip: { enabled: true }` with `gossip: {}`.
- **Command**: 
  ```bash
  sed -i 's/gossip: true/gossip: {}/g' config/zenoh/*.json5
  ```

### 1.2 Multi-Tier Container Boot
Use the SIL-6 production manifest to establish the converged topology.
- **Command**:
  ```bash
  podman-compose -f lib/cepaf/artifacts/podman-compose-prod-standalone.yml up -d
  ```
- **Verification**: `podman ps` must show `indrajaal-db-prod`, `indrajaal-obs-prod`, `indrajaal-ex-app-1`, and `zenoh-router` as `healthy`.

## 2.0 Agent Operating Protocols (YOLO Mode)

### 2.1 Gemini Agent Mandates (Observer Track)
- **Identity**: External Observer.
- **Policy**: ZERO-TOUCH. No code or container modifications permitted.
- **Tooling**: MUST use `mcp_sentinel-zenoh` for all system communication.
- **Action**: Every 60s, broadcast metabolic guidance to `indrajaal/evolution/advice/observer_guidance`.

### 2.2 Claude Agent Mandates (Executor Track)
- **Identity**: Autonomous Refactorer.
- **Policy**: HEIJUNKA (Load Leveling). 
- **Backpressure**: MUST check `uptime` load average before initiating `mix test` or `mix compile` swarms.
- **Constraint**: If `load_avg > (Cores * 1.5)`, wait for current queue to drain.

## 3.0 Homeostatic Command Set (The Metabolism)

### 3.1 Vitals Monitoring (Observe)
Auditors and Observers must use these commands to gauge system comfort:
```bash
# L0 Hardware Pass
uptime && free -m && df -h /

# L1 Container Pass
podman ps --format "table {{.Names}}\t{{.Status}}"

# L2 Process genome
ps -eo pid,%cpu,comm --sort=-%cpu | head -n 10
```

### 3.2 Metabolic Signaling (Act)
Use the Zenoh bus to influence internal behavior via MCP:
```json
// Topic: indrajaal/control/stabilization/metabolic_signal
{
  "observer": "agent-id",
  "advice": "Metabolic Pacing Mode: Active",
  "threshold": "load < 15.0"
}
```

## 4.0 Emergency Mitigation (Immune Response)
If the system breaches the comfort threshold (Load > 2x Cores), execute the following sequence:

### 4.1 Tier 1: Soft Throttling (Scheduler Deprioritization)
Break CPU deadlocks without killing the synthesis work.
- **Command**: 
  ```bash
  ps -u $(whoami) -o pid,comm | awk '/beam.smp/ {print $1}' | xargs -r renice -n 15 -p
  ```

### 4.2 Tier 2: Hard Suspension (SIGSTOP)
Pause the most aggressive Hydra head to reclaim interactive shells.
- **Command**:
  ```bash
  ps -eo pid,%cpu,comm --sort=-%cpu | awk '/beam.smp/ {print $1}' | head -n 1 | xargs -r kill -STOP
  ```

### 4.3 Tier 3: Native Emergency (Zenoh Abort)
Trigger `SC-EMR-057` via the mesh control plane.
- **Zenoh Key**: `indrajaal/cepaf/cmd/emergency`
- **Payload**: `{"action": "sa-emergency", "reason": "Host Starvation"}`

## 5.0 Continuous Verification Checklist
- [ ] **Zenoh Heart**: REST API reachable on port 8000.
- [ ] **Load Envelope**: 1-min load average <= Core Count.
- [ ] **Memory Margin**: Available RAM > 10GB.
- [ ] **Observer Loop**: Metbolic guidance pulses confirmed on bus.

**System is now optimally configured for Autonomous YOLO Evolution.**
