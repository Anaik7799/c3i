defmodule Indrajaal.KMS.GraphitiBridge do
  @moduledoc """
  Bidirectional synchronization between Graphiti knowledge graph and KMS holons.

  ## Purpose

  Bridges the temporal knowledge graph (Graphiti/Mnesia) with the fractal holonic
  KMS (SQLite/DuckDB), enabling:
  - Extracted facts to become queryable holons
  - Holon relationships to inform graph queries
  - Unified knowledge view across both systems

  ## Sync Directions

  1. **Graphiti → KMS**: Extracted facts become holons with type :knowledge
  2. **KMS → Graphiti**: Holon edges create graph relationships
  3. **Real-time**: PubSub events trigger incremental sync

  ## STAMP Constraints

  - SC-KMS-010: Bidirectional graph-holon sync
  - SC-KMS-011: Eventual consistency within 5s
  - SC-KMS-012: Conflict resolution via timestamp ordering

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
  alias Indrajaal.KMS.SQLite
  alias Indrajaal.AI.Graphiti.Store, as: GraphitiStore
  alias Indrajaal.AI.Graphiti.Schema.{Fact, Extraction}

  @sync_interval 5_000
  @batch_size 100

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc """
  Start the GraphitiBridge GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sync a Graphiti extraction to KMS holons.

  Creates holons for:
  - Each unique entity (source/target) as type :knowledge
  - Each fact as an edge between entity holons

  ## Parameters

  - `extraction`: The Graphiti extraction result
  - `opts`: Sync options
    - `:parent_id` - Optional parent holon for all created holons
    - `:namespace` - Namespace prefix for FQUNs

  ## Returns

  - `{:ok, %{holons: count, edges: count}}` on success
  """
  @spec sync_extraction(Extraction.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def sync_extraction(%Extraction{} = extraction, opts \\ []) do
    GenServer.call(__MODULE__, {:sync_extraction, extraction, opts}, 30_000)
  end

  @doc """
  Sync a single Graphiti fact to KMS.

  Creates or updates:
  - Source entity holon
  - Target entity holon
  - Edge between them with the fact label

  ## Parameters

  - `fact`: The Graphiti fact
  - `opts`: Sync options
  """
  @spec sync_fact(Fact.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def sync_fact(%Fact{} = fact, opts \\ []) do
    GenServer.call(__MODULE__, {:sync_fact, fact, opts})
  end

  @doc """
  Sync a KMS holon to Graphiti.

  Creates a fact if the holon has relationships defined in its genome.

  ## Parameters

  - `holon_id`: The KMS holon ID
  - `opts`: Sync options
  """
  @spec sync_holon_to_graphiti(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def sync_holon_to_graphiti(holon_id, opts \\ []) do
    GenServer.call(__MODULE__, {:sync_holon, holon_id, opts})
  end

  @doc """
  Sync all KMS edges to Graphiti facts.

  Iterates through KMS edges and creates corresponding Graphiti facts.
  """
  @spec sync_edges_to_graphiti(keyword()) :: {:ok, map()} | {:error, term()}
  def sync_edges_to_graphiti(opts \\ []) do
    GenServer.call(__MODULE__, {:sync_edges, opts}, 60_000)
  end

  @doc """
  Full bidirectional sync between Graphiti and KMS.

  Performs:
  1. Graphiti facts → KMS holons
  2. KMS edges → Graphiti facts
  """
  @spec full_sync(keyword()) :: {:ok, map()} | {:error, term()}
  def full_sync(opts \\ []) do
    GenServer.call(__MODULE__, {:full_sync, opts}, 120_000)
  end

  @doc """
  Get sync statistics.
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
    # Subscribe to KMS events
    Phoenix.PubSub.subscribe(Indrajaal.PubSub, "kms:holons")
    Phoenix.PubSub.subscribe(Indrajaal.PubSub, "kms:edges")

    # Schedule periodic sync check
    if Keyword.get(opts, :auto_sync, true) do
      Process.send_after(self(), :sync_check, @sync_interval)
    end

    state = %{
      synced_holons: 0,
      synced_facts: 0,
      synced_edges: 0,
      last_sync: nil,
      pending_facts: [],
      pending_holons: [],
      opts: opts
    }

    Logger.info("[GraphitiBridge] Initialized")
    {:ok, state}
  end

  @impl true
  def handle_call({:sync_extraction, extraction, opts}, _from, state) do
    result = do_sync_extraction(extraction, opts)

    new_state =
      case result do
        {:ok, %{holons: h, edges: e}} ->
          %{state | synced_holons: state.synced_holons + h, synced_edges: state.synced_edges + e}

        _ ->
          state
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:sync_fact, fact, opts}, _from, state) do
    result = do_sync_fact(fact, opts)

    new_state =
      case result do
        {:ok, _} ->
          %{state | synced_facts: state.synced_facts + 1}

        _ ->
          state
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:sync_holon, holon_id, opts}, _from, state) do
    result = do_sync_holon_to_graphiti(holon_id, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:sync_edges, opts}, _from, state) do
    result = do_sync_edges_to_graphiti(opts)

    new_state =
      case result do
        {:ok, %{facts: f}} ->
          %{state | synced_facts: state.synced_facts + f, last_sync: DateTime.utc_now()}

        _ ->
          state
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:full_sync, opts}, _from, state) do
    result = do_full_sync(opts)

    new_state =
      case result do
        {:ok, stats} ->
          %{
            state
            | synced_holons: state.synced_holons + Map.get(stats, :holons, 0),
              synced_facts: state.synced_facts + Map.get(stats, :facts, 0),
              synced_edges: state.synced_edges + Map.get(stats, :edges, 0),
              last_sync: DateTime.utc_now()
          }

        _ ->
          state
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      synced_holons: state.synced_holons,
      synced_facts: state.synced_facts,
      synced_edges: state.synced_edges,
      last_sync: state.last_sync,
      pending_facts: length(state.pending_facts),
      pending_holons: length(state.pending_holons)
    }

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_info(:sync_check, state) do
    # Process pending items
    new_state = process_pending(state)

    # Schedule next check
    Process.send_after(self(), :sync_check, @sync_interval)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:holon_created, holon}, state) do
    # Queue holon for sync to Graphiti
    new_pending = [holon | state.pending_holons] |> Enum.take(@batch_size)
    {:noreply, %{state | pending_holons: new_pending}}
  end

  @impl true
  def handle_info({:holon_updated, holon}, state) do
    # Queue holon for sync to Graphiti
    new_pending = [holon | state.pending_holons] |> Enum.take(@batch_size)
    {:noreply, %{state | pending_holons: new_pending}}
  end

  @impl true
  def handle_info({:edge_created, edge}, state) do
    # Convert edge to fact and sync
    case edge_to_fact(edge) do
      {:ok, fact} ->
        spawn(fn -> GraphitiStore.put_fact(fact) end)
        {:noreply, %{state | synced_facts: state.synced_facts + 1}}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private: Graphiti → KMS Sync
  # ---------------------------------------------------------------------------

  defp do_sync_extraction(%Extraction{facts: facts} = extraction, opts) do
    namespace = Keyword.get(opts, :namespace, "graphiti")
    parent_id = Keyword.get(opts, :parent_id)

    # Collect unique entities
    entities =
      facts
      |> Enum.flat_map(fn f -> [{f.source, f.category}, {f.target, :concept}] end)
      |> Enum.uniq_by(&elem(&1, 0))

    # Create holons for entities
    entity_holons =
      Enum.reduce(entities, %{}, fn {name, category}, acc ->
        case create_or_get_entity_holon(name, category, namespace, parent_id) do
          {:ok, holon_id} -> Map.put(acc, name, holon_id)
          _ -> acc
        end
      end)

    # Create edges for facts
    edges_created =
      facts
      |> Enum.count(fn fact ->
        source_id = Map.get(entity_holons, fact.source)
        target_id = Map.get(entity_holons, fact.target)

        if source_id && target_id do
          case create_fact_edge(source_id, target_id, fact) do
            {:ok, _} -> true
            _ -> false
          end
        else
          false
        end
      end)

    # Create summary holon for the extraction
    summary_holon_result =
      if extraction.summary do
        create_extraction_summary_holon(extraction, namespace, parent_id)
      else
        {:ok, nil}
      end

    case summary_holon_result do
      {:ok, _} ->
        {:ok, %{holons: map_size(entity_holons), edges: edges_created}}

      error ->
        error
    end
  end

  defp create_or_get_entity_holon(name, category, namespace, parent_id) do
    fqun = "#{namespace}/entity/#{slugify(name)}"

    # Try to find existing holon by FQUN
    case SQLite.query("SELECT id FROM holons WHERE fqun = ?", [fqun]) do
      {:ok, [[id]]} ->
        {:ok, id}

      {:ok, []} ->
        # Create new holon
        holon = %{
          fqun: fqun,
          type: :knowledge,
          name: name,
          parent_id: parent_id,
          genome: %{
            category: category,
            source: :graphiti,
            synced_at: DateTime.utc_now() |> DateTime.to_iso8601()
          },
          payload: %{entity_name: name}
        }

        case KMS.create_holon(holon) do
          {:ok, created} -> {:ok, created.id}
          error -> error
        end

      error ->
        error
    end
  end

  defp create_fact_edge(source_id, target_id, %Fact{} = fact) do
    edge = %{
      source_id: source_id,
      target_id: target_id,
      relation: fact.label,
      weight: fact.confidence / 100.0,
      metadata: %{
        category: fact.category,
        source: :graphiti,
        synced_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }

    KMS.create_edge(edge)
  end

  defp create_extraction_summary_holon(%Extraction{} = extraction, namespace, parent_id) do
    holon = %{
      fqun: "#{namespace}/extraction/#{generate_id()}",
      type: :artifact,
      name: "Extraction: #{String.slice(extraction.summary || "", 0..50)}",
      parent_id: parent_id,
      genome: %{
        chain_of_thought: extraction.chain_of_thought,
        entity_count: extraction.entity_count,
        fact_count: length(extraction.facts),
        source: :graphiti
      },
      payload: %{summary: extraction.summary}
    }

    case KMS.create_holon(holon) do
      {:ok, created} -> {:ok, created.id}
      error -> error
    end
  end

  defp do_sync_fact(%Fact{} = fact, opts) do
    namespace = Keyword.get(opts, :namespace, "graphiti")
    parent_id = Keyword.get(opts, :parent_id)

    with {:ok, source_id} <-
           create_or_get_entity_holon(fact.source, fact.category, namespace, parent_id),
         {:ok, target_id} <-
           create_or_get_entity_holon(fact.target, :concept, namespace, parent_id),
         {:ok, edge} <- create_fact_edge(source_id, target_id, fact) do
      {:ok, %{source_id: source_id, target_id: target_id, edge_id: edge.id}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: KMS → Graphiti Sync
  # ---------------------------------------------------------------------------

  defp do_sync_holon_to_graphiti(holon_id, _opts) do
    case KMS.get_holon(holon_id) do
      {:ok, holon} ->
        # Get holon's outgoing edges
        case KMS.get_edges(holon_id) do
          {:ok, edges} ->
            facts_created =
              edges
              |> Enum.count(fn edge ->
                case holon_edge_to_fact(holon, edge) do
                  {:ok, fact} ->
                    case GraphitiStore.put_fact(fact) do
                      {:ok, _} -> true
                      _ -> false
                    end

                  _ ->
                    false
                end
              end)

            {:ok, %{facts: facts_created}}

          error ->
            error
        end

      error ->
        error
    end
  end

  defp do_sync_edges_to_graphiti(_opts) do
    # Get all edges from KMS
    case SQLite.query("SELECT source_id, target_id, label, weight, metadata FROM edges LIMIT ?", [
           @batch_size
         ]) do
      {:ok, rows} ->
        facts_created =
          rows
          |> Enum.count(fn [source_id, target_id, label, weight, metadata] ->
            case edge_row_to_fact(source_id, target_id, label, weight, metadata) do
              {:ok, fact} ->
                case GraphitiStore.put_fact(fact) do
                  {:ok, _} -> true
                  _ -> false
                end

              _ ->
                false
            end
          end)

        {:ok, %{facts: facts_created}}

      error ->
        error
    end
  end

  defp do_full_sync(opts) do
    # Sync Graphiti → KMS
    graphiti_result =
      case GraphitiStore.get_facts(limit: @batch_size) do
        {:ok, facts} ->
          synced =
            facts
            |> Enum.count(fn fact ->
              case do_sync_fact(fact, opts) do
                {:ok, _} -> true
                _ -> false
              end
            end)

          %{holons: synced, edges: synced}

        _ ->
          %{holons: 0, edges: 0}
      end

    # Sync KMS → Graphiti
    kms_result =
      case do_sync_edges_to_graphiti(opts) do
        {:ok, stats} -> stats
        _ -> %{facts: 0}
      end

    {:ok, Map.merge(graphiti_result, kms_result)}
  end

  defp holon_edge_to_fact(source_holon, edge) do
    # Get target holon
    case KMS.get_holon(edge.target_id) do
      {:ok, target_holon} ->
        fact = %Fact{
          source: source_holon.name,
          target: target_holon.name,
          label: edge.label |> String.upcase() |> String.replace(" ", "_"),
          category: holon_type_to_category(source_holon.type),
          confidence: round((edge.weight || 1.0) * 100)
        }

        {:ok, fact}

      error ->
        error
    end
  end

  defp edge_to_fact(edge) do
    with {:ok, source} <- KMS.get_holon(edge.source_id),
         {:ok, target} <- KMS.get_holon(edge.target_id) do
      fact = %Fact{
        source: source.name,
        target: target.name,
        label: normalize_label(edge.label),
        category: holon_type_to_category(source.type),
        confidence: round((edge.weight || 1.0) * 100)
      }

      {:ok, fact}
    end
  end

  defp edge_row_to_fact(source_id, target_id, label, weight, _metadata) do
    with {:ok, source} <- KMS.get_holon(source_id),
         {:ok, target} <- KMS.get_holon(target_id) do
      fact = %Fact{
        source: source.name,
        target: target.name,
        label: normalize_label(label),
        category: holon_type_to_category(source.type),
        confidence: round((weight || 1.0) * 100)
      }

      {:ok, fact}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Helpers
  # ---------------------------------------------------------------------------

  defp process_pending(state) do
    # Process pending holons
    new_pending_holons =
      state.pending_holons
      |> Enum.drop_while(fn holon ->
        case do_sync_holon_to_graphiti(holon.id, state.opts) do
          {:ok, _} -> true
          _ -> false
        end
      end)

    %{state | pending_holons: new_pending_holons}
  end

  defp holon_type_to_category(:knowledge), do: :concept
  defp holon_type_to_category(:process), do: :event
  defp holon_type_to_category(:agent), do: :person
  defp holon_type_to_category(:artifact), do: :product
  defp holon_type_to_category(:decision), do: :concept
  defp holon_type_to_category(:architecture), do: :technology
  defp holon_type_to_category(_), do: :concept

  defp normalize_label(nil), do: "RELATED_TO"

  defp normalize_label(label) when is_binary(label) do
    label
    |> String.upcase()
    |> String.replace(~r/[^A-Z0-9]/, "_")
    |> String.replace(~r/_+/, "_")
    |> String.trim("_")
  end

  defp normalize_label(label), do: normalize_label(to_string(label))

  defp slugify(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.slice(0..63)
  end

  defp slugify(name), do: slugify(to_string(name))

  defp generate_id do
    8 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)
  end
end
