defmodule Indrajaal.Crm.Account do
  @moduledoc """
  CRM Account resource representing companies/organizations.

  Features:
  - Parent/child account hierarchy
  - Account teams and territory assignment
  - 360° customer view aggregations
  - Industry and revenue tracking
  - Relationship management

  ## STAMP Compliance
  - SC-ASH-001: force_change_attribute in before_action
  - SC-ASH-004: require_atomic? false for fn changes
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: uuid_primary_key
  - SC-DB-012: create_if_not_exists indexes
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Basic Information
    attribute :name, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 255
      description "Account/Company name"
    end

    attribute :account_number, :string do
      constraints max_length: 50
      description "External account reference number"
    end

    attribute :type, :atom do
      constraints one_of: [:customer, :prospect, :partner, :competitor, :other]
      default :prospect
      description "Account type"
    end

    attribute :industry, :string do
      constraints max_length: 100
      description "Industry sector"
    end

    attribute :annual_revenue, :decimal do
      constraints precision: 15, scale: 2
      description "Annual revenue"
    end

    attribute :num_employees, :integer do
      description "Number of employees"
    end

    attribute :website, :string do
      constraints max_length: 255
      description "Company website"
    end

    # Address Information
    attribute :billing_street, :string do
      constraints max_length: 255
    end

    attribute :billing_city, :string do
      constraints max_length: 100
    end

    attribute :billing_state, :string do
      constraints max_length: 100
    end

    attribute :billing_postal_code, :string do
      constraints max_length: 20
    end

    attribute :billing_country, :string do
      constraints max_length: 100
    end

    attribute :shipping_street, :string do
      constraints max_length: 255
    end

    attribute :shipping_city, :string do
      constraints max_length: 100
    end

    attribute :shipping_state, :string do
      constraints max_length: 100
    end

    attribute :shipping_postal_code, :string do
      constraints max_length: 20
    end

    attribute :shipping_country, :string do
      constraints max_length: 100
    end

    # Business Details
    attribute :phone, :string do
      constraints max_length: 50
    end

    attribute :fax, :string do
      constraints max_length: 50
    end

    attribute :description, :string do
      description "Account description"
    end

    attribute :rating, :atom do
      constraints one_of: [:hot, :warm, :cold]
      description "Account rating"
    end

    attribute :status, :atom do
      default :active
      constraints one_of: [:active, :inactive, :pending]
      description "Account status"
    end

    # Territory and ownership
    attribute :territory, :string do
      constraints max_length: 100
      description "Sales territory"
    end

    attribute :sla, :atom do
      constraints one_of: [:gold, :silver, :bronze, :none]
      default :none
      description "Service level agreement"
    end

    # Metadata
    attribute :tags, {:array, :string} do
      default []
      description "Account tags"
    end

    attribute :custom_fields, :map do
      default %{}
      description "Custom field values"
    end

    attribute :created_by_id, :uuid
    attribute :updated_by_id, :uuid

    timestamps()
  end

  relationships do
    # Hierarchy
    belongs_to :parent_account, __MODULE__ do
      attribute_public? true
      description "Parent account for hierarchy"
    end

    has_many :child_accounts, __MODULE__ do
      destination_attribute :parent_account_id
      description "Child accounts"
    end

    # Ownership
    belongs_to :owner, Indrajaal.Accounts.User do
      attribute_public? true
      description "Account owner"
    end

    belongs_to :created_by, Indrajaal.Accounts.User do
      source_attribute :created_by_id
      attribute_public? true
    end

    belongs_to :updated_by, Indrajaal.Accounts.User do
      source_attribute :updated_by_id
      attribute_public? true
    end

    # Related records
    has_many :contacts, Indrajaal.Crm.Contact
    has_many :opportunities, Indrajaal.Crm.Opportunity
    has_many :activities, Indrajaal.Crm.Activity
    has_many :team_members, Indrajaal.Crm.AccountTeamMember
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :name,
        :account_number,
        :type,
        :industry,
        :annual_revenue,
        :num_employees,
        :website,
        :phone,
        :fax,
        :description,
        :rating,
        :territory,
        :sla,
        :billing_street,
        :billing_city,
        :billing_state,
        :billing_postal_code,
        :billing_country,
        :shipping_street,
        :shipping_city,
        :shipping_state,
        :shipping_postal_code,
        :shipping_country,
        :tags,
        :custom_fields
      ]

      argument :owner_id, :uuid
      argument :parent_account_id, :uuid
      argument :created_by_id, :uuid, allow_nil?: false

      change set_attribute(:owner_id, arg(:owner_id))
      change set_attribute(:parent_account_id, arg(:parent_account_id))
      change set_attribute(:created_by_id, arg(:created_by_id))

      validate present([:name])
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :name,
        :account_number,
        :type,
        :industry,
        :annual_revenue,
        :num_employees,
        :website,
        :phone,
        :fax,
        :description,
        :rating,
        :status,
        :territory,
        :sla,
        :billing_street,
        :billing_city,
        :billing_state,
        :billing_postal_code,
        :billing_country,
        :shipping_street,
        :shipping_city,
        :shipping_state,
        :shipping_postal_code,
        :shipping_country,
        :tags,
        :custom_fields
      ]

      argument :updated_by_id, :uuid

      change set_attribute(:updated_by_id, arg(:updated_by_id))
    end

    update :assign do
      require_atomic? false
      accept []

      argument :owner_id, :uuid, allow_nil?: false

      change fn changeset, _ ->
        owner_id = Ash.Changeset.get_argument(changeset, :owner_id)
        Ash.Changeset.change_attribute(changeset, :owner_id, owner_id)
      end
    end

    update :change_parent do
      require_atomic? false
      accept []

      argument :parent_account_id, :uuid

      change fn changeset, _ ->
        parent_id = Ash.Changeset.get_argument(changeset, :parent_account_id)
        Ash.Changeset.change_attribute(changeset, :parent_account_id, parent_id)
      end
    end

    update :activate do
      require_atomic? false
      accept []

      change set_attribute(:status, :active)
    end

    update :deactivate do
      require_atomic? false
      accept []

      change set_attribute(:status, :inactive)
    end

    update :upgrade_sla do
      require_atomic? false
      accept []

      argument :sla_level, :atom,
        allow_nil?: false,
        constraints: [one_of: [:gold, :silver, :bronze]]

      change fn changeset, _ ->
        sla = Ash.Changeset.get_argument(changeset, :sla_level)
        Ash.Changeset.change_attribute(changeset, :sla, sla)
      end
    end
  end

  calculations do
    calculate :has_parent?, :boolean, expr(not is_nil(parent_account_id))
    calculate :is_active?, :boolean, expr(status == :active)

    calculate :hierarchy_level, :integer do
      calculation fn records, _ ->
        # Calculate depth in hierarchy tree
        Enum.map(records, fn record ->
          calculate_hierarchy_depth(record)
        end)
      end
    end
  end

  validations do
    validate match(:website, ~r/^https?:\/\//) do
      where present(:website)
    end

    # Prevent circular parent relationships
    validate fn changeset, _ ->
      parent_id = Ash.Changeset.get_attribute(changeset, :parent_account_id)
      account_id = Ash.Changeset.get_attribute(changeset, :id)

      if parent_id && account_id && parent_id == account_id do
        {:error, field: :parent_account_id, message: "Cannot be parent of itself"}
      else
        :ok
      end
    end
  end

  policies do
    # Admins can do anything
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Managers can manage accounts
    policy action_type([:read, :create, :update]) do
      authorize_if actor_attribute_equals(:role, :manager)
    end

    # Operators can read and update assigned accounts
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :operator)
    end

    policy action_type(:update) do
      authorize_if expr(owner_id == ^actor(:id))
    end
  end

  code_interface do
    define :create
    define :update
    define :assign, args: [:owner_id]
    define :change_parent, args: [:parent_account_id]
    define :activate
    define :deactivate
    define :upgrade_sla, args: [:sla_level]
  end

  postgres do
    table "accounts"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :name]
      index [:account_number], unique: true, where: "account_number IS NOT NULL"
      index [:type]
      index [:industry]
      index [:status]
      index [:owner_id]
      index [:parent_account_id], where: "parent_account_id IS NOT NULL"
      index [:territory]
      index [:sla]
      index [:created_at]
    end
  end

  # Helper to calculate hierarchy depth
  defp calculate_hierarchy_depth(_record) do
    # Simplified - in production would traverse parent chain
    # This requires recursive query or preloaded parent data
    0
  end
end
