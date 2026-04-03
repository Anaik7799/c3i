defmodule Intelitor.Accounts.ActivityLog do
  @moduledoc """
  User activity logging for security and audit purposes.

  Tracks authentication events, profile changes, and security-related
  activities at the user level.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Accounts,
    table: "user_activity_logs"

  use Intelitor.Multitenancy.TenantResource

  alias Intelitor.Shared.DeviceDetection

  attributes do
    uuid_primary_key :id

    attribute :activity_type, :atom do
      allow_nil? false

      constraints one_of: [
                    :sign_in,
                    :sign_out,
                    :failed_sign_in,
                    :password_reset_requested,
                    :password_changed,
                    :mfa_enabled,
                    :mfa_disabled,
                    :mfa_verified,
                    :mfa_failed,
                    :account_locked,
                    :account_unlocked,
                    :profile_updated,
                    :email_changed,
                    :session_expired,
                    :api_token_created,
                    :api_token_revoked
                  ]

      description "Type of activity"
    end

    attribute :ip_address, :string do
      constraints max_length: 45
      description "IP address of the activity"
    end

    attribute :user_agent, :string do
      constraints max_length: 500
      description "Browser/client user agent"
    end

    attribute :location, :map do
      default %{}
      description "Geolocation data if available"
    end

    attribute :device_info, :map do
      default %{}
      description "Device and browser information"
    end

    attribute :metadata, :map do
      default %{}
      description "Additional activity context"
    end

    attribute :success?, :boolean do
      default true
      description "Whether the activity succeeded"
    end

    attribute :failure_reason, :string do
      constraints max_length: 500
      description "Reason for failure if applicable"
    end

    attribute :session_id, :uuid do
      description "Associated session if applicable"
    end

    create_timestamp :occurred_at
  end

  relationships do
    belongs_to :user, Intelitor.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end

  actions do
    defaults [:read]

    create :log do
      accept [
        :user_id,
        :activity_type,
        :ip_address,
        :user_agent,
        :location,
        :device_info,
        :metadata,
        :success?,
        :failure_reason,
        :session_id
      ]

      change fn changeset, _ ->
        DeviceDetection.apply_device_detection(changeset)
      end
    end

    read :by_user do
      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id))
    end

    read :by_activity_type do
      argument :activity_type, :atom do
        allow_nil? false
      end

      filter expr(activity_type == ^arg(:activity_type))
    end

    read :failures do
      filter expr(success? == false)
    end

    read :recent do
      argument :hours, :integer do
        default 24
      end

      filter expr(occurred_at >= ago(^arg(:hours), :hour))
    end
  end

  calculations do
    calculate :activity_description, :string do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case record.activity_type do
            :sign_in -> "Signed in"
            :sign_out -> "Signed out"
            :failed_sign_in -> "Failed sign in attempt"
            :password_reset_requested -> "Requested password reset"
            :password_changed -> "Changed password"
            :mfa_enabled -> "Enabled multi-factor authentication"
            :mfa_disabled -> "Disabled multi-factor authentication"
            :mfa_verified -> "Verified MFA code"
            :mfa_failed -> "Failed MFA verification"
            :account_locked -> "Account locked"
            :account_unlocked -> "Account unlocked"
            :profile_updated -> "Updated profile"
            :email_changed -> "Changed email address"
            :session_expired -> "Session expired"
            :api_token_created -> "Created API token"
            :api_token_revoked -> "Revoked API token"
            _ -> "Unknown activity"
          end
        end)
      end
    end

    calculate :is_suspicious?, :boolean do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          # Simple suspicious activity detection
          case record.activity_type do
            type when type in [:failed_sign_in, :mfa_failed, :account_locked] ->
              true

            :sign_in ->
              # Check for unusual location or time
              # This is simplified - in production, compare with user's usual patterns
              false

            _ ->
              false
          end
        end)
      end
    end
  end

  policies do
    # Users can read their own activity logs
    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if expr(^actor(:role) in [:admin, :security_admin])
    end

    # Only system can create activity logs
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:is_system, true)
    end
  end

  code_interface do
    # get and list are already defined in BaseResource
    define :log, action: :log
    define :by_user
    define :by_activity_type
    define :failures
    define :recent
  end

  postgres do
    table "user_activity_logs"
    repo Intelitor.Repo

    custom_indexes do
      index [:user_id, :occurred_at]
      index [:activity_type, :occurred_at]

      index [:success?, :occurred_at],
        name: "user_activity_logs_failures_index",
        where: "success? = false"

      index [:session_id], where: "session_id IS NOT NULL"
    end
  end

  # Note: Device detection functions moved to DeviceDetection shared module
end
