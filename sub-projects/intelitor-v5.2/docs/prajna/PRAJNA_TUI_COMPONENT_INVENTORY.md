# PRAJNA TUI Component Inventory
**Version**: 1.0.0 | **Date**: 2025-12-27 | **Status**: ACTIVE
**Total Components**: 312 | **Fully Declarative, Composable, Functional**

## Design Principles

All components follow these core principles:

1. **Declarative**: Components are pure descriptions of UI state
2. **Composable**: Components combine via composition operators (`<|>`, `<+>`, `>>>`)
3. **Functional**: No side effects; state changes via messages
4. **Type-Safe**: Strongly typed with F#/Elixir type systems
5. **Accessible**: ARIA-compatible, keyboard navigable
6. **Themeable**: Material 3 design tokens, dark/light modes
7. **Responsive**: Adaptive to terminal dimensions

---

## Part I: Primitive Components (50)

### 1.1 Text Primitives (15)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 1 | `Text` | `string -> Props -> Element` | Plain text with styling |
| 2 | `Label` | `string -> Element` | Semantic label text |
| 3 | `Heading` | `Level -> string -> Element` | H1-H6 heading levels |
| 4 | `Paragraph` | `string -> Element` | Block paragraph text |
| 5 | `Code` | `string -> Language -> Element` | Syntax-highlighted code |
| 6 | `Pre` | `string -> Element` | Preformatted text |
| 7 | `Quote` | `string -> Element` | Blockquote text |
| 8 | `Link` | `string -> Url -> Element` | Hyperlink text |
| 9 | `Bold` | `string -> Element` | Bold emphasis |
| 10 | `Italic` | `string -> Element` | Italic emphasis |
| 11 | `Underline` | `string -> Element` | Underlined text |
| 12 | `Strikethrough` | `string -> Element` | Struck-through text |
| 13 | `Subscript` | `string -> Element` | Subscript text |
| 14 | `Superscript` | `string -> Element` | Superscript text |
| 15 | `Truncate` | `int -> string -> Element` | Truncated with ellipsis |

### 1.2 Box Primitives (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 16 | `Box` | `Props -> Element list -> Element` | Basic container |
| 17 | `HBox` | `Element list -> Element` | Horizontal layout |
| 18 | `VBox` | `Element list -> Element` | Vertical layout |
| 19 | `ZBox` | `Element list -> Element` | Z-index stacking |
| 20 | `Spacer` | `int -> Element` | Fixed-size spacer |
| 21 | `Flex` | `int -> Element` | Flexible spacer |
| 22 | `Divider` | `Orientation -> Element` | Line divider |
| 23 | `Border` | `BorderStyle -> Element -> Element` | Border wrapper |
| 24 | `Shadow` | `ShadowStyle -> Element -> Element` | Shadow effect |
| 25 | `Padding` | `int -> Element -> Element` | Padding wrapper |

### 1.3 Shape Primitives (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 26 | `Line` | `Point -> Point -> Element` | Line segment |
| 27 | `Rect` | `int -> int -> Element` | Rectangle |
| 28 | `RoundedRect` | `int -> int -> int -> Element` | Rounded rectangle |
| 29 | `Circle` | `int -> Element` | Circle (radius) |
| 30 | `Ellipse` | `int -> int -> Element` | Ellipse (rx, ry) |
| 31 | `Triangle` | `Point -> Point -> Point -> Element` | Triangle |
| 32 | `Polygon` | `Point list -> Element` | Polygon |
| 33 | `Arc` | `int -> float -> float -> Element` | Arc segment |
| 34 | `BezierCurve` | `Point list -> Element` | Bezier curve |
| 35 | `Canvas` | `int -> int -> DrawCmd list -> Element` | Drawing canvas |

### 1.4 Icon Primitives (15)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 36 | `Icon` | `IconName -> Element` | Named icon |
| 37 | `StatusDot` | `Status -> Element` | ● ◐ ○ indicators |
| 38 | `TrendArrow` | `Trend -> Element` | ↑↑ ↑ → ↓ ↓↓ arrows |
| 39 | `AlarmIcon` | `Severity -> Element` | · ℹ ⚠ ⛔ ☢ icons |
| 40 | `CheckIcon` | `bool -> Element` | ✓ ✗ check marks |
| 41 | `SpinnerIcon` | `unit -> Element` | Rotating spinner |
| 42 | `ProgressIcon` | `float -> Element` | Progress indicator |
| 43 | `BatteryIcon` | `float -> Element` | Battery level |
| 44 | `SignalIcon` | `int -> Element` | Signal strength |
| 45 | `LockIcon` | `bool -> Element` | Lock/unlock |
| 46 | `UserIcon` | `unit -> Element` | User avatar |
| 47 | `FolderIcon` | `bool -> Element` | Folder open/closed |
| 48 | `FileIcon` | `FileType -> Element` | File type icon |
| 49 | `ChartIcon` | `ChartType -> Element` | Chart type icon |
| 50 | `CustomIcon` | `char list list -> Element` | Custom ASCII art |

