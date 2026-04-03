/// DarkCockpitUI Unit Tests
/// Tests for TUI rendering, ANSI output, and visual components
module Cepaf.Cockpit.Tests.DarkCockpitUITests

open System
open Expecto

// ============================================================================
// ANSI Color Tests
// ============================================================================

module AnsiColors =
    let reset = "\x1b[0m"
    let bold = "\x1b[1m"
    let dim = "\x1b[2m"

    // NASA Dark Cockpit Colors
    let black = "\x1b[30m"
    let red = "\x1b[31m"       // Critical
    let green = "\x1b[32m"     // Healthy
    let yellow = "\x1b[33m"    // Warning
    let blue = "\x1b[34m"      // Info
    let magenta = "\x1b[35m"
    let cyan = "\x1b[36m"      // Accent
    let white = "\x1b[37m"

    let bgBlack = "\x1b[40m"
    let bgRed = "\x1b[41m"
    let bgGreen = "\x1b[42m"
    let bgYellow = "\x1b[43m"

let colorize (color: string) (text: string) =
    sprintf "%s%s%s" color text AnsiColors.reset

let colorizeHealth (health: float) (text: string) =
    if health >= 90.0 then colorize AnsiColors.green text
    elif health >= 70.0 then colorize AnsiColors.yellow text
    else colorize AnsiColors.red text

[<Tests>]
let ansiColorTests =
    testList "AnsiColors" [
        test "should colorize text with green" {
            let result = colorize AnsiColors.green "OK"
            Expect.stringContains result "\x1b[32m" "Should contain green code"
            Expect.stringContains result "\x1b[0m" "Should contain reset"
            Expect.stringContains result "OK" "Should contain text"
        }

        test "should colorize health >=90 green" {
            let result = colorizeHealth 95.0 "95%"
            Expect.stringContains result AnsiColors.green "Should be green for >=90"
        }

        test "should colorize health 70-89 yellow" {
            let result = colorizeHealth 75.0 "75%"
            Expect.stringContains result AnsiColors.yellow "Should be yellow for 70-89"
        }

        test "should colorize health <70 red" {
            let result = colorizeHealth 50.0 "50%"
            Expect.stringContains result AnsiColors.red "Should be red for <70"
        }
    ]

// ============================================================================
// Box Drawing Tests
// ============================================================================

module BoxChars =
    let topLeft = '┌'
    let topRight = '┐'
    let bottomLeft = '└'
    let bottomRight = '┘'
    let horizontal = '─'
    let vertical = '│'
    let teeDown = '┬'
    let teeUp = '┴'
    let teeLeft = '┤'
    let teeRight = '├'
    let cross = '┼'

let drawBox (width: int) (height: int) (title: string option) =
    let top =
        match title with
        | Some t ->
            let titleLen = min t.Length (width - 4)
            let leftPad = (width - titleLen - 2) / 2
            let rightPad = width - titleLen - 2 - leftPad
            sprintf "%c%s %s %s%c"
                BoxChars.topLeft
                (String.replicate leftPad (string BoxChars.horizontal))
                t.[..titleLen-1]
                (String.replicate rightPad (string BoxChars.horizontal))
                BoxChars.topRight
        | None ->
            sprintf "%c%s%c"
                BoxChars.topLeft
                (String.replicate (width - 2) (string BoxChars.horizontal))
                BoxChars.topRight

    let middle =
        [1..height-2]
        |> List.map (fun _ ->
            sprintf "%c%s%c"
                BoxChars.vertical
                (String.replicate (width - 2) " ")
                BoxChars.vertical)

    let bottom =
        sprintf "%c%s%c"
            BoxChars.bottomLeft
            (String.replicate (width - 2) (string BoxChars.horizontal))
            BoxChars.bottomRight

    [top] @ middle @ [bottom]

