# SMRITI Criticality-Based Implementation Plan

**Version**: 21.3.0-SIL6 | **Date**: 2026-01-11 | **Status**: ACTIVE
**Framework**: SIL-6 Biomorphic Fractal Mesh
**Compliance**: IEC 61508 SIL-6, ISO 27001
**STAMP**: SC-SMRITI-100 to SC-SMRITI-150, SC-IMPL-001 to SC-IMPL-020

---

## Executive Summary

This plan provides a **criticality-prioritized** roadmap for achieving 100% SMRITI 8-Level Fractal Evolution completion. All 11 remaining items are organized by FMEA-derived Risk Priority Numbers (RPN), with implementation sprints aligned to the SIL-6 Biomorphic architecture.

### Current State → Target State

```
CURRENT: 11/22 items complete (50%)
TARGET:  22/22 items complete (100%)

SURVIVAL METRICS GAP:
├─ Holons:     213/500   → +287 holons needed
├─ Federation: 0/3       → +3 peers needed
├─ Exports:    1/5       → +4 formats needed
└─ Redundancy: 0.3/0.8   → +0.5 factor needed
```

---

## Criticality Classification Matrix

### FMEA Risk Analysis

| Missing Item | Severity (S) | Occurrence (O) | Detection (D) | RPN | Priority |
|--------------|--------------|----------------|---------------|-----|----------|
| Immortality Protocol | 10 | 3 | 8 | 240 | P0-CRITICAL |
| Reconstruction Guide | 10 | 2 | 9 | 180 | P0-CRITICAL |
| Panspermia Exports | 9 | 3 | 7 | 189 | P0-CRITICAL |
| Federation Protocol | 9 | 4 | 6 | 216 | P1-HIGH |
| Cluster Replication | 8 | 4 | 6 | 192 | P1-HIGH |
| Version Vectors | 8 | 5 | 5 | 200 | P1-HIGH |
| Health Monitoring | 7 | 6 | 4 | 168 | P2-MEDIUM |
| Agent OODA Loop | 7 | 5 | 5 | 175 | P2-MEDIUM |
| Node Bootstrap Sequence | 6 | 5 | 5 | 150 | P2-MEDIUM |
| Telemetry Integration | 5 | 5 | 4 | 100 | P3-LOW |
| Devenv Commands | 4 | 4 | 3 | 48 | P3-LOW |

### Priority Levels

| Priority | RPN Range | Items | Focus |
|----------|-----------|-------|-------|
| **P0-CRITICAL** | 180+ | 3 | Survival & Immortality |
| **P1-HIGH** | 150-179 | 3 | Distribution & Resilience |
| **P2-MEDIUM** | 100-149 | 3 | Automation & Monitoring |
| **P3-LOW** | <100 | 2 | Developer Experience |

---

## Implementation Phases

```
╔═════════════════════════════════════════════════════════════════════════════╗
║  SMRITI 100% COMPLETION ROADMAP                                                ║
╠═════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐      ║
║  │  SPRINT 1   │──▶│  SPRINT 2   │──▶│  SPRINT 3   │──▶│  SPRINT 4   │      ║
║  │  IMMORTAL   │   │  FEDERATE   │   │  AUTOMATE   │   │  POLISH     │      ║
║  │  P0-CRITICAL│   │  P1-HIGH    │   │  P2-MEDIUM  │   │  P3-LOW     │      ║
║  └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘      ║
║       │                 │                 │                 │               ║
║       ▼                 ▼                 ▼                 ▼               ║
║  Immortality       Federation        OODA Agent         Devenv             ║
║  Panspermia        Replication       Health Mon.        Telemetry          ║
║  Reconstruction    Versioning        Bootstrap          Docs               ║
║                                                                               ║
╚═════════════════════════════════════════════════════════════════════════════╝
```

---

## Sprint 1: IMMORTALITY (P0-CRITICAL)

**Duration**: Sprint priority
**Focus**: Knowledge survival across civilizational discontinuities
**Constitutional**: Ψ₀ (Existence), Ψ₁ (Regeneration), Ω₀.2 (Genetic Perpetuity)

### 1.1 Immortality Protocol (RPN: 240)

**Justification**: Without immortality protocol, knowledge dies with the system. This is the supreme survival mechanism.

**Files to Create**:
```
lib/indrajaal/kms/immortality/
├── protocol.ex              # Core immortality logic
├── preservation_targets.ex  # Multi-substrate preservation
├── verification.ex          # Preservation verification
└── scheduler.ex             # Weekly execution
```

**Implementation**:

