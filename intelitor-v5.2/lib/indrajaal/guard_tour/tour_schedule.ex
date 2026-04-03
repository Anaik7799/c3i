defmodule Indrajaal.GuardTour.TourSchedule do
  @moduledoc """
  Scheduled patrol tours with recurrence patterns and guard assignments.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.GuardTour

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :start_time, :utc_datetime do
      allow_nil? false
    end

    attribute :end_time, :utc_datetime do
      allow_nil? false
    end

    attribute :recurrence_pattern, :atom do
      constraints one_of: [:none, :daily, :weekly, :monthly, :custom]
      default :none
    end

    attribute :recurrence_data, :map do
      default %{}
    end

    attribute :is_active, :boolean do
      default true
    end

    attribute :max_delay_minutes, :integer do
      default 15
      constraints min: 0, max: 120
    end

    attribute :auto_assign, :boolean do
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :route, Indrajaal.GuardTour.TourRoute do
      allow_nil? false
      attribute_writable? true
    end

    has_many :guard_assignments, Indrajaal.GuardTour.GuardAssignment do
      destination_attribute :schedule_id
    end

    has_many :tour_executions, Indrajaal.GuardTour.TourExecution do
      destination_attribute :schedule_id
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :activate do
      change set_attribute(:is_active, true)
    end

    update :deactivate do
      require_atomic? false
      change set_attribute(:is_active, false)
    end
  end

  validations do
    validate present([:start_time, :end_time]),
      message: "Schedule times are _required"

    validate compare(:end_time, greater_than: :start_time),
      message: "End time must be after start time"
  end

  code_interface do
    define :create
    define :activate
    define :deactivate
  end

  postgres do
    table "tour_schedules"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :is_active]
      index [:tenant_id, :start_time]
      index [:tenant_id, :route_id]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
