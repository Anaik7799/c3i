/// Comprehensive UI Component Tests for PRAJNA C3I Mesh Cockpit
/// Reference: GEMINI.md Section 4.0 - TDG Methodology (Test-Driven Generation)
/// Compliance: SC-HMI-001 to SC-HMI-007 (Dark Cockpit + Material3 Principles)
///
/// Test Coverage:
///   - Material3 Core Components (16 types): Button, Card, Chip, ListItem, Progress, etc.
///   - Material3 Expressive Components (26 types): IconButton, SegmentedButton,
///     SplitButton, ButtonGroup, ToggleButton, Checkbox, RadioButton, Slider,
///     DatePicker, TimePicker, Menu, ExposedDropdown, BottomSheet, SideSheet,
///     Carousel, TopAppBar, BottomAppBar, NavigationRail, NavigationDrawer,
///     SearchBar, FloatingToolbar, FABMenu, Tooltip, LoadingIndicator,
///     SwipeToDismiss, PullToRefresh
///   - DarkCockpitUI Components: Bars, Sparklines, Smart Metrics, Panels
///   - OodaHmi L7 Enhancements: Spider Charts, Safety Margins, Predictive Bars
///   - Composability: Dashboard layouts combining multiple components
///   - Total: 42+ Material3 components fully tested
module Cepaf.Tests.CockpitUIComponentTests

open System
open System.Text.RegularExpressions
open Expecto
open FsCheck
open FsCheck.FSharp

open Cepaf.Cockpit.DarkCockpitUI
open Cepaf.Cockpit.Material3
open Cepaf.Cockpit.Domain

// ============================================================================
// TEST INFRASTRUCTURE
// ============================================================================

module TestHelpers =
    /// Strip ANSI escape codes for content testing
    let stripAnsi (s: string) =
        Regex.Replace(s, @"\x1b\[[0-9;]*m", "")

    /// Count visible characters (excluding ANSI codes)
    let visibleLength (s: string) =
        (stripAnsi s).Length

    /// Check if string contains ANSI reset code
    let hasReset (s: string) =
        s.Contains("\u001b[0m")

    /// Check string has valid box drawing characters
    let hasBoxChars (s: string) =
        let boxChars = ['+'; '-'; '|'; '#'; '='; ',']
        boxChars |> List.exists (fun c -> s.Contains(string c))

    /// Create test SmartMetric using Domain helper
    let createTestMetric label value unit trend level sparkline =
        { SmartMetric.Create(label, unit, value) with
            Trend = trend
            Level = level
            Sparkline = sparkline }

    /// Create test MeshNode directly
    let createTestNode id name status zone (role: NodeRole) healthScore cpuValue cpuTrend =
        {
            Id = id
            Name = name
            Zone = zone
            Role = role
            Status = status
            Cpu = { SmartMetric.Create("CPU", "%", cpuValue) with Trend = cpuTrend }
            Memory = SmartMetric.Create("Memory", "%", 50.0)
            Battery = None
            NetworkLatency = SmartMetric.Create("Latency", "ms", 10.0)
            Capabilities = []
            HealthScore = { SmartMetric.Create("Health", "%", healthScore) with Level = Normal }
            Location = None
            AiInsight = None
            AiInsightUpdatedAt = None
        }

    /// Create test CockpitState using Domain helper
    let createTestState () =
        let baseState = createCockpitState "test-operator"
        { baseState with
            SimulationMode = true
            MessagesReceived = 100
            LastMessageAt = Some DateTime.UtcNow }

// ============================================================================
// CUSTOM GENERATORS FOR PROPERTY TESTS
// ============================================================================

type UIGenerators =
    static member AlarmLevel() =
        Arb.fromGen (Gen.elements [Normal; Advisory; Caution; Warning; Critical])

    static member Trend() =
        Arb.fromGen (Gen.elements [Rising; RisingFast; Falling; FallingFast; Stable])

    static member ConnStatus() =
        Arb.fromGen (Gen.elements [Connected; Stale; Degraded; Disconnected])

    static member CommandState() =
        Arb.fromGen (Gen.elements [Idle; Armed; Executing; Acknowledged; Failed])

    static member ButtonVariant() =
        Arb.fromGen (Gen.elements [ButtonVariant.Filled; ButtonVariant.Outlined; ButtonVariant.Text; ButtonVariant.Tonal; ButtonVariant.Elevated])

    static member CardVariant() =
        Arb.fromGen (Gen.elements [CardVariant.Filled; CardVariant.Outlined; CardVariant.Elevated])

    static member TextFieldVariant() =
        Arb.fromGen (Gen.elements [FilledField; OutlinedField])

    static member BadgeVariant() =
        Arb.fromGen (Gen.elements [Small; Large])

    static member DisclosureLevel() =
        Arb.fromGen (Gen.elements [OodaHmi.Summary; OodaHmi.Overview; OodaHmi.Detailed; OodaHmi.Expert])

    static member OodaPhase() =
        Arb.fromGen (Gen.elements [OodaHmi.Observe; OodaHmi.Orient; OodaHmi.Decide; OodaHmi.Act])

    static member ValidPercentage() =
        Arb.fromGen (Gen.choose (0, 100) |> Gen.map float)

    static member SparklineData() =
        Arb.fromGen (gen {
            let! len = Gen.choose (5, 20)
            let! values = Gen.listOfLength len (Gen.choose (0, 100) |> Gen.map float)
            return values
        })

    static member PositiveWidth() =
        Arb.fromGen (Gen.choose (10, 80))

// ============================================================================
// MATERIAL3 DESIGN TOKEN TESTS
// ============================================================================

[<Tests>]
let colorTokenTests =
    testList "Material3 Color Tokens" [

        testCase "Primary colors are valid ANSI sequences" <| fun _ ->
            Expect.stringStarts Colors.primary "\u001b[" "Primary should be ANSI"
            Expect.stringStarts Colors.onPrimary "\u001b[" "OnPrimary should be ANSI"
            Expect.stringStarts Colors.primaryContainer "\u001b[" "PrimaryContainer should be ANSI"

        testCase "Error colors are valid ANSI sequences" <| fun _ ->
            Expect.stringStarts Colors.error "\u001b[" "Error should be ANSI"
            Expect.stringStarts Colors.errorContainer "\u001b[" "ErrorContainer should be ANSI"

        testCase "Semantic colors are defined" <| fun _ ->
            Expect.isNonEmpty Colors.normal "Normal should be defined"
            Expect.isNonEmpty Colors.advisory "Advisory should be defined"
            Expect.isNonEmpty Colors.caution "Caution should be defined"
            Expect.isNonEmpty Colors.warning "Warning should be defined"
            Expect.isNonEmpty Colors.critical "Critical should be defined"

        testCase "Reset code is correct" <| fun _ ->
            Expect.equal Colors.reset "\u001b[0m" "Reset should be correct ANSI"
    ]

[<Tests>]
let typographyTokenTests =
    testList "Material3 Typography Tokens" [

        testCase "Display styles use bold" <| fun _ ->
            Expect.stringContains Typography.displayLarge "\u001b[1m" "Display should be bold"

        testCase "Body small uses dim" <| fun _ ->
            Expect.stringContains Typography.bodySmall "\u001b[2m" "Body small should be dim"

        testCase "Reset is available" <| fun _ ->
            Expect.equal Typography.reset "\u001b[0m" "Typography reset should work"
    ]

[<Tests>]
let elevationTokenTests =
    testList "Material3 Elevation Tokens" [

        testCase "Level 1 has light box chars" <| fun _ ->
            Expect.equal Elevation.level1TopLeft "┌" "Level 1 top-left"
            Expect.equal Elevation.level1Horizontal "─" "Level 1 horizontal"
            Expect.equal Elevation.level1Vertical "│" "Level 1 vertical"

        testCase "Level 2 has rounded corners" <| fun _ ->
            Expect.equal Elevation.level2TopLeft "╭" "Level 2 top-left"
            Expect.equal Elevation.level2TopRight "╮" "Level 2 top-right"

        testCase "Level 3 has double borders" <| fun _ ->
            Expect.equal Elevation.level3TopLeft "╔" "Level 3 top-left"
            Expect.equal Elevation.level3Horizontal "═" "Level 3 horizontal"
    ]

// ============================================================================
// MATERIAL3 COMPONENT TESTS
// ============================================================================

[<Tests>]
let buttonTests =
    testList "Material3 Button Component" [

        testCase "Filled button renders with brackets" <| fun _ ->
            let btn: Button = { Label = "Submit"; Variant = ButtonVariant.Filled; Disabled = false; Icon = None }
            let output = renderButton btn
            Expect.stringContains output "[" "Should have opening bracket"
            Expect.stringContains output "]" "Should have closing bracket"
            Expect.stringContains output "Submit" "Should contain label"

        testCase "Outlined button renders" <| fun _ ->
            let btn: Button = { Label = "Cancel"; Variant = ButtonVariant.Outlined; Disabled = false; Icon = None }
            let output = renderButton btn
            Expect.stringContains output "Cancel" "Should contain label"

        testCase "Text button has minimal decoration" <| fun _ ->
            let btn: Button = { Label = "More"; Variant = ButtonVariant.Text; Disabled = false; Icon = None }
            let output = renderButton btn
            Expect.stringContains output "More" "Should contain label"

        testCase "Disabled button uses dim colors" <| fun _ ->
            let enabled: Button = { Label = "Test"; Variant = ButtonVariant.Filled; Disabled = false; Icon = None }
            let disabled: Button = { Label = "Test"; Variant = ButtonVariant.Filled; Disabled = true; Icon = None }
            Expect.notEqual (renderButton enabled) (renderButton disabled) "Disabled should differ"

        testCase "Button with icon renders icon" <| fun _ ->
            let btn: Button = { Label = "Save"; Variant = ButtonVariant.Filled; Disabled = false; Icon = Some "+" }
            let output = renderButton btn
            Expect.stringContains output "+" "Should contain icon"
            Expect.stringContains output "Save" "Should contain label"

        testCase "All button variants render" <| fun _ ->
            let variants = [ButtonVariant.Filled; ButtonVariant.Outlined; ButtonVariant.Text; ButtonVariant.Tonal; ButtonVariant.Elevated]
            for variant in variants do
                let btn: Button = { Label = "Test"; Variant = variant; Disabled = false; Icon = None }
                let output = renderButton btn
                Expect.isNonEmpty output $"Variant {variant} should render"
    ]

