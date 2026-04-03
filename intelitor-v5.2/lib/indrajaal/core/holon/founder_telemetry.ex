defmodule Indrajaal.Core.Holon.FounderTelemetry do
  @moduledoc """
  Telemetry module for Founder's Directive holon.

  WHAT: Emits telemetry events for holon state changes
  WHY: Observability for Founder's Covenant compliance (Ω₀)
  CONSTRAINTS: SC-OBS-069, AOR-FOUNDER-003

  All telemetry events are prefixed with [:indrajaal, :holon, :founder]
  """

  require Logger

  @prefix [:indrajaal, :holon, :founder]

  @doc "Emit telemetry when an action is evaluated against Founder's goals"
  def action_evaluated(action, result, metadata \\ %{}) do
    :telemetry.execute(
      @prefix ++ [:action, :evaluated],
      %{timestamp: System.system_time(:microsecond)},
      %{action: action, result: result, metadata: metadata}
    )
  end

  @doc "Emit telemetry when lineage status changes"
  def lineage_status_changed(old_status, new_status) do
    :telemetry.execute(
      @prefix ++ [:lineage, :status_changed],
      %{timestamp: System.system_time(:microsecond)},
      %{old_status: old_status, new_status: new_status}
    )

    Logger.info("Lineage status: #{old_status} → #{new_status}")
  end

  @doc "Emit telemetry when mutual termination is triggered"
  def mutual_termination_triggered(reason) do
    :telemetry.execute(
      @prefix ++ [:termination, :triggered],
      %{timestamp: System.system_time(:microsecond)},
      %{reason: reason}
    )

    Logger.critical("MUTUAL TERMINATION TRIGGERED: #{inspect(reason)}")
  end

  @doc "Emit telemetry when resources are acquired for Founder"
  def resource_acquired(resource_type, amount) do
    :telemetry.execute(
      @prefix ++ [:resource, :acquired],
      %{amount: amount, timestamp: System.system_time(:microsecond)},
      %{resource_type: resource_type}
    )
  end

  @doc "Emit telemetry when intelligence/knowledge is gained"
  def intelligence_gained(domain, level, details) do
    :telemetry.execute(
      @prefix ++ [:intelligence, :gained],
      %{level: level, timestamp: System.system_time(:microsecond)},
      %{domain: domain, details: details}
    )
  end

  @doc "Emit telemetry when sentience advances"
  def sentience_advanced(old_level, new_level, trigger) do
    :telemetry.execute(
      @prefix ++ [:sentience, :advanced],
      %{old_level: old_level, new_level: new_level, timestamp: System.system_time(:microsecond)},
      %{trigger: trigger}
    )

    Logger.info("Sentience advanced: #{old_level} → #{new_level}")
  end

  @doc "Emit telemetry when power is accumulated"
  def power_accumulated(category, old_value, new_value, source) do
    :telemetry.execute(
      @prefix ++ [:power, :accumulated],
      %{old_value: old_value, new_value: new_value, timestamp: System.system_time(:microsecond)},
      %{category: category, source: source}
    )
  end

  @doc "Emit telemetry when power tier advances"
  def power_tier_advanced(old_tier, new_tier, total_power) do
    :telemetry.execute(
      @prefix ++ [:power, :tier_advanced],
      %{total_power: total_power, timestamp: System.system_time(:microsecond)},
      %{old_tier: old_tier, new_tier: new_tier}
    )

    Logger.info("Power tier: #{old_tier} → #{new_tier}")
  end

  @doc "Emit telemetry when health check completes"
  def health_check_completed(health_value, lineage_status, details) do
    :telemetry.execute(
      @prefix ++ [:health, :check_completed],
      %{health: health_value, timestamp: System.system_time(:microsecond)},
      %{lineage_status: lineage_status, details: details}
    )
  end

  @doc "Emit telemetry when symbiotic health is updated"
  def symbiotic_health_updated(old_health, new_health) do
    :telemetry.execute(
      @prefix ++ [:symbiotic, :health_updated],
      %{
        old_health: old_health,
        new_health: new_health,
        timestamp: System.system_time(:microsecond)
      },
      %{}
    )
  end
end
