defmodule Indrajaal.Dispatch.Assignment do
  @moduledoc """
  Represents a dispatch assignment linking teams / officers to incidents.

  Assignments track the deployment of resources to specific incidents,
  including response times, status updates, and completion tracking.
  They form the core coordination mechanism for incident response.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Dispatch

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Assignment identification
    attribute :assignment_number, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :incident_id, :uuid do
      public? true
    end

    attribute :alarm_event_id, :uuid do
      public? true
    end

    # Resource assignment
    attribute :team_id, :uuid do
      public? true
    end

    attribute :officer_id, :uuid do
      public? true
    end

    attribute :vehicle_id, :uuid do
      public? true
    end

    attribute :assignment_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :primary_response,
                    :backup,
                    :patrol,
                    :investigation,
                    :supervisor,
                    :specialist,
                    :medical,
                    :transport
                  ]

      default :primary_response
    end

    # Priority and urgency
    attribute :priority, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 10
      default 5
    end

    attribute :urgency, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :normal, :high, :urgent, :emergency]
      default :normal
    end

    # Status tracking
    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :assigned,
                    :acknowledged,
                    :en_route,
                    :on_scene,
                    :investigating,
                    :completed,
                    :cancelled,
                    :transferred
                  ]

      default :assigned
    end

    attribute :substatus, :string do
      public? true
      constraints max_length: 100
    end

    # Time tracking
    attribute :assigned_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :acknowledged_at, :utc_datetime_usec do
      public? true
    end

    attribute :en_route_at, :utc_datetime_usec do
      public? true
    end

    attribute :arrived_at, :utc_datetime_usec do
      public? true
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
    end

    attribute :response_time_seconds, :integer do
      public? true
      constraints min: 0
    end

    attribute :on_scene_duration_seconds, :integer do
      public? true
      constraints min: 0
    end

    # Location details
    attribute :incident_location, :string do
      allow_nil? false
      public? true
      constraints max_length: 500
    end

    attribute :incident_coordinates, :map do
      public? true
      default %{}
    end

    attribute :dispatch_location, :string do
      public? true
      constraints max_length: 500
    end

    attribute :route_id, :uuid do
      public? true
    end

    attribute :estimated_arrival_time, :utc_datetime_usec do
      public? true
    end

    # Assignment details
    attribute :instructions, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :special_instructions, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :_required_equipment, {:array, :string} do
      public? true
      default []
    end

    attribute :hazards, {:array, :string} do
      public? true
      default []
    end

    # Communication
    attribute :radio_channel, :string do
      public? true
      constraints max_length: 50
    end

    attribute :communication_log, {:array, :map} do
      public? true
      default []
    end

    attribute :last_communication, :utc_datetime_usec do
      public? true
    end

    # Outcome and completion
    attribute :outcome, :atom do
      public? true

      constraints one_of: [
                    :resolved,
                    :false_alarm,
                    :unable_to_locate,
                    :referred,
                    :arrested,
                    :transported,
                    :ongoing
                  ]
    end

    attribute :disposition, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :report_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :report_submitted?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :report_number, :string do
      public? true
      constraints max_length: 50
    end

    # Performance metrics
    attribute :customer_satisfaction, :integer do
      public? true
      constraints min: 1, max: 5
    end

    attribute :performance_rating, :integer do
      public? true
      constraints min: 1, max: 10
    end

    attribute :supervisor_review?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :reviewed_by, :uuid do
      public? true
    end

    attribute :review_notes, :string do
      public? true
      constraints max_length: 1000
    end

    # Billing and costs
    attribute :billable?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :billing_rate, :float do
      public? true
      constraints min: 0
    end

    attribute :total_cost, :float do
      public? true
      constraints min: 0
    end

    # Metadata
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
    belongs_to :team, Indrajaal.Dispatch.Team do
      attribute_public? true
    end

    belongs_to :officer, Indrajaal.Dispatch.Officer do
      attribute_public? true
    end

    belongs_to :vehicle, Indrajaal.Dispatch.Vehicle do
      attribute_public? true
    end

    belongs_to :route, Indrajaal.Dispatch.Route do
      attribute_public? true
    end

    belongs_to :alarm_event, Indrajaal.Alarms.AlarmEvent do
      attribute_public? true
    end

    belongs_to :reviewer, Indrajaal.Accounts.User do
      source_attribute :reviewed_by
      attribute_public? true
    end
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :incident_id,
        :alarm_event_id,
        :team_id,
        :officer_id,
        :vehicle_id,
        :assignment_type,
        :priority,
        :urgency,
        :incident_location,
        :incident_coordinates,
        :instructions,
        :special_instructions,
        :_required_equipment,
        :hazards,
        :radio_channel,
        :estimated_arrival_time,
        :report_required?,
        :billable?,
        :billing_rate,
        :metadata
      ]

      change fn changeset, __context ->
        changeset
        |> generate_assignment_number()
        |> Ash.Changeset.force_change_attribute(
          :assigned_at,
          DateTime.utc_now()
        )
        |> Ash.Changeset.force_change_attribute(:status, :assigned)
      end
    end

    update :acknowledge do
      require_atomic? false
      accept []

      validate attribute_equals(:status, :assigned)

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :acknowledged)
        |> Ash.Changeset.force_change_attribute(
          :acknowledged_at,
          DateTime.utc_now()
        )
      end
    end

    update :en_route do
      require_atomic? false
      accept [:dispatch_location, :route_id, :estimated_arrival_time]

      validate attribute_in(:status, [:assigned, :acknowledged])

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :en_route)
        |> Ash.Changeset.force_change_attribute(
          :en_route_at,
          DateTime.utc_now()
        )
      end
    end

    update :arrive do
      require_atomic? false

      accept []

      validate attribute_equals(:status, :en_route)

      change fn changeset, __context ->
        arrival_time = DateTime.utc_now()
        assigned_at = Ash.Changeset.get_attribute(changeset, :assigned_at)

        response_time =
          if assigned_at do
            DateTime.diff(arrival_time, assigned_at)
          else
            nil
          end

        _changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(:status, :on_scene)
          |> Ash.Changeset.force_change_attribute(:arrived_at, arrival_time)

        if response_time do
          Ash.Changeset.force_change_attribute(
            changeset,
            :response_time_seconds,
            response_time
          )
        else
          changeset
        end
      end
    end

    update :complete do
      require_atomic? false

      accept [:outcome, :disposition, :report_number, :customer_satisfaction]

      argument :outcome, :atom do
        allow_nil? false

        constraints one_of: [
                      :resolved,
                      :false_alarm,
                      :unable_to_locate,
                      :referred,
                      :arrested,
                      :transported,
                      :ongoing
                    ]
      end

      validate attribute_in(:status, [:on_scene, :investigating])

      change fn changeset, __context ->
        completion_time = DateTime.utc_now()
        arrived_at = Ash.Changeset.get_attribute(changeset, :arrived_at)

        on_scene_duration =
          if arrived_at do
            DateTime.diff(completion_time, arrived_at)
          else
            nil
          end

        _changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(:status, :completed)
          |> Ash.Changeset.force_change_attribute(
            :completed_at,
            completion_time
          )

        if on_scene_duration do
          Ash.Changeset.force_change_attribute(
            changeset,
            :on_scene_duration_seconds,
            on_scene_duration
          )
        else
          changeset
        end
      end
    end

    update :cancel do
      require_atomic? false

      accept [:disposition]

      argument :reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      validate fn changeset, __context ->
        status = Ash.Changeset.get_attribute(changeset, :status)

        if status in [:completed, :cancelled] do
          {:error, field: :status, message: "cannot cancel assignment in current state"}
        else
          :ok
        end
      end

      change fn changeset, __context ->
        reason = changeset.arguments.reason

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :cancelled)
        |> Ash.Changeset.force_change_attribute(:disposition, reason)
        |> Ash.Changeset.force_change_attribute(
          :completed_at,
          DateTime.utc_now()
        )
      end
    end

    update :transfer do
      require_atomic? false
      accept []

      argument :new_team_id, :uuid
      argument :new_officer_id, :uuid

      argument :transfer_reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      validate fn changeset, __context ->
        status = Ash.Changeset.get_attribute(changeset, :status)

        if status in [:completed, :cancelled] do
          {:error, field: :status, message: "cannot transfer assignment in current state"}
        else
          :ok
        end
      end

      change fn changeset, __context ->
        transfer_reason = changeset.arguments.transfer_reason

        _changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(:status, :transferred)
          |> Ash.Changeset.force_change_attribute(:disposition, transfer_reason)

        # Update assignments if provided
        if new_team_id = changeset.arguments.new_team_id do
          _changeset = Ash.Changeset.force_change_attribute(changeset, :team_id, new_team_id)
        end

        if new_officer_id = changeset.arguments.new_officer_id do
          _changeset =
            Ash.Changeset.force_change_attribute(changeset, :officer_id, new_officer_id)
        end

        changeset
      end
    end

    update :add_communication do
      require_atomic? false
      accept [:communication_log, :last_communication]

      argument :message, :string do
        allow_nil? false
        constraints max_length: 500
      end

      argument :sender, :string do
        allow_nil? false
        constraints max_length: 100
      end

      change fn changeset, __context ->
        log = Ash.Changeset.get_attribute(changeset, :communication_log) || []

        new_entry = %{
          "timestamp" => DateTime.utc_now(),
          "message" => changeset.arguments.message,
          "sender" => changeset.arguments.sender
        }

        changeset
        |> Ash.Changeset.force_change_attribute(
          :communication_log,
          [new_entry | log]
        )
        |> Ash.Changeset.force_change_attribute(
          :last_communication,
          DateTime.utc_now()
        )
      end
    end

    update :submit_report do
      require_atomic? false
      accept [:report_submitted?, :report_number]

      argument :report_number, :string do
        allow_nil? false
        constraints max_length: 50
      end

      validate attribute_equals(:report_required?, true)
      validate attribute_equals(:report_submitted?, false)

      change set_attribute(:report_submitted?, true)
    end

    update :review do
      accept [:performance_rating, :review_notes, :supervisor_review?]
      require_atomic? false

      argument :reviewed_by, :uuid do
        allow_nil? false
      end

      argument :performance_rating, :integer do
        allow_nil? false
        constraints min: 1, max: 10
      end

      validate attribute_equals(:supervisor_review?, false)

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:supervisor_review?, true)
        |> Ash.Changeset.force_change_attribute(
          :reviewed_by,
          changeset.arguments.reviewed_by
        )
      end
    end

    update :calculate_cost do
      require_atomic? false
      accept [:total_cost]

      change fn changeset, __context ->
        billable? = Ash.Changeset.get_attribute(changeset, :billable?)
        billing_rate = Ash.Changeset.get_attribute(changeset, :billing_rate)

        duration =
          Ash.Changeset.get_attribute(
            changeset,
            :on_scene_duration_seconds
          )

        if billable? && billing_rate && duration do
          hours = duration / 3600.0
          cost = billing_rate * hours
          Ash.Changeset.force_change_attribute(changeset, :total_cost, cost)
        else
          changeset
        end
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :is_active?, :boolean do
      calculation fn records, __context ->
        values =
          Enum.map(
            records,
            fn assignment ->
              assignment.status in [
                :assigned,
                :acknowledged,
                :en_route,
                :on_scene,
                :investigating
              ]
            end
          )

        {:ok, values}
      end
    end

    calculate :total_duration_minutes, :integer do
      calculation fn records, __context ->
        values =
          Enum.map(
            records,
            fn assignment ->
              if assignment.assigned_at && assignment.completed_at do
                div(
                  DateTime.diff(
                    assignment.completed_at,
                    assignment.assigned_at
                  ),
                  60
                )
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :is_overdue?, :boolean do
      calculation fn records, __context ->
        values =
          Enum.map(
            records,
            fn assignment ->
              assignment.estimated_arrival_time &&
                DateTime.compare(
                  DateTime.utc_now(),
                  assignment.estimated_arrival_time
                ) == :gt &&
                assignment.status in [:assigned, :acknowledged, :en_route]
            end
          )

        {:ok, values}
      end
    end

    calculate :_requires_supervisor_review?, :boolean do
      calculation fn records, __context ->
        values =
          Enum.map(
            records,
            fn assignment ->
              assignment.status == :completed &&
                !assignment.supervisor_review? &&
                ((assignment.performance_rating &&
                    assignment.performance_rating <
                      7) ||
                   (assignment.customer_satisfaction &&
                      assignment.customer_satisfaction <
                        3))
            end
          )

        {:ok, values}
      end
    end

    calculate :communication_count, :integer do
      calculation fn records, __context ->
        values =
          Enum.map(
            records,
            fn assignment ->
              length(assignment.communication_log || [])
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
      # Assigned officers can read their assignments
      authorize_if expr(officer_id == ^actor(:id))
    end

    policy action(:create) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "dispatcher")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action([:update, :add_communication]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "dispatcher")
      authorize_if actor_attribute_equals(:role, "operator")
      # Assigned officers can update their assignments
      authorize_if expr(officer_id == ^actor(:id))
    end

    policy action([:acknowledge, :en_route, :arrive, :complete]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "dispatcher")
      authorize_if actor_attribute_equals(:role, "operator")
      # Assigned officers can update status
      authorize_if expr(officer_id == ^actor(:id))
    end

    policy action([:cancel, :transfer]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "dispatcher")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end

    policy action(:review) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :acknowledge
    define :en_route
    define :arrive
    define :complete
    define :cancel
    define :transfer
    define :add_communication
    define :submit_report
    define :review
    define :calculate_cost
    define :destroy
  end

  postgres do
    table "dispatch_assignments"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :assignment_number], unique: true
      index [:incident_id], where: "incident_id IS NOT NULL"
      index [:alarm_event_id], where: "alarm_event_id IS NOT NULL"
      index [:team_id], where: "team_id IS NOT NULL"
      index [:officer_id], where: "officer_id IS NOT NULL"
      index [:vehicle_id], where: "vehicle_id IS NOT NULL"
      index [:status]
      index [:priority]
      index [:urgency]
      index [:assigned_at]
      index [:completed_at], where: "completed_at IS NOT NULL"

      index [:supervisor_review?],
        name: "assignments_supervisor_review_index",
        where: "supervisor_review? = false"

      index [:report_required?],
        name: "assignments_report_required_index",
        where: "report_required? = true AND report_submitted? = false"
    end
  end

  # Helper functions
  @spec generate_assignment_number(term()) :: term()
  defp generate_assignment_number(changeset) do
    # Generate assignment number like ASG - 20_251_206 - 001
    date_str =
      Date.utc_today()
      |> Date.to_string()
      |> String.replace("-", "")

    random_suffix =
      1..999
      |> Enum.random()
      |> Integer.to_string()
      |> String.pad_leading(3, "0")

    assignment_number = "ASG-#{date_str}-#{random_suffix}"

    Ash.Changeset.force_change_attribute(
      changeset,
      :assignment_number,
      assignment_number
    )
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Dispatch
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
