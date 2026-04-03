defmodule Indrajaal.Crm.Product do
  @moduledoc """
  Product Resource - Product catalog for sales.

  ## WHAT
  Represents products and services that can be sold. Products have:
  - Unique product codes (SKU)
  - Product families for categorization
  - Active/inactive status
  - Links to multiple pricebooks via PricebookEntry

  ## WHY
  Central product catalog for:
  - Quote line items
  - Opportunity products
  - Order line items
  - Revenue tracking per product

  ## STAMP Constraints
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: uuid_primary_key :id
  - SC-DB-012: create_if_not_exists for indexes
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  postgres do
    table "products"
    repo Indrajaal.Repo

    references do
      reference :pricebook_entries, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :product_code, :string do
      public? true
      description "SKU or product identifier"
    end

    attribute :description, :string do
      public? true
    end

    attribute :family, :atom do
      public? true
      constraints one_of: [:hardware, :software, :service, :subscription, :other]
      default :other
    end

    attribute :is_active, :boolean do
      public? true
      default true
    end

    attribute :quantity_unit, :string do
      public? true
      default "Each"
      description "Unit of measure (Each, Hours, GB, etc.)"
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :pricebook_entries, Indrajaal.Crm.PricebookEntry
    has_many :quote_line_items, Indrajaal.Crm.QuoteLineItem
    has_many :opportunity_line_items, Indrajaal.Crm.OpportunityLineItem
    has_many :order_line_items, Indrajaal.Crm.OrderLineItem
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :product_code, :description, :family, :is_active, :quantity_unit]
      primary? true
    end

    update :update do
      accept [:name, :product_code, :description, :family, :is_active, :quantity_unit]
      primary? true
    end

    update :activate do
      accept []
      change set_attribute(:is_active, true)
    end

    update :deactivate do
      accept []
      change set_attribute(:is_active, false)
    end

    read :active_products do
      filter expr(is_active == true)
    end

    read :by_family do
      argument :family, :atom, allow_nil?: false
      filter expr(family == ^arg(:family))
    end
  end

  identities do
    identity :unique_product_code, [:product_code]
  end

  postgres do
    custom_indexes do
      index [:is_active, :family], where: "is_active = true"
      index [:product_code], unique: true, where: "product_code IS NOT NULL"
    end
  end
end
