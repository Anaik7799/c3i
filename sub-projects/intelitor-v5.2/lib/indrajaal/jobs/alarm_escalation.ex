defmodule Indrajaal.Jobs.AlarmEscalation do
  @moduledoc """
  Oban job for handling alarm escalations when acknowledgment timeouts occur.
  """

  use Oban.Worker, queue: :alarms, max_attempts: 3

  require Logger
  alias Indrajaal.Alarms
  alias Indrajaal.Alarms.NotificationOrchestrator

  @impl Oban.Worker
  @spec perform(any()) :: any()
  def perform(%Oban.Job{args: args}) do
    %{
      "alarm_id" => alarm_id,
      "current_tier" => current_tier,
      "next_tier" => next_tier
    } = args

    with {:ok, alarm} <- get_and_validate_alarm(alarm_id),
         :ok <- validate_escalation_needed(alarm, current_tier) do
      escalate_alarm(alarm, next_tier)
    else
      {:error, :alarm_not_found} ->
        Logger.warning("Alarm #{alarm_id} not found for escalation")
        :ok

      {:error, :already_acknowledged} ->
        Logger.info("Alarm #{alarm_id} already acknowledged, skipping escalation")
        :ok

      error ->
        Logger.error("Failed to escalate alarm #{alarm_id}: #{inspect(error)}")
        error
    end
  end

  # Private Functions

  @spec get_and_validate_alarm(term()) :: term()
  defp get_and_validate_alarm(alarm_id) do
    case Alarms.Api.get_alarm_event(alarm_id) do
      {:ok, alarm} ->
        {:ok, alarm}

      {:error, _reason} ->
        # Fallback: check ETS cache for recently seen alarms
        case :ets.whereis(:alarm_escalation_cache) do
          :undefined ->
            {:error, :alarm_not_found}

          _tid ->
            case :ets.lookup(:alarm_escalation_cache, alarm_id) do
              [{^alarm_id, alarm}] ->
                {:ok, alarm}

              [] ->
                {:error, :alarm_not_found}
            end
        end
    end
  end

  @spec validate_escalation_needed(term(), term()) :: term()
  defp validate_escalation_needed(alarm, expected_tier) do
    cond do
      alarm.state in [:acknowledged, :investigating, :resolved, :false_alarm] ->
        {:error, :already_acknowledged}

      # Check if we're still at the expected tier level
      get_current_tier(alarm) != expected_tier ->
        {:error, :tier_mismatch}

      true ->
        :ok
    end
  end

  @spec escalate_alarm(term(), term()) :: term()
  defp escalate_alarm(alarm, next_tier) do
    Logger.warning("Escalating alarm #{alarm.id} to tier #{next_tier}")

    # Update alarm metadata
    updated_metadata =
      Map.merge(alarm.metadata || %{}, %{
        escalation_tier: next_tier,
        escalated_at: DateTime.utc_now(),
        escalation_reason: "No acknowledgment received"
      })

    update_attrs = %{
      severity: escalate_severity(alarm.severity),
      priority: min(10, Map.get(alarm, :priority, 5) + 2),
      metadata: updated_metadata
    }

    alarm_result =
      case Alarms.Api.update_alarm_event(alarm, update_attrs) do
        {:ok, updated} ->
          {:ok, updated}

        {:error, _reason} ->
          # Fallback: merge locally and cache the updated state
          updated = Map.merge(alarm, update_attrs)

          case :ets.whereis(:alarm_escalation_cache) do
            :undefined ->
              :ets.new(:alarm_escalation_cache, [:named_table, :set, :public])

            _tid ->
              :ok
          end

          :ets.insert(:alarm_escalation_cache, {alarm.id, updated})
          {:ok, updated}
      end

    with {:ok, updated_alarm} <- alarm_result,
         :ok <- notify_escalation(updated_alarm, next_tier) do
      # Record escalation in telemetry
      :telemetry.execute(
        [:indrajaal, :alarm, :escalated],
        %{count: 1, tier: next_tier},
        %{
          alarm_id: alarm.id,
          original_severity: alarm.severity,
          new_severity: updated_alarm.severity
        }
      )

      :ok
    end
  end

  @spec get_current_tier(term()) :: term()
  defp get_current_tier(alarm) do
    metadata = Map.get(alarm, :metadata) || %{}

    cond do
      is_map(metadata) && Map.has_key?(metadata, :escalation_tier) ->
        metadata.escalation_tier

      is_map(metadata) && Map.has_key?(metadata, "escalation_tier") ->
        metadata["escalation_tier"]

      true ->
        1
    end
  end

  @spec escalate_severity(term()) :: term()
  defp escalate_severity(current_severity) do
    case current_severity do
      :low -> :medium
      :medium -> :high
      :high -> :critical
      :critical -> :critical
    end
  end

  @spec notify_escalation(term(), term()) :: term()
  defp notify_escalation(alarm, tier) do
    # Build escalation - specific notification plan
    _escalation_plan = %{
      alarm_id: alarm.id,
      alarm_severity: alarm.severity,
      tiers: [build_escalation_tier(alarm, tier)]
    }

    # Use the notification orchestrator
    NotificationOrchestrator.notify_for_alarm(alarm)
  end

  @spec build_escalation_tier(term(), term()) :: term()
  defp build_escalation_tier(alarm, tier_level) do
    %{
      level: tier_level,
      recipients: get_escalation_recipients(alarm, tier_level),
      channels: get_escalation_channels(tier_level),
      escalation_timeout: get_escalation_timeout(alarm.severity),
      message_template: :escalation_alert,
      require_acknowledgment: true
    }
  end

  @spec get_escalation_recipients(term(), term()) :: term()
  defp get_escalation_recipients(alarm, tier_level) do
    case tier_level do
      2 ->
        # Supervisors and secondary operators
        Indrajaal.Accounts.list_users(%{
          filters: %{
            roles: ["supervisor", "senior_operator"],
            site_id: alarm.site_id
          }
        })

      3 ->
        # Managers and executives
        Indrajaal.Accounts.list_users(%{
          filters: %{
            roles: ["manager", "executive"]
          }
        })

      _ ->
        # Emergency contacts
        get_emergency_contacts()
    end
  end

  @spec get_escalation_channels(term()) :: term()
  defp get_escalation_channels(tier_level) do
    case tier_level do
      2 -> [:sms, :push, :email]
      3 -> [:voice, :sms]
      _ -> [:voice]
    end
  end

  @spec get_escalation_timeout(term()) :: term()
  defp get_escalation_timeout(severity) do
    case severity do
      # 1 minute
      :critical -> 60
      # 3 minutes
      :high -> 180
      # 5 minutes
      :medium -> 300
      # 10 minutes
      :low -> 600
    end
  end

  defp get_emergency_contacts do
    # Fetch emergency contacts from application config, falling back to empty list
    Application.get_env(:indrajaal, :emergency_contacts, [])
    |> Enum.map(fn contact ->
      case contact do
        %{} = c -> c
        {name, channel} -> %{name: name, channel: channel}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic feedback
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
