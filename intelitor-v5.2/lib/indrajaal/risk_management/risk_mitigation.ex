defmodule Indrajaal.RiskManagement.RiskMitigation do
  @moduledoc """
  Risk mitigation strategies and action plans for risk treatment.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.RiskManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :mitigation_strategy, :atom do
      constraints one_of: [:avoid, :mitigate, :transfer, :accept, :monitor]
      allow_nil? false
    end

    attribute :title, :string do
      allow_nil? false
      constraints max_length: 200
    end

    attribute :description, :string do
      allow_nil? false
      constraints max_length: 2000
    end

    attribute :implementation_status, :atom do
      constraints one_of: [:planned, :in_progress, :implemented, :verified, :cancelled]
      default :planned
    end

    attribute :priority, :atom do
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    attribute :planned_start_date, :date
    attribute :planned_completion_date, :date
    attribute :actual_start_date, :date
    attribute :actual_completion_date, :date

    attribute :estimated_cost, :decimal do
      constraints precision: 12, scale: 2
    end

    attribute :actual_cost, :decimal do
      constraints precision: 12, scale: 2
    end

    attribute :budget_allocated, :decimal do
      constraints precision: 12, scale: 2
    end

    attribute :resources_required, {:array, :string} do
      default []
    end

    attribute :success_criteria, {:array, :string} do
      default []
    end

    attribute :implementation_plan, :string do
      constraints max_length: 3000
    end

    attribute :effectiveness_measurement, :string do
      constraints max_length: 1000
    end

    attribute :progress_percentage, :integer do
      default 0
      constraints min: 0, max: 100
    end

    attribute :barriers_encountered, {:array, :string} do
      default []
    end

    timestamps()
  end

  relationships do
    belongs_to :risk, Indrajaal.RiskManagement.Risk do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :owner, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :approved_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    has_many :controls, Indrajaal.RiskManagement.RiskControl do
      destination_attribute :mitigation_id
    end
  end

  calculations do
    calculate :is_overdue, :boolean do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          case {record.implementation_status, record.planned_completion_date} do
            {status, completion_date}
            when status in [:planned, :in_progress] and not is_nil(completion_date) ->
              Date.compare(today, completion_date) == :gt

            _ ->
              false
          end
        end)
      end
    end

    calculate :cost_variance, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case {record.estimated_cost, record.actual_cost} do
            {estimated, actual} when not is_nil(estimated) and not is_nil(actual) ->
              Decimal.sub(actual, estimated)

            _ ->
              nil
          end
        end)
      end
    end

    calculate :schedule_variance_days, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case {record.planned_completion_date, record.actual_completion_date} do
            {planned, actual} when not is_nil(planned) and not is_nil(actual) ->
              Date.diff(actual, planned)

            _ ->
              nil
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :plan_mitigation do
      argument :risk_id, :uuid do
        allow_nil? false
      end

      argument :strategy, :atom do
        allow_nil? false
      end

      argument :title, :string do
        allow_nil? false
      end

      argument :description, :string do
        allow_nil? false
      end

      argument :owner_id, :uuid do
        allow_nil? false
      end

      argument :priority, :atom do
        allow_nil? false
      end

      change set_attribute(:risk_id, arg(:risk_id))
      change set_attribute(:mitigation_strategy, arg(:strategy))
      change set_attribute(:title, arg(:title))
      change set_attribute(:description, arg(:description))
      change set_attribute(:owner_id, arg(:owner_id))
      change set_attribute(:priority, arg(:priority))
    end

    update :approve_mitigation do
      require_atomic? false

      argument :approved_by_id, :uuid do
        allow_nil? false
      end

      argument :budget_allocated, :decimal

      change set_attribute(:approved_by_id, arg(:approved_by_id))
      change set_attribute(:budget_allocated, arg(:budget_allocated))
    end

    update :start_implementation do
      require_atomic? false
      change set_attribute(:implementation_status, :in_progress)
      change set_attribute(:actual_start_date, Date.utc_today())
    end

    update :update_progress do
      require_atomic? false

      argument :progress_percentage, :integer do
        allow_nil? false
      end

      argument :barriers, {:array, :string}

      change set_attribute(:progress_percentage, arg(:progress_percentage))
      change set_attribute(:barriers_encountered, arg(:barriers))
    end

    update :complete_implementation do
      require_atomic? false
      argument :actual_cost, :decimal
      argument :effectiveness_notes, :string

      change set_attribute(:implementation_status, :implemented)
      change set_attribute(:actual_completion_date, Date.utc_today())
      change set_attribute(:progress_percentage, 100)
      change set_attribute(:actual_cost, arg(:actual_cost))

      change set_attribute(
               :effectiveness_measurement,
               arg(:effectiveness_notes)
             )
    end

    update :verify_effectiveness do
      require_atomic? false

      argument :verification_notes, :string do
        allow_nil? false
      end

      change set_attribute(:implementation_status, :verified)
      change set_attribute(:effectiveness_measurement, arg(:verification_notes))
    end

    update :cancel_mitigation do
      require_atomic? false

      argument :cancellation_reason, :string do
        allow_nil? false
      end

      change set_attribute(:implementation_status, :cancelled)

      change fn changeset, _ ->
        reason = Ash.Changeset.get_argument(changeset, :cancellation_reason)
        current_barriers = changeset.data.barriers_encountered || []
        updated_barriers = current_barriers ++ ["CANCELLED: #{reason}"]
        Ash.Changeset.change_attribute(changeset, :barriers_encountered, updated_barriers)
      end
    end

    update :schedule_mitigation do
      require_atomic? false

      argument :start_date, :date do
        allow_nil? false
      end

      argument :completion_date, :date do
        allow_nil? false
      end

      argument :estimated_cost, :decimal

      change set_attribute(:planned_start_date, arg(:start_date))
      change set_attribute(:planned_completion_date, arg(:completion_date))
      change set_attribute(:estimated_cost, arg(:estimated_cost))
    end
  end

  validations do
    validate compare(:planned_completion_date,
               greater_than: :planned_start_date
             ),
             message: "Completion date must be after start date",
             where: [present([:planned_start_date, :planned_completion_date])]

    validate compare(:actual_completion_date,
               greater_than_or_equal_to: :actual_start_date
             ),
             message: "Actual completion date must be on or after actual start date",
             where: [present([:actual_start_date, :actual_completion_date])]
  end

  code_interface do
    define :create
    define :plan_mitigation
    define :approve_mitigation
    define :start_implementation
    define :update_progress
    define :complete_implementation
    define :verify_effectiveness
    define :cancel_mitigation
    define :schedule_mitigation
  end

  postgres do
    table "risk_mitigations"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :risk_id]
      index [:tenant_id, :mitigation_strategy]
      index [:tenant_id, :implementation_status]
      index [:tenant_id, :priority]
      index [:tenant_id, :owner_id]

      index [:tenant_id, :planned_completion_date],
        where: "planned_completion_date IS NOT NULL"

      index [:tenant_id, :actual_completion_date],
        where: "actual_completion_date IS NOT NULL"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Risk management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
