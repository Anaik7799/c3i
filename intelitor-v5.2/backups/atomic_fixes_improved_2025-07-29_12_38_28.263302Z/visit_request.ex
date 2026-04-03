defmodule Intelitor.VisitorManagement.VisitRequest do
  @moduledoc """
  Visit requests with scheduling, approval workflows, and access requirements.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.VisitorManagement,
    table: "visit_requests"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :request_id, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :visit_purpose, :string do
      allow_nil? false
      constraints max_length: 500
    end

    attribute :visit_type, :atom do
      constraints one_of: [
                    :business_meeting,
                    :site_tour,
                    :delivery,
                    :maintenance,
                    :installation,
                    :inspection,
                    :emergency,
                    :other
                  ]

      allow_nil? false
    end

    attribute :scheduled_arrival, :utc_datetime do
      allow_nil? false
    end

    attribute :scheduled_departure, :utc_datetime do
      allow_nil? false
    end

    attribute :actual_arrival, :utc_datetime
    attribute :actual_departure, :utc_datetime

    attribute :requested_areas, {:array, :uuid} do
      default []
    end

    attribute :equipment_bringing, {:array, :string} do
      default []
    end

    attribute :vehicle_details, :map do
      default %{}
    end

    attribute :number_of_visitors, :integer do
      default 1
      constraints min: 1, max: 50
    end

    attribute :additional_visitors, {:array, :map} do
      default []
    end

    attribute :special_instructions, :string do
      constraints max_length: 1000
    end

    attribute :request_status, :atom do
      constraints one_of: [
                    :submitted,
                    :under_review,
                    :approved,
                    :rejected,
                    :cancelled,
                    :completed
                  ]

      default :submitted
    end

    attribute :priority_level, :atom do
      constraints one_of: [:low, :medium, :high, :emergency]
      default :medium
    end

    attribute :approval_deadline, :utc_datetime

    attribute :rejection_reason, :string do
      constraints max_length: 500
    end

    attribute :compliance_requirements, {:array, :string} do
      default []
    end

    attribute :security_briefing_required, :boolean do
      default false
    end

    attribute :emergency_contact_notified, :boolean do
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :visitor, Intelitor.VisitorManagement.Visitor do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :visitor_type, Intelitor.VisitorManagement.VisitorType do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :requesting_employee, Intelitor.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :site, Intelitor.Sites.Site do
      allow_nil? false
      attribute_writable? true
    end

    has_many :approvals, Intelitor.VisitorManagement.VisitApproval do
      destination_attribute :visit_request_id
    end

    has_one :visitor_pass, Intelitor.VisitorManagement.VisitorPass do
      destination_attribute :visit_request_id
    end

    has_many :visitor_accesses, Intelitor.VisitorManagement.VisitorAccess do
      destination_attribute :visit_request_id
    end
  end

  calculations do
    calculate :visit_duration_hours, :decimal do
      calculation fn records, _ ->
        Enum.map(
          records,
          fn record ->
            case {record.actual_departure, record.actual_arrival} do
              {departure, arrival} when not is_nil(departure) and not is_nil(arrival) ->
                Decimal.div(DateTime.diff(departure, arrival, :second), 3600)

              _ ->
                case {record.scheduled_departure, record.scheduled_arrival} do
                  {departure, arrival}
                  when not is_nil(departure) and not is_nil(arrival) ->
                    Decimal.div(DateTime.diff(departure, arrival, :second), 3600)

                  _ ->
                    nil
                end
            end
          end
        )
      end
    end

    calculate :is_overdue_for_approval, :boolean do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(
          records,
          fn record ->
            case {record.request_status, record.approval_deadline} do
              {status, deadline}
              when status in [:submitted, :under_review] and not is_nil(deadline) ->
                DateTime.compare(now, deadline) == :gt

              _ ->
                false
            end
          end
        )
      end
    end

    calculate :is_visit_active, :boolean do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(
          records,
          fn record ->
            case record.request_status do
              :approved ->
                arrival_passed =
                  DateTime.compare(
                    now,
                    record.scheduled_arrival
                  ) != :lt

                departure_not_passed =
                  case record.actual_departure do
                    nil -> DateTime.compare(now, record.scheduled_departure) == :lt
                    _ -> false
                  end

                arrival_passed and departure_not_passed

              _ ->
                false
            end
          end
        )
      end
    end
  end

  actions do
    defaults [:read, :create, :destroy]

    create :submit_request do
      argument :request_id, :string do
        allow_nil? false
      end

      argument :visitor_id, :uuid do
        allow_nil? false
      end

      argument :visitor_type_id, :uuid do
        allow_nil? false
      end

      argument :requesting_employee_id, :uuid do
        allow_nil? false
      end

      argument :site_id, :uuid do
        allow_nil? false
      end

      argument :visit_purpose, :string do
        allow_nil? false
      end

      argument :visit_type, :atom do
        allow_nil? false
      end

      argument :scheduled_arrival, :utc_datetime do
        allow_nil? false
      end

      argument :scheduled_departure, :utc_datetime do
        allow_nil? false
      end

      change set_attribute(:request_id, arg(:request_id))
      change set_attribute(:visitor_id, arg(:visitor_id))
      change set_attribute(:visitor_type_id, arg(:visitor_type_id))
      change set_attribute(:requesting_employee_id, arg(:requesting_employee_id))
      change set_attribute(:site_id, arg(:site_id))
      change set_attribute(:visit_purpose, arg(:visit_purpose))
      change set_attribute(:visit_type, arg(:visit_type))
      change set_attribute(:scheduled_arrival, arg(:scheduled_arrival))
      change set_attribute(:scheduled_departure, arg(:scheduled_departure))
    end

    update :update_status do
      require_atomic? false
      argument :new_status, :atom do
        allow_nil? false
      end

      change set_attribute(:request_status, arg(:new_status))
    end

    update :approve_request do
      require_atomic? false
      change set_attribute(:request_status, :approved)
    end

    update :reject_request do
      require_atomic? false
      argument :rejection_reason, :string do
        allow_nil? false
      end

      change set_attribute(:request_status, :rejected)
      change set_attribute(:rejection_reason, arg(:rejection_reason))
    end

    update :cancel_request do
      require_atomic? false
      argument :cancellation_reason, :string

      change set_attribute(:request_status, :cancelled)
      change set_attribute(:rejection_reason, arg(:cancellation_reason))
    end

    update :record_arrival do
      require_atomic? false
      change set_attribute(:actual_arrival, &DateTime.utc_now/0)
    end

    update :record_departure do
      require_atomic? false
      change set_attribute(:actual_departure, &DateTime.utc_now/0)
      change set_attribute(:request_status, :completed)
    end

    update :set_approval_deadline do
      require_atomic? false
      argument :deadline, :utc_datetime do
        allow_nil? false
      end

      change set_attribute(:approval_deadline, arg(:deadline))
    end

    update :add_equipment_list do
      require_atomic? false
      argument :equipment, {:array, :string} do
        allow_nil? false
      end

      change set_attribute(:equipment_bringing, arg(:equipment))
    end

    update :add_vehicle_details do
      require_atomic? false
      argument :vehicle_info, :map do
        allow_nil? false
      end

      change set_attribute(:vehicle_details, arg(:vehicle_info))
    end

    update :add_additional_visitors do
      require_atomic? false
      argument :additional_visitors, {:array, :map} do
        allow_nil? false
      end

      argument :total_count, :integer do
        allow_nil? false
      end

      change set_attribute(:additional_visitors, arg(:additional_visitors))
      change set_attribute(:number_of_visitors, arg(:total_count))
    end

    update :set_compliance_requirements do
      require_atomic? false
      argument :requirements, {:array, :string} do
        allow_nil? false
      end

      change set_attribute(:compliance_requirements, arg(:requirements))
    end

    update :require_security_briefing do
      require_atomic? false
      change set_attribute(:security_briefing_required, true)
    end
  end

  validations do
    validate compare(:scheduled_departure, greater_than: :scheduled_arrival),
      message: "Departure time must be after arrival time"

    validate compare(:actual_departure, greater_than: :actual_arrival),
      message: "Actual departure must be after actual arrival",
      where: [present([:actual_arrival, :actual_departure])]
  end

  code_interface do
    define :create
    define :submit_request
    define :update_status
    define :approve_request
    define :reject_request
    define :cancel_request
    define :record_arrival
    define :record_departure
    define :set_approval_deadline
    define :add_equipment_list
    define :add_vehicle_details
    define :add_additional_visitors
    define :set_compliance_requirements
    define :require_security_briefing
  end

  postgres do
    table "visit_requests"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :request_id], unique: true
      index [:tenant_id, :visitor_id]
      index [:tenant_id, :requesting_employee_id]
      index [:tenant_id, :site_id]
      index [:tenant_id, :request_status]
      index [:tenant_id, :visit_type]
      index [:tenant_id, :priority_level]
      index [:tenant_id, :scheduled_arrival]
      index [:tenant_id, :scheduled_departure]
      index [:tenant_id, :approval_deadline], where: "approval_deadline IS NOT NULL"
    end
  end
end