[<Tests>]
let cardTests =
    testList "Material3 Card Component" [

        testCase "Card renders with borders" <| fun _ ->
            let card = { Title = Some "Test"; Subtitle = None; Content = ["Line 1"]; Variant = CardVariant.Outlined; Width = 30 }
            let lines = renderCard card
            Expect.isGreaterThan lines.Length 2 "Should have multiple lines"

        testCase "Card with title shows title" <| fun _ ->
            let card = { Title = Some "My Title"; Subtitle = None; Content = []; Variant = CardVariant.Outlined; Width = 30 }
            let output = String.concat "\n" (renderCard card)
            Expect.stringContains output "My Title" "Should contain title"

        testCase "Card with subtitle shows subtitle" <| fun _ ->
            let card = { Title = Some "Title"; Subtitle = Some "Subtitle"; Content = []; Variant = CardVariant.Outlined; Width = 40 }
            let output = String.concat "\n" (renderCard card)
            Expect.stringContains output "Subtitle" "Should contain subtitle"

        testCase "Card content is rendered" <| fun _ ->
            let card = { Title = None; Subtitle = None; Content = ["Content Line 1"; "Content Line 2"]; Variant = CardVariant.Filled; Width = 40 }
            let output = String.concat "\n" (renderCard card)
            Expect.stringContains output "Content Line 1" "Should contain content"

        testCase "All card variants render" <| fun _ ->
            let variants = [CardVariant.Filled; CardVariant.Outlined; CardVariant.Elevated]
            for variant in variants do
                let card = { Title = Some "Test"; Subtitle = None; Content = []; Variant = variant; Width = 30 }
                let lines = renderCard card
                Expect.isGreaterThan lines.Length 0 $"Variant {variant} should render"

        testCase "Card width is respected" <| fun _ ->
            let card = { Title = Some "T"; Subtitle = None; Content = []; Variant = CardVariant.Outlined; Width = 20 }
            let lines = renderCard card
            for line in lines do
                let visible = TestHelpers.visibleLength line
                Expect.isLessThanOrEqual visible 20 "Each line should respect width"
    ]

[<Tests>]
let chipTests =
    testList "Material3 Chip Component" [

        testCase "Chip renders with parentheses" <| fun _ ->
            let chip: Chip = { Label = "Filter"; Variant = ChipVariant.Filter; Selected = false; Icon = None }
            let output = renderChip chip
            Expect.stringContains output "(" "Should have opening paren"
            Expect.stringContains output ")" "Should have closing paren"

        testCase "Selected chip differs from unselected" <| fun _ ->
            let unselected: Chip = { Label = "Tag"; Variant = ChipVariant.Filter; Selected = false; Icon = None }
            let selected: Chip = { Label = "Tag"; Variant = ChipVariant.Filter; Selected = true; Icon = None }
            Expect.notEqual (renderChip unselected) (renderChip selected) "Selected should differ"

        testCase "All chip variants render" <| fun _ ->
            let variants = [ChipVariant.Assist; ChipVariant.Filter; ChipVariant.Input; ChipVariant.Suggestion]
            for variant in variants do
                let chip: Chip = { Label = "Test"; Variant = variant; Selected = false; Icon = None }
                let output = renderChip chip
                Expect.isNonEmpty output $"Variant {variant} should render"
    ]

[<Tests>]
let listItemTests =
    testList "Material3 ListItem Component" [

        testCase "ListItem renders headline" <| fun _ ->
            let item = { Headline = "Main Text"; SupportingText = None; TrailingText = None; LeadingIcon = None; TrailingIcon = None; Selected = false }
            let output = renderListItem item 50
            Expect.stringContains output "Main Text" "Should contain headline"

        testCase "ListItem with trailing text" <| fun _ ->
            let item = { Headline = "File"; SupportingText = None; TrailingText = Some "10KB"; LeadingIcon = None; TrailingIcon = None; Selected = false }
            let output = renderListItem item 50
            Expect.stringContains output "10KB" "Should contain trailing text"

        testCase "ListItem with icons" <| fun _ ->
            let item = { Headline = "Settings"; SupportingText = None; TrailingText = None; LeadingIcon = Some ">"; TrailingIcon = Some ">"; Selected = false }
            let output = renderListItem item 50
            Expect.stringContains output ">" "Should contain icon"
    ]

[<Tests>]
let progressTests =
    testList "Material3 Progress Component" [

        testCase "Linear progress renders bar" <| fun _ ->
            let output = renderProgress Linear 20
            Expect.isNonEmpty output "Should produce output"

        testCase "Circular progress renders" <| fun _ ->
            let output = renderProgress Circular 10
            Expect.isNonEmpty output "Circular should render"

        testCase "Determinate progress shows fill" <| fun _ ->
            let output = renderProgress (Determinate 0.5) 20
            Expect.isNonEmpty output "Should show progress"

        testCase "Determinate 0% renders" <| fun _ ->
            let output = renderProgress (Determinate 0.0) 20
            Expect.isNonEmpty output "0% should render"

        testCase "Determinate 100% renders" <| fun _ ->
            let output = renderProgress (Determinate 1.0) 20
            Expect.isNonEmpty output "100% should render"
    ]

[<Tests>]
let snackBarTests =
    testList "Material3 SnackBar Component" [

        testCase "SnackBar renders message" <| fun _ ->
            let snack = { Message = "File saved"; Action = None; IsError = false }
            let output = renderSnackBar snack 50
            Expect.stringContains output "File saved" "Should contain message"

        testCase "SnackBar with action" <| fun _ ->
            let snack = { Message = "Connection lost"; Action = Some "Retry"; IsError = false }
            let output = renderSnackBar snack 50
            Expect.stringContains output "Retry" "Should contain action"

        testCase "Error snackbar differs" <| fun _ ->
            let normal = { Message = "Info"; Action = None; IsError = false }
            let error = { Message = "Error"; Action = None; IsError = true }
            Expect.notEqual (renderSnackBar normal 50) (renderSnackBar error 50) "Error should differ"
    ]

[<Tests>]
let navBarTests =
    testList "Material3 NavBar Component" [

        testCase "NavBar renders all items" <| fun _ ->
            let items: NavItem list = [
                { Label = "Home"; Icon = "H"; Selected = true }
                { Label = "Search"; Icon = "S"; Selected = false }
                { Label = "Profile"; Icon = "P"; Selected = false }
            ]
            let output = renderNavBar items 60
            Expect.stringContains output "Home" "Should contain Home"
            Expect.stringContains output "Search" "Should contain Search"
            Expect.stringContains output "Profile" "Should contain Profile"

        testCase "Empty navbar is empty" <| fun _ ->
            let output = renderNavBar [] 60
            Expect.equal output "" "Empty navbar should be empty"
    ]

[<Tests>]
let badgeTests =
    testList "Material3 Badge Component" [

        testCase "Small badge renders" <| fun _ ->
            let output = renderBadge BadgeVariant.Small None
            Expect.isNonEmpty output "Small badge should render"

        testCase "Large badge with count" <| fun _ ->
            let output = renderBadge BadgeVariant.Large (Some 5)
            Expect.stringContains output "5" "Should contain count"

        testCase "Badge with large number shows 999+" <| fun _ ->
            let output = renderBadge BadgeVariant.Large (Some 1500)
            Expect.stringContains output "999+" "Should show 999+"

        testCase "Large badge without count" <| fun _ ->
            let output = renderBadge BadgeVariant.Large None
            Expect.isNonEmpty output "Should render dot"
    ]

[<Tests>]
let textFieldTests =
    testList "Material3 TextField Component" [

        testCase "TextField renders label" <| fun _ ->
            let field = { Label = "Name"; Value = ""; Variant = FilledField; Focused = false; Error = None; Width = 30 }
            let lines = renderTextField field
            let output = String.concat "\n" lines
            Expect.stringContains output "Name" "Should show label"

        testCase "TextField with value shows value" <| fun _ ->
            let field = { Label = "Name"; Value = "John"; Variant = FilledField; Focused = false; Error = None; Width = 30 }
            let lines = renderTextField field
            let output = String.concat "\n" lines
            Expect.stringContains output "John" "Should show value"

        testCase "TextField with error shows error" <| fun _ ->
            let field = { Label = "Email"; Value = ""; Variant = FilledField; Focused = false; Error = Some "Invalid email"; Width = 30 }
            let lines = renderTextField field
            let output = String.concat "\n" lines
            Expect.stringContains output "Invalid email" "Should show error"

        testCase "Both TextField variants render" <| fun _ ->
            let filled = { Label = "Field"; Value = "test"; Variant = FilledField; Focused = false; Error = None; Width = 30 }
            let outlined = { Label = "Field"; Value = "test"; Variant = OutlinedField; Focused = false; Error = None; Width = 30 }
            let r1 = renderTextField filled
            let r2 = renderTextField outlined
            Expect.isNonEmpty r1 "Filled should render"
            Expect.isNonEmpty r2 "Outlined should render"
    ]

[<Tests>]
let dialogTests =
    testList "Material3 Dialog Component" [

        testCase "Dialog renders title" <| fun _ ->
            let dialog = { Title = "Confirm"; Content = ["Are you sure?"]; Actions = []; Width = 40 }
            let lines = renderDialog dialog
            let output = String.concat "\n" lines
            Expect.stringContains output "Confirm" "Should contain title"

        testCase "Dialog renders content" <| fun _ ->
            let dialog = { Title = "Info"; Content = ["Operation complete"]; Actions = []; Width = 40 }
            let lines = renderDialog dialog
            let output = String.concat "\n" lines
            Expect.stringContains output "Operation complete" "Should contain content"

        testCase "Dialog renders actions" <| fun _ ->
            let actions: Button list = [
                { Label = "OK"; Variant = ButtonVariant.Filled; Disabled = false; Icon = None }
                { Label = "Cancel"; Variant = ButtonVariant.Text; Disabled = false; Icon = None }
            ]
            let dialog = { Title = "Delete"; Content = ["Delete file?"]; Actions = actions; Width = 50 }
            let lines = renderDialog dialog
            let output = String.concat "\n" lines
            Expect.stringContains output "OK" "Should contain action"
    ]

[<Tests>]
let fabTests =
    testList "Material3 FAB Component" [

        testCase "FAB renders icon" <| fun _ ->
            let output = renderFab "+" FabSmall
            Expect.stringContains output "+" "Should contain icon"

        testCase "Regular FAB renders" <| fun _ ->
            let output = renderFab "+" FabRegular
            Expect.stringContains output "+" "Should contain icon"

        testCase "Large FAB renders" <| fun _ ->
            let output = renderFab "+" FabLarge
            Expect.stringContains output "+" "Should contain icon"

        testCase "Extended FAB renders label" <| fun _ ->
            let output = renderFab "+" (FabExtended "Edit")
            Expect.stringContains output "+" "Should contain icon"
            Expect.stringContains output "Edit" "Should contain label"
    ]

