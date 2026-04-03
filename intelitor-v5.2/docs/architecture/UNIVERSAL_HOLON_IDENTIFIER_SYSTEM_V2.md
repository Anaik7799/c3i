# Universal Holon Identifier (UHI) System v2.0
## Comprehensive Naming System for Holon-Specific Databases
### Version 2.0.0-SIL6 | 2026-01-17

---

## 1.0 Overview

The Universal Holon Identifier (UHI) system provides a hierarchical, scalable naming
convention that uniquely identifies each holon and its associated databases across
the entire Indrajaal biomorphic organism.

### 1.1 Design Goals

1. **Uniqueness**: Every database file has a globally unique identifier
2. **Hierarchy**: 6-level structure enables efficient routing and discovery
3. **Self-Describing**: Identifier encodes runtime, layer, domain, type, and instance
4. **Path-Compatible**: Direct mapping to filesystem paths
5. **Scalable**: Supports 10^6+ holons across federated deployments

---

## 2.0 UHI Format Specification

### 2.1 Canonical Format

```
UHI = {runtime}:{layer}:{domain}:{type}:{instance}

FQDN = {runtime}:{layer}:{domain}:{type}:{instance}:{database}

Path = data/holons/{runtime}/{layer}/{domain}/{type}/{instance}/{database}.{ext}
```

### 2.2 Component Specifications

#### 2.2.1 Runtime Identifier

| Code | Full Name | Description | File Extension |
|------|-----------|-------------|----------------|
| `ex` | Elixir | BEAM/OTP runtime | `.beam` |
| `fs` | F# | .NET CLR runtime | `.dll` |
| `zig` | Zig | Native LLVM runtime | `.so`/`.dll` |
| `rs` | Rust | Native LLVM runtime | `.so`/`.dll` |
| `py` | Python | CPython runtime | `.pyc` |
| `js` | JavaScript | V8/Node runtime | `.js` |
| `go` | Go | Go runtime | `.go` |
| `wasm` | WebAssembly | WASM runtime | `.wasm` |

**Regex**: `^(ex|fs|zig|rs|py|js|go|wasm)$`

#### 2.2.2 Layer Identifier (L0-L9)

| Code | Layer | Fractal Level | Description |
|------|-------|---------------|-------------|
| `l0` | Runtime | 0 | Core execution substrate |
| `l1` | Function | 1 | Individual callable unit |
| `l2` | Component | 2 | Grouped related functions |
| `l3` | Holon | 3 | Autonomous agent boundary |
| `l4` | Container | 4 | Isolated execution environment |
| `l5` | Node | 5 | Physical/virtual machine |
| `l6` | Cluster | 6 | Distributed node group |
| `l7` | Federation | 7 | Multi-cluster coordination |
| `l8` | Cosmic | 8 | Universal imperative |
| `l9` | Quantum | 9 | Quantum substrate interface |

**Regex**: `^l[0-9]$`

#### 2.2.3 Domain Identifier (40+ Domains)

| Code | Domain | Description | STAMP Ref |
|------|--------|-------------|-----------|
| `acc` | Access Control | Permission management | SC-ACC-* |
| `acct` | Accounts | User account management | SC-ACCT-* |
| `alm` | Alarms | Alarm processing | SC-ALM-* |
| `ana` | Analytics | Data analytics | SC-ANA-* |
| `auth` | Authentication | Identity verification | SC-AUTH-* |
| `authz` | Authorization | Permission enforcement | SC-AUTHZ-* |
| `bil` | Billing | Financial transactions | SC-BIL-* |
| `brg` | Bridge | Cross-runtime bridge | SC-BRG-* |
| `clst` | Cluster | Cluster management | SC-CLST-* |
| `cmp` | Compliance | Regulatory compliance | SC-CMP-* |
| `comm` | Communication | Messaging services | SC-COMM-* |
| `coord` | Coordination | Distributed coordination | SC-COORD-* |
| `cor` | Cortex | AI cognitive processing | SC-COR-* |
| `cyb` | Cybernetic | Control systems | SC-CYB-* |
| `dev` | Devices | IoT device management | SC-DEV-* |
| `disp` | Dispatch | Event dispatch | SC-DISP-* |
| `dist` | Distributed | Distributed systems | SC-DIST-* |
| `evo` | Evolution | Test evolution | SC-EVO-* |
| `flm` | Flame | Flame distributed compute | SC-FLM-* |
| `fnd` | Founder | Founder directive | SC-FND-* |
| `grd` | Guardian | Safety validation | SC-GRD-* |
| `id` | Identity | Identity management | SC-ID-* |
| `imm` | Immune | Digital immune system | SC-IMM-* |
| `int` | Integration | External integration | SC-INT-* |
| `kms` | Key Management | Cryptographic keys | SC-KMS-* |
| `know` | Knowledge | Knowledge management | SC-KNOW-* |
| `maint` | Maintenance | System maintenance | SC-MAINT-* |
| `mesh` | Mesh | Service mesh | SC-MESH-* |
| `obs` | Observability | Telemetry & monitoring | SC-OBS-* |
| `pln` | Planning | Task planning | SC-PLN-* |
| `pol` | Policy | Policy enforcement | SC-POL-* |
| `prj` | Prajna | C3I command cockpit | SC-PRJ-* |
| `reg` | Register | Immutable audit trail | SC-REG-* |
| `saf` | Safety | Safety operations | SC-SAF-* |
| `sec` | Security | Security operations | SC-SEC-* |
| `site` | Sites | Site management | SC-SITE-* |
| `snt` | Sentinel | Health monitoring | SC-SNT-* |
| `val` | Validation | Data validation | SC-VAL-* |
| `vid` | Video | Video processing | SC-VID-* |
| `zen` | Zenoh | Zenoh mesh coordination | SC-ZEN-* |

