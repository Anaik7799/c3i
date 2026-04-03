defmodule Indrajaal.Maintenance.WorkOrderTest do
  use Indrajaal.DataCase
  # Don't import Factory directly - DataCase provides insert function
  alias Indrajaal.Core.Tenant
  alias Indrajaal.Devices.Device
  alias Indrajaal.Maintenance.{WorkOrder, Task, ServiceRecord}
  alias Indrajaal.Sites.Site

  describe "WorkOrder resource" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)
      site = insert(:site, tenant: tenant, organization: organization)
      device = insert(:device, tenant: tenant, site: site)

      {:ok, tenant: tenant, organization: organization, site: site, device: device}
    end

    test "creates a work order with valid attributes", %{
      tenant: tenant,
      site: site,
      device: device
    } do
      attrs = %{
        title: "Camera Lens Cleaning",
        description: "Clean camera lens and check focus calibration",
        work_order_type: :preventive,
        priority: :medium,
        status: :open,
        asset_type: "device",
        asset_id: device.id,
        estimated_hours: 2.5,
        scheduled_date: Date.utc_today() |> Date.add(7),
        requested_by: "site_manager",
        work_details: %{
          "tasks" => [
            "Clean camera lens",
            "Check focus calibration",
            "Test zoom functionality"
          ],
          "required_tools" => ["lens_cleaner", "calibration_tool"],
          "safety_requirements" => ["safety_harness", "hard_hat"]
        },
        site_id: site.id,
        tenant_id: tenant.id
      }

      {:ok, work_order} = WorkOrder.create(attrs)

      assert work_order.title == "Camera Lens Cleaning"
      assert work_order.work_order_type == :preventive
      assert work_order.priority == :medium
      assert work_order.status == :open
      assert work_order.asset_type == "device"
      assert work_order.asset_id == device.id
      assert work_order.estimated_hours == 2.5
      assert length(work_order.work_details["tasks"]) == 3
      assert "lens_cleaner" in work_order.work_details["required_tools"]
      assert work_order.site_id == site.id
      assert work_order.tenant_id == tenant.id
    end

    test "validates required fields", %{tenant: tenant} do
      {:error, changeset} = WorkOrder.create(%{tenant_id: tenant.id})

      assert changeset.errors[:title]
      assert changeset.errors[:work_order_type]
      assert changeset.errors[:priority]
      assert changeset.errors[:site_id]
    end

    test "manages work order status transitions",
         %{tenant: tenant, site: site, device: device} do
      work_order =
        insert(:work_order,
          status: :open,
          tenant: tenant,
          site: site,
          asset_type: "device",
          asset_id: device.id
        )

      # Open -> Assigned
      {:ok, assigned_wo} =
        WorkOrder.assign(work_order, %{
          technician_id: "tech-123",
          assigned_by: "supervisor-456",
          notes: "Assigned to senior technician"
        })

      assert assigned_wo.status == :assigned
      assert assigned_wo.assigned_to == "tech-123"
      assert assigned_wo.assigned_by == "supervisor-456"

      # Assigned -> In Progress
      {:ok, in_progress_wo} = WorkOrder.start_work(assigned_wo)
      assert in_progress_wo.status == :in_progress
      assert in_progress_wo.started_at != nil

      # In Progress -> Completed
      {:ok, completed_wo} =
        WorkOrder.complete(in_progress_wo, %{
          completion_notes: "All tasks completed successfully",
          actual_hours: 2.0,
          parts_used: ["lens_cleaning_kit"]
        })

      assert completed_wo.status == :completed
      assert completed_wo.completed_at != nil
      assert completed_wo.actual_hours == 2.0
      assert "lens_cleaning_kit" in completed_wo.parts_used
    end

    test "calculates work order duration",
         %{tenant: tenant, site: site, device: device} do
      # Create work order that started 2 hours ago
      started_time = DateTime.utc_now() |> DateTime.add(-7200, :second)

      work_order =
        insert(:work_order,
          status: :in_progress,
          started_at: started_time,
          tenant: tenant,
          site: site,
          asset_type: "device",
          asset_id: device.id
        )

      wo_with_calc = WorkOrder.read!(work_order.id, load: [:duration_hours])
      assert wo_with_calc.duration_hours >= 1.9
      # Allow some tolerance
      assert wo_with_calc.duration_hours <= 2.1
    end

    test "tracks work order costs",
         %{tenant: tenant, site: site, device: device} do
      work_order =
        insert(:work_order,
          tenant: tenant,
          site: site,
          asset_type: "device",
          asset_id: device.id
        )

      cost_data = %{
        "labor_cost" => 150.00,
        "parts_cost" => 75.50,
        "travel_cost" => 25.00,
        "overhead" => 50.00,
        "currency" => "USD"
      }

      {:ok, costed_wo} =
        WorkOrder.add_costs(work_order, %{
          cost_breakdown: cost_data
        })

      assert costed_wo.cost_breakdown["labor_cost"] == 150.00
      assert costed_wo.cost_breakdown["parts_cost"] == 75.50

      wo_with_total = WorkOrder.read!(costed_wo.id, load: [:total_cost])
      # Sum of all costs
      assert wo_with_total.total_cost == 300.50
    end

    test "manages work order attachments",
         %{tenant: tenant, site: site, device: device} do
      work_order =
        insert(:work_order,
          tenant: tenant,
          site: site,
          asset_type: "device",
          asset_id: device.id
        )

      attachments = [
        %{
          "filename" => "before_photo.jpg",
          "url" => "https://storage.example.com / before.jpg",
          "type" => "photo",
          "description" => "Camera condition before maintenance"
        },
        %{
          "filename" => "service_manual.pdf",
          "url" => "https://storage.example.com / manual.pdf",
          "type" => "document",
          "description" => "Equipment service manual"
        }
      ]

      {:ok, wo_with_attachments} =
        WorkOrder.add_attachments(work_order, %{
          attachments: attachments
        })

      assert length(wo_with_attachments.attachments) == 2
      photo = Enum.find(wo_with_attachments.attachments, &(&1["type"] == "photo"))
      assert photo["filename"] == "before_photo.jpg"
    end

    test "schedules recurring maintenance",
         %{tenant: tenant, site: site, device: device} do
      work_order =
        insert(:work_order,
          work_order_type: :preventive,
          tenant: tenant,
          site: site,
          asset_type: "device",
          asset_id: device.id
        )

      recurrence_config = %{
        "frequency" => "monthly",
        # Every 3 months
        "interval" => 3,
        # 1 year from now
        "end_date" => Date.utc_today() |> Date.add(365),
        "auto_generate" => true
      }

      {:ok, recurring_wo} =
        WorkOrder.set_recurrence(work_order, %{
          recurrence: recurrence_config
        })

      assert recurring_wo.recurrence["frequency"] == "monthly"
      assert recurring_wo.recurrence["interval"] == 3
      assert recurring_wo.recurrence["auto_generate"] == true
    end

    test "validates work order priority escalation",
         %{tenant: tenant, site: site, device: device} do
      work_order =
        insert(:work_order,
          priority: :low,
          # 1 day ago
          created_at: DateTime.utc_now() |> DateTime.add(-86_400, :second),
          tenant: tenant,
          site: site,
          asset_type: "device",
          asset_id: device.id
        )

      {:ok, escalated_wo} =
        WorkOrder.escalate_priority(work_order, %{
          new_priority: :high,
          escalation_reason: "Equipment failure affecting security"
        })

      assert escalated_wo.priority == :high
      assert escalated_wo.metadata["escalation_history"]

      escalation = List.first(escalated_wo.metadata["escalation_history"])
      assert escalation["from_priority"] == "low"
      assert escalation["to_priority"] == "high"
      assert escalation["reason"] == "Equipment failure affecting security"
    end

    test "tracks technician performance",
         %{tenant: tenant, site: site, device: device} do
      work_order =
        insert(:work_order,
          status: :completed,
          assigned_to: "tech-123",
          estimated_hours: 3.0,
          actual_hours: 2.5,
          tenant: tenant,
          site: site,
          asset_type: "device",
          asset_id: device.id
        )

      wo_with_calc = WorkOrder.read!(work_order.id, load: [:efficiency_rating])
      # Completed faster than estimated
      assert wo_with_calc.efficiency_rating >= 1.0
    end

    test "manages work order approval workflow",
         %{tenant: tenant, site: site, device: device} do
      work_order =
        insert(:work_order,
          status: :open,
          # Requires approval for long tasks
          estimated_hours: 8.0,
          tenant: tenant,
          site: site,
          asset_type: "device",
          asset_id: device.id
        )

      {:ok, pending_wo} =
        WorkOrder.request_approval(work_order, %{
          approver_id: "manager-456",
          justification: "Extended maintenance required for compliance"
        })

      assert pending_wo.status == :pending_approval
      assert pending_wo.metadata["approval_request"]

      {:ok, approved_wo} =
        WorkOrder.approve(pending_wo, %{
          approved_by: "manager-456",
          approval_notes: "Approved for compliance maintenance"
        })

      assert approved_wo.status == :approved

      assert approved_wo.metadata["approval_record"]["approved_by"] ==
               "manager-456"
    end

    test "integrates with inventory management",
         %{tenant: tenant, site: site, device: device} do
      work_order =
        insert(:work_order,
          tenant: tenant,
          site: site,
          asset_type: "device",
          asset_id: device.id
        )

      inventory_request = %{
        "required_parts" => [
          %{
            "part_number" => "LENS - KIT - 001",
            "quantity" => 1,
            "description" => "Camera lens cleaning kit"
          },
          %{
            "part_number" => "CALIB - TOOL",
            "quantity" => 1,
            "description" => "Focus calibration tool"
          }
        ],
        "tools_needed" => [
          "safety_harness",
          "multimeter",
          "laptop"
        ]
      }

      {:ok, wo_with_inventory} =
        WorkOrder.request_inventory(work_order, %{
          inventory_request: inventory_request
        })

      assert length(wo_with_inventory.inventory_request["required_parts"]) == 2
      assert "safety_harness" in wo_with_inventory.inventory_request["tools_needed"]
    end

    test "enforces tenant isolation", %{site: site, device: device} do
      tenant1 = site.tenant
      tenant2 = insert(:tenant)
      organization2 = insert(:organization, tenant: tenant2)
      site2 = insert(:site, tenant: tenant2, organization: organization2)
      device2 = insert(:device, tenant: tenant2, site: site2)

      wo1 =
        insert(:work_order,
          tenant: tenant1,
          site: site,
          asset_type: "device",
          asset_id: device.id
        )

      wo2 =
        insert(:work_order,
          tenant: tenant2,
          site: site2,
          asset_type: "device",
          asset_id: device2.id
        )

      tenant1_orders = WorkOrder.read!(tenant: tenant1)
      tenant2_orders = WorkOrder.read!(tenant: tenant2)

      assert length(tenant1_orders) == 1
      assert length(tenant2_orders) == 1
      assert Enum.any?(tenant1_orders, &(&1.id == wo1.id))
      assert Enum.any?(tenant2_orders, &(&1.id == wo2.id))
      refute Enum.any?(tenant1_orders, &(&1.id == wo2.id))
      refute Enum.any?(tenant2_orders, &(&1.id == wo1.id))
    end

    test "generates maintenance reports",
         %{tenant: tenant, site: site, device: device} do
      # Create completed work order
      work_order =
        insert(:work_order,
          status: :completed,
          work_order_type: :preventive,
          estimated_hours: 2.0,
          actual_hours: 1.8,
          tenant: tenant,
          site: site,
          asset_type: "device",
          asset_id: device.id
        )

      wo_with_calc =
        WorkOrder.read!(work_order.id,
          load: [
            :efficiency_rating,
            :duration_hours,
            :total_cost
          ]
        )

      assert is_float(wo_with_calc.efficiency_rating)
      assert is_float(wo_with_calc.duration_hours)
      assert is_number(wo_with_calc.total_cost)
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
