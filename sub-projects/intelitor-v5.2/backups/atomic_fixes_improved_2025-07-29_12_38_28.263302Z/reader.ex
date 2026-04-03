defmodule Intelitor.Devices.Reader do
  @moduledoc """
  Represents an access control reader device.

  Readers are used for access control, supporting various credential types
  including cards, PINs, biometrics, and mobile credentials. They control
  entry points and integrate with the access control system.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Devices,
    table: "readers"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Foreign key to device
    attribute :device_id, :uuid do
      allow_nil? false
      public? true
    end

    # Reader configuration
    attribute :reader_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:proximity, :smart_card, :biometric, :multi_technology, :mobile]
      default :proximity
    end

    attribute :reader_mode, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:entry, :exit, :in_out, :attendance]
      default :entry
    end

    attribute :technology, {:array, :atom} do
      public? true
      constraints items: [one_of: [:em, :hid, :mifare, :desfire, :iclass, :ble, :nfc, :qr]]
      default []
    end

    # Communication
    attribute :communication_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:wiegand, :rs485, :tcp_ip, :wireless]
      default :wiegand
    end

    attribute :wiegand_format, :integer do
      public? true
      default 26
    end

    attribute :address, :integer do
      public? true
      constraints min: 1, max: 255
    end

    # Reader features
    attribute :has_keypad?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :has_display?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :has_buzzer?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :has_led?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :has_tamper?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    # Biometric features (if applicable)
    attribute :biometric_type, :atom do
      public? true
      constraints one_of: [:fingerprint, :facial, :iris, :palm, :vein]
    end

    attribute :biometric_capacity, :integer do
      public? true
      constraints min: 0, max: 100_000
    end

    # Reader status
    attribute :reader_status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:online, :offline, :tamper, :fault]
      default :offline
    end

    attribute :led_state, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:off, :red, :green, :amber, :blue, :alternating]
      default :off
    end

    attribute :buzzer_enabled?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :anti_passback?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :duress_enabled?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Security settings
    attribute :card_format, :string do
      public? true
      constraints max_length: 50
    end

    attribute :facility_code, :integer do
      public? true
      constraints min: 0, max: 255
    end

    attribute :pin_length, :integer do
      public? true
      constraints min: 4, max: 8
      default 4
    end

    attribute :read_range_cm, :integer do
      public? true
      constraints min: 1, max: 100
      default 10
    end

    # Operational settings
    attribute :door_open_time_sec, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 300
      default 5
    end

    attribute :door_held_time_sec, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 300
      default 30
    end

    attribute :rex_enabled?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :door_sensor_enabled?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    # Statistics
    attribute :total_reads, :integer do
      allow_nil? false
      public? true
      default 0
    end

    attribute :granted_reads, :integer do
      allow_nil? false
      public? true
      default 0
    end

    attribute :denied_reads, :integer do
      allow_nil? false
      public? true
      default 0
    end

    attribute :last_read_at, :utc_datetime_usec do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :device, Intelitor.Devices.Device do
      allow_nil? false
      attribute_public? true
    end

    # Future relationships
    # belongs_to :door, Intelitor.Sites.Door
    # has_many :access_events, Intelitor.Alarms.AccessEvent
    # has_many :credentials, Intelitor.Policy.Credential
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :device_id,
        :reader_type,
        :reader_mode,
        :technology,
        :communication_type,
        :wiegand_format,
        :address,
        :has_keypad?,
        :has_display?,
        :has_buzzer?,
        :has_led?,
        :has_tamper?,
        :biometric_type,
        :biometric_capacity,
        :buzzer_enabled?,
        :anti_passback?,
        :duress_enabled?,
        :card_format,
        :facility_code,
        :pin_length,
        :read_range_cm,
        :door_open_time_sec,
        :door_held_time_sec,
        :rex_enabled?,
        :door_sensor_enabled?
      ]

      argument :device_id, :uuid do
        allow_nil? false
      end

      validate fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :wiegand_format) do
          nil -> :ok
          format when format in [26, 34, 37, 42] -> :ok
          _ -> {:error, field: :wiegand_format, message: "must be one of: 26, 34, 37, 42"}
        end
      end

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:reader_status, :offline)
        |> Ash.Changeset.force_change_attribute(:led_state, :off)
        |> Ash.Changeset.force_change_attribute(:total_reads, 0)
        |> Ash.Changeset.force_change_attribute(:granted_reads, 0)
        |> Ash.Changeset.force_change_attribute(:denied_reads, 0)
      end
    end


    update :go_online do
      accept []

      change set_attribute(:reader_status, :online)
      change set_attribute(:led_state, :red)
    end

    update :go_offline do
      require_atomic? false
      accept []

      change set_attribute(:reader_status, :offline)
      change set_attribute(:led_state, :off)
    end

    update :report_tamper do
      require_atomic? false
      accept []

      change set_attribute(:reader_status, :tamper)
      change set_attribute(:led_state, :alternating)
    end

    update :clear_tamper do
      require_atomic? false
      accept []

      change set_attribute(:reader_status, :online)
      change set_attribute(:led_state, :red)
    end

    update :set_led do
      require_atomic? false
      accept [:led_state]

      argument :led_state, :atom do
        allow_nil? false
        constraints one_of: [:off, :red, :green, :amber, :blue, :alternating]
      end
    end

    update :grant_access do
      accept []

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:led_state, :green)
        |> Ash.Changeset.force_change_attribute(:granted_reads, changeset.data.granted_reads + 1)
        |> Ash.Changeset.force_change_attribute(:total_reads, changeset.data.total_reads + 1)
        |> Ash.Changeset.force_change_attribute(:last_read_at, DateTime.utc_now())
      end
    end

    update :deny_access do
      require_atomic? false
      accept []

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:led_state, :red)
        |> Ash.Changeset.force_change_attribute(:denied_reads, changeset.data.denied_reads + 1)
        |> Ash.Changeset.force_change_attribute(:total_reads, changeset.data.total_reads + 1)
        |> Ash.Changeset.force_change_attribute(:last_read_at, DateTime.utc_now())
      end
    end

    update :reset_counters do
      accept []

      change set_attribute(:total_reads, 0)
      change set_attribute(:granted_reads, 0)
      change set_attribute(:denied_reads, 0)
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :success_rate, :float do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn reader ->
            if reader.total_reads > 0 do
              reader.granted_reads / reader.total_reads * 100.0
            else
              0.0
            end
          end)

        {:ok, values}
      end
    end

    calculate :denial_rate, :float do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn reader ->
            if reader.total_reads > 0 do
              reader.denied_reads / reader.total_reads * 100.0
            else
              0.0
            end
          end)

        {:ok, values}
      end
    end

    calculate :is_biometric?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn reader ->
            reader.reader_type == :biometric || reader.reader_type == :multi_technology
          end)

        {:ok, values}
      end
    end

    calculate :supports_mobile?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn reader ->
            reader.reader_type == :mobile ||
              reader.reader_type == :multi_technology ||
              Enum.any?(reader.technology || [], &(&1 in [:ble, :nfc, :qr]))
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
      authorize_if actor_attribute_equals(:role, "technician")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "viewer")
    end

    policy action_type([:create, :update]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "technician")
    end

    policy action([:go_online, :go_offline, :set_led, :reset_counters]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "technician")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action([:grant_access, :deny_access]) do
      # System actions - typically called by access control logic
      authorize_if always()
    end

    policy action([:report_tamper, :clear_tamper]) do
      # System or technician actions
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "technician")
      # System can report tamper
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
    define :report_tamper
    define :clear_tamper
    define :set_led
    define :grant_access
    define :deny_access
    define :reset_counters
  end

  postgres do
    table "readers"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :device_id], unique: true
      index [:reader_type]
      index [:reader_mode]
      index [:reader_status]
      index [:communication_type]
      index [:has_keypad?], name: "readers_has_keypad_index", where: "has_keypad? = true"
      index [:has_display?], name: "readers_has_display_index", where: "has_display? = true"
      index [:biometric_type], where: "biometric_type IS NOT NULL"
      index [:anti_passback?], name: "readers_anti_passback_index", where: "anti_passback? = true"

      index [:duress_enabled?],
        name: "readers_duress_enabled_index",
        where: "duress_enabled? = true"
    end
  end
end
