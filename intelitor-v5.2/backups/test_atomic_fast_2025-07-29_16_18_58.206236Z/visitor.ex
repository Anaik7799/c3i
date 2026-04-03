defmodule Intelitor.VisitorManagement.Visitor do
  @moduledoc """
  Visitor profiles with personal information and security clearance details.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.VisitorManagement,
    table: "visitors"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :visitor_id, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :first_name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :last_name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :email, :string do
      allow_nil? false
      constraints max_length: 255
    end

    attribute :phone_number, :string do
      constraints max_length: 20
    end

    attribute :company, :string do
      constraints max_length: 200
    end

    attribute :job_title, :string do
      constraints max_length: 100
    end

    attribute :nationality, :string do
      constraints max_length: 50
    end

    attribute :identification_type, :atom do
      constraints one_of: [
                    :drivers_license,
                    :passport,
                    :national_id,
                    :military_id,
                    :other
                  ]

      allow_nil? false
    end

    attribute :identification_number, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :identification_expiry, :date

    attribute :date_of_birth, :date

    attribute :emergency_contact_name, :string do
      constraints max_length: 100
    end

    attribute :emergency_contact_phone, :string do
      constraints max_length: 20
    end

    attribute :security_clearance_level, :atom do
      constraints one_of: [:none, :public_trust, :confidential, :secret, :top_secret]
      default :none
    end

    attribute :background_check_status, :atom do
      constraints one_of: [
                    :not_required,
                    :pending,
                    :in_progress,
                    :approved,
                    :rejected,
                    :expired
                  ]

      default :not_required
    end

    attribute :background_check_date, :date
    attribute :background_check_expiry, :date

    attribute :photo_url, :string do
      constraints max_length: 500
    end

    attribute :special_requirements, {:array, :string} do
      default []
    end

    attribute :blacklisted, :boolean do
      default false
    end

    attribute :blacklist_reason, :string do
      constraints max_length: 500
    end

    attribute :notes, :string do
      constraints max_length: 1000
    end

    timestamps()
  end

  relationships do
    belongs_to :visitor_type, Intelitor.VisitorManagement.VisitorType do
      allow_nil? false
      attribute_writable? true
    end

    has_many :visit_requests, Intelitor.VisitorManagement.VisitRequest do
      destination_attribute :visitor_id
    end

    has_many :visitor_passes, Intelitor.VisitorManagement.VisitorPass do
      destination_attribute :visitor_id
    end

    has_many :security_screenings, Intelitor.VisitorManagement.SecurityScreening do
      destination_attribute :visitor_id
    end

    has_many :compliance_records, Intelitor.VisitorManagement.VisitorCompliance do
      destination_attribute :visitor_id
    end
  end

  calculations do
    calculate :full_name, :string do
      calculation fn records, _ ->
        Enum.map(
          records,
          fn record ->
            "#{record.first_name} #{record.last_name}"
          end
        )
      end
    end

    calculate :is_clearance_expired, :boolean do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(
          records,
          fn record ->
            case record.background_check_expiry do
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

    calculate :days_until_clearance_expiry, :integer do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(
          records,
          fn record ->
            case record.background_check_expiry do
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
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    create :register_visitor do
      argument :visitor_id, :string do
        allow_nil? false
      end

      argument :first_name, :string do
        allow_nil? false
      end

      argument :last_name, :string do
        allow_nil? false
      end

      argument :email, :string do
        allow_nil? false
      end

      argument :visitor_type_id, :uuid do
        allow_nil? false
      end

      argument :identification_type, :atom do
        allow_nil? false
      end

      argument :identification_number, :string do
        allow_nil? false
      end

      change set_attribute(:visitor_id, arg(:visitor_id))
      change set_attribute(:first_name, arg(:first_name))
      change set_attribute(:last_name, arg(:last_name))
      change set_attribute(:email, arg(:email))
      change set_attribute(:visitor_type_id, arg(:visitor_type_id))
      change set_attribute(:identification_type, arg(:identification_type))
      change set_attribute(:identification_number, arg(:identification_number))
    end

    update :update_contact_info do
      require_atomic? false
      argument :phone_number, :string
      argument :company, :string
      argument :job_title, :string
      argument :emergency_contact_name, :string
      argument :emergency_contact_phone, :string

      change set_attribute(:phone_number, arg(:phone_number))
      change set_attribute(:company, arg(:company))
      change set_attribute(:job_title, arg(:job_title))
      change set_attribute(:emergency_contact_name, arg(:emergency_contact_name))
      change set_attribute(:emergency_contact_phone, arg(:emergency_contact_phone))
    end

    update :update_security_clearance do
      require_atomic? false
      argument :clearance_level, :atom do
        allow_nil? false
      end

      argument :background_check_status, :atom do
        allow_nil? false
      end

      argument :check_date, :date
      argument :expiry_date, :date

      change set_attribute(:security_clearance_level, arg(:clearance_level))
      change set_attribute(:background_check_status, arg(:background_check_status))
      change set_attribute(:background_check_date, arg(:check_date))
      change set_attribute(:background_check_expiry, arg(:expiry_date))
    end

    update :blacklist_visitor do
      require_atomic? false
      argument :reason, :string do
        allow_nil? false
      end

      change set_attribute(:blacklisted, true)
      change set_attribute(:blacklist_reason, arg(:reason))
    end

    update :remove_from_blacklist do
      require_atomic? false
      change set_attribute(:blacklisted, false)
      change set_attribute(:blacklist_reason, nil)
    end

    update :upload_photo do
      require_atomic? false
      argument :photo_url, :string do
        allow_nil? false
      end

      change set_attribute(:photo_url, arg(:photo_url))
    end
  end

  validations do
    validate match(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/),
      message: "must be a valid email address"
  end

  code_interface do
    define :create
    define :register_visitor
    define :update_contact_info
    define :update_security_clearance
    define :blacklist_visitor
    define :remove_from_blacklist
    define :upload_photo
  end

  postgres do
    table "visitors"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :visitor_id], unique: true
      index [:tenant_id, :email]
      index [:tenant_id, :identification_number], unique: true
      index [:tenant_id, :visitor_type_id]
      index [:tenant_id, :security_clearance_level]
      index [:tenant_id, :background_check_status]
      index [:tenant_id, :blacklisted]
      index [:tenant_id, :company]

      index [:tenant_id, :background_check_expiry],
        where: "background_check_expiry IS NOT NULL"
    end
  end
end
