#!/usr/bin/env dotnet fsi
/// ═══════════════════════════════════════════════════════════════════════════════
/// AEROSPACE THEME SIMULATOR RUNNER
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Run with: dotnet fsi lib/cepaf/scripts/ThemeSimulatorRunner.fsx
///
/// Or compile and run:
///   cd lib/cepaf
///   dotnet build
///   dotnet run -- theme-sim
///
/// ═══════════════════════════════════════════════════════════════════════════════

#r "nuget: FSharp.Core, 8.0.0"

open System
open System.Text

// ═══════════════════════════════════════════════════════════════════════════════
// ANSI ESCAPE CODES
// ═══════════════════════════════════════════════════════════════════════════════

module Ansi =
    let reset = "\u001b[0m"
    let bold = "\u001b[1m"
    let dim = "\u001b[2m"
    let blink = "\u001b[5m"
    let clear = "\u001b[2J\u001b[H"
    let hideCursor = "\u001b[?25l"
    let showCursor = "\u001b[?25h"

    let fg r g b = sprintf "\u001b[38;2;%d;%d;%dm" r g b
    let bg r g b = sprintf "\u001b[48;2;%d;%d;%dm" r g b

// ═══════════════════════════════════════════════════════════════════════════════
// COLOR DEFINITIONS (From Aerospace Theme)
// ═══════════════════════════════════════════════════════════════════════════════

type Color = { R: int; G: int; B: int; Name: string }

let voidBlack = { R = 0; G = 0; B = 0; Name = "Void Black" }
let spaceBlack = { R = 10; G = 10; B = 15; Name = "Space Black" }
let deepSpace = { R = 13; G = 17; B = 23; Name = "Deep Space" }
let nightSky = { R = 21; G = 21; B = 32; Name = "Night Sky" }
let twilight = { R = 30; G = 30; B = 46; Name = "Twilight" }
let dusk = { R = 37; G = 37; B = 48; Name = "Dusk" }

let plasmaCyan = { R = 0; G = 255; B = 255; Name = "Plasma Cyan" }
let quantumBlue = { R = 0; G = 175; B = 255; Name = "Quantum Blue" }
let electricBlue = { R = 0; G = 128; B = 255; Name = "Electric Blue" }
let neonPurple = { R = 191; G = 0; B = 255; Name = "Neon Purple" }

let nominalGreen = { R = 0; G = 255; B = 136; Name = "Nominal Green" }
let cautionAmber = { R = 255; G = 170; B = 0; Name = "Caution Amber" }
let alertRed = { R = 255; G = 68; B = 68; Name = "Alert Red" }
let advisoryCyan = { R = 0; G = 221; B = 221; Name = "Advisory Cyan" }

let brightText = { R = 255; G = 255; B = 255; Name = "Bright Text" }
let normalText = { R = 224; G = 224; B = 224; Name = "Normal Text" }
let mutedText = { R = 128; G = 128; B = 144; Name = "Muted Text" }
let dimText = { R = 80; G = 80; B = 96; Name = "Dim Text" }

let dataBlue = { R = 68; G = 136; B = 255; Name = "Data Blue" }
let dataGreen = { R = 68; G = 255; B = 136; Name = "Data Green" }
let dataPurple = { R = 170; G = 68; B = 255; Name = "Data Purple" }

let fgC (c: Color) = Ansi.fg c.R c.G c.B
let bgC (c: Color) = Ansi.bg c.R c.G c.B

// ═══════════════════════════════════════════════════════════════════════════════
// SIMULATOR STATE
// ═══════════════════════════════════════════════════════════════════════════════

type Screen =
    | Overview
    | Navigation
    | Status
    | Data
    | Interaction
    | Feedback
    | ArmFire

type State = {
    Screen: Screen
    Frame: int
    Selected: int
    ArmState: string
    ArmProgress: float
    Width: int
    Height: int
}

