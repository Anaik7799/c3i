defmodule Indrajaal.Communication.DeliveryLog do
  @moduledoc """
  Delivery tracking and audit logs for all sent messages.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.CommunicationDomain

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :recipient_address, :string do
      allow_nil? false
      constraints max_length: 255
    end

    attribute :delivery_status, :atom do
      constraints one_of: [:pending, :delivered, :failed, :bounced, :rejected, :read]
      default :pending
    end

    attribute :attempted_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :delivered_at, :utc_datetime
    attribute :read_at, :utc_datetime

    attribute :retry_count, :integer do
      default 0
      constraints min: 0
    end

    attribute :failure_reason, :string do
      constraints max_length: 500
    end

    attribute :provider_message_id, :string do
      constraints max_length: 255
    end

    attribute :provider_response, :map do
      default %{}
    end

    attribute :delivery_metadata, :map do
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :message, Indrajaal.Communication.Message do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :channel, Indrajaal.Communication.NotificationChannel do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :rule, Indrajaal.Communication.NotificationRule do
      attribute_writable? true
    end

    belongs_to :recipient_user, Indrajaal.Accounts.User do
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :log_attempt do
      argument :message_id, :uuid do
        allow_nil? false
      end

      argument :channel_id, :uuid do
        allow_nil? false
      end

      argument :recipient_address, :string do
        allow_nil? false
      end

      change set_attribute(:message_id, arg(:message_id))
      change set_attribute(:channel_id, arg(:channel_id))
      change set_attribute(:recipient_address, arg(:recipient_address))
    end

    update :mark_delivered do
      require_atomic? false
      argument :provider_message_id, :string

      change set_attribute(:delivery_status, :delivered)
      change set_attribute(:delivered_at, &DateTime.utc_now/0)
      change set_attribute(:provider_message_id, arg(:provider_message_id))
    end

    update :mark_failed do
      require_atomic? false

      argument :failure_reason, :string do
        allow_nil? false
      end

      change set_attribute(:delivery_status, :failed)
      change set_attribute(:failure_reason, arg(:failure_reason))

      change fn changeset, _ ->
        current_retry = changeset.data.retry_count || 0
        Ash.Changeset.change_attribute(changeset, :retry_count, current_retry + 1)
      end
    end

    update :mark_read do
      require_atomic? false
      change set_attribute(:delivery_status, :read)
      change set_attribute(:read_at, &DateTime.utc_now/0)
    end
  end

  code_interface do
    define :create
    define :log_attempt
    define :mark_delivered
    define :mark_failed
    define :mark_read
  end

  postgres do
    table "delivery_logs"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :message_id]
      index [:tenant_id, :channel_id]
      index [:tenant_id, :delivery_status]
      index [:tenant_id, :attempted_at]
      index [:tenant_id, :recipient_user_id]
      index [:tenant_id, :provider_message_id]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Communication
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
