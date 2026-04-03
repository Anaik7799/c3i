defmodule Indrajaal.Accounts.Session do
  @moduledoc """
  Session tracking for user authentication.

  Tracks active sessions, devices, locations, and provides
  session management capabilities for security.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Accounts

  use Indrajaal.Multitenancy.TenantResource

  alias Indrajaal.Shared.DeviceDetection

  attributes do
    uuid_primary_key :id

    attribute :token_hash, :string do
      allow_nil? false
      sensitive? true
      description "Hashed session token"
    end

    attribute :refresh_token_hash, :string do
      sensitive? true
      description "Hashed refresh token"
    end

    attribute :ip_address, :string do
      constraints max_length: 45
      description "IP address of session origin"
    end

    attribute :__user_agent, :string do
      constraints max_length: 500
      description "Browser / client user agent"
    end

    attribute :device_info, :map do
      default %{}
      description "Parsed device information"
    end

    attribute :location, :map do
      default %{}
      description "Geolocation data"
    end

    attribute :active, :boolean do
      default true
      description "Whether session is active"
    end

    attribute :last_activity_at, :utc_datetime_usec do
      description "Last activity timestamp"
    end

    attribute :revoked_at, :utc_datetime_usec do
      description "When session was revoked"
    end

    attribute :revoke_reason, :string do
      constraints max_length: 255
      description "Reason for revocation"
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
      description "Session expiration time"
    end

    attribute :refresh_expires_at, :utc_datetime_usec do
      description "Refresh token expiration"
    end

    attribute :metadata, :map do
      default %{}
      description "Additional session data"
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_token, [:token_hash]
    identity :unique_refresh_token, [:refresh_token_hash]
  end

  actions do
    defaults [:read]

    create :create do
      # SC-ASH-001: Accept attributes only. token is an argument.
      accept [:user_id, :ip_address, :__user_agent, :metadata, :tenant_id, :expires_at]

      argument :token, :string do
        allow_nil? false
      end

      argument :refresh_token, :string

      argument :ttl_seconds, :integer do
        # 1 hour
        default 3600
      end

      argument :refresh_ttl_seconds, :integer do
        # 30 days
        default 2_592_000
      end

      change fn changeset, __context ->
        token = Ash.Changeset.get_argument(changeset, :token)
        refresh_token = Ash.Changeset.get_argument(changeset, :refresh_token)

        # Priority: explicit expires_at > calculated from ttl_seconds
        expires_at = Ash.Changeset.get_attribute(changeset, :expires_at)
        ttl = Ash.Changeset.get_argument(changeset, :ttl_seconds)

        refresh_ttl =
          Ash.Changeset.get_argument(
            changeset,
            :refresh_ttl_seconds
          )

        now = DateTime.utc_now()
        final_expires_at = expires_at || DateTime.add(now, ttl, :second)

        changeset
        |> Ash.Changeset.force_change_attribute(:token_hash, hash_token(token))
        |> Ash.Changeset.force_change_attribute(
          :refresh_token_hash,
          hash_token(refresh_token)
        )
        |> Ash.Changeset.force_change_attribute(:expires_at, final_expires_at)
        |> Ash.Changeset.force_change_attribute(
          :refresh_expires_at,
          DateTime.add(now, refresh_ttl, :second)
        )
        |> Ash.Changeset.force_change_attribute(:last_activity_at, now)
        |> parse_device_info()
      end
    end

    update :revoke do
      require_atomic? false
      accept [:revoke_reason]

      change set_attribute(:active, false)
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
    end

    update :revoke_all_for_user do
      require_atomic? false
      accept []

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.change_attribute(:active, false)
        |> Ash.Changeset.change_attribute(:revoked_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(
          :revoke_reason,
          "All sessions revoked"
        )
      end
    end

    update :touch do
      require_atomic? false
      accept []

      change set_attribute(:last_activity_at, &DateTime.utc_now/0)
    end

    update :refresh do
      require_atomic? false
      accept []

      argument :new_token, :string do
        allow_nil? false
      end

      argument :ttl_seconds, :integer do
        default 3600
      end

      change fn changeset, _ ->
        token = Ash.Changeset.get_argument(changeset, :new_token)
        ttl = Ash.Changeset.get_argument(changeset, :ttl_seconds)
        now = DateTime.utc_now()

        changeset
        |> Ash.Changeset.change_attribute(:token_hash, hash_token(token))
        |> Ash.Changeset.change_attribute(:expires_at, DateTime.add(now, ttl, :second))
        |> Ash.Changeset.change_attribute(:last_activity_at, now)
      end
    end

    destroy :destroy do
      require_atomic? false
      soft? true
      change set_attribute(:active, false)
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
      change set_attribute(:revoke_reason, "Session ended")
    end
  end

  calculations do
    calculate :is_expired?, :boolean, expr(expires_at < now())

    calculate :is_active?,
              :boolean,
              expr(active == true and is_nil(revoked_at) and expires_at > now())

    calculate :refresh_expired?,
              :boolean,
              expr(
                not is_nil(refresh_expires_at) and
                  refresh_expires_at <
                    now()
              )

    calculate :time_until_expiry, :integer do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          if record.expires_at do
            DateTime.diff(record.expires_at, now, :second)
          else
            nil
          end
        end)
      end
    end

    calculate :inactive_duration, :integer do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          if record.last_activity_at do
            DateTime.diff(now, record.last_activity_at, :second)
          else
            nil
          end
        end)
      end
    end
  end

  validations do
    validate compare(:expires_at, greater_than: :inserted_at)

    validate compare(:refresh_expires_at, greater_than: :expires_at) do
      where present(:refresh_expires_at)
    end
  end

  policies do
    # Users can read their own sessions
    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Users can revoke their own sessions
    policy action_type(:destroy) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Users can revoke their own sessions (update action)
    policy action(:revoke) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Only system can create sessions
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:is_system, true)
    end

    # Only system can refresh and touch sessions (update actions)
    policy action([:refresh, :touch]) do
      authorize_if actor_attribute_equals(:is_system, true)
    end
  end

  code_interface do
    # get and list are already defined in BaseResource
    define :create
    define :revoke
    define :revoke_all_for_user
    define :touch
    define :refresh
  end

  postgres do
    table "sessions"
    repo Indrajaal.Repo

    custom_indexes do
      index [:user_id, :active]
      index [:token_hash], unique: true
      index [:refresh_token_hash], unique: true, where: "refresh_token_hash IS NOT NULL"
      index [:expires_at], where: "active = true"
      index [:last_activity_at]
    end
  end

  # Helper functions
  @spec hash_token(term()) :: term()
  defp hash_token(nil), do: nil

  defp hash_token(token) do
    hash = :crypto.hash(:sha256, token)
    Base.encode16(hash, case: :lower)
  end

  @spec parse_device_info(term()) :: term()
  defp parse_device_info(changeset) do
    DeviceDetection.apply_device_detection(changeset)
  end

  # Note: Device detection functions moved to DeviceDetection shared module
end

# Agent: Worker - 5 (Security Domain Agent)
# SOPv5.1 Compliance: ✅ User account management and authentication coordination
# Domain: Accounts
# Responsibilities: Security access control, authentication, policy enforcement
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
