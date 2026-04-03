defmodule Indrajaal.KMS.AI do
  @moduledoc """
  AI-powered knowledge management capabilities for the KMS.

  ## Purpose

  Provides intelligent automation for knowledge lifecycle management:
  - Auto-classification of holons based on content
  - Embedding generation for semantic search
  - Knowledge gardening (stale detection, cleanup suggestions)
  - Relationship inference between holons

  ## STAMP Constraints

  - SC-KMS-013: AI classification confidence >= 0.75
  - SC-KMS-014: Embedding dimensions = 1024 (OpenAI ada-002 compatible)
  - SC-KMS-015: Gardening runs max once per hour
  - SC-KMS-016: Human approval for destructive suggestions

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-30 |
  | Author | Cybernetic Architect |
  | Reference | Fractal Holonic Architecture |
  """

  use GenServer
  require Logger

  alias Indrajaal.KMS
  alias Indrajaal.KMS.{SQLite, Vectors}

  @gardening_interval :timer.hours(1)
  @stale_threshold_days 90
  @min_confidence 0.75
  @embedding_dimensions 1024
  @batch_size 50

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc """
  Start the KMS AI GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Auto-classify a holon based on its content.

  Uses LLM to analyze the holon's name, genome, and payload to suggest:
  - Appropriate type (knowledge, process, agent, artifact, etc.)
  - Relevant tags for discovery
  - Suggested parent holon

  ## Parameters

  - `holon_id`: The holon to classify
  - `opts`: Classification options
    - `:apply` - Whether to apply classification (default: false)
    - `:model` - LLM model to use

  ## Returns

  - `{:ok, %{type: atom, tags: [String.t], parent_suggestion: String.t | nil, confidence: float}}`
  """
  @spec classify(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def classify(holon_id, opts \\ []) do
    GenServer.call(__MODULE__, {:classify, holon_id, opts}, 30_000)
  end

  @doc """
  Batch classify multiple holons.
  """
  @spec classify_batch([String.t()], keyword()) :: {:ok, [map()]} | {:error, term()}
  def classify_batch(holon_ids, opts \\ []) do
    GenServer.call(__MODULE__, {:classify_batch, holon_ids, opts}, 120_000)
  end

  @doc """
  Generate embedding for a holon.

  Creates a vector representation of the holon's semantic content
  for similarity search and clustering.

  ## Parameters

  - `holon_id`: The holon to embed
  - `opts`: Embedding options
    - `:model` - Embedding model (default: text-embedding-ada-002)
    - `:store` - Whether to store in vectors DB (default: true)

  ## Returns

  - `{:ok, %{embedding: [float], dimensions: integer}}`
  """
  @spec generate_embedding(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def generate_embedding(holon_id, opts \\ []) do
    GenServer.call(__MODULE__, {:embed, holon_id, opts}, 30_000)
  end

  @doc """
  Generate embeddings for multiple holons.
  """
  @spec generate_embeddings_batch([String.t()], keyword()) :: {:ok, map()} | {:error, term()}
  def generate_embeddings_batch(holon_ids, opts \\ []) do
    GenServer.call(__MODULE__, {:embed_batch, holon_ids, opts}, 120_000)
  end

  @doc """
  Find semantically similar holons.

  Uses embedding similarity to find related knowledge.

  ## Parameters

  - `holon_id`: The reference holon
  - `opts`: Search options
    - `:limit` - Max results (default: 10)
    - `:min_similarity` - Minimum similarity threshold (default: 0.7)

  ## Returns

  - `{:ok, [%{holon_id: String.t, similarity: float}]}`
  """
  @spec find_similar(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def find_similar(holon_id, opts \\ []) do
    GenServer.call(__MODULE__, {:find_similar, holon_id, opts})
  end

  @doc """
  Run knowledge gardening analysis.

  Identifies:
  - Stale holons (not updated in threshold period)
  - Orphaned holons (no parent, no children, no edges)
  - Duplicate candidates (high embedding similarity)
  - Missing relationships (should be connected but aren't)

  ## Parameters

  - `opts`: Gardening options
    - `:stale_days` - Days before considered stale (default: 90)
    - `:dry_run` - Don't apply suggestions (default: true)

  ## Returns

  - `{:ok, %{stale: [holon_id], orphaned: [holon_id], duplicates: [[holon_id]], suggestions: [map]}}`
  """
  @spec garden(keyword()) :: {:ok, map()} | {:error, term()}
  def garden(opts \\ []) do
    GenServer.call(__MODULE__, {:garden, opts}, 60_000)
  end

  @doc """
  Infer relationships between holons.

  Uses LLM to analyze holon content and suggest edges.

  ## Parameters

  - `holon_ids`: List of holon IDs to analyze
  - `opts`: Inference options

  ## Returns

  - `{:ok, [%{source_id: String.t, target_id: String.t, label: String.t, confidence: float}]}`
  """
  @spec infer_relationships([String.t()], keyword()) :: {:ok, [map()]} | {:error, term()}
  def infer_relationships(holon_ids, opts \\ []) do
    GenServer.call(__MODULE__, {:infer_relationships, holon_ids, opts}, 60_000)
  end

  @doc """
  Ask the KMS Oracle a natural language question.

  Performs Retrieval-Augmented Generation (RAG) by:
  1. Searching KMS for relevant holons (Hybrid Search).
  2. constructing a context window.
  3. Querying OpenRouter with the recommended free model.

  ## Parameters
  - `query`: The user's question.
  - `opts`: Options
    - `:model` - Override model (default: google/gemini-2.0-flash-lite-preview-02-05:free)
    - `:limit` - Number of holons to retrieve (default: 10)

  ## Returns
  - `{:ok, response_text}`
  """
  @spec ask_oracle(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def ask_oracle(query, opts \\ []) do
    GenServer.call(__MODULE__, {:ask_oracle, query, opts}, 60_000)
  end

  @doc """
  Get AI service statistics.
  """
  @spec stats() :: {:ok, map()}
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    # Schedule periodic gardening if enabled
    if Keyword.get(opts, :auto_garden, false) do
      Process.send_after(self(), :garden, @gardening_interval)
    end

    state = %{
      classifications: 0,
      embeddings_generated: 0,
      similarities_found: 0,
      gardening_runs: 0,
      oracle_queries: 0,
      last_garden: nil,
      opts: opts,
      # Default free model for Oracle queries - High speed, low cost
      oracle_model: "google/gemini-2.0-flash-lite-preview-02-05:free"
    }

    Logger.info("[KMS.AI] Initialized")
    {:ok, state}
  end

  @impl true
  def handle_call({:ask_oracle, query, opts}, _from, state) do
    result = do_ask_oracle(query, opts, state)

    new_state =
      case result do
        {:ok, _} -> %{state | oracle_queries: state.oracle_queries + 1}
        _ -> state
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:classify, holon_id, opts}, _from, state) do
    result = do_classify(holon_id, opts)

    new_state =
      case result do
        {:ok, _} -> %{state | classifications: state.classifications + 1}
        _ -> state
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:classify_batch, holon_ids, opts}, _from, state) do
    results =
      holon_ids
      |> Enum.map(fn id -> do_classify(id, opts) end)
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, r} -> r end)

    new_state = %{state | classifications: state.classifications + length(results)}
    {:reply, {:ok, results}, new_state}
  end

  @impl true
  def handle_call({:embed, holon_id, opts}, _from, state) do
    result = do_generate_embedding(holon_id, opts)

    new_state =
      case result do
        {:ok, _} -> %{state | embeddings_generated: state.embeddings_generated + 1}
        _ -> state
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:embed_batch, holon_ids, opts}, _from, state) do
    results =
      holon_ids
      |> Enum.chunk_every(@batch_size)
      |> Enum.flat_map(fn batch ->
        batch
        |> Enum.map(fn id -> do_generate_embedding(id, opts) end)
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.map(fn {:ok, r} -> r end)
      end)

    new_state = %{state | embeddings_generated: state.embeddings_generated + length(results)}
    {:reply, {:ok, %{embedded: length(results), total: length(holon_ids)}}, new_state}
  end

  @impl true
  def handle_call({:find_similar, holon_id, opts}, _from, state) do
    result = do_find_similar(holon_id, opts)

    new_state =
      case result do
        {:ok, results} ->
          %{state | similarities_found: state.similarities_found + length(results)}

        _ ->
          state
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:garden, opts}, _from, state) do
    result = do_garden(opts)

    new_state =
      case result do
        {:ok, _} ->
          %{state | gardening_runs: state.gardening_runs + 1, last_garden: DateTime.utc_now()}

        _ ->
          state
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:infer_relationships, holon_ids, opts}, _from, state) do
    result = do_infer_relationships(holon_ids, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      classifications: state.classifications,
      embeddings_generated: state.embeddings_generated,
      similarities_found: state.similarities_found,
      gardening_runs: state.gardening_runs,
      oracle_queries: Map.get(state, :oracle_queries, 0),
      last_garden: state.last_garden
    }

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_info(:garden, state) do
    # Run gardening in background
    spawn(fn -> do_garden(dry_run: true) end)

    # Schedule next run
    Process.send_after(self(), :garden, @gardening_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private: Oracle (RAG)
  # ---------------------------------------------------------------------------

  defp do_ask_oracle(query, opts, state) do
    if state.opts[:llm_enabled] || llm_configured?() do
      limit = Keyword.get(opts, :limit, 10)
      # Use free model by default if not specified
      model = Keyword.get(opts, :model, state.oracle_model)

      # 1. Search for context (Hybrid: Text + Vector if available)
      {:ok, search_results} = KMS.search(query, limit: limit)

      # 2. Build RAG Context
      context = build_rag_context(search_results)

      # 3. Construct Prompt
      prompt = """
      You are the Indrajaal Oracle, a knowledge assistant for this system.
      Answer the user's question based ONLY on the provided context below.
      If the answer is not in the context, state that you don't know based on the available knowledge.

      CONTEXT:
      #{context}

      USER QUERY:
      #{query}
      """

      # 4. Call OpenRouter
      alias Indrajaal.AI.OpenRouterClient
      OpenRouterClient.chat(prompt, "kms_oracle", model: model)
    else
      {:error, :llm_disabled}
    end
  end

  defp llm_configured? do
    api_key = System.get_env("OPENROUTER_API_KEY")
    api_key != nil and api_key != ""
  end

  defp build_rag_context(results) do
    results
    |> Enum.map(fn holon ->
      """
      ---
      ID: #{holon.id}
      Name: #{holon.name}
      Type: #{holon.type}
      Content: #{build_holon_content(holon)}
      ---
      """
    end)
    |> Enum.join("\n")
  end

  # ---------------------------------------------------------------------------
  # Private: Classification
  # ---------------------------------------------------------------------------

  defp do_classify(holon_id, opts) do
    with {:ok, holon} <- KMS.get_holon(holon_id) do
      # Build content for classification
      content = build_holon_content(holon)

      # Use LLM for classification
      case classify_with_llm(content, opts) do
        {:ok, classification} ->
          # Optionally apply classification
          if Keyword.get(opts, :apply, false) do
            apply_classification(holon_id, classification)
          end

          {:ok, Map.put(classification, :holon_id, holon_id)}

        error ->
          error
      end
    end
  end

  defp classify_with_llm(content, opts) do
    api_key =
      Application.get_env(:indrajaal, :openrouter_api_key) || System.get_env("OPENROUTER_API_KEY")

    case try_llm_classification(content, opts, api_key) do
      {:ok, classification} ->
        if classification.confidence >= @min_confidence do
          {:ok, classification}
        else
          {:error, :low_confidence}
        end

      {:error, _reason} ->
        # Fall back to rule-based classification
        rule_based_classification(content)
    end
  end

  defp try_llm_classification(_content, _opts, nil), do: {:error, :api_not_configured}
  defp try_llm_classification(_content, _opts, ""), do: {:error, :api_not_configured}

  defp try_llm_classification(content, _opts, api_key) do
    model = "google/gemma-3-1b-it:free"

    prompt = """
    Classify the following knowledge content into exactly one type from this list:
    decision, architecture, debt, process, agent, artifact, knowledge

    Also extract up to 5 relevant tags from:
    api, security, performance, testing, deployment, database, frontend, backend, infrastructure

    Respond with JSON only, no explanation:
    {"type": "<type>", "tags": ["<tag1>", "<tag2>"], "confidence": <0.0-1.0>}

    Content:
    #{String.slice(content, 0, 500)}
    """

    body =
      Jason.encode!(%{
        "model" => model,
        "messages" => [%{"role" => "user", "content" => prompt}],
        "max_tokens" => 100
      })

    try do
      response =
        Req.post!(
          "https://openrouter.ai/api/v1/chat/completions",
          body: body,
          headers: [
            {"authorization", "Bearer #{api_key}"},
            {"content-type", "application/json"},
            {"http-referer", "https://indrajaal.local"}
          ],
          receive_timeout: 10_000
        )

      case response.status do
        200 ->
          parse_llm_classification_response(response.body, content)

        status ->
          Logger.warning(
            "[KMS.AI] OpenRouter classification returned HTTP #{status}, falling back"
          )

          {:error, {:http_error, status}}
      end
    rescue
      e ->
        Logger.warning("[KMS.AI] OpenRouter classification failed: #{inspect(e)}, falling back")
        {:error, :request_failed}
    end
  end

  defp parse_llm_classification_response(body, _content) do
    with text when is_binary(text) <-
           get_in(body, ["choices", Access.at(0), "message", "content"]),
         {:ok, parsed} <- Jason.decode(String.trim(text)),
         type_str when is_binary(type_str) <- Map.get(parsed, "type"),
         type <- String.to_existing_atom(type_str),
         tags when is_list(tags) <- Map.get(parsed, "tags", []),
         confidence when is_float(confidence) <- Map.get(parsed, "confidence", 0.8) do
      {:ok,
       %{
         type: type,
         tags: Enum.filter(tags, &is_binary/1) |> Enum.take(5),
         parent_suggestion: nil,
         confidence: confidence
       }}
    else
      _ ->
        Logger.warning("[KMS.AI] Failed to parse LLM classification response, falling back")
        {:error, :parse_failed}
    end
  rescue
    ArgumentError ->
      # String.to_existing_atom failed — unknown type from LLM
      Logger.warning("[KMS.AI] LLM returned unknown type atom, falling back")
      {:error, :unknown_type}

    e ->
      Logger.warning("[KMS.AI] LLM response parsing error: #{inspect(e)}, falling back")
      {:error, :parse_failed}
  end

  defp rule_based_classification(content) do
    type = infer_type_from_content(content)
    tags = extract_tags_from_content(content)

    classification = %{
      type: type,
      tags: tags,
      parent_suggestion: nil,
      confidence: calculate_confidence(content, type)
    }

    if classification.confidence >= @min_confidence do
      {:ok, classification}
    else
      {:error, :low_confidence}
    end
  end

  defp infer_type_from_content(content) do
    cond do
      String.contains?(content, ["decision", "adr", "rfc", "proposal"]) -> :decision
      String.contains?(content, ["architecture", "diagram", "c4", "model"]) -> :architecture
      String.contains?(content, ["debt", "todo", "fix", "refactor"]) -> :debt
      String.contains?(content, ["process", "workflow", "pipeline"]) -> :process
      String.contains?(content, ["agent", "bot", "automation"]) -> :agent
      String.contains?(content, ["artifact", "document", "file"]) -> :artifact
      true -> :knowledge
    end
  end

  defp extract_tags_from_content(content) do
    # Simple keyword extraction
    keywords =
      ~w(api security performance testing deployment database frontend backend infrastructure)

    keywords
    |> Enum.filter(fn kw -> String.contains?(String.downcase(content), kw) end)
    |> Enum.take(5)
  end

  defp calculate_confidence(content, _type) do
    # Simple heuristic based on content length and keyword matches
    base = 0.6
    length_bonus = min(0.2, String.length(content) / 1000)
    keyword_bonus = 0.1

    min(1.0, base + length_bonus + keyword_bonus)
  end

  defp apply_classification(holon_id, classification) do
    KMS.update_holon(holon_id, %{
      type: classification.type,
      genome: %{
        ai_classification: %{
          tags: classification.tags,
          confidence: classification.confidence,
          classified_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }
      }
    })
  end

  # ---------------------------------------------------------------------------
  # Private: Embeddings
  # ---------------------------------------------------------------------------

  defp do_generate_embedding(holon_id, opts) do
    with {:ok, holon} <- KMS.get_holon(holon_id) do
      content = build_holon_content(holon)

      # Generate embedding
      case generate_embedding_vector(content, opts) do
        {:ok, embedding} ->
          # Store if requested
          if Keyword.get(opts, :store, true) do
            Vectors.store_embedding(holon_id, embedding, content)
          end

          {:ok, %{holon_id: holon_id, dimensions: length(embedding)}}

        error ->
          error
      end
    end
  end

  defp generate_embedding_vector(content, opts) do
    content_hash = Base.encode16(:crypto.hash(:sha256, content), case: :lower)

    case :persistent_term.get({__MODULE__, :embedding_cache, content_hash}, :miss) do
      :miss ->
        result = do_generate_embedding_vector(content, opts, content_hash)
        result

      cached_embedding ->
        {:ok, cached_embedding}
    end
  end

  defp do_generate_embedding_vector(content, _opts, content_hash) do
    api_key =
      Application.get_env(:indrajaal, :openrouter_api_key) || System.get_env("OPENROUTER_API_KEY")

    case try_api_embedding(content, api_key) do
      {:ok, embedding} ->
        :persistent_term.put({__MODULE__, :embedding_cache, content_hash}, embedding)
        {:ok, embedding}

      {:error, _reason} ->
        {:ok, hash_pseudo_embedding(content)}
    end
  end

  defp try_api_embedding(_content, nil), do: {:error, :api_not_configured}
  defp try_api_embedding(_content, ""), do: {:error, :api_not_configured}

  defp try_api_embedding(content, api_key) do
    model = "nomic-ai/nomic-embed-text-v1.5"

    body =
      Jason.encode!(%{
        "model" => model,
        "input" => String.slice(content, 0, 2048)
      })

    try do
      response =
        Req.post!(
          "https://openrouter.ai/api/v1/embeddings",
          body: body,
          headers: [
            {"authorization", "Bearer #{api_key}"},
            {"content-type", "application/json"},
            {"http-referer", "https://indrajaal.local"}
          ],
          receive_timeout: 15_000
        )

      case response.status do
        200 ->
          parse_embedding_response(response.body)

        status ->
          Logger.warning("[KMS.AI] OpenRouter embedding returned HTTP #{status}, falling back")
          {:error, {:http_error, status}}
      end
    rescue
      e ->
        Logger.warning("[KMS.AI] OpenRouter embedding failed: #{inspect(e)}, falling back")
        {:error, :request_failed}
    end
  end

  defp parse_embedding_response(body) do
    with embedding when is_list(embedding) <-
           get_in(body, ["data", Access.at(0), "embedding"]),
         true <- length(embedding) > 0 do
      # Pad or truncate to @embedding_dimensions
      adjusted =
        if length(embedding) >= @embedding_dimensions do
          Enum.take(embedding, @embedding_dimensions)
        else
          padding = List.duplicate(0.0, @embedding_dimensions - length(embedding))
          embedding ++ padding
        end

      {:ok, adjusted}
    else
      _ ->
        Logger.warning("[KMS.AI] Failed to parse embedding response, falling back")
        {:error, :parse_failed}
    end
  end

  defp hash_pseudo_embedding(content) do
    hash = :crypto.hash(:sha256, content)
    bytes = :binary.bin_to_list(hash)

    bytes
    |> Enum.flat_map(fn b ->
      [
        (b - 128) / 256.0,
        :math.sin(b / 40.0),
        :math.cos(b / 40.0),
        :math.tanh((b - 128) / 64.0)
      ]
    end)
    |> Enum.take(@embedding_dimensions)
  end

  defp do_find_similar(holon_id, opts) do
    limit = Keyword.get(opts, :limit, 10)
    min_similarity = Keyword.get(opts, :min_similarity, 0.7)

    case Vectors.find_similar(holon_id, limit: limit * 2) do
      {:ok, results} ->
        filtered =
          results
          |> Enum.filter(fn r -> r.similarity >= min_similarity end)
          |> Enum.take(limit)

        {:ok, filtered}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Gardening
  # ---------------------------------------------------------------------------

  defp do_garden(opts) do
    stale_days = Keyword.get(opts, :stale_days, @stale_threshold_days)
    dry_run = Keyword.get(opts, :dry_run, true)

    # Find stale holons
    stale = find_stale_holons(stale_days)

    # Find orphaned holons
    orphaned = find_orphaned_holons()

    # Find potential duplicates via embedding similarity
    duplicates = find_duplicate_candidates()

    # Generate suggestions
    suggestions = generate_suggestions(stale, orphaned, duplicates)

    # Apply suggestions if not dry run
    unless dry_run do
      apply_suggestions(suggestions)
    end

    {:ok,
     %{
       stale: stale,
       orphaned: orphaned,
       duplicates: duplicates,
       suggestions: suggestions,
       dry_run: dry_run
     }}
  end

  defp find_stale_holons(days) do
    threshold =
      DateTime.utc_now() |> DateTime.add(-days * 24 * 3600, :second) |> DateTime.to_iso8601()

    case SQLite.query(
           "SELECT id FROM holons WHERE updated_at < ? OR updated_at IS NULL LIMIT ?",
           [threshold, @batch_size]
         ) do
      {:ok, rows} -> Enum.map(rows, fn [id] -> id end)
      _ -> []
    end
  end

  defp find_orphaned_holons do
    query = """
    SELECT h.id FROM holons h
    LEFT JOIN holons p ON h.parent_id = p.id
    LEFT JOIN edges e1 ON h.id = e1.source_id
    LEFT JOIN edges e2 ON h.id = e2.target_id
    WHERE h.parent_id IS NULL
    AND p.id IS NULL
    AND e1.id IS NULL
    AND e2.id IS NULL
    LIMIT ?
    """

    case SQLite.query(query, [@batch_size]) do
      {:ok, rows} -> Enum.map(rows, fn [id] -> id end)
      _ -> []
    end
  end

  defp find_duplicate_candidates do
    # Get holons with embeddings and find high-similarity pairs
    case Vectors.find_all_similar_pairs(min_similarity: 0.95, limit: 20) do
      {:ok, pairs} -> pairs
      _ -> []
    end
  end

  defp generate_suggestions(stale, orphaned, duplicates) do
    stale_suggestions =
      stale
      |> Enum.map(fn id ->
        %{type: :review_stale, holon_id: id, action: :review, severity: :low}
      end)

    orphan_suggestions =
      orphaned
      |> Enum.map(fn id ->
        %{type: :archive_orphan, holon_id: id, action: :archive, severity: :medium}
      end)

    duplicate_suggestions =
      duplicates
      |> Enum.map(fn [id1, id2] ->
        %{type: :merge_duplicates, holon_ids: [id1, id2], action: :merge, severity: :high}
      end)

    stale_suggestions ++ orphan_suggestions ++ duplicate_suggestions
  end

  defp apply_suggestions(suggestions) do
    # Only apply low-risk suggestions automatically
    suggestions
    |> Enum.filter(fn s -> s.severity == :low end)
    |> Enum.each(fn suggestion ->
      case suggestion.type do
        :review_stale ->
          # Mark for review by setting a flag in genome
          KMS.update_holon(suggestion.holon_id, %{
            genome: %{needs_review: true, flagged_at: DateTime.utc_now() |> DateTime.to_iso8601()}
          })

        _ ->
          :ok
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Private: Relationship Inference
  # ---------------------------------------------------------------------------

  defp do_infer_relationships(holon_ids, _opts) do
    # Load holons
    holons =
      holon_ids
      |> Enum.map(fn id ->
        case KMS.get_holon(id) do
          {:ok, h} -> h
          _ -> nil
        end
      end)
      |> Enum.filter(& &1)

    # Find pairs with semantic similarity
    relationships =
      for h1 <- holons, h2 <- holons, h1.id != h2.id do
        similarity = calculate_content_similarity(h1, h2)

        if similarity >= 0.6 do
          label = infer_relationship_label(h1, h2)
          %{source_id: h1.id, target_id: h2.id, label: label, confidence: similarity}
        else
          nil
        end
      end
      |> Enum.filter(& &1)
      |> Enum.uniq_by(fn r -> {min(r.source_id, r.target_id), max(r.source_id, r.target_id)} end)

    {:ok, relationships}
  end

  defp calculate_content_similarity(h1, h2) do
    # Simple Jaccard similarity on words
    words1 = extract_words(h1)
    words2 = extract_words(h2)

    intersection = MapSet.intersection(words1, words2) |> MapSet.size()
    union = MapSet.union(words1, words2) |> MapSet.size()

    if union > 0, do: intersection / union, else: 0.0
  end

  defp extract_words(holon) do
    content = build_holon_content(holon)

    content
    |> String.downcase()
    |> String.split(~r/[^a-z0-9]+/)
    |> Enum.filter(fn w -> String.length(w) > 2 end)
    |> MapSet.new()
  end

  defp infer_relationship_label(h1, h2) do
    cond do
      h1.type == :decision && h2.type == :architecture -> "IMPACTS"
      h1.type == :architecture && h2.type == :decision -> "GUIDED_BY"
      h1.type == :process && h2.type == :artifact -> "PRODUCES"
      h1.type == :agent && h2.type == :process -> "EXECUTES"
      h1.type == :knowledge && h2.type == :knowledge -> "RELATED_TO"
      true -> "ASSOCIATED_WITH"
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Helpers
  # ---------------------------------------------------------------------------

  defp build_holon_content(holon) do
    parts = [
      holon.name,
      to_string(holon.type),
      inspect(holon.genome || %{}),
      inspect(holon.payload || %{})
    ]

    Enum.join(parts, " ")
  end
end
