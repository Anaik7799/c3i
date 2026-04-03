defmodule Indrajaal.OperationalExcellence.BackupSystem do
  @moduledoc """
  Incremental backup system with git integration and integrity preservation.
  Implements TDG _requirements with STAMP safety constraints.

  Framework: AEE+SOPv5.1+GDE+PHICS+TPS+STAMP+Container-Only

  Safety Constraints:
  - SC-003: Backup operations must not corrupt existing backups
  - UCA-003: Pr_event backup retention policy from deleting active backups
  """

  use GenServer
  require Logger

  @backup_dir "__data/backups"
  @meta_data_file "backupmetadata.json"
  # @max_backup_size_mb 1000  # Reserved for future use
  # @incremental_threshold 0.1  # 10% of full backup size - Reserved for future use

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the last successful backup.
  """
  def get_last_backup do
    GenServer.call(__MODULE__, :get_last_backup)
  end

  @doc """
  Perform an incremental backup of changed files.
  Satisfies SC-003: Backup operations must not corrupt existing backups.
  """
  def perform_incremental_backup do
    # 5 min timeout
    GenServer.call(__MODULE__, :perform_incremental_backup, 300_000)
  end

  @doc """
  List all backups in the system.
  """
  def list_all_backups do
    GenServer.call(__MODULE__, :list_all_backups)
  end

  @doc """
  List backups older than specified days.
  Used for retention policy management.
  """
  def list_backups_older_than(days) do
    GenServer.call(__MODULE__, {:list_old_backups, days})
  end

  @doc """
  Verify integrity of a specific backup.
  """
  def verify_backup_integrity(backup_id) do
    GenServer.call(__MODULE__, {:verify_integrity, backup_id})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Ensure backup directory exists
    File.mkdir_p!(@backup_dir)

    state = %{
      backups: load_backup_meta_data(),
      last_backup: nil,
      backup_chain: [],
      active_backup: nil
    }

    # Load last backup info
    state = %{state | last_backup: find_last_backup(state.backups)}

    {:ok, state}
  end

  @impl true
  def handle_call(:getlastbackup, _from, state) do
    {:reply, {:ok, state.last_backup}, state}
  end

  @impl true
  def handle_call(:perform_incremental_backup, _from, state) do
    Logger.info("[BackupSystem] Starting incremental backup")

    # SC-003: Create backup with integrity preservation
    backup_id = generate_backup_id()

    try do
      # Detect changes since last backup
      changes = detect_changes_since(state.last_backup)

      if changes_warrant_backup?(changes) do
        # Create incremental backup
        backup = create_incremental_backup(backup_id, changes, state.last_backup)

        # Verify backup integrity before committing
        if verify_new_backup_integrity(backup) do
          # Update git repository
          :ok = update_git_repository(backup)

          # Update meta_data
          new_state = update_backup_meta_data(state, backup)

          # Cleanup old backups (with safety checks)
          new_state = safe_cleanup_old_backups(new_state)

          Logger.info("[BackupSystem] Incremental backup completed: #{backup_id}")
          {:reply, {:ok, backup}, new_state}
        else
          Logger.error("[BackupSystem] Backup integrity check failed")
          {:reply, {:error, :integrity_check_failed}, state}
        end
      else
        Logger.info("[BackupSystem] No significant changes detected, skipping backup")
        {:reply, {:ok, :no_changes}, state}
      end
    rescue
      error ->
        Logger.error("[BackupSystem] Backup failed: #{inspect(error)}")
        # SC-003: Ensure no corruption on failure
        cleanup_failed_backup(backup_id)
        {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_call(:list_all_backups, _from, state) do
    backup_list = Map.values(state.backups)
    backups = Enum.sort_by(backup_list, & &1.timestamp, {:desc, DateTime})

    {:reply, {:ok, backups}, state}
  end

  @impl true
  def handle_call({:list_old_backups, days}, _from, state) do
    cutoff = DateTime.add(DateTime.utc_now(), -days * 86_400, :second)

    backup_list = Map.values(state.backups)

    old_backups =
      Enum.filter(backup_list, fn backup ->
        DateTime.compare(backup.timestamp, cutoff) == :lt
      end)

    {:reply, old_backups, state}
  end

  @impl true
  def handle_call({:verifyintegrity, backup_id}, _from, state) do
    case Map.get(state.backups, backup_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      backup ->
        result = perform_integrity_check(backup)
        {:reply, result, state}
    end
  end

  # Private functions

  defp load_backup_meta_data do
    meta_data_path = Path.join(@backup_dir, @meta_data_file)

    if File.exists?(meta_data_path) do
      file_content = File.read!(meta_data_path)

      file_content
      |> Jason.decode!()
      |> Enum.map(fn {id, data} ->
        backup = atomize_backup(data)
        {id, backup}
      end)
      |> Map.new()
    else
      %{}
    end
  end

  defp find_last_backup(backups) when map_size(backups) == 0, do: nil

  defp find_last_backup(backups) do
    backups
    |> Map.values()
    |> Enum.max_by(& &1.timestamp, DateTime, fn -> nil end)
  end

  defp generate_backup_id do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    rand_bytes = :crypto.strong_rand_bytes(4)
    random = rand_bytes |> Base.encode16()
    "backup_#{timestamp}_#{random}"
  end

  defp detect_changes_since(nil) do
    # First backup - include everything
    %{
      files: list_all_project_files(),
      containers: list_all_containers(),
      volumes: list_all_volumes()
    }
  end

  defp detect_changes_since(last_backup) do
    # Use git to detect file changes
    changed_files =
      case System.cmd("git", ["diff", "--name-only", last_backup.commit_sha || "HEAD"]) do
        {output, 0} ->
          output
          |> String.split("\n", trim: true)
          |> Enum.filter(&valid_file?/1)

        _ ->
          # Fallback to all files
          list_all_project_files()
      end

    # Check container changes
    changed_containers = detect_container_changes(last_backup.timestamp)

    # Check volume changes
    changed_volumes = detect_volume_changes(last_backup.timestamp)

    %{
      files: changed_files,
      containers: changed_containers,
      volumes: changed_volumes
    }
  end

  defp changes_warrant_backup?(changes) do
    # Backup if there are any changes
    length(changes.files) > 0 or
      length(changes.containers) > 0 or
      length(changes.volumes) > 0
  end

  defp create_incremental_backup(backup_id, changes, parent_backup) do
    backup_path = Path.join(@backup_dir, backup_id)
    File.mkdir_p!(backup_path)

    # Create backup manifest
    manifest = %{
      id: backup_id,
      type: :incremental,
      timestamp: DateTime.utc_now(),
      parent_backup_id: parent_backup && parent_backup.id,
      changes: %{
        files_count: length(changes.files),
        containers_count: length(changes.containers),
        volumes_count: length(changes.volumes)
      },
      checksums: %{},
      size_mb: 0.0,
      # Will be populated after git commit retrieval
      commit_sha: nil
    }

    # Backup changed files
    file_checksums = backup_files(changes.files, backup_path)

    # Backup container configs
    container_checksums = backup_container_configs(changes.containers, backup_path)

    # Backup volume meta_data
    volume_checksums = backup_volume_meta_data(changes.volumes, backup_path)

    # Calculate total size
    size_mb = calculate_backup_size(backup_path)

    # Get current git commit
    {commit_sha, 0} = System.cmd("git", ["rev-parse", "HEAD"])
    commit_sha = String.trim(commit_sha)

    %{
      manifest
      | checksums: Map.merge(file_checksums, Map.merge(container_checksums, volume_checksums)),
        size_mb: size_mb,
        commit_sha: commit_sha
    }
  end

  defp verify_new_backup_integrity(backup) do
    # SC-003: Verify backup integrity before committing
    backup_path = Path.join(@backup_dir, backup.id)

    # Verify all files exist
    files_exist =
      Enum.all?(backup.checksums, fn {file, _checksum} ->
        File.exists?(Path.join(backup_path, file))
      end)

    # Verify checksums
    checksums_valid =
      Enum.all?(backup.checksums, fn {file, expected_checksum} ->
        actual_checksum = calculate_file_checksum(Path.join(backup_path, file))
        actual_checksum == expected_checksum
      end)

    # Verify manifest is complete
    manifest_valid = backup.id != nil and backup.timestamp != nil

    files_exist and checksums_valid and manifest_valid
  end

  defp update_git_repository(backup) do
    # Add backup to git repository
    backup_path = Path.join(@backup_dir, backup.id)

    System.cmd("git", ["add", backup_path])
    System.cmd("git", ["commit", "-m", "Backup: #{backup.id}"])

    :ok
  end

  defp update_backup_meta_data(state, backup) do
    new_backups = Map.put(state.backups, backup.id, backup)

    # Save meta_data
    save_backup_meta_data(new_backups)

    %{
      state
      | backups: new_backups,
        last_backup: backup,
        backup_chain: [backup.id | state.backup_chain] |> Enum.take(100)
    }
  end

  defp safe_cleanup_old_backups(state) do
    # UCA-003: Pr_event deletion of active backups
    retention_days = 30
    cutoff = DateTime.add(DateTime.utc_now(), -retention_days * 86_400, :second)

    # Find candidates for deletion
    deletion_candidates =
      state.backups
      |> Map.values()
      |> Enum.filter(fn backup ->
        DateTime.compare(backup.timestamp, cutoff) == :lt
      end)
      |> Enum.reject(fn backup ->
        # Don't delete if it's a parent of active backups
        # Don't delete if it's the only full backup
        active_parent?(backup, state.backups) or
          only_full_backup?(backup, state.backups)
      end)

    # Delete safe candidates
    Enum.each(deletion_candidates, fn backup ->
      delete_backup(backup)
    end)

    # Update state
    remaining_backups =
      Enum.reduce(deletion_candidates, state.backups, fn backup, acc ->
        Map.delete(acc, backup.id)
      end)

    %{state | backups: remaining_backups}
  end

  defp active_parent?(backup, all_backups) do
    # Check if any backup depends on this one
    Enum.any?(all_backups, fn {_id, b} ->
      b.parent_backup_id == backup.id
    end)
  end

  defp only_full_backup?(backup, all_backups) do
    backup.type == :full and
      Enum.count(all_backups, fn {_id, b} -> b.type == :full end) == 1
  end

  defp cleanup_failed_backup(backup_id) do
    backup_path = Path.join(@backup_dir, backup_id)
    File.rm_rf(backup_path)
  end

  defp perform_integrity_check(backup) do
    backup_path = Path.join(@backup_dir, backup.id)

    if File.exists?(backup_path) do
      # Verify checksums
      all_valid =
        Enum.all?(backup.checksums, fn {file, expected} ->
          file_path = Path.join(backup_path, file)

          if File.exists?(file_path) do
            actual = calculate_file_checksum(file_path)
            actual == expected
          else
            false
          end
        end)

      if all_valid, do: {:ok, :valid}, else: {:error, :checksum_mismatch}
    else
      {:error, :backup_not_found}
    end
  end

  defp save_backup_meta_data(backups) do
    meta_data_path = Path.join(@backup_dir, @meta_data_file)

    backup_data =
      Enum.map(backups, fn {id, backup} ->
        {id, Map.from_struct(backup)}
      end)

    data = backup_data |> Map.new()

    File.write!(meta_data_path, Jason.encode!(data, pretty: true))
  end

  # Helper functions

  defp list_all_project_files do
    files = Path.wildcard("**/*.{ex,exs,md,json,yaml,yml}", match_dot: true)
    files |> Enum.filter(&valid_file?/1)
  end

  defp valid_file?(path) do
    not String.starts_with?(path, "_build/") and
      not String.starts_with?(path, "deps/") and
      not String.starts_with?(path, ".git/") and
      not String.starts_with?(path, "__data/backups/")
  end

  defp list_all_containers do
    # Placeholder - would query Podman
    []
  end

  defp list_all_volumes do
    # Placeholder - would query Podman volumes
    []
  end

  defp detect_container_changes(_since) do
    # Placeholder - would check container modification times
    []
  end

  defp detect_volume_changes(_since) do
    # Placeholder - would check volume modification times
    []
  end

  defp backup_files(files, backup_path) do
    files_dir = Path.join(backup_path, "files")
    File.mkdir_p!(files_dir)

    file_checksums =
      Enum.map(files, fn file ->
        dest = Path.join(files_dir, file)
        File.mkdir_p!(Path.dirname(dest))
        File.copy!(file, dest)

        checksum = calculate_file_checksum(dest)
        {file, checksum}
      end)

    file_checksums |> Map.new()
  end

  defp backup_container_configs(_containers, _backup_path) do
    # Placeholder - would backup container configurations
    %{}
  end

  defp backup_volume_meta_data(_volumes, _backup_path) do
    # Placeholder - would backup volume meta_data
    %{}
  end

  defp calculate_backup_size(backup_path) do
    # Calculate directory size in MB
    {output, 0} = System.cmd("du", ["-sm", backup_path])

    output
    |> String.split("\t")
    |> hd()
    |> String.trim()
    |> String.to_float()
  end

  defp calculate_file_checksum(file_path) do
    file_stream = File.stream!(file_path, [], 65_536)

    file_stream
    |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16()
  end

  defp delete_backup(backup) do
    backup_path = Path.join(@backup_dir, backup.id)
    File.rm_rf(backup_path)
    Logger.info("[BackupSystem] Deleted old backup: #{backup.id}")
  end

  defp atomize_backup(data) do
    {:ok, timestamp, _offset} = DateTime.from_iso8601(data["timestamp"])

    %{
      id: data["id"],
      type: String.to_atom(data["type"]),
      timestamp: timestamp,
      parent_backup_id: data["parent_backup_id"],
      changes: data["changes"],
      checksums: data["checksums"],
      size_mb: data["size_mb"],
      commit_sha: data["commit_sha"]
    }
  end
end
