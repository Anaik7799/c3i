# UC-DEVELOPER: Dynamic State Transitions & DAG Paths
**Version**: 3.1.0-DYNAMICS | **Date**: 2025-12-30 | **Status**: ACTIVE
**Focus**: User Journey Evolution, State Machines, Animation Choreography

---

## Table of Contents
1. [UC-DEV-001 Full Journey DAG](#uc-dev-001-full-journey-dag)
2. [State Machine Definitions](#state-machine-definitions)
3. [Dynamic Wireframe Evolution](#dynamic-wireframe-evolution)
4. [Animation Choreography](#animation-choreography)
5. [Cross-Use-Case DAG Integration](#cross-use-case-dag-integration)

---

## UC-DEV-001: Create ADR - Full Journey DAG

### Primary DAG Path

```
                              ┌─────────────────────────────────────────┐
                              │         UC-DEV-001 JOURNEY DAG          │
                              └─────────────────────────────────────────┘

    ┌─────────┐    [D]ecide    ┌─────────┐    [N]ew     ┌─────────┐
    │  LOGIN  │ ─────────────► │DASHBOARD│ ──────────► │  FORM   │
    │  GATE   │                │  VIEW   │             │ PAGE 1  │
    └─────────┘                └─────────┘             └─────────┘
         │                          │                       │
         │                          │                       │ [Tab]
         │ Timeout/Error            │ [S]earch              ▼
         ▼                          ▼                 ┌─────────┐
    ┌─────────┐               ┌─────────┐            │  FORM   │
    │  ERROR  │               │ SEARCH  │            │ PAGE 2  │
    │  STATE  │               │ RESULTS │            └─────────┘
    └─────────┘               └─────────┘                  │
                                   │                       │ [Tab]
                                   │ [Enter]               ▼
                                   ▼                 ┌─────────┐
                              ┌─────────┐            │ REVIEW  │
                              │  DETAIL │            │ PAGE 3  │
                              │  VIEW   │            └─────────┘
                              └─────────┘                  │
                                   │                       │
                                   │                  ┌────┴────┐
                                   │                  │         │
                                   │            [Enter]   [Ctrl+S]
                                   │                  │         │
                                   │                  ▼         ▼
                                   │            ┌─────────┐ ┌─────────┐
                                   └───────────►│ SUCCESS │ │  DRAFT  │
                                                │ CONFIRM │ │  SAVED  │
                                                └─────────┘ └─────────┘
                                                      │
                                                      │ Auto (3s)
                                                      ▼
                                                ┌─────────┐
                                                │DASHBOARD│
                                                │ UPDATED │
                                                └─────────┘
```

### DAG Node State Definitions

```yaml
dag_nodes:
  LOGIN_GATE:
    id: "N001"
    entry_conditions:
      - user_not_authenticated
    exit_conditions:
      - valid_session_token
    transitions:
      - target: DASHBOARD_VIEW
        trigger: auth_success
        animation: fade_slide_right
      - target: ERROR_STATE
        trigger: auth_failure
        animation: shake_red_flash

  DASHBOARD_VIEW:
    id: "N002"
    state_variables:
      - decisions_list: Decision[]
      - selected_index: int
      - filter_active: boolean
      - sort_order: "created_desc" | "updated_desc" | "title_asc"
    ui_regions:
      - zone_a: navigation_tabs
      - zone_b: decisions_list
      - zone_c: quick_stats
      - zone_d: activity_feed
    transitions:
      - target: FORM_PAGE_1
        trigger: key_press("N")
        animation: zoom_expand_from_button
        duration_ms: 300
      - target: SEARCH_RESULTS
        trigger: key_press("S") | key_press("/")
        animation: search_bar_expand
        duration_ms: 200
      - target: DETAIL_VIEW
        trigger: key_press("Enter")
        animation: card_flip_to_detail
        duration_ms: 350

  FORM_PAGE_1:
    id: "N003"
    state_variables:
      - title: string
      - type: "adr" | "rfc" | "spike"
      - context: string
      - validation_errors: Error[]
      - is_dirty: boolean
      - auto_save_pending: boolean
    dynamic_elements:
      - title_field:
          on_change: validate_title, update_auto_id
          animation: inline_validation_pulse
      - context_field:
          on_change: update_word_count, validate_min_length
          animation: word_count_fade
      - type_selector:
          on_change: update_form_variant
          animation: morph_radio_selection
    transitions:
      - target: FORM_PAGE_2
        trigger: key_press("Tab") | scroll_to_bottom
        guard: page1_valid
        animation: slide_left
        duration_ms: 250
      - target: DASHBOARD_VIEW
        trigger: key_press("Esc")
        guard: confirm_if_dirty
        animation: zoom_collapse

  FORM_PAGE_2:
    id: "N004"
    state_variables:
      - positive_consequences: string[]
      - negative_consequences: string[]
      - linked_decisions: DecisionRef[]
      - linked_files: FileRef[]
      - tags: string[]
    dynamic_elements:
      - consequence_list:
          on_add: animate_list_insert
          on_remove: animate_list_collapse
          animation: spring_bounce
      - link_picker:
          on_open: overlay_slide_up
          on_select: badge_appear
          animation: elastic_snap
      - tag_input:
          on_add: tag_pill_grow
          on_remove: tag_pill_shrink
          animation: pill_morph
    transitions:
      - target: FORM_PAGE_3
        trigger: key_press("Tab")
        guard: page2_valid
        animation: slide_left
      - target: FORM_PAGE_1
        trigger: key_press("Shift+Tab")
        animation: slide_right

  FORM_PAGE_3:
    id: "N005"
    state_variables:
      - preview_data: ADRPreview
      - validation_complete: boolean
      - checklist_items: ChecklistItem[]
      - notify_channels: string[]
    dynamic_elements:
      - preview_card:
          on_load: fade_in_sequential
          animation: card_materialize
      - checklist:
          on_item_check: checkmark_draw
          animation: draw_checkmark
      - submit_button:
          on_validation_pass: enable_glow
          on_validation_fail: disable_dim
          animation: button_pulse
    transitions:
      - target: SUCCESS_CONFIRM
        trigger: key_press("Enter")
        guard: all_valid
        animation: submit_ripple_expand
        side_effects:
          - create_holon
          - broadcast_zenoh
          - create_audit_log
      - target: DRAFT_SAVED
        trigger: key_press("Ctrl+S")
        animation: save_checkmark
        duration_ms: 500

  SUCCESS_CONFIRM:
    id: "N006"
    state_variables:
      - created_adr: ADR
      - notifications_sent: int
      - zenoh_confirmed: boolean
    dynamic_elements:
      - success_icon:
          on_enter: scale_bounce_in
          animation: confetti_burst
      - status_badges:
          on_load: stagger_fade_in
          delay_between_ms: 100
      - action_buttons:
          on_load: slide_up_from_bottom
          animation: spring_appear
    transitions:
      - target: DASHBOARD_VIEW
        trigger: timeout(3000) | key_press("B")
        animation: zoom_out_fade
      - target: DETAIL_VIEW
        trigger: key_press("V")
        animation: morph_to_detail

  ERROR_STATE:
    id: "N007"
    state_variables:
      - error_type: "validation" | "network" | "permission" | "unknown"
      - error_message: string
      - retry_count: int
      - can_retry: boolean
    dynamic_elements:
      - error_banner:
          on_enter: slide_down_shake
          animation: glitch_chromatic
      - retry_button:
          on_click: spin_then_retry
          animation: button_loading_spin
    transitions:
      - target: previous_state
        trigger: key_press("R") & can_retry
        animation: fade_refresh
      - target: DASHBOARD_VIEW
        trigger: key_press("Esc")
        animation: dissolve_out
```

---

## State Machine Definitions

### ADR Form State Machine (FSM)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         ADR FORM STATE MACHINE                                │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────┐                                                                 │
│  │  IDLE   │◄──────────────────────────────────────────────────────┐        │
│  └────┬────┘                                                        │        │
│       │ [N]ew                                                       │        │
│       ▼                                                             │        │
│  ┌─────────┐    type_change    ┌─────────────┐                     │        │
│  │ENTERING │ ───────────────► │ CONFIGURING │                      │        │
│  │  TITLE  │                   │    TYPE     │                      │        │
│  └────┬────┘                   └──────┬──────┘                      │        │
│       │ title_valid                   │ type_selected              │        │
│       ▼                               ▼                             │        │
│  ┌─────────┐    ◄──────────────────────┐                           │        │
│  │ENTERING │                           │                            │        │
│  │ CONTEXT │                           │                            │        │
│  └────┬────┘                           │                            │        │
│       │ context_valid (≥50 words)      │ back                       │        │
│       ▼                                │                            │        │
│  ┌─────────┐    ◄──────────────────────┼───────────┐               │        │
│  │ENTERING │                           │           │                │        │
│  │DECISION │                           │           │                │        │
│  └────┬────┘                           │           │                │        │
│       │ decision_valid                 │           │ back           │        │
│       ▼                                │           │                │        │
│  ┌──────────┐                          │           │                │        │
│  │ENTERING  │ ─────────────────────────┘           │                │        │
│  │CONSEQUEN.│                                      │                │        │
│  └────┬─────┘                                      │                │        │
│       │ consequences_valid                         │                │        │
│       ▼                                            │                │        │
│  ┌──────────┐                                      │                │        │
│  │ LINKING  │ ─────────────────────────────────────┘                │        │
│  │ RELATED  │                                                       │        │
│  └────┬─────┘                                                       │        │
│       │ links_complete (optional)                                   │        │
│       ▼                                                             │        │
│  ┌──────────┐    validation_fail    ┌──────────┐                   │        │
│  │REVIEWING │ ────────────────────► │VALIDATION│ ───────┐          │        │
│  │ PREVIEW  │ ◄──────────────────── │  ERROR   │        │          │        │
│  └────┬─────┘    fix_errors         └──────────┘        │ retry    │        │
│       │                                                  │          │        │
│       │ submit                                           │          │        │
│       ▼                                                  │          │        │
│  ┌──────────┐    network_error      ┌──────────┐        │          │        │
│  │SUBMITTING│ ────────────────────► │ NETWORK  │ ───────┘          │        │
│  │          │                       │  ERROR   │                    │        │
│  └────┬─────┘                       └──────────┘                    │        │
│       │ success                                                     │        │
│       ▼                                                             │        │
│  ┌──────────┐                                                       │        │
│  │  SUCCESS │ ──────────────────────────────────────────────────────┘        │
│  │          │    timeout(3s) | close                                         │
│  └──────────┘                                                                │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

### UI Element State Machines

#### Submit Button States
```
                    ┌────────────────────────────────────────┐
                    │       SUBMIT BUTTON STATE MACHINE       │
                    └────────────────────────────────────────┘

   ┌──────────┐   form_invalid   ┌──────────┐   form_valid   ┌──────────┐
   │ DISABLED │ ◄─────────────── │  READY   │ ──────────────►│ ENABLED  │
   │  (gray)  │                  │ (dimmed) │                │  (blue)  │
   └──────────┘                  └──────────┘                └────┬─────┘
        │                                                          │
        │                                                     click│
        │                                                          ▼
        │                                                    ┌──────────┐
        │                           success                  │ LOADING  │
        │                       ┌─────────────────────────── │(spinning)│
        │                       │                            └────┬─────┘
        │                       ▼                                 │
        │                  ┌──────────┐                           │ error
        │                  │ SUCCESS  │                           │
        │   timeout(2s)    │ (green ✓)│                           ▼
        └──────────────────│          │                      ┌──────────┐
                           └──────────┘                      │  ERROR   │
                                                             │ (red ✗)  │
                                                             └──────────┘

   Visual States:
   ├── DISABLED:  bg-gray-300, cursor-not-allowed, opacity-50
   ├── READY:     bg-gray-400, cursor-not-allowed, opacity-70
   ├── ENABLED:   bg-blue-600, cursor-pointer, hover:bg-blue-700, shadow-lg
   ├── LOADING:   bg-blue-600, cursor-wait, spinner-animation
   ├── SUCCESS:   bg-green-600, checkmark-draw-animation
   └── ERROR:     bg-red-600, shake-animation, tooltip-error-message
```

#### Text Field States
```
   ┌──────────────────────────────────────────────────────────────────┐
   │                   TEXT FIELD STATE MACHINE                        │
   └──────────────────────────────────────────────────────────────────┘

              ┌─────────┐
              │  EMPTY  │
              │ (label  │
              │ centered│
              └────┬────┘
                   │ focus
                   ▼
              ┌─────────┐    blur (empty)    ┌─────────┐
              │ FOCUSED │ ─────────────────► │  EMPTY  │
              │ (label  │                    │         │
              │ floated)│ ◄─────────────────┐│         │
              └────┬────┘    focus          │└─────────┘
                   │ input                   │
                   ▼                         │
              ┌─────────┐    blur (filled)  │
              │ FILLED  │ ──────────────────┘
              │ (value  │
              │ shown)  │
              └────┬────┘
                   │ validate
          ┌────────┴────────┐
          │                 │
     valid│                 │invalid
          ▼                 ▼
     ┌─────────┐      ┌─────────┐
     │  VALID  │      │ INVALID │
     │ (green  │      │ (red    │
     │ border) │      │ border, │
     └─────────┘      │ error)  │
                      └─────────┘

   Transition Animations:
   ├── focus:    label-float-up (200ms ease-out)
   ├── blur:     label-float-down (150ms ease-in)
   ├── valid:    border-color-green-pulse (300ms)
   ├── invalid:  border-color-red-shake (400ms)
   └── typing:   subtle-glow-pulse (continuous while focused)
```

---

## Dynamic Wireframe Evolution

### UC-DEV-001: Step-by-Step UI Evolution

#### Evolution 1: Dashboard → New Decision (Transition Animation)

**T=0ms: Initial Dashboard State**
```
┌────────────────────────────────────────────────────────────────┐
│  ┌─────────┐ ┌─────────┐ ┌─────────┐                          │
│  │[D]ecide │ │[P]attern│ │[D]ebug  │    [N]ew highlighted     │
│  │   ◉     │ │    ○    │ │    ○    │         ↓                │
│  └─────────┘ └─────────┘ └─────────┘    ┌──────────┐          │
│                                          │ [N]ew ✦ │ ← glow   │
│  ╔═══════════════════════════════════╗  └──────────┘          │
│  ║  Recent Decisions                  ║                        │
│  ╠═══════════════════════════════════╣                        │
│  ║  │ 042 │ GraphQL Federation... │   ║                        │
│  ║  │ 041 │ JWT Token Rotation... │   ║                        │
│  ╚═══════════════════════════════════╝                        │
└────────────────────────────────────────────────────────────────┘
```

**T=50ms: Button Press Detected**
```
┌────────────────────────────────────────────────────────────────┐
│                                          ┌──────────┐          │
│                                          │ [N]ew    │ ← pressed│
│                                          │  ████    │   ripple │
│                                          └──────────┘   starts │
│  ╔═══════════════════════════════════╗                        │
│  ║  Recent Decisions                  ║  ← beginning to fade  │
│  ╠═══════════════════════════════════╣     opacity: 0.9       │
│  ║  │ 042 │ GraphQL Federation... │   ║                        │
│  ╚═══════════════════════════════════╝                        │
└────────────────────────────────────────────────────────────────┘
```

**T=100ms: Expansion Begins**
```
┌────────────────────────────────────────────────────────────────┐
│                             ┌────────────────────────────┐     │
│                             │                            │     │
│                             │   ← expanding from button  │     │
│                             │     origin point           │     │
│                             │                            │     │
│  ╔════════════════════╗     └────────────────────────────┘     │
│  ║  Recent Dec...      ║  ← fading out                        │
│  ╠════════════════════╣     opacity: 0.6                      │
│  ║  │ 042 │ Graph...   ║     scale: 0.95                      │
│  ╚════════════════════╝                                        │
└────────────────────────────────────────────────────────────────┘
```

**T=200ms: Form Materializing**
```
┌────────────────────────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════════════════════╗    │
│  ║            📝 NEW ARCHITECTURE DECISION               ║    │
│  ╚═══════════════════════════════════════════════════════╝    │
│                                                                │
│  ┌───────────────────────────────────────────────────────┐    │
│  │  SECTION 1: IDENTIFICATION                             │ ← │
│  │  ╭─────────────────────────────────────────────────╮   │   │
│  │  │  Title *                          ← label float │   │fading│
│  │  │  ┌─────────────────────────────────────────┐    │   │ in │
│  │  │  │ █                              ← cursor │    │   │   │
│  │  │  └─────────────────────────────────────────┘    │   │   │
│  │  ╰─────────────────────────────────────────────────╯   │   │
│  └───────────────────────────────────────────────────────┘    │
│                                                                │
│  Background: dashboard at opacity: 0.1, blur: 8px             │
└────────────────────────────────────────────────────────────────┘
```

**T=300ms: Form Fully Visible (Final State)**
```
┌────────────────────────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════════════════════╗    │
│  ║            📝 NEW ARCHITECTURE DECISION               ║    │
│  ║                Type: ADR | Status: Draft              ║    │
│  ╚═══════════════════════════════════════════════════════╝    │
│                                                                │
│  ┌───────────────────────────────────────────────────────┐    │
│  │  SECTION 1: IDENTIFICATION                             │    │
│  │  ╭─────────────────────────────────────────────────╮   │    │
│  │  │  Title *                                  ✨glow │   │    │
│  │  │  ┌─────────────────────────────────────────┐    │   │    │
│  │  │  │ █                                       │    │   │    │
│  │  │  └─────────────────────────────────────────┘    │   │    │
│  │  │  └─ Auto-ID: ADR-043 (generated on blur)        │   │    │
│  │  │                                                  │   │    │
│  │  │  Type: ◉ ADR  ○ RFC  ○ Spike                    │   │    │
│  │  ╰─────────────────────────────────────────────────╯   │    │
│  └───────────────────────────────────────────────────────┘    │
│                                                                │
│  Focus: title_field | Keyboard hint: [Tab] to next            │
└────────────────────────────────────────────────────────────────┘
```

---

#### Evolution 2: Form Validation States

**State A: Empty Field (Invalid)**
```
┌────────────────────────────────────────────────────────────────┐
│  Title *                                                       │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                                                         │  │
│  │  ← placeholder: "Enter decision title..."              │  │
│  │                                                         │  │
│  └─────────────────────────────────────────────────────────┘  │
│    border: gray-300 | no error shown yet (pristine)           │
└────────────────────────────────────────────────────────────────┘
```

**State B: Typing (Active)**
```
┌────────────────────────────────────────────────────────────────┐
│  Title *                               ← label floated up     │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ GraphQL Fed█                                            │  │
│  │                                     ← cursor blinking   │  │
│  │                                                         │  │
│  └─────────────────────────────────────────────────────────┘  │
│    border: blue-500 | subtle glow | character count: 12/200   │
└────────────────────────────────────────────────────────────────┘
```

**State C: Valid (On Blur)**
```
┌────────────────────────────────────────────────────────────────┐
│  Title *                                              ✓       │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ GraphQL Federation Strategy                             │  │
│  │                                                         │  │
│  │                                    ← checkmark appears  │  │
│  └─────────────────────────────────────────────────────────┘  │
│    border: green-500 | pulse animation | Auto-ID: ADR-043     │
│                                                                │
│    Animation: checkmark draws in (300ms), border glows green  │
└────────────────────────────────────────────────────────────────┘
```

**State D: Invalid (On Blur)**
```
┌────────────────────────────────────────────────────────────────┐
│  Title *                                              ✗       │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ X                                  ← too short          │  │
│  │                                                         │  │
│  │                                                         │  │
│  └─────────────────────────────────────────────────────────┘  │
│    border: red-500 | shake animation                          │
│                                                                │
│    ⚠️ Title must be at least 10 characters                   │
│       ↑ error message slides in from below                    │
│                                                                │
│    Animation: field shakes (400ms), error fades in (200ms)    │
└────────────────────────────────────────────────────────────────┘
```

---

#### Evolution 3: Page Transitions

**Page 1 → Page 2 Transition**

```
T=0ms (Page 1 at rest)          T=125ms (Mid-transition)        T=250ms (Page 2 at rest)
┌──────────────────────┐        ┌──────────────────────┐        ┌──────────────────────┐
│ ████████████████████ │        │ ████████  ┃ ████████ │        │ ████████████████████ │
│ ████████████████████ │   →    │ ████████  ┃ ████████ │   →    │ ████████████████████ │
│                      │        │ Page 1    ┃ Page 2   │        │                      │
│ SECTION 1            │        │ sliding   ┃ sliding  │        │ SECTION 4            │
│ ────────────         │        │ left      ┃ in       │        │ ────────────         │
│ Title: [filled]      │        │           ┃          │        │ Consequences:        │
│ Type:  [selected]    │        │           ┃          │        │ + [input field]      │
│ Context: [filled]    │        │           ┃          │        │ - [input field]      │
│                      │        │           ┃          │        │                      │
│ ───── [Page 1/3] ─── │        │ opacity:  ┃ opacity: │        │ ───── [Page 2/3] ─── │
│                      │        │   0.5     ┃   0.5    │        │                      │
└──────────────────────┘        └──────────────────────┘        └──────────────────────┘

Animation Curve: cubic-bezier(0.4, 0, 0.2, 1)
Transform: translateX(-100%) for page 1, translateX(0) for page 2
Opacity: page 1 fades to 0, page 2 fades from 0 to 1
```

---

#### Evolution 4: Success State Animation Choreography

```
┌────────────────────────────────────────────────────────────────────────────┐
│                        SUCCESS ANIMATION TIMELINE                           │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  T=0ms      Background dims (opacity 0.5)                                  │
│             ┌────────────────────────────────┐                             │
│             │     ░░░░░░░░░░░░░░░░░░░░░░     │                             │
│             └────────────────────────────────┘                             │
│                                                                             │
│  T=100ms    Success card scales up from center                             │
│             ┌────────────────────────────────┐                             │
│             │          ┌────────┐            │                             │
│             │          │   ✓    │ ← scale(0.5)                             │
│             │          └────────┘            │                             │
│             └────────────────────────────────┘                             │
│                                                                             │
│  T=200ms    Card fully visible, checkmark draws                            │
│             ┌────────────────────────────────┐                             │
│             │      ╔════════════════╗        │                             │
│             │      ║   ✓ SUCCESS    ║ ← scale(1.0)                         │
│             │      ╚════════════════╝        │                             │
│             └────────────────────────────────┘                             │
│                                                                             │
│  T=400ms    Confetti particles burst                                       │
│             ┌────────────────────────────────┐                             │
│             │    *  ╔════════════════╗  *    │                             │
│             │  *    ║   ✓ SUCCESS    ║    *  │                             │
│             │    *  ╚════════════════╝  *    │                             │
│             │  *        *      *        *    │                             │
│             └────────────────────────────────┘                             │
│                                                                             │
│  T=600ms    Status badges stagger in                                       │
│             ┌────────────────────────────────┐                             │
│             │      ╔════════════════╗        │                             │
│             │      ║   ✓ SUCCESS    ║        │                             │
│             │      ╠════════════════╣        │                             │
│             │      ║ 📊 Graph ✓     ║ ← badge 1                            │
│             │      ║ 🔔 Notify ✓    ║ ← badge 2 (+100ms)                   │
│             │      ║ 🔍 Index ✓     ║ ← badge 3 (+200ms)                   │
│             │      ╚════════════════╝        │                             │
│             └────────────────────────────────┘                             │
│                                                                             │
│  T=1000ms   Action buttons slide up                                        │
│             ┌────────────────────────────────┐                             │
│             │      ╔════════════════╗        │                             │
│             │      ║   ✓ SUCCESS    ║        │                             │
│             │      ╠════════════════╣        │                             │
│             │      ║ [View] [New] [Back]     ║ ← from bottom               │
│             │      ╚════════════════╝        │                             │
│             └────────────────────────────────┘                             │
│                                                                             │
│  T=3000ms   Auto-dismiss to dashboard                                      │
│             Card shrinks, background restores                              │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Cross-Use-Case DAG Integration

### Complete Developer Domain DAG

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER DOMAIN - INTEGRATED DAG                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│                              ┌─────────────────┐                                │
│                              │   ENTRY POINT   │                                │
│                              │  (Authenticate) │                                │
│                              └────────┬────────┘                                │
│                                       │                                          │
│                                       ▼                                          │
│                              ┌─────────────────┐                                │
│                              │ DEVELOPER DASH  │                                │
│                              │     (HOME)      │                                │
│                              └────────┬────────┘                                │
│                    ┌──────────────────┼──────────────────┐                      │
│                    │                  │                  │                      │
│           ┌────────▼────────┐ ┌───────▼───────┐ ┌───────▼───────┐              │
│           │  UC-DEV-001     │ │  UC-DEV-003   │ │  UC-DEV-004   │              │
│           │  Create ADR     │ │ Store Pattern │ │ Debug Session │              │
│           └────────┬────────┘ └───────┬───────┘ └───────┬───────┘              │
│                    │                  │                  │                      │
│                    │                  │                  │                      │
│           ┌────────▼────────┐         │                  │                      │
│           │  UC-DEV-002     │         │                  │                      │
│           │ Link to Code    │◄────────┼──────────────────┘                      │
│           └────────┬────────┘         │      (debug can link to ADR)            │
│                    │                  │                                          │
│                    ├──────────────────┤                                          │
│                    │                  │                                          │
│           ┌────────▼────────┐ ┌───────▼───────┐                                │
│           │  UC-DEV-005     │ │  UC-DEV-006   │                                │
│           │ Review Notes    │ │ Search Context│                                │
│           └────────┬────────┘ └───────┬───────┘                                │
│                    │                  │                                          │
│                    └────────┬─────────┘                                          │
│                             │                                                    │
│                    ┌────────▼────────┐                                          │
│                    │  UC-DEV-007     │                                          │
│                    │ View Statistics │                                          │
│                    └─────────────────┘                                          │
│                                                                                  │
│                                                                                  │
│  CROSS-DOMAIN EDGES:                                                            │
│  ─────────────────────────────────────────────────────────────────────         │
│                                                                                  │
│  UC-DEV-001 ──► UC-TL-001 (ADR can become RFC)                                  │
│           ──► UC-SRE-003 (ADR can define SLO)                                   │
│           ──► UC-PM-001 (ADR can relate to feature)                             │
│                                                                                  │
│  UC-DEV-003 ──► UC-KW-001 (Pattern appears in search)                           │
│           ──► UC-AI-001 (Pattern auto-classified)                               │
│                                                                                  │
│  UC-DEV-004 ──► UC-SRE-009 (Debug becomes post-mortem)                          │
│           ──► UC-ERR-001 (Debug triggers error flow)                            │
│                                                                                  │
│  UC-DEV-006 ──► UC-XRUN-001 (Context synced to F#)                              │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### State Transition Frequency Heatmap

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    STATE TRANSITION FREQUENCY HEATMAP                         │
│                      (Based on user behavior analytics)                       │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  FROM STATE          │ TO STATE              │ FREQUENCY │ AVG TIME          │
│  ────────────────────┼───────────────────────┼───────────┼─────────────────  │
│  Dashboard           │ Form Page 1           │ ████████  │ 45s               │
│  Form Page 1         │ Form Page 2           │ ███████   │ 2m 30s            │
│  Form Page 1         │ Dashboard (abandon)   │ ██        │ 30s               │
│  Form Page 2         │ Form Page 3           │ ██████    │ 1m 45s            │
│  Form Page 2         │ Form Page 1 (back)    │ █         │ 15s               │
│  Form Page 3         │ Success               │ █████████ │ 30s               │
│  Form Page 3         │ Form Page 2 (back)    │ █         │ 10s               │
│  Success             │ Dashboard             │ ████████  │ 3s (auto)         │
│  Success             │ Detail View           │ ███       │ 1s                │
│  Any                 │ Error State           │ █         │ N/A               │
│  Error State         │ Previous (retry)      │ ██████    │ 5s                │
│  Error State         │ Dashboard (abandon)   │ ██        │ 2s                │
│                                                                               │
│  LEGEND: █ = 10% of transitions                                              │
│                                                                               │
│  OPTIMIZATION OPPORTUNITIES:                                                  │
│  • Form Page 1 → Dashboard abandonment: Add progress saving                  │
│  • Error State → Dashboard: Improve error messages                           │
│  • Form Page 2 duration (1m 45s): Consider splitting consequences            │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Animation Choreography Specifications

### Timing Functions

```css
/* Animation Timing Constants */
:root {
  /* Durations */
  --duration-instant: 100ms;
  --duration-fast: 200ms;
  --duration-normal: 300ms;
  --duration-slow: 500ms;
  --duration-emphasis: 800ms;

  /* Easing Functions */
  --ease-default: cubic-bezier(0.4, 0, 0.2, 1);      /* Material Design standard */
  --ease-in: cubic-bezier(0.4, 0, 1, 1);             /* Accelerate */
  --ease-out: cubic-bezier(0, 0, 0.2, 1);            /* Decelerate */
  --ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);      /* Standard curve */
  --ease-bounce: cubic-bezier(0.68, -0.55, 0.265, 1.55); /* Overshoot */
  --ease-elastic: cubic-bezier(0.175, 0.885, 0.32, 1.275); /* Spring */

  /* Physics-based Springs (F# Terminal.Gui) */
  --spring-stiffness: 300;
  --spring-damping: 20;
  --spring-mass: 1;
}
```

### Animation Sequences

```yaml
animation_sequences:
  form_open:
    name: "Open ADR Form"
    total_duration: 300ms
    steps:
      - element: background
        animation: dim
        duration: 100ms
        delay: 0ms
        properties:
          opacity: [1, 0.5]
          filter: [blur(0px), blur(4px)]

      - element: form_container
        animation: scale_fade_in
        duration: 250ms
        delay: 50ms
        properties:
          opacity: [0, 1]
          transform: [scale(0.95), scale(1)]

      - element: first_input
        animation: focus_glow
        duration: 200ms
        delay: 300ms
        properties:
          box-shadow: [0, "0 0 8px rgba(59, 130, 246, 0.5)"]

  field_validation_success:
    name: "Field Passes Validation"
    total_duration: 400ms
    steps:
      - element: field_border
        animation: color_transition
        duration: 200ms
        properties:
          border-color: [gray-300, green-500]

      - element: checkmark_icon
        animation: draw_checkmark
        duration: 300ms
        delay: 100ms
        properties:
          stroke-dashoffset: [24, 0]

      - element: field_container
        animation: pulse_glow
        duration: 300ms
        delay: 0ms
        properties:
          box-shadow: ["0 0 0 rgba(34, 197, 94, 0)", "0 0 12px rgba(34, 197, 94, 0.4)", "0 0 0 rgba(34, 197, 94, 0)"]

  submit_success:
    name: "ADR Submit Success"
    total_duration: 1200ms
    steps:
      - element: submit_button
        animation: ripple_expand
        duration: 400ms
        properties:
          transform: [scale(1), scale(1.1), scale(1)]

      - element: form_container
        animation: shrink_fade
        duration: 200ms
        delay: 200ms
        properties:
          opacity: [1, 0]
          transform: [scale(1), scale(0.9)]

      - element: success_card
        animation: bounce_in
        duration: 400ms
        delay: 400ms
        easing: var(--ease-bounce)
        properties:
          opacity: [0, 1]
          transform: [scale(0.5), scale(1.05), scale(1)]

      - element: confetti_particles
        animation: burst
        duration: 600ms
        delay: 500ms
        properties:
          opacity: [1, 0]
          transform: [translateY(0), translateY(-100px)]

      - element: status_badges
        animation: stagger_fade_in
        duration: 200ms
        delay: 600ms
        stagger: 100ms
        properties:
          opacity: [0, 1]
          transform: [translateX(-10px), translateX(0)]
```

---

## Interaction Micro-States

### Hover States

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         HOVER STATE PROGRESSIONS                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  BUTTON HOVER (T=0 → T=150ms):                                          │
│                                                                          │
│  T=0ms           T=50ms          T=100ms         T=150ms                │
│  ┌────────┐      ┌────────┐      ┌────────┐      ┌────────┐             │
│  │ Submit │  →   │ Submit │  →   │ Submit │  →   │ Submit │             │
│  │ ░░░░░░ │      │ ▒▒▒▒▒▒ │      │ ▓▓▓▓▓▓ │      │ ██████ │             │
│  │ normal │      │ lighten│      │ elevate│      │ full   │             │
│  └────────┘      └────────┘      └────────┘      └────────┘             │
│  bg: 600         bg: 500         bg: 500         bg: 500                │
│  shadow: none    shadow: sm      shadow: md      shadow: lg             │
│  transform: 1    transform: 1    transform: 1.02 transform: 1.02        │
│                                                                          │
│                                                                          │
│  LIST ITEM HOVER:                                                        │
│                                                                          │
│  Normal                         Hovered                                  │
│  ┌──────────────────────┐      ┌──────────────────────┐                 │
│  │ ADR-042              │      │ ADR-042          ▶  │ ← indicator      │
│  │ GraphQL Federation   │  →   │ GraphQL Federation   │   appears       │
│  │ ●accepted  2h ago    │      │ ●accepted  2h ago    │                 │
│  └──────────────────────┘      └──────────────────────┘                 │
│  bg: transparent               bg: blue-50                               │
│  border-left: none             border-left: 3px blue-500                │
│                                                                          │
│                                                                          │
│  CARD HOVER (Depth Effect):                                              │
│                                                                          │
│  ┌─────────────────┐           ┌─────────────────┐                      │
│  │                 │           │                 │ ← shadow grows       │
│  │  Pattern Card   │    →      │  Pattern Card   │   card lifts         │
│  │                 │           │                 │   5px                │
│  └─────────────────┘           └─────────────────┘                      │
│                                 ╰────── shadow ──╯                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Focus States (Accessibility)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FOCUS STATE INDICATORS                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  KEYBOARD FOCUS RING:                                                    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                                                                  │   │
│  │    Unfocused               Tab-Focused                          │   │
│  │    ┌───────────┐          ╔═══════════╗                         │   │
│  │    │  Button   │    →     ║  Button   ║  ← 2px blue outline    │   │
│  │    └───────────┘          ╚═══════════╝    3px offset           │   │
│  │                                                                  │   │
│  │    outline: none          outline: 2px solid #3B82F6            │   │
│  │                           outline-offset: 3px                    │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  INPUT FIELD FOCUS:                                                      │
│                                                                          │
│  Unfocused                    Focused                                    │
│  ┌─────────────────────┐     ┌─────────────────────┐                   │
│  │ Enter title...      │     │ █                   │ ← cursor visible  │
│  │ label in field      │  →  │ Title *             │   label floated   │
│  └─────────────────────┘     └─────────────────────┘   border blue     │
│  border: gray-300            border: blue-500, 2px                      │
│  label: gray-400             label: blue-600, smaller                   │
│                              shadow: focus ring                          │
│                                                                          │
│  TAB ORDER VISUALIZATION:                                                │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Form with Tab Indices                                            │  │
│  │  ┌─────────────────────────────────────────────────────────────┐ │  │
│  │  │  [1] Title ────────────────────────────────────────────────│ │  │
│  │  │  [2] Type:  ○ ADR  ○ RFC  ○ Spike                          │ │  │
│  │  │  [3] Context ─────────────────────────────────────────────│ │  │
│  │  │  [4] Decision ────────────────────────────────────────────│ │  │
│  │  │  [5] [Cancel]  [6] [Save Draft]  [7] [Submit]             │ │  │
│  │  └─────────────────────────────────────────────────────────────┘ │  │
│  │                                                                   │  │
│  │  Tab order follows logical reading order (top-to-bottom,         │  │
│  │  left-to-right) with skip links for screen readers.              │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 3.1.0 | 2025-12-30 | Claude | Added dynamic state transitions, DAG paths, animation choreography |

**Companion Document**: UC_DEVELOPER.md (static wireframes)
**Animation Implementation**: See lib/indrajaal_web/assets/css/animations.css
**F# Terminal.Gui Equivalent**: lib/cepaf/src/Cepaf/Cockpit/Animations.fs