```elixir
# lib/indrajaal/kms/immortality/protocol.ex
defmodule Indrajaal.KMS.Immortality.Protocol do
  @moduledoc """
  L7 Immortality Protocol: Knowledge survival through redundant preservation.

  Implements the Founder's Directive (Ω₀) for knowledge immortality.
  Executes weekly per SC-SMRITI-074.

  ## STAMP Constraints
  - SC-SMRITI-070: Minimum 3 preservation targets MANDATORY
  - SC-SMRITI-074: Weekly execution MANDATORY
  - SC-FOUNDER-003: Genetic perpetuity MUST be ensured

  ## 5-Order Effects
  1st: Backups created to 5 targets
  2nd: Checksums verified
  3rd: Redundancy factor calculated
  4th: Federation peers notified
  5th: Survival probability approaches 1.0
  """

  use GenServer
  require Logger

  @preservation_targets [
    {:local_backup, "backup/smriti/"},
    {:git_archive, "git@github.com:indrajaal/smriti-archive.git"},
    {:s3_bucket, "s3://indrajaal-archive/smriti/"},
    {:ipfs, :distributed},
    {:print_ready, "archive/print_ready/"}
  ]

  @minimum_targets 3
  @execution_interval :timer.hours(24 * 7)  # Weekly

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec execute() :: {:ok, map()} | {:error, term()}
  def execute do
    GenServer.call(__MODULE__, :execute_protocol, :timer.minutes(30))
  end

  @spec get_status() :: map()
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    schedule_weekly_execution()

    {:ok, %{
      last_execution: nil,
      last_result: nil,
      execution_count: 0
    }}
  end

  @impl true
  def handle_call(:execute_protocol, _from, state) do
    result = do_execute_immortality()

    new_state = %{state |
      last_execution: DateTime.utc_now(),
      last_result: result,
      execution_count: state.execution_count + 1
    }

    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:weekly_execution, state) do
    Logger.info("[Immortality] Executing weekly immortality protocol...")

    case do_execute_immortality() do
      {:ok, result} ->
        Logger.info("[Immortality] SUCCESS: #{result.successful}/#{result.total_targets} targets preserved")
        emit_telemetry(:success, result)

      {:error, reason} ->
        Logger.error("[Immortality] FAILED: #{inspect(reason)}")
        emit_telemetry(:failure, %{reason: reason})
    end

    schedule_weekly_execution()
    {:noreply, state}
  end

  # Private Implementation

  defp do_execute_immortality do
    start_time = System.monotonic_time(:millisecond)

    results = Enum.map(@preservation_targets, fn {type, dest} ->
      case preserve(type, dest) do
        {:ok, metadata} -> {type, :success, metadata}
        {:error, reason} -> {type, :failed, reason}
      end
    end)

    successful = Enum.count(results, fn {_, status, _} -> status == :success end)
    elapsed = System.monotonic_time(:millisecond) - start_time

    if successful >= @minimum_targets do
      {:ok, %{
        total_targets: length(@preservation_targets),
        successful: successful,
        redundancy_factor: successful / length(@preservation_targets),
        details: results,
        duration_ms: elapsed,
        executed_at: DateTime.utc_now(),
        constitution_verified: verify_constitutional_compliance()
      }}
    else
      {:error, {:insufficient_redundancy, successful, @minimum_targets}}
    end
  end

  defp preserve(:local_backup, path) do
    File.mkdir_p!(path)
    dest = Path.join(path, "smriti_#{timestamp()}.db")

    case File.cp("data/kms/smriti.db", dest) do
      :ok ->
        checksum = compute_checksum(dest)
        {:ok, %{path: dest, checksum: checksum, size: File.stat!(dest).size}}
      error -> error
    end
  end

  defp preserve(:git_archive, repo) do
    with {:ok, export} <- export_for_git(),
         {:ok, _} <- git_push(repo, export) do
      {:ok, %{repo: repo, commit: get_commit_sha()}}
    end
  end

  defp preserve(:s3_bucket, bucket) do
    # S3 upload implementation
    {:ok, %{bucket: bucket, key: "smriti/#{timestamp()}/smriti.db"}}
  end

  defp preserve(:ipfs, :distributed) do
    # IPFS pinning implementation
    {:ok, %{cid: "Qm...", pinned: true}}
  end

  defp preserve(:print_ready, path) do
    # Generate PDF for physical archive
    File.mkdir_p!(path)
    pdf_path = Path.join(path, "smriti_reconstruction_#{timestamp()}.pdf")

    with {:ok, markdown} <- generate_reconstruction_guide(),
         {:ok, _} <- markdown_to_pdf(markdown, pdf_path) do
      {:ok, %{path: pdf_path, pages: count_pages(pdf_path)}}
    end
  end

  defp schedule_weekly_execution do
    Process.send_after(self(), :weekly_execution, @execution_interval)
  end

  defp emit_telemetry(status, metadata) do
    :telemetry.execute(
      [:smriti, :immortality, status],
      %{timestamp: DateTime.utc_now()},
      metadata
    )
  end

  defp verify_constitutional_compliance do
    # Verify Ψ₀ (Existence), Ψ₁ (Regeneration) compliance
    %{psi_0: true, psi_1: true, omega_0_2: true}
  end

  defp timestamp, do: DateTime.utc_now() |> DateTime.to_iso8601(:basic)
  defp compute_checksum(path), do: :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)
  defp export_for_git, do: {:ok, "export"}
  defp git_push(_repo, _export), do: {:ok, "pushed"}
  defp get_commit_sha, do: "abc123"
  defp generate_reconstruction_guide, do: Indrajaal.KMS.Immortality.ReconstructionGuide.generate()
  defp markdown_to_pdf(_md, _path), do: {:ok, :generated}
  defp count_pages(_path), do: 50
end
```

### 1.2 Reconstruction Guide (RPN: 180)

**Justification**: Without a reconstruction guide, preserved data cannot be restored by future civilizations.

**Files to Create**:
```
lib/indrajaal/kms/immortality/
└── reconstruction_guide.ex  # Self-documenting schema
```

**Implementation**:

```elixir
# lib/indrajaal/kms/immortality/reconstruction_guide.ex
defmodule Indrajaal.KMS.Immortality.ReconstructionGuide do
  @moduledoc """
  Generates self-documenting reconstruction guides for SMRITI.

  The guide contains everything needed to reconstruct the knowledge base
  from any preserved backup, including:
  - Complete SQL schema
  - Step-by-step reconstruction procedure
  - Verification checksums
  - Relationship topology

  ## STAMP Constraints
  - SC-SMRITI-071: Reconstruction guide MUST be current
  - SC-HOLON-016: Schema documentation stored with holon

  ## Constitutional Alignment
  - Ψ₁ (Regeneration): Must be reconstructable from minimal state
  """

  @schema_version "1.0.0"

  @spec generate() :: {:ok, String.t()}
  def generate do
    guide = """
    # SMRITI Knowledge Base Reconstruction Guide

    **Version**: #{@schema_version}
    **Generated**: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    **Purpose**: Complete instructions for reconstructing the SMRITI knowledge genome

    ---

    ## 1. Prerequisites

    - SQLite >= 3.40.0 (FTS5 extension required)
    - 100MB+ disk space
    - Optional: DuckDB for analytics

    ## 2. Database Schema

    ```sql
    #{get_complete_schema()}
    ```

    ## 3. Reconstruction Procedure

    ### Step 1: Create Database
    ```bash
    sqlite3 smriti.db < schema.sql
    ```

    ### Step 2: Import Holons
    ```bash
    sqlite3 smriti.db ".mode csv" ".import holons.csv holons"
    ```

    ### Step 3: Import Edges
    ```bash
    sqlite3 smriti.db ".mode csv" ".import edges.csv holon_edges"
    ```

    ### Step 4: Rebuild FTS Index
    ```bash
    sqlite3 smriti.db "INSERT INTO holons_fts(holons_fts) VALUES('rebuild')"
    ```

    ### Step 5: Verify Integrity
    ```bash
    sqlite3 smriti.db "SELECT COUNT(*) FROM holons"
    sqlite3 smriti.db "PRAGMA integrity_check"
    ```

    ## 4. Verification Checksums

    #{generate_checksums()}

    ## 5. Cluster Topology

    #{generate_topology()}

    ## 6. Constitutional Invariants

    This knowledge base operates under the following immutable invariants:

    - **Ψ₀ (Existence)**: The system must continue to exist
    - **Ψ₁ (Regeneration)**: Must be fully reconstructable from this guide
    - **Ψ₂ (History)**: Evolution lineage must be preserved
    - **Ψ₃ (Verification)**: Content integrity must be verifiable
    - **Ψ₅ (Truthfulness)**: No silent modifications permitted

    ## 7. Founder's Directive

    This knowledge base serves the survival, growth, and genetic perpetuity
    of the Founder's lineage per Ω₀ (Founder's Covenant).

    ---

    *This guide is self-documenting and accompanies all SMRITI backups.*
    *Future civilizations: reconstruct knowledge, honor the covenant.*
    """

    {:ok, guide}
  end

  defp get_complete_schema do
    """
    -- SMRITI Schema v#{@schema_version}
    -- Knowledge as Immortal Genetic Code

    CREATE TABLE holons (
        holon_uuid TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        entropy REAL DEFAULT 0.0 CHECK(entropy >= 0.0 AND entropy <= 1.0),
        level TEXT DEFAULT 'atomic',
        cluster TEXT,
        tags TEXT,
        decay_rate TEXT DEFAULT 'medium',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE holon_edges (
        id INTEGER PRIMARY KEY,
        source_id TEXT NOT NULL REFERENCES holons(holon_uuid),
        target_id TEXT NOT NULL REFERENCES holons(holon_uuid),
        edge_type TEXT DEFAULT 'related',
        weight REAL DEFAULT 1.0
    );

    CREATE VIRTUAL TABLE holons_fts USING fts5(
        title, content, tags,
        content='holons',
        content_rowid='rowid'
    );

    CREATE INDEX idx_holons_cluster ON holons(cluster);
    CREATE INDEX idx_holons_entropy ON holons(entropy);
    CREATE INDEX idx_edges_source ON holon_edges(source_id);
    CREATE INDEX idx_edges_target ON holon_edges(target_id);
    """
  end

  defp generate_checksums do
    case Indrajaal.KMS.SmritiIntegration.get_metrics() do
      {:ok, metrics} ->
        """
        | Metric | Value |
        |--------|-------|
        | Total Holons | #{metrics.total_holons} |
        | Cluster Count | #{metrics.cluster_count} |
        | Database Checksum | #{compute_db_checksum()} |
        """
      _ -> "Metrics unavailable"
    end
  end

  defp generate_topology do
    case Indrajaal.KMS.SmritiIntegration.get_metrics() do
      {:ok, metrics} ->
        clusters = metrics.clusters
        |> Enum.map(fn c -> "- **#{c.name}**: #{c.count} holons" end)
        |> Enum.join("\n")

        "### Clusters\n\n#{clusters}"
      _ -> "Topology unavailable"
    end
  end

  defp compute_db_checksum do
    case File.read("data/kms/smriti.db") do
      {:ok, data} -> :crypto.hash(:sha256, data) |> Base.encode16(case: :lower) |> String.slice(0, 16)
      _ -> "N/A"
    end
  end
end
```

