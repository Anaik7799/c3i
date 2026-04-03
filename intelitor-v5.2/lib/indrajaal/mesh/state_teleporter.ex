defmodule Indrajaal.Mesh.StateTeleporter do
  @moduledoc """
  State Teleportation - Holon State Transfer Between Distributed Instances.

  ## What
  Enables complete holon state transfer between distributed instances,
  supporting migration, failover, and replication scenarios.

  ## Why
  Holons must be portable and substrate-independent (SC-HOLON-020):
  - Live migration between hosts
  - Failover with state preservation
  - State forking for experimentation
  - Backup and restore across networks

  ## Teleportation Protocol
  ```
  Source Holon                    Target Holon
       │                               │
       ├──── 1. Initiate ─────────────►│
       │◄──── 2. Ready ────────────────┤
       │                               │
       ├──── 3. Checkpoint ────────────►│
       ├──── 4. State Chunks ──────────►│
       ├──── 5. Register Blocks ───────►│
       │                               │
       │◄──── 6. Verify ───────────────┤
       ├──── 7. Activate ─────────────►│
       │◄──── 8. Complete ─────────────┤
  ```

  ## Constraints
  - SC-HOLON-009: State must be fully portable
  - SC-REG-002: Chain verification on receive
  - SC-CONST-002: Constitutional check on restore
  - AOR-HOLON-010: Regenerative mandate preserved
  """

  use GenServer
  require Logger

  alias Indrajaal.Mesh.TailscaleMesh
  alias Indrajaal.Core.Holon.ImmutableRegister

  # 1 MB chunks
  @chunk_size 1_048_576
  @transfer_timeout_ms 60_000
  # @verify_timeout_ms used in production for verification handshake

  @type teleport_state ::
          :idle
          | :initiating
          | :sending
          | :receiving
          | :verifying
          | :activating
          | :complete
          | :failed

  @type transfer :: %{
          id: String.t(),
          source_id: String.t(),
          target_id: String.t(),
          state: teleport_state(),
          started_at: DateTime.t(),
          chunks_total: non_neg_integer(),
          chunks_sent: non_neg_integer(),
          checksum: String.t() | nil,
          error: term() | nil
        }

  defstruct [
    :name,
    :holon_id,
    active_transfers: %{},
    completed_transfers: [],
    stats: %{
      teleports_initiated: 0,
      teleports_completed: 0,
      teleports_failed: 0,
      bytes_sent: 0,
      bytes_received: 0
    }
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start the State Teleporter service.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Initiate state teleportation to a target holon.
  Returns transfer ID for tracking.
  """
  @spec teleport_to(String.t()) :: {:ok, String.t()} | {:error, term()}
  def teleport_to(target_peer_id) do
    GenServer.call(__MODULE__, {:teleport_to, target_peer_id}, @transfer_timeout_ms)
  end

  @doc """
  Accept incoming state teleportation from source.
  """
  @spec accept_teleport(String.t(), String.t()) :: :ok | {:error, term()}
  def accept_teleport(transfer_id, source_peer_id) do
    GenServer.call(__MODULE__, {:accept_teleport, transfer_id, source_peer_id})
  end

  @doc """
  Get status of a transfer.
  """
  @spec transfer_status(String.t()) :: {:ok, transfer()} | {:error, :not_found}
  def transfer_status(transfer_id) do
    GenServer.call(__MODULE__, {:transfer_status, transfer_id})
  end

  @doc """
  Get all active transfers.
  """
  @spec active_transfers() :: list(transfer())
  def active_transfers do
    GenServer.call(__MODULE__, :active_transfers)
  end

  @doc """
  Cancel an in-progress transfer.
  """
  @spec cancel_transfer(String.t()) :: :ok
  def cancel_transfer(transfer_id) do
    GenServer.cast(__MODULE__, {:cancel_transfer, transfer_id})
  end

  @doc """
  Get teleporter statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Create a checkpoint of current holon state.
  """
  @spec create_checkpoint() :: {:ok, map()} | {:error, term()}
  def create_checkpoint do
    GenServer.call(__MODULE__, :create_checkpoint)
  end

  @doc """
  Restore holon state from checkpoint.
  """
  @spec restore_checkpoint(map()) :: :ok | {:error, term()}
  def restore_checkpoint(checkpoint) do
    GenServer.call(__MODULE__, {:restore_checkpoint, checkpoint})
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    state = %__MODULE__{
      name: Keyword.get(opts, :name, __MODULE__),
      holon_id: Keyword.get(opts, :holon_id, get_local_holon_id())
    }

    Logger.info("[StateTeleporter] Initialized for holon: #{state.holon_id}")

    {:ok, state}
  end

  @impl true
  def handle_call({:teleport_to, target_peer_id}, _from, state) do
    Logger.info("[StateTeleporter] Initiating teleport to #{target_peer_id}")

    # Verify peer is reachable
    case verify_peer_ready(target_peer_id) do
      :ok ->
        # Create transfer record
        transfer_id = generate_transfer_id()

        transfer = %{
          id: transfer_id,
          source_id: state.holon_id,
          target_id: target_peer_id,
          state: :initiating,
          started_at: DateTime.utc_now(),
          chunks_total: 0,
          chunks_sent: 0,
          checksum: nil,
          error: nil
        }

        # Start transfer process
        spawn_link(fn -> execute_teleport(transfer_id, target_peer_id, state.holon_id) end)

        new_transfers = Map.put(state.active_transfers, transfer_id, transfer)
        new_stats = Map.update!(state.stats, :teleports_initiated, &(&1 + 1))

        {:reply, {:ok, transfer_id}, %{state | active_transfers: new_transfers, stats: new_stats}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:accept_teleport, transfer_id, source_peer_id}, _from, state) do
    Logger.info("[StateTeleporter] Accepting teleport #{transfer_id} from #{source_peer_id}")

    transfer = %{
      id: transfer_id,
      source_id: source_peer_id,
      target_id: state.holon_id,
      state: :receiving,
      started_at: DateTime.utc_now(),
      chunks_total: 0,
      chunks_sent: 0,
      checksum: nil,
      error: nil
    }

    new_transfers = Map.put(state.active_transfers, transfer_id, transfer)
    {:reply, :ok, %{state | active_transfers: new_transfers}}
  end

  @impl true
  def handle_call({:transfer_status, transfer_id}, _from, state) do
    case Map.get(state.active_transfers, transfer_id) do
      nil ->
        # Check completed transfers
        case Enum.find(state.completed_transfers, fn t -> t.id == transfer_id end) do
          nil -> {:reply, {:error, :not_found}, state}
          transfer -> {:reply, {:ok, transfer}, state}
        end

      transfer ->
        {:reply, {:ok, transfer}, state}
    end
  end

  @impl true
  def handle_call(:active_transfers, _from, state) do
    {:reply, Map.values(state.active_transfers), state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_call(:create_checkpoint, _from, state) do
    checkpoint = create_holon_checkpoint(state.holon_id)
    {:reply, checkpoint, state}
  end

  @impl true
  def handle_call({:restore_checkpoint, checkpoint}, _from, state) do
    result = restore_holon_checkpoint(checkpoint)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:serialize_to_file, holon_id, output_path}, _from, state) do
    result = do_serialize_to_file(holon_id, output_path)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:deserialize_from_file, input_path, target_holon_id}, _from, state) do
    result = do_deserialize_from_file(input_path, target_holon_id)
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:cancel_transfer, transfer_id}, state) do
    case Map.get(state.active_transfers, transfer_id) do
      nil ->
        {:noreply, state}

      transfer ->
        cancelled = %{transfer | state: :failed, error: :cancelled}
        new_transfers = Map.delete(state.active_transfers, transfer_id)

        {:noreply,
         %{
           state
           | active_transfers: new_transfers,
             completed_transfers: [cancelled | state.completed_transfers]
         }}
    end
  end

  @impl true
  def handle_info({:transfer_progress, transfer_id, progress}, state) do
    case Map.get(state.active_transfers, transfer_id) do
      nil ->
        {:noreply, state}

      transfer ->
        updated = Map.merge(transfer, progress)
        new_transfers = Map.put(state.active_transfers, transfer_id, updated)
        {:noreply, %{state | active_transfers: new_transfers}}
    end
  end

  @impl true
  def handle_info({:transfer_complete, transfer_id, result}, state) do
    case Map.get(state.active_transfers, transfer_id) do
      nil ->
        {:noreply, state}

      transfer ->
        completed =
          case result do
            :ok ->
              %{transfer | state: :complete}

            {:error, reason} ->
              %{transfer | state: :failed, error: reason}
          end

        new_transfers = Map.delete(state.active_transfers, transfer_id)

        new_stats =
          case result do
            :ok ->
              Map.update!(state.stats, :teleports_completed, &(&1 + 1))

            {:error, _} ->
              Map.update!(state.stats, :teleports_failed, &(&1 + 1))
          end

        {:noreply,
         %{
           state
           | active_transfers: new_transfers,
             completed_transfers: [completed | Enum.take(state.completed_transfers, 99)],
             stats: new_stats
         }}
    end
  end

  # ============================================================================
  # Teleport Execution
  # ============================================================================

  defp execute_teleport(transfer_id, target_peer_id, source_holon_id) do
    parent = self()

    try do
      # Step 1: Create checkpoint
      Logger.info("[StateTeleporter] Creating checkpoint for transfer #{transfer_id}")
      {:ok, checkpoint} = create_holon_checkpoint(source_holon_id)

      # Update progress
      send(parent, {:transfer_progress, transfer_id, %{state: :sending}})

      # Step 2: Chunk the state
      chunks = chunk_state(checkpoint)
      total_chunks = length(chunks)

      send(parent, {:transfer_progress, transfer_id, %{chunks_total: total_chunks}})

      # Step 3: Send chunks
      Enum.with_index(chunks)
      |> Enum.each(fn {chunk, idx} ->
        send_chunk(target_peer_id, transfer_id, chunk, idx)
        send(parent, {:transfer_progress, transfer_id, %{chunks_sent: idx + 1}})
      end)

      # Step 4: Send register blocks
      Logger.info("[StateTeleporter] Sending register blocks")
      send_register_blocks(target_peer_id, transfer_id)

      # Step 5: Request verification
      send(parent, {:transfer_progress, transfer_id, %{state: :verifying}})

      case request_verification(target_peer_id, transfer_id, checkpoint.checksum) do
        :ok ->
          # Step 6: Activate
          send(parent, {:transfer_progress, transfer_id, %{state: :activating}})
          send_activation(target_peer_id, transfer_id)

          send(parent, {:transfer_complete, transfer_id, :ok})

        {:error, reason} ->
          send(parent, {:transfer_complete, transfer_id, {:error, reason}})
      end
    rescue
      e ->
        Logger.error("[StateTeleporter] Transfer failed: #{inspect(e)}")
        send(parent, {:transfer_complete, transfer_id, {:error, e}})
    end
  end

  # ============================================================================
  # Checkpoint Management
  # ============================================================================

  defp create_holon_checkpoint(holon_id) do
    # Get state from SQLite
    sqlite_state = read_sqlite_state(holon_id)

    # Get history from DuckDB
    duckdb_state = read_duckdb_history(holon_id)

    # Get register chain
    register_state = ImmutableRegister.export()

    # Calculate checksum
    combined = :erlang.term_to_binary({sqlite_state, duckdb_state, register_state})
    checksum = :crypto.hash(:sha256, combined) |> Base.encode16(case: :lower)

    checkpoint = %{
      holon_id: holon_id,
      version: 1,
      created_at: DateTime.utc_now(),
      sqlite_state: sqlite_state,
      duckdb_state: duckdb_state,
      register_state: register_state,
      checksum: checksum,
      size_bytes: byte_size(combined)
    }

    Logger.info(
      "[StateTeleporter] Checkpoint created: #{checksum} (#{checkpoint.size_bytes} bytes)"
    )

    {:ok, checkpoint}
  end

  defp restore_holon_checkpoint(checkpoint) do
    Logger.info("[StateTeleporter] Restoring checkpoint #{checkpoint.checksum}")

    # Verify checksum first
    combined =
      :erlang.term_to_binary({
        checkpoint.sqlite_state,
        checkpoint.duckdb_state,
        checkpoint.register_state
      })

    computed_checksum = :crypto.hash(:sha256, combined) |> Base.encode16(case: :lower)

    if computed_checksum != checkpoint.checksum do
      Logger.error("[StateTeleporter] Checkpoint checksum mismatch!")
      {:error, :checksum_mismatch}
    else
      # Restore in order: register first, then state
      :ok = ImmutableRegister.import(checkpoint.register_state)
      :ok = write_sqlite_state(checkpoint.holon_id, checkpoint.sqlite_state)
      :ok = write_duckdb_history(checkpoint.holon_id, checkpoint.duckdb_state)

      Logger.info("[StateTeleporter] Checkpoint restored successfully")
      :ok
    end
  end

  # ============================================================================
  # State I/O - SC-HOLON-009: State must be fully portable
  # ============================================================================

  @holon_base_path "data/holons"

  @doc false
  defp holon_path(holon_id), do: Path.join([@holon_base_path, holon_id])
  defp sqlite_path(holon_id), do: Path.join([holon_path(holon_id), "state.sqlite"])
  defp duckdb_path(holon_id), do: Path.join([holon_path(holon_id), "history.duckdb"])
  defp checksum_path(holon_id), do: Path.join([holon_path(holon_id), "checksum.sha256"])

  defp read_sqlite_state(holon_id) do
    path = sqlite_path(holon_id)

    case File.read(path) do
      {:ok, binary} ->
        %{
          holon_id: holon_id,
          binary: binary,
          size_bytes: byte_size(binary),
          checksum: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
        }

      {:error, :enoent} ->
        Logger.warning("[StateTeleporter] No SQLite state found for #{holon_id}")
        %{holon_id: holon_id, binary: nil, size_bytes: 0}

      {:error, reason} ->
        Logger.error("[StateTeleporter] Failed to read SQLite state: #{inspect(reason)}")
        %{holon_id: holon_id, binary: nil, error: reason}
    end
  end

  defp read_duckdb_history(holon_id) do
    path = duckdb_path(holon_id)

    case File.read(path) do
      {:ok, binary} ->
        %{
          holon_id: holon_id,
          binary: binary,
          size_bytes: byte_size(binary),
          checksum: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
        }

      {:error, :enoent} ->
        Logger.warning("[StateTeleporter] No DuckDB history found for #{holon_id}")
        %{holon_id: holon_id, binary: nil, size_bytes: 0}

      {:error, reason} ->
        Logger.error("[StateTeleporter] Failed to read DuckDB history: #{inspect(reason)}")
        %{holon_id: holon_id, binary: nil, error: reason}
    end
  end

  defp write_sqlite_state(holon_id, state) do
    path = sqlite_path(holon_id)

    # Ensure directory exists
    path |> Path.dirname() |> File.mkdir_p!()

    case state do
      %{binary: nil} ->
        Logger.warning("[StateTeleporter] No SQLite binary to write for #{holon_id}")
        :ok

      %{binary: binary} when is_binary(binary) ->
        # Write atomically using temp file + rename
        temp_path = "#{path}.tmp"

        with :ok <- File.write(temp_path, binary),
             :ok <- File.rename(temp_path, path) do
          # Write checksum file
          checksum = :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
          File.write(checksum_path(holon_id), "#{checksum}  state.sqlite\n")

          Logger.info(
            "[StateTeleporter] Wrote SQLite state: #{path} (#{byte_size(binary)} bytes)"
          )

          :ok
        else
          {:error, reason} ->
            Logger.error("[StateTeleporter] Failed to write SQLite state: #{inspect(reason)}")
            {:error, reason}
        end

      _ ->
        :ok
    end
  end

  defp write_duckdb_history(holon_id, history) do
    path = duckdb_path(holon_id)

    # Ensure directory exists
    path |> Path.dirname() |> File.mkdir_p!()

    case history do
      %{binary: nil} ->
        Logger.warning("[StateTeleporter] No DuckDB binary to write for #{holon_id}")
        :ok

      %{binary: binary} when is_binary(binary) ->
        # Write atomically
        temp_path = "#{path}.tmp"

        with :ok <- File.write(temp_path, binary),
             :ok <- File.rename(temp_path, path) do
          Logger.info(
            "[StateTeleporter] Wrote DuckDB history: #{path} (#{byte_size(binary)} bytes)"
          )

          :ok
        else
          {:error, reason} ->
            Logger.error("[StateTeleporter] Failed to write DuckDB history: #{inspect(reason)}")
            {:error, reason}
        end

      _ ->
        :ok
    end
  end

  @doc """
  Serialize holon state to a portable file.
  SC-HOLON-009: State must be fully portable (single file copy)
  """
  @spec serialize_to_file(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def serialize_to_file(holon_id, output_path) do
    GenServer.call(__MODULE__, {:serialize_to_file, holon_id, output_path})
  end

  @doc """
  Deserialize holon state from a portable file.
  SC-HOLON-014: State verification on restore
  """
  @spec deserialize_from_file(String.t(), String.t()) :: :ok | {:error, term()}
  def deserialize_from_file(input_path, target_holon_id) do
    GenServer.call(__MODULE__, {:deserialize_from_file, input_path, target_holon_id})
  end

  defp do_serialize_to_file(holon_id, output_path) do
    Logger.info("[StateTeleporter] Serializing holon #{holon_id} to #{output_path}")

    # Gather all state components
    sqlite_state = read_sqlite_state(holon_id)
    duckdb_state = read_duckdb_history(holon_id)
    register_state = ImmutableRegister.export()

    # Create portable package
    package = %{
      format: "indrajaal_holon_state",
      version: 1,
      holon_id: holon_id,
      created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      sqlite_state: sqlite_state,
      duckdb_state: duckdb_state,
      register_state: register_state
    }

    # Serialize with compression
    binary = :erlang.term_to_binary(package, [:compressed])

    # Add checksum header
    checksum = :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
    header = "HOLON_STATE_V1|#{checksum}|#{byte_size(binary)}|"
    final_binary = header <> binary

    case File.write(output_path, final_binary) do
      :ok ->
        Logger.info(
          "[StateTeleporter] Serialized #{byte_size(final_binary)} bytes to #{output_path}"
        )

        {:ok, checksum}

      {:error, reason} ->
        Logger.error("[StateTeleporter] Serialization failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_deserialize_from_file(input_path, target_holon_id) do
    Logger.info("[StateTeleporter] Deserializing from #{input_path} to holon #{target_holon_id}")

    case File.read(input_path) do
      {:ok, file_binary} ->
        # Parse header
        case parse_state_file(file_binary) do
          {:ok, package, verified_checksum} ->
            Logger.info("[StateTeleporter] Verified checksum: #{verified_checksum}")

            # Restore components
            with :ok <- write_sqlite_state(target_holon_id, package.sqlite_state),
                 :ok <- write_duckdb_history(target_holon_id, package.duckdb_state),
                 :ok <- restore_register_state(package.register_state) do
              Logger.info(
                "[StateTeleporter] Deserialization complete for holon #{target_holon_id}"
              )

              :ok
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("[StateTeleporter] Failed to read file: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_state_file(file_binary) do
    # Parse header: HOLON_STATE_V1|checksum|size|
    case String.split(file_binary, "|", parts: 4) do
      ["HOLON_STATE_V1", expected_checksum, size_str, rest] ->
        expected_size = String.to_integer(size_str)

        if byte_size(rest) == expected_size do
          # Verify checksum
          computed_checksum = :crypto.hash(:sha256, rest) |> Base.encode16(case: :lower)

          if computed_checksum == expected_checksum do
            package = :erlang.binary_to_term(rest, [:safe])
            {:ok, package, computed_checksum}
          else
            Logger.error(
              "[StateTeleporter] Checksum mismatch: expected #{expected_checksum}, got #{computed_checksum}"
            )

            {:error, :checksum_mismatch}
          end
        else
          {:error, :size_mismatch}
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  defp restore_register_state({:ok, blocks}) when is_list(blocks) do
    ImmutableRegister.import(blocks)
  end

  defp restore_register_state(_), do: :ok

  # ============================================================================
  # Network Operations (Placeholders)
  # ============================================================================

  defp verify_peer_ready(peer_id) do
    case TailscaleMesh.status() do
      %{connected: true} ->
        peers = TailscaleMesh.peers()

        if Enum.any?(peers, fn p -> p.id == peer_id and p.status == :online end) do
          :ok
        else
          {:error, :peer_not_found}
        end

      _ ->
        {:error, :mesh_not_connected}
    end
  end

  defp chunk_state(checkpoint) do
    binary = :erlang.term_to_binary(checkpoint)
    chunk_binary(binary, @chunk_size)
  end

  defp chunk_binary(binary, size) when byte_size(binary) <= size do
    [binary]
  end

  defp chunk_binary(binary, size) do
    <<chunk::binary-size(size), rest::binary>> = binary
    [chunk | chunk_binary(rest, size)]
  end

  defp send_chunk(target_peer_id, transfer_id, chunk, index) do
    message = {:teleport_chunk, transfer_id, index, chunk}
    TailscaleMesh.send_to_peer(target_peer_id, message)
  end

  defp send_register_blocks(target_peer_id, transfer_id) do
    case ImmutableRegister.export() do
      {:ok, blocks} ->
        message = {:teleport_register, transfer_id, blocks}
        TailscaleMesh.send_to_peer(target_peer_id, message)

      _ ->
        :ok
    end
  end

  defp request_verification(target_peer_id, transfer_id, checksum) do
    message = {:teleport_verify, transfer_id, checksum}

    case TailscaleMesh.send_to_peer(target_peer_id, message) do
      :ok -> :ok
      error -> error
    end
  end

  defp send_activation(target_peer_id, transfer_id) do
    message = {:teleport_activate, transfer_id}
    TailscaleMesh.send_to_peer(target_peer_id, message)
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp generate_transfer_id do
    "xfer-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp get_local_holon_id do
    # Would get from application config
    Application.get_env(:indrajaal, :holon_id, "local-holon")
  end
end
