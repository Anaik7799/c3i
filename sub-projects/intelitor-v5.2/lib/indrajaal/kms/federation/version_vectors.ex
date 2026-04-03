defmodule Indrajaal.KMS.Federation.VersionVectors do
  @moduledoc """
  L5 Version Vectors: CRDT-style conflict-free replication data types.

  Implements version vectors for distributed holon state synchronization.
  Enables conflict detection and resolution in federation mesh.

  ## STAMP Constraints

  - SC-SMRITI-110: Version vectors stored in SQLite
  - SC-SMRITI-111: Concurrent updates detected
  - SC-SMRITI-112: Last-writer-wins for conflicts
  - SC-SMRITI-113: Causality preserved
  - SC-OBS-031: All vector operations emit telemetry
  - SC-HOLON-010: Version vector in SQLite for conflict resolution

  ## Constitutional Alignment

  - Ψ₂ (History): Causality chain preserved
  - Ψ₃ (Verification): Conflict detection verifiable
  - Ω₀ (Founder's Directive): Data consistency serves survival

  ## Theory

  A version vector V is a map from node_id to logical clock value.
  For nodes A and B:
  - V_A < V_B iff ∀i: V_A[i] ≤ V_B[i] and ∃j: V_A[j] < V_B[j]
  - V_A || V_B (concurrent) iff ¬(V_A ≤ V_B) and ¬(V_B ≤ V_A)

  ## 5-Order Effects

  1st: Vector updated locally
  2nd: Causality relation established
  3rd: Conflicts detected on merge
  4th: Resolution applied
  5th: Consistency achieved across federation

  ## Usage

      # Increment local clock
      {:ok, vector} = VersionVectors.increment("node-1")

      # Compare vectors
      :before | :after | :concurrent = VersionVectors.compare(v1, v2)

      # Merge vectors
      {:ok, merged} = VersionVectors.merge(v1, v2)

      # Detect conflicts
      conflicts = VersionVectors.detect_conflicts(v1, v2)
  """

  require Logger

  alias Indrajaal.KMS.SQLite

  @smriti_db_path Application.compile_env(:indrajaal, :smriti_db_path, "data/kms/smriti.db")

  @type node_id :: String.t()
  @type clock :: non_neg_integer()
  @type vector :: %{node_id() => clock()}
  @type comparison :: :before | :after | :concurrent | :equal
  @type conflict :: %{
          entry_id: String.t(),
          local_vector: vector(),
          remote_vector: vector(),
          local_value: term(),
          remote_value: term()
        }

  # ============================================================================
  # Public API - Vector Operations
  # ============================================================================

  @doc """
  Creates a new empty version vector.
  """
  @spec new() :: vector()
  def new, do: %{}

  @doc """
  Creates a version vector with initial value for a node.
  """
  @spec new(node_id()) :: vector()
  def new(node_id), do: %{node_id => 1}

  @doc """
  Increments the clock for a specific node.
  """
  @spec increment(vector(), node_id()) :: vector()
  def increment(vector, node_id) do
    emit_telemetry(:increment, %{node_id: node_id})

    current = Map.get(vector, node_id, 0)
    Map.put(vector, node_id, current + 1)
  end

  @doc """
  Gets the clock value for a specific node.
  """
  @spec get_clock(vector(), node_id()) :: clock()
  def get_clock(vector, node_id) do
    Map.get(vector, node_id, 0)
  end

  @doc """
  Compares two version vectors.

  Returns:
  - `:before` if v1 happened before v2
  - `:after` if v1 happened after v2
  - `:concurrent` if v1 and v2 are concurrent (conflict)
  - `:equal` if v1 equals v2
  """
  @spec compare(vector(), vector()) :: comparison()
  def compare(v1, v2) do
    emit_telemetry(:compare, %{})

    all_keys = MapSet.union(MapSet.new(Map.keys(v1)), MapSet.new(Map.keys(v2)))

    {less, greater} =
      Enum.reduce(all_keys, {false, false}, fn key, {less_acc, greater_acc} ->
        c1 = Map.get(v1, key, 0)
        c2 = Map.get(v2, key, 0)

        cond do
          c1 < c2 -> {true, greater_acc}
          c1 > c2 -> {less_acc, true}
          true -> {less_acc, greater_acc}
        end
      end)

    cond do
      less and greater -> :concurrent
      less -> :before
      greater -> :after
      true -> :equal
    end
  end

  @doc """
  Checks if v1 happened before or is equal to v2.
  """
  @spec happens_before?(vector(), vector()) :: boolean()
  def happens_before?(v1, v2) do
    compare(v1, v2) in [:before, :equal]
  end

  @doc """
  Checks if two vectors are concurrent (conflicting).
  """
  @spec concurrent?(vector(), vector()) :: boolean()
  def concurrent?(v1, v2) do
    compare(v1, v2) == :concurrent
  end

  @doc """
  Merges two version vectors, taking the maximum of each component.
  """
  @spec merge(vector(), vector()) :: vector()
  def merge(v1, v2) do
    emit_telemetry(:merge, %{v1_size: map_size(v1), v2_size: map_size(v2)})

    all_keys = MapSet.union(MapSet.new(Map.keys(v1)), MapSet.new(Map.keys(v2)))

    Enum.reduce(all_keys, %{}, fn key, acc ->
      c1 = Map.get(v1, key, 0)
      c2 = Map.get(v2, key, 0)
      Map.put(acc, key, max(c1, c2))
    end)
  end

  @doc """
  Merges multiple vectors.
  """
  @spec merge_all(list(vector())) :: vector()
  def merge_all([]), do: new()
  def merge_all([v]), do: v
  def merge_all([v1, v2 | rest]), do: merge_all([merge(v1, v2) | rest])

  # ============================================================================
  # Public API - Conflict Detection & Resolution
  # ============================================================================

  @doc """
  Detects conflicts between local and remote state.
  Returns a list of entries with concurrent modifications.
  """
  @spec detect_conflicts(vector(), vector()) :: list(conflict())
  def detect_conflicts(local_vector, remote_vector) do
    emit_telemetry(:detect_conflicts, %{})

    if concurrent?(local_vector, remote_vector) do
      # Identify which nodes have divergent clocks (the actual conflicting entries)
      all_keys =
        MapSet.union(MapSet.new(Map.keys(local_vector)), MapSet.new(Map.keys(remote_vector)))

      divergent_nodes =
        Enum.filter(all_keys, fn key ->
          local_clock = Map.get(local_vector, key, 0)
          remote_clock = Map.get(remote_vector, key, 0)
          local_clock != remote_clock
        end)

      Enum.map(divergent_nodes, fn node_id ->
        %{
          entry_id: node_id,
          local_vector: local_vector,
          remote_vector: remote_vector,
          local_value: Map.get(local_vector, node_id, 0),
          remote_value: Map.get(remote_vector, node_id, 0)
        }
      end)
    else
      []
    end
  end

  @doc """
  Resolves a conflict using last-writer-wins strategy.
  The entry with the higher total clock sum wins.
  """
  @spec resolve_conflict(conflict()) :: {:local | :remote, term()}
  def resolve_conflict(conflict) do
    emit_telemetry(:resolve_conflict, %{entry_id: conflict.entry_id})

    local_sum = conflict.local_vector |> Map.values() |> Enum.sum()
    remote_sum = conflict.remote_vector |> Map.values() |> Enum.sum()

    if local_sum >= remote_sum do
      {:local, conflict.local_value}
    else
      {:remote, conflict.remote_value}
    end
  end

  @doc """
  Computes the delta (difference) between two vectors.
  Returns {entries_to_send, entries_to_receive}.
  """
  @spec compute_delta(vector(), vector()) :: {list(String.t()), list(String.t())}
  def compute_delta(local_vector, remote_vector) do
    emit_telemetry(:compute_delta, %{})

    # Entries we have that remote doesn't (or has older version)
    to_send =
      local_vector
      |> Enum.filter(fn {node_id, local_clock} ->
        remote_clock = Map.get(remote_vector, node_id, 0)
        local_clock > remote_clock
      end)
      |> Enum.map(fn {node_id, _} -> node_id end)

    # Entries remote has that we don't (or has newer version)
    to_receive =
      remote_vector
      |> Enum.filter(fn {node_id, remote_clock} ->
        local_clock = Map.get(local_vector, node_id, 0)
        remote_clock > local_clock
      end)
      |> Enum.map(fn {node_id, _} -> node_id end)

    {to_send, to_receive}
  end

  # ============================================================================
  # Public API - Persistence
  # ============================================================================

  @doc """
  Gets the local version vector from SQLite storage.
  """
  @spec get_local_vector() :: vector()
  def get_local_vector do
    emit_telemetry(:get_local_vector, %{})

    case SQLite.query(@smriti_db_path, """
         SELECT vector FROM version_vectors WHERE holon_id = 'local'
         """) do
      {:ok, [%{vector: json}]} when is_binary(json) ->
        case Jason.decode(json) do
          {:ok, vector} -> vector
          _ -> new()
        end

      {:ok, [[json]]} when is_binary(json) ->
        case Jason.decode(json) do
          {:ok, vector} -> vector
          _ -> new()
        end

      _ ->
        new()
    end
  rescue
    _ -> new()
  end

  @doc """
  Persists the local version vector to SQLite.
  """
  @spec save_local_vector(vector()) :: :ok | {:error, term()}
  def save_local_vector(vector) do
    emit_telemetry(:save_local_vector, %{size: map_size(vector)})

    json = Jason.encode!(vector)
    checksum = compute_checksum(json)
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    case SQLite.execute(
           @smriti_db_path,
           """
           INSERT OR REPLACE INTO version_vectors (holon_id, vector, last_sync, checksum)
           VALUES ('local', ?, ?, ?)
           """,
           [json, now, checksum]
         ) do
      {:ok, _} -> :ok
      error -> error
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Gets the version vector for a specific holon.
  """
  @spec get_holon_vector(String.t()) :: vector()
  def get_holon_vector(holon_id) do
    emit_telemetry(:get_holon_vector, %{holon_id: holon_id})

    case SQLite.query(
           @smriti_db_path,
           """
           SELECT vector FROM version_vectors WHERE holon_id = ?
           """,
           [holon_id]
         ) do
      {:ok, [%{vector: json}]} when is_binary(json) ->
        case Jason.decode(json) do
          {:ok, vector} -> vector
          _ -> new()
        end

      {:ok, [[json]]} when is_binary(json) ->
        case Jason.decode(json) do
          {:ok, vector} -> vector
          _ -> new()
        end

      _ ->
        new()
    end
  rescue
    _ -> new()
  end

  @doc """
  Saves a holon's version vector.
  """
  @spec save_holon_vector(String.t(), vector()) :: :ok | {:error, term()}
  def save_holon_vector(holon_id, vector) do
    emit_telemetry(:save_holon_vector, %{holon_id: holon_id, size: map_size(vector)})

    json = Jason.encode!(vector)
    checksum = compute_checksum(json)
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    case SQLite.execute(
           @smriti_db_path,
           """
           INSERT OR REPLACE INTO version_vectors (holon_id, vector, last_sync, checksum)
           VALUES (?, ?, ?, ?)
           """,
           [holon_id, json, now, checksum]
         ) do
      {:ok, _} -> :ok
      error -> error
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Merges vectors and persists the result.
  """
  @spec merge_vectors(vector(), vector()) :: {:ok, vector()} | {:error, term()}
  def merge_vectors(local_vector, remote_vector) do
    merged = merge(local_vector, remote_vector)

    case save_local_vector(merged) do
      :ok -> {:ok, merged}
      error -> error
    end
  end

  # ============================================================================
  # Public API - Serialization
  # ============================================================================

  @doc """
  Serializes a version vector to JSON.
  """
  @spec to_json(vector()) :: String.t()
  def to_json(vector) do
    Jason.encode!(vector)
  end

  @doc """
  Deserializes a version vector from JSON.
  """
  @spec from_json(String.t()) :: {:ok, vector()} | {:error, term()}
  def from_json(json) do
    case Jason.decode(json) do
      {:ok, map} when is_map(map) ->
        # Ensure all values are integers
        vector =
          map
          |> Enum.map(fn {k, v} -> {to_string(k), parse_clock(v)} end)
          |> Map.new()

        {:ok, vector}

      error ->
        error
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp parse_clock(v) when is_integer(v), do: v
  defp parse_clock(v) when is_binary(v), do: String.to_integer(v)
  defp parse_clock(_), do: 0

  defp compute_checksum(data) do
    :crypto.hash(:sha256, data)
    |> Base.encode16(case: :lower)
  end

  # ============================================================================
  # Telemetry
  # ============================================================================

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:smriti, :version_vectors, event],
      %{timestamp: System.system_time(:nanosecond)},
      metadata
    )
  end
end
