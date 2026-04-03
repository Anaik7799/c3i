defmodule Intelitor.Devices.Sensor do
  @moduledoc """
  Represents security sensors such as motion detectors, door contacts, glass break sensors, etc.

  Sensors are the primary detection devices in the security system, generating
  events when triggered based on their specific detection capabilities.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Devices,
    table: "sensors"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :sensor_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :motion,
                    :door_contact,
                    :window_contact,
                    :glass_break,
                    :vibration,
                    :smoke,
                    :heat,
                    :gas,
                    :water_leak,
                    :temperature,
                    :humidity,
                    :panic_button,
                    :duress,
                    :beam,
                    :fence,
                    :seismic,
                    :other
                  ]
    end

    attribute :detection_method, :atom do
      public? true

      constraints one_of: [
                    :pir,
                    :microwave,
                    :dual_tech,
                    :magnetic,
                    :acoustic,
                    :optical,
                    :thermal,
                    :chemical
                  ]

      default :pir
    end

    attribute :sensitivity, :integer do
      public? true
      default 50
      constraints min: 0, max: 100
    end

    attribute :detection_range_m, :float do
      public? true
      constraints min: 0.0
    end

    attribute :detection_angle_deg, :integer do
      public? true
      constraints min: 0, max: 360
    end

    attribute :mounting_height_m, :float do
      public? true
      constraints min: 0.0
    end

    attribute :current_state, :atom do
      public? true
      constraints one_of: [:normal, :triggered, :tampered, :fault, :bypass]
      default :normal
    end

    attribute :armed?, :boolean do
      public? true
      default false
    end

    attribute :bypass?, :boolean do
      public? true
      default false
    end

    attribute :tamper?, :boolean do
      public? true
      default false
    end

    attribute :low_battery?, :boolean do
      public? true
      default false
    end

    attribute :supervised?, :boolean do
      public? true
      default true
    end

    attribute :response_time_ms, :integer do
      public? true
      default 500
      constraints min: 0
    end

    attribute :debounce_time_ms, :integer do
      public? true
      default 1000
      constraints min: 0
    end

    attribute :alarm_delay_sec, :integer do
      public? true
      default 0
      constraints min: 0
    end

    attribute :zone_number, :integer do
      public? true
      constraints min: 1
    end

    attribute :zone_type, :atom do
      public? true

      constraints one_of: [
                    :instant,
                    :delay,
                    :follower,
                    :"24_hour",
                    :fire,
                    :medical,
                    :panic,
                    :duress
                  ]

      default :instant
    end

    attribute :chime_enabled?, :boolean do
      public? true
      default true
    end

    attribute :led_enabled?, :boolean do
      public? true
      default true
    end

    attribute :pet_immune?, :boolean do
      public? true
      default false
    end

    attribute :environmental_compensation?, :boolean do
      public? true
      default false
    end

    attribute :last_triggered_at, :utc_datetime do
      public? true
    end

    attribute :trigger_count, :integer do
      public? true
      default 0
      constraints min: 0
    end

    attribute :false_alarm_count, :integer do
      public? true
      default 0
      constraints min: 0
    end

    attribute :calibration_data, :map do
      public? true
      default %{}
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

    belongs_to :device, Intelitor.Devices.Device do
      allow_nil? false
      public? true
    end

    # TODO: Uncomment when Alarms domain is implemented
    # belongs_to :alarm_zone, Intelitor.Alarms.Zone do
    #   public? true
    # end
  end

  identities do
    identity :unique_device_per_tenant, [:tenant_id, :device_id]
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :sensor_type,
        :detection_method,
        :sensitivity,
        :detection_range_m,
        :detection_angle_deg,
        :mounting_height_m,
        :device_id,
        :zone_number,
        :zone_type,
        :supervised?,
        :response_time_ms,
        :debounce_time_ms,
        :alarm_delay_sec,
        :chime_enabled?,
        :led_enabled?,
        :pet_immune?,
        :environmental_compensation?
      ]
    end


    update :trigger do
      require_atomic? false
      accept []
      change set_attribute(:current_state, :triggered)
      change set_attribute(:last_triggered_at, DateTime.utc_now())

      change fn changeset, _context ->
        count = Ash.Changeset.get_attribute(changeset, :trigger_count) || 0
        Ash.Changeset.change_attribute(changeset, :trigger_count, count + 1)
      end
    end

    update :reset do
      require_atomic? false
      accept []
      change set_attribute(:current_state, :normal)
      change set_attribute(:tamper?, false)
    end

    update :arm do
      require_atomic? false
      accept []
      change set_attribute(:armed?, true)
      change set_attribute(:bypass?, false)
    end

    update :disarm do
      require_atomic? false
      accept []
      change set_attribute(:armed?, false)
    end

    update :bypass do
      require_atomic? false
      
      argument :reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      change set_attribute(:bypass?, true)

      change fn changeset, context ->
        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        bypass_log = Map.get(metadata, "bypass_log", [])

        entry = %{
          "reason" => Ash.Changeset.get_argument(changeset, :reason),
          "bypassed_at" => DateTime.utc_now(),
          "bypassed_by" => context[:actor][:id]
        }

        updated_metadata = Map.put(metadata, "bypass_log", [entry | bypass_log])
        Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
      end
    end

    update :clear_bypass do
      require_atomic? false
      accept []
      change set_attribute(:bypass?, false)
    end

    update :report_tamper do
      require_atomic? false
      accept []
      change set_attribute(:tamper?, true)
      change set_attribute(:current_state, :tampered)
    end

    update :report_battery_status do
      require_atomic? false
      argument :low_battery, :boolean do
        allow_nil? false
      end

      change set_attribute(:low_battery?, arg(:low_battery))
    end

    update :calibrate do
      require_atomic? false
      argument :calibration_data, :map do
        allow_nil? false
      end

      change set_attribute(:calibration_data, arg(:calibration_data))

      change fn changeset, _context ->
        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        calibration_history = Map.get(metadata, "calibration_history", [])

        entry = %{
          "data" => Ash.Changeset.get_argument(changeset, :calibration_data),
          "calibrated_at" => DateTime.utc_now()
        }

        updated_metadata = Map.put(metadata, "calibration_history", [entry | calibration_history])
        Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
      end
    end

    update :mark_false_alarm do
      require_atomic? false
      accept []

      change fn changeset, _context ->
        count = Ash.Changeset.get_attribute(changeset, :false_alarm_count) || 0
        Ash.Changeset.change_attribute(changeset, :false_alarm_count, count + 1)
      end
    end
  end

  calculations do
    calculate :is_active?,
              :boolean,
              expr(not bypass? and not tamper? and current_state == :normal)

    calculate :requires_service?,
              :boolean,
              expr(tamper? or low_battery? or current_state == :fault)

    calculate :false_alarm_rate, :float do
      calculation fn records, _opts ->
        Enum.map(records, fn sensor ->
          if sensor.trigger_count && sensor.trigger_count > 0 do
            Float.round(sensor.false_alarm_count / sensor.trigger_count * 100, 2)
          else
            0.0
          end
        end)
      end
    end

    calculate :days_since_trigger, :integer do
      calculation fn records, _opts ->
        Enum.map(records, fn sensor ->
          case sensor.last_triggered_at do
            nil ->
              nil

            datetime ->
              DateTime.diff(DateTime.utc_now(), datetime, :day)
          end
        end)
      end
    end
  end

  validations do
    validate fn changeset, _context ->
      sensor_type = Ash.Changeset.get_attribute(changeset, :sensor_type)
      detection_method = Ash.Changeset.get_attribute(changeset, :detection_method)

      valid_methods =
        case sensor_type do
          :motion -> [:pir, :microwave, :dual_tech]
          type when type in [:door_contact, :window_contact] -> [:magnetic]
          :glass_break -> [:acoustic]
          :smoke -> [:optical, :thermal]
          _ -> nil
        end

      if valid_methods && detection_method not in valid_methods do
        {:error,
         field: :detection_method,
         message: "#{detection_method} is not valid for #{sensor_type} sensors"}
      else
        {:ok, changeset}
      end
    end

    validate fn changeset, _context ->
      zone_type = Ash.Changeset.get_attribute(changeset, :zone_type)
      alarm_delay = Ash.Changeset.get_attribute(changeset, :alarm_delay_sec)

      if zone_type == :instant && alarm_delay && alarm_delay > 0 do
        {:error, field: :alarm_delay_sec, message: "instant zones cannot have alarm delay"}
      else
        {:ok, changeset}
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
      authorize_if actor_attribute_equals(:role, "technician")
    end

    policy action([:arm, :disarm, :bypass, :clear_bypass]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_operator")
      authorize_if actor_attribute_equals(:role, "site_manager")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :trigger
    define :reset
    define :arm
    define :disarm
    define :bypass
    define :clear_bypass
    define :report_tamper
    define :report_battery_status
    define :calibrate
    define :mark_false_alarm
  end

  postgres do
    table "sensors"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :device_id], unique: true
      index [:sensor_type]
      index [:current_state]
      index [:zone_number]
      index [:armed?], name: "sensors_armed_index", where: "armed? = true"
      index [:bypass?], name: "sensors_bypass_index", where: "bypass? = true"
      index [:tamper?], name: "sensors_tamper_index", where: "tamper? = true"
      index [:low_battery?], name: "sensors_low_battery_index", where: "low_battery? = true"
    end
  end
end
