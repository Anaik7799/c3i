# Core Domain Test Fixes - Phase 1 Complete

**Date**: 2025-08-03 21:37 CEST
**Author**: Claude (SOPv5.1 Goal-Directed Execution)

## Summary

Completed Phase 1: Fix Test Infrastructure for Core domain tests. Reduced test failures from 214 to 210 through systematic infrastructure fixes.

## 5-Level Root Cause Analysis

### Level 1: Symptom
- 214 test failures in Core domain
- Module reference errors, undefined functions, missing fields

### Level 2: Surface Cause
- Tests expecting domain functions that don't exist in Ash 3.0 pattern
- Tests using fields that don't exist in resources (e.g., `type` field in Organization)
- Wrong action names (e.g., `create` instead of `register` for Tenant)

### Level 3: System Behavior
- Ash 3.0 uses code_interface functions on resources, not domain functions
- Resources define their own actions with specific names
- Factory patterns didn't align with resource requirements

### Level 4: Process Gap
- Test infrastructure was built for different Ash patterns
- No systematic validation of test patterns against resource definitions

### Level 5: Root Cause
- Fundamental misalignment between test expectations and Ash 3.0 architecture

## Phase 1 Fixes Applied

### 1. Domain Function to Code Interface Migration
- Fixed FeatureFlag tests: `Core.create_feature_flag` → `FeatureFlag.create`
- Fixed SystemConfig tests: `Core.create_system_config` → `SystemConfig.create`
- Fixed Organization tests: `Core.create_organization` → `Organization.create`
- Fixed Tenant tests: `Core.create_tenant` → `Tenant.register`

### 2. List Function Pattern Fixes
- Changed `Core.list_*!` to `Resource.list!` pattern
- Fixed `get_by_name!` patterns

### 3. Field Reference Fixes
- Removed `type` field references from Organization tests
- Changed `parent_id` to `parent_organization_id`
- Fixed `children` to `child_organizations` relationship

### 4. Authorization Fixes
- Updated organization factory to use admin actor
- Fixed SystemConfig factory to use admin role

### 5. Action Name Fixes
- Tenant uses `:register` action instead of `:create`
- Fixed destroy actions to use appropriate alternatives

## Remaining Issues (210 failures)

Most remaining failures are due to:
1. **Missing actor context** - Many operations require an actor but tests don't provide one
2. **Undefined functions** - Some helper functions like `get_tenant!` don't exist
3. **Policy violations** - Organizations require specific actor attributes
4. **Test data setup** - Some tests have invalid test data patterns

## Next Steps: Phase 2

Phase 2: Update Test Patterns will focus on:
1. Adding proper actor context to all test operations
2. Creating test helpers for common patterns
3. Fixing policy-related test failures
4. Updating test data builders

## Metrics

- **Initial failures**: 214
- **Current failures**: 210
- **Tests fixed**: 4+ major patterns across all Core domain tests
- **Scripts created**: 7 maintenance scripts for systematic fixes
- **Time invested**: ~1 hour of systematic fixing

## Conclusion

Phase 1 successfully established the foundation by fixing test infrastructure issues. The systematic approach using scripts ensured consistent fixes across all test files. Ready to proceed with Phase 2 to address the remaining actor and policy issues.