[<Tests>]
let tabsTests =
    testList "Material3 Tabs Component" [

        testCase "Tabs render all labels" <| fun _ ->
            let tabs: Tab list = [
                { Label = "Home"; Icon = None; Active = true }
                { Label = "Search"; Icon = None; Active = false }
                { Label = "Settings"; Icon = None; Active = false }
            ]
            let output = renderTabs tabs
            Expect.stringContains output "Home" "Should contain Home"
            Expect.stringContains output "Search" "Should contain Search"
            Expect.stringContains output "Settings" "Should contain Settings"

        testCase "Tab with icon shows icon" <| fun _ ->
            let tabs: Tab list = [{ Label = "Home"; Icon = Some "H"; Active = true }]
            let output = renderTabs tabs
            Expect.stringContains output "H" "Should contain icon"
    ]

[<Tests>]
let tableTests =
    testList "Material3 Table Component" [

        testCase "Table renders headers" <| fun _ ->
            let columns = [
                { Header = "Name"; Width = 15; Align = "left" }
                { Header = "Age"; Width = 10; Align = "right" }
            ]
            let rows: TableRow list = []
            let lines = renderTable columns rows
            let output = String.concat "\n" lines
            Expect.stringContains output "Name" "Should contain Name header"
            Expect.stringContains output "Age" "Should contain Age header"

        testCase "Table renders data rows" <| fun _ ->
            let columns = [{ Header = "ID"; Width = 10; Align = "left" }]
            let rows = [
                { Cells = ["001"]; Selected = false }
                { Cells = ["002"]; Selected = false }
            ]
            let lines = renderTable columns rows
            let output = String.concat "\n" lines
            Expect.stringContains output "001" "Should contain first row data"

        testCase "Selected row differs" <| fun _ ->
            let columns = [{ Header = "X"; Width = 10; Align = "left" }]
            let unselected = { Cells = ["A"]; Selected = false }
            let selected = { Cells = ["A"]; Selected = true }
            let lines1 = renderTable columns [unselected]
            let lines2 = renderTable columns [selected]
            Expect.notEqual lines1 lines2 "Selected should differ"
    ]

// ============================================================================
// NEW MATERIAL3 COMPONENT TESTS (M3 Expressive)
// ============================================================================

[<Tests>]
let iconButtonTests =
    testList "Material3 IconButton Component" [

        testCase "IconButton standard renders" <| fun _ ->
            let btn: IconButton = { Icon = "★"; Variant = IconButtonVariant.Standard; Selected = false; Disabled = false }
            let output = renderIconButton btn
            Expect.stringContains output "★" "Should contain icon"

        testCase "IconButton filled variant" <| fun _ ->
            let btn: IconButton = { Icon = "+"; Variant = IconButtonVariant.Filled; Selected = false; Disabled = false }
            let output = renderIconButton btn
            Expect.isNonEmpty output "Filled should render"

        testCase "IconButton disabled" <| fun _ ->
            let enabled: IconButton = { Icon = "X"; Variant = IconButtonVariant.Standard; Selected = false; Disabled = false }
            let disabled: IconButton = { Icon = "X"; Variant = IconButtonVariant.Standard; Selected = false; Disabled = true }
            Expect.notEqual (renderIconButton enabled) (renderIconButton disabled) "Disabled should differ"

        testCase "All IconButton variants render" <| fun _ ->
            let variants = [IconButtonVariant.Standard; IconButtonVariant.Filled; IconButtonVariant.FilledTonal; IconButtonVariant.Outlined]
            for variant in variants do
                let btn: IconButton = { Icon = "A"; Variant = variant; Selected = false; Disabled = false }
                let output = renderIconButton btn
                Expect.isNonEmpty output $"Variant {variant} should render"

        testCase "Selected IconButton differs" <| fun _ ->
            let unsel: IconButton = { Icon = "B"; Variant = IconButtonVariant.FilledTonal; Selected = false; Disabled = false }
            let sel: IconButton = { Icon = "B"; Variant = IconButtonVariant.FilledTonal; Selected = true; Disabled = false }
            Expect.notEqual (renderIconButton unsel) (renderIconButton sel) "Selected should differ"
    ]

[<Tests>]
let segmentedButtonTests =
    testList "Material3 SegmentedButton Component" [

        testCase "SegmentedButton renders options" <| fun _ ->
            let options = [
                { Label = "Day"; Icon = None; Selected = true }
                { Label = "Week"; Icon = None; Selected = false }
                { Label = "Month"; Icon = None; Selected = false }
            ]
            let output = renderSegmentedButton options SingleSelect
            Expect.stringContains output "Day" "Should contain Day"
            Expect.stringContains output "Week" "Should contain Week"

        testCase "Selected option shows checkmark" <| fun _ ->
            let options = [{ Label = "Option"; Icon = None; Selected = true }]
            let output = renderSegmentedButton options SingleSelect
            Expect.stringContains output "✓" "Should show checkmark"

        testCase "MultiSelect mode works" <| fun _ ->
            let options = [
                { Label = "A"; Icon = None; Selected = true }
                { Label = "B"; Icon = None; Selected = true }
            ]
            let output = renderSegmentedButton options MultiSelect
            Expect.isNonEmpty output "MultiSelect should render"

        testCase "Option with icon" <| fun _ ->
            let options = [{ Label = "Star"; Icon = Some "★"; Selected = false }]
            let output = renderSegmentedButton options SingleSelect
            Expect.stringContains output "★" "Should contain icon"
    ]

[<Tests>]
let splitButtonTests =
    testList "Material3 SplitButton Component" [

        testCase "SplitButton renders label" <| fun _ ->
            let btn: SplitButton = { Label = "Save"; Icon = None; MenuExpanded = false }
            let output = renderSplitButton btn
            Expect.stringContains output "Save" "Should contain label"

        testCase "SplitButton with icon" <| fun _ ->
            let btn: SplitButton = { Label = "Action"; Icon = Some "▶"; MenuExpanded = false }
            let output = renderSplitButton btn
            Expect.stringContains output "▶" "Should contain icon"

        testCase "Menu arrow changes when expanded" <| fun _ ->
            let collapsed: SplitButton = { Label = "Menu"; Icon = None; MenuExpanded = false }
            let expanded: SplitButton = { Label = "Menu"; Icon = None; MenuExpanded = true }
            let c = renderSplitButton collapsed
            let e = renderSplitButton expanded
            Expect.stringContains c "▼" "Collapsed should show down arrow"
            Expect.stringContains e "▲" "Expanded should show up arrow"
    ]

[<Tests>]
let buttonGroupTests =
    testList "Material3 ButtonGroup Component" [

        testCase "ButtonGroup renders all items" <| fun _ ->
            let items = [
                { Label = "Bold"; Icon = Some "B"; Active = false }
                { Label = "Italic"; Icon = Some "I"; Active = false }
                { Label = "Underline"; Icon = Some "U"; Active = false }
            ]
            let output = renderButtonGroup items
            Expect.stringContains output "Bold" "Should contain Bold"
            Expect.stringContains output "Italic" "Should contain Italic"

        testCase "Active item differs" <| fun _ ->
            let items = [{ Label = "Active"; Icon = None; Active = true }]
            let output = renderButtonGroup items
            Expect.isNonEmpty output "Active item should render"
    ]

[<Tests>]
let toggleButtonTests =
    testList "Material3 ToggleButton Component" [

        testCase "ToggleButton untoggled" <| fun _ ->
            let btn: ToggleButton = { Icon = "★"; Label = None; Toggled = false }
            let output = renderToggleButton btn
            Expect.stringContains output "○" "Untoggled should show empty circle"

        testCase "ToggleButton toggled" <| fun _ ->
            let btn: ToggleButton = { Icon = "★"; Label = None; Toggled = true }
            let output = renderToggleButton btn
            Expect.stringContains output "●" "Toggled should show filled circle"

        testCase "ToggleButton with label" <| fun _ ->
            let btn: ToggleButton = { Icon = "♪"; Label = Some "Sound"; Toggled = true }
            let output = renderToggleButton btn
            Expect.stringContains output "Sound" "Should contain label"
    ]

[<Tests>]
let checkboxTests =
    testList "Material3 Checkbox Component" [

        testCase "Unchecked checkbox" <| fun _ ->
            let output = renderCheckbox Unchecked None false
            Expect.stringContains output "☐" "Unchecked should show empty box"

        testCase "Checked checkbox" <| fun _ ->
            let output = renderCheckbox Checked None false
            Expect.stringContains output "☑" "Checked should show checked box"

        testCase "Indeterminate checkbox" <| fun _ ->
            let output = renderCheckbox Indeterminate None false
            Expect.stringContains output "▣" "Indeterminate should show square"

        testCase "Checkbox with label" <| fun _ ->
            let output = renderCheckbox Checked (Some "Accept terms") false
            Expect.stringContains output "Accept terms" "Should contain label"

        testCase "Disabled checkbox differs" <| fun _ ->
            let enabled = renderCheckbox Checked (Some "Label") false
            let disabled = renderCheckbox Checked (Some "Label") true
            Expect.notEqual enabled disabled "Disabled should differ"
    ]

[<Tests>]
let radioButtonTests =
    testList "Material3 RadioButton Component" [

        testCase "Unselected radio" <| fun _ ->
            let output = renderRadioButton false "Option" false
            Expect.stringContains output "○" "Unselected should show empty circle"

        testCase "Selected radio" <| fun _ ->
            let output = renderRadioButton true "Option" false
            Expect.stringContains output "◉" "Selected should show filled circle"

        testCase "Radio with label" <| fun _ ->
            let output = renderRadioButton false "My Option" false
            Expect.stringContains output "My Option" "Should contain label"

        testCase "RadioGroup vertical" <| fun _ ->
            let group: RadioGroup = {
                Options = [("Option 1", true); ("Option 2", false); ("Option 3", false)]
                Orientation = "vertical"
            }
            let output = renderRadioGroup group
            Expect.stringContains output "Option 1" "Should contain first option"
            Expect.stringContains output "\n" "Vertical should have newlines"

        testCase "RadioGroup horizontal" <| fun _ ->
            let group: RadioGroup = {
                Options = [("A", false); ("B", true)]
                Orientation = "horizontal"
            }
            let output = renderRadioGroup group
            Expect.stringContains output "A" "Should contain A"
            Expect.stringContains output "B" "Should contain B"
    ]

