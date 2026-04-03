defmodule Indrajaal.AI.Graphiti.Store do
  @moduledoc """
  Temporal knowledge graph storage using Mnesia.

  ## Purpose

  Stores extracted facts with temporal validity, enabling point-in-time
  queries and fact evolution tracking. Uses Mnesia for distributed,
  in-memory storage with persistence.

  ## Temporal Semantics

  Facts have `valid_from` and `valid_until` timestamps. A fact is
  "current" if `valid_from <= now < valid_until` (or `valid_until` is nil).

  ## STAMP Constraints

  - SC-AI-207: Temporal fact storage
  - SC-AI-208: Point-in-time queries
  - SC-AI-209: Fact versioning

  ## Usage

      # Store a fact
      {:ok, fact_id} = Store.put_fact(fact, extraction_id)

      # Query current facts
      {:ok, facts} = Store.get_facts(entity: "Alice")

      # Query historical facts
      {:ok, facts} = Store.get_facts(entity: "Alice", at: ~U[2024-01-01 00:00:00Z])
  """

  require Logger

  alias Indrajaal.AI.Graphiti.Schema.{Fact, Extraction}

  @table :graphiti_facts
  @extractions_table :graphiti_extractions

  # Fact record structure for Mnesia
  # {id, source, target, label, category, confidence, extraction_id, valid_from, valid_until, metadata}
  @fact_attributes [
    :id,
    :source,
    :target,
    :label,
    :category,
    :confidence,
    :extraction_id,
    :valid_from,
    :valid_until,
    :metadata
  ]

  # Extraction record structure
  # {id, chain_of_thought, summary, entity_count, created_at, source_text_hash, metadata}
  @extraction_attributes [
    :id,
    :chain_of_thought,
    :summary,
    :entity_count,
    :created_at,
    :source_text_hash,
    :metadata
  ]

  @type fact_id :: binary()
  @type extraction_id :: binary()
  @type query_opts :: [
          entity: String.t(),
          label: String.t(),
          category: atom(),
          at: DateTime.t(),
          limit: non_neg_integer()
        ]

  @doc """
  Initialize Mnesia tables for the knowledge graph.

  Should be called during application startup.
  """
  @spec init() :: :ok | {:error, term()}
  def init do
    # Ensure Mnesia is started
    case :mnesia.system_info(:is_running) do
      :yes -> :ok
      :no -> :mnesia.start()
      :starting -> wait_for_mnesia()
      :stopping -> {:error, :mnesia_stopping}
    end

    create_tables()
  end

  @doc """
  Store a complete extraction with all its facts.

  ## Parameters

  - `extraction`: The extraction result
  - `source_text`: Original text (for deduplication hash)
  - `opts`: Storage options

  ## Returns

  - `{:ok, extraction_id}` on success
  - `{:error, reason}` on failure
  """
  @spec store_extraction(Extraction.t(), String.t(), keyword()) ::
          {:ok, extraction_id()} | {:error, term()}
  def store_extraction(%Extraction{} = extraction, source_text, opts \\ []) do
    extraction_id = generate_id()
    now = DateTime.utc_now()
    source_hash = :sha256 |> :crypto.hash(source_text) |> Base.encode16(case: :lower)

    extraction_record = {
      @extractions_table,
      extraction_id,
      extraction.chain_of_thought,
      extraction.summary,
      extraction.entity_count,
      now,
      source_hash,
      Keyword.get(opts, :metadata, %{})
    }

    transaction_result =
      :mnesia.transaction(fn ->
        # Store extraction
        :mnesia.write(extraction_record)

        # Store each fact
        Enum.each(extraction.facts, fn fact ->
          fact_id = generate_id()

          fact_record = {
            @table,
            fact_id,
            fact.source,
            fact.target,
            fact.label,
            fact.category,
            fact.confidence,
            extraction_id,
            now,
            # valid_until - nil means currently valid
            nil,
            %{}
          }

          :mnesia.write(fact_record)
        end)

        extraction_id
      end)

    case transaction_result do
      {:atomic, id} ->
        Logger.debug(
          "[Graphiti.Store] Stored extraction #{id} with #{length(extraction.facts)} facts"
        )

        {:ok, id}

      {:aborted, reason} ->
        Logger.error("[Graphiti.Store] Failed to store extraction: #{inspect(reason)}")
        {:error, {:storage_failed, reason}}
    end
  end

  @doc """
  Store a single fact.

  ## Parameters

  - `fact`: The fact to store
  - `extraction_id`: Optional parent extraction ID
  - `opts`: Storage options
  """
  @spec put_fact(Fact.t(), extraction_id() | nil, keyword()) ::
          {:ok, fact_id()} | {:error, term()}
  def put_fact(%Fact{} = fact, extraction_id \\ nil, opts \\ []) do
    fact_id = generate_id()
    now = DateTime.utc_now()

    # Check for existing fact to update (temporal upsert)
    existing = find_current_fact(fact.source, fact.target, fact.label)

    transaction_result =
      :mnesia.transaction(fn ->
        # If existing fact found, set its valid_until to now
        case existing do
          nil ->
            :ok

          {_table, old_id, src, tgt, lbl, cat, conf, ext_id, valid_from, _valid_until, meta} ->
            updated = {@table, old_id, src, tgt, lbl, cat, conf, ext_id, valid_from, now, meta}
            :mnesia.write(updated)
        end

        # Write new fact
        fact_record = {
          @table,
          fact_id,
          fact.source,
          fact.target,
          fact.label,
          fact.category,
          fact.confidence,
          extraction_id,
          now,
          nil,
          Keyword.get(opts, :metadata, %{})
        }

        :mnesia.write(fact_record)
        fact_id
      end)

    case transaction_result do
      {:atomic, id} -> {:ok, id}
      {:aborted, reason} -> {:error, {:storage_failed, reason}}
    end
  end

  @doc """
  Query facts from the knowledge graph.

  ## Options

  - `:entity` - Match facts where source or target equals entity
  - `:label` - Match facts with specific label
  - `:category` - Match facts with specific category
  - `:at` - Point-in-time query (defaults to current)
  - `:limit` - Maximum facts to return
  - `:include_historical` - Include superseded facts

  ## Returns

  - `{:ok, [Fact.t()]}` on success
  """
  @spec get_facts(query_opts()) :: {:ok, [Fact.t()]} | {:error, term()}
  def get_facts(opts \\ []) do
    query_time = Keyword.get(opts, :at, DateTime.utc_now())
    include_historical = Keyword.get(opts, :include_historical, false)
    limit = Keyword.get(opts, :limit, 100)

    match_spec = build_match_spec(opts, query_time, include_historical)

    transaction_result =
      :mnesia.transaction(fn ->
        :mnesia.select(@table, match_spec)
      end)

    case transaction_result do
      {:atomic, records} ->
        facts =
          records
          |> Enum.take(limit)
          |> Enum.map(&record_to_fact/1)

        {:ok, facts}

      {:aborted, reason} ->
        {:error, {:query_failed, reason}}
    end
  end

  @doc """
  Get facts related to a specific entity.

  Returns facts where the entity is either source or target.
  """
  @spec get_entity_facts(String.t(), query_opts()) :: {:ok, [Fact.t()]} | {:error, term()}
  def get_entity_facts(entity, opts \\ []) do
    get_facts(Keyword.put(opts, :entity, entity))
  end

  @doc """
  Get the knowledge graph as edges for visualization.
  """
  @spec get_graph(query_opts()) :: {:ok, %{nodes: [map()], edges: [map()]}} | {:error, term()}
  def get_graph(opts \\ []) do
    case get_facts(opts) do
      {:ok, facts} ->
        nodes =
          facts
          |> Enum.flat_map(fn f -> [{f.source, f.category}, {f.target, :concept}] end)
          |> Enum.uniq_by(&elem(&1, 0))
          |> Enum.map(fn {name, category} -> %{id: name, label: name, category: category} end)

        edges =
          facts
          |> Enum.map(fn f ->
            %{
              source: f.source,
              target: f.target,
              label: f.label,
              confidence: f.confidence
            }
          end)

        {:ok, %{nodes: nodes, edges: edges}}

      error ->
        error
    end
  end

  @doc """
  Invalidate (soft delete) a fact by setting valid_until to now.
  """
  @spec invalidate_fact(fact_id()) :: :ok | {:error, term()}
  def invalidate_fact(fact_id) do
    now = DateTime.utc_now()

    transaction_result =
      :mnesia.transaction(fn ->
        case :mnesia.read(@table, fact_id) do
          [{_table, id, src, tgt, lbl, cat, conf, ext_id, valid_from, _valid_until, meta}] ->
            updated = {@table, id, src, tgt, lbl, cat, conf, ext_id, valid_from, now, meta}
            :mnesia.write(updated)
            :ok

          [] ->
            {:error, :not_found}
        end
      end)

    case transaction_result do
      {:atomic, :ok} -> :ok
      {:atomic, {:error, reason}} -> {:error, reason}
      {:aborted, reason} -> {:error, {:transaction_failed, reason}}
    end
  end

  @doc """
  Get statistics about the knowledge graph.
  """
  @spec stats() :: {:ok, map()} | {:error, term()}
  def stats do
    transaction_result =
      :mnesia.transaction(fn ->
        all_facts =
          :mnesia.select(@table, [{{:_, :_, :_, :_, :_, :_, :_, :_, :_, :_, :_}, [], [:"$_"]}])

        all_extractions =
          :mnesia.select(@extractions_table, [{{:_, :_, :_, :_, :_, :_, :_, :_}, [], [:"$_"]}])

        current_facts =
          Enum.filter(all_facts, fn {_, _, _, _, _, _, _, _, _, _, valid_until, _} ->
            is_nil(valid_until)
          end)

        entities =
          current_facts
          |> Enum.flat_map(fn {_, _, _, src, tgt, _, _, _, _, _, _, _} -> [src, tgt] end)
          |> Enum.uniq()

        %{
          total_facts: length(all_facts),
          current_facts: length(current_facts),
          historical_facts: length(all_facts) - length(current_facts),
          unique_entities: length(entities),
          extractions: length(all_extractions)
        }
      end)

    case transaction_result do
      {:atomic, stats} -> {:ok, stats}
      {:aborted, reason} -> {:error, {:stats_failed, reason}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Table Management
  # ---------------------------------------------------------------------------

  defp create_tables do
    # Create facts table
    case :mnesia.create_table(@table,
           attributes: @fact_attributes,
           type: :set,
           disc_copies: [node()],
           index: [:source, :target, :label, :extraction_id]
         ) do
      {:atomic, :ok} ->
        Logger.info("[Graphiti.Store] Created #{@table} table")

      {:aborted, {:already_exists, @table}} ->
        Logger.debug("[Graphiti.Store] #{@table} table already exists")

      {:aborted, reason} ->
        Logger.error("[Graphiti.Store] Failed to create #{@table}: #{inspect(reason)}")
    end

    # Create extractions table
    case :mnesia.create_table(@extractions_table,
           attributes: @extraction_attributes,
           type: :set,
           disc_copies: [node()],
           index: [:source_text_hash]
         ) do
      {:atomic, :ok} ->
        Logger.info("[Graphiti.Store] Created #{@extractions_table} table")

      {:aborted, {:already_exists, @extractions_table}} ->
        Logger.debug("[Graphiti.Store] #{@extractions_table} table already exists")

      {:aborted, reason} ->
        Logger.error(
          "[Graphiti.Store] Failed to create #{@extractions_table}: #{inspect(reason)}"
        )
    end

    :ok
  end

  defp wait_for_mnesia do
    case :mnesia.wait_for_tables([@table, @extractions_table], 5000) do
      :ok -> :ok
      {:timeout, _} -> {:error, :mnesia_timeout}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Query Building
  # ---------------------------------------------------------------------------

  defp build_match_spec(opts, query_time, include_historical) do
    # Match pattern: {table, id, source, target, label, category, confidence, extraction_id, valid_from, valid_until, metadata}
    base_pattern = {@table, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9", :"$10"}

    guards = []

    # Entity filter (source or target matches)
    guards =
      case Keyword.get(opts, :entity) do
        nil -> guards
        entity -> [{:orelse, {:==, :"$2", entity}, {:==, :"$3", entity}} | guards]
      end

    # Label filter
    guards =
      case Keyword.get(opts, :label) do
        nil -> guards
        label -> [{:==, :"$4", label} | guards]
      end

    # Category filter
    guards =
      case Keyword.get(opts, :category) do
        nil -> guards
        category -> [{:==, :"$5", category} | guards]
      end

    # Temporal filter (unless including historical)
    guards =
      if include_historical do
        guards
      else
        # valid_from <= query_time AND (valid_until IS NULL OR valid_until > query_time)
        query_ts = DateTime.to_unix(query_time, :microsecond)

        [
          {:orelse, {:==, :"$9", nil}, {:>, {:element, 1, :"$9"}, query_ts}}
          | guards
        ]
      end

    # Build final match spec
    final_guards =
      case guards do
        [] -> []
        [single] -> [single]
        multiple -> [{:andalso} | multiple]
      end

    result = [:"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8", :"$9", :"$10"]

    [{base_pattern, final_guards, [result]}]
  end

  defp find_current_fact(source, target, label) do
    match_spec = [
      {
        {@table, :"$1", source, target, label, :"$5", :"$6", :"$7", :"$8", nil, :"$10"},
        [],
        [:"$_"]
      }
    ]

    case :mnesia.dirty_select(@table, match_spec) do
      [record | _] -> record
      [] -> nil
    end
  rescue
    _ -> nil
  end

  # ---------------------------------------------------------------------------
  # Private: Conversion
  # ---------------------------------------------------------------------------

  defp record_to_fact([
         id,
         source,
         target,
         label,
         category,
         confidence,
         _extraction_id,
         _valid_from,
         _valid_until,
         _metadata
       ]) do
    %Fact{
      source: source,
      target: target,
      label: label,
      category: category,
      confidence: confidence
    }
    |> Map.put(:id, id)
  end

  defp generate_id do
    16 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)
  end
end