---

## Part II: Input Components (35)

### 2.1 Text Inputs (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 51 | `TextInput` | `string -> (string -> Msg) -> Element` | Single-line input |
| 52 | `TextArea` | `string -> (string -> Msg) -> Element` | Multi-line input |
| 53 | `PasswordInput` | `string -> (string -> Msg) -> Element` | Masked input |
| 54 | `SearchInput` | `string -> (string -> Msg) -> Element` | Search with icon |
| 55 | `NumberInput` | `float -> (float -> Msg) -> Element` | Numeric input |
| 56 | `IntegerInput` | `int -> (int -> Msg) -> Element` | Integer input |
| 57 | `EmailInput` | `string -> (string -> Msg) -> Element` | Email validation |
| 58 | `UrlInput` | `string -> (string -> Msg) -> Element` | URL validation |
| 59 | `CodeInput` | `string -> Language -> (string -> Msg) -> Element` | Code editor |
| 60 | `CommandInput` | `string -> (string -> Msg) -> Element` | Command-line style |

### 2.2 Selection Inputs (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 61 | `Checkbox` | `bool -> (bool -> Msg) -> Element` | Boolean toggle |
| 62 | `Radio` | `'a -> 'a list -> ('a -> Msg) -> Element` | Single selection |
| 63 | `RadioGroup` | `'a -> 'a list -> ('a -> Msg) -> Element` | Grouped radios |
| 64 | `Select` | `'a -> 'a list -> ('a -> Msg) -> Element` | Dropdown select |
| 65 | `MultiSelect` | `'a list -> 'a list -> ('a list -> Msg) -> Element` | Multiple selection |
| 66 | `Combobox` | `string -> string list -> (string -> Msg) -> Element` | Editable dropdown |
| 67 | `Autocomplete` | `string -> (string -> string list Async) -> (string -> Msg) -> Element` | Async suggestions |
| 68 | `TagInput` | `string list -> (string list -> Msg) -> Element` | Tag entry |
| 69 | `Toggle` | `bool -> (bool -> Msg) -> Element` | Switch toggle |
| 70 | `SegmentedControl` | `'a -> 'a list -> ('a -> Msg) -> Element` | Button group selection |

### 2.3 Range Inputs (8)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 71 | `Slider` | `float -> Range -> (float -> Msg) -> Element` | Value slider |
| 72 | `RangeSlider` | `float * float -> Range -> ((float * float) -> Msg) -> Element` | Range selection |
| 73 | `Stepper` | `int -> int -> int -> (int -> Msg) -> Element` | Step increment |
| 74 | `Rating` | `int -> int -> (int -> Msg) -> Element` | Star rating |
| 75 | `DatePicker` | `DateTime -> (DateTime -> Msg) -> Element` | Date selection |
| 76 | `TimePicker` | `TimeSpan -> (TimeSpan -> Msg) -> Element` | Time selection |
| 77 | `DateTimePicker` | `DateTime -> (DateTime -> Msg) -> Element` | Combined picker |
| 78 | `ColorPicker` | `Color -> (Color -> Msg) -> Element` | Color selection |

### 2.4 Action Inputs (7)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 79 | `Button` | `string -> Msg -> Element` | Clickable button |
| 80 | `IconButton` | `IconName -> Msg -> Element` | Icon-only button |
| 81 | `FAB` | `IconName -> Msg -> Element` | Floating action button |
| 82 | `SplitButton` | `string -> Msg -> MenuItems -> Element` | Button with dropdown |
| 83 | `ToggleButton` | `bool -> string -> (bool -> Msg) -> Element` | Toggleable button |
| 84 | `ButtonGroup` | `ButtonDef list -> Element` | Grouped buttons |
| 85 | `LinkButton` | `string -> Msg -> Element` | Text link button |

---

## Part III: Layout Components (35)

### 3.1 Container Layouts (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 86 | `Stack` | `Direction -> Gap -> Element list -> Element` | Stacked layout |
| 87 | `Grid` | `int -> int -> Element list -> Element` | Grid layout |
| 88 | `FlexBox` | `FlexProps -> Element list -> Element` | Flexbox layout |
| 89 | `Center` | `Element -> Element` | Centered content |
| 90 | `Wrap` | `Gap -> Element list -> Element` | Wrapping flow |
| 91 | `AspectRatio` | `float -> Element -> Element` | Fixed aspect ratio |
| 92 | `Container` | `MaxWidth -> Element -> Element` | Max-width container |
| 93 | `Absolute` | `Position -> Element -> Element` | Absolute positioning |
| 94 | `Relative` | `Element -> Element` | Relative container |
| 95 | `Fixed` | `Position -> Element -> Element` | Fixed positioning |

