# Z-KMS Elmish Client

## Overview

This is the Elmish.Land SPA (Single Page Application) client for the Zettelkasten Knowledge Management System. It provides an interactive web interface for visualizing and exploring knowledge graphs.

## Project Structure

```
Cepaf.Smriti.Client/
├── Cepaf.Smriti.Client.fsproj    # F# project file (net10.0)
├── package.json                  # npm dependencies
├── vite.config.js               # Vite bundler config
├── index.html                   # HTML entry point
│
├── src/
│   ├── Model.fs                 # Application state model
│   ├── Msg.fs                   # MVU message types
│   ├── Router.fs                # Type-safe routing
│   ├── Api.fs                   # HTTP client for backend
│   ├── App.fs                   # Main MVU update/view logic
│   └── Main.fs                  # Application entry point
│
├── Components/
│   ├── EntropyBadge.fs         # Entropy visualization component
│   ├── ZettelView.fs           # Zettel detail view
│   ├── GraphView.fs            # Cytoscape graph visualization
│   └── SearchBar.fs            # Live search component
│
└── Bindings/
    └── Cytoscape.fs            # JS interop for Cytoscape.js
```

## Architecture

### MVU (Model-View-Update) Pattern

The application follows the Elmish MVU architecture:

```
Model (State)
    ↓
View (UI Rendering)
    ↓
User Interaction
    ↓
Message Dispatch
    ↓
Update (State Transition)
    ↓
(repeat)
```

### Key Components

#### 1. Model (`src/Model.fs`)
- **Global State**: `Model` type contains all application state
- **Domain Types**: Zettel, GraphNode, GraphLink, SearchResult
- **Loading States**: `LoadingState<'T>` for async operations
- **Entropy Levels**: Fresh, Recent, Aging, Stale, Rotting

#### 2. Messages (`src/Msg.fs`)
All state transitions are driven by type-safe messages:
- Navigation: `NavigateTo`, `UrlChanged`
- Graph: `LoadGraph`, `GraphLoaded`, `ChangeLayout`
- Zettel: `SelectZettel`, `ZettelLoaded`
- Search: `PerformSearch`, `SearchCompleted`

#### 3. Router (`src/Router.fs`)
Type-safe URL routing with Feliz.Router:
- `/` - Home
- `/graph` - Graph Explorer
- `/z/{id}` - Zettel View
- `/cluster/{name}` - Cluster View
- `/search?q={query}` - Search Results

#### 4. API Client (`src/Api.fs`)
HTTP client for backend communication:
- `getZettels()` - Fetch all zettels
- `getZettel(id)` - Fetch single zettel
- `getGraphData()` - Fetch graph visualization data
- `search(query)` - Full-text search
- `getBacklinks(id)` - Fetch backlinks

## Build & Run

### Prerequisites
- .NET 10.0 SDK
- Node.js 22+
- npm/yarn

### Development

```bash
# 1. Install npm dependencies
npm install

# 2. Start development server (Fable watch + Vite)
npm start
```

This will:
- Compile F# to JavaScript using Fable
- Start Vite dev server on port 3001
- Enable hot module replacement (HMR)
- Proxy API requests to http://localhost:5000

### Build for Production

```bash
# Compile F# and bundle with Vite
npm run build
```

Output will be in `dist/` directory.

### Preview Production Build

```bash
npm run preview
```

## Integration with Backend

The client expects a Giraffe API server running on `http://localhost:5000` with these endpoints:

| Endpoint | Description |
|----------|-------------|
| GET `/api/zettels` | List all zettels (paginated) |
| GET `/api/zettels/{id}` | Get single zettel |
| GET `/api/zettels/{id}/backlinks` | Get backlinks |
| GET `/api/graph` | Full graph data for Cytoscape |
| GET `/api/graph/cluster/{name}` | Cluster subgraph |
| GET `/api/search?q={query}` | Full-text search |
| GET `/api/clusters` | List all clusters |
| GET `/api/metrics/entropy` | Top rotting zettels |

## Graph Visualization

The `GraphView` component uses **Cytoscape.js** for interactive graph visualization:

- **Layouts**: COSE (force-directed), Concentric, Circle, Grid
- **Node Colors**: Based on entropy (green → yellow → red)
- **Edge Weights**: Line thickness based on link weight
- **Interactions**: Click nodes to navigate, hover for tooltips

## Entropy Visualization

Zettels are color-coded by entropy (knowledge decay):

| Entropy | Color | Label | Meaning |
|---------|-------|-------|---------|
| 0.0-0.2 | 🌱 Green | Fresh | Recently created/updated |
| 0.2-0.4 | 🌿 Lime | Recent | Still relevant |
| 0.4-0.6 | 🍂 Yellow | Aging | Needs review soon |
| 0.6-0.8 | 🥀 Orange | Stale | Requires attention |
| 0.8-1.0 | 💀 Red | Rotting | Urgent maintenance |

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-KMS-001 | Read-only access to backend data | CRITICAL |
| SC-KMS-003 | Entropy calculation matches backend | HIGH |
| SC-KMS-005 | Cytoscape.js graph visualization | CRITICAL |
| SC-KMS-007 | Type-safe routing (Elmish.Land) | HIGH |
| SC-NET-001 | Target framework = net10.0 | CRITICAL |
| SC-FUNC-001 | Code MUST compile with 0 errors | CRITICAL |

## Verification

```bash
# Verify F# compilation
dotnet build

# Expected output:
# Build succeeded.
#     0 Warning(s)
#     0 Error(s)
```

## Next Steps

1. **Connect to Backend**: Ensure `Cepaf.Smriti.Api` server is running
2. **Test Graph Rendering**: Verify Cytoscape.js loads and displays nodes
3. **Search Functionality**: Test full-text search
4. **Mobile Responsiveness**: Test on different screen sizes
5. **Accessibility**: Add ARIA labels and keyboard navigation

## Related Documents

- Implementation Plan: `/home/an/.claude/plans/dreamy-nibbling-mountain.md`
- Backend API: `../Cepaf.Smriti.Api/README.md`
- Shared Types: `../Cepaf.Smriti.Shared/Types.fs`

## Change History

| Version | Date | Author | Change |
|---------|------|--------|--------|
| 1.0.0 | 2026-01-11 | Claude Opus 4.5 | Initial Elmish.Land SPA implementation |

## STAMP Compliance

- SC-NET-001: ✅ net10.0 target framework verified
- SC-FUNC-001: ✅ 0 errors, 0 warnings on build
- SC-KMS-007: ✅ Type-safe routing with Feliz.Router
- SC-KMS-005: ✅ Cytoscape.js bindings implemented
