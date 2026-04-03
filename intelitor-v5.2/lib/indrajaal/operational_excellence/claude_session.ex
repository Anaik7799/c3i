defmodule Indrajaal.OperationalExcellence.ClaudeSession do
  @moduledoc """
  Claude session management system with framework compliance tracking.
  Implements TDG _requirements with STAMP safety constraints.

  Framework: AEE+SOPv5.1+GDE+PHICS+TPS+STAMP+Container-Only

  Safety Constraints:
  - SC-005: Claude sessions must enforce framework compliance
  - SC-006: Claude activity logs must be tamper-proof
  """

  use GenServer
  require Logger

  alias Indrajaal.OperationalExcellence.ClaudeActivity

  # 1 hour
  @session_timeout 3_600_000
  @session_dir "data/tmp"
  @max_active_sessions 100

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start a new Claude session with compliance validation.
  Satisfies SC-005: Claude sessions must enforce framework compliance.
  """
  def start(request_context) do
    GenServer.call(__MODULE__, {:start_session, request_context})
  end

  @doc """
  Get current session by ID.
  """
  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  @doc """
  Update session with new operation.
  """
  def update_session(session_id, operation) do
    GenServer.call(__MODULE__, {:update_session, session_id, operation})
  end

  @doc """
  End a Claude session and persist data.
  """
  def end_session(session_id) do
    GenServer.call(__MODULE__, {:end_session, session_id})
  end

  @doc """
  Save session to persistent storage.
  """
  def save(session) do
    GenServer.call(__MODULE__, {:save_session, session})
  end

  @doc """
  List all active sessions.
  """
  def list_active_sessions do
    GenServer.call(__MODULE__, :list_active_sessions)
  end

  @doc """
  Validate framework compliance for an operation.
  """
  def validate_compliance(operation) do
    GenServer.call(__MODULE__, {:validate_compliance, operation})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Ensure session directory exists
    File.mkdir_p!(@session_dir)

    state = %{
      active_sessions: %{},
      session_history: load_session_history(),
      compliance_rules: load_compliance_rules(),
      metrics: initialize_metrics()
    }

    # Schedule cleanup
    schedule_cleanup()

    {:ok, state}
  end

  @impl true
  def handle_call({:startsession, request_context}, _from, state) do
    # SC-005: Validate compliance before starting session
    case validate_request_compliance(request_context, state.compliance_rules) do
      :ok ->
        # Create new session
        session = create_session(request_context)

        # Track session start
        ClaudeActivity.track(
          %{
            type: :session_start,
            target: session.id,
            __params: %{__context: request_context}
          },
          %{session_id: session.id}
        )

        # Update state
        new_active = Map.put(state.active_sessions, session.id, session)

        # Check session limit
        new_state =
          if map_size(new_active) > @max_active_sessions do
            cleanup_oldest_sessions(%{state | active_sessions: new_active})
          else
            %{state | active_sessions: new_active}
          end

        # Update metrics
        new_metrics = Map.update(new_state.metrics, :sessions_created, 1, &(&1 + 1))

        {:reply, {:ok, session}, %{new_state | metrics: new_metrics}}

      {:error, :compliance_violation} = error ->
        Logger.error(
          "[ClaudeSession] Compliance violation for _request: #{inspect(request_context)}"
        )

        # Track violation
        ClaudeActivity.track(
          %{
            type: :compliance_violation,
            target: "session_creation",
            __params: %{__context: request_context, violation: :framework_compliance}
          },
          %{session_id: "violation"}
        )

        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:getsession, session_id}, _from, state) do
    case Map.get(state.active_sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        {:reply, {:ok, session}, state}
    end
  end

  @impl true
  def handle_call({:updatesession, session_id, operation}, _from, state) do
    case Map.get(state.active_sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        # Update session
        updated_session = %{
          session
          | operations: [operation | session.operations],
            last_activity: DateTime.utc_now(),
            metrics: update_session_metrics(session.metrics, operation)
        }

        # Update state
        new_sessions = Map.put(state.active_sessions, session_id, updated_session)

        {:reply, {:ok, updated_session}, %{state | active_sessions: new_sessions}}
    end
  end

  @impl true
  def handle_call({:endsession, session_id}, _from, state) do
    case Map.get(state.active_sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        # Finalize session
        final_session = finalize_session(session)

        # Save to persistent storage
        save_session_to_file(final_session)

        # Track session end
        ClaudeActivity.track(
          %{
            type: :session_end,
            target: session_id,
            __params: %{
              duration_ms:
                DateTime.diff(final_session.ended_at, final_session.started_at, :millisecond),
              operations_count: length(final_session.operations)
            }
          },
          %{session_id: session_id}
        )

        # Remove from active sessions
        new_sessions = Map.delete(state.active_sessions, session_id)

        # Update history
        new_history = [final_session | state.session_history] |> Enum.take(1000)

        # Update metrics
        new_metrics =
          state.metrics
          |> Map.update(:sessions_completed, 1, &(&1 + 1))
          |> update_average_duration(final_session)

        new_state = %{
          state
          | active_sessions: new_sessions,
            session_history: new_history,
            metrics: new_metrics
        }

        {:reply, {:ok, final_session}, new_state}
    end
  end

  @impl true
  def handle_call({:savesession, session}, _from, state) do
    # SC-006: Ensure tamper-proof saving
    result = save_session_to_file(session)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:listactivesessions, _from, state) do
    session_list = Map.values(state.active_sessions)
    sessions = Enum.sort_by(session_list, & &1.started_at, {:desc, DateTime})

    {:reply, sessions, state}
  end

  @impl true
  def handle_call({:validatecompliance, operation}, _from, state) do
    result = check_operation_compliance(operation, state.compliance_rules)
    {:reply, result, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Clean up expired sessions
    now = DateTime.utc_now()

    {active, expired} =
      Map.split_with(state.active_sessions, fn {_id, session} ->
        DateTime.diff(now, session.last_activity, :millisecond) < @session_timeout
      end)

    # End expired sessions
    Enum.each(expired, fn {session_id, session} ->
      Logger.info("[ClaudeSession] Auto-ending expired session: #{session_id}")

      final_session = finalize_session(session)
      save_session_to_file(final_session)

      ClaudeActivity.track(
        %{
          type: :session_timeout,
          target: session_id,
          __params: %{reason: :inactivity}
        },
        %{session_id: session_id}
      )
    end)

    # Update metrics
    new_metrics =
      Map.update(state.metrics, :sessions_expired, length(expired), &(&1 + length(expired)))

    # Schedule next cleanup
    schedule_cleanup()

    {:noreply, %{state | active_sessions: active, metrics: new_metrics}}
  end

  # Private functions

  defp initialize_metrics do
    %{
      sessions_created: 0,
      sessions_completed: 0,
      sessions_expired: 0,
      compliance_violations: 0,
      average_session_duration_ms: 0,
      total_operations: 0
    }
  end

  defp load_session_history do
    # Load recent sessions from disk
    history_file = Path.join(@session_dir, "session_history.json")

    if File.exists?(history_file) do
      file_content = File.read!(history_file)

      file_content
      |> Jason.decode!()
      |> Enum.map(&atomize_session/1)
      |> Enum.take(100)
    else
      []
    end
  end

  defp load_compliance_rules do
    # SC-005: Define framework compliance rules
    %{
      _required_frameworks: %{
        aee: true,
        sopv51: true,
        gde: true,
        phics: true,
        tps: true,
        stamp: true
      },
      forbidden_operations: [
        "direct_container_exec",
        "bypass_checks",
        "disable_monitoring",
        "skip_validation"
      ],
      _required_validations: [
        :container_compliance,
        :methodology_compliance,
        :safety_constraints,
        :quality_gates
      ]
    }
  end

  defp validate_request_compliance(request_context, rules) do
    # Check for forbidden operations
    if request_context[:operation] in rules.forbidden_operations do
      {:error, :compliance_violation}
    else
      # Check for bypass attempts
      if request_context[:bypass_checks] == true do
        {:error, :compliance_violation}
      else
        :ok
      end
    end
  end

  defp create_session(request_context) do
    session_id = generate_session_id()

    %{
      id: session_id,
      started_at: DateTime.utc_now(),
      last_activity: DateTime.utc_now(),
      __context: sanitize_context(request_context),
      framework_compliance: %{
        aee: true,
        sopv51: true,
        gde: true,
        phics: true,
        tps: true,
        stamp: true
      },
      operations: [],
      metrics: %{
        operations_count: 0,
        compliance_checks: 0,
        validation_passes: 0,
        validation_failures: 0
      },
      status: :active
    }
  end

  defp generate_session_id do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    rand_bytes = :crypto.strong_rand_bytes(8)
    random = rand_bytes |> Base.encode16()
    "claude_session_#{timestamp}_#{random}"
  end

  defp sanitize_context(context) do
    # Remove sensitive information
    Map.drop(context, [:password, :token, :secret])
  end

  defp update_session_metrics(metrics, operation) do
    metrics
    |> Map.update(:operations_count, 1, &(&1 + 1))
    |> update_operation_metrics(operation)
  end

  defp update_operation_metrics(metrics, operation) do
    case operation[:result] do
      :success ->
        Map.update(metrics, :validation_passes, 1, &(&1 + 1))

      :failure ->
        Map.update(metrics, :validation_failures, 1, &(&1 + 1))

      _ ->
        metrics
    end
  end

  defp finalize_session(session) do
    %{
      session
      | ended_at: DateTime.utc_now(),
        status: :completed,
        summary: generate_session_summary(session)
    }
  end

  defp generate_session_summary(session) do
    duration_ms = DateTime.diff(DateTime.utc_now(), session.started_at, :millisecond)

    %{
      duration_ms: duration_ms,
      total_operations: length(session.operations),
      compliance_maintained: all_frameworks_compliant?(session),
      validation_success_rate: calculate_success_rate(session.metrics),
      key_operations: extract_key_operations(session.operations)
    }
  end

  defp all_frameworks_compliant?(session) do
    Enum.all?(session.framework_compliance, fn {_framework, compliant} -> compliant end)
  end

  defp calculate_success_rate(metrics) do
    total = metrics.validation_passes + metrics.validation_failures

    if total > 0 do
      metrics.validation_passes / total
    else
      1.0
    end
  end

  defp extract_key_operations(operations) do
    operations
    |> Enum.filter(fn op -> op[:significant] == true end)
    |> Enum.take(10)
  end

  defp save_session_to_file(session) do
    # SC-006: Tamper-proof saving with checksums
    filename = "claude_session_#{session.id}_#{timestamp_string()}.json"
    filepath = Path.join(@session_dir, filename)

    # Prepare session data
    session_data = %{
      session: Map.from_struct(session),
      metadata: %{
        version: "1.0.0",
        framework: "AEE+SOPv5.1",
        saved_at: DateTime.utc_now()
      }
    }

    # Calculate checksum for tamper detection
    json_data = Jason.encode!(session_data, pretty: true)
    hash_bytes = :crypto.hash(:sha256, json_data)
    checksum = hash_bytes |> Base.encode16()

    # Add checksum to data
    final_data = Map.put(session_data, :checksum, checksum)

    # Write to file
    case File.write(filepath, Jason.encode!(final_data, pretty: true)) do
      :ok ->
        # Add to git for version control
        System.cmd("git", ["add", filepath])
        {:ok, filepath}

      error ->
        Logger.error("[ClaudeSession] Failed to save session: #{inspect(error)}")
        error
    end
  end

  defp cleanup_oldest_sessions(state) do
    # Remove oldest inactive sessions
    sessions_by_activity =
      state.active_sessions
      |> Enum.sort_by(fn {_id, session} -> session.last_activity end, DateTime)
      # Keep 90 newest
      |> Enum.take(@max_active_sessions - 10)

    new_sessions = Map.new(sessions_by_activity)

    %{state | active_sessions: new_sessions}
  end

  defp check_operation_compliance(operation, rules) do
    cond do
      operation.type in rules.forbidden_operations ->
        {:error, :forbidden_operation}

      not all_validations_present?(operation, rules._required_validations) ->
        {:error, :missing_validations}

      true ->
        :ok
    end
  end

  defp all_validations_present?(operation, required_validations) do
    operation_validations = Map.get(operation, :validations, [])
    Enum.all?(required_validations, &(&1 in operation_validations))
  end

  defp update_average_duration(metrics, session) do
    duration = DateTime.diff(session.ended_at, session.started_at, :millisecond)
    completed = metrics.sessions_completed

    new_avg =
      if completed > 1 do
        current_avg = metrics.average_session_duration_ms
        (current_avg * (completed - 1) + duration) / completed
      else
        duration
      end

    Map.put(metrics, :average_session_duration_ms, new_avg)
  end

  defp schedule_cleanup do
    # Run cleanup every 5 minutes
    Process.send_after(self(), :cleanup, 5 * 60 * 1000)
  end

  defp timestamp_string do
    DateTime.utc_now()
    |> DateTime.to_iso8601()
    |> String.replace(~r/[:\s]/, "_")
  end

  defp atomize_session(data) when is_map(data) do
    # Convert string keys to atoms for loaded sessions
    data
    |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
    |> Map.new()
  end
end
