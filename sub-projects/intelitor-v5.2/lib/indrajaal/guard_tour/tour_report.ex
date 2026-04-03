defmodule Indrajaal.GuardTour.TourReport do
  @moduledoc """
  Comprehensive patrol tour completion reports with analytics.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.GuardTour

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :report_status, :atom do
      constraints one_of: [:draft, :submitted, :reviewed, :approved]
      default :draft
    end

    attribute :generated_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :submitted_at, :utc_datetime
    attribute :reviewed_at, :utc_datetime

    attribute :completion_score, :decimal do
      constraints min: 0, max: 100
    end

    attribute :efficiency_rating, :atom do
      constraints one_of: [:excellent, :good, :fair, :poor]
    end

    attribute :total_checkpoints, :integer do
      default 0
    end

    attribute :checkpoints_completed, :integer do
      default 0
    end

    attribute :checkpoints_missed, :integer do
      default 0
    end

    attribute :exceptions_count, :integer do
      default 0
    end

    attribute :total_duration_minutes, :integer
    attribute :average_checkpoint_time, :integer

    attribute :summary, :string do
      constraints max_length: 2000
    end

    attribute :recommendations, {:array, :string} do
      default []
    end

    attribute :follow_up_required, :boolean do
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :execution, Indrajaal.GuardTour.TourExecution do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :guard, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :reviewed_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end
  end

  calculations do
    calculate :completion_percentage, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          if record.total_checkpoints > 0 do
            Decimal.div(
              Decimal.mult(record.checkpoints_completed, 100),
              record.total_checkpoints
            )
          else
            Decimal.new(0)
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :generate_report do
      argument :execution_id, :uuid do
        allow_nil? false
      end

      argument :guard_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:execution_id, arg(:execution_id))
      change set_attribute(:guard_id, arg(:guard_id))
    end

    update :submit_report do
      require_atomic? false

      argument :summary, :string do
        allow_nil? false
      end

      change set_attribute(:report_status, :submitted)
      change set_attribute(:submitted_at, &DateTime.utc_now/0)
      change set_attribute(:summary, arg(:summary))
    end

    update :review_report do
      require_atomic? false

      argument :reviewed_by_id, :uuid do
        allow_nil? false
      end

      argument :efficiency_rating, :atom do
        allow_nil? false
      end

      argument :recommendations, {:array, :string}

      change set_attribute(:report_status, :reviewed)
      change set_attribute(:reviewed_at, &DateTime.utc_now/0)
      change set_attribute(:reviewed_by_id, arg(:reviewed_by_id))
      change set_attribute(:efficiency_rating, arg(:efficiency_rating))
      change set_attribute(:recommendations, arg(:recommendations))
    end

    update :approve_report do
      require_atomic? false
      change set_attribute(:report_status, :approved)
    end
  end

  code_interface do
    define :create
    define :generate_report
    define :submit_report
    define :review_report
    define :approve_report
  end

  postgres do
    table "tour_reports"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :execution_id], unique: true
      index [:tenant_id, :guard_id]
      index [:tenant_id, :report_status]
      index [:tenant_id, :generated_at]
      index [:tenant_id, :efficiency_rating]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
