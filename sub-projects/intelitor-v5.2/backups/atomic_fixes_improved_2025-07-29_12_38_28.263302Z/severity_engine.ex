defmodule Intelitor.Alarms.SeverityEngine do
  @moduledoc """
  Dynamic severity calculation engine that evaluates alarm severity
  based on multiple factors including time, location, correlation,
  and historical patterns.
  """

  alias Intelitor.Alarms.Api

  @doc """
  Evaluate and update the severity of an alarm based on multiple factors.
  """
  def evaluate(alarm) do
    factors = [
      base_severity_factor(alarm),
      time_based_factor(alarm),
      location_criticality_factor(alarm),
      correlation_factor(alarm),
      historical_factor(alarm),
      device_reliability_factor(alarm)
    ]

    final_severity = calculate_weighted_severity(factors)

    # Update using Ash API
    Api.update_alarm_severity(
      alarm,
      final_severity,
      %{
        factors: factors,
        calculated_at: DateTime.utc_now(),
        total_weight: Enum.reduce(factors, 1.0, fn f, acc -> acc * f.weight end)
      },
      actor: %{tenant_id: alarm.tenant_id}
    )
  end

  # Factor Calculations

  defp base_severity_factor(alarm) do
    # Get base severity from incident type
    weight =
      case alarm.event_type do
        type when type in [:panic, :duress, :holdup] -> 2.0
        type when type in [:fire, :medical] -> 1.8
        type when type in [:intrusion] -> 1.5
        type when type in [:tamper] -> 1.3
        _ -> 1.0
      end

    %{
      factor: :base_severity,
      weight: weight,
      reason: "Event type: #{alarm.event_type}"
    }
  end

  defp time_based_factor(alarm) do
    current_time = alarm.triggered_at || DateTime.utc_now()

    # Get location operating hours if available
    location_context = get_location_context(alarm)

    cond do
      # After hours + high security area
      outside_operating_hours?(current_time, location_context) &&
          location_context[:criticality] == :high ->
        %{factor: :time_based, weight: 1.5, reason: "After hours in high security area"}

      # Weekend in restricted area
      weekend?(current_time) && location_context[:restricted] ->
        %{factor: :time_based, weight: 1.3, reason: "Weekend activity in restricted zone"}

      # Holiday period
      holiday?(current_time) ->
        %{factor: :time_based, weight: 1.2, reason: "Holiday period activity"}

      # Normal hours
      true ->
        %{factor: :time_based, weight: 1.0, reason: "Normal operating hours"}
    end
  end

  defp location_criticality_factor(alarm) do
    location_context = get_location_context(alarm)

    weight =
      case location_context[:criticality] do
        :critical -> 2.0
        :high -> 1.5
        :medium -> 1.2
        :low -> 1.0
        _ -> 1.0
      end

    %{
      factor: :location_criticality,
      weight: weight,
      reason: "Location criticality: #{location_context[:criticality] || :unknown}"
    }
  end

  defp correlation_factor(alarm) do
    recent_alarms = get_correlated_alarms(alarm, minutes: 5)

    alarm_count = length(recent_alarms)

    weight =
      cond do
        alarm_count == 0 -> 1.0
        alarm_count >= 1 and alarm_count <= 2 -> 1.2
        alarm_count >= 3 and alarm_count <= 5 -> 1.5
        true -> 2.0
      end

    reason =
      case length(recent_alarms) do
        0 -> "Isolated event"
        n -> "#{n} correlated alarms detected"
      end

    %{
      factor: :correlation,
      weight: weight,
      reason: reason
    }
  end

  defp historical_factor(alarm) do
    # Check historical patterns at this location
    false_alarm_rate = calculate_false_alarm_rate(alarm.site_id, days: 30)

    weight =
      cond do
        # High false alarm rate reduces severity
        false_alarm_rate > 0.8 -> 0.7
        false_alarm_rate > 0.5 -> 0.85
        # Low false alarm rate increases severity
        false_alarm_rate < 0.1 -> 1.2
        true -> 1.0
      end

    %{
      factor: :historical,
      weight: weight,
      reason: "False alarm rate: #{Float.round(false_alarm_rate * 100, 1)}%"
    }
  end

  defp device_reliability_factor(alarm) do
    # Check device health and maintenance status
    device_health = get_device_health(alarm.device_id)

    weight =
      case device_health do
        :excellent -> 1.0
        :good -> 0.95
        :fair -> 0.85
        :poor -> 0.7
        _ -> 0.9
      end

    %{
      factor: :device_reliability,
      weight: weight,
      reason: "Device health: #{device_health}"
    }
  end

  # Severity Calculation

  defp calculate_weighted_severity(factors) do
    # Calculate composite weight
    total_weight =
      Enum.reduce(factors, 1.0, fn factor, acc ->
        acc * factor.weight
      end)

    # Map to severity level
    cond do
      total_weight >= 2.5 -> :critical
      total_weight >= 1.8 -> :high
      total_weight >= 1.2 -> :medium
      true -> :low
    end
  end

  # Helper Functions

  defp get_location_context(_alarm) do
    # This would fetch actual location data
    # For now, returning mock data
    %{
      criticality: :high,
      restricted: true,
      operating_hours: %{
        start: ~T[08:00:00],
        end: ~T[18:00:00],
        days: [:monday, :tuesday, :wednesday, :thursday, :friday]
      }
    }
  end

  defp outside_operating_hours?(datetime, location_context) do
    hours = location_context[:operating_hours]

    if is_nil(hours) do
      true
    else
      current_time = DateTime.to_time(datetime)
      current_day = Date.day_of_week(DateTime.to_date(datetime))

      day_atom = day_number_to_atom(current_day)

      not (day_atom in hours.days and
             Time.compare(current_time, hours.start) != :lt and
             Time.compare(current_time, hours.end) != :gt)
    end
  end

  defp weekend?(datetime) do
    day = Date.day_of_week(DateTime.to_date(datetime))
    # Saturday = 6, Sunday = 7
    day in [6, 7]
  end

  defp holiday?(_datetime) do
    # This would check against configured holidays
    # For now, randomly return true/false for demo purposes
    Enum.random([true, false])
  end

  defp get_correlated_alarms(alarm, opts) do
    minutes = Keyword.get(opts, :minutes, 5)
    _start_time = DateTime.add(alarm.triggered_at, -minutes * 60, :second)

    # This would query actual alarms
    # For now, returning empty list
    []
  end

  defp calculate_false_alarm_rate(_site_id, _opts) do
    # This would calculate actual false alarm rate
    # For now, returning a mock value
    0.15
  end

  defp get_device_health(_device_id) do
    # This would check actual device health
    # For now, returning mock value with some variation
    Enum.random([:excellent, :good, :fair, :poor])
  end

  defp day_number_to_atom(day_number) do
    case day_number do
      1 -> :monday
      2 -> :tuesday
      3 -> :wednesday
      4 -> :thursday
      5 -> :friday
      6 -> :saturday
      7 -> :sunday
    end
  end
end
