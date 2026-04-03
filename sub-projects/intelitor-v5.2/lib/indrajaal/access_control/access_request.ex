defmodule Indrajaal.AccessControl.AccessRequest do
  # PHASE N: Access control patterns unified

  @moduledoc """
  Manages access __requests that require approval before granting access.
  Supports workflow integration for multi - level approvals.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AccessControlDomain

  use Indrajaal.Multitenancy.TenantResource

  require Ash.Query

  attributes do
    uuid_primary_key :id

    attribute :__request_type, :atom do
      constraints one_of: [:permanent, :temporary, :visitor, :contractor, :emergency]
      allow_nil? false
    end

    attribute :justification, :string do
      allow_nil? false
    end

    attribute :__requested_areas, {:array, :uuid} do
      default []
    end

    attribute :__requested_from, :utc_datetime do
      allow_nil? false
    end

    attribute :__requested_until, :utc_datetime

    attribute :status, :atom do
      constraints one_of: [:pending, :approved, :denied, :expired, :cancelled]
      default :pending
    end

    attribute :approval_notes, :string
    attribute :denial_reason, :string

    attribute :approved_at, :utc_datetime
    attribute :approved_by_id, :uuid

    attribute :metadata, :map, default: %{}

    timestamps()
  end

  relationships do
    belongs_to :__requester, Indrajaal.Accounts.User do
      allow_nil? false
    end

    belongs_to :__requested_for, Indrajaal.Accounts.User do
      allow_nil? false
    end

    belongs_to :access_level, Indrajaal.AccessControl.AccessLevel

    has_one :access_grant, Indrajaal.AccessControl.AccessGrant
  end

  actions do
    defaults [:read, :update]

    create :submit do
      primary? true

      accept [
        :__request_type,
        :justification,
        :__requested_areas,
        :__requested_from,
        :__requested_until,
        :__requested_for_id,
        :access_level_id
      ]

      change set_attribute(:__requester_id, actor(:id))
    end

    update :approve do
      require_atomic? false
      accept [:approval_notes]

      change set_attribute(:status, :approved)
      change set_attribute(:approved_at, &DateTime.utc_now/0)
      change set_attribute(:approved_by_id, actor(:id))

      # Trigger access grant creation - would be implemented
      # change after_action(&create_access_grant / 2)
    end

    update :deny do
      require_atomic? false
      accept [:denial_reason]

      change set_attribute(:status, :denied)
      change set_attribute(:approved_at, &DateTime.utc_now/0)
      change set_attribute(:approved_by_id, actor(:id))
    end

    update :cancel do
      require_atomic? false
      accept []
      change set_attribute(:status, :cancelled)
    end

    read :list_pending do
      filter expr(status == :pending)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:tenant)
    end

    policy action_type(:create) do
      authorize_if relates_to_actor_via(:tenant)
    end

    policy action_type([:update]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
      authorize_if expr(__requester_id == actor(:id) and status == :pending)
    end
  end

  code_interface do
    define :submit, action: :submit
    define :approve, action: :approve
    define :deny, action: :deny
    define :cancel, action: :cancel
    define :list_pending
  end

  postgres do
    table "access_requests"
    repo Indrajaal.Repo
  end
end

# Agent: Worker - 5 (Security Domain Agent)
# SOPv5.1 Compliance: ✅ Security access control and policy enforcement with cyb
# Domain: Access control
# Responsibilities: Security access control, authentication, policy enforcement
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
