defmodule Indrajaal.Crm.Campaign do
  @moduledoc """
  Campaign Resource - Marketing campaigns for lead generation.

  ## WHAT
  Represents marketing campaigns with:
  - Campaign type (email, webinar, conference, etc.)
  - Budget tracking (budgeted vs actual cost)
  - Expected vs actual response rates
  - Parent/child campaign hierarchy
  - ROI calculation

  ## WHY
  Marketing campaign management:
  - Track campaign effectiveness
  - Measure ROI
  - Link leads to campaigns
  - Analyze campaign performance
  - Plan future campaigns

  ## STAMP Constraints
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: uuid_primary_key :id
  - SC-ASH-004: require_atomic? false for ROI calculation
  - SC-DB-012: create_if_not_exists for indexes
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  postgres do
    table "campaigns"
    repo Indrajaal.Repo

    references do
      reference :parent_campaign, on_delete: :nilify
      reference :child_campaigns, on_delete: :nilify
      reference :campaign_members, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :type, :atom do
      public? true

      constraints one_of: [
                    :email,
                    :webinar,
                    :conference,
                    :advertisement,
                    :direct_mail,
                    :referral,
                    :social,
                    :other
                  ]

      default :other
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:planned, :in_progress, :completed, :aborted]
      default :planned
    end

    attribute :start_date, :date, public?: true
    attribute :end_date, :date, public?: true

    attribute :budgeted_cost, :decimal do
      public? true
      constraints precision: 10, scale: 2
      default Decimal.new(0)
    end

    attribute :actual_cost, :decimal do
      public? true
      constraints precision: 10, scale: 2
      default Decimal.new(0)
    end

    attribute :expected_revenue, :decimal do
      public? true
      constraints precision: 10, scale: 2
      default Decimal.new(0)
    end

    attribute :expected_response_rate, :decimal do
      public? true
      constraints precision: 5, scale: 2
      default Decimal.new(0)
      description "Expected response rate as percentage"
    end

    attribute :is_active, :boolean do
      public? true
      default true
    end

    attribute :description, :string, public?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :parent_campaign, __MODULE__ do
      attribute_writable? true
    end

    has_many :child_campaigns, __MODULE__ do
      destination_attribute :parent_campaign_id
    end

    has_many :campaign_members, Indrajaal.Crm.CampaignMember
  end

  calculations do
    calculate :roi,
              :decimal,
              expr(
                fragment(
                  "CASE WHEN ? > 0 THEN ((? - ?) / ?) * 100 ELSE 0 END",
                  actual_cost,
                  expected_revenue,
                  actual_cost,
                  actual_cost
                )
              ) do
      allow_nil? false
      constraints precision: 10, scale: 2
    end

    calculate :num_leads,
              :integer,
              expr(count(campaign_members, query: [filter: expr(member_type == :lead)])) do
      allow_nil? false
    end

    calculate :num_contacts,
              :integer,
              expr(count(campaign_members, query: [filter: expr(member_type == :contact)])) do
      allow_nil? false
    end

    calculate :total_members, :integer, expr(count(campaign_members)) do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :type,
        :status,
        :start_date,
        :end_date,
        :budgeted_cost,
        :actual_cost,
        :expected_revenue,
        :expected_response_rate,
        :is_active,
        :description,
        :parent_campaign_id
      ]

      primary? true
    end

    update :update do
      accept [
        :name,
        :type,
        :status,
        :start_date,
        :end_date,
        :budgeted_cost,
        :actual_cost,
        :expected_revenue,
        :expected_response_rate,
        :is_active,
        :description
      ]

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

    update :start do
      accept []
      change set_attribute(:status, :in_progress)
    end

    update :complete do
      accept []
      change set_attribute(:status, :completed)
    end

    update :abort do
      accept []
      change set_attribute(:status, :aborted)
    end

    read :active_campaigns do
      filter expr(is_active == true)
    end

    read :by_status do
      argument :status, :atom, allow_nil?: false
      filter expr(status == ^arg(:status))
    end

    read :by_type do
      argument :type, :atom, allow_nil?: false
      filter expr(type == ^arg(:type))
    end

    read :parent_campaigns do
      filter expr(is_nil(parent_campaign_id))
    end
  end

  postgres do
    custom_indexes do
      index [:status, :is_active]
      index [:type]
      index [:start_date]
      index [:parent_campaign_id]
    end
  end
end
