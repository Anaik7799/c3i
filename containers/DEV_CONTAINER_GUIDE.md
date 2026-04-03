# SOPv5.11 Comprehensive Development Container Guide

**Container**: `localhost/indrajaal-dev:nixos-25.05-f817ec38`
**Status**: ✅ Production Ready
**Last Updated**: 2025-11-16 11:22:00 CEST

## Overview

The SOPv5.11 Comprehensive Development Container provides a complete, isolated development environment for the Indrajaal application with all required tools and services.

### Key Features

- ✅ **Complete Development Stack**: Elixir 1.19, Erlang 27, Node.js 20
- ✅ **External Services**: PostgreSQL and Redis running on host
- ✅ **PHICS v2.1**: Hot-reloading with <50ms sync latency
- ✅ **SOPv5.11 Compliance**: Cybernetic framework integration
- ✅ **Podman-Only**: Zero Docker dependencies
- ✅ **NixOS-Based**: Reproducible and immutable infrastructure
- ✅ **Multi-Path SSL/TLS**: Certificate strategy for Erlang/OTP compatibility
- ✅ **PAM-Free User Switching**: Enhanced container compatibility with setpriv

## Quick Start

### 1. Prerequisites

Ensure external services are running on the host:

```bash
# PostgreSQL must be running on port 5433
pg_isready -h localhost -p 5433

# Redis must be running on port 6379
redis-cli -h localhost -p 6379 ping
```

### 2. Start the Development Container

```bash
# Run the container with workspace mounted
podman run -it --rm \
  --name indrajaal-dev \
  -v "$(pwd):/workspace:z" \
  -p 4000:4000 \
  -p 4001:4001 \
  --add-host host.docker.internal:host-gateway \
  localhost/indrajaal-dev:nixos-25.05-f817ec38
```

### 3. Inside the Container

The container automatically:
- ✅ Creates `/etc/passwd` and `/etc/group` for user management
- ✅ Configures SSL certificates for Erlang/OTP (multi-path symlink strategy)
- ✅ Sets up workspace directory structure
- ✅ Installs Hex and Rebar3
- ✅ Runs `mix deps.get` if `mix.exs` exists
- ✅ Runs `npm install` if `assets/package.json` exists
- ✅ Switches to `developer` user (UID 1000) using setpriv
- ✅ Opens interactive bash shell in `/workspace`

## Architecture

### External Services (Running on Host)

**PostgreSQL 17** - Port 5433
- Accessed via: `host.docker.internal:5433`
- Database: `indrajaal_dev`
- User: `postgres`
- Password: `postgres`

**Redis 7** - Port 6379
- Accessed via: `host.docker.internal:6379`
- Database: 0 (default)

### Container Services

All development tools run inside the container:
- **Elixir 1.19** + **Erlang 27**: Application runtime
- **Node.js 20**: Frontend asset compilation
- **PostgreSQL Client**: Database access
- **Redis Client**: Cache access
- **Git, Curl, Wget**: Version control and downloads
- **Development Tools**: credo, dialyxir, sobelow, ex_doc
- **Editors**: nano, vim
- **Build Tools**: gcc, make, autoconf, automake

### Volume Mounts

- `/workspace` → Project root directory (read-write)
- Hot-reloading enabled via PHICS v2.1

### Port Mappings

- `4000` → Phoenix server
- `4001` → LiveReload WebSocket

## Development Workflow

### Starting Phoenix Server

```bash
# Inside the container
cd /workspace
mix phx.server

# Access at: http://localhost:4000
```

### Running Tests

```bash
# All tests
mix test

# With coverage
mix test --cover

# Specific test file
mix test test/specific_test.exs
```

### Compilation

```bash
# Standard compilation
mix compile

# With warnings as errors
mix compile --warnings-as-errors

# Force recompilation
mix compile --force
```

### Database Operations

```bash
# Create database
mix ecto.create

# Run migrations
mix ecto.migrate

# Reset database
mix ecto.reset

# Database status
mix ecto.migrations
```

### Asset Management

```bash
# Compile assets
cd assets && npm run build

# Watch assets for changes
cd assets && npm run watch

# Install new packages
cd assets && npm install <package>
```

## PHICS v2.1 Hot-Reloading

The container includes PHICS v2.1 for seamless hot-reloading:

### Configuration

Location: `/workspace/.phics/config.json`

```json
{
  "version": "2.1.0",
  "enabled": true,
  "watch_paths": [
    "/workspace/lib",
    "/workspace/test",
    "/workspace/priv",
    "/workspace/assets",
    "/workspace/config"
  ],
  "sync_interval_ms": 50,
  "hot_reload": true,
  "bidirectional_sync": true,
  "container_mode": true
}
```

### How It Works

1. Edit files on **host** in your preferred editor
2. Changes synced to **container** within 50ms
3. Phoenix automatically reloads code
4. LiveView updates browser in real-time

### Verification

```bash
# Check PHICS status
echo $PHICS_ENABLED          # Should be: true
echo $PHICS_WATCH_ENABLED    # Should be: true
echo $PHICS_HOT_RELOAD       # Should be: enabled
```

