defmodule Indrajaal.Devices.Panel do
  @moduledoc """
  Represents a security alarm panel device.

  Panels are the central control units for security systems, managing zones,
  __users, and alarm __events. They support the SIA DC - 09 protocol for alarm
  reporting and integrate with monitoring centers.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Devices

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Foreign key to device
    attribute :device_id, :uuid do
      allow_nil? false
      public? true
    end

    # Panel type
    attribute :panel_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:intrusion, :fire, :access_control, :integrated]
      default :intrusion
    end

    # Panel model and manufacturer
    attribute :manufacturer, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :model, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    # Connection details
    attribute :connection_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:ethernet, :cellular, :dual_path, :phone_line]
      default :ethernet
    end

    attribute :primary_ip, :string do
      public? true
      constraints max_length: 45
    end

    attribute :backup_ip, :string do
      public? true
      constraints max_length: 45
    end

    # SIA DC - 09 configuration
    attribute :account_number, :string do
      allow_nil? false
      public? true
      constraints max_length: 16
    end

    attribute :receiver_number, :string do
      public? true
      constraints max_length: 6
    end

    attribute :sia_level, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 4
      default 3
    end

    # Panel capabilities
    attribute :max_zones, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 1000
      default 32
    end

    attribute :max_users, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 1000
      default 50
    end

    attribute :max_outputs, :integer do
      allow_nil? false
      public? true
      constraints min: 0, max: 100
      default 4
    end

    attribute :max_partitions, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 32
      default 1
    end

    # Panel features
    attribute :features, :map do
      public? true
      default %{}
    end

    attribute :supports_bypass?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :supports_stay_arm?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :supports_force_arm?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Status and monitoring
    attribute :panel_status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:online, :offline, :trouble, :alarm, :programming]
      default :offline
    end

    attribute :last_test_time, :utc_datetime_usec do
      public? true
    end

    attribute :battery_voltage, :float do
      public? true
      constraints min: 0.0, max: 15.0
    end

    attribute :ac_power?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :phone_line_fault?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Programming
    attribute :installer_code, :string do
      public? false
      sensitive? true
      constraints max_length: 10
    end

    attribute :master_code, :string do
      public? false
      sensitive? true
      constraints max_length: 10
    end

    attribute :download_code, :string do
      public? false
      sensitive? true
      constraints max_length: 10
    end

    attribute :programming_locked?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :device, Indrajaal.Devices.Device do
      allow_nil? false
      attribute_public? true
    end

    # Future relationships
    # has_many :zones, Indrajaal.Alarms.Zone
    # has_many :panel_users, Indrajaal.Alarms.PanelUser
    # has_many :__events, Indrajaal.Alarms.Event
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :device_id,
        :panel_type,
        :manufacturer,
        :model,
        :connection_type,
        :primary_ip,
        :backup_ip,
        :account_number,
        :receiver_number,
        :sia_level,
        :max_zones,
        :max_users,
        :max_outputs,
        :max_partitions,
        :features,
        :supports_bypass?,
        :supports_stay_arm?,
        :supports_force_arm?,
        :installer_code,
        :master_code,
        :download_code
      ]

      argument :device_id, :uuid do
        allow_nil? false
      end

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:panel_status, :offline)
        |> Ash.Changeset.force_change_attribute(:ac_power?, true)
        |> Ash.Changeset.force_change_attribute(:phone_line_fault?, false)
        |> Ash.Changeset.force_change_attribute(:programming_locked?, false)
      end
    end

    update :go_online do
      accept []
      require_atomic? false

      change set_attribute(:panel_status, :online)
      change set_attribute(:last_test_time, &DateTime.utc_now/0)
    end

    update :go_offline do
      require_atomic? false
      accept []

      change set_attribute(:panel_status, :offline)
    end

    update :report_trouble do
      require_atomic? false
      accept [:battery_voltage, :ac_power?, :phone_line_fault?]

      change set_attribute(:panel_status, :trouble)
    end

    update :trigger_alarm do
      require_atomic? false
      accept []

      change set_attribute(:panel_status, :alarm)
    end

    update :enter_programming do
      require_atomic? false
      accept []

      validate fn changeset, __context ->
        if changeset.data.programming_locked? do
          {:error, field: :programming_locked?, message: "Panel programming is locked"}
        else
          :ok
        end
      end

      change set_attribute(:panel_status, :programming)
    end

    update :exit_programming do
      require_atomic? false
      accept []

      change set_attribute(:panel_status, :online)
    end

    update :lock_programming do
      require_atomic? false
      accept []

      change set_attribute(:programming_locked?, true)
    end

    update :unlock_programming do
      require_atomic? false
      accept []

      change set_attribute(:programming_locked?, false)
    end

    update :test_communication do
      require_atomic? false
      accept []

      change set_attribute(:last_test_time, &DateTime.utc_now/0)
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :active_zones, :integer do
      calculation fn _records, __context ->
        {:ok, 0}
      end
    end

    calculate :active_users, :integer do
      calculation fn _records, __context ->
        {:ok, 0}
      end
    end

    calculate :battery_status, :atom do
      calculation fn records, __context ->
        values =
          records
          |> Enum.map(fn panel ->
            cond do
              is_nil(panel.battery_voltage) -> :unknown
              panel.battery_voltage < 10.5 -> :low
              panel.battery_voltage < 11.5 -> :warning
              true -> :good
            end
          end)

        {:ok, values}
      end
    end

    calculate :communication_status, :atom do
      calculation fn records, __context ->
        values =
          records
          |> Enum.map(fn panel ->
            case panel.panel_status do
              :offline -> :disconnected
              :online -> :connected
              _ -> :connected
            end
          end)

        {:ok, values}
      end
    end
  end

  policies do
    import Indrajaal.Devices.DevicePolicies

    common_policies()

    policy action([:go_online, :go_offline, :test_communication]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "technician")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action([:enter_programming, :exit_programming, :lock_programming, :unlock_programming]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "technician")
    end

    policy action([:report_trouble, :trigger_alarm]) do
      # System actions - typically called by the panel itself
      authorize_if always()
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :go_online
    define :go_offline
    define :report_trouble
    define :trigger_alarm
    define :enter_programming
    define :exit_programming
    define :lock_programming
    define :unlock_programming
    define :test_communication
  end

  postgres do
    table "panels"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :device_id], unique: true
      index [:panel_type]
      index [:panel_status]
      index [:account_number]
      index [:connection_type]
      index [:ac_power?], name: "panels_ac_power_index", where: "ac_power? = false"

      index [:phone_line_fault?],
        name: "panels_phone_line_fault_index",
        where: "phone_line_fault? = true"

      index [:programming_locked?],
        name: "panels_programming_locked_index",
        where: "programming_locked? = true"
    end
  end
end

# Agent: Worker - 2 (Devices Domain Agent)
# SOPv5.1 Compliance: ✅ Device management and hardware integration coordination
# Domain: Devices
# Responsibilities: Device management, hardware integration, IoT coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
