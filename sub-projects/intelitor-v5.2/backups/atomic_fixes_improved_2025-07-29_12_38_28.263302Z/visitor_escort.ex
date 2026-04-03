defmodule Intelitor.VisitorManagement.VisitorEscort do
  @moduledoc """
  Escort assignments and tracking for visitors requiring supervision.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.VisitorManagement,
    table: "visitor_escorts"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :escort_status, :atom do
      constraints one_of: [
                    :assigned,
                    :active,
                    :completed,
                    :cancelled,
                    :emergency_terminated
                  ]

      default :assigned
    end

    attribute :escort_type, :atom do
      constraints one_of: [
                    :continuous,
                    :intermittent,
                    :area_specific,
                    :emergency_only
                  ]

      default :continuous
    end

    attribute :start_time, :utc_datetime
    attribute :end_time, :utc_datetime

    attribute :planned_start_time, :utc_datetime do
      allow_nil? false
    end

    attribute :planned_end_time, :utc_datetime do
      allow_nil? false
    end

    attribute :escort_areas, {:array, :uuid} do
      default []
    end

    attribute :escort_responsibilities, {:array, :string} do
      default []
    end

    attribute :special_instructions, :string do
      constraints max_length: 1000
    end

    attribute :visitor_briefing_completed, :boolean do
      default false
    end

    attribute :security_briefing_completed, :boolean do
      default false
    end

    attribute :escort_notes, :string do
      constraints max_length: 2000
    end

    attribute :incidents_reported, :integer do
      default 0
    end

    attribute :compliance_violations, :integer do
      default 0
    end

    attribute :emergency_procedures_followed, :boolean do
      default false
    end

    attribute :handover_notes, :string do
      constraints max_length: 1000
    end

    attribute :performance_rating, :atom do
      constraints one_of: [
                    :excellent,
                    :good,
                    :satisfactory,
                    :needs_improvement,
                    :unsatisfactory
                  ]
    end

    timestamps()
  end

  relationships do
    belongs_to :visitor, Intelitor.VisitorManagement.Visitor do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :visit_request, Intelitor.VisitorManagement.VisitRequest do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :primary_escort, Intelitor.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :backup_escort, Intelitor.Accounts.User do
      attribute_writable? true
    end

    belongs_to :assigned_by, Intelitor.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :relieved_by_escort, Intelitor.Accounts.User do
      attribute_writable? true
    end
  end

  calculations do
    calculate :escort_duration_hours, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case {record.end_time, record.start_time} do
            {end_time, start_time}
            when not is_nil(end_time) and not is_nil(start_time) ->
              diff_seconds = DateTime.diff(end_time, start_time, :second)
              Decimal.div(diff_seconds, 3600)

            _ ->
              nil
          end
        end)
      end
    end

    calculate :is_overrun, :boolean do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          case record.escort_status do
            status when status in [:assigned, :active] ->
              DateTime.compare(now, record.planned_end_time) == :gt

            _ ->
              false
          end
        end)
      end
    end

    calculate :is_currently_active, :boolean do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          record.escort_status == :active &&
            not is_nil(record.start_time) &&
            DateTime.compare(now, record.start_time) != :lt &&
            (is_nil(record.end_time) ||
               DateTime.compare(now, record.end_time) == :lt)
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    create :assign_escort do
      argument :visitor_id, :uuid do
        allow_nil? false
      end

      argument :visit_request_id, :uuid do
        allow_nil? false
      end

      argument :primary_escort_id, :uuid do
        allow_nil? false
      end

      argument :assigned_by_id, :uuid do
        allow_nil? false
      end

      argument :planned_start_time, :utc_datetime do
        allow_nil? false
      end

      argument :planned_end_time, :utc_datetime do
        allow_nil? false
      end

      argument :escort_type, :atom do
        allow_nil? false
      end

      change set_attribute(:visitor_id, arg(:visitor_id))
      change set_attribute(:visit_request_id, arg(:visit_request_id))
      change set_attribute(:primary_escort_id, arg(:primary_escort_id))
      change set_attribute(:assigned_by_id, arg(:assigned_by_id))
      change set_attribute(:planned_start_time, arg(:planned_start_time))
      change set_attribute(:planned_end_time, arg(:planned_end_time))
      change set_attribute(:escort_type, arg(:escort_type))
    end

    update :start_escort do
      require_atomic? false
      change set_attribute(:escort_status, :active)
      change set_attribute(:start_time, &DateTime.utc_now/0)
    end

    update :complete_escort do
      require_atomic? false
      argument :completion_notes, :string
      argument :performance_rating, :atom

      change set_attribute(:escort_status, :completed)
      change set_attribute(:end_time, &DateTime.utc_now/0)
      change set_attribute(:escort_notes, arg(:completion_notes))
      change set_attribute(:performance_rating, arg(:performance_rating))
    end

    update :cancel_escort do
      require_atomic? false
      argument :cancellation_reason, :string do
        allow_nil? false
      end

      change set_attribute(:escort_status, :cancelled)
      change set_attribute(:escort_notes, arg(:cancellation_reason))
    end

    update :emergency_terminate do
      require_atomic? false
      argument :emergency_reason, :string do
        allow_nil? false
      end

      change set_attribute(:escort_status, :emergency_terminated)
      change set_attribute(:end_time, &DateTime.utc_now/0)
      change set_attribute(:emergency_procedures_followed, true)
      change set_attribute(:escort_notes, arg(:emergency_reason))
    end

    update :assign_backup_escort do
      require_atomic? false
      argument :backup_escort_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:backup_escort_id, arg(:backup_escort_id))
    end

    update :handover_escort do
      require_atomic? false
      argument :relieved_by_escort_id, :uuid do
        allow_nil? false
      end

      argument :handover_notes, :string do
        allow_nil? false
      end

      change set_attribute(:relieved_by_escort_id, arg(:relieved_by_escort_id))
      change set_attribute(:handover_notes, arg(:handover_notes))
    end

    update :complete_briefings do
      require_atomic? false
      argument :visitor_briefing, :boolean do
        allow_nil? false
      end

      argument :security_briefing, :boolean do
        allow_nil? false
      end

      change set_attribute(:visitor_briefing_completed, arg(:visitor_briefing))
      change set_attribute(:security_briefing_completed, arg(:security_briefing))
    end

    update :report_incident do
      require_atomic? false
      argument :incident_details, :string do
        allow_nil? false
      end

      change fn changeset, _ ->
        current_incidents = changeset.data.incidents_reported || 0
        current_notes = changeset.data.escort_notes || ""

        incident_details =
          Ash.Changeset.get_argument(changeset, :incident_details)

        updated_notes =
          if current_notes == "" do
            "INCIDENT: #{incident_details}"
          else
            "#{current_notes}\n\nINCIDENT: #{incident_details}"
          end

        changeset
        |> Ash.Changeset.change_attribute(
          :incidents_reported,
          current_incidents + 1
        )
        |> Ash.Changeset.change_attribute(:escort_notes, updated_notes)
      end
    end

    update :report_compliance_violation do
      require_atomic? false
      argument :violation_details, :string do
        allow_nil? false
      end

      change fn changeset, _ ->
        current_violations = changeset.data.compliance_violations || 0
        current_notes = changeset.data.escort_notes || ""

        violation_details =
          Ash.Changeset.get_argument(changeset, :violation_details)

        updated_notes =
          if current_notes == "" do
            "COMPLIANCE VIOLATION: #{violation_details}"
          else
            "#{current_notes}\n\nCOMPLIANCE VIOLATION: #{violation_details}"
          end

        changeset
        |> Ash.Changeset.change_attribute(:compliance_violations, current_violations + 1)
        |> Ash.Changeset.change_attribute(:escort_notes, updated_notes)
      end
    end

    update :set_escort_areas do
      require_atomic? false

      argument :areas, {:array, :uuid} do
        allow_nil? false
      end

      change set_attribute(:escort_areas, arg(:areas))
    end

    update :add_responsibilities do
      require_atomic? false
      argument :responsibilities, {:array, :string} do
        allow_nil? false
      end

      change set_attribute(:escort_responsibilities, arg(:responsibilities))
    end
  end

  validations do
    validate compare(:planned_end_time, greater_than: :planned_start_time),
      message: "Planned end time must be after planned start time"
  end

  code_interface do
    define :create
    define :assign_escort
    define :start_escort
    define :complete_escort
    define :cancel_escort
    define :emergency_terminate
    define :assign_backup_escort
    define :handover_escort
    define :complete_briefings
    define :report_incident
    define :report_compliance_violation
    define :set_escort_areas
    define :add_responsibilities
  end

  postgres do
    table "visitor_escorts"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :visitor_id]
      index [:tenant_id, :visit_request_id]
      index [:tenant_id, :primary_escort_id]
      index [:tenant_id, :backup_escort_id], where: "backup_escort_id IS NOT NULL"
      index [:tenant_id, :escort_status]
      index [:tenant_id, :escort_type]
      index [:tenant_id, :planned_start_time]
      index [:tenant_id, :planned_end_time]
      index [:tenant_id, :start_time], where: "start_time IS NOT NULL"
      index [:tenant_id, :incidents_reported], where: "incidents_reported > 0"
    end
  end
end
