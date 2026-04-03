defmodule Indrajaal.Compliance.Framework do
  @moduledoc """
  Represents compliance frameworks and standards.

  Frameworks define the regulatory, industry, or organizational standards that
  must be adhered to. They provide the structure for compliance _requirements,
  assessment criteria, and reporting obligations.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.RiskManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Framework identification
    attribute :framework_code, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :framework_name, :string do
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :description, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :version, :string do
      allow_nil? false
      public? true
      constraints max_length: 20
      default "1.0"
    end

    # Framework classification
    attribute :framework_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :regulatory,
                    :industry_standard,
                    :best_practice,
                    :certification,
                    :internal_policy,
                    :contractual,
                    :international,
                    :national
                  ]

      default :regulatory
    end

    attribute :category, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :security,
                    :privacy,
                    :data_protection,
                    :financial,
                    :safety,
                    :environmental,
                    :quality,
                    :operational,
                    :governance
                  ]

      default :security
    end

    attribute :industry_sector, :atom do
      public? true

      constraints one_of: [
                    :financial_services,
                    :healthcare,
                    :government,
                    :education,
                    :technology,
                    :manufacturing,
                    :retail,
                    :energy,
                    :telecommunications
                  ]
    end

    # Regulatory information
    attribute :regulatory_body, :string do
      public? true
      constraints max_length: 200
    end

    attribute :jurisdiction, :string do
      public? true
      constraints max_length: 100
    end

    attribute :legal_basis, :string do
      public? true
      constraints max_length: 500
    end

    attribute :enforcement_authority, :string do
      public? true
      constraints max_length: 200
    end

    # Applicability and scope
    attribute :applicability_criteria, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :scope_description, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :covered_domains, {:array, :string} do
      public? true
      default []
    end

    attribute :excluded_areas, {:array, :string} do
      public? true
      default []
    end

    # Compliance _requirements
    attribute :total_requirements, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :mandatory_requirements, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :optional_requirements, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    # Implementation timeline
    attribute :effective_date, :date do
      public? true
    end

    attribute :implementation_deadline, :date do
      public? true
    end

    attribute :grace_period_months, :integer do
      public? true
      constraints min: 0, max: 60
    end

    attribute :transition_period_end, :date do
      public? true
    end

    # Assessment and certification
    attribute :assessment_f_requency, :atom do
      public? true

      constraints one_of: [
                    :annual,
                    :biennial,
                    :triennial,
                    :continuous,
                    :on_demand,
                    :_event_driven
                  ]
    end

    attribute :certification_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :certification_body, :string do
      public? true
      constraints max_length: 200
    end

    attribute :certification_validity_years, :integer do
      public? true
      constraints min: 1, max: 10
    end

    attribute :self_assessment_allowed?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    # Penalties and enforcement
    attribute :penalty_structure, :map do
      public? true
      default %{}
    end

    attribute :max_financial_penalty, :float do
      public? true
      constraints min: 0
    end

    attribute :penalty_currency, :string do
      public? true
      constraints max_length: 3
      default "USD"
    end

    attribute :non_compliance_consequences, :string do
      public? true
      constraints max_length: 2000
    end

    # Reporting _requirements
    attribute :reporting_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :reporting_f_requency, :atom do
      public? true

      constraints one_of: [
                    :monthly,
                    :quarterly,
                    :semi_annual,
                    :annual,
                    :ad_hoc,
                    :incident_based
                  ]
    end

    attribute :reporting_deadline_days, :integer do
      public? true
      constraints min: 1, max: 365
    end

    attribute :report_format_requirements, :string do
      public? true
      constraints max_length: 1000
    end

    # Framework relationships
    attribute :parent_framework_id, :uuid do
      public? true
    end

    attribute :superseded_framework_id, :uuid do
      public? true
    end

    attribute :related_frameworks, {:array, :uuid} do
      public? true
      default []
    end

    attribute :conflicting_frameworks, {:array, :uuid} do
      public? true
      default []
    end

    # Implementation status
    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :draft,
                    :active,
                    :deprecated,
                    :superseded,
                    :under_review,
                    :suspended
                  ]

      default :draft
    end

    attribute :implementation_status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :not_started,
                    :planning,
                    :in_progress,
                    :implemented,
                    :verified,
                    :certified
                  ]

      default :not_started
    end

    attribute :compliance_percentage, :float do
      public? true
      constraints min: 0, max: 100
    end

    attribute :last_assessment_date, :date do
      public? true
    end

    attribute :next_assessment_due, :date do
      public? true
    end

    # Risk and impact
    attribute :risk_level, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    attribute :business_impact, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    attribute :implementation_complexity, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :medium, :high, :very_high]
      default :medium
    end

    # Costs and resources
    attribute :estimated_implementation_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :annual_compliance_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :_required_resources, {:array, :string} do
      public? true
      default []
    end

    attribute :skilled_personnel_required, :integer do
      public? true
      constraints min: 0
    end

    # Documentation and references
    attribute :official_documentation_url, :string do
      public? true
      constraints max_length: 500
    end

    attribute :guidance_documents, {:array, :string} do
      public? true
      default []
    end

    attribute :reference_materials, {:array, :string} do
      public? true
      default []
    end

    attribute :training_materials, {:array, :string} do
      public? true
      default []
    end

    # Contact and support
    attribute :framework_owner_id, :uuid do
      public? true
    end

    attribute :compliance_officer_id, :uuid do
      public? true
    end

    attribute :support_contact, :string do
      public? true
      constraints max_length: 200
    end

    attribute :vendor_support_available?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Monitoring and alerts
    attribute :monitoring_enabled?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :alert_thresholds, :map do
      public? true
      default %{}
    end

    attribute :notification_recipients, {:array, :string} do
      public? true
      default []
    end

    # Change management
    attribute :change_log, {:array, :map} do
      public? true
      default []
    end

    attribute :last_updated_by, :uuid do
      public? true
    end

    attribute :approval_required?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :approved_by, :uuid do
      public? true
    end

    attribute :approval_date, :date do
      public? true
    end

    # Metadata
    attribute :keywords, {:array, :string} do
      public? true
      default []
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    attribute :tags, {:array, :string} do
      public? true
      default []
    end

    timestamps()
  end

  relationships do
    belongs_to :parent_framework, Indrajaal.Compliance.Framework do
      attribute_public? true
    end

    belongs_to :superseded_framework, Indrajaal.Compliance.Framework do
      attribute_public? true
    end

    belongs_to :framework_owner, Indrajaal.Accounts.User do
      attribute_public? true
    end

    belongs_to :compliance_officer, Indrajaal.Accounts.User do
      attribute_public? true
    end

    belongs_to :last_updated_by_user, Indrajaal.Accounts.User do
      source_attribute :last_updated_by
      attribute_public? true
    end

    belongs_to :approved_by_user, Indrajaal.Accounts.User do
      source_attribute :approved_by
      attribute_public? true
    end

    has_many :_requirements, Indrajaal.Compliance.Requirement
    has_many :assessments, Indrajaal.Compliance.Assessment
    has_many :reports, Indrajaal.Compliance.Report
    has_many :documents, Indrajaal.Compliance.Document

    has_many :child_frameworks, Indrajaal.Compliance.Framework do
      source_attribute :id
      destination_attribute :parent_framework_id
    end
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :framework_code,
        :framework_name,
        :description,
        :version,
        :framework_type,
        :category,
        :industry_sector,
        :regulatory_body,
        :jurisdiction,
        :legal_basis,
        :enforcement_authority,
        :applicability_criteria,
        :scope_description,
        :covered_domains,
        :excluded_areas,
        :effective_date,
        :implementation_deadline,
        :grace_period_months,
        :transition_period_end,
        :assessment_f_requency,
        :certification_required?,
        :certification_body,
        :certification_validity_years,
        :self_assessment_allowed?,
        :penalty_structure,
        :max_financial_penalty,
        :penalty_currency,
        :non_compliance_consequences,
        :reporting_required?,
        :reporting_f_requency,
        :reporting_deadline_days,
        :report_format_requirements,
        :parent_framework_id,
        :superseded_framework_id,
        :related_frameworks,
        :conflicting_frameworks,
        :risk_level,
        :business_impact,
        :implementation_complexity,
        :estimated_implementation_cost,
        :annual_compliance_cost,
        :_required_resources,
        :skilled_personnel_required,
        :official_documentation_url,
        :guidance_documents,
        :reference_materials,
        :training_materials,
        :framework_owner_id,
        :compliance_officer_id,
        :support_contact,
        :vendor_support_available?,
        :monitoring_enabled?,
        :alert_thresholds,
        :notification_recipients,
        :approval_required?,
        :keywords,
        :metadata
      ]

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :draft)
        |> Ash.Changeset.force_change_attribute(
          :implementation_status,
          :not_started
        )
        |> Ash.Changeset.force_change_attribute(:compliance_percentage, 0.0)
      end
    end

    update :activate do
      require_atomic? false
      accept []

      validate attribute_equals(:status, :draft)

      change set_attribute(:status, :active)
    end

    update :deprecate do
      require_atomic? false
      accept []

      argument :reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      validate attribute_equals(:status, :active)

      change fn changeset, _context ->
        reason = changeset.arguments.reason

        change_entry = %{
          "action" => "deprecated",
          "reason" => reason,
          "timestamp" => DateTime.utc_now(),
          # Would be set from _context in real implementation
          "user_id" => nil
        }

        change_log = Ash.Changeset.get_attribute(changeset, :change_log) || []

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :deprecated)
        |> Ash.Changeset.force_change_attribute(
          :change_log,
          [change_entry | change_log]
        )
      end
    end

    update :supersede do
      require_atomic? false
      accept [:superseded_framework_id]

      argument :new_framework_id, :uuid do
        allow_nil? false
      end

      argument :supersession_reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      validate attribute_equals(:status, :active)

      change fn changeset, _context ->
        new_framework_id = changeset.arguments.new_framework_id
        reason = changeset.arguments.supersession_reason

        change_entry = %{
          "action" => "superseded",
          "new_framework_id" => new_framework_id,
          "reason" => reason,
          "timestamp" => DateTime.utc_now(),
          "user_id" => nil
        }

        change_log = Ash.Changeset.get_attribute(changeset, :change_log) || []

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :superseded)
        |> Ash.Changeset.force_change_attribute(
          :superseded_framework_id,
          new_framework_id
        )
        |> Ash.Changeset.force_change_attribute(
          :change_log,
          [change_entry | change_log]
        )
      end
    end

    update :update_implementation_status do
      require_atomic? false
      accept [:implementation_status, :compliance_percentage]

      argument :status, :atom do
        allow_nil? false

        constraints one_of: [
                      :not_started,
                      :planning,
                      :in_progress,
                      :implemented,
                      :verified,
                      :certified
                    ]
      end

      argument :percentage, :float do
        constraints min: 0, max: 100
      end
    end

    update :update_requirements_count do
      require_atomic? false
      accept [:total_requirements, :mandatory_requirements, :optional_requirements]

      argument :total, :integer do
        allow_nil? false
        constraints min: 0
      end

      argument :mandatory, :integer do
        allow_nil? false
        constraints min: 0
      end

      change fn changeset, _context ->
        total = changeset.arguments.total
        mandatory = changeset.arguments.mandatory
        optional = total - mandatory

        changeset
        |> Ash.Changeset.force_change_attribute(:total_requirements, total)
        |> Ash.Changeset.force_change_attribute(
          :mandatory_requirements,
          mandatory
        )
        |> Ash.Changeset.force_change_attribute(
          :optional_requirements,
          optional
        )
      end
    end

    update :record_assessment do
      require_atomic? false
      accept [:last_assessment_date, :next_assessment_due, :compliance_percentage]

      argument :assessment_date, :date do
        allow_nil? false
      end

      argument :compliance_score, :float do
        allow_nil? false
        constraints min: 0, max: 100
      end

      change fn changeset, _context ->
        assessment_date = changeset.arguments.assessment_date
        score = changeset.arguments.compliance_score

        f_requency =
          Ash.Changeset.get_attribute(
            changeset,
            :assessment_f_requency
          )

        next_due =
          case f_requency do
            :annual -> Date.add(assessment_date, 365)
            :biennial -> Date.add(assessment_date, 730)
            :triennial -> Date.add(assessment_date, 1095)
            _ -> nil
          end

        _changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(
            :last_assessment_date,
            assessment_date
          )
          |> Ash.Changeset.force_change_attribute(:compliance_percentage, score)

        if next_due do
          Ash.Changeset.force_change_attribute(changeset, :next_assessment_due, next_due)
        else
          changeset
        end
      end
    end

    update :approve do
      require_atomic? false
      accept [:approved_by, :approval_date]

      argument :approved_by, :uuid do
        allow_nil? false
      end

      validate attribute_equals(:approval_required?, true)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(
          :approved_by,
          changeset.arguments.approved_by
        )
        |> Ash.Changeset.force_change_attribute(
          :approval_date,
          Date.utc_today()
        )
      end
    end

    update :add_change_log_entry do
      require_atomic? false
      accept [:change_log, :last_updated_by]

      argument :action_type, :string do
        allow_nil? false
        constraints max_length: 100
      end

      argument :description, :string do
        allow_nil? false
        constraints max_length: 500
      end

      argument :user_id, :uuid do
        allow_nil? false
      end

      change fn changeset, _context ->
        change_log = Ash.Changeset.get_attribute(changeset, :change_log) || []

        new_entry = %{
          "action" => changeset.arguments.action_type,
          "description" => changeset.arguments.description,
          "timestamp" => DateTime.utc_now(),
          "user_id" => changeset.arguments.user_id
        }

        changeset
        |> Ash.Changeset.force_change_attribute(
          :change_log,
          [new_entry | change_log]
        )
        |> Ash.Changeset.force_change_attribute(
          :last_updated_by,
          changeset.arguments.user_id
        )
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :is_active?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn framework ->
              framework.status == :active
            end
          )

        {:ok, values}
      end
    end

    calculate :is_overdue_assessment?, :boolean do
      calculation fn records, _context ->
        today = Date.utc_today()

        values =
          Enum.map(
            records,
            fn framework ->
              framework.next_assessment_due &&
                Date.compare(
                  today,
                  framework.next_assessment_due
                ) == :gt
            end
          )

        {:ok, values}
      end
    end

    calculate :days_until_assessment, :integer do
      calculation fn records, _context ->
        today = Date.utc_today()

        values =
          Enum.map(
            records,
            fn framework ->
              if framework.next_assessment_due do
                Date.diff(
                  framework.next_assessment_due,
                  today
                )
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :implementation_progress_status, :string do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn framework ->
              percentage = framework.compliance_percentage || 0.0

              cond do
                percentage >= 100.0 -> "Complete"
                percentage >= 75.0 -> "Near Complete"
                percentage >= 50.0 -> "In Progress"
                percentage >= 25.0 -> "Started"
                percentage > 0.0 -> "Initial"
                true -> "Not Started"
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :risk_score, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn framework ->
              risk_weight =
                case framework.risk_level do
                  :critical -> 4
                  :high -> 3
                  :medium -> 2
                  :low -> 1
                  _ -> 2
                end

              impact_weight =
                case framework.business_impact do
                  :critical -> 4
                  :high -> 3
                  :medium -> 2
                  :low -> 1
                  _ -> 2
                end

              complexity_weight =
                case framework.implementation_complexity do
                  :very_high -> 4
                  :high -> 3
                  :medium -> 2
                  :low -> 1
                  _ -> 2
                end

              # Compliance reduces risk
              compliance_factor =
                1.0 -
                  (framework.compliance_percentage ||
                     0.0) / 100.0

              base_score =
                (risk_weight + impact_weight + complexity_weight) *
                  10

              adjusted_score = base_score * compliance_factor

              round(adjusted_score)
            end
          )

        {:ok, values}
      end
    end

    calculate :total_estimated_cost, :float do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn framework ->
              implementation_cost =
                framework.estimated_implementation_cost ||
                  0.0

              annual_cost = framework.annual_compliance_cost || 0.0

              # Assume 3 - year lifecycle for total cost estimation
              implementation_cost + annual_cost * 3.0
            end
          )

        {:ok, values}
      end
    end
  end

  policies do
    bypass always() do
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "auditor")
      authorize_if actor_attribute_equals(:role, "manager")
      authorize_if actor_attribute_equals(:role, "legal")
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "legal")
    end

    policy action([:activate, :deprecate, :supersede]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
    end

    policy action(:approve) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "legal")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
    end

    policy action([:update_implementation_status, :record_assessment]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "auditor")
      # Framework owner can update their frameworks
      authorize_if expr(framework_owner_id == ^actor(:id))
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :activate
    define :deprecate
    define :supersede
    define :update_implementation_status
    define :update_requirements_count
    define :record_assessment
    define :approve
    define :add_change_log_entry
    define :destroy
  end

  postgres do
    table "compliance_frameworks"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :framework_code], unique: true
      index [:parent_framework_id], where: "parent_framework_id IS NOT NULL"

      index [:superseded_framework_id],
        where: "superseded_framework_id IS NOT NULL"

      index [:framework_owner_id], where: "framework_owner_id IS NOT NULL"
      index [:compliance_officer_id], where: "compliance_officer_id IS NOT NULL"
      index [:approved_by], where: "approved_by IS NOT NULL"
      index [:framework_type]
      index [:category]
      index [:industry_sector], where: "industry_sector IS NOT NULL"
      index [:status]
      index [:implementation_status]
      index [:risk_level]
      index [:business_impact]
      index [:effective_date], where: "effective_date IS NOT NULL"

      index [:implementation_deadline],
        where: "implementation_deadline IS NOT NULL"

      index [:last_assessment_date], where: "last_assessment_date IS NOT NULL"
      index [:next_assessment_due], where: "next_assessment_due IS NOT NULL"

      index [:certification_required?],
        name: "frameworks_certification_required_index",
        where: "certification_required? = true"

      index [:reporting_required?],
        name: "frameworks_reporting_required_index",
        where: "reporting_required? = true"

      index [:monitoring_enabled?],
        name: "frameworks_monitoring_enabled_index",
        where: "monitoring_enabled? = true"

      index [:approval_required?],
        name: "frameworks_approval_required_index",
        where: "approval_required? = true"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Compliance
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
