defmodule Indrajaal.Semantic.Client do
  @moduledoc """
  High-level API for F# Semantic Layer Operations

  WHAT: Provides idiomatic Elixir API for RDF triple store, SPARQL queries,
        vector similarity search, and zettel processing.

  WHY: Abstracts JSON-RPC complexity and provides type-safe, documented
       interface for semantic operations.

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-11 | Claude | Initial implementation |

  ## STAMP Compliance
  - SC-SYNC-001: Bridge timeout < 5s
  - SC-PRF-050: Response latency < 50ms target

  ## Usage

      # Add RDF triple
      {:ok, _} = Client.add_triple("user:1", "rdf:type", "Person")

      # Execute SPARQL query
      {:ok, results} = Client.query("SELECT * WHERE {?s rdf:type Person}")

      # Find similar entities
      {:ok, similar} = Client.find_similar("user:1", limit: 10)

      # Process zettel
      {:ok, processed} = Client.process_zettel("202601111200", "# My Note", %{tags: ["idea"]})
  """

  alias Indrajaal.Semantic.Bridge

  require Logger

  @default_timeout 5000

  @doc """
  Add an RDF triple to the semantic store.

  ## Parameters
    * `subject` - Subject URI or string
    * `predicate` - Predicate URI
    * `object` - Object URI, literal, or string

  ## Examples

      {:ok, _} = Client.add_triple("user:1", "rdf:type", "Person")
      {:ok, _} = Client.add_triple("user:1", "foaf:name", "Alice")
  """
  @spec add_triple(String.t(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def add_triple(subject, predicate, object) do
    params = %{
      subject: subject,
      predicate: predicate,
      object: object
    }

    case Bridge.call("triple.add", params, @default_timeout) do
      {:ok, result} ->
        :telemetry.execute([:semantic, :triple, :add], %{count: 1}, %{})
        {:ok, result}

      {:error, type, details} ->
        Logger.error("Failed to add triple",
          subject: subject,
          predicate: predicate,
          object: object,
          error: type,
          details: details
        )

        {:error, {type, details}}

      error ->
        {:error, error}
    end
  end

  @doc """
  Add multiple triples in a batch.

  ## Parameters
    * `triples` - List of {subject, predicate, object} tuples

  ## Examples

      triples = [
        {"user:1", "rdf:type", "Person"},
        {"user:1", "foaf:name", "Alice"}
      ]
      {:ok, count} = Client.add_triples(triples)
  """
  @spec add_triples([{String.t(), String.t(), String.t()}]) :: {:ok, map()} | {:error, term()}
  def add_triples(triples) when is_list(triples) do
    params = %{
      triples:
        Enum.map(triples, fn {s, p, o} ->
          %{subject: s, predicate: p, object: o}
        end)
    }

    case Bridge.call("triple.add_batch", params, @default_timeout) do
      {:ok, result} ->
        :telemetry.execute([:semantic, :triple, :add_batch], %{count: length(triples)}, %{})
        {:ok, result}

      {:error, type, details} ->
        Logger.error("Failed to add triple batch", error: type, details: details)
        {:error, {type, details}}

      error ->
        {:error, error}
    end
  end

  @doc """
  Remove an RDF triple from the semantic store.

  ## Parameters
    * `subject` - Subject URI or string
    * `predicate` - Predicate URI
    * `object` - Object URI, literal, or string
  """
  @spec remove_triple(String.t(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def remove_triple(subject, predicate, object) do
    params = %{
      subject: subject,
      predicate: predicate,
      object: object
    }

    case Bridge.call("triple.remove", params, @default_timeout) do
      {:ok, result} ->
        :telemetry.execute([:semantic, :triple, :remove], %{count: 1}, %{})
        {:ok, result}

      {:error, type, details} ->
        {:error, {type, details}}

      error ->
        {:error, error}
    end
  end

  # ============================================================================
  # Query Operations
  # ============================================================================

  @doc """
  Execute a SPARQL query against the semantic store.

  ## Parameters
    * `query` - SPARQL query string
    * `opts` - Options:
      * `:timeout` - Query timeout in ms (default: 5000)
      * `:limit` - Result limit

  ## Examples

      {:ok, results} = Client.query("SELECT * WHERE {?s rdf:type Person}")

      {:ok, results} = Client.query(
        "SELECT ?name WHERE {?s foaf:name ?name}",
        limit: 10
      )
  """
  @spec query(String.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def query(sparql_query, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    limit = Keyword.get(opts, :limit)

    params = %{query: sparql_query}
    params = if limit, do: Map.put(params, :limit, limit), else: params

    start = System.monotonic_time(:millisecond)

    case Bridge.call("query.sparql", params, timeout) do
      {:ok, %{"results" => results}} ->
        duration = System.monotonic_time(:millisecond) - start

        :telemetry.execute(
          [:semantic, :query, :sparql],
          %{duration_ms: duration, result_count: length(results)},
          %{}
        )

        {:ok, results}

      {:error, type, details} ->
        Logger.error("SPARQL query failed", query: sparql_query, error: type, details: details)
        {:error, {type, details}}

      error ->
        {:error, error}
    end
  end

  @doc """
  Execute a simple pattern query.

  ## Parameters
    * `subject` - Subject pattern (use nil for wildcard)
    * `predicate` - Predicate pattern (use nil for wildcard)
    * `object` - Object pattern (use nil for wildcard)

  ## Examples

      # Find all properties of user:1
      {:ok, triples} = Client.query_pattern("user:1", nil, nil)

      # Find all entities of type Person
      {:ok, triples} = Client.query_pattern(nil, "rdf:type", "Person")
  """
  @spec query_pattern(String.t() | nil, String.t() | nil, String.t() | nil) ::
          {:ok, list(map())} | {:error, term()}
  def query_pattern(subject, predicate, object) do
    params = %{
      subject: subject,
      predicate: predicate,
      object: object
    }

    case Bridge.call("query.pattern", params, @default_timeout) do
      {:ok, %{"triples" => triples}} ->
        {:ok, triples}

      {:error, type, details} ->
        {:error, {type, details}}

      error ->
        {:error, error}
    end
  end

  # ============================================================================
  # Vector Similarity Operations
  # ============================================================================

  @doc """
  Find similar entities using vector similarity search.

  ## Parameters
    * `entity_id` - Entity ID to find similar entities for
    * `opts` - Options:
      * `:limit` - Number of results (default: 10)
      * `:threshold` - Similarity threshold (0.0 - 1.0)
      * `:include_distances` - Include similarity scores (default: true)

  ## Examples

      {:ok, similar} = Client.find_similar("user:1", limit: 5)

      {:ok, similar} = Client.find_similar("zettel:123", threshold: 0.8)
  """
  @spec find_similar(String.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def find_similar(entity_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    threshold = Keyword.get(opts, :threshold)
    include_distances = Keyword.get(opts, :include_distances, true)

    params = %{
      entity_id: entity_id,
      limit: limit,
      include_distances: include_distances
    }

    params = if threshold, do: Map.put(params, :threshold, threshold), else: params

    case Bridge.call("vector.similar", params, @default_timeout) do
      {:ok, %{"results" => results}} ->
        :telemetry.execute(
          [:semantic, :vector, :similar],
          %{result_count: length(results)},
          %{entity_id: entity_id}
        )

        {:ok, results}

      {:error, type, details} ->
        Logger.error("Vector similarity search failed",
          entity_id: entity_id,
          error: type,
          details: details
        )

        {:error, {type, details}}

      error ->
        {:error, error}
    end
  end

  @doc """
  Add or update a vector embedding for an entity.

  ## Parameters
    * `entity_id` - Entity ID
    * `vector` - Embedding vector (list of floats)
    * `metadata` - Optional metadata map
  """
  @spec add_vector(String.t(), list(float()), map()) :: {:ok, map()} | {:error, term()}
  def add_vector(entity_id, vector, metadata \\ %{}) when is_list(vector) do
    params = %{
      entity_id: entity_id,
      vector: vector,
      metadata: metadata
    }

    case Bridge.call("vector.add", params, @default_timeout) do
      {:ok, result} ->
        {:ok, result}

      {:error, type, details} ->
        {:error, {type, details}}

      error ->
        {:error, error}
    end
  end

  # ============================================================================
  # Zettel Processing
  # ============================================================================

  @doc """
  Process a zettelkasten note (zettel).

  This performs:
  1. Markdown parsing
  2. Tag extraction
  3. Link extraction
  4. Vector embedding generation
  5. Triple store updates
  6. Similarity linking

  ## Parameters
    * `zettel_id` - Zettel ID (usually timestamp like "202601111200")
    * `content` - Markdown content
    * `metadata` - Metadata map with:
      * `:tags` - List of tags
      * `:title` - Note title
      * `:author` - Author

  ## Examples

      {:ok, processed} = Client.process_zettel(
        "202601111200",
        "# My Note\n\nSome content with [[links]]",
        %{tags: ["idea", "work"], title: "My Note"}
      )
  """
  @spec process_zettel(String.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def process_zettel(zettel_id, content, metadata \\ %{}) do
    params = %{
      zettel_id: zettel_id,
      content: content,
      metadata: metadata
    }

    # Zettel processing may take longer
    timeout = 10_000

    start = System.monotonic_time(:millisecond)

    case Bridge.call("zettel.process", params, timeout) do
      {:ok, result} ->
        duration = System.monotonic_time(:millisecond) - start

        :telemetry.execute(
          [:semantic, :zettel, :process],
          %{duration_ms: duration},
          %{zettel_id: zettel_id}
        )

        {:ok, result}

      {:error, type, details} ->
        Logger.error("Zettel processing failed",
          zettel_id: zettel_id,
          error: type,
          details: details
        )

        {:error, {type, details}}

      error ->
        {:error, error}
    end
  end

  @doc """
  Get backlinks for a zettel.

  ## Parameters
    * `zettel_id` - Zettel ID

  ## Returns
    List of zettels that link to this zettel
  """
  @spec get_backlinks(String.t()) :: {:ok, list(map())} | {:error, term()}
  def get_backlinks(zettel_id) do
    params = %{zettel_id: zettel_id}

    case Bridge.call("zettel.backlinks", params, @default_timeout) do
      {:ok, %{"backlinks" => backlinks}} ->
        {:ok, backlinks}

      {:error, type, details} ->
        {:error, {type, details}}

      error ->
        {:error, error}
    end
  end

  @doc """
  Get forward links from a zettel.

  ## Parameters
    * `zettel_id` - Zettel ID

  ## Returns
    List of zettels that this zettel links to
  """
  @spec get_forward_links(String.t()) :: {:ok, list(map())} | {:error, term()}
  def get_forward_links(zettel_id) do
    params = %{zettel_id: zettel_id}

    case Bridge.call("zettel.forward_links", params, @default_timeout) do
      {:ok, %{"links" => links}} ->
        {:ok, links}

      {:error, type, details} ->
        {:error, {type, details}}

      error ->
        {:error, error}
    end
  end

  # ============================================================================
  # Health & Utilities
  # ============================================================================

  @doc """
  Check semantic layer health.
  """
  @spec health() :: {:ok, map()} | {:error, term()}
  def health do
    Bridge.health_check()
  end

  @doc """
  Get semantic store statistics.
  """
  @spec stats() :: {:ok, map()} | {:error, term()}
  def stats do
    case Bridge.call("system.stats", %{}, @default_timeout) do
      {:ok, stats} ->
        {:ok, stats}

      error ->
        {:error, error}
    end
  end
end
