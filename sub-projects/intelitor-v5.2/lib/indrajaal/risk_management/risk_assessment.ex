defmodule Indrajaal.RiskManagement.RiskAssessment do
  @moduledoc """
  Detailed risk assessments with methodologies and documentation.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.RiskManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :assessment_type, :atom do
      constraints one_of: [
                    :initial,
                    :periodic,
                    :incident_triggered,
                    :change_triggered,
                    :audit_triggered
                  ]

      allow_nil? false
    end

    attribute :assessment_date, :date do
      allow_nil? false
      default &Date.utc_today/0
    end

    attribute :methodology, :atom do
      constraints one_of: [
                    :qualitative,
                    :quantitative,
                    :semi_quantitative,
                    :bow_tie,
                    :fmea,
                    :hazop
                  ]

      allow_nil? false
    end

    attribute :assessment_scope, :string do
      allow_nil? false
      constraints max_length: 1000
    end

    attribute :likelihood_analysis, :string do
      constraints max_length: 2000
    end

    attribute :impact_analysis, :string do
      constraints max_length: 2000
    end

    attribute :vulnerability_assessment, :string do
      constraints max_length: 2000
    end

    attribute :threat_analysis, :string do
      constraints max_length: 2000
    end

    attribute :control_effectiveness, :map do
      default %{}
    end

    attribute :assumptions, {:array, :string} do
      default []
    end

    attribute :limitations, {:array, :string} do
      default []
    end

    attribute :confidence_level, :atom do
      constraints one_of: [:very_low, :low, :medium, :high, :very_high]
      default :medium
    end

    attribute :assessment_findings, :string do
      constraints max_length: 3000
    end

    attribute :recommendations, {:array, :string} do
      default []
    end

    attribute :next_assessment_date, :date

    timestamps()
  end

  relationships do
    belongs_to :risk, Indrajaal.RiskManagement.Risk do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :assessor, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :reviewed_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    belongs_to :approved_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end
  end

  calculations do
    calculate :days_since_assessment, :integer do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          Date.diff(today, record.assessment_date)
        end)
      end
    end

    calculate :is_assessment_due, :boolean do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          case record.next_assessment_date do
            nil -> false
            next_date -> Date.compare(today, next_date) != :lt
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :conduct_assessment do
      argument :risk_id, :uuid do
        allow_nil? false
      end

      argument :assessment_type, :atom do
        allow_nil? false
      end

      argument :methodology, :atom do
        allow_nil? false
      end

      argument :assessor_id, :uuid do
        allow_nil? false
      end

      argument :scope, :string do
        allow_nil? false
      end

      change set_attribute(:risk_id, arg(:risk_id))
      change set_attribute(:assessment_type, arg(:assessment_type))
      change set_attribute(:methodology, arg(:methodology))
      change set_attribute(:assessor_id, arg(:assessor_id))
      change set_attribute(:assessment_scope, arg(:scope))
    end

    update :complete_analysis do
      require_atomic? false

      argument :likelihood_analysis, :string do
        allow_nil? false
      end

      argument :impact_analysis, :string do
        allow_nil? false
      end

      argument :findings, :string do
        allow_nil? false
      end

      argument :recommendations, {:array, :string}

      change set_attribute(:likelihood_analysis, arg(:likelihood_analysis))
      change set_attribute(:impact_analysis, arg(:impact_analysis))
      change set_attribute(:assessment_findings, arg(:findings))
      change set_attribute(:recommendations, arg(:recommendations))
    end

    update :add_vulnerability_assessment do
      require_atomic? false

      argument :vulnerability_details, :string do
        allow_nil? false
      end

      argument :threat_analysis, :string do
        allow_nil? false
      end

      change set_attribute(
               :vulnerability_assessment,
               arg(:vulnerability_details)
             )

      change set_attribute(:threat_analysis, arg(:threat_analysis))
    end

    update :evaluate_controls do
      require_atomic? false

      argument :control_effectiveness, :map do
        allow_nil? false
      end

      argument :confidence_level, :atom do
        allow_nil? false
      end

      change set_attribute(:control_effectiveness, arg(:control_effectiveness))
      change set_attribute(:confidence_level, arg(:confidence_level))
    end

    update :schedule_next_assessment do
      require_atomic? false

      argument :next_date, :date do
        allow_nil? false
      end

      change set_attribute(:next_assessment_date, arg(:next_date))
    end

    update :review_assessment do
      require_atomic? false

      argument :reviewed_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:reviewed_by_id, arg(:reviewed_by_id))
    end

    update :approve_assessment do
      require_atomic? false

      argument :approved_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:approved_by_id, arg(:approved_by_id))
    end
  end

  code_interface do
    define :create
    define :conduct_assessment
    define :complete_analysis
    define :add_vulnerability_assessment
    define :evaluate_controls
    define :schedule_next_assessment
    define :review_assessment
    define :approve_assessment
  end

  postgres do
    table "risk_assessments"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :risk_id]
      index [:tenant_id, :assessment_type]
      index [:tenant_id, :methodology]
      index [:tenant_id, :assessment_date]
      index [:tenant_id, :assessor_id]

      index [:tenant_id, :next_assessment_date],
        where: "next_assessment_date IS NOT NULL"

      index [:tenant_id, :confidence_level]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Risk management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
