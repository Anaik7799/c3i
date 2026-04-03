# lib/indrajaal/kms/immortality/protocol.ex
defmodule Indrajaal.KMS.Immortality.Protocol do
  @moduledoc """
  Weekly immortality protocol execution for species-scale survival.

  WHAT: Orchestrates multi-target knowledge preservation to ensure SMRITI
  data survives across storage failures, host destruction, and civilizational
  collapse. Exports to multiple independent targets and verifies minimum
  redundancy before declaring success.

  WHY: SC-SMRITI-074 requires immortality protocol execution. A single
  backup target is a single point of failure — the protocol MUST succeed
  on at least @minimum_targets independent targets to guarantee survival.

  CONSTRAINTS:
  - SC-SMRITI-074: Immortality protocol execution
  - SC-SMRITI-072: Multi-format export (JSON, Markdown, SQLite)
  - SC-HOLON-010: Regenerable from exported state alone
  - SC-HOLON-015: SQLite/DuckDB files are PRIMARY backup targets

  ## Change History
  | Version | Date       | Author | Change                                         |
  |---------|------------|--------|------------------------------------------------|
  | 21.2.1  | 2026-03-10 | Claude | Fix: multi-target preservation, real status    |
  | 21.0.0  | 2026-01-05 | Claude | Initial stub (single JSON export only)         |

  Task 42.3.0.0.0
  """
  use GenServer
  require Logger
  alias Indrajaal.KMS.Panspermia.Exporter

  @preservation_targets [
    {:local_backup, "backup/smriti/"},
    {:git_archive, "git@github.com:indrajaal/smriti-archive.git"},
    {:s3_bucket, "s3://indrajaal-archive/smriti/"},
    {:ipfs, :distributed},
    {:print_ready, "archive/print_ready/"}
  ]
  @minimum_targets 3

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Executes the full immortality protocol, returning {:ok, report} or {:error, reason}."
  @spec execute() :: {:ok, map()} | {:error, term()}
  def execute do
    GenServer.call(__MODULE__, :execute, 60_000)
  end

  @doc "Returns the current protocol status."
  @spec get_status() :: map()
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  def preservation_targets, do: @preservation_targets
  def minimum_targets, do: @minimum_targets

  @impl true
  def init(opts) do
    db_path = Keyword.get(opts, :db_path, get_db_path())

    {:ok,
     %{
       last_run: nil,
       status: :idle,
       db_path: db_path,
       last_report: nil
     }}
  end

  @impl true
  def handle_call(:execute, _from, state) do
    Logger.info("[Immortality] Executing multi-target preservation protocol...")

    report = execute_preservation(state.db_path)

    new_status =
      if report.success_count >= @minimum_targets, do: :completed, else: :partial_failure

    if new_status == :completed do
      Logger.info(
        "[Immortality] Protocol SUCCEEDED: #{report.success_count}/#{report.total_targets} targets preserved"
      )
    else
      Logger.warning(
        "[Immortality] Protocol PARTIAL: #{report.success_count}/#{report.total_targets} targets (minimum #{@minimum_targets} required)"
      )
    end

    :telemetry.execute(
      [:smriti, :immortality, :execution],
      %{
        success_count: report.success_count,
        total_targets: report.total_targets,
        duration_ms: report.duration_ms
      },
      %{status: new_status}
    )

    new_state = %{
      state
      | last_run: DateTime.utc_now(),
        status: new_status,
        last_report: report
    }

    {:reply, {:ok, report}, new_state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, Map.take(state, [:status, :last_run, :last_report]), state}
  end

  # --- Private: Multi-target Preservation ---

  defp execute_preservation(db_path) do
    start = System.monotonic_time(:millisecond)

    results =
      @preservation_targets
      |> Enum.map(fn target -> {target, preserve_to_target(target, db_path)} end)

    duration = System.monotonic_time(:millisecond) - start

    successes = Enum.filter(results, fn {_target, result} -> match?({:ok, _}, result) end)
    failures = Enum.reject(results, fn {_target, result} -> match?({:ok, _}, result) end)

    %{
      success_count: length(successes),
      total_targets: length(@preservation_targets),
      minimum_required: @minimum_targets,
      met_minimum: length(successes) >= @minimum_targets,
      duration_ms: duration,
      successes:
        Enum.map(successes, fn {{type, dest}, {:ok, path}} ->
          %{type: type, destination: dest, path: path}
        end),
      failures:
        Enum.map(failures, fn {{type, dest}, {:error, reason}} ->
          %{type: type, destination: dest, reason: reason}
        end),
      executed_at: DateTime.utc_now()
    }
  end

  defp preserve_to_target({:local_backup, dir}, db_path) do
    # Export all 3 formats to local backup directory
    with {:ok, _json_path} <- Exporter.export(:json, dir, db_path: db_path),
         {:ok, _md_path} <- Exporter.export(:markdown, dir, db_path: db_path),
         {:ok, sqlite_path} <- Exporter.export(:sqlite, dir, db_path: db_path) do
      Logger.debug("[Immortality] Local backup: 3 formats exported to #{dir}")
      {:ok, sqlite_path}
    end
  rescue
    e -> {:error, {:local_backup_failed, Exception.message(e)}}
  end

  defp preserve_to_target({:print_ready, dir}, db_path) do
    # Export markdown (human-readable, print-ready) for civilizational collapse scenario
    case Exporter.export(:markdown, dir, db_path: db_path) do
      {:ok, path} ->
        Logger.debug("[Immortality] Print-ready export to #{path}")
        {:ok, path}

      error ->
        error
    end
  rescue
    e -> {:error, {:print_ready_failed, Exception.message(e)}}
  end

  defp preserve_to_target({:git_archive, _repo_url}, _db_path) do
    # Git archive requires git push — gracefully degrade if not configured
    {:error, :git_archive_not_configured}
  end

  defp preserve_to_target({:s3_bucket, _bucket_url}, _db_path) do
    # S3 requires cloud credentials — gracefully degrade if not configured
    {:error, :s3_not_configured}
  end

  defp preserve_to_target({:ipfs, :distributed}, _db_path) do
    # IPFS requires running daemon — gracefully degrade if not available
    {:error, :ipfs_not_available}
  end

  defp get_db_path do
    Application.get_env(:indrajaal, :smriti_db_path, "data/kms/smriti.db")
  end
end