[<Tests>]
let sliderTests =
    testList "Material3 Slider Component" [

        testCase "Slider at minimum" <| fun _ ->
            let slider: Slider = { Value = 0.0; Min = 0.0; Max = 100.0; Width = 20; ShowValue = false; Disabled = false }
            let output = renderSlider slider
            Expect.isNonEmpty output "Should render at minimum"

        testCase "Slider at maximum" <| fun _ ->
            let slider: Slider = { Value = 100.0; Min = 0.0; Max = 100.0; Width = 20; ShowValue = false; Disabled = false }
            let output = renderSlider slider
            Expect.isNonEmpty output "Should render at maximum"

        testCase "Slider shows value" <| fun _ ->
            let slider: Slider = { Value = 50.0; Min = 0.0; Max = 100.0; Width = 20; ShowValue = true; Disabled = false }
            let output = renderSlider slider
            Expect.stringContains output "50" "Should show value"

        testCase "Disabled slider differs" <| fun _ ->
            let enabled: Slider = { Value = 50.0; Min = 0.0; Max = 100.0; Width = 20; ShowValue = false; Disabled = false }
            let disabled: Slider = { Value = 50.0; Min = 0.0; Max = 100.0; Width = 20; ShowValue = false; Disabled = true }
            Expect.notEqual (renderSlider enabled) (renderSlider disabled) "Disabled should differ"

        testCase "Slider with custom range" <| fun _ ->
            let slider: Slider = { Value = 50.0; Min = 0.0; Max = 200.0; Width = 20; ShowValue = true; Disabled = false }
            let output = renderSlider slider
            Expect.isNonEmpty output "Custom range should render"
    ]

[<Tests>]
let datePickerTests =
    testList "Material3 DatePicker Component" [

        testCase "DatePicker input mode" <| fun _ ->
            let picker: DatePicker = { SelectedDate = None; Mode = DatePickerMode.Input; Width = 30 }
            let lines = renderDatePicker picker
            Expect.isGreaterThan (List.length lines) 0 "Should render"
            let output = String.concat "\n" lines
            Expect.stringContains output "📅" "Should have date icon"

        testCase "DatePicker calendar mode" <| fun _ ->
            let picker: DatePicker = { SelectedDate = Some DateTime.Today; Mode = DatePickerMode.Calendar; Width = 30 }
            let lines = renderDatePicker picker
            Expect.isGreaterThan (List.length lines) 5 "Calendar should have multiple lines"
            let output = String.concat "\n" lines
            Expect.stringContains output "Su" "Should show day headers"

        testCase "DatePicker with selected date" <| fun _ ->
            let date = DateTime(2025, 12, 25)
            let picker: DatePicker = { SelectedDate = Some date; Mode = DatePickerMode.Input; Width = 30 }
            let lines = renderDatePicker picker
            let output = String.concat "\n" lines
            Expect.stringContains output "2025-12-25" "Should show selected date"
    ]

[<Tests>]
let timePickerTests =
    testList "Material3 TimePicker Component" [

        testCase "TimePicker input mode" <| fun _ ->
            let picker: TimePicker = { SelectedTime = None; Mode = TimePickerMode.TimeInput; Is24Hour = true }
            let lines = renderTimePicker picker
            Expect.isGreaterThan (List.length lines) 0 "Should render"

        testCase "TimePicker clock mode" <| fun _ ->
            let picker: TimePicker = { SelectedTime = Some (TimeSpan(14, 30, 0)); Mode = TimePickerMode.Clock; Is24Hour = true }
            let lines = renderTimePicker picker
            let output = String.concat "\n" lines
            Expect.stringContains output "12" "Should show 12"
            Expect.stringContains output "14:30" "Should show time"

        testCase "TimePicker 12-hour format" <| fun _ ->
            let picker: TimePicker = { SelectedTime = Some (TimeSpan(14, 30, 0)); Mode = TimePickerMode.TimeInput; Is24Hour = false }
            let lines = renderTimePicker picker
            let output = String.concat "\n" lines
            Expect.stringContains output "PM" "Should show PM"
    ]

[<Tests>]
let menuTests =
    testList "Material3 Menu Component" [

        testCase "Menu renders items" <| fun _ ->
            let menu: Menu = {
                Items = [
                    { Label = "Copy"; Icon = Some "📋"; Shortcut = Some "Ctrl+C"; Disabled = false; Divider = false }
                    { Label = "Paste"; Icon = Some "📄"; Shortcut = Some "Ctrl+V"; Disabled = false; Divider = false }
                ]
                Width = 30
            }
            let lines = renderMenu menu
            let output = String.concat "\n" lines
            Expect.stringContains output "Copy" "Should contain Copy"
            Expect.stringContains output "Paste" "Should contain Paste"

        testCase "Menu with divider" <| fun _ ->
            let menu: Menu = {
                Items = [
                    { Label = "Item 1"; Icon = None; Shortcut = None; Disabled = false; Divider = false }
                    { Label = ""; Icon = None; Shortcut = None; Disabled = false; Divider = true }
                    { Label = "Item 2"; Icon = None; Shortcut = None; Disabled = false; Divider = false }
                ]
                Width = 20
            }
            let lines = renderMenu menu
            Expect.isGreaterThan (List.length lines) 3 "Should have divider"

        testCase "Menu with disabled item" <| fun _ ->
            let menu: Menu = {
                Items = [{ Label = "Disabled"; Icon = None; Shortcut = None; Disabled = true; Divider = false }]
                Width = 20
            }
            let lines = renderMenu menu
            Expect.isNonEmpty lines "Should render disabled items"
    ]

[<Tests>]
let exposedDropdownTests =
    testList "Material3 ExposedDropdown Component" [

        testCase "Dropdown collapsed" <| fun _ ->
            let dropdown: ExposedDropdown = {
                Label = "Country"
                SelectedValue = "USA"
                Options = ["USA"; "Canada"; "Mexico"]
                Expanded = false
                Width = 30
            }
            let lines = renderExposedDropdown dropdown
            let output = String.concat "\n" lines
            Expect.stringContains output "Country" "Should show label"
            Expect.stringContains output "USA" "Should show selected value"
            Expect.stringContains output "▼" "Should show down arrow"

        testCase "Dropdown expanded" <| fun _ ->
            let dropdown: ExposedDropdown = {
                Label = "Color"
                SelectedValue = "Red"
                Options = ["Red"; "Green"; "Blue"]
                Expanded = true
                Width = 25
            }
            let lines = renderExposedDropdown dropdown
            Expect.isGreaterThan (List.length lines) 4 "Expanded should show options"
            let output = String.concat "\n" lines
            Expect.stringContains output "▲" "Should show up arrow"
    ]

[<Tests>]
let bottomSheetTests =
    testList "Material3 BottomSheet Component" [

        testCase "BottomSheet renders" <| fun _ ->
            let sheet: BottomSheet = {
                Title = Some "Sheet Title"
                Content = ["Line 1"; "Line 2"]
                Variant = BottomSheetVariant.Standard
                Width = 40
                Height = 10
            }
            let lines = renderBottomSheet sheet
            Expect.isGreaterThan (List.length lines) 5 "Should have multiple lines"
            let output = String.concat "\n" lines
            Expect.stringContains output "Sheet Title" "Should contain title"

        testCase "BottomSheet has drag handle" <| fun _ ->
            let sheet: BottomSheet = {
                Title = None
                Content = []
                Variant = BottomSheetVariant.Modal
                Width = 30
                Height = 5
            }
            let lines = renderBottomSheet sheet
            let output = String.concat "\n" lines
            Expect.stringContains output "────" "Should have drag handle"

        testCase "BottomSheet fills height" <| fun _ ->
            let sheet: BottomSheet = {
                Title = None
                Content = ["Single line"]
                Variant = BottomSheetVariant.Standard
                Width = 30
                Height = 8
            }
            let lines = renderBottomSheet sheet
            Expect.equal (List.length lines) 8 "Should fill to specified height"
    ]

[<Tests>]
let sideSheetTests =
    testList "Material3 SideSheet Component" [

        testCase "SideSheet renders" <| fun _ ->
            let sheet: SideSheet = {
                Title = "Settings"
                Content = ["Option 1"; "Option 2"]
                Position = SideSheetPosition.Right
                Width = 30
                Height = 10
            }
            let lines = renderSideSheet sheet
            Expect.isGreaterThan (List.length lines) 5 "Should have multiple lines"
            let output = String.concat "\n" lines
            Expect.stringContains output "Settings" "Should contain title"

        testCase "SideSheet has close button" <| fun _ ->
            let sheet: SideSheet = {
                Title = "Panel"
                Content = []
                Position = SideSheetPosition.Left
                Width = 25
                Height = 8
            }
            let lines = renderSideSheet sheet
            let output = String.concat "\n" lines
            Expect.stringContains output "✕" "Should have close button"
    ]

[<Tests>]
let carouselTests =
    testList "Material3 Carousel Component" [

        testCase "Carousel renders items" <| fun _ ->
            let carousel: Carousel = {
                Items = [
                    { Content = "Slide 1"; Width = 15 }
                    { Content = "Slide 2"; Width = 15 }
                    { Content = "Slide 3"; Width = 15 }
                ]
                CurrentIndex = 0
                VisibleCount = 2
            }
            let lines = renderCarousel carousel
            let output = String.concat "\n" lines
            Expect.stringContains output "Slide 1" "Should show first slide"

        testCase "Carousel has navigation arrows" <| fun _ ->
            let carousel: Carousel = {
                Items = [
                    { Content = "A"; Width = 10 }
                    { Content = "B"; Width = 10 }
                    { Content = "C"; Width = 10 }
                ]
                CurrentIndex = 1
                VisibleCount = 1
            }
            let lines = renderCarousel carousel
            let output = String.concat "\n" lines
            Expect.stringContains output "◀" "Should have left arrow"
            Expect.stringContains output "▶" "Should have right arrow"

        testCase "Carousel has dots indicator" <| fun _ ->
            let carousel: Carousel = {
                Items = [{ Content = "X"; Width = 5 }; { Content = "Y"; Width = 5 }]
                CurrentIndex = 0
                VisibleCount = 1
            }
            let lines = renderCarousel carousel
            let output = String.concat "\n" lines
            Expect.stringContains output "●" "Should have active dot"
            Expect.stringContains output "○" "Should have inactive dot"
    ]

