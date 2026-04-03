# Indrajaal Theme Ontology: The "Aero-GPU" Fractal System
**Version**: 1.0.0-MATH | **Paradigm**: Category Theory + Fractal Geometry | **Basis**: `tview`

---

## 0.0 Abstract Abstract

This document defines the **Ontology** of the Indrajaal "Orbital Command" theme. It moves beyond simple style guides (lists of colors) to define the **Algebra of Visual Composition**.

We treat the User Interface as a **Category ($\mathcal{C}_{UI}$)** where:
1.  **Objects** are visual primitives (Runes, Colors, Spaces).
2.  **Morphisms** are the transformation functions (Rendering, State Changes).
3.  **Fractals** define the self-similar structure from the atomic pixel to the full dashboard.

---

## 1.0 The Chromatic Manifold ($\mathcal{V}_{color}$)

We do not define static colors. We define **Signal Vectors** within a 3D Color Space.

### 1.1 The Spectral Basis
The aesthetic relies on high-contrast "Neon" signals against a "Void" background.

$$ \text{Color} = \vec{v} \in \{R, G, B, \alpha\} $$

| Semantic Vector | Hex Vector | Perception | Use Case |
| :--- | :--- | :--- | :--- |
| $\vec{v}_{void}$ | `#000000` | Infinite Depth | Backgrounds |
| $\vec{v}_{hud}$ | `#00afff` | Electric Blue | Borders, Labels, Static Info |
| $\vec{v}_{warn}$ | `#ffaa00` | Sodium Amber | Warnings, Transitions, Engaging |
| $\vec{v}_{crit}$ | `#ff0000` | Reactor Red | Errors, Kill Switches, Weapons Free |
| $\vec{v}_{safe}$ | `#00ff00` | Radium Green | Success, Nominal, Stable |
| $\vec{v}_{dim}$ | `#444444` | Titanium Grey | Inactive, Locked, Historic |

### 1.2 The Gradient Morphism ($f_{grad}$)
To simulate GPU shading in a TUI, we apply a dithering function over a discrete domain (cells).

$$ f_{grad}(\vec{start}, \vec{end}, n) = \sum_{i=0}^{n} (\vec{start} \times (1 - \frac{i}{n})) + (\vec{end} \times \frac{i}{n}) $$

**Visual Realization:**
`[#ff0000]█[#ff4400]█[#ff8800]█[#ffcc00]▓[#ffff00]▒[#444444]░`
*(Transition: Solid Red $\to$ Orange $\to$ Yellow $\to$ Texture Fade $\to$ Void)*

---

## 2.0 The Glyphic Monoid ($\mathcal{M}_{glyph}$)

The "GPU" look is achieved by combining standard ASCII with Unicode Block Elements to create **Pseudo-Volumetric** textures.

### 2.1 The Texture Monoid
A texture $T$ is a monoid $(M, \oplus, \epsilon)$ where operation $\oplus$ is visual superposition.

*   **Solid**: `█` (100% Opacity)
*   **High-Dense**: `▓` (75% Opacity)
*   **Mid-Dense**: `▒` (50% Opacity)
*   **Low-Dense**: `░` (25% Opacity)
*   **Void**: ` ` (0% Opacity)

### 2.2 Wireframe Topology
We use Box-Drawing characters to define the "Chassis" of the interface.

*   **Rigid**: `╔═╗`, `╠═╣` (Structural beams)
*   **Connective**: `───`, `│` (Data pipes)
*   **Terminator**: `└─`, `┘` (End of stream)

---

## 3.0 The Fractal Holarchy (Scale Invariance)

The system is **Fractal**: The rules that apply to a single character also apply to a panel, a screen, and the entire application.

### 3.1 Level 0: The Quantum (The Cell)
*   **Structure**: `[Color][Glyph][Reset]`
*   **Example**: `[#00ff00]█[white]`
*   **Function**: The smallest unit of state display.

### 3.2 Level 1: The Molecular (The Bar)
*   **Structure**: A sequence of Quantums.
*   **Logic**: $Length \times \frac{Current}{Total}$
*   **Aesthetic**: Gradient Morphism applied to the sequence.
*   **Example**: `[[#00ff00]|||||[white].....]` (CPU Usage)

