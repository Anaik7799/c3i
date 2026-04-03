# SOPv5.1 NixOS Container Build Guide

**Last Updated**: 2025-12-31
**Status**: Production Ready - KVM-Free Build System

## Quick Operations (Devenv)

For daily container operations, use devenv commands:

```bash
devenv shell
sa-up           # Start standalone stack (3 containers)
sa-down         # Stop stack
sa-status       # Container status
sa-logs         # View logs
help            # All commands
```

See [README.md](../README.md) for full command reference.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Container Architecture](#container-architecture)
5. [Build Process](#build-process)
6. [Loading and Running](#loading-and-running)
7. [Runtime Verification](#runtime-verification)
8. [Troubleshooting](#troubleshooting)
9. [PHICS Integration](#phics-integration)
10. [Advanced Topics](#advanced-topics)

## Overview

The Indrajaal project uses NixOS-based containers built with `pkgs.dockerTools.buildImage` using a **KVM-free** approach. This enables building containers on systems without virtualization support.

### Key Features

- ✅ **No KVM Requirement**: Uses `copyToRoot` instead of `runAsRoot`
- ✅ **Runtime User Creation**: User setup happens at container startup, not build time
- ✅ **PHICS v2.1 Integration**: Hot-reloading support for development workflow
- ✅ **Podman Compatible**: Verified to work with Podman 5.4.1+
- ✅ **Content-Addressable**: Efficient storage using Nix's deduplication

### Available Containers

- **sopv51-base** (1.67 GB): Development environment with full tooling
- **sopv51-elixir-app** (622 MB): Production Phoenix application container
- **sopv51-dev-comprehensive** (TBD): Comprehensive development container with PostgreSQL and Redis integration
- **indrajaal-timescaledb-demo** (~1.2 GB): PostgreSQL 17 with TimescaleDB 2.23.0 extension for time-series data

## Prerequisites

### Required Software

```bash
# Verify Nix is available
nix --version  # Should show Nix 2.x

# Verify Podman is available
podman --version  # Should show Podman 5.4.1+

# Verify you're in the NixOS devenv
echo $DEVENV_ACTIVE  # Should output "1" if in devenv shell
```

### System Requirements

- **Build System**: NixOS or system with Nix package manager
- **Container Runtime**: Podman 5.4.1+ (rootless mode supported)
- **Disk Space**: Minimum 5GB free for container builds
- **Memory**: 2GB+ recommended for build process

## Quick Start

### 1. Build Both Containers

```bash
# Set git metadata variables
GIT_REV="$(git rev-parse --short HEAD)"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Build base container
nix-build containers/sopv51-base.nix \
  --argstr gitRev "$GIT_REV" \
  --argstr gitBranch "$GIT_BRANCH" \
  --argstr buildDate "$BUILD_DATE"

# Build app container
nix-build containers/sopv51-elixir-app.nix \
  --argstr gitRev "$GIT_REV" \
  --argstr gitBranch "$GIT_BRANCH" \
  --argstr buildDate "$BUILD_DATE"
```

### 2. Load into Podman

```bash
# Load base container
podman load < result

# Load app container (after building)
podman load < result
```

### 3. Verify Containers

```bash
# List loaded containers
podman images | grep indrajaal-sopv51

# Expected output:
# localhost/indrajaal-sopv51-base        nixos-25.05-latest  <IMAGE_ID>  55 years ago  1.67 GB
# localhost/indrajaal-sopv51-elixir-app  nixos-25.05-latest  <IMAGE_ID>  55 years ago  622 MB
```

## Container Architecture

### Base Container (`sopv51-base.nix`)

**Purpose**: Development environment with full tooling

**Features**:
- Complete Elixir/Phoenix development tools
- Interactive bash shell for debugging
- Comprehensive package set for development
- PHICS marker files for container identification

**Key Components**:
```nix
basePackages = pkgs.buildEnv {
  name = "indrajaal-base-packages";
  paths = with pkgs; [
    bash coreutils findutils gnugrep gawk gnused
    git curl wget vim nano less
    postgresql_17 redis nodejs_20 yarn imagemagick
    elixir_1_18 erlang_27 cacert
  ];
};
```

**Runtime Entrypoint**: Creates developer user and workspace directories

### App Container (`sopv51-elixir-app.nix`)

**Purpose**: Production Phoenix application

**Features**:
- Minimal package set for production deployment
- PHICS configuration for hot-reloading
- Single entrypoint execution model
- Optimized for container orchestration

**Key Components**:
```nix
appFS = pkgs.symlinkJoin {
  name = "indrajaal-app-fs";
  paths = with pkgs; [
    postgresql_17 redis nodejs_20 yarn
    imagemagick cacert
    phicsConfig appEntrypoint
  ];
};
```

**Runtime Entrypoint**: Runs Phoenix server as developer user

**Note**: This container does NOT include bash by design - it runs only via its entrypoint.

## Build Process

### Build Architecture

The container build process uses NixOS's `pkgs.dockerTools.buildImage` with the following key techniques:

#### copyToRoot vs runAsRoot

**Previous Approach (DEPRECATED)**:
```nix
runAsRoot = ''
  useradd -m developer
  mkdir -p /workspace
'';
```
❌ **Problem**: Requires KVM for VM-based builds

**Current Approach**:
```nix
copyToRoot = pkgs.buildEnv {
  name = "indrajaal-base-root";
  paths = [ basePackages markerFiles ];
};
```
✅ **Solution**: No KVM required, runtime entrypoint handles user/directory setup

#### Build-Time vs Runtime Setup

**Build-Time** (Nix evaluation):
- Package installation
- File creation (configs, scripts)
- Environment variable setup
- Label and metadata configuration

**Runtime** (Container startup):
- User creation
- Directory creation
- Permission setup
- Application startup

### Build Commands

#### Basic Build

```bash
nix-build containers/sopv51-base.nix \
  --argstr gitRev "latest" \
  --argstr gitBranch "main" \
  --argstr buildDate "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

#### Build with Specific Git Info

```bash
nix-build containers/sopv51-elixir-app.nix \
  --argstr gitRev "$(git rev-parse --short HEAD)" \
  --argstr gitBranch "$(git rev-parse --abbrev-ref HEAD)" \
  --argstr buildDate "$(date -Iseconds)"
```

#### Build with Logging

```bash
nix-build containers/sopv51-base.nix \
  --argstr gitRev "latest" \
  --argstr gitBranch "main" \
  --argstr buildDate "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  2>&1 | tee ./data/tmp/$(date +%Y%m%d-%H%M)-sopv51-base-build.log
```

### Build Output

Successful builds create a `result` symlink pointing to the Nix store:

```bash
$ ls -l result
lrwxrwxrwx 1 user user 85 Nov 16 08:20 result -> /nix/store/xxxxx-docker-image-indrajaal-sopv51-base.tar.gz
```

## Loading and Running

### Loading into Podman

```bash
# Load container image
podman load < result

# Verify loading
podman images | grep indrajaal-sopv51
```

Expected output:
```
Loaded image: localhost/indrajaal-sopv51-base:nixos-25.05-latest
```

### Running Containers

#### Base Container (Interactive Development)

```bash
# Start interactive shell
podman run -it --name dev-env \
  -v $(pwd):/workspace:z \
  localhost/indrajaal-sopv51-base:nixos-25.05-latest

# Run specific command
podman run --rm --name test-base \
  localhost/indrajaal-sopv51-base:nixos-25.05-latest \
  /bin/bash -c "cd /workspace && mix compile"
```

#### App Container (Production Mode)

```bash
# Start Phoenix application
podman run -d --name indrajaal-app \
  -p 4000:4000 -p 4001:4001 \
  -v $(pwd):/workspace:z \
  localhost/indrajaal-sopv51-elixir-app:nixos-25.05-latest

# Check logs
podman logs -f indrajaal-app

# Exec into running container (for debugging)
podman exec -it indrajaal-app /bin/sh
```

**Note**: App container doesn't have bash, use `/bin/sh` or full path to bash from Nix store.

## Runtime Verification

### Base Container Verification

```bash
# Test base container runs correctly
podman run --rm --name test-base \
  localhost/indrajaal-sopv51-base:nixos-25.05-latest \
  /bin/bash -c "echo 'Testing base container' && id && pwd && ls -la /workspace"
```

Expected output:
```
Testing base container
uid=0 gid=0 groups=0
/workspace
total 16
drwxr-xr-x 4 0 0 4096 Nov 16 07:45 .
dr-xr-xr-x 1 0 0 4096 Nov 16 07:45 ..
drwxr-xr-x 2 0 0 4096 Nov 16 07:45 data
drwxr-xr-x 2 0 0 4096 Nov 16 07:45 logs
```

### App Container Verification

App container is designed to run via its entrypoint only:

```bash
# Start app container with default entrypoint
podman run -d --name test-app \
  -p 4000:4000 \
  -v $(pwd):/workspace:z \
  localhost/indrajaal-sopv51-elixir-app:nixos-25.05-latest

# Wait for startup
sleep 5

# Check if Phoenix is running
curl http://localhost:4000/health

# Check container logs
podman logs test-app

# Cleanup
podman stop test-app
podman rm test-app
```

### Verification Checklist

- [ ] Container loads without errors
- [ ] Workspace directories exist
- [ ] Entrypoint script executes
- [ ] Phoenix server starts (app container)
- [ ] PHICS marker files present
- [ ] Volume mounts work correctly

## Troubleshooting

### Common Issues

#### 1. Build Fails with KVM Error

**Error**:
```
error: a 'x86_64-linux' with features {} is required to build
```

**Solution**: Verify you're using the latest container definitions with `copyToRoot`, not `runAsRoot`.

#### 2. Container Load Fails with Healthcheck Error

**Error**:
```
Error: decoding tar config: json: cannot unmarshal string into Go struct field Schema2HealthConfig
```

**Solution**: Healthcheck blocks have been removed from current containers. Health monitoring should be external.

#### 3. App Container "Bash Not Found" Error

**Error**:
```
Error: crun: executable file `/bin/bash` not found
```

**Solution**: This is expected behavior. App container doesn't include bash - use entrypoint or exec with `/bin/sh`.

#### 4. Permission Issues with Volume Mounts

**Error**:
```
Permission denied accessing /workspace
```

**Solution**: Add `:z` or `:Z` SELinux label to volume mount:
```bash
-v $(pwd):/workspace:z
```

### Debug Commands

```bash
# Inspect container configuration
podman inspect localhost/indrajaal-sopv51-base:nixos-25.05-latest

# Check container entrypoint
podman inspect localhost/indrajaal-sopv51-elixir-app:nixos-25.05-latest \
  --format '{{.Config.Cmd}}'

# Run with shell override (base container only)
podman run -it --rm \
  --entrypoint /bin/bash \
  localhost/indrajaal-sopv51-base:nixos-25.05-latest

# Check container filesystem
podman run --rm \
  localhost/indrajaal-sopv51-base:nixos-25.05-latest \
  find /workspace -ls
```

## PHICS Integration

### What is PHICS?

**PHICS** (Phoenix Hot-reloading Integration Container System) enables seamless hot-reloading during development within containerized environments.

### PHICS Configuration

Located at `/workspace/.phics/config.json` in app container:

```json
{
  "watch_paths": [
    "lib/**/*.ex",
    "lib/**/*.exs",
    "priv/static/**/*",
    "assets/**/*"
  ],
  "reload_commands": [
    "mix compile",
    "mix phx.digest"
  ],
  "port": 4000
}
```

### PHICS Development Workflow

```bash
# 1. Start app container with PHICS enabled
podman run -d --name phics-dev \
  -p 4000:4000 -p 4001:4001 \
  -v $(pwd):/workspace:z \
  -e PHICS_ENABLED=true \
  localhost/indrajaal-sopv51-elixir-app:nixos-25.05-latest

# 2. Edit files on host - changes sync automatically
# Files in lib/, priv/static/, assets/ trigger recompilation

# 3. Monitor logs for reload events
podman logs -f phics-dev

# 4. Access application
curl http://localhost:4000
```

### PHICS Marker Files

Both containers include PHICS marker files for identification:

- **Base Container**: `/.phics-container` marker
- **App Container**: `/workspace/.phics/config.json` configuration

## Advanced Topics

### Container Image Tags

Images are tagged with NixOS version and git revision:

```
localhost/indrajaal-sopv51-base:nixos-25.05-latest
localhost/indrajaal-sopv51-elixir-app:nixos-25.05-latest
```

### Content-Addressable Storage

Nix's content-addressable store means:
- Packages are shared between containers automatically
- Rebuilds only create new layers for changed components
- Disk usage is optimized through deduplication

### Standalone vs Layered Architecture

**Current Design**: Both containers are standalone (not layered)

**Why**: Nix doesn't provide access to parent container config at evaluation time, making `fromImage` layering impractical.

**Benefits**:
- ✅ Clean separation of concerns
- ✅ Smaller app container (622 MB vs base 1.67 GB)
- ✅ Nix deduplication still applies
- ✅ No dependency on base container at runtime

**Trade-offs**:
- ⚠️ Some package duplication in Nix expressions
- ⚠️ Environment variables must be duplicated

### Adding Bash to App Container (Optional)

If interactive shell is needed in app container:

```nix
# In sopv51-elixir-app.nix
appFS = pkgs.symlinkJoin {
  name = "indrajaal-app-fs";
  paths = with pkgs; [
    bash          # Add this line
    postgresql_17
    redis
    # ... rest of packages
  ];
};
```

Rebuild after modification:
```bash
nix-build containers/sopv51-elixir-app.nix \
  --argstr gitRev "latest" \
  --argstr gitBranch "main" \
  --argstr buildDate "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

### Multi-Container Orchestration

Example `podman-compose.yml` (if using podman-compose):

```yaml
version: '3'

services:
  app:
    image: localhost/indrajaal-sopv51-elixir-app:nixos-25.05-latest
    ports:
      - "4000:4000"
      - "4001:4001"
    volumes:
      - ./:/workspace:z
    environment:
      - PHICS_ENABLED=true
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/indrajaal_dev
      - REDIS_URL=redis://redis:6379

  db:
    image: postgres:17
    environment:
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=indrajaal_dev
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Build Containers

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Nix
        uses: cachix/install-nix-action@v22

      - name: Build Base Container
        run: |
          nix-build containers/sopv51-base.nix \
            --argstr gitRev "${{ github.sha }}" \
            --argstr gitBranch "${{ github.ref_name }}" \
            --argstr buildDate "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

      - name: Build App Container
        run: |
          nix-build containers/sopv51-elixir-app.nix \
            --argstr gitRev "${{ github.sha }}" \
            --argstr gitBranch "${{ github.ref_name }}" \
            --argstr buildDate "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

      - name: Load and Test
        run: |
          podman load < result
          podman run --rm localhost/indrajaal-sopv51-base:nixos-25.05-latest \
            /bin/bash -c "echo 'Build successful'"
```

## TimescaleDB Container

### indrajaal-timescaledb-demo

A PostgreSQL 17 container with TimescaleDB 2.23.0 extension for time-series data storage and analysis.

**Features**:
- PostgreSQL 17 with TimescaleDB extension fully integrated
- Built-from-source TimescaleDB using NixOS withPackages pattern
- Automatic extension preloading via shared_preload_libraries
- Hypertable support for time-series data partitioning
- **Security-enhanced execution**: Non-root PostgreSQL with privilege dropping (UID 999)
- **User namespace management**: Automated postgres user creation in entrypoint
- **Principle of least privilege**: Database runs as postgres user, never root
- **Proper directory permissions**: 700 for data directory, owner-only access
- Data persistence via volume mounts
- Network accessible on port 5433 (non-standard port for security)

**Build TimescaleDB Container**:
```bash
# Build the container (requires NIXPKGS_ALLOW_UNFREE=1 for TimescaleDB)
NIXPKGS_ALLOW_UNFREE=1 nix-build containers/indrajaal-timescaledb-demo.nix --impure 2>&1 | tee ./data/tmp/$(date +%Y%m%d-%H%M)-timescaledb-build.log

# Load into Podman
podman load < result

# Verify the image
podman images | grep indrajaal-timescaledb-demo
```

**Security and User Management**:

The container implements enterprise-grade security with non-root execution:

```bash
# Security entrypoint script: scripts/timescale/container-entrypoint.sh
# - Creates postgres user (UID 999) if not exists
# - Sets proper directory ownership (999:999)
# - Configures directory permissions (700 for data, 755 for run)
# - Initializes database as postgres user via su-exec
# - Starts PostgreSQL server as postgres user

# Key security features:
# 1. Privilege dropping with su-exec (not root execution)
# 2. User namespace mapping (UID 999 postgres user)
# 3. Directory isolation (700 permissions for data)
# 4. Proper volume mount architecture
```

**Volume Mount Architecture**:

```yaml
# Critical: Backup directory must be OUTSIDE PostgreSQL data directory
# to prevent initdb "directory not empty" errors

# ✅ CORRECT: Backup mount outside data directory
volumes:
  - ./data/timescaledb:/var/lib/postgresql/data:z
  - ./data/timescale-backups:/var/backups:z  # Separate backup mount

# ❌ WRONG: Backup mount creates subdirectory in data directory
volumes:
  - ./data/timescaledb:/var/lib/postgresql/data:z
  - ./data/timescaledb/backups:/var/backups:z  # Creates subdirectory
```

**Run TimescaleDB Container**:
```bash
# Start with data persistence (via podman-compose)
podman-compose up -d postgres

# Or start manually with proper volume mounts
podman run -d --name timescaledb \
  -p 5433:5433 \
  -v $(pwd)/data/timescaledb:/var/lib/postgresql/data:z \
  -v $(pwd)/scripts/timescale/container-entrypoint.sh:/scripts/container-entrypoint.sh:z \
  -v $(pwd)/data/timescale-backups:/var/backups:z \
  localhost/indrajaal-timescaledb-demo:nixos-devenv

# Verify security setup
podman exec timescaledb id postgres
# Expected: uid=999(postgres) gid=999(postgres) groups=999(postgres)

# Verify database access
podman exec timescaledb psql -h localhost -p 5433 -U postgres -c "SELECT version();"

# Check logs for security initialization
podman logs timescaledb
```

**Create TimescaleDB Extension and Hypertables**:
```bash
# Connect to PostgreSQL
podman exec -it timescaledb psql -U postgres

# Create TimescaleDB extension (run once per database)
CREATE EXTENSION IF NOT EXISTS timescaledb;

# Verify extension is loaded
\dx timescaledb

# Create a time-series table
CREATE TABLE sensor_data (
  time TIMESTAMPTZ NOT NULL,
  sensor_id INTEGER,
  temperature DOUBLE PRECISION,
  humidity DOUBLE PRECISION
);

# Convert to hypertable (enables automatic partitioning)
SELECT create_hypertable('sensor_data', 'time');

# Insert sample time-series data
INSERT INTO sensor_data VALUES
  (NOW(), 1, 21.5, 45.0),
  (NOW() - INTERVAL '1 hour', 1, 21.8, 46.2),
  (NOW() - INTERVAL '2 hours', 1, 22.1, 47.5);

# Query with time-series optimization
SELECT * FROM sensor_data
WHERE time > NOW() - INTERVAL '24 hours'
ORDER BY time DESC;
```

**TimescaleDB-Specific Features**:
```sql
-- Continuous aggregates for real-time materialized views
CREATE MATERIALIZED VIEW sensor_hourly
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', time) AS hour,
       sensor_id,
       AVG(temperature) as avg_temp,
       MAX(temperature) as max_temp
FROM sensor_data
GROUP BY hour, sensor_id;

-- Data retention policies
SELECT add_retention_policy('sensor_data', INTERVAL '90 days');

-- Compression for older data
ALTER TABLE sensor_data SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'sensor_id'
);

SELECT add_compression_policy('sensor_data', INTERVAL '7 days');

-- Time-series analytics functions
SELECT time_bucket('5 minutes', time) AS bucket,
       sensor_id,
       AVG(temperature) as avg_temp
FROM sensor_data
WHERE time > NOW() - INTERVAL '1 hour'
GROUP BY bucket, sensor_id
ORDER BY bucket DESC;
```

**Container Management**:
```bash
# Stop container
podman stop timescaledb

# Start container
podman start timescaledb

# Remove container (keeps data in volume)
podman rm timescaledb

# Backup database
podman exec timescaledb pg_dump -U postgres -d postgres > backup.sql

# Restore database
podman exec -i timescaledb psql -U postgres -d postgres < backup.sql
```

**Troubleshooting**:
- **Extension not available**: Verify container was built with `NIXPKGS_ALLOW_UNFREE=1` flag
- **Must be preloaded error**: Check `shared_preload_libraries` in postgresql.conf includes 'timescaledb'
- **Permission denied**: Ensure volume mount has correct SELinux context (`:z` flag)
- **Connection refused**: Verify container is running and port 5432 is exposed
- **Data not persisting**: Use named volume (`timescaledb_data`) or host directory mount

**Integration with Indrajaal Application**:
```elixir
# In config/dev.exs or config/runtime.exs
config :indrajaal, Indrajaal.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",  # or container name if using podman-compose
  port: 5432,
  database: "indrajaal_dev",
  pool_size: 10

# In migration file
def change do
  # Enable TimescaleDB extension
  execute "CREATE EXTENSION IF NOT EXISTS timescaledb", "DROP EXTENSION IF EXISTS timescaledb"

  # Create time-series table
  create table(:alarm_events) do
    add :time, :utc_datetime_usec, null: false
    add :alarm_id, references(:alarms), null: false
    add :event_type, :string
    add :severity, :integer
    timestamps()
  end

  # Convert to hypertable
  execute """
  SELECT create_hypertable('alarm_events', 'time')
  """, ""
end
```

**Documentation**:
- **Container Definition**: `containers/indrajaal-timescaledb-demo.nix`
- **Build Log**: `data/tmp/20251125-1422-postgres-container-rebuild.log`
- **TimescaleDB Docs**: https://docs.timescale.com/

## Comprehensive Development Container

### sopv51-dev-comprehensive

A complete development environment container that integrates with external PostgreSQL 17 and Redis 7 services running on the host.

**Features**:
- Full Elixir 1.19 + Erlang 27 development environment
- PHICS v2.1 hot-reloading with <50ms synchronization
- Integration with host PostgreSQL 17 (port 5433)
- Integration with host Redis 7 (port 6379)
- SOPv5.11 cybernetic framework compliance
- User namespace management (UID 1000)
- Automated startup with dependency checking
- Multi-path SSL/TLS certificate strategy for Erlang/OTP compatibility
- PAM-free user switching with setpriv for enhanced container compatibility

**Build and Run**:
```bash
# Build the comprehensive development container
nix-build -E "(import ./containers/sopv51-dev-comprehensive.nix {gitRev = \"$(git rev-parse --short HEAD)\"; gitBranch = \"$(git rev-parse --abbrev-ref HEAD)\"; buildDate = \"$(date -Iseconds)\";})"

# Load into Podman
podman load < /nix/store/*-docker-image-indrajaal-dev.tar.gz

# Run with automated setup (starts PostgreSQL and Redis if needed)
./scripts/containers/start-dev-container.sh
```

**Manual Services Setup**:
```bash
# Start PostgreSQL 17 on port 5433
./scripts/containers/start-postgresql.sh

# Start Redis 7 on port 6379
./scripts/containers/start-redis.sh

# Start development container (connects to external services via host.docker.internal)
podman run -it --rm \
  --name indrajaal-dev \
  -v "$(pwd):/workspace:z" \
  -p 4000:4000 \
  -p 4001:4001 \
  --add-host host.docker.internal:host-gateway \
  localhost/indrajaal-dev:nixos-25.05-$(git rev-parse --short HEAD)
```

**Documentation**:
- **Setup Guide**: `containers/DEV_CONTAINER_GUIDE.md`
- **Helper Scripts**: `scripts/containers/start-*.sh`
- **Complete Documentation**: `docs/journal/20251116-1132-comprehensive-dev-container-permanent-setup.md`

**Container-Specific Troubleshooting**:

**SSL/TLS Certificate Issues**:
- **Problem**: Hex installation fails with `no_cacerts_found` error
- **Root Cause**: Erlang/OTP's `:pubkey_os_cacerts` module cannot find SSL certificates
- **Solution**: Container uses multi-path symlink strategy linking NixOS cacert bundle to multiple standard paths:
  - `/etc/ssl/certs/ca-bundle.crt`
  - `/etc/pki/tls/certs/ca-bundle.crt`
  - `/etc/ssl/cert.pem`
  - `/etc/ssl/certs/ca-certificates.crt`
- **Verification**: Run `elixir -e "IO.inspect(:public_key.cacerts_get())"` inside container to verify certificates are accessible

**PAM Authentication Errors**:
- **Problem**: Container exits with `su: pam_start: error 26` during user switching
- **Root Cause**: Minimal NixOS container doesn't include PAM modules required by `su` command
- **Solution**: Container uses `setpriv` instead of `su` for PAM-free user switching:
  ```bash
  setpriv --reuid=1000 --regid=1000 --init-groups /bin/bash
  ```
- **Benefits**: More container-friendly, no authentication infrastructure required, works in minimal container environments

## References

- **Container Definitions**: `containers/sopv51-base.nix`, `containers/sopv51-elixir-app.nix`, `containers/sopv51-dev-comprehensive.nix`
- **Build Documentation**: `data/tmp/20251116-0830-sopv51-container-refactoring-complete.md`
- **Runtime Verification**: `data/tmp/20251116-0845-sopv51-container-runtime-verification.md`
- **Complete Journey**: `docs/journal/20251116-0850-sopv51-container-refactoring-journal.md`
- **Comprehensive Dev Setup**: `docs/journal/20251116-1132-comprehensive-dev-container-permanent-setup.md`
- **NixOS Docker Tools**: https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-dockerTools
- **PHICS Documentation**: See project CLAUDE.md for PHICS v2.1 details

---

**Last Updated**: 2025-11-16 08:52:00 CET
**Maintained By**: Indrajaal Development Team
**Version**: 1.0.0 (KVM-Free Architecture)
