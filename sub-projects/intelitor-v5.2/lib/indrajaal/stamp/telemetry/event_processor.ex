defmodule Indrajaal.STAMP.Telemetry.EventProcessor do
  @moduledoc """
  Event Processing Engine - SOPv5.1 Implementation

  🎯 SOPv5.1: Cybernetic __event processing with real - time safety monitoring
  🧪 TDG IMPLEMENTATION: Addresses critical test failures for safety __event handling
  🤖 MULTI - AGENT READY: Optimized for parallel __event processing
  [LAUNCH] NO TIMEOUT: High - throughput __event processing with infinite patience

  This module processes telemetry __events from registered handlers and implements
  real - time safety monitoring with automated response mechanisms.
  """

  require Logger
  use GenServer

  @doc """
  Start the __event processor with SOPv5.1 multi - layer agent support
  """
  @spec start_link(any()) :: any()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ========================================================================
  # PUBLIC API - TDG IMPLEMENTATION
  # ========================================================================

  @doc """
  Process alarm - related telemetry __events
  TDG: Addresses test "handles alarm telemetry __events and updates metrics"
  """
  @spec process_alarm_event(any(), any()) :: any()
  def process_alarm_event(measurements, metadata) do
    GenServer.cast(__MODULE__, {:process_alarm, measurements, metadata})
  end

  @doc """
  Process tenant access violation __events
  TDG: Addresses test "detects cross - tenant access violations"
  """
  @spec process_tenant_event(any(), any()) :: any()
  def process_tenant_event(measurements, metadata) do
    GenServer.cast(__MODULE__, {:process_tenant, measurements, metadata})
  end

  @doc """
  Process authentication failure __events
  TDG: Addresses test "tracks authentication failure rate"
  """
  @spec process_auth_event(any(), any()) :: any()
  def process_auth_event(measurements, metadata) do
    GenServer.cast(__MODULE__, {:process_auth, measurements, metadata})
  end

  @doc """
  Process database transaction __events
  TDG: Addresses test "monitors database transaction health"
  """
  @spec process_transaction_event(any(), any()) :: any()
  def process_transaction_event(measurements, metadata) do
    GenServer.cast(__MODULE__, {:process_transaction, measurements, metadata})
  end

  @doc """
  Process generic safety __events
  TDG: Addresses general __event processing __requirements
  """
  @spec process_generic_event(term(), term(), term(), term()) :: term()
  def process_generic_event(handler_id, event, measurements, metadata) do
    GenServer.cast(__MODULE__, {:process_generic, handler_id, event, measurements, metadata})
  end

  @doc """
  Get current safety metrics
  TDG: Addresses test validation __requirements
  """
  @spec get_safety_metrics() :: any()
  def get_safety_metrics do
    GenServer.call(__MODULE__, :get_safety_metrics, :infinity)
  end

  @doc """
  Get violation history
  TDG: Addresses test __requirement for violation tracking
  """
  @spec get_violations() :: any()
  def get_violations do
    GenServer.call(__MODULE__, :get_violations, :infinity)
  end

  @doc """
  Check if alarm storm condition exists
  TDG: Addresses test "triggers safety response for alarm storm condition"
  """
  @spec check_alarm_storm_condition() :: any()
  def check_alarm_storm_condition do
    GenServer.call(__MODULE__, :check_alarm_storm, :infinity)
  end

  # ========================================================================
  # GENSERVER CALLBACKS
  # ========================================================================

  @impl true
  @spec init(any()) :: any()
  def init(_opts) do
    Logger.info("🏭 SOPv5.1: Starting Telemetry Event Processor")

    state = %{
      metrics: %{
        alarm_count: 0,
        tenant_violations: 0,
        auth_failures: 0,
        transaction_rollbacks: 0,
        __events_processed_total: 0,
        last_alarm_storm_check: DateTime.utc_now()
      },
      violations: [],
      thresholds: %{
        alarm_storm_threshold: 1000,
        auth_failure_threshold: 100,
        # Zero tolerance
        tenant_violation_threshold: 0,
        transaction_rollback_threshold: 20
      },
      response_triggers: %{
        alarm_storm_active: false,
        critical_violations_detected: false
      }
    }

    # Initialize ETS tables for metrics storage
    :ets.new(:__event_metrics, [:public, :named_table, :set])
    :ets.new(:safety_violations, [:public, :named_table, :bag])
    :ets.new(:processing_stats, [:public, :named_table, :set])

    # Store initial metrics
    :ets.insert(:__event_metrics, {:current_metrics, state.metrics})
    :ets.insert(:processing_stats, {:start_time, DateTime.utc_now()})

    {:ok, state}
  end

  # ========================================================================
  # EVENT PROCESSING HANDLERS
  # ========================================================================

  @impl true
  @spec handle_cast(term(), term()) :: term()
  def handle_cast({:process_alarm, _measurements, metadata}, state) do
    Logger.debug("🚨 Processing alarm __event: #{inspect(metadata)}")

    # Update alarm count
    new_alarm_count = state.metrics.alarm_count + 1

    # Check for alarm storm condition
    alarm_storm_detected = new_alarm_count > state.thresholds.alarm_storm_threshold

    # Update metrics
    updated_metrics = %{
      state.metrics
      | alarm_count: new_alarm_count,
        __events_processed_total: state.metrics.__events_processed_total + 1
    }

    # Store metrics in ETS
    :ets.insert(:__event_metrics, {:current_metrics, updated_metrics})

    # Handle alarm storm response
    updated_triggers =
      if alarm_storm_detected and not state.response_triggers.alarm_storm_active do
        Logger.warning("🚨 ALARM STORM DETECTED: #{new_alarm_count} alarms exceed threshold")

        # Log violation
        violation = %{
          type: :alarm_storm,
          detected_at: DateTime.utc_now(),
          threshold: state.thresholds.alarm_storm_threshold,
          actual_value: new_alarm_count,
          severity: :critical
        }

        :ets.insert(:safety_violations, {:alarm_storm, violation})

        # Trigger safety response
        trigger_safety_response(:alarm_storm, violation)

        %{state.response_triggers | alarm_storm_active: true}
      else
        state.response_triggers
      end

    new_state = %{state | metrics: updated_metrics, response_triggers: updated_triggers}

    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast({:process_tenant, term(), term()}, term()) :: {:noreply, term()}
  def handle_cast({:process_tenant, _measurements, metadata}, state) do
    Logger.debug("🔐 Processing tenant access __event: #{inspect(metadata)}")

    # Check for cross - tenant access violations
    is_violation = detect_tenant_violation(metadata)

    updated_metrics = %{
      state.metrics
      | __events_processed_total: state.metrics.__events_processed_total + 1
    }

    new_state =
      if is_violation do
        Logger.error("🚨 TENANT VIOLATION DETECTED: #{inspect(metadata)}")

        # Zero tolerance for tenant violations
        violation = %{
          type: :tenant_violation,
          detected_at: DateTime.utc_now(),
          metadata: metadata,
          severity: :critical
        }

        # Log violation
        :ets.insert(:safety_violations, {:tenant_violation, violation})

        # Trigger immediate safety response
        trigger_safety_response(:tenant_violation, violation)

        # Update violation count
        updated_tenant_metrics = %{
          updated_metrics
          | tenant_violations: state.metrics.tenant_violations + 1
        }

        %{state | metrics: updated_tenant_metrics, violations: [violation | state.violations]}
      else
        %{state | metrics: updated_metrics}
      end

    # Store updated metrics
    :ets.insert(:__event_metrics, {:current_metrics, new_state.metrics})

    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast({:process_auth, term(), term()}, term()) :: {:noreply, term()}
  def handle_cast({:process_auth, _measurements, metadata}, state) do
    Logger.debug("🔑 Processing auth __event: #{inspect(metadata)}")

    # Track authentication failures
    is_failure = Map.get(metadata, :result) == :failure

    updated_metrics =
      if is_failure do
        new_failure_count = state.metrics.auth_failures + 1

        # Check if failure rate exceeds threshold
        if new_failure_count > state.thresholds.auth_failure_threshold do
          Logger.warning("🚨 AUTH FAILURE THRESHOLD EXCEEDED: #{new_failure_count} failures")

          violation = %{
            type: :auth_failure_threshold,
            detected_at: DateTime.utc_now(),
            threshold: state.thresholds.auth_failure_threshold,
            actual_value: new_failure_count,
            severity: :high
          }

          :ets.insert(:safety_violations, {:auth_failure, violation})
          trigger_safety_response(:auth_failure_threshold, violation)
        end

        %{
          state.metrics
          | auth_failures: new_failure_count,
            __events_processed_total: state.metrics.__events_processed_total + 1
        }
      else
        %{state.metrics | __events_processed_total: state.metrics.__events_processed_total + 1}
      end

    # Store updated metrics
    :ets.insert(:__event_metrics, {:current_metrics, updated_metrics})

    new_state = %{state | metrics: updated_metrics}
    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast({:process_transaction, term(), term()}, term()) :: {:noreply, term()}
  def handle_cast({:process_transaction, _measurements, metadata}, state) do
    Logger.debug("💾 Processing transaction __event: #{inspect(metadata)}")

    # Track transaction rollbacks
    is_rollback = Map.get(metadata, :result) == :rollback

    updated_metrics =
      if is_rollback do
        new_rollback_count = state.metrics.transaction_rollbacks + 1

        # Check if rollback rate exceeds threshold
        if new_rollback_count > state.thresholds.transaction_rollback_threshold do
          Logger.warning("🚨 TRANSACTION ROLLBACK THRESHOLD EXCEEDED: #{new_rollback_count}")

          violation = %{
            type: :transaction_rollback_threshold,
            detected_at: DateTime.utc_now(),
            threshold: state.thresholds.transaction_rollback_threshold,
            actual_value: new_rollback_count,
            severity: :medium
          }

          :ets.insert(:safety_violations, {:transaction_rollback, violation})
          trigger_safety_response(:transaction_rollback_threshold, violation)
        end

        %{
          state.metrics
          | transaction_rollbacks: new_rollback_count,
            __events_processed_total: state.metrics.__events_processed_total + 1
        }
      else
        %{state.metrics | __events_processed_total: state.metrics.__events_processed_total + 1}
      end

    # Store updated metrics
    :ets.insert(:__event_metrics, {:current_metrics, updated_metrics})

    new_state = %{state | metrics: updated_metrics}
    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast(term(), term()) :: term()
  def handle_cast({:process_generic, handler_id, event, measurements, metadata}, state) do
    Logger.debug("⚡ Processing generic __event from #{handler_id}: #{inspect(event)}")

    # Update general processing metrics
    updated_metrics = %{
      state.metrics
      | __events_processed_total: state.metrics.__events_processed_total + 1
    }

    # Store processing stats by handler
    :ets.insert(
      :processing_stats,
      {handler_id,
       %{
         last_event: event,
         last_processed: DateTime.utc_now(),
         measurements: measurements,
         metadata: metadata
       }}
    )

    # Store updated metrics
    :ets.insert(:__event_metrics, {:current_metrics, updated_metrics})

    new_state = %{state | metrics: updated_metrics}
    {:noreply, new_state}
  end

  # ========================================================================
  # QUERY HANDLERS
  # ========================================================================

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:get_safety_metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:get_violations, _from, state) do
    # Get violations from ETS
    violations = :ets.tab2list(:safety_violations)
    {:reply, violations, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:check_alarm_storm, _from, state) do
    alarm_storm_active = state.response_triggers.alarm_storm_active
    current_alarm_count = state.metrics.alarm_count
    threshold = state.thresholds.alarm_storm_threshold

    result = %{
      active: alarm_storm_active,
      current_count: current_alarm_count,
      threshold: threshold,
      exceeded: current_alarm_count > threshold
    }

    {:reply, result, state}
  end

  # ========================================================================
  # PRIVATE HELPER FUNCTIONS
  # ========================================================================

  @spec detect_tenant_violation(term()) :: term()
  defp detect_tenant_violation(metadata) do
    # TDG: Simple violation detection logic
    # In real implementation, this would check:
    # - Cross - tenant data access
    # - Tenant ID mismatches
    # - Unauthorized tenant operations

    requested_tenant = Map.get(metadata, :requested_tenant)
    user_tenant = Map.get(metadata, :user_tenant)

    # Violation if user tries to access different tenant data
    case {requested_tenant, user_tenant} do
      # No tenant specified
      {nil, _} -> false
      # No user tenant
      {_, nil} -> false
      # Same tenant, OK
      {same, same} -> false
      # Cross - tenant access - violation!
      {_different, _user} -> true
    end
  end

  @spec trigger_safety_response(term(), term()) :: term()
  defp trigger_safety_response(violation_type, violation_data) do
    Logger.error("🚨 TRIGGERING SAFETY RESPONSE for #{violation_type}")
    Logger.error("📋 Violation Details: #{inspect(violation_data)}")

    # TDG: Safety response implementation
    case violation_data.severity do
      :critical ->
        Logger.error("🔥 CRITICAL RESPONSE: Immediate intervention __required")

      # In real system: trigger pager, slack alerts, circuit breakers

      :high ->
        Logger.warning("⚠️ HIGH PRIORITY RESPONSE: Escalation __required")

      # In real system: trigger slack alerts, email notifications

      :medium ->
        Logger.info("📢 MEDIUM PRIORITY RESPONSE: Monitoring alert")

      # In real system: trigger monitoring alerts

      _ ->
        Logger.debug("📝 LOW PRIORITY: Logging for analysis")
    end

    # Store response trigger
    :ets.insert(
      :processing_stats,
      {:last_safety_response,
       %{
         type: violation_type,
         triggered_at: DateTime.utc_now(),
         severity: violation_data.severity
       }}
    )
  end
end
