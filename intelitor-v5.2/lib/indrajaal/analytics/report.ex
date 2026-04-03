defmodule Indrajaal.Analytics.Report do
  @moduledoc """
  Analytics Report Resource - Comprehensive analytics and reporting management.

  Implements multi-tenant analytics reports with advanced configuration
  and analytics-specific attributes for business intelligence operations.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Analytics

  use Indrajaal.Multitenancy.TenantResource

  postgres do
    table "analytics"
    repo Indrajaal.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 255
    end

    attribute :description, :string do
      constraints max_length: 1000
    end

    attribute :active, :boolean do
      default true
      allow_nil? false
    end

    attribute :metadata, :map do
      default %{}
    end

    # Domain-specific fields
    attribute :type, :string do
      constraints max_length: 100
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :published, :archived, :active, :inactive]
      default :draft
    end

    attribute :configuration, :map do
      default %{}
    end

    attribute :tags, {:array, :string} do
      default []
    end

    # Audit fields
    attribute :created_by_id, :uuid
    attribute :updated_by_id, :uuid

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    # Future relationships can be added here
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    create :create_report do
      accept [:name, :description, :active, :metadata, :type, :status, :configuration, :tags]

      change fn changeset, __context ->
        tenant_id = Ash.Changeset.get_context(changeset, :tenant_id)

        changeset
        |> Ash.Changeset.change_attribute(:tenant_id, tenant_id)
      end
    end

    update :update_report do
      accept [:name, :description, :active, :metadata, :type, :status, :configuration, :tags]
      require_atomic? false
    end

    read :list_reports do
      # Default read action with tenant filtering
    end

    read :get_report do
      get? true
    end
  end

  identities do
    identity :unique_name_per_tenant, [:name, :tenant_id]
  end

  @doc false
  def changeset(struct, attrs) do
    struct
    |> Map.merge(attrs)
  end
end

# Agent: Worker - 6 (Analytics Domain Agent)
# SOPv5.1 Compliance: ✅ Data analytics and business intelligence coordination w
# Domain: Analytics
# Responsibilities: Data analytics, business intelligence, performance metrics
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