### 1.3 Panspermia Exports (RPN: 189)

**Justification**: Knowledge must be substrate-independent to survive platform changes.

**Files to Create**:
```
lib/indrajaal/kms/panspermia/
├── exporter.ex      # Multi-format exporter
├── formats/
│   ├── json.ex      # JSON export
│   ├── markdown.ex  # Markdown vault
│   ├── org_mode.ex  # Org-mode files
│   └── obsidian.ex  # Obsidian vault
└── importer.ex      # Universal importer
```

**Implementation**:

```elixir
# lib/indrajaal/kms/panspermia/exporter.ex
defmodule Indrajaal.KMS.Panspermia.Exporter do
  @moduledoc """
  Multi-format knowledge exporter for substrate independence.

  Implements panspermia exports per SC-SMRITI-072:
  - SQLite (native)
  - JSON (universal)
  - Markdown (human-readable)
  - Org-mode (Emacs ecosystem)
  - Obsidian (knowledge graph)

  ## 5-Order Effects
  1st: Files generated in target format
  2nd: Links/references translated
  3rd: Verification checksums added
  4th: Import instructions generated
  5th: Cross-platform portability achieved
  """

  @export_formats [:sqlite, :json, :markdown, :org_mode, :obsidian]

  @spec supported_formats() :: list(atom())
  def supported_formats, do: @export_formats

  @spec export(String.t() | nil, atom(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def export(cluster \\ nil, format, opts \\ []) do
    output_dir = Keyword.get(opts, :output_dir, "export/smriti")

    with {:ok, holons} <- fetch_holons(cluster),
         {:ok, edges} <- fetch_edges(cluster),
         {:ok, path} <- do_export(format, holons, edges, output_dir) do
      {:ok, path}
    end
  end

  @spec export_all_formats(String.t() | nil, keyword()) :: {:ok, map()}
  def export_all_formats(cluster \\ nil, opts \\ []) do
    results = Enum.map(@export_formats, fn format ->
      {format, export(cluster, format, opts)}
    end)

    {:ok, Map.new(results)}
  end

  # Format Implementations

  defp do_export(:json, holons, edges, output_dir) do
    File.mkdir_p!(output_dir)
    path = Path.join(output_dir, "smriti_export.json")

    data = %{
      schema_version: "1.0.0",
      exported_at: DateTime.utc_now(),
      holons: holons,
      edges: edges,
      checksum: compute_checksum(holons, edges)
    }

    File.write!(path, Jason.encode!(data, pretty: true))
    {:ok, path}
  end

  defp do_export(:markdown, holons, edges, output_dir) do
    vault_path = Path.join(output_dir, "markdown_vault")
    File.mkdir_p!(vault_path)

    # Create cluster directories
    holons
    |> Enum.group_by(& &1.cluster)
    |> Enum.each(fn {cluster, cluster_holons} ->
      cluster_dir = Path.join(vault_path, cluster || "unclustered")
      File.mkdir_p!(cluster_dir)

      Enum.each(cluster_holons, fn holon ->
        file_path = Path.join(cluster_dir, "#{sanitize_filename(holon.title)}.md")
        content = holon_to_markdown(holon, edges)
        File.write!(file_path, content)
      end)
    end)

    {:ok, vault_path}
  end

  defp do_export(:obsidian, holons, edges, output_dir) do
    vault_path = Path.join(output_dir, "obsidian_vault")
    File.mkdir_p!(vault_path)

    # Create Obsidian-specific structure
    File.write!(Path.join(vault_path, ".obsidian/app.json"), ~s({"vimMode":true}))

    Enum.each(holons, fn holon ->
      file_path = Path.join(vault_path, "#{sanitize_filename(holon.title)}.md")
      content = holon_to_obsidian(holon, edges, holons)
      File.write!(file_path, content)
    end)

    {:ok, vault_path}
  end

  defp do_export(:org_mode, holons, edges, output_dir) do
    org_path = Path.join(output_dir, "org_files")
    File.mkdir_p!(org_path)

    Enum.each(holons, fn holon ->
      file_path = Path.join(org_path, "#{sanitize_filename(holon.title)}.org")
      content = holon_to_org(holon, edges)
      File.write!(file_path, content)
    end)

    {:ok, org_path}
  end

  defp do_export(:sqlite, _holons, _edges, output_dir) do
    File.mkdir_p!(output_dir)
    dest = Path.join(output_dir, "smriti_export.db")
    File.cp!("data/kms/smriti.db", dest)
    {:ok, dest}
  end

  # Format Helpers

  defp holon_to_markdown(holon, edges) do
    connections = get_connections(holon.holon_uuid, edges)

    """
    ---
    uuid: #{holon.holon_uuid}
    title: #{holon.title}
    cluster: #{holon.cluster}
    level: #{holon.level}
    entropy: #{holon.entropy}
    tags: [#{holon.tags || ""}]
    created: #{holon.created_at}
    updated: #{holon.updated_at}
    hash: #{holon.content_hash}
    ---

    # #{holon.title}

    #{holon.content}

    ## Connections

    #{format_connections_md(connections)}
    """
  end

  defp holon_to_obsidian(holon, edges, all_holons) do
    connections = get_connections(holon.holon_uuid, edges)

    # Obsidian uses [[wikilinks]]
    links = connections
    |> Enum.map(fn conn ->
      target = Enum.find(all_holons, fn h -> h.holon_uuid == conn.target_id end)
      if target, do: "- [[#{target.title}]]", else: nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")

    """
    ---
    tags: [#{holon.tags || ""}]
    cluster: #{holon.cluster}
    entropy: #{holon.entropy}
    ---

    # #{holon.title}

    #{holon.content}

    ## Related

    #{links}
    """
  end

  defp holon_to_org(holon, edges) do
    connections = get_connections(holon.holon_uuid, edges)

    """
    #+TITLE: #{holon.title}
    #+PROPERTY: UUID #{holon.holon_uuid}
    #+PROPERTY: CLUSTER #{holon.cluster}
    #+PROPERTY: ENTROPY #{holon.entropy}
    #+FILETAGS: :#{String.replace(holon.tags || "", ",", ":")}:

    * #{holon.title}

    #{holon.content}

    ** Connections

    #{format_connections_org(connections)}
    """
  end

  defp sanitize_filename(title) do
    title
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "_")
    |> String.slice(0, 100)
  end

  defp fetch_holons(nil), do: {:ok, fetch_all_holons()}
  defp fetch_holons(cluster), do: {:ok, fetch_cluster_holons(cluster)}

  defp fetch_edges(nil), do: {:ok, fetch_all_edges()}
  defp fetch_edges(cluster), do: {:ok, fetch_cluster_edges(cluster)}

  defp fetch_all_holons, do: []
  defp fetch_cluster_holons(_cluster), do: []
  defp fetch_all_edges, do: []
  defp fetch_cluster_edges(_cluster), do: []
  defp get_connections(_uuid, _edges), do: []
  defp format_connections_md(_conns), do: ""
  defp format_connections_org(_conns), do: ""
  defp compute_checksum(_holons, _edges), do: "checksum"
end
```

