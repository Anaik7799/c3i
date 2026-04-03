defmodule Intelitor.Sites.Area do
  @moduledoc """
  Represents a specific area within a zone or floor.

  Areas are the smallest physical units in the location hierarchy
  and typically represent rooms, sections, or specific spaces.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Sites,
    table: "areas"

  use Intelitor.Multitenancy.TenantResource

  alias Intelitor.Shared.ValidationUtilities

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
      constraints max_length: 50
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :area_type, :atom do
      public? true

      constraints one_of: [
                    :office,
                    :conference_room,
                    :break_room,
                    :restroom,
                    :storage,
                    :server_room,
                    :lobby,
                    :hallway,
                    :stairwell,
                    :elevator,
                    :parking_space,
                    :loading_dock,
                    :utility,
                    :other
                  ]

      default :office
    end

    attribute :area_sqm, :float do
      public? true
      constraints min: 0.0
    end

    attribute :max_occupancy, :integer do
      public? true
      constraints min: 0
    end

    attribute :current_occupancy, :integer do
      public? true
      default 0
      constraints min: 0
    end

    attribute :access_level, :atom do
      public? true
      constraints one_of: [:public, :employees, :authorized, :restricted]
      default :employees
    end

    attribute :climate_controlled?, :boolean do
      public? true
      default true
    end

    attribute :has_windows?, :boolean do
      public? true
      default false
    end

    attribute :emergency_exit?, :boolean do
      public? true
      default false
    end

    attribute :assets, {:array, :map} do
      public? true
      default []
    end

    attribute :environmental_data, :map do
      public? true
      default %{}
    end

    attribute :booking_enabled?, :boolean do
      public? true
      default false
    end

    attribute :booking_rules, :map do
      public? true
      default %{}
    end

    attribute :status, :atom do
      public? true
      constraints one_of: [:available, :occupied, :maintenance, :closed]
      default :available
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

    belongs_to :site, Intelitor.Sites.Site do
      allow_nil? false
      public? true
    end

    belongs_to :building, Intelitor.Sites.Building do
      public? true
    end

    belongs_to :floor, Intelitor.Sites.Floor do
      public? true
    end

    belongs_to :zone, Intelitor.Sites.Zone do
      allow_nil? false
      public? true
    end

    # TODO: Uncomment when Devices domain is implemented
    # has_many :devices, Intelitor.Devices.Device do
    #   public? true
    # end

    # TODO: Uncomment when Dispatch domain is implemented
    # has_many :bookings, Intelitor.Dispatch.Booking do
    #   public? true
    # end
  end

  identities do
    identity :unique_code_per_zone, [:zone_id, :code]
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    update :update_occupancy do
      require_atomic? false
      argument :occupancy, :integer do
        allow_nil? false
        constraints min: 0
      end

      change set_attribute(:current_occupancy, arg(:occupancy))

      # Update status based on occupancy
      change fn changeset, _context ->
        occupancy = Ash.Changeset.get_attribute(changeset, :current_occupancy)
        max_occupancy = Ash.Changeset.get_attribute(changeset, :max_occupancy)

        status =
          cond do
            occupancy == 0 -> :available
            max_occupancy && occupancy >= max_occupancy -> :occupied
            true -> :occupied
          end

        Ash.Changeset.change_attribute(changeset, :status, status)
      end

      validate fn changeset, _context ->
        current = Ash.Changeset.get_attribute(changeset, :current_occupancy)
        max = Ash.Changeset.get_attribute(changeset, :max_occupancy)

        if max && current > max do
          {:error,
           field: :current_occupancy, message: "Cannot exceed maximum occupancy of #{max}"}
        else
          {:ok, changeset}
        end
      end
    end

    update :update_environmental_data do
      require_atomic? false
      argument :temperature_c, :float
      argument :humidity_percent, :float
      argument :co2_ppm, :integer
      argument :noise_db, :float

      change fn changeset, _context ->
        data = Ash.Changeset.get_attribute(changeset, :environmental_data) || %{}

        updates =
          %{
            "temperature_c" => Ash.Changeset.get_argument(changeset, :temperature_c),
            "humidity_percent" => Ash.Changeset.get_argument(changeset, :humidity_percent),
            "co2_ppm" => Ash.Changeset.get_argument(changeset, :co2_ppm),
            "noise_db" => Ash.Changeset.get_argument(changeset, :noise_db),
            "updated_at" => DateTime.utc_now()
          }
          |> Enum.filter(fn {_k, v} -> v != nil end)
          |> Map.new()

        updated_data = Map.merge(data, updates)
        Ash.Changeset.change_attribute(changeset, :environmental_data, updated_data)
      end
    end

    update :set_status do
      require_atomic? false
      argument :status, :atom do
        allow_nil? false
        constraints one_of: [:available, :occupied, :maintenance, :closed]
      end

      argument :reason, :string do
        constraints max_length: 500
      end

      change set_attribute(:status, arg(:status))

      # Create status history entry when status changes
      change fn changeset, _context ->
        if Ash.Changeset.changing_attribute?(changeset, :status) do
          old_status = changeset.data.status
          new_status = Ash.Changeset.get_attribute(changeset, :status)
          reason = Ash.Changeset.get_argument(changeset, :reason)

          # In a real implementation, this would create a status history record
          # For now, we'll add the change to metadata
          metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
          status_history = Map.get(metadata, "status_history", [])

          new_entry = %{
            "from_status" => old_status,
            "to_status" => new_status,
            "reason" => reason,
            "changed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
          }

          updated_metadata = Map.put(metadata, "status_history", [new_entry | status_history])
          Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
        else
          changeset
        end
      end
    end

    update :enable_booking do
      require_atomic? false
      accept [:booking_rules]
      change set_attribute(:booking_enabled?, true)

      validate fn changeset, _context ->
        area_type = Ash.Changeset.get_attribute(changeset, :area_type)

        if area_type in [:conference_room, :office] do
          {:ok, changeset}
        else
          {:error,
           field: :booking_enabled?, message: "Booking not supported for #{area_type} areas"}
        end
      end
    end

    update :disable_booking do
      require_atomic? false
      accept []
      change set_attribute(:booking_enabled?, false)
    end
  end

  calculations do
    calculate :is_available?, :boolean, expr(status == :available)

    calculate :is_occupied?, :boolean, expr(current_occupancy > 0)

    calculate :occupancy_percentage, :float do
      calculation fn records, _opts ->
        Enum.map(records, fn area ->
          if area.max_occupancy && area.max_occupancy > 0 do
            Float.round(area.current_occupancy / area.max_occupancy * 100, 2)
          else
            0.0
          end
        end)
      end
    end

    # TODO: Uncomment when Devices domain is implemented
    # calculate :device_count, :integer, expr(count(devices))

    calculate :environmental_status, :atom do
      calculation fn records, _opts ->
        Enum.map(records, fn area ->
          evaluate_environmental_status(area.environmental_data)
        end)
      end
    end

    calculate :requires_attention?, :boolean do
      calculation fn records, _opts ->
        Enum.map(records, fn area ->
          data = area.environmental_data || %{}

          temp = Map.get(data, "temperature_c", 22)
          humidity = Map.get(data, "humidity_percent", 50)
          co2 = Map.get(data, "co2_ppm", 400)

          # Check if any parameter is out of comfortable range
          temp < 18 || temp > 26 ||
            humidity < 30 || humidity > 60 ||
            co2 > 1000
        end)
      end
    end
  end

  validations do
    validate string_length(:name, min: 1, max: 255)
    validate string_length(:code, min: 1, max: 50)

    validate &ValidationUtilities.validate_occupancy_limits/2
    validate &ValidationUtilities.validate_stairwell_emergency_exit/2
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:tenant_id) == tenant_id)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "site_manager")
      authorize_if actor_attribute_equals(:role, "facility_manager")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :update_occupancy
    define :update_environmental_data
    define :set_status
    define :enable_booking
    define :disable_booking
    define :list_by_zone, action: :read, args: [:zone_id]
    define :list_available, action: :read
  end

  postgres do
    table "areas"
    repo Intelitor.Repo

    custom_indexes do
      index [:zone_id, :code], unique: true
      index [:site_id, :status]
      index [:floor_id], where: "floor_id IS NOT NULL"
      index [:area_type]

      index [:booking_enabled?],
        name: "areas_booking_enabled_index",
        where: "booking_enabled? = true"

      index [:status], where: "status = 'available'"
    end
  end

  # Helper functions
  defp evaluate_environmental_status(nil), do: :unknown

  defp evaluate_environmental_status(data) do
    temp = Map.get(data, "temperature_c", 22)
    humidity = Map.get(data, "humidity_percent", 50)
    co2 = Map.get(data, "co2_ppm", 400)

    cond do
      co2 > 2000 -> :critical
      co2 > 1000 || temp < 16 || temp > 28 -> :poor
      co2 > 800 || temp < 18 || temp > 26 || humidity < 30 || humidity > 60 -> :fair
      true -> :good
    end
  end
end
