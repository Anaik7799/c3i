# 🌐 Web Pages Reverification & Restoration Plan

**Date**: December 21, 2025
**Status**: IN PROGRESS
**Objective**: Ensure 100% of web pages (LiveViews and Controllers) are routable, functional, and verified.

## 🚨 Critical Gap Analysis
A scan of `lib/indrajaal_web/live/` vs `lib/indrajaal_web/router.ex` revealed **4 orphaned LiveViews** that are defined but not accessible via any URL.

| LiveView Module | Status | Proposed Route |
|-----------------|--------|----------------|
| `ConfigManagementLive` | ❌ ORPHANED | `/admin/config` |
| `MonitoringDashboardLive` | ❌ ORPHANED | `/monitoring` |
| `StampTdgGdeDashboardLive` | ❌ ORPHANED | `/analytics/dashboard` |
| `SystemStatusLive` | ❌ ORPHANED | `/admin/system-status` |
| `AccessControlMonitoringLive` | ✅ Mapped | `/admin/access_control` |
| `PerformanceDashboardLive` | ✅ Mapped | `/performance` |
| `PermissionsManagementLive` | ✅ Mapped | `/admin/permissions` |
| `StampTdgGdeAdvancedAnalyticsLive` | ✅ Mapped | `/analytics/stamp-tdg-gde-advanced` |

## 🗺️ 5-Level Execution Plan

### Level 1: Infrastructure & Inventory (Completed)
- [x] Identify all LiveView files.
- [x] Cross-reference with Router.
- [x] Identify orphans.

### Level 2: Router Restoration (Immediate Action)
- [ ] **Task**: Edit `lib/indrajaal_web/router.ex` to expose the 4 orphaned LiveViews.
- [ ] **Constraint**: Use proper scopes (`/admin` vs `/analytics`).
- [ ] **Verification**: `mix phx.routes` to confirm availability.

### Level 3: Compilation & Smoke Testing
- [ ] **Task**: Run `mix compile --warnings-as-errors` to ensure the new routes don't break compilation.
- [ ] **Task**: Execute `scripts/testing/simple_web_check.exs` (updated to include new routes).
- [ ] **Success Criteria**: All 8 LiveViews return 200 OK.

### Level 4: Functional Verification
- [ ] **Task**: Check for runtime crashes on mount.
- [ ] **Task**: Verify basic rendering of the LiveViews (checking for specific HTML elements).

### Level 5: Documentation & Finalization
- [ ] **Task**: Update `WEB_PAGES_FINAL_VERIFICATION.md` with the new comprehensive status.
- [ ] **Task**: Mark C0.1.2.3 as fully complete in `PROJECT_TODOLIST.md`.

## 🛠️ Execution Instructions

1. **Modify Router**: Add the missing `live` definitions.
2. **Update Test Script**: Add the new paths to `scripts/testing/simple_web_check.exs`.
3. **Run Validation**: Execute the script and fix any crashes.
