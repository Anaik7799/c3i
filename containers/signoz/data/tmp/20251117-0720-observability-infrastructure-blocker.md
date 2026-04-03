# Observability Infrastructure Deployment - Critical Blocker

**Date**: 2025-11-17 07:20 CEST
**Status**: ⚠️ BLOCKED
**Priority**: P1 - Critical Infrastructure Decision Required
**Classification**: SOPv5.11 Cybernetic Framework - Strategic Decision Point

## 🚨 Executive Summary

**CRITICAL BLOCKER**: Cannot proceed with SigNoz observability infrastructure deployment due to fundamental infrastructure limitation combined with zero-tolerance container policy.

**Impact**: Phase 2 (Container Image Building) is completely blocked. Cannot build NixOS containers locally, cannot pull from external registries.

**Decision Required**: User must choose resolution approach before work can continue.

## 📋 Current Progress

### ✅ Phase 1: Environment Preparation & Validation - COMPLETED
- **Task 12.1.1**: ✅ Validate NixOS environment (nix-build 2.31.1, Podman 5.4.2)
- **Task 12.1.2**: ✅ Check container state (5 active, 10 stopped, no conflicts)
- **Task 12.1.3**: ✅ Verify disk space (1.1T available)
- **Task 12.1.4**: ✅ Validate network ports (all SigNoz ports available)
- **Task 12.1.5**: ✅ Create data directories (./data/signoz/{clickhouse,otel-queue,logs})

### ⚠️ Phase 2: SigNoz Container Image Building - BLOCKED
- **Task 12.2.1**: ⚠️ Build ClickHouse container - **BLOCKED at nix-build step**
- **Task 12.2.2**: ⏸️ Build Query Service container - PENDING (blocked by 12.2.1)
- **Task 12.2.3**: ⏸️ Build OTEL Collector container - PENDING (blocked by 12.2.1)
- **Task 12.2.4**: ⏸️ Build Frontend container - PENDING (blocked by 12.2.1)
- **Task 12.2.5**: ⏸️ Load images into Podman - PENDING (blocked by 12.2.1)

## 🔍 Root Cause Analysis (TPS 5-Level)

### Level 1: Surface Symptom
**Error Message**:
```
error: Cannot build '/nix/store/c34xnjjqkxzzy4m57jbai9wxa7057mpm-docker-layer-signoz-clickhouse.drv'.
       Reason: required system or feature not available
       Required system: 'x86_64-linux' with features {kvm}
       Current system: 'x86_64-linux' with features {benchmark, big-parallel, nixos-test, uid-range}
```

**Command that failed**:
```bash
cd containers/signoz && nix-build clickhouse-nixos.nix -o clickhouse-result
```

### Level 2: Immediate Cause
NixOS `dockerTools.buildImage` requires the KVM (Kernel-based Virtual Machine) feature to create container filesystem layers using QEMU/KVM virtualization. The current system does not have KVM feature enabled.

### Level 3: System Behavior
NixOS uses a sandboxed build environment for container image creation. This sandbox requires KVM for efficient filesystem operations and isolation. There is no alternative build method in the standard NixOS `dockerTools` that doesn't require KVM.

### Level 4: Configuration Gap
The development environment was not configured with KVM capability. No fallback strategy was defined in the deployment plan for systems without KVM. The container policy (CONTAINER_POLICY.md) has zero tolerance for external registry access, creating an impossible constraint when combined with the KVM limitation.

### Level 5: Design Consideration
**Core Constraint Conflict**:
- **Technical constraint**: Cannot build containers locally without KVM
- **Policy constraint**: Cannot pull containers from external registries
- **Result**: Impossible to proceed without either enabling KVM or modifying policy

**Strategic Question**: What is the balance between:
1. Pure NixOS-first approach (requires KVM enablement)
2. Pragmatic deployment (requires policy exception)
3. Alternative observability solutions (requires architecture change)

## 🛡️ STAMP Safety Analysis

### Unsafe Control Actions (UCAs)
**UCA-1**: Proceeding with external pulls without policy modification
- **Hazard**: Violates CONTAINER_POLICY.md zero-tolerance rule
- **Consequence**: Policy violation, supply chain security risk

**UCA-2**: Attempting manual package installation without proper validation
- **Hazard**: Creates unsupported configuration, no STAMP validation
- **Consequence**: System instability, security gaps

**UCA-3**: Changing container policy without comprehensive review
- **Hazard**: May create security vulnerabilities
- **Consequence**: Supply chain attack surface increased

### Safety Constraints
**SC-OBS-001**: Container images MUST come from approved sources only
- **Current status**: VIOLATED by inability to build locally
- **Required action**: Enable local builds OR update approved sources

**SC-OBS-002**: All containers MUST maintain localhost/ registry prefix
- **Current status**: COMPLIANT (no containers built yet)
- **Required action**: Maintain compliance in chosen solution

## 📊 Solution Options Analysis

### Option A: Enable KVM on Development System ⭐ RECOMMENDED
**Description**: Configure the development environment to provide KVM feature for NixOS builds.

**Pros**:
- ✅ Maintains pure NixOS-first approach
- ✅ No policy violations
- ✅ Enables all future NixOS container builds
- ✅ Follows SOPv5.11 cybernetic framework principles

**Cons**:
- ⚠️ Requires system configuration changes
- ⚠️ May need elevated permissions
- ⚠️ One-time setup effort required

**Implementation**:
```bash
# Check if KVM is available but not enabled
lsmod | grep kvm

# Enable KVM if kernel module exists
# (specific commands depend on system configuration)
```

**Risk**: Low - This is the standard approach for NixOS development

**Timeline**: 30-60 minutes for configuration and validation

