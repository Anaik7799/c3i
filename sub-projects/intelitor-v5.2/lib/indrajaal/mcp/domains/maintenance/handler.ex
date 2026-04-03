defmodule Indrajaal.MCP.Domains.Maintenance.Handler do
  @moduledoc """
  MCP Handler for Maintenance Domain.

  WHAT: Provides 12 tools for work order management, preventive maintenance scheduling,
        technician assignment, asset service tracking, and maintenance KPI reporting —
        wired to simulated asset and work order data with realistic priorities and SLA targets.
  WHY: Enables AI assistants to manage facility maintenance operations including work order
       lifecycle, preventive maintenance schedules, technician dispatch, and asset health
       monitoring — with audit trails and Guardian approval for write operations.
  CONSTRAINTS: SC-MCP-070, SC-MCP-071, SC-MCP-072

  ## Tools Provided
  - indrajaal.maintenance.work_orders.list      - List work orders with filtering
  - indrajaal.maintenance.work_orders.get       - Get detailed work order information
  - indrajaal.maintenance.work_orders.create    - Create a new work order (Guardian required)
  - indrajaal.maintenance.work_orders.update    - Update work order status (Guardian required)
  - indrajaal.maintenance.work_orders.close     - Close/complete a work order (Guardian required)
  - indrajaal.maintenance.schedule.list         - List scheduled maintenance tasks
  - indrajaal.maintenance.schedule.plan         - Plan upcoming maintenance window
  - indrajaal.maintenance.technicians.list      - List available technicians and assignments
  - indrajaal.maintenance.assets.list           - List assets with service status
  - indrajaal.maintenance.assets.history        - Get asset maintenance history
  - indrajaal.maintenance.metrics               - Get maintenance KPI metrics
  - indrajaal.maintenance.alerts                - Get overdue/critical maintenance alerts

  ## STAMP Constraints
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-MCP-071: All tools MUST have valid schemas
  - SC-MCP-072: audit_log MUST be called on every handle clause

  ## Change History
  | Version | Date       | Author            | Change                                        |
  |---------|------------|-------------------|-----------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude Sonnet 4.6 | Rewrite to atom-dispatch, realistic simulated |
  |         |            |                   | data, audit_log, generated_at, ETS state      |
  | 21.2.0  | 2026-03-01 | Claude Sonnet 4.6 | Initial string-dispatch stubs                 |
  """

  use Indrajaal.MCP.Domains.Handler, domain: :maintenance

  alias Indrajaal.MCP.Foundation.Types

  require Logger

  # ETS table for session-scoped work order state
  @wo_table :mcp_maintenance_wo

  @impl true
  def list_tools do
    [
      Types.new_tool_schema(
        "indrajaal.maintenance.work_orders.list",
        "List work orders with optional filtering by status, priority, asset, or technician.",
        %{
          "type" => "object",
          "properties" => %{
            "status" => %{
              "type" => "string",
              "enum" => ["open", "in_progress", "pending_parts", "completed", "cancelled", "all"],
              "description" => "Filter by work order status (default: open)"
            },
            "priority" => %{
              "type" => "string",
              "enum" => ["critical", "high", "medium", "low"],
              "description" => "Filter by priority level"
            },
            "asset_id" => %{
              "type" => "string",
              "description" => "Filter by asset identifier"
            },
            "technician_id" => %{
              "type" => "string",
              "description" => "Filter by assigned technician"
            },
            "limit" => %{
              "type" => "integer",
              "minimum" => 1,
              "maximum" => 100,
              "description" => "Maximum results to return (default: 20)"
            }
          }
        }
      ),
      Types.new_tool_schema(
        "indrajaal.maintenance.work_orders.get",
        "Get full details of a specific work order including history, parts, and notes.",
        %{
          "type" => "object",
          "properties" => %{
            "work_order_id" => %{
              "type" => "string",
              "description" => "Work order identifier"
            }
          },
          "required" => ["work_order_id"]
        }
      ),
      Types.new_tool_schema(
        "indrajaal.maintenance.work_orders.create",
        "Create a new work order for asset repair or maintenance. Guardian approval required.",
        %{
          "type" => "object",
          "properties" => %{
            "asset_id" => %{
              "type" => "string",
              "description" => "Asset requiring maintenance"
            },
            "title" => %{
              "type" => "string",
              "description" => "Brief description of the issue"
            },
            "description" => %{
              "type" => "string",
              "description" => "Detailed description of work required"
            },
            "priority" => %{
              "type" => "string",
              "enum" => ["critical", "high", "medium", "low"],
              "description" => "Work order priority"
            },
            "work_type" => %{
              "type" => "string",
              "enum" => ["corrective", "preventive", "inspection", "emergency"],
              "description" => "Type of maintenance work"
            },
            "requested_by" => %{
              "type" => "string",
              "description" => "Requestor name or ID"
            },
            "due_date" => %{
              "type" => "string",
              "description" => "ISO 8601 due date (optional)"
            }
          },
          "required" => ["asset_id", "title", "priority"]
        },
        requires_guardian: true
      ),
      Types.new_tool_schema(
        "indrajaal.maintenance.work_orders.update",
        "Update status, notes, or assignment of an existing work order. Guardian approval required.",
        %{
          "type" => "object",
          "properties" => %{
            "work_order_id" => %{
              "type" => "string",
              "description" => "Work order to update"
            },
            "status" => %{
              "type" => "string",
              "enum" => ["open", "in_progress", "pending_parts", "completed", "cancelled"],
              "description" => "New status"
            },
            "technician_id" => %{
              "type" => "string",
              "description" => "Assign to technician"
            },
            "notes" => %{
              "type" => "string",
              "description" => "Progress notes or comments"
            },
            "parts_required" => %{
              "type" => "array",
              "items" => %{"type" => "string"},
              "description" => "List of parts required"
            }
          },
          "required" => ["work_order_id"]
        },
        requires_guardian: true
      ),
      Types.new_tool_schema(
        "indrajaal.maintenance.work_orders.close",
        "Close or complete a work order with resolution details. Guardian approval required.",
        %{
          "type" => "object",
          "properties" => %{
            "work_order_id" => %{
              "type" => "string",
              "description" => "Work order to close"
            },
            "resolution" => %{
              "type" => "string",
              "description" => "Description of work performed and resolution"
            },
            "outcome" => %{
              "type" => "string",
              "enum" => ["resolved", "partially_resolved", "deferred", "no_fault_found"],
              "description" => "Closure outcome"
            },
            "labour_hours" => %{
              "type" => "number",
              "description" => "Actual labour hours spent"
            },
            "parts_used" => %{
              "type" => "array",
              "items" => %{"type" => "string"},
              "description" => "Parts actually consumed"
            }
          },
          "required" => ["work_order_id", "resolution", "outcome"]
        },
        requires_guardian: true
      ),
      Types.new_tool_schema(
        "indrajaal.maintenance.schedule.list",
        "List upcoming scheduled preventive maintenance tasks sorted by due date.",
        %{
          "type" => "object",
          "properties" => %{
            "horizon_days" => %{
              "type" => "integer",
              "minimum" => 1,
              "maximum" => 365,
              "description" => "Look-ahead window in days (default: 30)"
            },
            "asset_type" => %{
              "type" => "string",
              "description" => "Filter by asset type (e.g. hvac, fire_panel, elevator)"
            },
            "overdue_only" => %{
              "type" => "boolean",
              "description" => "Return only overdue tasks (default: false)"
            }
          }
        }
      ),
      Types.new_tool_schema(
        "indrajaal.maintenance.schedule.plan",
        "Generate an optimised maintenance window plan for a given time range, respecting technician availability and asset dependencies.",
        %{
          "type" => "object",
          "properties" => %{
            "start_date" => %{
              "type" => "string",
              "description" => "ISO 8601 start date for the planning window"
            },
            "end_date" => %{
              "type" => "string",
              "description" => "ISO 8601 end date for the planning window"
            },
            "technician_ids" => %{
              "type" => "array",
              "items" => %{"type" => "string"},
              "description" => "Technicians to consider (default: all available)"
            },
            "priority_threshold" => %{
              "type" => "string",
              "enum" => ["critical", "high", "medium", "low"],
              "description" => "Minimum priority to include (default: medium)"
            }
          }
        }
      ),
      Types.new_tool_schema(
        "indrajaal.maintenance.technicians.list",
        "List maintenance technicians with current assignments, availability, and skill sets.",
        %{
          "type" => "object",
          "properties" => %{
            "available_only" => %{
              "type" => "boolean",
              "description" => "Return only available technicians (default: false)"
            },
            "skill" => %{
              "type" => "string",
              "description" => "Filter by required skill (e.g. electrical, hvac, plumbing)"
            }
          }
        }
      ),
      Types.new_tool_schema(
        "indrajaal.maintenance.assets.list",
        "List monitored assets with current service status, health score, and next service date.",
        %{
          "type" => "object",
          "properties" => %{
            "asset_type" => %{
              "type" => "string",
              "description" => "Filter by asset type"
            },
            "location" => %{
              "type" => "string",
              "description" => "Filter by location or zone"
            },
            "health_threshold" => %{
              "type" => "integer",
              "minimum" => 0,
              "maximum" => 100,
              "description" => "Return assets with health score below this value"
            }
          }
        }
      ),
      Types.new_tool_schema(
        "indrajaal.maintenance.assets.history",
        "Get full maintenance history for a specific asset.",
        %{
          "type" => "object",
          "properties" => %{
            "asset_id" => %{
              "type" => "string",
              "description" => "Asset identifier"
            },
            "limit" => %{
              "type" => "integer",
              "minimum" => 1,
              "maximum" => 200,
              "description" => "Number of historical records (default: 50)"
            }
          },
          "required" => ["asset_id"]
        }
      ),
      Types.new_tool_schema(
        "indrajaal.maintenance.metrics",
        "Get maintenance KPI metrics including MTTR, MTBF, completion rates, and backlog.",
        %{
          "type" => "object",
          "properties" => %{
            "period" => %{
              "type" => "string",
              "enum" => ["today", "week", "month", "quarter", "year"],
              "description" => "Reporting period (default: month)"
            }
          }
        }
      ),
      Types.new_tool_schema(
        "indrajaal.maintenance.alerts",
        "Get overdue, escalated, or critical maintenance alerts requiring immediate attention.",
        %{
          "type" => "object",
          "properties" => %{
            "severity" => %{
              "type" => "string",
              "enum" => ["critical", "high", "any"],
              "description" => "Minimum alert severity (default: any)"
            }
          }
        }
      )
    ]
  end

  # ---------------------------------------------------------------------------
  # handle/3 — atom-dispatch clauses (SC-MCP-072: audit_log on every clause)
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:work_orders_list, args, context) do
    audit_log(@domain, :work_orders_list, args, context)

    status_filter = Map.get(args, "status", "open")
    priority_filter = Map.get(args, "priority")
    asset_id_filter = Map.get(args, "asset_id")
    technician_filter = Map.get(args, "technician_id")
    limit = Map.get(args, "limit", 20)

    work_orders =
      simulated_work_orders()
      |> maybe_filter_wo_status(status_filter)
      |> maybe_filter_wo_priority(priority_filter)
      |> maybe_filter_wo_asset(asset_id_filter)
      |> maybe_filter_wo_technician(technician_filter)
      |> Enum.take(limit)

    success(%{
      work_orders: work_orders,
      total: length(work_orders),
      filters: %{status: status_filter, priority: priority_filter},
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      data_source: "simulated"
    })
  end

  @impl true
  def handle(:work_orders_get, args, context) do
    audit_log(@domain, :work_orders_get, args, context)

    with {:ok, _} <- validate_required(args, ["work_order_id"]) do
      wo_id = Map.get(args, "work_order_id")

      case find_work_order(wo_id) do
        nil ->
          error(%{
            code: "NOT_FOUND",
            message: "Work order #{wo_id} not found",
            generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
          })

        wo ->
          success(%{
            work_order:
              Map.merge(wo, %{
                "history" => simulated_wo_history(wo_id),
                "parts_log" => [],
                "photos" => []
              }),
            generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
            data_source: "simulated"
          })
      end
    end
  end

  @impl true
  def handle(:work_orders_create, args, context) do
    audit_log(@domain, :work_orders_create, args, context)

    with {:ok, _} <- validate_required(args, ["asset_id", "title", "priority"]) do
      ensure_ets_table(@wo_table)

      new_wo = %{
        "id" => generate_id(),
        "asset_id" => Map.get(args, "asset_id"),
        "title" => Map.get(args, "title"),
        "description" => Map.get(args, "description", ""),
        "priority" => Map.get(args, "priority"),
        "work_type" => Map.get(args, "work_type", "corrective"),
        "status" => "open",
        "requested_by" => Map.get(args, "requested_by", "system"),
        "due_date" => Map.get(args, "due_date"),
        "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "updated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "technician_id" => nil,
        "estimated_hours" => priority_to_estimated_hours(Map.get(args, "priority", "medium"))
      }

      :ets.insert(@wo_table, {new_wo["id"], new_wo})

      success(%{
        work_order: new_wo,
        message: "Work order #{new_wo["id"]} created successfully",
        generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end
  end

  @impl true
  def handle(:work_orders_update, args, context) do
    audit_log(@domain, :work_orders_update, args, context)

    with {:ok, _} <- validate_required(args, ["work_order_id"]) do
      wo_id = Map.get(args, "work_order_id")
      base_wo = find_work_order(wo_id) || %{"id" => wo_id, "status" => "open"}

      updated_wo =
        base_wo
        |> maybe_update_field("status", args)
        |> maybe_update_field("technician_id", args)
        |> maybe_update_field("notes", args)
        |> maybe_update_field("parts_required", args)
        |> Map.put("updated_at", DateTime.utc_now() |> DateTime.to_iso8601())

      ensure_ets_table(@wo_table)
      :ets.insert(@wo_table, {wo_id, updated_wo})

      success(%{
        work_order: updated_wo,
        message: "Work order #{wo_id} updated",
        generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end
  end

  @impl true
  def handle(:work_orders_close, args, context) do
    audit_log(@domain, :work_orders_close, args, context)

    with {:ok, _} <- validate_required(args, ["work_order_id", "resolution", "outcome"]) do
      wo_id = Map.get(args, "work_order_id")
      base_wo = find_work_order(wo_id) || %{"id" => wo_id}

      closed_wo =
        base_wo
        |> Map.put("status", "completed")
        |> Map.put("resolution", Map.get(args, "resolution"))
        |> Map.put("outcome", Map.get(args, "outcome"))
        |> Map.put("labour_hours", Map.get(args, "labour_hours", 0))
        |> Map.put("parts_used", Map.get(args, "parts_used", []))
        |> Map.put("closed_at", DateTime.utc_now() |> DateTime.to_iso8601())
        |> Map.put("updated_at", DateTime.utc_now() |> DateTime.to_iso8601())

      ensure_ets_table(@wo_table)
      :ets.insert(@wo_table, {wo_id, closed_wo})

      success(%{
        work_order: closed_wo,
        message: "Work order #{wo_id} closed with outcome: #{Map.get(args, "outcome")}",
        generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end
  end

  @impl true
  def handle(:schedule_list, args, context) do
    audit_log(@domain, :schedule_list, args, context)

    horizon_days = Map.get(args, "horizon_days", 30)
    asset_type_filter = Map.get(args, "asset_type")
    overdue_only = Map.get(args, "overdue_only", false)

    scheduled =
      simulated_schedule()
      |> Enum.filter(fn task ->
        if overdue_only,
          do: task["overdue"] == true,
          else: task["days_until_due"] <= horizon_days
      end)
      |> maybe_filter_schedule_asset_type(asset_type_filter)
      |> Enum.sort_by(& &1["days_until_due"])

    success(%{
      scheduled_tasks: scheduled,
      total: length(scheduled),
      overdue_count: Enum.count(scheduled, & &1["overdue"]),
      horizon_days: horizon_days,
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      data_source: "simulated"
    })
  end

  @impl true
  def handle(:schedule_plan, args, context) do
    audit_log(@domain, :schedule_plan, args, context)

    start_date = Map.get(args, "start_date", Date.utc_today() |> Date.to_iso8601())
    end_date = Map.get(args, "end_date", Date.utc_today() |> Date.add(30) |> Date.to_iso8601())
    priority_threshold = Map.get(args, "priority_threshold", "medium")
    technician_ids = Map.get(args, "technician_ids", [])

    technicians =
      simulated_technicians()
      |> then(fn techs ->
        if technician_ids == [],
          do: techs,
          else: Enum.filter(techs, &(&1["id"] in technician_ids))
      end)

    tasks =
      simulated_schedule()
      |> Enum.filter(&priority_meets_threshold?(&1["priority"], priority_threshold))
      |> Enum.take(20)

    windows = assign_maintenance_windows(tasks, technicians, start_date)

    success(%{
      plan: %{
        "start_date" => start_date,
        "end_date" => end_date,
        "priority_threshold" => priority_threshold,
        "windows" => windows,
        "total_tasks" => length(windows),
        "technician_count" => length(technicians),
        "estimated_total_hours" => Enum.sum(Enum.map(windows, & &1["estimated_hours"]))
      },
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      data_source: "simulated"
    })
  end

  @impl true
  def handle(:technicians_list, args, context) do
    audit_log(@domain, :technicians_list, args, context)

    available_only = Map.get(args, "available_only", false)
    skill_filter = Map.get(args, "skill")

    technicians =
      simulated_technicians()
      |> then(fn techs ->
        if available_only, do: Enum.filter(techs, & &1["available"]), else: techs
      end)
      |> maybe_filter_technician_skill(skill_filter)

    success(%{
      technicians: technicians,
      total: length(technicians),
      available_count: Enum.count(technicians, & &1["available"]),
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      data_source: "simulated"
    })
  end

  @impl true
  def handle(:assets_list, args, context) do
    audit_log(@domain, :assets_list, args, context)

    asset_type_filter = Map.get(args, "asset_type")
    location_filter = Map.get(args, "location")
    health_threshold = Map.get(args, "health_threshold")

    assets =
      simulated_assets()
      |> maybe_filter_asset_type(asset_type_filter)
      |> maybe_filter_asset_location(location_filter)
      |> then(fn list ->
        if health_threshold do
          Enum.filter(list, fn a -> a["health_score"] < health_threshold end)
        else
          list
        end
      end)

    success(%{
      assets: assets,
      total: length(assets),
      critical_count: Enum.count(assets, &(&1["health_score"] < 40)),
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      data_source: "simulated"
    })
  end

  @impl true
  def handle(:assets_history, args, context) do
    audit_log(@domain, :assets_history, args, context)

    with {:ok, _} <- validate_required(args, ["asset_id"]) do
      asset_id = Map.get(args, "asset_id")
      limit = Map.get(args, "limit", 50)
      history = simulated_asset_history(asset_id, limit)

      success(%{
        asset_id: asset_id,
        history: history,
        total_records: length(history),
        generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        data_source: "simulated"
      })
    end
  end

  @impl true
  def handle(:metrics, args, context) do
    audit_log(@domain, :metrics, args, context)

    period = Map.get(args, "period", "month")

    success(%{
      period: period,
      metrics: %{
        "work_orders" => %{
          "open" => 14,
          "in_progress" => 8,
          "pending_parts" => 3,
          "completed" => 47,
          "cancelled" => 2,
          "overdue" => 5
        },
        "performance" => %{
          "mttr_hours" => 4.2,
          "mtbf_days" => 32.5,
          "completion_rate_pct" => 91.4,
          "first_time_fix_rate_pct" => 78.3,
          "sla_compliance_pct" => 88.7
        },
        "backlog" => %{
          "total_open" => 25,
          "critical" => 2,
          "high" => 7,
          "medium" => 11,
          "low" => 5
        },
        "resources" => %{
          "total_technicians" => 6,
          "utilisation_pct" => 72.4,
          "avg_jobs_per_technician" => 4.2
        },
        "costs" => %{
          "labour_hours_total" => 198.5,
          "parts_cost_estimate" => "GBP 4,230"
        }
      },
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      data_source: "simulated"
    })
  end

  @impl true
  def handle(:alerts, args, context) do
    audit_log(@domain, :alerts, args, context)

    severity_filter = Map.get(args, "severity", "any")

    alerts =
      simulated_alerts()
      |> Enum.filter(fn alert ->
        case severity_filter do
          "any" -> true
          "critical" -> alert["severity"] == "critical"
          "high" -> alert["severity"] in ["critical", "high"]
          _ -> true
        end
      end)

    success(%{
      alerts: alerts,
      total: length(alerts),
      critical_count: Enum.count(alerts, &(&1["severity"] == "critical")),
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      data_source: "simulated"
    })
  end

  # ---------------------------------------------------------------------------
  # Simulated data generators
  # ---------------------------------------------------------------------------

  defp simulated_work_orders do
    [
      %{
        "id" => "WO-2026-001",
        "asset_id" => "ASSET-HVAC-001",
        "title" => "HVAC compressor noise — Floor 3 North",
        "priority" => "high",
        "work_type" => "corrective",
        "status" => "in_progress",
        "technician_id" => "TECH-002",
        "created_at" => "2026-03-22T08:30:00Z",
        "updated_at" => "2026-03-23T14:00:00Z",
        "due_date" => "2026-03-25T17:00:00Z",
        "estimated_hours" => 3.0,
        "overdue" => false
      },
      %{
        "id" => "WO-2026-002",
        "asset_id" => "ASSET-ELEV-003",
        "title" => "Elevator door sensor replacement — Block B",
        "priority" => "critical",
        "work_type" => "corrective",
        "status" => "open",
        "technician_id" => nil,
        "created_at" => "2026-03-23T10:00:00Z",
        "updated_at" => "2026-03-23T10:00:00Z",
        "due_date" => "2026-03-24T12:00:00Z",
        "estimated_hours" => 5.0,
        "overdue" => false
      },
      %{
        "id" => "WO-2026-003",
        "asset_id" => "ASSET-FIRE-012",
        "title" => "Fire panel battery replacement — Level 1",
        "priority" => "medium",
        "work_type" => "preventive",
        "status" => "open",
        "technician_id" => nil,
        "created_at" => "2026-03-20T09:00:00Z",
        "updated_at" => "2026-03-20T09:00:00Z",
        "due_date" => "2026-03-26T17:00:00Z",
        "estimated_hours" => 1.5,
        "overdue" => false
      },
      %{
        "id" => "WO-2026-004",
        "asset_id" => "ASSET-GEN-001",
        "title" => "Generator monthly test and service",
        "priority" => "medium",
        "work_type" => "preventive",
        "status" => "pending_parts",
        "technician_id" => "TECH-001",
        "created_at" => "2026-03-15T08:00:00Z",
        "updated_at" => "2026-03-21T11:30:00Z",
        "due_date" => "2026-03-22T17:00:00Z",
        "estimated_hours" => 4.0,
        "overdue" => true
      },
      %{
        "id" => "WO-2026-005",
        "asset_id" => "ASSET-CCTV-022",
        "title" => "PTZ camera calibration — Car Park Level 2",
        "priority" => "low",
        "work_type" => "corrective",
        "status" => "open",
        "technician_id" => nil,
        "created_at" => "2026-03-24T07:00:00Z",
        "updated_at" => "2026-03-24T07:00:00Z",
        "due_date" => "2026-03-31T17:00:00Z",
        "estimated_hours" => 1.0,
        "overdue" => false
      }
    ]
  end

  defp simulated_schedule do
    [
      %{
        "id" => "PM-2026-011",
        "asset_id" => "ASSET-HVAC-001",
        "asset_type" => "hvac",
        "title" => "Quarterly HVAC filter change",
        "priority" => "medium",
        "frequency" => "quarterly",
        "estimated_hours" => 2.0,
        "days_until_due" => 6,
        "due_date" => "2026-03-30",
        "overdue" => false,
        "location" => "Floor 3 North Plant Room"
      },
      %{
        "id" => "PM-2026-012",
        "asset_id" => "ASSET-ELEV-001",
        "asset_type" => "elevator",
        "title" => "Monthly elevator safety inspection",
        "priority" => "high",
        "frequency" => "monthly",
        "estimated_hours" => 1.5,
        "days_until_due" => -2,
        "due_date" => "2026-03-22",
        "overdue" => true,
        "location" => "Block A Lift Shaft"
      },
      %{
        "id" => "PM-2026-013",
        "asset_id" => "ASSET-FIRE-012",
        "asset_type" => "fire_panel",
        "title" => "6-monthly fire panel functional test",
        "priority" => "critical",
        "frequency" => "semi-annual",
        "estimated_hours" => 4.0,
        "days_until_due" => 12,
        "due_date" => "2026-04-05",
        "overdue" => false,
        "location" => "Level 1 Fire Control Room"
      },
      %{
        "id" => "PM-2026-014",
        "asset_id" => "ASSET-GEN-001",
        "asset_type" => "generator",
        "title" => "Annual generator load test",
        "priority" => "high",
        "frequency" => "annual",
        "estimated_hours" => 6.0,
        "days_until_due" => 21,
        "due_date" => "2026-04-14",
        "overdue" => false,
        "location" => "Basement Plant Room"
      },
      %{
        "id" => "PM-2026-015",
        "asset_id" => "ASSET-CCTV-ALL",
        "asset_type" => "cctv",
        "title" => "CCTV system health check and lens clean",
        "priority" => "low",
        "frequency" => "quarterly",
        "estimated_hours" => 8.0,
        "days_until_due" => 45,
        "due_date" => "2026-05-08",
        "overdue" => false,
        "location" => "All zones"
      }
    ]
  end

  defp simulated_technicians do
    [
      %{
        "id" => "TECH-001",
        "name" => "James Kovacs",
        "skills" => ["electrical", "hvac", "generator"],
        "available" => false,
        "current_job" => "WO-2026-004",
        "location" => "Basement Plant Room",
        "active_jobs" => 1
      },
      %{
        "id" => "TECH-002",
        "name" => "Priya Sharma",
        "skills" => ["hvac", "plumbing", "mechanical"],
        "available" => false,
        "current_job" => "WO-2026-001",
        "location" => "Floor 3 North",
        "active_jobs" => 1
      },
      %{
        "id" => "TECH-003",
        "name" => "Marcus Webb",
        "skills" => ["elevator", "mechanical", "electrical"],
        "available" => true,
        "current_job" => nil,
        "location" => "Workshop",
        "active_jobs" => 0
      },
      %{
        "id" => "TECH-004",
        "name" => "Fatima Al-Rashid",
        "skills" => ["fire_panel", "fire_suppression", "electrical"],
        "available" => true,
        "current_job" => nil,
        "location" => "Workshop",
        "active_jobs" => 0
      },
      %{
        "id" => "TECH-005",
        "name" => "Declan O'Brien",
        "skills" => ["cctv", "access_control", "networking"],
        "available" => true,
        "current_job" => nil,
        "location" => "Control Room",
        "active_jobs" => 0
      },
      %{
        "id" => "TECH-006",
        "name" => "Yuki Nakamura",
        "skills" => ["electrical", "plumbing", "general"],
        "available" => false,
        "current_job" => "WO-2026-EXT",
        "location" => "Off-site",
        "active_jobs" => 2
      }
    ]
  end

  defp simulated_assets do
    [
      %{
        "id" => "ASSET-HVAC-001",
        "name" => "HVAC Unit — Floor 3 North",
        "asset_type" => "hvac",
        "location" => "Floor 3 North Plant Room",
        "health_score" => 62,
        "status" => "degraded",
        "last_service" => "2025-12-15",
        "next_service" => "2026-03-30",
        "open_work_orders" => 1
      },
      %{
        "id" => "ASSET-ELEV-001",
        "name" => "Passenger Elevator — Block A",
        "asset_type" => "elevator",
        "location" => "Block A",
        "health_score" => 85,
        "status" => "operational",
        "last_service" => "2026-02-22",
        "next_service" => "2026-03-22",
        "open_work_orders" => 0
      },
      %{
        "id" => "ASSET-ELEV-003",
        "name" => "Goods Elevator — Block B",
        "asset_type" => "elevator",
        "location" => "Block B",
        "health_score" => 38,
        "status" => "fault",
        "last_service" => "2026-01-10",
        "next_service" => "2026-02-10",
        "open_work_orders" => 1
      },
      %{
        "id" => "ASSET-FIRE-012",
        "name" => "Fire Detection Panel — Level 1",
        "asset_type" => "fire_panel",
        "location" => "Level 1 Fire Control Room",
        "health_score" => 91,
        "status" => "operational",
        "last_service" => "2025-09-15",
        "next_service" => "2026-04-05",
        "open_work_orders" => 1
      },
      %{
        "id" => "ASSET-GEN-001",
        "name" => "Standby Generator — Basement",
        "asset_type" => "generator",
        "location" => "Basement Plant Room",
        "health_score" => 54,
        "status" => "degraded",
        "last_service" => "2025-09-01",
        "next_service" => "2026-03-22",
        "open_work_orders" => 1
      },
      %{
        "id" => "ASSET-CCTV-022",
        "name" => "PTZ Camera — Car Park Level 2",
        "asset_type" => "cctv",
        "location" => "Car Park Level 2",
        "health_score" => 77,
        "status" => "operational",
        "last_service" => "2025-12-01",
        "next_service" => "2026-05-08",
        "open_work_orders" => 1
      }
    ]
  end

  defp simulated_alerts do
    [
      %{
        "id" => "ALERT-M-001",
        "type" => "overdue_work_order",
        "severity" => "high",
        "message" =>
          "Work order WO-2026-004 is overdue by 2 days — Generator service pending parts",
        "work_order_id" => "WO-2026-004",
        "asset_id" => "ASSET-GEN-001",
        "raised_at" => "2026-03-22T18:00:00Z",
        "acknowledged" => false
      },
      %{
        "id" => "ALERT-M-002",
        "type" => "overdue_scheduled_pm",
        "severity" => "high",
        "message" => "Elevator safety inspection PM-2026-012 overdue by 2 days — TECH required",
        "schedule_id" => "PM-2026-012",
        "asset_id" => "ASSET-ELEV-001",
        "raised_at" => "2026-03-22T06:00:00Z",
        "acknowledged" => false
      },
      %{
        "id" => "ALERT-M-003",
        "type" => "critical_asset_health",
        "severity" => "critical",
        "message" =>
          "ASSET-ELEV-003 health score 38 — elevator fault, work order open and unassigned",
        "asset_id" => "ASSET-ELEV-003",
        "work_order_id" => "WO-2026-002",
        "raised_at" => "2026-03-23T10:05:00Z",
        "acknowledged" => false
      },
      %{
        "id" => "ALERT-M-004",
        "type" => "unassigned_critical_work_order",
        "severity" => "critical",
        "message" =>
          "Critical work order WO-2026-002 has no technician assigned — elevator door sensor",
        "work_order_id" => "WO-2026-002",
        "asset_id" => "ASSET-ELEV-003",
        "raised_at" => "2026-03-23T10:30:00Z",
        "acknowledged" => false
      }
    ]
  end

  defp simulated_wo_history(wo_id) do
    [
      %{
        "timestamp" => "2026-03-23T08:00:00Z",
        "event" => "status_changed",
        "from" => "open",
        "to" => "in_progress",
        "actor" => "TECH-002",
        "note" => "Technician on site"
      },
      %{
        "timestamp" => "2026-03-22T12:00:00Z",
        "event" => "work_order_created",
        "actor" => "system",
        "note" => "Created for asset #{wo_id}"
      }
    ]
  end

  defp simulated_asset_history(asset_id, limit) do
    base = [
      %{
        "date" => "2025-12-15",
        "type" => "preventive",
        "title" => "Quarterly service",
        "technician" => "TECH-001",
        "outcome" => "completed",
        "labour_hours" => 2.5,
        "asset_id" => asset_id
      },
      %{
        "date" => "2025-09-10",
        "type" => "corrective",
        "title" => "Fault repair",
        "technician" => "TECH-002",
        "outcome" => "resolved",
        "labour_hours" => 3.0,
        "asset_id" => asset_id
      },
      %{
        "date" => "2025-06-15",
        "type" => "preventive",
        "title" => "6-monthly service",
        "technician" => "TECH-001",
        "outcome" => "completed",
        "labour_hours" => 4.0,
        "asset_id" => asset_id
      }
    ]

    Enum.take(base, limit)
  end

  # ---------------------------------------------------------------------------
  # Maintenance window planning helper
  # ---------------------------------------------------------------------------

  defp assign_maintenance_windows(tasks, technicians, start_date) do
    available = Enum.filter(technicians, & &1["available"])
    pool = if available == [], do: technicians, else: available

    tasks
    |> Enum.with_index()
    |> Enum.map(fn {task, idx} ->
      tech = Enum.at(pool, rem(idx, max(length(pool), 1)))

      %{
        "task_id" => task["id"],
        "title" => task["title"],
        "asset_id" => task["asset_id"],
        "priority" => task["priority"],
        "estimated_hours" => task["estimated_hours"],
        "assigned_to" => if(tech, do: tech["id"], else: "unassigned"),
        "technician_name" => if(tech, do: tech["name"], else: "TBD"),
        "planned_date" => planned_date(start_date, idx),
        "status" => "planned"
      }
    end)
  end

  defp planned_date(start_date, offset_days) do
    case Date.from_iso8601(start_date) do
      {:ok, date} -> date |> Date.add(offset_days) |> Date.to_iso8601()
      _ -> start_date
    end
  end

  # ---------------------------------------------------------------------------
  # Filter helpers
  # ---------------------------------------------------------------------------

  defp maybe_filter_wo_status(wos, "all"), do: wos
  defp maybe_filter_wo_status(wos, status), do: Enum.filter(wos, &(&1["status"] == status))

  defp maybe_filter_wo_priority(wos, nil), do: wos

  defp maybe_filter_wo_priority(wos, priority),
    do: Enum.filter(wos, &(&1["priority"] == priority))

  defp maybe_filter_wo_asset(wos, nil), do: wos
  defp maybe_filter_wo_asset(wos, asset_id), do: Enum.filter(wos, &(&1["asset_id"] == asset_id))

  defp maybe_filter_wo_technician(wos, nil), do: wos

  defp maybe_filter_wo_technician(wos, tech_id),
    do: Enum.filter(wos, &(&1["technician_id"] == tech_id))

  defp maybe_filter_schedule_asset_type(tasks, nil), do: tasks

  defp maybe_filter_schedule_asset_type(tasks, asset_type),
    do: Enum.filter(tasks, &(&1["asset_type"] == asset_type))

  defp maybe_filter_technician_skill(techs, nil), do: techs

  defp maybe_filter_technician_skill(techs, skill),
    do: Enum.filter(techs, &(skill in &1["skills"]))

  defp maybe_filter_asset_type(assets, nil), do: assets

  defp maybe_filter_asset_type(assets, type),
    do: Enum.filter(assets, &(&1["asset_type"] == type))

  defp maybe_filter_asset_location(assets, nil), do: assets

  defp maybe_filter_asset_location(assets, loc),
    do: Enum.filter(assets, &String.contains?(&1["location"], loc))

  defp maybe_update_field(map, field, args) do
    case Map.get(args, field) do
      nil -> map
      value -> Map.put(map, field, value)
    end
  end

  # ---------------------------------------------------------------------------
  # Priority helpers
  # ---------------------------------------------------------------------------

  defp priority_meets_threshold?(priority, threshold) do
    order = %{"critical" => 4, "high" => 3, "medium" => 2, "low" => 1}
    Map.get(order, priority, 0) >= Map.get(order, threshold, 0)
  end

  defp priority_to_estimated_hours("critical"), do: 6.0
  defp priority_to_estimated_hours("high"), do: 3.0
  defp priority_to_estimated_hours("medium"), do: 2.0
  defp priority_to_estimated_hours(_low), do: 1.0

  defp find_work_order(wo_id) do
    ensure_ets_table(@wo_table)

    case :ets.lookup(@wo_table, wo_id) do
      [{^wo_id, wo}] -> wo
      _ -> Enum.find(simulated_work_orders(), &(&1["id"] == wo_id))
    end
  end

  # ---------------------------------------------------------------------------
  # ETS + ID utilities
  # ---------------------------------------------------------------------------

  defp ensure_ets_table(table) do
    unless :ets.whereis(table) != :undefined do
      :ets.new(table, [:named_table, :public, :set])
    end
  rescue
    _ -> :ok
  end

  defp generate_id do
    "WO-#{:os.system_time(:millisecond)}-#{:rand.uniform(9999)}"
  end
end
