defmodule Indrajaal.Crm.Pricebook do
  @moduledoc """
  Pricebook Resource - Price lists for different market segments.

  ## WHAT
  Represents a price list containing products at specific prices:
  - Standard pricebook (default)
  - Partner pricebook (discounted)
  - Enterprise pricebook (volume pricing)
  - Regional pricebooks (currency/locale)

  ## WHY
  Enables flexible pricing strategies:
  - Different prices for different customer segments
  - Seasonal pricing
  - Promotional pricing
  - Volume discounts

  ## STAMP Constraints
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: uuid_primary_key :id
  - SC-DB-012: create_if_not_exists for indexes
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  postgres do
    table "pricebooks"
    repo Indrajaal.Repo

    references do
      reference :pricebook_entries, on_delete: :delete
      reference :quotes, on_delete: :nilify
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :is_active, :boolean do
      public? true
      default true
    end

    attribute :is_standard, :boolean do
      public? true
      default false
      description "Is this the default/standard pricebook?"
    end

    attribute :currency_code, :string do
      public? true
      default "USD"
      constraints max_length: 3
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :pricebook_entries, Indrajaal.Crm.PricebookEntry
    has_many :quotes, Indrajaal.Crm.Quote
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :is_active, :is_standard, :currency_code]
      primary? true
    end

    update :update do
      accept [:name, :description, :is_active, :is_standard, :currency_code]
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

    read :standard_pricebook do
      filter expr(is_standard == true and is_active == true)
      get? true
    end

    read :active_pricebooks do
      filter expr(is_active == true)
    end
  end

  identities do
    identity :unique_name, [:name]
  end

  postgres do
    custom_indexes do
      index [:is_active, :is_standard]
      index [:currency_code]
    end
  end
end
