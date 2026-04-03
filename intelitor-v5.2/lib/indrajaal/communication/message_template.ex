defmodule Indrajaal.Communication.MessageTemplate do
  @moduledoc """
  Reusable message templates with variable substitution.
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
      constraints max_length: 500
    end

    attribute :template_type, :atom do
      constraints one_of: [:alert, :notification, :report, :marketing, :system]
      allow_nil? false
    end

    attribute :subject_template, :string do
      constraints max_length: 200
    end

    attribute :body_template, :string do
      allow_nil? false
      constraints max_length: 10_000
    end

    attribute :variables, {:array, :string} do
      default []
    end

    attribute :supported_channels, {:array, :atom} do
      default [:email, :sms, :push, :in_app]
    end

    attribute :is_active, :boolean do
      default true
    end

    attribute :language, :string do
      default "en"
      constraints max_length: 5
    end

    attribute :category, :string do
      constraints max_length: 50
    end

    timestamps()
  end

  relationships do
    has_many :messages, Indrajaal.Communication.Message do
      destination_attribute :template_id
    end

    belongs_to :created_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :create_template do
      argument :name, :string do
        allow_nil? false
      end

      argument :template_type, :atom do
        allow_nil? false
      end

      argument :body_template, :string do
        allow_nil? false
      end

      argument :created_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:name, arg(:name))
      change set_attribute(:template_type, arg(:template_type))
      change set_attribute(:body_template, arg(:body_template))
      change set_attribute(:created_by_id, arg(:created_by_id))
    end

    update :activate do
      require_atomic? false
      change set_attribute(:is_active, true)
    end

    update :deactivate do
      require_atomic? false
      change set_attribute(:is_active, false)
    end
  end

  code_interface do
    define :create
    define :create_template
    define :activate
    define :deactivate
  end

  postgres do
    table "message_templates"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :template_type]
      index [:tenant_id, :is_active]
      index [:tenant_id, :category]
      index [:tenant_id, :language]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Communication
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
