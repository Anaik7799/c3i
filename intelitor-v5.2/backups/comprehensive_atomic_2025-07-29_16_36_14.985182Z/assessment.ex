defmodule Intelitor.Compliance.Assessment do
  @moduledoc """
  Represents compliance assessments and audits.

  Assessments evaluate compliance status against frameworks and requirements,
  documenting findings, evidence, and remediation actions. They support
  both internal assessments and external audits.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Compliance,
    table: "compliance_assessments"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Assessment identification
    attribute :assessment_number, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :assessment_name, :string do
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :description, :string do
      public? true
      constraints max_length: 2000
    end

    # Assessment scope
    attribute :framework_id, :uuid do
      public? true
    end

    attribute :requirement_id, :uuid do
      public? true
    end

    attribute :scope_description, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :included_systems, {:array, :string} do
      public? true
      default []
    end

    attribute :excluded_systems, {:array, :string} do
      public? true
      default []
    end

    attribute :coverage_areas, {:array, :string} do
      public? true
      default []
    end

    # Assessment type and methodology
    attribute :assessment_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :internal_audit,
                    :external_audit,
                    :self_assessment,
                    :third_party_assessment,
                    :certification_audit,
                    :surveillance_audit,
                    :gap_analysis,
                    :maturity_assessment
                  ]

      default :internal_audit
    end

    attribute :methodology, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :checklist_based,
                    :risk_based,
                    :process_based,
                    :controls_based,
                    :maturity_model,
                    :gap_analysis,
                    :penetration_testing,
                    :vulnerability_assessment
                  ]

      default :checklist_based
    end

    attribute :assessment_approach, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :comprehensive,
                    :targeted,
                    :sampling_based,
                    :risk_focused,
                    :continuous
                  ]

      default :comprehensive
    end

    # Assessment execution
    attribute :planned_start_date, :date do
      public? true
    end

    attribute :planned_end_date, :date do
      public? true
    end

    attribute :actual_start_date, :date do
      public? true
    end

    attribute :actual_end_date, :date do
      public? true
    end

    attribute :estimated_effort_days, :integer do
      public? true
      constraints min: 0
    end

    attribute :actual_effort_days, :integer do
      public? true
      constraints min: 0
    end

    # Assessment team
    attribute :lead_assessor_id, :uuid do
      public? true
    end

    attribute :assessment_team, {:array, :uuid} do
      public? true
      default []
    end

    attribute :external_assessors, {:array, :map} do
      public? true
      default []
    end

    attribute :assessment_organization, :string do
      public? true
      constraints max_length: 200
    end

    # Status and progress
    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :planned,
                    :in_progress,
                    :fieldwork_complete,
                    :report_draft,
                    :review_pending,
                    :completed,
                    :cancelled,
                    :on_hold
                  ]

      default :planned
    end

    attribute :progress_percentage, :integer do
      allow_nil? false
      public? true
      constraints min: 0, max: 100
      default 0
    end

    attribute :current_phase, :atom do
      public? true

      constraints one_of: [
                    :planning,
                    :preparation,
                    :fieldwork,
                    :testing,
                    :evaluation,
                    :reporting,
                    :review,
                    :finalization,
                    :follow_up
                  ]
    end

    # Assessment criteria and standards
    attribute :assessment_criteria, :string do
      public? true
      constraints max_length: 3000
    end

    attribute :evaluation_standards, :map do
      public? true
      default %{}
    end

    attribute :sampling_methodology, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :evidence_requirements, :string do
      public? true
      constraints max_length: 2000
    end

    # Assessment methods
    attribute :methods_used, {:array, :atom} do
      public? true
      default []

      constraints items: [
                    one_of: [
                      :document_review,
                      :interview,
                      :observation,
                      :walkthrough,
                      :testing,
                      :inquiry,
                      :analytical_procedures,
                      :reperformance,
                      :inspection,
                      :confirmation,
                      :recalculation
                    ]
                  ]
    end

    attribute :interview_list, {:array, :map} do
      public? true
      default []
    end

    attribute :documents_reviewed, {:array, :string} do
      public? true
      default []
    end

    attribute :tests_performed, {:array, :map} do
      public? true
      default []
    end

    # Findings and results
    attribute :total_findings, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :critical_findings, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :high_findings, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :medium_findings, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :low_findings, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :observations, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :findings_details, {:array, :map} do
      public? true
      default []
    end

    # Compliance scoring
    attribute :overall_compliance_score, :float do
      public? true
      constraints min: 0, max: 100
    end

    attribute :compliance_level, :atom do
      public? true

      constraints one_of: [
                    :fully_compliant,
                    :substantially_compliant,
                    :partially_compliant,
                    :minimally_compliant,
                    :non_compliant,
                    :not_assessed
                  ]
    end

    attribute :maturity_level, :integer do
      public? true
      constraints min: 0, max: 5
    end

    attribute :control_effectiveness, :atom do
      public? true

      constraints one_of: [
                    :effective,
                    :partially_effective,
                    :ineffective,
                    :not_tested
                  ]
    end

    # Risk assessment
    attribute :risk_rating, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    attribute :residual_risk, :atom do
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
    end

    attribute :risk_factors, {:array, :string} do
      public? true
      default []
    end

    attribute :threat_landscape, :string do
      public? true
      constraints max_length: 2000
    end

    # Recommendations and remediation
    attribute :recommendations, {:array, :map} do
      public? true
      default []
    end

    attribute :priority_actions, {:array, :string} do
      public? true
      default []
    end

    attribute :quick_wins, {:array, :string} do
      public? true
      default []
    end

    attribute :long_term_improvements, {:array, :string} do
      public? true
      default []
    end

    attribute :remediation_timeline, :map do
      public? true
      default %{}
    end

    # Assessment artifacts
    attribute :assessment_plan_url, :string do
      public? true
      constraints max_length: 500
    end

    attribute :working_papers, {:array, :string} do
      public? true
      default []
    end

    attribute :evidence_collected, {:array, :string} do
      public? true
      default []
    end

    attribute :report_url, :string do
      public? true
      constraints max_length: 500
    end

    attribute :executive_summary, :string do
      public? true
      constraints max_length: 5000
    end

    # Quality assurance
    attribute :peer_review_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :peer_reviewer_id, :uuid do
      public? true
    end

    attribute :peer_review_completed?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :quality_rating, :integer do
      public? true
      constraints min: 1, max: 5
    end

    # Client and stakeholder management
    attribute :client_contact, :string do
      public? true
      constraints max_length: 200
    end

    attribute :key_stakeholders, {:array, :string} do
      public? true
      default []
    end

    attribute :communication_log, {:array, :map} do
      public? true
      default []
    end

    attribute :client_feedback, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :satisfaction_rating, :integer do
      public? true
      constraints min: 1, max: 5
    end

    # Follow-up and monitoring
    attribute :follow_up_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :follow_up_date, :date do
      public? true
    end

    attribute :next_assessment_due, :date do
      public? true
    end

    attribute :continuous_monitoring?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :monitoring_frequency, :atom do
      public? true
      constraints one_of: [:weekly, :monthly, :quarterly, :semi_annual, :annual]
    end

    # Cost and resource tracking
    attribute :assessment_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :external_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :internal_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :travel_expenses, :float do
      public? true
      constraints min: 0
    end

    attribute :resources_used, {:array, :string} do
      public? true
      default []
    end

    # Certification and accreditation
    attribute :certification_impact?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :certification_body, :string do
      public? true
      constraints max_length: 200
    end

    attribute :accreditation_standard, :string do
      public? true
      constraints max_length: 100
    end

    attribute :certificate_validity, :date do
      public? true
    end

    # Approval and sign-off
    attribute :report_approved?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :approved_by, :uuid do
      public? true
    end

    attribute :approval_date, :date do
      public? true
    end

    attribute :management_response, :string do
      public? true
      constraints max_length: 3000
    end

    attribute :action_plan_agreed?, :boolean do
      allow_nil? false
      public? true
      default false
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
    belongs_to :framework, Intelitor.Compliance.Framework do
      attribute_public? true
    end

    belongs_to :requirement, Intelitor.Compliance.Requirement do
      attribute_public? true
    end

    belongs_to :lead_assessor, Intelitor.Accounts.User do
      attribute_public? true
    end

    belongs_to :peer_reviewer, Intelitor.Accounts.User do
      attribute_public? true
    end

    belongs_to :approved_by_user, Intelitor.Accounts.User do
      source_attribute :approved_by
      attribute_public? true
    end

    has_many :reports, Intelitor.Compliance.Report
    has_many :documents, Intelitor.Compliance.Document
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :assessment_name,
        :description,
        :framework_id,
        :requirement_id,
        :scope_description,
        :included_systems,
        :excluded_systems,
        :coverage_areas,
        :assessment_type,
        :methodology,
        :assessment_approach,
        :planned_start_date,
        :planned_end_date,
        :estimated_effort_days,
        :lead_assessor_id,
        :assessment_team,
        :external_assessors,
        :assessment_organization,
        :assessment_criteria,
        :evaluation_standards,
        :sampling_methodology,
        :evidence_requirements,
        :methods_used,
        :risk_rating,
        :client_contact,
        :key_stakeholders,
        :follow_up_required?,
        :continuous_monitoring?,
        :monitoring_frequency,
        :assessment_cost,
        :external_cost,
        :internal_cost,
        :certification_impact?,
        :certification_body,
        :accreditation_standard,
        :peer_review_required?,
        :keywords,
        :metadata
      ]

      change fn changeset, _context ->
        changeset
        |> generate_assessment_number()
        |> Ash.Changeset.force_change_attribute(:status, :planned)
        |> Ash.Changeset.force_change_attribute(:progress_percentage, 0)
        |> Ash.Changeset.force_change_attribute(:current_phase, :planning)
      end
    end


    update :start_assessment do
        require_atomic? false
      accept [:actual_start_date, :status, :current_phase]

      validate attribute_equals(:status, :planned)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :in_progress)
        |> Ash.Changeset.force_change_attribute(:current_phase, :preparation)
        |> Ash.Changeset.force_change_attribute(:actual_start_date, Date.utc_today())
        |> Ash.Changeset.force_change_attribute(:progress_percentage, 10)
      end
    end

    update :update_progress do
      require_atomic? false
      
      accept [:progress_percentage, :current_phase]

      argument :percentage, :integer do
        allow_nil? false
        constraints min: 0, max: 100
      end

      argument :phase, :atom do
        allow_nil? false

        constraints one_of: [
                      :planning,
                      :preparation,
                      :fieldwork,
                      :testing,
                      :evaluation,
                      :reporting,
                      :review,
                      :finalization,
                      :follow_up
                    ]
      end
    end

    update :complete_fieldwork do
        require_atomic? false
      accept [:status, :current_phase, :progress_percentage]

      validate attribute_equals(:status, :in_progress)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :fieldwork_complete)
        |> Ash.Changeset.force_change_attribute(:current_phase, :evaluation)
        |> Ash.Changeset.force_change_attribute(:progress_percentage, 75)
      end
    end

    update :add_finding do
      require_atomic? false
      accept [
        :findings_details,
        :total_findings,
        :critical_findings,
        :high_findings,
        :medium_findings,
        :low_findings,
        :observations
      ]

      argument :finding_type, :atom do
        allow_nil? false
        constraints one_of: [:critical, :high, :medium, :low, :observation]
      end

      argument :title, :string do
        allow_nil? false
        constraints max_length: 200
      end

      argument :description, :string do
        allow_nil? false
        constraints max_length: 2000
      end

      argument :risk_rating, :atom do
        allow_nil? false
        constraints one_of: [:low, :medium, :high, :critical]
      end

      change fn changeset, _context ->
        findings = Ash.Changeset.get_attribute(changeset, :findings_details) || []
        finding_type = changeset.arguments.finding_type

        new_finding = %{
          "id" => Ash.UUID.generate(),
          "type" => finding_type,
          "title" => changeset.arguments.title,
          "description" => changeset.arguments.description,
          "risk_rating" => changeset.arguments.risk_rating,
          "date_identified" => Date.utc_today(),
          "status" => "open"
        }

        # Update counters
        current_total = Ash.Changeset.get_attribute(changeset, :total_findings)

        current_count =
          case finding_type do
            :critical -> Ash.Changeset.get_attribute(changeset, :critical_findings)
            :high -> Ash.Changeset.get_attribute(changeset, :high_findings)
            :medium -> Ash.Changeset.get_attribute(changeset, :medium_findings)
            :low -> Ash.Changeset.get_attribute(changeset, :low_findings)
            :observation -> Ash.Changeset.get_attribute(changeset, :observations)
          end

        changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(
            :findings_details,
            [new_finding | findings]
          )
          |> Ash.Changeset.force_change_attribute(:total_findings, current_total + 1)

        case finding_type do
          :critical ->
            Ash.Changeset.force_change_attribute(
              changeset,
              :critical_findings,
              current_count + 1
            )

          :high ->
            Ash.Changeset.force_change_attribute(
              changeset,
              :high_findings,
              current_count + 1
            )

          :medium ->
            Ash.Changeset.force_change_attribute(
              changeset,
              :medium_findings,
              current_count + 1
            )

          :low ->
            Ash.Changeset.force_change_attribute(
              changeset,
              :low_findings,
              current_count + 1
            )

          :observation ->
            Ash.Changeset.force_change_attribute(
              changeset,
              :observations,
              current_count + 1
            )
        end
      end
    end

    update :calculate_compliance_score do
      require_atomic? false
      accept [:overall_compliance_score, :compliance_level, :control_effectiveness]

      change fn changeset, _context ->
        total = Ash.Changeset.get_attribute(changeset, :total_findings)
        critical = Ash.Changeset.get_attribute(changeset, :critical_findings)
        high = Ash.Changeset.get_attribute(changeset, :high_findings)
        medium = Ash.Changeset.get_attribute(changeset, :medium_findings)
        low = Ash.Changeset.get_attribute(changeset, :low_findings)

        # Calculate weighted score (simplified algorithm)
        penalty_score = critical * 20 + high * 10 + medium * 5 + low * 2
        base_score = 100.0
        final_score = max(0.0, base_score - penalty_score)

        compliance_level =
          cond do
            final_score >= 95.0 -> :fully_compliant
            final_score >= 80.0 -> :substantially_compliant
            final_score >= 60.0 -> :partially_compliant
            final_score >= 40.0 -> :minimally_compliant
            true -> :non_compliant
          end

        effectiveness =
          cond do
            final_score >= 80.0 -> :effective
            final_score >= 60.0 -> :partially_effective
            true -> :ineffective
          end

        changeset
        |> Ash.Changeset.force_change_attribute(:overall_compliance_score, final_score)
        |> Ash.Changeset.force_change_attribute(:compliance_level, compliance_level)
        |> Ash.Changeset.force_change_attribute(:control_effectiveness, effectiveness)
      end
    end

    update :submit_for_review do
      require_atomic? false
      accept [:status, :current_phase]

      validate attribute_equals(:status, :fieldwork_complete)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :review_pending)
        |> Ash.Changeset.force_change_attribute(:current_phase, :review)
        |> Ash.Changeset.force_change_attribute(:progress_percentage, 90)
      end
    end

    update :complete_assessment do
      require_atomic? false
      accept [:status, :actual_end_date, :actual_effort_days, :progress_percentage]

      argument :actual_effort_days, :integer do
        allow_nil? false
        constraints min: 0
      end

      validate attribute_equals(:status, :review_pending)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :completed)
        |> Ash.Changeset.force_change_attribute(:actual_end_date, Date.utc_today())
        |> Ash.Changeset.force_change_attribute(
          :actual_effort_days,
          changeset.arguments.actual_effort_days
        )
        |> Ash.Changeset.force_change_attribute(:progress_percentage, 100)
      end
    end

    update :approve_report do
      require_atomic? false
      accept [:report_approved?, :approved_by, :approval_date]

      argument :approved_by, :uuid do
        allow_nil? false
      end

      argument :management_response, :string do
        constraints max_length: 3000
      end

      validate attribute_equals(:status, :completed)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:report_approved?, true)
        |> Ash.Changeset.force_change_attribute(
          :approved_by,
          changeset.arguments.approved_by
        )
        |> Ash.Changeset.force_change_attribute(:approval_date, Date.utc_today())
        |> (fn cs ->
              if response = changeset.arguments.management_response do
                Ash.Changeset.force_change_attribute(cs, :management_response, response)
              else
                cs
              end
            end).()
      end
    end

    update :add_communication do
      require_atomic? false
      accept [:communication_log]

      argument :message, :string do
        allow_nil? false
        constraints max_length: 1000
      end

      argument :sender, :string do
        allow_nil? false
        constraints max_length: 100
      end

      argument :recipient, :string do
        allow_nil? false
        constraints max_length: 100
      end

      change fn changeset, _context ->
        log = Ash.Changeset.get_attribute(changeset, :communication_log) || []

        new_entry = %{
          "timestamp" => DateTime.utc_now(),
          "message" => changeset.arguments.message,
          "sender" => changeset.arguments.sender,
          "recipient" => changeset.arguments.recipient
        }

        Ash.Changeset.force_change_attribute(
          changeset,
          :communication_log,
          [new_entry | log]
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
            fn assessment ->
              assessment.planned_end_date &&
                Date.compare(
                  today,
                  assessment.planned_end_date
                ) == :gt &&
                assessment.status not in [:completed, :cancelled]
            end
          )

        {:ok, values}
      end
    end

    calculate :days_remaining, :integer do
      calculation fn records, _context ->
        today = Date.utc_today()

        values =
          Enum.map(
            records,
            fn assessment ->
              if assessment.planned_end_date do
                Date.diff(
                  assessment.planned_end_date,
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

    calculate :effort_variance_days, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn assessment ->
              if assessment.actual_effort_days && assessment.estimated_effort_days do
                assessment.actual_effort_days - assessment.estimated_effort_days
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :finding_severity_score, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn assessment ->
              assessment.critical_findings * 4 +
                assessment.high_findings * 3 +
                assessment.medium_findings * 2 +
                assessment.low_findings * 1
            end
          )

        {:ok, values}
      end
    end

    calculate :assessment_quality_indicator, :string do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn assessment ->
              cond do
                assessment.quality_rating && assessment.quality_rating >= 4 ->
                  "High Quality"

                assessment.quality_rating && assessment.quality_rating >= 3 ->
                  "Good Quality"

                assessment.quality_rating && assessment.quality_rating >= 2 ->
                  "Acceptable Quality"

                assessment.quality_rating ->
                  "Needs Improvement"

                true ->
                  "Not Rated"
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :total_cost, :float do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn assessment ->
              external = assessment.external_cost || 0.0
              internal = assessment.internal_cost || 0.0
              travel = assessment.travel_expenses || 0.0
              external + internal + travel
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
      # Lead assessor can read their assessments
      authorize_if expr(lead_assessor_id == ^actor(:id))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "auditor")
    end

    policy action([
             :start_assessment,
             :update_progress,
             :complete_fieldwork,
             :add_finding,
             :calculate_compliance_score,
             :submit_for_review,
             :complete_assessment,
             :add_communication
           ]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "auditor")
      # Lead assessor can update their assessments
      authorize_if expr(lead_assessor_id == ^actor(:id))
    end

    policy action(:approve_report) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "manager")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :start_assessment
    define :update_progress
    define :complete_fieldwork
    define :add_finding
    define :calculate_compliance_score
    define :submit_for_review
    define :complete_assessment
    define :approve_report
    define :add_communication
    define :destroy
  end

  postgres do
    table "compliance_assessments"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :assessment_number], unique: true
      index [:framework_id], where: "framework_id IS NOT NULL"
      index [:requirement_id], where: "requirement_id IS NOT NULL"
      index [:lead_assessor_id], where: "lead_assessor_id IS NOT NULL"
      index [:peer_reviewer_id], where: "peer_reviewer_id IS NOT NULL"
      index [:approved_by], where: "approved_by IS NOT NULL"
      index [:assessment_type]
      index [:methodology]
      index [:status]
      index [:current_phase], where: "current_phase IS NOT NULL"
      index [:planned_start_date], where: "planned_start_date IS NOT NULL"
      index [:planned_end_date], where: "planned_end_date IS NOT NULL"
      index [:actual_start_date], where: "actual_start_date IS NOT NULL"
      index [:actual_end_date], where: "actual_end_date IS NOT NULL"
      index [:compliance_level], where: "compliance_level IS NOT NULL"
      index [:risk_rating]

      index [:follow_up_required?],
        name: "assessments_follow_up_required_index",
        where: "follow_up_required? = true"

      index [:continuous_monitoring?],
        name: "assessments_continuous_monitoring_index",
        where: "continuous_monitoring? = true"

      index [:certification_impact?],
        name: "assessments_certification_impact_index",
        where: "certification_impact? = true"

      index [:peer_review_required?],
        name: "assessments_peer_review_required_index",
        where: "peer_review_required? = true"

      index [:report_approved?],
        name: "assessments_report_approved_index",
        where: "report_approved? = true"
    end
  end

  # Helper functions
  defp generate_assessment_number(changeset) do
    # Generate assessment number like ASS-20251206-001
    date_str = Date.utc_today() |> Date.to_string() |> String.replace("-", "")

    random_suffix =
      :rand.uniform(999)
      |> Integer.to_string()
      |> String.pad_leading(3, "0")

    assessment_number = "ASS-#{date_str}-#{random_suffix}"

    Ash.Changeset.force_change_attribute(
      changeset,
      :assessment_number,
      assessment_number
    )
  end
end
