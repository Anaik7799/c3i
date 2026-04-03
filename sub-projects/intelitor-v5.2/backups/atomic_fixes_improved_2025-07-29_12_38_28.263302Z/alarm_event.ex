defmodule Intelitor.Alarms.AlarmEvent do
  @moduledoc """
  Represents a security alarm event in the system.

  AlarmEvents are the core of the alarm processing system, managing the
  lifecycle
  of security incidents from triggering through resolution. They use state
  machines
  to ensure proper workflow and audit trail.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Alarms,
    table: "alarm_events"

  use Intelitor.Multitenancy.TenantResource
  use Intelitor.Tracing.ResourceHelpers

  attributes do
    uuid_primary_key :id

    # Event identification
    attribute :event_code, :string do
      allow_nil? false
      public? true
      constraints max_length: 20
    end

    attribute :event_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :intrusion,
                    :panic,
                    :duress,
                    :fire,
                    :medical,
                    :environmental,
                    :tamper,
                    :trouble,
                    :supervisory,
                    :holdup,
                    :silent
                  ]
    end

    attribute :severity, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
      default :high
    end

    attribute :priority, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 10
      default 5
    end

    # State machine attribute
    attribute :state, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :triggered,
                    :acknowledged,
                    :investigating,
                    :resolved,
                    :false_alarm
                  ]

      default :triggered
    end

    # Location information
    attribute :site_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :zone_id, :uuid do
      public? true
    end

    attribute :device_id, :uuid do
      public? true
    end

    attribute :location_details, :string do
      public? true
      constraints max_length: 500
    end

    # Event details
    attribute :description, :string do
      allow_nil? false
      public? true
      constraints max_length: 1000
    end

    attribute :sia_code, :string do
      public? true
      constraints max_length: 10
    end

    attribute :account_number, :string do
      public? true
      constraints max_length: 16
    end

    attribute :raw_data, :map do
      public? true
      default %{}
    end

    # Response information
    attribute :acknowledged_by, :uuid do
      public? true
    end

    attribute :acknowledged_at, :utc_datetime_usec do
      public? true
    end

    attribute :investigating_by, :uuid do
      public? true
    end

    attribute :investigating_at, :utc_datetime_usec do
      public? true
    end

    attribute :resolved_by, :uuid do
      public? true
    end

    attribute :resolved_at, :utc_datetime_usec do
      public? true
    end

    attribute :resolution_notes, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :false_alarm_reason, :string do
      public? true
      constraints max_length: 500
    end

    # Verification
    attribute :verified?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :verification_method, :atom do
      public? true

      constraints one_of: [
                    :video,
                    :audio,
                    :phone,
                    :dispatch,
                    :sensor_correlation
                  ]
    end

    attribute :verification_details, :string do
      public? true
      constraints max_length: 500
    end

    # Automation
    attribute :auto_acknowledged?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :workflow_template_id, :uuid do
      public? true
    end

    attribute :workflow_state, :map do
      public? true
      default %{}
    end

    # Timing
    attribute :triggered_at, :utc_datetime_usec do
      allow_nil? false
      public? true
      default &DateTime.utc_now/0
    end

    attribute :response_time_seconds, :integer do
      public? true
    end

    attribute :resolution_time_seconds, :integer do
      public? true
    end

    # Related events
    attribute :parent_event_id, :uuid do
      public? true
    end

    attribute :correlated_events, {:array, :uuid} do
      public? true
      default []
    end

    # Correlation and processing metadata
    attribute :correlation_group_id, :uuid do
      public? true
    end

    attribute :correlation_data, :map do
      public? true
      default %{}
    end

    attribute :severity_factors, :map do
      public? true
      default %{}
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    attribute :evidence_data, :map do
      public? true
      default %{}
    end

    # Storm detection
    attribute :storm_suppressed, :boolean do
      public? true
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :site, Intelitor.Sites.Site do
      allow_nil? false
      attribute_public? true
    end

    belongs_to :zone, Intelitor.Sites.Zone do
      attribute_public? true
    end

    belongs_to :device, Intelitor.Devices.Device do
      attribute_public? true
    end

    belongs_to :incident_type, Intelitor.Alarms.IncidentType do
      attribute_public? true
    end

    belongs_to :acknowledged_user, Intelitor.Accounts.User do
      attribute_writable? false
      source_attribute :acknowledged_by
      attribute_public? true
    end

    belongs_to :investigating_user, Intelitor.Accounts.User do
      attribute_writable? false
      source_attribute :investigating_by
      attribute_public? true
    end

    belongs_to :resolved_user, Intelitor.Accounts.User do
      attribute_writable? false
      source_attribute :resolved_by
      attribute_public? true
    end

    belongs_to :workflow_template, Intelitor.Alarms.WorkflowTemplate do
      attribute_public? true
    end

    belongs_to :parent_event, __MODULE__ do
      attribute_public? true
    end

    has_many :child_events, __MODULE__ do
      destination_attribute :parent_event_id
    end

    has_many :responses, Intelitor.Alarms.Response
    has_many :notifications, Intelitor.Alarms.Notification
    has_many :dispatch_logs, Intelitor.Alarms.DispatchLog
  end

  # State transitions implemented as update actions

  actions do
    defaults [:read, :update]

    # Query actions for alarm processing
    read :list_alarm_events do
      argument :filters, :map, allow_nil?: true

      # Use simple filtering - Ash will handle tenant isolation via policies
      prepare build(sort: [triggered_at: :desc])
    end

    read :get_alarm_event do
      get_by [:id]
    end

    read :count_by_state do
      argument :state, :atom do
        allow_nil? false

        constraints one_of: [
                      :triggered,
                      :acknowledged,
                      :investigating,
                      :resolved,
                      :false_alarm
                    ]
      end

      filter expr(state == ^arg(:state))
      prepare build(load: [], select: [:id])
    end

    read :active_alarms do
      filter expr(state not in [:resolved, :false_alarm])
      prepare build(sort: [priority: :desc, triggered_at: :asc])
    end

    read :recent_alarms do
      argument :minutes, :integer, default: 5

      # For now, just sort - we'll handle the time filter in the API layer
      prepare build(sort: [triggered_at: :desc])
    end

    create :create do
      primary? true

      accept [
        :event_code,
        :event_type,
        :severity,
        :priority,
        :site_id,
        :zone_id,
        :device_id,
        :location_details,
        :description,
        :sia_code,
        :account_number,
        :raw_data,
        :incident_type_id,
        :workflow_template_id
      ]

      argument :site_id, :uuid do
        allow_nil? false
      end

      change {Intelitor.Changes.TraceOperation,
              operation_type: :alarm, operation_name: "triggered"}

      change {Intelitor.Changes.TraceOperation,
              operation_type: :business_critical,
              operation_name: "alarm.trigger",
              importance: :critical}

      change {Intelitor.Changes.TraceOperation,
              operation_type: :audit, operation_name: "alarm_triggered"}

      change fn changeset, context ->
        triggered_at = DateTime.utc_now()

        changeset
        |> Ash.Changeset.force_change_attribute(:triggered_at, triggered_at)
        |> Ash.Changeset.force_change_attribute(:state, :triggered)
        |> set_priority_from_type()
      end

      after_action(fn changeset, result, context ->
        # Emit critical alarm telemetry
        severity_level =
          case result.severity do
            :critical -> 4
            :high -> 3
            :medium -> 2
            :low -> 1
          end

        :telemetry.execute(
          [:intelitor, :alarm, :triggered],
          %{
            count: 1,
            severity_level: severity_level,
            priority: result.priority
          },
          %{
            alarm_id: result.id,
            event_type: result.event_type,
            site_id: result.site_id,
            device_id: result.device_id,
            tenant_id: Intelitor.Tracing.extract_tenant_id(context[:actor])
          }
        )

        {:ok, result}
      end)
    end


    update :acknowledge do
      accept [:acknowledged_by]
      require_atomic? false

      argument :acknowledged_by, :uuid do
        allow_nil? false
      end

      change {Intelitor.Changes.TraceOperation,
              operation_type: :alarm, operation_name: "acknowledged"}

      change {Intelitor.Changes.TraceOperation,
              operation_type: :business_critical,
              operation_name: "alarm.acknowledge",
              importance: :high}

      change {Intelitor.Changes.TraceOperation,
              operation_type: :audit, operation_name: "alarm_acknowledged"}

      change fn changeset, context ->
        acknowledged_at = DateTime.utc_now()

        changeset
        |> Ash.Changeset.force_change_attribute(:state, :acknowledged)
        |> Ash.Changeset.force_change_attribute(:acknowledged_at, acknowledged_at)
        |> Ash.Changeset.force_change_attribute(
          :acknowledged_by,
          changeset.arguments.acknowledged_by
        )
        |> calculate_response_time()
      end

      after_action(fn changeset, result, context ->
        response_time = result.response_time_seconds || 0

        :telemetry.execute(
          [:intelitor, :alarm, :acknowledged],
          %{count: 1, response_time_seconds: response_time},
          %{
            alarm_id: result.id,
            acknowledged_by: result.acknowledged_by,
            event_type: result.event_type,
            tenant_id: Intelitor.Tracing.extract_tenant_id(context[:actor])
          }
        )

        {:ok, result}
      end)
    end

    update :begin_investigation do
      require_atomic? false
      accept [:investigating_by]

      argument :investigating_by, :uuid do
        allow_nil? false
      end

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:state, :investigating)
        |> Ash.Changeset.force_change_attribute(:investigating_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(
          :investigating_by,
          changeset.arguments.investigating_by
        )
        |> ensure_acknowledged()
      end
    end

    update :verify do
      require_atomic? false
      accept [:verified?, :verification_method, :verification_details]

      validate attribute_equals(:verified?, false)

      change set_attribute(:verified?, true)
    end

    update :resolve do
      require_atomic? false
      accept [:resolved_by, :resolution_notes]

      argument :resolved_by, :uuid do
        allow_nil? false
      end

      argument :resolution_notes, :string do
        constraints max_length: 2000
      end

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:state, :resolved)
        |> Ash.Changeset.force_change_attribute(:resolved_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(
          :resolved_by,
          changeset.arguments.resolved_by
        )
        |> calculate_resolution_time()
      end
    end

    update :mark_false_alarm do
      require_atomic? false
      accept [:resolved_by, :false_alarm_reason]

      argument :resolved_by, :uuid do
        allow_nil? false
      end

      argument :false_alarm_reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:state, :false_alarm)
        |> Ash.Changeset.force_change_attribute(:resolved_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(
          :resolved_by,
          changeset.arguments.resolved_by
        )
        |> Ash.Changeset.force_change_attribute(
          :false_alarm_reason,
          changeset.arguments.false_alarm_reason
        )
        |> calculate_resolution_time()
      end
    end

    update :reopen do
      require_atomic? false
      accept [:investigating_by]

      argument :investigating_by, :uuid do
        allow_nil? false
      end

      argument :reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      validate attribute_in(:state, [:resolved, :false_alarm])

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:state, :investigating)
        |> Ash.Changeset.force_change_attribute(:investigating_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(
          :investigating_by,
          changeset.arguments.investigating_by
        )
        |> Ash.Changeset.force_change_attribute(:reopened_at, DateTime.utc_now())
      end
    end

    update :correlate_event do
      require_atomic? false
      accept []

      argument :related_event_id, :uuid do
        allow_nil? false
      end

      change fn changeset, _context ->
        current_events = Ash.Changeset.get_attribute(changeset, :correlated_events) || []
        related_id = changeset.arguments.related_event_id

        if related_id in current_events do
          changeset
        else
          Ash.Changeset.force_change_attribute(
            changeset,
            :correlated_events,
            [
              related_id | current_events
            ]
          )
        end
      end
    end

    update :update_severity do
      require_atomic? false
      accept [:severity, :severity_factors]

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(
          :metadata,
          Map.merge(
            Ash.Changeset.get_attribute(
              changeset,
              :metadata
            ) || %{},
            %{
              "severity_updated_at" => DateTime.utc_now(),
              "severity_update_count" =>
                Map.get(
                  Ash.Changeset.get_attribute(changeset, :metadata) || %{},
                  "severity_update_count",
                  0
                ) + 1
            }
          )
        )
      end
    end

    update :update_correlation do
      require_atomic? false
      accept [:correlation_group_id, :parent_event_id, :correlated_events, :correlation_data]
    end

    update :mark_storm_suppressed do
      require_atomic? false
      accept []

      change set_attribute(:storm_suppressed, true)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(
          :metadata,
          Map.merge(
            Ash.Changeset.get_attribute(
              changeset,
              :metadata
            ) || %{},
            %{"storm_suppressed_at" => DateTime.utc_now()}
          )
        )
      end
    end

    destroy :destroy do
      primary? true
      soft? true
    end
  end

  calculations do
    calculate :duration_seconds, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn event ->
              if event.resolved_at do
                DateTime.diff(
                  event.resolved_at,
                  event.triggered_at
                )
              else
                DateTime.diff(DateTime.utc_now(), event.triggered_at)
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :is_active?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn event ->
              event.state not in [:resolved, :false_alarm]
            end
          )

        {:ok, values}
      end
    end

    calculate :requires_dispatch?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn event ->
              event.severity in [:high, :critical] and
                event.event_type in [:intrusion, :panic, :duress, :holdup, :fire, :medical]
            end
          )

        {:ok, values}
      end
    end

    calculate :sla_status, :atom do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn event ->
              # Calculate SLA status based on event type, severity, and response times
              calculate_sla_status(event)
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

    policy action(:create) do
      # System and devices can create alarms
      authorize_if always()
    end

    policy action(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "viewer")
      # Site managers can view their site's alarms
      authorize_if expr(site.site_managers.user_id == ^actor(:id))
    end

    policy action([:acknowledge, :begin_investigation, :verify]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action([:resolve, :mark_false_alarm, :reopen]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      # Require supervisor role for critical alarms
      authorize_if expr(severity != :critical)
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :acknowledge
    define :begin_investigation
    define :verify
    define :resolve
    define :mark_false_alarm
    define :reopen
    define :correlate_event
    define :update_severity
    define :update_correlation
    define :mark_storm_suppressed
    define :list_alarm_events
    define :get_alarm_event
    define :count_by_state
    define :active_alarms
    define :recent_alarms
  end

  postgres do
    table "alarm_events"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :site_id, :state]
      index [:event_type, :severity]
      index [:triggered_at]
      index [:state], where: "state NOT IN ('resolved', 'false_alarm')"
      index [:priority], where: "state = 'triggered'"
      index [:device_id], where: "device_id IS NOT NULL"
      index [:zone_id], where: "zone_id IS NOT NULL"
      index [:parent_event_id], where: "parent_event_id IS NOT NULL"
      index [:verified?], name: "alarm_events_verified_index", where: "verified? = true"

      index [:auto_acknowledged?],
        name: "alarm_events_auto_ack_index",
        where: "auto_acknowledged? = true"
    end
  end

  # Helper functions
  defp calculate_response_time(changeset) do
    triggered_at = Ash.Changeset.get_attribute(changeset, :triggered_at)
    acknowledged_at = Ash.Changeset.get_attribute(changeset, :acknowledged_at)

    if triggered_at && acknowledged_at do
      response_seconds = DateTime.diff(acknowledged_at, triggered_at)

      Ash.Changeset.force_change_attribute(
        changeset,
        :response_time_seconds,
        response_seconds
      )
    else
      changeset
    end
  end

  defp calculate_resolution_time(changeset) do
    triggered_at = Ash.Changeset.get_attribute(changeset, :triggered_at)
    resolved_at = Ash.Changeset.get_attribute(changeset, :resolved_at)

    if triggered_at && resolved_at do
      resolution_seconds = DateTime.diff(resolved_at, triggered_at)

      Ash.Changeset.force_change_attribute(
        changeset,
        :resolution_time_seconds,
        resolution_seconds
      )
    else
      changeset
    end
  end

  defp ensure_acknowledged(changeset) do
    if is_nil(Ash.Changeset.get_attribute(changeset, :acknowledged_at)) do
      changeset
      |> Ash.Changeset.force_change_attribute(:acknowledged_at, DateTime.utc_now())
      |> Ash.Changeset.force_change_attribute(
        :acknowledged_by,
        Ash.Changeset.get_attribute(
          changeset,
          :investigating_by
        )
      )
      |> calculate_response_time()
    else
      changeset
    end
  end

  defp set_priority_from_type(changeset) do
    event_type = Ash.Changeset.get_attribute(changeset, :event_type)
    severity = Ash.Changeset.get_attribute(changeset, :severity)

    priority =
      case {event_type, severity} do
        {type, :critical}
        when type in [:panic, :duress, :holdup, :fire, :medical] ->
          10

        {type, :critical} when type in [:intrusion] ->
          9

        {type, :high} when type in [:panic, :duress, :holdup] ->
          9

        {type, :high} when type in [:fire, :medical] ->
          8

        {type, :high} when type in [:intrusion] ->
          7

        {:tamper, _} ->
          6

        {_, :medium} ->
          5

        {_, :low} ->
          3

        _ ->
          5
      end

    Ash.Changeset.force_change_attribute(changeset, :priority, priority)
  end

  # Calculate SLA status based on event characteristics and response times
  defp calculate_sla_status(event) do
    # Define SLA targets based on event type and severity (in seconds)
    sla_targets = %{
      # Critical alarms must be acknowledged within these times
      # 1 minute
      {[:panic, :duress, :holdup, :fire, :medical], :critical} => 60,
      # 2 minutes
      {[:intrusion], :critical} => 120,
      # 3 minutes
      {[:panic, :duress, :holdup], :high} => 180,
      # 4 minutes
      {[:fire, :medical], :high} => 240,
      # 5 minutes
      {[:intrusion], :high} => 300,
      # 10 minutes
      {[:tamper], :high} => 600,
      # 15 minutes
      {:medium, :any} => 900,
      # 30 minutes
      {:low, :any} => 1800,
      # 15 minutes default
      {:default, :any} => 900
    }

    # Get applicable SLA target
    target_seconds = get_sla_target(event.event_type, event.severity, sla_targets)

    case event.state do
      :triggered ->
        # Check if still within initial response window
        elapsed = DateTime.diff(DateTime.utc_now(), event.triggered_at)
        if elapsed > target_seconds, do: :sla_breach, else: :within_sla

      :acknowledged ->
        # Check acknowledgment response time
        if event.response_time_seconds && event.response_time_seconds > target_seconds do
          :sla_breach
        else
          :within_sla
        end

      state when state in [:investigating, :resolved, :false_alarm] ->
        # For completed events, check final response time
        response_time =
          event.response_time_seconds ||
            (event.acknowledged_at && DateTime.diff(event.acknowledged_at, event.triggered_at)) ||
            DateTime.diff(DateTime.utc_now(), event.triggered_at)

        if response_time > target_seconds, do: :sla_breach, else: :within_sla

      _ ->
        :unknown
    end
  end

  defp get_sla_target(event_type, severity, targets) do
    # Try to find exact match first
    exact_key = {[event_type], severity}

    if Map.has_key?(targets, exact_key) do
      targets[exact_key]
    else
      # Try severity-based match
      severity_key = {severity, :any}

      if Map.has_key?(targets, severity_key) do
        targets[severity_key]
      else
        # Use default
        targets[{:default, :any}]
      end
    end
  end
end