**Regex**: `^[a-z]{2,5}$`

#### 2.2.4 Type Identifier

| Code | Type | Description | Lifecycle |
|------|------|-------------|-----------|
| `srv` | Service | Stateless service holon | Long-running |
| `agt` | Agent | Autonomous agent holon | Long-running |
| `wkr` | Worker | Task execution holon | Ephemeral |
| `crd` | Coordinator | Orchestration holon | Long-running |
| `mon` | Monitor | Observability holon | Long-running |
| `gwy` | Gateway | External interface holon | Long-running |
| `prx` | Proxy | Request routing holon | Long-running |
| `exe` | Executive | High-authority holon | Long-running |
| `sat` | Satellite | Distributed runner | Ephemeral |
| `twin` | DigitalTwin | State mirror holon | Long-running |

**Regex**: `^(srv|agt|wkr|crd|mon|gwy|prx|exe|sat|twin)$`

#### 2.2.5 Instance Identifier

Instance names must be:
- Lowercase alphanumeric with hyphens
- 1-32 characters
- Start with a letter
- End with alphanumeric

**Regex**: `^[a-z][a-z0-9-]{0,30}[a-z0-9]?$`

**Reserved Instances**:
| Name | Purpose |
|------|---------|
| `main` | Primary instance |
| `primary` | Primary in HA pair |
| `secondary` | Secondary in HA pair |
| `backup` | Backup instance |
| `test` | Test instance |
| `dev` | Development instance |
| `staging` | Staging instance |
| `prod` | Production instance |

#### 2.2.6 Database Identifier

| Code | File Extension | Engine | Purpose | Access Pattern |
|------|----------------|--------|---------|----------------|
| `state` | `.sqlite` | SQLite | Real-time mutable state | Read/Write |
| `vectors` | `.sqlite` | SQLite | Embeddings for semantic search | Read/Write |
| `cache` | `.sqlite` | SQLite | Temporary cached data | Read/Write |
| `analytics` | `.duckdb` | DuckDB | OLAP analytical queries | Read-heavy |
| `history` | `.duckdb` | DuckDB | Immutable event log | Append-only |
| `register` | `.duckdb` | DuckDB | Cryptographic audit trail | Append-only |

**Regex**: `^(state|vectors|cache|analytics|history|register)$`

---

## 3.0 Path Resolution

### 3.1 Base Path Configuration

```yaml
# config/holon_paths.yaml
base_path: "data/holons"
backup_path: "data/holons_backup"
archive_path: "data/holons_archive"

# Per-runtime overrides
runtimes:
  ex:
    path_suffix: ""
  fs:
    path_suffix: ""
  zig:
    path_suffix: "_native"
```

### 3.2 Path Resolution Algorithm

