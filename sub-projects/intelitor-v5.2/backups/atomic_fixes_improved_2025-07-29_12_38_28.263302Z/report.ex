defmodule Intelitor.Compliance.Report do
  @moduledoc """
  Represents compliance reports and documentation.

  Reports provide formal documentation of compliance status, assessment results,
  audit findings, and regulatory submissions. They support both internal
  reporting and external regulatory requirements.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Compliance,
    table: "compliance_reports"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Report identification
    attribute :report_number, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :report_title, :string do
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :report_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :compliance_report,
                    :audit_report,
                    :assessment_report,
                    :gap_analysis,
                    :risk_assessment,
                    :regulatory_filing,
                    :certification_report,
                    :management_letter,
                    :executive_summary,
                    :dashboard_report
                  ]

      default :compliance_report
    end

    attribute :description, :string do
      public? true
      constraints max_length: 2000
    end

    # Report scope and relationships
    attribute :framework_id, :uuid do
      public? true
    end

    attribute :assessment_id, :uuid do
      public? true
    end

    attribute :reporting_period_start, :date do
      public? true
    end

    attribute :reporting_period_end, :date do
      public? true
    end

    attribute :scope_description, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :covered_systems, {:array, :string} do
      public? true
      default []
    end

    attribute :covered_processes, {:array, :string} do
      public? true
      default []
    end

    # Report metadata
    attribute :version, :string do
      allow_nil? false
      public? true
      constraints max_length: 20
      default "1.0"
    end

    attribute :language, :string do
      allow_nil? false
      public? true
      constraints max_length: 5
      default "en"
    end

    attribute :confidentiality_level, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :public,
                    :internal,
                    :confidential,
                    :restricted,
                    :top_secret
                  ]

      default :internal
    end

    attribute :classification, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:draft, :preliminary, :final, :superseded, :archived]
      default :draft
    end

    # Authoring and approval
    attribute :author_id, :uuid do
      public? true
    end

    attribute :contributors, {:array, :uuid} do
      public? true
      default []
    end

    attribute :reviewer_id, :uuid do
      public? true
    end

    attribute :approver_id, :uuid do
      public? true
    end

    attribute :prepared_by, :string do
      public? true
      constraints max_length: 200
    end

    attribute :reviewed_by, :string do
      public? true
      constraints max_length: 200
    end

    attribute :approved_by, :string do
      public? true
      constraints max_length: 200
    end

    # Status and workflow
    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :draft,
                    :in_review,
                    :pending_approval,
                    :approved,
                    :published,
                    :submitted,
                    :rejected,
                    :cancelled,
                    :archived
                  ]

      default :draft
    end

    attribute :workflow_stage, :atom do
      public? true

      constraints one_of: [
                    :authoring,
                    :internal_review,
                    :quality_assurance,
                    :management_review,
                    :approval,
                    :finalization,
                    :publication,
                    :submission,
                    :completed
                  ]
    end

    # Important dates
    attribute :creation_date, :date do
      allow_nil? false
      public? true
    end

    attribute :review_date, :date do
      public? true
    end

    attribute :approval_date, :date do
      public? true
    end

    attribute :publication_date, :date do
      public? true
    end

    attribute :submission_date, :date do
      public? true
    end

    attribute :due_date, :date do
      public? true
    end

    # Content structure
    attribute :executive_summary, :string do
      public? true
      constraints max_length: 5000
    end

    attribute :methodology, :string do
      public? true
      constraints max_length: 3000
    end

    attribute :key_findings, {:array, :map} do
      public? true
      default []
    end

    attribute :recommendations, {:array, :map} do
      public? true
      default []
    end

    attribute :conclusions, :string do
      public? true
      constraints max_length: 3000
    end

    attribute :appendices, {:array, :map} do
      public? true
      default []
    end

    # Compliance metrics
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
                    :non_compliant
                  ]
    end

    attribute :total_requirements_assessed, :integer do
      public? true
      constraints min: 0
    end

    attribute :compliant_requirements, :integer do
      public? true
      constraints min: 0
    end

    attribute :non_compliant_requirements, :integer do
      public? true
      constraints min: 0
    end

    attribute :partially_compliant_requirements, :integer do
      public? true
      constraints min: 0
    end

    # Findings summary
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

    # Risk assessment
    attribute :overall_risk_rating, :atom do
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
    end

    attribute :residual_risk_rating, :atom do
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
    end

    attribute :risk_trends, :atom do
      public? true
      constraints one_of: [:improving, :stable, :deteriorating, :mixed]
    end

    attribute :threat_landscape_summary, :string do
      public? true
      constraints max_length: 2000
    end

    # Action plans and remediation
    attribute :action_plan_included?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :immediate_actions, {:array, :string} do
      public? true
      default []
    end

    attribute :short_term_actions, {:array, :string} do
      public? true
      default []
    end

    attribute :long_term_actions, {:array, :string} do
      public? true
      default []
    end

    attribute :remediation_timeline, :map do
      public? true
      default %{}
    end

    attribute :estimated_remediation_cost, :float do
      public? true
      constraints min: 0
    end

    # Distribution and audience
    attribute :target_audience, {:array, :atom} do
      public? true
      default []

      constraints items: [
                    one_of: [
                      :board,
                      :executive_management,
                      :senior_management,
                      :department_heads,
                      :compliance_team,
                      :audit_committee,
                      :regulators,
                      :external_auditors,
                      :business_units,
                      :it_team,
                      :security_team,
                      :legal_team
                    ]
                  ]
    end

    attribute :distribution_list, {:array, :string} do
      public? true
      default []
    end

    attribute :external_recipients, {:array, :string} do
      public? true
      default []
    end

    attribute :restricted_access?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Format and delivery
    attribute :format, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:pdf, :word, :html, :presentation, :dashboard, :excel]
      default :pdf
    end

    attribute :page_count, :integer do
      public? true
      constraints min: 0
    end

    attribute :document_url, :string do
      public? true
      constraints max_length: 500
    end

    attribute :interactive_dashboard_url, :string do
      public? true
      constraints max_length: 500
    end

    attribute :supporting_documents, {:array, :string} do
      public? true
      default []
    end

    # Regulatory compliance
    attribute :regulatory_requirement?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :regulatory_body, :string do
      public? true
      constraints max_length: 200
    end

    attribute :regulation_reference, :string do
      public? true
      constraints max_length: 100
    end

    attribute :filing_reference, :string do
      public? true
      constraints max_length: 100
    end

    attribute :submission_method, :atom do
      public? true
      constraints one_of: [:online_portal, :email, :postal_mail, :in_person, :ftp]
    end

    # Quality assurance
    attribute :peer_reviewed?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :quality_assured?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :accuracy_verified?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :completeness_checked?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :quality_score, :integer do
      public? true
      constraints min: 1, max: 5
    end

    # Feedback and revisions
    attribute :feedback_received, {:array, :map} do
      public? true
      default []
    end

    attribute :revision_history, {:array, :map} do
      public? true
      default []
    end

    attribute :major_revisions, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :minor_revisions, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
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

    attribute :next_report_due, :date do
      public? true
    end

    attribute :monitoring_frequency, :atom do
      public? true
      constraints one_of: [:monthly, :quarterly, :semi_annual, :annual, :ad_hoc]
    end

    # Performance metrics
    attribute :preparation_time_hours, :integer do
      public? true
      constraints min: 0
    end

    attribute :review_time_hours, :integer do
      public? true
      constraints min: 0
    end

    attribute :total_effort_hours, :integer do
      public? true
      constraints min: 0
    end

    attribute :cost_to_prepare, :float do
      public? true
      constraints min: 0
    end

    attribute :stakeholder_satisfaction, :integer do
      public? true
      constraints min: 1, max: 5
    end

    # Archive and retention
    attribute :retention_period_years, :integer do
      public? true
      constraints min: 1, max: 50
    end

    attribute :archive_date, :date do
      public? true
    end

    attribute :destruction_date, :date do
      public? true
    end

    attribute :legal_hold?, :boolean do
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

    belongs_to :assessment, Intelitor.Compliance.Assessment do
      attribute_public? true
    end

    belongs_to :author, Intelitor.Accounts.User do
      attribute_public? true
    end

    belongs_to :reviewer, Intelitor.Accounts.User do
      attribute_public? true
    end

    belongs_to :approver, Intelitor.Accounts.User do
      attribute_public? true
    end

    has_many :documents, Intelitor.Compliance.Document
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :report_title,
        :report_type,
        :description,
        :framework_id,
        :assessment_id,
        :reporting_period_start,
        :reporting_period_end,
        :scope_description,
        :covered_systems,
        :covered_processes,
        :language,
        :confidentiality_level,
        :author_id,
        :contributors,
        :reviewer_id,
        :approver_id,
        :prepared_by,
        :due_date,
        :executive_summary,
        :methodology,
        :key_findings,
        :recommendations,
        :conclusions,
        :appendices,
        :target_audience,
        :distribution_list,
        :external_recipients,
        :restricted_access?,
        :format,
        :regulatory_requirement?,
        :regulatory_body,
        :regulation_reference,
        :submission_method,
        :retention_period_years,
        :keywords,
        :metadata
      ]

      change fn changeset, _context ->
        changeset
        |> generate_report_number()
        |> Ash.Changeset.force_change_attribute(:creation_date, Date.utc_today())
        |> Ash.Changeset.force_change_attribute(:status, :draft)
        |> Ash.Changeset.force_change_attribute(:workflow_stage, :authoring)
        |> Ash.Changeset.force_change_attribute(:classification, :draft)
      end
    end


    update :submit_for_review do
      accept [:status, :workflow_stage]

      validate attribute_equals(:status, :draft)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :in_review)
        |> Ash.Changeset.force_change_attribute(:workflow_stage, :internal_review)
      end
    end

    update :complete_review do
      require_atomic? false
      accept [:status, :workflow_stage, :review_date, :reviewed_by, :peer_reviewed?]

      argument :reviewer_notes, :string do
        constraints max_length: 2000
      end

      validate attribute_equals(:status, :in_review)

      change fn changeset, _context ->
        reviewer_notes = changeset.arguments.reviewer_notes

        revision_entry = %{
          "type" => "review",
          "date" => Date.utc_today(),
          "notes" => reviewer_notes,
          "version" => Ash.Changeset.get_attribute(changeset, :version)
        }

        revision_history = Ash.Changeset.get_attribute(changeset, :revision_history) || []

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :pending_approval)
        |> Ash.Changeset.force_change_attribute(:workflow_stage, :management_review)
        |> Ash.Changeset.force_change_attribute(:review_date, Date.utc_today())
        |> Ash.Changeset.force_change_attribute(:peer_reviewed?, true)
        |> Ash.Changeset.force_change_attribute(
          :revision_history,
          [
            revision_entry | revision_history
          ]
        )
      end
    end

    update :approve do
      require_atomic? false
      
      accept [:status, :workflow_stage, :approval_date, :approved_by]

      argument :approver_id, :uuid do
        allow_nil? false
      end

      validate attribute_equals(:status, :pending_approval)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :approved)
        |> Ash.Changeset.force_change_attribute(:workflow_stage, :finalization)
        |> Ash.Changeset.force_change_attribute(:approval_date, Date.utc_today())
        |> Ash.Changeset.force_change_attribute(
          :approver_id,
          changeset.arguments.approver_id
        )
        |> Ash.Changeset.force_change_attribute(:classification, :final)
      end
    end

    update :publish do
      require_atomic? false
      
      accept [:status, :workflow_stage, :publication_date]

      validate attribute_equals(:status, :approved)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :published)
        |> Ash.Changeset.force_change_attribute(:workflow_stage, :publication)
        |> Ash.Changeset.force_change_attribute(:publication_date, Date.utc_today())
      end
    end

    update :submit_regulatory do
      require_atomic? false
      accept [:status, :submission_date, :filing_reference]

      argument :filing_reference, :string do
        allow_nil? false
        constraints max_length: 100
      end

      validate attribute_equals(:regulatory_requirement?, true)
      validate attribute_equals(:status, :published)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :submitted)
        |> Ash.Changeset.force_change_attribute(:workflow_stage, :submission)
        |> Ash.Changeset.force_change_attribute(:submission_date, Date.utc_today())
        |> Ash.Changeset.force_change_attribute(
          :filing_reference,
          changeset.arguments.filing_reference
        )
      end
    end

    update :update_metrics do
      require_atomic? false
      accept [
        :overall_compliance_score,
        :compliance_level,
        :total_requirements_assessed,
        :compliant_requirements,
        :non_compliant_requirements,
        :partially_compliant_requirements,
        :total_findings,
        :critical_findings,
        :high_findings,
        :medium_findings,
        :low_findings,
        :observations,
        :overall_risk_rating,
        :residual_risk_rating
      ]

      change fn changeset, _context ->
        # Calculate compliance percentages
        total =
          Ash.Changeset.get_argument_or_attribute(changeset, :total_requirements_assessed) || 0

        compliant =
          Ash.Changeset.get_argument_or_attribute(changeset, :compliant_requirements) || 0

        if total > 0 do
          compliance_score = compliant / total * 100.0

          compliance_level =
            cond do
              compliance_score >= 95.0 -> :fully_compliant
              compliance_score >= 80.0 -> :substantially_compliant
              compliance_score >= 60.0 -> :partially_compliant
              compliance_score >= 40.0 -> :minimally_compliant
              true -> :non_compliant
            end

          changeset
          |> Ash.Changeset.force_change_attribute(
            :overall_compliance_score,
            compliance_score
          )
          |> Ash.Changeset.force_change_attribute(:compliance_level, compliance_level)
        else
          changeset
        end
      end
    end

    update :add_feedback do
      require_atomic? false
      accept [:feedback_received]

      argument :feedback_type, :atom do
        allow_nil? false
        constraints one_of: [:comment, :correction, :suggestion, :question, :concern]
      end

      argument :feedback_text, :string do
        allow_nil? false
        constraints max_length: 2000
      end

      argument :provided_by, :string do
        allow_nil? false
        constraints max_length: 100
      end

      change fn changeset, _context ->
        feedback = Ash.Changeset.get_attribute(changeset, :feedback_received) || []

        new_feedback = %{
          "id" => Ash.UUID.generate(),
          "type" => changeset.arguments.feedback_type,
          "text" => changeset.arguments.feedback_text,
          "provided_by" => changeset.arguments.provided_by,
          "date" => Date.utc_today(),
          "status" => "open"
        }

        Ash.Changeset.force_change_attribute(
          changeset,
          :feedback_received,
          [
            new_feedback | feedback
          ]
        )
      end
    end

    update :create_revision do
      require_atomic? false
      accept [:version, :major_revisions, :minor_revisions]

      argument :revision_type, :atom do
        allow_nil? false
        constraints one_of: [:major, :minor]
      end

      argument :revision_notes, :string do
        allow_nil? false
        constraints max_length: 1000
      end

      change fn changeset, _context ->
        current_version = Ash.Changeset.get_attribute(changeset, :version)
        revision_type = changeset.arguments.revision_type
        revision_notes = changeset.arguments.revision_notes

        # Simple version increment logic
        [major, minor] =
          String.split(current_version, ".")
          |> Enum.map(&String.to_integer/1)

        {new_version, major_count, minor_count} =
          case revision_type do
            :major ->
              {"#{major + 1}.0", Ash.Changeset.get_attribute(changeset, :major_revisions) + 1,
               Ash.Changeset.get_attribute(changeset, :minor_revisions)}

            :minor ->
              {"#{major}.#{minor + 1}", Ash.Changeset.get_attribute(changeset, :major_revisions),
               Ash.Changeset.get_attribute(changeset, :minor_revisions) + 1}
          end

        revision_entry = %{
          "type" => revision_type,
          "version" => new_version,
          "date" => Date.utc_today(),
          "notes" => revision_notes
        }

        revision_history = Ash.Changeset.get_attribute(changeset, :revision_history) || []

        changeset
        |> Ash.Changeset.force_change_attribute(:version, new_version)
        |> Ash.Changeset.force_change_attribute(:major_revisions, major_count)
        |> Ash.Changeset.force_change_attribute(:minor_revisions, minor_count)
        |> Ash.Changeset.force_change_attribute(
          :revision_history,
          [
            revision_entry | revision_history
          ]
        )
        |> Ash.Changeset.force_change_attribute(:status, :draft)
        |> Ash.Changeset.force_change_attribute(:classification, :draft)
      end
    end

    update :archive do
      require_atomic? false
      
      accept [:status, :classification, :archive_date]

      validate attribute_in(:status, [:published, :submitted])

      change fn changeset, _context ->
        retention_years = Ash.Changeset.get_attribute(changeset, :retention_period_years) || 7
        archive_date = Date.utc_today()
        destruction_date = Date.add(archive_date, retention_years * 365)

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :archived)
        |> Ash.Changeset.force_change_attribute(:classification, :archived)
        |> Ash.Changeset.force_change_attribute(:archive_date, archive_date)
        |> Ash.Changeset.force_change_attribute(:destruction_date, destruction_date)
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
            fn report ->
              report.due_date &&
                Date.compare(
                  today,
                  report.due_date
                ) == :gt &&
                report.status not in [:published, :submitted, :archived, :cancelled]
            end
          )

        {:ok, values}
      end
    end

    calculate :days_until_due, :integer do
      calculation fn records, _context ->
        today = Date.utc_today()

        values =
          Enum.map(
            records,
            fn report ->
              if report.due_date do
                Date.diff(
                  report.due_date,
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

    calculate :preparation_days, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn report ->
              if report.creation_date && report.publication_date do
                Date.diff(
                  report.publication_date,
                  report.creation_date
                )
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :compliance_trend, :string do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn report ->
              case report.compliance_level do
                :fully_compliant -> "Excellent"
                :substantially_compliant -> "Good"
                :partially_compliant -> "Needs Improvement"
                :minimally_compliant -> "Poor"
                :non_compliant -> "Critical"
                _ -> "Unknown"
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
            fn report ->
              report.critical_findings * 4 +
                report.high_findings * 3 +
                report.medium_findings * 2 +
                report.low_findings * 1
            end
          )

        {:ok, values}
      end
    end

    calculate :total_effort, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn report ->
              prep = report.preparation_time_hours || 0
              review = report.review_time_hours || 0
              prep + review
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
      authorize_if actor_attribute_equals(:role, "executive")
      # Report author can read their reports
      authorize_if expr(author_id == ^actor(:id))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "legal")
    end

    policy action([:submit_for_review, :update_metrics, :add_feedback, :create_revision]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "auditor")
      # Report author can update their reports
      authorize_if expr(author_id == ^actor(:id))
    end

    policy action([:complete_review, :approve, :publish]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "manager")
    end

    policy action([:submit_regulatory, :archive]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :submit_for_review
    define :complete_review
    define :approve
    define :publish
    define :submit_regulatory
    define :update_metrics
    define :add_feedback
    define :create_revision
    define :archive
    define :destroy
  end

  postgres do
    table "compliance_reports"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :report_number], unique: true
      index [:framework_id], where: "framework_id IS NOT NULL"
      index [:assessment_id], where: "assessment_id IS NOT NULL"
      index [:author_id], where: "author_id IS NOT NULL"
      index [:reviewer_id], where: "reviewer_id IS NOT NULL"
      index [:approver_id], where: "approver_id IS NOT NULL"
      index [:report_type]
      index [:status]
      index [:workflow_stage], where: "workflow_stage IS NOT NULL"
      index [:classification]
      index [:confidentiality_level]
      index [:creation_date]
      index [:due_date], where: "due_date IS NOT NULL"
      index [:publication_date], where: "publication_date IS NOT NULL"
      index [:submission_date], where: "submission_date IS NOT NULL"
      index [:compliance_level], where: "compliance_level IS NOT NULL"
      index [:overall_risk_rating], where: "overall_risk_rating IS NOT NULL"

      index [:regulatory_requirement?],
        name: "reports_regulatory_requirement_index",
        where: "regulatory_requirement? = true"

      index [:follow_up_required?],
        name: "reports_follow_up_required_index",
        where: "follow_up_required? = true"

      index [:restricted_access?],
        name: "reports_restricted_access_index",
        where: "restricted_access? = true"

      index [:legal_hold?], name: "reports_legal_hold_index", where: "legal_hold? = true"
      index [:archive_date], where: "archive_date IS NOT NULL"
    end
  end

  # Helper functions
  defp generate_report_number(changeset) do
    # Generate report number like RPT-20251206-001
    date_str = Date.utc_today() |> Date.to_string() |> String.replace("-", "")

    random_suffix =
      :rand.uniform(999)
      |> Integer.to_string()
      |> String.pad_leading(3, "0")

    report_number = "RPT-#{date_str}-#{random_suffix}"

    Ash.Changeset.force_change_attribute(changeset, :report_number, report_number)
  end
end
