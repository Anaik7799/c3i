defmodule Indrajaal.RiskManagement.Risk do
  @moduledoc """
  Core risk register with identification, classification, and tracking.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.RiskManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :risk_id, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :title, :string do
      allow_nil? false
      constraints max_length: 200
    end

    attribute :description, :string do
      allow_nil? false
      constraints max_length: 2000
    end

    attribute :risk_source, :atom do
      constraints one_of: [:internal, :external, :regulatory, :technological, :human, :natural]
      allow_nil? false
    end

    attribute :risk_status, :atom do
      constraints one_of: [
                    :identified,
                    :assessed,
                    :treatment_planned,
                    :treatment_active,
                    :monitored,
                    :closed
                  ]

      default :identified
    end

    attribute :inherent_probability, :integer do
      constraints min: 1, max: 5
    end

    attribute :inherent_impact, :integer do
      constraints min: 1, max: 5
    end

    attribute :inherent_risk_score, :integer

    attribute :residual_probability, :integer do
      constraints min: 1, max: 5
    end

    attribute :residual_impact, :integer do
      constraints min: 1, max: 5
    end

    attribute :residual_risk_score, :integer

    attribute :target_probability, :integer do
      constraints min: 1, max: 5
    end

    attribute :target_impact, :integer do
      constraints min: 1, max: 5
    end

    attribute :target_risk_score, :integer

    attribute :potential_consequences, {:array, :string} do
      default []
    end

    attribute :affected_assets, {:array, :uuid} do
      default []
    end

    attribute :affected_processes, {:array, :string} do
      default []
    end

    attribute :regulatory_implications, {:array, :string} do
      default []
    end

    attribute :identified_date, :date do
      allow_nil? false
      default Date.utc_today()
    end

    attribute :last_reviewed_date, :date
    attribute :next_review_date, :date

    timestamps()
  end

  relationships do
    belongs_to :category, Indrajaal.RiskManagement.RiskCategory do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :risk_owner, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :identified_by, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    has_many :assessments, Indrajaal.RiskManagement.RiskAssessment do
      destination_attribute :risk_id
    end

    has_many :mitigations, Indrajaal.RiskManagement.RiskMitigation do
      destination_attribute :risk_id
    end

    has_many :incidents, Indrajaal.RiskManagement.RiskIncident do
      destination_attribute :risk_id
    end

    has_many :controls, Indrajaal.RiskManagement.RiskControl do
      destination_attribute :risk_id
    end

    has_many :treatments, Indrajaal.RiskManagement.RiskTreatment do
      destination_attribute :risk_id
    end
  end

  calculations do
    calculate :inherent_risk_level, :atom do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          score = record.inherent_risk_score || 0

          cond do
            score >= 20 -> :critical
            score >= 15 -> :high
            score >= 10 -> :medium
            score >= 5 -> :low
            true -> :minimal
          end
        end)
      end
    end

    calculate :residual_risk_level, :atom do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          score = record.residual_risk_score || 0

          cond do
            score >= 20 -> :critical
            score >= 15 -> :high
            score >= 10 -> :medium
            score >= 5 -> :low
            true -> :minimal
          end
        end)
      end
    end

    calculate :risk_treatment_effectiveness, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          inherent = record.inherent_risk_score || 0
          residual = record.residual_risk_score || inherent

          if inherent > 0 do
            reduction = inherent - residual
            Decimal.div(Decimal.mult(reduction, 100), inherent)
          else
            Decimal.new(0)
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :update, :destroy]

    create :create do
      primary? true

      accept [
        :risk_id,
        :title,
        :description,
        :risk_source,
        :risk_status,
        :inherent_probability,
        :inherent_impact,
        :residual_probability,
        :residual_impact,
        :target_probability,
        :target_impact,
        :potential_consequences,
        :affected_assets,
        :affected_processes,
        :regulatory_implications,
        :identified_date,
        :next_review_date,
        :last_reviewed_date,
        :category_id,
        :risk_owner_id,
        :identified_by_id
      ]
    end

    create :identify_risk do
      argument :risk_id, :string do
        allow_nil? false
      end

      argument :title, :string do
        allow_nil? false
      end

      argument :description, :string do
        allow_nil? false
      end

      argument :category_id, :uuid do
        allow_nil? false
      end

      argument :risk_owner_id, :uuid do
        allow_nil? false
      end

      argument :identified_by_id, :uuid do
        allow_nil? false
      end

      argument :risk_source, :atom do
        allow_nil? false
      end

      change set_attribute(:risk_id, arg(:risk_id))
      change set_attribute(:title, arg(:title))
      change set_attribute(:description, arg(:description))
      change set_attribute(:category_id, arg(:category_id))
      change set_attribute(:risk_owner_id, arg(:risk_owner_id))
      change set_attribute(:identified_by_id, arg(:identified_by_id))
      change set_attribute(:risk_source, arg(:risk_source))
    end

    update :assess_inherent_risk do
      require_atomic? false

      argument :probability, :integer do
        allow_nil? false
      end

      argument :impact, :integer do
        allow_nil? false
      end

      change set_attribute(:inherent_probability, arg(:probability))
      change set_attribute(:inherent_impact, arg(:impact))

      change fn changeset, _ ->
        prob = Ash.Changeset.get_argument(changeset, :probability)
        impact = Ash.Changeset.get_argument(changeset, :impact)
        score = prob * impact
        Ash.Changeset.change_attribute(changeset, :inherent_risk_score, score)
      end

      change set_attribute(:risk_status, :assessed)
    end

    update :assess_residual_risk do
      require_atomic? false

      argument :probability, :integer do
        allow_nil? false
      end

      argument :impact, :integer do
        allow_nil? false
      end

      change set_attribute(:residual_probability, arg(:probability))
      change set_attribute(:residual_impact, arg(:impact))

      change fn changeset, _ ->
        prob = Ash.Changeset.get_argument(changeset, :probability)
        impact = Ash.Changeset.get_argument(changeset, :impact)
        score = prob * impact
        Ash.Changeset.change_attribute(changeset, :residual_risk_score, score)
      end
    end

    update :set_target_risk do
      require_atomic? false

      argument :probability, :integer do
        allow_nil? false
      end

      argument :impact, :integer do
        allow_nil? false
      end

      change set_attribute(:target_probability, arg(:probability))
      change set_attribute(:target_impact, arg(:impact))

      change fn changeset, _ ->
        prob = Ash.Changeset.get_argument(changeset, :probability)
        impact = Ash.Changeset.get_argument(changeset, :impact)
        score = prob * impact
        Ash.Changeset.change_attribute(changeset, :target_risk_score, score)
      end
    end

    update :update_status do
      require_atomic? false

      argument :new_status, :atom do
        allow_nil? false
      end

      change set_attribute(:risk_status, arg(:new_status))
    end

    update :schedule_review do
      require_atomic? false

      argument :next_review_date, :date do
        allow_nil? false
      end

      change set_attribute(:last_reviewed_date, Date.utc_today())
      change set_attribute(:next_review_date, arg(:next_review_date))
    end

    update :close_risk do
      require_atomic? false

      argument :closure_reason, :string do
        allow_nil? false
      end

      change set_attribute(:risk_status, :closed)

      change fn changeset, _ ->
        current_desc = changeset.data.description
        reason = Ash.Changeset.get_argument(changeset, :closure_reason)
        updated_desc = "#{current_desc}

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Risk management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
\n\nCLOSED: #{reason}"
        Ash.Changeset.change_attribute(changeset, :description, updated_desc)
      end
    end
  end

  validations do
    validate compare(:residual_risk_score,
               less_than_or_equal_to: :inherent_risk_score
             ),
             message: "Residual risk cannot be higher than inherent risk"

    validate compare(:target_risk_score,
               less_than_or_equal_to: :residual_risk_score
             ),
             message: "Target risk should not be higher than residual risk"
  end

  code_interface do
    define :create
    define :identify_risk
    define :assess_inherent_risk
    define :assess_residual_risk
    define :set_target_risk
    define :update_status
    define :schedule_review
    define :close_risk
  end

  postgres do
    table "risks"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :risk_id], unique: true
      index [:tenant_id, :category_id]
      index [:tenant_id, :risk_status]
      index [:tenant_id, :risk_owner_id]
      index [:tenant_id, :inherent_risk_score]
      index [:tenant_id, :residual_risk_score]

      index [:tenant_id, :next_review_date],
        where: "next_review_date IS NOT NULL"

      index [:tenant_id, :identified_date]
    end
  end
end
