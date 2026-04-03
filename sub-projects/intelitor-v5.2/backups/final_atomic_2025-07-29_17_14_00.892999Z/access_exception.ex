defmodule Intelitor.AccessControl.AccessException do
  @moduledoc """
  Override records for emergency access and special circumstances.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.AccessControl,
    table: "access_exceptions"

  use Intelitor.Multitenancy.TenantResource

  require Ash.Query

  attributes do
    uuid_primary_key :id

    attribute :exception_type, :atom do
      constraints one_of: [:emergency, :maintenance, :override, :escort, :manual]
      allow_nil? false
    end

    attribute :reason, :string do
      allow_nil? false
    end

    attribute :authorized_by_name, :string do
      allow_nil? false
      constraints max_length: 200
    end

    attribute :authorized_by_role, :string do
      constraints max_length: 100
    end

    attribute :granted_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :expires_at, :utc_datetime

    attribute :access_points_affected, {:array, :uuid} do
      default []
    end

    attribute :users_affected, {:array, :uuid} do
      default []
    end

    attribute :used_at, :utc_datetime
    attribute :used_by_id, :uuid

    attribute :status, :atom do
      constraints one_of: [:active, :used, :expired, :revoked]
      default :active
    end

    attribute :witness_name, :string do
      constraints max_length: 200
    end

    attribute :documentation_required, :boolean, default: false
    attribute :documentation_url, :string

    attribute :metadata, :map, default: %{}

    timestamps()
  end

  relationships do
    belongs_to :created_by, Intelitor.Accounts.User do
      allow_nil? false
    end

    belongs_to :authorized_by, Intelitor.Accounts.User
  end

  actions do
    defaults [:read]

    create :create_exception do
      primary? true

      accept [
        :exception_type,
        :reason,
        :authorized_by_name,
        :authorized_by_role,
        :expires_at,
        :access_points_affected,
        :users_affected,
        :witness_name,
        :documentation_required,
        :documentation_url,
        :authorized_by_id
      ]

      change set_attribute(:created_by_id, actor(:id))
    end

    update :use_exception do
      require_atomic? false
      accept [:used_by_id]

      change set_attribute(:status, :used)
      change set_attribute(:used_at, &DateTime.utc_now/0)
    end

    update :revoke do
      require_atomic? false
      accept []
      change set_attribute(:status, :revoked)
    end

    update :add_documentation do
      accept [:documentation_url]
    end

    read :list_active_exceptions do
      filter expr(status == :active)
    end

    read :list_emergency_exceptions do
      filter expr(exception_type == :emergency)
    end
  end

  calculations do
    calculate :is_valid?, :boolean do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn exception ->
          exception.status == :active &&
            (is_nil(exception.expires_at) || DateTime.compare(exception.expires_at, now) == :gt)
        end)
      end
    end

    calculate :time_remaining_minutes, :integer do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn exception ->
          if exception.expires_at do
            max(0, DateTime.diff(exception.expires_at, now, :minute))
          else
            nil
          end
        end)
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:tenant)
    end

    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end

    policy action_type(:update) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
      # Allow using exceptions for authorized users
      authorize_if relates_to_actor_via(:tenant)
    end
  end

  code_interface do
    define :create_exception, action: :create_exception
    define :use_exception, action: :use_exception
    define :revoke, action: :revoke
    define :add_documentation, action: :add_documentation
    define :list_active_exceptions
    define :list_emergency_exceptions
  end

  postgres do
    table "access_exceptions"
    repo Intelitor.Repo
  end
end
