defmodule Intelitor.VisitorManagement.VisitorCompliance do
  @moduledoc """
  Visitor compliance tracking and regulatory requirement management.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.VisitorManagement,
    table: "visitor_compliance"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :compliance_type, :atom do
      constraints one_of: [
                    :gdpr,
                    :hipaa,
                    :sox,
                    :pci_dss,
                    :iso_27001,
                    :nist,
                    :custom_policy
                  ]

      allow_nil? false
    end

    attribute :compliance_status, :atom do
      constraints one_of: [
                    :compliant,
                    :non_compliant,
                    :partial_compliance,
                    :pending_review,
                    :exempt
                  ]

      default :pending_review
    end

    attribute :assessment_date, :date do
      allow_nil? false
      default &Date.utc_today/0
    end

    attribute :compliance_requirements, {:array, :string} do
      default []
    end

    attribute :requirements_met, {:array, :string} do
      default []
    end

    attribute :requirements_not_met, {:array, :string} do
      default []
    end

    attribute :documentation_provided, {:array, :map} do
      default []
    end

    attribute :training_completed, {:array, :string} do
      default []
    end

    attribute :training_required, {:array, :string} do
      default []
    end

    attribute :consent_forms_signed, {:array, :string} do
      default []
    end

    attribute :data_processing_agreements, {:array, :map} do
      default []
    end

    attribute :privacy_briefing_completed, :boolean do
      default false
    end

    attribute :confidentiality_agreement_signed, :boolean do
      default false
    end

    attribute :access_restrictions, {:array, :string} do
      default []
    end

    attribute :monitoring_requirements, {:array, :string} do
      default []
    end

    attribute :retention_period_days, :integer do
      constraints min: 1, max: 7300
    end

    attribute :data_subject_rights, :map do
      default %{}
    end

    attribute :compliance_score, :decimal do
      constraints precision: 5, scale: 2, min: 0, max: 100
    end

    attribute :non_compliance_reasons, {:array, :string} do
      default []
    end

    attribute :corrective_actions_required, {:array, :string} do
      default []
    end

    attribute :corrective_actions_completed, {:array, :string} do
      default []
    end

    attribute :exemption_reason, :string do
      constraints max_length: 500
    end

    attribute :review_date, :date
    attribute :next_assessment_date, :date

    attribute :compliance_notes, :string do
      constraints max_length: 2000
    end

    timestamps()
  end

  relationships do
    belongs_to :visitor, Intelitor.VisitorManagement.Visitor do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :visit_request, Intelitor.VisitorManagement.VisitRequest do
      attribute_writable? true
    end

    belongs_to :assessed_by, Intelitor.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :reviewed_by, Intelitor.Accounts.User do
      attribute_writable? true
    end
  end

  calculations do
    calculate :compliance_percentage, :decimal do
      calculation fn records, _ ->
        Enum.map(
          records,
          fn record ->
            total_requirements = length(record.compliance_requirements || [])
            met_requirements = length(record.requirements_met || [])

            if total_requirements > 0 do
              Decimal.div(
                Decimal.mult(
                  met_requirements,
                  100
                ),
                total_requirements
              )
            else
              Decimal.new(100)
            end
          end
        )
      end
    end

    calculate :days_until_review, :integer do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(
          records,
          fn record ->
            case record.next_assessment_date do
              nil ->
                nil

              next_date ->
                Date.diff(
                  next_date,
                  today
                )
            end
          end
        )
      end
    end

    calculate :is_review_overdue, :boolean do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(
          records,
          fn record ->
            case record.next_assessment_date do
              nil ->
                false

              next_date ->
                Date.compare(
                  today,
                  next_date
                ) == :gt
            end
          end
        )
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    create :initiate_compliance_assessment do
      argument :visitor_id, :uuid do
        allow_nil? false
      end

      argument :compliance_type, :atom do
        allow_nil? false
      end

      argument :assessed_by_id, :uuid do
        allow_nil? false
      end

      argument :requirements, {:array, :string} do
        allow_nil? false
      end

      change set_attribute(:visitor_id, arg(:visitor_id))
      change set_attribute(:compliance_type, arg(:compliance_type))
      change set_attribute(:assessed_by_id, arg(:assessed_by_id))
      change set_attribute(:compliance_requirements, arg(:requirements))
    end

    update :assess_requirements do
      require_atomic? false
      argument :requirements_met, {:array, :string} do
        allow_nil? false
      end

      argument :requirements_not_met, {:array, :string}

      change set_attribute(:requirements_met, arg(:requirements_met))
      change set_attribute(:requirements_not_met, arg(:requirements_not_met))

      change fn changeset, _ ->
        met = length(Ash.Changeset.get_argument(changeset, :requirements_met))
        not_met = length(Ash.Changeset.get_argument(changeset, :requirements_not_met) || [])
        total = met + not_met

        status =
          cond do
            not_met == 0 -> :compliant
            met == 0 -> :non_compliant
            true -> :partial_compliance
          end

        score =
          if total > 0 do
            Decimal.div(Decimal.mult(met, 100), total)
          else
            Decimal.new(100)
          end

        changeset
        |> Ash.Changeset.change_attribute(:compliance_status, status)
        |> Ash.Changeset.change_attribute(:compliance_score, score)
      end
    end

    update :submit_documentation do
      require_atomic? false
      argument :documents, {:array, :map} do
        allow_nil? false
      end

      change set_attribute(:documentation_provided, arg(:documents))
    end

    update :complete_training do
      require_atomic? false
      argument :training_completed, {:array, :string} do
        allow_nil? false
      end

      change set_attribute(:training_completed, arg(:training_completed))
    end

    update :sign_consent_forms do
      require_atomic? false
      argument :forms_signed, {:array, :string} do
        allow_nil? false
      end

      change set_attribute(:consent_forms_signed, arg(:forms_signed))
    end

    update :complete_privacy_briefing do
      require_atomic? false
      change set_attribute(:privacy_briefing_completed, true)
    end

    update :sign_confidentiality_agreement do
      require_atomic? false
      change set_attribute(:confidentiality_agreement_signed, true)
    end

    update :set_data_processing_agreements do
      require_atomic? false
      argument :agreements, {:array, :map} do
        allow_nil? false
      end

      change set_attribute(:data_processing_agreements, arg(:agreements))
    end

    update :apply_access_restrictions do
      require_atomic? false
      argument :restrictions, {:array, :string} do
        allow_nil? false
      end

      argument :monitoring_requirements, {:array, :string}

      change set_attribute(:access_restrictions, arg(:restrictions))
      change set_attribute(:monitoring_requirements, arg(:monitoring_requirements))
    end

    update :set_retention_policy do
      require_atomic? false
      argument :retention_days, :integer do
        allow_nil? false
      end

      argument :data_subject_rights, :map do
        allow_nil? false
      end

      change set_attribute(:retention_period_days, arg(:retention_days))
      change set_attribute(:data_subject_rights, arg(:data_subject_rights))
    end

    update :identify_non_compliance do
      require_atomic? false
      argument :reasons, {:array, :string} do
        allow_nil? false
      end

      argument :corrective_actions, {:array, :string} do
        allow_nil? false
      end

      change set_attribute(:compliance_status, :non_compliant)
      change set_attribute(:non_compliance_reasons, arg(:reasons))
      change set_attribute(:corrective_actions_required, arg(:corrective_actions))
    end

    update :complete_corrective_actions do
      require_atomic? false
      argument :actions_completed, {:array, :string} do
        allow_nil? false
      end

      change set_attribute(:corrective_actions_completed, arg(:actions_completed))

      change fn changeset, _ ->
        required = length(changeset.data.corrective_actions_required || [])
        completed = length(Ash.Changeset.get_argument(changeset, :actions_completed))

        new_status =
          if completed >= required do
            :compliant
          else
            :partial_compliance
          end

        Ash.Changeset.change_attribute(changeset, :compliance_status, new_status)
      end
    end

    update :grant_exemption do
      require_atomic? false
      argument :exemption_reason, :string do
        allow_nil? false
      end

      change set_attribute(:compliance_status, :exempt)
      change set_attribute(:exemption_reason, arg(:exemption_reason))
    end

    update :schedule_review do
      require_atomic? false
      argument :review_date, :date do
        allow_nil? false
      end

      argument :next_assessment_date, :date do
        allow_nil? false
      end

      change set_attribute(:review_date, arg(:review_date))
      change set_attribute(:next_assessment_date, arg(:next_assessment_date))
    end

    update :review_compliance do
      require_atomic? false
      argument :reviewed_by_id, :uuid do
        allow_nil? false
      end

      argument :review_notes, :string

      change set_attribute(:reviewed_by_id, arg(:reviewed_by_id))
      change set_attribute(:review_date, Date.utc_today())
      change set_attribute(:compliance_notes, arg(:review_notes))
    end
  end

  code_interface do
    define :create
    define :initiate_compliance_assessment
    define :assess_requirements
    define :submit_documentation
    define :complete_training
    define :sign_consent_forms
    define :complete_privacy_briefing
    define :sign_confidentiality_agreement
    define :set_data_processing_agreements
    define :apply_access_restrictions
    define :set_retention_policy
    define :identify_non_compliance
    define :complete_corrective_actions
    define :grant_exemption
    define :schedule_review
    define :review_compliance
  end

  postgres do
    table "visitor_compliance"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :visitor_id]
      index [:tenant_id, :compliance_type]
      index [:tenant_id, :compliance_status]
      index [:tenant_id, :assessment_date]

      index [:tenant_id, :next_assessment_date],
        where: "next_assessment_date IS NOT NULL"

      index [:tenant_id, :compliance_score], where: "compliance_score IS NOT NULL"
      index [:tenant_id, :assessed_by_id]
      index [:tenant_id, :reviewed_by_id], where: "reviewed_by_id IS NOT NULL"
      index [:tenant_id, :privacy_briefing_completed]
      index [:tenant_id, :confidentiality_agreement_signed]
    end
  end
end
