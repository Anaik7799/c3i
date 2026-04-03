defmodule Indrajaal.Crm.QuoteLineItem do
  @moduledoc """
  QuoteLineItem Resource - Individual line items on a quote.

  ## WHAT
  Represents a single product on a quote with:
  - Product reference
  - Quantity
  - Unit price (from pricebook or override)
  - Discount (percentage or amount)
  - Total price (calculated)
  - Sort order for presentation

  ## WHY
  Line-item detail for quotes:
  - Multiple products per quote
  - Individual pricing/discounts
  - Bundle configuration
  - Revenue allocation

  ## STAMP Constraints
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: uuid_primary_key :id
  - SC-ASH-004: require_atomic? false for calculations
  - SC-DB-012: create_if_not_exists for indexes

  ## FMEA Mitigations
  - Price calculation error (RPN 108): Auto-calculate on save
  - Inventory mismatch (RPN 112): Validate quantity against availability
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  postgres do
    table "quote_line_items"
    repo Indrajaal.Repo

    references do
      reference :quote, on_delete: :delete
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
      description "Price per unit (from pricebook or override)"
    end

    attribute :discount, :decimal do
      public? true
      constraints precision: 10, scale: 2
      default Decimal.new(0)
      description "Discount amount (not percentage)"
    end

    attribute :total_price, :decimal do
      public? true
      constraints precision: 10, scale: 2
      default Decimal.new(0)
    end

    attribute :sort_order, :integer do
      public? true
      default 0
      description "Display order on quote"
    end

    attribute :description, :string do
      public? true
      description "Optional line item description"
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :quote, Indrajaal.Crm.Quote do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :product, Indrajaal.Crm.Product do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :pricebook_entry, Indrajaal.Crm.PricebookEntry do
      attribute_writable? true
      description "Source of unit price from pricebook"
    end
  end

  calculations do
    calculate :discount_percentage,
              :decimal,
              expr(
                fragment(
                  "CASE WHEN ? > 0 THEN (? / (? * ?)) * 100 ELSE 0 END",
                  unit_price,
                  discount,
                  quantity,
                  unit_price
                )
              ) do
      allow_nil? false
      constraints precision: 5, scale: 2
    end

    calculate :subtotal, :decimal, expr(quantity * unit_price) do
      allow_nil? false
      constraints precision: 10, scale: 2
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :quote_id,
        :product_id,
        :pricebook_entry_id,
        :quantity,
        :unit_price,
        :discount,
        :sort_order,
        :description
      ]

      primary? true

      change fn changeset, _context ->
        # Calculate total_price
        quantity = Ash.Changeset.get_attribute(changeset, :quantity)
        unit_price = Ash.Changeset.get_attribute(changeset, :unit_price)
        discount = Ash.Changeset.get_attribute(changeset, :discount) || Decimal.new(0)

        subtotal = Decimal.mult(quantity, unit_price)
        total_price = Decimal.sub(subtotal, discount)

        Ash.Changeset.force_change_attribute(changeset, :total_price, total_price)
      end
    end

    update :update do
      accept [:quantity, :unit_price, :discount, :sort_order, :description]
      primary? true
      require_atomic? false

      change fn changeset, _context ->
        # Recalculate total_price
        quantity = Ash.Changeset.get_attribute(changeset, :quantity)
        unit_price = Ash.Changeset.get_attribute(changeset, :unit_price)
        discount = Ash.Changeset.get_attribute(changeset, :discount) || Decimal.new(0)

        subtotal = Decimal.mult(quantity, unit_price)
        total_price = Decimal.sub(subtotal, discount)

        Ash.Changeset.force_change_attribute(changeset, :total_price, total_price)
      end
    end

    read :by_quote do
      argument :quote_id, :uuid, allow_nil?: false
      filter expr(quote_id == ^arg(:quote_id))
      prepare build(sort: [:sort_order, :created_at])
    end
  end

  postgres do
    custom_indexes do
      index [:quote_id, :sort_order]
      index [:product_id]
    end
  end
end
