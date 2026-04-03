# Container Helper Scripts

This directory contains helper scripts for managing the SOPv5.11 development environment with comprehensive container support.

## Quick Start

### Complete Development Environment Setup

```bash
# One command to start everything (PostgreSQL, Redis, and dev container)
./scripts/containers/start-dev-container.sh
```

This automated script will:
1. ✅ Check if the development container image exists
2. ✅ Start PostgreSQL 17 on port 5433 (if not already running)
3. ✅ Start Redis 7 on port 6379 (if not already running)
4. ✅ Start the comprehensive development container with PHICS v2.1 hot-reloading

### Individual Service Management

```bash
# Start PostgreSQL 17 only
./scripts/containers/start-postgresql.sh

# Start Redis 7 only
./scripts/containers/start-redis.sh
```

## Available Scripts

### start-dev-container.sh
**Purpose**: Main orchestrator script that starts the complete development environment

**Features**:
- Automatic dependency checking (PostgreSQL, Redis)
- Container image validation
- Service startup with health checks
- PHICS v2.1 integration for hot-reloading
- Volume mounting for workspace synchronization
- Multi-path SSL/TLS certificate configuration
- PAM-free user switching with setpriv

**Usage**:
```bash
./scripts/containers/start-dev-container.sh
```

**Prerequisites**:
- Container image built: `localhost/indrajaal-dev:nixos-25.05-<git-rev>`
- Podman 5.4.1+ installed
- Project root access (requires mix.exs in current directory)

### start-postgresql.sh
**Purpose**: Start PostgreSQL 17 server for development

**Features**:
- Runs on port 5433 (non-conflicting with system PostgreSQL)
- Data directory: `./data/postgres/` (persistent storage)
- Automatic initialization if data directory doesn't exist
- Proper shutdown handling

**Usage**:
```bash
./scripts/containers/start-postgresql.sh
```

**Configuration**:
- Port: 5433
- User: postgres (no password for development)
- Data: `./data/postgres/`
- Access: Local connections only

### start-redis.sh
**Purpose**: Start Redis 7 server for development

**Features**:
- Runs on port 6379 (standard Redis port)
- Data directory: `./data/redis/` (persistent storage)
- AOF (Append-Only File) persistence enabled
- Proper configuration for development

**Usage**:
```bash
./scripts/containers/start-redis.sh
```

**Configuration**:
- Port: 6379
- Persistence: AOF enabled
- Data: `./data/redis/`
- Access: Local connections only

## Container Architecture

### External Services (Host)
- **PostgreSQL 17**: Port 5433, data in `./data/postgres/`
- **Redis 7**: Port 6379, data in `./data/redis/`

### Development Container
- **Name**: indrajaal-dev
- **Ports**: 4000 (Phoenix), 4001 (LiveReload)
- **Volume**: `$(pwd):/workspace:z` (bidirectional sync)
- **Network**: Access host services via `host.docker.internal`

### PHICS v2.1 Integration
- Hot-reloading enabled by default
- <50ms file synchronization latency
- Automatic recompilation on file changes
- LiveView updates without manual refresh

## Building the Container

### Build from Source

```bash
# Build with current git information
nix-build -E "(import ./containers/sopv51-dev-comprehensive.nix {
  gitRev = \"$(git rev-parse --short HEAD)\";
  gitBranch = \"$(git rev-parse --abbrev-ref HEAD)\";
  buildDate = \"$(date -Iseconds)\";
})"

# Load into Podman
podman load < /nix/store/*-docker-image-indrajaal-dev.tar.gz
```

### Verify Build

```bash
# Check if image is loaded
podman images | grep indrajaal-dev

# Expected output:
# localhost/indrajaal-dev  nixos-25.05-f817ec38  <IMAGE_ID>  55 years ago  <SIZE>
```

## Troubleshooting

### Container-Specific Issues

