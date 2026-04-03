defmodule Indrajaal.AI.Graphiti.Pipeline do
  @moduledoc """
  Unified knowledge extraction and storage pipeline.

  ## Purpose

  Provides a single interface for extracting structured knowledge from text
  and storing it in the temporal graph. Integrates with the Simplex
  architecture for Guardian validation and cost monitoring.

  ## Architecture

  ```
  Text Input
      │
      ▼
  ┌─────────────────┐
  │ ContentInspector│ ◄── Security check
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │ GraphVerification│ ◄── Simplex validation
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │    Extractor    │ ◄── LLM + Schema validation
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │      Store      │ ◄── Mnesia temporal storage
  └────────┬────────┘
           │
           ▼
     Knowledge Graph
  ```

  ## STAMP Constraints

  - SC-AI-210: Pipeline validation before extraction
  - SC-AI-211: All extractions flow through Guardian
  - SC-AI-212: Cost tracking per extraction

  ## Usage

      # Extract and store
      {:ok, result} = Pipeline.process("Alice works at OpenRouter.")
      # => %{extraction_id: "...", facts: [...], stats: %{}}

      # Query the graph
      {:ok, facts} = Pipeline.query(entity: "Alice")

      # Get graph visualization data
      {:ok, graph} = Pipeline.get_graph()
  """

  require Logger

  alias Indrajaal.AI.Graphiti.{Extractor, Store}
  alias Indrajaal.AI.Graphiti.Schema.Extraction
  alias Indrajaal.AI.Security.ContentInspector
  alias Indrajaal.AI.Simplex.GraphVerification
  alias Indrajaal.AI.Simplex.TelemetryFlow

  @type process_opts :: [
          model: String.t(),
          source: atom(),
          store: boolean(),
          metadata: map()
        ]

  @type query_opts :: [
          entity: String.t(),
          label: String.t(),
          category: atom(),
          at: DateTime.t(),
          limit: non_neg_integer()
        ]

  @doc """
  Process text through the full extraction and storage pipeline.

  ## Parameters

  - `text`: The text to extract knowledge from
  - `opts`: Processing options
    - `:model` - LLM model to use
    - `:source` - Request source for telemetry (default: :graphiti)
    - `:store` - Whether to store results (default: true)
    - `:metadata` - Additional metadata to store

  ## Returns

  - `{:ok, result}` with extraction_id, facts, and stats
  - `{:error, reason}` on failure
  """
  @spec process(String.t(), process_opts()) :: {:ok, map()} | {:error, term()}
  def process(text, opts \\ []) when is_binary(text) do
    start_time = System.monotonic_time(:millisecond)
    source = Keyword.get(opts, :source, :graphiti)

    with :ok <- validate_input(text),
         {:ok, :clean} <- inspect_content(text),
         :ok <- verify_access(source),
         {:ok, extraction} <- extract(text, opts),
         {:ok, extraction_id} <- maybe_store(extraction, text, opts) do
      end_time = System.monotonic_time(:millisecond)
      latency = end_time - start_time

      emit_pipeline_telemetry(extraction, latency, source)

      result = %{
        extraction_id: extraction_id,
        facts: extraction.facts,
        entity_count: extraction.entity_count,
        summary: extraction.summary,
        chain_of_thought: extraction.chain_of_thought,
        latency_ms: latency
      }

      {:ok, result}
    end
  end

  @doc """
  Process multiple texts in batch.

  Returns partial results if some extractions fail.
  """
  @spec process_batch([String.t()], process_opts()) ::
          {:ok, [map()]} | {:partial, [map()], [term()]} | {:error, term()}
  def process_batch(texts, opts \\ []) when is_list(texts) do
    results =
      texts
      |> Task.async_stream(
        fn text -> process(text, opts) end,
        max_concurrency: 3,
        timeout: 120_000
      )
      |> Enum.map(fn
        {:ok, {:ok, result}} -> {:ok, result}
        {:ok, {:error, reason}} -> {:error, reason}
        {:exit, reason} -> {:error, {:timeout, reason}}
      end)

    successes = results |> Enum.filter(&match?({:ok, _}, &1)) |> Enum.map(&elem(&1, 1))
    failures = Enum.filter(results, &match?({:error, _}, &1))

    cond do
      Enum.empty?(failures) -> {:ok, successes}
      Enum.empty?(successes) -> {:error, {:all_failed, failures}}
      true -> {:partial, successes, failures}
    end
  end

  @doc """
  Extract knowledge without storing.

  Useful for preview/validation workflows.
  """
  @spec extract_only(String.t(), process_opts()) :: {:ok, Extraction.t()} | {:error, term()}
  def extract_only(text, opts \\ []) do
    with :ok <- validate_input(text),
         {:ok, :clean} <- inspect_content(text) do
      extract(text, opts)
    end
  end

  @doc """
  Query the knowledge graph.

  ## Options

  - `:entity` - Filter by entity name (source or target)
  - `:label` - Filter by relationship label
  - `:category` - Filter by entity category
  - `:at` - Point-in-time query
  - `:limit` - Maximum results

  ## Returns

  - `{:ok, [Fact.t()]}` on success
  """
  @spec query(query_opts()) :: {:ok, [map()]} | {:error, term()}
  def query(opts \\ []) do
    Store.get_facts(opts)
  end

  @doc """
  Get facts for a specific entity.
  """
  @spec entity_facts(String.t(), query_opts()) :: {:ok, [map()]} | {:error, term()}
  def entity_facts(entity, opts \\ []) do
    Store.get_entity_facts(entity, opts)
  end

  @doc """
  Get the knowledge graph structure for visualization.

  Returns nodes and edges suitable for graph rendering.
  """
  @spec get_graph(query_opts()) :: {:ok, %{nodes: [map()], edges: [map()]}} | {:error, term()}
  def get_graph(opts \\ []) do
    Store.get_graph(opts)
  end

  @doc """
  Get pipeline and storage statistics.
  """
  @spec stats() :: {:ok, map()} | {:error, term()}
  def stats do
    case Store.stats() do
      {:ok, store_stats} ->
        {:ok,
         Map.merge(store_stats, %{
           pipeline: :graphiti,
           version: "1.0.0"
         })}

      error ->
        error
    end
  end

  @doc """
  Initialize the Graphiti pipeline.

  Should be called during application startup to ensure Mnesia tables exist.
  """
  @spec init() :: :ok | {:error, term()}
  def init do
    Logger.info("[Graphiti.Pipeline] Initializing knowledge graph storage...")
    Store.init()
  end

  @doc """
  Health check for the pipeline.
  """
  @spec health_check() :: {:ok, :healthy} | {:error, term()}
  def health_check do
    with {:ok, _stats} <- stats() do
      {:ok, :healthy}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Validation Pipeline
  # ---------------------------------------------------------------------------

  defp validate_input(text) when is_binary(text) do
    cond do
      String.length(text) < 10 ->
        {:error, {:invalid_input, "text too short (minimum 10 characters)"}}

      String.length(text) > 100_000 ->
        {:error, {:invalid_input, "text too long (maximum 100,000 characters)"}}

      true ->
        :ok
    end
  end

  defp validate_input(_) do
    {:error, {:invalid_input, "text must be a string"}}
  end

  defp inspect_content(text) do
    case ContentInspector.inspect_prompt(text) do
      {:ok, :clean} -> {:ok, :clean}
      {:error, reason} -> {:error, {:content_blocked, reason}}
    end
  end

  defp verify_access(source) do
    proposal = %{
      source: source,
      target: :openrouter,
      timestamp: DateTime.utc_now(),
      confidence: 0.9
    }

    case GraphVerification.verify_topology(proposal) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, {:access_denied, reason}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Extraction
  # ---------------------------------------------------------------------------

  defp extract(text, opts) do
    Extractor.extract(text, opts)
  end

  # ---------------------------------------------------------------------------
  # Private: Storage
  # ---------------------------------------------------------------------------

  defp maybe_store(extraction, text, opts) do
    if Keyword.get(opts, :store, true) do
      metadata = Keyword.get(opts, :metadata, %{})
      Store.store_extraction(extraction, text, metadata: metadata)
    else
      # Return a dummy ID when not storing
      {:ok, "preview_#{:erlang.unique_integer([:positive])}"}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Telemetry
  # ---------------------------------------------------------------------------

  defp emit_pipeline_telemetry(extraction, latency, source) do
    TelemetryFlow.emit_ai_event(
      [:graphiti, :pipeline, :process],
      %{
        facts_count: length(extraction.facts),
        entity_count: extraction.entity_count,
        latency_ms: latency
      },
      %{
        source: source,
        stored: true
      }
    )
  end
end
