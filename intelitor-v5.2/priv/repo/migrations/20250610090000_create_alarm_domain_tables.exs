defmodule Indrajaal.Repo.Migrations.CreateAlarmDomainTables do
  @moduledoc """
  Creates database tables for the Alarms domain.

  This migration creates:
  - alarm_events: Core alarm events with state machine
  - incident_types: Alarm type definitions
  - alarm_notifications: Notification records
  - alarm_responses: Response history
  - dispatch_logs: Dispatch coordination
  - workflow_templates: Automation templates
  """

  use Ecto.Migration

  @spec up() :: any()
  def up do
    # Create incident_types table
    create table(:incident_types, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "incident_types_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :code, :text, null: false
      add :category, :text, null: false
      add :priority, :bigint, null: false, default: 5
      add :default_severity, :text, null: false, default: "high"
      add :requires_dispatch?, :boolean, null: false, default: false
      add :auto_acknowledge?, :boolean, null: false, default: false
      add :auto_resolve_minutes, :bigint
      add :sia_codes, {:array, :text}, null: false, default: []
      add :description, :text
      add :response_instructions, :text
      add :active?, :boolean, null: false, default: true
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:incident_types, [:tenant_id, :code], unique: true)
    create index(:incident_types, [:category])
    create index(:incident_types, [:active?], where: "\"active?\" = true")

    # Create workflow_templates table
    create table(:workflow_templates, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "workflow_templates_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :description, :text
      add :trigger_conditions, :map, null: false, default: %{}
      add :steps, {:array, :map}, null: false, default: []
      add :active?, :boolean, null: false, default: true
      add :version, :bigint, null: false, default: 1
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:workflow_templates, [:tenant_id, :name, :version], unique: true)
    create index(:workflow_templates, [:active?], where: "\"active?\" = true")

    # Create alarm_events table
    create table(:alarm_events, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "alarm_events_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :event_code, :text, null: false
      add :event_type, :text, null: false
      add :severity, :text, null: false, default: "high"
      add :priority, :bigint, null: false, default: 5
      add :state, :text, null: false, default: "triggered"

      # Location references
      add :site_id,
          references(:sites,
            column: :id,
            name: "alarm_events_site_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :zone_id,
          references(:zones,
            column: :id,
            name: "alarm_events_zone_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :device_id,
          references(:devices,
            column: :id,
            name: "alarm_events_device_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :location_details, :text

      # Event details
      add :description, :text, null: false
      add :sia_code, :text
      add :account_number, :text
      add :raw_data, :map, default: %{}

      # Response information
      add :acknowledged_by,
          references(:users,
            column: :id,
            name: "alarm_events_acknowledged_by_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :acknowledged_at, :utc_datetime_usec

      add :investigating_by,
          references(:users,
            column: :id,
            name: "alarm_events_investigating_by_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :investigating_at, :utc_datetime_usec

      add :resolved_by,
          references(:users,
            column: :id,
            name: "alarm_events_resolved_by_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :resolved_at, :utc_datetime_usec
      add :resolution_notes, :text
      add :false_alarm_reason, :text

      # Verification
      add :verified?, :boolean, null: false, default: false
      add :verification_method, :text
      add :verification_details, :text

      # Automation
      add :auto_acknowledged?, :boolean, null: false, default: false

      add :workflow_template_id,
          references(:workflow_templates,
            column: :id,
            name: "alarm_events_workflow_template_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :workflow_state, :map, default: %{}

      # Timing
      add :triggered_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :response_time_seconds, :bigint
      add :resolution_time_seconds, :bigint

      # Related events
      add :parent_event_id,
          references(:alarm_events,
            column: :id,
            name: "alarm_events_parent_event_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :correlated_events, {:array, :uuid}, default: []

      # Processing metadata
      add :correlation_group_id, :uuid
      add :correlation_data, :map, default: %{}
      add :severity_factors, :map, default: %{}
      add :metadata, :map, default: %{}
      add :evidence_data, :map, default: %{}
      add :storm_suppressed, :boolean, default: false

      # Type reference
      add :incident_type_id,
          references(:incident_types,
            column: :id,
            name: "alarm_events_incident_type_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:alarm_events, [:tenant_id, :site_id, :state])
    create index(:alarm_events, [:event_type, :severity])
    create index(:alarm_events, [:triggered_at])
    create index(:alarm_events, [:state], where: "state NOT IN ('resolved', 'false_alarm')")
    create index(:alarm_events, [:priority], where: "state = 'triggered'")
    create index(:alarm_events, [:device_id], where: "device_id IS NOT NULL")
    create index(:alarm_events, [:zone_id], where: "zone_id IS NOT NULL")
    create index(:alarm_events, [:parent_event_id], where: "parent_event_id IS NOT NULL")

    create index(:alarm_events, [:verified?],
             name: "alarm_events_verified_index",
             where: "\"verified?\" = true"
           )

    create index(:alarm_events, [:auto_acknowledged?],
             name: "alarm_events_auto_ack_index",
             where: "\"auto_acknowledged?\" = true"
           )

    # Create alarm_notifications table
    create table(:alarm_notifications, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "alarm_notifications_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :alarm_event_id,
          references(:alarm_events,
            column: :id,
            name: "alarm_notifications_alarm_event_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :user_id,
          references(:users,
            column: :id,
            name: "alarm_notifications_user_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :channel, :text, null: false
      add :priority, :text, null: false, default: "normal"
      add :status, :text, null: false, default: "pending"
      add :sent_at, :utc_datetime_usec
      add :delivered_at, :utc_datetime_usec
      add :read_at, :utc_datetime_usec
      add :failed_at, :utc_datetime_usec
      add :failure_reason, :text
      add :retry_count, :bigint, null: false, default: 0
      add :notification_data, :map, default: %{}
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:alarm_notifications, [:alarm_event_id])
    create index(:alarm_notifications, [:user_id])
    create index(:alarm_notifications, [:status])
    create index(:alarm_notifications, [:sent_at], where: "sent_at IS NOT NULL")

    # Create alarm_responses table
    create table(:alarm_responses, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "alarm_responses_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :alarm_event_id,
          references(:alarm_events,
            column: :id,
            name: "alarm_responses_alarm_event_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :user_id,
          references(:users,
            column: :id,
            name: "alarm_responses_user_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :action_type, :text, null: false
      add :action_details, :text
      add :metadata, :map, default: %{}

      add :performed_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:alarm_responses, [:alarm_event_id])
    create index(:alarm_responses, [:user_id])
    create index(:alarm_responses, [:action_type])
    create index(:alarm_responses, [:performed_at])

    # Create dispatch_logs table
    create table(:dispatch_logs, primary_key: false) do
      add :tenant_id,
          references(:tenants,
            column: :id,
            name: "dispatch_logs_tenant_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :alarm_event_id,
          references(:alarm_events,
            column: :id,
            name: "dispatch_logs_alarm_event_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :dispatch_team_id,
          references(:dispatch_teams,
            column: :id,
            name: "dispatch_logs_dispatch_team_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :officer_id,
          references(:dispatch_officers,
            column: :id,
            name: "dispatch_logs_officer_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :status, :text, null: false, default: "pending"
      add :priority, :text, null: false, default: "normal"
      add :dispatched_at, :utc_datetime_usec
      add :arrived_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :cancelled_at, :utc_datetime_usec
      add :cancellation_reason, :text
      add :response_notes, :text
      add :metadata, :map, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:dispatch_logs, [:alarm_event_id])
    create index(:dispatch_logs, [:status])
    create index(:dispatch_logs, [:dispatched_at], where: "dispatched_at IS NOT NULL")
  end

  @spec down() :: any()
  def down do
    drop table(:dispatch_logs)
    drop table(:alarm_responses)
    drop table(:alarm_notifications)
    drop table(:alarm_events)
    drop table(:workflow_templates)
    drop table(:incident_types)
  end
end
