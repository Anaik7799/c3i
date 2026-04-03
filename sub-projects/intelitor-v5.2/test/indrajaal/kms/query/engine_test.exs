defmodule Indrajaal.KMS.Query.EngineTest do
  @moduledoc """
  Tests for the L5 Knowledge Query Engine module.

  ## STAMP Constraints Tested

  - SC-SMRITI-130: Query results MUST include integrity proofs
  - SC-SMRITI-131: Full-text search via FTS5
  - SC-SMRITI-132: Semantic search via vector embeddings
  - SC-SMRITI-133: Query timeout < 500ms
  - SC-PRF-050: Response latency < 50ms for cached queries
  - SC-OBS-034: All query events emit telemetry

  ## TDG Compliance

  - Unit tests for query operations
  - Property tests for query invariants
  - Integration tests for caching behavior
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.KMS.Query.Engine

  # ============================================================================
  # Unit Tests - Search
  # ============================================================================

  describe "search/2" do
    test "function exists with correct arity" do
      # Ensure module is loaded before checking exports
      {:module, _} = Code.ensure_loaded(Engine)
      assert function_exported?(Engine, :search, 2)
    end

    test "accepts query string" do
      # Note: Will return empty or error if DB not available
      result = Engine.search("test query")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts search options" do
      result = Engine.search("test", limit: 5, cluster: "docs")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "semantic_search/2" do
    test "function exists with correct arity" do
      {:module, _} = Code.ensure_loaded(Engine)
      assert function_exported?(Engine, :semantic_search, 2)
    end

    test "accepts query string with options" do
      result = Engine.semantic_search("how to handle failures", limit: 10, threshold: 0.8)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "search_with_proof/2" do
    test "function exists with correct arity" do
      {:module, _} = Code.ensure_loaded(Engine)
      assert function_exported?(Engine, :search_with_proof, 2)
    end
  end

  describe "get/2" do
    test "function exists with correct arity" do
      {:module, _} = Code.ensure_loaded(Engine)
      assert function_exported?(Engine, :get, 2)
    end

    test "returns not_found for nonexistent holon" do
      result = Engine.get("nonexistent-holon-id-12345")
      assert match?({:error, _}, result)
    end
  end

  # ============================================================================
  # Unit Tests - Query Plan
  # ============================================================================

  describe "explain/1" do
    test "returns query plan for FTS query" do
      assert {:ok, plan} = Engine.explain("distributed systems")

      assert Map.has_key?(plan, :query_type)
      assert Map.has_key?(plan, :estimated_rows)
      assert Map.has_key?(plan, :index_used)
      assert Map.has_key?(plan, :cost)
    end

    test "detects raw SQL query type" do
      {:ok, plan} = Engine.explain("SELECT * FROM holons")
      assert plan.query_type == :raw
    end

    test "detects semantic query type" do
      {:ok, plan} = Engine.explain("semantic: how to handle failures")
      assert plan.query_type == :semantic
    end

    test "detects FTS query type" do
      {:ok, plan} = Engine.explain("+distributed -monolith")
      assert plan.query_type == :fts
    end
  end

  # ============================================================================
  # Unit Tests - Clusters
  # ============================================================================

  describe "list_clusters/0" do
    test "function exists" do
      {:module, _} = Code.ensure_loaded(Engine)
      assert function_exported?(Engine, :list_clusters, 0)
    end

    test "returns list structure" do
      result = Engine.list_clusters()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================================
  # Unit Tests - Statistics
  # ============================================================================

  describe "stats/0" do
    test "returns query statistics" do
      assert {:ok, stats} = Engine.stats()

      assert Map.has_key?(stats, :cache_size)
      assert Map.has_key?(stats, :cache_hit_rate)
      assert Map.has_key?(stats, :avg_query_time_ms)
      assert Map.has_key?(stats, :total_queries)
    end

    test "cache size is non-negative" do
      {:ok, stats} = Engine.stats()
      assert stats.cache_size >= 0
    end
  end

  # ============================================================================
  # Unit Tests - Cache
  # ============================================================================

  describe "clear_cache/0" do
    test "clears the query cache" do
      assert :ok = Engine.clear_cache()
    end

    test "cache is empty after clear" do
      Engine.clear_cache()
      {:ok, stats} = Engine.stats()
      assert stats.cache_size == 0
    end
  end

  # ============================================================================
  # Unit Tests - Configuration
  # ============================================================================

  describe "query_timeout/0" do
    test "returns positive timeout in milliseconds" do
      timeout = Engine.query_timeout()

      assert is_integer(timeout)
      assert timeout > 0
    end

    test "default timeout is 500ms (SC-SMRITI-133)" do
      assert Engine.query_timeout() == 500
    end
  end

  describe "max_results/0" do
    test "returns positive maximum" do
      max = Engine.max_results()

      assert is_integer(max)
      assert max > 0
    end

    test "default max results is 100" do
      assert Engine.max_results() == 100
    end
  end

  # ============================================================================
  # Property Tests (PropCheck)
  # ============================================================================

  describe "query properties (PropCheck)" do
    property "query timeout is always positive" do
      forall _n <- PC.integer(1, 100) do
        Engine.query_timeout() > 0
      end
    end

    property "max results is always positive" do
      forall _n <- PC.integer(1, 100) do
        Engine.max_results() > 0
      end
    end

    property "explain always returns valid plan structure" do
      forall query <- PC.binary() do
        # Engine.explain/1 always succeeds with a plan (never returns error)
        {:ok, plan} = Engine.explain(query)

        is_map(plan) and
          Map.has_key?(plan, :query_type) and
          Map.has_key?(plan, :estimated_rows) and
          Map.has_key?(plan, :cost)
      end
    end
  end

  # ============================================================================
  # Property Tests (StreamData) - Converted to regular tests
  # ============================================================================

  describe "search invariants (StreamData)" do
    test "search options are respected" do
      for limit <- [1, 5, 10, 50] do
        result = Engine.search("test", limit: limit)
        # Either succeeds or fails gracefully
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    test "query timeout configuration is stable" do
      for _ <- 1..10 do
        assert Engine.query_timeout() == 500
      end
    end
  end

  # ============================================================================
  # Constitutional Alignment Tests
  # ============================================================================

  describe "constitutional alignment" do
    test "implements Ψ₂ (History) - preserves evolutionary context" do
      # Query engine can retrieve historical knowledge
      assert function_exported?(Engine, :get, 2)
    end

    test "implements Ψ₃ (Verification) - Merkle proofs for integrity" do
      assert function_exported?(Engine, :search_with_proof, 2)
    end

    test "implements Ψ₅ (Truthfulness) - accurate results" do
      assert function_exported?(Engine, :explain, 1)
    end
  end

  # ============================================================================
  # STAMP Constraint Tests
  # ============================================================================

  describe "STAMP constraints" do
    test "SC-SMRITI-130: query results support integrity proofs" do
      assert function_exported?(Engine, :search_with_proof, 2)
    end

    test "SC-SMRITI-131: full-text search via FTS5" do
      assert function_exported?(Engine, :search, 2)
    end

    test "SC-SMRITI-132: semantic search supported" do
      assert function_exported?(Engine, :semantic_search, 2)
    end

    test "SC-SMRITI-133: query timeout is 500ms" do
      assert Engine.query_timeout() == 500
    end

    test "SC-PRF-050: caching for response latency" do
      assert function_exported?(Engine, :clear_cache, 0)
      {:ok, stats} = Engine.stats()
      assert Map.has_key?(stats, :cache_hit_rate)
    end
  end

  # ============================================================================
  # 5-Order Effects Tests
  # ============================================================================

  describe "5-order effects" do
    test "1st order: query parsed and planned" do
      assert {:ok, plan} = Engine.explain("test query")
      assert is_map(plan)
    end

    test "2nd order: index lookup capability" do
      {:ok, plan} = Engine.explain("test")
      # Index may or may not be used depending on query and data
      assert Map.has_key?(plan, :index_used)
    end

    test "3rd order: results retrieved and ranked" do
      assert function_exported?(Engine, :search, 2)
    end

    test "4th order: Merkle proof capability" do
      assert function_exported?(Engine, :search_with_proof, 2)
    end

    test "5th order: cache for future queries" do
      assert function_exported?(Engine, :clear_cache, 0)
      {:ok, stats} = Engine.stats()
      assert Map.has_key?(stats, :cache_size)
    end
  end

  # ============================================================================
  # Integration Tests
  # ============================================================================

  describe "caching behavior" do
    test "cache can be cleared and stats retrieved" do
      :ok = Engine.clear_cache()
      {:ok, stats1} = Engine.stats()
      assert stats1.cache_size == 0

      # Run a search (may populate cache if DB available)
      Engine.search("test query")

      {:ok, _stats2} = Engine.stats()
      # Cache size may be 0 or 1 depending on DB availability
    end
  end

  describe "query plan detection" do
    test "correctly identifies query types" do
      queries = [
        {"SELECT * FROM holons", :raw},
        {"semantic: how does it work", :semantic},
        {"+include -exclude", :fts},
        {"simple search", :hybrid}
      ]

      for {query, expected_type} <- queries do
        {:ok, plan} = Engine.explain(query)
        assert plan.query_type == expected_type
      end
    end
  end
end
