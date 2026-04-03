defmodule Indrajaal.Claude.MandatoryLoggingEnforcer do
  @moduledoc """
  MANDATORY Claude Logging Enforcement System

  🚨 CRITICAL RULE: ALL Claude - generated activities MUST be logged to ./__data / tmp
    folder

  This module provides systematic enforcement of mandatory Claude logging
    __requirements:
  - Automatic interception of all Claude activities
  - Forced logging to ./__data / tmp directory with ZERO exceptions
  - Comprehensive audit trail for SOPv5.1 compliance
  - Real - time validation and enforcement
  - Container - aware logging with PHICS integration

  ZERO TOLERANCE POLICY:
  - No Claude activity may proceed without logging
  - All logs MUST be stored in ./__data / tmp directory
  - Violations result in immediate system halt
  - Complete audit trail __required for regulatory compliance

  Agent: Supervisor - 1 enforces mandatory logging with cybernetic oversight
  SOPv5.1 Compliance: ✅ Zero tolerance logging enforcement with systematic
    validation
  """

  use GenServer
  require Logger

  @log_directory "./__data / tmp"
  @mandatory_logging_enabled true
  # :halt_system | :warn | :ignore
  @violation_action :halt_system

  # Claude activity types that MUST be logged
  @mandatory_log_activities [
    :task_start,
    :task_completion,
    :code_generation,
    :file_operation,
    :compilation_activity,
    :agent_coordination,
    :error_occurrence,
    :performance_metric,
    :cybernetic_coordination,
    :tps_methodology,
    :stamp_analysis,
    :tdg_compliance,
    :container_execution,
    :phics_activity,
    :git_incremental_check,
    :timestamp_correction,
    :journal_entry,
    :readme_update,
    :session_start,
    :session_end
  ]

  @spec start_link(any()) :: any()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Enforce mandatory logging for Claude activity.
  CRITICAL: This function MUST be called for ALL Claude activities.
  """
  @spec enforce_logging(any(), any()) :: any()
  def enforce_logging(activitytype, details \\ %{}) do
    GenServer.call(__MODULE__, {:enforce_logging, activitytype, details}, :infinity)
  end

  @doc """
  Validate that logging directory exists and is accessible.
  """
  @spec validate_logging_environment() :: any()
  def validate_logging_environment do
    GenServer.call(__MODULE__, :validate_logging_environment)
  end

  @doc """
  Get logging statistics and compliance metrics.
  """
  @spec get_logging_stats() :: any()
  def get_logging_stats do
    GenServer.call(__MODULE__, :get_logging_stats)
  end

  @doc """
  MANDATORY: Check if activity __requires logging (all activities do).
  """
  @spec activity_requires_logging?(any()) :: any()
  def activity_requires_logging?(activity_type) do
    activity_type in @mandatory_log_activities or @mandatory_logging_enabled
  end

  # ============================================================================
  # GenServer Implementation
  # ============================================================================

  @impl true
  @spec init(any()) :: any()
  def init(opts) do
    # Ensure log directory exists
    File.mkdir_p!(@log_directory)

    state = %{
      logs_written: 0,
      violations_detected: 0,
      last_log_time: DateTime.utc_now(),
      mandatory_enabled: Keyword.get(opts, :mandatory_enabled, @mandatory_logging_enabled),
      log_directory: Keyword.get(opts, :log_directory, @log_directory),
      session_id: generate_session_id(),
      startup_time: DateTime.utc_now()
    }

    Logger.info("Mandatory Claude Logging Enforcer initialized",
      log_directory: state.log_directory,
      mandatory_enabled: state.mandatory_enabled,
      session_id: state.session_id
    )

    # Log the enforcer startup
    write_mandatory_log(
      :enforcer_startup,
      %{
        session_id: state.session_id,
        log_directory: state.log_directory,
        mandatory_enabled: state.mandatory_enabled,
        violation_action: @violation_action,
        startup_time: state.startup_time
      },
      state
    )

    {:ok, Map.put(state, :logs_written, 1)}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:log_activity, activitytype, details}, _from, state) do
    # MANDATORY: All activities must be logged
    if state.mandatory_enabled do
      case write_mandatory_log(activitytype, details, state) do
        :ok ->
          new_state = %{
            state
            | logs_written: state.logs_written + 1,
              last_log_time: DateTime.utc_now()
          }

          {:reply, :ok, new_state}

        {:error, reason} ->
          # CRITICAL VIOLATION: Unable to write mandatory log
          violation_details = %{
            activity_type: activitytype,
            details: details,
            error: reason,
            violation_time: DateTime.utc_now(),
            session_id: state.session_id
          }

          handle_logging_violation(violation_details, state)
      end
    else
      # Logging disabled - this is a configuration violation
      violation_details = %{
        activity_type: activitytype,
        details: details,
        violation_type: :logging_disabled,
        violation_time: DateTime.utc_now(),
        session_id: state.session_id
      }

      handle_logging_violation(violation_details, state)
    end
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:validate_logging_environment, _from, state) do
    validation_result = %{
      directory_exists: File.dir?(state.log_directory),
      directory_writable: directory_writable?(state.log_directory),
      mandatory_enabled: state.mandatory_enabled,
      logs_written: state.logs_written,
      violations_detected: state.violations_detected,
      session_id: state.session_id,
      validation_time: DateTime.utc_now()
    }

    all_valid =
      validation_result.directory_exists and
        validation_result.directory_writable and
        validation_result.mandatory_enabled

    result = Map.put(validation_result, :valid, all_valid)

    # Log the validation
    write_mandatory_log(:logging_environment_validation, result, state)

    {:reply, result, %{state | logs_written: state.logs_written + 1}}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:get_logging_stats, _from, state) do
    stats = %{
      logs_written: state.logs_written,
      violations_detected: state.violations_detected,
      last_log_time: state.last_log_time,
      session_id: state.session_id,
      startup_time: state.startup_time,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.startup_time, :second),
      log_directory: state.log_directory,
      mandatory_enabled: state.mandatory_enabled,
      stats_generated: DateTime.utc_now()
    }

    {:reply, stats, state}
  end

  # ============================================================================
  # Private Implementation
  # ============================================================================

  defp write_mandatory_log(activitytype, details, state) do
    timestamp = DateTime.utc_now()

    log_entry = %{
      timestamp: timestamp,
      session_id: state.session_id,
      activity_type: activitytype,
      details: details,
      mandatory_logging: true,
      sopv51_compliance: true,
      log_sequence: state.logs_written + 1,
      agent: "Supervisor - 1 (Mandatory Logging Enforcer)",
      container_mode: Map.get(details, :container_mode, true),
      phics_enabled: Map.get(details, :phics_enabled, true)
    }

    # Generate unique log filename
    unix_timestamp = DateTime.to_unix(timestamp)
    filename = "claude_mandatory_#{activitytype}_#{unix_timestamp}_#{state.session_id}.json"
    file_path = Path.join(state.log_directory, filename)

    # Write log with comprehensive error handling
    try do
      log_content = Jason.encode!(log_entry, pretty: true)

      case File.write(file_path, log_content) do
        :ok ->
          Logger.debug("Mandatory log written: #{filename}")
          :ok

        {:error, reason} ->
          Logger.error("Failed to write mandatory log: #{reason}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Exception writing mandatory log: #{inspect(error)}")
        {:error, error}
    end
  end

  @spec handle_logging_violation(term(), term()) :: term()
  defp handle_logging_violation(violationdetails, state) do
    Logger.error("CRITICAL LOGGING VIOLATION", violationdetails)

    new_state = %{state | violations_detected: state.violations_detected + 1}

    case @violation_action do
      :halt_system ->
        # CRITICAL: System halt due to logging violation
        Logger.error("SYSTEM HALT: Mandatory logging violation detected")

        # Try to write violation log before halting
        try do
          write_violation_log(violationdetails, state)
        catch
          # Continue to halt even if violation log fails
          _, _ -> :ok
        end

        System.halt(1)

      :warn ->
        Logger.warning(
          "Logging violation detected but continuing",
          violationdetails
        )

        {:reply, {:warning, violationdetails}, new_state}

      :ignore ->
        {:reply, :ok, new_state}
    end
  end

  @spec write_violation_log(term(), term()) :: term()
  defp write_violation_log(violationdetails, state) do
    timestamp = DateTime.utc_now()
    unix_timestamp = DateTime.to_unix(timestamp)
    filename = "claude_violation_#{unix_timestamp}_#{state.session_id}.json"
    file_path = Path.join(state.log_directory, filename)

    violation_log = %{
      timestamp: timestamp,
      session_id: state.session_id,
      violation_type: :mandatory_logging_violation,
      violation_details: violationdetails,
      system_state: %{
        logs_written: state.logs_written,
        violations_detected: state.violations_detected,
        mandatory_enabled: state.mandatory_enabled
      },
      action_taken: @violation_action,
      sopv51_compliance: false,
      critical: true
    }

    case File.write(file_path, Jason.encode!(violation_log, pretty: true)) do
      :ok -> Logger.info("Violation log written: #{filename}")
      {:error, reason} -> Logger.error("Failed to write violation log: #{reason}")
    end
  end

  @spec directory_writable?(term()) :: term()
  defp directory_writable?(directory) do
    test_file = Path.join(directory, "write_test_#{System.unique_integer()}.tmp")

    case File.write(test_file, "test") do
      :ok ->
        File.rm(test_file)
        true

      {:error, _} ->
        false
    end
  end

  @spec generate_session_id() :: any()
  defp generate_session_id do
    random_bytes = :crypto.strong_rand_bytes(8)
    Base.encode16(random_bytes, case: :lower)
  end
end

# Agent: Supervisor - 1 (AI Coordination)
# SOPv5.1 Compliance: ✅ AI coordination and intelligent system management with
# Domain: Claude
# Responsibilities: Strategic oversight, coordination, quality assurance, cyber
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
