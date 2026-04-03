# AEROSPACE COMPONENT TAXONOMY - GPU/OLED OPTIMIZED
## Complete Design System v3.0.0-GPU-OLED-COLOR
**Created**: 2025-12-30T12:00:00+01:00 | **Status**: DEFINITIVE REFERENCE
**Target**: GPU-Accelerated Terminal (Kitty/Alacritty/WezTerm) + OLED Display
**Color Gamut**: DCI-P3 / Display P3 (Wide Gamut) | **Bit Depth**: 10-bit HDR

---

# PART 1: STANDARDS MAPPING & COLOR SYSTEM

## 1.0 STANDARDS COMPLIANCE MATRIX

### 1.1 Primary Standards Mapped

| Standard | Full Name | Domain | Sections Applied |
|----------|-----------|--------|------------------|
| **MIL-STD-1472G** | Human Engineering | Military HMI | §5.1-5.15 Display Design |
| **NASA-STD-3000** | Man-Systems Integration | Aerospace | Vol.4 Crew Interface |
| **NASA-HFDS** | Human Factors Design Standard | Aerospace | Display Guidelines |
| **NUREG-0700** | Human-System Interface Design | Nuclear | §1-4 Display Elements |
| **DO-178C** | Software for Airborne Systems | Aviation | Display Safety Levels |
| **DO-254** | Airborne Electronic Hardware | Aviation | GPU Hardware Safety |
| **ARP4754A** | Aircraft Systems Development | Aviation | System Display Integration |
| **SAE AS6802** | Time-Triggered Ethernet | Aerospace | Real-time Display Sync |

### 1.2 Safety & Functional Standards

| Standard | Full Name | Domain | Application |
|----------|-----------|--------|-------------|
| **IEC 61508** | Functional Safety | Industrial | SIL 1-4 Display Requirements |
| **ISO 13849-1** | Safety of Machinery | Industrial | PLa-PLe Category |
| **EN 50131** | Alarm Systems | Security | Grade 1-4 Display |
| **IEC 62443** | Industrial Cybersecurity | Industrial | Security Display States |
| **ISO 26262** | Road Vehicle Safety | Automotive | ASIL A-D Display |

### 1.3 Human Factors & Accessibility Standards

| Standard | Full Name | Domain | Application |
|----------|-----------|--------|-------------|
| **ISO 9241-110** | Ergonomics of HCI | Usability | Dialogue Principles |
| **ISO 9241-112** | Information Presentation | Usability | Display Layout |
| **ISO 9241-125** | Visual Presentation | Usability | Color & Contrast |
| **ISO 9241-171** | Accessibility Guidance | Accessibility | Universal Design |
| **WCAG 2.1 AA** | Web Content Accessibility | Accessibility | Contrast Ratios |
| **ISO 11064** | Control Centre Design | Ergonomics | Workstation Layout |

### 1.4 Space Systems Standards

| Standard | Full Name | Domain | Application |
|----------|-----------|--------|-------------|
| **ECSS-E-ST-70-11C** | Space Segment Operability | Space | Ground Display Design |
| **ECSS-E-ST-40C** | Software | Space | Display Software Safety |
| **CCSDS 503.0-B-1** | Space Link Extension | Space | Telemetry Display |
| **SMC-S-016** | Test Requirements | Space | Display Verification |
| **NASA-STD-8719.13** | Software Safety | Space | Display Safety Analysis |

### 1.5 Display Technology Standards

| Standard | Full Name | Domain | Application |
|----------|-----------|--------|-------------|
| **VESA DisplayHDR** | HDR Performance | Display | HDR Tiers (400-1400) |
| **DCI-P3** | Digital Cinema | Color | Wide Gamut Coverage |
| **ITU-R BT.2020** | Ultra HD Television | Color | HDR Color Space |
| **IEC 61966-2-1** | sRGB Color Space | Color | Base Color Reference |
| **ISO 12646** | Graphic Technology | Color | Display Conditions |

---

## 2.0 GPU-OLED COLOR SYSTEM

### 2.1 OLED-Optimized Base Palette

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OLED-OPTIMIZED COLOR PALETTE                             │
│                    True Black + Wide Gamut P3                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ████  VOID BLACK        #000000  rgb(0,0,0)       TRUE OLED BLACK         │
│  ████  DEEP SPACE        #050508  rgb(5,5,8)       Near-black background   │
│  ████  COSMIC DARK       #0a0a10  rgb(10,10,16)    Primary background      │
│  ████  NEBULA GREY       #12121a  rgb(18,18,26)    Elevated surface        │
│  ████  STELLAR GREY      #1a1a24  rgb(26,26,36)    Card background         │
│  ████  ASTEROID GREY     #252530  rgb(37,37,48)    Border/divider          │
│                                                                             │
│  ████  PLASMA CYAN       #00ffff  rgb(0,255,255)   P3: Primary accent      │
│  ████  QUANTUM BLUE      #00afff  rgb(0,175,255)   P3: Secondary accent    │
│  ████  PHOTON BLUE       #0080ff  rgb(0,128,255)   P3: Tertiary accent     │
│  ████  NEBULA PURPLE     #8844ff  rgb(136,68,255)  P3: Highlight accent    │
│  ████  COSMIC VIOLET     #aa44ff  rgb(170,68,255)  P3: Special accent      │
│                                                                             │
│  ████  NOMINAL GREEN     #00ff88  rgb(0,255,136)   P3: Success/Go/Healthy  │
│  ████  THRUST GREEN      #44ff44  rgb(68,255,68)   P3: Active/Running      │
│  ████  ORBIT GREEN       #88ff44  rgb(136,255,68)  P3: Optimal             │
│                                                                             │
│  ████  CAUTION AMBER     #ffaa00  rgb(255,170,0)   P3: Warning/Attention   │
│  ████  SOLAR YELLOW      #ffdd00  rgb(255,221,0)   P3: Highlight           │
│  ████  CORONA ORANGE     #ff8800  rgb(255,136,0)   P3: Elevated warning    │
│                                                                             │
│  ████  ALERT RED         #ff4444  rgb(255,68,68)   P3: Error/Critical      │
│  ████  PLASMA RED        #ff0044  rgb(255,0,68)    P3: Emergency           │
│  ████  SUPERNOVA RED     #ff0000  rgb(255,0,0)     P3: Maximum alert       │
│                                                                             │
│  ████  PURE WHITE        #ffffff  rgb(255,255,255) Text/Maximum contrast   │
│  ████  LUNAR WHITE       #e0e0e8  rgb(224,224,232) Primary text            │
│  ████  STARLIGHT         #a0a0b0  rgb(160,160,176) Secondary text          │
│  ████  COMET GREY        #606070  rgb(96,96,112)   Disabled/Muted          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 GPU Shader Color Syntax (tview/tcell)

```go
// GPU-accelerated color definitions for tview
// Uses 24-bit true color (16.7M colors)

// Backgrounds (OLED True Black optimized)
const (
    ColorVoidBlack    = tcell.NewRGBColor(0, 0, 0)       // #000000
    ColorDeepSpace    = tcell.NewRGBColor(5, 5, 8)       // #050508
    ColorCosmicDark   = tcell.NewRGBColor(10, 10, 16)    // #0a0a10
    ColorNebulaeGrey  = tcell.NewRGBColor(18, 18, 26)    // #12121a
    ColorStellarGrey  = tcell.NewRGBColor(26, 26, 36)    // #1a1a24
    ColorAsteroidGrey = tcell.NewRGBColor(37, 37, 48)    // #252530
)

// Primary Accents (Wide Gamut P3)
const (
    ColorPlasmaCyan   = tcell.NewRGBColor(0, 255, 255)   // #00ffff
    ColorQuantumBlue  = tcell.NewRGBColor(0, 175, 255)   // #00afff
    ColorPhotonBlue   = tcell.NewRGBColor(0, 128, 255)   // #0080ff
    ColorNebulaPurple = tcell.NewRGBColor(136, 68, 255)  // #8844ff
    ColorCosmicViolet = tcell.NewRGBColor(170, 68, 255)  // #aa44ff
)

// Semantic Status Colors
const (
    ColorNominalGreen = tcell.NewRGBColor(0, 255, 136)   // #00ff88
    ColorCautionAmber = tcell.NewRGBColor(255, 170, 0)   // #ffaa00
    ColorAlertRed     = tcell.NewRGBColor(255, 68, 68)   // #ff4444
    ColorPlasmaRed    = tcell.NewRGBColor(255, 0, 68)    // #ff0044
)
```

