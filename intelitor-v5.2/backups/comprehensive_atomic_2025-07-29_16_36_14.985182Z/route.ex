defmodule Intelitor.Dispatch.Route do
  @moduledoc """
  Represents navigation routes for dispatch assignments.

  Routes provide optimized navigation paths for response teams, including
  real-time traffic information, estimated travel times, and alternative
  paths. They integrate with mapping services and GPS tracking.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Dispatch,
    table: "dispatch_routes"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Route identification
    attribute :assignment_id, :uuid do
      public? true
    end

    attribute :vehicle_id, :uuid do
      public? true
    end

    attribute :route_name, :string do
      public? true
      constraints max_length: 100
    end

    # Origin and destination
    attribute :origin_address, :string do
      allow_nil? false
      public? true
      constraints max_length: 500
    end

    attribute :origin_coordinates, :map do
      allow_nil? false
      public? true
      default %{}
    end

    attribute :destination_address, :string do
      allow_nil? false
      public? true
      constraints max_length: 500
    end

    attribute :destination_coordinates, :map do
      allow_nil? false
      public? true
      default %{}
    end

    # Route details
    attribute :route_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:fastest, :shortest, :avoid_traffic, :emergency, :custom]
      default :fastest
    end

    attribute :route_geometry, :map do
      public? true
      default %{}
    end

    attribute :waypoints, {:array, :map} do
      public? true
      default []
    end

    attribute :turn_by_turn_directions, {:array, :map} do
      public? true
      default []
    end

    # Distance and time
    attribute :total_distance_km, :float do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :estimated_duration_minutes, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :traffic_duration_minutes, :integer do
      public? true
      constraints min: 1
    end

    attribute :actual_duration_minutes, :integer do
      public? true
      constraints min: 0
    end

    # Traffic and conditions
    attribute :traffic_conditions, :atom do
      public? true
      constraints one_of: [:light, :moderate, :heavy, :severe, :unknown]
    end

    attribute :traffic_incidents, {:array, :map} do
      public? true
      default []
    end

    attribute :road_conditions, {:array, :string} do
      public? true
      default []
    end

    attribute :weather_impact, :atom do
      public? true
      constraints one_of: [:none, :light, :moderate, :severe]
      default :none
    end

    # Status and tracking
    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:planned, :active, :completed, :cancelled, :deviated]
      default :planned
    end

    attribute :started_at, :utc_datetime_usec do
      public? true
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
    end

    attribute :current_progress_percent, :integer do
      public? true
      constraints min: 0, max: 100
      default 0
    end

    attribute :current_location, :map do
      public? true
      default %{}
    end

    attribute :last_update, :utc_datetime_usec do
      public? true
    end

    # Deviations and alternatives
    attribute :planned_route?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :deviation_reason, :string do
      public? true
      constraints max_length: 500
    end

    attribute :alternative_routes, {:array, :map} do
      public? true
      default []
    end

    attribute :route_recalculations, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    # Emergency and priority
    attribute :emergency_route?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :use_emergency_lanes?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :avoid_toll_roads?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :avoid_highways?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Navigation provider
    attribute :provider, :atom do
      public? true
      constraints one_of: [:google_maps, :mapbox, :here, :openstreetmap, :custom]
      default :google_maps
    end

    attribute :provider_route_id, :string do
      public? true
      constraints max_length: 200
    end

    attribute :provider_response, :map do
      public? true
      default %{}
    end

    # Performance metrics
    attribute :accuracy_rating, :float do
      public? true
      constraints min: 0, max: 5
    end

    attribute :efficiency_score, :integer do
      public? true
      constraints min: 0, max: 100
    end

    attribute :time_variance_minutes, :integer do
      public? true
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

    timestamps()
  end

  relationships do
    belongs_to :assignment, Intelitor.Dispatch.Assignment do
      attribute_public? true
    end

    belongs_to :vehicle, Intelitor.Dispatch.Vehicle do
      attribute_public? true
    end
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :assignment_id,
        :vehicle_id,
        :route_name,
        :origin_address,
        :origin_coordinates,
        :destination_address,
        :destination_coordinates,
        :route_type,
        :total_distance_km,
        :estimated_duration_minutes,
        :emergency_route?,
        :use_emergency_lanes?,
        :avoid_toll_roads?,
        :avoid_highways?,
        :provider,
        :metadata
      ]

      argument :origin_lat, :float do
        allow_nil? false
        constraints min: -90, max: 90
      end

      argument :origin_lng, :float do
        allow_nil? false
        constraints min: -180, max: 180
      end

      argument :dest_lat, :float do
        allow_nil? false
        constraints min: -90, max: 90
      end

      argument :dest_lng, :float do
        allow_nil? false
        constraints min: -180, max: 180
      end

      change fn changeset, _context ->
        origin_coords = %{
          "latitude" => changeset.arguments.origin_lat,
          "longitude" => changeset.arguments.origin_lng
        }

        dest_coords = %{
          "latitude" => changeset.arguments.dest_lat,
          "longitude" => changeset.arguments.dest_lng
        }

        changeset
        |> Ash.Changeset.force_change_attribute(:origin_coordinates, origin_coords)
        |> Ash.Changeset.force_change_attribute(:destination_coordinates, dest_coords)
        |> calculate_route_metrics()
      end
    end


    update :start_navigation do
        require_atomic? false
      accept []

      validate attribute_equals(:status, :planned)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :active)
        |> Ash.Changeset.force_change_attribute(:started_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:current_progress_percent, 0)
      end
    end

    update :update_progress do
      require_atomic? false
      accept [:current_progress_percent, :current_location, :last_update]

      argument :latitude, :float do
        allow_nil? false
        constraints min: -90, max: 90
      end

      argument :longitude, :float do
        allow_nil? false
        constraints min: -180, max: 180
      end

      argument :progress_percent, :integer do
        allow_nil? false
        constraints min: 0, max: 100
      end

      validate attribute_equals(:status, :active)

      change fn changeset, _context ->
        location = %{
          "latitude" => changeset.arguments.latitude,
          "longitude" => changeset.arguments.longitude,
          "timestamp" => DateTime.utc_now(),
          "accuracy" => 10.0
        }

        changeset
        |> Ash.Changeset.force_change_attribute(:current_location, location)
        |> Ash.Changeset.force_change_attribute(
          :current_progress_percent,
          changeset.arguments.progress_percent
        )
        |> Ash.Changeset.force_change_attribute(:last_update, DateTime.utc_now())
      end
    end

    update :complete_route do
      require_atomic? false
      accept [:actual_duration_minutes, :accuracy_rating, :efficiency_score]

      validate attribute_equals(:status, :active)

      change fn changeset, _context ->
        completed_at = DateTime.utc_now()
        started_at = Ash.Changeset.get_attribute(changeset, :started_at)

        actual_duration =
          if started_at do
            div(DateTime.diff(completed_at, started_at), 60)
          else
            nil
          end

        changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(:status, :completed)
          |> Ash.Changeset.force_change_attribute(:completed_at, completed_at)
          |> Ash.Changeset.force_change_attribute(:current_progress_percent, 100)

        if actual_duration do
          estimated = Ash.Changeset.get_attribute(changeset, :estimated_duration_minutes)
          variance = actual_duration - estimated

          changeset
          |> Ash.Changeset.force_change_attribute(:actual_duration_minutes, actual_duration)
          |> Ash.Changeset.force_change_attribute(:time_variance_minutes, variance)
        else
          changeset
        end
      end
    end

    update :cancel_route do
      require_atomic? false
      accept []

      argument :reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      validate attribute_in(:status, [:planned, :active])

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :cancelled)
        |> Ash.Changeset.force_change_attribute(:notes, changeset.arguments.reason)
      end
    end

    update :recalculate_route do
      require_atomic? false
      accept [
        :route_geometry,
        :waypoints,
        :turn_by_turn_directions,
        :estimated_duration_minutes,
        :traffic_duration_minutes
      ]

      argument :new_distance_km, :float do
        constraints min: 0
      end

      argument :new_duration_minutes, :integer do
        constraints min: 1
      end

      change fn changeset, _context ->
        recalcs = Ash.Changeset.get_attribute(changeset, :route_recalculations)

        changeset =
          Ash.Changeset.force_change_attribute(changeset, :route_recalculations, recalcs + 1)

        if new_distance = changeset.arguments.new_distance_km do
          changeset =
            Ash.Changeset.force_change_attribute(changeset, :total_distance_km, new_distance)
        end

        if new_duration = changeset.arguments.new_duration_minutes do
          changeset =
            Ash.Changeset.force_change_attribute(
              changeset,
              :estimated_duration_minutes,
              new_duration
            )
        end

        changeset
      end
    end

    update :report_deviation do
      require_atomic? false
      accept [:deviation_reason, :planned_route?]

      argument :deviation_reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :deviated)
        |> Ash.Changeset.force_change_attribute(:planned_route?, false)
      end
    end

    update :update_traffic_conditions do
      require_atomic? false
      accept [:traffic_conditions, :traffic_incidents, :traffic_duration_minutes]

      argument :conditions, :atom do
        allow_nil? false
        constraints one_of: [:light, :moderate, :heavy, :severe, :unknown]
      end
    end

    update :add_traffic_incident do
      accept []

      argument :incident_type, :string do
        allow_nil? false
        constraints max_length: 100
      end

      argument :incident_location, :string do
        allow_nil? false
        constraints max_length: 200
      end

      argument :severity, :atom do
        allow_nil? false
        constraints one_of: [:minor, :moderate, :major, :severe]
      end

      change fn changeset, _context ->
        incidents = Ash.Changeset.get_attribute(changeset, :traffic_incidents) || []

        new_incident = %{
          "type" => changeset.arguments.incident_type,
          "location" => changeset.arguments.incident_location,
          "severity" => changeset.arguments.severity,
          "reported_at" => DateTime.utc_now()
        }

        Ash.Changeset.force_change_attribute(changeset, :traffic_incidents, [
          new_incident | incidents
        ])
      end
    end

    update :set_alternative_routes do
      require_atomic? false
      accept [:alternative_routes]

      argument :alternatives, {:array, :map} do
        allow_nil? false
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :is_active?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn route ->
            route.status == :active
          end)

        {:ok, values}
      end
    end

    calculate :is_delayed?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn route ->
            if route.started_at && route.status == :active do
              elapsed_minutes = div(DateTime.diff(DateTime.utc_now(), route.started_at), 60)
              elapsed_minutes > route.estimated_duration_minutes
            else
              false
            end
          end)

        {:ok, values}
      end
    end

    calculate :estimated_arrival_time, :utc_datetime_usec do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn route ->
            if route.started_at && route.status == :active do
              remaining_percent = 100 - route.current_progress_percent

              remaining_duration =
                (route.estimated_duration_minutes * remaining_percent / 100.0) |> round()

              DateTime.add(DateTime.utc_now(), remaining_duration * 60, :second)
            else
              nil
            end
          end)

        {:ok, values}
      end
    end

    calculate :traffic_delay_minutes, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn route ->
            if route.traffic_duration_minutes && route.estimated_duration_minutes do
              route.traffic_duration_minutes - route.estimated_duration_minutes
            else
              0
            end
          end)

        {:ok, values}
      end
    end

    calculate :has_traffic_incidents?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn route ->
            !Enum.empty?(route.traffic_incidents || [])
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

    policy action(:create) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "dispatcher")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action([:update, :start_navigation, :update_progress, :complete_route]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "dispatcher")
      authorize_if actor_attribute_equals(:role, "operator")
      # System can update routes automatically
      authorize_if always()
    end

    policy action([:cancel_route, :recalculate_route]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "dispatcher")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :start_navigation
    define :update_progress
    define :complete_route
    define :cancel_route
    define :recalculate_route
    define :report_deviation
    define :update_traffic_conditions
    define :add_traffic_incident
    define :set_alternative_routes
    define :destroy
  end

  postgres do
    table "dispatch_routes"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :assignment_id], where: "assignment_id IS NOT NULL"
      index [:vehicle_id], where: "vehicle_id IS NOT NULL"
      index [:status]
      index [:route_type]

      index [:emergency_route?],
        name: "dispatch_routes_emergency_index",
        where: "emergency_route? = true"

      index [:started_at]
      index [:completed_at], where: "completed_at IS NOT NULL"
      index [:provider]
    end
  end

  # Helper functions
  defp calculate_route_metrics(changeset) do
    # In a real implementation, this would call a mapping service API
    # For now, we'll just set some basic calculated fields
    changeset
  end
end