let mutable state = {
    Screen = Overview
    Frame = 0
    Selected = 0
    ArmState = "idle"
    ArmProgress = 0.0
    Width = try Console.WindowWidth with _ -> 140
    Height = try Console.WindowHeight with _ -> 50
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDERING HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

let visibleLen (s: string) =
    System.Text.RegularExpressions.Regex.Replace(s, @"\u001b\[[0-9;]*m", "").Length

let padR (s: string) (w: int) =
    let vl = visibleLen s
    if vl < w then s + String.replicate (w - vl) " " else s

let hRule (c: char) (w: int) (color: Color option) =
    let line = String.replicate w (string c)
    match color with
    | Some col -> sprintf "%s%s%s" (fgC col) line Ansi.reset
    | None -> line

// ═══════════════════════════════════════════════════════════════════════════════
// COMPONENT RENDERERS
// ═══════════════════════════════════════════════════════════════════════════════

let renderSwatch (c: Color) =
    sprintf "%s██%s %-16s #%02X%02X%02X" (fgC c) Ansi.reset c.Name c.R c.G c.B

let renderStatusBadges () =
    [
        sprintf "  %s●%s Nominal   %s●%s Degraded  %s●%s Critical"
            (fgC nominalGreen) Ansi.reset
            (fgC cautionAmber) Ansi.reset
            (fgC alertRed) Ansi.reset
        sprintf "  %s◆%s Advisory  %s◐%s Stale     %s○%s Unknown"
            (fgC advisoryCyan) Ansi.reset
            (fgC mutedText) Ansi.reset
            (fgC dimText) Ansi.reset
    ]

let renderProgress frame =
    let progress = (float (frame % 100)) / 100.0
    let filled = int (progress * 20.0)
    let empty = 20 - filled
    let bar = sprintf "%s%s%s%s%s"
        (fgC nominalGreen)
        (String.replicate filled "█")
        (fgC dusk)
        (String.replicate empty "░")
        Ansi.reset
    [
        sprintf "  Linear:    [%s] %.0f%%" bar (progress * 100.0)
        sprintf "  Circular:  %s◐%s  %.0f%%" (fgC quantumBlue) Ansi.reset (progress * 100.0)
    ]

let renderSparkline () =
    let data = [| 3; 5; 7; 4; 8; 6; 9; 7; 5; 8; 6; 4; 7; 9; 8 |]
    let chars = [| "▁"; "▂"; "▃"; "▄"; "▅"; "▆"; "▇"; "█" |]
    let maxVal = Array.max data
    let spark =
        data
        |> Array.map (fun v ->
            let idx = int (float v / float maxVal * 7.0) |> min 7 |> max 0
            sprintf "%s%s%s" (fgC dataBlue) chars.[idx] Ansi.reset)
        |> String.concat ""
    [sprintf "  Trend: %s" spark]

let renderButtons sel =
    let variants = [
        ("Primary", plasmaCyan, voidBlack)
        ("Secondary", quantumBlue, voidBlack)
        ("Danger", alertRed, voidBlack)
        ("Success", nominalGreen, voidBlack)
    ]
    variants
    |> List.mapi (fun i (name, bgCol, fgCol) ->
        let selected = i = sel % variants.Length
        let prefix = if selected then "▸" else " "
        let btn = sprintf "%s%s %s %s" (bgC bgCol) (fgC fgCol) name Ansi.reset
        sprintf " %s %s%s" prefix btn (if selected then " ← selected" else ""))

let renderToasts () =
    [
        sprintf "  %s┌────────────────────────────┐%s" (fgC nominalGreen) Ansi.reset
        sprintf "  %s│%s %s✓%s Operation successful   %s│%s" (fgC nominalGreen) Ansi.reset (fgC nominalGreen) Ansi.reset (fgC nominalGreen) Ansi.reset
        sprintf "  %s└────────────────────────────┘%s" (fgC nominalGreen) Ansi.reset
        ""
        sprintf "  %s┌────────────────────────────┐%s" (fgC cautionAmber) Ansi.reset
        sprintf "  %s│%s %s⚠%s Warning: Check inputs  %s│%s" (fgC cautionAmber) Ansi.reset (fgC cautionAmber) Ansi.reset (fgC cautionAmber) Ansi.reset
        sprintf "  %s└────────────────────────────┘%s" (fgC cautionAmber) Ansi.reset
        ""
        sprintf "  %s┌────────────────────────────┐%s" (fgC alertRed) Ansi.reset
        sprintf "  %s│%s %s✗%s Error: Connection failed%s│%s" (fgC alertRed) Ansi.reset (fgC alertRed) Ansi.reset (fgC alertRed) Ansi.reset
        sprintf "  %s└────────────────────────────┘%s" (fgC alertRed) Ansi.reset
    ]

let renderArmFire armState armProgress frame =
    let (borderColor, label, icon) =
        match armState with
        | "idle" -> (mutedText, "ARM (Hold 3s)", "○")
        | "arming" -> (cautionAmber, sprintf "ARMING %.0f%%" (armProgress * 100.0), "◐")
        | "armed" ->
            let icon = if frame % 10 < 5 then "◉" else "○"
            (cautionAmber, "ARMED - CONFIRM?", icon)
        | "firing" -> (alertRed, "EXECUTING...", "●")
        | "complete" -> (nominalGreen, "COMPLETE", "✓")
        | _ -> (mutedText, "UNKNOWN", "?")

    let progressBar =
        if armState = "arming" then
            let filled = int (armProgress * 20.0)
            let empty = 20 - filled
            sprintf "  [%s%s%s%s%s]"
                (fgC cautionAmber)
                (String.replicate filled "█")
                (fgC dusk)
                (String.replicate empty "░")
                Ansi.reset
        else ""

    [
        sprintf "  %s╔════════════════════════╗%s" (fgC borderColor) Ansi.reset
        sprintf "  %s║%s  %s%s %s%s  %s║%s"
            (fgC borderColor) Ansi.reset
            (fgC borderColor) icon label
            Ansi.reset
            (fgC borderColor) Ansi.reset
        sprintf "  %s╚════════════════════════╝%s" (fgC borderColor) Ansi.reset
        progressBar
        ""
        sprintf "  Protocol: %sHold 3s%s → %sConfirm%s → %sExecute%s"
            (fgC cautionAmber) Ansi.reset
            (fgC alertRed) Ansi.reset
            (fgC nominalGreen) Ansi.reset
        ""
        sprintf "  Controls: %s[Space]%s ARM  %s[Enter]%s Confirm  %s[Esc]%s Reset"
            (fgC plasmaCyan) Ansi.reset
            (fgC nominalGreen) Ansi.reset
            (fgC cautionAmber) Ansi.reset
    ]

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN RENDERERS
// ═══════════════════════════════════════════════════════════════════════════════

let renderOverview () =
    [
        sprintf "%s━━━ AEROSPACE THEME - COLOR PALETTE ━━━%s" (fgC dusk) Ansi.reset
        ""
        "  Backgrounds:"
        sprintf "    %s" (renderSwatch voidBlack)
        sprintf "    %s" (renderSwatch spaceBlack)
        sprintf "    %s" (renderSwatch deepSpace)
        ""
        "  Accents:"
        sprintf "    %s" (renderSwatch plasmaCyan)
        sprintf "    %s" (renderSwatch quantumBlue)
        sprintf "    %s" (renderSwatch neonPurple)
        ""
        "  Semantic:"
        sprintf "    %s" (renderSwatch nominalGreen)
        sprintf "    %s" (renderSwatch cautionAmber)
        sprintf "    %s" (renderSwatch alertRed)
        ""
        sprintf "%s━━━ THEME STATISTICS ━━━%s" (fgC dusk) Ansi.reset
        sprintf "  Components: %s26%s   Variants: %s77%s   States: %s117%s"
            (fgC plasmaCyan) Ansi.reset
            (fgC quantumBlue) Ansi.reset
            (fgC electricBlue) Ansi.reset
    ]

let renderStatusScreen frame =
    [
        sprintf "%s━━━ STATUS COMPONENTS ━━━%s" (fgC dusk) Ansi.reset
        ""
        "  Status Badges:"
    ] @
    renderStatusBadges () @
    [""; "  Progress:"] @
    renderProgress frame @
    [""; "  Sparkline:"] @
    renderSparkline ()

let renderInteractionScreen sel =
    [
        sprintf "%s━━━ INTERACTION COMPONENTS ━━━%s" (fgC dusk) Ansi.reset
        ""
        "  Buttons:"
    ] @
    renderButtons sel

let renderFeedbackScreen () =
    [
        sprintf "%s━━━ FEEDBACK COMPONENTS ━━━%s" (fgC dusk) Ansi.reset
        ""
        "  Toast Notifications:"
        ""
    ] @
    renderToasts ()

let renderArmFireScreen armState armProgress frame =
    [
        sprintf "%s━━━ ARM & FIRE PROTOCOL ━━━%s" (fgC dusk) Ansi.reset
        ""
        "  Safety-Critical Action Button:"
        ""
    ] @
    renderArmFire armState armProgress frame

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN RENDER
// ═══════════════════════════════════════════════════════════════════════════════

let renderHeader () =
    let title = " ◆ AEROSPACE THEME SIMULATOR "
    let screen = sprintf " [%A] " state.Screen
    let frame = sprintf " Frame: %d " state.Frame
    let padding = state.Width - (visibleLen title) - (visibleLen screen) - (visibleLen frame)
    [
        sprintf "%s%s%s%s%s%s%s"
            (bgC plasmaCyan) (fgC voidBlack)
            title
            (String.replicate (max 0 padding) " ")
            screen frame
            Ansi.reset
        hRule '─' state.Width (Some dusk)
    ]

let renderFooter () =
    let help = " [1-6] Screens  [←→] Navigate  [Space] ARM  [q] Quit "
    [
        hRule '─' state.Width (Some dusk)
        sprintf "%s%s%s" (fgC mutedText) help Ansi.reset
    ]

let render () =
    let sb = StringBuilder()
    sb.Append(Ansi.clear) |> ignore

    for line in renderHeader () do sb.AppendLine(line) |> ignore

    let content =
        match state.Screen with
        | Overview -> renderOverview ()
        | Status -> renderStatusScreen state.Frame
        | Interaction -> renderInteractionScreen state.Selected
        | Feedback -> renderFeedbackScreen ()
        | ArmFire -> renderArmFireScreen state.ArmState state.ArmProgress state.Frame
        | _ -> [sprintf "Screen: %A" state.Screen]

    for line in content do sb.AppendLine(line) |> ignore
    for line in renderFooter () do sb.AppendLine(line) |> ignore

    Console.Write(sb.ToString())

// ═══════════════════════════════════════════════════════════════════════════════
// INPUT HANDLING
// ═══════════════════════════════════════════════════════════════════════════════

let handleInput (key: ConsoleKeyInfo) =
    match key.Key with
    | ConsoleKey.Q -> true  // Quit
    | ConsoleKey.D1 -> state <- { state with Screen = Overview }; false
    | ConsoleKey.D2 -> state <- { state with Screen = Status }; false
    | ConsoleKey.D3 -> state <- { state with Screen = Interaction }; false
    | ConsoleKey.D4 -> state <- { state with Screen = Feedback }; false
    | ConsoleKey.D5 -> state <- { state with Screen = ArmFire }; false
    | ConsoleKey.LeftArrow -> state <- { state with Selected = max 0 (state.Selected - 1) }; false
    | ConsoleKey.RightArrow -> state <- { state with Selected = state.Selected + 1 }; false
    | ConsoleKey.Spacebar when state.Screen = ArmFire ->
        let newArm = match state.ArmState with "idle" -> "arming" | "armed" -> "idle" | x -> x
        state <- { state with ArmState = newArm; ArmProgress = 0.0 }
        false
    | ConsoleKey.Enter when state.Screen = ArmFire && state.ArmState = "armed" ->
        state <- { state with ArmState = "firing" }
        false
    | ConsoleKey.Escape when state.Screen = ArmFire ->
        state <- { state with ArmState = "idle"; ArmProgress = 0.0 }
        false
    | _ -> false

let update () =
    state <- { state with
        Frame = state.Frame + 1
        Width = try Console.WindowWidth with _ -> 140
        Height = try Console.WindowHeight with _ -> 50
    }

    // Update ARM progress
    match state.ArmState with
    | "arming" ->
        let p = state.ArmProgress + 0.02
        if p >= 1.0 then state <- { state with ArmState = "armed"; ArmProgress = 1.0 }
        else state <- { state with ArmProgress = p }
    | "firing" when state.Frame % 30 = 0 ->
        state <- { state with ArmState = "complete"; ArmProgress = 0.0 }
    | "complete" when state.Frame % 60 = 0 ->
        state <- { state with ArmState = "idle"; ArmProgress = 0.0 }
    | _ -> ()

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN LOOP
// ═══════════════════════════════════════════════════════════════════════════════

printfn "Starting Aerospace Theme Simulator..."
printfn "Press any key to begin (q to quit)..."

Console.Write(Ansi.hideCursor)

let mutable quit = false
while not quit do
    render ()

    if Console.KeyAvailable then
        let key = Console.ReadKey(true)
        quit <- handleInput key
    else
        Threading.Thread.Sleep(16)
        update ()

Console.Write(Ansi.showCursor)
Console.Write(Ansi.clear)
printfn "Aerospace Theme Simulator closed."
printfn ""
printfn "Theme Summary:"
printfn "  - 17 Dimensions covered"
printfn "  - 26 Components, 77 Variants, 117 States"
printfn "  - 24 Standards compliance mappings"
printfn "  - GPU/OLED optimized with P3 wide gamut"
printfn ""
printfn "Files created:"
printfn "  - lib/cepaf/src/Cepaf/Cockpit/AerospaceTheme.fs (Data structures)"
printfn "  - lib/cepaf/src/Cepaf/Cockpit/ThemeEditor.fs (Editor UI)"
printfn "  - lib/cepaf/src/Cepaf/Cockpit/ThemeSimulator.fs (Simulator)"
