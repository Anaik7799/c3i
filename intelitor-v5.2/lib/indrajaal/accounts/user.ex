defmodule Indrajaal.Accounts.User do
  @moduledoc """
  User resource with comprehensive authentication and authorization.

  Features:
  - Email / password authentication with bcrypt
  - Multi - factor authentication (TOTP)
  - Account locking and security monitoring
  - Tenant - based isolation
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Accounts

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      constraints max_length: 255
      description "User's email address (case - insensitive)"
    end

    attribute :username, :ci_string do
      constraints max_length: 50, match: ~r/^[a-zA-Z0-9_-]+$/
      description "Optional username for login"
    end

    attribute :full_name, :string do
      constraints max_length: 255
      description "User's full display name"
    end

    attribute :hashed_password, :string do
      sensitive? true
      description "Bcrypt - hashed password"
    end

    attribute :confirmed_at, :utc_datetime_usec do
      description "When the email was confirmed"
    end

    attribute :locked_at, :utc_datetime_usec do
      description "When the account was locked"
    end

    attribute :failed_attempts, :integer do
      default 0
      description "Number of consecutive failed login attempts"
    end

    attribute :mfa_enabled, :boolean do
      default false
      description "Whether MFA is enabled"
    end

    attribute :mfa_secret, Indrajaal.Security.EncryptedBinary do
      public? false
      sensitive? true
      description "TOTP secret for MFA"
    end

    attribute :recovery_codes, {:array, Indrajaal.Security.EncryptedBinary} do
      public? false
      sensitive? true
      default []
      description "One - time recovery codes for MFA"
    end

    attribute :preferences, :map do
      default %{}
      description "User preferences and settings"
    end

    attribute :status, :atom do
      constraints one_of: [:active, :inactive, :locked, :archived]
      default :active
      description "Account status"
    end

    attribute :role, :atom do
      constraints one_of: [:admin, :manager, :operator, :viewer, :user]
      default :user
      description "User role for authorization"
    end

    attribute :azure_id, :string do
      constraints max_length: 255
      description "Microsoft Entra ID identifier"
    end

    attribute :last_sign_in_at, :utc_datetime_usec do
      description "Last successful sign in"
    end

    attribute :last_sign_in_ip, :string do
      constraints max_length: 45
      description "IP address of last sign in"
    end

    attribute :is_service_account, :boolean do
      default false
      description "Whether this is a service account"
    end

    timestamps()
  end

  relationships do
    has_one :profile, Indrajaal.Accounts.Profile
    has_many :sessions, Indrajaal.Accounts.Session
    has_many :tokens, Indrajaal.Accounts.Token
    has_many :activity_logs, Indrajaal.Accounts.ActivityLog

    many_to_many :teams, Indrajaal.Accounts.Team do
      through Indrajaal.Accounts.TeamMembership
      source_attribute :id
      source_attribute_on_join_resource :user_id
      destination_attribute :id
      destination_attribute_on_join_resource :team_id
    end
  end

  identities do
    identity :unique_email_per_tenant, [:tenant_id, :email]
    identity :unique_username_per_tenant, [:tenant_id, :username]
    identity :unique_azure_id, [:azure_id]
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :email,
        :username,
        :full_name,
        :preferences,
        :status,
        :role,
        :tenant_id,
        :hashed_password,
        :confirmed_at,
        :failed_attempts,
        :locked_at,
        :mfa_enabled,
        :is_service_account
      ]

      argument :password, :string
      argument :failed_login_attempts, :integer
      argument :active, :boolean

      change {Indrajaal.Accounts.Changes.HashPassword, []}

      change fn changeset, _ ->
        # Map virtual 'active' argument to physical 'status' attribute
        case Ash.Changeset.get_argument(changeset, :active) do
          false -> Ash.Changeset.force_change_attribute(changeset, :status, :inactive)
          true -> Ash.Changeset.force_change_attribute(changeset, :status, :active)
          _ -> changeset
        end
      end

      primary? true
    end

    update :update do
      accept [
        :email,
        :username,
        :full_name,
        :preferences,
        :status,
        :role,
        :azure_id,
        :mfa_enabled,
        :is_service_account
      ]

      argument :password, :string
      argument :active, :boolean

      change {Indrajaal.Accounts.Changes.HashPassword, []}

      change fn changeset, _ ->
        # Map virtual 'active' argument to physical 'status' attribute
        case Ash.Changeset.get_argument(changeset, :active) do
          false -> Ash.Changeset.force_change_attribute(changeset, :status, :inactive)
          true -> Ash.Changeset.force_change_attribute(changeset, :status, :active)
          _ -> changeset
        end
      end

      require_atomic? false
      primary? true
    end

    create :register do
      accept [:email, :username, :full_name]

      argument :password, :string do
        allow_nil? false
        constraints min_length: 12
      end

      change {Indrajaal.Accounts.Changes.HashPassword, []}
      change {Indrajaal.Accounts.Changes.GenerateUsername, []}
      change {Indrajaal.Accounts.Changes.SendConfirmationEmail, []}
    end

    update :confirm do
      require_atomic? false
      accept []

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.change_attribute(:status, :active)
        |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
      end
    end

    update :enable_mfa do
      require_atomic? false
      accept []
      argument :secret, :string
      argument :recovery_codes, {:array, :string}

      change fn changeset, _ ->
        secret = Ash.Changeset.get_argument(changeset, :secret)
        codes = Ash.Changeset.get_argument(changeset, :recovery_codes)

        changeset
        |> Ash.Changeset.change_attribute(:mfa_enabled, true)
        |> Ash.Changeset.change_attribute(:mfa_secret, secret)
        |> Ash.Changeset.change_attribute(:recovery_codes, codes)
      end
    end

    update :disable_mfa do
      require_atomic? false
      accept []
      change set_attribute(:mfa_enabled, false)
      change set_attribute(:mfa_secret, nil)
      change set_attribute(:recovery_codes, [])
    end

    update :lock do
      require_atomic? false
      accept []
      change set_attribute(:status, :locked)
      change set_attribute(:locked_at, &DateTime.utc_now/0)
    end

    update :unlock do
      require_atomic? false
      accept []
      change set_attribute(:status, :active)
      change set_attribute(:locked_at, nil)
      change set_attribute(:failed_attempts, 0)
    end

    update :increment_failed_attempts do
      require_atomic? false
      accept []

      change fn changeset, _ ->
        new_count = (changeset.data.failed_attempts || 0) + 1
        changeset = Ash.Changeset.change_attribute(changeset, :failed_attempts, new_count)

        if new_count >= 5 do
          changeset
          |> Ash.Changeset.change_attribute(:status, :locked)
          |> Ash.Changeset.change_attribute(:locked_at, DateTime.utc_now())
        else
          changeset
        end
      end
    end

    update :update_last_sign_in do
      require_atomic? false
      accept []
      argument :ip_address, :string

      change fn changeset, context ->
        ip = Ash.Changeset.get_argument(changeset, :ip_address) || context[:ip_address]

        changeset
        |> Ash.Changeset.change_attribute(:last_sign_in_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:last_sign_in_ip, ip)
        |> Ash.Changeset.change_attribute(:failed_attempts, 0)
      end
    end

    update :update_profile do
      accept [:full_name, :username, :preferences]
      require_atomic? false
    end

    update :update_theme do
      require_atomic? false
      accept []

      argument :theme, :atom do
        allow_nil? false
        constraints one_of: [:light, :dark, :system]
      end

      change fn changeset, _ ->
        theme = Ash.Changeset.get_argument(changeset, :theme)
        prefs = Ash.Changeset.get_attribute(changeset, :preferences) || %{}
        new_prefs = Map.put(prefs, "theme", theme)
        Ash.Changeset.change_attribute(changeset, :preferences, new_prefs)
      end
    end

    update :archive do
      accept []
      require_atomic? false
      change set_attribute(:status, :archived)
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :is_confirmed?, :boolean, expr(not is_nil(confirmed_at))
    calculate :is_locked?, :boolean, expr(not is_nil(locked_at))
    calculate :active, :boolean, expr(status == :active)

    calculate :__requires_mfa?, :boolean do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          record.mfa_enabled
        end)
      end
    end
  end

  validations do
    validate string_length(:username, min: 3, max: 50) do
      where present(:username)
    end
  end

  policies do
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :manager)
      authorize_if actor_attribute_equals(:is_system_admin, true)
    end

    policy action_type(:read) do
      authorize_if expr(id == ^actor(:id))
      authorize_if expr(^actor(:role) in [:admin, :manager])
      authorize_if actor_attribute_equals(:is_system_admin, true)
    end

    policy action_type(:update) do
      authorize_if expr(id == ^actor(:id))
      authorize_if expr(^actor(:role) in [:admin, :manager])
      authorize_if actor_attribute_equals(:is_system_admin, true)
    end

    policy action_type(:destroy) do
      authorize_if expr(^actor(:role) == :admin)
      authorize_if actor_attribute_equals(:is_system_admin, true)
    end
  end

  code_interface do
    define :create
    define :register
    define :confirm
    define :enable_mfa
    define :disable_mfa
    define :lock
    define :unlock
    define :update
    define :update_profile
    define :update_theme, args: [:theme]
    define :archive
    define :destroy
  end

  postgres do
    table "users"
    repo Indrajaal.Repo

    custom_indexes do
      index [:last_sign_in_at]
      index [:status], where: "status != 'archived'"
      index [:azure_id], unique: true, where: "azure_id IS NOT NULL"
      index [:tenant_id, :username], unique: true, where: "username IS NOT NULL"
      index [:tenant_id, :email], unique: true
    end
  end
end