### 3.2 Split Layouts (8)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 96 | `Split` | `Orientation -> Ratio -> Element -> Element -> Element` | Two-pane split |
| 97 | `ResizableSplit` | `Orientation -> float -> Element -> Element -> Element` | Draggable split |
| 98 | `CollapsibleSplit` | `Orientation -> Element -> Element -> Element` | Collapsible pane |
| 99 | `MasterDetail` | `Element -> Element -> Element` | Master-detail pattern |
| 100 | `Sidebar` | `Side -> int -> Element -> Element -> Element` | Sidebar layout |
| 101 | `Drawer` | `Side -> Element -> Element` | Slide-out drawer |
| 102 | `Panel` | `string -> Element -> Element` | Titled panel |
| 103 | `CollapsiblePanel` | `string -> bool -> Element -> Element` | Collapsible panel |

### 3.3 Scroll Layouts (7)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 104 | `ScrollView` | `ScrollProps -> Element -> Element` | Scrollable container |
| 105 | `HScroll` | `Element -> Element` | Horizontal scroll |
| 106 | `VScroll` | `Element -> Element` | Vertical scroll |
| 107 | `InfiniteScroll` | `(int -> 'a list Async) -> ('a -> Element) -> Element` | Infinite loading |
| 108 | `VirtualScroll` | `'a list -> ('a -> Element) -> Element` | Virtualized list |
| 109 | `Viewport` | `int -> int -> Element -> Element` | Fixed viewport |
| 110 | `Anchor` | `string -> Element -> Element` | Scroll anchor |

### 3.4 Responsive Layouts (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 111 | `Responsive` | `(Size -> Element) -> Element` | Size-aware layout |
| 112 | `MediaQuery` | `Query -> Element -> Element -> Element` | Conditional render |
| 113 | `Breakpoint` | `Breakpoints -> Element` | Breakpoint-based |
| 114 | `ShowAt` | `Size -> Element -> Element` | Show at size |
| 115 | `HideAt` | `Size -> Element -> Element` | Hide at size |
| 116 | `AdaptiveColumns` | `int -> Element list -> Element` | Auto column count |
| 117 | `MasonryGrid` | `int -> Element list -> Element` | Masonry layout |
| 118 | `WaterfallGrid` | `int -> Element list -> Element` | Waterfall layout |
| 119 | `AutoGrid` | `int -> int -> Element list -> Element` | Auto-fit grid |
| 120 | `DynamicLayout` | `LayoutRule list -> Element list -> Element` | Rule-based layout |

---

## Part IV: Data Display Components (55)

### 4.1 Tables (12)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 121 | `Table` | `Column list -> Row list -> Element` | Basic table |
| 122 | `DataTable` | `'a list -> Column<'a> list -> Element` | Typed data table |
| 123 | `SortableTable` | `'a list -> SortableColumn<'a> list -> Element` | Sortable columns |
| 124 | `FilterableTable` | `'a list -> FilterableColumn<'a> list -> Element` | Filterable |
| 125 | `PaginatedTable` | `'a list -> int -> Column<'a> list -> Element` | With pagination |
| 126 | `GroupedTable` | `'a list -> ('a -> 'b) -> Column<'a> list -> Element` | Grouped rows |
| 127 | `TreeTable` | `TreeNode<'a> list -> Column<'a> list -> Element` | Hierarchical |
| 128 | `EditableTable` | `'a list -> EditableColumn<'a> list -> Element` | Inline editing |
| 129 | `ResizableTable` | `'a list -> Column<'a> list -> Element` | Resizable columns |
| 130 | `VirtualTable` | `'a list -> Column<'a> list -> Element` | Virtualized rows |
| 131 | `StickyTable` | `'a list -> Column<'a> list -> Element` | Sticky header |
| 132 | `CompactTable` | `'a list -> Column<'a> list -> Element` | Condensed view |

### 4.2 Lists (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 133 | `List` | `Element list -> Element` | Basic list |
| 134 | `OrderedList` | `Element list -> Element` | Numbered list |
| 135 | `UnorderedList` | `Element list -> Element` | Bulleted list |
| 136 | `DefinitionList` | `(string * string) list -> Element` | Term-definition |
| 137 | `DescriptionList` | `Description list -> Element` | Description items |
| 138 | `ActionList` | `ActionItem list -> Element` | With actions |
| 139 | `NavigationList` | `NavItem list -> Element` | Navigation items |
| 140 | `CheckList` | `CheckItem list -> Element` | Checkable items |
| 141 | `Timeline` | `TimelineEvent list -> Element` | Timeline view |
| 142 | `Feed` | `FeedItem list -> Element` | Activity feed |

