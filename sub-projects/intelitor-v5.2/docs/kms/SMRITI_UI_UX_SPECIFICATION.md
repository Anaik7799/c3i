# Z-KMS UI/UX Specification

## Overview

This document defines the user interface and experience specifications for Z-KMS, incorporating best practices from Obsidian, Heptabase, AFFiNE, Logseq, and other leading Zettelkasten systems.

---

## 1. Layout Architecture

### 1.1 Three-Panel Layout

```
┌─────────────────────────────────────────────────────────────────────────┐
│ ┌─────────────┐  ┌────────────────────────────────┐  ┌───────────────┐ │
│ │             │  │                                │  │               │ │
│ │   SIDEBAR   │  │         MAIN CONTENT           │  │   PREVIEW /   │ │
│ │             │  │                                │  │   BACKLINKS   │ │
│ │  Navigation │  │   Editor / Graph / Search      │  │               │ │
│ │  Tree       │  │                                │  │   Context     │ │
│ │  Clusters   │  │                                │  │   Panel       │ │
│ │  Tags       │  │                                │  │               │ │
│ │             │  │                                │  │               │ │
│ │  ─────────  │  │                                │  │               │ │
│ │             │  │                                │  │               │ │
│ │  Quick      │  │                                │  │               │ │
│ │  Actions    │  │                                │  │               │ │
│ │             │  │                                │  │               │ │
│ └─────────────┘  └────────────────────────────────┘  └───────────────┘ │
│       240px              flex-grow                        320px        │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Responsive Breakpoints

| Breakpoint | Behavior |
|------------|----------|
| Desktop (>1200px) | Full 3-panel layout |
| Tablet (768-1200px) | Sidebar collapsible, 2-panel |
| Mobile (<768px) | Single panel, bottom navigation |

---

## 2. Color System

### 2.1 Theme Colors (Dark Mode - Default)

```css
:root {
  /* Background layers */
  --bg-base: #1e1e2e;        /* Main background */
  --bg-surface: #282839;     /* Cards, panels */
  --bg-elevated: #313244;    /* Dropdowns, modals */
  --bg-hover: #3b3b54;       /* Hover states */

  /* Text hierarchy */
  --text-primary: #cdd6f4;   /* Main text */
  --text-secondary: #a6adc8; /* Muted text */
  --text-tertiary: #6c7086;  /* Disabled text */

  /* Accents */
  --accent-primary: #89b4fa; /* Links, primary actions */
  --accent-secondary: #cba6f7; /* Tags, badges */
  --accent-success: #a6e3a1; /* Success states */
  --accent-warning: #f9e2af; /* Warnings */
  --accent-error: #f38ba8;   /* Errors, rotting */

  /* Entropy colors */
  --entropy-fresh: #a6e3a1;  /* 0.0 - 0.3 */
  --entropy-aging: #f9e2af;  /* 0.3 - 0.7 */
  --entropy-rotting: #f38ba8; /* 0.7 - 1.0 */

  /* Graph colors */
  --graph-node-default: #89b4fa;
  --graph-edge-wiki: #6c7086;
  --graph-edge-semantic: #cba6f7;
  --graph-node-selected: #f5c2e7;
}
```

### 2.2 Light Mode Variant

```css
:root.light {
  --bg-base: #eff1f5;
  --bg-surface: #dce0e8;
  --bg-elevated: #ccd0da;
  --text-primary: #4c4f69;
  --text-secondary: #6c6f85;
  --accent-primary: #1e66f5;
  /* ... rest adapted for light theme */
}
```

---

## 3. Typography

### 3.1 Font Stack

```css
:root {
  /* UI Font */
  --font-ui: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;

  /* Editor Font (monospace for code, proportional for prose) */
  --font-editor: "JetBrains Mono", "Fira Code", monospace;
  --font-prose: "Source Serif Pro", Georgia, serif;

  /* Sizes */
  --font-xs: 0.75rem;    /* 12px */
  --font-sm: 0.875rem;   /* 14px */
  --font-base: 1rem;     /* 16px */
  --font-lg: 1.125rem;   /* 18px */
  --font-xl: 1.25rem;    /* 20px */
  --font-2xl: 1.5rem;    /* 24px */
  --font-3xl: 2rem;      /* 32px */

  /* Line heights */
  --line-tight: 1.25;
  --line-normal: 1.5;
  --line-relaxed: 1.75;
}
```

### 3.2 Text Styles

| Element | Font | Size | Weight | Color |
|---------|------|------|--------|-------|
| H1 (Zettel Title) | UI | 2xl | 600 | primary |
| H2 | UI | xl | 600 | primary |
| H3 | UI | lg | 500 | primary |
| Body | Prose | base | 400 | primary |
| Code | Editor | sm | 400 | secondary |
| Tag | UI | xs | 500 | secondary |
| Caption | UI | sm | 400 | tertiary |

---

## 4. Component Library

### 4.1 Zettel Card

```
┌────────────────────────────────────────────────────────┐
│ ● Functional Programming Concepts           [Atomic]  │
│ ────────────────────────────────────────────────────── │
│ Pure functions avoid side effects and always          │
│ return the same output for given inputs...            │
│                                                        │
│ #programming  #functional  #concepts                   │
│ ────────────────────────────────────────────────────── │
│ ◉ Fresh (12%)   │   4 links   │   Updated 2h ago      │
└────────────────────────────────────────────────────────┘
```

**States:**
- Default: bg-surface, border-none
- Hover: bg-hover, shadow-md
- Selected: border-accent-primary (2px)
- Rotting: border-left entropy-rotting (4px)

### 4.2 Search Bar

```
┌────────────────────────────────────────────────────────┐
│ 🔍  Search Zettels...                           ⌘K    │
└────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────┐
│ 🔍  pattern matching                                   │
├────────────────────────────────────────────────────────┤
│ 📄 Pattern Matching in Elixir      #elixir #patterns  │
│     ...using <mark>pattern matching</mark> to...      │
├────────────────────────────────────────────────────────┤
│ 📄 Rust Pattern Matching           #rust #patterns    │
│     ...exhaustive <mark>pattern matching</mark>...    │
├────────────────────────────────────────────────────────┤
│ 📄 Functional Design Patterns      #fp #design        │
│     ...common <mark>patterns</mark> include...        │
└────────────────────────────────────────────────────────┘
```

### 4.3 Tag Badge

```
┌─────────────────┐   ┌─────────────────┐
│ #architecture   │   │ #safety         │
└─────────────────┘   └─────────────────┘
    Default              Highlighted

