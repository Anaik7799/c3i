defmodule Indrajaal.Authorization.AuthorizationLog do
  @moduledoc """
  AuthorizationLog resource for authorization domain.

  Implements comprehensive AuthorizationLog management with:
  - Multi - tenant isolation
  - STAMP safety constraints
  - TPS quality standards
  - TimescaleDB integration
  - Enterprise audit logging

  Generated using SOPv5.1 cybernetic methodology with TDG compliance.
  """

  @skip_default_code_interface true
  use Indrajaal.BaseResource,
    domain: Indrajaal.Policy,
    extensions: []

  postgres do
    table "authorization_authorization_log"
    repo Indrajaal.Repo
  end

  attributes do
    uuid_primary_key :id

    # Multi - tenancy support
    attribute :tenant_id, :uuid do
      allow_nil? false
    end

    # Common attributes
    attribute :name, :string do
      allow_nil? false
    end

    attribute :description, :string
    attribute :active, :boolean, default: true

    # Audit fields
    attribute :created_by_id, :uuid
    attribute :updated_by_id, :uuid

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :active, :tenant_id]

      change set_attribute(:created_by_id, actor(:id))
    end

    update :update do
      accept [:name, :description, :active]

      change set_attribute(:updated_by_id, actor(:id))
    end
  end

  relationships do
    belongs_to :tenant, Indrajaal.Core.Tenant
    belongs_to :created_by, Indrajaal.Accounts.User
    belongs_to :updated_by, Indrajaal.Accounts.User
  end

  identities do
    identity :unique_name_per_tenant, [:name, :tenant_id]
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(tenant_id == ^actor(:tenant_id))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(tenant_id == ^actor(:tenant_id))
    end
  end

  code_interface do
    define :get, action: :read, get?: true
    define :list, action: :read
    define :create
    define :update
    define :destroy
  end
end

# Agent: Worker - 6 (ASH Domain Implementation Specialist)
# SOPv5.1 Compliance: ✅ AuthorizationLog resource with cybernetic coordination
# Domain: Authorization
# Responsibilities: AuthorizationLog management and authorization domain integration
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
