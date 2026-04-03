defmodule Intelitor.Devices.Device do
  @moduledoc """
  Represents a physical security device in the system.

  This is the base resource for all devices, containing common attributes
  and relationships. Specific device types (sensors, cameras, etc.) extend
  this through their own resources.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Devices,
    table: "devices"

  use Intelitor.Multitenancy.TenantResource
  use Intelitor.Tracing.ResourceHelpers

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255
    end

    attribute :serial_number, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :mac_address, :string do
      public? true

      constraints max_length: 17,
                  match: ~S/^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$/
    end

    attribute :ip_address, :string do
      public? true
      constraints max_length: 45
    end

    attribute :firmware_version, :string do
      public? true
      constraints max_length: 50
    end

    attribute :hardware_version, :string do
      public? true
      constraints max_length: 50
    end

    attribute :status, :atom do
      public? true
      constraints one_of: [:active, :inactive, :maintenance, :faulty, :disconnected, :unknown]
      default :inactive
    end

    attribute :health_status, :atom do
      public? true
      constraints one_of: [:healthy, :degraded, :critical, :unknown]
      default :unknown
    end

    attribute :last_seen_at, :utc_datetime do
      public? true
    end

    attribute :last_heartbeat_at, :utc_datetime do
      public? true
    end

    attribute :configuration, :map do
      public? true
      default %{}
    end

    attribute :telemetry_data, :map do
      public? true
      default %{}
    end

    attribute :installation_date, :date do
      public? true
    end

    attribute :warranty_expiry, :date do
      public? true
    end

    attribute :maintenance_schedule, :map do
      public? true
      default %{}
    end

    attribute :last_maintenance_date, :date do
      public? true
    end

    attribute :notes, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :tags, {:array, :string} do
      public? true
      default []
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

    belongs_to :device_type, Intelitor.Devices.DeviceType do
      allow_nil? false
      public? true
    end

    belongs_to :location, Intelitor.Sites.Location do
      allow_nil? false
      public? true
    end

    belongs_to :site, Intelitor.Sites.Site do
      allow_nil? false
      public? true
    end

    # TODO: Uncomment when Alarms domain is implemented
    # has_many :events, Intelitor.Alarms.Event do
    #   public? true
    # end

    # TODO: Uncomment when Maintenance domain is implemented
    # has_many :maintenance_records, Intelitor.Maintenance.ServiceRecord do
    #   public? true
    # end
  end

  identities do
    identity :unique_serial_per_tenant, [:tenant_id, :serial_number]
    identity :unique_mac_per_tenant, [:tenant_id, :mac_address]
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :name,
        :serial_number,
        :mac_address,
        :ip_address,
        :firmware_version,
        :hardware_version,
        :device_type_id,
        :location_id,
        :site_id,
        :configuration,
        :installation_date,
        :warranty_expiry,
        :notes,
        :tags
      ]

      change {Intelitor.Changes.TraceOperation,
              operation_type: :device, operation_name: "created"}

      change {Intelitor.Changes.TraceBusinessCritical,
              operation_name: "device.register", importance: :high}

      change {Intelitor.Changes.TraceAndAudit, audit_action: :device_created}

      change set_attribute(:status, :inactive)
      change set_attribute(:last_seen_at, DateTime.utc_now())

      after_action(fn changeset, result, context ->
        :telemetry.execute(
          [:intelitor, :device, :created],
          %{count: 1},
          %{
            device_id: result.id,
            device_type: result.device_type_id,
            site_id: result.site_id,
            serial_number: result.serial_number,
            tenant_id: Intelitor.Tracing.extract_tenant_id(context[:actor])
          }
        )

        {:ok, result}
      end)
    end


    update :update_location do
      require_atomic? false
      argument :location_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:location_id, arg(:location_id))

      change fn changeset, _context ->
        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        history = Map.get(metadata, "location_history", [])

        entry = %{
          "location_id" => Ash.Changeset.get_argument(changeset, :location_id),
          "moved_at" => DateTime.utc_now()
        }

        updated_metadata = Map.put(metadata, "location_history", [entry | history])
        Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
      end
    end

    update :heartbeat do
      require_atomic? false
      accept []

      change {Intelitor.Changes.TraceOperation,
              operation_type: :device, operation_name: "heartbeat"}

      change set_attribute(:last_heartbeat_at, DateTime.utc_now())
      change set_attribute(:last_seen_at, DateTime.utc_now())
      change set_attribute(:status, :active)

      after_action(fn changeset, result, context ->
        # Only emit telemetry for periodic heartbeat monitoring, not every heartbeat
        current_time = DateTime.utc_now()
        last_heartbeat = result.last_heartbeat_at

        if last_heartbeat && DateTime.diff(current_time, last_heartbeat, :minute) >= 5 do
          :telemetry.execute(
            [:intelitor, :device, :heartbeat],
            %{
              count: 1,
              uptime_minutes: DateTime.diff(current_time, result.last_seen_at, :minute)
            },
            %{
              device_id: result.id,
              device_type: result.device_type_id,
              status: result.status,
              tenant_id: Intelitor.Tracing.extract_tenant_id(context[:actor])
            }
          )
        end

        {:ok, result}
      end)
    end

    update :update_status do
      require_atomic? false
      argument :status, :atom do
        allow_nil? false
        constraints one_of: [:active, :inactive, :maintenance, :faulty, :disconnected, :unknown]
      end

      argument :reason, :string do
        constraints max_length: 500
      end

      change set_attribute(:status, arg(:status))
      change set_attribute(:last_seen_at, DateTime.utc_now())

      change fn changeset, context ->
        reason = Ash.Changeset.get_argument(changeset, :reason)

        if reason do
          metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
          status_history = Map.get(metadata, "status_history", [])

          entry = %{
            "status" => Ash.Changeset.get_argument(changeset, :status),
            "reason" => reason,
            "changed_at" => DateTime.utc_now(),
            "changed_by" => context[:actor][:id]
          }

          updated_metadata = Map.put(metadata, "status_history", [entry | status_history])
          Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
        else
          changeset
        end
      end
    end

    update :update_telemetry do
      require_atomic? false
      argument :telemetry, :map do
        allow_nil? false
      end

      change fn changeset, _context ->
        telemetry = Ash.Changeset.get_argument(changeset, :telemetry)
        timestamped = Map.put(telemetry, "timestamp", DateTime.utc_now())

        Ash.Changeset.change_attribute(changeset, :telemetry_data, timestamped)
        |> Ash.Changeset.change_attribute(:last_seen_at, DateTime.utc_now())
      end
    end

    update :perform_maintenance do
      require_atomic? false
      argument :maintenance_type, :string do
        allow_nil? false
        constraints max_length: 100
      end

      argument :performed_by, :string do
        allow_nil? false
        constraints max_length: 255
      end

      argument :notes, :string do
        constraints max_length: 1000
      end

      change set_attribute(:last_maintenance_date, Date.utc_today())
      change set_attribute(:health_status, :healthy)

      change fn changeset, _context ->
        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        maintenance_log = Map.get(metadata, "maintenance_log", [])

        entry = %{
          "type" => Ash.Changeset.get_argument(changeset, :maintenance_type),
          "performed_by" => Ash.Changeset.get_argument(changeset, :performed_by),
          "notes" => Ash.Changeset.get_argument(changeset, :notes),
          "date" => Date.utc_today()
        }

        updated_metadata = Map.put(metadata, "maintenance_log", [entry | maintenance_log])
        Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
      end
    end

    destroy :destroy do
      require_atomic? false
      soft? true
      change set_attribute(:status, :inactive)
    end
  end

  calculations do
    calculate :is_online?,
              :boolean,
              expr(status == :active and last_heartbeat_at > ago(5, :minute))

    calculate :is_healthy?, :boolean, expr(health_status == :healthy)

    calculate :needs_maintenance?, :boolean do
      calculation fn records, _opts ->
        Enum.map(records, fn device ->
          case device.last_maintenance_date do
            nil ->
              true

            date ->
              days_since = Date.diff(Date.utc_today(), date)
              schedule = device.maintenance_schedule || %{}
              interval_days = Map.get(schedule, "interval_days", 90)
              days_since >= interval_days
          end
        end)
      end
    end

    calculate :warranty_status, :atom do
      calculation fn records, _opts ->
        today = Date.utc_today()

        Enum.map(records, fn device ->
          case device.warranty_expiry do
            nil ->
              :unknown

            expiry ->
              cond do
                Date.compare(expiry, today) == :lt -> :expired
                Date.diff(expiry, today) <= 30 -> :expiring_soon
                true -> :active
              end
          end
        end)
      end
    end

    calculate :uptime_percentage, :float do
      calculation fn records, _opts ->
        Enum.map(records, fn device ->
          # This would need actual implementation with event history
          case device.status do
            :active -> 99.9
            :maintenance -> 95.0
            _ -> 0.0
          end
        end)
      end
    end

    # TODO: Uncomment when Alarms domain is implemented
    # calculate :event_count_24h, :integer, expr(count(events, query: [filter: expr(created_at > ago(24, :hour))]))
  end

  validations do
    validate string_length(:name, min: 3, max: 255)
    validate string_length(:serial_number, min: 1, max: 100)

    validate fn changeset, _context ->
      mac = Ash.Changeset.get_attribute(changeset, :mac_address)

      if mac && !Regex.match?(~r/^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$/i, mac) do
        {:error, field: :mac_address, message: "must be a valid MAC address"}
      else
        {:ok, changeset}
      end
    end

    validate fn changeset, _context ->
      ip = Ash.Changeset.get_attribute(changeset, :ip_address)

      if ip do
        # Basic IP validation (v4 or v6)
        valid_ipv4? = Regex.match?(~r/^(\d{1,3}\.){3}\d{1,3}$/, ip)
        valid_ipv6? = String.contains?(ip, ":")

        if valid_ipv4? || valid_ipv6? do
          {:ok, changeset}
        else
          {:error, field: :ip_address, message: "must be a valid IPv4 or IPv6 address"}
        end
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

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "device_manager")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :update_location
    define :heartbeat
    define :update_status
    define :update_telemetry
    define :perform_maintenance
    define :destroy
    define :get_by_serial, action: :read, get_by: [:tenant_id, :serial_number]
  end

  postgres do
    table "devices"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :serial_number], unique: true
      index [:tenant_id, :mac_address], unique: true, where: "mac_address IS NOT NULL"
      index [:device_type_id]
      index [:location_id]
      index [:site_id]
      index [:status]
      index [:health_status]
      index [:last_seen_at]
      index [:installation_date]
    end
  end
end
