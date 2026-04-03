defmodule Indrajaal.AccessControl.AccessLog do
  # PHASE N: Access control patterns unified

  @moduledoc """
  Comprehensive audit log of all access attempts and results.
  High - volume resource optimized for write performance.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AccessControlDomain

  use Indrajaal.Multitenancy.TenantResource

  require Ash.Query

  attributes do
    uuid_primary_key :id

    attribute :__event_type, :atom do
      constraints one_of: [:granted, :denied, :tailgate, :forced, :emergency, :duress]
      allow_nil? false
    end

    attribute :timestamp, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :access_point_id, :uuid do
      allow_nil? false
    end

    attribute :direction, :atom do
      constraints one_of: [:in, :out]
      allow_nil? false
    end

    attribute :denial_reason, :string do
      constraints max_length: 200
    end

    attribute :credential_presented, :string do
      constraints max_length: 100
    end

    attribute :location_data, :map do
      default %{}
      # GPS coordinates, floor, zone, etc.
    end

    attribute :device_data, :map do
      default %{}
      # Reader info, firmware version, etc.
    end

    attribute :biometric_score, :float
    attribute :tailgate_detected, :boolean, default: false
    attribute :duress_code_used, :boolean, default: false

    timestamps()
  end

  relationships do
    belongs_to :access_credential, Indrajaal.AccessControl.AccessCredential
    belongs_to :access_grant, Indrajaal.AccessControl.AccessGrant
    belongs_to :user, Indrajaal.Accounts.User

    # Link to devices domain
    belongs_to :device, Indrajaal.Devices.Device do
      allow_nil? false
    end
  end

  actions do
    defaults [:read]

    create :log_access do
      primary? true

      accept [
        :__event_type,
        :access_point_id,
        :direction,
        :denial_reason,
        :credential_presented,
        :location_data,
        :device_data,
        :biometric_score,
        :tailgate_detected,
        :duress_code_used,
        :access_credential_id,
        :access_grant_id,
        :user_id,
        :device_id
      ]

      # Trigger alarms for security __events - would be implemented
      # change after_action(fn changeset, _record ->
      #   if record.__event_type in [:forced, :duress, :tailgate] do
      #     # Create alarm __event
      #     Indrajaal.Alarms.AlarmEvent.create_from_access_event(record)
      #   end
      #   {:ok, record}
      # end)
    end

    read :list_by_user do
      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id))
    end

    read :list_by_credential do
      argument :credential_id, :uuid do
        allow_nil? false
      end

      filter expr(access_credential_id == ^arg(:credential_id))
    end

    read :list_security_events do
      filter expr(__event_type in [:forced, :duress, :tailgate])
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:tenant)
    end

    policy action_type(:create) do
      # Allow system actors to create logs
      authorize_if relates_to_actor_via(:tenant)
    end
  end

  code_interface do
    define :log_access, action: :log_access
    define :list_by_user, args: [:user_id]
    define :list_by_credential, args: [:credential_id]
    define :list_security_events
  end

  postgres do
    table "access_logs"
    repo Indrajaal.Repo

    custom_indexes do
      # High - performance indexes for common queries
      index [:tenant_id, :timestamp], name: "access_logs_tenant_timestamp_index"

      index [:tenant_id, :user_id, :timestamp],
        name: "access_logs_tenant_user_timestamp_index"

      index [:tenant_id, :access_point_id, :timestamp],
        name: "access_logs_tenant_ap_timestamp_index"

      index [:tenant_id, :__event_type],
        where: "__event_type IN ('forced', 'duress', 'tailgate')",
        name: "access_logs_security_events_index"
    end
  end
end

# Agent: Worker - 5 (Security Domain Agent)
# SOPv5.1 Compliance: ✅ Security access control and policy enforcement with cyb
# Domain: Access control
# Responsibilities: Security access control, authentication, policy enforcement
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
