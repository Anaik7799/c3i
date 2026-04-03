defmodule Indrajaal.Communication.BroadcastCampaign do
  @moduledoc """
  Coordinated messaging campaigns across multiple channels and recipients.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.CommunicationDomain

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :description, :string do
      constraints max_length: 1000
    end

    attribute :campaign_type, :atom do
      constraints one_of: [:emergency, :maintenance, :training, :marketing, :announcement]
      allow_nil? false
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :scheduled, :sending, :completed, :cancelled, :failed]
      default :draft
    end

    attribute :scheduled_at, :utc_datetime
    attribute :started_at, :utc_datetime
    attribute :completed_at, :utc_datetime

    attribute :target_audience, :atom do
      constraints one_of: [
                    :all_users,
                    :specific_groups,
                    :specific_users,
                    :role_based,
                    :location_based
                  ]

      allow_nil? false
    end

    attribute :target_group_ids, {:array, :uuid} do
      default []
    end

    attribute :target_user_ids, {:array, :uuid} do
      default []
    end

    attribute :channel_strategy, :map do
      default %{}
    end

    attribute :total_recipients, :integer do
      default 0
    end

    attribute :messages_sent, :integer do
      default 0
    end

    attribute :delivery_success_rate, :decimal do
      constraints min: 0, max: 100
    end

    timestamps()
  end

  relationships do
    belongs_to :created_by, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    has_many :messages, Indrajaal.Communication.Message do
      destination_attribute :campaign_id
    end
  end

  calculations do
    calculate :is_active, :boolean do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          record.status in [:scheduled, :sending]
        end)
      end
    end

    calculate :completion_percentage, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          if record.total_recipients > 0 do
            Decimal.div(
              Decimal.mult(record.messages_sent, 100),
              record.total_recipients
            )
          else
            Decimal.new(0)
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :create_campaign do
      argument :name, :string do
        allow_nil? false
      end

      argument :campaign_type, :atom do
        allow_nil? false
      end

      argument :target_audience, :atom do
        allow_nil? false
      end

      argument :created_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:name, arg(:name))
      change set_attribute(:campaign_type, arg(:campaign_type))
      change set_attribute(:target_audience, arg(:target_audience))
      change set_attribute(:created_by_id, arg(:created_by_id))
    end

    update :schedule_campaign do
      require_atomic? false

      argument :scheduled_at, :utc_datetime do
        allow_nil? false
      end

      change set_attribute(:status, :scheduled)
      change set_attribute(:scheduled_at, arg(:scheduled_at))
    end

    update :start_campaign do
      require_atomic? false
      change set_attribute(:status, :sending)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end

    update :complete_campaign do
      require_atomic? false
      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end

    update :cancel_campaign do
      require_atomic? false
      change set_attribute(:status, :cancelled)
    end

    update :update_progress do
      require_atomic? false

      argument :messages_sent, :integer do
        allow_nil? false
      end

      argument :success_rate, :decimal

      change set_attribute(:messages_sent, arg(:messages_sent))
      change set_attribute(:delivery_success_rate, arg(:success_rate))
    end
  end

  code_interface do
    define :create
    define :create_campaign
    define :schedule_campaign
    define :start_campaign
    define :complete_campaign
    define :cancel_campaign
    define :update_progress
  end

  postgres do
    table "broadcast_campaigns"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :status]
      index [:tenant_id, :campaign_type]
      index [:tenant_id, :scheduled_at]
      index [:tenant_id, :created_by_id]
      index [:tenant_id, :target_audience]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Communication
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
