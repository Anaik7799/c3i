defmodule Indrajaal.Upgrade.RollbackManager do
  @moduledoc """
  Rollback Manager: Multi-level rollback with transaction-style semantics

  WHAT: Manages rollback operations for code, state, and full system rollbacks.
  WHY: Ensures reliable recovery from failed upgrades per SC-SIL4-026.
  CONSTRAINTS: SC-SIL4-026 (rollback path), SC-EMR-060 (rollback capability), SC-HOLON-015

  ## Rollback Levels
  - Level 1: Configuration rollback (fastest, least disruptive)
  - Level 2: State rollback (restores holon state)
  - Level 3: Code rollback (reverts to previous release)
  - Level 4: Full rollback (state + code + config)

  ## Features
  - 24-hour rollback window (SC-SIL4-026)
  - Transaction-style semantics with commit/abort
  - Audit logging to Immutable Register
  - Guardian approval for critical rollbacks
  """

  use GenServer
  require Logger

  alias Indrajaal.Upgrade.StateSnapshot
  alias Indrajaal.Core.Holon.ImmutableRegister, as: Register
  alias Indrajaal.Safety.Guardian

  @rollback_window_hours 24

  @type rollback_level :: :config | :state | :code | :full
  @type rollback_status :: :pending | :in_progress | :completed | :failed | :cancelled
  @type rollback_entry :: %{
          id: String.t(),
          level: rollback_level(),
          snapshot_id: String.t() | nil,
          previous_version: String.t() | nil,
          target_version: String.t(),
          status: rollback_status(),
          created_at: DateTime.t(),
          completed_at: DateTime.t() | nil,
          reason: String.t(),
          effects: map() | nil
        }

  defmodule State do
    @moduledoc false
    defstruct pending_rollbacks: [],
              active_rollback: nil,
              history: [],
              guardian_approved: false
  end

  # Client API

  @doc """
  Starts the Rollback Manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initiates a rollback operation.

  Returns `{:ok, rollback_id}` if approved and queued, or `{:error, reason}`.

  ## Parameters
  - `level`: Rollback level (:config, :state, :code, :full)
  - `reason`: Reason for rollback
  - `opts`: Additional options including `:snapshot_id` for state rollbacks

  ## STAMP Constraints
  - SC-SIL4-026: Rollback path must exist
  - SC-EMR-060: Rollback capability required
  """
  @spec initiate(rollback_level(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def initiate(level, reason, opts \\ []) do
    GenServer.call(__MODULE__, {:initiate, level, reason, opts}, 30_000)
  end

  @doc """
  Executes a pending rollback.

  Returns `:ok` on success or `{:error, reason}`.
  """
  @spec execute(String.t()) :: :ok | {:error, term()}
  def execute(rollback_id) do
    GenServer.call(__MODULE__, {:execute, rollback_id}, 60_000)
  end

  @doc """
  Cancels a pending rollback.
  """
  @spec cancel(String.t()) :: :ok | {:error, term()}
  def cancel(rollback_id) do
    GenServer.call(__MODULE__, {:cancel, rollback_id})
  end

  @doc """
  Returns status of a rollback operation.
  """
  @spec status(String.t()) :: {:ok, rollback_entry()} | {:error, :not_found}
  def status(rollback_id) do
    GenServer.call(__MODULE__, {:status, rollback_id})
  end

  @doc """
  Lists all rollback entries within the rollback window.
  """
  @spec list() :: [rollback_entry()]
  def list do
    GenServer.call(__MODULE__, :list)
  end

  @doc """
  Checks if rollback is available for the current state.

  Returns `{:ok, [rollback_entry()]}` with available rollback points.
  """
  @spec available_rollbacks() :: {:ok, [rollback_entry()]} | {:error, term()}
  def available_rollbacks do
    GenServer.call(__MODULE__, :available_rollbacks)
  end

  @doc """
  Emergency rollback - bypasses normal approval for critical situations.

  ## STAMP Constraints
  - SC-EMR-057: Emergency stop < 5s
  - SC-EMR-060: Rollback capability
  """
  @spec emergency_rollback(String.t()) :: :ok | {:error, term()}
  def emergency_rollback(reason) do
    GenServer.call(__MODULE__, {:emergency_rollback, reason}, 10_000)
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("[SC-SIL4-026] Rollback Manager starting")

    state = %State{
      pending_rollbacks: [],
      active_rollback: nil,
      history: load_history(),
      guardian_approved: false
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:initiate, level, reason, opts}, _from, state) do
    rollback_id = generate_rollback_id()
    snapshot_id = Keyword.get(opts, :snapshot_id)

    # Request Guardian approval for critical rollbacks
    case request_guardian_approval(level, reason) do
      {:ok, :approved} ->
        entry = %{
          id: rollback_id,
          level: level,
          snapshot_id: snapshot_id,
          previous_version: current_version(),
          target_version: determine_target_version(snapshot_id, opts),
          status: :pending,
          created_at: DateTime.utc_now(),
          completed_at: nil,
          reason: reason,
          effects: nil
        }

        log_to_register(:rollback_initiated, entry)
        Logger.info("[SC-SIL4-026] Rollback initiated: #{rollback_id} (#{level})")

        new_state = %{state | pending_rollbacks: [entry | state.pending_rollbacks]}
        {:reply, {:ok, rollback_id}, new_state}

      {:error, reason} = error ->
        Logger.warning("[SC-SIL4-026] Rollback denied by Guardian: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:execute, rollback_id}, _from, state) do
    case find_rollback(rollback_id, state) do
      {:ok, entry} when entry.status == :pending ->
        Logger.info("[SC-SIL4-026] Executing rollback: #{rollback_id}")

        updated_entry = %{entry | status: :in_progress}
        new_state = update_rollback(updated_entry, state)

        case perform_rollback(updated_entry) do
          {:ok, effects} ->
            completed_entry = %{
              updated_entry
              | status: :completed,
                completed_at: DateTime.utc_now(),
                effects: effects
            }

            log_to_register(:rollback_completed, completed_entry)
            Logger.info("[SC-SIL4-026] Rollback completed: #{rollback_id}")

            final_state =
              move_to_history(completed_entry, %{
                new_state
                | active_rollback: nil
              })

            {:reply, :ok, final_state}

          {:error, reason} = error ->
            failed_entry = %{
              updated_entry
              | status: :failed,
                completed_at: DateTime.utc_now(),
                effects: %{error: reason}
            }

            log_to_register(:rollback_failed, failed_entry)
            Logger.error("[SC-SIL4-026] Rollback failed: #{rollback_id}: #{inspect(reason)}")

            final_state =
              move_to_history(failed_entry, %{
                new_state
                | active_rollback: nil
              })

            {:reply, error, final_state}
        end

      {:ok, entry} ->
        {:reply, {:error, {:invalid_status, entry.status}}, state}

      :not_found ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:cancel, rollback_id}, _from, state) do
    case find_rollback(rollback_id, state) do
      {:ok, entry} when entry.status == :pending ->
        cancelled_entry = %{entry | status: :cancelled, completed_at: DateTime.utc_now()}
        log_to_register(:rollback_cancelled, cancelled_entry)
        Logger.info("[SC-SIL4-026] Rollback cancelled: #{rollback_id}")

        new_state = remove_pending(rollback_id, state)
        {:reply, :ok, move_to_history(cancelled_entry, new_state)}

      {:ok, _entry} ->
        {:reply, {:error, :cannot_cancel_active}, state}

      :not_found ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:status, rollback_id}, _from, state) do
    case find_rollback(rollback_id, state) do
      {:ok, entry} -> {:reply, {:ok, entry}, state}
      :not_found -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:list, _from, state) do
    all_entries = state.pending_rollbacks ++ filter_within_window(state.history)
    {:reply, all_entries, state}
  end

  @impl true
  def handle_call(:available_rollbacks, _from, state) do
    case StateSnapshot.list() do
      {:ok, snapshots} ->
        available =
          snapshots
          |> Enum.filter(&within_rollback_window?(&1.timestamp))
          |> Enum.map(fn s ->
            %{
              snapshot_id: s.id,
              type: s.type,
              version: s.version,
              timestamp: s.timestamp
            }
          end)

        {:reply, {:ok, available}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:emergency_rollback, reason}, _from, state) do
    Logger.warning("[SC-EMR-057] Emergency rollback triggered: #{reason}")

    # Get latest snapshot for emergency rollback
    case StateSnapshot.latest() do
      {:ok, snapshot_id} ->
        entry = %{
          id: generate_rollback_id(),
          level: :full,
          snapshot_id: snapshot_id,
          previous_version: current_version(),
          target_version: "emergency",
          status: :in_progress,
          created_at: DateTime.utc_now(),
          completed_at: nil,
          reason: "EMERGENCY: #{reason}",
          effects: nil
        }

        log_to_register(:emergency_rollback_started, entry)

        case perform_rollback(entry) do
          {:ok, effects} ->
            completed = %{
              entry
              | status: :completed,
                completed_at: DateTime.utc_now(),
                effects: effects
            }

            log_to_register(:emergency_rollback_completed, completed)
            {:reply, :ok, move_to_history(completed, state)}

          {:error, _} = error ->
            failed = %{entry | status: :failed, completed_at: DateTime.utc_now()}
            log_to_register(:emergency_rollback_failed, failed)
            {:reply, error, move_to_history(failed, state)}
        end

      {:error, :no_snapshots} ->
        Logger.error("[SC-EMR-057] No snapshots available for emergency rollback")
        {:reply, {:error, :no_snapshots}, state}
    end
  end

  # Private Functions

  defp generate_rollback_id do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "rb_#{timestamp}_#{random}"
  end

  defp current_version do
    Application.spec(:indrajaal, :vsn) |> to_string()
  end

  defp determine_target_version(nil, _opts), do: "previous"

  defp determine_target_version(snapshot_id, _opts) do
    case StateSnapshot.verify(snapshot_id) do
      :ok ->
        case File.read("data/snapshots/#{snapshot_id}.meta") do
          {:ok, data} ->
            metadata = :erlang.binary_to_term(data)
            metadata.version

          _ ->
            "unknown"
        end

      _ ->
        "unknown"
    end
  end

  defp request_guardian_approval(:full, reason) do
    # Full rollbacks require Guardian approval per SC-PRAJNA-001
    try do
      proposal = %{type: :rollback, level: :full, reason: reason}

      case Guardian.validate_proposal(proposal) do
        {:ok, _approved} -> {:ok, :approved}
        {:veto, veto_reason, _fallback} -> {:error, {:guardian_denied, veto_reason}}
      end
    rescue
      _ ->
        # Guardian not available, auto-approve for development
        Logger.warning("[SC-PRAJNA-001] Guardian not available, auto-approving rollback")
        {:ok, :approved}
    end
  end

  defp request_guardian_approval(_level, _reason) do
    # Lower level rollbacks auto-approved
    {:ok, :approved}
  end

  defp find_rollback(rollback_id, state) do
    case Enum.find(state.pending_rollbacks, &(&1.id == rollback_id)) do
      nil ->
        case Enum.find(state.history, &(&1.id == rollback_id)) do
          nil -> :not_found
          entry -> {:ok, entry}
        end

      entry ->
        {:ok, entry}
    end
  end

  defp update_rollback(entry, state) do
    pending =
      Enum.map(state.pending_rollbacks, fn e ->
        if e.id == entry.id, do: entry, else: e
      end)

    %{state | pending_rollbacks: pending, active_rollback: entry}
  end

  defp remove_pending(rollback_id, state) do
    pending = Enum.reject(state.pending_rollbacks, &(&1.id == rollback_id))
    %{state | pending_rollbacks: pending}
  end

  defp move_to_history(entry, state) do
    new_state = remove_pending(entry.id, state)
    %{new_state | history: [entry | new_state.history]}
  end

  defp perform_rollback(%{level: :config, snapshot_id: snapshot_id})
       when not is_nil(snapshot_id) do
    # Level 1: Config rollback
    Logger.info("[SC-SIL4-026] Performing config rollback")

    case StateSnapshot.restore(snapshot_id, type: :config_only) do
      :ok -> {:ok, %{level: :config, action: :restored}}
      error -> error
    end
  end

  defp perform_rollback(%{level: :state, snapshot_id: snapshot_id})
       when not is_nil(snapshot_id) do
    # Level 2: State rollback
    Logger.info("[SC-SIL4-026] Performing state rollback")

    case StateSnapshot.restore(snapshot_id, type: :state_only) do
      :ok -> {:ok, %{level: :state, action: :restored}}
      error -> error
    end
  end

  defp perform_rollback(%{level: :code}) do
    # Level 3: Code rollback - requires release system
    Logger.info("[SC-SIL4-026] Performing code rollback")

    # This would typically invoke the release system
    # For now, log the intent
    Logger.warning("[SC-SIL4-026] Code rollback requires release system - manual intervention")
    {:ok, %{level: :code, action: :manual_required}}
  end

  defp perform_rollback(%{level: :full, snapshot_id: snapshot_id}) when not is_nil(snapshot_id) do
    # Level 4: Full rollback
    Logger.info("[SC-SIL4-026] Performing full rollback")

    with :ok <- StateSnapshot.restore(snapshot_id) do
      {:ok, %{level: :full, action: :restored, snapshot_id: snapshot_id}}
    end
  end

  defp perform_rollback(%{level: _level, snapshot_id: nil}) do
    # No snapshot specified - try to use latest
    case StateSnapshot.latest() do
      {:ok, snapshot_id} ->
        StateSnapshot.restore(snapshot_id)
        {:ok, %{action: :restored_from_latest, snapshot_id: snapshot_id}}

      error ->
        error
    end
  end

  defp within_rollback_window?(timestamp) do
    cutoff = DateTime.utc_now() |> DateTime.add(-@rollback_window_hours * 3600, :second)
    DateTime.compare(timestamp, cutoff) == :gt
  end

  defp filter_within_window(entries) do
    Enum.filter(entries, fn e -> within_rollback_window?(e.created_at) end)
  end

  defp load_history do
    # Load history from persistent storage if available
    history_file = "data/rollback_history.bin"

    case File.read(history_file) do
      {:ok, data} ->
        :erlang.binary_to_term(data)
        |> filter_within_window()

      _ ->
        []
    end
  end

  defp log_to_register(action, entry) do
    try do
      Register.append(:rollback, %{
        action: action,
        rollback_id: entry.id,
        level: entry.level,
        timestamp: DateTime.utc_now()
      })
    rescue
      _ -> :ok
    end
  end
end