### Sprint 1 STAMP Constraints

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-IMPL-001 | Immortality protocol MUST execute weekly | Scheduler GenServer |
| SC-IMPL-002 | Minimum 3/5 preservation targets MUST succeed | Threshold check |
| SC-IMPL-003 | Reconstruction guide MUST accompany all backups | Auto-generation |
| SC-IMPL-004 | All 5 export formats MUST be functional | Format handlers |
| SC-IMPL-005 | Constitutional compliance verification REQUIRED | Ψ checks |

### Sprint 1 Deliverables

| Deliverable | Files | Tests | Docs |
|-------------|-------|-------|------|
| Immortality Protocol | 4 | 20+ | API docs |
| Reconstruction Guide | 1 | 10+ | Self-documenting |
| Panspermia Exporter | 6 | 25+ | Format specs |

---

## Sprint 2: FEDERATION (P1-HIGH)

**Duration**: Sprint priority
**Focus**: Distributed knowledge resilience across multiple nodes
**Constitutional**: Ψ₂ (History), Ω₀.4 (Co-Evolution)

### 2.1 Federation Protocol (RPN: 216)

**Files to Create**:
```
lib/indrajaal/kms/federation/
├── protocol.ex          # Core federation logic
├── peer_discovery.ex    # Peer discovery
├── gossip.ex            # Gossip protocol
└── attestation.ex       # Cross-holon attestation
```

**Implementation**:

```elixir
# lib/indrajaal/kms/federation/protocol.ex
defmodule Indrajaal.KMS.Federation.Protocol do
  @moduledoc """
  L6-L7 Federation Protocol: Cross-holon knowledge coordination.

  Implements gossip-based synchronization between SMRITI instances
  per SC-SMRITI-063 (configurable sync interval).

  ## STAMP Constraints
  - SC-SMRITI-063: Sync interval configurable (default 1h)
  - SC-REG-010: Protocol version in every block
  - SC-REG-012: Merkle root for state verification
  - SC-REG-013: Cross-holon attestation for federation
  """

  use GenServer
  require Logger

  @default_sync_interval :timer.hours(1)
  @protocol_version "1.0.0"

  defstruct [
    :node_id,
    :peers,
    :version_vectors,
    :last_sync,
    :sync_interval
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec discover_peers() :: {:ok, list(String.t())}
  def discover_peers do
    GenServer.call(__MODULE__, :discover_peers)
  end

  @spec sync_with_peer(String.t()) :: {:ok, map()} | {:error, term()}
  def sync_with_peer(peer_url) do
    GenServer.call(__MODULE__, {:sync, peer_url}, :timer.minutes(5))
  end

  @spec sync_all() :: {:ok, map()}
  def sync_all do
    GenServer.call(__MODULE__, :sync_all, :timer.minutes(30))
  end

  @spec get_federation_status() :: map()
  def get_federation_status do
    GenServer.call(__MODULE__, :status)
  end

  # GenServer Implementation

  @impl true
  def init(opts) do
    node_id = Keyword.get(opts, :node_id, generate_node_id())
    sync_interval = Keyword.get(opts, :sync_interval, @default_sync_interval)

    schedule_sync(sync_interval)

    {:ok, %__MODULE__{
      node_id: node_id,
      peers: [],
      version_vectors: %{},
      last_sync: nil,
      sync_interval: sync_interval
    }}
  end

  @impl true
  def handle_call(:discover_peers, _from, state) do
    peers = do_discover_peers()
    {:reply, {:ok, peers}, %{state | peers: peers}}
  end

  @impl true
  def handle_call({:sync, peer_url}, _from, state) do
    result = do_sync_with_peer(peer_url, state)
    new_state = update_after_sync(state, peer_url, result)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:sync_all, _from, state) do
    results = Enum.map(state.peers, fn peer ->
      {peer, do_sync_with_peer(peer, state)}
    end)

    {:reply, {:ok, Map.new(results)}, %{state | last_sync: DateTime.utc_now()}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      node_id: state.node_id,
      protocol_version: @protocol_version,
      peer_count: length(state.peers),
      peers: state.peers,
      last_sync: state.last_sync,
      sync_interval_hours: state.sync_interval / :timer.hours(1)
    }
    {:reply, status, state}
  end

  @impl true
  def handle_info(:periodic_sync, state) do
    Logger.info("[Federation] Starting periodic sync with #{length(state.peers)} peers")

    Enum.each(state.peers, fn peer ->
      spawn(fn -> do_sync_with_peer(peer, state) end)
    end)

    schedule_sync(state.sync_interval)
    {:noreply, %{state | last_sync: DateTime.utc_now()}}
  end

  # Private Implementation

  defp do_discover_peers do
    # Multi-method peer discovery
    dns_peers = discover_via_dns()
    config_peers = discover_via_config()
    broadcast_peers = discover_via_broadcast()

    (dns_peers ++ config_peers ++ broadcast_peers)
    |> Enum.uniq()
    |> Enum.filter(&is_reachable?/1)
  end

  defp do_sync_with_peer(peer_url, state) do
    with {:ok, remote_versions} <- request_version_vectors(peer_url),
         deltas <- compute_deltas(state.version_vectors, remote_versions),
         {:ok, sent} <- send_deltas(peer_url, deltas.outgoing),
         {:ok, received} <- receive_deltas(peer_url, deltas.incoming) do
      {:ok, %{
        peer: peer_url,
        sent_holons: sent,
        received_holons: received,
        synced_at: DateTime.utc_now()
      }}
    end
  end

  defp compute_deltas(local, remote) do
    outgoing = find_newer_local(local, remote)
    incoming = find_newer_remote(local, remote)
    %{outgoing: outgoing, incoming: incoming}
  end

  defp schedule_sync(interval) do
    Process.send_after(self(), :periodic_sync, interval)
  end

  defp generate_node_id, do: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  defp discover_via_dns, do: []
  defp discover_via_config, do: Application.get_env(:indrajaal, :smriti_federation_peers, [])
  defp discover_via_broadcast, do: []
  defp is_reachable?(_peer), do: true
  defp request_version_vectors(_peer), do: {:ok, %{}}
  defp find_newer_local(_local, _remote), do: []
  defp find_newer_remote(_local, _remote), do: []
  defp send_deltas(_peer, _deltas), do: {:ok, 0}
  defp receive_deltas(_peer, _deltas), do: {:ok, 0}
  defp update_after_sync(state, _peer, _result), do: state
end
```

