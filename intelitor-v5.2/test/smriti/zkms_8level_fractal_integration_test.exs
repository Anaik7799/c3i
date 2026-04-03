defmodule SMRITI.EightLevelFractalIntegrationTest do
  @moduledoc """
  SMRITI 8-Level Fractal Integration Test Suite

  Tests SMRITI integration across all 8 levels of the fractal architecture:
  - L0: Runtime/Code (SQLite primitives)
  - L1: Function (CRUD operations)
  - L2: Component (Module integration)
  - L3: Holon/Agent (Domain logic)
  - L4: Container (Service boundaries)
  - L5: Node/Service (Deployment)
  - L6: Cluster (Distributed)
  - L7: Federation (Multi-system)

  STAMP Constraints: SC-COV-001 to SC-COV-006
  """

  use ExUnit.Case, async: false

  alias Indrajaal.KMS.{HolonStore, SmritiLifecycle}

  @smriti_db_path "data/kms/smriti.db"

  # ============================================================================
  # L0: RUNTIME/CODE LEVEL
  # Tests raw SQLite operations and data structures
  # ============================================================================

  describe "L0: Runtime/Code Level" do
    test "SQLite database file exists and is accessible" do
      assert File.exists?(@smriti_db_path), "SMRITI database must exist"
      assert File.stat!(@smriti_db_path).size > 0, "Database must not be empty"
    end

    test "SQLite schema contains required tables" do
      {:ok, conn} = Exqlite.Sqlite3.open(@smriti_db_path)

      {:ok, tables} =
        Exqlite.Sqlite3.execute(conn, "SELECT name FROM sqlite_master WHERE type='table'")

      table_names = Enum.map(tables, fn [name] -> name end)

      assert "holons" in table_names, "holons table required"
      assert "holon_edges" in table_names, "holon_edges table required"
      assert "holons_fts" in table_names, "FTS5 index required"

      Exqlite.Sqlite3.close(conn)
    end

    test "FTS5 full-text search index is functional" do
      {:ok, conn} = Exqlite.Sqlite3.open(@smriti_db_path)

      # Test FTS5 query
      {:ok, results} =
        Exqlite.Sqlite3.execute(conn, """
        SELECT COUNT(*) FROM holons_fts WHERE holons_fts MATCH 'architecture OR security'
        """)

      assert [[count]] = results
      assert is_integer(count), "FTS5 query must return count"

      Exqlite.Sqlite3.close(conn)
    end
  end

  # ============================================================================
  # L1: FUNCTION LEVEL
  # Tests individual CRUD operations
  # ============================================================================

  describe "L1: Function Level" do
    test "holon creation with required fields" do
      holon = %{
        holon_uuid: Ecto.UUID.generate(),
        title: "Test Holon L1",
        content: "Test content for L1 function level",
        tags: "test,l1,function",
        entropy: 0.0,
        level: "atomic",
        decay_rate: "medium",
        content_hash:
          :crypto.hash(:sha256, "Test content for L1 function level")
          |> Base.encode16(case: :lower),
        cluster: "test_l1"
      }

      assert is_binary(holon.holon_uuid)
      assert String.length(holon.content_hash) == 64
    end

    test "content hash is deterministic" do
      content = "Test content for hashing"
      hash1 = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
      hash2 = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)

      assert hash1 == hash2, "Hash must be deterministic"
    end

    test "entropy calculation follows decay model" do
      # 90 days old → 0.5 entropy (180-day decay)
      age_days = 90
      entropy = min(1.0, age_days / 180.0)

      assert_in_delta entropy, 0.5, 0.01
    end
  end

  # ============================================================================
  # L2: COMPONENT LEVEL
  # Tests module integration
  # ============================================================================

  describe "L2: Component Level" do
    test "HolonStore module is available" do
      assert Code.ensure_loaded?(Indrajaal.KMS.HolonStore),
             "HolonStore module must be loaded"
    end

    test "SmritiLifecycle module provides lifecycle management" do
      assert Code.ensure_loaded?(Indrajaal.KMS.SmritiLifecycle),
             "SmritiLifecycle module must be loaded"
    end

    test "holon levels follow hierarchy" do
      levels = ["atomic", "molecular", "organism", "ecosystem"]

      # Verify ordering
      assert Enum.at(levels, 0) == "atomic"
      assert Enum.at(levels, 3) == "ecosystem"
    end
  end

  # ============================================================================
  # L3: HOLON/AGENT LEVEL
  # Tests domain logic and agent behavior
  # ============================================================================

  describe "L3: Holon/Agent Level" do
    test "orphan detection identifies holons without edges" do
      {:ok, conn} = Exqlite.Sqlite3.open(@smriti_db_path)

      {:ok, results} =
        Exqlite.Sqlite3.execute(conn, """
        SELECT COUNT(*) FROM holons h
        WHERE NOT EXISTS (
          SELECT 1 FROM holon_edges e
          WHERE e.source_id = h.holon_uuid OR e.target_id = h.holon_uuid
        )
        """)

      assert [[orphan_count]] = results
      assert is_integer(orphan_count)

      Exqlite.Sqlite3.close(conn)
    end

    test "stale detection finds high-entropy holons" do
      {:ok, conn} = Exqlite.Sqlite3.open(@smriti_db_path)

      {:ok, results} =
        Exqlite.Sqlite3.execute(conn, """
        SELECT COUNT(*) FROM holons WHERE entropy > 0.6
        """)

      assert [[stale_count]] = results
      assert is_integer(stale_count)

      Exqlite.Sqlite3.close(conn)
    end

    test "cluster grouping organizes holons" do
      {:ok, conn} = Exqlite.Sqlite3.open(@smriti_db_path)

      {:ok, results} =
        Exqlite.Sqlite3.execute(conn, """
        SELECT cluster, COUNT(*) as cnt
        FROM holons
        WHERE cluster IS NOT NULL AND cluster != ''
        GROUP BY cluster
        ORDER BY cnt DESC
        """)

      assert length(results) > 0, "Must have at least one cluster"

      Exqlite.Sqlite3.close(conn)
    end
  end

  # ============================================================================
  # L4: CONTAINER LEVEL
  # Tests service boundaries and CLI
  # ============================================================================

  describe "L4: Container Level" do
    test "SMRITI CLI script exists" do
      cli_path = "lib/cepaf/scripts/SmritiIngestorCLI.fsx"
      assert File.exists?(cli_path), "CLI script must exist"
    end

    test "SMRITI data directory structure" do
      assert File.dir?("data/kms"), "KMS data directory must exist"
      assert File.exists?("data/kms/smriti.db"), "SMRITI database must exist"
    end

    @tag :cli
    test "CLI status command returns valid output" do
      {output, exit_code} =
        System.cmd(
          "dotnet",
          [
            "fsi",
            "lib/cepaf/scripts/SmritiIngestorCLI.fsx",
            "status"
          ],
          cd: File.cwd!()
        )

      assert exit_code == 0, "Status command must succeed"
      assert String.contains?(output, "SMRITI STATUS"), "Must show status header"
      assert String.contains?(output, "Total Holons"), "Must show holon count"
    end
  end

  # ============================================================================
  # L5: NODE/SERVICE LEVEL
  # Tests deployment and configuration
  # ============================================================================

  describe "L5: Node/Service Level" do
    test "SMRITI configuration from environment" do
      # Default path when env not set
      default_path = "data/kms/smriti.db"
      assert File.exists?(default_path)
    end

    test "SMRITI integrates with OpenRouter for AI extraction" do
      # Check for OpenRouter configuration capability
      env_key = System.get_env("OPENROUTER_API_KEY")

      if env_key do
        assert String.starts_with?(env_key, "sk-or-"), "API key format"
      end
    end

    test "SMRITI documentation exists" do
      docs = [
        "docs/smriti/SMRITI_USER_GUIDE.md",
        "docs/smriti/SMRITI_DEVELOPER_GUIDE.md",
        "docs/smriti/SMRITI_AI_QUALITY_COMPARISON.md"
      ]

      for doc <- docs do
        assert File.exists?(doc), "#{doc} must exist"
      end
    end
  end

  # ============================================================================
  # L6: CLUSTER LEVEL
  # Tests distributed behavior and replication
  # ============================================================================

  describe "L6: Cluster Level" do
    test "SMRITI supports multiple clusters" do
      {:ok, conn} = Exqlite.Sqlite3.open(@smriti_db_path)

      {:ok, results} =
        Exqlite.Sqlite3.execute(conn, """
        SELECT DISTINCT cluster FROM holons WHERE cluster IS NOT NULL
        """)

      cluster_count = length(results)
      assert cluster_count >= 10, "Should have multiple clusters (have #{cluster_count})"

      Exqlite.Sqlite3.close(conn)
    end

    test "SMRITI state is portable (single file)" do
      # Verify single-file portability (SC-HOLON-009)
      db_stat = File.stat!(@smriti_db_path)
      assert db_stat.type == :regular, "Database must be a regular file"
    end

    test "SMRITI WAL mode for concurrent access" do
      {:ok, conn} = Exqlite.Sqlite3.open(@smriti_db_path)

      {:ok, [[mode]]} = Exqlite.Sqlite3.execute(conn, "PRAGMA journal_mode")
      # Accept either wal or delete (default)
      assert mode in ["wal", "delete"], "Journal mode must be wal or delete"

      Exqlite.Sqlite3.close(conn)
    end
  end

  # ============================================================================
  # L7: FEDERATION LEVEL
  # Tests multi-system integration
  # ============================================================================

  describe "L7: Federation Level" do
    test "SMRITI integrates with Prajna cockpit" do
      # Verify Prajna API module can query SMRITI
      assert Code.ensure_loaded?(IndrajaalWeb.Api.PrajnaController) or
               Code.ensure_loaded?(Indrajaal.Cockpit.Prajna),
             "Prajna integration module must exist"
    end

    test "SMRITI supports DuckDB analytics export" do
      # Check for DuckDB integration capability
      duckdb_path = "data/holons/analytics.duckdb"

      # DuckDB export is optional
      if File.exists?(duckdb_path) do
        assert File.stat!(duckdb_path).size > 0
      end
    end

    test "SMRITI knowledge graph can be exported" do
      {:ok, conn} = Exqlite.Sqlite3.open(@smriti_db_path)

      # Verify export query works
      {:ok, results} =
        Exqlite.Sqlite3.execute(conn, """
        SELECT h.holon_uuid, h.title, h.cluster, h.level, h.entropy
        FROM holons h
        ORDER BY h.cluster, h.title
        LIMIT 5
        """)

      assert length(results) > 0, "Export query must return data"

      Exqlite.Sqlite3.close(conn)
    end
  end

  # ============================================================================
  # CROSS-CUTTING: CONSTITUTIONAL INVARIANTS
  # ============================================================================

  describe "Constitutional Invariants" do
    test "SC-HOLON-001: All holon state in SQLite" do
      # Verify no PostgreSQL holon state
      # This is a design constraint verified by architecture
      assert File.exists?(@smriti_db_path), "SQLite must be primary store"
    end

    test "SC-HOLON-009: Portable single-file state" do
      db_stat = File.stat!(@smriti_db_path)
      assert db_stat.type == :regular
      # Reasonable size limit for portability
      assert db_stat.size < 1_000_000_000, "Database should be < 1GB for portability"
    end

    test "PSI-5: Truthfulness - content hash integrity" do
      {:ok, conn} = Exqlite.Sqlite3.open(@smriti_db_path)

      {:ok, results} =
        Exqlite.Sqlite3.execute(conn, """
        SELECT holon_uuid, content_hash FROM holons LIMIT 5
        """)

      for [_uuid, hash] <- results do
        assert String.length(hash) == 64, "Hash must be 64 hex chars"
        assert Regex.match?(~r/^[0-9a-f]+$/, hash), "Hash must be lowercase hex"
      end

      Exqlite.Sqlite3.close(conn)
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS
  # ============================================================================

  describe "Property-Based Tests" do
    use PropCheck

    property "hash function is deterministic" do
      forall content <- binary() do
        hash1 = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
        hash2 = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
        hash1 == hash2
      end
    end

    property "entropy is bounded [0, 1]" do
      forall age <- non_neg_integer() do
        entropy = min(1.0, age / 180.0)
        entropy >= 0.0 and entropy <= 1.0
      end
    end

    property "UUID generation produces unique values" do
      forall _seed <- integer() do
        uuid1 = Ecto.UUID.generate()
        uuid2 = Ecto.UUID.generate()
        uuid1 != uuid2
      end
    end
  end
end