### 4.3 Trees (8)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 143 | `Tree` | `TreeNode list -> Element` | Basic tree |
| 144 | `FileTree` | `FileNode list -> Element` | File browser |
| 145 | `MenuTree` | `MenuItem list -> Element` | Menu hierarchy |
| 146 | `SelectableTree` | `TreeNode list -> (NodeId -> Msg) -> Element` | Selectable nodes |
| 147 | `CheckboxTree` | `TreeNode list -> (NodeId list -> Msg) -> Element` | Checkable nodes |
| 148 | `DraggableTree` | `TreeNode list -> (DragEvent -> Msg) -> Element` | Drag-and-drop |
| 149 | `LazyTree` | `(NodeId -> TreeNode list Async) -> Element` | Lazy loading |
| 150 | `SearchableTree` | `TreeNode list -> Element` | With search |

### 4.4 Cards (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 151 | `Card` | `CardProps -> Element -> Element` | Basic card |
| 152 | `MetricCard` | `string -> float -> Trend -> Element` | Smart metric |
| 153 | `StatCard` | `string -> string -> Delta -> Element` | Statistic card |
| 154 | `ProfileCard` | `Profile -> Element` | User profile |
| 155 | `MediaCard` | `Media -> Element -> Element` | With media |
| 156 | `ActionCard` | `Element -> Action list -> Element` | With actions |
| 157 | `ExpandableCard` | `Element -> Element -> Element` | Expandable content |
| 158 | `SelectableCard` | `bool -> Element -> (bool -> Msg) -> Element` | Selectable |
| 159 | `DraggableCard` | `Element -> Element` | Draggable |
| 160 | `KanbanCard` | `KanbanItem -> Element` | Kanban item |

### 4.5 Charts & Visualizations (15)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 161 | `Sparkline` | `float list -> Element` | Mini line chart |
| 162 | `BarChart` | `BarData list -> Element` | Vertical bars |
| 163 | `HBarChart` | `BarData list -> Element` | Horizontal bars |
| 164 | `LineChart` | `Series list -> Element` | Line chart |
| 165 | `AreaChart` | `Series list -> Element` | Area chart |
| 166 | `PieChart` | `Slice list -> Element` | Pie chart |
| 167 | `DonutChart` | `Slice list -> Element` | Donut chart |
| 168 | `GaugeChart` | `float -> Range -> Element` | Gauge meter |
| 169 | `HeatMap` | `Cell list list -> Element` | Heat map grid |
| 170 | `TreeMap` | `TreeMapNode list -> Element` | Tree map |
| 171 | `Sankey` | `SankeyData -> Element` | Sankey diagram |
| 172 | `NetworkGraph` | `Node list -> Edge list -> Element` | Network visualization |
| 173 | `FlameGraph` | `FlameNode -> Element` | Flame chart |
| 174 | `Histogram` | `float list -> int -> Element` | Histogram |
| 175 | `ScatterPlot` | `Point list -> Element` | Scatter plot |

---

## Part V: Feedback Components (30)

### 5.1 Status Indicators (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 176 | `Badge` | `string -> Variant -> Element` | Status badge |
| 177 | `Chip` | `string -> Element` | Compact chip |
| 178 | `Tag` | `string -> Color -> Element` | Colored tag |
| 179 | `Status` | `StatusType -> string -> Element` | Status indicator |
| 180 | `HealthBar` | `float -> Element` | Health percentage |
| 181 | `ProgressBar` | `float -> Element` | Progress percentage |
| 182 | `BufferBar` | `float -> float -> Element` | With buffer |
| 183 | `Meter` | `float -> Range -> Element` | Value meter |
| 184 | `Throbber` | `unit -> Element` | Activity indicator |
| 185 | `Skeleton` | `SkeletonType -> Element` | Loading skeleton |

### 5.2 Alerts & Notifications (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 186 | `Alert` | `Severity -> string -> Element` | Alert banner |
| 187 | `Toast` | `Severity -> string -> Element` | Toast notification |
| 188 | `Snackbar` | `string -> Action option -> Element` | Snackbar message |
| 189 | `Banner` | `string -> Element` | Full-width banner |
| 190 | `Callout` | `Severity -> string -> Element` | Callout box |
| 191 | `InlineMessage` | `Severity -> string -> Element` | Inline message |
| 192 | `Notification` | `NotificationData -> Element` | Rich notification |
| 193 | `SystemAlert` | `string -> Element` | System-level alert |
| 194 | `AlarmCard` | `Alarm -> Element` | Alarm display |
| 195 | `AlarmBanner` | `Severity -> string -> Element` | Alarm banner |

### 5.3 Dialogs & Modals (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 196 | `Modal` | `Element -> Element` | Modal dialog |
| 197 | `Dialog` | `DialogProps -> Element -> Element` | Dialog wrapper |
| 198 | `ConfirmDialog` | `string -> Msg -> Msg -> Element` | Confirmation |
| 199 | `AlertDialog` | `Severity -> string -> Element` | Alert dialog |
| 200 | `InputDialog` | `string -> (string -> Msg) -> Element` | Input prompt |
| 201 | `FullScreenDialog` | `Element -> Element` | Full-screen modal |
| 202 | `BottomSheet` | `Element -> Element` | Bottom slide-up |
| 203 | `Popover` | `Element -> Element -> Element` | Popover content |
| 204 | `Tooltip` | `string -> Element -> Element` | Hover tooltip |
| 205 | `Lightbox` | `Media list -> Element` | Media lightbox |