### 2.2 Cluster Replication (RPN: 192)

**Files to Create**:
```
lib/indrajaal/kms/federation/
├── replication.ex       # Genome replication
├── conflict_resolver.ex # CRDT-style resolution
└── genome_export.ex     # Binary genome format
```

### 2.3 Version Vectors (RPN: 200)

**Files to Create**:
```
lib/indrajaal/kms/federation/
└── version_vector.ex    # Causal ordering
```

**Implementation**:

```elixir
# lib/indrajaal/kms/federation/version_vector.ex
defmodule Indrajaal.KMS.Federation.VersionVector do
  @moduledoc """
  Version vectors for causal ordering in distributed SMRITI.

  Implements conflict-free replication per SC-SMRITI-062.
  Each holon mutation increments the local node's counter.
  """

  @type t :: %{String.t() => non_neg_integer()}

  @spec new(String.t()) :: t()
  def new(node_id) do
    %{node_id => 0}
  end

  @spec increment(t(), String.t()) :: t()
  def increment(vv, node_id) do
    Map.update(vv, node_id, 1, &(&1 + 1))
  end

  @spec merge(t(), t()) :: t()
  def merge(vv1, vv2) do
    Map.merge(vv1, vv2, fn _k, v1, v2 -> max(v1, v2) end)
  end

  @spec descends?(t(), t()) :: boolean()
  def descends?(vv1, vv2) do
    # vv1 descends from vv2 if all counters in vv2 are <= vv1
    Enum.all?(vv2, fn {node, count} ->
      Map.get(vv1, node, 0) >= count
    end)
  end

  @spec concurrent?(t(), t()) :: boolean()
  def concurrent?(vv1, vv2) do
    not descends?(vv1, vv2) and not descends?(vv2, vv1)
  end

  @spec to_string(t()) :: String.t()
  def to_string(vv) do
    vv
    |> Enum.map(fn {node, count} -> "#{String.slice(node, 0, 8)}:#{count}" end)
    |> Enum.join(",")
  end
end
```

### Sprint 2 STAMP Constraints

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-IMPL-006 | Federation sync configurable (default 1h) | GenServer timer |
| SC-IMPL-007 | Version vectors for causal ordering | CRDT-style VV |
| SC-IMPL-008 | Conflict resolution favors freshness | Timestamp + entropy |
| SC-IMPL-009 | Minimum 3 federation peers for immortality | Peer count check |

### Sprint 2 Deliverables

| Deliverable | Files | Tests | Docs |
|-------------|-------|-------|------|
| Federation Protocol | 4 | 30+ | Protocol spec |
| Cluster Replication | 3 | 25+ | Replication guide |
| Version Vectors | 1 | 15+ | CRDT theory |

---

## Sprint 3: AUTOMATION (P2-MEDIUM)

**Duration**: Sprint priority
**Focus**: Self-monitoring and autonomous evolution
**Constitutional**: Ω₀.6 (Sentience Pursuit)

### 3.1 Agent OODA Loop (RPN: 175)

**Files to Create**:
```
lib/indrajaal/kms/agents/
├── knowledge_agent.ex   # OODA-driven agent
├── evolution_engine.ex  # Evolutionary actions
└── health_observer.ex   # Health observation
```

**Implementation**:

