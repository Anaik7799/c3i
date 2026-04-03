defmodule Indrajaal.Alarms.IncidentType do
  @moduledoc """
  Defines types of security incidents and their response protocols.

  IncidentTypes provide a categorization system for alarm __events, defining
  severity levels, response procedures, and notification __requirements for
  different types of security incidents.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Alarms

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Type identification
    attribute :code, :string do
      allow_nil? false
      public? true
      constraints max_length: 20
    end

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :description, :string do
      public? true
      constraints max_length: 500
    end

    attribute :category, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :intrusion,
                    :fire,
                    :medical,
                    :environmental,
                    :panic,
                    :technical,
                    :system,
                    :access_control
                  ]
    end

    # Severity and priority
    attribute :default_severity, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
      default :high
    end

    attribute :default_priority, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 10
      default 5
    end

    attribute :escalation_minutes, :integer do
      public? true
      constraints min: 1, max: 1440
      default 15
    end

    # Response configuration
    attribute :auto_dispatch?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :__requires_verification?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :police_response?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :fire_response?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :medical_response?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Notification settings
    attribute :notify_customer?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :notify_contacts?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :notification_delay_seconds, :integer do
      public? true
      constraints min: 0, max: 3600
      default 0
    end

    # Instructions and procedures
    attribute :operator_instructions, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :dispatch_instructions, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :customer_message_template, :string do
      public? true
      constraints max_length: 1000
    end

    # SIA codes mapping
    attribute :sia_codes, {:array, :string} do
      public? true
      default []
    end

    # Configuration
    attribute :settings, :map do
      public? true
      default %{}
    end

    attribute :active?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :system_type?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    timestamps()
  end

  relationships do
    has_many :alarm_events, Indrajaal.Alarms.AlarmEvent
    has_many :workflow_templates, Indrajaal.Alarms.WorkflowTemplate
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    update :activate do
      require_atomic? false

      accept []

      validate attribute_equals(:active?, false)

      change set_attribute(:active?, true)
    end

    update :deactivate do
      require_atomic? false

      accept []

      validate attribute_equals(:active?, true)

      change set_attribute(:active?, false)
    end

    update :update_response_config do
      require_atomic? false

      accept [
        :auto_dispatch?,
        :__requires_verification?,
        :police_response?,
        :fire_response?,
        :medical_response?,
        :escalation_minutes
      ]
    end

    update :update_notification_config do
      require_atomic? false

      accept [
        :notify_customer?,
        :notify_contacts?,
        :notification_delay_seconds,
        :customer_message_template
      ]
    end

    update :update_instructions do
      accept [:operator_instructions, :dispatch_instructions]
      require_atomic? false
    end

    update :add_sia_code do
      accept []
      require_atomic? false

      argument :sia_code, :string do
        allow_nil? false
        constraints max_length: 10
      end

      change fn changeset, __context ->
        current_codes = Ash.Changeset.get_attribute(changeset, :sia_codes) || []
        new_code = changeset.arguments.sia_code

        if new_code in current_codes do
          changeset
        else
          Ash.Changeset.force_change_attribute(changeset, :sia_codes, [new_code | current_codes])
        end
      end
    end

    update :remove_sia_code do
      require_atomic? false
      accept []

      argument :sia_code, :string do
        allow_nil? false
      end

      change fn changeset, __context ->
        current_codes = Ash.Changeset.get_attribute(changeset, :sia_codes) || []
        code_to_remove = changeset.arguments.sia_code

        updated_codes = current_codes |> Enum.reject(&(&1 == code_to_remove))
        Ash.Changeset.force_change_attribute(changeset, :sia_codes, updated_codes)
      end
    end
  end

  calculations do
    calculate :response_authorities, {:array, :atom} do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn incident_type ->
            authorities = []

            authorities =
              if incident_type.police_response?, do: [:police | authorities], else: authorities

            authorities =
              if incident_type.fire_response?, do: [:fire | authorities], else: authorities

            if incident_type.medical_response?, do: [:medical | authorities], else: authorities
          end)

        {:ok, values}
      end
    end

    calculate :__requires_immediate_response?, :boolean do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn incident_type ->
            incident_type.default_severity in [:high, :critical] ||
              incident_type.auto_dispatch? ||
              incident_type.category in [:fire, :medical, :panic]
          end)

        {:ok, values}
      end
    end
  end

  policies do
    bypass always() do
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "technician")
      authorize_if actor_attribute_equals(:role, "viewer")
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action([:activate, :deactivate]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :activate
    define :deactivate
    define :update_response_config
    define :update_notification_config
    define :update_instructions
    define :add_sia_code
    define :remove_sia_code
  end

  postgres do
    table "incident_types"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :code], unique: true
      index [:category]
      index [:active?], name: "incident_types_active_index", where: "active? = true"
      index [:default_severity]

      index [:auto_dispatch?],
        name: "incident_types_auto_dispatch_index",
        where: "auto_dispatch? = true"

      index [:system_type?], name: "incident_types_system_index", where: "system_type? = true"
    end
  end
end

# Agent: Worker - 1 (Alarms Domain Agent)
# SOPv5.1 Compliance: ✅ Critical alarm processing and incident response coordin
# Domain: Alarms
# Responsibilities: Alarm processing, incident response, critical system monito
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
