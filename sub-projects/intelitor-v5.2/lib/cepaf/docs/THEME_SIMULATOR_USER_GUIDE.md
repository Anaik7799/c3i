# Aerospace Theme Simulator - User Guide

**Version**: 1.0.0 | **Framework**: SOPv5.11 | **.NET**: 10.0 LTS
**Compliance**: NASA-STD-3000 | NUREG-0700 | MIL-STD-1472H | WCAG 2.1 AA/AAA

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Overview](#overview)
3. [Screens & Navigation](#screens--navigation)
4. [User Journey System](#user-journey-system)
5. [Design Testing System](#design-testing-system)
6. [Keyboard Controls](#keyboard-controls)
7. [Test Categories](#test-categories)
8. [BDD Test Scenarios](#bdd-test-scenarios)
9. [Troubleshooting](#troubleshooting)

---

## Quick Start

```bash
# Option 1: Use the launch script
./scripts/theme-simulator.sh

# Option 2: Direct command
devenv shell -- dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- -t

# Option 3: Full command
devenv shell -- dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- --theme-simulator
```

---

## Overview

The Aerospace Theme Simulator is a comprehensive TUI (Terminal User Interface) tool for testing and validating the 17-dimensional aerospace design system. It provides:

- **77 Component Variants** across 26 component types
- **117 States** (Default, Hover, Focus, Active, Disabled, etc.)
- **12 Test Categories** for systematic validation
- **User Journey Simulation** with checkpoints, branches, and rollback
- **WCAG Compliance Testing** with AA/AAA verification
- **Color Blindness Simulation** (Protanopia, Deuteranopia, Tritanopia, Achromatopsia)

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AEROSPACE THEME SIMULATOR                        │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
│  │   Screens   │  │  Journeys   │  │    Tests    │  │  Branches  │ │
│  │  (12 total) │  │ (5 predef)  │  │(12 categs)  │  │ (timeline) │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └────────────┘ │
├─────────────────────────────────────────────────────────────────────┤
│  17-Dimensional Design System | Fractal Holonic Architecture       │
│  STAMP Safety Constraints | IEC 61508 SIL-2 Compliant              │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Screens & Navigation

### Available Screens

| Screen | Key | Description |
|--------|-----|-------------|
| **Palette Demo** | `1` | Color palette with all 17 color dimensions |
| **Typography Demo** | `2` | Font scales, weights, and text rendering |
| **Buttons Demo** | `3` | All button variants and states |
| **Inputs Demo** | `4` | Form inputs, validation states |
| **Cards Demo** | `5` | Card layouts and compositions |
| **Tables Demo** | `6` | Data tables with sorting/filtering |
| **Badges Demo** | `7` | Status badges, notifications |
| **Progress Demo** | `8` | Progress bars, spinners, loaders |
| **Alerts Demo** | `9` | Alert messages, toasts, notifications |
| **Modals Demo** | `0` | Modal dialogs, overlays |
| **Navigation Demo** | `N` | Navigation components, menus |
| **Dashboard Demo** | `D` | Complete dashboard layout |
| **Journey Simulation** | `J` | User journey testing |
| **Journey Timeline** | `K` | Timeline visualization |
| **Journey Branches** | `L` | Branch management |

### Screen Layout Modes

| Mode | Viewport | Use Case |
|------|----------|----------|
| Compact | < 80 cols | Mobile/narrow terminals |
| Standard | 80-120 cols | Default terminal |
| Wide | 120-180 cols | Large monitors |
| Ultrawide | > 180 cols | Multi-monitor setups |

---

## User Journey System

### Predefined Journeys

#### 1. Security Officer Journey
```
Steps: 8 | Duration: ~15 min | Difficulty: 3/5

Given I am a security officer
When I log into the system
Then I should see the alarm dashboard

Scenario: Respond to Critical Alarm
  - View alarm list with priority sorting
  - Select critical alarm for investigation
  - Review alarm details and camera feed
  - Acknowledge and document response
  - Escalate if necessary
  - Close alarm with resolution notes
```

#### 2. Aerospace Designer Journey
```
Steps: 10 | Duration: ~25 min | Difficulty: 4/5

Given I am a UX designer
When I access the theme system
Then I should see all 17 color dimensions

Scenario: Create Custom Theme Variant
  - Browse color palette
  - Adjust primary colors
  - Test contrast ratios (WCAG)
  - Preview in color blindness modes
  - Export theme configuration
```

#### 3. System Administrator Journey
```
Steps: 6 | Duration: ~10 min | Difficulty: 2/5

Given I am a system administrator
When I access system settings
Then I should see configuration options

Scenario: Configure System Settings
  - Access admin dashboard
  - Modify system parameters
  - Validate changes
  - Apply configuration
  - Verify system health
```

#### 4. Accessibility Tester Journey
```
Steps: 7 | Duration: ~20 min | Difficulty: 4/5

Given I am an accessibility tester
When I run WCAG compliance tests
Then I should verify AA/AAA compliance

Scenario: Full WCAG Audit
  - Check contrast ratios
  - Test keyboard navigation
  - Verify screen reader compatibility
  - Test color blindness modes
  - Document compliance status
```

#### 5. Control Room Operator Journey
```
Steps: 12 | Duration: ~30 min | Difficulty: 5/5

Given I am a control room operator
When I monitor safety-critical systems
Then I should see real-time status

Scenario: Emergency Response
  - Monitor system dashboard
  - Detect anomaly
  - Initiate ARM protocol
  - Confirm with FIRE sequence
  - Execute emergency procedure
  - Document incident
```

### Journey Controls

| Key | Action | Description |
|-----|--------|-------------|
| `J` | Open Journeys | Navigate to journey selection |
| `Enter` | Start Journey | Begin selected journey |
| `Space` | Execute Step | Execute current step |
| `C` | Checkpoint | Create checkpoint at current position |
| `R` | Rollback | Rollback to selected checkpoint |
| `B` | Branch | Create new branch from checkpoint |
| `M` | Merge | Merge branch into main |
| `K` | Timeline | View journey timeline |
| `L` | Branches | View/manage branches |

### Checkpoint System

```
Checkpoint Structure:
┌──────────────────────────────────────┐
│ CP-20251231-143022-3                 │
│ ├── Name: "CP @ Step 3"              │
│ ├── Journey: security-officer        │
│ ├── Step: 3/8                        │
│ ├── State: [serialized]              │
│ ├── Tags: [manual, branch-point]     │
│ └── Parent: CP-20251231-142815-1     │
└──────────────────────────────────────┘
```

### Branch Management

```
Branch Visualization:
main ─────●─────●─────●─────●─────●
              ↘
         branch-1 ────●────●
                       ↘
                  branch-2 ────●
```

---

## Design Testing System

### Test Suite Structure

```fsharp
TestSuite {
    Id: "TS-001"
    Name: "WCAG Compliance Suite"
    Tests: [
        DesignTest { Category: ColorContrast; Severity: Critical }
        DesignTest { Category: ColorBlindness; Severity: High }
        DesignTest { Category: TextReadability; Severity: High }
    ]
    RunInParallel: true
    StopOnFirstFailure: false
}
```

### A/B Testing

```
A/B Test Configuration:
┌─────────────────────────────────────────────┐
│ Test: "Button Color Comparison"             │
│ ├── Variant A: Default Blue (#1E90FF)       │
│ ├── Variant B: Electric Blue (#7DF9FF)      │
│ ├── Metrics: Click rate, Time to action     │
│ └── Duration: 1000 iterations               │
└─────────────────────────────────────────────┘
```

### Regression Testing

```
Regression Baseline:
┌─────────────────────────────────────────────┐
│ Baseline: v1.0.0 (2025-12-30)               │
│ ├── ColorContrast: PASS (4.5:1 ratio)       │
│ ├── ButtonStates: PASS (all 7 states)       │
│ ├── AnimationTiming: PASS (200ms)           │
│ └── Tolerance: 5% deviation allowed         │
└─────────────────────────────────────────────┘
```

---

## Keyboard Controls

### Global Controls

| Key | Action |
|-----|--------|
| `Q` | Quit simulator |
| `Esc` | Back / Cancel |
| `?` | Show help |
| `Tab` | Next section |
| `Shift+Tab` | Previous section |

### Navigation

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate up/down |
| `←` / `→` | Navigate left/right |
| `Enter` | Select / Confirm |
| `Space` | Toggle / Execute |
| `Home` | Go to first item |
| `End` | Go to last item |
| `PgUp` / `PgDn` | Page navigation |

### Screen Switching

| Key | Screen |
|-----|--------|
| `1-9, 0` | Component demos |
| `N` | Navigation demo |
| `D` | Dashboard demo |
| `J` | Journey simulation |
| `K` | Journey timeline |
| `L` | Journey branches |

### Journey Controls

| Key | Action |
|-----|--------|
| `C` | Create checkpoint |
| `R` | Rollback to checkpoint |
| `B` | Create branch |
| `M` | Merge branch |
| `P` | Pause journey |
| `S` | Skip step |

### Testing Controls

| Key | Action |
|-----|--------|
| `T` | Run test suite |
| `A` | Run A/B test |
| `G` | Generate test report |
| `E` | Export results |

---

## Test Categories

### 1. Color Contrast (WCAG)
```
Category: ColorContrast
Severity: Critical
Tests:
  - Normal text contrast (4.5:1 minimum)
  - Large text contrast (3:1 minimum)
  - UI component contrast (3:1 minimum)
  - Focus indicator contrast
```

### 2. Color Blindness
```
Category: ColorBlindness
Severity: High
Simulations:
  - Protanopia (red-blind)
  - Deuteranopia (green-blind)
  - Tritanopia (blue-blind)
  - Achromatopsia (total color blindness)
```

### 3. Typography Readability
```
Category: TypographyReadability
Severity: High
Tests:
  - Font size minimums (14px body)
  - Line height (1.5 minimum)
  - Letter spacing
  - Word spacing
  - Paragraph width (45-75 characters)
```

### 4. Animation Timing
```
Category: AnimationTiming
Severity: Medium
Tests:
  - Transition duration (100-300ms)
  - Easing functions
  - Reduced motion support
  - No flashing (< 3 Hz)
```

### 5. Component States
```
Category: ComponentStates
Severity: High
States:
  - Default, Hover, Focus, Active
  - Disabled, Loading, Error
  - Selected, Expanded, Collapsed
```

### 6. Layout Responsiveness
```
Category: LayoutResponsiveness
Severity: Medium
Breakpoints:
  - Mobile: < 640px
  - Tablet: 640-1024px
  - Desktop: 1024-1440px
  - Large: > 1440px
```

### 7. Spacing Consistency
```
Category: SpacingConsistency
Severity: Low
Scale:
  - xs: 4px, sm: 8px, md: 16px
  - lg: 24px, xl: 32px, xxl: 48px
```

### 8. Icon Clarity
```
Category: IconClarity
Severity: Medium
Tests:
  - Minimum size (24x24px touch)
  - Stroke width consistency
  - Color contrast
  - Semantic meaning
```

### 9. Focus Management
```
Category: FocusManagement
Severity: Critical
Tests:
  - Visible focus indicator
  - Logical tab order
  - Focus trap in modals
  - Skip links
```

### 10. Error States
```
Category: ErrorStates
Severity: High
Tests:
  - Error message visibility
  - Color coding (not color-only)
  - Icon usage
  - Recovery guidance
```

### 11. Loading States
```
Category: LoadingStates
Severity: Medium
Tests:
  - Skeleton screens
  - Progress indicators
  - Timeout handling
  - Retry mechanisms
```

### 12. Safety Protocol (ARM/FIRE)
```
Category: SafetyProtocol
Severity: Critical
Tests:
  - Two-step confirmation
  - ARM state timeout (30s)
  - FIRE confirmation required
  - Abort capability
  - Audit logging
```

---

## BDD Test Scenarios

### Feature: Color Palette Validation

```gherkin
Feature: WCAG Color Contrast Compliance
  As a user with visual impairments
  I want sufficient color contrast
  So that I can read all text content

  Scenario: Normal text meets AA standard
    Given the theme uses color "#1A1A2E" for text
    And the background color is "#FFFFFF"
    When I calculate the contrast ratio
    Then the ratio should be greater than 4.5:1
    And the AA compliance badge should show "PASS"

  Scenario: Large text meets AA standard
    Given the theme uses heading color "#2D3748"
    And the background color is "#F7FAFC"
    When I calculate the contrast ratio
    Then the ratio should be greater than 3:1

  Scenario: Focus indicator is visible
    Given a focusable element receives focus
    When the focus indicator is displayed
    Then the indicator should have contrast ratio >= 3:1
    And the indicator should be at least 2px wide
```

### Feature: User Journey Execution

```gherkin
Feature: Security Officer Alarm Response
  As a security officer
  I want to respond to alarms efficiently
  So that I can maintain facility security

  Background:
    Given I am logged in as "security_officer"
    And I have permission "alarm.respond"

  Scenario: View and acknowledge critical alarm
    Given there is a critical alarm "DOOR-BREACH-001"
    When I navigate to the alarm dashboard
    Then I should see the alarm in the critical section
    And the alarm should be highlighted in red

    When I select the alarm
    Then I should see the alarm details panel
    And I should see the camera feed if available

    When I click "Acknowledge"
    And I enter response notes "Investigating breach"
    Then the alarm status should change to "Acknowledged"
    And the timestamp should be recorded

  Scenario: Create checkpoint during investigation
    Given I am on step 4 of the journey
    When I press "C" to create checkpoint
    Then a checkpoint should be created
    And the checkpoint should store current state
    And I should see confirmation message

  Scenario: Rollback to previous checkpoint
    Given I have checkpoint "CP-001" at step 3
    And I am currently on step 6
    When I select checkpoint "CP-001"
    And I press "R" to rollback
    Then the state should restore to step 3
    And all subsequent actions should be undone
```

### Feature: Color Blindness Simulation

```gherkin
Feature: Color Blindness Accessibility
  As a colorblind user
  I want the interface to be usable
  So that I can distinguish UI elements

  Scenario Outline: UI remains distinguishable in <mode>
    Given I enable "<mode>" color blindness simulation
    When I view the alarm dashboard
    Then critical alarms should be distinguishable from warnings
    And success states should be distinguishable from errors
    And all status badges should have text labels

  Examples:
    | mode          |
    | Protanopia    |
    | Deuteranopia  |
    | Tritanopia    |
    | Achromatopsia |

  Scenario: Color is not the only indicator
    Given I am viewing a form with validation errors
    When a field has an error
    Then the field should have an error icon
    And the field should have error text
    And the field should not rely solely on red color
```

### Feature: ARM/FIRE Safety Protocol

```gherkin
Feature: Safety-Critical Action Confirmation
  As a control room operator
  I want two-step confirmation for critical actions
  So that accidental triggers are prevented

  Scenario: ARM then FIRE sequence for emergency shutdown
    Given I am on the emergency controls panel
    And the system is in normal operation

    When I press the "Emergency Shutdown" button
    Then the button should enter ARM state
    And a 30-second countdown should begin
    And the button should pulse amber

    When I press the button again within 30 seconds
    Then the FIRE confirmation dialog should appear
    And I must type "CONFIRM" to proceed

    When I type "CONFIRM" and press Enter
    Then the emergency shutdown should execute
    And an audit log entry should be created

  Scenario: ARM state timeout
    Given the button is in ARM state
    When 30 seconds elapse without FIRE
    Then the button should return to normal state
    And a "Timeout" message should display
    And an audit log should record the timeout

  Scenario: Abort during ARM state
    Given the button is in ARM state
    When I press Escape
    Then the ARM state should cancel
    And the button should return to normal
```

### Feature: Journey Branching

```gherkin
Feature: Journey Branch Management
  As a tester
  I want to create branches from checkpoints
  So that I can explore alternative paths

  Scenario: Create branch at decision point
    Given I am at a branch point in the journey
    And I have created checkpoint "CP-Decision"

    When I press "B" to create a branch
    Then a new branch should be created
    And the branch should be named "Branch 1"
    And the branch should have a distinct color
    And the timeline should show the fork

  Scenario: Switch between branches
    Given I have branches "main" and "Branch 1"
    And I am currently on "main"

    When I press "L" to view branches
    And I select "Branch 1"
    And I press Enter to switch
    Then the current branch should be "Branch 1"
    And the state should reflect Branch 1's position

  Scenario: Merge branch into main
    Given I am on "Branch 1" at step 8
    And "main" is at step 5

    When I press "M" to merge
    And I confirm the merge
    Then "main" should incorporate Branch 1's changes
    And the merge should be recorded in history
```

---

## Troubleshooting

### Common Issues

#### Simulator won't start
```bash
# Check .NET version
dotnet --version  # Should be 10.0.x

# Rebuild if needed
devenv shell -- dotnet build lib/cepaf/src/Cepaf/Cepaf.fsproj
```

#### Colors not displaying correctly
```bash
# Ensure terminal supports true color
echo $COLORTERM  # Should be "truecolor" or "24bit"

# Test true color support
printf "\x1b[38;2;255;100;0mTRUE COLOR TEST\x1b[0m\n"
```

#### Keyboard not responding
- Ensure terminal is in raw mode
- Check for conflicting terminal multiplexer bindings (tmux/screen)
- Try running without tmux: `devenv shell -- dotnet run ...`

#### Journey state lost
- Checkpoints are stored in memory only
- Use `C` frequently to save progress
- Export test results before quitting

### Performance Optimization

```bash
# For faster startup, use release build
devenv shell -- dotnet run -c Release --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- -t
```

### Log Files

```bash
# View CEPAF logs
tail -f lib/cepaf/artifacts/cepa-audit.log

# View detailed trace
CEPAF_LOG_LEVEL=trace ./scripts/theme-simulator.sh
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-12-31 | Initial release with .NET 10 |
| 0.9.0 | 2025-12-30 | Added journey branching |
| 0.8.0 | 2025-12-29 | Added design testing system |

---

**Generated by**: Claude Code | **Framework**: SOPv5.11 | **STAMP Compliant**