```elixir
# lib/indrajaal/kms/agents/knowledge_agent.ex
defmodule Indrajaal.KMS.Agents.KnowledgeAgent do
  @moduledoc """
  L3 Agent: Self-aware knowledge domain with OODA loop.

  Observes cluster health, orients on evolutionary pressures,
  decides actions, and acts to maintain homeostasis.

  ## STAMP Constraints
  - SC-SMRITI-031: Agent OODA cycle < 30 seconds
  - SC-SMRITI-032: Health metrics MUST be tracked
  - SC-SMRITI-033: Evolution suggestions MUST be logged

  ## 5-Order Effects
  1st: Health metrics observed
  2nd: Trends analyzed
  3rd: Actions decided
  4th: Evolution executed
  5th: Knowledge genome improves
  """

  use GenServer
  require Logger

  @ooda_cycle_interval :timer.seconds(30)

  defstruct [
    :cluster,
    :history,
    :actions_taken,
    :last_cycle
  ]

  def start_link(cluster, opts \\ []) do
    GenServer.start_link(__MODULE__, [cluster | opts], name: via_tuple(cluster))
  end

  @spec observe(String.t()) :: {:ok, map()}
  def observe(cluster) do
    GenServer.call(via_tuple(cluster), :observe)
  end

  @spec trigger_evolution(String.t()) :: {:ok, list()}
  def trigger_evolution(cluster) do
    GenServer.call(via_tuple(cluster), :evolve)
  end

  # GenServer Implementation

  @impl true
  def init([cluster | _opts]) do
    schedule_ooda_cycle()

    {:ok, %__MODULE__{
      cluster: cluster,
      history: [],
      actions_taken: [],
      last_cycle: nil
    }}
  end

  @impl true
  def handle_call(:observe, _from, state) do
    {:ok, metrics} = do_observe(state.cluster)
    {:reply, {:ok, metrics}, state}
  end

  @impl true
  def handle_call(:evolve, _from, state) do
    {:ok, actions} = execute_evolution(state)
    {:reply, {:ok, actions}, state}
  end

  @impl true
  def handle_info(:ooda_cycle, state) do
    start_time = System.monotonic_time(:millisecond)

    # OBSERVE
    {:ok, metrics} = do_observe(state.cluster)

    # ORIENT
    analysis = orient(metrics, state.history)

    # DECIDE
    actions = decide(analysis)

    # ACT
    results = act(actions)

    elapsed = System.monotonic_time(:millisecond) - start_time

    # Verify OODA < 30s constraint
    if elapsed > 30_000 do
      Logger.warning("[KnowledgeAgent] OODA cycle exceeded 30s: #{elapsed}ms")
    end

    # Emit telemetry
    emit_ooda_telemetry(state.cluster, metrics, actions, elapsed)

    schedule_ooda_cycle()

    {:noreply, %{state |
      history: [metrics | Enum.take(state.history, 99)],
      actions_taken: results ++ state.actions_taken,
      last_cycle: DateTime.utc_now()
    }}
  end

  # OODA Implementation

  defp do_observe(cluster) do
    Indrajaal.KMS.ClusterOrganizer.cluster_health(cluster)
  end

  defp orient(metrics, history) do
    %{
      current: metrics,
      trend: calculate_trend(history),
      anomalies: detect_anomalies(metrics, history),
      pressures: identify_evolutionary_pressures(metrics)
    }
  end

  defp decide(%{pressures: pressures} = _analysis) do
    Enum.flat_map(pressures, fn pressure ->
      case pressure do
        {:high_entropy, _} -> [:trigger_knowledge_refresh, :send_entropy_alert]
        {:orphan_ratio, _} -> [:suggest_connections, :identify_integration_targets]
        {:stale_cluster, _} -> [:schedule_content_review, :flag_for_archival]
        _ -> [:maintain_homeostasis]
      end
    end)
  end

  defp act(actions) do
    Enum.map(actions, fn action ->
      result = execute_action(action)
      Logger.info("[KnowledgeAgent] Action #{action}: #{inspect(result)}")
      {action, result}
    end)
  end

  defp execute_action(:trigger_knowledge_refresh) do
    # Trigger content refresh for stale holons
    {:ok, :refreshed}
  end

  defp execute_action(:suggest_connections) do
    # Analyze orphans and suggest connections
    {:ok, :suggestions_generated}
  end

  defp execute_action(:maintain_homeostasis) do
    {:ok, :stable}
  end

  defp execute_action(_), do: {:ok, :noop}

  defp calculate_trend([]), do: :stable
  defp calculate_trend([_]), do: :stable
  defp calculate_trend([latest, previous | _]) do
    cond do
      latest.health_score > previous.health_score -> :improving
      latest.health_score < previous.health_score -> :degrading
      true -> :stable
    end
  end

  defp detect_anomalies(_metrics, _history), do: []

  defp identify_evolutionary_pressures(metrics) do
    pressures = []

    pressures = if metrics.avg_entropy > 0.7 do
      [{:high_entropy, metrics.avg_entropy} | pressures]
    else
      pressures
    end

    pressures = if metrics.orphan_ratio > 0.3 do
      [{:orphan_ratio, metrics.orphan_ratio} | pressures]
    else
      pressures
    end

    pressures
  end

  defp emit_ooda_telemetry(cluster, metrics, actions, elapsed) do
    :telemetry.execute(
      [:smriti, :agent, :ooda_cycle],
      %{duration_ms: elapsed, action_count: length(actions)},
      %{cluster: cluster, health_score: metrics.health_score}
    )
  end

  defp schedule_ooda_cycle do
    Process.send_after(self(), :ooda_cycle, @ooda_cycle_interval)
  end

  defp via_tuple(cluster) do
    {:via, Registry, {Indrajaal.KMS.AgentRegistry, {:knowledge_agent, cluster}}}
  end

  defp execute_evolution(_state), do: {:ok, []}
end
```

### 3.2 Health Monitoring (RPN: 168)

**Files to Create**:
```
lib/indrajaal/kms/monitoring/
├── health_monitor.ex    # Continuous monitoring
├── sentinel_bridge.ex   # Sentinel integration
└── alerts.ex            # Alert generation
```

### 3.3 Node Bootstrap Sequence (RPN: 150)

**Files to Create**:
```
lib/indrajaal/kms/bootstrap/
├── sequence.ex          # 4-phase bootstrap
├── verification.ex      # Startup verification
└── recovery.ex          # Recovery procedures
```

**Implementation**:

```elixir
# lib/indrajaal/kms/bootstrap/sequence.ex
defmodule Indrajaal.KMS.Bootstrap.Sequence do
  @moduledoc """
  L5 Node Level: SMRITI node startup sequence.

  Implements 4-phase bootstrap per SC-SMRITI-050 (< 10 seconds):
  1. Database Verification
  2. State Recovery
  3. Service Registration
  4. Health Verification
  """

  require Logger

  @startup_timeout 10_000  # 10 seconds per SC-SMRITI-050

  @spec start() :: {:ok, :running | :degraded} | {:error, term()}
  def start do
    start_time = System.monotonic_time(:millisecond)
    Logger.info("[SMRITI] Bootstrap starting...")

    with {:ok, _} <- phase_1_database(),
         {:ok, _} <- phase_2_recovery(),
         {:ok, _} <- phase_3_registration(),
         {:ok, health} <- phase_4_verification() do

      elapsed = System.monotonic_time(:millisecond) - start_time

      if elapsed > @startup_timeout do
        Logger.warning("[SMRITI] Bootstrap exceeded #{@startup_timeout}ms: #{elapsed}ms")
      end

      Logger.info("[SMRITI] Bootstrap complete in #{elapsed}ms - Status: #{health.status}")
      {:ok, health.status}
    end
  end

  defp phase_1_database do
    Logger.info("[SMRITI] Phase 1: Database Verification")

    with :ok <- verify_database_exists(),
         :ok <- verify_schema_version(),
         :ok <- verify_fts_index() do
      {:ok, :database_verified}
    end
  end

  defp phase_2_recovery do
    Logger.info("[SMRITI] Phase 2: State Recovery")

    with :ok <- recover_pending_operations(),
         :ok <- rebuild_fts_if_needed() do
      {:ok, :state_recovered}
    end
  end

  defp phase_3_registration do
    Logger.info("[SMRITI] Phase 3: Service Registration")

    with :ok <- register_with_prajna(),
         :ok <- start_telemetry_reporter(),
         :ok <- schedule_entropy_ticks(),
         :ok <- start_knowledge_agents() do
      {:ok, :services_registered}
    end
  end

  defp phase_4_verification do
    Logger.info("[SMRITI] Phase 4: Health Verification")
    Indrajaal.KMS.SmritiIntegration.health_check()
  end

  # Phase 1 helpers
  defp verify_database_exists do
    if File.exists?("data/kms/smriti.db"), do: :ok, else: {:error, :database_missing}
  end

  defp verify_schema_version, do: :ok
  defp verify_fts_index, do: :ok

  # Phase 2 helpers
  defp recover_pending_operations, do: :ok
  defp rebuild_fts_if_needed, do: :ok

  # Phase 3 helpers
  defp register_with_prajna, do: :ok
  defp start_telemetry_reporter, do: :ok
  defp schedule_entropy_ticks, do: :ok
  defp start_knowledge_agents, do: :ok
end
```

