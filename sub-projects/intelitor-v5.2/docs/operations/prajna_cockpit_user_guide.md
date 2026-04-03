# Prajna Cockpit User Guide

> Version: 21.3.1-SIL6 | Date: 2026-03-28 | STAMP: SC-HMI-001 to SC-HMI-080

## Overview

Prajna is the primary web-based cockpit for Indrajaal, built with Phoenix LiveView.
It provides real-time monitoring, alarm management, device health visualization,
and an AI copilot interface. Access it at `http://localhost:4000/prajna`.

## Navigation Structure

```
/prajna
  |
  +-- /prajna/dashboard          Main health dashboard (default landing)
  +-- /prajna/alarms             Alarm list and management
  +-- /prajna/devices            Device health grid
  +-- /prajna/copilot            AI copilot chat interface
  +-- /prajna/analytics          Analytics and report builder
  +-- /prajna/compliance         Constraint compliance matrix
  +-- /prajna/singularity        Singularity explorer
  +-- /prajna/git-intelligence   Git mesh telemetry dashboard
```

The sidebar navigation is persistent across all views. The active page is
highlighted with a chromatic accent bar (SC-HMI-010).

## 1. Dashboard -- Health Overview

The main dashboard displays a real-time health matrix for the entire mesh.

### Key Elements

- **Cluster Status Banner**: Green/amber/red indicator for overall mesh health
- **Container Grid**: 4 containers (zenoh-router, db, obs, app) with live status
- **Zenoh Mesh Panel**: Connection count, latency, session ID
- **CPU Governor Widget**: Current CPU %, scheduler count, governor mode
- **STAMP Compliance Gauge**: Percentage of constraints passing
- **Recent Events Timeline**: Last 20 system events with timestamps

### Real-Time Updates

All dashboard widgets update via Phoenix PubSub. No manual refresh needed.
Data refreshes every 10 seconds (SC-VER-041: OODA cycle < 100ms).

## 2. Alarms -- Alarm Management

Displays all active, acknowledged, and historical alarms.

### Features

- **Severity Filtering**: Critical / High / Medium / Low toggle buttons
- **Storm Detection**: Automatic grouping when > 10 alarms in 60s (SC-ALARM-007)
- **Acknowledge**: Click to acknowledge; requires two-step confirm for Critical
- **Escalation Trail**: View escalation history for any alarm
- **Export**: Download alarm history as CSV

### Alarm Table Columns

| Column | Description |
|--------|-------------|
| Severity | Color-coded badge (red/orange/yellow/blue) |
| Source | Device or subsystem that raised the alarm |
| Message | Human-readable alarm description |
| Timestamp | HLC timestamp with timezone |
| Status | Active / Acknowledged / Cleared |
| Actions | Acknowledge / Escalate / Clear |

### Two-Step Commit (SC-SAFETY-001)

Critical alarm actions (Clear All, Force Acknowledge) require the arm-confirm
sequence: click once to arm (button turns amber), click again to execute.
A cancel button appears during the armed state.

## 3. Devices -- Device Health Grid

An 8x8 matrix view of all monitored devices (SC-HMI-011).

### Grid Layout

Each cell represents a device with color-coded health:
- **Green**: Healthy, all sensors nominal
- **Amber**: Degraded, one or more sensors out of range
- **Red**: Critical, device offline or sensor failure
- **Grey**: Unknown, no telemetry received

### Device Detail Panel

Click any cell to open the detail side-panel showing:
- Device FQUN (Fully Qualified Unique Name)
- Last telemetry timestamp
- Sensor readings (temperature, humidity, voltage, etc.)
- Alarm history for this device
- Maintenance schedule

## 4. Copilot -- AI Chat Interface

The AI copilot provides natural-language interaction with the Indrajaal system
through the Cortex AI subsystem.

### Capabilities

- **System Queries**: "What is the current alarm count?"
- **Diagnostics**: "Why is node-3 showing degraded health?"
- **Actions**: "Acknowledge all medium alarms from sensor-bay-2"
- **Analysis**: "Show me the trend for CPU utilization over the last hour"

### Input Controls

- Type in the message box and press Enter or click Send
- Use `/` prefix for direct commands (e.g., `/status`, `/alarms critical`)
- Shift+Enter for multiline input

### Safety Gate

All copilot actions that mutate system state require Guardian approval.
The copilot will display a confirmation dialog before executing mutations.

## 5. Analytics -- Report Builder

Build custom analytics reports from telemetry and alarm data.

### Report Types

- **Time Series**: Plot any metric over a configurable time range
- **Alarm Frequency**: Histogram of alarm occurrences by source/severity
- **SLA Compliance**: Uptime percentage per device/zone
- **Capacity Planning**: Resource utilization trends with projections

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `g d` | Go to Dashboard |
| `g a` | Go to Alarms |
| `g v` | Go to Devices |
| `g c` | Go to Copilot |
| `g n` | Go to Analytics |
| `?` | Show keyboard shortcut help |
| `Esc` | Close any open panel or dialog |
| `r` | Refresh current view data |

## Dark Cockpit Mode (SC-HMI-010)

Prajna defaults to a dark theme optimized for control-room environments.
The color palette follows aviation dark-cockpit standards:
- Background: `#0d1117` (near-black)
- Text: `#c9d1d9` (soft white)
- Accent: Chromatic per-status (green/amber/red)
- Interactive elements: `#58a6ff` (muted blue)

## Browser Requirements

- Chrome 120+ or Firefox 120+ (WebSocket support required)
- Minimum resolution: 1280x720
- Recommended: 1920x1080 or higher for full grid visibility

## Related Constraints

- SC-HMI-001 to SC-HMI-080: Full cockpit UI compliance
- SC-ALARM-001 to SC-ALARM-041: Alarm management rules
- SC-DEV-001 to SC-DEV-008: Device dashboard requirements
- SC-SAFETY-001: Two-step commit for destructive actions
- SC-COCKPIT-002: WebUI uses F# Bolero (C3I console, separate from Prajna)