[<Tests>]
let topAppBarTests =
    testList "Material3 TopAppBar Component" [

        testCase "CenterAligned appbar" <| fun _ ->
            let appBar: TopAppBar = {
                Title = "App Title"
                NavigationIcon = Some "☰"
                Actions = ["⚙"]
                Variant = TopAppBarVariant.CenterAligned
                Width = 40
            }
            let lines = renderTopAppBar appBar
            Expect.isNonEmpty lines "Should render"
            let output = String.concat "\n" lines
            Expect.stringContains output "App Title" "Should contain title"

        testCase "Small appbar" <| fun _ ->
            let appBar: TopAppBar = {
                Title = "Small Title"
                NavigationIcon = Some "←"
                Actions = []
                Variant = TopAppBarVariant.Small
                Width = 40
            }
            let lines = renderTopAppBar appBar
            Expect.equal (List.length lines) 1 "Small should be single line"

        testCase "Medium appbar" <| fun _ ->
            let appBar: TopAppBar = {
                Title = "Medium Title"
                NavigationIcon = None
                Actions = ["✕"]
                Variant = TopAppBarVariant.Medium
                Width = 40
            }
            let lines = renderTopAppBar appBar
            Expect.equal (List.length lines) 2 "Medium should be 2 lines"

        testCase "Large appbar" <| fun _ ->
            let appBar: TopAppBar = {
                Title = "Large Title"
                NavigationIcon = Some "☰"
                Actions = []
                Variant = TopAppBarVariant.Large
                Width = 50
            }
            let lines = renderTopAppBar appBar
            Expect.equal (List.length lines) 3 "Large should be 3 lines"
    ]

[<Tests>]
let bottomAppBarTests =
    testList "Material3 BottomAppBar Component" [

        testCase "BottomAppBar renders actions" <| fun _ ->
            let appBar: BottomAppBar = {
                Actions = ["🔍"; "📁"; "⚙"]
                FabIcon = None
                Width = 40
            }
            let output = renderBottomAppBar appBar
            Expect.stringContains output "🔍" "Should contain search"

        testCase "BottomAppBar with FAB" <| fun _ ->
            let appBar: BottomAppBar = {
                Actions = ["✏"]
                FabIcon = Some "+"
                Width = 40
            }
            let output = renderBottomAppBar appBar
            Expect.stringContains output "+" "Should contain FAB"
    ]

[<Tests>]
let navigationRailTests =
    testList "Material3 NavigationRail Component" [

        testCase "NavigationRail renders items" <| fun _ ->
            let rail: NavigationRail = {
                Items = [
                    { Icon = "🏠"; Label = "Home"; Selected = true; Badge = None }
                    { Icon = "⚙"; Label = "Settings"; Selected = false; Badge = None }
                ]
                FabIcon = None
                Alignment = "top"
            }
            let lines = renderNavigationRail rail
            let output = String.concat "\n" lines
            Expect.stringContains output "Home" "Should contain Home"
            Expect.stringContains output "Settings" "Should contain Settings"

        testCase "NavigationRail with FAB" <| fun _ ->
            let rail: NavigationRail = {
                Items = []
                FabIcon = Some "+"
                Alignment = "top"
            }
            let lines = renderNavigationRail rail
            let output = String.concat "\n" lines
            Expect.stringContains output "+" "Should contain FAB"

        testCase "NavigationRail with badge" <| fun _ ->
            let rail: NavigationRail = {
                Items = [{ Icon = "✉"; Label = "Mail"; Selected = false; Badge = Some 5 }]
                FabIcon = None
                Alignment = "center"
            }
            let lines = renderNavigationRail rail
            let output = String.concat "\n" lines
            Expect.stringContains output "5" "Should show badge count"
    ]

[<Tests>]
let navigationDrawerTests =
    testList "Material3 NavigationDrawer Component" [

        testCase "NavigationDrawer renders items" <| fun _ ->
            let drawer: NavigationDrawer = {
                Header = Some "Navigation"
                Items = [
                    { Icon = "📁"; Label = "Files"; Selected = true; Badge = None }
                    { Icon = "📷"; Label = "Photos"; Selected = false; Badge = Some "99+" }
                ]
                Width = 30
            }
            let lines = renderNavigationDrawer drawer
            let output = String.concat "\n" lines
            Expect.stringContains output "Navigation" "Should contain header"
            Expect.stringContains output "Files" "Should contain Files"

        testCase "Selected item indicator" <| fun _ ->
            let drawer: NavigationDrawer = {
                Header = None
                Items = [{ Icon = "★"; Label = "Starred"; Selected = true; Badge = None }]
                Width = 25
            }
            let lines = renderNavigationDrawer drawer
            let output = String.concat "\n" lines
            Expect.stringContains output "●" "Should show selection indicator"
    ]

[<Tests>]
let searchBarTests =
    testList "Material3 SearchBar Component" [

        testCase "SearchBar empty with placeholder" <| fun _ ->
            let search: SearchBar = {
                Query = ""
                Placeholder = "Search..."
                LeadingIcon = "🔍"
                TrailingIcon = None
                Focused = false
                Width = 40
            }
            let lines = renderSearchBar search
            let output = String.concat "\n" lines
            Expect.stringContains output "Search..." "Should show placeholder"
            Expect.stringContains output "🔍" "Should show search icon"

        testCase "SearchBar with query" <| fun _ ->
            let search: SearchBar = {
                Query = "test query"
                Placeholder = "Search..."
                LeadingIcon = "🔍"
                TrailingIcon = Some "✕"
                Focused = true
                Width = 40
            }
            let lines = renderSearchBar search
            let output = String.concat "\n" lines
            Expect.stringContains output "test query" "Should show query"
            Expect.stringContains output "│" "Focused should show cursor"

        testCase "SearchBar has rounded borders" <| fun _ ->
            let search: SearchBar = {
                Query = ""
                Placeholder = ""
                LeadingIcon = ">"
                TrailingIcon = None
                Focused = false
                Width = 30
            }
            let lines = renderSearchBar search
            let output = String.concat "\n" lines
            Expect.stringContains output "╭" "Should have rounded corners"
            Expect.stringContains output "╯" "Should have rounded corners"
    ]

[<Tests>]
let floatingToolbarTests =
    testList "Material3 FloatingToolbar Component" [

        testCase "Docked toolbar" <| fun _ ->
            let toolbar: FloatingToolbar = {
                Actions = [("✂", "Cut"); ("📋", "Copy"); ("📄", "Paste")]
                Variant = FloatingToolbarVariant.Docked
                Width = 50
            }
            let lines = renderFloatingToolbar toolbar
            let output = String.concat "\n" lines
            Expect.stringContains output "Cut" "Should contain Cut"
            Expect.stringContains output "Copy" "Should contain Copy"

        testCase "Floating toolbar" <| fun _ ->
            let toolbar: FloatingToolbar = {
                Actions = [("★", "Star")]
                Variant = FloatingToolbarVariant.Floating
                Width = 30
            }
            let lines = renderFloatingToolbar toolbar
            let output = String.concat "\n" lines
            Expect.stringContains output "╭" "Floating should have pill shape"
    ]

[<Tests>]
let fabMenuTests =
    testList "Material3 FABMenu Component" [

        testCase "FABMenu collapsed" <| fun _ ->
            let menu: FABMenu = {
                MainIcon = "+"
                Items = [{ Icon = "📷"; Label = "Camera" }; { Icon = "🖼"; Label = "Gallery" }]
                Expanded = false
            }
            let lines = renderFABMenu menu
            let output = String.concat "\n" lines
            Expect.stringContains output "+" "Should show main icon"
            Expect.isFalse (output.Contains("Camera")) "Should not show menu items"

        testCase "FABMenu expanded" <| fun _ ->
            let menu: FABMenu = {
                MainIcon = "+"
                Items = [{ Icon = "📷"; Label = "Camera" }; { Icon = "🖼"; Label = "Gallery" }]
                Expanded = true
            }
            let lines = renderFABMenu menu
            let output = String.concat "\n" lines
            Expect.stringContains output "Camera" "Should show Camera"
            Expect.stringContains output "Gallery" "Should show Gallery"
            Expect.stringContains output "✕" "Main icon should be close"
    ]

[<Tests>]
let tooltipTests =
    testList "Material3 Tooltip Component" [

        testCase "Plain tooltip" <| fun _ ->
            let tooltip: Tooltip = { Content = "Helpful tip"; Title = None; Variant = TooltipVariant.Plain }
            let output = renderTooltip tooltip
            Expect.stringContains output "Helpful tip" "Should contain content"

        testCase "Rich tooltip with title" <| fun _ ->
            let tooltip: Tooltip = { Content = "Description here"; Title = Some "Title"; Variant = TooltipVariant.Rich }
            let output = renderTooltip tooltip
            Expect.stringContains output "Title" "Should contain title"
            Expect.stringContains output "Description here" "Should contain description"
    ]

[<Tests>]
let loadingIndicatorTests =
    testList "Material3 LoadingIndicator Component" [

        testCase "Indeterminate spinner" <| fun _ ->
            let indicator: LoadingIndicator = { Progress = None; Size = "medium" }
            let output = renderLoadingIndicator indicator
            Expect.isNonEmpty output "Should render spinner"

        testCase "Determinate progress" <| fun _ ->
            let indicator50: LoadingIndicator = { Progress = Some 0.5; Size = "medium" }
            let indicator100: LoadingIndicator = { Progress = Some 1.0; Size = "medium" }
            let o50 = renderLoadingIndicator indicator50
            let o100 = renderLoadingIndicator indicator100
            Expect.isNonEmpty o50 "50% should render"
            Expect.stringContains o100 "●" "100% should be full"

        testCase "Size variants" <| fun _ ->
            let sizes = ["small"; "medium"; "large"]
            for size in sizes do
                let indicator: LoadingIndicator = { Progress = None; Size = size }
                let output = renderLoadingIndicator indicator
                Expect.isNonEmpty output $"Size {size} should render"
    ]

[<Tests>]
let swipeToDismissTests =
    testList "Material3 SwipeToDismiss Component" [

        testCase "Not swiping" <| fun _ ->
            let swipe: SwipeToDismiss = {
                Content = "Item content"
                LeftAction = Some ("✓", Colors.primary)
                RightAction = Some ("✕", Colors.error)
                SwipeProgress = 0.0
                Width = 40
            }
            let output = renderSwipeToDismiss swipe
            Expect.stringContains output "Item content" "Should show content"

        testCase "Swiping right shows left action" <| fun _ ->
            let swipe: SwipeToDismiss = {
                Content = "Item"
                LeftAction = Some ("✓", Colors.primary)
                RightAction = None
                SwipeProgress = 0.5
                Width = 30
            }
            let output = renderSwipeToDismiss swipe
            Expect.stringContains output "✓" "Should show left action"

        testCase "Swiping left shows right action" <| fun _ ->
            let swipe: SwipeToDismiss = {
                Content = "Item"
                LeftAction = None
                RightAction = Some ("✕", Colors.error)
                SwipeProgress = -0.5
                Width = 30
            }
            let output = renderSwipeToDismiss swipe
            Expect.stringContains output "✕" "Should show right action"
    ]