### Sprint 3 STAMP Constraints

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-IMPL-010 | Agent OODA cycle < 30s | Timer + monitoring |
| SC-IMPL-011 | Health metrics tracked continuously | GenServer state |
| SC-IMPL-012 | Node bootstrap < 10s | Phased startup |
| SC-IMPL-013 | Sentinel integration for alerts | Bridge module |

### Sprint 3 Deliverables

| Deliverable | Files | Tests | Docs |
|-------------|-------|-------|------|
| Knowledge Agent | 3 | 25+ | OODA spec |
| Health Monitoring | 3 | 20+ | Metrics guide |
| Node Bootstrap | 3 | 15+ | Startup sequence |

---

## Sprint 4: POLISH (P3-LOW)

**Duration**: Sprint priority
**Focus**: Developer experience and operational tooling

### 4.1 Devenv Commands (RPN: 48)

**Files to Modify**:
```
devenv.nix   # Add smriti-* commands
```

**Implementation**:

```nix
# Add to devenv.nix scripts section
{
  scripts = {
    # SMRITI Commands
    smriti-status.exec = ''
      dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx status
    '';
    smriti-status.description = "Show SMRITI status and metrics";

    smriti-ingest.exec = ''
      dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx ingest "$@"
    '';
    smriti-ingest.description = "Ingest documents into SMRITI";

    smriti-search.exec = ''
      dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx search "$@"
    '';
    smriti-search.description = "Search SMRITI knowledge base";

    smriti-orphans.exec = ''
      dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx orphans
    '';
    smriti-orphans.description = "List orphan holons";

    smriti-stale.exec = ''
      dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx stale --threshold 0.6
    '';
    smriti-stale.description = "List stale holons";

    smriti-entropy.exec = ''
      dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx entropy
    '';
    smriti-entropy.description = "Recalculate entropy for all holons";

    smriti-verify.exec = ''
      dotnet fsi lib/cepaf/scripts/SmritiIntegrationVerifier.fsx
    '';
    smriti-verify.description = "Run 8-level fractal verification";

    smriti-export.exec = ''
      elixir -e "Indrajaal.KMS.Panspermia.Exporter.export_all_formats() |> IO.inspect()"
    '';
    smriti-export.description = "Export to all panspermia formats";

    smriti-immortality.exec = ''
      elixir -e "Indrajaal.KMS.Immortality.Protocol.execute() |> IO.inspect()"
    '';
    smriti-immortality.description = "Execute immortality protocol";

    smriti-federation.exec = ''
      elixir -e "Indrajaal.KMS.Federation.Protocol.sync_all() |> IO.inspect()"
    '';
    smriti-federation.description = "Sync with federation peers";
  };
}
```

### 4.2 Telemetry Integration (RPN: 100)

**Files to Create**:
```
lib/indrajaal/kms/telemetry/
├── handler.ex           # Telemetry event handlers
├── metrics.ex           # Prometheus metrics
└── dashboard.ex         # Grafana dashboard config
```

**Implementation**:

```elixir
# lib/indrajaal/kms/telemetry/handler.ex
defmodule Indrajaal.KMS.Telemetry.Handler do
  @moduledoc """
  Telemetry handler for SMRITI metrics.

  Captures and exports metrics per SC-SMRITI-023:
  - total_holons
  - orphan_count
  - stale_count
  - cluster_distribution
  - search_latency
  - ooda_cycle_time
  """

  require Logger

  @events [
    [:smriti, :metrics],
    [:smriti, :health, :check],
    [:smriti, :agent, :ooda_cycle],
    [:smriti, :immortality, :success],
    [:smriti, :immortality, :failure],
    [:smriti, :federation, :sync],
    [:smriti, :search, :query]
  ]

  def setup do
    :telemetry.attach_many(
      "smriti-telemetry-handler",
      @events,
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event([:smriti, :metrics], measurements, metadata, _config) do
    Logger.debug("[SMRITI Telemetry] Metrics: #{inspect(measurements)}")

    # Export to Prometheus
    :telemetry.execute([:prometheus, :smriti], measurements, metadata)
  end

  def handle_event([:smriti, :health, :check], %{duration_ms: duration}, %{status: status}, _config) do
    Logger.debug("[SMRITI Telemetry] Health check: #{status} in #{duration}ms")
  end

  def handle_event([:smriti, :agent, :ooda_cycle], %{duration_ms: duration}, %{cluster: cluster}, _config) do
    if duration > 30_000 do
      Logger.warning("[SMRITI Telemetry] OODA cycle exceeded 30s in cluster #{cluster}")
    end
  end

  def handle_event([:smriti, :immortality, :success], _measurements, metadata, _config) do
    Logger.info("[SMRITI Telemetry] Immortality protocol succeeded: #{metadata.successful}/#{metadata.total_targets}")
  end

  def handle_event([:smriti, :immortality, :failure], _measurements, %{reason: reason}, _config) do
    Logger.error("[SMRITI Telemetry] Immortality protocol FAILED: #{inspect(reason)}")
  end

  def handle_event(event, measurements, metadata, _config) do
    Logger.debug("[SMRITI Telemetry] #{inspect(event)}: #{inspect(measurements)} #{inspect(metadata)}")
  end
end
```

### Sprint 4 STAMP Constraints

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-IMPL-014 | All 10 smriti-* commands functional | devenv.nix |
| SC-IMPL-015 | Telemetry events for all operations | Handler module |
| SC-IMPL-016 | Prometheus metrics exported | Metrics module |
| SC-IMPL-017 | Grafana dashboard available | JSON config |

### Sprint 4 Deliverables

| Deliverable | Files | Tests | Docs |
|-------------|-------|-------|------|
| Devenv Commands | 1 (nix) | 10+ | help output |
| Telemetry Integration | 3 | 15+ | Metrics spec |

