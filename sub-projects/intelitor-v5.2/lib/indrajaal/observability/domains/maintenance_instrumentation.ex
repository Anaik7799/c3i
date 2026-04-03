defmodule Indrajaal.Observability.Domains.MaintenanceInstrumentation do
  @moduledoc """
  require Logger
  Instrumentation for the Maintenance domain.

  Provides comprehensive telemetry,
    metrics, and tracing for work order management,
  asset tracking, pr_eventive maintenance scheduling, and maintenance analytics.
  """

  use Indrajaal.Observability.InstrumentationBase,
    domain: :maintenance

  # EP-012: Aliases not explicitly used but available through InstrumentationBase

  # Telemetry __event prefixes
  @work_order_prefix [:indrajaal, :maintenance, :work_order]
  @asset_prefix [:indrajaal, :maintenance, :asset]
  @schedule_prefix [:indrajaal, :maintenance, :schedule]
  @inventory_prefix [:indrajaal, :maintenance, :inventory]

  @doc """
  Attaches all maintenance telemetry handlers.
  """
  def setup do
    attach_work_order_handlers()
    attach_asset_handlers()
    attach_schedule_handlers()
    attach_inventory_handlers()
    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :maintenance, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :maintenance}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :maintenance, :metric],
      %{value: value},
      %{name: name}
    )

    :ok
  end

  def configure(_opts) do
    :ok
  end

  def get_configuration do
    {:ok,
     [
       domain: :maintenance,
       work_order_event_prefix: @work_order_prefix,
       asset_event_prefix: @asset_prefix,
       schedule_event_prefix: @schedule_prefix,
       inventory_event_prefix: @inventory_prefix
     ]}
  end

  def shutdown do
    :ok
  end

  # Work Order Management Handlers
  defp attach_work_order_handlers do
    events = [
      @work_order_prefix ++ [:created],
      @work_order_prefix ++ [:assigned],
      @work_order_prefix ++ [:started],
      @work_order_prefix ++ [:completed],
      @work_order_prefix ++ [:cancelled],
      @work_order_prefix ++ [:escalated],
      @work_order_prefix ++ [:sla, :breached]
    ]

    :telemetry.attach_many(
      "maintenance - work - order - handlers",
      events,
      &handle_work_order_event/4,
      nil
    )
  end

  # Asset Management Handlers
  defp attach_asset_handlers do
    events = [
      @asset_prefix ++ [:status, :changed],
      @asset_prefix ++ [:health, :updated],
      @asset_prefix ++ [:failure, :predicted],
      @asset_prefix ++ [:maintenance, :performed],
      @asset_prefix ++ [:warranty, :expiring],
      @asset_prefix ++ [:lifecycle, :event]
    ]

    :telemetry.attach_many(
      "maintenance - asset - handlers",
      events,
      &handle_asset_event/4,
      nil
    )
  end

  # Pr_eventive Maintenance Schedule Handlers
  defp attach_schedule_handlers do
    events = [
      @schedule_prefix ++ [:task, :due],
      @schedule_prefix ++ [:task, :completed],
      @schedule_prefix ++ [:task, :overdue],
      @schedule_prefix ++ [:plan, :generated],
      @schedule_prefix ++ [:optimization, :performed]
    ]

    :telemetry.attach_many(
      "maintenance - schedule - handlers",
      events,
      &handle_schedule_event/4,
      nil
    )
  end

  # Inventory Management Handlers
  defp attach_inventory_handlers do
    events = [
      @inventory_prefix ++ [:stock, :low],
      @inventory_prefix ++ [:stock, :replenished],
      @inventory_prefix ++ [:part, :used],
      @inventory_prefix ++ [:order, :placed],
      @inventory_prefix ++ [:cost, :tracked]
    ]

    :telemetry.attach_many(
      "maintenance - inventory - handlers",
      events,
      &handle_inventory_event/4,
      nil
    )
  end

  # Event Handlers
  defp handle_work_order_event(event, measurements, metadata, __config) do
    case event do
      [@work_order_prefix | [:created]] ->
        Logger.info("Work order created",
          work_order_id: metadata[:work_order_id],
          priority: metadata[:priority],
          type: metadata[:type],
          asset_id: metadata[:asset_id],
          trace_id: metadata[:trace_id]
        )

        Telemetry.create_span(
          "maintenance.work_order",
          metadata[:trace_id],
          %{
            "work_order.id" => metadata[:work_order_id],
            "work_order.type" => metadata[:type],
            "work_order.priority" => metadata[:priority],
            "work_order.asset_id" => metadata[:asset_id],
            "work_order.estimated_hours" => metadata[:estimated_hours]
          }
        )

        Telemetry.record_metric(
          "maintenance.work_orders.created",
          1,
          :counter,
          %{
            type: metadata[:type],
            priority: metadata[:priority]
          }
        )

      [@work_order_prefix | [:completed]] ->
        duration_hours = measurements[:duration_hours]

        Logger.info("Work order completed",
          work_order_id: metadata[:work_order_id],
          duration_hours: duration_hours,
          technician_id: metadata[:technician_id]
        )

        Telemetry.record_metric(
          "maintenance.work_order.duration",
          duration_hours,
          :histogram,
          %{
            type: metadata[:type],
            priority: metadata[:priority]
          }
        )

        Telemetry.record_metric(
          "maintenance.work_order.completion_rate",
          100,
          :gauge,
          %{technician_id: metadata[:technician_id]}
        )

      [@work_order_prefix | [:sla, :breached]] ->
        Logger.warning("Work order SLA breached",
          work_order_id: metadata[:work_order_id],
          sla_type: metadata[:sla_type],
          breach_duration_hours: measurements[:breach_hours]
        )

        Telemetry.record_metric(
          "maintenance.sla.breaches",
          1,
          :counter,
          %{
            sla_type: metadata[:sla_type],
            priority: metadata[:priority]
          }
        )

      [@work_order_prefix | [:escalated]] ->
        Telemetry.record_metric(
          "maintenance.work_order.escalations",
          1,
          :counter,
          %{
            escalation_level: metadata[:escalation_level],
            reason: metadata[:reason]
          }
        )

      _ ->
        :ok
    end
  end

  defp handle_asset_event(event, measurements, metadata, __config) do
    case event do
      [@asset_prefix | [:status, :changed]] ->
        Logger.info("Asset status changed",
          asset_id: metadata[:asset_id],
          from_status: metadata[:from_status],
          to_status: metadata[:to_status]
        )

        Telemetry.record_metric(
          "maintenance.asset.status_changes",
          1,
          :counter,
          %{
            from_status: metadata[:from_status],
            to_status: metadata[:to_status],
            asset_type: metadata[:asset_type]
          }
        )

      [@asset_prefix | [:health, :updated]] ->
        health_score = measurements[:health_score]

        Telemetry.record_metric(
          "maintenance.asset.health_score",
          health_score,
          :gauge,
          %{
            asset_id: metadata[:asset_id],
            asset_type: metadata[:asset_type]
          }
        )

        if health_score < 50 do
          Logger.warning("Asset health degraded",
            asset_id: metadata[:asset_id],
            health_score: health_score
          )
        end

      [@asset_prefix | [:failure, :predicted]] ->
        Logger.warning("Asset failure predicted",
          asset_id: metadata[:asset_id],
          failure_probability: measurements[:probability],
          predicted_days: metadata[:days_until_failure]
        )

        Telemetry.record_metric(
          "maintenance.asset.failure_predictions",
          1,
          :counter,
          %{
            asset_type: metadata[:asset_type],
            failure_mode: metadata[:failure_mode]
          }
        )

      [@asset_prefix | [:maintenance, :performed]] ->
        Telemetry.record_metric(
          "maintenance.asset.maintenance_cost",
          measurements[:cost],
          :counter,
          %{
            asset_type: metadata[:asset_type],
            maintenance_type: metadata[:maintenance_type]
          }
        )

        Telemetry.record_metric(
          "maintenance.asset.downtime_hours",
          measurements[:downtime_hours],
          :counter,
          %{asset_id: metadata[:asset_id]}
        )

      _ ->
        :ok
    end
  end

  defp handle_schedule_event(event, measurements, metadata, __config) do
    case event do
      [@schedule_prefix | [:task, :due]] ->
        Telemetry.record_metric(
          "maintenance.schedule.tasks_due",
          1,
          :counter,
          %{
            task_type: metadata[:task_type],
            asset_type: metadata[:asset_type]
          }
        )

      [@schedule_prefix | [:task, :overdue]] ->
        Logger.warning("Maintenance task overdue",
          task_id: metadata[:task_id],
          asset_id: metadata[:asset_id],
          overdue_days: measurements[:overdue_days]
        )

        Telemetry.record_metric(
          "maintenance.schedule.overdue_tasks",
          1,
          :gauge,
          %{
            task_type: metadata[:task_type],
            overdue_days: measurements[:overdue_days]
          }
        )

      [@schedule_prefix | [:plan, :generated]] ->
        Telemetry.record_metric(
          "maintenance.schedule.plans_generated",
          1,
          :counter,
          %{
            plan_type: metadata[:plan_type],
            duration_days: metadata[:duration_days]
          }
        )

      [@schedule_prefix | [:optimization, :performed]] ->
        savings_percent = measurements[:cost_savings_percent]

        Logger.info("Maintenance schedule optimized",
          optimization_type: metadata[:optimization_type],
          cost_savings_percent: savings_percent,
          efficiency_gain: measurements[:efficiency_gain]
        )

        Telemetry.record_metric(
          "maintenance.optimization.savings",
          savings_percent,
          :gauge,
          %{optimization_type: metadata[:optimization_type]}
        )

      _ ->
        :ok
    end
  end

  defp handle_inventory_event(event, measurements, metadata, __config) do
    case event do
      [@inventory_prefix | [:stock, :low]] ->
        Logger.warning("Inventory stock low",
          part_id: metadata[:part_id],
          current_quantity: measurements[:current_quantity],
          reorder_point: metadata[:reorder_point]
        )

        Telemetry.record_metric(
          "maintenance.inventory.low_stock_alerts",
          1,
          :counter,
          %{
            part_category: metadata[:part_category],
            criticality: metadata[:criticality]
          }
        )

      [@inventory_prefix | [:part, :used]] ->
        Telemetry.record_metric(
          "maintenance.inventory.parts_used",
          measurements[:quantity],
          :counter,
          %{
            part_id: metadata[:part_id],
            work_order_id: metadata[:work_order_id]
          }
        )

        Telemetry.record_metric(
          "maintenance.inventory.part_cost",
          measurements[:cost],
          :counter,
          %{part_category: metadata[:part_category]}
        )

      [@inventory_prefix | [:order, :placed]] ->
        Telemetry.record_metric(
          "maintenance.inventory.orders_placed",
          1,
          :counter,
          %{
            supplier_id: metadata[:supplier_id],
            order_type: metadata[:order_type]
          }
        )

        Telemetry.record_metric(
          "maintenance.inventory.order_value",
          measurements[:total_value],
          :counter,
          %{supplier_id: metadata[:supplier_id]}
        )

      _ ->
        :ok
    end
  end

  @doc """
  Records work order lifecycle __events.
  """
  def recordwork_order(task_id, event_type, measurements, metadata \\ %{}) do
    :telemetry.execute(
      @work_order_prefix ++ [event_type],
      measurements,
      Map.merge(metadata, %{task_id: task_id})
    )
  end

  @doc """
  Records inventory usage and stock levels.
  """
  @spec record_inventory_usage(term(), term(), term(), term()) :: term()
  def record_inventory_usage(part_id, quantity, cost, work_order_id) do
    :telemetry.execute(
      @inventory_prefix ++ [:part, :used],
      %{
        quantity: quantity,
        cost: cost
      },
      %{
        part_id: part_id,
        work_order_id: work_order_id
      }
    )
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
