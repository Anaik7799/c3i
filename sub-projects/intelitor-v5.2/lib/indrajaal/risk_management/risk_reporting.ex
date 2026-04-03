defmodule Indrajaal.RiskManagement.RiskReporting do
  @moduledoc """
  Risk reporting and dashboard management for executive and regulatory
    reporting.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.RiskManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :report_name, :string do
      allow_nil? false
      constraints max_length: 200
    end

    attribute :report_type, :atom do
      constraints one_of: [
                    :executive_summary,
                    :detailed_risk_register,
                    :compliance_report,
                    :incident_summary,
                    :kpi_dashboard,
                    :regulatory_filing
                  ]

      allow_nil? false
    end

    attribute :report_f_requency, :atom do
      constraints one_of: [:ad_hoc, :weekly, :monthly, :quarterly, :semi_annually, :annually]
      allow_nil? false
    end

    attribute :report_period_start, :date do
      allow_nil? false
    end

    attribute :report_period_end, :date do
      allow_nil? false
    end

    attribute :generated_date, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :report_status, :atom do
      constraints one_of: [:draft, :review, :approved, :published, :archived]
      default :draft
    end

    attribute :report_scope, :string do
      constraints max_length: 1000
    end

    attribute :included_risk_categories, {:array, :uuid} do
      default []
    end

    attribute :included_risk_levels, {:array, :atom} do
      default [:high, :critical]
    end

    attribute :key_metrics, :map do
      default %{}
    end

    attribute :executive_summary, :string do
      constraints max_length: 3000
    end

    attribute :key_findings, {:array, :string} do
      default []
    end

    attribute :recommendations, {:array, :string} do
      default []
    end

    attribute :trends_analysis, :string do
      constraints max_length: 2000
    end

    attribute :compliance_status, :map do
      default %{}
    end

    attribute :action_items, {:array, :map} do
      default []
    end

    attribute :next_report_date, :date

    attribute :distribution_list, {:array, :uuid} do
      default []
    end

    attribute :confidentiality_level, :atom do
      constraints one_of: [:public, :internal, :confidential, :restricted]
      default :confidential
    end

    attribute :regulatory_requirements, {:array, :string} do
      default []
    end

    timestamps()
  end

  relationships do
    belongs_to :generated_by, Indrajaal.Accounts.User do
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
    calculate :report_age_days, :integer do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          DateTime.diff(now, record.generated_date, :day)
        end)
      end
    end

    calculate :coverage_percentage, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case record.key_metrics do
            %{"total_risks" => total, "covered_risks" => covered} when total > 0 ->
              Decimal.div(Decimal.mult(covered, 100), total)

            _ ->
              Decimal.new(0)
          end
        end)
      end
    end

    calculate :is_overdue, :boolean do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          case record.next_report_date do
            nil -> false
            next_date -> Date.compare(today, next_date) == :gt
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :generate_report do
      argument :report_name, :string do
        allow_nil? false
      end

      argument :report_type, :atom do
        allow_nil? false
      end

      argument :f_requency, :atom do
        allow_nil? false
      end

      argument :period_start, :date do
        allow_nil? false
      end

      argument :period_end, :date do
        allow_nil? false
      end

      argument :generated_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:report_name, arg(:report_name))
      change set_attribute(:report_type, arg(:report_type))
      change set_attribute(:report_f_requency, arg(:f_requency))
      change set_attribute(:report_period_start, arg(:period_start))
      change set_attribute(:report_period_end, arg(:period_end))
      change set_attribute(:generated_by_id, arg(:generated_by_id))
    end

    update :add_executive_summary do
      require_atomic? false

      argument :summary, :string do
        allow_nil? false
      end

      argument :key_findings, {:array, :string} do
        allow_nil? false
      end

      change set_attribute(:executive_summary, arg(:summary))
      change set_attribute(:key_findings, arg(:key_findings))
    end

    update :add_metrics do
      require_atomic? false

      argument :metrics, :map do
        allow_nil? false
      end

      change set_attribute(:key_metrics, arg(:metrics))
    end

    update :add_trends_analysis do
      require_atomic? false

      argument :trends, :string do
        allow_nil? false
      end

      argument :recommendations, {:array, :string}

      change set_attribute(:trends_analysis, arg(:trends))
      change set_attribute(:recommendations, arg(:recommendations))
    end

    update :add_compliance_status do
      require_atomic? false

      argument :compliance_data, :map do
        allow_nil? false
      end

      argument :regulatory_requirements, {:array, :string}

      change set_attribute(:compliance_status, arg(:compliance_data))

      change set_attribute(
               :regulatory_requirements,
               arg(:regulatory_requirements)
             )
    end

    update :submit_for_review do
      require_atomic? false

      argument :reviewed_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:report_status, :review)
      change set_attribute(:reviewed_by_id, arg(:reviewed_by_id))
    end

    update :approve_report do
      require_atomic? false

      argument :approved_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:report_status, :approved)
      change set_attribute(:approved_by_id, arg(:approved_by_id))
    end

    update :publish_report do
      require_atomic? false

      argument :distribution_list, {:array, :uuid} do
        allow_nil? false
      end

      change set_attribute(:report_status, :published)
      change set_attribute(:distribution_list, arg(:distribution_list))
    end

    update :archive_report do
      require_atomic? false
      change set_attribute(:report_status, :archived)
    end

    update :schedule_next_report do
      require_atomic? false

      argument :next_date, :date do
        allow_nil? false
      end

      change set_attribute(:next_report_date, arg(:next_date))
    end

    update :add_action_items do
      require_atomic? false

      argument :action_items, {:array, :map} do
        allow_nil? false
      end

      change set_attribute(:action_items, arg(:action_items))
    end

    update :set_confidentiality do
      require_atomic? false

      argument :level, :atom do
        allow_nil? false
      end

      change set_attribute(:confidentiality_level, arg(:level))
    end

    update :update_scope do
      require_atomic? false

      argument :scope_description, :string do
        allow_nil? false
      end

      argument :risk_categories, {:array, :uuid}
      argument :risk_levels, {:array, :atom}

      change set_attribute(:report_scope, arg(:scope_description))
      change set_attribute(:included_risk_categories, arg(:risk_categories))
      change set_attribute(:included_risk_levels, arg(:risk_levels))
    end
  end

  validations do
    validate compare(:report_period_end, greater_than: :report_period_start),
      message: "Report period end must be after start date"
  end

  code_interface do
    define :create
    define :generate_report
    define :add_executive_summary
    define :add_metrics
    define :add_trends_analysis
    define :add_compliance_status
    define :submit_for_review
    define :approve_report
    define :publish_report
    define :archive_report
    define :schedule_next_report
    define :add_action_items
    define :set_confidentiality
    define :update_scope
  end

  postgres do
    table "risk_reporting"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :report_type]
      index [:tenant_id, :report_f_requency]
      index [:tenant_id, :report_status]
      index [:tenant_id, :generated_date]
      index [:tenant_id, :report_period_start, :report_period_end]
      index [:tenant_id, :generated_by_id]

      index [:tenant_id, :next_report_date],
        where: "next_report_date IS NOT NULL"

      index [:tenant_id, :confidentiality_level]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Risk management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
