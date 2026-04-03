# Functional NixOS Development Container Guide

**Last Updated**: 2025-11-16 15:10:00 CEST
**Status**: ✅ PRODUCTION READY
**Container Version**: NixOS 25.05 with Elixir 1.19.2

## Overview

This guide documents the fully functional NixOS development container for the Indrajaal project, which includes all necessary fixes and features for seamless Phoenix development.

## Container Features

### ✅ Core Technologies
- **Elixir**: 1.19.2 (upgraded from 1.18.4)
- **Erlang/OTP**: 27
- **Node.js**: 20
- **PostgreSQL Client**: 17 (connects to external PostgreSQL on port 5433)
- **Redis Client**: 7 (connects to external Redis on port 6379)

### ✅ Critical Fixes Applied
1. **UTF-8 Locale Support**: Full glibc locales with LOCALE_ARCHIVE environment variable
2. **SSL/TLS Certificates**: Multi-path certificate symlink strategy for Erlang/OTP compatibility
3. **PAM-Free User Switching**: Using `setpriv` instead of `su` to avoid authentication issues
4. **PHICS v2.1 Integration**: Hot-reloading support with bidirectional file synchronization

### ✅ Development Capabilities
- ✓ Phoenix server with hot-reloading
- ✓ Compilation within container
- ✓ Testing with ExUnit
- ✓ Interactive IEx shell
- ✓ Database migrations
- ✓ Asset compilation (esbuild, tailwind)

## Quick Start

### One-Command Setup

```bash
# Build, load, start, and verify the container
elixir scripts/containers/create_functional_dev_container.exs --all
```

### Manual Setup

#### Step 1: Build Container

```bash
cd containers
nix-build sopv51-dev-comprehensive.nix
```

This will output a path like:
```
/nix/store/lgixpkk7l1b6l99l2drzx8680fqzi9m4-docker-image-indrajaal-dev.tar.gz
```

#### Step 2: Load Container Image

```bash
podman load < /nix/store/lgixpkk7l1b6l99l2drzx8680fqzi9m4-docker-image-indrajaal-dev.tar.gz
```

#### Step 3: Start Container

```bash
cd /home/an/dev/indrajaal-demo  # Must be in project root
./scripts/containers/start-dev-container.sh
```

Or manually:

```bash
podman run -d --name indrajaal-dev \
  -v "$(pwd):/workspace:z" \
  -p 4000:4000 \
  -p 4001:4001 \
  localhost/indrajaal-dev:nixos-25.05-unknown
```

#### Step 4: Verify Installation

```bash
# Check Elixir version
podman exec indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && elixir --version"

# Check locale support
podman exec indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && echo \$LOCALE_ARCHIVE"

# Check SSL certificates
podman exec indrajaal-dev bash -c "ls -la /etc/ssl/certs/ca-bundle.crt"
```

## Daily Workflow

### Starting Development Session

```bash
# 1. Ensure external services are running (PostgreSQL, Redis)
./scripts/containers/start-postgresql.sh
./scripts/containers/start-redis.sh

# 2. Start development container
./scripts/containers/start-dev-container.sh
```

### Running Commands in Container

**Important**: Always source the environment file first to set LOCALE_ARCHIVE and other variables.

```bash
# ✅ Correct pattern (with environment sourcing)
podman exec indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && cd /workspace && COMMAND"

# ❌ Wrong pattern (missing environment sourcing)
podman exec indrajaal-dev bash -c "cd /workspace && COMMAND"
```

### Common Development Commands

```bash
# Install dependencies
podman exec indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && cd /workspace && mix deps.get"

# Compile project
podman exec indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && cd /workspace && mix compile"

# Run tests
podman exec indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && cd /workspace && mix test"

# Start Phoenix server
podman exec indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && cd /workspace && mix phx.server"

# Interactive IEx shell
podman exec -it indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && cd /workspace && iex -S mix"

# Database migrations
podman exec indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && cd /workspace && mix ecto.migrate"
```

## Container Architecture

### Directory Structure

```
/workspace          # Project root (mounted from host)
  ├── lib/
  ├── test/
  ├── mix.exs
  └── ...

/etc/profile.d/
  └── indrajaal.sh  # Environment configuration (MUST be sourced)

/etc/ssl/certs/     # SSL certificate symlinks
  ├── ca-bundle.crt
  ├── ca-certificates.crt
  └── ...

/nix/store/
  ├── *-elixir-1.19.2/
  ├── *-erlang-27/
  ├── *-glibc-locales-2.40-66/
  └── ...
```

