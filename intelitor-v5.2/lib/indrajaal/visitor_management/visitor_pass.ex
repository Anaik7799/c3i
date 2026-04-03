defmodule Indrajaal.VisitorManagement.VisitorPass do
  @moduledoc """
  Physical and digital visitor passes with access controls and tracking.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.VisitorManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :pass_number, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :pass_type, :atom do
      constraints one_of: [
                    :physical_badge,
                    :digital_pass,
                    :temporary_sticker,
                    :wristband,
                    :rfid_card
                  ]

      allow_nil? false
    end

    attribute :pass_status, :atom do
      constraints one_of: [
                    :issued,
                    :active,
                    :expired,
                    :revoked,
                    :lost,
                    :returned
                  ]

      default :issued
    end

    attribute :issued_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :valid_from, :utc_datetime do
      allow_nil? false
    end

    attribute :valid_until, :utc_datetime do
      allow_nil? false
    end

    attribute :revoked_at, :utc_datetime
    attribute :returned_at, :utc_datetime

    attribute :access_level, :atom do
      constraints one_of: [
                    :public_areas,
                    :restricted_areas,
                    :confidential_areas,
                    :secure_areas
                  ]

      default :public_areas
    end

    attribute :authorized_areas, {:array, :uuid} do
      default []
    end

    attribute :restricted_areas, {:array, :uuid} do
      default []
    end

    attribute :photo_url, :string do
      constraints max_length: 500
    end

    attribute :qr_code_data, :string do
      constraints max_length: 1000
    end

    attribute :rfid_uid, :string do
      constraints max_length: 50
    end

    attribute :security_features, :map do
      default %{}
    end

    attribute :escort_required, :boolean do
      default false
    end

    attribute :emergency_contact_info, :map do
      default %{}
    end

    attribute :special_conditions, {:array, :string} do
      default []
    end

    attribute :usage_count, :integer do
      default 0
    end

    attribute :last_used_at, :utc_datetime

    attribute :revocation_reason, :string do
      constraints max_length: 500
    end

    timestamps()
  end

  relationships do
    belongs_to :visitor, Indrajaal.VisitorManagement.Visitor do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :visit_request, Indrajaal.VisitorManagement.VisitRequest do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :issued_by, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :revoked_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    has_many :visitor_accesses, Indrajaal.VisitorManagement.VisitorAccess do
      destination_attribute :visitor_pass_id
    end
  end

  calculations do
    calculate :is_valid, :boolean do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          record.pass_status == :active &&
            DateTime.compare(now, record.valid_from) != :lt &&
            DateTime.compare(now, record.valid_until) == :lt
        end)
      end
    end

    calculate :is_expired, :boolean do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          DateTime.compare(now, record.valid_until) != :lt
        end)
      end
    end

    calculate :hours_remaining, :decimal do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          case record.pass_status do
            :active ->
              if DateTime.compare(now, record.valid_until) == :lt do
                diff_seconds = DateTime.diff(record.valid_until, now, :second)
                Decimal.div(diff_seconds, 3600)
              else
                Decimal.new(0)
              end

            _ ->
              nil
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :issue_pass do
      argument :pass_number, :string do
        allow_nil? false
      end

      argument :visitor_id, :uuid do
        allow_nil? false
      end

      argument :visit_request_id, :uuid do
        allow_nil? false
      end

      argument :issued_by_id, :uuid do
        allow_nil? false
      end

      argument :pass_type, :atom do
        allow_nil? false
      end

      argument :valid_from, :utc_datetime do
        allow_nil? false
      end

      argument :valid_until, :utc_datetime do
        allow_nil? false
      end

      change set_attribute(:pass_number, arg(:pass_number))
      change set_attribute(:visitor_id, arg(:visitor_id))
      change set_attribute(:visit_request_id, arg(:visit_request_id))
      change set_attribute(:issued_by_id, arg(:issued_by_id))
      change set_attribute(:pass_type, arg(:pass_type))
      change set_attribute(:valid_from, arg(:valid_from))
      change set_attribute(:valid_until, arg(:valid_until))
    end

    update :activate_pass do
      require_atomic? false
      change set_attribute(:pass_status, :active)
    end

    update :revoke_pass do
      require_atomic? false

      argument :revoked_by_id, :uuid do
        allow_nil? false
      end

      argument :reason, :string do
        allow_nil? false
      end

      change set_attribute(:pass_status, :revoked)
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
      change set_attribute(:revoked_by_id, arg(:revoked_by_id))
      change set_attribute(:revocation_reason, arg(:reason))
    end

    update :mark_lost do
      require_atomic? false
      change set_attribute(:pass_status, :lost)
    end

    update :mark_returned do
      require_atomic? false
      change set_attribute(:pass_status, :returned)
      change set_attribute(:returned_at, &DateTime.utc_now/0)
    end

    update :record_usage do
      require_atomic? false

      change fn changeset, _ ->
        current_count = changeset.data.usage_count || 0

        changeset
        |> Ash.Changeset.change_attribute(:usage_count, current_count + 1)
        |> Ash.Changeset.change_attribute(:last_used_at, DateTime.utc_now())
      end
    end

    update :set_access_areas do
      require_atomic? false

      argument :authorized_areas, {:array, :uuid} do
        allow_nil? false
      end

      argument :restricted_areas, {:array, :uuid}

      argument :access_level, :atom do
        allow_nil? false
      end

      change set_attribute(:authorized_areas, arg(:authorized_areas))
      change set_attribute(:restricted_areas, arg(:restricted_areas))
      change set_attribute(:access_level, arg(:access_level))
    end

    update :configure_security_features do
      require_atomic? false

      argument :features, :map do
        allow_nil? false
      end

      argument :qr_code_data, :string
      argument :rfid_uid, :string

      change set_attribute(:security_features, arg(:features))
      change set_attribute(:qr_code_data, arg(:qr_code_data))
      change set_attribute(:rfid_uid, arg(:rfid_uid))
    end

    update :_require_escort do
      require_atomic? false
      change set_attribute(:escort_required, true)
    end

    update :remove_escort_requirement do
      require_atomic? false
      change set_attribute(:escort_required, false)
    end

    update :add_special_conditions do
      require_atomic? false

      argument :conditions, {:array, :string} do
        allow_nil? false
      end

      change set_attribute(:special_conditions, arg(:conditions))
    end

    update :extend_validity do
      require_atomic? false

      argument :new_expiry, :utc_datetime do
        allow_nil? false
      end

      change set_attribute(:valid_until, arg(:new_expiry))
    end
  end

  validations do
    validate compare(:valid_until, greater_than: :valid_from),
      message: "Valid until must be after valid from"
  end

  code_interface do
    define :create
    define :issue_pass
    define :activate_pass
    define :revoke_pass
    define :mark_lost
    define :mark_returned
    define :record_usage
    define :set_access_areas
    define :configure_security_features
    define :_require_escort
    define :remove_escort_requirement
    define :add_special_conditions
    define :extend_validity
  end

  postgres do
    table "visitor_passes"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :pass_number], unique: true
      index [:tenant_id, :visitor_id]
      index [:tenant_id, :visit_request_id]
      index [:tenant_id, :pass_status]
      index [:tenant_id, :pass_type]
      index [:tenant_id, :valid_from, :valid_until]
      index [:tenant_id, :issued_by_id]

      index [:tenant_id, :rfid_uid],
        unique: true,
        where: "rfid_uid IS NOT NULL"

      index [:tenant_id, :last_used_at], where: "last_used_at IS NOT NULL"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Visitor management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
