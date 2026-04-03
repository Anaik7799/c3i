# KVM Constraint Analysis - Policy Exception Required

**Date**: 2025-11-17 07:35 CEST
**Status**: ⚠️ CRITICAL DECISION POINT
**Classification**: Infrastructure Limitation Requires Policy Exception

## 🔍 Technical Analysis

### Environment Constraints Discovered
1. **Virtualization Layer**: Running inside KVM virtual machine
   ```bash
   $ systemd-detect-virt
   kvm
   ```

2. **No Nested Virtualization**: /dev/kvm not available
   ```bash
   $ ls -la /dev/kvm
   ls: cannot access '/dev/kvm': No such file or directory
   ```

3. **Base Image Reality**: `localhost/indrajaal-sopv51-base` is standard Linux, not NixOS
   - Does not have nix-env or NixOS package management
   - Cannot build NixOS packages within container

### Why Option A (Enable KVM) Is Not Feasible

**Nested Virtualization Required**: To enable KVM inside a KVM VM requires:
1. Host system configuration changes (outside project scope)
2. Significant performance overhead
3. Not standard development environment practice

**Conclusion**: Option A cannot be implemented in current environment.

## 💡 Recommended Solution: Documented Policy Exception

### Proposal: One-Time Controlled Pull with Security Documentation

**Approach**: Grant explicit, documented exception for official SigNoz images with:
1. Security verification process
2. Immediate localhost re-tagging
3. External reference removal
4. Complete audit trail

### Implementation Plan

#### Step 1: Document Policy Exception
Create `CONTAINER_POLICY_EXCEPTIONS.md` with:
- Exception ID: EXC-001
- Component: SigNoz Observability Stack
- Justification: Infrastructure constraint (KVM unavailable in VM)
- Images: Official SigNoz releases (docker.io/signoz/*)
- Security: Official project images, signed releases
- Mitigation: Immediate re-tag to localhost/, remove external references
- Approval: Required before execution
- Review Date: Annual security review

#### Step 2: Controlled Pull Process
```bash
# 1. Pull official SigNoz images (version pinned)
podman pull docker.io/signoz/clickhouse:0.21.0
podman pull docker.io/signoz/query-service:0.40.0
podman pull docker.io/signoz/otel-collector:0.40.0
podman pull docker.io/signoz/frontend:0.40.0

# 2. Immediate re-tag to localhost/ (CONTAINER_POLICY.md compliance)
podman tag docker.io/signoz/clickhouse:0.21.0 localhost/signoz-clickhouse:latest
podman tag docker.io/signoz/query-service:0.40.0 localhost/signoz-query-service:latest
podman tag docker.io/signoz/otel-collector:0.40.0 localhost/signoz-otel-collector:latest
podman tag docker.io/signoz/frontend:0.40.0 localhost/signoz-frontend:latest

# 3. Remove external references (security)
podman rmi docker.io/signoz/clickhouse:0.21.0
podman rmi docker.io/signoz/query-service:0.40.0
podman rmi docker.io/signoz/otel-collector:0.40.0
podman rmi docker.io/signoz/frontend:0.40.0

# 4. Verify localhost/ compliance
podman images | grep signoz
# Expected: Only localhost/signoz-* images remain
```

#### Step 3: Create Exception Documentation

**File**: `docs/security/CONTAINER_POLICY_EXCEPTIONS.md`

**Content**:
```markdown
# Container Policy Exceptions

## EXC-001: SigNoz Observability Stack

**Date**: 2025-11-17
**Status**: APPROVED
**Component**: SigNoz (ClickHouse, Query Service, OTEL Collector, Frontend)

### Justification
- **Technical Constraint**: Development environment runs in KVM VM
- **KVM Limitation**: Nested virtualization not available
- **NixOS Builds**: Require KVM for dockerTools.buildImage
- **Infrastructure**: Cannot enable KVM without host system changes

### Security Analysis
**Source**: Official SigNoz project (https://github.com/SigNoz/signoz)
- Maintained by SigNoz, Inc.
- Published to docker.io/signoz/*
- Regular security updates
- Open-source project with active community

**Version Pinning**: All images use specific version tags (not :latest)
- clickhouse:0.21.0
- query-service:0.40.0
- otel-collector:0.40.0
- frontend:0.40.0

### Mitigation Measures
1. **Immediate Re-tagging**: All images re-tagged to localhost/* immediately
2. **External Reference Removal**: Original docker.io references deleted
3. **Version Pinning**: No floating :latest tags
4. **Audit Trail**: Complete pull/tag/remove sequence logged
5. **Annual Review**: Security review scheduled annually

### Compliance
**CONTAINER_POLICY.md Alignment**:
- ✅ Final state: 100% localhost/* registry compliance
- ✅ No external registries in `podman images` output
- ✅ All containers use localhost/* references
- ⚠️ Temporary exception during initial pull only

**Exception Scope**: Limited to initial deployment only
**Future Updates**: Evaluate alternative build methods for updates

### Approval
**Approved By**: [User Approval Required]
**Date**: 2025-11-17
**Review Date**: 2026-11-17
```

### Alternative: Wait for Different Environment

If policy exception is not acceptable, alternative is to:
1. Wait for bare metal or KVM-enabled development environment
2. Defer SigNoz deployment until infrastructure supports it
3. Use alternative observability (Prometheus + Grafana + Loki)

## 📊 Risk Assessment

### Policy Exception Approach
**Security Risk**: LOW
- Official project images
- Version pinned (not :latest)
- Immediate localhost re-tagging
- External references removed
- Complete audit trail

**Policy Risk**: MEDIUM
- Creates precedent for exceptions
- Requires comprehensive documentation
- Needs clear exception criteria

**Implementation Risk**: LOW
- Well-defined process
- Reversible (can remove containers)
- Standard Podman operations

### Alternative Approaches
**Wait for Different Environment**:
- Timeline: Unknown
- Blocks observability deployment indefinitely
- May never materialize

**Alternative Stack (Prometheus + Grafana + Loki)**:
- Architecture change required
- Different feature set
- May not meet all requirements

## 💡 Recommendation

**Proceed with documented policy exception** for pragmatic deployment while maintaining security:

1. Document exception in `CONTAINER_POLICY_EXCEPTIONS.md`
2. Execute controlled pull/tag/remove process
3. Achieve localhost/ compliance
4. Annual security review scheduled
5. Future: Explore Buildah/alternative builds that work in VMs

This balances:
- ✅ Security (official images, version pinned, audit trail)
- ✅ Policy compliance (final state is localhost/ only)
- ✅ Pragmatism (deployment can proceed)
- ✅ Documentation (comprehensive exception record)

**User approval required to proceed.**
