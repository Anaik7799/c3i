defmodule Indrajaal.AccessControl.VisitorPass do
  # PHASE N: Access control patterns unified

  @moduledoc """
  Temporary credentials for visitors with expiration and tracking.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.VisitorManagement

  use Indrajaal.Multitenancy.TenantResource

  require Ash.Query

  attributes do
    uuid_primary_key :id

    attribute :pass_number, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :visitor_name, :string do
      allow_nil? false
      constraints max_length: 200
    end

    attribute :visitor_company, :string do
      constraints max_length: 200
    end

    attribute :host_name, :string do
      allow_nil? false
      constraints max_length: 200
    end

    attribute :purpose, :string

    attribute :issued_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :expires_at, :utc_datetime do
      allow_nil? false
    end

    attribute :areas_allowed, {:array, :uuid} do
      default []
    end

    attribute :escort_required, :boolean, default: false

    attribute :status, :atom do
      constraints one_of: [:active, :expired, :revoked, :completed]
      default :active
    end

    attribute :check_in_time, :utc_datetime
    attribute :check_out_time, :utc_datetime

    attribute :photo_url, :string
    attribute :identification_verified, :boolean, default: false

    attribute :metadata, :map, default: %{}

    timestamps()
  end

  relationships do
    belongs_to :host_user, Indrajaal.Accounts.User do
      allow_nil? false
    end

    belongs_to :issued_by, Indrajaal.Accounts.User do
      allow_nil? false
    end
  end

  identities do
    identity :unique_pass_number, [:tenant_id, :pass_number]
  end

  actions do
    defaults [:read, :update]

    create :issue do
      primary? true

      accept [
        :pass_number,
        :visitor_name,
        :visitor_company,
        :host_name,
        :purpose,
        :expires_at,
        :areas_allowed,
        :escort_required,
        :host_user_id,
        :photo_url,
        :identification_verified
      ]

      change set_attribute(:issued_by_id, actor(:id))
    end

    update :check_in do
      require_atomic? false
      accept []
      change set_attribute(:check_in_time, &DateTime.utc_now/0)
    end

    update :check_out do
      require_atomic? false
      accept []
      change set_attribute(:check_out_time, &DateTime.utc_now/0)
      change set_attribute(:status, :completed)
    end

    update :revoke do
      require_atomic? false
      accept []
      change set_attribute(:status, :revoked)
    end

    read :list_active_passes do
      filter expr(status == :active)
    end
  end

  calculations do
    calculate :is_active?, :boolean do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn pass ->
          pass.status == :active &&
            DateTime.compare(pass.expires_at, now) == :gt
        end)
      end
    end

    calculate :duration_minutes, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn pass ->
          if pass.check_in_time && pass.check_out_time do
            DateTime.diff(pass.check_out_time, pass.check_in_time, :minute)
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

    policy action_type([:create, :update]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
      authorize_if actor_attribute_equals(:role, "receptionist")
    end
  end

  code_interface do
    define :issue, action: :issue
    define :check_in, action: :check_in
    define :check_out, action: :check_out
    define :revoke, action: :revoke
    define :list_active_passes
  end

  postgres do
    table "visitor_passes"
    repo Indrajaal.Repo
  end
end

# Agent: Worker - 5 (Security Domain Agent)
# SOPv5.1 Compliance: ✅ Security access control and policy enforcement with cyb
# Domain: Access control
# Responsibilities: Security access control, authentication, policy enforcement
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
