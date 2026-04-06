---
paths: lib/indrajaal/**/*.ex, lib/indrajaal_web/**/*.ex, lib/cepaf/**/*.fs
---
# Full System Control & 5-Order Effects Rules
# Overview
Comprehensive control and monitoring of all 780+ modules across 100 domains with 5-order cascade analysis.
# STAMP Constraints (Control)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-CTRL-001 | System status available in real-time | CRITICAL |
| SC-CTRL-002 | All 30 domains queryable | HIGH |
| SC-CTRL-003 | 5-order effects analysis required | HIGH |
| SC-CTRL-004 | Emergency stop < 5 seconds | CRITICAL |
| SC-CTRL-005 | Circuit breakers per domain | HIGH |
| SC-CTRL-006 | All commands via Guardian | CRITICAL |
| SC-CTRL-007 | Telemetry for all operations | MEDIUM |
# STAMP Constraints (Monitoring)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-MON-001 | Metrics refresh every 30s | MEDIUM |
| SC-MON-002 | Infrastructure metrics complete | HIGH |
| SC-MON-003 | Domain metrics per domain | HIGH |
| SC-MON-004 | Safety metrics mandatory | CRITICAL |
| SC-MON-005 | Dashboard data available | HIGH |
| SC-MON-006 | Alert generation on thresholds | HIGH |
# The 30 Domains
```elixir
@domains [
:access_control, :accounts, :alarms, :analytics, :authentication,
:authorization, :billing, :cluster, :cockpit, :communication,
:compliance, :coordination, :cortex, :cybernetic, :devices,
:dispatch, :distributed, :flame, :identity, :integration,
:knowledge, :maintenance, :mesh, :observability, :policy,
:safety, :security, :sites, :validation, :video
]
```
# 5-Order Effects Model
| Order | Time Scale | Question | Example |
|-------|------------|----------|---------|
| 1st | Immediate | What direct action occurs? | Alarm acknowledged |
| 2nd | Seconds | What adjacent systems react? | Sentinel notified |
| 3rd | Seconds-Minutes | What integration effects? | Report generated |
| 4th | Minutes | What capabilities unlock? | Dispatch enabled |
| 5th | Minutes-Hours | What ecosystem effects? | SLA compliance logged |
# AOR Rules (Control)
| ID | Rule |
|----|------|
| AOR-CTRL-001 | Query domain status before operations |
| AOR-CTRL-002 | Log all control actions to register |
| AOR-CTRL-003 | Validate 5-order effects before execute |
| AOR-CTRL-004 | Circuit breakers prevent cascading failure |
| AOR-CTRL-005 | Guardian approval for all mutations |
# AOR Rules (Monitoring)
| ID | Rule |
|----|------|
| AOR-MON-001 | Monitor all 30 domains continuously |
| AOR-MON-002 | Track safety metrics at highest priority |
| AOR-MON-003 | Alert on threshold violations |
| AOR-MON-004 | Dashboard refresh every 30 seconds |
| AOR-MON-005 | Log all monitoring events |
# Key Modules
# MasterControl
`lib/indrajaal/cockpit/prajna/master_control.ex`
- `system_status/0` - Full system status
- `domain_status/1` - Per-domain status
- `execute_command/3` - Command execution
- `analyze_effects/3` - 5-order analysis
- `emergency_stop/1` - Emergency halt
# FullSystemMonitor
`lib/indrajaal/cockpit/prajna/full_system_monitor.ex`
- `get_metrics/0` - All metrics
- `dashboard_data/0` - Dashboard-formatted data
- `get_alerts/0` - Active alerts
- `set_threshold/2` - Configure thresholds
# Effect Chain Example
```
Domain: :alarms
Action: :process
Order 1 (Immediate):
- Alarm received and parsed
- Initial classification
Order 2 (Seconds):
- Correlation engine triggered
- Zone mapping applied
- Sentinel notified
Order 3 (Seconds-Minutes):
- Workflow triggered
- Notification sent
- Dashboard updated
Order 4 (Minutes):
- Dispatch recommended
- Response tracked
- SLA timer started
Order 5 (Minutes-Hours):
- Compliance logged
- Analytics updated
- Pattern learned
```
# Telemetry Events
```elixir
:telemetry.execute([:prajna, :control, :command], %{
domain: :alarms,
action: :process,
duration_ms: 45,
effects_analyzed: true
}, %{operator: "admin"})
```