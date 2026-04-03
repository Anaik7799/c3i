defmodule Intelitor.Dispatch.Team do
  @moduledoc """
  Represents a dispatch team that responds to security incidents.

  Teams are organized groups of officers and resources that can be deployed
  to handle various types of security incidents. They have specializations,
  availability schedules, and performance metrics tracking.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Dispatch,
    table: "dispatch_teams"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Team identification
    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :code, :string do
      allow_nil? false
      public? true
      constraints max_length: 20
    end

    attribute :description, :string do
      public? true
      constraints max_length: 500
    end

    # Team type and specialization
    attribute :team_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :patrol,
                    :response,
                    :investigation,
                    :k9,
                    :tactical,
                    :medical,
                    :fire,
                    :hazmat,
                    :technical,
                    :supervisory
                  ]

      default :response
    end

    attribute :specializations, {:array, :atom} do
      public? true

      constraints items: [
                    one_of: [
                      :alarm_response,
                      :patrol,
                      :investigation,
                      :crowd_control,
                      :vip_protection,
                      :emergency_medical,
                      :fire_suppression,
                      :hazmat_response,
                      :technical_rescue,
                      :k9_operations,
                      :tactical_operations,
                      :surveillance
                    ]
                  ]

      default []
    end

    # Capacity and manning
    attribute :max_officers, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 50
      default 4
    end

    attribute :min_officers, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 10
      default 2
    end

    attribute :current_officers, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    # Status and availability
    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :available,
                    :assigned,
                    :responding,
                    :on_scene,
                    :unavailable,
                    :off_duty
                  ]

      default :available
    end

    attribute :availability_level, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:high, :medium, :low, :critical_only]
      default :high
    end

    attribute :priority_level, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 10
      default 5
    end

    # Location and coverage
    attribute :base_location, :string do
      public? true
      constraints max_length: 200
    end

    attribute :current_location, :map do
      public? true
      default %{}
    end

    attribute :coverage_areas, {:array, :uuid} do
      public? true
      default []
    end

    attribute :response_radius_km, :float do
      public? true
      constraints min: 0, max: 200
      default 25.0
    end

    # Performance metrics
    attribute :average_response_time_minutes, :float do
      public? true
      constraints min: 0
    end

    attribute :total_assignments, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :completed_assignments, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :success_rate_percent, :float do
      public? true
      constraints min: 0, max: 100
    end

    # Schedule and shifts
    attribute :shift_pattern, :atom do
      public? true
      constraints one_of: [:fixed, :rotating, :on_call, :flexible]
      default :fixed
    end

    attribute :current_shift, :map do
      public? true
      default %{}
    end

    attribute :next_shift_change, :utc_datetime_usec do
      public? true
    end

    # Equipment and vehicles
    attribute :assigned_vehicles, {:array, :uuid} do
      public? true
      default []
    end

    attribute :required_equipment, {:array, :string} do
      public? true
      default []
    end

    attribute :current_equipment, {:array, :string} do
      public? true
      default []
    end

    # Communication
    attribute :radio_channel, :string do
      public? true
      constraints max_length: 50
    end

    attribute :contact_phone, :string do
      public? true
      constraints max_length: 50
    end

    attribute :emergency_contact, :string do
      public? true
      constraints max_length: 100
    end

    # Configuration
    attribute :auto_assign?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :max_concurrent_assignments, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 10
      default 1
    end

    attribute :notification_preferences, :map do
      public? true

      default %{
        "sms" => true,
        "radio" => true,
        "app" => true,
        "email" => false
      }
    end

    # Metadata
    attribute :metadata, :map do
      public? true
      default %{}
    end

    attribute :tags, {:array, :string} do
      public? true
      default []
    end

    attribute :active?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    timestamps()
  end

  relationships do
    has_many :officers, Intelitor.Dispatch.Officer
    has_many :vehicles, Intelitor.Dispatch.Vehicle
    has_many :assignments, Intelitor.Dispatch.Assignment
  end

  actions do
    defaults [:create, :read, :destroy, :update]

    update :update_status do
      require_atomic? false
      accept [:status, :current_location]

      argument :status, :atom do
        allow_nil? false

        constraints one_of: [
                      :available,
                      :assigned,
                      :responding,
                      :on_scene,
                      :unavailable,
                      :off_duty
                    ]
      end
    end

    update :update_manning do
      require_atomic? false
      accept [:current_officers]

      argument :current_officers, :integer do
        allow_nil? false
        constraints min: 0
      end

      validate fn changeset, _context ->
        current = Ash.Changeset.get_argument(changeset, :current_officers)
        max_officers = Ash.Changeset.get_attribute(changeset, :max_officers)

        if current > max_officers do
          {:error, field: :current_officers, message: "cannot exceed max officers"}
        else
          :ok
        end
      end
    end

    update :assign_officer do
      require_atomic? false
      accept []

      argument :officer_id, :uuid do
        allow_nil? false
      end

      validate fn changeset, _context ->
        current = Ash.Changeset.get_attribute(changeset, :current_officers)
        max_officers = Ash.Changeset.get_attribute(changeset, :max_officers)

        if current >= max_officers do
          {:error, field: :current_officers, message: "team at maximum capacity"}
        else
          :ok
        end
      end

      change fn changeset, _context ->
        current = Ash.Changeset.get_attribute(changeset, :current_officers)
        Ash.Changeset.force_change_attribute(changeset, :current_officers, current + 1)
      end
    end

    update :remove_officer do
      require_atomic? false
      accept []

      argument :officer_id, :uuid do
        allow_nil? false
      end

      validate fn changeset, _context ->
        current = Ash.Changeset.get_attribute(changeset, :current_officers)
        min_officers = Ash.Changeset.get_attribute(changeset, :min_officers)

        if current <= min_officers do
          {:error, field: :current_officers, message: "team at minimum manning"}
        else
          :ok
        end
      end

      change fn changeset, _context ->
        current = Ash.Changeset.get_attribute(changeset, :current_officers)
        Ash.Changeset.force_change_attribute(changeset, :current_officers, current - 1)
      end
    end

    update :assign_vehicle do
      require_atomic? false
      accept []

      argument :vehicle_id, :uuid do
        allow_nil? false
      end

      change fn changeset, _context ->
        vehicles = Ash.Changeset.get_attribute(changeset, :assigned_vehicles) || []
        vehicle_id = changeset.arguments.vehicle_id

        if vehicle_id in vehicles do
          changeset
        else
          Ash.Changeset.force_change_attribute(
            changeset,
            :assigned_vehicles,
            [
              vehicle_id | vehicles
            ]
          )
        end
      end
    end

    update :remove_vehicle do
      require_atomic? false
      accept []

      argument :vehicle_id, :uuid do
        allow_nil? false
      end

      change fn changeset, _context ->
        vehicles = Ash.Changeset.get_attribute(changeset, :assigned_vehicles) || []
        vehicle_id = changeset.arguments.vehicle_id

        updated_vehicles = Enum.reject(vehicles, &(&1 == vehicle_id))

        Ash.Changeset.force_change_attribute(
          changeset,
          :assigned_vehicles,
          updated_vehicles
        )
      end
    end

    update :update_location do
      require_atomic? false
      accept [:current_location]

      argument :latitude, :float do
        allow_nil? false
        constraints min: -90, max: 90
      end

      argument :longitude, :float do
        allow_nil? false
        constraints min: -180, max: 180
      end

      change fn changeset, _context ->
        location = %{
          "latitude" => changeset.arguments.latitude,
          "longitude" => changeset.arguments.longitude,
          "timestamp" => DateTime.utc_now(),
          "accuracy" => 10.0
        }

        Ash.Changeset.force_change_attribute(changeset, :current_location, location)
      end
    end

    update :update_metrics do
      require_atomic? false
      accept [:average_response_time_minutes, :success_rate_percent]

      change fn changeset, _context ->
        total = Ash.Changeset.get_attribute(changeset, :total_assignments)
        completed = Ash.Changeset.get_attribute(changeset, :completed_assignments)

        success_rate =
          if total > 0 do
            completed / total * 100.0
          else
            nil
          end

        if success_rate do
          Ash.Changeset.force_change_attribute(
            changeset,
            :success_rate_percent,
            success_rate
          )
        else
          changeset
        end
      end
    end

    update :track_assignment do
      require_atomic? false
      accept []

      argument :completed?, :boolean do
        allow_nil? false
      end

      change fn changeset, _context ->
        total = Ash.Changeset.get_attribute(changeset, :total_assignments)
        completed = Ash.Changeset.get_attribute(changeset, :completed_assignments)
        completed? = changeset.arguments.completed?

        changeset = Ash.Changeset.force_change_attribute(changeset, :total_assignments, total + 1)

        if completed? do
          Ash.Changeset.force_change_attribute(
            changeset,
            :completed_assignments,
            completed + 1
          )
        else
          changeset
        end
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
            fn team ->
              team.status == :available &&
                team.current_officers >= team.min_officers &&
                team.active?
            end
          )

        {:ok, values}
      end
    end

    calculate :manning_percentage, :float do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn team ->
              if team.max_officers > 0 do
                team.current_officers / team.max_officers * 100.0
              else
                0.0
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :is_understaffed?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn team ->
              team.current_officers < team.min_officers
            end
          )

        {:ok, values}
      end
    end

    calculate :vehicle_count, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn team ->
            length(team.assigned_vehicles || [])
          end)

        {:ok, values}
      end
    end

    calculate :coverage_area_count, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn team ->
            length(team.coverage_areas || [])
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
      authorize_if actor_attribute_equals(:role, "dispatcher")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end

    policy action([:update_status, :update_location, :update_metrics]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "dispatcher")
    end

    policy action([:assign_officer, :remove_officer, :assign_vehicle, :remove_vehicle]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :update_status
    define :update_manning
    define :assign_officer
    define :remove_officer
    define :assign_vehicle
    define :remove_vehicle
    define :update_location
    define :update_metrics
    define :track_assignment
    define :activate
    define :deactivate
    define :destroy
  end

  postgres do
    table "dispatch_teams"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :code], unique: true
      index [:team_type]
      index [:status]
      index [:availability_level]
      index [:priority_level]
      index [:active?], name: "dispatch_teams_active_index", where: "active? = true"

      index [:auto_assign?],
        name: "dispatch_teams_auto_assign_index",
        where: "auto_assign? = true"

      index [:current_officers]
    end
  end
end