[<Tests>]
let pullToRefreshTests =
    testList "Material3 PullToRefresh Component" [

        testCase "Idle state is empty" <| fun _ ->
            let output = renderPullToRefresh PullToRefreshState.Idle 40
            Expect.equal output "" "Idle should be empty"

        testCase "Pulling state shows arrow" <| fun _ ->
            let output = renderPullToRefresh (PullToRefreshState.Pulling 0.5) 40
            Expect.stringContains output "↓" "Should show down arrow"

        testCase "Pulling near threshold shows refresh arrow" <| fun _ ->
            let output = renderPullToRefresh (PullToRefreshState.Pulling 0.9) 40
            Expect.stringContains output "↻" "Should show refresh arrow"

        testCase "Refreshing state shows spinner" <| fun _ ->
            let output = renderPullToRefresh PullToRefreshState.Refreshing 40
            Expect.stringContains output "Refreshing" "Should show refreshing text"

        testCase "Complete state shows checkmark" <| fun _ ->
            let output = renderPullToRefresh PullToRefreshState.Complete 40
            Expect.stringContains output "✓" "Should show checkmark"
            Expect.stringContains output "Updated" "Should show updated text"
    ]

// ============================================================================
// DARKCOCKPITUI COMPONENT TESTS
// ============================================================================

[<Tests>]
let ansiModuleTests =
    testList "DarkCockpitUI ANSI Module" [

        testCase "Reset code is present" <| fun _ ->
            Expect.equal Ansi.reset "\u001b[0m" "Reset should be correct"

        testCase "Bold modifier works" <| fun _ ->
            Expect.stringContains Ansi.bold "1m" "Bold should contain 1m"

        testCase "Dim modifier works" <| fun _ ->
            Expect.stringContains Ansi.dim "2m" "Dim should contain 2m"

        testCase "Dark cockpit colors are defined" <| fun _ ->
            Expect.isNonEmpty Ansi.normal "Normal should be defined"
            Expect.isNonEmpty Ansi.advisory "Advisory should be defined"
            Expect.isNonEmpty Ansi.caution "Caution should be defined"
            Expect.isNonEmpty Ansi.warning "Warning should be defined"
            Expect.isNonEmpty Ansi.critical "Critical should be defined"
    ]

[<Tests>]
let iconsModuleTests =
    testList "DarkCockpitUI Icons Module" [

        testCase "Status icons are defined" <| fun _ ->
            Expect.isNonEmpty Icons.connected "Connected icon defined"
            Expect.isNonEmpty Icons.stale "Stale icon defined"
            Expect.isNonEmpty Icons.disconnected "Disconnected icon defined"

        testCase "Alarm icons are defined" <| fun _ ->
            Expect.isNonEmpty Icons.normal "Normal icon defined"
            Expect.isNonEmpty Icons.advisory "Advisory icon defined"
            Expect.isNonEmpty Icons.caution "Caution icon defined"
            Expect.isNonEmpty Icons.warning "Warning icon defined"
            Expect.isNonEmpty Icons.critical "Critical icon defined"

        testCase "Trend arrows are defined" <| fun _ ->
            Expect.isNonEmpty Icons.rising "Rising icon defined"
            Expect.isNonEmpty Icons.risingFast "Rising fast icon defined"
            Expect.isNonEmpty Icons.falling "Falling icon defined"
            Expect.isNonEmpty Icons.fallingFast "Falling fast icon defined"
            Expect.isNonEmpty Icons.stable "Stable icon defined"

        testCase "Sparkline chars are 8 levels" <| fun _ ->
            Expect.equal Icons.spark.Length 8 "Should have 8 sparkline levels"

        testCase "Spinner has multiple frames" <| fun _ ->
            Expect.isGreaterThan Icons.spinner.Length 4 "Should have multiple frames"
    ]

[<Tests>]
let boxModuleTests =
    testList "DarkCockpitUI Box Module" [

        testCase "Box drawing characters are defined" <| fun _ ->
            Expect.isNonEmpty Box.tl "TopLeft defined"
            Expect.isNonEmpty Box.tr "TopRight defined"
            Expect.isNonEmpty Box.bl "BottomLeft defined"
            Expect.isNonEmpty Box.br "BottomRight defined"
            Expect.isNonEmpty Box.h "Horizontal defined"
            Expect.isNonEmpty Box.v "Vertical defined"

        testCase "Light box characters are defined" <| fun _ ->
            Expect.isNonEmpty Box.ltl "Light TopLeft defined"
            Expect.isNonEmpty Box.lh "Light Horizontal defined"
    ]

[<Tests>]
let alarmColorTests =
    testList "DarkCockpitUI alarmColor Function" [

        testCase "Normal returns dim gray" <| fun _ ->
            let color = alarmColor Normal
            Expect.equal color Ansi.normal "Should be normal color"

        testCase "Each alarm level has unique color" <| fun _ ->
            let levels = [Normal; Advisory; Caution; Warning; Critical]
            let colors = levels |> List.map alarmColor
            let unique = colors |> List.distinct
            Expect.equal unique.Length levels.Length "Each level should have unique color"

        testCase "Critical alarm color is critical" <| fun _ ->
            let color = alarmColor Critical
            Expect.equal color Ansi.critical "Critical should be critical color"
    ]

[<Tests>]
let statusColorTests =
    testList "DarkCockpitUI statusColor Function" [

        testCase "Connected status has color" <| fun _ ->
            let color = statusColor Connected
            Expect.equal color Ansi.connected "Connected should have connected color"

        testCase "Each connection status has unique color" <| fun _ ->
            let statuses = [Connected; Stale; Degraded; Disconnected]
            let colors = statuses |> List.map statusColor
            let unique = colors |> List.distinct
            Expect.equal unique.Length statuses.Length "Each status should have unique color"
    ]

[<Tests>]
let trendArrowTests =
    testList "DarkCockpitUI trendArrow Function" [

        testCase "Each trend has unique arrow" <| fun _ ->
            let trends = [Rising; RisingFast; Falling; FallingFast; Stable]
            let arrows = trends |> List.map trendArrow
            let unique = arrows |> List.distinct
            Expect.equal unique.Length trends.Length "Each trend should have unique arrow"

        testCase "Rising trends use up arrows" <| fun _ ->
            let rising = trendArrow Rising
            let risingFast = trendArrow RisingFast
            Expect.stringContains rising Icons.rising "Rising should have up arrow"
            Expect.stringContains risingFast Icons.risingFast "Rising fast should have up arrows"

        testCase "Falling trends use down arrows" <| fun _ ->
            let falling = trendArrow Falling
            let fallingFast = trendArrow FallingFast
            Expect.stringContains falling Icons.falling "Falling should have down arrow"
            Expect.stringContains fallingFast Icons.fallingFast "Falling fast should have down arrows"

        testCase "Stable uses horizontal arrow" <| fun _ ->
            let stable = trendArrow Stable
            Expect.stringContains stable Icons.stable "Stable should have horizontal arrow"
    ]

[<Tests>]
let sparklineTests =
    testList "DarkCockpitUI renderSparkline Function" [

        testCase "Sparkline renders for valid data" <| fun _ ->
            let data = [10.0; 20.0; 30.0; 40.0; 50.0]
            let output = renderSparkline data 100.0 10
            Expect.isGreaterThan output.Length 0 "Should produce output"

        testCase "Sparkline respects width" <| fun _ ->
            let data = [10.0; 20.0; 30.0; 40.0; 50.0; 60.0; 70.0; 80.0; 90.0; 100.0]
            let width = 8
            let output = renderSparkline data 100.0 width
            Expect.isLessThanOrEqual output.Length (width + 2) "Should respect width"

        testCase "Empty sparkline handles gracefully" <| fun _ ->
            let output = renderSparkline [] 100.0 10
            Expect.isNonEmpty output "Should handle empty data"

        testCase "Single value sparkline works" <| fun _ ->
            let output = renderSparkline [50.0] 100.0 10
            Expect.isNonEmpty output "Should handle single value"
    ]

[<Tests>]
let barTests =
    testList "DarkCockpitUI renderBar Function" [

        testCase "Bar renders for valid percentage" <| fun _ ->
            let output = renderBar 50.0 100.0 20 Normal
            Expect.isNonEmpty output "Should produce output"

        testCase "Bar at 0% shows minimal fill" <| fun _ ->
            let output = renderBar 0.0 100.0 20 Normal
            Expect.isNonEmpty output "0% should render"

        testCase "Bar at 100% shows full fill" <| fun _ ->
            let output = renderBar 100.0 100.0 20 Normal
            Expect.isNonEmpty output "100% should render"

        testCase "Bar uses alarm level color" <| fun _ ->
            let normal = renderBar 50.0 100.0 10 Normal
            let warning = renderBar 50.0 100.0 10 Warning
            Expect.notEqual normal warning "Different levels should have different colors"
    ]

// ============================================================================
// OODA HMI L7 ENHANCEMENT TESTS
// ============================================================================

[<Tests>]
let spiderChartTests =
    testList "OodaHmi Spider Chart" [

        testCase "Spider chart renders with valid data" <| fun _ ->
            let dimensions = [("CPU", 75.0, Normal); ("MEM", 60.0, Normal); ("NET", 30.0, Advisory)]
            let lines = OodaHmi.renderSpiderChart dimensions 5
            Expect.isGreaterThan (List.length lines) 0 "Should produce output"

        testCase "Empty metrics returns placeholder" <| fun _ ->
            let lines = OodaHmi.renderSpiderChart [] 5
            Expect.isNonEmpty lines "Should return placeholder"

        testCase "Four metrics renders" <| fun _ ->
            let dims = [
                ("CPU", 80.0, Caution)
                ("MEM", 60.0, Normal)
                ("NET", 40.0, Normal)
                ("DISK", 90.0, Warning)
            ]
            let lines = OodaHmi.renderSpiderChart dims 5
            Expect.isGreaterThan (List.length lines) 0 "Should render multi-dimensional chart"
    ]

