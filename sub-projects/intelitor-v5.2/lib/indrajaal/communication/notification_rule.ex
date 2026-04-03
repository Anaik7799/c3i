defmodule Indrajaal.Communication.NotificationRule do
  @moduledoc """
  Rules for automatic notification triggering based on __events.
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

    attribute :__event_type, :atom do
      constraints one_of: [
                    :alarm,
                    :access_denied,
                    :system_failure,
                    :guard_tour_exception,
                    :maintenance_due,
                    :custom
                  ]

      allow_nil? false
    end

    attribute :conditions, :map do
      default %{}
    end

    attribute :is_enabled, :boolean do
      default true
    end

    attribute :priority, :atom do
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    attribute :throttle_minutes, :integer do
      default 0
      constraints min: 0, max: 1440
    end

    attribute :escalation_enabled, :boolean do
      default false
    end

    attribute :escalation_minutes, :integer do
      default 15
      constraints min: 1, max: 1440
    end

    attribute :recipient_groups, {:array, :uuid} do
      default []
    end

    attribute :recipient_users, {:array, :uuid} do
      default []
    end

    timestamps()
  end

  relationships do
    belongs_to :channel, Indrajaal.Communication.NotificationChannel do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :template, Indrajaal.Communication.MessageTemplate do
      attribute_writable? true
    end

    belongs_to :created_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    has_many :delivery_logs, Indrajaal.Communication.DeliveryLog do
      destination_attribute :rule_id
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :create_rule do
      argument :name, :string do
        allow_nil? false
      end

      argument :__event_type, :atom do
        allow_nil? false
      end

      argument :channel_id, :uuid do
        allow_nil? false
      end

      argument :created_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:name, arg(:name))
      change set_attribute(:__event_type, arg(:__event_type))
      change set_attribute(:channel_id, arg(:channel_id))
      change set_attribute(:created_by_id, arg(:created_by_id))
    end

    update :enable do
      require_atomic? false
      change set_attribute(:is_enabled, true)
    end

    update :disable do
      require_atomic? false
      change set_attribute(:is_enabled, false)
    end

    update :add_recipients do
      require_atomic? false
      argument :user_ids, {:array, :uuid}
      argument :group_ids, {:array, :uuid}

      change fn changeset, _ ->
        current_users = changeset.data.recipient_users || []
        current_groups = changeset.data.recipient_groups || []

        new_users =
          case Ash.Changeset.get_argument(changeset, :user_ids) do
            nil -> current_users
            user_ids -> Enum.uniq(current_users ++ user_ids)
          end

        new_groups =
          case Ash.Changeset.get_argument(changeset, :group_ids) do
            nil -> current_groups
            group_ids -> Enum.uniq(current_groups ++ group_ids)
          end

        changeset
        |> Ash.Changeset.change_attribute(:recipient_users, new_users)
        |> Ash.Changeset.change_attribute(:recipient_groups, new_groups)
      end
    end
  end

  code_interface do
    define :create
    define :create_rule
    define :enable
    define :disable
    define :add_recipients
  end

  postgres do
    table "notification_rules"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :__event_type]
      index [:tenant_id, :is_enabled]
      index [:tenant_id, :priority]
      index [:tenant_id, :channel_id]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Communication
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
