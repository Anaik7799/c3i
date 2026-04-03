defmodule Indrajaal.GuardTour.TourException do
  @moduledoc """
  Exceptions and anomalies during patrol execution _requiring attention.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.GuardTour

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :exception_type, :atom do
      constraints one_of: [
                    :missed_checkpoint,
                    :late_arrival,
                    :route_deviation,
                    :emergency,
                    :equipment_failure,
                    :other
                  ]

      allow_nil? false
    end

    attribute :severity, :atom do
      constraints one_of: [:low, :medium, :high, :critical]
      allow_nil? false
    end

    attribute :detected_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :description, :string do
      allow_nil? false
      constraints max_length: 1000
    end

    attribute :location, :string do
      constraints max_length: 200
    end

    attribute :latitude, :decimal do
      constraints precision: 10, scale: 8
    end

    attribute :longitude, :decimal do
      constraints precision: 11, scale: 8
    end

    attribute :resolved_at, :utc_datetime

    attribute :resolution_notes, :string do
      constraints max_length: 1000
    end

    attribute :_requires_followup, :boolean do
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :execution, Indrajaal.GuardTour.TourExecution do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :checkpoint, Indrajaal.GuardTour.Checkpoint do
      attribute_writable? true
    end

    belongs_to :reported_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    belongs_to :resolved_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :report_exception do
      argument :execution_id, :uuid do
        allow_nil? false
      end

      argument :exception_type, :atom do
        allow_nil? false
      end

      argument :severity, :atom do
        allow_nil? false
      end

      argument :description, :string do
        allow_nil? false
      end

      argument :reported_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:execution_id, arg(:execution_id))
      change set_attribute(:exception_type, arg(:exception_type))
      change set_attribute(:severity, arg(:severity))
      change set_attribute(:description, arg(:description))
      change set_attribute(:reported_by_id, arg(:reported_by_id))
    end

    update :resolve_exception do
      require_atomic? false

      argument :resolved_by_id, :uuid do
        allow_nil? false
      end

      argument :resolution_notes, :string do
        allow_nil? false
      end

      change set_attribute(:resolved_at, &DateTime.utc_now/0)
      change set_attribute(:resolved_by_id, arg(:resolved_by_id))
      change set_attribute(:resolution_notes, arg(:resolution_notes))
    end
  end

  code_interface do
    define :create
    define :report_exception
    define :resolve_exception
  end

  postgres do
    table "tour_exceptions"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :execution_id]
      index [:tenant_id, :exception_type]
      index [:tenant_id, :severity]
      index [:tenant_id, :detected_at]
      index [:tenant_id, :resolved_at], where: "resolved_at IS NOT NULL"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