```elixir
defmodule Indrajaal.Holon.DatabasePath do
  @base_path "data/holons"

  @doc """
  Resolve FQDN to filesystem path.

  ## Examples

      iex> resolve("ex:l3:kms:srv:main:state")
      "data/holons/ex/l3/kms/srv/main/state.sqlite"

      iex> resolve("fs:l4:prj:agt:cockpit:analytics")
      "data/holons/fs/l4/prj/agt/cockpit/analytics.duckdb"
  """
  def resolve(fqdn) do
    case String.split(fqdn, ":") do
      [runtime, layer, domain, type, instance, db_type] ->
        ext = db_extension(db_type)
        Path.join([
          @base_path,
          runtime,
          layer,
          domain,
          type,
          instance,
          "#{db_type}.#{ext}"
        ])
      _ ->
        {:error, "Invalid FQDN format"}
    end
  end

  defp db_extension("state"), do: "sqlite"
  defp db_extension("vectors"), do: "sqlite"
  defp db_extension("cache"), do: "sqlite"
  defp db_extension("analytics"), do: "duckdb"
  defp db_extension("history"), do: "duckdb"
  defp db_extension("register"), do: "duckdb"
  defp db_extension(_), do: {:error, "Unknown database type"}
end
```

```fsharp
module Cepaf.Holon.DatabasePath

let private basePath = "data/holons"

let private dbExtension = function
    | "state" | "vectors" | "cache" -> "sqlite"
    | "analytics" | "history" | "register" -> "duckdb"
    | t -> failwith $"Unknown database type: {t}"

let resolve (fqdn: string) =
    match fqdn.Split(':') with
    | [| runtime; layer; domain; typ; instance; dbType |] ->
        let ext = dbExtension dbType
        $"{basePath}/{runtime}/{layer}/{domain}/{typ}/{instance}/{dbType}.{ext}"
    | _ ->
        failwith $"Invalid FQDN format: {fqdn}"
```

---

## 4.0 Holon Manifest

Each holon has a manifest file describing its databases and configuration.

### 4.1 Manifest Location

```
data/holons/{runtime}/{layer}/{domain}/{type}/{instance}/manifest.json
```

### 4.2 Manifest Schema

```json
{
  "$schema": "https://indrajaal.ai/schemas/holon-manifest-v2.json",
  "version": "2.0.0",
  "uhi": "ex:l3:kms:srv:main",
  "created_at": "2026-01-17T12:00:00Z",
  "updated_at": "2026-01-17T14:30:00Z",

  "metadata": {
    "name": "Key Management Service - Main",
    "description": "Primary KMS holon for cryptographic key operations",
    "owner": "security-team",
    "tags": ["security", "kms", "critical"],
    "sil_level": 6
  },

  "databases": {
    "state": {
      "engine": "sqlite",
      "path": "state.sqlite",
      "schema_version": "1.2.0",
      "wal_mode": true,
      "max_size_mb": 1024,
      "tables": ["keys", "rotations", "access_log"]
    },
    "analytics": {
      "engine": "duckdb",
      "path": "analytics.duckdb",
      "schema_version": "1.0.0",
      "max_size_mb": 10240,
      "tables": ["key_usage_metrics", "access_patterns"]
    },
    "history": {
      "engine": "duckdb",
      "path": "history.duckdb",
      "schema_version": "1.0.0",
      "append_only": true,
      "max_size_mb": 102400,
      "tables": ["key_events", "audit_trail"]
    },
    "register": {
      "engine": "duckdb",
      "path": "register.duckdb",
      "schema_version": "1.0.0",
      "append_only": true,
      "cryptographic": true,
      "tables": ["blocks", "merkle_proofs"]
    }
  },

  "version_vector": {
    "ex:l3:kms:srv:main": 12345,
    "local": 67890
  },

  "dependencies": [
    "ex:l3:grd:agt:primary",
    "ex:l3:snt:srv:main"
  ],

  "zenoh_topics": {
    "publish": [
      "indrajaal/kms/keys/rotated",
      "indrajaal/kms/access/logged"
    ],
    "subscribe": [
      "indrajaal/grd/approval/*",
      "indrajaal/snt/health/*"
    ]
  },

  "backup": {
    "enabled": true,
    "schedule": "0 */6 * * *",
    "retention_days": 30
  },

  "checksum": {
    "algorithm": "sha256",
    "manifest": "abc123...",
    "databases": {
      "state": "def456...",
      "analytics": "ghi789...",
      "history": "jkl012...",
      "register": "mno345..."
    }
  }
}
```

---

## 5.0 Discovery and Routing

### 5.1 Holon Registry