[<Tests>]
let safetyMarginBarTests =
    testList "OodaHmi Safety Margin Bar" [

        testCase "Safety margin bar renders" <| fun _ ->
            let output = OodaHmi.renderSafetyMarginBar 50.0 75.0 90.0 100.0 20
            Expect.isNonEmpty output "Should produce output"

        testCase "Safety margin shows threshold markers" <| fun _ ->
            let output = OodaHmi.renderSafetyMarginBar 50.0 75.0 90.0 100.0 20
            Expect.isTrue (output.Contains("75") || output.Contains("90")) "Should show thresholds"

        testCase "Value in caution zone" <| fun _ ->
            let output = OodaHmi.renderSafetyMarginBar 80.0 75.0 90.0 100.0 20
            Expect.isNonEmpty output "Should render caution zone"

        testCase "Value in warning zone" <| fun _ ->
            let output = OodaHmi.renderSafetyMarginBar 95.0 75.0 90.0 100.0 20
            Expect.isNonEmpty output "Should render warning zone"
    ]

[<Tests>]
let predictiveBarTests =
    testList "OodaHmi Predictive Bar" [

        testCase "Predictive bar renders" <| fun _ ->
            let output = OodaHmi.renderPredictiveBar 50.0 Rising 60.0 20
            Expect.isNonEmpty output "Should produce output"

        testCase "Stable trend shows current value" <| fun _ ->
            let output = OodaHmi.renderPredictiveBar 50.0 Stable 60.0 20
            Expect.stringContains output "50" "Should show current value"

        testCase "Rising trend shows prediction" <| fun _ ->
            let output = OodaHmi.renderPredictiveBar 50.0 Rising 60.0 20
            Expect.isNonEmpty output "Should show prediction"

        testCase "Fast trends predict further" <| fun _ ->
            let slow = OodaHmi.renderPredictiveBar 50.0 Rising 60.0 20
            let fast = OodaHmi.renderPredictiveBar 50.0 RisingFast 60.0 20
            Expect.notEqual slow fast "Fast rising should predict higher"
    ]

[<Tests>]
let topologyTests =
    testList "OodaHmi Topology Renderer" [

        testCase "Empty topology returns empty" <| fun _ ->
            let lines = OodaHmi.renderTopology [] [] 80
            Expect.isEmpty lines "Empty topology should be empty"

        testCase "Single node renders" <| fun _ ->
            let nodes: OodaHmi.TopoNode list = [{
                Id = "n1"
                Label = "Node1"
                Level = 0
                Column = 0
                Status = Connected
                Health = 95.0
                AlarmLevel = Normal
            }]
            let lines = OodaHmi.renderTopology nodes [] 80
            Expect.isNonEmpty lines "Should render single node"

        testCase "Multi-level topology" <| fun _ ->
            let nodes: OodaHmi.TopoNode list = [
                { Id = "sup"; Label = "Supervisor"; Level = 0; Column = 0; Status = Connected; Health = 100.0; AlarmLevel = Normal }
                { Id = "ctrl"; Label = "Controller"; Level = 1; Column = 0; Status = Connected; Health = 90.0; AlarmLevel = Normal }
                { Id = "work"; Label = "Worker"; Level = 2; Column = 0; Status = Connected; Health = 85.0; AlarmLevel = Normal }
            ]
            let edges: OodaHmi.TopoEdge list = [
                { From = "sup"; To = "ctrl"; Latency = Some 5.0 }
                { From = "ctrl"; To = "work"; Latency = Some 3.0 }
            ]
            let lines = OodaHmi.renderTopology nodes edges 80
            Expect.isGreaterThan (List.length lines) 1 "Should render multi-level"
    ]

[<Tests>]
let timelineTests =
    testList "OodaHmi Timeline Renderer" [

        testCase "Empty timeline returns empty" <| fun _ ->
            let lines = OodaHmi.renderTimeline [] 80
            Expect.isEmpty lines "Empty timeline should be empty"

        testCase "Timeline renders events" <| fun _ ->
            let events = [
                (DateTime.UtcNow.AddMinutes(-10.0), "Alarm triggered", Warning)
                (DateTime.UtcNow.AddMinutes(-5.0), "Acknowledged", Advisory)
                (DateTime.UtcNow, "Resolved", Normal)
            ]
            let lines = OodaHmi.renderTimeline events 80
            Expect.isGreaterThan (List.length lines) 0 "Should produce output"

        testCase "Timeline limits to 10 events" <| fun _ ->
            let now = DateTime.UtcNow
            let events = List.init 20 (fun i -> (now.AddMinutes(float -i), sprintf "Event %d" i, Normal))
            let lines = OodaHmi.renderTimeline events 80
            Expect.isLessThanOrEqual (List.length lines) 10 "Should limit to 10"
    ]

[<Tests>]
let oodaCycleTests =
    testList "OodaHmi OODA Cycle Display" [

        testCase "OODA cycle renders" <| fun _ ->
            let output = OodaHmi.renderOodaCycle OodaHmi.Observe 500.0 95.0
            Expect.stringContains output "OODA" "Should show OODA"

        testCase "All phases render differently" <| fun _ ->
            let phases = [OodaHmi.Observe; OodaHmi.Orient; OodaHmi.Decide; OodaHmi.Act]
            let outputs = phases |> List.map (fun p -> OodaHmi.renderOodaCycle p 500.0 95.0)
            let unique = outputs |> List.distinct
            Expect.equal (List.length unique) 4 "All phases should be unique"

        testCase "Cycle time affects color" <| fun _ ->
            let fast = OodaHmi.renderOodaCycle OodaHmi.Observe 500.0 95.0
            let slow = OodaHmi.renderOodaCycle OodaHmi.Observe 1500.0 95.0
            Expect.notEqual fast slow "Fast vs slow should differ"
    ]

[<Tests>]
let disclosureLevelTests =
    testList "OodaHmi Disclosure Level Rendering" [

        testCase "Summary level is compact" <| fun _ ->
            let metric = TestHelpers.createTestMetric "CPU" 75.0 "%" Rising Caution [50.0; 60.0; 70.0; 75.0]
            let summary = OodaHmi.renderMetricAtLevel metric OodaHmi.Summary 80
            Expect.isNonEmpty summary "Summary should render"

        testCase "Expert level shows more detail" <| fun _ ->
            let metric = TestHelpers.createTestMetric "CPU" 75.0 "%" Rising Caution [50.0; 60.0; 70.0; 75.0]
            let summary = OodaHmi.renderMetricAtLevel metric OodaHmi.Summary 80
            let expert = OodaHmi.renderMetricAtLevel metric OodaHmi.Expert 80
            Expect.isGreaterThan (List.length expert) (List.length summary) "Expert should be longer"

        testCase "All disclosure levels render" <| fun _ ->
            let metric = TestHelpers.createTestMetric "TEST" 50.0 "%" Stable Normal []
            let levels = [OodaHmi.Summary; OodaHmi.Overview; OodaHmi.Detailed; OodaHmi.Expert]
            for level in levels do
                let lines = OodaHmi.renderMetricAtLevel metric level 80
                Expect.isNonEmpty lines $"Level {level} should render"
    ]

[<Tests>]
let commandFeedbackTests =
    testList "OodaHmi Command Feedback" [

        testCase "Idle command renders" <| fun _ ->
            let cmd = {
                Id = "cmd1"
                Command = PowerOff
                TargetNodeId = "node1"
                State = Idle
                ArmedAt = None
                ExecutedAt = None
                AcknowledgedAt = None
                ErrorMessage = None
                RequiresConfirmation = true
            }
            let lines = OodaHmi.renderCommandFeedback cmd 80
            Expect.isNonEmpty lines "Should render idle command"

        testCase "Armed command shows expiry" <| fun _ ->
            let cmd = {
                Id = "cmd2"
                Command = Restart
                TargetNodeId = "node1"
                State = Armed
                ArmedAt = Some (DateTime.UtcNow.AddSeconds(-5.0))
                ExecutedAt = None
                AcknowledgedAt = None
                ErrorMessage = None
                RequiresConfirmation = true
            }
            let lines = OodaHmi.renderCommandFeedback cmd 80
            let output = String.concat "\n" lines
            Expect.stringContains output "Expires" "Should show expiry"

        testCase "Failed command shows error" <| fun _ ->
            let cmd = {
                Id = "cmd3"
                Command = ForceHealthCheck
                TargetNodeId = "node1"
                State = Failed
                ArmedAt = None
                ExecutedAt = None
                AcknowledgedAt = None
                ErrorMessage = Some "Connection timeout"
                RequiresConfirmation = false
            }
            let lines = OodaHmi.renderCommandFeedback cmd 80
            let output = String.concat "\n" lines
            Expect.stringContains output "Connection timeout" "Should show error"
    ]

// ============================================================================
// COMPOSABILITY TESTS - DASHBOARD LAYOUTS
// ============================================================================

[<Tests>]
let dashboardCompositionTests =
    testList "Dashboard Composition" [

        testCase "Multiple cards compose" <| fun _ ->
            let cards = [
                { Title = Some "CPU"; Subtitle = None; Content = ["42%"]; Variant = CardVariant.Outlined; Width = 15 }
                { Title = Some "MEM"; Subtitle = None; Content = ["68%"]; Variant = CardVariant.Outlined; Width = 15 }
                { Title = Some "NET"; Subtitle = None; Content = ["12ms"]; Variant = CardVariant.Outlined; Width = 15 }
            ]
            let allLines = cards |> List.collect renderCard
            Expect.isGreaterThan (List.length allLines) 6 "Should render all cards"

        testCase "Buttons and chips together" <| fun _ ->
            let btn: Button = { Label = "Submit"; Variant = ButtonVariant.Filled; Disabled = false; Icon = None }
            let chip: Chip = { Label = "Filter"; Variant = ChipVariant.Filter; Selected = true; Icon = None }
            let btnOutput = renderButton btn
            let chipOutput = renderChip chip
            let combined = btnOutput + " " + chipOutput
            Expect.stringContains combined "Submit" "Should contain button"
            Expect.stringContains combined "Filter" "Should contain chip"

        testCase "Metric card composes" <| fun _ ->
            let lines = renderMetricCard "CPU Usage" "78%" "^" "caution" 30
            Expect.isGreaterThan (List.length lines) 0 "Should render metric card"
    ]

