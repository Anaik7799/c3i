defmodule Intelitor.VisitorManagement.SecurityScreening do
  @moduledoc """
  Security screening processes and background checks for visitors.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.VisitorManagement,
    table: "security_screenings"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :screening_type, :atom do
      constraints one_of: [
                    :basic_id_check,
                    :background_check,
                    :security_interview,
                    :biometric_enrollment,
                    :document_verification,
                    :reference_check
                  ]

      allow_nil? false
    end

    attribute :screening_status, :atom do
      constraints one_of: [
                    :scheduled,
                    :in_progress,
                    :completed,
                    :failed,
                    :cancelled,
                    :requires_escalation
                  ]

      default :scheduled
    end

    attribute :screening_level, :atom do
      constraints one_of: [:basic, :standard, :enhanced, :comprehensive]
      allow_nil? false
    end

    attribute :requested_date, :date do
      allow_nil? false
      default &Date.utc_today/0
    end

    attribute :scheduled_date, :date
    attribute :completed_date, :date

    attribute :screening_officer, :string do
      constraints max_length: 100
    end

    attribute :screening_location, :string do
      constraints max_length: 200
    end

    attribute :documents_verified, {:array, :string} do
      default []
    end

    attribute :biometric_data_collected, :boolean do
      default false
    end

    attribute :biometric_types, {:array, :atom} do
      default []
    end

    attribute :interview_conducted, :boolean do
      default false
    end

    attribute :interview_notes, :string do
      constraints max_length: 2000
    end

    attribute :background_check_provider, :string do
      constraints max_length: 100
    end

    attribute :background_check_reference, :string do
      constraints max_length: 100
    end

    attribute :screening_results, :map do
      default %{}
    end

    attribute :risk_assessment_score, :integer do
      constraints min: 0, max: 100
    end

    attribute :risk_factors_identified, {:array, :string} do
      default []
    end

    attribute :recommendations, {:array, :string} do
      default []
    end

    attribute :clearance_level_granted, :atom do
      constraints one_of: [:none, :basic, :standard, :confidential, :secret]
      default :none
    end

    attribute :clearance_conditions, {:array, :string} do
      default []
    end

    attribute :clearance_expiry_date, :date

    attribute :appeals_process_initiated, :boolean do
      default false
    end

    attribute :screening_notes, :string do
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

    belongs_to :requested_by, Intelitor.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :conducted_by, Intelitor.Accounts.User do
      attribute_writable? true
    end

    belongs_to :approved_by, Intelitor.Accounts.User do
      attribute_writable? true
    end
  end

  calculations do
    calculate :days_to_expiry, :integer do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          case record.clearance_expiry_date do
            nil -> nil
            expiry_date -> Date.diff(expiry_date, today)
          end
        end)
      end
    end

    calculate :is_clearance_expired, :boolean do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          case record.clearance_expiry_date do
            nil -> false
            expiry_date -> Date.compare(today, expiry_date) == :gt
          end
        end)
      end
    end

    calculate :screening_duration_days, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case {record.completed_date, record.requested_date} do
            {completed, requested} when not is_nil(completed) ->
              Date.diff(completed, requested)

            _ ->
              nil
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    create :initiate_screening do
      argument :visitor_id, :uuid do
        allow_nil? false
      end

      argument :screening_type, :atom do
        allow_nil? false
      end

      argument :screening_level, :atom do
        allow_nil? false
      end

      argument :requested_by_id, :uuid do
        allow_nil? false
      end

      argument :scheduled_date, :date

      change set_attribute(:visitor_id, arg(:visitor_id))
      change set_attribute(:screening_type, arg(:screening_type))
      change set_attribute(:screening_level, arg(:screening_level))
      change set_attribute(:requested_by_id, arg(:requested_by_id))
      change set_attribute(:scheduled_date, arg(:scheduled_date))
    end

    update :start_screening do
      require_atomic? false
      argument :conducted_by_id, :uuid do
        allow_nil? false
      end

      argument :screening_officer, :string
      argument :screening_location, :string

      change set_attribute(:screening_status, :in_progress)
      change set_attribute(:conducted_by_id, arg(:conducted_by_id))
      change set_attribute(:screening_officer, arg(:screening_officer))
      change set_attribute(:screening_location, arg(:screening_location))
    end

    update :verify_documents do
      require_atomic? false
      argument :documents, {:array, :string} do
        allow_nil? false
      end

      change set_attribute(:documents_verified, arg(:documents))
    end

    update :collect_biometrics do
      require_atomic? false
      argument :biometric_types, {:array, :atom} do
        allow_nil? false
      end

      change set_attribute(:biometric_data_collected, true)
      change set_attribute(:biometric_types, arg(:biometric_types))
    end

    update :conduct_interview do
      require_atomic? false
      argument :interview_notes, :string do
        allow_nil? false
      end

      change set_attribute(:interview_conducted, true)
      change set_attribute(:interview_notes, arg(:interview_notes))
    end

    update :complete_background_check do
      require_atomic? false
      argument :provider, :string do
        allow_nil? false
      end

      argument :reference_number, :string do
        allow_nil? false
      end

      argument :results, :map do
        allow_nil? false
      end

      change set_attribute(:background_check_provider, arg(:provider))
      change set_attribute(:background_check_reference, arg(:reference_number))
      change set_attribute(:screening_results, arg(:results))
    end

    update :assess_risk do
      require_atomic? false
      argument :risk_score, :integer do
        allow_nil? false
      end

      argument :risk_factors, {:array, :string}
      argument :recommendations, {:array, :string}

      change set_attribute(:risk_assessment_score, arg(:risk_score))
      change set_attribute(:risk_factors_identified, arg(:risk_factors))
      change set_attribute(:recommendations, arg(:recommendations))
    end

    update :complete_screening do
      require_atomic? false
      argument :clearance_level, :atom do
        allow_nil? false
      end

      argument :clearance_conditions, {:array, :string}
      argument :expiry_date, :date

      argument :approved_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:screening_status, :completed)
      change set_attribute(:completed_date, Date.utc_today())
      change set_attribute(:clearance_level_granted, arg(:clearance_level))
      change set_attribute(:clearance_conditions, arg(:clearance_conditions))
      change set_attribute(:clearance_expiry_date, arg(:expiry_date))
      change set_attribute(:approved_by_id, arg(:approved_by_id))
    end

    update :fail_screening do
      require_atomic? false
      argument :failure_reason, :string do
        allow_nil? false
      end

      change set_attribute(:screening_status, :failed)
      change set_attribute(:completed_date, Date.utc_today())
      change set_attribute(:clearance_level_granted, :none)
      change set_attribute(:screening_notes, arg(:failure_reason))
    end

    update :escalate_screening do
      require_atomic? false
      argument :escalation_reason, :string do
        allow_nil? false
      end

      change set_attribute(:screening_status, :requires_escalation)
      change set_attribute(:screening_notes, arg(:escalation_reason))
    end

    update :initiate_appeals_process do
      require_atomic? false
      change set_attribute(:appeals_process_initiated, true)
    end

    update :cancel_screening do
      require_atomic? false
      argument :cancellation_reason, :string do
        allow_nil? false
      end

      change set_attribute(:screening_status, :cancelled)
      change set_attribute(:screening_notes, arg(:cancellation_reason))
    end

    update :extend_clearance do
      require_atomic? false
      argument :new_expiry_date, :date do
        allow_nil? false
      end

      argument :extension_reason, :string do
        allow_nil? false
      end

      change set_attribute(:clearance_expiry_date, arg(:new_expiry_date))

      change fn changeset, _ ->
        current_notes = changeset.data.screening_notes || ""
        reason = Ash.Changeset.get_argument(changeset, :extension_reason)
        updated_notes = "#{current_notes}\n\nCLEARANCE EXTENDED: #{reason}"
        Ash.Changeset.change_attribute(changeset, :screening_notes, updated_notes)
      end
    end
  end

  code_interface do
    define :create
    define :initiate_screening
    define :start_screening
    define :verify_documents
    define :collect_biometrics
    define :conduct_interview
    define :complete_background_check
    define :assess_risk
    define :complete_screening
    define :fail_screening
    define :escalate_screening
    define :initiate_appeals_process
    define :cancel_screening
    define :extend_clearance
  end

  postgres do
    table "security_screenings"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :visitor_id]
      index [:tenant_id, :screening_type]
      index [:tenant_id, :screening_status]
      index [:tenant_id, :screening_level]
      index [:tenant_id, :requested_date]
      index [:tenant_id, :scheduled_date], where: "scheduled_date IS NOT NULL"
      index [:tenant_id, :completed_date], where: "completed_date IS NOT NULL"
      index [:tenant_id, :clearance_level_granted]
      index [:tenant_id, :clearance_expiry_date], where: "clearance_expiry_date IS NOT NULL"
      index [:tenant_id, :risk_assessment_score], where: "risk_assessment_score IS NOT NULL"
      index [:tenant_id, :appeals_process_initiated], where: "appeals_process_initiated = true"
    end
  end
end