### Environment Variables

Key environment variables set in `/etc/profile.d/indrajaal.sh`:

```bash
# Core paths
export PATH="/bin:/usr/bin:/usr/local/bin"
export MIX_HOME="/workspace/.mix"
export HEX_HOME="/workspace/.hex"
export NPM_CONFIG_PREFIX="/workspace/.npm-global"

# Locale support (CRITICAL)
export LOCALE_ARCHIVE=/nix/store/*-glibc-locales-2.40-66/lib/locale/locale-archive
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# SSL/TLS certificates
export SSL_CERT_FILE=/nix/store/*-cacert-*/etc/ssl/certs/ca-bundle.crt

# PHICS configuration
export PHICS_ENABLED=true
export PHICS_WATCH_ENABLED=true
export PHICS_CONTAINER_MODE=development
export PHICS_HOT_RELOAD=enabled

# SOPv5.11 configuration
export SOPV51_ENABLED=true
export SOPV51_CYBERNETIC_EXECUTION=true
export SOPV51_PATIENT_MODE=true
export SOPV51_CONTAINER_ONLY=true

# Development settings
export MIX_ENV=dev
export NODE_ENV=development
export ELIXIR_ERL_OPTIONS="+S 16"
```

## Troubleshooting

### Issue: "VM is running with native name encoding of latin1"

**Symptom**: Elixir warns about latin1 encoding instead of UTF-8.

**Solution**: Always source the environment file before running Elixir commands:

```bash
podman exec indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && elixir --version"
```

The `LOCALE_ARCHIVE` environment variable must be set for Elixir to find UTF-8 locale data.

### Issue: "bash: warning: setlocale: LC_ALL: cannot change locale"

**Symptom**: Bash shows locale warning when starting.

**Impact**: This is purely cosmetic and appears before the environment file is sourced. Once sourced, all locale-dependent tools work correctly with UTF-8.

**Solution**: This warning can be ignored. Elixir itself will not show locale warnings when the environment is properly sourced.

### Issue: "Could not find an SCM for dependency :phoenix"

**Symptom**: Mix complains about missing Hex package manager.

**Solution**: Install Hex within the container:

```bash
podman exec indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && cd /workspace && mix local.hex --force"
```

The container entrypoint should install Hex automatically, but if running commands directly via `podman exec`, you may need to install it manually.

### Issue: SSL/TLS certificate errors from Erlang

**Symptom**: Erlang cannot find SSL certificates for HTTPS connections.

**Solution**: Verify the certificate symlinks exist:

```bash
podman exec indrajaal-dev bash -c "ls -la /etc/ssl/certs/ca-bundle.crt /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/cert.pem"
```

The container implements a multi-path certificate strategy to ensure Erlang can find certificates at any of these standard locations.

### Issue: Container not starting from correct directory

**Symptom**: `mix.exs` not found when starting container.

**Solution**: Always start the container from the project root directory:

```bash
cd /home/an/dev/indrajaal-demo  # Project root
./scripts/containers/start-dev-container.sh
```

The workspace mount (`-v "$(pwd):/workspace:z"`) requires you to be in the correct directory.

## Advanced Usage

### Interactive Development Shell

For extended development sessions, you can get an interactive bash shell inside the container:

```bash
podman exec -it indrajaal-dev bash

# Inside container:
source /etc/profile.d/indrajaal.sh
cd /workspace
mix compile
mix phx.server
```

### Hot-Reloading with PHICS

The container supports PHICS v2.1 hot-reloading:

1. Edit files on host (in `/home/an/dev/indrajaal-demo`)
2. Files are automatically synchronized to container (`/workspace`)
3. Phoenix LiveReload detects changes and reloads browser

### Running Background Services

```bash
# Start Phoenix server in detached mode
podman exec -d indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && cd /workspace && mix phx.server"

# View logs
podman logs -f indrajaal-dev
```

### Resource Management

The container is designed to use:
- **CPU**: 10-16 cores (via `ELIXIR_ERL_OPTIONS="+S 16"`)
- **Memory**: Dynamically allocated, typically 2-4GB for development

## Container Definition Reference

The container is defined in `containers/sopv51-dev-comprehensive.nix`.

### Key Sections

#### Packages Included

