defmodule Indrajaal.GuardTour.TourExecution do
  @moduledoc """
  Individual patrol tour execution instances with real - time tracking.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.GuardTour

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :execution_status, :atom do
      constraints one_of: [:scheduled, :in_progress, :completed, :aborted, :overdue]
      default :scheduled
    end

    attribute :started_at, :utc_datetime
    attribute :completed_at, :utc_datetime

    attribute :scheduled_start, :utc_datetime do
      allow_nil? false
    end

    attribute :actual_duration, :integer
    attribute :expected_duration, :integer

    attribute :completion_percentage, :decimal do
      constraints min: 0, max: 100
      default 0
    end

    attribute :checkpoints_completed, :integer do
      default 0
    end

    attribute :checkpoints_missed, :integer do
      default 0
    end

    attribute :notes, :string do
      constraints max_length: 1000
    end

    timestamps()
  end

  relationships do
    belongs_to :route, Indrajaal.GuardTour.TourRoute do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :schedule, Indrajaal.GuardTour.TourSchedule do
      attribute_writable? true
    end

    belongs_to :assigned_guard, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    has_many :checkpoint_scans, Indrajaal.GuardTour.CheckpointScan do
      destination_attribute :execution_id
    end

    has_many :tour_exceptions, Indrajaal.GuardTour.TourException do
      destination_attribute :execution_id
    end

    has_one :tour_report, Indrajaal.GuardTour.TourReport do
      destination_attribute :execution_id
    end
  end

  calculations do
    calculate :is_overdue, :boolean do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          case record.execution_status do
            status when status in [:scheduled, :in_progress] ->
              DateTime.diff(now, record.scheduled_start, :minute) > 30

            _ ->
              false
          end
        end)
      end
    end

    calculate :delay_minutes, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          if record.started_at && record.scheduled_start do
            DateTime.diff(record.started_at, record.scheduled_start, :minute)
          else
            nil
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    update :start_tour do
      require_atomic? false

      argument :guard_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:execution_status, :in_progress)
      change set_attribute(:started_at, &DateTime.utc_now/0)
      change set_attribute(:assigned_guard_id, arg(:guard_id))
    end

    update :complete_tour do
      require_atomic? false
      change set_attribute(:execution_status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)

      change fn changeset, _ ->
        if changeset.data.started_at do
          duration = DateTime.diff(DateTime.utc_now(), changeset.data.started_at, :minute)
          Ash.Changeset.change_attribute(changeset, :actual_duration, duration)
        else
          changeset
        end
      end
    end

    update :abort_tour do
      require_atomic? false

      argument :reason, :string do
        allow_nil? false
      end

      change set_attribute(:execution_status, :aborted)
      change set_attribute(:notes, arg(:reason))
    end
  end

  code_interface do
    define :create
    define :start_tour
    define :complete_tour
    define :abort_tour
  end

  postgres do
    table "tour_executions"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :execution_status]
      index [:tenant_id, :scheduled_start]
      index [:tenant_id, :assigned_guard_id]
      index [:tenant_id, :route_id, :started_at]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