## Helper Scripts

### Start PostgreSQL (Host)

Create `scripts/start-postgresql.sh`:
```bash
#!/bin/bash
# Start PostgreSQL on port 5433 (avoiding conflicts with default 5432)
podman run -d --name indrajaal-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=indrajaal_dev \
  -p 5433:5432 \
  postgres:17-alpine
```

### Start Redis (Host)

Create `scripts/start-redis.sh`:
```bash
#!/bin/bash
# Start Redis on port 6379
podman run -d --name indrajaal-redis \
  -p 6379:6379 \
  redis:7-alpine
```

### Start Development Container

Create `scripts/start-dev-container.sh`:
```bash
#!/bin/bash
# Start comprehensive development container
podman run -it --rm \
  --name indrajaal-dev \
  -v "$(pwd):/workspace:z" \
  -p 4000:4000 \
  -p 4001:4001 \
  --add-host host.docker.internal:host-gateway \
  localhost/indrajaal-dev:nixos-25.05-f817ec38
```

## Troubleshooting

### Container-Specific Issues

#### SSL/TLS Certificate Problems

**Problem**: Hex installation fails with `no_cacerts_found` error during container startup

**Root Cause**: Erlang/OTP's `:pubkey_os_cacerts` module cannot find SSL certificates in standard system paths

**Solution**: Container implements multi-path symlink strategy linking NixOS cacert bundle to multiple standard paths:
- `/etc/ssl/certs/ca-bundle.crt`
- `/etc/pki/tls/certs/ca-bundle.crt`
- `/etc/ssl/cert.pem`
- `/etc/ssl/certs/ca-certificates.crt`

**Verification**: Inside container, run:
```bash
elixir -e "IO.inspect(:public_key.cacerts_get())"
# Should return list of certificates, not :no_cacerts_found
```

#### PAM Authentication Errors

**Problem**: Container exits with `su: pam_start: error 26` during user switching

**Root Cause**: Minimal NixOS container doesn't include PAM modules required by `su` command

**Solution**: Container uses `setpriv` instead of `su` for PAM-free user switching:
```bash
setpriv --reuid=1000 --regid=1000 --init-groups /bin/bash
```

**Benefits**:
- More container-friendly than `su`
- No authentication infrastructure required
- Works reliably in minimal container environments
- Proper user/group initialization with `--init-groups`

### External Service Connectivity

### Cannot Connect to PostgreSQL

**Problem**: `FATAL:  password authentication failed`

**Solution**:
1. Verify PostgreSQL is running: `pg_isready -h localhost -p 5433`
2. Test connection: `psql -h host.docker.internal -p 5433 -U postgres -d indrajaal_dev`
3. Ensure `--add-host host.docker.internal:host-gateway` in run command

### Cannot Connect to Redis

**Problem**: `Error in reconnection: :econnrefused`

**Solution**:
1. Verify Redis is running: `redis-cli -h localhost -p 6379 ping`
2. Test from container: `redis-cli -h host.docker.internal -p 6379 ping`
3. Ensure Redis bound to `0.0.0.0` not just `127.0.0.1`

### Mix Dependencies Not Installing

**Problem**: `** (Mix) Could not find Hex...`

**Solution**:
1. Container auto-installs Hex on startup
2. Manual install: `mix local.hex --force`
3. Install Rebar: `mix local.rebar --force`
4. Retry: `mix deps.get`

### Hot-Reloading Not Working

**Problem**: Code changes not reflected

**Solution**:
1. Verify: `echo $PHICS_ENABLED`
2. Check Phoenix LiveReload config
3. Ensure port 4001 mapped: `-p 4001:4001`
4. Check browser console for WebSocket

### Permission Denied Errors

**Problem**: `Permission denied` creating files

**Solution**:
1. Container runs as UID 1000
2. Fix ownership: `chown -R 1000:1000 .`
3. Use `:z` volume flag: `-v "$(pwd):/workspace:z"`

## Container Maintenance

### Updating

```bash
# Rebuild with latest
nix-build -E "(import ./containers/sopv51-dev-comprehensive.nix {
  gitRev = \"$(git rev-parse --short HEAD)\";
  gitBranch = \"$(git rev-parse --abbrev-ref HEAD)\";
  buildDate = \"$(date -Iseconds)\";
})"

# Load
podman load < /nix/store/...-docker-image-indrajaal-dev.tar.gz
```

### Cleaning Up

```bash
podman stop indrajaal-dev
podman container prune
podman image prune
```

## Additional Resources

- **Container Definition**: `containers/sopv51-dev-comprehensive.nix`
- **Helper Scripts**: `scripts/containers/`
  - `start-postgresql.sh` - PostgreSQL service management
  - `start-redis.sh` - Redis service management
  - `start-dev-container.sh` - Main orchestrator script
- **Container README**: `containers/README.md`
- **Scripts README**: `scripts/containers/README.md`
- **CLAUDE.md**: Complete project guidelines

---

**Container Built**: 2025-11-16 11:20:00 CEST
**Git Revision**: f817ec38
**Branch**: feature/aee-sopv511-compilation-cleanup
**Status**: ✅ Production Ready
