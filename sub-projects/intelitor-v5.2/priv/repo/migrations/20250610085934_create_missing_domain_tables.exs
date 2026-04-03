defmodule Indrajaal.Repo.Migrations.CreateMissingDomainTables do
  @moduledoc """
  Creates missing tables for domains that alarm tables depend on.

  This migration creates:
  - Devices domain tables (devices, cameras, sensors, panels, readers, device_types)
  - Dispatch domain tables (dispatch_teams, dispatch_officers, dispatch_vehicles, etc.)
  - Additional missing tables
  """

  use Ecto.Migration

  @spec up() :: any()
  def up do
    # Create device_types table
    create table(:device_types, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "device_types_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :code, :text, null: false
      add :category, :text, null: false
      add :manufacturer, :text
      add :model, :text
      add :capabilities, {:array, :text}, default: []
      add :configuration_schema, :map, default: %{}
      add :active?, :boolean, null: false, default: true
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:device_types, [:tenant_id, :code], unique: true)
    create index(:device_types, [:category])
    create index(:device_types, [:active?], where: "\"active?\" = true")

    # Create devices table
    create table(:devices, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "devices_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :serial_number, :text, null: false

      add :device_type_id,
          references(:device_types,
            column: :id,
            name: "devices_device_type_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :location_id,
          references(:locations,
            column: :id,
            name: "devices_location_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :status, :text, null: false, default: "offline"
      add :configuration, :map, default: %{}
      add :last_seen_at, :utc_datetime_usec
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:devices, [:tenant_id, :serial_number], unique: true)
    create index(:devices, [:device_type_id])
    create index(:devices, [:location_id])
    create index(:devices, [:status])

    # Create cameras table
    create table(:cameras, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "cameras_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :device_id,
          references(:devices,
            column: :id,
            name: "cameras_device_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :stream_url, :text
      add :resolution, :text
      add :fps, :bigint
      add :capabilities, {:array, :text}, default: []
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:cameras, [:device_id], unique: true)

    # Create sensors table
    create table(:sensors, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "sensors_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :device_id,
          references(:devices,
            column: :id,
            name: "sensors_device_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :sensor_type, :text, null: false
      add :trigger_threshold, :map, default: %{}
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:sensors, [:device_id], unique: true)
    create index(:sensors, [:sensor_type])

    # Create panels table
    create table(:panels, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "panels_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :device_id,
          references(:devices,
            column: :id,
            name: "panels_device_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :panel_type, :text, null: false
      add :zones_supported, :bigint
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:panels, [:device_id], unique: true)

    # Create readers table
    create table(:readers, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "readers_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :device_id,
          references(:devices,
            column: :id,
            name: "readers_device_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :reader_type, :text, null: false
      add :supported_formats, {:array, :text}, default: []
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:readers, [:device_id], unique: true)

    # Create dispatch teams table
    create table(:dispatch_teams, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "dispatch_teams_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :code, :text, null: false
      add :shift_pattern, :text
      add :coverage_area, :map, default: %{}
      add :active?, :boolean, null: false, default: true
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:dispatch_teams, [:tenant_id, :code], unique: true)
    create index(:dispatch_teams, [:active?], where: "\"active?\" = true")

    # Create dispatch officers table
    create table(:dispatch_officers, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "dispatch_officers_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :user_id,
          references(:users,
            column: :id,
            name: "dispatch_officers_user_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :badge_number, :text, null: false

      add :dispatch_team_id,
          references(:dispatch_teams,
            column: :id,
            name: "dispatch_officers_dispatch_team_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :status, :text, null: false, default: "off_duty"
      add :certifications, {:array, :text}, default: []
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:dispatch_officers, [:tenant_id, :badge_number], unique: true)
    create index(:dispatch_officers, [:user_id])
    create index(:dispatch_officers, [:dispatch_team_id])
    create index(:dispatch_officers, [:status])

    # Create dispatch vehicles table
    create table(:dispatch_vehicles, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "dispatch_vehicles_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :vehicle_number, :text, null: false
      add :vehicle_type, :text, null: false
      add :license_plate, :text

      add :dispatch_team_id,
          references(:dispatch_teams,
            column: :id,
            name: "dispatch_vehicles_dispatch_team_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :status, :text, null: false, default: "available"
      add :current_location, :map, default: %{}
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:dispatch_vehicles, [:tenant_id, :vehicle_number], unique: true)
    create index(:dispatch_vehicles, [:dispatch_team_id])
    create index(:dispatch_vehicles, [:status])

    # Create dispatch routes table
    create table(:dispatch_routes, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "dispatch_routes_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :route_points, {:array, :map}, default: []
      add :estimated_duration_minutes, :bigint
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:dispatch_routes, [:tenant_id])

    # Create dispatch assignments table
    create table(:dispatch_assignments, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "dispatch_assignments_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :dispatch_team_id,
          references(:dispatch_teams,
            column: :id,
            name: "dispatch_assignments_dispatch_team_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :officer_id,
          references(:dispatch_officers,
            column: :id,
            name: "dispatch_assignments_officer_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :vehicle_id,
          references(:dispatch_vehicles,
            column: :id,
            name: "dispatch_assignments_vehicle_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :shift_start, :utc_datetime_usec, null: false
      add :shift_end, :utc_datetime_usec, null: false
      add :status, :text, null: false, default: "scheduled"
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:dispatch_assignments, [:dispatch_team_id])
    create index(:dispatch_assignments, [:officer_id])
    create index(:dispatch_assignments, [:shift_start, :shift_end])
  end

  @spec down() :: any()
  def down do
    drop table(:dispatch_assignments)
    drop table(:dispatch_routes)
    drop table(:dispatch_vehicles)
    drop table(:dispatch_officers)
    drop table(:dispatch_teams)
    drop table(:readers)
    drop table(:panels)
    drop table(:sensors)
    drop table(:cameras)
    drop table(:devices)
    drop table(:device_types)
  end
end
