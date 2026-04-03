defmodule Indrajaal.GuardTour.TourRoute do
  @moduledoc """
  Predefined security patrol routes with ordered checkpoints.
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

    attribute :description, :string do
      constraints max_length: 500
    end

    attribute :route_type, :atom do
      constraints one_of: [:regular, :emergency, :maintenance, :custom]
      allow_nil? false
    end

    attribute :estimated_duration, :integer do
      allow_nil? false
      constraints min: 1
    end

    attribute :checkpoint_order, {:array, :uuid} do
      default []
    end

    attribute :is_active, :boolean do
      default true
    end

    attribute :priority_level, :atom do
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    timestamps()
  end

  relationships do
    has_many :checkpoints, Indrajaal.GuardTour.Checkpoint do
      destination_attribute :route_id
    end

    has_many :tour_schedules, Indrajaal.GuardTour.TourSchedule do
      destination_attribute :route_id
    end

    has_many :tour_executions, Indrajaal.GuardTour.TourExecution do
      destination_attribute :route_id
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

  code_interface do
    define :create
    define :activate
    define :deactivate
  end

  postgres do
    table "tour_routes"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :is_active]
      index [:tenant_id, :route_type]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
