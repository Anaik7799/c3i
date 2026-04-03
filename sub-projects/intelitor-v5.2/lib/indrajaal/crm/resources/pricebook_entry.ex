defmodule Indrajaal.Crm.PricebookEntry do
  @moduledoc """
  PricebookEntry Resource - Links products to pricebooks with pricing.

  ## WHAT
  Junction table between Product and Pricebook that stores:
  - The product
  - The pricebook it belongs to
  - The list price for that product in that pricebook
  - Active status

  ## WHY
  Enables a product to have different prices in different pricebooks:
  - Standard price: $100
  - Partner price: $85
  - Enterprise price: $75

  ## STAMP Constraints
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: uuid_primary_key :id
  - SC-DB-012: create_if_not_exists for indexes
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  postgres do
    table "pricebook_entries"
    repo Indrajaal.Repo

    references do
      reference :product, on_delete: :delete
      reference :pricebook, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :unit_price, :decimal do
      allow_nil? false
      public? true
      constraints precision: 10, scale: 2
    end

    attribute :is_active, :boolean do
      public? true
      default true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :product, Indrajaal.Crm.Product do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :pricebook, Indrajaal.Crm.Pricebook do
      allow_nil? false
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:product_id, :pricebook_id, :unit_price, :is_active]
      primary? true
    end

    update :update do
      accept [:unit_price, :is_active]
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

    read :by_pricebook do
      argument :pricebook_id, :uuid, allow_nil?: false
      filter expr(pricebook_id == ^arg(:pricebook_id) and is_active == true)
    end

    read :by_product do
      argument :product_id, :uuid, allow_nil?: false
      filter expr(product_id == ^arg(:product_id) and is_active == true)
    end
  end

  identities do
    identity :unique_product_pricebook, [:product_id, :pricebook_id]
  end

  postgres do
    custom_indexes do
      index [:pricebook_id, :is_active]
      index [:product_id, :is_active]
      index [:product_id, :pricebook_id], unique: true
    end
  end
end