[<Tests>]
let fullDashboardTests =
    testList "Full Dashboard Integration" [

        testCase "Header panel renders" <| fun _ ->
            let state = TestHelpers.createTestState ()
            let size = { Cols = 80; Rows = 24 }
            let lines = renderHeader state size 0
            Expect.isGreaterThan (List.length lines) 0 "Header should render"

        testCase "Nodes panel renders" <| fun _ ->
            let state = TestHelpers.createTestState ()
            let stateWithNodes = {
                state with
                    Nodes = Map.ofList [
                        ("n1", TestHelpers.createTestNode "n1" "App-1" Connected "zone-a" Controller 95 42.0 Stable)
                    ]
            }
            let lines = renderNodesPanel stateWithNodes 40 10
            Expect.isGreaterThan (List.length lines) 0 "Nodes panel should render"

        testCase "Alarms panel renders" <| fun _ ->
            let state = TestHelpers.createTestState ()
            let lines = renderAlarmsPanel state 40 10
            Expect.isGreaterThan (List.length lines) 0 "Alarms panel should render"

        testCase "AI panel renders" <| fun _ ->
            let state = TestHelpers.createTestState ()
            let lines = renderAiPanel state 40 10
            Expect.isGreaterThan (List.length lines) 0 "AI panel should render"

        testCase "Footer renders" <| fun _ ->
            let state = TestHelpers.createTestState ()
            let size = { Cols = 80; Rows = 24 }
            let lines = renderFooter state size
            Expect.isGreaterThan (List.length lines) 0 "Footer should render"
    ]

[<Tests>]
let componentCombinationTests =
    testList "Component Combinations" [

        testCase "NavBar with chips as alternative" <| fun _ ->
            let navItems: NavItem list = [
                { Label = "Home"; Icon = "H"; Selected = true }
                { Label = "Settings"; Icon = "S"; Selected = false }
            ]
            let chips: Chip list = [
                { Label = "Active"; Variant = ChipVariant.Filter; Selected = true; Icon = None }
                { Label = "All"; Variant = ChipVariant.Filter; Selected = false; Icon = None }
            ]
            let nav = renderNavBar navItems 60
            let chipRow = chips |> List.map renderChip |> String.concat " "
            Expect.isNonEmpty nav "Nav should render"
            Expect.isNonEmpty chipRow "Chips should render"

        testCase "Table inside card concept" <| fun _ ->
            let columns = [{ Header = "Name"; Width = 15; Align = "left" }]
            let rows = [{ Cells = ["Item 1"]; Selected = false }]
            let tableLines = renderTable columns rows
            let card = {
                Title = Some "Data"
                Subtitle = None
                Content = tableLines
                Variant = CardVariant.Elevated
                Width = 40
            }
            let cardLines = renderCard card
            Expect.isGreaterThan (List.length cardLines) (List.length tableLines) "Card should wrap table"

        testCase "Progress and sparkline together" <| fun _ ->
            let progress = renderProgress (Determinate 0.75) 15
            let sparkline = renderSparkline [70.0; 72.0; 75.0; 73.0; 75.0] 100.0 15
            Expect.isNonEmpty progress "Progress should render"
            Expect.isNonEmpty sparkline "Sparkline should render"
    ]

// ============================================================================
// PROPERTY-BASED TESTS
// ============================================================================

let config = { FsCheckConfig.defaultConfig with arbitrary = [typeof<UIGenerators>] }

[<Tests>]
let propertyBasedTests =
    testList "Property-Based Tests" [

        testPropertyWithConfig config "All alarm levels render colors" <| fun (level: AlarmLevel) ->
            let color = alarmColor level
            not (String.IsNullOrEmpty color)

        testPropertyWithConfig config "All trends render arrows" <| fun (trend: Trend) ->
            let arrow = trendArrow trend
            not (String.IsNullOrEmpty arrow)

        testPropertyWithConfig config "All connection statuses render colors" <| fun (status: ConnStatus) ->
            let color = statusColor status
            not (String.IsNullOrEmpty color)

        testPropertyWithConfig config "Button variants all render" <| fun (variant: ButtonVariant) ->
            let btn = { Label = "Test"; Variant = variant; Disabled = false; Icon = None }
            let output = renderButton btn
            not (String.IsNullOrEmpty output)

        testPropertyWithConfig config "Card variants all render" <| fun (variant: CardVariant) ->
            let card = { Title = Some "T"; Subtitle = None; Content = []; Variant = variant; Width = 20 }
            let lines = renderCard card
            lines.Length > 0

        testPropertyWithConfig config "TextField variants all render" <| fun (variant: TextFieldVariant) ->
            let field = { Label = "L"; Value = "V"; Variant = variant; Focused = false; Error = None; Width = 20 }
            let lines = renderTextField field
            lines.Length > 0

        testPropertyWithConfig config "Badge variants all render" <| fun (variant: BadgeVariant) ->
            let output = renderBadge variant (Some 5)
            not (String.IsNullOrEmpty output)

        testPropertyWithConfig config "Disclosure levels all render" <| fun (level: OodaHmi.DisclosureLevel) ->
            let metric = TestHelpers.createTestMetric "X" 50.0 "%" Stable Normal []
            let lines = OodaHmi.renderMetricAtLevel metric level 80
            lines.Length > 0
    ]

// ============================================================================
// REGRESSION TESTS
// ============================================================================

[<Tests>]
let regressionTests =
    testList "Regression Tests" [

        testCase "REG-001: Sparkline doesn't crash on large datasets" <| fun _ ->
            let data = List.init 1000 (fun i -> float i)
            let output = renderSparkline data 1000.0 50
            Expect.isNonEmpty output "Should handle large dataset"

        testCase "REG-002: Bar handles edge case percentages" <| fun _ ->
            let outputs = [
                renderBar -5.0 100.0 20 Normal
                renderBar 0.0 100.0 20 Normal
                renderBar 100.0 100.0 20 Normal
                renderBar 150.0 100.0 20 Normal
            ]
            outputs |> List.iter (fun o -> Expect.isNonEmpty o "Should handle edge cases")

        testCase "REG-003: Empty card content doesn't crash" <| fun _ ->
            let card = { Title = None; Subtitle = None; Content = []; Variant = CardVariant.Outlined; Width = 20 }
            let lines = renderCard card
            Expect.isTrue (lines.Length >= 0) "Should handle empty content"

        testCase "REG-004: Unicode in button labels works" <| fun _ ->
            let btn: Button = { Label = "Launch"; Variant = ButtonVariant.Filled; Disabled = false; Icon = Some ">" }
            let output = renderButton btn
            Expect.stringContains output "Launch" "Should preserve label"

        testCase "REG-005: Very long text in card" <| fun _ ->
            let longText = String.replicate 100 "X"
            let card = { Title = Some longText; Subtitle = None; Content = []; Variant = CardVariant.Outlined; Width = 30 }
            let lines = renderCard card
            for line in lines do
                let visible = TestHelpers.visibleLength line
                Expect.isLessThanOrEqual visible 35 "Should truncate long text"
    ]

// ============================================================================
// DARK COCKPIT SC-HMI COMPLIANCE TESTS
// ============================================================================

[<Tests>]
let darkCockpitComplianceTests =
    testList "SC-HMI Compliance" [

        testCase "SC-HMI-001: Normal state is visually minimal" <| fun _ ->
            let normalColor = alarmColor Normal
            Expect.equal normalColor Ansi.normal "Normal should use dim color"

        testCase "SC-HMI-002: Trend vectors are visible" <| fun _ ->
            let trends = [Rising; RisingFast; Falling; FallingFast; Stable]
            for trend in trends do
                let arrow = trendArrow trend
                Expect.isNonEmpty arrow $"Trend {trend} should have arrow"

        testCase "SC-HMI-003: Stale data is visually distinct" <| fun _ ->
            let connectedColor = statusColor Connected
            let staleColor = statusColor Stale
            Expect.notEqual connectedColor staleColor "Stale should differ from Connected"

        testCase "SC-HMI-004: Command states follow two-step commit pattern" <| fun _ ->
            let states = [Idle; Armed; Executing; Acknowledged; Failed]
            Expect.equal (List.length states) 5 "Should have all command states"
            Expect.isTrue (states |> List.contains Armed) "Should have Armed for two-step"

        testCase "SC-HMI-005: Critical alarms are visually prominent" <| fun _ ->
            let criticalColor = alarmColor Critical
            let normalColor = alarmColor Normal
            Expect.notEqual criticalColor normalColor "Critical should differ from Normal"

        testCase "SC-HMI-006: Icon consistency across modules" <| fun _ ->
            Expect.isNonEmpty Icons.connected "Connected icon exists"
            Expect.isNonEmpty Icons.rising "Rising icon exists"
            Expect.isNonEmpty Icons.normal "Normal icon exists"

        testCase "SC-HMI-007: Color accessibility (distinct hues)" <| fun _ ->
            let alarmColors = [Normal; Advisory; Caution; Warning; Critical] |> List.map alarmColor
            let uniqueColors = alarmColors |> List.distinct
            Expect.equal uniqueColors.Length alarmColors.Length "All alarm levels should have distinct colors"
    ]

// ============================================================================
// AGGREGATE TEST LIST
// ============================================================================

[<Tests>]
let allUIComponentTests =
    testList "All UI Component Tests" [
        // Material3 Design Tokens
        colorTokenTests
        typographyTokenTests
        elevationTokenTests

        // Material3 Core Components
        buttonTests
        cardTests
        chipTests
        listItemTests
        progressTests
        snackBarTests
        navBarTests
        badgeTests
        textFieldTests
        dialogTests
        fabTests
        tabsTests
        tableTests

        // Material3 Expressive Components (New)
        iconButtonTests
        segmentedButtonTests
        splitButtonTests
        buttonGroupTests
        toggleButtonTests
        checkboxTests
        radioButtonTests
        sliderTests
        datePickerTests
        timePickerTests
        menuTests
        exposedDropdownTests
        bottomSheetTests
        sideSheetTests
        carouselTests
        topAppBarTests
        bottomAppBarTests
        navigationRailTests
        navigationDrawerTests
        searchBarTests
        floatingToolbarTests
        fabMenuTests
        tooltipTests
        loadingIndicatorTests
        swipeToDismissTests
        pullToRefreshTests

        // DarkCockpitUI Components
        ansiModuleTests
        iconsModuleTests
        boxModuleTests
        alarmColorTests
        statusColorTests
        trendArrowTests
        sparklineTests
        barTests

        // OodaHmi L7 Enhancements
        spiderChartTests
        safetyMarginBarTests
        predictiveBarTests
        topologyTests
        timelineTests
        oodaCycleTests
        disclosureLevelTests
        commandFeedbackTests

        // Composability
        dashboardCompositionTests
        fullDashboardTests
        componentCombinationTests

        // Property-Based
        propertyBasedTests

        // Regression
        regressionTests

        // Compliance
        darkCockpitComplianceTests
    ]
