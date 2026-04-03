defmodule Indrajaal.Compliance.Requirement do
  @moduledoc """
  Represents individual compliance _requirements within frameworks.

  Requirements define specific controls, procedures, or conditions that must
  be implemented and maintained to achieve compliance. They include detailed
  specifications, implementation guidance, and assessment criteria.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.RiskManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Requirement identification
    attribute :framework_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :_requirement_id, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :_requirement_number, :string do
      public? true
      constraints max_length: 20
    end

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :description, :string do
      allow_nil? false
      public? true
      constraints max_length: 5000
    end

    # Requirement classification
    attribute :_requirement_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :control,
                    :procedure,
                    :policy,
                    :documentation,
                    :technical,
                    :administrative,
                    :physical,
                    :training,
                    :monitoring,
                    :reporting
                  ]

      default :control
    end

    attribute :control_family, :atom do
      public? true

      constraints one_of: [
                    :access_control,
                    :awareness_training,
                    :audit_accountability,
                    :security_assessment,
                    :configuration_management,
                    :contingency_planning,
                    :identification_authentication,
                    :incident_response,
                    :maintenance,
                    :media_protection,
                    :physical_environmental,
                    :planning,
                    :personnel_security,
                    :risk_assessment,
                    :system_acquisition,
                    :system_communications,
                    :system_information_integrity
                  ]
    end

    attribute :category, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :security,
                    :privacy,
                    :data_protection,
                    :operational,
                    :governance,
                    :financial,
                    :safety,
                    :environmental,
                    :quality
                  ]

      default :security
    end

    # Requirement priority and criticality
    attribute :priority, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 10
      default 5
    end

    attribute :criticality, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    attribute :mandatory?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    # Implementation details
    attribute :implementation_guidance, :string do
      public? true
      constraints max_length: 10_000
    end

    attribute :implementation_examples, :string do
      public? true
      constraints max_length: 5000
    end

    attribute :technical_specifications, :map do
      public? true
      default %{}
    end

    attribute :acceptance_criteria, :string do
      public? true
      constraints max_length: 3000
    end

    # Dependencies and relationships
    attribute :pre_requisite_requirements, {:array, :uuid} do
      public? true
      default []
    end

    attribute :dependent_requirements, {:array, :uuid} do
      public? true
      default []
    end

    attribute :related_requirements, {:array, :uuid} do
      public? true
      default []
    end

    attribute :conflicting_requirements, {:array, :uuid} do
      public? true
      default []
    end

    # Scope and applicability
    attribute :applicable_systems, {:array, :string} do
      public? true
      default []
    end

    attribute :applicable_roles, {:array, :string} do
      public? true
      default []
    end

    attribute :exclusions, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :scope_limitations, :string do
      public? true
      constraints max_length: 1000
    end

    # Implementation timeline
    attribute :implementation_deadline, :date do
      public? true
    end

    attribute :estimated_effort_hours, :integer do
      public? true
      constraints min: 0
    end

    attribute :implementation_complexity, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :medium, :high, :very_high]
      default :medium
    end

    # Status and compliance
    attribute :implementation_status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :not_started,
                    :planning,
                    :in_progress,
                    :implemented,
                    :verified,
                    :compliant,
                    :non_compliant,
                    :partially_compliant,
                    :not_applicable
                  ]

      default :not_started
    end

    attribute :compliance_status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :compliant,
                    :non_compliant,
                    :partially_compliant,
                    :not_assessed,
                    :not_applicable
                  ]

      default :not_assessed
    end

    attribute :compliance_percentage, :float do
      public? true
      constraints min: 0, max: 100
    end

    # Assessment and validation
    attribute :assessment_method, :atom do
      public? true

      constraints one_of: [
                    :documentation_review,
                    :interview,
                    :observation,
                    :testing,
                    :automated_scan,
                    :penetration_test,
                    :vulnerability_assessment
                  ]
    end

    attribute :evidence_requirements, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :validation_procedures, :string do
      public? true
      constraints max_length: 3000
    end

    attribute :last_assessment_date, :date do
      public? true
    end

    attribute :next_assessment_due, :date do
      public? true
    end

    attribute :assessment_f_requency, :atom do
      public? true

      constraints one_of: [
                    :monthly,
                    :quarterly,
                    :semi_annual,
                    :annual,
                    :biennial,
                    :continuous
                  ]
    end

    # Assignment and ownership
    attribute :assigned_to, :uuid do
      public? true
    end

    attribute :responsible_party, :string do
      public? true
      constraints max_length: 200
    end

    attribute :accountable_party, :string do
      public? true
      constraints max_length: 200
    end

    attribute :consulted_parties, {:array, :string} do
      public? true
      default []
    end

    attribute :informed_parties, {:array, :string} do
      public? true
      default []
    end

    # Risk and impact
    attribute :risk_if_not_implemented, :atom do
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

    attribute :threat_scenarios, {:array, :string} do
      public? true
      default []
    end

    attribute :risk_mitigation_measures, :string do
      public? true
      constraints max_length: 2000
    end

    # Cost and resources
    attribute :implementation_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :ongoing_cost_annual, :float do
      public? true
      constraints min: 0
    end

    attribute :_required_resources, {:array, :string} do
      public? true
      default []
    end

    attribute :_required_skills, {:array, :string} do
      public? true
      default []
    end

    attribute :training_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Monitoring and measurement
    attribute :monitoring_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :metrics, {:array, :map} do
      public? true
      default []
    end

    attribute :performance_indicators, :map do
      public? true
      default %{}
    end

    attribute :alert_conditions, {:array, :string} do
      public? true
      default []
    end

    # Documentation and references
    attribute :reference_documents, {:array, :string} do
      public? true
      default []
    end

    attribute :implementation_templates, {:array, :string} do
      public? true
      default []
    end

    attribute :best_practices, :string do
      public? true
      constraints max_length: 3000
    end

    attribute :common_pitfalls, :string do
      public? true
      constraints max_length: 2000
    end

    # Automation and tooling
    attribute :automation_possible?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :recommended_tools, {:array, :string} do
      public? true
      default []
    end

    attribute :integration_requirements, :string do
      public? true
      constraints max_length: 1000
    end

    # Compliance tracking
    attribute :findings, {:array, :map} do
      public? true
      default []
    end

    attribute :exceptions, {:array, :map} do
      public? true
      default []
    end

    attribute :compensating_controls, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :remediation_plan, :string do
      public? true
      constraints max_length: 3000
    end

    attribute :remediation_deadline, :date do
      public? true
    end

    # Change management
    attribute :version, :string do
      allow_nil? false
      public? true
      constraints max_length: 20
      default "1.0"
    end

    attribute :change_history, {:array, :map} do
      public? true
      default []
    end

    attribute :last_updated_by, :uuid do
      public? true
    end

    attribute :review_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :reviewed_by, :uuid do
      public? true
    end

    attribute :review_date, :date do
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
    belongs_to :framework, Indrajaal.Compliance.Framework do
      attribute_public? true
    end

    belongs_to :assigned_to_user, Indrajaal.Accounts.User do
      source_attribute :assigned_to
      attribute_public? true
    end

    belongs_to :last_updated_by_user, Indrajaal.Accounts.User do
      source_attribute :last_updated_by
      attribute_public? true
    end

    belongs_to :reviewed_by_user, Indrajaal.Accounts.User do
      source_attribute :reviewed_by
      attribute_public? true
    end

    has_many :assessments, Indrajaal.Compliance.Assessment do
      destination_attribute :_requirement_id
    end

    has_many :documents, Indrajaal.Compliance.Document do
      destination_attribute :_requirement_id
    end
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :framework_id,
        :_requirement_id,
        :_requirement_number,
        :title,
        :description,
        :_requirement_type,
        :control_family,
        :category,
        :priority,
        :criticality,
        :mandatory?,
        :implementation_guidance,
        :implementation_examples,
        :technical_specifications,
        :acceptance_criteria,
        :pre_requisite_requirements,
        :dependent_requirements,
        :related_requirements,
        :conflicting_requirements,
        :applicable_systems,
        :applicable_roles,
        :exclusions,
        :scope_limitations,
        :implementation_deadline,
        :estimated_effort_hours,
        :implementation_complexity,
        :assessment_method,
        :evidence_requirements,
        :validation_procedures,
        :assessment_f_requency,
        :responsible_party,
        :accountable_party,
        :consulted_parties,
        :informed_parties,
        :risk_if_not_implemented,
        :business_impact,
        :threat_scenarios,
        :risk_mitigation_measures,
        :implementation_cost,
        :ongoing_cost_annual,
        :_required_resources,
        :_required_skills,
        :training_required?,
        :monitoring_required?,
        :metrics,
        :performance_indicators,
        :alert_conditions,
        :reference_documents,
        :implementation_templates,
        :best_practices,
        :common_pitfalls,
        :automation_possible?,
        :recommended_tools,
        :integration_requirements,
        :compensating_controls,
        :version,
        :keywords,
        :metadata
      ]
    end

    update :assign do
      accept [:assigned_to]
      require_atomic? false

      argument :user_id, :uuid do
        allow_nil? false
      end
    end

    update :update_implementation_status do
      accept [:implementation_status, :compliance_percentage]
      require_atomic? false

      argument :status, :atom do
        allow_nil? false

        constraints one_of: [
                      :not_started,
                      :planning,
                      :in_progress,
                      :implemented,
                      :verified,
                      :compliant,
                      :non_compliant,
                      :partially_compliant,
                      :not_applicable
                    ]
      end

      argument :percentage, :float do
        constraints min: 0, max: 100
      end

      change fn changeset, _context ->
        status = changeset.arguments.status
        percentage = changeset.arguments.percentage

        # Auto - update compliance status based on implementation status
        compliance_status =
          case {status, percentage} do
            {:compliant, _} ->
              :compliant

            {:non_compliant, _} ->
              :non_compliant

            {:partially_compliant, _} ->
              :partially_compliant

            {:not_applicable, _} ->
              :not_applicable

            {:verified, _} ->
              :compliant

            {:implemented, p} when p != nil and p >= 100.0 ->
              :compliant

            {:implemented, p}
            when p != nil and p >= 50.0 ->
              :partially_compliant

            _ ->
              :not_assessed
          end

        changeset
        |> Ash.Changeset.force_change_attribute(:implementation_status, status)
        |> Ash.Changeset.force_change_attribute(:compliance_status, compliance_status)
        |> apply_compliance_percentage(percentage)
      end
    end

    update :record_assessment do
      require_atomic? false

      accept [
        :last_assessment_date,
        :next_assessment_due,
        :compliance_status,
        :compliance_percentage
      ]

      argument :assessment_date, :date do
        allow_nil? false
      end

      argument :compliance_status, :atom do
        allow_nil? false

        constraints one_of: [
                      :compliant,
                      :non_compliant,
                      :partially_compliant,
                      :not_applicable
                    ]
      end

      argument :score, :float do
        constraints min: 0, max: 100
      end

      change fn changeset, _context ->
        assessment_date = changeset.arguments.assessment_date
        status = changeset.arguments.compliance_status
        score = changeset.arguments.score
        f_requency = Ash.Changeset.get_attribute(changeset, :assessment_f_requency)

        next_due =
          case f_requency do
            :monthly -> Date.add(assessment_date, 30)
            :quarterly -> Date.add(assessment_date, 90)
            :semi_annual -> Date.add(assessment_date, 180)
            :annual -> Date.add(assessment_date, 365)
            :biennial -> Date.add(assessment_date, 730)
            _ -> nil
          end

        _changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(:last_assessment_date, assessment_date)
          |> Ash.Changeset.force_change_attribute(:compliance_status, status)

        _changeset =
          if score do
            Ash.Changeset.force_change_attribute(changeset, :compliance_percentage, score)
          else
            changeset
          end

        if next_due do
          Ash.Changeset.force_change_attribute(changeset, :next_assessment_due, next_due)
        else
          changeset
        end
      end
    end

    update :add_finding do
      require_atomic? false
      accept [:findings]

      argument :finding_type, :atom do
        allow_nil? false
        constraints one_of: [:gap, :weakness, :non_compliance, :observation]
      end

      argument :description, :string do
        allow_nil? false
        constraints max_length: 1000
      end

      argument :severity, :atom do
        allow_nil? false
        constraints one_of: [:low, :medium, :high, :critical]
      end

      change fn changeset, _context ->
        findings = Ash.Changeset.get_attribute(changeset, :findings) || []

        new_finding = %{
          "id" => Ash.UUID.generate(),
          "type" => changeset.arguments.finding_type,
          "description" => changeset.arguments.description,
          "severity" => changeset.arguments.severity,
          "date_identified" => Date.utc_today(),
          "status" => "open"
        }

        Ash.Changeset.force_change_attribute(
          changeset,
          :findings,
          [new_finding | findings]
        )
      end
    end

    update :resolve_finding do
      require_atomic? false
      accept [:findings]

      argument :finding_id, :string do
        allow_nil? false
      end

      argument :resolution_notes, :string do
        allow_nil? false
        constraints max_length: 1000
      end

      change fn changeset, _context ->
        findings = Ash.Changeset.get_attribute(changeset, :findings) || []
        finding_id = changeset.arguments.finding_id
        resolution_notes = changeset.arguments.resolution_notes

        updated_findings =
          Enum.map(
            findings,
            fn finding ->
              if finding["id"] == finding_id do
                Map.merge(
                  finding,
                  %{
                    "status" => "resolved",
                    "resolution_date" => Date.utc_today(),
                    "resolution_notes" => resolution_notes
                  }
                )
              else
                finding
              end
            end
          )

        Ash.Changeset.force_change_attribute(changeset, :findings, updated_findings)
      end
    end

    update :_request_exception do
      require_atomic? false
      accept [:exceptions]

      argument :justification, :string do
        allow_nil? false
        constraints max_length: 2000
      end

      argument :_requested_by, :uuid do
        allow_nil? false
      end

      change fn changeset, _context ->
        exceptions = Ash.Changeset.get_attribute(changeset, :exceptions) || []

        new_exception = %{
          "id" => Ash.UUID.generate(),
          "justification" => changeset.arguments.justification,
          "_requested_by" => changeset.arguments._requested_by,
          "_request_date" => Date.utc_today(),
          "status" => "pending_approval"
        }

        Ash.Changeset.force_change_attribute(
          changeset,
          :exceptions,
          [new_exception | exceptions]
        )
      end
    end

    update :review do
      require_atomic? false
      accept [:review_required?, :reviewed_by, :review_date]

      argument :reviewed_by, :uuid do
        allow_nil? false
      end

      argument :review_notes, :string do
        constraints max_length: 1000
      end

      change fn changeset, _context ->
        reviewed_by = changeset.arguments.reviewed_by
        review_notes = changeset.arguments.review_notes

        review_entry = %{
          "reviewed_by" => reviewed_by,
          "review_date" => Date.utc_today(),
          "notes" => review_notes
        }

        change_history = Ash.Changeset.get_attribute(changeset, :change_history) || []

        changeset
        |> Ash.Changeset.force_change_attribute(:review_required?, false)
        |> Ash.Changeset.force_change_attribute(:reviewed_by, reviewed_by)
        |> Ash.Changeset.force_change_attribute(:review_date, Date.utc_today())
        |> Ash.Changeset.force_change_attribute(
          :change_history,
          [review_entry | change_history]
        )
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :is_overdue?, :boolean do
      calculation fn records, _context ->
        today = Date.utc_today()

        values =
          Enum.map(
            records,
            fn _requirement ->
              _requirement.implementation_deadline &&
                Date.compare(
                  today,
                  _requirement.implementation_deadline
                ) == :gt &&
                _requirement.implementation_status not in [
                  :implemented,
                  :verified,
                  :compliant,
                  :not_applicable
                ]
            end
          )

        {:ok, values}
      end
    end

    calculate :assessment_overdue?, :boolean do
      calculation fn records, _context ->
        today = Date.utc_today()

        values =
          Enum.map(
            records,
            fn _requirement ->
              _requirement.next_assessment_due &&
                Date.compare(
                  today,
                  _requirement.next_assessment_due
                ) == :gt
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
            fn _requirement ->
              risk_weight =
                case _requirement.risk_if_not_implemented do
                  :critical -> 4
                  :high -> 3
                  :medium -> 2
                  :low -> 1
                  _ -> 2
                end

              impact_weight =
                case _requirement.business_impact do
                  :critical -> 4
                  :high -> 3
                  :medium -> 2
                  :low -> 1
                  _ -> 2
                end

              criticality_weight =
                case _requirement.criticality do
                  :critical -> 4
                  :high -> 3
                  :medium -> 2
                  :low -> 1
                  _ -> 2
                end

              # Compliance reduces risk
              compliance_factor =
                case _requirement.compliance_status do
                  :compliant -> 0.1
                  :partially_compliant -> 0.5
                  :not_applicable -> 0.0
                  _ -> 1.0
                end

              base_score = (risk_weight + impact_weight + criticality_weight) * 10
              adjusted_score = base_score * compliance_factor

              round(adjusted_score)
            end
          )

        {:ok, values}
      end
    end

    calculate :open_findings_count, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn _requirement ->
              findings = _requirement.findings || []

              Enum.count(
                findings,
                fn finding -> finding["status"] == "open" end
              )
            end
          )

        {:ok, values}
      end
    end

    calculate :pending_exceptions_count, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn _requirement ->
              exceptions = _requirement.exceptions || []

              Enum.count(
                exceptions,
                fn exception -> exception["status"] == "pending_approval" end
              )
            end
          )

        {:ok, values}
      end
    end

    calculate :implementation_progress, :string do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn _requirement ->
              case _requirement.implementation_status do
                :not_started -> "Not Started 0%"
                :planning -> "Planning 10%"
                :in_progress -> "In Progress #{_requirement.compliance_percentage || 0}%"
                :implemented -> "Implemented #{_requirement.compliance_percentage || 0}%"
                :verified -> "Verified 100%"
                :compliant -> "Compliant 100%"
                :not_applicable -> "Not Applicable"
                _ -> "Unknown"
              end
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
      # Assigned _users can read their _requirements
      authorize_if expr(assigned_to == ^actor(:id))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "legal")
    end

    policy action([:assign, :update_implementation_status, :record_assessment]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "auditor")
      # Assigned _users can update their _requirements
      authorize_if expr(assigned_to == ^actor(:id))
    end

    policy action([:add_finding, :resolve_finding]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "auditor")
    end

    policy action(:review) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "legal")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :assign
    define :update_implementation_status
    define :record_assessment
    define :add_finding
    define :resolve_finding
    define :_request_exception
    define :review
    define :destroy
  end

  postgres do
    table "compliance_requirements"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :framework_id, :_requirement_id], unique: true
      index [:framework_id]
      index [:assigned_to], where: "assigned_to IS NOT NULL"
      index [:last_updated_by], where: "last_updated_by IS NOT NULL"
      index [:reviewed_by], where: "reviewed_by IS NOT NULL"
      index [:_requirement_type]
      index [:control_family], where: "control_family IS NOT NULL"
      index [:category]
      index [:priority]
      index [:criticality]
      index [:mandatory?], name: "_requirements_mandatory_index", where: "mandatory? = true"
      index [:implementation_status]
      index [:compliance_status]
      index [:implementation_deadline], where: "implementation_deadline IS NOT NULL"
      index [:last_assessment_date], where: "last_assessment_date IS NOT NULL"
      index [:next_assessment_due], where: "next_assessment_due IS NOT NULL"
      index [:risk_if_not_implemented]
      index [:business_impact]

      index [:training_required?],
        name: "_requirements_training_required_index",
        where: "training_required? = true"

      index [:monitoring_required?],
        name: "_requirements_monitoring_required_index",
        where: "monitoring_required? = true"

      index [:automation_possible?],
        name: "_requirements_automation_possible_index",
        where: "automation_possible? = true"

      index [:review_required?],
        name: "_requirements_review_required_index",
        where: "review_required? = true"
    end
  end

  # Helper functions
  @spec apply_compliance_percentage(term(), float() | nil) :: term()
  defp apply_compliance_percentage(changeset, percentage) do
    if percentage do
      Ash.Changeset.force_change_attribute(changeset, :compliance_percentage, percentage)
    else
      changeset
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: # OK: General system coordination and management with cyberneti
# Domain: Compliance
# Responsibilitie,s: Template generation, standards enforcement, general coordinat
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedbac,k: Active feedback loops for continuous improvement
