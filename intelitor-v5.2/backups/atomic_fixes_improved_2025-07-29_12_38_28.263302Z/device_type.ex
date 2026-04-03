defmodule Intelitor.Devices.DeviceType do
  @moduledoc """
  Represents different types of security devices in the system.

  DeviceTypes define the category, capabilities, and configuration
  templates for devices. This enables standardized device management
  across different manufacturers and models.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Devices,
    table: "device_types"

  use Intelitor.Multitenancy.TenantResource

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

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :capabilities, {:array, :string} do
      public? true
      default []
    end

    attribute :configuration_schema, :map do
      public? true
      default %{}
    end

    attribute :default_configuration, :map do
      public? true
      default %{}
    end

    attribute :communication_protocols, {:array, :atom} do
      public? true
      default []

      constraints items: [
                    one_of: [:tcp, :udp, :mqtt, :websocket, :http, :serial, :zigbee, :zwave]
                  ]
    end

    attribute :power_requirements, :map do
      public? true
      default %{}
    end

    attribute :environmental_specs, :map do
      public? true
      default %{}
    end

    attribute :certifications, {:array, :string} do
      public? true
      default []
    end

    attribute :firmware_versions, {:array, :map} do
      public? true
      default []
    end

    attribute :is_deprecated?, :boolean do
      public? true
      default false
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
    belongs_to :tenant, Intelitor.Core.Tenant do
      allow_nil? false
    end

    has_many :devices, Intelitor.Devices.Device do
      public? true
    end
  end

  identities do
    identity :unique_code_per_tenant, [:tenant_id, :code]
  end

  actions do
    defaults [:read, :create, :update]
    update :deprecate do
      require_atomic? false
      accept []
      change set_attribute(:is_deprecated?, true)
      change set_attribute(:active?, false)
    end

    update :activate do
      require_atomic? false
      accept []
      change set_attribute(:active?, true)
    end

    update :update_firmware do
      require_atomic? false
      argument :version, :string do
        allow_nil? false
        constraints max_length: 50
      end

      argument :release_date, :date do
        allow_nil? false
      end

      argument :release_notes, :string do
        constraints max_length: 2000
      end

      argument :download_url, :string do
        constraints max_length: 500
      end

      change fn changeset, _context ->
        versions = Ash.Changeset.get_attribute(changeset, :firmware_versions) || []

        new_version = %{
          "version" => Ash.Changeset.get_argument(changeset, :version),
          "release_date" => Ash.Changeset.get_argument(changeset, :release_date),
          "release_notes" => Ash.Changeset.get_argument(changeset, :release_notes),
          "download_url" => Ash.Changeset.get_argument(changeset, :download_url),
          "added_at" => DateTime.utc_now()
        }

        Ash.Changeset.change_attribute(changeset, :firmware_versions, [new_version | versions])
      end
    end

    destroy :archive do
      require_atomic? false
      soft? true
      change set_attribute(:active?, false)
    end
  end

  calculations do
    calculate :is_active?, :boolean, expr(active? and not is_deprecated?)

    calculate :device_count, :integer, expr(count(devices))

    calculate :latest_firmware_version, :string do
      calculation fn records, _opts ->
        Enum.map(records, fn type ->
          versions = type.firmware_versions || []

          case versions do
            [%{"version" => version} | _] -> version
            _ -> nil
          end
        end)
      end
    end

    calculate :supports_protocol?, :boolean do
      argument :protocol, :atom do
        allow_nil? false
        constraints one_of: [:tcp, :udp, :mqtt, :websocket, :http, :serial, :zigbee, :zwave]
      end

      calculation fn records, %{protocol: protocol} ->
        Enum.map(records, fn type ->
          protocol in (type.communication_protocols || [])
        end)
      end
    end
  end

  validations do
    validate string_length(:name, min: 3, max: 255)
    validate string_length(:code, min: 2, max: 50)

    validate match(:code, ~S/^[A-Z][A-Z0-9_-]*$/) do
      message "must start with uppercase letter and contain only uppercase letters, numbers, underscores, and hyphens"
    end

    validate fn changeset, _context ->
      category = Ash.Changeset.get_attribute(changeset, :category)
      capabilities = Ash.Changeset.get_attribute(changeset, :capabilities) || []

      required_capabilities =
        case category do
          :sensor -> ["detection"]
          :camera -> ["video_capture"]
          :panel -> ["alarm_control"]
          :reader -> ["access_control"]
          _ -> []
        end

      missing = required_capabilities -- capabilities

      if Enum.empty?(missing) do
        {:ok, changeset}
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
    define :deprecate
    define :activate
    define :update_firmware
    define :get_by_code, action: :read, get_by: [:tenant_id, :code]
  end

  postgres do
    table "device_types"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :code], unique: true
      index [:category]
      index [:active?], name: "device_types_active_index", where: "active? = true"
      index [:manufacturer]
    end
  end
end