---

## Part VI: Navigation Components (30)

### 6.1 Menus (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 206 | `Menu` | `MenuItem list -> Element` | Basic menu |
| 207 | `ContextMenu` | `MenuItem list -> Element -> Element` | Right-click menu |
| 208 | `DropdownMenu` | `string -> MenuItem list -> Element` | Dropdown menu |
| 209 | `ActionMenu` | `IconName -> MenuItem list -> Element` | Action dropdown |
| 210 | `MegaMenu` | `MegaMenuItem list -> Element` | Multi-column menu |
| 211 | `CommandPalette` | `Command list -> Element` | Command palette |
| 212 | `QuickActions` | `Action list -> Element` | Quick action menu |
| 213 | `NestedMenu` | `NestedMenuItem list -> Element` | Nested submenus |
| 214 | `RadioMenu` | `'a -> 'a list -> ('a -> Msg) -> Element` | Radio selection |
| 215 | `CheckMenu` | `'a list -> 'a list -> ('a list -> Msg) -> Element` | Checkbox menu |

### 6.2 Navigation Bars (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 216 | `Navbar` | `NavItem list -> Element` | Top navigation |
| 217 | `TabBar` | `Tab list -> int -> (int -> Msg) -> Element` | Tab navigation |
| 218 | `TabNav` | `TabItem list -> Element` | Tab navigation |
| 219 | `BottomNav` | `NavItem list -> Element` | Bottom navigation |
| 220 | `SideNav` | `NavItem list -> Element` | Side navigation |
| 221 | `Breadcrumb` | `BreadcrumbItem list -> Element` | Breadcrumb trail |
| 222 | `StepIndicator` | `Step list -> int -> Element` | Step progress |
| 223 | `Pagination` | `int -> int -> (int -> Msg) -> Element` | Page navigation |
| 224 | `PageSizeSelect` | `int -> int list -> (int -> Msg) -> Element` | Page size |
| 225 | `QuickNav` | `Anchor list -> Element` | Anchor navigation |

### 6.3 Keyboard Navigation (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 226 | `KeyboardShortcut` | `Key list -> Msg -> Element -> Element` | Key binding |
| 227 | `FocusTrap` | `Element -> Element` | Focus containment |
| 228 | `FocusRing` | `Element -> Element` | Visible focus |
| 229 | `TabOrder` | `int -> Element -> Element` | Tab index |
| 230 | `ArrowNav` | `Element list -> Element` | Arrow key nav |
| 231 | `VimNav` | `Element -> Element` | Vim-style nav |
| 232 | `JumpTo` | `string -> Element -> Element` | Jump shortcut |
| 233 | `SearchJump` | `(string -> Element list) -> Element` | Search jump |
| 234 | `HistoryNav` | `Element -> Element` | Back/forward |
| 235 | `HotKey` | `string -> Msg -> Element` | Hotkey display |

---

## Part VII: Container Components (25)

### 7.1 Surface Components (8)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 236 | `Surface` | `Elevation -> Element -> Element` | Elevated surface |
| 237 | `Paper` | `Element -> Element` | Paper surface |
| 238 | `Glass` | `Element -> Element` | Glassmorphism |
| 239 | `Gradient` | `Color list -> Element -> Element` | Gradient background |
| 240 | `Pattern` | `PatternType -> Element -> Element` | Pattern fill |
| 241 | `Blur` | `float -> Element -> Element` | Blur effect |
| 242 | `Frosted` | `Element -> Element` | Frosted glass |
| 243 | `Neumorphic` | `Element -> Element` | Neumorphism style |

### 7.2 Overlay Components (7)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 244 | `Overlay` | `float -> Element -> Element` | Overlay backdrop |
| 245 | `Backdrop` | `Msg -> Element -> Element` | Clickable backdrop |
| 246 | `Portal` | `string -> Element -> Element` | Portal to container |
| 247 | `Layer` | `int -> Element -> Element` | Z-layer |
| 248 | `Sticky` | `Position -> Element -> Element` | Sticky position |
| 249 | `Float` | `Position -> Element -> Element` | Floating element |
| 250 | `Affix` | `Offset -> Element -> Element` | Affixed position |

### 7.3 Grouping Components (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 251 | `Group` | `Element list -> Element` | Visual group |
| 252 | `Cluster` | `Gap -> Element list -> Element` | Clustered items |
| 253 | `Fieldset` | `string -> Element -> Element` | Field group |
| 254 | `Section` | `string -> Element -> Element` | Content section |
| 255 | `Article` | `Element -> Element` | Article container |
| 256 | `Aside` | `Element -> Element` | Aside content |
| 257 | `Header` | `Element -> Element` | Header section |
| 258 | `Footer` | `Element -> Element` | Footer section |
| 259 | `Main` | `Element -> Element` | Main content |
| 260 | `Nav` | `Element -> Element` | Navigation section |

