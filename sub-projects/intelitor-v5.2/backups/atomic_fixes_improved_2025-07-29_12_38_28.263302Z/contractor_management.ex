defmodule Intelitor.VisitorManagement.ContractorManagement do
  @moduledoc """
  Extended contractor management with project tracking and certification requirements.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.VisitorManagement,
    table: "contractor_management"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :contractor_id, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :company_name, :string do
      allow_nil? false
      constraints max_length: 200
    end

    attribute :contractor_type, :atom do
      constraints one_of: [
                    :general_contractor,
                    :subcontractor,
                    :consultant,
                    :vendor,
                    :service_provider,
                    :specialist
                  ]

      allow_nil? false
    end

    attribute :project_name, :string do
      constraints max_length: 200
    end

    attribute :project_description, :string do
      constraints max_length: 1000
    end

    attribute :contract_reference, :string do
      constraints max_length: 100
    end

    attribute :project_start_date, :date
    attribute :project_end_date, :date

    attribute :work_areas, {:array, :uuid} do
      default []
    end

    attribute :work_schedule, :map do
      default %{}
    end

    attribute :safety_certifications, {:array, :string} do
      default []
    end

    attribute :required_certifications, {:array, :string} do
      default []
    end

    attribute :insurance_provider, :string do
      constraints max_length: 200
    end

    attribute :insurance_policy_number, :string do
      constraints max_length: 100
    end

    attribute :insurance_expiry_date, :date

    attribute :liability_coverage_amount, :decimal do
      constraints precision: 15, scale: 2
    end

    attribute :contact_person, :string do
      constraints max_length: 100
    end

    attribute :contact_phone, :string do
      constraints max_length: 20
    end

    attribute :contact_email, :string do
      constraints max_length: 255
    end

    attribute :emergency_contact, :map do
      default %{}
    end

    attribute :equipment_list, {:array, :map} do
      default []
    end

    attribute :hazardous_materials, {:array, :map} do
      default []
    end

    attribute :safety_protocols, {:array, :string} do
      default []
    end

    attribute :contractor_status, :atom do
      constraints one_of: [:active, :suspended, :terminated, :completed, :on_hold]
      default :active
    end

    attribute :performance_rating, :decimal do
      constraints precision: 3, scale: 2, min: 0, max: 5
    end

    attribute :safety_incidents, :integer do
      default 0
    end

    attribute :compliance_violations, :integer do
      default 0
    end

    attribute :contract_notes, :string do
      constraints max_length: 2000
    end

    timestamps()
  end

  relationships do
    belongs_to :visitor, Intelitor.VisitorManagement.Visitor do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :project_manager, Intelitor.Accounts.User do
      attribute_writable? true
    end

    belongs_to :safety_officer, Intelitor.Accounts.User do
      attribute_writable? true
    end
  end

  calculations do
    calculate :project_duration_days, :integer do
      calculation fn records, _ ->
        Enum.map(
          records,
          fn record ->
            case {record.project_start_date, record.project_end_date} do
              {start_date, end_date} when not is_nil(start_date) and not is_nil(end_date) ->
                Date.diff(end_date, start_date)

              _ ->
                nil
            end
          end
        )
      end
    end

    calculate :days_until_insurance_expiry, :integer do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(
          records,
          fn record ->
            case record.insurance_expiry_date do
              nil ->
                nil

              expiry_date ->
                Date.diff(
                  expiry_date,
                  today
                )
            end
          end
        )
      end
    end

    calculate :is_insurance_expired, :boolean do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(
          records,
          fn record ->
            case record.insurance_expiry_date do
              nil ->
                false

              expiry_date ->
                Date.compare(
                  today,
                  expiry_date
                ) == :gt
            end
          end
        )
      end
    end

    calculate :safety_score, :decimal do
      calculation fn records, _ ->
        Enum.map(
          records,
          fn record ->
            base_score = 100
            incidents = record.safety_incidents || 0
            violations = record.compliance_violations || 0

            penalty = incidents * 10 + violations * 5

            final_score =
              max(
                0,
                base_score - penalty
              )

            Decimal.new(final_score)
          end
        )
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    create :register_contractor do
      argument :contractor_id, :string do
        allow_nil? false
      end

      argument :visitor_id, :uuid do
        allow_nil? false
      end

      argument :company_name, :string do
        allow_nil? false
      end

      argument :contractor_type, :atom do
        allow_nil? false
      end

      argument :project_name, :string

      argument :contact_person, :string do
        allow_nil? false
      end

      change set_attribute(:contractor_id, arg(:contractor_id))
      change set_attribute(:visitor_id, arg(:visitor_id))
      change set_attribute(:company_name, arg(:company_name))
      change set_attribute(:contractor_type, arg(:contractor_type))
      change set_attribute(:project_name, arg(:project_name))
      change set_attribute(:contact_person, arg(:contact_person))
    end

    update :update_project_details do
      require_atomic? false
      argument :project_description, :string
      argument :contract_reference, :string
      argument :start_date, :date
      argument :end_date, :date
      argument :project_manager_id, :uuid

      change set_attribute(:project_description, arg(:project_description))
      change set_attribute(:contract_reference, arg(:contract_reference))
      change set_attribute(:project_start_date, arg(:start_date))
      change set_attribute(:project_end_date, arg(:end_date))
      change set_attribute(:project_manager_id, arg(:project_manager_id))
    end

    update :update_insurance_info do
      require_atomic? false
      argument :provider, :string do
        allow_nil? false
      end

      argument :policy_number, :string do
        allow_nil? false
      end

      argument :expiry_date, :date do
        allow_nil? false
      end

      argument :coverage_amount, :decimal do
        allow_nil? false
      end

      change set_attribute(:insurance_provider, arg(:provider))
      change set_attribute(:insurance_policy_number, arg(:policy_number))
      change set_attribute(:insurance_expiry_date, arg(:expiry_date))
      change set_attribute(:liability_coverage_amount, arg(:coverage_amount))
    end

    update :update_certifications do
      require_atomic? false
      argument :safety_certifications, {:array, :string} do
        allow_nil? false
      end

      argument :required_certifications, {:array, :string} do
        allow_nil? false
      end

      change set_attribute(:safety_certifications, arg(:safety_certifications))
      change set_attribute(:required_certifications, arg(:required_certifications))
    end

    update :assign_work_areas do
      require_atomic? false
      argument :work_areas, {:array, :uuid} do
        allow_nil? false
      end

      argument :work_schedule, :map

      change set_attribute(:work_areas, arg(:work_areas))
      change set_attribute(:work_schedule, arg(:work_schedule))
    end

    update :register_equipment do
      require_atomic? false
      argument :equipment_list, {:array, :map} do
        allow_nil? false
      end

      change set_attribute(:equipment_list, arg(:equipment_list))
    end

    update :register_hazardous_materials do
      require_atomic? false
      argument :materials, {:array, :map} do
        allow_nil? false
      end

      argument :safety_protocols, {:array, :string} do
        allow_nil? false
      end

      change set_attribute(:hazardous_materials, arg(:materials))
      change set_attribute(:safety_protocols, arg(:safety_protocols))
    end

    update :report_safety_incident do
      require_atomic? false
      argument :incident_details, :string do
        allow_nil? false
      end

      change fn changeset, _ ->
        current_incidents = changeset.data.safety_incidents || 0
        incident_details = Ash.Changeset.get_argument(changeset, :incident_details)
        current_notes = changeset.data.contract_notes || ""

        updated_notes =
          if current_notes == "" do
            "SAFETY INCIDENT: #{incident_details}"
          else
            "#{current_notes}\n\nSAFETY INCIDENT: #{incident_details}"
          end

        changeset
        |> Ash.Changeset.change_attribute(:safety_incidents, current_incidents + 1)
        |> Ash.Changeset.change_attribute(:contract_notes, updated_notes)
      end
    end

    update :report_compliance_violation do
      require_atomic? false
      argument :violation_details, :string do
        allow_nil? false
      end

      change fn changeset, _ ->
        current_violations = changeset.data.compliance_violations || 0
        violation_details = Ash.Changeset.get_argument(changeset, :violation_details)
        current_notes = changeset.data.contract_notes || ""

        updated_notes =
          if current_notes == "" do
            "COMPLIANCE VIOLATION: #{violation_details}"
          else
            "#{current_notes}\n\nCOMPLIANCE VIOLATION: #{violation_details}"
          end

        changeset
        |> Ash.Changeset.change_attribute(:compliance_violations, current_violations + 1)
        |> Ash.Changeset.change_attribute(:contract_notes, updated_notes)
      end

          end

    update :update_performance_rating do
      require_atomic? false
      argument :rating, :decimal do
        allow_nil? false
      end

      argument :rating_notes, :string

      change set_attribute(:performance_rating, arg(:rating))

      change fn changeset, _ ->
        current_notes = changeset.data.contract_notes || ""
        rating_notes = Ash.Changeset.get_argument(changeset, :rating_notes)

        updated_notes =
          if rating_notes do
            "#{current_notes}\n\nPERFORMANCE RATING: #{rating_notes}"
          else
            current_notes
          end

        Ash.Changeset.change_attribute(changeset, :contract_notes, updated_notes)
      end

          end

    update :suspend_contractor do
      require_atomic? false
      argument :suspension_reason, :string do
        allow_nil? false
      end

      change set_attribute(:contractor_status, :suspended)

      change fn changeset, _ ->
        current_notes = changeset.data.contract_notes || ""
        reason = Ash.Changeset.get_argument(changeset, :suspension_reason)
        updated_notes = "#{current_notes}\n\nSUSPENDED: #{reason}"
        Ash.Changeset.change_attribute(changeset, :contract_notes, updated_notes)
      end

          end

    update :reactivate_contractor do
      require_atomic? false
      argument :reactivation_reason, :string do
        allow_nil? false
      end

      change set_attribute(:contractor_status, :active)

      change fn changeset, _ ->
        current_notes = changeset.data.contract_notes || ""
        reason = Ash.Changeset.get_argument(changeset, :reactivation_reason)
        updated_notes = "#{current_notes}\n\nREACTIVATED: #{reason}"
        Ash.Changeset.change_attribute(changeset, :contract_notes, updated_notes)
      end

          end

    update :complete_project do
      require_atomic? false
      argument :completion_notes, :string do
        allow_nil? false
      end

      change set_attribute(:contractor_status, :completed)

      change fn changeset, _ ->
        current_notes = changeset.data.contract_notes || ""
        notes = Ash.Changeset.get_argument(changeset, :completion_notes)
        updated_notes = "#{current_notes}\n\nPROJECT COMPLETED: #{notes}"
        Ash.Changeset.change_attribute(changeset, :contract_notes, updated_notes)
      end

          end
  end

  validations do
    validate compare(:project_end_date, greater_than: :project_start_date),
      message: "Project end date must be after start date",
      where: [present([:project_start_date, :project_end_date])]

    validate match(:contact_email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/),
      message: "must be a valid email address",
      where: [present(:contact_email)]
  end

  code_interface do
    define :create
    define :register_contractor
    define :update_project_details
    define :update_insurance_info
    define :update_certifications
    define :assign_work_areas
    define :register_equipment
    define :register_hazardous_materials
    define :report_safety_incident
    define :report_compliance_violation
    define :update_performance_rating
    define :suspend_contractor
    define :reactivate_contractor
    define :complete_project
  end

  postgres do
    table "contractor_management"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :contractor_id], unique: true
      index [:tenant_id, :visitor_id]
      index [:tenant_id, :company_name]
      index [:tenant_id, :contractor_type]
      index [:tenant_id, :contractor_status]
      index [:tenant_id, :project_start_date], where: "project_start_date IS NOT NULL"
      index [:tenant_id, :project_end_date], where: "project_end_date IS NOT NULL"

      index [:tenant_id, :insurance_expiry_date],
        where: "insurance_expiry_date IS NOT NULL"

      index [:tenant_id, :safety_incidents], where: "safety_incidents > 0"
      index [:tenant_id, :performance_rating], where: "performance_rating IS NOT NULL"
    end
  end
end