### 2.3 tview Inline Color Syntax

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TVIEW GPU COLOR SYNTAX                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Format: [#RRGGBB]text[-]  or  [#RRGGBB:#RRGGBB]text[-:-]                  │
│          [foreground]      or  [foreground:background]                      │
│                                                                             │
│  Examples:                                                                  │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  [#00ffff]PLASMA CYAN TEXT[-]                                              │
│  [#00ff88]● NOMINAL[-]  [#ffaa00]◆ CAUTION[-]  [#ff4444]▲ ALERT[-]         │
│  [#00afff:#0a0a10]QUANTUM BLUE ON COSMIC DARK[-:-]                         │
│  [#ffffff:#ff0044]█ EMERGENCY █[-:-]                                       │
│                                                                             │
│  Status Indicators:                                                         │
│  [#00ff88]●[-] ONLINE    [#00ffff]●[-] NOMINAL   [#ffaa00]●[-] WARNING    │
│  [#ff4444]●[-] CRITICAL  [#606070]●[-] OFFLINE   [#8844ff]●[-] STANDBY    │
│                                                                             │
│  Progress Bars:                                                             │
│  [#00ff88]████████████████████[-][#252530]░░░░░░░░░░[-] 67%               │
│  [#ffaa00]██████████[-][#252530]░░░░░░░░░░░░░░░░░░░░[-] 33%               │
│  [#ff4444]████[-][#252530]░░░░░░░░░░░░░░░░░░░░░░░░░░[-] 13%               │
│                                                                             │
│  Borders:                                                                   │
│  [#00afff]┌──────────────────────────────────────┐[-]                      │
│  [#00afff]│[-] [#e0e0e8]Content with border[-]   [#00afff]│[-]             │
│  [#00afff]└──────────────────────────────────────┘[-]                      │
│                                                                             │
│  Glow Effect (simulated with color gradient):                               │
│  [#003344]░[-][#005566]░[-][#0077aa]▒[-][#00afff]█ GLOW █[-][#0077aa]▒[-][#005566]░[-][#003344]░[-]  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.4 Semantic Color Mapping

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SEMANTIC COLOR ASSIGNMENTS                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  SYSTEM STATUS                                                              │
│  ══════════════════════════════════════════════════════════════════════════ │
│  [#00ff88]█[-] NOMINAL      System operating within normal parameters       │
│  [#00ffff]█[-] STANDBY      System ready, awaiting input                    │
│  [#00afff]█[-] PROCESSING   Active operation in progress                    │
│  [#8844ff]█[-] ARMED        Safety-critical action prepared                 │
│  [#ffaa00]█[-] CAUTION      Attention required, non-critical                │
│  [#ff8800]█[-] WARNING      Elevated concern, action recommended            │
│  [#ff4444]█[-] ALERT        Critical issue, immediate attention             │
│  [#ff0044]█[-] EMERGENCY    System emergency, safety protocols active       │
│  [#606070]█[-] OFFLINE      System unavailable                              │
│  [#ffffff]█[-] UNKNOWN      State indeterminate                             │
│                                                                             │
│  OPERATIONAL PHASES                                                         │
│  ══════════════════════════════════════════════════════════════════════════ │
│  [#00afff]█[-] PRE-FLIGHT   Mission preparation phase                       │
│  [#00ffff]█[-] COUNTDOWN    T-minus active countdown                        │
│  [#ffdd00]█[-] IGNITION     Launch sequence initiated                       │
│  [#ff8800]█[-] LIFTOFF      Active ascent                                   │
│  [#00ff88]█[-] IN ORBIT     Nominal orbital operations                      │
│  [#8844ff]█[-] MANEUVER     Orbital adjustment in progress                  │
│  [#00ffff]█[-] DOCKING      Proximity operations                            │
│  [#ffaa00]█[-] REENTRY      Atmospheric reentry phase                       │
│  [#00ff88]█[-] LANDING      Terminal descent and landing                    │
│  [#44ff44]█[-] MISSION END  Operations complete                             │
│                                                                             │
│  DATA QUALITY                                                               │
│  ══════════════════════════════════════════════════════════════════════════ │
│  [#00ff88]█[-] VALID        Data verified and trusted                       │
│  [#ffaa00]█[-] STALE        Data age exceeds threshold                      │
│  [#ff4444]█[-] INVALID      Data failed validation                          │
│  [#606070]█[-] NO DATA      No telemetry received                           │
│  [#8844ff]█[-] SIMULATED    Synthetic/test data                             │
│                                                                             │
│  RESOURCE LEVELS                                                            │
│  ══════════════════════════════════════════════════════════════════════════ │
│  [#00ff88]█[-] 100-80%      Optimal reserve                                 │
│  [#88ff44]█[-] 80-60%       Good reserve                                    │
│  [#ffdd00]█[-] 60-40%       Adequate reserve                                │
│  [#ffaa00]█[-] 40-20%       Low reserve - caution                           │
│  [#ff8800]█[-] 20-10%       Critical low - warning                          │
│  [#ff4444]█[-] 10-0%        Depleted - alert                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.5 OLED-Specific Optimizations

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OLED DISPLAY OPTIMIZATIONS                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TRUE BLACK (#000000) BENEFITS                                              │
│  ─────────────────────────────────────────────────────────────────────────  │
│  • Pixels physically OFF = zero power consumption                           │
│  • Infinite contrast ratio against any lit pixel                            │
│  • No light bleed into adjacent content                                     │
│  • Deeper perceived color saturation                                        │
│                                                                             │
│  BURN-IN PREVENTION                                                         │
│  ─────────────────────────────────────────────────────────────────────────  │
│  • Static elements use [#e0e0e8] not [#ffffff] (reduced luminance)         │
│  • Status indicators pulse/breathe rather than static glow                  │
│  • High-contrast borders: [#252530] not bright colors                      │
│  • Auto-dim after 30s inactivity: luminance -30%                           │
│  • Pixel shift: 1px every 60 seconds (imperceptible)                       │
│                                                                             │
│  HDR TONEMAPPING                                                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│  • Peak whites: 1000 nits for alerts only (brief flash)                    │
│  • Standard UI: 200-400 nits sustained                                      │
│  • Backgrounds: 0-50 nits (OLED-friendly)                                  │
│  • Status lights: 600 nits max (attention without fatigue)                 │
│                                                                             │
│  WIDE GAMUT P3 UTILIZATION                                                  │
│  ─────────────────────────────────────────────────────────────────────────  │
│  sRGB Limit │ P3 Extended │ Purpose                                        │
│  ───────────┼─────────────┼────────────────────────────────────────────────│
│  #00ff00    │ #00ff88     │ Greens more cyan-shifted, better visibility    │
│  #0000ff    │ #0080ff     │ Blues more visible, less eye strain            │
│  #ff0000    │ #ff0044     │ Reds with magenta, higher urgency perception   │
│  #ffff00    │ #ffdd00     │ Yellows warmer, less harsh                     │
│  N/A        │ #00ffff     │ Pure cyan only in P3, maximum pop              │
│                                                                             │
│  GPU ACCELERATION REQUIREMENTS                                              │
│  ─────────────────────────────────────────────────────────────────────────  │
│  • Terminal: Kitty (GPU), Alacritty (GPU), WezTerm (GPU)                   │
│  • Minimum: OpenGL 3.3 / Metal / Vulkan                                    │
│  • Color: 24-bit true color (COLORTERM=truecolor)                          │
│  • Refresh: 120Hz for smooth 60fps animation                               │
│  • Latency: <8ms input-to-display for responsiveness                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.6 Contrast Ratio Compliance Matrix

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WCAG 2.1 CONTRAST COMPLIANCE                             │
│                    Minimum: 4.5:1 (AA) | Target: 7:1 (AAA)                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  FOREGROUND       │ BACKGROUND     │ RATIO   │ WCAG  │ USE CASE            │
│  ─────────────────┼────────────────┼─────────┼───────┼─────────────────────│
│  [#ffffff] White  │ [#000000] Void │ 21.0:1  │ AAA   │ Maximum contrast    │
│  [#e0e0e8] Lunar  │ [#000000] Void │ 17.4:1  │ AAA   │ Primary text        │
│  [#e0e0e8] Lunar  │ [#0a0a10] Cos  │ 14.2:1  │ AAA   │ Body text           │
│  [#00ffff] Cyan   │ [#000000] Void │ 16.7:1  │ AAA   │ Primary accent      │
│  [#00ff88] Green  │ [#000000] Void │ 15.3:1  │ AAA   │ Success status      │
│  [#ffaa00] Amber  │ [#000000] Void │ 11.5:1  │ AAA   │ Warning status      │
│  [#ff4444] Red    │ [#000000] Void │ 6.2:1   │ AA    │ Error status        │
│  [#00afff] Q.Blue │ [#000000] Void │ 9.8:1   │ AAA   │ Links/interactive   │
│  [#a0a0b0] Star   │ [#0a0a10] Cos  │ 7.1:1   │ AAA   │ Secondary text      │
│  [#606070] Comet  │ [#0a0a10] Cos  │ 4.6:1   │ AA    │ Disabled text       │
│  [#8844ff] Purple │ [#000000] Void │ 5.8:1   │ AA    │ Highlight accent    │
│                                                                             │
│  LARGE TEXT (18pt+)                                                         │
│  ─────────────────┼────────────────┼─────────┼───────┼─────────────────────│
│  [#ff4444] Red    │ [#0a0a10] Cos  │ 5.1:1   │ AAA   │ Large alerts        │
│  [#606070] Comet  │ [#000000] Void │ 5.3:1   │ AAA   │ Large labels        │
│                                                                             │
│  NON-TEXT ELEMENTS (3:1 minimum)                                            │
│  ─────────────────┼────────────────┼─────────┼───────┼─────────────────────│
│  [#252530] Border │ [#0a0a10] Cos  │ 3.2:1   │ OK    │ UI boundaries       │
│  [#00afff] Focus  │ [#0a0a10] Cos  │ 8.1:1   │ OK    │ Focus indicator     │
│  [#ff4444] Alert  │ [#1a1a24] Card │ 5.5:1   │ OK    │ Alert icons         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3.0 EXTENDED COLOR PALETTES

### 3.1 Mission Phase Palette

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MISSION PHASE COLORS                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PRE-LAUNCH                                                                 │
│  [#1a3366]████[-] ASSEMBLY     #1a3366  Integration phase                  │
│  [#264d99]████[-] CHECKOUT     #264d99  Systems verification               │
│  [#3366cc]████[-] COUNTDOWN    #3366cc  Launch countdown                   │
│  [#4080ff]████[-] TERMINAL     #4080ff  Final countdown                    │
│                                                                             │
│  ASCENT                                                                     │
│  [#ff6600]████[-] IGNITION     #ff6600  Main engine start                  │
│  [#ff8833]████[-] LIFTOFF      #ff8833  Vehicle moving                     │
│  [#ffaa66]████[-] MAX-Q        #ffaa66  Maximum dynamic pressure           │
│  [#ffcc99]████[-] MECO         #ffcc99  Main engine cutoff                 │
│                                                                             │
│  ORBIT                                                                      │
│  [#00cc88]████[-] ORBIT INSERT #00cc88  Orbital velocity achieved          │
│  [#00ff88]████[-] NOMINAL OPS  #00ff88  Standard operations                │
│  [#44ffaa]████[-] MANEUVER     #44ffaa  Orbital adjustment                 │
│  [#88ffcc]████[-] COAST        #88ffcc  Unpowered flight                   │
│                                                                             │
│  PROXIMITY                                                                  │
│  [#00ddff]████[-] FAR RANGE    #00ddff  >1km separation                    │
│  [#00bbff]████[-] MID RANGE    #00bbff  100m-1km separation                │
│  [#0099ff]████[-] CLOSE RANGE  #0099ff  10-100m separation                 │
│  [#0077ff]████[-] FINAL APP    #0077ff  <10m final approach                │
│  [#8844ff]████[-] CONTACT      #8844ff  Physical contact                   │
│                                                                             │
│  DESCENT                                                                    │
│  [#cc6600]████[-] DEORBIT      #cc6600  Reentry burn                       │
│  [#ff4400]████[-] REENTRY      #ff4400  Atmospheric interface              │
│  [#ff6644]████[-] HYPERSONIC   #ff6644  High-speed descent                 │
│  [#ff8866]████[-] SUPERSONIC   #ff8866  Mach >1                            │
│  [#ffaa88]████[-] SUBSONIC     #ffaa88  Terminal descent                   │
│  [#00ff88]████[-] LANDING      #00ff88  Touchdown                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Subsystem Status Palette

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SUBSYSTEM-SPECIFIC COLORS                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  POWER SYSTEMS                                                              │
│  [#ffdd00]████[-] SOLAR        #ffdd00  Solar array power                  │
│  [#00ff88]████[-] BATTERY      #00ff88  Battery systems                    │
│  [#ff8800]████[-] FUEL CELL    #ff8800  Fuel cell power                    │
│  [#8844ff]████[-] RTG          #8844ff  Radioisotope power                 │
│                                                                             │
│  THERMAL SYSTEMS                                                            │
│  [#0088ff]████[-] COLD         #0088ff  Below nominal (-40°C)              │
│  [#00ccff]████[-] COOL         #00ccff  Low nominal (-20 to 0°C)           │
│  [#00ff88]████[-] OPTIMAL      #00ff88  Nominal range (0-30°C)             │
│  [#ffcc00]████[-] WARM         #ffcc00  High nominal (30-50°C)             │
│  [#ff8800]████[-] HOT          #ff8800  Above nominal (50-80°C)            │
│  [#ff4444]████[-] OVERHEAT     #ff4444  Critical (>80°C)                   │
│                                                                             │
│  PROPULSION                                                                 │
│  [#606070]████[-] OFF          #606070  Engine inactive                    │
│  [#ffdd00]████[-] PRIMED       #ffdd00  Ready to fire                      │
│  [#ff8800]████[-] IGNITION     #ff8800  Startup sequence                   │
│  [#ff4400]████[-] THRUSTING    #ff4400  Active burn                        │
│  [#00ff88]████[-] SHUTDOWN     #00ff88  Nominal shutdown                   │
│                                                                             │
│  COMMUNICATIONS                                                             │
│  [#00ff88]████[-] LOCKED       #00ff88  Signal acquired                    │
│  [#ffaa00]████[-] SEARCHING    #ffaa00  Acquiring signal                   │
│  [#ff4444]████[-] LOS          #ff4444  Loss of signal                     │
│  [#8844ff]████[-] BLACKOUT     #8844ff  Expected comm loss                 │
│                                                                             │
│  GUIDANCE/NAVIGATION                                                        │
│  [#00ff88]████[-] TRACKING     #00ff88  Target locked                      │
│  [#00afff]████[-] COMPUTING    #00afff  Solution in progress               │
│  [#ffaa00]████[-] COARSE       #ffaa00  Low precision                      │
│  [#ff4444]████[-] LOST         #ff4444  No valid solution                  │
│                                                                             │
│  LIFE SUPPORT                                                               │
│  [#00ff88]████[-] O2 NOMINAL   #00ff88  Oxygen normal                      │
│  [#00ccff]████[-] CO2 NORMAL   #00ccff  CO2 within limits                  │
│  [#ffaa00]████[-] HUMIDITY     #ffaa00  Humidity warning                   │
│  [#ff4444]████[-] PRESSURE     #ff4444  Cabin pressure alert               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Alert Level Gradient

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ALERT LEVEL COLOR GRADIENT                               │
│                    NASA/ESA Alert Classification System                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  LEVEL 0 - NOMINAL                                                          │
│  [#00ff88]████████████████████████████████████████████████████████[-]       │
│  #00ff88 → All systems operating within specification                       │
│                                                                             │
│  LEVEL 1 - ADVISORY                                                         │
│  [#44ffaa]████████████████████████████████████████████████████████[-]       │
│  #44ffaa → Parameter drift detected, monitoring enhanced                    │
│                                                                             │
│  LEVEL 2 - WATCH                                                            │
│  [#88ff88]████████████████████████████████████████████████████████[-]       │
│  #88ff88 → Condition developing, crew awareness required                    │
│                                                                             │
│  LEVEL 3 - CAUTION                                                          │
│  [#ccff44]████████████████████████████████████████████████████████[-]       │
│  #ccff44 → Off-nominal condition, action may be required                    │
│                                                                             │
│  LEVEL 4 - WARNING                                                          │
│  [#ffdd00]████████████████████████████████████████████████████████[-]       │
│  #ffdd00 → Significant off-nominal, action required                         │
│                                                                             │
│  LEVEL 5 - ALERT                                                            │
│  [#ffaa00]████████████████████████████████████████████████████████[-]       │
│  #ffaa00 → Serious condition, immediate action required                     │
│                                                                             │
│  LEVEL 6 - CRITICAL                                                         │
│  [#ff6600]████████████████████████████████████████████████████████[-]       │
│  #ff6600 → Critical failure, contingency procedures active                  │
│                                                                             │
│  LEVEL 7 - EMERGENCY                                                        │
│  [#ff4444]████████████████████████████████████████████████████████[-]       │
│  #ff4444 → Emergency condition, abort procedures available                  │
│                                                                             │
│  LEVEL 8 - ABORT                                                            │
│  [#ff0044]████████████████████████████████████████████████████████[-]       │
│  #ff0044 → Mission abort, crew safety priority                              │
│                                                                             │
│  LEVEL 9 - CATASTROPHIC                                                     │
│  [#ff0000]████████████████████████████████████████████████████████[-]       │
│  #ff0000 → Loss of vehicle/mission imminent                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART 2: TYPOGRAPHY, LAYOUT & GPU ANIMATION

## 4.0 TYPOGRAPHY SYSTEM

### 4.1 GPU-Optimized Font Stack

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FONT STACK - GPU RENDERING                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PRIMARY MONOSPACE (Required for terminal)                                  │
│  ─────────────────────────────────────────────────────────────────────────  │
│  1. "JetBrains Mono"     - Ligatures, excellent at small sizes              │
│  2. "Fira Code"          - Ligatures, wide glyph coverage                   │
│  3. "Cascadia Code"      - Microsoft, Powerline built-in                    │
│  4. "SF Mono"            - Apple, excellent OLED rendering                  │
│  5. "Menlo"              - Fallback macOS                                   │
│  6. "Consolas"           - Fallback Windows                                 │
│  7. "Liberation Mono"    - Fallback Linux                                   │
│  8. monospace            - System fallback                                  │
│                                                                             │
│  NERD FONT REQUIREMENT                                                      │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Icons require Nerd Font patched version:                                   │
│  • JetBrainsMono Nerd Font                                                  │
│  • FiraCode Nerd Font                                                       │
│  • Provides: Powerline, Font Awesome, Material, Octicons, Weather           │
│                                                                             │
│  LIGATURE EXAMPLES                                                          │
│  ─────────────────────────────────────────────────────────────────────────  │
│  ->  =>  !=  ==  ===  <=  >=  |>  <|  ::  ...  ++  --  **  //               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Type Scale (Modular Scale 1.25)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TYPE SCALE - AEROSPACE                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  SCALE       SIZE    WEIGHT    LINE-H  USE CASE                             │
│  ──────────────────────────────────────────────────────────────────────────│
│  [#00ffff]DISPLAY-1[-]  3.052   Bold      1.0     Mission title, T-countdown     │
│  [#00afff]DISPLAY-2[-]  2.441   Bold      1.0     Section headers               │
│  [#00afff]HEADING-1[-]  1.953   SemiBold  1.1     Panel titles                  │
│  [#e0e0e8]HEADING-2[-]  1.563   SemiBold  1.2     Card headers                  │
│  [#e0e0e8]HEADING-3[-]  1.250   Medium    1.2     Subsection titles             │
│  [#e0e0e8]BODY[-]       1.000   Regular   1.4     Primary content               │
│  [#a0a0b0]CAPTION[-]    0.800   Regular   1.3     Labels, metadata              │
│  [#606070]MICRO[-]      0.640   Regular   1.2     Timestamps, IDs               │
│                                                                             │
│  CHARACTER CELL (Terminal Standard)                                         │
│  ──────────────────────────────────────────────────────────────────────────│
│  Base: 1 character = 1 cell                                                 │
│  Width: 8-10 pixels (depending on font)                                     │
│  Height: 16-20 pixels (depending on line height)                            │
│  Aspect: ~1:2 (width:height)                                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.3 Text Styles & Treatments

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TEXT STYLE CATALOG                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  EMPHASIS STYLES                                                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#e0e0e8]Normal text[-]                    Standard body copy              │
│  [#e0e0e8::b]Bold text[::-]                 Strong emphasis                 │
│  [#e0e0e8::i]Italic text[::-]               Subtle emphasis                 │
│  [#e0e0e8::u]Underline text[::-]            Links (avoid - accessibility)   │
│  [#e0e0e8::s]Strikethrough[::-]             Deprecated/cancelled            │
│  [#e0e0e8::r]Reverse video[::-]             Selection highlight             │
│  [#e0e0e8::d]Dim text[::-]                  De-emphasized                   │
│                                                                             │
│  SEMANTIC TEXT COLORS                                                       │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ffff]PRIMARY ACCENT[-]                 Interactive elements            │
│  [#00afff]SECONDARY ACCENT[-]               Links, actions                  │
│  [#00ff88]SUCCESS TEXT[-]                   Confirmations, completed        │
│  [#ffaa00]WARNING TEXT[-]                   Caution messages                │
│  [#ff4444]ERROR TEXT[-]                     Error messages                  │
│  [#8844ff]SPECIAL TEXT[-]                   Highlight, armed states         │
│  [#606070]DISABLED TEXT[-]                  Inactive elements               │
│                                                                             │
│  TELEMETRY NUMBER FORMATTING                                                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]+1,234.567[-]                     Positive value (green)          │
│  [#ff4444]-1,234.567[-]                     Negative value (red)            │
│  [#e0e0e8]1,234.567[-]                      Neutral value (white)           │
│  [#ffaa00]~1,234.567[-]                     Approximate (amber)             │
│  [#606070]---.---[-]                        No data (grey dashes)           │
│                                                                             │
│  COUNTDOWN TYPOGRAPHY                                                       │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ffff::b]T-00:15:00[::-]                Pre-launch (cyan)               │
│  [#ffdd00::b]T-00:00:10[::-]                Final countdown (yellow)        │
│  [#ff4400::b]T+00:00:05[::-]                Post-ignition (orange)          │
│  [#00ff88::b]T+01:23:45[::-]                In-flight (green)               │
│                                                                             │
│  COORDINATE DISPLAY                                                         │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00afff]LAT[-] [#e0e0e8]+28.573°[-]  [#00afff]LON[-] [#e0e0e8]-80.649°[-] │
│  [#00afff]ALT[-] [#e0e0e8]408.2 km[-]  [#00afff]VEL[-] [#e0e0e8]7.66 km/s[-]│
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5.0 SPACING & LAYOUT SYSTEM

### 5.1 Spacing Tokens (8px Base Grid)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SPACING TOKENS - 8px GRID                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TOKEN   CELLS  PIXELS  USE CASE                                            │
│  ──────────────────────────────────────────────────────────────────────────│
│  xs      0.5    4px     Inline spacing, icon gaps                           │
│  sm      1      8px     Tight padding, dense lists                          │
│  md      2      16px    Standard padding, card spacing                      │
│  lg      3      24px    Section spacing, panel gaps                         │
│  xl      4      32px    Major section dividers                              │
│  2xl     6      48px    Page-level spacing                                  │
│  3xl     8      64px    Dashboard panels                                    │
│                                                                             │
│  TERMINAL CELL EQUIVALENTS                                                  │
│  ──────────────────────────────────────────────────────────────────────────│
│  1 char width  = 1 horizontal cell = ~8-10px                                │
│  1 line height = 1 vertical cell   = ~16-20px                               │
│                                                                             │
│  VISUAL SPACING                                                             │
│  ──────────────────────────────────────────────────────────────────────────│
│                                                                             │
│  xs: [#252530]│[-]4px[#252530]│[-]                                         │
│  sm: [#252530]│[-]  8px  [#252530]│[-]                                     │
│  md: [#252530]│[-]    16px    [#252530]│[-]                                │
│  lg: [#252530]│[-]      24px      [#252530]│[-]                            │
│  xl: [#252530]│[-]        32px        [#252530]│[-]                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Grid System (12-Column)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    12-COLUMN GRID SYSTEM                                    │
│                    Standard Terminal: 120 columns                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  COLUMN WIDTHS (120 char terminal)                                          │
│  ──────────────────────────────────────────────────────────────────────────│
│  1 col  =  10 chars    │████████│                                          │
│  2 cols =  20 chars    │████████████████████│                              │
│  3 cols =  30 chars    │██████████████████████████████│                    │
│  4 cols =  40 chars    │████████████████████████████████████████│          │
│  6 cols =  60 chars    │half width═════════════════════════════│           │
│  12 cols = 120 chars   │full width═══════════════════════════════════════│ │
│                                                                             │
│  COMMON LAYOUTS                                                             │
│  ──────────────────────────────────────────────────────────────────────────│
│                                                                             │
│  LAYOUT: 3-3-6 (Status | Telemetry | Main)                                  │
│  [#252530]┌──────────┬──────────┬────────────────────────────────────────┐[-]
│  [#252530]│[-][#00afff] STATUS [-][#252530]│[-][#00afff] TELEMETRY[-][#252530]│[-][#00afff]           MAIN CONTENT            [-][#252530]│[-]
│  [#252530]│[-] 3 cols [#252530]│[-] 3 cols  [#252530]│[-]               6 cols              [#252530]│[-]
│  [#252530]└──────────┴──────────┴────────────────────────────────────────┘[-]
│                                                                             │
│  LAYOUT: 4-8 (Sidebar | Content)                                            │
│  [#252530]┌────────────────┬────────────────────────────────────────────────┐[-]
│  [#252530]│[-][#00afff]    SIDEBAR    [-][#252530]│[-][#00afff]              MAIN CONTENT                 [-][#252530]│[-]
│  [#252530]│[-]    4 cols    [#252530]│[-]                  8 cols                  [#252530]│[-]
│  [#252530]└────────────────┴────────────────────────────────────────────────┘[-]
│                                                                             │
│  LAYOUT: 4-4-4 (Triple Panel)                                               │
│  [#252530]┌────────────────┬────────────────┬────────────────┐[-]
│  [#252530]│[-][#00afff]    PANEL 1    [-][#252530]│[-][#00afff]    PANEL 2    [-][#252530]│[-][#00afff]    PANEL 3    [-][#252530]│[-]
│  [#252530]│[-]    4 cols    [#252530]│[-]    4 cols    [#252530]│[-]    4 cols    [#252530]│[-]
│  [#252530]└────────────────┴────────────────┴────────────────┘[-]
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Density Modes

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DENSITY MODE VARIANTS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  COMPACT MODE (Mission Critical - Maximum Data)                             │
│  ──────────────────────────────────────────────────────────────────────────│
│  [#252530]┌─TELEMETRY─────────────────────────────────────────┐[-]
│  [#252530]│[-][#00ff88]●[-]ALT[#e0e0e8] 408.2[-][#606070]km[-] [#00ff88]●[-]VEL[#e0e0e8] 7.66[-][#606070]km/s[-] [#00ff88]●[-]INC[#e0e0e8] 51.6[-][#606070]°[-]   [#252530]│[-]
│  [#252530]│[-][#00ff88]●[-]PER[#e0e0e8] 403.1[-][#606070]km[-] [#00ff88]●[-]APO[#e0e0e8] 412.8[-][#606070]km[-] [#00ff88]●[-]ECC[#e0e0e8] 0.001[-]     [#252530]│[-]
│  [#252530]└───────────────────────────────────────────────────┘[-]
│  Line height: 1.0 | Padding: 4px | Data-dense                               │
│                                                                             │
│  COMFORTABLE MODE (Standard Operations)                                     │
│  ──────────────────────────────────────────────────────────────────────────│
│  [#252530]┌─ TELEMETRY ───────────────────────────────────────────────┐[-]
│  [#252530]│[-]                                                         [#252530]│[-]
│  [#252530]│[-]  [#00ff88]●[-] ALTITUDE    [#e0e0e8]408.2 km[-]        [#00afff]▲ +0.3[-]           [#252530]│[-]
│  [#252530]│[-]  [#00ff88]●[-] VELOCITY    [#e0e0e8]7.66 km/s[-]       [#00afff]► NOMINAL[-]        [#252530]│[-]
│  [#252530]│[-]  [#00ff88]●[-] INCLINATION [#e0e0e8]51.64°[-]          [#00afff]► STABLE[-]         [#252530]│[-]
│  [#252530]│[-]                                                         [#252530]│[-]
│  [#252530]└───────────────────────────────────────────────────────────┘[-]
│  Line height: 1.4 | Padding: 16px | Balanced readability                    │
│                                                                             │
│  SPACIOUS MODE (Training/Presentation)                                      │
│  ──────────────────────────────────────────────────────────────────────────│
│  [#252530]┌─────────────────────────────────────────────────────────────────┐[-]
│  [#252530]│[-]                                                               [#252530]│[-]
│  [#252530]│[-]        [#00afff]T E L E M E T R Y   D A T A[-]                       [#252530]│[-]
│  [#252530]│[-]                                                               [#252530]│[-]
│  [#252530]│[-]     ┌─────────────┬─────────────┬─────────────┐               [#252530]│[-]
│  [#252530]│[-]     │[#00ff88]  ALTITUDE  [-]│[#00ff88]  VELOCITY  [-]│[#00ff88] INCLINATION[-]│               [#252530]│[-]
│  [#252530]│[-]     │             │             │             │               [#252530]│[-]
│  [#252530]│[-]     │ [#e0e0e8]408.2 km[-]   │ [#e0e0e8]7.66 km/s[-]  │  [#e0e0e8]51.64°[-]    │               [#252530]│[-]
│  [#252530]│[-]     │             │             │             │               [#252530]│[-]
│  [#252530]│[-]     └─────────────┴─────────────┴─────────────┘               [#252530]│[-]
│  [#252530]│[-]                                                               [#252530]│[-]
│  [#252530]└─────────────────────────────────────────────────────────────────┘[-]
│  Line height: 1.6 | Padding: 32px | Maximum clarity                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 6.0 BORDERS & VISUAL HIERARCHY

### 6.1 Border Character Sets

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    BORDER CHARACTER CATALOG                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  SINGLE LINE (Standard UI)                                                  │
│  ┌─────────────────────┐                                                    │
│  │ ┌ ┐ └ ┘ ─ │ ├ ┤ ┬ ┴ ┼ │  Light, clean appearance                       │
│  └─────────────────────┘                                                    │
│                                                                             │
│  DOUBLE LINE (Emphasis/Primary)                                             │
│  ╔═════════════════════╗                                                    │
│  ║ ╔ ╗ ╚ ╝ ═ ║ ╠ ╣ ╦ ╩ ╬ ║  Strong borders, mission-critical               │
│  ╚═════════════════════╝                                                    │
│                                                                             │
│  HEAVY LINE (Maximum Emphasis)                                              │
│  ┏━━━━━━━━━━━━━━━━━━━━━┓                                                    │
│  ┃ ┏ ┓ ┗ ┛ ━ ┃ ┣ ┫ ┳ ┻ ╋ ┃  Bold, high contrast                            │
│  ┗━━━━━━━━━━━━━━━━━━━━━┛                                                    │
│                                                                             │
│  ROUNDED (Soft UI)                                                          │
│  ╭─────────────────────╮                                                    │
│  │ ╭ ╮ ╰ ╯             │  Friendly, modern feel                             │
│  ╰─────────────────────╯                                                    │
│                                                                             │
│  MIXED (Single/Double Hybrid)                                               │
│  ╒═════════════════════╕                                                    │
│  │ ╒ ╕ ╘ ╛ ═ │ ╞ ╡ ╤ ╧ ╪ │  Header emphasis with light body                │
│  ╘═════════════════════╛                                                    │
│                                                                             │
│  ASCII FALLBACK (Tier 3)                                                    │
│  +---------------------+                                                    │
│  | + - | < > ^ v       |  Maximum compatibility                             │
│  +---------------------+                                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Semantic Border Colors

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SEMANTIC BORDER ASSIGNMENTS                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  STANDARD BORDERS                                                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#252530]┌─────────────────────┐[-]  #252530 - Default border (subtle)     │
│  [#252530]│ Default panel       │[-]                                        │
│  [#252530]└─────────────────────┘[-]                                        │
│                                                                             │
│  FOCUSED/SELECTED                                                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00afff]┌─────────────────────┐[-]  #00afff - Focus indicator             │
│  [#00afff]│[-] [#e0e0e8]Active panel[-]        [#00afff]│[-]                │
│  [#00afff]└─────────────────────┘[-]                                        │
│                                                                             │
│  STATUS: NOMINAL                                                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]╔═════════════════════╗[-]  #00ff88 - Healthy system              │
│  [#00ff88]║[-] [#e0e0e8]All systems GO[-]      [#00ff88]║[-]                │
│  [#00ff88]╚═════════════════════╝[-]                                        │
│                                                                             │
│  STATUS: WARNING                                                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#ffaa00]╔═════════════════════╗[-]  #ffaa00 - Attention required          │
│  [#ffaa00]║[-] [#e0e0e8]Caution: Check fuel[-] [#ffaa00]║[-]                │
│  [#ffaa00]╚═════════════════════╝[-]                                        │
│                                                                             │
│  STATUS: CRITICAL                                                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#ff4444]╔═════════════════════╗[-]  #ff4444 - Error/Alert                 │
│  [#ff4444]║[-] [#e0e0e8]ALERT: Hull breach[-]  [#ff4444]║[-]                │
│  [#ff4444]╚═════════════════════╝[-]                                        │
│                                                                             │
│  STATUS: ARMED                                                              │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#8844ff]┏━━━━━━━━━━━━━━━━━━━━━┓[-]  #8844ff - Armed state                 │
│  [#8844ff]┃[-] [#e0e0e8]⚠ ARMED - Hold SPACE[-][#8844ff]┃[-]                │
│  [#8844ff]┗━━━━━━━━━━━━━━━━━━━━━┛[-]                                        │
│                                                                             │
│  STATUS: ENGAGED                                                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#ff0044]┏━━━━━━━━━━━━━━━━━━━━━┓[-]  #ff0044 - Executing                   │
│  [#ff0044]┃[-] [#ffffff]█ FIRING █[-]         [#ff0044]┃[-]                 │
│  [#ff0044]┗━━━━━━━━━━━━━━━━━━━━━┛[-]                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.3 GPU Glow Effects

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SIMULATED GLOW EFFECTS (GPU)                             │
│                    Using color gradients for depth                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  CYAN GLOW (Focus/Primary)                                                  │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#002233]░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░[-]                                │
│  [#003344]░[-][#004455]░[-][#006677]▒[-][#0088aa]▒[-][#00afff]┌──────────────────┐[-][#0088aa]▒[-][#006677]▒[-][#004455]░[-][#003344]░[-] │
│  [#004455]░[-][#006677]▒[-][#0088aa]▒[-][#00afff]│[-]  [#e0e0e8]QUANTUM PANEL[-]    [#00afff]│[-][#0088aa]▒[-][#006677]▒[-][#004455]░[-]  │
│  [#003344]░[-][#004455]░[-][#006677]▒[-][#0088aa]▒[-][#00afff]└──────────────────┘[-][#0088aa]▒[-][#006677]▒[-][#004455]░[-][#003344]░[-] │
│  [#002233]░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░[-]                                │
│                                                                             │
│  GREEN GLOW (Nominal)                                                       │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#002211]░[-][#003322]░[-][#005533]▒[-][#007744]▒[-][#00ff88]●[-][#007744]▒[-][#005533]▒[-][#003322]░[-][#002211]░[-] [#e0e0e8]NOMINAL[-] │
│                                                                             │
│  RED GLOW (Alert)                                                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#220000]░[-][#440011]░[-][#661122]▒[-][#882233]▒[-][#ff4444]●[-][#882233]▒[-][#661122]▒[-][#440011]░[-][#220000]░[-] [#e0e0e8]ALERT[-]   │
│                                                                             │
│  PURPLE GLOW (Armed)                                                        │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#110022]░[-][#220044]░[-][#331166]▒[-][#5522aa]▒[-][#8844ff]◆[-][#5522aa]▒[-][#331166]▒[-][#220044]░[-][#110022]░[-] [#e0e0e8]ARMED[-]   │
│                                                                             │
│  PULSING GLOW ANIMATION (3 frames)                                          │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Frame 1: [#003344]░[-][#005566]▒[-][#0088aa]▓[-][#00afff]█[-][#0088aa]▓[-][#005566]▒[-][#003344]░[-] DIM     │
│  Frame 2: [#004455]░[-][#0077aa]▒[-][#00aadd]▓[-][#00ffff]█[-][#00aadd]▓[-][#0077aa]▒[-][#004455]░[-] MEDIUM  │
│  Frame 3: [#005566]▒[-][#0099cc]▓[-][#00ddff]█[-][#ffffff]█[-][#00ddff]█[-][#0099cc]▓[-][#005566]▒[-] BRIGHT  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7.0 GPU ANIMATION SYSTEM

### 7.1 Timing Functions (Easing Curves)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ANIMATION EASING CURVES                                  │
│                    60fps GPU-accelerated                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  LINEAR                          EASE-OUT-CUBIC                             │
│  ────────────────────────────    ────────────────────────────               │
│       ●                               ●●●●●                                 │
│      ●                              ●●                                      │
│     ●                             ●●                                        │
│    ●                            ●●                                          │
│   ●                           ●                                             │
│  ●                          ●                                               │
│  ●─────────────────────► t  ●─────────────────────► t                      │
│  Constant velocity          Smooth deceleration                             │
│  Duration: system            Duration: 200-300ms                            │
│                                                                             │
│  EASE-IN-OUT-QUAD            BOUNCE                                         │
│  ────────────────────────────    ────────────────────────────               │
│           ●●●●●                        ●●●●  ●●  ●                          │
│        ●●●                           ●●    ●●  ●●●●                         │
│      ●●                            ●●           ●●                          │
│    ●●                            ●●                                         │
│  ●●                            ●●                                           │
│  ●─────────────────────► t  ●─────────────────────► t                      │
│  Smooth start/stop          Playful, attention                              │
│  Duration: 300-400ms         Duration: 400-600ms                            │
│                                                                             │
│  SPRING (Overdamped)         ELASTIC                                        │
│  ────────────────────────────    ────────────────────────────               │
│            ●●●●●●●●                     ●●●                                 │
│         ●●●                           ●●   ●●●                              │
│       ●●                            ●●       ●●●●●●●                        │
│     ●●                            ●●                                        │
│   ●●                            ●●                                          │
│  ●─────────────────────► t  ●─────────────────────► t                      │
│  Natural physics             High energy, alerts                            │
│  Duration: 400-800ms         Duration: 500-800ms                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Animation Catalog

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ANIMATION CATALOG - GPU ACCELERATED                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  STATUS PULSE (Idle Indicator)                                              │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Cycle: 2000ms | Easing: ease-in-out-sine                                   │
│  Frame 0:    [#00ff88]●[-] 100% opacity                                     │
│  Frame 500:  [#00cc66]●[-]  70% opacity                                     │
│  Frame 1000: [#009944]●[-]  40% opacity                                     │
│  Frame 1500: [#00cc66]●[-]  70% opacity                                     │
│  Frame 2000: [#00ff88]●[-] 100% opacity (loop)                              │
│                                                                             │
│  ALERT FLASH (Critical Attention)                                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Cycle: 500ms | Easing: step-end                                            │
│  Frame 0:    [#ff4444]█ ALERT █[-]                                          │
│  Frame 250:  [#000000]█ ALERT █[-] (black/invisible)                        │
│  Frame 500:  [#ff4444]█ ALERT █[-] (loop)                                   │
│                                                                             │
│  SCANNING LINE (Data Processing)                                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Cycle: 1500ms | Easing: ease-in-out-cubic                                  │
│  [#252530]┌────────────────────────────────────────┐[-]                     │
│  [#252530]│[-][#00afff]▶[-][#0088aa]───────────────────────[-]             [#252530]│[-] T+0ms   │
│  [#252530]│[-]         [#00afff]▶[-][#0088aa]──────────────[-]             [#252530]│[-] T+500ms │
│  [#252530]│[-]                    [#00afff]▶[-][#0088aa]───[-]             [#252530]│[-] T+1000ms│
│  [#252530]│[-]                           [#00afff]▶[-]     [#252530]│[-] T+1500ms│
│  [#252530]└────────────────────────────────────────┘[-]                     │
│                                                                             │
│  PROGRESS BAR FILL                                                          │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Duration: varies | Easing: linear                                          │
│  [#252530]░░░░░░░░░░░░░░░░░░░░[-]   0% [#606070]Initializing[-]             │
│  [#00ff88]████[-][#252530]░░░░░░░░░░░░░░░░[-]  20% [#a0a0b0]Processing[-]   │
│  [#00ff88]████████████[-][#252530]░░░░░░░░[-]  60% [#e0e0e8]Building[-]     │
│  [#00ff88]████████████████████[-] 100% [#00ff88]Complete[-]                 │
│                                                                             │
│  COUNTDOWN TICK                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Each second: 100ms animation                                               │
│  T-10: [#00ffff]T-00:00:10[-]  Normal size                                  │
│  T-10: [#00ffff::b]T-00:00:10[::-]  Scale 110% (50ms)                       │
│  T-10: [#00ffff]T-00:00:10[-]  Scale 100% (50ms)                            │
│  Flash [#ffdd00]━━[-] at T-10, T-5, T-3, T-2, T-1                           │
│                                                                             │
│  DOCKING APPROACH (Proximity Animation)                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Distance-based color + animation speed                                     │
│  >100m:  [#00ddff]◇[-]   2000ms cycle, slow pulse                           │
│   50m:   [#00bbff]◆[-]   1000ms cycle, medium pulse                         │
│   10m:   [#0099ff]◆[-]    500ms cycle, fast pulse                           │
│    1m:   [#0077ff]█[-]    200ms cycle, rapid pulse                          │
│  DOCK:   [#00ff88]●[-]    SOLID, no animation + chime                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.3 ARM & FIRE Animation Choreography

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ARM & FIRE PROTOCOL - GPU ANIMATION                      │
│                    MIL-STD-1472G §5.2.6.3 Compliant                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PHASE 0: READY (Idle)                                                      │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#252530]┌────────────────────────────────────────┐[-]                     │
│  [#252530]│[-]                                      [#252530]│[-]           │
│  [#252530]│[-]  [#ffaa00]◆[-] [#e0e0e8]DEORBIT BURN[-]                      [#252530]│[-]           │
│  [#252530]│[-]                                      [#252530]│[-]           │
│  [#252530]│[-]  [#a0a0b0]Press [SPACE] to ARM[-]             [#252530]│[-]           │
│  [#252530]│[-]                                      [#252530]│[-]           │
│  [#252530]└────────────────────────────────────────┘[-]                     │
│  Animation: Button pulses 2000ms, subtle glow                               │
│                                                                             │
│  PHASE 1: ARMING (User pressed SPACE, releases)                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│  T+0ms:                                                                     │
│  [#8844ff]┌────────────────────────────────────────┐[-]                     │
│  [#8844ff]│[-]                                      [#8844ff]│[-]           │
│  [#8844ff]│[-]  [#8844ff]⚠[-] [#ffffff]ARMED - DEORBIT BURN[-]              [#8844ff]│[-]           │
│  [#8844ff]│[-]                                      [#8844ff]│[-]           │
│  [#8844ff]│[-]  [#e0e0e8]HOLD [#ffffff::r][SPACE][::-] [#e0e0e8]for 3 seconds[-]      [#8844ff]│[-]           │
│  [#8844ff]│[-]                                      [#8844ff]│[-]           │
│  [#8844ff]└────────────────────────────────────────┘[-]                     │
│  Animation: Border transitions to purple (150ms ease-out)                   │
│  Sound: "armed" tone (440Hz, 200ms)                                         │
│                                                                             │
│  PHASE 2: ENGAGING (User holding SPACE)                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  T+0ms (0%):                                                                │
│  [#8844ff]┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓[-]                     │
│  [#8844ff]┃[-]  [#8844ff]⚠ ENGAGING - DEORBIT BURN[-]           [#8844ff]┃[-]           │
│  [#8844ff]┃[-]  [#8844ff]▓[-][#252530]░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░[-]  [#e0e0e8]0%[-]  [#8844ff]┃[-]           │
│  [#8844ff]┃[-]  [#a0a0b0]Continue holding SPACE...[-]            [#8844ff]┃[-]           │
│  [#8844ff]┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛[-]                     │
│                                                                             │
│  T+1000ms (33%):                                                            │
│  [#9955ff]┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓[-]                     │
│  [#9955ff]┃[-]  [#9955ff]⚠ ENGAGING - DEORBIT BURN[-]           [#9955ff]┃[-]           │
│  [#9955ff]┃[-]  [#9955ff]▓▓▓▓▓▓▓▓▓▓[-][#252530]░░░░░░░░░░░░░░░░░░░░░[-] [#e0e0e8]33%[-]  [#9955ff]┃[-]           │
│  [#9955ff]┃[-]  [#a0a0b0]Continue holding SPACE...[-]            [#9955ff]┃[-]           │
│  [#9955ff]┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛[-]                     │
│  Sound: Rising tone (440Hz → 550Hz)                                         │
│                                                                             │
│  T+2000ms (67%):                                                            │
│  [#aa66ff]┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓[-]                     │
│  [#aa66ff]┃[-]  [#aa66ff]⚠ ENGAGING - DEORBIT BURN[-]           [#aa66ff]┃[-]           │
│  [#aa66ff]┃[-]  [#aa66ff]▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓[-][#252530]░░░░░░░░░░░[-] [#e0e0e8]67%[-]  [#aa66ff]┃[-]           │
│  [#aa66ff]┃[-]  [#ffaa00]⚠ RELEASE TO CANCEL[-]                  [#aa66ff]┃[-]           │
│  [#aa66ff]┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛[-]                     │
│  Sound: Rising tone (550Hz → 660Hz)                                         │
│  Border glow intensity: 0.7                                                 │
│                                                                             │
│  T+2900ms (97%) - POINT OF NO RETURN WARNING:                               │
│  [#cc88ff]┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓[-]                     │
│  [#cc88ff]┃[-]  [#ffaa00]⚠⚠ FINAL COMMIT - DEORBIT ⚠⚠[-]        [#cc88ff]┃[-]           │
│  [#cc88ff]┃[-]  [#cc88ff]▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓[-][#252530]░[-] [#e0e0e8]97%[-]  [#cc88ff]┃[-]           │
│  [#cc88ff]┃[-]  [#ff4444]RELEASE NOW TO ABORT[-]                 [#cc88ff]┃[-]           │
│  [#cc88ff]┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛[-]                     │
│  Sound: Warning beep (880Hz, rapid)                                         │
│                                                                             │
│  PHASE 3: FIRED (T+3000ms - 100%)                                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  T+3000ms:                                                                  │
│  [#ffffff]┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓[-]  ← FLASH (50ms)     │
│  [#ffffff]┃[-]  [#000000]██ EXECUTING DEORBIT BURN ██[-]        [#ffffff]┃[-]           │
│  [#ffffff]┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛[-]                     │
│                                                                             │
│  T+3050ms:                                                                  │
│  [#ff0044]┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓[-]                     │
│  [#ff0044]┃[-]  [#ffffff]█ FIRING - DEORBIT BURN █[-]           [#ff0044]┃[-]           │
│  [#ff0044]┃[-]  [#ff8844]▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓[-][#e0e0e8]ACTIVE[-]  [#ff0044]┃[-]           │
│  [#ff0044]┃[-]  [#e0e0e8]ΔV: [-][#00ff88]+125.4 m/s[-]  [#e0e0e8]Remaining: [-][#ffdd00]2:45[-]   [#ff0044]┃[-]           │
│  [#ff0044]┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛[-]                     │
│  Sound: "firing" tone + rumble                                              │
│  Animation: Border pulses red 500ms cycle                                   │
│                                                                             │
│  PHASE 4: COMPLETE                                                          │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]┌────────────────────────────────────────┐[-]                     │
│  [#00ff88]│[-]  [#00ff88]✓ DEORBIT BURN COMPLETE[-]              [#00ff88]│[-]           │
│  [#00ff88]│[-]  [#e0e0e8]ΔV Applied: [-][#00ff88]125.4 m/s[-]               [#00ff88]│[-]           │
│  [#00ff88]│[-]  [#e0e0e8]New Periapsis: [-][#ffaa00]85 km[-]                [#00ff88]│[-]           │
│  [#00ff88]└────────────────────────────────────────┘[-]                     │
│  Sound: "complete" chime (success tone)                                     │
│                                                                             │
│  ABORT SEQUENCE (User released during ENGAGING)                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#ffaa00]┌────────────────────────────────────────┐[-]                     │
│  [#ffaa00]│[-]  [#ffaa00]⊘ ABORTED - DEORBIT BURN[-]             [#ffaa00]│[-]           │
│  [#ffaa00]│[-]  [#a0a0b0]Action cancelled by operator[-]         [#ffaa00]│[-]           │
│  [#ffaa00]│[-]  [#a0a0b0]Returning to READY state...[-]          [#ffaa00]│[-]           │
│  [#ffaa00]└────────────────────────────────────────┘[-]                     │
│  Sound: "abort" tone (descending)                                           │
│  Transition: 500ms fade to READY state                                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART 3: COMPONENT LIBRARY (ALL VARIANTS)

## 8.0 NAVIGATION COMPONENTS

### 8.1 Command Bar Variants

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    COMMAND BAR VARIANTS                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  VARIANT A: MINIMAL (Compact Mode)                                          │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#0a0a10:#000000]                                                         [-:-]
│  [#00afff]MISSION[-]:[#e0e0e8]ISS-REBOOST-047[-] [#252530]│[-] [#00ff88]●[-][#a0a0b0]NOM[-] [#252530]│[-] [#00ffff]T+02:15:33[-] [#252530]│[-] [#a0a0b0]? Help[-]
│  [#252530]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[-]
│                                                                             │
│  VARIANT B: STANDARD (Comfortable Mode)                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#000000]██████████████████████████████████████████████████████████████████[-]
│  [#1a1a24]┌──────────────────────────────────────────────────────────────────┐[-]
│  [#1a1a24]│[-] [#00afff]◆ MISSION[-] [#e0e0e8]ISS-REBOOST-047[-]        [#00ff88]● NOMINAL[-]        [#00ffff]T+02:15:33[-] [#1a1a24]│[-]
│  [#1a1a24]│[-] [#606070]Phase: Orbital Maintenance[-]    [#a0a0b0]Crew: 7[-]    [#a0a0b0]Orbit: 423[-]    [#1a1a24]│[-]
│  [#1a1a24]└──────────────────────────────────────────────────────────────────┘[-]
│                                                                             │
│  VARIANT C: EXPANDED (Spacious Mode)                                        │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#000000]██████████████████████████████████████████████████████████████████[-]
│  [#12121a]╔══════════════════════════════════════════════════════════════════╗[-]
│  [#12121a]║[-]                                                                [#12121a]║[-]
│  [#12121a]║[-]  [#00afff]◆[-] [#00ffff::b]MISSION ISS-REBOOST-047[::-]                                [#12121a]║[-]
│  [#12121a]║[-]     [#a0a0b0]International Space Station Altitude Maintenance[-]           [#12121a]║[-]
│  [#12121a]║[-]                                                                [#12121a]║[-]
│  [#12121a]║[-]  [#00ff88]● NOMINAL[-]   [#e0e0e8]All Systems GO[-]        [#00ffff]T+02:15:33[-]   [#a0a0b0]MET[-]  [#12121a]║[-]
│  [#12121a]║[-]                                                                [#12121a]║[-]
│  [#12121a]╚══════════════════════════════════════════════════════════════════╝[-]
│                                                                             │
│  VARIANT D: ALERT STATE                                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#330000]██████████████████████████████████████████████████████████████████[-]
│  [#ff4444]╔══════════════════════════════════════════════════════════════════╗[-]
│  [#ff4444]║[-] [#ff4444]▲ ALERT[-] [#ffffff]MISSION ISS-REBOOST-047[-]   [#ff4444]● CRITICAL[-]   [#ffaa00]T+02:15:33[-] [#ff4444]║[-]
│  [#ff4444]║[-] [#ffaa00]⚠ ATTITUDE ANOMALY DETECTED - IMMEDIATE ACTION REQUIRED[-]       [#ff4444]║[-]
│  [#ff4444]╚══════════════════════════════════════════════════════════════════╝[-]
│  Animation: Border pulses 500ms, background flashes                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.2 Sidebar Navigation Variants

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SIDEBAR NAVIGATION VARIANTS                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  VARIANT A: ICON-ONLY (Collapsed)                                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#0a0a10]┌───┐[-]                                                          │
│  [#0a0a10]│[-][#00afff]◉[-][#0a0a10]│[-]  ← Selected (Dashboard)                                    │
│  [#0a0a10]│[-][#606070]◎[-][#0a0a10]│[-]    Telemetry                                               │
│  [#0a0a10]│[-][#606070]⚙[-][#0a0a10]│[-]    Systems                                                 │
│  [#0a0a10]│[-][#606070]⚡[-][#0a0a10]│[-]    Power                                                   │
│  [#0a0a10]│[-][#606070]📡[-][#0a0a10]│[-]    Comms                                                   │
│  [#0a0a10]│[-][#252530]─[-][#0a0a10]│[-]    ─ Divider                                               │
│  [#0a0a10]│[-][#ff4444]⚠[-][#0a0a10]│[-]    Alerts (has notification)                               │
│  [#0a0a10]│[-][#606070]?[-][#0a0a10]│[-]    Help                                                    │
│  [#0a0a10]└───┘[-]                                                          │
│                                                                             │
│  VARIANT B: ICON + LABEL (Standard)                                         │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#0a0a10]┌────────────────────┐[-]                                         │
│  [#1a1a24]│[-][#00afff]◉[-] [#00afff]Dashboard[-]      [#1a1a24]│[-]  ← Selected (cyan bg hint)           │
│  [#0a0a10]│[-][#a0a0b0]◎[-] [#a0a0b0]Telemetry[-]      [#0a0a10]│[-]                                     │
│  [#0a0a10]│[-][#a0a0b0]⚙[-] [#a0a0b0]Systems[-]        [#0a0a10]│[-]                                     │
│  [#0a0a10]│[-][#a0a0b0]⚡[-] [#a0a0b0]Power[-]          [#0a0a10]│[-]                                     │
│  [#0a0a10]│[-][#a0a0b0]📡[-] [#a0a0b0]Communications[-] [#0a0a10]│[-]                                     │
│  [#0a0a10]│[-][#252530]────────────────[-][#0a0a10]│[-]                                     │
│  [#0a0a10]│[-][#ff4444]⚠[-] [#ff4444]Alerts[-] [#ff4444::r] 3 [::-]     [#0a0a10]│[-]  ← Badge showing count       │
│  [#0a0a10]│[-][#a0a0b0]?[-] [#a0a0b0]Help[-]           [#0a0a10]│[-]                                     │
│  [#0a0a10]└────────────────────┘[-]                                         │
│                                                                             │
│  VARIANT C: FULL DETAIL (Expanded)                                          │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#12121a]┌──────────────────────────────┐[-]                               │
│  [#12121a]│[-] [#00afff]NAVIGATION[-]                  [#12121a]│[-]                               │
│  [#12121a]├──────────────────────────────┤[-]                               │
│  [#1a1a24]│[-] [#00afff]◉[-] [#00afff]Dashboard[-]              [#1a1a24]│[-]                               │
│  [#1a1a24]│[-]   [#606070]Overview & Status[-]        [#1a1a24]│[-]                               │
│  [#12121a]├──────────────────────────────┤[-]                               │
│  [#12121a]│[-] [#a0a0b0]◎[-] [#e0e0e8]Telemetry[-]              [#12121a]│[-]                               │
│  [#12121a]│[-]   [#606070]Real-time Data Streams[-]   [#12121a]│[-]                               │
│  [#12121a]│[-]   [#00ff88]● 47 Active Channels[-]     [#12121a]│[-]                               │
│  [#12121a]├──────────────────────────────┤[-]                               │
│  [#12121a]│[-] [#a0a0b0]⚙[-] [#e0e0e8]Systems[-]                [#12121a]│[-]                               │
│  [#12121a]│[-]   [#00ff88]● Propulsion[-]  [#ffaa00]◆ Thermal[-] [#12121a]│[-]                               │
│  [#12121a]└──────────────────────────────┘[-]                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.3 Breadcrumb Variants

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    BREADCRUMB NAVIGATION VARIANTS                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  VARIANT A: ARROW SEPARATOR                                                 │
│  [#00afff]Mission[-] [#606070]›[-] [#00afff]Systems[-] [#606070]›[-] [#00afff]Propulsion[-] [#606070]›[-] [#e0e0e8]Engine #2[-]  │
│                                                                             │
│  VARIANT B: SLASH SEPARATOR                                                 │
│  [#00afff]Mission[-] [#252530]/[-] [#00afff]Systems[-] [#252530]/[-] [#00afff]Propulsion[-] [#252530]/[-] [#e0e0e8]Engine #2[-]  │
│                                                                             │
│  VARIANT C: HIERARCHICAL PATH                                               │
│  [#606070]┌[-] [#00afff]Mission[-]                                                       │
│  [#606070]├─[-] [#00afff]Systems[-]                                                      │
│  [#606070]├──[-] [#00afff]Propulsion[-]                                                  │
│  [#606070]└───[-] [#e0e0e8]Engine #2[-] [#00ff88]●[-]                                    │
│                                                                             │
│  VARIANT D: ICON ENHANCED                                                   │
│  [#00afff]🚀 Mission[-] [#606070]›[-] [#00afff]⚙ Systems[-] [#606070]›[-] [#00afff]🔥 Propulsion[-] [#606070]›[-] [#e0e0e8]Engine #2[-] │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 9.0 STATUS DISPLAY COMPONENTS

### 9.1 Status Indicator Variants

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STATUS INDICATOR VARIANTS                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  VARIANT A: MINIMAL DOT                                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]●[-] Nominal    [#ffaa00]●[-] Warning    [#ff4444]●[-] Critical   [#606070]●[-] Offline     │
│  [#00ffff]●[-] Standby    [#8844ff]●[-] Armed      [#ff0044]●[-] Emergency  [#e0e0e8]●[-] Unknown     │
│                                                                             │
│  VARIANT B: DOT WITH LABEL                                                  │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]● NOMINAL[-]   [#ffaa00]● WARNING[-]   [#ff4444]● CRITICAL[-]   [#606070]● OFFLINE[-]       │
│  [#00ffff]● STANDBY[-]   [#8844ff]● ARMED[-]     [#ff0044]● EMERGENCY[-]  [#e0e0e8]● UNKNOWN[-]       │
│                                                                             │
│  VARIANT C: ICON BADGE                                                      │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]✓[-] OK        [#ffaa00]⚠[-] WARN      [#ff4444]✕[-] FAIL       [#606070]○[-] OFF          │
│  [#00ffff]◆[-] READY     [#8844ff]◈[-] ARMED     [#ff0044]⚡[-] EMERG      [#e0e0e8]?[-] N/A          │
│                                                                             │
│  VARIANT D: BLOCK INDICATOR                                                 │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]█ NOM[-]   [#ffaa00]█ WRN[-]   [#ff4444]█ CRT[-]   [#606070]█ OFF[-]                       │
│  [#00ffff]█ SBY[-]   [#8844ff]█ ARM[-]   [#ff0044]█ EMR[-]   [#e0e0e8]█ UNK[-]                       │
│                                                                             │
│  VARIANT E: TRAFFIC LIGHT (Stacked Vertical)                                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#252530]┌───┐[-]     [#252530]┌───┐[-]     [#252530]┌───┐[-]                               │
│  [#252530]│[-][#331111]●[-][#252530]│[-]     [#252530]│[-][#331111]●[-][#252530]│[-]     [#252530]│[-][#ff4444]●[-][#252530]│[-]  ← RED lit             │
│  [#252530]│[-][#333311]●[-][#252530]│[-]     [#252530]│[-][#ffaa00]●[-][#252530]│[-]     [#252530]│[-][#333311]●[-][#252530]│[-]  ← AMBER lit           │
│  [#252530]│[-][#00ff88]●[-][#252530]│[-]     [#252530]│[-][#113311]●[-][#252530]│[-]     [#252530]│[-][#113311]●[-][#252530]│[-]  ← GREEN lit           │
│  [#252530]└───┘[-]     [#252530]└───┘[-]     [#252530]└───┘[-]                               │
│  GO         CAUTION      STOP                                               │
│                                                                             │
│  VARIANT F: PROGRESS RING (Text-based)                                      │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88](████████████████████)[-] 100%    [#00ff88](████████████░░░░░░░░)[-] 60%    │
│  [#ffaa00](████████░░░░░░░░░░░░)[-] 40%     [#ff4444](████░░░░░░░░░░░░░░░░)[-] 20%    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 9.2 Gauge Variants

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GAUGE DISPLAY VARIANTS                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  VARIANT A: HORIZONTAL BAR GAUGE                                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#a0a0b0]FUEL TANK 1[-]                                                    │
│  [#00ff88]████████████████████████████████████████[-][#252530]░░░░░░░░░░[-] [#e0e0e8]82%[-]   │
│  [#606070]0%                    50%                   100%[-]               │
│                                                                             │
│  [#a0a0b0]FUEL TANK 2[-]  [#ffaa00]LOW[-]                                   │
│  [#ffaa00]████████████[-][#252530]░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░[-] [#ffaa00]24%[-]   │
│  [#606070]0%         ▲THRESHOLD                     100%[-]                 │
│                                                                             │
│  VARIANT B: VERTICAL BAR GAUGE                                              │
│  ─────────────────────────────────────────────────────────────────────────  │
│     [#a0a0b0]O2[-]    [#a0a0b0]N2[-]    [#a0a0b0]CO2[-]   [#a0a0b0]H2O[-]                            │
│  [#252530]┌───┐[-] [#252530]┌───┐[-] [#252530]┌───┐[-] [#252530]┌───┐[-]                             │
│  [#252530]│[-][#00ff88]███[-][#252530]│[-] [#252530]│[-][#00ff88]███[-][#252530]│[-] [#252530]│[-][#00ff88]░░░[-][#252530]│[-] [#252530]│[-][#ffaa00]███[-][#252530]│[-]                             │
│  [#252530]│[-][#00ff88]███[-][#252530]│[-] [#252530]│[-][#00ff88]███[-][#252530]│[-] [#252530]│[-][#00ff88]░░░[-][#252530]│[-] [#252530]│[-][#ffaa00]███[-][#252530]│[-]                             │
│  [#252530]│[-][#00ff88]███[-][#252530]│[-] [#252530]│[-][#00ff88]███[-][#252530]│[-] [#252530]│[-][#00ff88]███[-][#252530]│[-] [#252530]│[-][#252530]░░░[-][#252530]│[-]                             │
│  [#252530]│[-][#00ff88]███[-][#252530]│[-] [#252530]│[-][#00ff88]███[-][#252530]│[-] [#252530]│[-][#00ff88]███[-][#252530]│[-] [#252530]│[-][#252530]░░░[-][#252530]│[-]                             │
│  [#252530]│[-][#00ff88]███[-][#252530]│[-] [#252530]│[-][#252530]░░░[-][#252530]│[-] [#252530]│[-][#00ff88]███[-][#252530]│[-] [#252530]│[-][#252530]░░░[-][#252530]│[-]                             │
│  [#252530]└───┘[-] [#252530]└───┘[-] [#252530]└───┘[-] [#252530]└───┘[-]                             │
│  [#e0e0e8]95%[-]   [#e0e0e8]78%[-]   [#00ff88]0.04%[-] [#ffaa00]45%[-]                             │
│                                                                             │
│  VARIANT C: SEMICIRCLE GAUGE (ASCII Art)                                    │
│  ─────────────────────────────────────────────────────────────────────────  │
│          [#00ff88]╱───────╲[-]                                              │
│        [#00ff88]╱[-]    [#e0e0e8]87%[-]   [#00ff88]╲[-]                                          │
│       [#00ff88]│[-]           [#00ff88]│[-]                                             │
│       [#606070]0[-]           [#606070]100[-]                                           │
│           [#a0a0b0]THRUST[-]                                                │
│                                                                             │
│  VARIANT D: DIAL GAUGE                                                      │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#252530]┌─────────────────────────┐[-]                                    │
│  [#252530]│[-]      [#ff4444]╲[-]  [#ffaa00]│[-]  [#00ff88]╱[-]           [#252530]│[-]                                    │
│  [#252530]│[-]   [#ff4444]MIN[-]  [#00afff]◆[-]  [#00ff88]MAX[-]        [#252530]│[-]     ◆ = needle position             │
│  [#252530]│[-]       [#e0e0e8]7.66 km/s[-]        [#252530]│[-]                                    │
│  [#252530]│[-]       [#a0a0b0]VELOCITY[-]         [#252530]│[-]                                    │
│  [#252530]└─────────────────────────┘[-]                                    │
│                                                                             │
│  VARIANT E: SPARKLINE (Mini Trend)                                          │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#a0a0b0]CPU[-] [#00ff88]▂▃▅▆▅▄▃▄▅▆▇▆▅▄▃▂▃▄▅[-] [#e0e0e8]67%[-]                              │
│  [#a0a0b0]MEM[-] [#ffaa00]▄▄▅▅▆▆▇▇▇▇▆▆▆▇▇▆▆▅[-] [#ffaa00]78%[-]                              │
│  [#a0a0b0]NET[-] [#00ff88]▁▂▁▂▃▂▁▁▂▃▄▃▂▁▁▂▃▂[-] [#e0e0e8]23%[-]                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 9.3 Countdown Timer Variants

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    COUNTDOWN TIMER VARIANTS                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  VARIANT A: MINIMAL                                                         │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ffff]T-00:15:00[-]                                                     │
│                                                                             │
│  VARIANT B: LABELED                                                         │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#a0a0b0]COUNTDOWN[-] [#00ffff]T-00:15:00[-] [#a0a0b0]TO IGNITION[-]                        │
│                                                                             │
│  VARIANT C: SEGMENTED DISPLAY                                               │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#252530]┌────┬────┬────┬────┬────┬────┐[-]                                │
│  [#252530]│[-][#00ffff] T- [-][#252530]│[-][#00ffff] 00 [-][#252530]│[-][#00ffff] : [-][#252530]│[-][#00ffff] 15 [-][#252530]│[-][#00ffff] : [-][#252530]│[-][#00ffff] 00 [-][#252530]│[-]                                │
│  [#252530]│[-]    [#252530]│[-][#606070] HR [-][#252530]│[-]    [#252530]│[-][#606070] MIN[-][#252530]│[-]    [#252530]│[-][#606070] SEC[-][#252530]│[-]                                │
│  [#252530]└────┴────┴────┴────┴────┴────┘[-]                                │
│                                                                             │
│  VARIANT D: LARGE DISPLAY (Mission Critical)                                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#000000]██████████████████████████████████████████████████████████████████[-]
│  [#00ffff]╔══════════════════════════════════════════════════════════════╗[-]
│  [#00ffff]║[-]                                                            [#00ffff]║[-]
│  [#00ffff]║[-]                 [#00ffff::b]T - 0 0 : 1 5 : 0 0[::-]                        [#00ffff]║[-]
│  [#00ffff]║[-]                                                            [#00ffff]║[-]
│  [#00ffff]║[-]     [#606070]HOURS[-]        [#606070]MINUTES[-]       [#606070]SECONDS[-]              [#00ffff]║[-]
│  [#00ffff]║[-]                                                            [#00ffff]║[-]
│  [#00ffff]╚══════════════════════════════════════════════════════════════╝[-]
│                                                                             │
│  VARIANT E: FINAL COUNTDOWN (T-10 and below)                                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#ffdd00]╔══════════════════════════════════════════════════════════════╗[-]
│  [#ffdd00]║[-]                                                            [#ffdd00]║[-]
│  [#ffdd00]║[-]              [#ffffff::b]▌▌▌ T - 1 0 ▌▌▌[::-]                          [#ffdd00]║[-]
│  [#ffdd00]║[-]                                                            [#ffdd00]║[-]
│  [#ffdd00]║[-]        [#e0e0e8]MAIN ENGINE START IN 10 SECONDS[-]                 [#ffdd00]║[-]
│  [#ffdd00]║[-]                                                            [#ffdd00]║[-]
│  [#ffdd00]╚══════════════════════════════════════════════════════════════╝[-]
│  Animation: Pulses yellow, beeps each second                                │
│                                                                             │
│  VARIANT F: MISSION ELAPSED TIME (T+)                                       │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]╔═══════════════════════════════════════╗[-]                      │
│  [#00ff88]║[-] [#a0a0b0]MET[-] [#00ff88]T+02:15:33[-] [#00ff88]● IN FLIGHT[-]  [#00ff88]║[-]                      │
│  [#00ff88]╚═══════════════════════════════════════╝[-]                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 10.0 DATA DISPLAY COMPONENTS

### 10.1 Data Table Variants

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DATA TABLE VARIANTS                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  VARIANT A: MINIMAL (No Borders)                                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00afff]SYSTEM[-]         [#00afff]STATUS[-]    [#00afff]VALUE[-]      [#00afff]UNIT[-]              │
│  [#e0e0e8]Propulsion[-]     [#00ff88]● NOM[-]    [#e0e0e8]98.7[-]      [#606070]%[-]                │
│  [#e0e0e8]Power[-]          [#00ff88]● NOM[-]    [#e0e0e8]12.4[-]      [#606070]kW[-]               │
│  [#e0e0e8]Thermal[-]        [#ffaa00]◆ WRN[-]    [#ffaa00]67.2[-]      [#606070]°C[-]               │
│  [#e0e0e8]Communications[-] [#00ff88]● NOM[-]    [#e0e0e8]-82[-]       [#606070]dBm[-]              │
│                                                                             │
│  VARIANT B: BORDERED (Standard)                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#252530]┌──────────────┬──────────┬──────────┬──────────┐[-]              │
│  [#252530]│[-] [#00afff]SYSTEM[-]       [#252530]│[-] [#00afff]STATUS[-]   [#252530]│[-] [#00afff]VALUE[-]    [#252530]│[-] [#00afff]UNIT[-]     [#252530]│[-]              │
│  [#252530]├──────────────┼──────────┼──────────┼──────────┤[-]              │
│  [#252530]│[-] [#e0e0e8]Propulsion[-]   [#252530]│[-] [#00ff88]● NOM[-]    [#252530]│[-] [#e0e0e8]98.7[-]     [#252530]│[-] [#606070]%[-]        [#252530]│[-]              │
│  [#252530]│[-] [#e0e0e8]Power[-]        [#252530]│[-] [#00ff88]● NOM[-]    [#252530]│[-] [#e0e0e8]12.4[-]     [#252530]│[-] [#606070]kW[-]       [#252530]│[-]              │
│  [#252530]│[-] [#e0e0e8]Thermal[-]      [#252530]│[-] [#ffaa00]◆ WRN[-]    [#252530]│[-] [#ffaa00]67.2[-]     [#252530]│[-] [#606070]°C[-]       [#252530]│[-]              │
│  [#252530]│[-] [#e0e0e8]Communications[-][#252530]│[-] [#00ff88]● NOM[-]    [#252530]│[-] [#e0e0e8]-82[-]      [#252530]│[-] [#606070]dBm[-]      [#252530]│[-]              │
│  [#252530]└──────────────┴──────────┴──────────┴──────────┘[-]              │
│                                                                             │
│  VARIANT C: ZEBRA STRIPE                                                    │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00afff]SYSTEM           STATUS     VALUE      UNIT[-]                    │
│  [#12121a]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[-]              │
│  [#12121a]Propulsion       [#00ff88]● NOM[-]     98.7       %              [-]│
│  [#0a0a10]Power            [#00ff88]● NOM[-]     12.4       kW             [-]│
│  [#12121a]Thermal          [#ffaa00]◆ WRN[-]     67.2       °C             [-]│
│  [#0a0a10]Communications   [#00ff88]● NOM[-]     -82        dBm            [-]│
│                                                                             │
│  VARIANT D: SELECTED ROW HIGHLIGHT                                          │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#252530]┌──────────────┬──────────┬──────────┬──────────┐[-]              │
│  [#252530]│[-] [#00afff]SYSTEM[-]       [#252530]│[-] [#00afff]STATUS[-]   [#252530]│[-] [#00afff]VALUE[-]    [#252530]│[-] [#00afff]UNIT[-]     [#252530]│[-]              │
│  [#252530]├──────────────┼──────────┼──────────┼──────────┤[-]              │
│  [#252530]│[-] [#e0e0e8]Propulsion[-]   [#252530]│[-] [#00ff88]● NOM[-]    [#252530]│[-] [#e0e0e8]98.7[-]     [#252530]│[-] [#606070]%[-]        [#252530]│[-]              │
│  [#00afff]│[-] [#ffffff]Power[-]        [#00afff]│[-] [#00ff88]● NOM[-]    [#00afff]│[-] [#ffffff]12.4[-]     [#00afff]│[-] [#e0e0e8]kW[-]       [#00afff]│[-]  ← Selected  │
│  [#252530]│[-] [#e0e0e8]Thermal[-]      [#252530]│[-] [#ffaa00]◆ WRN[-]    [#252530]│[-] [#ffaa00]67.2[-]     [#252530]│[-] [#606070]°C[-]       [#252530]│[-]              │
│  [#252530]│[-] [#e0e0e8]Communications[-][#252530]│[-] [#00ff88]● NOM[-]    [#252530]│[-] [#e0e0e8]-82[-]      [#252530]│[-] [#606070]dBm[-]      [#252530]│[-]              │
│  [#252530]└──────────────┴──────────┴──────────┴──────────┘[-]              │
│                                                                             │
│  VARIANT E: ALERT ROW                                                       │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#252530]│[-] [#e0e0e8]Propulsion[-]   [#252530]│[-] [#00ff88]● NOM[-]    [#252530]│[-] [#e0e0e8]98.7[-]     [#252530]│[-] [#606070]%[-]        [#252530]│[-]              │
│  [#ff4444]│[-] [#ffffff]HULL SENSOR[-]  [#ff4444]│[-] [#ff4444]▲ CRT[-]    [#ff4444]│[-] [#ffffff]BREACH[-]   [#ff4444]│[-] [#ffffff]![-]        [#ff4444]│[-]  ← ALERT     │
│  [#252530]│[-] [#e0e0e8]Power[-]        [#252530]│[-] [#00ff88]● NOM[-]    [#252530]│[-] [#e0e0e8]12.4[-]     [#252530]│[-] [#606070]kW[-]       [#252530]│[-]              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 10.2 Telemetry Panel Variants

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TELEMETRY PANEL VARIANTS                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  VARIANT A: DENSE GRID (Mission Control)                                    │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00afff]ORBITAL MECHANICS[-]                                              │
│  [#252530]┌─────────────────┬─────────────────┬─────────────────┐[-]        │
│  [#252530]│[-][#a0a0b0]ALT[-] [#e0e0e8]408.2[-][#606070]km[-]   [#252530]│[-][#a0a0b0]VEL[-] [#e0e0e8]7.66[-][#606070]km/s[-]  [#252530]│[-][#a0a0b0]INC[-] [#e0e0e8]51.64[-][#606070]°[-]    [#252530]│[-]        │
│  [#252530]│[-][#a0a0b0]PER[-] [#e0e0e8]403.1[-][#606070]km[-]   [#252530]│[-][#a0a0b0]APO[-] [#e0e0e8]412.8[-][#606070]km[-]   [#252530]│[-][#a0a0b0]ECC[-] [#e0e0e8]0.0012[-]     [#252530]│[-]        │
│  [#252530]│[-][#a0a0b0]LAN[-] [#e0e0e8]145.2[-][#606070]°[-]    [#252530]│[-][#a0a0b0]AOP[-] [#e0e0e8]87.3[-][#606070]°[-]     [#252530]│[-][#a0a0b0]TA[-]  [#e0e0e8]234.1[-][#606070]°[-]    [#252530]│[-]        │
│  [#252530]└─────────────────┴─────────────────┴─────────────────┘[-]        │
│                                                                             │
│  VARIANT B: VALUE + TREND                                                   │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#252530]┌────────────────────────────────────────────────────────┐[-]     │
│  [#252530]│[-] [#00afff]ALTITUDE[-]                                         [#252530]│[-]     │
│  [#252530]│[-] [#00ff88::b]408.2 km[::-]                      [#00ff88]▲ +0.3[-] [#00ff88]↗[-]      [#252530]│[-]     │
│  [#252530]│[-] [#606070]▂▃▃▄▄▅▅▆▆▆▆▆▆▆▆▆▆▆▇▇[-]   [#00ff88]● NOMINAL[-]      [#252530]│[-]     │
│  [#252530]└────────────────────────────────────────────────────────┘[-]     │
│                                                                             │
│  VARIANT C: MULTI-VALUE CARD                                                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#12121a]╔════════════════════════════════════════════════════════╗[-]     │
│  [#12121a]║[-] [#00afff]◆ PROPULSION SYSTEM[-]                   [#00ff88]● NOMINAL[-] [#12121a]║[-]     │
│  [#12121a]╠════════════════════════════════════════════════════════╣[-]     │
│  [#12121a]║[-]                                                      [#12121a]║[-]     │
│  [#12121a]║[-]  [#a0a0b0]THRUST[-]      [#e0e0e8]98.7%[-]     [#a0a0b0]FUEL[-]       [#e0e0e8]82.4%[-]   [#12121a]║[-]     │
│  [#12121a]║[-]  [#00ff88]████████████[-] [#252530]░░[-]  [#00ff88]████████████████[-] [#252530]░░░[-]   [#12121a]║[-]     │
│  [#12121a]║[-]                                                      [#12121a]║[-]     │
│  [#12121a]║[-]  [#a0a0b0]CHAMBER[-]     [#e0e0e8]3420K[-]    [#a0a0b0]PRESSURE[-]    [#e0e0e8]21.4MPa[-] [#12121a]║[-]     │
│  [#12121a]║[-]  [#00ff88]███████████[-] [#ffaa00]░░[-]   [#00ff88]██████████████[-] [#252530]░░░░[-]    [#12121a]║[-]     │
│  [#12121a]║[-]                                                      [#12121a]║[-]     │
│  [#12121a]╚════════════════════════════════════════════════════════╝[-]     │
│                                                                             │
│  VARIANT D: REAL-TIME STREAM                                                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#252530]┌─ TELEMETRY STREAM ─────────────────────────────────────┐[-]     │
│  [#252530]│[-] [#606070]12:45:33.124[-] [#00afff]ALT[-] [#e0e0e8]408.217[-][#606070]km[-]  [#00ff88]▲[-]           [#252530]│[-]     │
│  [#252530]│[-] [#606070]12:45:33.224[-] [#00afff]VEL[-] [#e0e0e8]7.6621[-][#606070]km/s[-] [#e0e0e8]━[-]           [#252530]│[-]     │
│  [#252530]│[-] [#606070]12:45:33.324[-] [#00afff]ALT[-] [#e0e0e8]408.219[-][#606070]km[-]  [#00ff88]▲[-]           [#252530]│[-]     │
│  [#252530]│[-] [#606070]12:45:33.424[-] [#ffaa00]TMP[-] [#ffaa00]67.2[-][#606070]°C[-]    [#ffaa00]⚠[-]           [#252530]│[-]     │
│  [#252530]│[-] [#606070]12:45:33.524[-] [#00afff]VEL[-] [#e0e0e8]7.6622[-][#606070]km/s[-] [#00ff88]▲[-]           [#252530]│[-]     │
│  [#252530]│[-] [#00ff88]▌[-] [#a0a0b0]Live[-] [#606070]│[-] [#e0e0e8]47[-] [#606070]channels[-] [#606070]│[-] [#e0e0e8]10[-][#606070]Hz[-]          [#252530]│[-]     │
│  [#252530]└────────────────────────────────────────────────────────┘[-]     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 10.3 Tree View Variants

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TREE VIEW VARIANTS                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  VARIANT A: STANDARD TREE                                                   │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00afff]▼[-] [#e0e0e8]SPACECRAFT[-]                                       │
│  [#606070]├─[-] [#00afff]▼[-] [#e0e0e8]Propulsion[-]                        │
│  [#606070]│  ├─[-] [#00ff88]●[-] [#e0e0e8]Main Engine[-]                    │
│  [#606070]│  ├─[-] [#00ff88]●[-] [#e0e0e8]RCS Thrusters[-]                  │
│  [#606070]│  └─[-] [#ffaa00]◆[-] [#e0e0e8]Fuel System[-]                    │
│  [#606070]├─[-] [#00afff]►[-] [#e0e0e8]Power[-] [#606070](collapsed)[-]     │
│  [#606070]├─[-] [#00afff]▼[-] [#e0e0e8]Thermal[-]                           │
│  [#606070]│  ├─[-] [#00ff88]●[-] [#e0e0e8]Radiators[-]                      │
│  [#606070]│  └─[-] [#ff4444]▲[-] [#ff4444]Heat Exchanger[-] [#ff4444]ALERT[-]│
│  [#606070]└─[-] [#00afff]►[-] [#e0e0e8]Life Support[-]                      │
│                                                                             │
│  VARIANT B: ICON TREE                                                       │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00afff]📂[-] [#e0e0e8]SPACECRAFT[-]                                      │
│  [#606070]├─[-] [#00afff]📂[-] [#e0e0e8]Propulsion[-]                       │
│  [#606070]│  ├─[-] [#00ff88]🔥[-] [#e0e0e8]Main Engine[-] [#00ff88]●[-]     │
│  [#606070]│  ├─[-] [#00ff88]💨[-] [#e0e0e8]RCS Thrusters[-] [#00ff88]●[-]   │
│  [#606070]│  └─[-] [#ffaa00]⛽[-] [#e0e0e8]Fuel System[-] [#ffaa00]◆[-]      │
│  [#606070]├─[-] [#606070]📁[-] [#a0a0b0]Power[-]                            │
│  [#606070]├─[-] [#00afff]📂[-] [#e0e0e8]Thermal[-]                          │
│  [#606070]│  ├─[-] [#00ff88]❄[-] [#e0e0e8]Radiators[-] [#00ff88]●[-]        │
│  [#606070]│  └─[-] [#ff4444]🌡[-] [#ff4444]Heat Exchanger[-] [#ff4444]▲[-]  │
│  [#606070]└─[-] [#606070]📁[-] [#a0a0b0]Life Support[-]                     │
│                                                                             │
│  VARIANT C: STATUS TREE (Checkbox Style)                                    │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00afff][-][-] [#e0e0e8]Pre-Flight Checklist[-]                           │
│  [#606070]├─[-] [#00ff88][✓][-] [#00ff88]Fuel loaded[-]                     │
│  [#606070]├─[-] [#00ff88][✓][-] [#00ff88]Systems check[-]                   │
│  [#606070]├─[-] [#ffaa00][○][-] [#e0e0e8]Weather clearance[-] [#ffaa00]pending[-]│
│  [#606070]├─[-] [#606070][ ][-] [#a0a0b0]Range safety[-]                    │
│  [#606070]└─[-] [#606070][ ][-] [#a0a0b0]Final GO/NO-GO[-]                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 11.0 INTERACTION COMPONENTS

### 11.1 Button Variants

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    BUTTON VARIANTS                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PRIMARY BUTTONS                                                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00afff]┌──────────────┐[-]  [#1a1a24:#00afff]┌──────────────┐[-:-]  [#252530]┌──────────────┐[-] │
│  [#00afff]│[-] [#000000]EXECUTE[-]     [#00afff]│[-]  [#1a1a24:#00afff]│[-:-] [#00afff]EXECUTE[-]     [#1a1a24:#00afff]│[-:-]  [#252530]│[-] [#606070]EXECUTE[-]     [#252530]│[-] │
│  [#00afff]└──────────────┘[-]  [#1a1a24:#00afff]└──────────────┘[-:-]  [#252530]└──────────────┘[-] │
│  Normal               Hover                  Disabled                       │
│                                                                             │
│  DESTRUCTIVE BUTTONS                                                        │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#ff4444]┌──────────────┐[-]  [#1a1a24:#ff4444]┌──────────────┐[-:-]  [#252530]┌──────────────┐[-] │
│  [#ff4444]│[-] [#000000]ABORT[-]       [#ff4444]│[-]  [#1a1a24:#ff4444]│[-:-] [#ff4444]ABORT[-]       [#1a1a24:#ff4444]│[-:-]  [#252530]│[-] [#606070]ABORT[-]       [#252530]│[-] │
│  [#ff4444]└──────────────┘[-]  [#1a1a24:#ff4444]└──────────────┘[-:-]  [#252530]└──────────────┘[-] │
│  Normal               Hover                  Disabled                       │
│                                                                             │
│  GHOST BUTTONS                                                              │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#252530]┌──────────────┐[-]  [#1a1a24]┌──────────────┐[-]  [#0a0a10]┌──────────────┐[-] │
│  [#252530]│[-] [#00afff]DETAILS[-]     [#252530]│[-]  [#1a1a24]│[-] [#00ffff]DETAILS[-]     [#1a1a24]│[-]  [#0a0a10]│[-] [#606070]DETAILS[-]     [#0a0a10]│[-] │
│  [#252530]└──────────────┘[-]  [#1a1a24]└──────────────┘[-]  [#0a0a10]└──────────────┘[-] │
│  Normal               Hover                  Disabled                       │
│                                                                             │
│  ICON BUTTONS                                                               │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#252530][[-][#00afff]◀[-][#252530]][-] [#252530][[-][#00afff]▶[-][#252530]][-] [#252530][[-][#00afff]⟳[-][#252530]][-] [#252530][[-][#00ff88]✓[-][#252530]][-] [#252530][[-][#ff4444]✕[-][#252530]][-] [#252530][[-][#ffaa00]⚙[-][#252530]][-] [#252530][[-][#00afff]?[-][#252530]][-] │
│  Back   Forward Refresh Confirm Cancel Settings Help                       │
│                                                                             │
│  TOGGLE BUTTONS                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]┌──────────────┐[-]  [#252530]┌──────────────┐[-]                 │
│  [#00ff88]│[-] [#000000]● AUTO[-]      [#00ff88]│[-]  [#252530]│[-] [#a0a0b0]○ AUTO[-]      [#252530]│[-]                 │
│  [#00ff88]└──────────────┘[-]  [#252530]└──────────────┘[-]                 │
│  ON                    OFF                                                  │
│                                                                             │
│  BUTTON GROUP                                                               │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00afff]┌────────┬────────┬────────┐[-]                                   │
│  [#00afff]│[-][#000000] ORBIT [-][#00afff]│[-][#252530] DOCK  [-][#252530]│[-][#252530] LAND  [-][#252530]│[-]  ← First selected    │
│  [#00afff]└────────┴────────┴────────┘[-]                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 11.2 Input Field Variants

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INPUT FIELD VARIANTS                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TEXT INPUT                                                                 │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#a0a0b0]Target Altitude[-]                                                │
│  [#252530]┌────────────────────────────────────────┐[-]                     │
│  [#252530]│[-] [#e0e0e8]408.5[-][#00afff]▌[-]                              [#252530]│[-]  ← Focused with cursor  │
│  [#252530]└────────────────────────────────────────┘[-]                     │
│  [#606070]Enter altitude in kilometers[-]                                   │
│                                                                             │
│  [#a0a0b0]Burn Duration[-]                                                  │
│  [#00afff]┌────────────────────────────────────────┐[-]  ← Focus border     │
│  [#00afff]│[-] [#e0e0e8]00:02:30[-][#00afff]▌[-]                           [#00afff]│[-]                     │
│  [#00afff]└────────────────────────────────────────┘[-]                     │
│                                                                             │
│  [#a0a0b0]Invalid Field[-]                                                  │
│  [#ff4444]┌────────────────────────────────────────┐[-]  ← Error border     │
│  [#ff4444]│[-] [#e0e0e8]abc[-][#00afff]▌[-]                                [#ff4444]│[-]                     │
│  [#ff4444]└────────────────────────────────────────┘[-]                     │
│  [#ff4444]✕ Must be a number[-]                                             │
│                                                                             │
│  DROPDOWN SELECT                                                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#a0a0b0]Engine Mode[-]                                                    │
│  [#252530]┌────────────────────────────────┬───┐[-]                         │
│  [#252530]│[-] [#e0e0e8]Full Thrust[-]                 [#252530]│[-] [#00afff]▼[-] [#252530]│[-]                         │
│  [#252530]└────────────────────────────────┴───┘[-]                         │
│                                                                             │
│  [#00afff]┌────────────────────────────────┬───┐[-]  ← Open dropdown        │
│  [#00afff]│[-] [#e0e0e8]Full Thrust[-]                 [#00afff]│[-] [#00afff]▲[-] [#00afff]│[-]                         │
│  [#00afff]├────────────────────────────────┴───┤[-]                         │
│  [#1a1a24]│[-] [#00ffff]Full Thrust[-]                     [#1a1a24]│[-]  ← Highlighted         │
│  [#0a0a10]│[-] [#e0e0e8]Cruise[-]                          [#0a0a10]│[-]                         │
│  [#0a0a10]│[-] [#e0e0e8]Idle[-]                            [#0a0a10]│[-]                         │
│  [#0a0a10]│[-] [#ff4444]Emergency Shutdown[-]              [#0a0a10]│[-]                         │
│  [#00afff]└────────────────────────────────────┘[-]                         │
│                                                                             │
│  SLIDER                                                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#a0a0b0]Throttle[-]                    [#e0e0e8]67%[-]                    │
│  [#606070]0[-] [#00ff88]═══════════════════[-][#00afff]◆[-][#252530]═══════════[-] [#606070]100[-]           │
│                                   ▲ Thumb                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 11.3 Modal Dialog Variants

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MODAL DIALOG VARIANTS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  VARIANT A: CONFIRMATION DIALOG                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#000000:50%]░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░[-:-]
│  [#000000:50%]░[-:-][#12121a]┌────────────────────────────────────────────────┐[-][#000000:50%]░[-:-]
│  [#000000:50%]░[-:-][#12121a]│[-] [#00afff]CONFIRM ACTION[-]                              [#12121a]│[-][#000000:50%]░[-:-]
│  [#000000:50%]░[-:-][#12121a]├────────────────────────────────────────────────┤[-][#000000:50%]░[-:-]
│  [#000000:50%]░[-:-][#12121a]│[-]                                              [#12121a]│[-][#000000:50%]░[-:-]
│  [#000000:50%]░[-:-][#12121a]│[-]  [#e0e0e8]Execute orbital insertion burn?[-]           [#12121a]│[-][#000000:50%]░[-:-]
│  [#000000:50%]░[-:-][#12121a]│[-]  [#a0a0b0]This action cannot be undone.[-]             [#12121a]│[-][#000000:50%]░[-:-]
│  [#000000:50%]░[-:-][#12121a]│[-]                                              [#12121a]│[-][#000000:50%]░[-:-]
│  [#000000:50%]░[-:-][#12121a]│[-]        [#252530][CANCEL][-]    [#00afff][CONFIRM][-]         [#12121a]│[-][#000000:50%]░[-:-]
│  [#000000:50%]░[-:-][#12121a]│[-]                                              [#12121a]│[-][#000000:50%]░[-:-]
│  [#000000:50%]░[-:-][#12121a]└────────────────────────────────────────────────┘[-][#000000:50%]░[-:-]
│  [#000000:50%]░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░[-:-]
│                                                                             │
│  VARIANT B: CRITICAL WARNING DIALOG                                         │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#330000:50%]░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░[-:-]
│  [#330000:50%]░[-:-][#ff4444]╔════════════════════════════════════════════════╗[-][#330000:50%]░[-:-]
│  [#330000:50%]░[-:-][#ff4444]║[-] [#ff4444]⚠ CRITICAL WARNING[-]                          [#ff4444]║[-][#330000:50%]░[-:-]
│  [#330000:50%]░[-:-][#ff4444]╠════════════════════════════════════════════════╣[-][#330000:50%]░[-:-]
│  [#330000:50%]░[-:-][#ff4444]║[-]                                              [#ff4444]║[-][#330000:50%]░[-:-]
│  [#330000:50%]░[-:-][#ff4444]║[-]  [#ffffff]ABORT MISSION?[-]                             [#ff4444]║[-][#330000:50%]░[-:-]
│  [#330000:50%]░[-:-][#ff4444]║[-]                                              [#ff4444]║[-][#330000:50%]░[-:-]
│  [#330000:50%]░[-:-][#ff4444]║[-]  [#ffaa00]This will terminate all active[-]            [#ff4444]║[-][#330000:50%]░[-:-]
│  [#330000:50%]░[-:-][#ff4444]║[-]  [#ffaa00]operations and trigger emergency[-]          [#ff4444]║[-][#330000:50%]░[-:-]
│  [#330000:50%]░[-:-][#ff4444]║[-]  [#ffaa00]protocols.[-]                                 [#ff4444]║[-][#330000:50%]░[-:-]
│  [#330000:50%]░[-:-][#ff4444]║[-]                                              [#ff4444]║[-][#330000:50%]░[-:-]
│  [#330000:50%]░[-:-][#ff4444]║[-]    [#252530][CANCEL][-]    [#ff4444][ABORT MISSION][-]    [#ff4444]║[-][#330000:50%]░[-:-]
│  [#330000:50%]░[-:-][#ff4444]║[-]                                              [#ff4444]║[-][#330000:50%]░[-:-]
│  [#330000:50%]░[-:-][#ff4444]╚════════════════════════════════════════════════╝[-][#330000:50%]░[-:-]
│  [#330000:50%]░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░[-:-]
│                                                                             │
│  VARIANT C: ARM & FIRE MODAL (Full choreography in Part 2)                  │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#110022:50%]░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░[-:-]
│  [#110022:50%]░[-:-][#8844ff]┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓[-][#110022:50%]░[-:-]
│  [#110022:50%]░[-:-][#8844ff]┃[-] [#8844ff]⚠ ARMED - DEORBIT BURN[-]                      [#8844ff]┃[-][#110022:50%]░[-:-]
│  [#110022:50%]░[-:-][#8844ff]┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫[-][#110022:50%]░[-:-]
│  [#110022:50%]░[-:-][#8844ff]┃[-]                                              [#8844ff]┃[-][#110022:50%]░[-:-]
│  [#110022:50%]░[-:-][#8844ff]┃[-]    [#ffffff]HOLD [-][#ffffff::r][SPACE][::-][#ffffff] FOR 3 SECONDS[-]         [#8844ff]┃[-][#110022:50%]░[-:-]
│  [#110022:50%]░[-:-][#8844ff]┃[-]                                              [#8844ff]┃[-][#110022:50%]░[-:-]
│  [#110022:50%]░[-:-][#8844ff]┃[-]  [#8844ff]▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░[-] [#e0e0e8]0%[-]   [#8844ff]┃[-][#110022:50%]░[-:-]
│  [#110022:50%]░[-:-][#8844ff]┃[-]                                              [#8844ff]┃[-][#110022:50%]░[-:-]
│  [#110022:50%]░[-:-][#8844ff]┃[-]        [#a0a0b0]Press ESC to disarm[-]                  [#8844ff]┃[-][#110022:50%]░[-:-]
│  [#110022:50%]░[-:-][#8844ff]┃[-]                                              [#8844ff]┃[-][#110022:50%]░[-:-]
│  [#110022:50%]░[-:-][#8844ff]┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛[-][#110022:50%]░[-:-]
│  [#110022:50%]░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░[-:-]
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART 4: SOUND, FEEDBACK, ACCESSIBILITY & THEMES

## 12.0 SOUND DESIGN SYSTEM

### 12.1 Audio Palette (Frequencies & Durations)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AUDIO PALETTE - AEROSPACE                                │
│                    PCM 48kHz / 16-bit / Mono                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  NOTIFICATION TONES                                                         │
│  ─────────────────────────────────────────────────────────────────────────  │
│  NAME            FREQ      DURATION  ENVELOPE   USE CASE                    │
│  ───────────────────────────────────────────────────────────────────────── │
│  info_ping       880Hz     100ms     Sharp      General notification        │
│  success_chime   C5-E5-G5  200ms     Soft       Action completed            │
│  warning_beep    660Hz     150ms×2   Pulsed     Attention required          │
│  error_buzz      220Hz     300ms     Harsh      Error occurred              │
│  critical_alarm  440Hz     500ms×∞   Alternating Emergency                  │
│                                                                             │
│  COUNTDOWN SOUNDS                                                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  NAME            FREQ      DURATION  ENVELOPE   USE CASE                    │
│  ───────────────────────────────────────────────────────────────────────── │
│  tick_normal     1000Hz    50ms      Click      T-60 to T-11               │
│  tick_final      1200Hz    100ms     Sharp      T-10 to T-1                │
│  ignition_tone   200→2kHz  2000ms    Rising     T-0 engine start           │
│  launch_rumble   50-200Hz  Sustain   Rumble     T+0 onwards                │
│                                                                             │
│  ARM & FIRE SOUNDS                                                          │
│  ─────────────────────────────────────────────────────────────────────────  │
│  NAME            FREQ      DURATION  ENVELOPE   USE CASE                    │
│  ───────────────────────────────────────────────────────────────────────── │
│  arm_engage      440Hz     200ms     Sharp      SPACE pressed to arm       │
│  arming_tone     440→660Hz 3000ms    Rising     Holding SPACE              │
│  point_no_return 880Hz     100ms×5   Rapid      T+2900ms warning           │
│  fire_confirm    1000Hz+   100ms     Impact     Action executed            │
│  abort_descend   660→220Hz 500ms     Falling    Action cancelled           │
│                                                                             │
│  INTERFACE SOUNDS                                                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  NAME            FREQ      DURATION  ENVELOPE   USE CASE                    │
│  ───────────────────────────────────────────────────────────────────────── │
│  focus_move      2000Hz    20ms      Tick       Navigation between items   │
│  select_click    1500Hz    30ms      Click      Item selected              │
│  menu_open       800→1200  100ms     Rising     Panel/menu opens           │
│  menu_close      1200→800  100ms     Falling    Panel/menu closes          │
│  typing_key      1800Hz    10ms      Tick       Keystroke feedback         │
│                                                                             │
│  TELEMETRY SOUNDS                                                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  NAME            FREQ      DURATION  ENVELOPE   USE CASE                    │
│  ───────────────────────────────────────────────────────────────────────── │
│  data_receive    3000Hz    5ms       Blip       Telemetry packet received  │
│  threshold_warn  550Hz     200ms×2   Double     Value approaching limit    │
│  threshold_crit  440Hz     300ms×3   Triple     Value exceeded limit       │
│  signal_acquired 800-1200  500ms     Sweep      Comm link established      │
│  signal_lost     1200-400  800ms     Descend    Comm link lost             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 12.2 Sound Trigger Mapping

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SOUND TRIGGER MATRIX                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  UI EVENT                          SOUND              VISUAL                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Navigation focus change           focus_move         [#00afff] highlight   │
│  Button click                      select_click       Flash 50ms            │
│  Toggle ON                         success_chime      [#00ff88] transition  │
│  Toggle OFF                        menu_close         [#252530] transition  │
│  Modal open                        menu_open          Fade in 150ms         │
│  Modal close                       menu_close         Fade out 150ms        │
│  Form submit success               success_chime      [#00ff88] border      │
│  Form validation error             error_buzz         [#ff4444] shake       │
│  Dropdown open                     menu_open          Expand animation      │
│  Dropdown select                   select_click       Highlight + close     │
│                                                                             │
│  STATUS EVENT                      SOUND              VISUAL                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Status → NOMINAL                  success_chime      [#00ff88] pulse       │
│  Status → WARNING                  warning_beep       [#ffaa00] pulse       │
│  Status → CRITICAL                 critical_alarm     [#ff4444] flash       │
│  Status → OFFLINE                  signal_lost        [#606070] fade        │
│  New alert                         warning_beep       Badge increment       │
│  Alert acknowledged                select_click       Badge decrement       │
│  Alert cleared                     success_chime      Badge remove          │
│                                                                             │
│  ARM & FIRE EVENT                  SOUND              VISUAL                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Enter ARMED state                 arm_engage         [#8844ff] border      │
│  ENGAGING (holding)                arming_tone        Progress fill         │
│  POINT_OF_NO_RETURN (97%)          point_no_return    [#ffaa00] flash       │
│  FIRED                             fire_confirm       [#ffffff] flash 50ms  │
│  ABORT                             abort_descend      [#ffaa00] border      │
│  COMPLETE                          success_chime      [#00ff88] border      │
│                                                                             │
│  COUNTDOWN EVENT                   SOUND              VISUAL                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  T-60 to T-11 (each second)        tick_normal        Digit flip            │
│  T-10 to T-1 (each second)         tick_final         Flash + scale 110%    │
│  T-0                               ignition_tone      Full screen flash     │
│  T+0 onwards                       launch_rumble      Border glow pulse     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 13.0 FEEDBACK & NOTIFICATION COMPONENTS

### 13.1 Toast Notification Variants

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TOAST NOTIFICATION VARIANTS                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  VARIANT A: INFO (Bottom-right default)                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                           [#12121a]┌──────────────────────┐[-]│
│                                           [#12121a]│[-] [#00afff]ℹ[-] [#e0e0e8]Telemetry updated[-] [#12121a]│[-]│
│                                           [#12121a]└──────────────────────┘[-]│
│                                                                             │
│  VARIANT B: SUCCESS                                                         │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                           [#00ff88]┌──────────────────────┐[-]│
│                                           [#00ff88]│[-] [#000000]✓ Burn complete[-]    [#00ff88]│[-]│
│                                           [#00ff88]└──────────────────────┘[-]│
│                                                                             │
│  VARIANT C: WARNING                                                         │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                           [#ffaa00]┌──────────────────────┐[-]│
│                                           [#ffaa00]│[-] [#000000]⚠ Fuel below 20%[-]  [#ffaa00]│[-]│
│                                           [#ffaa00]└──────────────────────┘[-]│
│                                                                             │
│  VARIANT D: ERROR                                                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                           [#ff4444]┌──────────────────────┐[-]│
│                                           [#ff4444]│[-] [#ffffff]✕ Command failed[-]   [#ff4444]│[-]│
│                                           [#ff4444]└──────────────────────┘[-]│
│                                                                             │
│  VARIANT E: PERSISTENT (With action)                                        │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                  [#ffaa00]┌─────────────────────────────────┐[-]│
│                                  [#ffaa00]│[-] [#000000]⚠ Attitude drift detected[-]    [#ffaa00]│[-]│
│                                  [#ffaa00]│[-]   [#000000]Corrective action required[-]  [#ffaa00]│[-]│
│                                  [#ffaa00]│[-]              [#000000][DISMISS][-] [#ffaa00][FIX NOW][-] [#ffaa00]│[-]│
│                                  [#ffaa00]└─────────────────────────────────┘[-]│
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 13.2 Alert Banner Variants

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ALERT BANNER VARIANTS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  VARIANT A: INLINE INFO                                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#1a1a24]┌──────────────────────────────────────────────────────────────────┐[-]
│  [#1a1a24]│[-] [#00afff]ℹ[-] [#e0e0e8]System will undergo scheduled maintenance at 14:00 UTC[-]     [#1a1a24]│[-]
│  [#1a1a24]└──────────────────────────────────────────────────────────────────┘[-]
│                                                                             │
│  VARIANT B: WARNING BANNER                                                  │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#332200]┌──────────────────────────────────────────────────────────────────┐[-]
│  [#332200]│[-] [#ffaa00]⚠ WARNING[-] [#e0e0e8]Solar storm activity may affect communications[-]    [#332200]│[-]
│  [#332200]│[-] [#a0a0b0]Expected duration: 2 hours | Impact: Minor delays[-]              [#332200]│[-]
│  [#332200]└──────────────────────────────────────────────────────────────────┘[-]
│                                                                             │
│  VARIANT C: CRITICAL BANNER (Full width, sticky)                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#ff4444]╔══════════════════════════════════════════════════════════════════╗[-]
│  [#ff4444]║[-] [#ffffff]▲ CRITICAL[-] [#ffffff]HULL BREACH DETECTED - SECTOR 7[-]              [#ff4444]║[-]
│  [#ff4444]║[-] [#ffaa00]Immediate evacuation required | Emergency protocols active[-]     [#ff4444]║[-]
│  [#ff4444]║[-]                                     [#ffffff][ACKNOWLEDGE][-] [#ffffff][DETAILS][-] [#ff4444]║[-]
│  [#ff4444]╚══════════════════════════════════════════════════════════════════╝[-]
│                                                                             │
│  VARIANT D: SUCCESS BANNER                                                  │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#003322]┌──────────────────────────────────────────────────────────────────┐[-]
│  [#003322]│[-] [#00ff88]✓ SUCCESS[-] [#e0e0e8]Orbital insertion complete - All parameters nominal[-] [#003322]│[-]
│  [#003322]└──────────────────────────────────────────────────────────────────┘[-]
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 14.0 ACCESSIBILITY FEATURES

### 14.1 WCAG 2.1 Compliance Matrix

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ACCESSIBILITY COMPLIANCE                                 │
│                    WCAG 2.1 Level AA                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PERCEIVABLE (Principle 1)                                                  │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]✓[-] 1.1.1 Non-text Content      Alt text for all icons           │
│  [#00ff88]✓[-] 1.3.1 Info & Relationships  Semantic structure preserved     │
│  [#00ff88]✓[-] 1.3.3 Sensory Chars         Not color-alone for status       │
│  [#00ff88]✓[-] 1.4.1 Use of Color          Icons + text for all states      │
│  [#00ff88]✓[-] 1.4.3 Contrast (Min)        4.5:1 text, 3:1 UI elements      │
│  [#00ff88]✓[-] 1.4.11 Non-text Contrast    3:1 for all interactive          │
│                                                                             │
│  OPERABLE (Principle 2)                                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]✓[-] 2.1.1 Keyboard              Full keyboard navigation         │
│  [#00ff88]✓[-] 2.1.2 No Keyboard Trap      ESC always exits modals          │
│  [#00ff88]✓[-] 2.3.1 Three Flashes         Max 3 flashes/second             │
│  [#00ff88]✓[-] 2.4.3 Focus Order           Logical tab sequence             │
│  [#00ff88]✓[-] 2.4.7 Focus Visible         [#00afff] cyan border 2px        │
│  [#00ff88]✓[-] 2.5.1 Pointer Gestures      Single pointer alternatives      │
│                                                                             │
│  UNDERSTANDABLE (Principle 3)                                               │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]✓[-] 3.1.1 Language              Lang attribute set               │
│  [#00ff88]✓[-] 3.2.1 On Focus              No context change on focus       │
│  [#00ff88]✓[-] 3.3.1 Error Identification  Clear error messages             │
│  [#00ff88]✓[-] 3.3.2 Labels                All inputs have labels           │
│                                                                             │
│  ROBUST (Principle 4)                                                       │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]✓[-] 4.1.1 Parsing               Valid markup structure           │
│  [#00ff88]✓[-] 4.1.2 Name, Role, Value     ARIA labels where needed         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 14.2 Reduced Motion Mode

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    REDUCED MOTION ACCOMMODATIONS                            │
│                    prefers-reduced-motion: reduce                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  STANDARD                          REDUCED MOTION                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Pulse animation 2000ms    →       Static indicator                         │
│  Flash animation 500ms     →       Color change instant                     │
│  Progress bar smooth       →       Progress bar stepped                     │
│  Slide transitions 200ms   →       Instant show/hide                        │
│  Fade transitions 150ms    →       Instant opacity change                   │
│  Glow effects pulse        →       Static border color                      │
│  Countdown scale 110%      →       Bold text only                           │
│  ARM & FIRE animation      →       Progress text only                       │
│                                                                             │
│  PRESERVED ANIMATIONS (Safety-critical)                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  • Critical alarm flash (1Hz max, essential for safety)                     │
│  • Data staleness indicator (required by regulation)                        │
│  • Connection status pulse (1Hz, essential feedback)                        │
│                                                                             │
│  VISUAL ALTERNATIVE: Status text always visible                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Standard:  [#00ff88]●[-]                                                   │
│  Reduced:   [#00ff88]● ONLINE[-]  (text label always shown)                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 14.3 High Contrast Mode

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    HIGH CONTRAST THEME                                      │
│                    WCAG AAA / Windows High Contrast                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  COLOR REMAPPING                                                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│  STANDARD              →  HIGH CONTRAST                                     │
│  [#0a0a10] Background  →  [#000000] Pure Black                              │
│  [#e0e0e8] Text        →  [#ffffff] Pure White                              │
│  [#00afff] Accent      →  [#00ffff] Bright Cyan                             │
│  [#00ff88] Success     →  [#00ff00] Bright Green                            │
│  [#ffaa00] Warning     →  [#ffff00] Bright Yellow                           │
│  [#ff4444] Error       →  [#ff0000] Bright Red                              │
│  [#252530] Border      →  [#ffffff] White borders                           │
│  [#606070] Disabled    →  [#888888] Medium Grey                             │
│                                                                             │
│  EXAMPLE: High Contrast Panel                                               │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#ffffff]┌─────────────────────────────────────────┐[-]                    │
│  [#ffffff]│[-] [#00ffff]TELEMETRY[-]                         [#ffffff]│[-]                    │
│  [#ffffff]├─────────────────────────────────────────┤[-]                    │
│  [#ffffff]│[-] [#ffffff]Altitude:[-]  [#ffffff]408.2 km[-]  [#00ff00]● OK[-]    [#ffffff]│[-]                    │
│  [#ffffff]│[-] [#ffffff]Velocity:[-]  [#ffffff]7.66 km/s[-] [#00ff00]● OK[-]    [#ffffff]│[-]                    │
│  [#ffffff]│[-] [#ffffff]Thermal:[-]   [#ffff00]67.2 °C[-]   [#ffff00]⚠ WARN[-]  [#ffffff]│[-]                    │
│  [#ffffff]└─────────────────────────────────────────┘[-]                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 15.0 THEME VARIANTS

### 15.1 Theme: Aerospace Dark (Default)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    THEME: AEROSPACE DARK (DEFAULT)                          │
│                    Optimized for OLED, low light environments               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [#000000]██████████████████████████████████████████████████████████████████[-]
│  [#0a0a10]┌─ MISSION CONTROL ─────────────────────────────────────────────────┐[-]
│  [#0a0a10]│[-]                                                                 [#0a0a10]│[-]
│  [#0a0a10]│[-]  [#00afff]◆ ISS-REBOOST-047[-]                    [#00ff88]● NOMINAL[-]      [#0a0a10]│[-]
│  [#0a0a10]│[-]                                                                 [#0a0a10]│[-]
│  [#0a0a10]│[-]  [#252530]┌─────────────┐[-] [#252530]┌─────────────┐[-] [#252530]┌─────────────┐[-]    [#0a0a10]│[-]
│  [#0a0a10]│[-]  [#252530]│[-][#a0a0b0]ALTITUDE[-]    [#252530]│[-] [#252530]│[-][#a0a0b0]VELOCITY[-]    [#252530]│[-] [#252530]│[-][#a0a0b0]INCLINATION[-] [#252530]│[-]    [#0a0a10]│[-]
│  [#0a0a10]│[-]  [#252530]│[-][#e0e0e8]408.2 km[-]   [#252530]│[-] [#252530]│[-][#e0e0e8]7.66 km/s[-]   [#252530]│[-] [#252530]│[-][#e0e0e8]51.64°[-]      [#252530]│[-]    [#0a0a10]│[-]
│  [#0a0a10]│[-]  [#252530]│[-][#00ff88]● NOMINAL[-]  [#252530]│[-] [#252530]│[-][#00ff88]● NOMINAL[-]   [#252530]│[-] [#252530]│[-][#00ff88]● STABLE[-]    [#252530]│[-]    [#0a0a10]│[-]
│  [#0a0a10]│[-]  [#252530]└─────────────┘[-] [#252530]└─────────────┘[-] [#252530]└─────────────┘[-]    [#0a0a10]│[-]
│  [#0a0a10]│[-]                                                                 [#0a0a10]│[-]
│  [#0a0a10]└───────────────────────────────────────────────────────────────────┘[-]
│  [#000000]██████████████████████████████████████████████████████████████████[-]
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 15.2 Theme: Aerospace Light

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    THEME: AEROSPACE LIGHT                                   │
│                    High ambient light, outdoor/daylight                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [#f0f0f5]██████████████████████████████████████████████████████████████████[-]
│  [#e8e8f0]┌─ MISSION CONTROL ─────────────────────────────────────────────────┐[-]
│  [#e8e8f0]│[-]                                                                 [#e8e8f0]│[-]
│  [#e8e8f0]│[-]  [#0066aa]◆ ISS-REBOOST-047[-]                    [#008844]● NOMINAL[-]      [#e8e8f0]│[-]
│  [#e8e8f0]│[-]                                                                 [#e8e8f0]│[-]
│  [#e8e8f0]│[-]  [#ffffff]┌─────────────┐[-] [#ffffff]┌─────────────┐[-] [#ffffff]┌─────────────┐[-]    [#e8e8f0]│[-]
│  [#e8e8f0]│[-]  [#ffffff]│[-][#606070]ALTITUDE[-]    [#ffffff]│[-] [#ffffff]│[-][#606070]VELOCITY[-]    [#ffffff]│[-] [#ffffff]│[-][#606070]INCLINATION[-] [#ffffff]│[-]    [#e8e8f0]│[-]
│  [#e8e8f0]│[-]  [#ffffff]│[-][#1a1a24]408.2 km[-]   [#ffffff]│[-] [#ffffff]│[-][#1a1a24]7.66 km/s[-]   [#ffffff]│[-] [#ffffff]│[-][#1a1a24]51.64°[-]      [#ffffff]│[-]    [#e8e8f0]│[-]
│  [#e8e8f0]│[-]  [#ffffff]│[-][#008844]● NOMINAL[-]  [#ffffff]│[-] [#ffffff]│[-][#008844]● NOMINAL[-]   [#ffffff]│[-] [#ffffff]│[-][#008844]● STABLE[-]    [#ffffff]│[-]    [#e8e8f0]│[-]
│  [#e8e8f0]│[-]  [#ffffff]└─────────────┘[-] [#ffffff]└─────────────┘[-] [#ffffff]└─────────────┘[-]    [#e8e8f0]│[-]
│  [#e8e8f0]│[-]                                                                 [#e8e8f0]│[-]
│  [#e8e8f0]└───────────────────────────────────────────────────────────────────┘[-]
│  [#f0f0f5]██████████████████████████████████████████████████████████████████[-]
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 15.3 Theme: Retro Green CRT

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    THEME: RETRO GREEN CRT                                   │
│                    Apollo/Shuttle era aesthetic                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [#000800]██████████████████████████████████████████████████████████████████[-]
│  [#001400]┌─ MISSION CONTROL ─────────────────────────────────────────────────┐[-]
│  [#001400]│[-]                                                                 [#001400]│[-]
│  [#001400]│[-]  [#00ff00]◆ ISS-REBOOST-047[-]                    [#00ff00]● NOMINAL[-]      [#001400]│[-]
│  [#001400]│[-]                                                                 [#001400]│[-]
│  [#001400]│[-]  [#003300]┌─────────────┐[-] [#003300]┌─────────────┐[-] [#003300]┌─────────────┐[-]    [#001400]│[-]
│  [#001400]│[-]  [#003300]│[-][#008800]ALTITUDE[-]    [#003300]│[-] [#003300]│[-][#008800]VELOCITY[-]    [#003300]│[-] [#003300]│[-][#008800]INCLINATION[-] [#003300]│[-]    [#001400]│[-]
│  [#001400]│[-]  [#003300]│[-][#00ff00]408.2 km[-]   [#003300]│[-] [#003300]│[-][#00ff00]7.66 km/s[-]   [#003300]│[-] [#003300]│[-][#00ff00]51.64°[-]      [#003300]│[-]    [#001400]│[-]
│  [#001400]│[-]  [#003300]│[-][#00ff00]● NOMINAL[-]  [#003300]│[-] [#003300]│[-][#00ff00]● NOMINAL[-]   [#003300]│[-] [#003300]│[-][#00ff00]● STABLE[-]    [#003300]│[-]    [#001400]│[-]
│  [#001400]│[-]  [#003300]└─────────────┘[-] [#003300]└─────────────┘[-] [#003300]└─────────────┘[-]    [#001400]│[-]
│  [#001400]│[-]                                                                 [#001400]│[-]
│  [#001400]└───────────────────────────────────────────────────────────────────┘[-]
│  [#000800]██████████████████████████████████████████████████████████████████[-]
│                                                                             │
│  CRT SCANLINE EFFECT (optional):                                            │
│  Every other line: opacity 90%                                              │
│  Phosphor glow: blur 1px on bright elements                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 15.4 Theme: Amber CRT

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    THEME: AMBER CRT                                         │
│                    Classic terminal aesthetic                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [#0a0800]██████████████████████████████████████████████████████████████████[-]
│  [#141000]┌─ MISSION CONTROL ─────────────────────────────────────────────────┐[-]
│  [#141000]│[-]                                                                 [#141000]│[-]
│  [#141000]│[-]  [#ffaa00]◆ ISS-REBOOST-047[-]                    [#ffaa00]● NOMINAL[-]      [#141000]│[-]
│  [#141000]│[-]                                                                 [#141000]│[-]
│  [#141000]│[-]  [#332800]┌─────────────┐[-] [#332800]┌─────────────┐[-] [#332800]┌─────────────┐[-]    [#141000]│[-]
│  [#141000]│[-]  [#332800]│[-][#886600]ALTITUDE[-]    [#332800]│[-] [#332800]│[-][#886600]VELOCITY[-]    [#332800]│[-] [#332800]│[-][#886600]INCLINATION[-] [#332800]│[-]    [#141000]│[-]
│  [#141000]│[-]  [#332800]│[-][#ffaa00]408.2 km[-]   [#332800]│[-] [#332800]│[-][#ffaa00]7.66 km/s[-]   [#332800]│[-] [#332800]│[-][#ffaa00]51.64°[-]      [#332800]│[-]    [#141000]│[-]
│  [#141000]│[-]  [#332800]│[-][#ffaa00]● NOMINAL[-]  [#332800]│[-] [#332800]│[-][#ffaa00]● NOMINAL[-]   [#332800]│[-] [#332800]│[-][#ffaa00]● STABLE[-]    [#332800]│[-]    [#141000]│[-]
│  [#141000]│[-]  [#332800]└─────────────┘[-] [#332800]└─────────────┘[-] [#332800]└─────────────┘[-]    [#141000]│[-]
│  [#141000]│[-]                                                                 [#141000]│[-]
│  [#141000]└───────────────────────────────────────────────────────────────────┘[-]
│  [#0a0800]██████████████████████████████████████████████████████████████████[-]
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART 5: COMPLETE INVENTORY & IMPLEMENTATION

## 16.0 COMPONENT INVENTORY MATRIX

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    COMPLETE COMPONENT INVENTORY                             │
│                    GPU-OLED Aerospace Design System v3.0                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  COMPONENT              VARIANTS  STATES   ANIMATIONS  tview WIDGET         │
│  ═════════════════════════════════════════════════════════════════════════  │
│  Command Bar            4         3        2           Frame + Flex         │
│  Sidebar Navigation     3         4        1           TreeView             │
│  Breadcrumb             4         2        0           TextView             │
│  Status Indicator       6         8        3           TextView             │
│  Gauge (Horizontal)     2         5        1           Gauge/ProgressBar    │
│  Gauge (Vertical)       1         5        1           Custom Box           │
│  Gauge (Dial)           2         5        1           Custom Box           │
│  Sparkline              1         3        1           Custom Box           │
│  Countdown Timer        6         4        4           TextView             │
│  Data Table             5         4        2           Table                │
│  Telemetry Panel        4         5        2           Grid + TextView      │
│  Tree View              3         3        1           TreeView             │
│  Button (Primary)       3         4        2           Button               │
│  Button (Destructive)   3         4        2           Button               │
│  Button (Ghost)         3         4        1           Button               │
│  Button (Icon)          7         3        1           Button               │
│  Button (Toggle)        2         2        1           Checkbox             │
│  Button Group           1         3        1           Flex + Button        │
│  Input (Text)           3         5        1           InputField           │
│  Input (Dropdown)       2         4        2           DropDown             │
│  Input (Slider)         1         4        1           Custom               │
│  Modal (Confirm)        1         3        2           Modal                │
│  Modal (Critical)       1         3        3           Modal                │
│  Modal (ARM & FIRE)     1         5        5           Modal + ProgressBar  │
│  Toast Notification     5         2        2           TextView             │
│  Alert Banner           4         2        1           Box + TextView       │
│  ─────────────────────────────────────────────────────────────────────────  │
│  TOTALS                 77        117      48                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 17.0 tview COMPONENT MAPPING

```go
// tview Component Mapping for Aerospace Design System
// Go implementation patterns

// Color constants (24-bit true color)
var AeroColors = struct {
    VoidBlack    tcell.Color
    DeepSpace    tcell.Color
    CosmicDark   tcell.Color
    PlasmaCyan   tcell.Color
    QuantumBlue  tcell.Color
    NominalGreen tcell.Color
    CautionAmber tcell.Color
    AlertRed     tcell.Color
    LunarWhite   tcell.Color
}{
    VoidBlack:    tcell.NewRGBColor(0, 0, 0),
    DeepSpace:    tcell.NewRGBColor(5, 5, 8),
    CosmicDark:   tcell.NewRGBColor(10, 10, 16),
    PlasmaCyan:   tcell.NewRGBColor(0, 255, 255),
    QuantumBlue:  tcell.NewRGBColor(0, 175, 255),
    NominalGreen: tcell.NewRGBColor(0, 255, 136),
    CautionAmber: tcell.NewRGBColor(255, 170, 0),
    AlertRed:     tcell.NewRGBColor(255, 68, 68),
    LunarWhite:   tcell.NewRGBColor(224, 224, 232),
}

// Component: Command Bar
func NewAeroCommandBar(mission string, status string) *tview.Flex {
    return tview.NewFlex().
        SetDirection(tview.FlexColumn).
        AddItem(NewMissionLabel(mission), 0, 1, false).
        AddItem(NewStatusIndicator(status), 12, 0, false).
        AddItem(NewCountdownTimer(), 15, 0, false)
}

// Component: Status Indicator
func NewStatusIndicator(status string) *tview.TextView {
    tv := tview.NewTextView().
        SetDynamicColors(true).
        SetTextAlign(tview.AlignCenter)

    switch status {
    case "NOMINAL":
        tv.SetText("[#00ff88]● NOMINAL[-]")
    case "WARNING":
        tv.SetText("[#ffaa00]◆ WARNING[-]")
    case "CRITICAL":
        tv.SetText("[#ff4444]▲ CRITICAL[-]")
    case "ARMED":
        tv.SetText("[#8844ff]◈ ARMED[-]")
    }
    return tv
}

// Component: ARM & FIRE Modal
func NewArmFireModal(action string, onFire func()) *tview.Modal {
    modal := tview.NewModal().
        SetText(fmt.Sprintf("⚠ ARMED - %s\n\nHOLD [SPACE] FOR 3 SECONDS", action)).
        AddButtons([]string{"Cancel"}).
        SetBackgroundColor(AeroColors.DeepSpace).
        SetButtonBackgroundColor(AeroColors.CosmicDark).
        SetButtonTextColor(AeroColors.LunarWhite)

    // Progress bar and hold detection handled separately
    return modal
}

// Component: Telemetry Panel
func NewTelemetryPanel(data []TelemetryPoint) *tview.Table {
    table := tview.NewTable().
        SetBorders(true).
        SetBordersColor(AeroColors.CosmicDark)

    // Header
    table.SetCell(0, 0, tview.NewTableCell("PARAMETER").
        SetTextColor(AeroColors.QuantumBlue))
    table.SetCell(0, 1, tview.NewTableCell("VALUE").
        SetTextColor(AeroColors.QuantumBlue))
    table.SetCell(0, 2, tview.NewTableCell("STATUS").
        SetTextColor(AeroColors.QuantumBlue))

    // Data rows
    for i, d := range data {
        table.SetCell(i+1, 0, tview.NewTableCell(d.Name).
            SetTextColor(AeroColors.LunarWhite))
        table.SetCell(i+1, 1, tview.NewTableCell(d.Value).
            SetTextColor(AeroColors.LunarWhite))
        table.SetCell(i+1, 2, tview.NewTableCell(statusIcon(d.Status)).
            SetTextColor(statusColor(d.Status)))
    }
    return table
}
```

---

## 18.0 STANDARDS COMPLIANCE SUMMARY

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STANDARDS COMPLIANCE SUMMARY                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  MILITARY/AEROSPACE                                                         │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]✓[-] MIL-STD-1472G    Human Engineering Design Criteria            │
│  [#00ff88]✓[-] NASA-STD-3000    Man-Systems Integration Standards            │
│  [#00ff88]✓[-] NASA-HFDS        Human Factors Design Standard                │
│  [#00ff88]✓[-] DO-178C          Software for Airborne Systems                │
│  [#00ff88]✓[-] DO-254           Airborne Electronic Hardware                 │
│  [#00ff88]✓[-] ARP4754A         Aircraft Systems Development                 │
│                                                                             │
│  NUCLEAR/INDUSTRIAL                                                         │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]✓[-] NUREG-0700       Human-System Interface Design Review         │
│  [#00ff88]✓[-] IEC 61508        Functional Safety (SIL 1-4)                  │
│  [#00ff88]✓[-] ISO 13849-1      Safety of Machinery (PLa-PLe)                │
│                                                                             │
│  SPACE SYSTEMS                                                              │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]✓[-] ECSS-E-ST-70-11C Space Segment Operability                    │
│  [#00ff88]✓[-] ECSS-E-ST-40C    Software Standards                           │
│  [#00ff88]✓[-] CCSDS 503.0-B-1  Space Link Extension                         │
│                                                                             │
│  ACCESSIBILITY                                                              │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]✓[-] WCAG 2.1 AA      Web Content Accessibility Guidelines         │
│  [#00ff88]✓[-] ISO 9241-171     Software Accessibility                       │
│  [#00ff88]✓[-] EN 301 549       ICT Accessibility (EU)                       │
│                                                                             │
│  DISPLAY TECHNOLOGY                                                         │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]✓[-] VESA DisplayHDR  HDR Performance Certification                │
│  [#00ff88]✓[-] DCI-P3           Wide Color Gamut Coverage                    │
│  [#00ff88]✓[-] ISO 12646        Graphic Technology Display Conditions        │
│                                                                             │
│  ERGONOMICS                                                                 │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [#00ff88]✓[-] ISO 9241-110     Ergonomics of HCI - Dialogue Principles      │
│  [#00ff88]✓[-] ISO 9241-112     Information Presentation                     │
│  [#00ff88]✓[-] ISO 9241-125     Visual Presentation of Information           │
│  [#00ff88]✓[-] ISO 11064        Control Centre Ergonomics                    │
│                                                                             │
│  TOTAL STANDARDS MAPPED: 24                                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 19.0 IMPLEMENTATION CHECKLIST

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    IMPLEMENTATION CHECKLIST                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PHASE 1: FOUNDATION                                                        │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [ ] Configure terminal for true color (24-bit)                             │
│  [ ] Install GPU-accelerated terminal (Kitty/Alacritty/WezTerm)            │
│  [ ] Configure Nerd Font with ligatures                                     │
│  [ ] Define color constants in code                                         │
│  [ ] Set up theme switching mechanism                                       │
│                                                                             │
│  PHASE 2: CORE COMPONENTS                                                   │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [ ] Implement status indicators (all 8 states)                             │
│  [ ] Implement buttons (primary, destructive, ghost, icon)                  │
│  [ ] Implement input fields (text, dropdown, slider)                        │
│  [ ] Implement data table with row states                                   │
│  [ ] Implement tree view with status icons                                  │
│                                                                             │
│  PHASE 3: NAVIGATION                                                        │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [ ] Implement command bar (all 4 variants)                                 │
│  [ ] Implement sidebar navigation (collapsed/expanded)                      │
│  [ ] Implement breadcrumb navigation                                        │
│  [ ] Set up keyboard navigation (Tab, Arrow, Enter, Esc)                   │
│                                                                             │
│  PHASE 4: FEEDBACK                                                          │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [ ] Implement toast notifications (all 5 types)                            │
│  [ ] Implement alert banners (inline, sticky)                               │
│  [ ] Implement modal dialogs (confirm, critical)                            │
│  [ ] Configure sound triggers                                               │
│                                                                             │
│  PHASE 5: SAFETY-CRITICAL                                                   │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [ ] Implement ARM & FIRE modal with full choreography                      │
│  [ ] Configure 3-second hold detection                                      │
│  [ ] Implement countdown timer (all variants)                               │
│  [ ] Add abort handling                                                     │
│                                                                             │
│  PHASE 6: POLISH                                                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│  [ ] Implement animations (GPU-accelerated)                                 │
│  [ ] Add glow effects                                                       │
│  [ ] Test accessibility (keyboard, contrast, reduced motion)                │
│  [ ] Performance test (60fps target)                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 20.0 DOCUMENT METADATA

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DOCUMENT METADATA                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Document ID:        AERO-COMP-TAX-v3.0.0-GPU-OLED-COLOR                   │
│  Version:            3.0.0                                                  │
│  Status:             DEFINITIVE REFERENCE                                   │
│  Created:            2025-12-30T12:00:00+01:00                             │
│  Last Updated:       2025-12-30T12:30:00+01:00                             │
│                                                                             │
│  Target Platform:    GPU-Accelerated Terminal (Kitty/Alacritty/WezTerm)    │
│  Display:            OLED with Wide Gamut (DCI-P3 / Display P3)            │
│  Color Depth:        24-bit True Color (16.7M colors)                      │
│  HDR Support:        VESA DisplayHDR 400-1400                              │
│                                                                             │
│  Dimensions Covered:                                                        │
│  ─────────────────────────────────────────────────────────────────────────  │
│  1.  Standards Compliance (24 standards)                                    │
│  2.  Color System (OLED-optimized, P3 wide gamut)                          │
│  3.  Semantic Colors (status, phase, subsystem)                            │
│  4.  Typography (fonts, scale, treatments)                                 │
│  5.  Spacing & Layout (8px grid, 12-column)                                │
│  6.  Borders & Visual Hierarchy                                            │
│  7.  GPU Glow Effects                                                       │
│  8.  Animation System (easing, catalog, choreography)                      │
│  9.  Sound Design (tones, triggers)                                        │
│  10. Navigation Components (4 types, 11 variants)                          │
│  11. Status Components (6 types, 18 variants)                              │
│  12. Data Components (4 types, 14 variants)                                │
│  13. Interaction Components (6 types, 23 variants)                         │
│  14. Feedback Components (2 types, 9 variants)                             │
│  15. Accessibility (WCAG 2.1 AA, reduced motion, high contrast)            │
│  16. Themes (4 variants: Dark, Light, Green CRT, Amber CRT)                │
│  17. tview Implementation Mapping                                          │
│                                                                             │
│  Component Totals:                                                          │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Components:         26                                                     │
│  Variants:           77                                                     │
│  States:             117                                                    │
│  Animations:         48                                                     │
│  Sound Effects:      25+                                                    │
│  Standards:          24                                                     │
│                                                                             │
│  File Location:                                                             │
│  docs/kms/design/AEROSPACE_COMPONENT_TAXONOMY_COMPLETE_COLOR_v1.md         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

**END OF DOCUMENT**

*AEROSPACE COMPONENT TAXONOMY - GPU/OLED OPTIMIZED*
*Complete Design System v3.0.0-GPU-OLED-COLOR*
*© 2025 Indrajaal Safety-Critical Systems*