```elixir
defmodule Indrajaal.Holon.Registry do
  @moduledoc """
  Central registry for holon discovery.
  """

  use GenServer

  @type uhi :: String.t()
  @type holon_info :: %{
    uhi: uhi(),
    runtime: String.t(),
    layer: String.t(),
    domain: String.t(),
    type: String.t(),
    instance: String.t(),
    databases: [String.t()],
    status: :starting | :ready | :degraded | :stopping,
    registered_at: DateTime.t()
  }

  def register(uhi, opts \\ []) do
    GenServer.call(__MODULE__, {:register, uhi, opts})
  end

  def unregister(uhi) do
    GenServer.cast(__MODULE__, {:unregister, uhi})
  end

  def lookup(uhi) do
    GenServer.call(__MODULE__, {:lookup, uhi})
  end

  def find_by_domain(domain) do
    GenServer.call(__MODULE__, {:find_by_domain, domain})
  end

  def find_by_layer(layer) do
    GenServer.call(__MODULE__, {:find_by_layer, layer})
  end

  def find_by_runtime(runtime) do
    GenServer.call(__MODULE__, {:find_by_runtime, runtime})
  end

  def list_all do
    GenServer.call(__MODULE__, :list_all)
  end
end
```

### 5.2 Zenoh Topic Routing

```
Topic Format:
indrajaal/db/{source_runtime}/{source_instance}/request/{target_runtime}/{target_instance}/{db_type}

Examples:
indrajaal/db/ex/main/request/fs/cockpit/state
indrajaal/db/fs/cepaf/request/ex/guard/analytics
indrajaal/db/ex/main/response/abc123def456
```

---

## 6.0 Database Lifecycle

### 6.1 Initialization

```elixir
defmodule Indrajaal.Holon.Database.Lifecycle do
  def initialize(uhi) do
    # 1. Validate UHI format
    :ok = validate_uhi(uhi)

    # 2. Create directory structure
    :ok = ensure_directories(uhi)

    # 3. Initialize each database
    for db_type <- [:state, :vectors, :cache, :analytics, :history, :register] do
      initialize_database(uhi, db_type)
    end

    # 4. Write manifest
    :ok = write_manifest(uhi)

    # 5. Register holon
    :ok = Registry.register(uhi)

    {:ok, uhi}
  end

  def initialize_database(uhi, db_type) do
    path = DatabasePath.resolve("#{uhi}:#{db_type}")
    schema = get_schema(db_type)

    case db_type do
      t when t in [:state, :vectors, :cache] ->
        {:ok, conn} = Exqlite.open(path)
        :ok = apply_schema(conn, schema)
        :ok = Exqlite.execute(conn, "PRAGMA journal_mode=WAL")
        Exqlite.close(conn)

      t when t in [:analytics, :history, :register] ->
        {:ok, conn} = Duckdbex.open(path)
        :ok = apply_schema(conn, schema)
        Duckdbex.close(conn)
    end
  end
end
```

### 6.2 Migration

```elixir
defmodule Indrajaal.Holon.Database.Migrator do
  def migrate(uhi, db_type, target_version) do
    current = get_schema_version(uhi, db_type)

    migrations =
      get_migrations(db_type)
      |> Enum.filter(fn m -> m.version > current and m.version <= target_version end)
      |> Enum.sort_by(& &1.version)

    for migration <- migrations do
      apply_migration(uhi, db_type, migration)
    end

    {:ok, target_version}
  end

  def rollback(uhi, db_type, target_version) do
    current = get_schema_version(uhi, db_type)

    rollbacks =
      get_migrations(db_type)
      |> Enum.filter(fn m -> m.version <= current and m.version > target_version end)
      |> Enum.sort_by(& &1.version, :desc)

    for rollback <- rollbacks do
      apply_rollback(uhi, db_type, rollback)
    end

    {:ok, target_version}
  end
end
```

---

## 7.0 STAMP Constraints (SC-DBNAME-*)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-DBNAME-001 | UHI format MUST follow canonical specification | CRITICAL | Regex validation |
| SC-DBNAME-002 | FQDN MUST include all 6 components | CRITICAL | Parser validation |
| SC-DBNAME-003 | Path resolution MUST be deterministic | HIGH | Property test |
| SC-DBNAME-004 | Database files MUST reside under base path | CRITICAL | Path check |
| SC-DBNAME-005 | Manifest MUST exist for each holon | HIGH | Startup check |
| SC-DBNAME-006 | Manifest MUST include checksum | HIGH | Integrity check |
| SC-DBNAME-007 | Runtime codes MUST be registered | HIGH | Enum check |
| SC-DBNAME-008 | Cross-runtime access MUST use Zenoh topics | CRITICAL | Code review |
| SC-DBNAME-009 | Instance names MUST be unique per domain/type | HIGH | Registry check |
| SC-DBNAME-010 | Database type MUST match engine | CRITICAL | Path validation |
| SC-DBNAME-011 | Schema version MUST be tracked | HIGH | Manifest check |
| SC-DBNAME-012 | Append-only databases MUST NOT allow updates | CRITICAL | Trigger/constraint |
| SC-DBNAME-013 | Backup paths MUST follow naming convention | MEDIUM | Path check |
| SC-DBNAME-014 | Archive paths MUST include timestamp | MEDIUM | Path check |
| SC-DBNAME-015 | Temporary databases MUST use cache type | MEDIUM | Code review |

