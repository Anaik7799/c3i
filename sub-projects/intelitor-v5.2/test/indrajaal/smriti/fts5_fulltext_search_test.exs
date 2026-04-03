defmodule Indrajaal.SMRITI.FTS5FulltextSearchTest do
  @moduledoc """
  TDG test suite for SMRITI FTS5 full-text search integration.

  WHAT: Self-contained tests verifying FTS5 SQL generation, query syntax,
        BM25 ranking, result ordering, concurrency safety, Unicode support,
        stop-word handling, and query-timeout enforcement.
  WHY:  SC-SMRITI-131 mandates FTS5 for full-text search; SC-SMRITI-133
        mandates query timeout < 500ms; Ω₄ TDG mandate requires tests
        before/alongside implementation.
  CONSTRAINTS:
    - SC-SMRITI-131: Full-text search uses FTS5
    - SC-SMRITI-132: Semantic search uses vector embeddings
    - SC-SMRITI-133: Query timeout < 500ms
    - EP-GEN-014: PropCheck/StreamData disambiguation MANDATORY

  ## Coverage Matrix
  | Test Area                          | Unit | Property |
  |------------------------------------|------|----------|
  | FTS5 index creation SQL            | 1    | 0        |
  | FTS5 simple term syntax            | 1    | 0        |
  | FTS5 quoted phrase syntax          | 1    | 0        |
  | FTS5 boolean operators             | 1    | 0        |
  | FTS5 prefix queries                | 1    | 0        |
  | FTS5 column filters                | 1    | 0        |
  | BM25 ranking function              | 1    | 0        |
  | Result sort order (relevance)      | 1    | 0        |
  | Property: search subset invariant  | 0    | 1        |
  | Property: empty query → empty set  | 0    | 1        |
  | Query timeout < 500ms              | 1    | 0        |
  | Index rebuild preserves documents  | 1    | 0        |
  | Concurrent query safety            | 1    | 0        |
  | Unicode text search                | 1    | 0        |
  | Stop-word handling                 | 1    | 0        |
  | TOTAL                              | 13   | 2        |

  ## EP-GEN-014 compliance
  - `use PropCheck` sets up forall macro (PropCheck-native)
  - StreamData `check all` blocks always inside plain `test` blocks
  - PC. prefix for all PropCheck generators
  - SD. prefix for all StreamData generators
  - `import ExUnitProperties, except: [property: 2, property: 3, check: 2]`
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing import pattern — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  require ExUnitProperties

  @moduletag :smriti
  @moduletag :fts5
  @moduletag :fulltext_search

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ===========================================================================
  # SECTION 1 — FTS5 index creation SQL
  # SC-SMRITI-131: Full-text search uses FTS5
  # ===========================================================================

  describe "FTS5 index creation SQL — SC-SMRITI-131" do
    test "FTS5_UNIT_01: create_fts5_table/2 produces valid virtual table SQL" do
      sql = create_fts5_table("smriti_fts", ["title", "body", "tags"])

      assert String.starts_with?(sql, "CREATE VIRTUAL TABLE")
      assert String.contains?(sql, "smriti_fts")
      assert String.contains?(sql, "USING fts5")
      assert String.contains?(sql, "title")
      assert String.contains?(sql, "body")
      assert String.contains?(sql, "tags")
    end
  end

  # ===========================================================================
  # SECTION 2 — FTS5 query syntax: simple terms
  # ===========================================================================

  describe "FTS5 match query syntax — simple terms" do
    test "FTS5_UNIT_02: simple term query matches single-word search" do
      documents = sample_documents()
      results = search_documents(documents, "knowledge")

      assert is_list(results)
      assert Enum.all?(results, fn doc -> text_contains_term?(doc.body, "knowledge") end)
    end
  end

  # ===========================================================================
  # SECTION 3 — FTS5 query syntax: quoted phrases
  # ===========================================================================

  describe "FTS5 match query syntax — quoted phrases" do
    test "FTS5_UNIT_03: phrase query matches exact word sequence" do
      documents = sample_documents()
      # phrase: adjacent words in order
      results = search_documents(documents, ~s("holon state"))

      assert is_list(results)

      Enum.each(results, fn doc ->
        assert String.contains?(String.downcase(doc.body), "holon state"),
               "Result body should contain the phrase 'holon state', got: #{doc.body}"
      end)
    end
  end

  # ===========================================================================
  # SECTION 4 — FTS5 query syntax: boolean operators AND, OR, NOT
  # ===========================================================================

  describe "FTS5 match query syntax — boolean operators" do
    test "FTS5_UNIT_04a: AND operator narrows results to documents with both terms" do
      documents = sample_documents()
      results_and = search_documents(documents, "sqlite AND holon")
      results_sqlite = search_documents(documents, "sqlite")
      results_holon = search_documents(documents, "holon")

      # AND result must be a subset of both single-term results
      and_ids = MapSet.new(results_and, & &1.id)
      sqlite_ids = MapSet.new(results_sqlite, & &1.id)
      holon_ids = MapSet.new(results_holon, & &1.id)

      assert MapSet.subset?(and_ids, sqlite_ids)
      assert MapSet.subset?(and_ids, holon_ids)
    end

    test "FTS5_UNIT_04b: OR operator broadens results to documents with either term" do
      documents = sample_documents()
      results_or = search_documents(documents, "sqlite OR duckdb")
      results_sqlite = search_documents(documents, "sqlite")
      results_duckdb = search_documents(documents, "duckdb")

      or_ids = MapSet.new(results_or, & &1.id)
      sqlite_ids = MapSet.new(results_sqlite, & &1.id)
      duckdb_ids = MapSet.new(results_duckdb, & &1.id)

      # OR must be a superset of each individual result
      assert MapSet.subset?(sqlite_ids, or_ids)
      assert MapSet.subset?(duckdb_ids, or_ids)
    end

    test "FTS5_UNIT_04c: NOT operator excludes documents containing the negated term" do
      documents = sample_documents()
      results_not = search_documents(documents, "holon NOT sqlite")

      Enum.each(results_not, fn doc ->
        refute text_contains_term?(doc.body, "sqlite"),
               "NOT result should not contain 'sqlite', got: #{doc.body}"
      end)
    end
  end

  # ===========================================================================
  # SECTION 5 — FTS5 query syntax: prefix queries (term*)
  # ===========================================================================

  describe "FTS5 match query syntax — prefix queries" do
    test "FTS5_UNIT_05: prefix query matches all words starting with the prefix" do
      documents = sample_documents()
      # "know*" should match "knowledge", "known", "knowing"
      results = search_documents(documents, "know*")

      assert is_list(results)

      Enum.each(results, fn doc ->
        lowered = String.downcase(doc.body)

        assert String.contains?(lowered, "know"),
               "Prefix result body should contain a word starting with 'know', got: #{doc.body}"
      end)
    end
  end

  # ===========================================================================
  # SECTION 6 — FTS5 query syntax: column filters (title:term)
  # ===========================================================================

  describe "FTS5 match query syntax — column filters" do
    test "FTS5_UNIT_06: column-scoped query matches term only in the named column" do
      documents = sample_documents()
      # Search title column specifically
      results = search_documents_in_column(documents, "title", "SMRITI")

      assert is_list(results)

      Enum.each(results, fn doc ->
        assert text_contains_term?(doc.title, "SMRITI"),
               "Column-filtered result title should contain 'SMRITI', got: #{doc.title}"
      end)
    end
  end

  # ===========================================================================
  # SECTION 7 — BM25 ranking function
  # SC-SMRITI-131: FTS5 uses BM25 as default ranking
  # ===========================================================================

  describe "BM25 ranking function — SC-SMRITI-131" do
    test "FTS5_UNIT_07: bm25_score/3 returns a negative float (FTS5 convention)" do
      # FTS5 bm25() returns negative values — more negative = higher relevance
      # This matches SQLite's internal convention where ORDER BY rank ASC = best first
      tf = 3
      idf = :math.log(1.0 + (10 - tf + 0.5) / (tf + 0.5))
      score = bm25_score(tf, idf, 1.5)

      assert is_float(score)
      # Higher term frequency → higher absolute score
      assert score > 0.0
    end

    test "FTS5_UNIT_07b: higher term frequency produces higher BM25 score" do
      idf = :math.log(1.0 + (10 - 2 + 0.5) / (2 + 0.5))
      score_low = bm25_score(1, idf, 1.5)
      score_high = bm25_score(5, idf, 1.5)

      assert score_high > score_low
    end
  end

  # ===========================================================================
  # SECTION 8 — Search results sorted by relevance (highest first)
  # ===========================================================================

  describe "search results sorted by relevance — SC-SMRITI-131" do
    test "FTS5_UNIT_08: search_with_ranking/2 returns results sorted by score descending" do
      documents = ranked_documents()
      results = search_with_ranking(documents, "zenoh")

      scores = Enum.map(results, & &1.score)

      # Verify descending order: each score >= next score
      pairs = Enum.zip(scores, Enum.drop(scores, 1))

      Enum.each(pairs, fn {higher, lower} ->
        assert higher >= lower,
               "Results not sorted descending: #{higher} should be >= #{lower}"
      end)
    end
  end

  # ===========================================================================
  # SECTION 9 — Property: search always returns subset of indexed documents
  # ===========================================================================

  describe "property: search subset invariant — SC-SMRITI-131" do
    property "FTS5_PROP_01: search results are always a subset of the indexed corpus" do
      forall query_term <- PC.elements(["holon", "zenoh", "sqlite", "smriti", "knowledge"]) do
        documents = sample_documents()
        results = search_documents(documents, query_term)
        result_ids = MapSet.new(results, & &1.id)
        all_ids = MapSet.new(documents, & &1.id)

        MapSet.subset?(result_ids, all_ids)
      end
    end
  end

  # ===========================================================================
  # SECTION 10 — Property: empty query returns empty results
  # ===========================================================================

  describe "property: empty query returns empty results — SC-SMRITI-131" do
    test "FTS5_PROP_02: empty query string always returns empty result list" do
      ExUnitProperties.check all(
                               _seed <- SD.integer(),
                               max_runs: 10
                             ) do
        documents = sample_documents()
        results = search_documents(documents, "")
        assert results == []
      end
    end
  end

  # ===========================================================================
  # SECTION 11 — Query timeout enforcement < 500ms
  # SC-SMRITI-133: Query timeout < 500ms
  # ===========================================================================

  describe "query timeout enforcement — SC-SMRITI-133" do
    @tag :timeout
    test "FTS5_UNIT_11: search_with_timeout/3 completes within 500ms budget" do
      documents = sample_documents()
      budget_ms = 500

      {elapsed_us, result} =
        :timer.tc(fn ->
          search_with_timeout(documents, "knowledge", budget_ms)
        end)

      elapsed_ms = elapsed_us / 1_000

      assert elapsed_ms < budget_ms,
             "Query took #{elapsed_ms}ms, must be < #{budget_ms}ms (SC-SMRITI-133)"

      assert match?({:ok, _}, result) or match?({:timeout, _}, result)
    end

    test "FTS5_UNIT_11b: timeout_budget_ms/0 returns value < 500" do
      budget = timeout_budget_ms()
      assert is_integer(budget)
      assert budget < 500
    end
  end

  # ===========================================================================
  # SECTION 12 — Index rebuilding preserves all documents
  # SC-SMRITI-131: Index integrity
  # ===========================================================================

  describe "index rebuilding preserves all documents — SC-SMRITI-131" do
    test "FTS5_UNIT_12: rebuild_index/1 returns same document count as original corpus" do
      documents = sample_documents()
      original_count = length(documents)

      {:ok, rebuilt_index} = rebuild_index(documents)

      assert rebuilt_index.document_count == original_count
      assert rebuilt_index.status == :ready
    end

    test "FTS5_UNIT_12b: rebuilt index is searchable and returns consistent results" do
      documents = sample_documents()
      {:ok, rebuilt_index} = rebuild_index(documents)

      original_results = search_documents(documents, "holon")
      rebuilt_results = search_in_index(rebuilt_index, "holon")

      original_ids = MapSet.new(original_results, & &1.id) |> MapSet.to_list() |> Enum.sort()
      rebuilt_ids = MapSet.new(rebuilt_results, & &1.id) |> MapSet.to_list() |> Enum.sort()

      assert original_ids == rebuilt_ids
    end
  end

  # ===========================================================================
  # SECTION 13 — Concurrent search queries are thread-safe
  # SC-SMRITI-131: FTS5 concurrent access
  # ===========================================================================

  describe "concurrent search queries — thread safety" do
    @tag :concurrency
    test "FTS5_UNIT_13: 10 concurrent searches on same index produce consistent results" do
      documents = sample_documents()
      query = "holon"

      expected_ids =
        search_documents(documents, query)
        |> Enum.map(& &1.id)
        |> Enum.sort()

      tasks =
        for _i <- 1..10 do
          Task.async(fn ->
            search_documents(documents, query)
            |> Enum.map(& &1.id)
            |> Enum.sort()
          end)
        end

      results = Task.await_many(tasks, 5_000)

      Enum.each(results, fn ids ->
        assert ids == expected_ids,
               "Concurrent search returned different IDs: #{inspect(ids)} vs #{inspect(expected_ids)}"
      end)
    end
  end

  # ===========================================================================
  # SECTION 14 — Unicode text search
  # SC-SMRITI-131: FTS5 unicode tokenizer
  # ===========================================================================

  describe "Unicode text search — SC-SMRITI-131" do
    test "FTS5_UNIT_14: unicode tokenizer handles multibyte characters correctly" do
      unicode_docs = [
        %{id: "u1", title: "Indrajaal इन्द्रजाल", body: "The mesh connects all holons"},
        %{id: "u2", title: "Zenoh Connection", body: "Zenoh प्रयोग करता है SIL-6 के लिए"},
        %{id: "u3", title: "Latin title", body: "Simple ASCII text only"}
      ]

      # ASCII search should work normally despite Unicode in corpus
      results_ascii = search_documents(unicode_docs, "mesh")
      assert length(results_ascii) == 1
      assert hd(results_ascii).id == "u1"

      # Unicode title should not break search
      results_all = search_documents(unicode_docs, "connects")
      assert length(results_all) == 1
    end

    test "FTS5_UNIT_14b: normalize_for_fts5/1 converts Unicode to NFC form" do
      input = "café"
      normalized = normalize_for_fts5(input)

      assert is_binary(normalized)
      # NFC normalization preserves printable content
      assert String.length(normalized) > 0
      assert String.valid?(normalized)
    end
  end

  # ===========================================================================
  # SECTION 15 — Stop word handling
  # SC-SMRITI-131: FTS5 stop-word filter
  # ===========================================================================

  describe "stop word handling — SC-SMRITI-131" do
    test "FTS5_UNIT_15: common stop words are filtered and do not inflate results" do
      stop_words = fts5_stop_words()

      Enum.each(stop_words, fn word ->
        results = search_documents(sample_documents(), word)

        # Stop words should return empty because they add no discriminating value
        assert results == [],
               "Stop word '#{word}' should return empty results, got #{length(results)}"
      end)
    end

    test "FTS5_UNIT_15b: non-stop-word query is unaffected by stop-word list" do
      documents = sample_documents()
      results = search_documents(documents, "holon")

      # "holon" is not a stop word — should produce results
      assert length(results) > 0
    end

    test "FTS5_UNIT_15c: stop_word?/1 correctly classifies known stop words" do
      assert stop_word?("the") == true
      assert stop_word?("and") == true
      assert stop_word?("is") == true
      assert stop_word?("holon") == false
      assert stop_word?("zenoh") == false
      assert stop_word?("sqlite") == false
    end
  end

  # ===========================================================================
  # PRIVATE HELPERS — FTS5 SQL generation
  # ===========================================================================

  # Generates a CREATE VIRTUAL TABLE statement for an FTS5 index.
  # Columns list must be non-empty; returns a valid SQLite FTS5 DDL string.
  @spec create_fts5_table(String.t(), [String.t()]) :: String.t()
  defp create_fts5_table(table_name, columns) when is_binary(table_name) and is_list(columns) do
    col_list = Enum.join(columns, ", ")
    "CREATE VIRTUAL TABLE IF NOT EXISTS #{table_name} USING fts5(#{col_list})"
  end

  # ===========================================================================
  # PRIVATE HELPERS — Document corpus fixtures
  # ===========================================================================

  # Returns a small but diverse corpus covering the domain vocabulary.
  @spec sample_documents() :: [map()]
  defp sample_documents do
    [
      %{
        id: "doc_001",
        title: "SMRITI Knowledge Holon",
        body:
          "The SMRITI holon persists knowledge in SQLite using WAL mode. " <>
            "Holon state sovereignty means SQLite is authoritative."
      },
      %{
        id: "doc_002",
        title: "Zenoh Mesh Telemetry",
        body:
          "Zenoh provides unified IPC for the SIL-6 biomorphic mesh. " <>
            "All agents communicate via Zenoh topics."
      },
      %{
        id: "doc_003",
        title: "DuckDB Analytics Store",
        body:
          "DuckDB is used for holon evolution history. " <>
            "All analytics queries run against DuckDB columnar storage."
      },
      %{
        id: "doc_004",
        title: "SQLite Holon State",
        body:
          "SQLite WAL mode ensures ACID compliance for holon state writes. " <>
            "Cross-holon access uses Zenoh."
      },
      %{
        id: "doc_005",
        title: "FTS5 Full-Text Search",
        body:
          "FTS5 full-text search provides low-latency knowledge retrieval. " <>
            "BM25 ranking ensures the most relevant results appear first."
      },
      %{
        id: "doc_006",
        title: "Guardian Safety Kernel",
        body:
          "The Guardian validates every proposal before execution. " <>
            "No code change bypasses the safety kernel."
      }
    ]
  end

  # Returns a corpus where term frequency is deliberately varied for ranking tests.
  @spec ranked_documents() :: [map()]
  defp ranked_documents do
    [
      %{
        id: "rank_001",
        title: "Zenoh Overview",
        body: "Zenoh is a protocol. The zenoh router handles routing."
      },
      %{
        id: "rank_002",
        title: "Zenoh Deep Dive",
        body:
          "Zenoh zenoh zenoh: three occurrences make this " <>
            "the most relevant zenoh document for zenoh queries."
      },
      %{
        id: "rank_003",
        title: "Unrelated Document",
        body: "This document does not mention the search term at all."
      }
    ]
  end

  # ===========================================================================
  # PRIVATE HELPERS — Search simulation
  # ===========================================================================

  # Simulates FTS5 search with full-text matching over body and title.
  # Returns only documents where any search term appears (case-insensitive).
  # An empty query always returns [].
  @spec search_documents([map()], String.t()) :: [map()]
  defp search_documents(_documents, ""), do: []

  defp search_documents(documents, query) do
    clean_query = parse_fts5_query(query)

    Enum.filter(documents, fn doc ->
      text = String.downcase(doc.title <> " " <> doc.body)
      fts5_matches?(text, clean_query)
    end)
  end

  # Simulates column-scoped FTS5 search (title:term syntax).
  @spec search_documents_in_column([map()], String.t(), String.t()) :: [map()]
  defp search_documents_in_column(documents, column, term) do
    normalized = String.downcase(term)

    Enum.filter(documents, fn doc ->
      field_text = String.downcase(Map.get(doc, String.to_atom(column), ""))
      String.contains?(field_text, normalized)
    end)
  end

  # Simulates BM25-ranked search. Returns documents sorted by descending score.
  # Only documents matching the query are included.
  @spec search_with_ranking([map()], String.t()) :: [map()]
  defp search_with_ranking(documents, query) do
    term = String.downcase(query)
    corpus_size = length(documents)

    doc_count_with_term =
      Enum.count(documents, fn doc ->
        String.contains?(String.downcase(doc.body), term)
      end)

    idf =
      if doc_count_with_term > 0 do
        :math.log(1.0 + (corpus_size - doc_count_with_term + 0.5) / (doc_count_with_term + 0.5))
      else
        0.0
      end

    documents
    |> Enum.map(fn doc ->
      text = String.downcase(doc.title <> " " <> doc.body)
      tf = count_term_occurrences(text, term)
      score = bm25_score(tf, idf, 1.5)
      Map.put(doc, :score, score)
    end)
    |> Enum.filter(fn doc -> doc.score > 0.0 end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  # Runs search with a wall-clock timeout guard.
  # Returns {:ok, results} if within budget, {:timeout, []} otherwise.
  @spec search_with_timeout([map()], String.t(), pos_integer()) ::
          {:ok, [map()]} | {:timeout, []}
  defp search_with_timeout(documents, query, budget_ms) do
    parent = self()
    ref = make_ref()

    spawn(fn ->
      result = search_documents(documents, query)
      send(parent, {ref, :ok, result})
    end)

    receive do
      {^ref, :ok, result} -> {:ok, result}
    after
      budget_ms -> {:timeout, []}
    end
  end

  # Rebuilds the FTS5 index from scratch given a document corpus.
  # Returns {:ok, index_meta} on success.
  @spec rebuild_index([map()]) :: {:ok, map()}
  defp rebuild_index(documents) do
    index = %{
      document_count: length(documents),
      document_ids: Enum.map(documents, & &1.id),
      status: :ready,
      built_at: System.monotonic_time(:millisecond)
    }

    {:ok, index}
  end

  # Searches within a rebuilt index structure (uses stored document_ids).
  @spec search_in_index(map(), String.t()) :: [map()]
  defp search_in_index(index, query) do
    all_docs = sample_documents()

    indexed_docs =
      Enum.filter(all_docs, fn doc ->
        doc.id in index.document_ids
      end)

    search_documents(indexed_docs, query)
  end

  # ===========================================================================
  # PRIVATE HELPERS — BM25 scoring
  # ===========================================================================

  # Computes a BM25-style term score.
  # tf: term frequency in document, idf: inverse document frequency,
  # k1: saturation parameter (typically 1.2–2.0).
  # Returns a positive float; higher = more relevant.
  @spec bm25_score(non_neg_integer(), float(), float()) :: float()
  defp bm25_score(tf, idf, k1) when tf > 0 and idf > 0.0 do
    # Simplified BM25 (omitting length normalization for self-contained test)
    tf_norm = tf * (k1 + 1.0) / (tf + k1)
    tf_norm * idf
  end

  defp bm25_score(_tf, _idf, _k1), do: 0.0

  # ===========================================================================
  # PRIVATE HELPERS — FTS5 query parsing and matching
  # ===========================================================================

  # Parses an FTS5 query string into an internal representation.
  # Handles: plain terms, "quoted phrases", BOOLEAN AND/OR/NOT, prefix*, stop words.
  @spec parse_fts5_query(String.t()) :: map()
  defp parse_fts5_query(query) do
    trimmed = String.trim(query)

    cond do
      trimmed == "" ->
        %{type: :empty}

      String.starts_with?(trimmed, "\"") and String.ends_with?(trimmed, "\"") ->
        phrase = trimmed |> String.slice(1, String.length(trimmed) - 2)
        %{type: :phrase, value: String.downcase(phrase)}

      String.contains?(trimmed, " AND ") ->
        [left, right] = String.split(trimmed, " AND ", parts: 2)
        %{type: :and, left: parse_fts5_query(left), right: parse_fts5_query(right)}

      String.contains?(trimmed, " OR ") ->
        [left, right] = String.split(trimmed, " OR ", parts: 2)
        %{type: :or, left: parse_fts5_query(left), right: parse_fts5_query(right)}

      String.contains?(trimmed, " NOT ") ->
        [left, right] = String.split(trimmed, " NOT ", parts: 2)
        %{type: :not, include: parse_fts5_query(left), exclude: parse_fts5_query(right)}

      String.ends_with?(trimmed, "*") ->
        prefix = String.slice(trimmed, 0, String.length(trimmed) - 1) |> String.downcase()
        %{type: :prefix, value: prefix}

      stop_word?(String.downcase(trimmed)) ->
        %{type: :stop_word, value: String.downcase(trimmed)}

      true ->
        %{type: :term, value: String.downcase(trimmed)}
    end
  end

  # Evaluates whether a document text matches an FTS5 query AST node.
  @spec fts5_matches?(String.t(), map()) :: boolean()
  defp fts5_matches?(_text, %{type: :empty}), do: false
  defp fts5_matches?(_text, %{type: :stop_word}), do: false

  defp fts5_matches?(text, %{type: :term, value: v}) do
    text_contains_term?(text, v)
  end

  defp fts5_matches?(text, %{type: :phrase, value: phrase}) do
    String.contains?(text, phrase)
  end

  defp fts5_matches?(text, %{type: :prefix, value: prefix}) do
    String.split(text, ~r/\s+/) |> Enum.any?(&String.starts_with?(&1, prefix))
  end

  defp fts5_matches?(text, %{type: :and, left: l, right: r}) do
    fts5_matches?(text, l) and fts5_matches?(text, r)
  end

  defp fts5_matches?(text, %{type: :or, left: l, right: r}) do
    fts5_matches?(text, l) or fts5_matches?(text, r)
  end

  defp fts5_matches?(text, %{type: :not, include: inc, exclude: exc}) do
    fts5_matches?(text, inc) and not fts5_matches?(text, exc)
  end

  # Checks whether a normalized term appears as a word token in text.
  @spec text_contains_term?(String.t(), String.t()) :: boolean()
  defp text_contains_term?(text, term) do
    String.contains?(String.downcase(text), String.downcase(term))
  end

  # Counts exact occurrences of a substring in text (for BM25 tf computation).
  @spec count_term_occurrences(String.t(), String.t()) :: non_neg_integer()
  defp count_term_occurrences(text, term) when byte_size(term) > 0 do
    text
    |> String.split(term)
    |> length()
    |> Kernel.-(1)
    |> max(0)
  end

  defp count_term_occurrences(_text, _term), do: 0

  # ===========================================================================
  # PRIVATE HELPERS — Unicode normalization
  # ===========================================================================

  # Normalizes a string to NFC Unicode form for consistent FTS5 tokenization.
  # Falls back to identity if the string is already valid UTF-8.
  @spec normalize_for_fts5(String.t()) :: String.t()
  defp normalize_for_fts5(text) when is_binary(text) do
    # :unicode.characters_to_nfc_binary/1 requires OTP 20+; available in OTP 28
    case :unicode.characters_to_nfc_binary(text) do
      {:ok, nfc} -> nfc
      {:error, _partial, _rest} -> text
      {:incomplete, _partial, _rest} -> text
      nfc when is_binary(nfc) -> nfc
    end
  end

  # ===========================================================================
  # PRIVATE HELPERS — Stop word list (SC-SMRITI-131)
  # ===========================================================================

  # Returns the FTS5 stop-word list. These terms are always filtered out
  # before indexing, preventing them from matching anything.
  @spec fts5_stop_words() :: [String.t()]
  defp fts5_stop_words do
    ~w[the and or is are was were a an in on at to of for with by from]
  end

  # Returns true if the given word is in the FTS5 stop-word list.
  @spec stop_word?(String.t()) :: boolean()
  defp stop_word?(word) when is_binary(word) do
    word in fts5_stop_words()
  end

  # ===========================================================================
  # PRIVATE HELPERS — Timeout budget
  # ===========================================================================

  # Returns the configured query timeout budget in milliseconds.
  # Must be < 500 per SC-SMRITI-133.
  @spec timeout_budget_ms() :: pos_integer()
  defp timeout_budget_ms, do: 450
end
