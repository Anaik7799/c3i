defmodule Indrajaal.RiskManagement.RiskTreatment do
  @moduledoc """
  Risk treatment plans and decision frameworks for risk response strategies.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.RiskManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :treatment_strategy, :atom do
      constraints one_of: [
                    :avoid,
                    :mitigate,
                    :transfer,
                    :accept,
                    :monitor,
                    :exploit,
                    :enhance,
                    :share
                  ]

      allow_nil? false
    end

    attribute :treatment_name, :string do
      allow_nil? false
      constraints max_length: 200
    end

    attribute :treatment_description, :string do
      allow_nil? false
      constraints max_length: 2000
    end

    attribute :treatment_status, :atom do
      constraints one_of: [:planned, :approved, :in_progress, :implemented, :reviewed, :closed]
      default :planned
    end

    attribute :decision_date, :date do
      allow_nil? false
      default &Date.utc_today/0
    end

    attribute :implementation_priority, :atom do
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    attribute :planned_start_date, :date
    attribute :planned_completion_date, :date
    attribute :actual_start_date, :date
    attribute :actual_completion_date, :date

    attribute :decision_rationale, :string do
      constraints max_length: 1000
    end

    attribute :success_criteria, {:array, :string} do
      default []
    end

    attribute :key_performance_indicators, {:array, :map} do
      default []
    end

    attribute :residual_risk_acceptance, :string do
      constraints max_length: 1000
    end

    attribute :cost_benefit_analysis, :map do
      default %{}
    end

    attribute :stakeholder_approval, :boolean do
      default false
    end

    attribute :budget_allocated, :decimal do
      constraints precision: 12, scale: 2
    end

    attribute :resources_assigned, {:array, :string} do
      default []
    end

    attribute :dependencies, {:array, :string} do
      default []
    end

    attribute :constraints, {:array, :string} do
      default []
    end

    attribute :monitoring_f_requency, :atom do
      constraints one_of: [:weekly, :monthly, :quarterly, :semi_annually, :annually]
      default :quarterly
    end

    attribute :effectiveness_review_date, :date

    timestamps()
  end

  relationships do
    belongs_to :risk, Indrajaal.RiskManagement.Risk do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :treatment_owner, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :approved_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    belongs_to :reviewed_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end
  end

  calculations do
    calculate :treatment_duration_days, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case {record.planned_start_date, record.planned_completion_date} do
            {start_date, end_date} when not is_nil(start_date) and not is_nil(end_date) ->
              Date.diff(end_date, start_date)

            _ ->
              nil
          end
        end)
      end
    end

    calculate :is_overdue, :boolean do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          case {record.treatment_status, record.planned_completion_date} do
            {status, completion_date}
            when status in [:planned, :approved, :in_progress] and not is_nil(completion_date) ->
              Date.compare(today, completion_date) == :gt

            _ ->
              false
          end
        end)
      end
    end

    calculate :cost_benefit_ratio, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case record.cost_benefit_analysis do
            %{"total_cost" => cost, "total_benefit" => benefit} when cost > 0 ->
              Decimal.div(benefit, cost)

            _ ->
              nil
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :plan_treatment do
      argument :risk_id, :uuid do
        allow_nil? false
      end

      argument :strategy, :atom do
        allow_nil? false
      end

      argument :treatment_name, :string do
        allow_nil? false
      end

      argument :description, :string do
        allow_nil? false
      end

      argument :treatment_owner_id, :uuid do
        allow_nil? false
      end

      argument :priority, :atom do
        allow_nil? false
      end

      change set_attribute(:risk_id, arg(:risk_id))
      change set_attribute(:treatment_strategy, arg(:strategy))
      change set_attribute(:treatment_name, arg(:treatment_name))
      change set_attribute(:treatment_description, arg(:description))
      change set_attribute(:treatment_owner_id, arg(:treatment_owner_id))
      change set_attribute(:implementation_priority, arg(:priority))
    end

    update :conduct_cost_benefit_analysis do
      require_atomic? false

      argument :analysis_data, :map do
        allow_nil? false
      end

      argument :decision_rationale, :string do
        allow_nil? false
      end

      change set_attribute(:cost_benefit_analysis, arg(:analysis_data))
      change set_attribute(:decision_rationale, arg(:decision_rationale))
    end

    update :approve_treatment do
      require_atomic? false

      argument :approved_by_id, :uuid do
        allow_nil? false
      end

      argument :budget_allocated, :decimal
      argument :stakeholder_approval, :boolean, default: true

      change set_attribute(:treatment_status, :approved)
      change set_attribute(:approved_by_id, arg(:approved_by_id))
      change set_attribute(:budget_allocated, arg(:budget_allocated))
      change set_attribute(:stakeholder_approval, arg(:stakeholder_approval))
    end

    update :start_treatment do
      require_atomic? false
      change set_attribute(:treatment_status, :in_progress)
      change set_attribute(:actual_start_date, Date.utc_today())
    end

    update :complete_treatment do
      require_atomic? false
      argument :completion_notes, :string

      change set_attribute(:treatment_status, :implemented)
      change set_attribute(:actual_completion_date, Date.utc_today())

      change fn changeset, _ ->
        current_desc = changeset.data.treatment_description
        notes = Ash.Changeset.get_argument(changeset, :completion_notes)

        updated_desc =
          if notes,
            do: "#{current_desc}

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Risk management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
\n\nCOMPLETION NOTES: #{notes}",
            else: current_desc

        Ash.Changeset.change_attribute(changeset, :treatment_description, updated_desc)
      end
    end

    update :schedule_effectiveness_review do
      require_atomic? false

      argument :review_date, :date do
        allow_nil? false
      end

      change set_attribute(:effectiveness_review_date, arg(:review_date))
    end

    update :review_effectiveness do
      require_atomic? false

      argument :reviewed_by_id, :uuid do
        allow_nil? false
      end

      argument :review_findings, :string do
        allow_nil? false
      end

      change set_attribute(:treatment_status, :reviewed)
      change set_attribute(:reviewed_by_id, arg(:reviewed_by_id))

      change fn changeset, _ ->
        current_desc = changeset.data.treatment_description
        findings = Ash.Changeset.get_argument(changeset, :review_findings)
        updated_desc = "#{current_desc}\n\nEFFECTIVENESS REVIEW: #{findings}"
        Ash.Changeset.change_attribute(changeset, :treatment_description, updated_desc)
      end
    end

    update :close_treatment do
      require_atomic? false

      argument :closure_reason, :string do
        allow_nil? false
      end

      change set_attribute(:treatment_status, :closed)

      change fn changeset, _ ->
        current_desc = changeset.data.treatment_description
        reason = Ash.Changeset.get_argument(changeset, :closure_reason)
        updated_desc = "#{current_desc}\n\nCLOSED: #{reason}"
        Ash.Changeset.change_attribute(changeset, :treatment_description, updated_desc)
      end
    end

    update :update_schedule do
      require_atomic? false

      argument :start_date, :date do
        allow_nil? false
      end

      argument :completion_date, :date do
        allow_nil? false
      end

      change set_attribute(:planned_start_date, arg(:start_date))
      change set_attribute(:planned_completion_date, arg(:completion_date))
    end

    update :assign_resources do
      require_atomic? false

      argument :resources, {:array, :string} do
        allow_nil? false
      end

      change set_attribute(:resources_assigned, arg(:resources))
    end
  end

  validations do
    validate compare(:planned_completion_date,
               greater_than: :planned_start_date
             ),
             message: "Completion date must be after start date",
             where: [present([:planned_start_date, :planned_completion_date])]
  end

  code_interface do
    define :create
    define :plan_treatment
    define :conduct_cost_benefit_analysis
    define :approve_treatment
    define :start_treatment
    define :complete_treatment
    define :schedule_effectiveness_review
    define :review_effectiveness
    define :close_treatment
    define :update_schedule
    define :assign_resources
  end

  postgres do
    table "risk_treatments"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :risk_id]
      index [:tenant_id, :treatment_strategy]
      index [:tenant_id, :treatment_status]
      index [:tenant_id, :implementation_priority]
      index [:tenant_id, :treatment_owner_id]

      index [:tenant_id, :planned_completion_date],
        where: "planned_completion_date IS NOT NULL"

      index [:tenant_id, :effectiveness_review_date],
        where: "effectiveness_review_date IS NOT NULL"

      index [:tenant_id, :stakeholder_approval]
    end
  end
end
