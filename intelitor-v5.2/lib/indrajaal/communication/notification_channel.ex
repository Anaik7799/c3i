defmodule Indrajaal.Communication.NotificationChannel do
  @moduledoc """
  Available notification channels and their configuration.
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

    attribute :channel_type, :atom do
      constraints one_of: [:email, :sms, :push, :in_app, :webhook, :slack, :teams]
      allow_nil? false
    end

    attribute :is_enabled, :boolean do
      default true
    end

    attribute :configuration, :map do
      default %{}
    end

    attribute :rate_limit_per_minute, :integer do
      default 100
      constraints min: 1, max: 10_000
    end

    attribute :retry_attempts, :integer do
      default 3
      constraints min: 0, max: 10
    end

    attribute :priority_order, :integer do
      default 1
      constraints min: 1
    end

    attribute :escalation_delay_minutes, :integer do
      default 5
      constraints min: 0, max: 1440
    end

    timestamps()
  end

  relationships do
    has_many :messages, Indrajaal.Communication.Message do
      destination_attribute :channel_id
    end

    has_many :delivery_logs, Indrajaal.Communication.DeliveryLog do
      destination_attribute :channel_id
    end

    has_many :notification_rules, Indrajaal.Communication.NotificationRule do
      destination_attribute :channel_id
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    update :enable do
      require_atomic? false
      change set_attribute(:is_enabled, true)
    end

    update :disable do
      require_atomic? false
      change set_attribute(:is_enabled, false)
    end

    update :update_config do
      require_atomic? false

      argument :config_data, :map do
        allow_nil? false
      end

      change set_attribute(:configuration, arg(:config_data))
    end
  end

  code_interface do
    define :create
    define :enable
    define :disable
    define :update_config
  end

  postgres do
    table "notification_channels"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :channel_type]
      index [:tenant_id, :is_enabled]
      index [:tenant_id, :priority_order]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Communication
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