[<Tests>]
let boxDrawingTests =
    testList "BoxDrawing" [
        test "should draw box with correct dimensions" {
            let box = drawBox 20 5 None
            Expect.equal box.Length 5 "Should have 5 lines"
            Expect.equal box.[0].Length 20 "First line should be 20 chars"
        }

        test "should include title in box" {
            let box = drawBox 20 5 (Some "TEST")
            Expect.stringContains box.[0] "TEST" "Should contain title"
        }

        test "should have correct corners" {
            let box = drawBox 10 3 None
            Expect.equal (box.[0].[0]) BoxChars.topLeft "Top-left corner"
            Expect.equal (box.[0].[9]) BoxChars.topRight "Top-right corner"
            Expect.equal (box.[2].[0]) BoxChars.bottomLeft "Bottom-left corner"
            Expect.equal (box.[2].[9]) BoxChars.bottomRight "Bottom-right corner"
        }

        test "should draw vertical borders" {
            let box = drawBox 10 5 None
            for i in 1..3 do
                Expect.equal (box.[i].[0]) BoxChars.vertical "Left border"
                Expect.equal (box.[i].[9]) BoxChars.vertical "Right border"
        }
    ]

// ============================================================================
// Progress Bar Tests
// ============================================================================

let progressBar (width: int) (value: float) (max: float) =
    let percentage = value / max
    let filled = int (float (width - 2) * percentage)
    let empty = width - 2 - filled
    sprintf "[%s%s]" (String.replicate filled "█") (String.replicate empty "░")

let progressBarWithLabel (width: int) (value: float) (max: float) (label: string) =
    let bar = progressBar (width - label.Length - 1) value max
    sprintf "%s %s" label bar

[<Tests>]
let progressBarTests =
    testList "ProgressBar" [
        test "should render empty progress bar" {
            let bar = progressBar 10 0.0 100.0
            Expect.equal bar "[░░░░░░░░]" "Should show empty bar"
        }

        test "should render full progress bar" {
            let bar = progressBar 10 100.0 100.0
            Expect.equal bar "[████████]" "Should show full bar"
        }

        test "should render half progress bar" {
            let bar = progressBar 10 50.0 100.0
            Expect.equal bar "[████░░░░]" "Should show half bar"
        }

        test "should include label" {
            let bar = progressBarWithLabel 20 75.0 100.0 "CPU:"
            Expect.stringContains bar "CPU:" "Should contain label"
            Expect.stringContains bar "█" "Should contain filled portion"
        }
    ]

// ============================================================================
// Gauge Tests
// ============================================================================

let gaugeDisplay (value: float) (min: float) (max: float) =
    let percentage = (value - min) / (max - min) * 100.0
    let indicator =
        if percentage >= 90.0 then "▲"
        elif percentage >= 70.0 then "●"
        elif percentage >= 50.0 then "◆"
        else "▼"
    sprintf "%s %.1f%%" indicator percentage

[<Tests>]
let gaugeTests =
    testList "Gauge" [
        test "should show high indicator for >=90%" {
            let gauge = gaugeDisplay 95.0 0.0 100.0
            Expect.stringContains gauge "▲" "Should show high indicator"
            Expect.stringContains gauge "95.0%" "Should show percentage"
        }

        test "should show medium-high indicator for 70-89%" {
            let gauge = gaugeDisplay 75.0 0.0 100.0
            Expect.stringContains gauge "●" "Should show medium-high indicator"
        }

        test "should show medium indicator for 50-69%" {
            let gauge = gaugeDisplay 55.0 0.0 100.0
            Expect.stringContains gauge "◆" "Should show medium indicator"
        }

        test "should show low indicator for <50%" {
            let gauge = gaugeDisplay 25.0 0.0 100.0
            Expect.stringContains gauge "▼" "Should show low indicator"
        }
    ]

// ============================================================================
// Spider Chart Tests (Text-based)
// ============================================================================

let spiderChart (values: (string * float) list) =
    // Simple text representation of spider chart values
    values
    |> List.map (fun (label, value) ->
        let bars = int (value / 10.0)
        sprintf "%s: %s %.0f%%" (label.PadRight(10)) (String.replicate bars "█") value)

[<Tests>]
let spiderChartTests =
    testList "SpiderChart" [
        test "should render all metrics" {
            let values = [
                ("CPU", 75.0)
                ("Memory", 60.0)
                ("Network", 90.0)
            ]
            let chart = spiderChart values
            Expect.equal chart.Length 3 "Should have 3 lines"
            Expect.stringContains chart.[0] "CPU" "Should contain CPU"
            Expect.stringContains chart.[1] "Memory" "Should contain Memory"
            Expect.stringContains chart.[2] "Network" "Should contain Network"
        }

        test "should show bar proportional to value" {
            let values = [("Test", 100.0)]
            let chart = spiderChart values
            let line = chart.[0]
            let barCount = line |> Seq.filter ((=) '█') |> Seq.length
            Expect.equal barCount 10 "100% should have 10 bars"
        }
    ]

