defmodule Indrajaal.Deployment.DyingGasp do
  @moduledoc """
  SIL-4 Compliant Dying Gasp Protocol

  WHAT: Captures and persists critical state before container shutdown.

  WHY: SIL-4 requires state preservation for crash recovery and forensics.
  The "dying gasp" pattern ensures that even during abrupt termination,
  critical state is checkpointed for later recovery.

  CONSTRAINTS:
  - SC-SIL4-007: Dying gasp mandatory before shutdown
  - SC-HOLON-017: SHA-256 checksum for integrity
  - SC-REG-001: All state changes via append-only register
  - SC-SIL4-027: State snapshot before upgrade

  TECHNIQUES:
  | Technique | Source | Purpose |
  |-----------|--------|---------|
  | State Serialization | Industry | Portable state capture |
  | SHA256 Hashing | NIST | Integrity verification |
  | Append-Only Log | Event Sourcing | Recovery timeline |
  | Compression | Industry | Storage efficiency |

  AOR:
  - AOR-SIL4-001: Always checkpoint before shutdown
  - AOR-HOLON-017: Verify SHA-256 on load
  """

  require Logger

  # =============================================================================
  # Constants
  # =============================================================================

  @checkpoint_dir "data/checkpoints"
  @max_checkpoints_per_container 10

  defstruct [
    :active_checkpoints,
    :total_captured,
    :last_checkpoint_at,
    :status
  ]

  @type container_id :: String.t()
  @type checkpoint_id :: String.t()

  @type checkpoint_metadata :: %{
          container_id: container_id(),
          checkpoint_id: checkpoint_id(),
          timestamp: DateTime.t(),
          sha256: String.t(),
          size_bytes: non_neg_integer(),
          compressed: boolean(),
          version: String.t()
        }

  @type checkpoint :: %{
          metadata: checkpoint_metadata(),
          state: map(),
          holon_state: map() | nil,
          process_state: map() | nil,
          ets_tables: map() | nil
        }

  @type gasp_result :: %{
          success: boolean(),
          checkpoint_id: checkpoint_id() | nil,
          path: String.t() | nil,
          duration_ms: non_neg_integer(),
          error: term() | nil
        }

  # =============================================================================
  # Public API
  # =============================================================================

  @doc """
  Captures a dying gasp checkpoint for a container.
  Should be called as early as possible during shutdown sequence.
  """
  @spec capture(container_id(), keyword()) :: {:ok, gasp_result()} | {:error, term()}
  def capture(container_id, opts \\ []) do
    start_time = System.monotonic_time(:millisecond)
    checkpoint_id = generate_checkpoint_id(container_id)

    emit_telemetry(:capture_start, %{container: container_id, checkpoint_id: checkpoint_id})

    try do
      # Ensure checkpoint directory exists
      ensure_checkpoint_dir()

      # Capture state from various sources
      state = capture_state(container_id, opts)

      # Build checkpoint with metadata
      checkpoint = build_checkpoint(container_id, checkpoint_id, state)

      # Serialize and compress
      serialized = serialize_checkpoint(checkpoint)

      # Calculate SHA256
      sha256 = :crypto.hash(:sha256, serialized) |> Base.encode16(case: :lower)

      # Update metadata with hash and size
      checkpoint = put_in(checkpoint.metadata.sha256, sha256)
      checkpoint = put_in(checkpoint.metadata.size_bytes, byte_size(serialized))

      # Write to file
      path = checkpoint_path(container_id, checkpoint_id)
      :ok = write_checkpoint(path, serialized, checkpoint.metadata)

      duration = System.monotonic_time(:millisecond) - start_time

      # Cleanup old checkpoints
      cleanup_old_checkpoints(container_id)

      result = %{
        success: true,
        checkpoint_id: checkpoint_id,
        path: path,
        duration_ms: duration,
        error: nil
      }

      emit_telemetry(:capture_complete, %{
        container: container_id,
        checkpoint_id: checkpoint_id,
        duration_ms: duration,
        size_bytes: checkpoint.metadata.size_bytes,
        sha256: sha256
      })

      Logger.info(
        "[DyingGasp] Checkpoint captured for #{container_id}: #{checkpoint_id} " <>
          "(#{checkpoint.metadata.size_bytes} bytes, #{duration}ms)"
      )

      # ZUIP D-05: Publish dying gasp to Zenoh (fire-and-forget)
      Indrajaal.Observability.ZenohSafetyPublisher.publish_dying_gasp(
        container_id,
        %{checkpoint_id: checkpoint_id, duration_ms: duration, sha256: sha256}
      )

      {:ok, result}
    rescue
      e ->
        duration = System.monotonic_time(:millisecond) - start_time

        result = %{
          success: false,
          checkpoint_id: checkpoint_id,
          path: nil,
          duration_ms: duration,
          error: e
        }

        emit_telemetry(:capture_failed, %{
          container: container_id,
          error: Exception.message(e),
          duration_ms: duration
        })

        Logger.error("[DyingGasp] Capture failed for #{container_id}: #{Exception.message(e)}")

        {:error, result}
    end
  end

  @doc """
  Recovers state from the latest checkpoint for a container.
  """
  @spec recover(container_id()) :: {:ok, checkpoint()} | {:error, term()}
  def recover(container_id) do
    emit_telemetry(:recover_start, %{container: container_id})

    case find_latest_checkpoint(container_id) do
      {:ok, path} ->
        recover_from_path(path)

      {:error, :no_checkpoints} ->
        Logger.info("[DyingGasp] No checkpoints found for #{container_id}")
        {:error, :no_checkpoints}
    end
  end

  @doc """
  Recovers state from a specific checkpoint file.
  """
  @spec recover_from_path(String.t()) :: {:ok, checkpoint()} | {:error, term()}
  def recover_from_path(path) do
    with {:ok, data} <- File.read(path),
         {:ok, metadata} <- read_metadata(path),
         :ok <- verify_integrity(data, metadata.sha256),
         {:ok, checkpoint} <- deserialize_checkpoint(data) do
      emit_telemetry(:recover_complete, %{
        container: checkpoint.metadata.container_id,
        checkpoint_id: checkpoint.metadata.checkpoint_id
      })

      Logger.info(
        "[DyingGasp] Recovered checkpoint #{checkpoint.metadata.checkpoint_id} " <>
          "from #{checkpoint.metadata.timestamp}"
      )

      {:ok, checkpoint}
    else
      {:error, reason} ->
        Logger.error("[DyingGasp] Recovery failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Lists all checkpoints for a container.
  """
  @spec list_checkpoints(container_id()) :: {:ok, [checkpoint_metadata()]} | {:error, term()}
  def list_checkpoints(container_id) do
    pattern = Path.join([@checkpoint_dir, container_id, "*.checkpoint"])

    files =
      pattern
      |> Path.wildcard()
      |> Enum.sort(:desc)

    metadata =
      files
      |> Enum.map(fn path ->
        case read_metadata(path) do
          {:ok, meta} -> meta
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, metadata}
  end

  @doc """
  Verifies the integrity of a checkpoint file.
  """
  @spec verify_checkpoint(String.t()) :: :ok | {:error, term()}
  def verify_checkpoint(path) do
    with {:ok, data} <- File.read(path),
         {:ok, metadata} <- read_metadata(path),
         :ok <- verify_integrity(data, metadata.sha256) do
      Logger.info("[DyingGasp] Checkpoint verified: #{path}")
      :ok
    end
  end

  @doc """
  Deletes a specific checkpoint.
  """
  @spec delete_checkpoint(String.t()) :: :ok | {:error, term()}
  def delete_checkpoint(path) do
    metadata_path = path <> ".meta"

    with :ok <- File.rm(path),
         _ <- File.rm(metadata_path) do
      Logger.info("[DyingGasp] Deleted checkpoint: #{path}")
      :ok
    end
  end

  # =============================================================================
  # Private: State Capture
  # =============================================================================

  defp capture_state(container_id, opts) do
    include_ets = Keyword.get(opts, :include_ets, true)
    include_processes = Keyword.get(opts, :include_processes, true)
    custom_state = Keyword.get(opts, :custom_state, %{})

    %{
      container_id: container_id,
      captured_at: DateTime.utc_now(),
      node: Node.self(),
      uptime_ms: :erlang.statistics(:wall_clock) |> elem(0),
      memory: Map.new(:erlang.memory()),
      process_count: :erlang.system_info(:process_count),
      ets_tables: if(include_ets, do: capture_ets_state(), else: nil),
      process_state: if(include_processes, do: capture_process_state(), else: nil),
      custom: custom_state
    }
  end

  defp capture_ets_state do
    :ets.all()
    |> Enum.map(fn table ->
      try do
        info = :ets.info(table)

        if info do
          %{
            name: Keyword.get(info, :name),
            size: Keyword.get(info, :size),
            memory: Keyword.get(info, :memory),
            type: Keyword.get(info, :type)
          }
        else
          nil
        end
      rescue
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp capture_process_state do
    # Capture state of key GenServers
    key_processes = [
      Indrajaal.Deployment.WaveExecutor,
      Indrajaal.Lifecycle.HealthCoordinator,
      Indrajaal.Safety.Sentinel,
      Indrajaal.Safety.PatternHunter
    ]

    key_processes
    |> Enum.map(fn module ->
      case GenServer.whereis(module) do
        nil ->
          nil

        pid ->
          try do
            # Get process info (not internal state for safety)
            info = Process.info(pid, [:memory, :message_queue_len, :reductions])

            if info do
              %{
                module: module,
                pid: inspect(pid),
                memory: Keyword.get(info, :memory),
                message_queue_len: Keyword.get(info, :message_queue_len),
                reductions: Keyword.get(info, :reductions)
              }
            else
              nil
            end
          rescue
            _ -> nil
          end
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # =============================================================================
  # Private: Checkpoint Building
  # =============================================================================

  defp build_checkpoint(container_id, checkpoint_id, state) do
    metadata = %{
      container_id: container_id,
      checkpoint_id: checkpoint_id,
      timestamp: DateTime.utc_now(),
      sha256: "",
      size_bytes: 0,
      compressed: true,
      version: "1.0.0"
    }

    %{
      metadata: metadata,
      state: state,
      holon_state: capture_holon_state(),
      process_state: state.process_state,
      ets_tables: state.ets_tables
    }
  end

  defp capture_holon_state do
    # Try to capture holon state from SQLite if available
    holon_dir = "data/holons"

    if File.dir?(holon_dir) do
      holon_dir
      |> File.ls!()
      |> Enum.take(5)
      |> Enum.map(fn holon_id ->
        %{
          holon_id: holon_id,
          exists: true,
          sqlite_path: Path.join([holon_dir, holon_id, "state.sqlite"])
        }
      end)
    else
      nil
    end
  end

  @doc """
  Serializes a checkpoint structure for storage.
  """
  @spec serialize_checkpoint(checkpoint()) :: binary()
  def serialize_checkpoint(checkpoint) do
    checkpoint
    |> Jason.encode!()
    |> :zlib.compress()
  end

  # =============================================================================
  # Private: Serialization
  # =============================================================================

  defp deserialize_checkpoint(data) do
    try do
      decompressed = :zlib.uncompress(data)
      checkpoint = Jason.decode!(decompressed, keys: :atoms)
      {:ok, checkpoint}
    rescue
      e -> {:error, {:deserialization_failed, e}}
    end
  end

  # =============================================================================
  # Private: File Operations
  # =============================================================================

  defp ensure_checkpoint_dir do
    File.mkdir_p!(@checkpoint_dir)
  end

  defp checkpoint_path(container_id, checkpoint_id) do
    container_dir = Path.join(@checkpoint_dir, container_id)
    File.mkdir_p!(container_dir)
    Path.join(container_dir, "#{checkpoint_id}.checkpoint")
  end

  defp write_checkpoint(path, data, metadata) do
    # Write checkpoint data
    :ok = File.write!(path, data)

    # Write metadata sidecar
    metadata_path = path <> ".meta"
    metadata_json = Jason.encode!(metadata, pretty: true)
    :ok = File.write!(metadata_path, metadata_json)

    :ok
  end

  defp read_metadata(checkpoint_path) do
    metadata_path = checkpoint_path <> ".meta"

    case File.read(metadata_path) do
      {:ok, json} ->
        metadata = Jason.decode!(json, keys: :atoms)
        {:ok, metadata}

      {:error, :enoent} ->
        {:error, :metadata_not_found}
    end
  end

  defp find_latest_checkpoint(container_id) do
    container_dir = Path.join(@checkpoint_dir, container_id)
    pattern = Path.join(container_dir, "*.checkpoint")

    case Path.wildcard(pattern) |> Enum.sort(:desc) |> List.first() do
      nil -> {:error, :no_checkpoints}
      path -> {:ok, path}
    end
  end

  defp cleanup_old_checkpoints(container_id) do
    container_dir = Path.join(@checkpoint_dir, container_id)
    pattern = Path.join(container_dir, "*.checkpoint")

    checkpoints =
      pattern
      |> Path.wildcard()
      |> Enum.sort(:desc)

    # Keep only the most recent checkpoints
    to_delete = Enum.drop(checkpoints, @max_checkpoints_per_container)

    Enum.each(to_delete, fn path ->
      delete_checkpoint(path)
    end)

    if length(to_delete) > 0 do
      Logger.debug("[DyingGasp] Cleaned up #{length(to_delete)} old checkpoints")
    end
  end

  # =============================================================================
  # Private: Integrity Verification
  # =============================================================================

  defp verify_integrity(data, expected_sha256) do
    actual_sha256 = :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)

    if actual_sha256 == expected_sha256 do
      :ok
    else
      {:error, {:integrity_mismatch, expected: expected_sha256, actual: actual_sha256}}
    end
  end

  # =============================================================================
  # Private: Helpers
  # =============================================================================

  defp generate_checkpoint_id(container_id) do
    timestamp =
      DateTime.utc_now()
      |> DateTime.to_unix(:millisecond)

    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "#{container_id}-#{timestamp}-#{random}"
  end

  # =============================================================================
  # Private: Telemetry
  # =============================================================================

  defp emit_telemetry(event, measurements) do
    :telemetry.execute(
      [:indrajaal, :deployment, :dying_gasp, event],
      measurements,
      %{timestamp: DateTime.utc_now()}
    )
  end
end