### 3.3 Level 2: The Organ (The Component)
*   **Structure**: A bounded manifold containing Molecules.
*   **Logic**: `Border(Title) + Content`
*   **Example**: The **Safety Interlock Modal**. It contains a Title (Molecule), a Description (Molecule), and a Progress Bar (Molecule).

### 3.4 Level 3: The System (The Dashboard)
*   **Structure**: A grid layout of Organs.
*   **Logic**: `Grid(Row, Col) -> Component`
*   **Example**: The **Flight Control Screen**. It arranges the Runbook List (Organ), Telemetry Log (Organ), and Status Header (Organ).

---

## 4.0 Category Theory Mapping ($\mathcal{C}_{UI}$)

We define the system dynamics using functors and morphisms.

### 4.1 The State Functor ($F_{state}$)
This functor maps the **System State Category** (Logic) to the **Visual Category** (UI).

$$ F_{state}: \mathcal{C}_{Logic} \to \mathcal{C}_{Visual} $$

*   **Object Mapping**:
    *   `State.Nominal` $\to$ `Color.Green`
    *   `State.Warning` $\to$ `Color.Amber`
    *   `State.Critical` $\to$ `Color.Red`
    *   `State.Locked` $\to$ `Color.Grey + Texture.Striped`

*   **Morphism Mapping**:
    *   `Logic.Transition(Start -> End)` $\to$ `Visual.Animation(FadeOut -> FadeIn)`

### 4.2 The Severity Isomorphism
There is a direct, one-to-one mapping (Isomorphism) between **Impact** and **Visual Intensity**.

$$ Intensity(UI) \cong Impact(Business) $$

*   **Low Impact** (Log rotation) $\cong$ Thin borders, Grey/White text, No shading.
*   **High Impact** (Database Drop) $\cong$ Thick borders, Red/Amber gradients, Blinking text, Modal overlays.

---

## 5.0 Implementation Spec (tview)

How this ontology translates to actual code constructs.

### 5.1 Color Tokens (The Palette)
```elixir
@colors %{
  void: "black",
  hud:  "#00afff",  # Electric Blue
  warn: "#ffaa00",  # Sodium Amber
  crit: "#ff0000",  # Reactor Red
  safe: "#00ff00",  # Radium Green
  dim:  "#444444"   # Titanium Grey
}
```

### 5.2 Shaders (The Render Functions)
```elixir
# The Gradient Morphism Implementation
def render_bar(percent) do
  cond do
    percent > 90 -> "[#ff0000]█████████▓" # Critical Heat
    percent > 70 -> "[#ffaa00]██████▓▓▒▒" # Warning Heat
    true         -> "[#00ff00]████▓▓▒▒░░" # Nominal Cool
  end
end
```

### 5.3 Component Taxonomy
1.  **TelemetryTable**: High-density data grid.
2.  **HoloModal**: Floating overlay with drop-shadow effects (simulated via block chars).
3.  **Sparkline**: ASCII trend chart.
4.  **Interlock**: A specialized form requiring "Hold-to-Confirm" logic.

---

## 6.0 Visual Proof of Concept

```
[#00afff]╔══════════════════════════════════════════════╗[white]
[#00afff]║[white]  [#ffff00]⚡ SYSTEM ENTROPY MONITOR[white]                   [#00afff]║[white]
[#00afff]╠══════════════════════════════════════════════╣[white]
[#00afff]║[white]  [#888888]NODE_01[white]  [#00ff00]NOMINAL[white]   [#00ff00]████▓▓▒░░░[white]  24%  [#00afff]║[white]
[#00afff]║[white]  [#888888]NODE_02[white]  [#ffaa00]WARNING[white]   [#ffaa00]████████▓▒[white]  78%  [#00afff]║[white]
[#00afff]║[white]  [#888888]NODE_03[white]  [#ff0000]CRITICAL[white]  [#ff0000]██████████[white]  99%  [#00afff]║[white]
[#00afff]╚══════════════════════════════════════════════╝[white]
```
*Figure 1: Application of the Chromatic Manifold and Texture Monoid to a Dashboard Organ.*

```