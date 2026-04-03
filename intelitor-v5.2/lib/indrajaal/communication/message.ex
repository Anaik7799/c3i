defmodule Indrajaal.Communication.Message do
  @moduledoc """
  Communication Message resource with enterprise messaging capabilities.

  Implements multi-tenant messaging system with comprehensive audit trails.
  Supports broadcast campaigns, direct messages, and notification channels.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.CommunicationDomain

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 255
    end

    attribute :description, :string do
      constraints max_length: 1000
    end

    attribute :active, :boolean do
      default true
    end

    attribute :metadata, :map do
      default %{}
    end

    # Domain-specific communication fields
    attribute :type, :atom do
      constraints one_of: [:email, :sms, :push, :in_app, :webhook]
      allow_nil? false
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :scheduled, :sent, :delivered, :failed, :cancelled]
      default :draft
    end

    attribute :configuration, :map do
      default %{}
    end

    attribute :tags, {:array, :string} do
      default []
    end

    attribute :subject, :string do
      constraints max_length: 200
    end

    attribute :body, :string
    attribute :recipients, {:array, :string}
    attribute :sender, :string
    attribute :scheduled_at, :utc_datetime
    attribute :sent_at, :utc_datetime
    attribute :delivered_at, :utc_datetime

    # Foreign key attributes for relationships
    attribute :campaign_id, :uuid
    attribute :template_id, :uuid
    attribute :channel_id, :uuid

    attribute :created_by_id, :uuid do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :campaign, Indrajaal.Communication.BroadcastCampaign do
      attribute_writable? false
      source_attribute :campaign_id
      destination_attribute :id
    end

    belongs_to :template, Indrajaal.Communication.MessageTemplate do
      attribute_writable? false
      source_attribute :template_id
      destination_attribute :id
    end

    belongs_to :channel, Indrajaal.Communication.NotificationChannel do
      attribute_writable? false
      source_attribute :channel_id
      destination_attribute :id
    end

    belongs_to :created_by, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? false
      source_attribute :created_by_id
      destination_attribute :id
    end
  end

  actions do
    defaults [:read, :destroy]

    default_accept [
      :name,
      :description,
      :active,
      :metadata,
      :type,
      :status,
      :configuration,
      :tags,
      :subject,
      :body,
      :recipients,
      :sender,
      :scheduled_at,
      :campaign_id,
      :template_id,
      :channel_id,
      :created_by_id
    ]

    create :create do
      accept [
        :name,
        :description,
        :active,
        :metadata,
        :type,
        :status,
        :configuration,
        :tags,
        :subject,
        :body,
        :recipients,
        :sender,
        :scheduled_at,
        :campaign_id,
        :template_id,
        :channel_id,
        :created_by_id
      ]
    end

    update :update do
      require_atomic? false

      accept [
        :name,
        :description,
        :active,
        :metadata,
        :status,
        :configuration,
        :tags,
        :subject,
        :body,
        :recipients,
        :scheduled_at,
        :campaign_id,
        :template_id,
        :channel_id
      ]
    end

    update :send_message do
      require_atomic? false

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.change_attribute(:status, :sent)
        |> Ash.Changeset.change_attribute(:sent_at, DateTime.utc_now())
      end
    end

    update :mark_delivered do
      require_atomic? false

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.change_attribute(:status, :delivered)
        |> Ash.Changeset.change_attribute(:delivered_at, DateTime.utc_now())
      end
    end
  end

  validations do
    validate present([:name, :type]), message: "Name and type are __required"
    validate string_length(:name, min: 1, max: 255), message: "Name must be 1-255 characters"

    validate string_length(:description, max: 1000),
      message: "Description cannot exceed 1000 characters"

    validate string_length(:subject, max: 200), message: "Subject cannot exceed 200 characters"
  end

  preparations do
    prepare build(load: [:created_by, :campaign])
  end

  code_interface do
    define :create, action: :create
    define :update, action: :update
    define :destroy, action: :destroy
    define :read, action: :read
    define :send_message, action: :send_message
    define :mark_delivered, action: :mark_delivered
  end

  postgres do
    table "communication_messages"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :type]
      index [:tenant_id, :status]
      index [:tenant_id, :campaign_id]
      index [:tenant_id, :template_id]
      index [:tenant_id, :channel_id]
      index [:tenant_id, :created_by_id]
      index [:tenant_id, :scheduled_at]
      index [:tenant_id, :sent_at]
    end
  end

  # Traditional Ecto changeset for compatibility with existing context code
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(message, attrs) do
    message
    |> Ecto.Changeset.cast(attrs, [
      :name,
      :description,
      :active,
      :metadata,
      :type,
      :status,
      :configuration,
      :tags,
      :subject,
      :body,
      :recipients,
      :sender,
      :scheduled_at,
      :sent_at,
      :delivered_at,
      :campaign_id,
      :template_id,
      :channel_id,
      :created_by_id
    ])
    |> Ecto.Changeset.validate_required([:name, :type, :created_by_id])
    |> Ecto.Changeset.validate_length(:name, min: 1, max: 255)
    |> Ecto.Changeset.validate_length(:description, max: 1000)
    |> Ecto.Changeset.validate_length(:subject, max: 200)
    |> Ecto.Changeset.validate_inclusion(:type, [:email, :sms, :push, :in_app, :webhook])
    |> Ecto.Changeset.validate_inclusion(:status, [
      :draft,
      :scheduled,
      :sent,
      :delivered,
      :failed,
      :cancelled
    ])
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Communication
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
