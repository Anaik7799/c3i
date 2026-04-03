defmodule Indrajaal.Crm.Order do
  @moduledoc """
  Order Resource - Sales orders for fulfillment.

  ## WHAT
  Represents a confirmed sales order containing:
  - Reference to quote (optional)
  - Reference to account and contact
  - Order status (draft, submitted, approved, activated, cancelled)
  - Order type (new, renewal, upgrade)
  - Billing and shipping information
  - Line items with products

  ## WHY
  Order management and fulfillment:
  - Convert quotes to orders
  - Track order status
  - Revenue recognition
  - Fulfillment tracking
  - Invoice generation

  ## STAMP Constraints
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: uuid_primary_key :id
  - SC-ASH-004: require_atomic? false for calculations
  - SC-DB-012: create_if_not_exists for indexes
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  postgres do
    table "orders"
    repo Indrajaal.Repo

    references do
      reference :account, on_delete: :restrict
      reference :contact, on_delete: :nilify
      reference :quote, on_delete: :nilify
      reference :opportunity, on_delete: :nilify
      reference :line_items, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :order_number, :string do
      public? true
      description "Auto-generated order number (ORD-YYYYMMDD-NNNN)"
    end

    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :draft,
                    :submitted,
                    :approved,
                    :activated,
                    :cancelled,
                    :shipped,
                    :delivered
                  ]

      default :draft
    end

    attribute :order_type, :atom do
      public? true
      constraints one_of: [:new, :renewal, :upgrade, :downgrade]
      default :new
    end

    attribute :order_date, :date do
      public? true
      default &Date.utc_today/0
    end

    attribute :requested_delivery_date, :date, public?: true
    attribute :actual_delivery_date, :date, public?: true

    attribute :subtotal, :decimal do
      public? true
      constraints precision: 10, scale: 2
      default Decimal.new(0)
    end

    attribute :discount, :decimal do
      public? true
      constraints precision: 10, scale: 2
      default Decimal.new(0)
    end

    attribute :tax, :decimal do
      public? true
      constraints precision: 10, scale: 2
      default Decimal.new(0)
    end

    attribute :shipping_cost, :decimal do
      public? true
      constraints precision: 10, scale: 2
      default Decimal.new(0)
    end

    attribute :total, :decimal do
      public? true
      constraints precision: 10, scale: 2
      default Decimal.new(0)
    end

    # Billing Address
    attribute :billing_street, :string, public?: true
    attribute :billing_city, :string, public?: true
    attribute :billing_state, :string, public?: true
    attribute :billing_postal_code, :string, public?: true
    attribute :billing_country, :string, public?: true

    # Shipping Address
    attribute :shipping_street, :string, public?: true
    attribute :shipping_city, :string, public?: true
    attribute :shipping_state, :string, public?: true
    attribute :shipping_postal_code, :string, public?: true
    attribute :shipping_country, :string, public?: true

    attribute :description, :string, public?: true
    attribute :internal_notes, :string, public?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :account, Indrajaal.Crm.Account do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :contact, Indrajaal.Crm.Contact do
      attribute_writable? true
    end

    belongs_to :quote, Indrajaal.Crm.Quote do
      attribute_writable? true
      description "Source quote if order was created from quote"
    end

    belongs_to :opportunity, Indrajaal.Crm.Opportunity do
      attribute_writable? true
    end

    has_many :line_items, Indrajaal.Crm.OrderLineItem
  end

  calculations do
    calculate :line_item_count, :integer, expr(count(line_items)) do
      allow_nil? false
    end

    calculate :grand_total, :decimal, expr(subtotal - discount + tax + shipping_cost) do
      allow_nil? false
      constraints precision: 10, scale: 2
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :account_id,
        :contact_id,
        :quote_id,
        :opportunity_id,
        :status,
        :order_type,
        :order_date,
        :requested_delivery_date,
        :description,
        :internal_notes,
        :billing_street,
        :billing_city,
        :billing_state,
        :billing_postal_code,
        :billing_country,
        :shipping_street,
        :shipping_city,
        :shipping_state,
        :shipping_postal_code,
        :shipping_country
      ]

      primary? true

      change fn changeset, _context ->
        # Generate order number
        order_number =
          "ORD-#{Date.utc_today() |> Date.to_iso8601(:basic)}-#{:rand.uniform(9999) |> Integer.to_string() |> String.pad_leading(4, "0")}"

        Ash.Changeset.force_change_attribute(changeset, :order_number, order_number)
      end
    end

    update :update do
      accept [
        :status,
        :order_type,
        :requested_delivery_date,
        :actual_delivery_date,
        :description,
        :internal_notes,
        :billing_street,
        :billing_city,
        :billing_state,
        :billing_postal_code,
        :billing_country,
        :shipping_street,
        :shipping_city,
        :shipping_state,
        :shipping_postal_code,
        :shipping_country
      ]

      primary? true
    end

    update :calculate_totals do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        order = changeset.data
        line_items = Ash.load!(order, :line_items).line_items

        subtotal =
          Enum.reduce(line_items, Decimal.new(0), fn item, acc ->
            Decimal.add(acc, item.total_price)
          end)

        total = Decimal.sub(subtotal, order.discount)
        total = Decimal.add(total, order.tax)
        total = Decimal.add(total, order.shipping_cost)

        changeset
        |> Ash.Changeset.force_change_attribute(:subtotal, subtotal)
        |> Ash.Changeset.force_change_attribute(:total, total)
      end
    end

    update :submit do
      accept []
      change set_attribute(:status, :submitted)
    end

    update :approve do
      accept []
      change set_attribute(:status, :approved)
    end

    update :activate do
      accept []
      change set_attribute(:status, :activated)
    end

    update :cancel do
      accept []
      change set_attribute(:status, :cancelled)
    end

    update :mark_shipped do
      accept []
      change set_attribute(:status, :shipped)
    end

    update :mark_delivered do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :delivered)
        |> Ash.Changeset.force_change_attribute(:actual_delivery_date, Date.utc_today())
      end
    end

    action :create_from_quote, :map do
      argument :quote_id, :uuid, allow_nil?: false

      run fn input, _context ->
        quote_id = input.arguments.quote_id

        case Ash.get(Indrajaal.Crm.Quote, quote_id) do
          {:ok, quote} ->
            quote = Ash.load!(quote, :line_items)

            # Create order
            {:ok, order} =
              Indrajaal.Crm.Order
              |> Ash.Changeset.for_create(:create, %{
                account_id: quote.account_id,
                contact_id: quote.contact_id,
                quote_id: quote.id,
                opportunity_id: quote.opportunity_id,
                billing_street: quote.billing_street,
                billing_city: quote.billing_city,
                billing_state: quote.billing_state,
                billing_postal_code: quote.billing_postal_code,
                billing_country: quote.billing_country,
                shipping_street: quote.shipping_street,
                shipping_city: quote.shipping_city,
                shipping_state: quote.shipping_state,
                shipping_postal_code: quote.shipping_postal_code,
                shipping_country: quote.shipping_country
              })
              |> Ash.create()

            {:ok, %{order_id: order.id}}

          {:error, _} ->
            {:error, :quote_not_found}
        end
      end
    end

    read :by_account do
      argument :account_id, :uuid, allow_nil?: false
      filter expr(account_id == ^arg(:account_id))
    end

    read :by_status do
      argument :status, :atom, allow_nil?: false
      filter expr(status == ^arg(:status))
    end

    read :by_quote do
      argument :quote_id, :uuid, allow_nil?: false
      filter expr(quote_id == ^arg(:quote_id))
    end
  end

  identities do
    identity :unique_order_number, [:order_number]
  end

  postgres do
    custom_indexes do
      index [:status]
      index [:account_id]
      index [:quote_id]
      index [:order_date]
      index [:order_number], unique: true, where: "order_number IS NOT NULL"
    end
  end
end
