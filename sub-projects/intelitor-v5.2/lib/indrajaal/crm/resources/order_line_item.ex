defmodule Indrajaal.Crm.OrderLineItem do
  @moduledoc """
  OrderLineItem Resource - Individual line items on an order.

  ## WHAT
  Represents a single product on an order with:
  - Product reference
  - Quantity ordered
  - Unit price
  - Total price
  - Fulfillment status

  ## WHY
  Order line-item tracking for:
  - Product fulfillment
  - Inventory allocation
  - Revenue recognition
  - Shipping management

  ## STAMP Constraints
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: uuid_primary_key :id
  - SC-DB-012: create_if_not_exists for indexes
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  postgres do
    table "order_line_items"
    repo Indrajaal.Repo

    references do
      reference :order, on_delete: :delete
      reference :product, on_delete: :restrict
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

    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :pending,
                    :allocated,
                    :picked,
                    :packed,
                    :shipped,
                    :delivered,
                    :cancelled
                  ]

      default :pending
    end

    attribute :description, :string, public?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :order, Indrajaal.Crm.Order do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :product, Indrajaal.Crm.Product do
      allow_nil? false
      attribute_writable? true
    end
  end

  calculations do
    calculate :extended_price, :decimal, expr(quantity * unit_price) do
      allow_nil? false
      constraints precision: 10, scale: 2
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:order_id, :product_id, :quantity, :unit_price, :status, :description]
      primary? true

      change fn changeset, _context ->
        quantity = Ash.Changeset.get_attribute(changeset, :quantity)
        unit_price = Ash.Changeset.get_attribute(changeset, :unit_price)
        total_price = Decimal.mult(quantity, unit_price)

        Ash.Changeset.force_change_attribute(changeset, :total_price, total_price)
      end
    end

    update :update do
      accept [:quantity, :unit_price, :status, :description]
      primary? true
      require_atomic? false

      change fn changeset, _context ->
        quantity = Ash.Changeset.get_attribute(changeset, :quantity)
        unit_price = Ash.Changeset.get_attribute(changeset, :unit_price)
        total_price = Decimal.mult(quantity, unit_price)

        Ash.Changeset.force_change_attribute(changeset, :total_price, total_price)
      end
    end

    update :allocate do
      accept []
      change set_attribute(:status, :allocated)
    end

    update :pick do
      accept []
      change set_attribute(:status, :picked)
    end

    update :pack do
      accept []
      change set_attribute(:status, :packed)
    end

    update :ship do
      accept []
      change set_attribute(:status, :shipped)
    end

    update :deliver do
      accept []
      change set_attribute(:status, :delivered)
    end

    update :cancel do
      accept []
      change set_attribute(:status, :cancelled)
    end

    read :by_order do
      argument :order_id, :uuid, allow_nil?: false
      filter expr(order_id == ^arg(:order_id))
    end

    read :by_status do
      argument :status, :atom, allow_nil?: false
      filter expr(status == ^arg(:status))
    end
  end

  postgres do
    custom_indexes do
      index [:order_id]
      index [:product_id]
      index [:status]
    end
  end
end
