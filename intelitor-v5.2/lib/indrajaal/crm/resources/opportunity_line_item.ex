defmodule Indrajaal.Crm.OpportunityLineItem do
  @moduledoc """
  OpportunityLineItem Resource - Products associated with opportunities.

  ## WHAT
  Links products to opportunities for:
  - Revenue tracking per product
  - Product mix analysis
  - Forecast by product family
  - Win/loss analysis per product

  ## WHY
  Product-level opportunity tracking:
  - Which products are selling?
  - What's the revenue per product?
  - Product bundle analysis
  - Cross-sell/upsell tracking

  ## STAMP Constraints
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: uuid_primary_key :id
  - SC-DB-012: create_if_not_exists for indexes
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  postgres do
    table "opportunity_line_items"
    repo Indrajaal.Repo

    references do
      reference :opportunity, on_delete: :delete
      reference :product, on_delete: :restrict
      reference :pricebook_entry, on_delete: :restrict
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :decimal do
      allow_nil? false
      public? true
      constraints precision: 10, scale: 2
      default Decimal.new(1)
    end

    attribute :unit_price, :decimal do
      allow_nil? false
      public? true
      constraints precision: 10, scale: 2
    end

    attribute :total_price, :decimal do
      public? true
      constraints precision: 10, scale: 2
      default Decimal.new(0)
    end

    attribute :description, :string do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :opportunity, Indrajaal.Crm.Opportunity do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :product, Indrajaal.Crm.Product do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :pricebook_entry, Indrajaal.Crm.PricebookEntry do
      attribute_writable? true
    end
  end

  calculations do
    calculate :revenue_contribution, :decimal, expr(fragment("? * ?", quantity, unit_price)) do
      allow_nil? false
      constraints precision: 10, scale: 2
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :opportunity_id,
        :product_id,
        :pricebook_entry_id,
        :quantity,
        :unit_price,
        :description
      ]

      primary? true

      change fn changeset, _context ->
        quantity = Ash.Changeset.get_attribute(changeset, :quantity)
        unit_price = Ash.Changeset.get_attribute(changeset, :unit_price)
        total_price = Decimal.mult(quantity, unit_price)

        Ash.Changeset.force_change_attribute(changeset, :total_price, total_price)
      end
    end

    update :update do
      accept [:quantity, :unit_price, :description]
      primary? true
      require_atomic? false

      change fn changeset, _context ->
        quantity = Ash.Changeset.get_attribute(changeset, :quantity)
        unit_price = Ash.Changeset.get_attribute(changeset, :unit_price)
        total_price = Decimal.mult(quantity, unit_price)

        Ash.Changeset.force_change_attribute(changeset, :total_price, total_price)
      end
    end

    read :by_opportunity do
      argument :opportunity_id, :uuid, allow_nil?: false
      filter expr(opportunity_id == ^arg(:opportunity_id))
    end

    read :by_product do
      argument :product_id, :uuid, allow_nil?: false
      filter expr(product_id == ^arg(:product_id))
    end
  end

  postgres do
    custom_indexes do
      index [:opportunity_id]
      index [:product_id]
    end
  end
end
