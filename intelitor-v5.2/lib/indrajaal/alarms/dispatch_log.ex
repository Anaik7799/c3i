defmodule Indrajaal.Alarms.DispatchLog do
  @moduledoc """
  Tracks dispatch activities and assignments for alarm events.

  DispatchLogs record all dispatch - related activities including team assignments,

  status updates, and coordination between control room and field units.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Alarms

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Log identification
    attribute :alarm_event_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :dispatcher_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :entry_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :assignment,
                    :status_update,
                    :communication,
                    :arrival,
                    :departure,
                    :handoff,
                    :escalation,
                    :cancellation,
                    :note
                  ]
    end

    # Dispatch details
    attribute :dispatch_team_id, :uuid do
      public? true
    end

    attribute :assigned_units, {:array, :string} do
      public? true
      default []
    end

    attribute :dispatch_priority, :atom do
      public? true
      constraints one_of: [:routine, :urgent, :emergency, :critical]
      default :urgent
    end

    # Status and timing
    attribute :status, :atom do
      public? true

      constraints one_of: [
                    :assigned,
                    :acknowledged,
                    :en_route,
                    :on_scene,
                    :investigating,
                    :completed,
                    :cancelled,
                    :unavailable
                  ]
    end

    attribute :eta_minutes, :integer do
      public? true
      constraints min: 1, max: 1440
    end

    attribute :actual_arrival_time, :utc_datetime_usec do
      public? true
    end

    attribute :actual_departure_time, :utc_datetime_usec do
      public? true
    end

    # Communication
    attribute :message, :string do
      allow_nil? false
      public? true
      constraints max_length: 1000
    end

    attribute :communication_channel, :atom do
      public? true
      constraints one_of: [:radio, :phone, :app, :sms, :system]
    end

    attribute :recipient_units, {:array, :string} do
      public? true
      default []
    end

    # Location tracking
    attribute :dispatch_location, :string do
      public? true
      constraints max_length: 500
    end

    attribute :gps_coordinates, :map do
      public? true
      default %{}
    end

    attribute :zone_id, :uuid do
      public? true
    end

    # Handoff and escalation
    attribute :previous_team_id, :uuid do
      public? true
    end

    attribute :next_team_id, :uuid do
      public? true
    end

    attribute :handoff_notes, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :escalation_reason, :string do
      public? true
      constraints max_length: 500
    end

    attribute :escalated_to, :string do
      public? true
      constraints max_length: 100
    end

    # References
    attribute :incident_number, :string do
      public? true
      constraints max_length: 50
    end

    attribute :external_reference, :string do
      public? true
      constraints max_length: 100
    end

    # Metadata
    attribute :metadata, :map do
      public? true
      default %{}
    end

    attribute :acknowledged?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :acknowledged_at, :utc_datetime_usec do
      public? true
    end

    attribute :acknowledged_by_id, :uuid do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :alarm_event, Indrajaal.Alarms.AlarmEvent do
      allow_nil? false
      attribute_public? true
    end

    belongs_to :dispatcher, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_public? true
    end

    belongs_to :acknowledged_by, Indrajaal.Accounts.User do
      attribute_public? true
    end

    # Future relationships
    # belongs_to :dispatch_team, Indrajaal.Dispatch.Team
    # belongs_to :zone, Indrajaal.Sites.Zone
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :alarm_event_id,
        :dispatcher_id,
        :entry_type,
        :dispatch_team_id,
        :assigned_units,
        :dispatch_priority,
        :status,
        :eta_minutes,
        :message,
        :communication_channel,
        :recipient_units,
        :dispatch_location,
        :gps_coordinates,
        :zone_id,
        :incident_number,
        :external_reference,
        :metadata
      ]

      argument :alarm_event_id, :uuid do
        allow_nil? false
      end

      argument :dispatcher_id, :uuid do
        allow_nil? false
      end

      argument :message, :string do
        allow_nil? false
        constraints max_length: 1000
      end
    end

    update :acknowledge do
      require_atomic? false
      accept []

      argument :acknowledged_by_id, :uuid do
        allow_nil? false
      end

      validate attribute_equals(:acknowledged?, false)

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:acknowledged?, true)
        |> Ash.Changeset.force_change_attribute(
          :acknowledged_at,
          DateTime.utc_now()
        )
        |> Ash.Changeset.force_change_attribute(
          :acknowledged_by_id,
          changeset.arguments.acknowledged_by_id
        )
      end
    end

    update :add_handoff do
      require_atomic? false

      accept [:handoff_notes]

      argument :next_team_id, :uuid do
        allow_nil? false
      end

      argument :handoff_notes, :string do
        constraints max_length: 1000
      end

      change fn changeset, __context ->
        current_team = Ash.Changeset.get_attribute(changeset, :dispatch_team_id)

        changeset
        |> Ash.Changeset.force_change_attribute(:previous_team_id, current_team)
        |> Ash.Changeset.force_change_attribute(
          :next_team_id,
          changeset.arguments.next_team_id
        )
        |> Ash.Changeset.force_change_attribute(:entry_type, :handoff)
      end
    end

    update :add_escalation do
      require_atomic? false
      accept [:escalation_reason, :escalated_to]

      argument :escalation_reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      change set_attribute(:entry_type, :escalation)
    end

    update :mark_arrival do
      require_atomic? false

      accept [:actual_arrival_time]

      argument :actual_arrival_time, :utc_datetime_usec do
        allow_nil? false
      end

      change set_attribute(:status, :on_scene)
    end

    update :mark_departure do
      require_atomic? false

      accept [:actual_departure_time]

      argument :actual_departure_time, :utc_datetime_usec do
        allow_nil? false
      end

      validate fn changeset, __context ->
        arrival = Ash.Changeset.get_attribute(changeset, :actual_arrival_time)

        departure =
          Ash.Changeset.get_attribute(
            changeset,
            :actual_departure_time
          )

        if arrival && departure &&
             DateTime.compare(
               departure,
               arrival
             ) == :lt do
          {:error, field: :actual_departure_time, message: "must be after arrival time"}
        else
          :ok
        end
      end

      change set_attribute(:status, :completed)
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :response_time_minutes, :integer do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn log ->
            if log.entry_type == :assignment && log.actual_arrival_time do
              div(DateTime.diff(log.actual_arrival_time, log.inserted_at), 60)
            else
              nil
            end
          end)

        {:ok, values}
      end
    end

    calculate :on_scene_duration_minutes, :integer do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn log ->
            if log.actual_arrival_time && log.actual_departure_time do
              div(DateTime.diff(log.actual_departure_time, log.actual_arrival_time), 60)
            else
              nil
            end
          end)

        {:ok, values}
      end
    end

    calculate :is_active?, :boolean do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn log ->
            log.status in [:assigned, :acknowledged, :en_route, :on_scene, :investigating]
          end)

        {:ok, values}
      end
    end

    calculate :__requires_acknowledgment?, :boolean do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn log ->
            !log.acknowledged? &&
              log.entry_type in [:assignment, :escalation, :handoff]
          end)

        {:ok, values}
      end
    end
  end

  policies do
    bypass always() do
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action(:create) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "dispatcher")
    end

    policy action(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "dispatcher")
      authorize_if actor_attribute_equals(:role, "supervisor")
      authorize_if actor_attribute_equals(:role, "guard")
    end

    policy action([:update, :acknowledge, :mark_arrival, :mark_departure]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "dispatcher")
      # Guards can update their own dispatch logs
      authorize_if expr(dispatch_team_id == ^actor(:team_id))
    end

    policy action([:add_handoff, :add_escalation]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "dispatcher")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :acknowledge
    define :add_handoff
    define :add_escalation
    define :mark_arrival
    define :mark_departure
    define :destroy
  end

  postgres do
    table "dispatch_logs"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :alarm_event_id]
      index [:dispatcher_id]
      index [:dispatch_team_id], where: "dispatch_team_id IS NOT NULL"
      index [:entry_type]
      index [:status]
      index [:dispatch_priority]

      index [:acknowledged?],
        name: "dispatch_logs_acknowledged_index",
        where: "acknowledged? = true"

      index [:zone_id], where: "zone_id IS NOT NULL"
      index [:created_at]
    end
  end
end

# Agent: Worker - 1 (Alarms Domain Agent)
# SOPv5.1 Compliance: ✅ Critical alarm processing and incident response coordin
# Domain: Alarms
# Responsibilities: Alarm processing, incident response, critical system monito
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