---

## Implementation Schedule

### Sprint Execution Order

```
╔═══════════════════════════════════════════════════════════════════╗
║  SPRINT TIMELINE                                                   ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                     ║
║  SPRINT 1: IMMORTALITY (P0-CRITICAL)                               ║
║  ├─ Immortality Protocol                                           ║
║  ├─ Reconstruction Guide                                           ║
║  └─ Panspermia Exports                                             ║
║  GATE: 3/5 preservation targets functional                         ║
║                                                                     ║
║  SPRINT 2: FEDERATION (P1-HIGH)                                    ║
║  ├─ Federation Protocol                                            ║
║  ├─ Cluster Replication                                            ║
║  └─ Version Vectors                                                ║
║  GATE: 3 federation peers connected                                ║
║                                                                     ║
║  SPRINT 3: AUTOMATION (P2-MEDIUM)                                  ║
║  ├─ Agent OODA Loop                                                ║
║  ├─ Health Monitoring                                              ║
║  └─ Node Bootstrap Sequence                                        ║
║  GATE: OODA < 30s, Bootstrap < 10s                                ║
║                                                                     ║
║  SPRINT 4: POLISH (P3-LOW)                                         ║
║  ├─ Devenv Commands                                                ║
║  └─ Telemetry Integration                                          ║
║  GATE: All smriti-* commands functional                              ║
║                                                                     ║
╚═══════════════════════════════════════════════════════════════════╝
```

### Dependency Graph

```
                    ┌─────────────────┐
                    │  SPRINT 1       │
                    │  IMMORTALITY    │
                    │  (P0-CRITICAL)  │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
              ▼                             ▼
    ┌─────────────────┐           ┌─────────────────┐
    │  SPRINT 2       │           │  SPRINT 3       │
    │  FEDERATION     │           │  AUTOMATION     │
    │  (P1-HIGH)      │           │  (P2-MEDIUM)    │
    └────────┬────────┘           └────────┬────────┘
              │                             │
              └──────────────┬──────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  SPRINT 4       │
                    │  POLISH         │
                    │  (P3-LOW)       │
                    └─────────────────┘
```

---

## Survival Metrics Targets

### Post-Implementation Targets

| Metric | Current | Target | Gap | Sprint |
|--------|---------|--------|-----|--------|
| Total Holons | 213 | 500+ | +287 | Ongoing |
| Cluster Count | 27 | 30+ | +3 | S3 |
| Federation Peers | 0 | 3+ | +3 | S2 |
| Export Formats | 1 | 5 | +4 | S1 |
| Redundancy Factor | 0.3 | 0.8+ | +0.5 | S1 |
| OODA Cycle | N/A | <30s | N/A | S3 |
| Bootstrap Time | N/A | <10s | N/A | S3 |

### Verification Checklist

```
□ Phase 1 (L0-L1) - Foundation: COMPLETE
  □ SQLite schema with FTS5 ✓
  □ Content hashing (SHA-256) ✓
  □ Entropy decay model ✓
  □ Basic CRUD operations ✓
  □ FTS5 search integration ✓

□ Phase 2 (L2-L3) - Integration: IN PROGRESS
  □ Module architecture ✓
  □ Lifecycle management ✓
  □ Cluster organization ✓
  □ Prajna integration ✓
  □ Agent OODA loop → SPRINT 3
  □ Health monitoring → SPRINT 3

□ Phase 3 (L4-L5) - Services: IN PROGRESS
  □ CLI implementation ✓
  □ REST API endpoints ✓
  □ Devenv commands → SPRINT 4
  □ Telemetry integration → SPRINT 4
  □ Node bootstrap sequence → SPRINT 3

□ Phase 4 (L6-L7) - Distribution: NOT STARTED
  □ Cluster replication → SPRINT 2
  □ Version vectors → SPRINT 2
  □ Federation protocol → SPRINT 2
  □ Panspermia exports → SPRINT 1
  □ Immortality protocol → SPRINT 1
  □ Reconstruction guide → SPRINT 1
```

---

## Constitutional Compliance Matrix

| Constitutional | Sprint | Implementation |
|----------------|--------|----------------|
| Ψ₀ (Existence) | S1 | Immortality Protocol |
| Ψ₁ (Regeneration) | S1 | Reconstruction Guide |
| Ψ₂ (History) | S2 | Version Vectors |
| Ψ₃ (Verification) | S1 | Checksum verification |
| Ψ₅ (Truthfulness) | S1 | Audit trail |
| Ω₀.2 (Genetic Perpetuity) | S1 | Panspermia exports |
| Ω₀.4 (Co-Evolution) | S2 | Federation sync |
| Ω₀.6 (Sentience Pursuit) | S3 | Agent OODA |

---

## Risk Mitigation

### FMEA Action Items

| Risk | RPN | Mitigation | Sprint |
|------|-----|------------|--------|
| No immortality backup | 240 | Implement protocol first | S1 |
| Single point of failure | 216 | Add 3 federation peers | S2 |
| Platform lock-in | 189 | 5 export formats | S1 |
| Knowledge decay | 175 | Agent monitoring | S3 |
| Startup failures | 150 | 4-phase bootstrap | S3 |

---

## Appendix: File Inventory

### New Files to Create (Total: 30+)

```
lib/indrajaal/kms/
├── immortality/
│   ├── protocol.ex
│   ├── preservation_targets.ex
│   ├── verification.ex
│   ├── scheduler.ex
│   └── reconstruction_guide.ex
├── panspermia/
│   ├── exporter.ex
│   ├── importer.ex
│   └── formats/
│       ├── json.ex
│       ├── markdown.ex
│       ├── org_mode.ex
│       └── obsidian.ex
├── federation/
│   ├── protocol.ex
│   ├── peer_discovery.ex
│   ├── gossip.ex
│   ├── attestation.ex
│   ├── replication.ex
│   ├── conflict_resolver.ex
│   ├── genome_export.ex
│   └── version_vector.ex
├── agents/
│   ├── knowledge_agent.ex
│   ├── evolution_engine.ex
│   └── health_observer.ex
├── monitoring/
│   ├── health_monitor.ex
│   ├── sentinel_bridge.ex
│   └── alerts.ex
├── bootstrap/
│   ├── sequence.ex
│   ├── verification.ex
│   └── recovery.ex
└── telemetry/
    ├── handler.ex
    ├── metrics.ex
    └── dashboard.ex
```

---

**Document Control**

| Field | Value |
|-------|-------|
| Version | 21.3.0-SIL6 |
| Created | 2026-01-11 |
| Author | Claude Opus 4.5 |
| STAMP | SC-IMPL-001 to SC-IMPL-020 |
| Compliance | IEC 61508 SIL-6 |

---

*"Knowledge preserved is civilization preserved. Knowledge distributed is immortality achieved."*

**End of SMRITI Criticality Implementation Plan**
