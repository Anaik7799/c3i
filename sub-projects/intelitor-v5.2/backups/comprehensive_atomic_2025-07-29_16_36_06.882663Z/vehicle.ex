defmodule Intelitor.Dispatch.Vehicle do
  @moduledoc """
  Represents dispatch vehicles used by security teams.

  Vehicles are the mobile assets used for patrol, response, and transportation.
  They include patrol cars, motorcycles, emergency vehicles, and specialized
  equipment carriers with tracking, maintenance, and utilization monitoring.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Dispatch,
    table: "dispatch_vehicles"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Vehicle identification
    attribute :call_sign, :string do
      allow_nil? false
      public? true
      constraints max_length: 20
    end

    attribute :license_plate, :string do
      allow_nil? false
      public? true
      constraints max_length: 20
    end

    attribute :fleet_number, :string do
      public? true
      constraints max_length: 50
    end

    attribute :vin, :string do
      public? false
      constraints max_length: 17
    end

    # Vehicle details
    attribute :make, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :model, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :year, :integer do
      allow_nil? false
      public? true
      constraints min: 1990, max: 2030
    end

    attribute :color, :string do
      public? true
      constraints max_length: 50
    end

    attribute :vehicle_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :patrol_car,
                    :suv,
                    :motorcycle,
                    :van,
                    :truck,
                    :emergency_response,
                    :k9_unit,
                    :command_vehicle,
                    :specialized_equipment,
                    :unmarked
                  ]

      default :patrol_car
    end

    # Assignment and status
    attribute :team_id, :uuid do
      public? true
    end

    attribute :assigned_officer_id, :uuid do
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :available,
                    :assigned,
                    :in_use,
                    :en_route,
                    :on_scene,
                    :out_of_service,
                    :maintenance,
                    :fueling,
                    :cleaning
                  ]

      default :available
    end

    attribute :operational_status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:operational, :limited, :non_operational]
      default :operational
    end

    # Location and tracking
    attribute :current_location, :map do
      public? true
      default %{}
    end

    attribute :last_location_update, :utc_datetime_usec do
      public? true
    end

    attribute :base_location, :string do
      public? true
      constraints max_length: 200
    end

    attribute :gps_device_id, :string do
      public? true
      constraints max_length: 100
    end

    # Equipment and capabilities
    attribute :equipment_list, {:array, :string} do
      public? true
      default []
    end

    attribute :special_equipment, {:array, :string} do
      public? true
      default []
    end

    attribute :communication_equipment, {:array, :string} do
      public? true
      default []
    end

    attribute :max_occupancy, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 12
      default 2
    end

    attribute :cargo_capacity_kg, :float do
      public? true
      constraints min: 0
    end

    # Performance and maintenance
    attribute :odometer_km, :float do
      allow_nil? false
      public? true
      constraints min: 0
      default 0.0
    end

    attribute :fuel_level_percent, :integer do
      public? true
      constraints min: 0, max: 100
    end

    attribute :fuel_capacity_liters, :float do
      public? true
      constraints min: 0
    end

    attribute :last_maintenance_date, :date do
      public? true
    end

    attribute :next_maintenance_km, :float do
      public? true
      constraints min: 0
    end

    attribute :last_inspection_date, :date do
      public? true
    end

    attribute :next_inspection_date, :date do
      public? true
    end

    # Utilization metrics
    attribute :total_assignments, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :total_distance_km, :float do
      allow_nil? false
      public? true
      default 0.0
      constraints min: 0
    end

    attribute :total_runtime_hours, :float do
      allow_nil? false
      public? true
      default 0.0
      constraints min: 0
    end

    attribute :average_fuel_consumption, :float do
      public? true
      constraints min: 0
    end

    # Insurance and registration
    attribute :insurance_policy, :string do
      public? true
      constraints max_length: 100
    end

    attribute :insurance_expires, :date do
      public? true
    end

    attribute :registration_expires, :date do
      public? true
    end

    attribute :safety_inspection_expires, :date do
      public? true
    end

    # Emergency equipment status
    attribute :emergency_lights?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :siren?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :first_aid_kit?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :fire_extinguisher?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :emergency_equipment_check_date, :date do
      public? true
    end

    # Maintenance alerts
    attribute :maintenance_alerts, {:array, :string} do
      public? true
      default []
    end

    attribute :defects, {:array, :map} do
      public? true
      default []
    end

    # Metadata
    attribute :notes, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    attribute :active?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    timestamps()
  end

  relationships do
    belongs_to :team, Intelitor.Dispatch.Team do
      attribute_public? true
    end

    belongs_to :assigned_officer, Intelitor.Dispatch.Officer do
      attribute_public? true
    end

    has_many :assignments, Intelitor.Dispatch.Assignment
    has_many :routes, Intelitor.Dispatch.Route
  end

  actions do
    defaults [:create, :read, :destroy, :update]

    update :update_status do
      require_atomic? false
      accept [:status, :operational_status]

      argument :status, :atom do
        allow_nil? false

        constraints one_of: [
                      :available,
                      :assigned,
                      :in_use,
                      :en_route,
                      :on_scene,
                      :out_of_service,
                      :maintenance,
                      :fueling,
                      :cleaning
                    ]
      end
    end

    update :assign_to_team do
      require_atomic? false
      accept [:team_id]

      argument :team_id, :uuid do
        allow_nil? false
      end

      validate attribute_in(:status, [:available, :out_of_service])

      change set_attribute(:status, :assigned)
    end

    update :assign_to_officer do
      require_atomic? false
      accept [:assigned_officer_id]

      argument :officer_id, :uuid do
        allow_nil? false
      end

      validate attribute_in(:status, [:available, :assigned])

      change set_attribute(:status, :assigned)
    end

    update :remove_assignment do
      require_atomic? false
      accept []

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:team_id, nil)
        |> Ash.Changeset.force_change_attribute(:assigned_officer_id, nil)
        |> Ash.Changeset.force_change_attribute(:status, :available)
      end
    end

    update :update_location do
      require_atomic? false
      accept [:current_location, :last_location_update]

      argument :latitude, :float do
        allow_nil? false
        constraints min: -90, max: 90
      end

      argument :longitude, :float do
        allow_nil? false
        constraints min: -180, max: 180
      end

      argument :heading, :float do
        constraints min: 0, max: 360
        default 0.0
      end

      argument :speed_kmh, :float do
        constraints min: 0
        default 0.0
      end

      change fn changeset, _context ->
        location = %{
          "latitude" => changeset.arguments.latitude,
          "longitude" => changeset.arguments.longitude,
          "timestamp" => DateTime.utc_now(),
          "accuracy" => 10.0,
          "heading" => changeset.arguments.heading,
          "speed" => changeset.arguments.speed_kmh
        }

        changeset
        |> Ash.Changeset.force_change_attribute(:current_location, location)
        |> Ash.Changeset.force_change_attribute(:last_location_update, DateTime.utc_now())
      end
    end

    update :update_odometer do
      require_atomic? false
      accept [:odometer_km, :total_distance_km]

      argument :new_reading_km, :float do
        allow_nil? false
        constraints min: 0
      end

      validate fn changeset, _context ->
        current = Ash.Changeset.get_attribute(changeset, :odometer_km)
        new_reading = changeset.arguments.new_reading_km

        if new_reading < current do
          {:error, field: :odometer_km, message: "cannot decrease odometer reading"}
        else
          :ok
        end
      end

      change fn changeset, _context ->
        current = Ash.Changeset.get_attribute(changeset, :odometer_km)
        new_reading = changeset.arguments.new_reading_km
        distance_traveled = new_reading - current

        total_distance = Ash.Changeset.get_attribute(changeset, :total_distance_km)

        changeset
        |> Ash.Changeset.force_change_attribute(:odometer_km, new_reading)
        |> Ash.Changeset.force_change_attribute(
          :total_distance_km,
          total_distance + distance_traveled
        )
      end
    end

    update :update_fuel_level do
      require_atomic? false
      accept [:fuel_level_percent]

      argument :fuel_level_percent, :integer do
        allow_nil? false
        constraints min: 0, max: 100
      end
    end

    update :schedule_maintenance do
      require_atomic? false
      accept [:next_maintenance_km, :last_maintenance_date]

      argument :maintenance_type, :string do
        allow_nil? false
        constraints max_length: 100
      end

      argument :scheduled_date, :date do
        allow_nil? false
      end

      change fn changeset, _context ->
        maintenance_type = changeset.arguments.maintenance_type
        scheduled_date = changeset.arguments.scheduled_date

        alert = "#{maintenance_type} scheduled for #{scheduled_date}"
        alerts = Ash.Changeset.get_attribute(changeset, :maintenance_alerts) || []

        if alert in alerts do
          changeset
        else
          Ash.Changeset.force_change_attribute(
            changeset,
            :maintenance_alerts,
            [alert | alerts]
          )
        end
      end
    end

    update :complete_maintenance do
      require_atomic? false
      accept [:last_maintenance_date, :maintenance_alerts]

      argument :maintenance_type, :string do
        allow_nil? false
      end

      argument :next_service_km, :float do
        constraints min: 0
      end

      change fn changeset, _context ->
        maintenance_type = changeset.arguments.maintenance_type
        alerts = Ash.Changeset.get_attribute(changeset, :maintenance_alerts) || []

        # Remove completed maintenance alerts
        updated_alerts = Enum.reject(alerts, &String.contains?(&1, maintenance_type))

        changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(:last_maintenance_date, Date.utc_today())
          |> Ash.Changeset.force_change_attribute(:maintenance_alerts, updated_alerts)

        # Set next service milestone if provided
        if next_km = changeset.arguments.next_service_km do
          Ash.Changeset.force_change_attribute(changeset, :next_maintenance_km, next_km)
        else
          changeset
        end
      end
    end

    update :report_defect do
      require_atomic? false
      accept []

      argument :defect_description, :string do
        allow_nil? false
        constraints max_length: 500
      end

      argument :severity, :atom do
        allow_nil? false
        constraints one_of: [:minor, :major, :critical]
      end

      change fn changeset, _context ->
        defects = Ash.Changeset.get_attribute(changeset, :defects) || []

        new_defect = %{
          "description" => changeset.arguments.defect_description,
          "severity" => changeset.arguments.severity,
          "reported_at" => DateTime.utc_now(),
          "status" => "open"
        }

        changeset =
          Ash.Changeset.force_change_attribute(
            changeset,
            :defects,
            [new_defect | defects]
          )

        # Set operational status based on severity
        if changeset.arguments.severity == :critical do
          Ash.Changeset.force_change_attribute(
            changeset,
            :operational_status,
            :non_operational
          )
        else
          changeset
        end
      end
    end

    update :resolve_defect do
      require_atomic? false
      accept []

      argument :defect_index, :integer do
        allow_nil? false
        constraints min: 0
      end

      change fn changeset, _context ->
        defects = Ash.Changeset.get_attribute(changeset, :defects) || []
        index = changeset.arguments.defect_index

        if index < length(defects) do
          updated_defects =
            List.update_at(
              defects,
              index,
              fn defect ->
                Map.merge(
                  defect,
                  %{"status" => "resolved", "resolved_at" => DateTime.utc_now()}
                )
              end
            )

          Ash.Changeset.force_change_attribute(changeset, :defects, updated_defects)
        else
          changeset
        end
      end
    end

    update :track_assignment do
      require_atomic? false
      accept [:total_assignments, :total_runtime_hours]

      argument :runtime_hours, :float do
        allow_nil? false
        constraints min: 0
      end

      change fn changeset, _context ->
        total_assignments = Ash.Changeset.get_attribute(changeset, :total_assignments)
        total_runtime = Ash.Changeset.get_attribute(changeset, :total_runtime_hours)
        additional_hours = changeset.arguments.runtime_hours

        changeset
        |> Ash.Changeset.force_change_attribute(:total_assignments, total_assignments + 1)
        |> Ash.Changeset.force_change_attribute(
          :total_runtime_hours,
          total_runtime + additional_hours
        )
      end
    end

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
  end

  calculations do
    calculate :is_available?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn vehicle ->
              vehicle.status == :available &&
                vehicle.operational_status == :operational &&
                vehicle.active?
            end
          )

        {:ok, values}
      end
    end

    calculate :needs_maintenance?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn vehicle ->
              (vehicle.next_maintenance_km && vehicle.odometer_km >= vehicle.next_maintenance_km) ||
                !Enum.empty?(vehicle.maintenance_alerts || []) ||
                !Enum.empty?(vehicle.defects || [])
            end
          )

        {:ok, values}
      end
    end

    calculate :fuel_range_km, :float do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn vehicle ->
              if vehicle.fuel_level_percent && vehicle.fuel_capacity_liters &&
                   vehicle.average_fuel_consumption do
                current_fuel = vehicle.fuel_level_percent / 100.0 * vehicle.fuel_capacity_liters
                current_fuel / vehicle.average_fuel_consumption * 100.0
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :utilization_rate, :float do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn vehicle ->
              # Simple calculation based on assignments vs available time
              # In practice, this would be more sophisticated

              if vehicle.total_assignments > 0 do
                min(vehicle.total_runtime_hours / (vehicle.total_assignments * 8.0), 1.0) * 100.0
              else
                0.0
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :critical_defects_count, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn vehicle ->
              defects = vehicle.defects || []

              Enum.count(
                defects,
                fn defect ->
                  defect["severity"] == "critical" && defect["status"] != "resolved"
                end
              )
            end
          )

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
      authorize_if actor_attribute_equals(:role, "dispatcher")
      authorize_if actor_attribute_equals(:role, "supervisor")
      authorize_if actor_attribute_equals(:role, "technician")
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end

    policy action([:update_status, :update_location, :update_fuel_level]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "dispatcher")
      # Assigned officers can update their vehicle
      authorize_if expr(assigned_officer_id == ^actor(:id))
    end

    policy action([:assign_to_team, :assign_to_officer, :remove_assignment]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "dispatcher")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end

    policy action([:schedule_maintenance, :complete_maintenance, :report_defect, :resolve_defect]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "technician")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :update_status
    define :assign_to_team
    define :assign_to_officer
    define :remove_assignment
    define :update_location
    define :update_odometer
    define :update_fuel_level
    define :schedule_maintenance
    define :complete_maintenance
    define :report_defect
    define :resolve_defect
    define :track_assignment
    define :activate
    define :deactivate
    define :destroy
  end

  postgres do
    table "dispatch_vehicles"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :call_sign], unique: true
      index [:license_plate], unique: true
      index [:fleet_number], where: "fleet_number IS NOT NULL"
      index [:team_id], where: "team_id IS NOT NULL"
      index [:assigned_officer_id], where: "assigned_officer_id IS NOT NULL"
      index [:status]
      index [:operational_status]
      index [:vehicle_type]
      index [:active?], name: "dispatch_vehicles_active_index", where: "active? = true"
      index [:last_location_update]
      index [:next_maintenance_km], where: "next_maintenance_km IS NOT NULL"
    end
  end
end
