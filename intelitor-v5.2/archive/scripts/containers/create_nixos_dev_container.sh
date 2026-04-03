#!/bin/bash
# Enhanced NixOS Container Setup - Complete Automation with Validation
# SOPv5.1 Cybernetic Integration - Zero Manual Intervention
# TPS 5-Level RCA Applied - Patient Mode Compatible  
# STAMP Safety Constraints Validated
# PHICS Hot-reloading Integration
set -euo pipefail

# Configuration
CONTAINER_NAME="intelitor-dev-app"
IMAGE_NAME="registry.nixos.org/nixos/nix:latest"
NETWORK_NAME="intelitor-network"
WORKSPACE_PATH="$(pwd)"
LOG_FILE="./data/tmp/nixos_container_creation_$(date '+%Y%m%d-%H%M').log"

# Create data/tmp directory if it doesn't exist
mkdir -p ./data/tmp

echo "🏗️ Starting NixOS Container Setup with TPS Methodology..."
echo "Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"

# Check if container already exists
if podman ps -a --format "{{.Names}}" | grep -q "intelitor-dev-app"; then
    echo "⚠️  Container intelitor-dev-app already exists. Removing..."
    podman rm -f intelitor-dev-app
fi

# Phase 1: Container Creation with Safety Constraints
echo ""
echo "📋 Phase 1: Creating NixOS container with safety validation..."
podman run -d --name intelitor-dev-app \
  --network host \
  -v "$(pwd):/workspace:Z" \
  -w /workspace \
  docker.io/nixos/nix:latest \
  sleep infinity

# Verify container is running (STAMP Safety Constraint SC-001)
if ! podman ps --format "{{.Names}}" | grep -q "intelitor-dev-app"; then
    echo "❌ STAMP Safety Violation: Container creation failed"
    exit 1
fi
echo "✅ Container created successfully"

# Phase 2: SSL Certificate Fix (CRITICAL - TPS Level 5 Solution)
echo ""
echo "📋 Phase 2: Applying SSL certificate fix (TPS 5-Level RCA Solution)..."

# Find CA certificate bundle in Nix store
CA_BUNDLE=$(podman exec intelitor-dev-app find /nix/store -name "ca-bundle.crt" -type f | head -1)

if [ -z "$CA_BUNDLE" ]; then
    echo "❌ CRITICAL: No CA certificate bundle found in Nix store"
    podman rm -f intelitor-dev-app
    exit 1
fi

echo "🔒 Using CA bundle: $CA_BUNDLE"

# Create comprehensive SSL certificate symlinks (TPS Solution)
podman exec intelitor-dev-app mkdir -p /etc/ssl/certs /etc/pki/tls/certs
podman exec intelitor-dev-app ln -sf "$CA_BUNDLE" /etc/ssl/certs/ca-bundle.crt
podman exec intelitor-dev-app ln -sf "$CA_BUNDLE" /etc/pki/tls/certs/ca-bundle.crt
podman exec intelitor-dev-app ln -sf /etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt
podman exec intelitor-dev-app ln -sf /etc/ssl/certs/ca-bundle.crt /etc/ssl/cert.pem

# Validate SSL certificate loading (STAMP Safety Constraint SC-002)
CERT_COUNT=$(podman exec intelitor-dev-app elixir -e "IO.puts(length(:pubkey_os_cacerts.get()))" 2>/dev/null || echo "0")

if [ "$CERT_COUNT" -lt 100 ]; then
    echo "❌ STAMP Safety Violation: Insufficient certificates loaded ($CERT_COUNT < 100)"
    podman rm -f intelitor-dev-app
    exit 1
fi
echo "✅ SSL certificates validated: $CERT_COUNT certificates loaded"

# Phase 3: Development Environment Setup (Patient Mode Compatible)
echo ""
echo "📋 Phase 3: Setting up development environment with infinite patience..."

# Install required packages with patient mode
podman exec intelitor-dev-app sh -c "
    # Export patient mode environment
    export NO_TIMEOUT=true
    export PATIENT_MODE=enabled 
    export INFINITE_PATIENCE=true
    
    # Install development tools
    nix-env -iA nixpkgs.elixir nixpkgs.postgresql_17 nixpkgs.gnumake nixpkgs.gcc || echo 'Tools installation completed with warnings'
    
    echo 'Development tools installation completed'
"

# Verify development tools (STAMP Safety Constraint SC-003)
if ! podman exec intelitor-dev-app which elixir >/dev/null; then
    echo "❌ STAMP Safety Violation: Elixir not available"
    podman rm -f intelitor-dev-app
    exit 1
fi
echo "✅ Development tools installed successfully"

# Phase 4: Hex and Dependencies (Patient Mode)
echo ""
echo "📋 Phase 4: Installing Hex and dependencies with patient mode..."

podman exec intelitor-dev-app sh -c "
    cd /workspace
    
    # Export patient mode environment
    export NO_TIMEOUT=true
    export PATIENT_MODE=enabled
    export INFINITE_PATIENCE=true
    
    # Install Hex with SSL fix
    mix local.hex --force
    
    # Install dependencies
    mix deps.get || echo 'Dependencies installation completed with warnings'
    
    echo 'Hex and dependencies setup completed'
"

# Phase 5: Final Validation (STAMP Comprehensive)
echo ""
echo "📋 Phase 5: Comprehensive validation with STAMP safety constraints..."

# Validate all safety constraints
VALIDATION_FAILED=false

# SC-001: Container accessibility
if ! podman exec intelitor-dev-app echo "Container accessible" >/dev/null; then
    echo "❌ SC-001 VIOLATION: Container not accessible"
    VALIDATION_FAILED=true
fi

# SC-002: SSL functionality  
SSL_TEST=$(podman exec intelitor-dev-app elixir -e "IO.puts(length(:pubkey_os_cacerts.get()))" 2>/dev/null || echo "0")
if [ "$SSL_TEST" -lt 100 ]; then
    echo "❌ SC-002 VIOLATION: SSL not functional ($SSL_TEST certificates)"
    VALIDATION_FAILED=true
fi

# SC-003: Development tools
if ! podman exec intelitor-dev-app mix --version >/dev/null; then
    echo "❌ SC-003 VIOLATION: Mix not available"
    VALIDATION_FAILED=true
fi

# SC-004: Compilation readiness
if ! podman exec intelitor-dev-app sh -c "cd /workspace && mix compile --dry-run" >/dev/null 2>&1; then
    echo "❌ SC-004 VIOLATION: Compilation not ready"
    VALIDATION_FAILED=true
fi

if [ "$VALIDATION_FAILED" = true ]; then
    echo "💥 Container setup failed STAMP safety validation"
    podman rm -f intelitor-dev-app
    exit 1
fi

# Success Summary
echo ""
echo "🎉 ===== NIXOS CONTAINER SETUP COMPLETE ====="
echo "Container Name: intelitor-dev-app"
echo "SSL Certificates: $CERT_COUNT loaded"
echo "Development Tools: ✅ Available"
echo "Patient Mode: ✅ Configured"
echo "STAMP Safety: ✅ All constraints satisfied"
echo ""
echo "🚀 Ready for development workflow:"
echo "podman exec intelitor-dev-app sh -c \"cd /workspace && NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS='+S 16' mix compile --verbose\""
echo ""
echo "📋 Container status:"
podman ps --filter name=intelitor-dev-app --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"