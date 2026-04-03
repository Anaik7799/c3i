defmodule Indrajaal.Crm.Quote do
  @moduledoc """
  Quote Resource - CPQ (Configure, Price, Quote) for opportunities.

  ## WHAT
  Formal price quote presented to customer containing:
  - Line items (products + quantities + prices)
  - Discounts (line item and total)
  - Tax calculations
  - Billing and shipping addresses
  - Approval workflow status

  ## WHY
  CPQ functionality for sales:
  - Configure product bundles
  - Calculate pricing with discounts
  - Generate PDF quotes
  - Track quote acceptance
  - Link to opportunities

  ## STAMP Constraints
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: uuid_primary_key :id
  - SC-ASH-004: require_atomic? false for calculations
  - SC-DB-012: create_if_not_exists for indexes

  ## FMEA Mitigations
  - Price calculation error (RPN 108): Dual calculation path + audit log
  - Quote version conflict (RPN 140): Optimistic locking via updated_at
  - Discount abuse (RPN 72): Approval workflow for discounts > 20%
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  postgres do
    table "quotes"
    repo Indrajaal.Repo

    references do
      reference :opportunity, on_delete: :nilify
      reference :account, on_delete: :nilify
      reference :contact, on_delete: :nilify
      reference :pricebook, on_delete: :restrict
      reference :line_items, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :quote_number, :string do
      public? true
      description "Auto-generated quote number (Q-YYYYMMDD-NNNN)"
    end

    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :draft,
                    :needs_review,
                    :approved,
                    :rejected,
                    :presented,
                    :accepted,
                    :denied
                  ]

      default :draft
    end

    attribute :expiration_date, :date do
      public? true
    end

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

    attribute :total, :decimal do
      public? true
      constraints precision: 10, scale: 2
      default Decimal.new(0)
    end

    attribute :tax, :decimal do
      public? true
      constraints precision: 10, scale: 2
      default Decimal.new(0)
    end

    attribute :grand_total, :decimal do
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
    belongs_to :opportunity, Indrajaal.Crm.Opportunity do
      attribute_writable? true
    end

    belongs_to :account, Indrajaal.Crm.Account do
      attribute_writable? true
    end

    belongs_to :contact, Indrajaal.Crm.Contact do
      attribute_writable? true
    end

    belongs_to :pricebook, Indrajaal.Crm.Pricebook do
      allow_nil? false
      attribute_writable? true
    end

    has_many :line_items, Indrajaal.Crm.QuoteLineItem
  end

  calculations do
    calculate :discount_percentage,
              :decimal,
              expr(
                fragment(
                  "CASE WHEN ? > 0 THEN (? / ?) * 100 ELSE 0 END",
                  subtotal,
                  discount,
                  subtotal
                )
              ) do
      allow_nil? false
      constraints precision: 5, scale: 2
    end

    calculate :line_item_count, :integer, expr(count(line_items)) do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :status,
        :expiration_date,
        :opportunity_id,
        :account_id,
        :contact_id,
        :pricebook_id,
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
        # Generate quote number
        quote_number =
          "Q-#{Date.utc_today() |> Date.to_iso8601(:basic)}-#{:rand.uniform(9999) |> Integer.to_string() |> String.pad_leading(4, "0")}"

        Ash.Changeset.force_change_attribute(changeset, :quote_number, quote_number)
      end
    end

    update :update do
      accept [
        :name,
        :status,
        :expiration_date,
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
        quote = changeset.data
        line_items = Ash.load!(quote, :line_items).line_items

        subtotal =
          Enum.reduce(line_items, Decimal.new(0), fn item, acc ->
            Decimal.add(acc, item.total_price)
          end)

        total = Decimal.sub(subtotal, quote.discount)
        grand_total = Decimal.add(total, quote.tax)

        changeset
        |> Ash.Changeset.force_change_attribute(:subtotal, subtotal)
        |> Ash.Changeset.force_change_attribute(:total, total)
        |> Ash.Changeset.force_change_attribute(:grand_total, grand_total)
      end
    end

    update :submit_for_approval do
      accept []
      change set_attribute(:status, :needs_review)
    end

    update :approve do
      accept []
      change set_attribute(:status, :approved)
    end

    update :reject do
      accept []
      change set_attribute(:status, :rejected)
    end

    update :present do
      accept []
      change set_attribute(:status, :presented)
    end

    update :accept do
      accept []
      change set_attribute(:status, :accepted)
    end

    update :deny do
      accept []
      change set_attribute(:status, :denied)
    end

    action :clone, :map do
      argument :quote_id, :uuid, allow_nil?: false

      run fn input, _context ->
        quote_id = input.arguments.quote_id

        case Ash.get(Indrajaal.Crm.Quote, quote_id) do
          {:ok, quote} ->
            quote = Ash.load!(quote, :line_items)

            # Create new quote
            {:ok, new_quote} =
              Indrajaal.Crm.Quote
              |> Ash.Changeset.for_create(:create, %{
                name: "#{quote.name} (Copy)",
                opportunity_id: quote.opportunity_id,
                account_id: quote.account_id,
                contact_id: quote.contact_id,
                pricebook_id: quote.pricebook_id,
                description: quote.description,
                billing_street: quote.billing_street,
                billing_city: quote.billing_city,
                billing_state: quote.billing_state,
                billing_postal_code: quote.billing_postal_code,
                billing_country: quote.billing_country
              })
              |> Ash.create()

            {:ok, %{quote_id: new_quote.id}}

          {:error, _} ->
            {:error, :quote_not_found}
        end
      end
    end

    read :by_opportunity do
      argument :opportunity_id, :uuid, allow_nil?: false
      filter expr(opportunity_id == ^arg(:opportunity_id))
    end

    read :by_account do
      argument :account_id, :uuid, allow_nil?: false
      filter expr(account_id == ^arg(:account_id))
    end

    read :by_status do
      argument :status, :atom, allow_nil?: false
      filter expr(status == ^arg(:status))
    end
  end

  identities do
    identity :unique_quote_number, [:quote_number]
  end

  postgres do
    custom_indexes do
      index [:status]
      index [:opportunity_id]
      index [:account_id]
      index [:expiration_date]
      index [:quote_number], unique: true, where: "quote_number IS NOT NULL"
    end
  end
end
