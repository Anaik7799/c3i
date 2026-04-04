---
name: cpu-governor
description: user_invocable: true
---
---

# CPU Governor Skill

Check CPU utilization, run commands with adaptive throttling, and enforce the 85% hard limit.

## Usage

When invoked, display current CPU governor status and offer governed execution:

1. Run `source scripts/cpu-governor.sh && cpu_governor_status` to show current state
2. If the user provides a command, wrap it with the appropriate governed function
3. For compilation: use `governed_compile`
4. For testing: use `governed_test` (includes HEALTH_PORT=4051)
5. For Wallaby E2E: use `governed_wallaby` (includes HEALTH_PORT=4051, port 4050 server)
6. For arbitrary commands: use `governed_exec`

## Commands

```bash
# Show status
source scripts/cpu-governor.sh && cpu_governor_status

# Governed compilation
source scripts/cpu-governor.sh && governed_compile

# Governed test (includes HEALTH_PORT=4051 for FoundationSupervisor)
source scripts/cpu-governor.sh && governed_test [test_files] [flags]

# Governed Wallaby E2E (Chrome on port 4050, HEALTH_PORT=4051)
source scripts/cpu-governor.sh && governed_wallaby [test_files] [flags]

# Governed arbitrary command
source scripts/cpu-governor.sh && governed_exec <command> [args...]
```

## Port Assignments

| Port | Service | Notes |
|------|---------|-------|
| 4050 | Phoenix Wallaby test endpoint | config/wallaby.exs |
| 4051 | FoundationSupervisor health plug (test) | HEALTH_PORT env var |

## Key Implementation Details

- CPU measurement uses `/proc/stat` differential (NOT load average)
- Wallaby base_url is `http://localhost:4050` (set in config/wallaby.exs)
- Oban fully disabled during E2E tests (plugins: false, queues: false)
- Chrome/chromedriver from NixOS devenv (Chromium 143)
- All governed commands run with `nice -n $GOVERNOR_NICE`

## STAMP Reference

SC-CPU-GOV-001 to SC-CPU-GOV-010, AOR-CPU-GOV-001 to AOR-CPU-GOV-010