---

## 8.0 AOR Rules (AOR-DBNAME-*)

| ID | Rule |
|----|------|
| AOR-DBNAME-001 | VALIDATE UHI format before any database operation |
| AOR-DBNAME-002 | RESOLVE paths using DatabasePath module only |
| AOR-DBNAME-003 | REGISTER holon in Registry on startup |
| AOR-DBNAME-004 | UNREGISTER holon on shutdown |
| AOR-DBNAME-005 | UPDATE manifest on schema changes |
| AOR-DBNAME-006 | VERIFY checksums on database load |
| AOR-DBNAME-007 | LOG all path resolution failures |
| AOR-DBNAME-008 | CREATE directory structure before database init |
| AOR-DBNAME-009 | BACKUP before migration |
| AOR-DBNAME-010 | TEST path resolution in unit tests |

---

## 9.0 Examples

### 9.1 Complete UHI Examples

| UHI | Description |
|-----|-------------|
| `ex:l3:kms:srv:main` | Elixir KMS service, main instance |
| `ex:l3:grd:agt:primary` | Elixir Guardian agent, primary instance |
| `ex:l3:snt:srv:main` | Elixir Sentinel service, main instance |
| `fs:l4:prj:agt:cockpit` | F# Prajna cockpit agent |
| `fs:l4:brg:srv:cepaf` | F# CEPAF bridge service |
| `fs:l5:obs:mon:prometheus` | F# observability monitor |
| `zig:l0:zen:srv:router` | Zig Zenoh router service |
| `rs:l0:nif:srv:zenoh` | Rust Zenoh NIF service |

### 9.2 FQDN to Path Examples

| FQDN | Path |
|------|------|
| `ex:l3:kms:srv:main:state` | `data/holons/ex/l3/kms/srv/main/state.sqlite` |
| `ex:l3:kms:srv:main:analytics` | `data/holons/ex/l3/kms/srv/main/analytics.duckdb` |
| `fs:l4:prj:agt:cockpit:history` | `data/holons/fs/l4/prj/agt/cockpit/history.duckdb` |
| `fs:l4:prj:agt:cockpit:register` | `data/holons/fs/l4/prj/agt/cockpit/register.duckdb` |

---

## 10.0 Directory Structure

```
data/
└── holons/
    ├── ex/                          # Elixir runtime
    │   ├── l3/                      # Holon layer
    │   │   ├── kms/                 # KMS domain
    │   │   │   └── srv/             # Service type
    │   │   │       └── main/        # Instance
    │   │   │           ├── manifest.json
    │   │   │           ├── state.sqlite
    │   │   │           ├── vectors.sqlite
    │   │   │           ├── cache.sqlite
    │   │   │           ├── analytics.duckdb
    │   │   │           ├── history.duckdb
    │   │   │           └── register.duckdb
    │   │   ├── grd/                 # Guardian domain
    │   │   │   └── agt/
    │   │   │       └── primary/
    │   │   │           └── ...
    │   │   └── snt/                 # Sentinel domain
    │   │       └── srv/
    │   │           └── main/
    │   │               └── ...
    │   └── l4/                      # Container layer
    │       └── ...
    ├── fs/                          # F# runtime
    │   ├── l4/
    │   │   ├── prj/                 # Prajna domain
    │   │   │   └── agt/
    │   │   │       └── cockpit/
    │   │   │           └── ...
    │   │   └── brg/                 # Bridge domain
    │   │       └── srv/
    │   │           └── cepaf/
    │   │               └── ...
    │   └── l5/
    │       └── obs/
    │           └── mon/
    │               └── ...
    └── zig/                         # Zig runtime
        └── l0/
            └── zen/
                └── srv/
                    └── router/
                        └── ...
```

---

**Document Control**
- Version: 2.0.0
- Author: Claude Opus 4.5
- Date: 2026-01-17
- STAMP: SC-DBNAME-001 to SC-DBNAME-015
- AOR: AOR-DBNAME-001 to AOR-DBNAME-010
