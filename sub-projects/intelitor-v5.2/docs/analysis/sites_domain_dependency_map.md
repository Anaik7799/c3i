# Sites Domain Dependency Map

**Analysis Date**: 2025-10-12 22:48:00 CEST
**Status**: Sites folder - 0 errors, 0 warnings ✅
**System-wide**: 212 warnings remaining

## 1. Sites Domain Core Structure

### 1.1 Core Resources (6 files)

```
lib/indrajaal/sites/
├── site.ex              (108 lines) - Root level, tenant-specific sites
├── building.ex          (256 lines) - Buildings within sites
├── floor.ex             (308 lines) - Floors within buildings
├── zone.ex              (358 lines) - Security zones (can span multiple areas)
├── area.ex              (422 lines) - Smallest physical units (rooms/spaces)
└── location.ex          (390 lines) - Generic location abstraction
```

**Total Lines**: 1,842 lines of Ash resource definitions

### 1.2 Location Hierarchy

```
Site (root)
├── Building
│   ├── Floor
│   │   ├── Zone
│   │   │   └── Area
│   │   └── Area (direct floor relationship)
│   └── Zone (direct building relationship)
└── Zone (direct site relationship)

Location (polymorphic reference to any level)
```

## 2. Direct Dependencies (What Sites Uses)

### 2.1 Core Framework Dependencies

**Used by ALL 6 files:**
- `Indrajaal.BaseResource` - Base resource configuration and domain setup
- `Indrajaal.Multitenancy.TenantResource` - Multi-tenancy support
- `Indrajaal.Core.Tenant` - Tenant relationship (belongs_to)

**Used by 2 files (floor.ex, area.ex):**
- `Indrajaal.Shared.ValidationUtilities` - Custom validation functions
  - `validate_occupancy_limits/2`
  - `validate_stairwell_emergency_exit/2`

### 2.2 Framework Features Used

**Ash Framework Features:**
- Attributes: uuid_primary_key, string, integer, atom, float, boolean, map, array
- Relationships: belongs_to, has_many (including self-referential)
- Actions: defaults, custom updates (set_status, update_occupancy, etc.)
- Calculations: expr() macro, custom calculation functions
- Validations: string_length, custom validation functions
- Policies: authorize_if, actor_attribute_equals
- Identities: unique constraints
- Code Interface: define functions for external usage
- PostgreSQL: custom indexes, conditional indexes

## 3. Reverse Dependencies (Who Uses Sites)

### 3.1 Direct Usage by Domain (13 files across 7 domains)

#### visitor_management Domain (3 files)
1. **visitor_access.ex**
   - `belongs_to :entry_location, Indrajaal.Sites.Location`
   - `belongs_to :exit_location, Indrajaal.Sites.Location`

2. **visit_request.ex**
   - `belongs_to :site, Indrajaal.Sites.Site`

3. **(1 more file using Location - to be confirmed)**

#### access_control Domain (1 file)
1. **anti_passback.ex**
   - `belongs_to :zone, Indrajaal.Sites.Zone`

#### maintenance Domain (4 files)
1. **schedule.ex**
   - `belongs_to :site, Indrajaal.Sites.Site`

2. **equipment.ex**
   - `belongs_to :site, Indrajaal.Sites.Site`
   - `belongs_to :building, Indrajaal.Sites.Building`
   - `belongs_to :floor, Indrajaal.Sites.Floor`

3. **(2 more files using sites modules - to be confirmed)**

#### analytics Domain (4 files)
1. **heat_map.ex**
   - `belongs_to :site, Indrajaal.Sites.Site`

2. **trend_analysis.ex**
   - `belongs_to :site, Indrajaal.Sites.Site`

3. **security_metric.ex**
   - `belongs_to :site, Indrajaal.Sites.Site`

4. **risk_score.ex**
   - `belongs_to :site, Indrajaal.Sites.Site`

#### video Domain (2 files)
1. **analytics.ex**
   - `belongs_to :zone, Indrajaal.Sites.Zone`

2. **camera.ex**
   - `belongs_to :site, Indrajaal.Sites.Site`
   - `belongs_to :zone, Indrajaal.Sites.Zone`

#### guard_tour Domain (1 file)
1. **checkpoint.ex**
   - `belongs_to :location, Indrajaal.Sites.Location`

#### asset_management Domain (1 file)
1. **asset_location.ex**
   - `belongs_to :site, Indrajaal.Sites.Site`

### 3.2 Usage Patterns Summary

**Most Used Resources:**
- `Site` - 9 references (visitor_management, maintenance, analytics x4, video, asset_management)
- `Location` - 3 references (visitor_management x2, guard_tour)
- `Zone` - 3 references (access_control, video x2)
- `Building` - 1 reference (maintenance)
- `Floor` - 1 reference (maintenance)
- `Area` - 0 direct references (used through Location)

**Domain Integration Patterns:**
1. **Site-level tracking**: analytics, maintenance, visitor management
2. **Zone-level security**: access_control, video surveillance
3. **Location abstraction**: visitor management, guard tours
4. **Multi-level hierarchy**: maintenance equipment tracking

## 4. Compilation Status

### 4.1 Sites Folder Status ✅
- **Errors**: 0
- **Warnings**: 0
- **Bugs Fixed**: 10 total
  - 1 syntax error (area.ex)
  - 4 wrong attribute names (floor.ex x2, zone.ex x2)
  - 5 unused variables (area.ex, building.ex, floor.ex x2, zone.ex x2)

### 4.2 System-wide Status ⚠️
- **Total Warnings**: 212
- **Related Files**: Need analysis

### 4.3 Warning Categories (Preliminary)
1. Unused functions (10+ occurrences)
2. Unused variables - `opts` parameters (100+ occurrences)
3. Clause grouping issues (2 occurrences)
4. Pattern-specific unused variables (multiple)

## 5. Next Steps

### 5.1 Immediate Actions
1. ✅ Complete dependency map (this document)
2. ⏳ Read all 13 identified related files
3. ⏳ Analyze warnings in related files
4. ⏳ Create systematic fix plan
5. ⏳ Execute fixes using SOPv5.11 AEE

### 5.2 Extended Actions
1. ⏳ Analyze warnings in shared utilities
2. ⏳ Fix all 212 system-wide warnings
3. ⏳ Apply GDE goal-oriented execution
4. ⏳ Validate zero-warning state

## 6. Impact Assessment

### 6.1 Critical Path Files
Files that are most critical to sites domain functionality:
1. **Site** - Root of hierarchy, referenced by 9 files
2. **Location** - Abstraction layer, referenced by 3 files
3. **Zone** - Security layer, referenced by 3 files
4. **Building/Floor** - Physical structure, referenced by maintenance

### 6.2 Risk Assessment
- Sites folder: ✅ LOW RISK (all bugs fixed)
- Related files: ⚠️ MEDIUM RISK (warnings need analysis)
- System-wide: ⚠️ MEDIUM RISK (212 warnings remaining)

## 7. Methodology

### 7.1 SOPv5.11 AEE (Autonomous Execution Engine)
- Systematic automated fixes
- Patient mode compilation
- Zero-tolerance for errors
- Comprehensive validation

### 7.2 GDE (Goal-Directed Execution)
- Goal: Zero warnings in sites domain and related files
- Strategy: Systematic analysis and fixing
- Validation: After each fix batch
- Documentation: Complete audit trail
