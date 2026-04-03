namespace Cepaf.Cockpit

open System
open System.Text
open System.Threading
open Cepaf.Cockpit.Domain

/// ═══════════════════════════════════════════════════════════════════════════════
/// C3I SITUATIONAL AWARENESS - SOUND & MOVEMENT SYSTEM
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// WHAT: Multi-sensory C3I system for enhanced situational awareness through
///       intelligent use of color, movement, screen space, and sound.
///
/// WHY: NASA-STD-3000 and MIL-STD-1472H mandate multi-modal alerting for
///      safety-critical systems. OODA loop optimization requires minimizing
///      cognitive load while maximizing response time.
///
/// DESIGN PRINCIPLES:
///   1. Sound for urgency signaling (not distraction)
///   2. Movement for attention capture (not animation theater)
///   3. Color for status encoding (Dark Cockpit philosophy)
///   4. Screen space for information density (management by exception)
///
/// STAMP Compliance:
///   - SC-HMI-008: Multi-modal alerting (sound + visual)
///   - SC-HMI-009: Movement for attention capture
///   - SC-HMI-010: Sound escalation protocol
///   - SC-HMI-011: Cognitive load management
///
/// ═══════════════════════════════════════════════════════════════════════════════
module SituationalAwareness =

    // ═══════════════════════════════════════════════════════════════════════════
    // SOUND SYSTEM - Auditory Situational Awareness
    // ═══════════════════════════════════════════════════════════════════════════

    module Sound =

        /// Sound urgency levels - escalating alertness
        type SoundUrgency =
            | Silent        // No sound
            | Subtle        // Soft click/tick (confirmation)
            | Informational // Single tone (advisory)
            | Attention     // Double beep (caution)
            | Urgent        // Triple beep (warning)
            | Critical      // Continuous alarm (critical)

        /// Sound patterns for different events
        type SoundPattern =
            | Click         // 100ms beep at 800Hz
            | Tick          // 50ms beep at 1000Hz
            | Chime         // Rising tone 400-800Hz
            | Beep          // 200ms beep at 1000Hz
            | DoubleBeep    // Two 150ms beeps
            | TripleBeep    // Three 100ms beeps
            | Alarm         // Continuous 500Hz pulsing
            | Success       // Rising chime (C-E-G)
            | Failure       // Falling tone (800-400Hz)
            | Heartbeat     // Slow double pulse (alive indicator)

        /// Terminal bell sequence (ANSI)
        let private bell = "\u0007"  // BEL character

        /// State for sound management
        type SoundState = {
            Enabled: bool
            LastSound: DateTime option
            MinInterval: TimeSpan         // Minimum time between sounds
            MutedUntil: DateTime option
            CurrentUrgency: SoundUrgency
        }

        let defaultSoundState = {
            Enabled = true
            LastSound = None
            MinInterval = TimeSpan.FromMilliseconds(500.0)
            MutedUntil = None
            CurrentUrgency = Silent
        }

        /// Check if sound can be played (respects min interval and mute)
        let canPlaySound (state: SoundState) =
            if not state.Enabled then false
            else
                match state.MutedUntil with
                | Some until when DateTime.UtcNow < until -> false
                | _ ->
                    match state.LastSound with
                    | Some last when DateTime.UtcNow - last < state.MinInterval -> false
                    | _ -> true

        /// Play terminal bell (cross-platform)
        let playBell () =
            Console.Write(bell)

        /// Play a sound pattern using terminal bells
        /// Note: Actual frequency control requires platform-specific APIs
        let playPattern (pattern: SoundPattern) (state: SoundState) : SoundState =
            if not (canPlaySound state) then state
            else
                let beeps =
                    match pattern with
                    | Click -> 1
                    | Tick -> 1
                    | Chime -> 1
                    | Beep -> 1
                    | DoubleBeep -> 2
                    | TripleBeep -> 3
                    | Alarm -> 5
                    | Success -> 3
                    | Failure -> 2
                    | Heartbeat -> 2

                for i in 1..beeps do
                    playBell()
                    if i < beeps then
                        Thread.Sleep(100)

                { state with LastSound = Some DateTime.UtcNow }

        /// Map alarm level to sound urgency
        let alarmToUrgency (level: AlarmLevel) : SoundUrgency =
            match level with
            | AlarmLevel.Normal -> SoundUrgency.Silent
            | AlarmLevel.Advisory -> SoundUrgency.Informational
            | AlarmLevel.Caution -> SoundUrgency.Attention
            | AlarmLevel.Warning -> SoundUrgency.Urgent
            | AlarmLevel.Critical -> SoundUrgency.Critical

        /// Map urgency to sound pattern
        let urgencyToPattern (urgency: SoundUrgency) : SoundPattern option =
            match urgency with
            | Silent -> None
            | Subtle -> Some Click
            | Informational -> Some Chime
            | Attention -> Some DoubleBeep
            | Urgent -> Some TripleBeep
            | Critical -> Some Alarm

        /// Play sound for alarm level if appropriate
        let playAlarmSound (level: AlarmLevel) (state: SoundState) : SoundState =
            let urgency = alarmToUrgency level
            match urgencyToPattern urgency with
            | Some pattern -> playPattern pattern state
            | None -> state

        /// Mute sounds for specified duration
        let muteSounds (duration: TimeSpan) (state: SoundState) : SoundState =
            { state with MutedUntil = Some (DateTime.UtcNow + duration) }

        /// Enable/disable sounds
        let setSoundEnabled (enabled: bool) (state: SoundState) : SoundState =
            { state with Enabled = enabled }

    // ═══════════════════════════════════════════════════════════════════════════
    // MOVEMENT SYSTEM - Visual Attention Capture
    // ═══════════════════════════════════════════════════════════════════════════

    module Movement =

        /// Movement types for attention capture
        type MovementType =
            | Static        // No movement
            | Pulse         // Brightness pulse (fade in/out)
            | Blink         // On/off blink (warning only)
            | Slide         // Horizontal slide (progress)
            | Expand        // Size expansion (emphasis)
            | Shake         // Horizontal shake (error)
            | Wave          // Sequential highlight (cascade)

        /// Animation frame state
        type AnimationState = {
            Frame: int
            LastUpdate: DateTime
            FrameRate: int              // FPS
            Movement: MovementType
            Duration: TimeSpan option   // None = infinite
            StartedAt: DateTime
        }

        /// ANSI movement sequences
        module Ansi =
            let cursorUp n = sprintf "\u001b[%dA" n
            let cursorDown n = sprintf "\u001b[%dB" n
            let cursorForward n = sprintf "\u001b[%dC" n
            let cursorBack n = sprintf "\u001b[%dD" n
            let cursorPosition row col = sprintf "\u001b[%d;%dH" row col
            let eraseToEndOfLine = "\u001b[K"
            let saveCursor = "\u001b[s"
            let restoreCursor = "\u001b[u"

        /// Brightness levels for pulse animation
        let private brightnessLevels = [|
            "\u001b[38;2;30;30;35m"     // Very dim
            "\u001b[38;2;60;60;70m"     // Dim
            "\u001b[38;2;100;100;110m"  // Medium-dim
            "\u001b[38;2;140;140;150m"  // Medium
            "\u001b[38;2;180;180;190m"  // Medium-bright
            "\u001b[38;2;220;220;230m"  // Bright
            "\u001b[38;2;255;255;255m"  // Full bright
        |]

        /// Get brightness color for pulse frame
        let getPulseColor (frame: int) : string =
            let idx = abs (frame % (brightnessLevels.Length * 2) - brightnessLevels.Length)
            brightnessLevels.[min idx (brightnessLevels.Length - 1)]

        /// Calculate next animation frame
        let nextFrame (state: AnimationState) : AnimationState =
            let now = DateTime.UtcNow
            let elapsed = now - state.LastUpdate
            let frameInterval = TimeSpan.FromMilliseconds(1000.0 / float state.FrameRate)

            if elapsed >= frameInterval then
                { state with
                    Frame = state.Frame + 1
                    LastUpdate = now
                }
            else
                state

        /// Check if animation should continue
        let shouldContinue (state: AnimationState) : bool =
            match state.Duration with
            | Some duration -> DateTime.UtcNow - state.StartedAt < duration
            | None -> true

        /// Create a new animation state
        let createAnimation (movement: MovementType) (fps: int) (duration: TimeSpan option) : AnimationState =
            {
                Frame = 0
                LastUpdate = DateTime.UtcNow
                FrameRate = fps
                Movement = movement
                Duration = duration
                StartedAt = DateTime.UtcNow
            }

        /// Render a pulsing element
        let renderPulse (content: string) (state: AnimationState) : string =
            let color = getPulseColor state.Frame
            sprintf "%s%s\u001b[0m" color content

        /// Render a blinking element (critical alerts only)
        let renderBlink (content: string) (state: AnimationState) : string =
            if state.Frame % 2 = 0 then
                sprintf "\u001b[31;5m%s\u001b[0m" content  // Red + blink
            else
                sprintf "\u001b[30m%s\u001b[0m" content    // Hidden/black

        /// Render a sliding progress indicator
        let renderSlide (width: int) (state: AnimationState) : string =
            let pos = state.Frame % (width * 2)
            let actualPos = if pos < width then pos else width * 2 - pos - 1
            let before = String.replicate actualPos "─"
            let indicator = "\u001b[36m━━━\u001b[0m"
            let after = String.replicate (max 0 (width - actualPos - 3)) "─"
            sprintf "\u001b[90m%s%s%s\u001b[0m" before indicator after

        /// Render shaking element (error feedback)
        let renderShake (content: string) (state: AnimationState) : string =
            let offset = [| 0; 1; -1; 2; -2; 1; -1; 0 |]
            let idx = state.Frame % offset.Length
            let spaces = String.replicate (abs offset.[idx]) " "
            if offset.[idx] >= 0 then
                sprintf "%s%s" spaces content
            else
                sprintf "%s%s" content spaces

        /// Render wave animation (cascading highlight)
        let renderWave (items: string list) (state: AnimationState) (highlightColor: string) : string list =
            let highlightIdx = state.Frame % items.Length
            items
            |> List.mapi (fun i item ->
                if i = highlightIdx then
                    sprintf "%s%s\u001b[0m" highlightColor item
                else
                    item
            )

        /// Map alarm level to movement type
        let alarmToMovement (level: AlarmLevel) : MovementType =
            match level with
            | Normal -> Static
            | Advisory -> Static
            | Caution -> Pulse
            | Warning -> Pulse
            | Critical -> Blink

    // ═══════════════════════════════════════════════════════════════════════════
    // SCREEN SPACE MANAGEMENT - Intelligent Layout
    // ═══════════════════════════════════════════════════════════════════════════

    module ScreenSpace =

        /// Screen region priority levels
        type RegionPriority =
            | Primary       // Center of attention, largest area
            | Secondary     // Supporting information
            | Tertiary      // Contextual/reference
            | Peripheral    // Edge information, minimal space

        /// Screen region definition
        type ScreenRegion = {
            Id: string
            Priority: RegionPriority
            X: int
            Y: int
            Width: int
            Height: int
            MinWidth: int
            MinHeight: int
            MaxWidth: int option
            MaxHeight: int option
            CanCollapse: bool
            IsCollapsed: bool
        }

        /// Layout configuration
        type LayoutConfig = {
            TotalWidth: int
            TotalHeight: int
            Regions: ScreenRegion list
            GutterWidth: int
            HeaderHeight: int
            FooterHeight: int
        }

        /// Create adaptive layout based on terminal size
        let createAdaptiveLayout (width: int) (height: int) : LayoutConfig =
            let isCompact = width < 120 || height < 40
            let isUltraWide = width > 200

            let gutterWidth = if isCompact then 0 else 1
            let headerHeight = if isCompact then 2 else 3
            let footerHeight = 2

            let contentHeight = height - headerHeight - footerHeight
            let contentWidth = width

            // Adaptive regions based on screen size
            let regions =
                if isCompact then
                    // Stacked layout for small screens
                    [
                        { Id = "header"; Priority = Primary; X = 0; Y = 0
                          Width = contentWidth; Height = headerHeight
                          MinWidth = 60; MinHeight = 2; MaxWidth = None; MaxHeight = Some 3
                          CanCollapse = false; IsCollapsed = false }
                        { Id = "main"; Priority = Primary; X = 0; Y = headerHeight
                          Width = contentWidth; Height = contentHeight * 2 / 3
                          MinWidth = 60; MinHeight = 10; MaxWidth = None; MaxHeight = None
                          CanCollapse = false; IsCollapsed = false }
                        { Id = "alerts"; Priority = Secondary; X = 0; Y = headerHeight + contentHeight * 2 / 3
                          Width = contentWidth; Height = contentHeight / 3
                          MinWidth = 60; MinHeight = 5; MaxWidth = None; MaxHeight = None
                          CanCollapse = true; IsCollapsed = false }
                    ]
                elif isUltraWide then
                    // Three-column layout for ultrawide
                    let colWidth = contentWidth / 3
                    [
                        { Id = "header"; Priority = Primary; X = 0; Y = 0
                          Width = contentWidth; Height = headerHeight
                          MinWidth = 120; MinHeight = 3; MaxWidth = None; MaxHeight = Some 4
                          CanCollapse = false; IsCollapsed = false }
                        { Id = "left"; Priority = Secondary; X = 0; Y = headerHeight
                          Width = colWidth; Height = contentHeight
                          MinWidth = 40; MinHeight = 20; MaxWidth = Some 60; MaxHeight = None
                          CanCollapse = true; IsCollapsed = false }
                        { Id = "center"; Priority = Primary; X = colWidth; Y = headerHeight
                          Width = colWidth; Height = contentHeight
                          MinWidth = 60; MinHeight = 20; MaxWidth = None; MaxHeight = None
                          CanCollapse = false; IsCollapsed = false }
                        { Id = "right"; Priority = Secondary; X = colWidth * 2; Y = headerHeight
                          Width = colWidth; Height = contentHeight
                          MinWidth = 40; MinHeight = 20; MaxWidth = Some 60; MaxHeight = None
                          CanCollapse = true; IsCollapsed = false }
                    ]
                else
                    // Standard two-column layout
                    let leftWidth = contentWidth / 2
                    let rightWidth = contentWidth - leftWidth
                    [
                        { Id = "header"; Priority = Primary; X = 0; Y = 0
                          Width = contentWidth; Height = headerHeight
                          MinWidth = 80; MinHeight = 3; MaxWidth = None; MaxHeight = Some 4
                          CanCollapse = false; IsCollapsed = false }
                        { Id = "left"; Priority = Primary; X = 0; Y = headerHeight
                          Width = leftWidth; Height = contentHeight / 2
                          MinWidth = 40; MinHeight = 10; MaxWidth = None; MaxHeight = None
                          CanCollapse = false; IsCollapsed = false }
                        { Id = "right"; Priority = Secondary; X = leftWidth; Y = headerHeight
                          Width = rightWidth; Height = contentHeight / 2
                          MinWidth = 40; MinHeight = 10; MaxWidth = None; MaxHeight = None
                          CanCollapse = true; IsCollapsed = false }
                        { Id = "bottomLeft"; Priority = Secondary; X = 0; Y = headerHeight + contentHeight / 2
                          Width = leftWidth; Height = contentHeight / 2
                          MinWidth = 40; MinHeight = 8; MaxWidth = None; MaxHeight = None
                          CanCollapse = true; IsCollapsed = false }
                        { Id = "bottomRight"; Priority = Tertiary; X = leftWidth; Y = headerHeight + contentHeight / 2
                          Width = rightWidth; Height = contentHeight / 2
                          MinWidth = 40; MinHeight = 8; MaxWidth = None; MaxHeight = None
                          CanCollapse = true; IsCollapsed = false }
                    ]

            {
                TotalWidth = width
                TotalHeight = height
                Regions = regions
                GutterWidth = gutterWidth
                HeaderHeight = headerHeight
                FooterHeight = footerHeight
            }

        /// Adjust layout for alarm state (expand alarms panel when critical)
        let adjustForAlarmState (alarmLevel: AlarmLevel) (activeAlarms: int) (layout: LayoutConfig) : LayoutConfig =
            if alarmLevel >= Warning && activeAlarms > 0 then
                // Expand alerts region, collapse tertiary regions
                let regions =
                    layout.Regions
                    |> List.map (fun r ->
                        if r.Id = "alerts" || r.Id = "right" then
                            { r with Height = r.Height + 5; IsCollapsed = false }
                        elif r.Priority = Tertiary then
                            { r with IsCollapsed = true }
                        else r
                    )
                { layout with Regions = regions }
            else layout

        /// Get region by ID
        let getRegion (id: string) (layout: LayoutConfig) : ScreenRegion option =
            layout.Regions |> List.tryFind (fun r -> r.Id = id)

    // ═══════════════════════════════════════════════════════════════════════════
    // COLOR INTELLIGENCE - Adaptive Color Management
    // ═══════════════════════════════════════════════════════════════════════════

    module ColorIntelligence =

        /// Color mode based on time of day
        type ColorMode =
            | DayMode       // Slightly brighter for well-lit rooms
            | NightMode     // Maximum contrast for dark rooms
            | HighContrast  // Accessibility mode

        /// Determine color mode based on time
        let getColorModeForTime (hour: int) : ColorMode =
            if hour >= 6 && hour < 18 then DayMode
            else NightMode

        /// Get color palette for mode
        let getColorPalette (mode: ColorMode) =
            match mode with
            | DayMode ->
                {| Normal = "\u001b[38;2;80;80;90m"
                   Advisory = "\u001b[38;2;0;180;180m"
                   Caution = "\u001b[38;2;220;160;0m"
                   Warning = "\u001b[38;2;220;60;60m"
                   Critical = "\u001b[38;2;255;0;0;5m"
                   Background = "\u001b[48;2;20;20;25m" |}
            | NightMode ->
                {| Normal = "\u001b[38;2;50;50;60m"
                   Advisory = "\u001b[38;2;0;140;140m"
                   Caution = "\u001b[38;2;180;130;0m"
                   Warning = "\u001b[38;2;180;40;40m"
                   Critical = "\u001b[38;2;220;0;0;5m"
                   Background = "\u001b[48;2;10;10;15m" |}
            | HighContrast ->
                {| Normal = "\u001b[38;2;200;200;200m"
                   Advisory = "\u001b[38;2;0;255;255m"
                   Caution = "\u001b[38;2;255;255;0m"
                   Warning = "\u001b[38;2;255;0;0m"
                   Critical = "\u001b[38;2;255;0;0;5m"
                   Background = "\u001b[48;2;0;0;0m" |}

        /// Apply staleness decay to color
        let applyStalenessFade (color: string) (stalenessSeconds: float) : string =
            if stalenessSeconds < 5.0 then color
            else
                let fadeFactor = min 0.8 (stalenessSeconds / 60.0)
                // Return gray instead of faded color
                let grayLevel = int (255.0 * (1.0 - fadeFactor * 0.8))
                sprintf "\u001b[38;2;%d;%d;%dm" grayLevel grayLevel grayLevel

    // ═══════════════════════════════════════════════════════════════════════════
    // INTEGRATED SITUATIONAL AWARENESS ENGINE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Combined state for situational awareness
    type SituationalState = {
        Sound: Sound.SoundState
        Animations: Map<string, Movement.AnimationState>
        Layout: ScreenSpace.LayoutConfig
        ColorMode: ColorIntelligence.ColorMode
        LastAlarmLevel: AlarmLevel
        OodaPhase: DarkCockpitUI.OodaHmi.OodaPhase
    }

    /// Initialize situational awareness engine
    let initialize (width: int) (height: int) : SituationalState =
        let hour = DateTime.Now.Hour
        {
            Sound = Sound.defaultSoundState
            Animations = Map.empty
            Layout = ScreenSpace.createAdaptiveLayout width height
            ColorMode = ColorIntelligence.getColorModeForTime hour
            LastAlarmLevel = Normal
            OodaPhase = DarkCockpitUI.OodaHmi.Observe
        }

    /// Process an alarm event with multi-modal response
    let processAlarm (alarm: Alarm) (state: SituationalState) : SituationalState =
        // 1. Sound response
        let newSoundState = Sound.playAlarmSound alarm.Level state.Sound

        // 2. Movement response
        let newAnimations =
            if alarm.Level >= Caution then
                let movement = Movement.alarmToMovement alarm.Level
                let duration = if alarm.Level >= Warning then None else Some (TimeSpan.FromSeconds(10.0))
                let animation = Movement.createAnimation movement 10 duration
                state.Animations |> Map.add alarm.Id animation
            else state.Animations

        // 3. Layout adjustment
        let activeAlarms =
            state.Animations
            |> Map.filter (fun _ anim -> Movement.shouldContinue anim)
            |> Map.count
        let newLayout = ScreenSpace.adjustForAlarmState alarm.Level activeAlarms state.Layout

        { state with
            Sound = newSoundState
            Animations = newAnimations
            Layout = newLayout
            LastAlarmLevel = alarm.Level
        }

    /// Update animation states (call each frame)
    let updateAnimations (state: SituationalState) : SituationalState =
        let newAnimations =
            state.Animations
            |> Map.map (fun _ anim -> Movement.nextFrame anim)
            |> Map.filter (fun _ anim -> Movement.shouldContinue anim)
        { state with Animations = newAnimations }

    /// Update color mode based on time
    let updateColorMode (state: SituationalState) : SituationalState =
        let hour = DateTime.Now.Hour
        let newMode = ColorIntelligence.getColorModeForTime hour
        if newMode <> state.ColorMode then
            { state with ColorMode = newMode }
        else state

    /// Render element with situational awareness
    let renderWithAwareness
        (elementId: string)
        (content: string)
        (alarmLevel: AlarmLevel)
        (stalenessSeconds: float)
        (state: SituationalState) : string =

        let palette = ColorIntelligence.getColorPalette state.ColorMode

        // Apply alarm color
        let baseColor =
            match alarmLevel with
            | Normal -> palette.Normal
            | Advisory -> palette.Advisory
            | Caution -> palette.Caution
            | Warning -> palette.Warning
            | Critical -> palette.Critical

        // Apply staleness fade
        let color = ColorIntelligence.applyStalenessFade baseColor stalenessSeconds

        // Apply animation if present
        match Map.tryFind elementId state.Animations with
        | Some animation ->
            match animation.Movement with
            | Movement.Pulse -> Movement.renderPulse content animation
            | Movement.Blink -> Movement.renderBlink content animation
            | Movement.Shake -> sprintf "%s%s\u001b[0m" color (Movement.renderShake content animation)
            | _ -> sprintf "%s%s\u001b[0m" color content
        | None ->
            sprintf "%s%s\u001b[0m" color content

    /// Get OODA cycle indicator
    let getOodaIndicator (state: SituationalState) (cycleMs: float) (quality: float) : string =
        DarkCockpitUI.OodaHmi.renderOodaCycle state.OodaPhase cycleMs quality

    /// Advance OODA phase
    let advanceOodaPhase (state: SituationalState) : SituationalState =
        let nextPhase =
            match state.OodaPhase with
            | DarkCockpitUI.OodaHmi.Observe -> DarkCockpitUI.OodaHmi.Orient
            | DarkCockpitUI.OodaHmi.Orient -> DarkCockpitUI.OodaHmi.Decide
            | DarkCockpitUI.OodaHmi.Decide -> DarkCockpitUI.OodaHmi.Act
            | DarkCockpitUI.OodaHmi.Act -> DarkCockpitUI.OodaHmi.Observe
        { state with OodaPhase = nextPhase }
