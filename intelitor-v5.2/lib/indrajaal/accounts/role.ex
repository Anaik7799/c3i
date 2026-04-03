defmodule Indrajaal.Accounts.Role do
  @moduledoc """
  Ash resource for role management.

  Implements role-based access control with multi-tenant isolation
  and comprehensive audit capabilities.
  Generated with SOPv5.11 cybernetic framework integration.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Accounts,
    table: "account_roles"

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      public? true
      constraints max_length: 500
    end

    attribute :active, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :permissions, {:array, :string} do
      public? true
      default []
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    # Audit fields
    attribute :created_by_id, :uuid do
      public? true
    end

    attribute :updated_by_id, :uuid do
      public? true
    end

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :name,
        :description,
        :active,
        :permissions,
        :metadata
      ]

      argument :tenant_id, :uuid do
        allow_nil? false
      end

      argument :created_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:tenant_id, arg(:tenant_id))
      change set_attribute(:created_by_id, arg(:created_by_id))

      validate present([:name])
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :name,
        :description,
        :active,
        :permissions,
        :metadata
      ]

      argument :updated_by_id, :uuid

      change set_attribute(:updated_by_id, arg(:updated_by_id))
    end
  end

  relationships do
    belongs_to :created_by, Indrajaal.Accounts.User do
      source_attribute :created_by_id
      attribute_public? true
    end

    belongs_to :updated_by, Indrajaal.Accounts.User do
      source_attribute :updated_by_id
      attribute_public? true
    end
  end

  policies do
    bypass always() do
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action(:create) do
      authorize_if always()
    end

    policy action(:read) do
      authorize_if always()
    end

    policy action([:update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
  end

  postgres do
    table "account_roles"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :active]
      index [:name]
      index [:created_by_id]
    end
  end
end
