defmodule Indrajaal.Jobs.AlarmCorrelation do
  @moduledoc """
  Oban job for finalizing alarm correlations after the correlation window closes.
  """

  use Oban.Worker, queue: :alarms, max_attempts: 2

  require Logger
  alias Indrajaal.Alarms
  alias Indrajaal.Alarms.CorrelationEngine

  @correlation_table :alarm_correlation_store

  @impl Oban.Worker
  @spec perform(any()) :: any()
  def perform(%Oban.Job{args: %{"alarm_id" => alarm_id}}) do
    alarm =
      case Alarms.Api.get_alarm_event(alarm_id) do
        {:ok, fetched} -> fetched
        {:error, _} -> %{id: alarm_id, tenant_id: nil, site_id: nil, zone_id: nil}
      end

    with {:ok, alarm} <- {:ok, alarm},
         {:ok, analysis} <- CorrelationEngine.finalize_correlations(alarm) do
      if significant_correlation?(analysis) do
        create_incident_from_correlations(alarm, analysis)
      else
        # Proceed with individual alarm processing
        process_individual_alarm(alarm)
      end
    else
      error ->
        Logger.error("Failed to process correlation for alarm #{alarm_id}: #{inspect(error)}")
        error
    end
  end

  @spec significant_correlation?(term()) :: term()
  defp significant_correlation?(analysis) do
    analysis.correlation_count >= 3 ||
      analysis.confidence_score > 0.7 ||
      analysis.recommended_action in [:immediate_dispatch, :priority_investigation]
  end

  @spec create_incident_from_correlations(term(), term()) :: term()
  defp create_incident_from_correlations(alarm, analysis) do
    Logger.info("Creating incident from #{analysis.correlation_count} correlated alarms")

    # Create a parent incident that groups the correlated alarms
    with {:ok, incident} <- create_incident(alarm, analysis),
         :ok <- link_correlated_alarms(incident, alarm, analysis) do
      # Trigger incident - level workflows
      trigger_incident_response(incident)

      {:ok, incident}
    else
      error ->
        Logger.error("Failed to create incident from correlations: #{inspect(error)}")
        error
    end
  end

  @spec create_incident(term(), term()) :: term()
  defp create_incident(alarm, analysis) do
    incident_attrs = %{
      event_code: "INCIDENT",
      event_type: :supervisory,
      severity: determine_incident_severity(alarm, analysis),
      priority: 9,
      site_id: Map.get(alarm, :site_id),
      zone_id: Map.get(alarm, :zone_id),
      description: "Security incident: #{analysis.correlation_count} correlated alarms",
      tenant_id: Map.get(alarm, :tenant_id),
      metadata: %{
        incident: true,
        correlation_analysis: analysis,
        source_alarm_id: alarm.id,
        correlation_types: Map.get(analysis, :correlation_types, [])
      }
    }

    result =
      case Map.get(alarm, :tenant_id) do
        nil ->
          {:ok,
           Map.merge(incident_attrs, %{
             id: Ecto.UUID.generate(),
             state: :triggered,
             created_at: DateTime.utc_now()
           })}

        tenant_id ->
          case Alarms.Api.create_alarm_event(incident_attrs, tenant: tenant_id) do
            {:ok, incident} ->
              {:ok, incident}

            {:error, _reason} ->
              {:ok,
               Map.merge(incident_attrs, %{
                 id: Ecto.UUID.generate(),
                 state: :triggered,
                 created_at: DateTime.utc_now()
               })}
          end
      end

    case result do
      {:ok, incident} ->
        ensure_correlation_table()
        :ets.insert(@correlation_table, {incident.id, :incident, incident})

        :telemetry.execute(
          [:indrajaal, :alarm, :incident_created],
          %{count: 1, correlated_count: analysis.correlation_count},
          %{incident_id: incident.id, severity: incident_attrs.severity}
        )

        {:ok, incident}

      error ->
        error
    end
  end

  @spec determine_incident_severity(term(), term()) :: term()
  defp determine_incident_severity(_alarm, analysis) do
    cond do
      analysis.recommended_action == :immediate_dispatch -> :critical
      analysis.confidence_score > 0.8 -> :high
      analysis.correlation_count > 5 -> :high
      true -> :medium
    end
  end

  defp link_correlated_alarms(incident, source_alarm, _analysis) do
    update_attrs = %{
      parent_event_id: incident.id,
      metadata:
        Map.merge(Map.get(source_alarm, :metadata) || %{}, %{
          incident_id: incident.id,
          correlation_finalized: true
        })
    }

    # Attempt Ash update; fall back to ETS record
    updated_alarm =
      case Alarms.Api.update_alarm_event(source_alarm, update_attrs) do
        {:ok, updated} ->
          updated

        {:error, _reason} ->
          Map.merge(source_alarm, update_attrs)
      end

    ensure_correlation_table()
    :ets.insert(@correlation_table, {source_alarm.id, :linked_alarm, updated_alarm})

    :telemetry.execute(
      [:indrajaal, :alarm, :linked_to_incident],
      %{count: 1},
      %{alarm_id: source_alarm.id, incident_id: incident.id}
    )

    :ok
  end

  @spec process_individual_alarm(term()) :: term()
  defp process_individual_alarm(alarm) do
    Logger.debug("Processing alarm #{alarm.id} as individual event")

    update_attrs = %{
      metadata:
        Map.merge(Map.get(alarm, :metadata) || %{}, %{
          correlation_checked: true,
          correlation_result: :no_significant_correlation
        })
    }

    result =
      case Alarms.Api.update_alarm_event(alarm, update_attrs) do
        {:ok, updated} ->
          {:ok, updated}

        {:error, _reason} ->
          {:ok, Map.merge(alarm, update_attrs)}
      end

    :telemetry.execute(
      [:indrajaal, :alarm, :correlation_checked],
      %{count: 1},
      %{alarm_id: alarm.id, result: :no_significant_correlation}
    )

    result
  end

  @spec trigger_incident_response(term()) :: term()
  defp trigger_incident_response(incident) do
    # Use enhanced workflows for incidents
    Task.start(fn ->
      Indrajaal.Alarms.trigger_for_alarm(incident)
    end)

    # Priority notifications for incidents
    Task.start(fn ->
      Indrajaal.Alarms.NotificationOrchestrator.notify_for_alarm(incident)
    end)

    :ok
  end

  @spec ensure_correlation_table() :: :ok
  defp ensure_correlation_table do
    case :ets.whereis(@correlation_table) do
      :undefined ->
        :ets.new(@correlation_table, [:named_table, :set, :public])
        :ok

      _tid ->
        :ok
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: # OK: General system coordination and management with cyberneti
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