**SSL/TLS Certificate Problems**:
- **Problem**: Hex installation fails with `no_cacerts_found` error
- **Cause**: Erlang/OTP cannot find SSL certificates in standard paths
- **Solution**: Container automatically creates multi-path symlinks during startup:
  ```bash
  /etc/ssl/certs/ca-bundle.crt → /nix/store/.../cacert
  /etc/pki/tls/certs/ca-bundle.crt → /nix/store/.../cacert
  /etc/ssl/cert.pem → /nix/store/.../cacert
  /etc/ssl/certs/ca-certificates.crt → /nix/store/.../cacert
  ```
- **Verification**: Inside container run: `elixir -e "IO.inspect(:public_key.cacerts_get())"`

**PAM Authentication Errors**:
- **Problem**: Container exits with `su: pam_start: error 26`
- **Cause**: Minimal NixOS container lacks PAM modules
- **Solution**: Container uses `setpriv` instead of `su`:
  ```bash
  setpriv --reuid=1000 --regid=1000 --init-groups /bin/bash
  ```
- **Benefits**: More container-friendly, no authentication infrastructure required

### Service Issues

### PostgreSQL Won't Start

**Check if port is already in use:**
```bash
lsof -i :5433
```

**Check data directory permissions:**
```bash
ls -la ./data/postgres/
```

**View PostgreSQL logs:**
```bash
tail -f ./data/postgres/logfile
```

### Redis Won't Start

**Check if port is already in use:**
```bash
lsof -i :6379
```

**Test Redis connection:**
```bash
redis-cli -h localhost -p 6379 ping
```

### Container Image Not Found

**Rebuild the container:**
```bash
nix-build -E "(import ./containers/sopv51-dev-comprehensive.nix {
  gitRev = \"$(git rev-parse --short HEAD)\";
  gitBranch = \"$(git rev-parse --abbrev-ref HEAD)\";
  buildDate = \"$(date -Iseconds)\";
})" && podman load < /nix/store/*-docker-image-indrajaal-dev.tar.gz
```

### PHICS Hot-Reloading Not Working

**Check PHICS configuration:**
```bash
cat /workspace/.phics/config.json  # Inside container
```

**Verify volume mount:**
```bash
podman inspect indrajaal-dev | grep -A 5 Mounts
```

## Development Workflow

### Standard Development Session

```bash
# 1. Start complete environment
./scripts/containers/start-dev-container.sh

# 2. Container starts with interactive shell at /workspace
# You're now inside the container with:
# - PostgreSQL 17 accessible at host.docker.internal:5433
# - Redis 7 accessible at host.docker.internal:6379
# - PHICS hot-reloading enabled
# - All project files mounted at /workspace

# 3. Run Phoenix server
mix phx.server

# 4. Edit files on host - changes sync automatically
# 5. Browser auto-reloads on changes (LiveView)

# 6. Exit container (Ctrl+D or exit)
# PostgreSQL and Redis continue running on host
```

### Stopping Services

```bash
# Stop PostgreSQL
pg_ctl stop -D ./data/postgres/

# Stop Redis
redis-cli -h localhost -p 6379 shutdown

# Stop container
podman stop indrajaal-dev
```

## SOPv5.11 Compliance

All scripts follow SOPv5.11 cybernetic framework requirements:

- ✅ **Podman-only policy**: No Docker usage
- ✅ **Container-native development**: All work inside containers
- ✅ **PHICS v2.1 integration**: Hot-reloading with <50ms latency
- ✅ **User namespace management**: Runs as UID 1000 (developer)
- ✅ **External services architecture**: PostgreSQL and Redis on host
- ✅ **Localhost-only registry**: Images stored in localhost/ namespace

## Documentation References

- **Container Build Guide**: `containers/README.md`
- **Dev Container Guide**: `containers/DEV_CONTAINER_GUIDE.md`
- **Complete Setup Journal**: `docs/journal/20251116-1132-comprehensive-dev-container-permanent-setup.md`
- **PHICS v2.1 Documentation**: See CLAUDE.md section on PHICS

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review container documentation in `containers/`
3. Check journal entries in `docs/journal/`
4. Consult CLAUDE.md for SOPv5.11 framework details

---

**Last Updated**: 2025-11-16 11:45:00 CET
**Maintained By**: Indrajaal Development Team
**Version**: 1.0.0 (Comprehensive Development Container)