```nix
paths = [
  # Core runtime
  elixir              # 1.19.2
  pkgs.erlang_27      # OTP 27
  pkgs.nodejs_20      # Node.js 20

  # Database clients
  pkgs.postgresql_17  # PostgreSQL client
  pkgs.redis         # Redis client

  # Development tools
  pkgs.git
  pkgs.curl
  pkgs.jq

  # SSL/TLS
  pkgs.cacert
  pkgs.openssl

  # Locale support (CRITICAL)
  pkgs.glibcLocales

  # Process management
  pkgs.util-linux  # For setpriv command
]
```

#### Environment Configuration

Located in the `envConfig` section, this text file is placed at `/etc/profile.d/indrajaal.sh` and must be sourced before running development commands.

#### Entrypoint Script

The `devEntrypoint` script:
1. Creates /etc/passwd and /etc/group for user management
2. Sets up SSL certificates with multi-path symlinks
3. Creates workspace structure
4. Installs Hex and Rebar if not present
5. Switches to developer user (UID 1000) using `setpriv`

## Validation and Testing

### Automated Validation

```bash
# Run complete validation suite
elixir scripts/containers/create_functional_dev_container.exs --verify
```

This checks:
- ✓ Container is running
- ✓ Elixir 1.19.2 is installed
- ✓ Mix is accessible
- ✓ Locale support is configured
- ✓ SSL certificates are available

### Manual Verification

```bash
# Elixir version and locale
podman exec indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && elixir --version"

# Expected output (no locale warnings):
# Elixir 1.19.2 (compiled with Erlang/OTP 27)

# Compilation test
podman exec indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && cd /workspace && mix compile"

# Expected: Successful compilation with warnings only (no errors)
```

## Related Documentation

- **Locale Fix Implementation**: `docs/journal/20251116-1503-locale-fix-implementation.md`
- **Container Policy**: `CONTAINER_POLICY.md`
- **Container Definition**: `containers/sopv51-dev-comprehensive.nix`
- **PHICS Documentation**: `docs/phics/README.md`
- **SOPv5.11 Framework**: `docs/sopv511/README.md`

## Support and Maintenance

### Regular Maintenance

```bash
# Update dependencies
podman exec indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && cd /workspace && mix deps.update --all"

# Clean build artifacts
podman exec indrajaal-dev bash -c "source /etc/profile.d/indrajaal.sh && cd /workspace && mix clean"

# Rebuild container (when NixOS packages update)
cd containers && nix-build sopv51-dev-comprehensive.nix
podman load < /nix/store/*-docker-image-indrajaal-dev.tar.gz
```

### Container Updates

When updating the container definition (`sopv51-dev-comprehensive.nix`):

1. Make changes to the `.nix` file
2. Rebuild: `cd containers && nix-build sopv51-dev-comprehensive.nix`
3. Load new image: `podman load < /nix/store/*-docker-image-indrajaal-dev.tar.gz`
4. Restart container: `./scripts/containers/start-dev-container.sh`
5. Verify: `elixir scripts/containers/create_functional_dev_container.exs --verify`

## Best Practices

### ✅ DO

- Always source `/etc/profile.d/indrajaal.sh` before running commands
- Start container from project root directory
- Use the provided scripts (`start-dev-container.sh`, `create_functional_dev_container.exs`)
- Check that external services (PostgreSQL, Redis) are running before starting container
- Verify locale, SSL, and Elixir version after major updates

### ❌ DON'T

- Run Elixir commands without sourcing the environment file
- Modify the container while it's running (changes won't persist)
- Use `su` instead of `setpriv` for user switching
- Start container from subdirectories (must be project root)
- Ignore locale warnings from Elixir (indicates environment not sourced)

## Success Criteria

A properly functioning container should:

✅ Show Elixir 1.19.2 when checking version
✅ Compile the project without Elixir version errors
✅ Not show "VM is running with native name encoding of latin1" when environment is sourced
✅ Successfully connect to external PostgreSQL and Redis
✅ Support Phoenix hot-reloading
✅ Have working SSL certificates for HTTPS dependencies

## Conclusion

This functional NixOS development container provides a complete, reproducible development environment with all necessary fixes for Elixir 1.19, UTF-8 locales, SSL certificates, and PHICS hot-reloading. By following the patterns documented here, developers can work seamlessly within the container without encountering the historical issues that have been systematically resolved.

For questions or issues, refer to the troubleshooting section or consult the related documentation listed above.
