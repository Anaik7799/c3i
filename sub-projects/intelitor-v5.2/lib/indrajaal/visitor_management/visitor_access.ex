defmodule Indrajaal.VisitorManagement.VisitorAccess do
  @moduledoc """
  Real - time visitor access tracking and location monitoring.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.VisitorManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :access_event_type, :atom do
      constraints one_of: [
                    :entry,
                    :exit,
                    :area_change,
                    :access_denied,
                    :tailgating_detected,
                    :emergency_exit
                  ]

      allow_nil? false
    end

    attribute :timestamp, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :access_method, :atom do
      constraints one_of: [
                    :badge_scan,
                    :qr_code_scan,
                    :biometric,
                    :manual_override,
                    :escort_verification
                  ]

      allow_nil? false
    end

    attribute :access_result, :atom do
      constraints one_of: [:granted, :denied, :forced, :emergency]
      allow_nil? false
    end

    attribute :denial_reason, :string do
      constraints max_length: 200
    end

    attribute :location_from, :uuid
    attribute :location_to, :uuid

    attribute :device_identifier, :string do
      constraints max_length: 100
    end

    attribute :reader_location, :string do
      constraints max_length: 200
    end

    attribute :verification_method, :string do
      constraints max_length: 100
    end

    attribute :additional_data, :map do
      default %{}
    end

    attribute :security_alert_triggered, :boolean do
      default false
    end

    attribute :alert_level, :atom do
      constraints one_of: [:info, :warning, :high, :critical]
      default :info
    end

    attribute :incident_reported, :boolean do
      default false
    end

    attribute :follow_up_required, :boolean do
      default false
    end

    attribute :notes, :string do
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

    belongs_to :visitor_pass, Indrajaal.VisitorManagement.VisitorPass do
      attribute_writable? true
    end

    belongs_to :authorizing_escort, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    belongs_to :location_from_ref, Indrajaal.Sites.Location do
      attribute_writable? true
    end

    belongs_to :location_to_ref, Indrajaal.Sites.Location do
      attribute_writable? true
    end
  end

  calculations do
    calculate :duration_at_location, :integer do
      calculation fn records, _ ->
        # This would typically be calculated based on consecutive access _events
        # For now, we'll return nil as it _requires complex logic
        Enum.map(records, fn _record -> nil end)
      end
    end

    calculate :is_security_concern, :boolean do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          record.access_result == :denied ||
            record.security_alert_triggered ||
            record.access_event_type in [:access_denied, :tailgating_detected] ||
            record.alert_level in [:high, :critical]
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :log_access_event do
      argument :visitor_id, :uuid do
        allow_nil? false
      end

      argument :visit_request_id, :uuid do
        allow_nil? false
      end

      argument :_event_type, :atom do
        allow_nil? false
      end

      argument :access_method, :atom do
        allow_nil? false
      end

      argument :access_result, :atom do
        allow_nil? false
      end

      argument :device_identifier, :string
      argument :location_to, :uuid

      change set_attribute(:visitor_id, arg(:visitor_id))
      change set_attribute(:visit_request_id, arg(:visit_request_id))
      change set_attribute(:access_event_type, arg(:_event_type))
      change set_attribute(:access_method, arg(:access_method))
      change set_attribute(:access_result, arg(:access_result))
      change set_attribute(:device_identifier, arg(:device_identifier))
      change set_attribute(:location_to, arg(:location_to))
    end

    create :log_denied_access do
      argument :visitor_id, :uuid do
        allow_nil? false
      end

      argument :visit_request_id, :uuid do
        allow_nil? false
      end

      argument :access_method, :atom do
        allow_nil? false
      end

      argument :denial_reason, :string do
        allow_nil? false
      end

      argument :device_identifier, :string
      argument :alert_level, :atom, default: :warning

      change set_attribute(:visitor_id, arg(:visitor_id))
      change set_attribute(:visit_request_id, arg(:visit_request_id))
      change set_attribute(:access_event_type, :access_denied)
      change set_attribute(:access_method, arg(:access_method))
      change set_attribute(:access_result, :denied)
      change set_attribute(:denial_reason, arg(:denial_reason))
      change set_attribute(:device_identifier, arg(:device_identifier))
      change set_attribute(:security_alert_triggered, true)
      change set_attribute(:alert_level, arg(:alert_level))
    end

    update :trigger_security_alert do
      require_atomic? false

      argument :alert_level, :atom do
        allow_nil? false
      end

      argument :alert_reason, :string do
        allow_nil? false
      end

      change set_attribute(:security_alert_triggered, true)
      change set_attribute(:alert_level, arg(:alert_level))
      change set_attribute(:notes, arg(:alert_reason))
    end

    update :report_incident do
      require_atomic? false

      argument :incident_details, :string do
        allow_nil? false
      end

      change set_attribute(:incident_reported, true)
      change set_attribute(:follow_up_required, true)
      change set_attribute(:notes, arg(:incident_details))
    end

    update :authorize_by_escort do
      require_atomic? false

      argument :escort_id, :uuid do
        allow_nil? false
      end

      argument :authorization_notes, :string

      change set_attribute(:authorizing_escort_id, arg(:escort_id))
      change set_attribute(:verification_method, "Escort Authorization")
      change set_attribute(:notes, arg(:authorization_notes))
    end

    update :add_location_details do
      require_atomic? false
      argument :from_location, :uuid
      argument :to_location, :uuid
      argument :reader_location, :string

      change set_attribute(:location_from, arg(:from_location))
      change set_attribute(:location_to, arg(:to_location))
      change set_attribute(:reader_location, arg(:reader_location))
    end

    update :add_verification_data do
      require_atomic? false

      argument :verification_method, :string do
        allow_nil? false
      end

      argument :additional_data, :map

      change set_attribute(:verification_method, arg(:verification_method))
      change set_attribute(:additional_data, arg(:additional_data))
    end

    update :_require_follow_up do
      require_atomic? false

      argument :reason, :string do
        allow_nil? false
      end

      change set_attribute(:follow_up_required, true)
      change set_attribute(:notes, arg(:reason))
    end

    update :close_follow_up do
      require_atomic? false

      argument :resolution_notes, :string do
        allow_nil? false
      end

      change set_attribute(:follow_up_required, false)

      change fn changeset, _ ->
        current_notes = changeset.data.notes || ""
        resolution = Ash.Changeset.get_argument(changeset, :resolution_notes)
        updated_notes = "#{current_notes}

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Visitor management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
\n\nRESOLUTION: #{resolution}"
        Ash.Changeset.change_attribute(changeset, :notes, updated_notes)
      end
    end
  end

  code_interface do
    define :create
    define :log_access_event
    define :log_denied_access
    define :trigger_security_alert
    define :report_incident
    define :authorize_by_escort
    define :add_location_details
    define :add_verification_data
    define :_require_follow_up
    define :close_follow_up
  end

  postgres do
    table "visitor_access"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :visitor_id, :timestamp]
      index [:tenant_id, :visit_request_id]
      index [:tenant_id, :access_event_type]
      index [:tenant_id, :access_result]
      index [:tenant_id, :timestamp]

      index [:tenant_id, :security_alert_triggered],
        where: "security_alert_triggered = true"

      index [:tenant_id, :alert_level]
      index [:tenant_id, :incident_reported], where: "incident_reported = true"

      index [:tenant_id, :follow_up_required],
        where: "follow_up_required = true"

      index [:tenant_id, :device_identifier]
      index [:tenant_id, :location_to], where: "location_to IS NOT NULL"
    end
  end
end
