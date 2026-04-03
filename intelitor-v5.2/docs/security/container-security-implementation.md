# Container Security Implementation Guide

**Version:** 1.0.0
**Updated:** 2025-12-19
**Framework:** SOPv5.11 + STAMP + TPS
**Status:** IMPLEMENTED

## Overview

This document describes the container security implementation for the Indrajaal system, covering image scanning, network policies, security contexts, and resource limits per STAMP safety constraints SC-CNT-009 through SC-CNT-016.

## STAMP Constraint Coverage

| Constraint | Description | Implementation |
|------------|-------------|----------------|
| SC-CNT-009 | NixOS containers only | Registry validation in Trivy scanner |
| SC-CNT-010 | localhost/ registry only | Blocked registries in security config |
| SC-CNT-011 | PHICS < 50ms latency | Network policy optimization |
| SC-CNT-012 | Rootless execution | `user:` directive, `no-new-privileges` |
| SC-CNT-013 | Health verification | Healthchecks with `depends_on` conditions |
| SC-CNT-014 | Resource isolation | Resource limits per ContainerAllocation |
| SC-CNT-015 | Network security | Network policies, firewall rules |
| SC-CNT-016 | No registry drift | Trivy pre-build scanning |

## Files Created/Modified

### 1. Security Configuration Files

| File | Purpose |
|------|---------|
| `config/security/container_security_hardened.yml` | Comprehensive security configuration |
| `config/security/container_network_policies.yml` | Network isolation policies |

### 2. Scripts

| File | Purpose |
|------|---------|
| `scripts/security/trivy_container_scan.sh` | Image vulnerability scanning |

### 3. Compose Files

| File | Purpose |
|------|---------|
| `podman-compose-secure.yml` | Hardened container orchestration |

## Usage Guide

### 1. Image Scanning with Trivy

**Scan a single image:**
```bash
./scripts/security/trivy_container_scan.sh localhost/indrajaal-app:latest
```

**Scan all Indrajaal images:**
```bash
./scripts/security/trivy_container_scan.sh --all
```

**Pre-build Nix expression analysis:**
```bash
./scripts/security/trivy_container_scan.sh --pre-build containers/sopv51-elixir-app.nix
```

**Generate SBOM (Software Bill of Materials):**
```bash
./scripts/security/trivy_container_scan.sh --sbom localhost/indrajaal-app:latest
```

### 2. Running Secure Containers

**Start with hardened configuration:**
```bash
podman-compose -f podman-compose-secure.yml up -d
```

**Verify security contexts:**
```bash
podman inspect indrajaal-app | jq '.[0].HostConfig.SecurityOpt'
podman inspect indrajaal-app | jq '.[0].HostConfig.CapDrop'
```

### 3. Verifying Network Isolation

**Check container network assignments:**
```bash
podman network inspect indrajaal-net
```

**Test inter-container connectivity:**
```bash
# From app container - should work
podman exec indrajaal-app curl -s http://172.30.0.10:5433

# From db container - should fail (no outbound to app)
podman exec indrajaal-db curl -s http://172.30.0.20:4000
```

## Security Features

### 1. Image Scanning

- **Trivy integration** for vulnerability scanning
- **Severity thresholds**: Fail on CRITICAL and HIGH
- **Registry validation**: Only `localhost/` allowed
- **Base image validation**: Only NixOS-based images
- **Secret detection**: Scan for hardcoded credentials
- **SBOM generation**: CycloneDX format

### 2. Security Context

All containers implement:

- **Non-root execution**: UID 1000 (developer) or 999 (postgres)
- **Read-only root filesystem**: Where applicable
- **Dropped capabilities**: ALL capabilities dropped
- **Minimal capability additions**: Only what's required
- **No privilege escalation**: `no-new-privileges:true`
- **Seccomp profiles**: RuntimeDefault

### 3. Resource Limits

Per STAMP ContainerAllocation matrix:

| Container | CPU | RAM | PIDs |
|-----------|-----|-----|------|
| indrajaal-app | 12 | 32GB | 4096 |
| indrajaal-db | 4 | 16GB | 1024 |
| indrajaal-obs | 4 | 8GB | 2048 |
| indrajaal-redis | 2 | 4GB | 512 |
| indrajaal-nginx | 1 | 1GB | 256 |
| indrajaal-grafana | 1 | 2GB | 512 |

### 4. Network Policies

**Container Communication Matrix:**

```
              | indrajaal-app | indrajaal-db | indrajaal-obs |
--------------|---------------|--------------|---------------|
indrajaal-app |      -        |   Y (5433)   |   Y (4317)    |
indrajaal-db  |      N        |      -       |       N       |
indrajaal-obs |   Y (4000)    |   Y (5433)   |       -       |
```

**Key restrictions:**
- Database only accepts connections from app and obs
- Database cannot initiate outbound connections
- App can reach database and observability
- Observability can scrape metrics from all

## Secrets Management

Secrets are handled via:

1. **File mounts** (`*_FILE` environment variables)
2. **tmpfs volumes** for `/run/secrets`
3. **Never in environment variables**

Example:
```yaml
environment:
  POSTGRES_PASSWORD_FILE: /run/secrets/db_password
volumes:
  - type: tmpfs
    target: /run/secrets
    tmpfs:
      size: 1048576
```

## Audit and Compliance

Scan reports are stored in:
```
data/security/scan-reports/
├── <image>_<timestamp>.json     # Vulnerability reports
└── sbom/
    └── <image>_sbom.json        # Software Bill of Materials
```

Log file:
```
data/tmp/trivy-scan.log
```

## Integration with CI/CD

Add to your pipeline:

```yaml
# Example GitHub Actions step
- name: Security Scan
  run: |
    ./scripts/security/trivy_container_scan.sh --all
    if [ $? -ne 0 ]; then
      echo "Security scan failed"
      exit 1
    fi
```

## Troubleshooting

### Common Issues

1. **Trivy not installed**
   ```bash
   nix-env -iA nixpkgs.trivy
   ```

2. **Permission denied on read-only filesystem**
   - Ensure writable paths use tmpfs or bind mounts with `:z`

3. **Container fails to start with capability error**
   - Check if required capability is in `cap_add`

4. **Network connectivity issues**
   - Verify IP assignments in network policies
   - Check firewall rules

## References

- STAMP Constraints: `CLAUDE.md` Section 4.2
- ContainerAllocation Matrix: `CLAUDE.md` Section 1.2
- Network Architecture: `docs/architecture/c4-container-diagram.md`
