# Dark/Light Theme - 10 Agent + 1 Supervisor Architecture
## 5-Level RCA with GDE Goal-Directed Execution

**Date**: 2025-12-29T01:00:00+01:00
**Goal**: 100% Dark/Light Theme Feature Development and Testing
**Framework**: SOPv5.11 + STAMP + TDG + GDE + 5-Level RCA

---

## AGENT ARCHITECTURE (10 Agents + 1 Supervisor)

```
                    ┌─────────────────────────────────────────────────────────────┐
                    │           L5-SUPERVISOR: Theme Implementation Executive     │
                    │  THINKING: Orchestrating 10 agents for 100% theme support   │
                    │  DOING: Coordinating parallel development and testing       │
                    └───────────────────────────┬─────────────────────────────────┘
                                                │
    ┌───────────────────────────────────────────┼───────────────────────────────────────────┐
    │                                           │                                           │
┌───▼────┐ ┌───▼────┐ ┌───▼────┐ ┌───▼────┐ ┌───▼────┐ ┌───▼────┐ ┌───▼────┐ ┌───▼────┐ ┌───▼────┐ ┌───▼────┐
│L4-A01  │ │L4-A02  │ │L4-A03  │ │L4-A04  │ │L4-A05  │ │L4-A06  │ │L4-A07  │ │L4-A08  │ │L4-A09  │ │L4-A10  │
│Tailwind│ │CSS Vars│ │JS Hook │ │Backend │ │Layout  │ │Settings│ │Prajna  │ │Core    │ │LiveView│ │Testing │
│Config  │ │System  │ │Theme   │ │Persist │ │Updates │ │UI Wire │ │Comps   │ │Comps   │ │Pages   │ │& QA    │
└────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘
```

---

## 5-LEVEL HIERARCHICAL TASK STRUCTURE

### L1.0.0.0.0 - Theme Implementation Master Goal [L5-SUPERVISOR]
**Status**: in_progress | **Priority**: P0 | **Agent**: L5-SUPERVISOR
**THINKING**: Coordinating 10 agents to achieve 100% dark/light theme support
**DOING**: Dispatching agents, monitoring progress, validating completeness

---

### L2.1.0.0.0 - Infrastructure Layer [L4-A01, L4-A02, L4-A03]

#### L3.1.1.0.0 - Tailwind Configuration [L4-A01]
**Status**: pending | **Priority**: P0-CRITICAL | **Agent**: L4-A01
**THINKING**: Enabling class-based dark mode in Tailwind
**DOING**: Adding darkMode: 'class', semantic color tokens

##### L4.1.1.1.0 - Enable darkMode: 'class'
- File: `assets/tailwind.config.js`
- Add: `darkMode: 'class'` at module level

##### L4.1.1.2.0 - Add semantic color tokens
- surface: primary, secondary, tertiary, elevated
- content: primary, secondary, muted, inverse
- border-theme: primary, secondary, focus
- status: healthy, advisory, caution, warning, critical

