# BACKSTAGE UI/UX REPLICATION: MASTER FEATURE LIST & MAPPING
**Version**: 5.0.0 (Pixel-Perfect)
**Target**: `Cepaf.Cockpit` (Avalonia XAML + F#)
**Compliance**: SIL-6 Biomorphic Mesh
**Scope**: Full visual and functional replication of Backstage.io

---

## 1.0 UI/UX FEATURE DECOMPOSITION (7 LEVELS)

This matrix decomposes the Backstage React frontend into replicable F# Avalonia components.

### 1.1 The App Shell (Global Layout)

| L1: Screen | L2: Region | L3: Widget | L4: Control | L5: State | L6: Interaction | L7: F# Binding |
|---|---|---|---|---|---|---|
| **AppShell** | **Sidebar** | Navigation Menu | `TreeView` | `SelectedRoute` | Click Navigation | `ShellVM.NavigateTo` |
| | | Search Trigger | `Button` (Icon) | `IsSearchVisible` | Open Modal | `ShellVM.ToggleSearch` |
| | | User Settings | `UserAvatar` | `CurrentUser` | Open Flyout | `ShellVM.ShowSettings` |
| | **Header** | Breadcrumbs | `ItemsControl` | `CurrentPath` | Navigate Up | `ShellVM.GoUp` |
| | | Theme Toggle | `ToggleSwitch` | `CurrentTheme` | Switch Dark/Light | `ThemeManager.Toggle` |
| | **Content** | Page Router | `TransitioningContent` | `CurrentView` | Animation | `Router.CurrentViewModel` |

### 1.2 Catalog Index (The "Home" Screen)

| L1: Screen | L2: Region | L3: Widget | L4: Control | L5: State | L6: Interaction | L7: F# Binding |
|---|---|---|---|---|---|---|
| **Catalog** | **Filters** | Kind Picker | `ComboBox` | `SelectedKind` | Filter List | `CatalogVM.FilterKind` |
| | | Type Picker | `ComboBox` | `SelectedType` | Filter List | `CatalogVM.FilterType` |
| | | Tag Cloud | `ChipGroup` | `SelectedTags` | Toggle Tag | `CatalogVM.ToggleTag` |
| | | Owner Picker | `AutoCompleteBox` | `OwnerFilter` | Text Input | `CatalogVM.SetOwner` |
| | **Entity Table** | Data Grid | `DataGrid` | `Entities` | Sort/Pagination | `CatalogVM.SortBy` |
| | | Name Column | `Hyperlink` | `Entity.Name` | Navigate Detail | `CatalogVM.OpenEntity` |
| | | System Column | `TextBlock` | `Entity.System` | Filter by System | `CatalogVM.FilterSystem` |
| | | Actions | `PopupMenu` | `ContextMenu` | Edit/Unregister | `CatalogVM.ShowActions` |
| | **Header** | Create Button | `Button` (Primary) | `CanCreate` | Nav to Wizard | `Router.Go("scaffold")` |

### 1.3 Entity Detail (The "Service" View)

| L1: Screen | L2: Region | L3: Widget | L4: Control | L5: State | L6: Interaction | L7: F# Binding |
|---|---|---|---|---|---|---|
| **EntityPage** | **Overview** | Info Card | `Card` | `Entity.Metadata` | Read | `EntityVM.Metadata` |
| | | Relations | `GraphControl` | `Entity.Relations` | Pan/Zoom | `GraphVM.Layout` |
| | | Links | `LinkList` | `Entity.Links` | Open Browser | `Launcher.OpenUrl` |
| | **CI/CD** | Build History | `Table` | `Builds` | Inspect Log | `BuildsVM.ShowLog` |
| | **API** | Swagger View | `WebView` / `TextEditor` | `ApiDefinition` | Scroll | `ApiVM.Spec` |
| | **Docs** | TechDocs Embed | `MarkdownViewer` | `DocsContent` | Scroll/Link | `DocsVM.Content` |
| | **Errors** | Compliance | `AlertBar` | `Errors` | Dismiss | `EntityVM.AckError` |

### 1.4 Scaffolder (The "Create" Wizard)

| L1: Screen | L2: Region | L3: Widget | L4: Control | L5: State | L6: Interaction | L7: F# Binding |
|---|---|---|---|---|---|---|
| **Create** | **TemplateList** | Template Card | `Card` | `Templates` | Select Template | `ScaffoldVM.Select` |
| | **Wizard** | Step Stepper | `StepBar` | `CurrentStep` | Progression | `WizardVM.Next` |
| | | Dynamic Form | `FormBuilder` | `FormData` | Input Valid | `Schema.Validate` |
| | | Review | Summary | `TextBlock` | Final Check | `WizardVM.Review` |
| | **Output** | Log Stream | `ConsoleView` | `TaskLogs` | Auto-scroll | `TaskVM.Logs` |

---

## 2.0 BDD SPECIFICATION STRATEGY

We define **User Journeys** using Gherkin syntax to strictly enforce the "Backstage Experience".

### Journey 1: "The Explorer"
*   **Actor**: Developer
*   **Goal**: Find a service, check its owner, and view its API.
*   **Flow**: Catalog -> Filter -> Detail Page -> API Tab.

### Journey 2: "The Creator"
*   **Actor**: Architect
*   **Goal**: Create a new microservice from a standard template.
*   **Flow**: Create -> Select Template -> Fill Form -> Wait for Job -> View New Service.

### Journey 3: "The Operator"
*   **Actor**: SRE
*   **Goal**: Troubleshoot a failing service.
*   **Flow**: Catalog -> Detail Page -> Runtime/K8s Tab -> View Pod Logs.

---

## 3.0 ARCHITECTURE & IMPLEMENTATION PLAN

We will generate the BDD Feature files and the corresponding F# implementation stubs.

### 3.1 Feature Files (`lib/cepaf/tests/bdd/`)
1.  `catalog_explorer.feature`: Search, Filter, View.
2.  `scaffolder_creator.feature`: Templates, Forms, Execution.
3.  `techdocs_reader.feature`: Documentation rendering.

### 3.2 F# UI Modules (`Cepaf.Cockpit`)
We will create Avalonia-compatible ViewModels that satisfy the BDD steps.

1.  `CatalogSteps.fs`: Glue code between Gherkin and `CatalogViewModel`.
2.  `ScaffolderSteps.fs`: Glue code for the Wizard logic.

---

## 4.0 "5 RUNS" REFINEMENT

1.  **Run 1 (BDD Definition)**: Write the Feature Files (The Contract).
2.  **Run 2 (Step Definitions)**: Implement the F# Test Steps (The Verification).
3.  **Run 3 (UI Logic)**: Implement the ViewModels (The Logic).
4.  **Run 4 (Visuals)**: Define the XAML/Styles (The Look).
5.  **Run 5 (Integration)**: Connect to the KMS Backend (The Data).

Let's begin with **Run 1 & 2**: Creating the Feature Files and Test Steps.
