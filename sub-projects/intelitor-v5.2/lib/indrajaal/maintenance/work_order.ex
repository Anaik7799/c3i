defmodule Indrajaal.Maintenance.WorkOrder do
  @moduledoc """
  Work order management for maintenance activities.

  Implements multi-tenant data model with audit fields.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Maintenance

  use Indrajaal.Multitenancy.TenantResource

  postgres do
    table "work_orders"
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

    attribute :type, :string do
      constraints max_length: 100
    end

    attribute :status, :atom do
      constraints one_of: [:pending, :in_progress, :completed, :cancelled]
      default :pending
      allow_nil? false
    end

    attribute :priority, :atom do
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
      allow_nil? false
    end

    attribute :active, :boolean do
      default true
      allow_nil? false
    end

    attribute :metadata, :map do
      default %{}
    end

    attribute :configuration, :map do
      default %{}
    end

    attribute :tags, {:array, :string} do
      default []
    end

    attribute :equipment_id, :uuid do
      public? true
    end

    attribute :parent_schedule_id, :uuid do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :created_by, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :updated_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    read :by_id do
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))
    end

    create :create_work_order do
      accept [:name, :description, :type, :status, :priority, :configuration, :tags, :metadata]
      argument :created_by_id, :uuid, allow_nil?: false

      change set_attribute(:created_by_id, arg(:created_by_id))
    end

    update :update_status do
      require_atomic? false
      accept [:status]
      argument :updated_by_id, :uuid, allow_nil?: false

      change set_attribute(:updated_by_id, arg(:updated_by_id))
    end
  end

  code_interface do
    define :by_id, args: [:id]
    define :read_all, action: :read
    define :create
    define :update
    define :destroy
  end

  identities do
    identity :unique_name_per_tenant, [:name, :tenant_id]
  end
end