Styles:
- Background: accent-secondary at 20% opacity
- Text: accent-secondary
- Border-radius: 4px
- Padding: 2px 8px
```

### 4.4 Entropy Indicator

```
Fresh:    ◉━━━━━━━━━━  12%   (Green)
Aging:    ◉━━━━━━━━━━  55%   (Yellow)
Rotting:  ◉━━━━━━━━━━  87%   (Red)

Alternative (Pill):
┌─────────┐  ┌─────────┐  ┌─────────┐
│ Fresh   │  │ Aging   │  │Rotting  │
└─────────┘  └─────────┘  └─────────┘
  (Green)     (Yellow)      (Red)
```

### 4.5 Link Autocomplete

```
User types: [[

┌────────────────────────────────────────────────────────┐
│ 🔗 Link to Zettel                                      │
├────────────────────────────────────────────────────────┤
│ Recent:                                                 │
│   📄 STAMP Safety Constraints                          │
│   📄 Holon Architecture                                │
│   📄 Pattern Matching in Elixir                        │
├────────────────────────────────────────────────────────┤
│ Type to search...                                       │
└────────────────────────────────────────────────────────┘

User types: [[arch

┌────────────────────────────────────────────────────────┐
│ 🔍 arch                                          3 ⏎   │
├────────────────────────────────────────────────────────┤
│   📄 Holon Architecture             #architecture      │
│   📄 System Architecture Overview   #architecture      │
│   📄 Search Architecture            #search #design    │
├────────────────────────────────────────────────────────┤
│ ➕ Create "arch" as new Zettel                         │
└────────────────────────────────────────────────────────┘
```

---

## 5. Views

### 5.1 Editor View

```
┌─────────────────────────────────────────────────────────────────────────┐
│ ┌─ Breadcrumb ─────────────────────────────────────────────────────────┐│
│ │ Clusters > Architecture > Holon Architecture                         ││
│ └──────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│ ┌─ Title ──────────────────────────────────────────────────────────────┐│
│ │ # Holon Architecture                                        [Edit]   ││
│ └──────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│ ┌─ Metadata Bar ───────────────────────────────────────────────────────┐│
│ │ 📂 Architecture  │  📅 Updated 3d ago  │  ◉ Aging 42%  │  4 links    ││
│ └──────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│ ┌─ Tags ───────────────────────────────────────────────────────────────┐│
│ │ #architecture  #holon  #biomorphic  #fractal              [+ Add]    ││
│ └──────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│ ┌─ Content ────────────────────────────────────────────────────────────┐│
│ │                                                                       ││
│ │  The Holon Architecture defines a self-contained, self-replicating   ││
│ │  unit of functionality that can operate independently or as part     ││
│ │  of a larger system.                                                  ││
│ │                                                                       ││
│ │  ## Core Principles                                                   ││
│ │                                                                       ││
│ │  - **Sovereignty**: Each holon owns its state via [[SQLite]]         ││
│ │  - **Regeneration**: Can rebuild from [[Immutable Register]]         ││
│ │  - **Evolution**: Tracked in [[DuckDB]] history                      ││
│ │                                                                       ││
│ └──────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│ ┌─ Backlinks ──────────────────────────────────────────────────────────┐│
│ │ 🔗 5 Zettels link here:                                              ││
│ │   📄 STAMP Constraints         "...respecting [[Holon Architecture]]"││
│ │   📄 Founder's Directive       "...aligned with [[Holon Architecture"││
│ │   📄 System Overview           "...built on [[Holon Architecture]]..." ││
│ │   [Show 2 more...]                                                    ││
│ └──────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Graph View

```
┌─────────────────────────────────────────────────────────────────────────┐
│ ┌─ Toolbar ────────────────────────────────────────────────────────────┐│
│ │ [🔍 Search]  [📊 Layout ▼]  [🎨 Color by ▼]  [📏 Filter ▼]  [⟳ Reset]││
│ └──────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│ ┌─ Graph Canvas ───────────────────────────────────────────────────────┐│
│ │                                                                       ││
│ │                    ●───●                                              ││
│ │                   /     \                                             ││
│ │              ●───●       ●───●                                        ││
│ │               \   \     /   /                                         ││
│ │                ●   ●───●   ●                                          ││
│ │               /               \                                       ││
│ │          ●───●                 ●───●                                  ││
│ │                                                                       ││
│ │  [+] Zoom In  [−] Zoom Out  [⬚] Fit  [◎] Center                      ││
│ └──────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│ ┌─ Legend ─────────────────────────────────────────────────────────────┐│
│ │ Entropy: ● Fresh  ● Aging  ● Rotting                                 ││
│ │ Size:    ● Atomic ● Molecular ● Organism ● Ecosystem                 ││
│ │ Edges:   ─ Wiki   ╌ Semantic  ┄ Code                                 ││
│ └──────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Entropy Dashboard

```
┌─────────────────────────────────────────────────────────────────────────┐
│ ┌─ Header ─────────────────────────────────────────────────────────────┐│
│ │ 📊 Knowledge Freshness Dashboard                   Last updated: 2m  ││
│ └──────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│ ┌─ Overview Cards ─────────────────────────────────────────────────────┐│
│ │ ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐          ││
│ │ │   523     │  │   156     │  │   287     │  │    80     │          ││
│ │ │  Total    │  │  Fresh    │  │  Aging    │  │ Rotting   │          ││
│ │ │ Zettels   │  │   30%     │  │   55%     │  │   15%     │          ││
│ │ └───────────┘  └───────────┘  └───────────┘  └───────────┘          ││
│ └──────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│ ┌─ Charts ─────────────────────────────────────────────────────────────┐│
│ │ ┌─ Distribution ──────────┐  ┌─ Trend (30 days) ──────────────────┐ ││
│ │ │     ████                │  │                    ___             │ ││
│ │ │     ████████            │  │               ___/                 │ ││
│ │ │     ████████████        │  │          ___/                      │ ││
│ │ │     Fresh Aging Rotting │  │     ___/                           │ ││
│ │ └─────────────────────────┘  └────────────────────────────────────┘ ││
│ └──────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│ ┌─ Priority Review List ───────────────────────────────────────────────┐│
│ │ Zettels needing attention (sorted by entropy):                       ││
│ │ ┌────────────────────────────────────────────────────────────────┐  ││
│ │ │ 🔴 API Design Patterns          94%  │ Last updated: 45 days   │  ││
│ │ ├────────────────────────────────────────────────────────────────┤  ││
│ │ │ 🔴 Database Migration Guide     89%  │ Last updated: 38 days   │  ││
│ │ ├────────────────────────────────────────────────────────────────┤  ││
│ │ │ 🟠 Testing Best Practices       78%  │ Last updated: 25 days   │  ││
│ │ └────────────────────────────────────────────────────────────────┘  ││
│ └──────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Interactions

### 6.1 Keyboard Shortcuts

| Shortcut | Action | Context |
|----------|--------|---------|
| `Cmd/Ctrl + N` | New Zettel | Global |
| `Cmd/Ctrl + K` | Quick search | Global |
| `Cmd/Ctrl + /` | Toggle sidebar | Global |
| `Cmd/Ctrl + G` | Open graph view | Global |
| `Cmd/Ctrl + E` | Toggle edit/preview | Editor |
| `Cmd/Ctrl + S` | Save (force) | Editor |
| `Cmd/Ctrl + B` | Bold | Editor |
| `Cmd/Ctrl + I` | Italic | Editor |
| `[[` | Link autocomplete | Editor |
| `#` | Tag autocomplete | Editor |
| `Esc` | Close modal/panel | Modal |
| `↑/↓` | Navigate list | Search/Autocomplete |
| `Enter` | Select item | Search/Autocomplete |

### 6.2 Gestures (Touch)

| Gesture | Action |
|---------|--------|
| Pinch | Zoom graph |
| Two-finger pan | Pan graph |
| Long press node | Show context menu |
| Swipe left on card | Quick actions (edit, delete) |
| Pull down | Refresh |

### 6.3 Animations

```css
/* Smooth transitions */
.transition-default {
  transition: all 150ms ease-out;
}

/* Card hover lift */
.card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

/* Graph node pulse on selection */
@keyframes pulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.1); }
}
.node-selected { animation: pulse 0.5s ease-in-out; }

/* Search results fade in */
.search-result {
  opacity: 0;
  animation: fadeIn 200ms ease-out forwards;
}
@keyframes fadeIn {
  to { opacity: 1; }
}
```

---

## 7. Accessibility

### 7.1 WCAG 2.1 AA Compliance

- **Color Contrast**: Minimum 4.5:1 for text, 3:1 for UI elements
- **Focus Indicators**: Visible focus ring on all interactive elements
- **Screen Reader**: ARIA labels on all controls
- **Keyboard Navigation**: All features accessible without mouse
- **Reduced Motion**: Respect `prefers-reduced-motion`

### 7.2 ARIA Patterns

```html
<!-- Search combobox -->
<div role="combobox" aria-expanded="true" aria-haspopup="listbox">
  <input type="text" aria-label="Search Zettels" aria-autocomplete="list" />
  <ul role="listbox" aria-label="Search results">
    <li role="option" aria-selected="true">Result 1</li>
    <li role="option">Result 2</li>
  </ul>
</div>

<!-- Graph -->
<div role="application" aria-label="Knowledge graph">
  <button aria-label="Zoom in">+</button>
  <button aria-label="Zoom out">-</button>
  <!-- Nodes are buttons with aria-label for title -->
  <button role="button" aria-label="Zettel: Holon Architecture">●</button>
</div>
```

---

## 8. Responsive Behavior

### 8.1 Desktop (>1200px)

- Full 3-panel layout
- All features visible
- Graph fills main panel

### 8.2 Tablet (768-1200px)

- Sidebar collapses to icons
- Right panel toggleable
- Touch-friendly button sizes (44px minimum)

### 8.3 Mobile (<768px)

- Single panel view with bottom navigation
- Swipe to switch between views (Editor, Graph, Search)
- Floating action button for new Zettel
- Simplified graph view (limited nodes)

```
Mobile Navigation Bar:
┌────────────────────────────────────────────┐
│  📝        🔍        🕸️        📊        ⚙️  │
│ Editor   Search    Graph   Dashboard  Settings │
└────────────────────────────────────────────┘
```

---

## 9. Loading & Empty States

### 9.1 Loading States

```
Skeleton Loading (Search Results):
┌────────────────────────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░              │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░     │
│ ░░░░░░░░░░░░░                             │
├────────────────────────────────────────────┤
│ ░░░░░░░░░░░░░░░░░░░░░░                    │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░       │
│ ░░░░░░░░░░░░░░░                           │
└────────────────────────────────────────────┘

Graph Loading:
┌────────────────────────────────────────────┐
│                                            │
│            ⟳ Loading graph...              │
│              523 nodes                     │
│                                            │
└────────────────────────────────────────────┘
```

### 9.2 Empty States

```
No Zettels:
┌────────────────────────────────────────────┐
│                                            │
│               📝                           │
│                                            │
│        No Zettels yet                      │
│                                            │
│   Start building your knowledge base       │
│   by creating your first Zettel.           │
│                                            │
│        [+ Create Zettel]                   │
│                                            │
└────────────────────────────────────────────┘

No Search Results:
┌────────────────────────────────────────────┐
│                                            │
│               🔍                           │
│                                            │
│     No results for "quantum"               │
│                                            │
│   Try different keywords or create a       │
│   new Zettel with this topic.              │
│                                            │
│   [+ Create "quantum" Zettel]              │
│                                            │
└────────────────────────────────────────────┘
```

---

## 10. Error States

```
API Error:
┌────────────────────────────────────────────┐
│ ⚠️ Connection Error                        │
│                                            │
│ Unable to reach the Z-KMS server.          │
│ Your changes are saved locally.            │
│                                            │
│ [Retry]  [Work Offline]                    │
└────────────────────────────────────────────┘

Validation Error (inline):
Title: [                                    ]
       ⚠️ Title is required

Content: [                                  ]
         ⚠️ Content must be at least 10 characters
```

---

## Related Documents

- `docs/kms/SMRITI_COMPREHENSIVE_USECASES.md` - Use Cases
- `docs/kms/SMRITI_FEATURE_SPECIFICATIONS.md` - Feature Specs
- `lib/cepaf/src/Cepaf.Smriti.Client/` - Elmish Implementation
