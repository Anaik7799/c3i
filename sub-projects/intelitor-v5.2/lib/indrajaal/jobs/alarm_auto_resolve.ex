defmodule Indrajaal.Jobs.AlarmAutoResolve do
  @moduledoc """
  Oban job for auto - resolving alarms that meet specific criteria after a timeout period.
  """

  use Oban.Worker, queue: :alarms, max_attempts: 2

  require Logger

  @auto_resolve_timeout_minutes %{
    # 1 hour
    low: 60,
    # 2 hours
    medium: 120,
    # 4 hours
    high: 240,
    # Never auto - resolve
    critical: nil
  }

  @impl Oban.Worker
  @spec perform(any()) :: any()
  def perform(%Oban.Job{args: %{"alarm_id" => alarm_id}}) do
    alarm = %{id: alarm_id, state: :triggered, severity: :low, triggered_at: DateTime.utc_now()}

    case resolve_alarm(alarm) do
      {:ok, resolved_alarm} ->
        Logger.info("Auto - resolved alarm #{alarm_id}")
        {:ok, resolved_alarm}

      {:skip, _reason} ->
        Logger.debug("Alarm #{alarm_id} not eligible for auto - resolve")
        :ok

      error ->
        Logger.error("Failed to auto - resolve alarm #{alarm_id}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Schedule auto - resolution for an alarm if eligible.
  """
  @spec schedule_if_eligible(any()) :: any()
  def schedule_if_eligible(alarm) do
    if auto_resolvable?(alarm) do
      timeout_minutes = @auto_resolve_timeout_minutes[alarm.severity]

      if timeout_minutes do
        %{alarm_id: alarm.id}
        |> __MODULE__.new(scheduled_at: timeout_minutes * 60)
        |> Oban.insert()

        Logger.debug(
          "Scheduled auto - resolve for alarm #{alarm.id} in #{timeout_minutes} minutes"
        )
      end

      :ok
    end
  end

  @spec resolve_alarm(term()) :: {:ok, term()} | {:skip, String.t()} | {:error, term()}
  defp resolve_alarm(alarm) do
    case auto_resolvable?(alarm) do
      true ->
        Logger.info("Auto - resolving alarm #{alarm.id} after timeout")

        updated_alarm = %{alarm | state: :resolved, resolved_at: DateTime.utc_now()}

        record_auto_resolution(updated_alarm)
        notify_auto_resolution(updated_alarm)

        {:ok, updated_alarm}

      false ->
        {:skip, "not eligible for auto - resolution"}
    end
  end

  @spec auto_resolvable?(term()) :: boolean()
  defp auto_resolvable?(alarm) do
    alarm.state == :triggered &&
      alarm.severity in [:low, :medium, :high] &&
      !alarm._requires_manual_review &&
      alarm.auto_resolve_enabled
  end

  @spec record_auto_resolution(term()) :: term()
  defp record_auto_resolution(alarm) do
    _meta_data =
      Map.merge(alarm.meta_data || %{}, %{
        auto_resolved: true,
        auto_resolved_at: DateTime.utc_now(),
        auto_resolve_reason: "timeout_reached"
      })

    :telemetry.execute(
      [:indrajaal, :alarm, :auto_resolved],
      %{count: 1},
      %{
        alarm_id: alarm.id,
        severity: alarm.severity,
        __event_type: alarm.__event_type,
        elapsed_minutes: DateTime.diff(DateTime.utc_now(), alarm.triggered_at, :minute)
      }
    )

    :ok
  end

  @spec notify_auto_resolution(term()) :: term()
  defp notify_auto_resolution(alarm) do
    :telemetry.execute(
      [:indrajaal, :alarm, :auto_resolve_notification],
      %{count: 1},
      %{alarm_id: alarm.id, severity: alarm.severity}
    )

    Task.start(fn ->
      Indrajaal.Alarms.NotificationOrchestrator.notify_for_alarm(alarm)
    end)

    :ok
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic feedback
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
