defmodule Indrajaal.Smriti.Immortality.ReconstructionGuide do
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
  - Ψ₁ (Regeneration): Must be fully reconstructable from minimal state
  """

  @schema_version "1.0.0"

  @spec generate() :: {:ok, String.t()}
  def generate do
    guide =
      """
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
      |> String.trim()

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

      _ ->
        "Metrics unavailable"
    end
  end

  defp generate_topology do
    case Indrajaal.KMS.SmritiIntegration.get_metrics() do
      {:ok, metrics} ->
        clusters =
          metrics.clusters
          |> Enum.map(fn c -> "- **#{c.name}**: #{c.count} holons" end)
          |> Enum.join("\n")

        "### Clusters\n\n#{clusters}"

      _ ->
        "Topology unavailable"
    end
  end

  defp compute_db_checksum do
    case File.read("data/kms/smriti.db") do
      {:ok, data} ->
        :crypto.hash(:sha256, data) |> Base.encode16(case: :lower) |> String.slice(0, 16)

      _ ->
        "N/A"
    end
  end
end
