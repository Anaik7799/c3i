defmodule Indrajaal.KMS.Service do
  @moduledoc """
  Fractal Holonic Knowledge Management System - Shared Database Edition

  WHAT: Unified knowledge management using SQLite (OLTP) + DuckDB (OLAP).
  WHY: Shared databases accessible by both Elixir and F# cockpits.
  CONSTRAINTS: SC-KMS-001 (SQLite/DuckDB only), SC-KMS-002 (cross-runtime access)
  """

  use GenServer

  require Logger

  alias Indrajaal.KMS.SQLite
  alias Indrajaal.KMS.Analytics
  alias Indrajaal.Holon.DatabasePath

  # STAMP Constraints
  @stamp_constraints %{
    "SC-KMS-001" => "SQLite + DuckDB only - no ETS/DETS/Khepri",
    "SC-KMS-002" => "Cross-runtime access - Elixir and F# share databases",
    "SC-KMS-003" => "Portable holons - directory copy = full backup",
    "SC-KMS-004" => "OODA cycle <100ms on SQLite hot path",
    "SC-DBNAME-001" => "All holon databases use UHI naming",
    "SC-DBNAME-002" => "FQDN resolution is deterministic"
  }

  @type holon_id :: String.t()
  @type holon_type :: :knowledge | :process | :agent | :artifact | :index
  @type vital_signs :: %{health: float(), stress: float(), energy: float()}

  @type holon :: %{
          id: holon_id(),
          fqun: String.t(),
          type: holon_type(),
          name: String.t(),
          parent_id: holon_id() | nil,
          genome: map(),
          vital_signs: vital_signs(),
          membrane: map(),
          payload: map(),
          hlc_physical: non_neg_integer(),
          hlc_logical: non_neg_integer(),
          created_at: String.t(),
          updated_at: String.t()
        }

  @doc """
  Get the node-specific data directory path using UHI naming.

  Uses DatabasePath.holon_dir/1 with node-specific instance name.
  Path format: data/holons/ex/l3/kms/{node_instance}/
  """
  @spec data_dir() :: String.t()
  def data_dir do
    # Get node-specific instance name for UHI
    node_instance = get_node_instance()
    uhi = "ex:l3:kms:srv:#{node_instance}"

    case DatabasePath.holon_dir(uhi) do
      {:ok, dir} -> dir
      {:error, _} -> "data/holons/ex/l3/kms/#{node_instance}"
    end
  end

  @doc """
  Get the SQLite database path using FQDN resolution.

  FQDN: ex:l3:kms:srv:{node}:state -> data/holons/ex/l3/kms/{node}/state.sqlite
  """
  @spec sqlite_path() :: String.t()
  def sqlite_path do
    node_instance = get_node_instance()
    fqdn = "ex:l3:kms:srv:#{node_instance}:state"

    case DatabasePath.resolve(fqdn) do
      {:ok, path} -> path
      {:error, _} -> Path.join(data_dir(), "state.sqlite")
    end
  end

  @doc """
  Get the DuckDB database path using FQDN resolution.

  FQDN: ex:l3:kms:srv:{node}:history -> data/holons/ex/l3/kms/{node}/history.duckdb
  """
  @spec duckdb_path() :: String.t()
  def duckdb_path do
    node_instance = get_node_instance()
    fqdn = "ex:l3:kms:srv:#{node_instance}:history"

    case DatabasePath.resolve(fqdn) do
      {:ok, path} -> path
      {:error, _} -> Path.join(data_dir(), "history.duckdb")
    end
  end

  # Get sanitized node instance name for UHI
  defp get_node_instance do
    node_id = System.get_env("HOSTNAME") || "#{Node.self()}"
    String.replace(node_id, ~r/[^a-zA-Z0-9_-]/, "_")
  end

  @doc """
  Get STAMP constraints for this module.
  """
  @spec stamp_constraints() :: map()
  def stamp_constraints, do: @stamp_constraints

  # OTP / GenServer Callbacks

  @doc """
  Starts the KMS GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Perform initialization logic
    case initialize_databases() do
      :ok -> {:ok, %{}}
      {:error, reason} -> {:stop, reason}
    end
  end

  # Helper for init logic (renamed from original init/0 to avoid conflict)
  defp initialize_databases do
    with :ok <- ensure_data_dir(),
         :ok <- SQLite.init(sqlite_path()),
         :ok <- Analytics.init(duckdb_path(), sqlite_path()) do
      Logger.info("[KMS] Initialized databases at #{data_dir()}")
      :ok
    end
  end

  # Initialization (Public API for backward compatibility if needed, but primarily internal now)

  @doc """
  Initialize the KMS databases.
  """
  @spec init() :: :ok | {:error, term()}
  def init do
    initialize_databases()
  end

  # CRUD Operations (SQLite)

  @doc """
  Get a holon by ID.
  """
  @spec get_holon(holon_id()) :: {:ok, holon()} | {:error, :not_found | term()}
  def get_holon(holon_id) do
    SQLite.get_holon(sqlite_path(), holon_id)
  end

  @doc """
  Get a holon by FQUN (Fully-Qualified Unique Name).
  """
  @spec get_holon_by_fqun(String.t()) :: {:ok, holon()} | {:error, :not_found | term()}
  def get_holon_by_fqun(fqun) do
    SQLite.get_holon_by_fqun(sqlite_path(), fqun)
  end

  @doc """
  List all holons, optionally filtered by type.
  """
  @spec list_holons(keyword()) :: {:ok, [holon()]} | {:error, term()}
  def list_holons(opts \\ []) do
    SQLite.list_holons(sqlite_path(), opts)
  end

  @doc """
  Create a new holon.
  """
  @spec create_holon(map()) :: {:ok, holon()} | {:error, term()}
  def create_holon(attrs) do
    holon = build_holon(attrs)
    SQLite.insert_holon(sqlite_path(), holon)
  end

  @doc """
  Update a holon.
  """
  @spec update_holon(holon_id(), map()) :: {:ok, holon()} | {:error, term()}
  def update_holon(holon_id, attrs) do
    SQLite.update_holon(sqlite_path(), holon_id, attrs)
  end

  @doc """
  Delete a holon.
  """
  @spec delete_holon(holon_id()) :: :ok | {:error, term()}
  def delete_holon(holon_id) do
    SQLite.delete_holon(sqlite_path(), holon_id)
  end

  # Relationships

  @doc """
  Create a relationship between two holons.
  """
  @spec create_edge(holon_id(), holon_id(), atom(), keyword()) :: :ok | {:error, term()}
  def create_edge(source_id, target_id, relation, opts \\ []) do
    weight = Keyword.get(opts, :weight, 1.0)
    metadata = Keyword.get(opts, :metadata, %{})
    SQLite.insert_edge(sqlite_path(), source_id, target_id, relation, weight, metadata)
  end

  @doc """
  Create a relationship from a map (overload).
  """
  @spec create_edge(map()) :: :ok | {:error, term()}
  def create_edge(%{source_id: source, target_id: target, relation: rel} = edge) do
    weight = Map.get(edge, :weight, 1.0)
    metadata = Map.get(edge, :metadata, %{})
    # Convert string relation to atom if needed, or update SQLite to handle string
    # SQLite.insert_edge expects atom for relation but converts to string internally.
    # We'll ensure atom here if possible, or string.
    relation_atom = if is_binary(rel), do: String.to_atom(rel), else: rel
    SQLite.insert_edge(sqlite_path(), source, target, relation_atom, weight, metadata)
  end

  @doc """
  Get all edges for a holon.
  """
  @spec get_edges(holon_id()) :: {:ok, [map()]} | {:error, term()}
  def get_edges(holon_id) do
    SQLite.get_edges(sqlite_path(), holon_id)
  end

  @doc """
  List all edges with optional filtering.

  ## Options
    - `:type` - Filter by edge type/relation (atom or string)
    - `:limit` - Maximum results (default: 100)
  """
  @spec list_edges(keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_edges(opts \\ []) do
    SQLite.list_edges(sqlite_path(), opts)
  end

  @doc """
  Get all children of a holon.
  """
  @spec get_children(holon_id()) :: {:ok, [holon()]} | {:error, term()}
  def get_children(holon_id) do
    SQLite.get_children(sqlite_path(), holon_id)
  end

  @doc """
  Get all descendants of a holon (recursive).
  """
  @spec get_descendants(holon_id()) :: {:ok, [holon()]} | {:error, term()}
  def get_descendants(holon_id) do
    SQLite.get_descendants(sqlite_path(), holon_id)
  end

  # Search

  @doc """
  Full-text search using SQLite FTS5.
  """
  @spec search(String.t(), keyword()) :: {:ok, [holon()]} | {:error, term()}
  def search(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    SQLite.full_text_search(sqlite_path(), query, limit)
  end

  # Analytics (DuckDB)

  @doc """
  Get health report aggregating vital signs across all holons.
  """
  @spec health_report() :: {:ok, map()} | {:error, term()}
  def health_report do
    Analytics.health_report(duckdb_path(), sqlite_path())
  end

  @doc """
  Get event statistics over a time period.
  """
  @spec event_stats(keyword()) :: {:ok, [map()]} | {:error, term()}
  def event_stats(opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    Analytics.event_stats(duckdb_path(), sqlite_path(), days)
  end

  @doc """
  Get holons with high entropy (stale/degraded).
  """
  @spec entropy_report(float()) :: {:ok, [map()]} | {:error, term()}
  def entropy_report(threshold \\ 0.5) do
    Analytics.entropy_report(duckdb_path(), sqlite_path(), threshold)
  end

  @doc """
  Get holons ranked by decay (entropy > 0.2).
  Used by EvolutionEngine for Omega-Cycle.
  """
  @spec get_rotting_holons(integer()) :: {:ok, [map()]} | {:error, term()}
  def get_rotting_holons(limit \\ 5) do
    Analytics.get_rotting_holons(duckdb_path(), sqlite_path(), limit)
  end

  @doc """
  Export old events to Parquet for archival.
  """
  @spec archive_events(non_neg_integer()) :: {:ok, String.t()} | {:error, term()}
  def archive_events(days_old \\ 90) do
    archive_dir = Path.join(data_dir(), "archive")
    File.mkdir_p!(archive_dir)
    Analytics.archive_events(duckdb_path(), sqlite_path(), archive_dir, days_old)
  end

  # Event Logging

  @doc """
  Log an event for a holon.
  """
  @spec log_event(holon_id(), atom(), map()) :: :ok | {:error, term()}
  def log_event(holon_id, event_type, payload \\ %{}) do
    SQLite.log_event(sqlite_path(), holon_id, event_type, payload)
  end

  # Swarm Operations

  @doc """
  Extract a holon as a portable swarm cell.
  """
  @spec extract_swarm_cell(holon_id(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def extract_swarm_cell(holon_id, output_dir) do
    File.mkdir_p!(output_dir)

    with {:ok, holon} <- get_holon(holon_id),
         {:ok, descendants} <- get_descendants(holon_id) do
      cell_db = Path.join(output_dir, "holon.db")
      SQLite.export_holons(sqlite_path(), [holon | descendants], cell_db)

      # Write manifest
      manifest = build_manifest(holon)
      manifest_path = Path.join(output_dir, "manifest.json")
      File.write!(manifest_path, Jason.encode!(manifest, pretty: true))

      {:ok, output_dir}
    end
  end

  @doc """
  Merge a swarm cell back into the main database.
  """
  @spec merge_swarm_cell(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def merge_swarm_cell(cell_path) do
    cell_db = Path.join(cell_path, "holon.db")
    SQLite.import_holons(sqlite_path(), cell_db)
  end

  # Vectors (Delegated to Indrajaal.KMS.Vectors)

  @doc """
  Store an embedding for a holon.
  """
  @spec store_embedding(String.t(), [float()], keyword()) :: :ok | {:error, term()}
  defdelegate store_embedding(holon_id, embedding, opts \\ []), to: Indrajaal.KMS.Vectors

  @doc """
  Get embedding for a holon.
  """
  @spec get_embedding(String.t(), keyword()) :: {:ok, [float()]} | {:error, :not_found | term()}
  defdelegate get_embedding(holon_id, opts \\ []), to: Indrajaal.KMS.Vectors

  @doc """
  Perform similarity search using cosine similarity.
  """
  @spec similarity_search([float()], keyword()) :: {:ok, [map()]} | {:error, term()}
  defdelegate similarity_search(query_embedding, opts \\ []), to: Indrajaal.KMS.Vectors

  @doc """
  Ask the KMS Oracle a natural language question.
  Uses RAG (Retrieval-Augmented Generation) via OpenRouter.
  """
  @spec ask_oracle(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  defdelegate ask_oracle(query, opts \\ []), to: Indrajaal.KMS.AI

  # ---------------------------------------------------------------------------
  # Web Knowledge (Delegated to Indrajaal.KMS.WebKnowledge)
  # SC-KMS-020 to SC-KMS-023: Internet Knowledge Retrieval
  # ---------------------------------------------------------------------------

  @doc """
  Search the internet for knowledge on a topic.
  Results are cached and optionally stored as temporary knowledge holons.
  """
  @spec web_search(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  defdelegate web_search(query, opts \\ []), to: Indrajaal.KMS.WebKnowledge, as: :search

  @doc """
  Fetch and extract knowledge from a specific URL.
  """
  @spec fetch_url(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  defdelegate fetch_url(url, opts \\ []), to: Indrajaal.KMS.WebKnowledge

  @doc """
  Ask oracle with web-augmented context.
  Combines local KMS knowledge with fresh web search results.
  """
  @spec ask_oracle_augmented(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  defdelegate ask_oracle_augmented(query, opts \\ []),
    to: Indrajaal.KMS.WebKnowledge,
    as: :ask_augmented

  @doc """
  Get web knowledge cache statistics.
  """
  @spec web_cache_stats() :: {:ok, map()}
  defdelegate web_cache_stats(), to: Indrajaal.KMS.WebKnowledge, as: :cache_stats

  @doc """
  Add a dependency between two tasks.
  """
  @spec add_dependency(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  defdelegate add_dependency(blocking_id, blocked_id), to: Indrajaal.KMS.Todos

  # Private Functions

  defp ensure_data_dir do
    File.mkdir_p!(data_dir())
    :ok
  end

  defp build_holon(attrs) do
    holon_id = generate_holon_id()
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    {physical, logical} = get_hlc_timestamp()

    %{
      id: holon_id,
      fqun: build_fqun(attrs, holon_id),
      type: to_string(attrs[:type] || :knowledge),
      name: attrs[:name] || "unnamed",
      parent_id: attrs[:parent_id],
      genome: Jason.encode!(attrs[:genome] || %{schema_version: "1.0.0"}),
      vital_signs: Jason.encode!(%{health: 1.0, stress: 0.0, energy: 1.0}),
      membrane: Jason.encode!(attrs[:membrane] || %{}),
      payload: Jason.encode!(attrs[:payload] || %{}),
      hlc_physical: physical,
      hlc_logical: logical,
      created_at: now,
      updated_at: now
    }
  end

  defp generate_holon_id do
    "hln_" <> Base.encode32(:crypto.strong_rand_bytes(8), case: :lower, padding: false)
  end

  defp build_fqun(attrs, holon_id) do
    type = attrs[:type] || :knowledge
    name = attrs[:name] || "unnamed"
    # Use short node name or "local"
    node_name =
      case node() do
        :nonode@nohost -> "local"
        n -> n |> to_string() |> String.split("@") |> List.first()
      end

    "kms/l3/#{type}/default/#{name}@#{node_name}##{holon_id}"
  end

  defp get_hlc_timestamp do
    # Try to use HLC if available, fallback to system time
    alias Indrajaal.Observability.Fractal.HybridLogicalClock, as: HLC

    case function_exported?(HLC, :now, 0) && HLC.now() do
      {:ok, timestamp} ->
        physical = div(timestamp, 65_536)
        logical = rem(timestamp, 65_536)
        {physical, logical}

      _ ->
        {System.system_time(:microsecond), 0}
    end
  end

  defp build_manifest(holon) do
    encoded = Jason.encode!(holon)
    hash_result = :crypto.hash(:sha256, encoded)
    checksum = hash_result |> Base.encode16(case: :lower)
    node_name = node()
    home_origin = node_name |> to_string()
    exported_at = DateTime.utc_now() |> DateTime.to_iso8601()

    %{
      identity: %{
        id: holon.id,
        fqun: holon.fqun,
        checksum: checksum
      },
      genome: Jason.decode!(holon.genome),
      vital_signs: Jason.decode!(holon.vital_signs),
      reconstruction: %{
        home_origin: home_origin,
        peers: [],
        last_sync_hlc: [holon.hlc_physical, holon.hlc_logical]
      },
      exported_at: exported_at
    }
  end
end