##### L4.1.1.3.0 - Add cockpit color palette
- cockpit.900 (#111827) to cockpit.100 (#f3f4f6)

##### L4.1.1.4.0 - Add high-contrast variant plugin
- Plugin for `.high-contrast` class variant

---

#### L3.1.2.0.0 - CSS Variables System [L4-A02]
**Status**: pending | **Priority**: P0-CRITICAL | **Agent**: L4-A02
**THINKING**: Creating theme-aware CSS variable system
**DOING**: Defining :root, .dark, .high-contrast variables

##### L4.1.2.1.0 - Light Theme Variables (:root)
```css
--surface-primary: #ffffff
--surface-secondary: #f9fafb
--content-primary: #18181b
--border-primary: #e5e7eb
```

##### L4.1.2.2.0 - Dark Theme Variables (.dark)
```css
--surface-primary: #111827
--surface-secondary: #1f2937
--content-primary: #f3f4f6
--border-primary: #374151
```

##### L4.1.2.3.0 - High Contrast Variables (.high-contrast)
```css
--surface-primary: #000000
--content-primary: #ffffff
--status-critical: #ff0000
```

##### L4.1.2.4.0 - Smooth transition styling
- `transition: background-color 0.15s, color 0.15s`
- `.theme-switching *` - disable transitions during switch

---

#### L3.1.3.0.0 - JavaScript Theme Hook [L4-A03]
**Status**: pending | **Priority**: P0-CRITICAL | **Agent**: L4-A03
**THINKING**: Creating real-time theme switching without page reload
**DOING**: Building ThemeHook with localStorage + LiveView integration

##### L4.1.3.1.0 - Create theme_hook.js
- File: `assets/js/hooks/theme_hook.js`
- Handle set_theme and toggle_theme events
- System preference detection (prefers-color-scheme)
- LocalStorage persistence

##### L4.1.3.2.0 - FOUC Prevention Script
- Inline script for immediate theme application
- Prevent flash of unstyled content

##### L4.1.3.3.0 - Register hook in app.js
- Import ThemeHook
- Add to Hooks object

---

### L2.2.0.0.0 - Backend Persistence Layer [L4-A04]

#### L3.2.1.0.0 - Theme Context Module [L4-A04]
**Status**: pending | **Priority**: P1-HIGH | **Agent**: L4-A04

##### L4.2.1.1.0 - Create ThemeContext module
- File: `lib/indrajaal_web/contexts/theme_context.ex`
- get_theme/2, get_user_theme/1, valid_theme?/1

##### L4.2.1.2.0 - Update User resource
- File: `lib/indrajaal/accounts/user.ex`
- Add update_theme action
- Store in preferences map

##### L4.2.1.3.0 - Create ThemePlug
- File: `lib/indrajaal_web/plugs/theme_plug.ex`
- Inject theme into connection assigns

##### L4.2.1.4.0 - Create LiveView ThemeHook
- File: `lib/indrajaal_web/live/hooks/theme_hook.ex`
- on_mount for theme attachment
- handle_event for theme changes

##### L4.2.1.5.0 - Update Router
- Add ThemePlug to browser pipeline
- Add on_mount to live_session

---

### L2.3.0.0.0 - Layout Layer [L4-A05]

#### L3.3.1.0.0 - Root Layout Update [L4-A05]
**Status**: pending | **Priority**: P1-HIGH | **Agent**: L4-A05

##### L4.3.1.1.0 - Add theme class to html element
##### L4.3.1.2.0 - Add FOUC prevention inline script
##### L4.3.1.3.0 - Add ThemeHook to body
##### L4.3.1.4.0 - Add color-scheme meta tag

#### L3.3.2.0.0 - App Layout Update [L4-A05]
##### L4.3.2.1.0 - Add dark: variants to header
##### L4.3.2.2.0 - Add dark: variants to navigation

---

### L2.4.0.0.0 - Settings UI Layer [L4-A06]

#### L3.4.1.0.0 - Wire Theme Selector [L4-A06]
**Status**: pending | **Priority**: P1-HIGH | **Agent**: L4-A06

##### L4.4.1.1.0 - Update handle_event for theme changes
##### L4.4.1.2.0 - Push theme to client on selection
##### L4.4.1.3.0 - Persist theme on save
##### L4.4.1.4.0 - Add theme preview functionality

---

### L2.5.0.0.0 - Component Layer [L4-A07, L4-A08]

#### L3.5.1.0.0 - Prajna Components [L4-A07]
**Status**: pending | **Priority**: P2-MEDIUM | **Agent**: L4-A07
**THINKING**: Refactoring 16 components for theme support
**DOING**: Adding dark: variants to all Prajna components

##### L4.5.1.1.0 - Status components (4)
- status_indicator, status_icon, trend_indicator, gauge

##### L4.5.1.2.0 - Display components (4)
- sparkline, metric_card, prajna_header, prajna_nav

##### L4.5.1.3.0 - Card components (4)
- alarm_card, node_card, container_card, insight_card

##### L4.5.1.4.0 - Modal/Status components (4)
- two_step_modal, ooda_status, safety_status, fractal_log

#### L3.5.2.0.0 - Core Components [L4-A08]
**Status**: pending | **Priority**: P2-MEDIUM | **Agent**: L4-A08

##### L4.5.2.1.0 - Flash components
##### L4.5.2.2.0 - Modal components
##### L4.5.2.3.0 - Form components
##### L4.5.2.4.0 - Table components

---

### L2.6.0.0.0 - LiveView Pages Layer [L4-A09]

#### L3.6.1.0.0 - Prajna Cockpit Pages (11 files) [L4-A09]
**Status**: pending | **Priority**: P2-MEDIUM | **Agent**: L4-A09

##### L4.6.1.1.0 - Core cockpit pages
- prajna_live.ex, mesh_live.ex, cluster_live.ex

##### L4.6.1.2.0 - Operations pages
- alarms_live.ex, commands_live.ex, containers_live.ex

##### L4.6.1.3.0 - Monitoring pages
- observability_live.ex, diagnostics_live.ex

##### L4.6.1.4.0 - Control pages
- startup_live.ex, shutdown_live.ex, copilot_live.ex

#### L3.6.2.0.0 - Main Dashboard Pages (9 files) [L4-A09]
##### L4.6.2.1.0 - monitoring_dashboard_live.ex
##### L4.6.2.2.0 - performance_dashboard_live.ex
##### L4.6.2.3.0 - access_control_monitoring_live.ex
##### L4.6.2.4.0 - Other dashboard pages (6)

#### L3.6.3.0.0 - Operations Pages (5 files) [L4-A09]
##### L4.6.3.1.0 - access_dashboard_live.ex
##### L4.6.3.2.0 - active_alarms_live.ex
##### L4.6.3.3.0 - alarm_investigation_live.ex
##### L4.6.3.4.0 - dispatch_console_live.ex, video_wall_live.ex

---

### L2.7.0.0.0 - Testing & QA Layer [L4-A10]

#### L3.7.1.0.0 - Unit Tests [L4-A10]
**Status**: pending | **Priority**: P1-HIGH | **Agent**: L4-A10

##### L4.7.1.1.0 - ThemeContext tests
##### L4.7.1.2.0 - ThemePlug tests
##### L4.7.1.3.0 - LiveView hook tests

#### L3.7.2.0.0 - Contrast Ratio Tests (SC-HMI-008) [L4-A10]
##### L4.7.2.1.0 - Light theme contrast verification
##### L4.7.2.2.0 - Dark theme contrast verification
##### L4.7.2.3.0 - High contrast verification

#### L3.7.3.0.0 - Integration Tests [L4-A10]
##### L4.7.3.1.0 - Theme switching test
##### L4.7.3.2.0 - Theme persistence test
##### L4.7.3.3.0 - Cross-page theme consistency

#### L3.7.4.0.0 - Property-Based Tests [L4-A10]
##### L4.7.4.1.0 - PropCheck theme roundtrip
##### L4.7.4.2.0 - ExUnitProperties theme validation

---

## 5-LEVEL RCA FRAMEWORK

### Level 1: SYMPTOM
- **What**: UI lacks dark/light theme toggle
- **Where**: All 25+ LiveView pages
- **Impact**: Poor UX, accessibility issues, SC-HMI non-compliance

### Level 2: DIRECT CAUSE
- **Tailwind**: darkMode not enabled
- **CSS**: No theme variables defined
- **JavaScript**: No theme switching mechanism
- **Backend**: No theme persistence

### Level 3: ROOT CAUSE
- **Historical**: System built with hardcoded dark styling for Prajna
- **Architecture**: No theming abstraction layer
- **Design**: Light/dark separation not planned

### Level 4: SYSTEMIC CAUSE
- **Missing Pattern**: No component theming standard
- **No Variables**: Hardcoded colors in templates
- **No Persistence**: User preferences not leveraged

### Level 5: PREVENTION (Implementation)
- **Tailwind Dark Mode**: `darkMode: 'class'`
- **CSS Variables**: Theme-aware semantic tokens
- **Component Pattern**: `dark:` variants on all components
- **Persistence**: User.preferences.theme storage
- **Testing**: SC-HMI-008 contrast ratio validation

---

## CRITICALITY-BASED EXECUTION PLAN

### P0-CRITICAL (Block Everything Else)
| Todo ID | Task | Agent | Status |
|---------|------|-------|--------|
| 1.1.0.0.0 | Tailwind darkMode config | L4-A01 | pending |
| 1.2.0.0.0 | CSS Variables system | L4-A02 | pending |
| 1.3.0.0.0 | JavaScript ThemeHook | L4-A03 | pending |

### P1-HIGH (Core Functionality)
| Todo ID | Task | Agent | Status |
|---------|------|-------|--------|
| 2.1.0.0.0 | ThemeContext module | L4-A04 | pending |
| 2.2.0.0.0 | User resource update | L4-A04 | pending |
| 2.3.0.0.0 | ThemePlug | L4-A04 | pending |
| 2.4.0.0.0 | LiveView hook | L4-A04 | pending |
| 3.1.0.0.0 | Root layout update | L4-A05 | pending |
| 4.1.0.0.0 | Settings UI wiring | L4-A06 | pending |
| 7.1.0.0.0 | Unit tests | L4-A10 | pending |

### P2-MEDIUM (Component Updates)
| Todo ID | Task | Agent | Status |
|---------|------|-------|--------|
| 5.1.0.0.0 | Prajna components (16) | L4-A07 | pending |
| 5.2.0.0.0 | Core components | L4-A08 | pending |
| 6.1.0.0.0 | Prajna LiveViews (11) | L4-A09 | pending |
| 6.2.0.0.0 | Main LiveViews (9) | L4-A09 | pending |
| 6.3.0.0.0 | Operations LiveViews (5) | L4-A09 | pending |

### P3-LOW (Testing & Polish)
| Todo ID | Task | Agent | Status |
|---------|------|-------|--------|
| 7.2.0.0.0 | Contrast ratio tests | L4-A10 | pending |
| 7.3.0.0.0 | Integration tests | L4-A10 | pending |
| 7.4.0.0.0 | Property-based tests | L4-A10 | pending |

---

## GDE METRICS

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Tailwind Config | 1 file | 0 | pending |
| CSS Variables | 3 themes | 0 | pending |
| JS Hooks | 1 hook | 0 | pending |
| Backend Modules | 4 modules | 0 | pending |
| Components Updated | 20+ | 0 | pending |
| LiveViews Updated | 25+ | 0 | pending |
| Tests Created | 10+ | 0 | pending |
| Feature Complete | 100% | 0% | in_progress |

---

## SMART DASHBOARD STATUS

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DARK/LIGHT THEME - SMART DASHBOARD                       │
├─────────────────────────────────────────────────────────────────────────────┤
│  Overall Progress: ░░░░░░░░░░░░░░░░░░░░ 0%                                 │
│                                                                             │
│  ┌─ P0-CRITICAL ────────────────────────────────────────────────────────┐  │
│  │  Tailwind Config:     ░░░░░░░░░░ 0%  [L4-A01 PENDING]               │  │
│  │  CSS Variables:       ░░░░░░░░░░ 0%  [L4-A02 PENDING]               │  │
│  │  JS Theme Hook:       ░░░░░░░░░░ 0%  [L4-A03 PENDING]               │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌─ P1-HIGH ────────────────────────────────────────────────────────────┐  │
│  │  Backend Persist:     ░░░░░░░░░░ 0%  [L4-A04 PENDING]               │  │
│  │  Layout Updates:      ░░░░░░░░░░ 0%  [L4-A05 PENDING]               │  │
│  │  Settings UI:         ░░░░░░░░░░ 0%  [L4-A06 PENDING]               │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌─ P2-MEDIUM ──────────────────────────────────────────────────────────┐  │
│  │  Prajna Comps (16):   ░░░░░░░░░░ 0%  [L4-A07 PENDING]               │  │
│  │  Core Comps:          ░░░░░░░░░░ 0%  [L4-A08 PENDING]               │  │
│  │  LiveViews (25):      ░░░░░░░░░░ 0%  [L4-A09 PENDING]               │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌─ P3-LOW ─────────────────────────────────────────────────────────────┐  │
│  │  Testing & QA:        ░░░░░░░░░░ 0%  [L4-A10 PENDING]               │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  Agents: 10/10 Ready | Supervisor: ACTIVE | RCA Level: 5                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## SESSION TASK → TODOLIST MAPPING

| Session Task | Todo ID | Agent | mix todo Command |
|--------------|---------|-------|------------------|
| Tailwind config | 1.1.0.0.0 | L4-A01 | `mix todo.update "1.1.0.0.0" in_progress` |
| CSS variables | 1.2.0.0.0 | L4-A02 | `mix todo.update "1.2.0.0.0" in_progress` |
| JS hook | 1.3.0.0.0 | L4-A03 | `mix todo.update "1.3.0.0.0" in_progress` |
| ThemeContext | 2.1.0.0.0 | L4-A04 | `mix todo.update "2.1.0.0.0" in_progress` |
| User resource | 2.2.0.0.0 | L4-A04 | `mix todo.update "2.2.0.0.0" in_progress` |
| ThemePlug | 2.3.0.0.0 | L4-A04 | `mix todo.update "2.3.0.0.0" in_progress` |
| LiveView hook | 2.4.0.0.0 | L4-A04 | `mix todo.update "2.4.0.0.0" in_progress` |
| Root layout | 3.1.0.0.0 | L4-A05 | `mix todo.update "3.1.0.0.0" in_progress` |
| Settings wire | 4.1.0.0.0 | L4-A06 | `mix todo.update "4.1.0.0.0" in_progress` |
| Prajna comps | 5.1.0.0.0 | L4-A07 | `mix todo.update "5.1.0.0.0" in_progress` |
| Core comps | 5.2.0.0.0 | L4-A08 | `mix todo.update "5.2.0.0.0" in_progress` |
| LiveViews | 6.0.0.0.0 | L4-A09 | `mix todo.update "6.0.0.0.0" in_progress` |
| Testing | 7.0.0.0.0 | L4-A10 | `mix todo.update "7.0.0.0.0" in_progress` |

---

*Generated by L5-SUPERVISOR | SOPv5.11 + GDE + 5-Level RCA Compliant*