// ============================================================================
// Status Line Tests
// ============================================================================

type StatusLine = {
    Label: string
    Value: string
    Status: string
    Color: string
}

let formatStatusLine (width: int) (status: StatusLine) : string =
    let labelWidth = 15
    let valueWidth = 20
    let _statusWidth = width - labelWidth - valueWidth - 4

    sprintf "%s│ %s│ %s"
        (status.Label.PadRight(labelWidth))
        (status.Value.PadRight(valueWidth))
        status.Status

[<Tests>]
let statusLineTests =
    testList "StatusLine" [
        test "should format status line" {
            let status = {
                Label = "Database"
                Value = "PostgreSQL 17"
                Status = "Running"
                Color = AnsiColors.green
            }
            let line = formatStatusLine 60 status
            Expect.stringContains line "Database" "Should contain label"
            Expect.stringContains line "PostgreSQL" "Should contain value"
            Expect.stringContains line "Running" "Should contain status"
        }
    ]

// ============================================================================
// Alarm List Tests
// ============================================================================

type AlarmDisplay = {
    Level: string
    Message: string
    Time: string
    Acked: bool
}

let formatAlarmLine (alarm: AlarmDisplay) =
    let ackStatus = if alarm.Acked then "[ACK]" else "[NEW]"
    sprintf "%s %s %s - %s" alarm.Level ackStatus alarm.Time alarm.Message

[<Tests>]
let alarmDisplayTests =
    testList "AlarmDisplay" [
        test "should format new alarm" {
            let alarm = {
                Level = "CRIT"
                Message = "CPU overload"
                Time = "10:30:45"
                Acked = false
            }
            let line = formatAlarmLine alarm
            Expect.stringContains line "[NEW]" "Should show NEW for unacked"
            Expect.stringContains line "CRIT" "Should show level"
            Expect.stringContains line "CPU overload" "Should show message"
        }

        test "should format acknowledged alarm" {
            let alarm = {
                Level = "WARN"
                Message = "Memory high"
                Time = "10:30:45"
                Acked = true
            }
            let line = formatAlarmLine alarm
            Expect.stringContains line "[ACK]" "Should show ACK for acked"
        }
    ]

// ============================================================================
// Layout Tests
// ============================================================================

type LayoutRegion = {
    X: int
    Y: int
    Width: int
    Height: int
}

let splitHorizontal (region: LayoutRegion) (ratio: float) =
    let leftWidth = int (float region.Width * ratio)
    let rightWidth = region.Width - leftWidth
    let left = { region with Width = leftWidth }
    let right = { region with X = region.X + leftWidth; Width = rightWidth }
    (left, right)

let splitVertical (region: LayoutRegion) (ratio: float) =
    let topHeight = int (float region.Height * ratio)
    let bottomHeight = region.Height - topHeight
    let top = { region with Height = topHeight }
    let bottom = { region with Y = region.Y + topHeight; Height = bottomHeight }
    (top, bottom)

[<Tests>]
let layoutTests =
    testList "Layout" [
        test "should split horizontal 50/50" {
            let region = { X = 0; Y = 0; Width = 100; Height = 50 }
            let (left, right) = splitHorizontal region 0.5
            Expect.equal left.Width 50 "Left should be 50"
            Expect.equal right.Width 50 "Right should be 50"
            Expect.equal right.X 50 "Right should start at 50"
        }

        test "should split vertical 30/70" {
            let region = { X = 0; Y = 0; Width = 100; Height = 100 }
            let (top, bottom) = splitVertical region 0.3
            Expect.equal top.Height 30 "Top should be 30"
            Expect.equal bottom.Height 70 "Bottom should be 70"
            Expect.equal bottom.Y 30 "Bottom should start at 30"
        }

        test "should preserve width in vertical split" {
            let region = { X = 10; Y = 20; Width = 80; Height = 60 }
            let (top, bottom) = splitVertical region 0.5
            Expect.equal top.Width region.Width "Top width should match"
            Expect.equal bottom.Width region.Width "Bottom width should match"
        }
    ]
