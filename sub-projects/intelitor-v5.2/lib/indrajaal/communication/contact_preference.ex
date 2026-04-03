defmodule Indrajaal.Communication.ContactPreference do
  @moduledoc """
  Individual user communication preferences and channel settings.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.CommunicationDomain

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :notification_type, :atom do
      constraints one_of: [:all, :critical_only, :alerts, :reports, :none]
      default :all
    end

    attribute :preferred_channels, {:array, :atom} do
      default [:email, :in_app]
    end

    attribute :quiet_hours_start, :time
    attribute :quiet_hours_end, :time

    attribute :timezone, :string do
      default "UTC"
      constraints max_length: 50
    end

    attribute :email_f_requency, :atom do
      constraints one_of: [:immediate, :hourly, :daily, :weekly, :none]
      default :immediate
    end

    attribute :sms_enabled, :boolean do
      default false
    end

    attribute :push_enabled, :boolean do
      default true
    end

    attribute :in_app_enabled, :boolean do
      default true
    end

    attribute :emergency_contact_methods, {:array, :atom} do
      default [:sms, :email, :push]
    end

    attribute :language_preference, :string do
      default "en"
      constraints max_length: 5
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :group, Indrajaal.Communication.ContactGroup do
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :set_preferences do
      argument :user_id, :uuid do
        allow_nil? false
      end

      argument :notification_type, :atom do
        allow_nil? false
      end

      argument :preferred_channels, {:array, :atom} do
        allow_nil? false
      end

      change set_attribute(:user_id, arg(:user_id))
      change set_attribute(:notification_type, arg(:notification_type))
      change set_attribute(:preferred_channels, arg(:preferred_channels))
    end

    update :update_channels do
      require_atomic? false

      argument :channels, {:array, :atom} do
        allow_nil? false
      end

      change set_attribute(:preferred_channels, arg(:channels))
    end

    update :set_quiet_hours do
      require_atomic? false

      argument :start_time, :time do
        allow_nil? false
      end

      argument :end_time, :time do
        allow_nil? false
      end

      change set_attribute(:quiet_hours_start, arg(:start_time))
      change set_attribute(:quiet_hours_end, arg(:end_time))
    end

    update :enable_emergency_notifications do
      require_atomic? false
      change set_attribute(:notification_type, :all)
      change set_attribute(:sms_enabled, true)
      change set_attribute(:push_enabled, true)
    end

    update :disable_notifications do
      require_atomic? false
      change set_attribute(:notification_type, :none)
      change set_attribute(:sms_enabled, false)
      change set_attribute(:push_enabled, false)
    end
  end

  validations do
    validate compare(:quiet_hours_end, greater_than: :quiet_hours_start),
      message: "Quiet hours end must be after start"
  end

  code_interface do
    define :create
    define :set_preferences
    define :update_channels
    define :set_quiet_hours
    define :enable_emergency_notifications
    define :disable_notifications
  end

  postgres do
    table "contact_preferences"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :user_id]
      index [:tenant_id, :group_id]
      index [:tenant_id, :notification_type]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Communication
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
