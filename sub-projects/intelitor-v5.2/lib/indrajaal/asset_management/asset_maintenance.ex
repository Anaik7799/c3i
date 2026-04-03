defmodule Indrajaal.AssetManagement.AssetMaintenance do
  @moduledoc """
  Maintenance schedules, records, and tracking for assets.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AssetManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :maintenance_type, :atom do
      constraints one_of: [
                    :pr_eventive,
                    :corrective,
                    :predictive,
                    :emergency,
                    :inspection,
                    :calibration
                  ]

      allow_nil? false
    end

    attribute :status, :atom do
      constraints one_of: [:scheduled, :in_progress, :completed, :cancelled, :overdue]
      default :scheduled
    end

    attribute :priority, :atom do
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    attribute :scheduled_date, :date do
      allow_nil? false
    end

    attribute :completed_date, :date

    attribute :duration_hours, :decimal do
      constraints precision: 8, scale: 2
    end

    attribute :description, :string do
      allow_nil? false
      constraints max_length: 1000
    end

    attribute :work_performed, :string do
      constraints max_length: 2000
    end

    attribute :parts_used, {:array, :map} do
      default []
    end

    attribute :labor_cost, :decimal do
      constraints precision: 10, scale: 2
    end

    attribute :parts_cost, :decimal do
      constraints precision: 10, scale: 2
    end

    attribute :total_cost, :decimal do
      constraints precision: 10, scale: 2
    end

    attribute :next_maintenance_date, :date

    attribute :maintenance_notes, :string do
      constraints max_length: 2000
    end

    attribute :certification_required, :boolean do
      default false
    end

    attribute :certification_obtained, :boolean do
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :asset, Indrajaal.AssetManagement.Asset do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :assigned_technician, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    belongs_to :__requested_by, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :completed_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    belongs_to :work_order, Indrajaal.Maintenance.WorkOrder do
      attribute_writable? true
    end
  end

  calculations do
    calculate :is_overdue, :boolean do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          case record.status do
            status when status in [:scheduled, :in_progress] ->
              Date.compare(today, record.scheduled_date) == :gt

            _ ->
              false
          end
        end)
      end
    end

    calculate :days_until_due, :integer do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          if record.scheduled_date do
            Date.diff(record.scheduled_date, today)
          else
            nil
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :schedule_maintenance do
      argument :asset_id, :uuid do
        allow_nil? false
      end

      argument :maintenance_type, :atom do
        allow_nil? false
      end

      argument :scheduled_date, :date do
        allow_nil? false
      end

      argument :description, :string do
        allow_nil? false
      end

      argument :__requested_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:asset_id, arg(:asset_id))
      change set_attribute(:maintenance_type, arg(:maintenance_type))
      change set_attribute(:scheduled_date, arg(:scheduled_date))
      change set_attribute(:description, arg(:description))
      change set_attribute(:__requested_by_id, arg(:__requested_by_id))
    end

    update :assign_technician do
      require_atomic? false

      argument :technician_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:assigned_technician_id, arg(:technician_id))
    end

    update :start_maintenance do
      require_atomic? false
      change set_attribute(:status, :in_progress)
    end

    update :complete_maintenance do
      require_atomic? false

      argument :work_performed, :string do
        allow_nil? false
      end

      argument :completed_by_id, :uuid do
        allow_nil? false
      end

      argument :duration_hours, :decimal
      argument :total_cost, :decimal

      change set_attribute(:status, :completed)
      change set_attribute(:completed_date, Date.utc_today())
      change set_attribute(:work_performed, arg(:work_performed))
      change set_attribute(:completed_by_id, arg(:completed_by_id))
      change set_attribute(:duration_hours, arg(:duration_hours))
      change set_attribute(:total_cost, arg(:total_cost))
    end

    update :cancel_maintenance do
      require_atomic? false

      argument :reason, :string do
        allow_nil? false
      end

      change set_attribute(:status, :cancelled)
      change set_attribute(:maintenance_notes, arg(:reason))
    end

    update :reschedule do
      require_atomic? false

      argument :new_date, :date do
        allow_nil? false
      end

      change set_attribute(:scheduled_date, arg(:new_date))
      change set_attribute(:status, :scheduled)
    end
  end

  code_interface do
    define :create
    define :schedule_maintenance
    define :assign_technician
    define :start_maintenance
    define :complete_maintenance
    define :cancel_maintenance
    define :reschedule
  end

  postgres do
    table "asset_maintenance"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :asset_id]
      index [:tenant_id, :status]
      index [:tenant_id, :maintenance_type]
      index [:tenant_id, :scheduled_date]
      index [:tenant_id, :assigned_technician_id]
      index [:tenant_id, :priority]

      index [:tenant_id, :next_maintenance_date],
        where: "next_maintenance_date IS NOT NULL"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Asset management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
