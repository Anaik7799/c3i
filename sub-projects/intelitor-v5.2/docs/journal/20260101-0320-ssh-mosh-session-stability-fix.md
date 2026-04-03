# SSH/Mosh Session Stability Fix

**Date**: 2026-01-01T03:20:00+01:00
**Type**: Infrastructure Maintenance
**Status**: COMPLETED (partial - requires sudo for SSH config)

## Problem Statement

SSH and mosh sessions were hanging intermittently on vm-1.

## Root Cause Analysis

| Issue | Finding | Severity |
|-------|---------|----------|
| Orphaned mosh-servers | 20 stale processes from 2025 | MEDIUM |
| SSH keepalive disabled | All ClientAlive* settings commented out | HIGH |
| No TCP keepalive | Connections silently die on network hiccups | HIGH |

### System Health (Verified OK)

- Memory: 46GB total, 36GB available
- Swap: 3.1GB/8GB used (acceptable)
- Load: 1.37 (normal)
- Disk I/O: Minimal
- Network errors: Zero on all interfaces
- No OOM kills

## Actions Taken

### 1. Mosh Server Cleanup (COMPLETED)

```bash
# Killed 20 stale mosh-servers from 2025
ps aux | grep mosh-server | grep "2025" | awk '{print $2}' | xargs -r kill
```

**Result**: 20 stale servers terminated, 5 active sessions preserved.

### 2. SSH Keepalive Configuration (PENDING - requires sudo)

Create `/etc/ssh/sshd_config.d/keepalive.conf`:

```
ClientAliveInterval 60
ClientAliveCountMax 3
TCPKeepAlive yes
```

Then reload:
```bash
sudo systemctl reload ssh
```

### 3. Client-Side Configuration (RECOMMENDED)

Add to `~/.ssh/config` on connecting machines:

```
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
```

## Configuration Rationale

| Setting | Value | Purpose |
|---------|-------|---------|
| ClientAliveInterval | 60s | Server sends keepalive every 60 seconds |
| ClientAliveCountMax | 3 | Allow 3 missed keepalives before disconnect |
| TCPKeepAlive | yes | Enable TCP-level keepalives |

**Effective timeout**: 180 seconds (3 x 60s) before connection considered dead.

## Tailscale Notes

- Connection from razr15-1 (Windows) via Tailscale direct connection
- Tailscale MTU: 1280 (normal for WireGuard tunnel)
- Some devices using relay (Pixel via Helsinki) - may add latency

## Verification Commands

```bash
# Check SSH config is active
sudo sshd -T | grep -iE "clientalive|tcpkeep"

# Monitor active connections
ss -tnp | grep ssh

# Check mosh server count
ps aux | grep mosh-server | grep -v grep | wc -l
```

## Follow-up

- [ ] Apply sudo commands for SSH keepalive config
- [ ] Verify SSH sessions remain stable over 24h period
- [ ] Consider adding mosh cleanup to cron (weekly)

## STAMP Compliance

- **SC-PRF-050**: Session stability supports <50ms response requirement
- **SC-OBS-069**: Maintains terminal observability for dual logging

---
*Generated during infrastructure maintenance session*
