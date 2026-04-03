defmodule Indrajaal.GuardTour.GuardAssignment do
  @moduledoc """
  Guard assignments to patrol schedules and routes.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.GuardTour

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :assignment_type, :atom do
      constraints one_of: [:primary, :backup, :supervisor]
      allow_nil? false
    end

    attribute :assigned_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :valid_from, :utc_datetime do
      allow_nil? false
    end

    attribute :valid_until, :utc_datetime

    attribute :is_active, :boolean do
      default true
    end

    attribute :priority_order, :integer do
      default 1
      constraints min: 1
    end

    attribute :qualifications_required, {:array, :string} do
      default []
    end

    timestamps()
  end

  relationships do
    belongs_to :guard, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :schedule, Indrajaal.GuardTour.TourSchedule do
      attribute_writable? true
    end

    belongs_to :route, Indrajaal.GuardTour.TourRoute do
      attribute_writable? true
    end

    belongs_to :assigned_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :assign_guard do
      argument :guard_id, :uuid do
        allow_nil? false
      end

      argument :schedule_id, :uuid
      argument :route_id, :uuid

      argument :assignment_type, :atom do
        allow_nil? false
      end

      argument :valid_from, :utc_datetime do
        allow_nil? false
      end

      argument :assigned_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:guard_id, arg(:guard_id))
      change set_attribute(:schedule_id, arg(:schedule_id))
      change set_attribute(:route_id, arg(:route_id))
      change set_attribute(:assignment_type, arg(:assignment_type))
      change set_attribute(:valid_from, arg(:valid_from))
      change set_attribute(:assigned_by_id, arg(:assigned_by_id))
    end

    update :deactivate do
      require_atomic? false
      change set_attribute(:is_active, false)
    end
  end

  validations do
    validate present(:schedule_id, where: absent(:route_id)),
      message: "Must assign to either a schedule or route, but not both"

    validate present(:route_id, where: absent(:schedule_id)),
      message: "Must assign to either a schedule or route, but not both"

    validate compare(:valid_until, greater_than: :valid_from),
      message: "Valid until must be after valid from"
  end

  code_interface do
    define :create
    define :assign_guard
    define :deactivate
  end

  postgres do
    table "guard_assignments"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :guard_id]
      index [:tenant_id, :schedule_id]
      index [:tenant_id, :route_id]
      index [:tenant_id, :is_active]
      index [:tenant_id, :valid_from, :valid_until]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