---

## Part VIII: Safety-Critical Components (C3I) (35)

### 8.1 Alarm Components (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 261 | `AlarmPanel` | `Alarm list -> Element` | Alarm panel |
| 262 | `AlarmSummary` | `AlarmStats -> Element` | Alarm statistics |
| 263 | `AlarmTimeline` | `Alarm list -> Element` | Alarm timeline |
| 264 | `AlarmMap` | `GeoAlarm list -> Element` | Geographic alarms |
| 265 | `AlarmFeed` | `Alarm list -> Element` | Live alarm feed |
| 266 | `AlarmDetails` | `Alarm -> Element` | Alarm detail view |
| 267 | `AlarmAckButton` | `AlarmId -> (AlarmId -> Msg) -> Element` | Acknowledge button |
| 268 | `AlarmEscalate` | `AlarmId -> (AlarmId -> Msg) -> Element` | Escalation button |
| 269 | `AlarmSilence` | `AlarmId -> Duration -> (AlarmId -> Msg) -> Element` | Silence button |
| 270 | `AlarmCorrelation` | `Alarm list -> Element` | Correlated alarms |

### 8.2 Command Components (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 271 | `CommandPanel` | `Command list -> Element` | Command center |
| 272 | `TwoStepButton` | `string -> Msg -> Element` | Two-step commit |
| 273 | `ArmButton` | `CommandId -> (CommandId -> Msg) -> Element` | Arm command |
| 274 | `ConfirmButton` | `CommandId -> (CommandId -> Msg) -> Element` | Confirm command |
| 275 | `CancelButton` | `CommandId -> (CommandId -> Msg) -> Element` | Cancel command |
| 276 | `CommandHistory` | `CommandRecord list -> Element` | Command history |
| 277 | `CommandTimer` | `DateTime -> Element` | Countdown timer |
| 278 | `CommandStatus` | `CommandStatus -> Element` | Status display |
| 279 | `EmergencyStop` | `Msg -> Element` | E-Stop button |
| 280 | `LockoutControl` | `bool -> (bool -> Msg) -> Element` | Lockout toggle |

### 8.3 Mesh & Node Components (8)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 281 | `MeshTopology` | `Node list -> Edge list -> Element` | Mesh visualization |
| 282 | `NodeCard` | `MeshNode -> Element` | Node status card |
| 283 | `NodeGrid` | `MeshNode list -> Element` | Node grid view |
| 284 | `NodeDetail` | `MeshNode -> Element` | Node detail view |
| 285 | `NodeMetrics` | `NodeId -> Metrics -> Element` | Node metrics |
| 286 | `NodeActions` | `NodeId -> Action list -> Element` | Node controls |
| 287 | `ClusterStatus` | `Cluster -> Element` | Cluster health |
| 288 | `QuorumIndicator` | `int -> int -> Element` | Quorum display |

### 8.4 AI Copilot Components (7)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 289 | `CopilotPanel` | `Insight list -> Element` | Copilot insights |
| 290 | `InsightCard` | `Insight -> Element` | Insight display |
| 291 | `RecommendationCard` | `Recommendation -> Element` | AI recommendation |
| 292 | `ConfidenceMeter` | `float -> Element` | Confidence display |
| 293 | `CopilotChat` | `Message list -> (string -> Msg) -> Element` | Chat interface |
| 294 | `AnomalyAlert` | `Anomaly -> Element` | Anomaly display |
| 295 | `PredictionCard` | `Prediction -> Element` | Prediction display |

---

## Part IX: Animation & Movement Components (20)

### 9.1 Transitions (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 296 | `FadeIn` | `Duration -> Element -> Element` | Fade in |
| 297 | `FadeOut` | `Duration -> Element -> Element` | Fade out |
| 298 | `SlideIn` | `Direction -> Duration -> Element -> Element` | Slide in |
| 299 | `SlideOut` | `Direction -> Duration -> Element -> Element` | Slide out |
| 300 | `Expand` | `Duration -> Element -> Element` | Expand |
| 301 | `Collapse` | `Duration -> Element -> Element` | Collapse |
| 302 | `CrossFade` | `Element -> Element -> Element` | Cross-fade |
| 303 | `Morph` | `Element -> Element -> Element` | Morph transition |
| 304 | `Flip` | `Axis -> Element -> Element` | Flip animation |
| 305 | `Zoom` | `Direction -> Element -> Element` | Zoom in/out |