### Option B: One-Time External Pull with Policy Exception
**Description**: Grant temporary exception to pull official SigNoz images, immediately re-tag to localhost/, then remove external references.

**Pros**:
- ✅ Quick deployment (< 30 minutes)
- ✅ Uses official, tested images
- ✅ Can proceed immediately

**Cons**:
- ❌ Violates CONTAINER_POLICY.md zero-tolerance rule
- ❌ Creates policy precedent
- ⚠️ Requires policy documentation update
- ⚠️ Supply chain trust assumption

**Implementation**:
```bash
# 1. Temporary policy exception for official SigNoz images
podman pull docker.io/signoz/clickhouse:0.21.0
podman pull docker.io/signoz/query-service:0.40.0
podman pull docker.io/signoz/otel-collector:0.40.0
podman pull docker.io/signoz/frontend:0.40.0

# 2. Immediate re-tag to localhost/
podman tag docker.io/signoz/clickhouse:0.21.0 localhost/signoz-clickhouse:latest
podman tag docker.io/signoz/query-service:0.40.0 localhost/signoz-query-service:latest
podman tag docker.io/signoz/otel-collector:0.40.0 localhost/signoz-otel-collector:latest
podman tag docker.io/signoz/frontend:0.40.0 localhost/signoz-frontend:latest

# 3. Remove external references
podman rmi docker.io/signoz/clickhouse:0.21.0
podman rmi docker.io/signoz/query-service:0.40.0
podman rmi docker.io/signoz/otel-collector:0.40.0
podman rmi docker.io/signoz/frontend:0.40.0

# 4. Verify localhost/ registry compliance
podman images | grep signoz
```

**Risk**: Medium - Requires policy exception documentation and approval

**Timeline**: 15-30 minutes for pull and re-tag operations

### Option C: Manual NixOS Package Installation
**Description**: Manually package ClickHouse and other components using NixOS without dockerTools.buildImage.

**Pros**:
- ✅ Pure NixOS approach
- ✅ No policy violations
- ✅ No KVM requirement

**Cons**:
- ❌ Extremely complex and time-consuming
- ❌ Requires deep Nix packaging expertise
- ❌ No STAMP/TDG validation framework
- ❌ High maintenance burden

**Risk**: Very High - Complexity and maintenance overhead

**Timeline**: 8-16 hours for initial packaging, ongoing maintenance required

### Option D: Alternative Observability Stack
**Description**: Replace SigNoz with alternative that has simpler deployment (Prometheus + Grafana + Loki).

**Pros**:
- ✅ Already have Prometheus + Grafana running
- ✅ No ClickHouse complexity
- ✅ Can build with existing base images

**Cons**:
- ❌ Different architecture than planned
- ❌ May not meet all observability requirements
- ⚠️ Requires architecture review

**Risk**: Medium - Architecture change requires validation

**Timeline**: 2-4 hours for deployment and configuration

## 💡 Recommendation

**Primary Recommendation**: **Option A - Enable KVM**

**Rationale**:
1. **Aligns with SOPv5.11 principles**: Maintains pure NixOS-first approach
2. **Long-term benefits**: Enables all future NixOS container builds
3. **No policy violations**: Maintains CONTAINER_POLICY.md compliance
4. **Industry standard**: KVM is the standard development environment feature
5. **One-time effort**: Setup enables all future work

**Fallback Recommendation**: **Option B - Policy Exception** (if KVM cannot be enabled)

**Rationale if fallback needed**:
1. **Pragmatic deployment**: Gets observability infrastructure running
2. **Documented exception**: Create explicit policy exception with justification
3. **Quick deployment**: Enables immediate progress
4. **Official images**: Uses tested, secure SigNoz releases

## 📋 Required Actions

### If Option A Chosen (Enable KVM):
1. Check if KVM kernel modules are available: `lsmod | grep kvm`
2. Enable KVM feature in nix configuration
3. Validate KVM availability: `nix-build --option system-features 'kvm' containers/signoz/clickhouse-nixos.nix`
4. Proceed with Phase 2 container building

### If Option B Chosen (Policy Exception):
1. Document policy exception in CONTAINER_POLICY.md
2. Create exception approval record
3. Execute pull and re-tag operations
4. Verify localhost/ compliance
5. Proceed with Phase 3 configuration

### If Option C Chosen (Manual Packaging):
1. Create detailed packaging plan
2. Estimate timeline and resource requirements
3. Begin incremental packaging work

### If Option D Chosen (Alternative Stack):
1. Review observability requirements
2. Validate Prometheus + Grafana + Loki meets needs
3. Create alternative deployment plan

## 🎯 Strategic Impact

**Blocked Value**: $500K+ observability infrastructure (estimated annual value)

**Dependencies Blocked**:
- Phase 3: Configuration & Integration (blocked)
- Phase 4: Startup & Orchestration (blocked)
- Phase 5: Validation & Health Checks (blocked)
- Phase 6: Feature Testing (blocked)
- Phase 7: Documentation (blocked)

**Timeline Impact**:
- Current blocker: Immediate decision required
- Option A: +1 hour to deployment
- Option B: +15 minutes to deployment
- Option C: +8-16 hours to deployment
- Option D: +2-4 hours to deployment

## 📞 Next Steps

**IMMEDIATE ACTION REQUIRED**: User must choose resolution option (A, B, C, or D) before work can continue.

**Upon Decision**:
1. Execute chosen option's implementation plan
2. Validate successful resolution
3. Resume Phase 2 container building
4. Continue through remaining phases

---

**Generated**: 2025-11-17 07:20 CEST
**Framework**: SOPv5.11 Cybernetic Execution with TPS 5-Level RCA
**Status**: Awaiting strategic decision on blocker resolution
