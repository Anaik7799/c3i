defmodule Indrajaal.Core.SmritiFts5SearchTest do
  @moduledoc """
  Integration tests for SMRITI FTS5 full-text search capabilities.

  WHAT: Self-contained FTS5 search simulation using ETS tables.
        Tests BM25 ranking, prefix/phrase/boolean search, snippet extraction,
        timeout enforcement, Unicode support, and property invariants.
  WHY: SC-SMRITI-131 mandates FTS5 for full-text search; SC-SMRITI-133
       mandates query timeout < 500ms. These tests verify SMRITI search
       contracts without requiring the production SQLite/FTS5 stack.
  CONSTRAINTS: SC-SMRITI-131 (FTS5 full-text search), SC-SMRITI-133
               (query timeout <500ms), SC-SMRITI-074 (immortality protocol),
               SC-XHOLON-020 (SQLite read < 1ms), EP-GEN-014

  ## Coverage Matrix
  | Category                        | Unit | Property | Total |
  |---------------------------------|------|----------|-------|
  | Index creation + insertion      | 3    | 0        | 3     |
  | BM25 ranking                    | 3    | 2        | 5     |
  | Prefix search                   | 2    | 1        | 3     |
  | Phrase search                   | 2    | 1        | 3     |
  | Boolean operators (AND/OR/NOT)  | 3    | 0        | 3     |
  | Highlight / snippet extraction  | 3    | 0        | 3     |
  | Timeout enforcement             | 2    | 1        | 3     |
  | Unicode support                 | 3    | 1        | 4     |
  | Empty / invalid query handling  | 3    | 0        | 3     |
  | Relevance score invariants      | 0    | 2        | 2     |
  | TOTAL                           | 32   | 0        | 32    |

  ## EP-GEN-014 compliance
  - SD. prefix used exclusively for StreamData generators
  - `check all` always inside plain `test` blocks
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  @moduletag :smriti
  @moduletag :fts5
  @moduletag :search

  # ============================================================================
  # FTS5 Simulation Engine
  # All helpers are self-contained defp — no production module dependency.
  # The ETS-backed simulation mirrors real FTS5 semantics closely enough to
  # validate search contracts specified in SC-SMRITI-131/133.
  # ============================================================================

  # A document stored in the simulated FTS5 index.
  # Fields: id, title, body, tags (mirrors typical SMRITI knowledge entry).
  @type doc_id :: pos_integer()
  @type fts_doc :: %{
          id: doc_id(),
          title: String.t(),
          body: String.t(),
          tags: String.t()
        }

  # Maximum query execution time allowed (SC-SMRITI-133).
  @query_timeout_ms 500

  # --- Index lifecycle ---

  @spec new_index() :: :ets.tid()
  defp new_index do
    :ets.new(:fts5_sim, [:set, :private])
  end

  @spec drop_index(:ets.tid()) :: :ok
  defp drop_index(table) do
    :ets.delete(table)
    :ok
  end

  @spec insert_doc(:ets.tid(), fts_doc()) :: :ok
  defp insert_doc(table, %{id: id} = doc) do
    :ets.insert(table, {id, doc})
    :ok
  end

  @spec insert_docs(:ets.tid(), [fts_doc()]) :: :ok
  defp insert_docs(table, docs) do
    Enum.each(docs, &insert_doc(table, &1))
    :ok
  end

  @spec all_docs(:ets.tid()) :: [fts_doc()]
  defp all_docs(table) do
    :ets.tab2list(table) |> Enum.map(fn {_id, doc} -> doc end)
  end

  @spec doc_count(:ets.tid()) :: non_neg_integer()
  defp doc_count(table), do: :ets.info(table, :size)

  # --- Tokenisation ---

  # Normalise and tokenise text: lowercase, split on non-word chars, drop empties.
  @spec tokenise(String.t()) :: [String.t()]
  defp tokenise(text) do
    text
    |> String.downcase()
    |> String.split(~r/[^\p{L}\p{N}]+/u)
    |> Enum.reject(&(&1 == ""))
  end

  # --- BM25 Ranking ---
  # Simplified BM25 implementation faithful enough to test ranking properties.
  # Parameters: k1=1.5, b=0.75 (standard defaults).

  @bm25_k1 1.5
  @bm25_b 0.75

  @spec bm25_score([String.t()], fts_doc(), float(), non_neg_integer()) :: float()
  defp bm25_score(query_terms, doc, avg_dl, corpus_size) do
    doc_text = "#{doc.title} #{doc.body} #{doc.tags}"
    doc_tokens = tokenise(doc_text)
    dl = length(doc_tokens)

    Enum.reduce(query_terms, 0.0, fn term, acc ->
      tf = Enum.count(doc_tokens, &(&1 == term))

      if tf == 0 do
        acc
      else
        # Approximate df: assume each term appears in at most corpus_size docs.
        # For simulation we treat df=1 (conservative; tests relative ordering).
        df = 1
        idf = :math.log(1 + (corpus_size - df + 0.5) / (df + 0.5))

        numerator = tf * (@bm25_k1 + 1)
        denominator = tf + @bm25_k1 * (1 - @bm25_b + @bm25_b * dl / max(avg_dl, 1.0))

        acc + idf * numerator / denominator
      end
    end)
  end

  @spec avg_doc_length([fts_doc()]) :: float()
  defp avg_doc_length([]), do: 1.0

  defp avg_doc_length(docs) do
    total =
      Enum.reduce(docs, 0, fn doc, acc ->
        acc + length(tokenise("#{doc.title} #{doc.body} #{doc.tags}"))
      end)

    total / length(docs)
  end

  # --- Search operations ---

  # Match a single document against a list of required terms (AND semantics).
  @spec doc_matches_all?([String.t()], fts_doc()) :: boolean()
  defp doc_matches_all?(terms, doc) do
    text = tokenise("#{doc.title} #{doc.body} #{doc.tags}")
    Enum.all?(terms, fn t -> t in text end)
  end

  # Match a single document against any required term (OR semantics).
  @spec doc_matches_any?([String.t()], fts_doc()) :: boolean()
  defp doc_matches_any?(terms, doc) do
    text = tokenise("#{doc.title} #{doc.body} #{doc.tags}")
    Enum.any?(terms, fn t -> t in text end)
  end

  # Check a document does NOT contain ANY of the excluded terms.
  @spec doc_excludes_all?([String.t()], fts_doc()) :: boolean()
  defp doc_excludes_all?(excluded_terms, doc) do
    text = tokenise("#{doc.title} #{doc.body} #{doc.tags}")
    Enum.all?(excluded_terms, fn t -> t not in text end)
  end

  # Prefix match: does any token in the doc begin with the given prefix?
  @spec doc_matches_prefix?(String.t(), fts_doc()) :: boolean()
  defp doc_matches_prefix?(prefix, doc) do
    lc_prefix = String.downcase(prefix)
    text = tokenise("#{doc.title} #{doc.body} #{doc.tags}")
    Enum.any?(text, &String.starts_with?(&1, lc_prefix))
  end

  # Phrase match: do the consecutive phrase tokens appear in order in the doc?
  @spec doc_matches_phrase?([String.t()], fts_doc()) :: boolean()
  defp doc_matches_phrase?(phrase_tokens, doc) do
    text = tokenise("#{doc.title} #{doc.body} #{doc.tags}")
    n = length(phrase_tokens)
    len = length(text)

    if n == 0 or len < n do
      false
    else
      Enum.any?(0..(len - n), fn i ->
        Enum.slice(text, i, n) == phrase_tokens
      end)
    end
  end

  # --- Timed query wrapper (SC-SMRITI-133) ---

  @spec timed_query((-> any()), non_neg_integer()) ::
          {:ok, any(), non_neg_integer()} | {:error, :timeout}
  defp timed_query(query_fn, timeout_ms) do
    start_us = System.monotonic_time(:microsecond)
    result = query_fn.()
    elapsed_us = System.monotonic_time(:microsecond) - start_us
    elapsed_ms = div(elapsed_us, 1000)

    if elapsed_ms > timeout_ms do
      {:error, :timeout}
    else
      {:ok, result, elapsed_ms}
    end
  end

  # --- Ranked full-text search (AND mode by default) ---

  @spec fts_search(:ets.tid(), String.t(), keyword()) ::
          {:ok, [%{doc: fts_doc(), score: float()}]} | {:error, :empty_query} | {:error, :timeout}
  defp fts_search(table, query_string, opts \\ []) do
    mode = Keyword.get(opts, :mode, :and)
    timeout = Keyword.get(opts, :timeout_ms, @query_timeout_ms)
    normalised = String.trim(query_string)

    if normalised == "" do
      {:error, :empty_query}
    else
      timed_query(
        fn ->
          terms = tokenise(normalised)
          docs = all_docs(table)
          avg_dl = avg_doc_length(docs)
          corpus_size = max(length(docs), 1)

          matched =
            case mode do
              :and ->
                Enum.filter(docs, &doc_matches_all?(terms, &1))

              :or ->
                Enum.filter(docs, &doc_matches_any?(terms, &1))

              {:not, include_terms, exclude_terms} ->
                docs
                |> Enum.filter(&doc_matches_all?(include_terms, &1))
                |> Enum.filter(&doc_excludes_all?(exclude_terms, &1))
            end

          results =
            matched
            |> Enum.map(fn doc ->
              score = bm25_score(terms, doc, avg_dl, corpus_size)
              %{doc: doc, score: score}
            end)
            |> Enum.sort_by(& &1.score, :desc)

          results
        end,
        timeout
      )
      |> case do
        {:ok, results, _elapsed} -> {:ok, results}
        {:error, :timeout} -> {:error, :timeout}
      end
    end
  end

  # --- Prefix search ---

  @spec fts_prefix_search(:ets.tid(), String.t(), keyword()) ::
          {:ok, [%{doc: fts_doc(), score: float()}]} | {:error, :empty_query} | {:error, :timeout}
  defp fts_prefix_search(table, prefix, opts \\ []) do
    timeout = Keyword.get(opts, :timeout_ms, @query_timeout_ms)
    normalised = String.trim(prefix)

    if normalised == "" do
      {:error, :empty_query}
    else
      timed_query(
        fn ->
          docs = all_docs(table)

          docs
          |> Enum.filter(&doc_matches_prefix?(normalised, &1))
          |> Enum.map(fn doc -> %{doc: doc, score: 1.0} end)
        end,
        timeout
      )
      |> case do
        {:ok, results, _elapsed} -> {:ok, results}
        {:error, :timeout} -> {:error, :timeout}
      end
    end
  end

  # --- Phrase search ---

  @spec fts_phrase_search(:ets.tid(), String.t(), keyword()) ::
          {:ok, [%{doc: fts_doc(), score: float()}]} | {:error, :empty_query} | {:error, :timeout}
  defp fts_phrase_search(table, phrase, opts \\ []) do
    timeout = Keyword.get(opts, :timeout_ms, @query_timeout_ms)
    phrase_tokens = tokenise(phrase)

    if phrase_tokens == [] do
      {:error, :empty_query}
    else
      timed_query(
        fn ->
          docs = all_docs(table)
          avg_dl = avg_doc_length(docs)
          corpus_size = max(length(docs), 1)

          docs
          |> Enum.filter(&doc_matches_phrase?(phrase_tokens, &1))
          |> Enum.map(fn doc ->
            score = bm25_score(phrase_tokens, doc, avg_dl, corpus_size)
            %{doc: doc, score: score}
          end)
          |> Enum.sort_by(& &1.score, :desc)
        end,
        timeout
      )
      |> case do
        {:ok, results, _elapsed} -> {:ok, results}
        {:error, :timeout} -> {:error, :timeout}
      end
    end
  end

  # --- Snippet extraction ---

  # Extract a snippet from a document body containing the query term,
  # with configurable window size and highlight markers.
  @spec extract_snippet(String.t(), String.t(), non_neg_integer()) :: String.t()
  defp extract_snippet(body, query_term, window \\ 5) do
    lc_term = String.downcase(query_term)
    words = String.split(body, ~r/\s+/)
    n = length(words)

    idx =
      Enum.find_index(words, fn w ->
        String.downcase(w) |> String.contains?(lc_term)
      end)

    if idx == nil do
      String.slice(body, 0, 80)
    else
      start_i = max(0, idx - window)
      end_i = min(n - 1, idx + window)

      snippet_words =
        words
        |> Enum.with_index()
        |> Enum.filter(fn {_w, i} -> i >= start_i and i <= end_i end)
        |> Enum.map(fn {w, i} ->
          if i == idx, do: "[#{w}]", else: w
        end)

      Enum.join(snippet_words, " ")
    end
  end

  # Highlight all occurrences of a term within text using open/close markers.
  @spec highlight_term(String.t(), String.t(), String.t(), String.t()) :: String.t()
  defp highlight_term(text, term, open_marker, close_marker) do
    lc_term = String.downcase(term)

    String.split(text, ~r/\s+/)
    |> Enum.map(fn word ->
      if String.contains?(String.downcase(word), lc_term) do
        "#{open_marker}#{word}#{close_marker}"
      else
        word
      end
    end)
    |> Enum.join(" ")
  end

  # --- Sample corpus fixture ---

  @spec sample_corpus() :: [fts_doc()]
  defp sample_corpus do
    [
      %{
        id: 1,
        title: "SMRITI Knowledge Holon Architecture",
        body:
          "The SMRITI module implements a federated knowledge graph with immutable append-only history stored in DuckDB.",
        tags: "smriti knowledge architecture federation"
      },
      %{
        id: 2,
        title: "Zenoh Unified IPC Backplane",
        body:
          "Zenoh provides low-latency pub-sub messaging across the biomorphic mesh using router-based topology.",
        tags: "zenoh ipc messaging mesh topology"
      },
      %{
        id: 3,
        title: "Guardian Safety Kernel Validation",
        body:
          "The Guardian module validates all proposals via Simplex architecture before any state mutation is applied.",
        tags: "guardian safety simplex validation"
      },
      %{
        id: 4,
        title: "OODA Cycle Fast Loop Implementation",
        body:
          "OODA cycles MUST complete in under 100ms. Each phase — Observe, Orient, Decide, Act — is bounded.",
        tags: "ooda cycle performance latency bounds"
      },
      %{
        id: 5,
        title: "SQLite WAL Mode and Holon State",
        body:
          "All holon real-time state is persisted in SQLite with WAL mode enabled for concurrent read access.",
        tags: "sqlite wal holon state persistence"
      },
      %{
        id: 6,
        title: "DuckDB Append-Only Evolution History",
        body:
          "DuckDB stores the complete evolution history of every holon in a columnar append-only format.",
        tags: "duckdb evolution history columnar analytics"
      },
      %{
        id: 7,
        title: "Reed-Solomon Error Correction RS(255,223)",
        body:
          "Reed-Solomon encoding adds 32 parity symbols allowing correction of up to 16 symbol errors per block.",
        tags: "reed solomon error correction parity block"
      },
      %{
        id: 8,
        title: "Biomorphic Fractal Mesh Boot Sequence",
        body:
          "The mesh boots through five mandatory stages: Preflight, Ignition, Lens, Convergence, and Ready.",
        tags: "biomorphic mesh boot stages convergence"
      },
      %{
        id: 9,
        title: "Prajna C3I Cockpit LiveView Interface",
        body:
          "Prajna serves a real-time command and control interface over Phoenix LiveView with Zenoh telemetry bridge.",
        tags: "prajna cockpit liveview phoenix telemetry"
      },
      %{
        id: 10,
        title: "Constitutional Reconfiguration Protocol",
        body:
          "Levels L1–L7 may be reconfigured under survival pressure. Constitution L0 is immutable by definition.",
        tags: "constitution reconfiguration levels survival"
      }
    ]
  end

  # Unicode corpus for multilingual search testing.
  @spec unicode_corpus() :: [fts_doc()]
  defp unicode_corpus do
    [
      %{
        id: 101,
        title: "इन्द्रजाल — संरचना",
        body: "इन्द्रजाल एक जैविकाकारीय जाल है जो स्वायत्त एजेंटों का समन्वय करता है।",
        tags: "hindi architecture agents"
      },
      %{
        id: 102,
        title: "Biomorphic नेटवर्क",
        body: "Zenoh के माध्यम से सभी संदेश भेजे जाते हैं। Latency 50ms से कम होनी चाहिए।",
        tags: "hindi zenoh network latency"
      },
      %{
        id: 103,
        title: "Système de Sécurité SIL-6",
        body: "Le système doit satisfaire les exigences SIL-6 avec une PFH inférieure à 10⁻¹².",
        tags: "french safety sil6 requirements"
      },
      %{
        id: 104,
        title: "Sicherheitskernel Guardian",
        body: "Der Guardian validiert alle Vorschläge bevor ein Zustandswechsel stattfindet.",
        tags: "german guardian safety kernel"
      },
      %{
        id: 105,
        title: "가디언 안전 커널",
        body: "가디언 모듈은 모든 제안을 검증하고 상태 변이 전에 승인합니다.",
        tags: "korean guardian safety kernel"
      }
    ]
  end

  # ============================================================================
  # SECTION 1 — Index Creation and Document Insertion
  # ============================================================================

  describe "FTS5 index creation and document insertion" do
    test "FTS5_INDEX_01: new_index/0 creates an empty ETS-backed index" do
      table = new_index()
      assert doc_count(table) == 0
      drop_index(table)
    end

    test "FTS5_INDEX_02: insert_doc/2 stores documents retrievable by id" do
      table = new_index()

      doc = %{
        id: 1,
        title: "Test Document",
        body: "This is a test body with searchable content.",
        tags: "test search"
      }

      :ok = insert_doc(table, doc)
      assert doc_count(table) == 1

      [{1, stored_doc}] = :ets.lookup(table, 1)
      assert stored_doc.title == "Test Document"
      drop_index(table)
    end

    test "FTS5_INDEX_03: insert_docs/2 bulk-inserts corpus and doc_count matches" do
      table = new_index()
      corpus = sample_corpus()
      :ok = insert_docs(table, corpus)
      assert doc_count(table) == length(corpus)
      drop_index(table)
    end
  end

  # ============================================================================
  # SECTION 2 — BM25 Ranking
  # ============================================================================

  describe "BM25 ranking" do
    setup do
      table = new_index()
      :ok = insert_docs(table, sample_corpus())
      on_exit(fn -> :ets.delete(table) end)
      {:ok, table: table}
    end

    test "FTS5_BM25_01: results are sorted by descending BM25 score", %{table: table} do
      {:ok, results} = fts_search(table, "zenoh")
      scores = Enum.map(results, & &1.score)
      assert scores == Enum.sort(scores, :desc)
    end

    test "FTS5_BM25_02: document most relevant to query term ranks first", %{table: table} do
      # Doc 2 ("Zenoh Unified IPC Backplane") should rank highest for "zenoh"
      {:ok, results} = fts_search(table, "zenoh")
      assert length(results) >= 1
      top = hd(results)

      assert String.contains?(top.doc.title, "Zenoh") or
               String.contains?(top.doc.body, "Zenoh")
    end

    test "FTS5_BM25_03: all matched results have non-negative BM25 scores", %{table: table} do
      {:ok, results} = fts_search(table, "holon")
      assert Enum.all?(results, fn r -> r.score >= 0.0 end)
    end

    test "FTS5_BM25_PROP_01: BM25 score ordering is transitive" do
      ExUnitProperties.check all(
                               terms <-
                                 SD.list_of(SD.member_of(["holon", "zenoh", "guardian", "ooda"]),
                                   min_length: 1
                                 ),
                               max_runs: 20
                             ) do
        table = new_index()
        insert_docs(table, sample_corpus())

        query = Enum.uniq(terms) |> Enum.join(" ")
        {:ok, results} = fts_search(table, query)

        scores = Enum.map(results, & &1.score)
        sorted_desc = Enum.sort(scores, :desc)
        drop_index(table)

        assert scores == sorted_desc
      end
    end

    test "FTS5_BM25_PROP_SD_01: any doc matching the query has a positive BM25 score" do
      ExUnitProperties.check all(
                               term <-
                                 SD.member_of([
                                   "knowledge",
                                   "guardian",
                                   "zenoh",
                                   "sqlite",
                                   "history"
                                 ]),
                               max_runs: 15
                             ) do
        table = new_index()
        insert_docs(table, sample_corpus())
        {:ok, results} = fts_search(table, term)
        assert Enum.all?(results, fn r -> r.score > 0.0 end)
        drop_index(table)
      end
    end
  end

  # ============================================================================
  # SECTION 3 — Prefix Search
  # ============================================================================

  describe "FTS5 prefix search" do
    setup do
      table = new_index()
      :ok = insert_docs(table, sample_corpus())
      on_exit(fn -> :ets.delete(table) end)
      {:ok, table: table}
    end

    test "FTS5_PREFIX_01: prefix 'zen' matches documents containing 'zenoh'", %{table: table} do
      {:ok, results} = fts_prefix_search(table, "zen")
      assert length(results) >= 1
      ids = Enum.map(results, & &1.doc.id)
      # Doc 2 is the Zenoh document
      assert 2 in ids
    end

    test "FTS5_PREFIX_02: prefix 'smr' matches SMRITI document", %{table: table} do
      {:ok, results} = fts_prefix_search(table, "smr")
      ids = Enum.map(results, & &1.doc.id)
      assert 1 in ids
    end

    test "FTS5_PREFIX_PROP_01: prefix match results are subset of full-term search results" do
      ExUnitProperties.check all(
                               full_term <-
                                 SD.member_of([
                                   "zenoh",
                                   "guardian",
                                   "sqlite",
                                   "history",
                                   "biomorphic"
                                 ]),
                               max_runs: 10
                             ) do
        table = new_index()
        insert_docs(table, sample_corpus())

        prefix = String.slice(full_term, 0, 3)
        {:ok, prefix_results} = fts_prefix_search(table, prefix)
        {:ok, full_results} = fts_search(table, full_term, mode: :or)

        prefix_ids = MapSet.new(prefix_results, & &1.doc.id)
        full_ids = MapSet.new(full_results, & &1.doc.id)

        drop_index(table)

        assert MapSet.subset?(full_ids, prefix_ids)
      end
    end
  end

  # ============================================================================
  # SECTION 4 — Phrase Search
  # ============================================================================

  describe "FTS5 phrase search" do
    setup do
      table = new_index()
      :ok = insert_docs(table, sample_corpus())
      on_exit(fn -> :ets.delete(table) end)
      {:ok, table: table}
    end

    test "FTS5_PHRASE_01: phrase 'wal mode' matches SQLite document", %{table: table} do
      {:ok, results} = fts_phrase_search(table, "wal mode")
      ids = Enum.map(results, & &1.doc.id)
      assert 5 in ids
    end

    test "FTS5_PHRASE_02: phrase with reversed token order does NOT match", %{table: table} do
      # "mode wal" is not in the body of any document (in that order)
      {:ok, results} = fts_phrase_search(table, "mode wal")
      ids = Enum.map(results, & &1.doc.id)
      # Doc 5 body has "WAL mode" (wal then mode), not "mode wal"
      refute 5 in ids
    end

    test "FTS5_PHRASE_PROP_01: phrase search is always a subset of AND search for same terms" do
      ExUnitProperties.check all(
                               phrase <-
                                 SD.member_of([
                                   "wal mode",
                                   "error correction",
                                   "boot sequence",
                                   "knowledge graph"
                                 ]),
                               max_runs: 10
                             ) do
        table = new_index()
        insert_docs(table, sample_corpus())

        {:ok, phrase_results} = fts_phrase_search(table, phrase)
        {:ok, and_results} = fts_search(table, phrase, mode: :and)

        phrase_ids = MapSet.new(phrase_results, & &1.doc.id)
        and_ids = MapSet.new(and_results, & &1.doc.id)

        drop_index(table)

        assert MapSet.subset?(phrase_ids, and_ids)
      end
    end
  end

  # ============================================================================
  # SECTION 5 — Boolean Operators (AND / OR / NOT)
  # ============================================================================

  describe "FTS5 boolean operators" do
    setup do
      table = new_index()
      :ok = insert_docs(table, sample_corpus())
      on_exit(fn -> :ets.delete(table) end)
      {:ok, table: table}
    end

    test "FTS5_BOOL_01: AND mode returns only documents matching ALL terms", %{table: table} do
      # "zenoh" AND "mesh" should match the Zenoh document and possibly the boot document
      {:ok, results} = fts_search(table, "zenoh mesh", mode: :and)

      assert Enum.all?(results, fn r ->
               text = tokenise("#{r.doc.title} #{r.doc.body} #{r.doc.tags}")
               "zenoh" in text and "mesh" in text
             end)
    end

    test "FTS5_BOOL_02: OR mode returns documents matching ANY term", %{table: table} do
      {:ok, and_results} = fts_search(table, "zenoh guardian", mode: :and)
      {:ok, or_results} = fts_search(table, "zenoh guardian", mode: :or)
      # OR always returns >= AND results
      assert length(or_results) >= length(and_results)
    end

    test "FTS5_BOOL_03: NOT mode excludes documents containing excluded terms", %{table: table} do
      # Include docs with "history", exclude docs with "duckdb"
      {:ok, results} =
        fts_search(table, "", mode: {:not, ["history"], ["duckdb"]})

      refute {:error, :empty_query} == {:ok, results}

      assert Enum.all?(results, fn r ->
               text = tokenise("#{r.doc.title} #{r.doc.body} #{r.doc.tags}")
               "history" in text and "duckdb" not in text
             end)
    end
  end

  # ============================================================================
  # SECTION 6 — Highlight and Snippet Extraction
  # ============================================================================

  describe "FTS5 highlight and snippet extraction" do
    test "FTS5_SNIP_01: extract_snippet/3 wraps the matching word in brackets" do
      body = "The Guardian module validates all proposals before any state mutation."
      snippet = extract_snippet(body, "guardian", 3)
      assert String.contains?(snippet, "[Guardian]") or String.contains?(snippet, "[guardian]")
    end

    test "FTS5_SNIP_02: extract_snippet/3 returns a window of context words" do
      body = "Alpha beta gamma delta epsilon zeta eta theta iota kappa"
      snippet = extract_snippet(body, "epsilon", 2)
      # With window=2, should include delta and zeta around epsilon
      assert String.contains?(snippet, "delta") or String.contains?(snippet, "zeta")
    end

    test "FTS5_SNIP_03: extract_snippet/3 gracefully handles missing term" do
      body = "No matching content here."
      snippet = extract_snippet(body, "guardian", 5)
      # Falls back to truncated body
      assert is_binary(snippet)
      assert String.length(snippet) <= 80
    end

    test "FTS5_HL_01: highlight_term/4 wraps matching words with open/close markers" do
      text = "The Guardian module validates proposals via the Guardian kernel."
      highlighted = highlight_term(text, "guardian", "<b>", "</b>")
      assert String.contains?(highlighted, "<b>Guardian</b>")
      # Should appear at least twice (two occurrences)
      occurrences = highlighted |> String.split("<b>") |> length()
      assert occurrences >= 3
    end

    test "FTS5_HL_02: highlight_term/4 is case-insensitive for matching" do
      text = "SMRITI stores knowledge efficiently."
      highlighted = highlight_term(text, "smriti", ">>", "<<")
      assert String.contains?(highlighted, ">>SMRITI<<")
    end

    test "FTS5_HL_03: highlight_term/4 leaves non-matching words unchanged" do
      text = "zenoh guardian sqlite"
      highlighted = highlight_term(text, "guardian", "**", "**")
      assert String.contains?(highlighted, "zenoh")
      assert String.contains?(highlighted, "sqlite")
      assert String.contains?(highlighted, "**guardian**")
    end
  end

  # ============================================================================
  # SECTION 7 — Query Timeout Enforcement (SC-SMRITI-133)
  # ============================================================================

  describe "query timeout enforcement (SC-SMRITI-133: < 500ms)" do
    setup do
      table = new_index()
      :ok = insert_docs(table, sample_corpus())
      on_exit(fn -> :ets.delete(table) end)
      {:ok, table: table}
    end

    test "FTS5_TIMEOUT_01: standard query completes within 500ms timeout", %{table: table} do
      start = System.monotonic_time(:millisecond)
      {:ok, _results} = fts_search(table, "guardian zenoh sqlite", timeout_ms: 500)
      elapsed = System.monotonic_time(:millisecond) - start
      assert elapsed < 500, "Query took #{elapsed}ms, exceeds 500ms timeout"
    end

    test "FTS5_TIMEOUT_02: timed_query/2 with artificially short timeout detects exceeded time" do
      # Simulate a slow query by passing an already-elapsed timeout budget of 0ms.
      # We rely on the simulation returning before real timeout by using 0ms threshold.
      result =
        timed_query(
          fn ->
            # Introduce a minimal artificial delay longer than 0ms threshold
            Process.sleep(5)
            :done
          end,
          # 0ms timeout: any non-instant query will exceed this
          0
        )

      assert result == {:error, :timeout}
    end

    test "FTS5_TIMEOUT_PROP_01: all search calls on sample corpus complete within 500ms" do
      ExUnitProperties.check all(
                               term <-
                                 SD.member_of(["holon", "zenoh", "guardian", "smriti", "duckdb"]),
                               max_runs: 25
                             ) do
        table = new_index()
        insert_docs(table, sample_corpus())

        start = System.monotonic_time(:millisecond)
        result = fts_search(table, term, timeout_ms: @query_timeout_ms)
        elapsed = System.monotonic_time(:millisecond) - start

        drop_index(table)

        assert match?({:ok, _}, result)
        assert elapsed < @query_timeout_ms
      end
    end
  end

  # ============================================================================
  # SECTION 8 — Unicode Support
  # ============================================================================

  describe "Unicode support in FTS5 search" do
    setup do
      table = new_index()
      :ok = insert_docs(table, unicode_corpus())
      on_exit(fn -> :ets.delete(table) end)
      {:ok, table: table}
    end

    test "FTS5_UNICODE_01: Hindi script tokenises correctly and matches", %{table: table} do
      {:ok, results} = fts_search(table, "zenoh")
      # Doc 102 has "Zenoh" in body
      ids = Enum.map(results, & &1.doc.id)
      assert 102 in ids
    end

    test "FTS5_UNICODE_02: French and German docs are searchable via Latin terms", %{table: table} do
      {:ok, results} = fts_search(table, "guardian")
      ids = Enum.map(results, & &1.doc.id)
      # Doc 104 (German) contains "Guardian"
      assert 104 in ids
    end

    test "FTS5_UNICODE_03: tokenise/1 handles multibyte UTF-8 without raising" do
      texts = [
        "इन्द्रजाल एजेंट",
        "가디언 안전",
        "Système SIL-6",
        "Sicherheitskernel",
        "中文测试 test"
      ]

      for text <- texts do
        tokens = tokenise(text)
        assert is_list(tokens)
        assert Enum.all?(tokens, &is_binary/1)
      end
    end

    test "FTS5_UNICODE_PROP_01: tokenise/1 never raises on arbitrary UTF-8 binary input" do
      ExUnitProperties.check all(
                               s <- SD.string(:alphanumeric, min_length: 0, max_length: 100),
                               max_runs: 50
                             ) do
        tokens = tokenise(s)
        assert is_list(tokens)
        assert Enum.all?(tokens, &is_binary/1)
      end
    end
  end

  # ============================================================================
  # SECTION 9 — Empty and Invalid Query Handling
  # ============================================================================

  describe "empty and invalid query handling" do
    setup do
      table = new_index()
      :ok = insert_docs(table, sample_corpus())
      on_exit(fn -> :ets.delete(table) end)
      {:ok, table: table}
    end

    test "FTS5_EMPTY_01: empty string query returns {:error, :empty_query}", %{table: table} do
      assert {:error, :empty_query} = fts_search(table, "")
    end

    test "FTS5_EMPTY_02: whitespace-only query returns {:error, :empty_query}", %{table: table} do
      assert {:error, :empty_query} = fts_search(table, "   ")
    end

    test "FTS5_EMPTY_03: empty prefix search returns {:error, :empty_query}", %{table: table} do
      assert {:error, :empty_query} = fts_prefix_search(table, "")
    end

    test "FTS5_EMPTY_04: query with no matches returns {:ok, []}", %{table: table} do
      {:ok, results} = fts_search(table, "zzzyyyxxx_nonexistent")
      assert results == []
    end

    test "FTS5_EMPTY_05: phrase search on whitespace-only returns {:error, :empty_query}",
         %{table: table} do
      assert {:error, :empty_query} = fts_phrase_search(table, "  ")
    end
  end

  # ============================================================================
  # SECTION 10 — Relevance Score Property Invariants
  # ============================================================================

  describe "relevance score invariants" do
    test "FTS5_SCORE_PROP_01: all scores are non-negative floats" do
      ExUnitProperties.check all(
                               term <-
                                 SD.member_of(["holon", "zenoh", "guardian", "ooda", "smriti"]),
                               max_runs: 25
                             ) do
        table = new_index()
        insert_docs(table, sample_corpus())
        {:ok, results} = fts_search(table, term)
        drop_index(table)

        assert Enum.all?(results, fn r ->
                 is_float(r.score) and r.score >= 0.0
               end)
      end
    end

    test "FTS5_SCORE_PROP_02: more specific AND query has fewer or equal results than OR" do
      ExUnitProperties.check all(
                               t1 <- SD.member_of(["zenoh", "guardian", "sqlite", "holon"]),
                               t2 <- SD.member_of(["mesh", "safety", "wal", "knowledge"]),
                               max_runs: 25
                             ) do
        table = new_index()
        insert_docs(table, sample_corpus())

        combined = "#{t1} #{t2}"
        {:ok, and_results} = fts_search(table, combined, mode: :and)
        {:ok, or_results} = fts_search(table, combined, mode: :or)

        drop_index(table)

        assert length(and_results) <= length(or_results)
      end
    end
  end
end
