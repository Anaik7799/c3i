defmodule Intelitor.Accounts.User do
  @moduledoc """
  User resource with comprehensive authentication and authorization.

  Features:
  - Email/password authentication with bcrypt
  - Multi-factor authentication (TOTP)
  - Account locking and failed attempt tracking
  - Recovery codes for MFA
  - Integration with Microsoft Entra ID
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Accounts,
    table: "users"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      constraints max_length: 255
      description "User's email address (case-insensitive)"
    end

    attribute :username, :ci_string do
      constraints max_length: 50,
                  match: ~S/^[a-zA-Z0-9_-]+$/

      description "Optional username for login"
    end

    attribute :full_name, :string do
      constraints max_length: 255
      description "User's full display name"
    end

    attribute :hashed_password, :string do
      public? false
      sensitive? true
      description "Bcrypt hashed password"
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

    attribute :mfa_secret, :string do
      public? false
      sensitive? true
      description "TOTP secret for MFA"
    end

    attribute :recovery_codes, {:array, :string} do
      public? false
      sensitive? true
      default []
      description "One-time recovery codes for MFA"
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

    timestamps()
  end

  relationships do
    has_one :profile, Intelitor.Accounts.Profile
    has_many :sessions, Intelitor.Accounts.Session
    has_many :tokens, Intelitor.Accounts.Token
    has_many :activity_logs, Intelitor.Accounts.ActivityLog

    many_to_many :teams, Intelitor.Accounts.Team do
      through Intelitor.Accounts.TeamMembership
      source_attribute :id
      source_attribute_on_join_resource :user_id
      destination_attribute :id
      destination_attribute_on_join_resource :team_id
    end

    # Roles relationship will be added when Policy domain is implemented
    # many_to_many :roles, Intelitor.Policy.Role do
    #   through Intelitor.Policy.UserRole
    #   source_attribute :id
    #   source_attribute_on_join_resource :user_id
    #   destination_attribute :id
    #   destination_attribute_on_join_resource :role_id
    # end
  end

  identities do
    identity :unique_email_per_tenant, [:tenant_id, :email]
    identity :unique_username_per_tenant, [:tenant_id, :username]
    identity :unique_azure_id, [:azure_id]
  end

  # Authentication will be configured separately when AshAuthentication is properly set up

  actions do
    defaults [:read]

    create :register do
      accept [:email, :username, :full_name]

      argument :password, :string do
        allow_nil? false
        constraints min_length: 12
      end

      change {Intelitor.Accounts.Changes.HashPassword, []}
      change {Intelitor.Accounts.Changes.GenerateUsername, []}
      change {Intelitor.Accounts.Changes.SendConfirmationEmail, []}
    end

    update :confirm do
      require_atomic? false
      accept []

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:status, :active)
      end
    end

    update :enable_mfa do
      require_atomic? false
      accept []

      change fn changeset, _ ->
        secret = NimbleTOTP.secret()

        codes =
          Enum.map(1..10, fn _ ->
            :crypto.strong_rand_bytes(4) |> Base.encode32(padding: false)
          end)

        changeset
        |> Ash.Changeset.change_attribute(:mfa_enabled, true)
        |> Ash.Changeset.change_attribute(:mfa_secret, secret)
        |> Ash.Changeset.change_attribute(:recovery_codes, codes)
      end
    end

    update :disable_mfa do
      require_atomic? false
      accept []

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.change_attribute(:mfa_enabled, false)
        |> Ash.Changeset.change_attribute(:mfa_secret, nil)
        |> Ash.Changeset.change_attribute(:recovery_codes, [])
      end
    end

    update :lock do
      require_atomic? false
      accept []

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.change_attribute(:status, :locked)
        |> Ash.Changeset.change_attribute(:locked_at, DateTime.utc_now())
      end
    end

    update :unlock do
      require_atomic? false
      accept []

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.change_attribute(:status, :active)
        |> Ash.Changeset.change_attribute(:locked_at, nil)
        |> Ash.Changeset.change_attribute(:failed_attempts, 0)
      end
    end

    update :increment_failed_attempts do
      require_atomic? false
      accept []

      change fn changeset, _ ->
        current = Ash.Changeset.get_attribute(changeset, :failed_attempts) || 0
        new_attempts = current + 1

        changeset = Ash.Changeset.change_attribute(changeset, :failed_attempts, new_attempts)

        # Lock after 5 failed attempts
        if new_attempts >= 5 do
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

      change fn changeset, _ ->
        ip = Ash.Changeset.get_argument(changeset, :ip_address)

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

    update :archive do
      accept []
      require_atomic? false
      change set_attribute(:status, :archived)
    end

    destroy :destroy do
      require_atomic? false
      soft? true
      change set_attribute(:status, :archived)
    end
  end

  calculations do
    calculate :is_confirmed?, :boolean, expr(not is_nil(confirmed_at))

    calculate :is_locked?, :boolean, expr(status == :locked or not is_nil(locked_at))

    calculate :requires_mfa?, :boolean, expr(mfa_enabled == true and not is_nil(mfa_secret))

    calculate :days_since_last_sign_in, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          if record.last_sign_in_at do
            DateTime.diff(DateTime.utc_now(), record.last_sign_in_at, :day)
          else
            nil
          end
        end)
      end
    end
  end

  validations do
    validate string_length(:email, max: 255)
    validate match(:email, ~S/^[^\s]+@[^\s]+$/)

    validate string_length(:username, min: 3, max: 50) do
      where present(:username)
    end

    validate string_length(:full_name, max: 255) do
      where present(:full_name)
    end
  end

  policies do
    # Users can read and update their own profile
    policy action_type(:read) do
      authorize_if expr(id == ^actor(:id))
      authorize_if expr(^actor(:role) in [:admin, :manager])
    end

    # Users can manage their own profile (specific update actions)
    policy action([:update_profile, :enable_mfa, :disable_mfa]) do
      authorize_if expr(id == ^actor(:id))
    end

    # Admin actions - update type
    policy action_type(:update) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Admin actions - specific update actions
    policy action([:lock, :unlock, :archive]) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Admin actions - destroy type
    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Registration is public
    policy action(:register) do
      authorize_if always()
    end
  end

  code_interface do
    # get and list are already defined in BaseResource
    define :register
    define :confirm
    define :enable_mfa
    define :disable_mfa
    define :lock
    define :unlock
    define :update_profile
    define :archive
  end

  postgres do
    table "users"
    repo Intelitor.Repo

    identity_wheres_to_sql unique_azure_id: "azure_id IS NOT NULL"

    custom_indexes do
      index [:tenant_id, :email], unique: true
      index [:tenant_id, :username], unique: true, where: "username IS NOT NULL"
      index [:azure_id], unique: true, where: "azure_id IS NOT NULL"
      index [:status], where: "status != 'archived'"
      index [:last_sign_in_at]
    end
  end
end