### 9.2 Continuous Animations (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 306 | `Pulse` | `Duration -> Element -> Element` | Pulsing effect |
| 307 | `Blink` | `Duration -> Element -> Element` | Blinking effect |
| 308 | `Shake` | `Intensity -> Element -> Element` | Shake animation |
| 309 | `Wave` | `Direction -> Element -> Element` | Wave motion |
| 310 | `Bounce` | `Duration -> Element -> Element` | Bounce effect |
| 311 | `Rotate` | `Duration -> Element -> Element` | Rotation |
| 312 | `Breathe` | `Duration -> Element -> Element` | Breathing effect |
| 313 | `Ripple` | `Position -> Element -> Element` | Ripple effect |
| 314 | `Marquee` | `Direction -> Element -> Element` | Scrolling text |
| 315 | `TypeWriter` | `Duration -> string -> Element` | Typewriter effect |

---

## Part X: Sound Components (12)

### 10.1 Audio Feedback (12)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 316 | `Beep` | `Frequency -> Duration -> Element` | Single beep |
| 317 | `MultiBeep` | `Frequency list -> Duration -> Element` | Multiple beeps |
| 318 | `Click` | `unit -> Element` | Click sound |
| 319 | `Success` | `unit -> Element` | Success chime |
| 320 | `Failure` | `unit -> Element` | Failure tone |
| 321 | `Warning` | `unit -> Element` | Warning tone |
| 322 | `Critical` | `unit -> Element` | Critical alarm |
| 323 | `Notification` | `NotificationType -> Element` | Notification sound |
| 324 | `Heartbeat` | `Duration -> Element` | Heartbeat pulse |
| 325 | `SoundOnChange` | `'a -> (unit -> unit) -> Element` | Sound on change |
| 326 | `SpatialSound` | `Position -> Sound -> Element` | Spatial audio |
| 327 | `AmbientSound` | `SoundType -> Element` | Ambient background |

---

## Part XI: Observability Components (15)

### 11.1 Metrics & Telemetry (8)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 328 | `MetricsDashboard` | `Metric list -> Element` | Metrics overview |
| 329 | `TelemetryStream` | `TelemetryData -> Element` | Live telemetry |
| 330 | `TraceViewer` | `Trace -> Element` | Trace visualization |
| 331 | `SpanTimeline` | `Span list -> Element` | Span timeline |
| 332 | `LogViewer` | `LogEntry list -> Element` | Log viewer |
| 333 | `LogStream` | `LogStream -> Element` | Live log stream |
| 334 | `AuditTrail` | `AuditEntry list -> Element` | Audit log |
| 335 | `HealthDashboard` | `HealthData -> Element` | Health overview |

### 11.2 Debug & Development (7)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 336 | `StateInspector` | `'a -> Element` | State debugger |
| 337 | `MessageLog` | `Msg list -> Element` | Message history |
| 338 | `PerformancePanel` | `PerfData -> Element` | Perf metrics |
| 339 | `ComponentTree` | `Element -> Element` | Component hierarchy |
| 340 | `PropsInspector` | `Props -> Element` | Props debugger |
| 341 | `RenderCount` | `Element -> Element` | Render counter |
| 342 | `FrameRate` | `unit -> Element` | FPS display |

---

## Part XII: Composite Components (20)

### 12.1 Dashboard Composites (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 343 | `ExecutiveDashboard` | `DashboardData -> Element` | Executive view |
| 344 | `OperationalDashboard` | `OpsData -> Element` | Operations view |
| 345 | `SecurityDashboard` | `SecurityData -> Element` | Security overview |
| 346 | `AnalyticsDashboard` | `AnalyticsData -> Element` | Analytics view |
| 347 | `ComplianceDashboard` | `ComplianceData -> Element` | Compliance view |
| 348 | `SystemDashboard` | `SystemData -> Element` | System health |
| 349 | `IncidentDashboard` | `IncidentData -> Element` | Incident view |
| 350 | `ResourceDashboard` | `ResourceData -> Element` | Resource overview |
| 351 | `KPIDashboard` | `KPIData -> Element` | KPI tracking |
| 352 | `RealtimeDashboard` | `StreamData -> Element` | Real-time view |

### 12.2 Screen Composites (10)

| # | Component | Type Signature | Description |
|---|-----------|----------------|-------------|
| 353 | `StartupScreen` | `StartupState -> Element` | Startup sequence |
| 354 | `ShutdownScreen` | `ShutdownState -> Element` | Shutdown sequence |
| 355 | `LoginScreen` | `LoginProps -> Element` | Authentication |
| 356 | `ErrorScreen` | `Error -> Element` | Error display |
| 357 | `LoadingScreen` | `string -> Element` | Loading state |
| 358 | `EmptyScreen` | `string -> Element` | Empty state |
| 359 | `MaintenanceScreen` | `MaintenanceInfo -> Element` | Maintenance mode |
| 360 | `OnboardingScreen` | `Step list -> Element` | Onboarding flow |
| 361 | `SettingsScreen` | `Settings -> Element` | Settings panel |
| 362 | `HelpScreen` | `HelpContent -> Element` | Help documentation |

---

## Component Composition Operators

