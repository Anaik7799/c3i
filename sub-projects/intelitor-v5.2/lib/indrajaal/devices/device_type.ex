defmodule Indrajaal.Devices.DeviceType do
  @moduledoc """
  Represents different types of security devices in the system.

  DeviceTypes define the category, capabilities, and configuration
  templates for devices. This enables standardized device management
  across different manufacturers and models.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Devices

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255
    end

    attribute :code, :string do
      allow_nil? false
      public? true

      constraints max_length: 50,
                  match: ~S/^[A-Z][A-Z0-9_-]*$/
    end

    attribute :category, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:sensor, :camera, :panel, :reader, :controller, :output, :other]
    end

    attribute :manufacturer, :string do
      public? true
      constraints max_length: 255
    end

    attribute :model, :string do
      public? true
      constraints max_length: 255
    end

    attribute :capabilities, {:array, :string} do
      public? true
      default []
    end

    attribute :configuration_schema, :map do
      public? true
      default %{}
    end

    attribute :active?, :boolean do
      public? true
      default true
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Indrajaal.Core.Tenant do
      allow_nil? false
    end

    has_many :devices, Indrajaal.Devices.Device do
      public? true
    end
  end

  identities do
    identity :unique_code_per_tenant, [:tenant_id, :code]
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :name,
        :code,
        :category,
        :manufacturer,
        :model,
        :capabilities,
        :configuration_schema,
        :metadata,
        :tenant_id,
        :active?
      ]
    end

    update :activate do
      require_atomic? false
      accept []
      change set_attribute(:active?, true)
    end

    destroy :archive do
      require_atomic? false
      soft? true
      change set_attribute(:active?, false)
    end
  end

  calculations do
    calculate :is_active?, :boolean, expr(active?)

    calculate :device_count, :integer, expr(count(devices))
  end

  validations do
    validate string_length(:name, min: 3, max: 255)
    validate string_length(:code, min: 2, max: 50)

    validate match(:code, ~S/^[A-Z][A-Z0-9_-]*$/) do
      message "must start with uppercase letter and contain only uppercase letters, numbers, underscores, and hyphens"
    end

    validate fn changeset, __context ->
      category = Ash.Changeset.get_attribute(changeset, :category)
      capabilities = Ash.Changeset.get_attribute(changeset, :capabilities) || []

      _required_capabilities =
        case category do
          :sensor -> ["detection"]
          :camera -> ["video_capture"]
          :panel -> ["alarm_control"]
          :reader -> ["access_control"]
          _ -> []
        end

      missing = _required_capabilities -- capabilities

      if Enum.empty?(missing) do
        :ok
      else
        {:error,
         field: :capabilities,
         message: "must include #{Enum.join(missing, ", ")} for #{category} devices"}
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:tenant_id) == tenant_id)
    end

    policy action_type([:create, :update]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "device_manager")
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, "admin")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :activate
    define :get_by_code, action: :read, get_by: [:tenant_id, :code]
  end

  postgres do
    table "device_types"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :code], unique: true
      index [:category]
      index [:active?], name: "device_types_active_index", where: "active? = true"
      index [:manufacturer]
    end
  end
end

# Agent: Worker - 2 (Devices Domain Agent)
# SOPv5.1 Compliance: OK - Device management and hardware integration coordination
# Domain: Devices
# Responsibilities: Device management, hardware integration, IoT coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
