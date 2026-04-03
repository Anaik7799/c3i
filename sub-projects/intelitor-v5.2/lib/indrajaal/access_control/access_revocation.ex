defmodule Indrajaal.AccessControl.AccessRevocation do
  # PHASE N: Access control patterns unified

  @moduledoc """
  Track and manage credential revocations with audit trail.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AccessControlDomain

  use Indrajaal.Multitenancy.TenantResource

  require Ash.Query

  attributes do
    uuid_primary_key :id

    attribute :revocation_type, :atom do
      constraints one_of: [
                    :temporary,
                    :permanent,
                    :security_breach,
                    :termination,
                    :lost_credential
                  ]

      allow_nil? false
    end

    attribute :reason, :string do
      allow_nil? false
    end

    attribute :revoked_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :effective_until, :utc_datetime
    attribute :restoration_notes, :string
    attribute :restored_at, :utc_datetime
    attribute :restored_by_id, :uuid

    attribute :status, :atom do
      constraints one_of: [:active, :restored, :expired]
      default :active
    end

    attribute :metadata, :map, default: %{}

    timestamps()
  end

  relationships do
    belongs_to :access_credential, Indrajaal.AccessControl.AccessCredential do
      allow_nil? false
    end

    belongs_to :revoked_by, Indrajaal.Accounts.User do
      allow_nil? false
    end
  end

  actions do
    defaults [:read]

    create :revoke do
      primary? true
      accept [:revocation_type, :reason, :access_credential_id, :effective_until]

      change set_attribute(:revoked_by_id, actor(:id))
    end

    update :restore do
      require_atomic? false
      accept [:restoration_notes]

      change set_attribute(:status, :restored)
      change set_attribute(:restored_at, &DateTime.utc_now/0)
      change set_attribute(:restored_by_id, actor(:id))
    end

    read :list_active_revocations do
      filter expr(status == :active)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:tenant)
    end

    policy action_type([:create, :update]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
    end
  end

  code_interface do
    define :revoke, action: :revoke
    define :restore, action: :restore
    define :list_active_revocations
  end

  postgres do
    table "access_revocations"
    repo Indrajaal.Repo
  end
end

# Agent: Worker - 5 (Security Domain Agent)
# SOPv5.1 Compliance: ✅ Security access control and policy enforcement with cyb
# Domain: Access control
# Responsibilities: Security access control, authentication, policy enforcement
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