```fsharp
/// Horizontal composition
let (<|>) (a: Element) (b: Element) : Element = HBox [a; b]

/// Vertical composition
let (<->) (a: Element) (b: Element) : Element = VBox [a; b]

/// Z-layer composition
let (<^>) (a: Element) (b: Element) : Element = ZBox [a; b]

/// Wrapper composition
let (>>>) (wrapper: Element -> Element) (inner: Element) : Element = wrapper inner

/// Conditional composition
let when' (cond: bool) (elem: Element) : Element = if cond then elem else Empty

/// Optional composition
let maybe (opt: Element option) : Element = Option.defaultValue Empty opt

/// Map composition
let map (f: 'a -> Element) (items: 'a list) : Element list = List.map f items

/// Filter composition
let filter (pred: 'a -> bool) (f: 'a -> Element) (items: 'a list) : Element list =
    items |> List.filter pred |> List.map f
```

---

## Usage Examples

### Example 1: Simple Alert Card
```fsharp
let alertCard severity message =
    Card { elevation = 2; padding = 8 }
        [
            HBox [
                AlarmIcon severity
                Spacer 8
                VBox [
                    Heading H3 (severityToString severity)
                    Paragraph message
                ]
            ]
            HBox [
                Button "Acknowledge" AckMsg
                Button "Dismiss" DismissMsg
            ]
        ]
```

### Example 2: Metric Dashboard
```fsharp
let metricDashboard metrics =
    Grid 3 2 [
        for metric in metrics do
            MetricCard metric.name metric.value metric.trend
    ]
    |> Panel "System Metrics"
```

### Example 3: Command Center
```fsharp
let commandCenter state =
    VBox [
        Heading H2 "Command Center"
        match state.armedCommand with
        | Some cmd ->
            Card { elevation = 3 } [
                TwoStepButton cmd.name (ConfirmCmd cmd.id)
                CommandTimer cmd.expiresAt
            ] |> Pulse 1000<ms>
        | None ->
            Text "No armed commands"

        CommandHistory state.history
    ]
```

### Example 4: Responsive Layout
```fsharp
let responsiveLayout content =
    Responsive (fun size ->
        match size with
        | Small ->
            VBox content
        | Medium ->
            Grid 2 1 content
        | Large ->
            Grid 3 1 content
    )
```

---

## STAMP Compliance Matrix

| Constraint | Components | Coverage |
|------------|------------|----------|
| SC-HMI-001 | AlarmPanel, AlarmCard | Dark Cockpit |
| SC-HMI-002 | TwoStepButton, ArmButton | Two-Step Commit |
| SC-HMI-003 | MetricCard, Sparkline | Analog Display |
| SC-HMI-004 | StatusDot, HealthBar | Staleness Decay |
| SC-HMI-005 | EmergencyStop | E-Stop <1s |
| SC-HMI-006 | Modal, ConfirmDialog | Confirmation |
| SC-HMI-007 | AuditTrail, CommandHistory | Audit Logging |
| SC-HMI-008 | Beep, Warning, Critical | Sound Alerts |
| SC-HMI-009 | Pulse, Blink, Shake | Movement |
| SC-HMI-010 | Responsive, AdaptiveLayout | Screen Space |
| SC-HMI-011 | ColorIntelligence | Color Modes |

---

## Total Component Count: 362

| Category | Count |
|----------|-------|
| Primitives | 50 |
| Inputs | 35 |
| Layouts | 35 |
| Data Display | 55 |
| Feedback | 30 |
| Navigation | 30 |
| Containers | 25 |
| Safety-Critical | 35 |
| Animation | 20 |
| Sound | 12 |
| Observability | 15 |
| Composites | 20 |
| **Total** | **362** |

---

## Appendix A: Type Definitions

```fsharp
// Core Types
type Element =
    | Empty
    | Text of string * Props
    | Box of Props * Element list
    | Custom of (RenderContext -> string)

type Props = {
    id: string option
    className: string option
    style: Style option
    events: EventHandler list
}

type Style = {
    fg: Color option
    bg: Color option
    bold: bool
    italic: bool
    underline: bool
    padding: int option
    margin: int option
}

// Status Types
type Status = Healthy | Degraded | Offline | Unknown
type Severity = Normal | Advisory | Caution | Warning | Critical
type Trend = RisingFast | Rising | Stable | Falling | FallingFast

// Layout Types
type Direction = Horizontal | Vertical
type Side = Left | Right | Top | Bottom
type Orientation = Row | Column
type Position = { x: int; y: int }
type Size = Small | Medium | Large | ExtraLarge

// Data Types
type Alarm = { id: string; severity: Severity; message: string; timestamp: DateTime }
type MeshNode = { id: string; status: Status; cpu: float; memory: float }
type Metric = { name: string; value: float; trend: Trend; unit: string }
type Insight = { type': InsightType; message: string; confidence: float }
```

---

*Document generated by PRAJNA C3I Mesh Cockpit*
*STAMP Compliance: SC-HMI-001 through SC-HMI-011*
*Framework: SOPv5.11 + Material 3 + Functional Composition*
