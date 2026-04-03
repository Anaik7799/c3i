defmodule Indrajaal.Maintenance.Schedule do
  @moduledoc """
  Represents recurring maintenance schedules for equipment and facilities.

  Schedules define pr_eventive maintenance programs with recurring patterns,
  automatic work order generation, and compliance tracking. They ensure
  equipment longevity and regulatory compliance through systematic maintenance.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Maintenance

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Schedule identification
    attribute :schedule_name, :string do
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :schedule_code, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    # Equipment and location
    attribute :equipment_id, :uuid do
      public? true
    end

    attribute :site_id, :uuid do
      public? true
    end

    attribute :location_description, :string do
      public? true
      constraints max_length: 500
    end

    # Schedule type and classification
    attribute :schedule_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :time_based,
                    :usage_based,
                    :condition_based,
                    :predictive,
                    :regulatory
                  ]

      default :time_based
    end

    attribute :maintenance_category, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :electrical,
                    :mechanical,
                    :plumbing,
                    :hvac,
                    :security,
                    :network,
                    :software,
                    :structural,
                    :cleaning,
                    :grounds
                  ]

      default :security
    end

    attribute :maintenance_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :inspection,
                    :lubrication,
                    :cleaning,
                    :calibration,
                    :replacement,
                    :testing,
                    :adjustment,
                    :software_update
                  ]

      default :inspection
    end

    # Recurrence pattern
    attribute :recurrence_pattern, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :daily,
                    :weekly,
                    :monthly,
                    :quarterly,
                    :semi_annual,
                    :annual,
                    :biennial,
                    :custom
                  ]

      default :monthly
    end

    attribute :recurrence_interval, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 999
      default 1
    end

    attribute :recurrence_details, :map do
      public? true
      default %{}
    end

    # Usage - based triggers
    attribute :usage_trigger_value, :float do
      public? true
      constraints min: 0
    end

    attribute :usage_trigger_unit, :atom do
      public? true
      constraints one_of: [:hours, :cycles, :distance, :volume, :count]
    end

    attribute :current_usage_value, :float do
      public? true
      constraints min: 0
      default 0.0
    end

    # Condition - based triggers
    attribute :condition_triggers, {:array, :map} do
      public? true
      default []
    end

    attribute :sensor_monitoring?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Date management
    attribute :start_date, :date do
      allow_nil? false
      public? true
    end

    attribute :end_date, :date do
      public? true
    end

    attribute :next_due_date, :date do
      allow_nil? false
      public? true
    end

    attribute :last_completed_date, :date do
      public? true
    end

    attribute :lead_time_days, :integer do
      allow_nil? false
      public? true
      constraints min: 0, max: 365
      default 7
    end

    # Work order template
    attribute :work_order_template, :map do
      public? true
      default %{}
    end

    attribute :estimated_duration_hours, :float do
      public? true
      constraints min: 0
    end

    attribute :_required_skills, {:array, :string} do
      public? true
      default []
    end

    attribute :_required_tools, {:array, :string} do
      public? true
      default []
    end

    attribute :_required_parts, {:array, :map} do
      public? true
      default []
    end

    # Priority and criticality
    attribute :priority, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 10
      default 5
    end

    attribute :criticality, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    attribute :safety_critical?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Compliance and regulatory
    attribute :regulatory_requirement?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :compliance_standards, {:array, :string} do
      public? true
      default []
    end

    attribute :inspection_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :certification_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Cost estimation
    attribute :estimated_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :labor_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :parts_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :external_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :budget_code, :string do
      public? true
      constraints max_length: 50
    end

    # Assignment preferences
    attribute :preferred_technician_id, :uuid do
      public? true
    end

    attribute :preferred_team_id, :uuid do
      public? true
    end

    attribute :vendor_id, :uuid do
      public? true
    end

    attribute :auto_assign?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Execution windows
    attribute :execution_window_start, :time do
      public? true
    end

    attribute :execution_window_end, :time do
      public? true
    end

    attribute :blackout_dates, {:array, :date} do
      public? true
      default []
    end

    attribute :seasonal_adjustment?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Performance tracking
    attribute :total_work_orders, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :completed_work_orders, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :on_time_completion_rate, :float do
      public? true
      constraints min: 0, max: 100
    end

    attribute :average_completion_time_hours, :float do
      public? true
      constraints min: 0
    end

    attribute :average_cost, :float do
      public? true
      constraints min: 0
    end

    # Status and control
    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:draft, :active, :suspended, :completed, :cancelled]
      default :draft
    end

    attribute :auto_generate?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :suspension_reason, :string do
      public? true
      constraints max_length: 500
    end

    # Notifications
    attribute :notification_settings, :map do
      public? true

      default %{
        "advance_days" => 7,
        "overdue_alerts" => true,
        "completion_notifications" => true
      }
    end

    attribute :notification_recipients, {:array, :string} do
      public? true
      default []
    end

    # Documentation
    attribute :procedures, :string do
      public? true
      constraints max_length: 10_000
    end

    attribute :safety_instructions, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :document_urls, {:array, :string} do
      public? true
      default []
    end

    # Environmental factors
    attribute :weather_dependent?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :environmental_conditions, {:array, :string} do
      public? true
      default []
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

    timestamps()
  end

  relationships do
    belongs_to :equipment, Indrajaal.Maintenance.Equipment do
      attribute_public? true
    end

    belongs_to :site, Indrajaal.Sites.Site do
      attribute_public? true
    end

    belongs_to :preferred_technician, Indrajaal.Accounts.User do
      attribute_public? true
    end

    has_many :work_orders, Indrajaal.Maintenance.WorkOrder do
      source_attribute :id
      destination_attribute :parent_schedule_id
    end
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :schedule_name,
        :schedule_code,
        :description,
        :equipment_id,
        :site_id,
        :location_description,
        :schedule_type,
        :maintenance_category,
        :maintenance_type,
        :recurrence_pattern,
        :recurrence_interval,
        :recurrence_details,
        :usage_trigger_value,
        :usage_trigger_unit,
        :condition_triggers,
        :sensor_monitoring?,
        :start_date,
        :end_date,
        :lead_time_days,
        :work_order_template,
        :estimated_duration_hours,
        :_required_skills,
        :_required_tools,
        :_required_parts,
        :priority,
        :criticality,
        :safety_critical?,
        :regulatory_requirement?,
        :compliance_standards,
        :inspection_required?,
        :certification_required?,
        :estimated_cost,
        :labor_cost,
        :parts_cost,
        :external_cost,
        :budget_code,
        :preferred_technician_id,
        :preferred_team_id,
        :vendor_id,
        :auto_assign?,
        :execution_window_start,
        :execution_window_end,
        :blackout_dates,
        :seasonal_adjustment?,
        :notification_settings,
        :notification_recipients,
        :procedures,
        :safety_instructions,
        :weather_dependent?,
        :environmental_conditions,
        :metadata
      ]

      change fn changeset, __context ->
        start_date =
          Ash.Changeset.get_argument_or_attribute(
            changeset,
            :start_date
          )

        next_due = calculate_next_due_date(start_date, changeset)

        changeset
        |> Ash.Changeset.force_change_attribute(:next_due_date, next_due)
        |> Ash.Changeset.force_change_attribute(:status, :draft)
      end
    end

    update :activate do
      require_atomic? false
      accept []

      validate attribute_equals(:status, :draft)

      change set_attribute(:status, :active)
    end

    update :suspend do
      require_atomic? false
      accept [:suspension_reason]

      argument :reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      validate attribute_equals(:status, :active)

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :suspended)
        |> Ash.Changeset.force_change_attribute(
          :suspension_reason,
          changeset.arguments.reason
        )
      end
    end

    update :reactivate do
      require_atomic? false
      accept []

      validate attribute_equals(:status, :suspended)

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :active)
        |> Ash.Changeset.force_change_attribute(:suspension_reason, nil)
      end
    end

    update :complete do
      require_atomic? false
      accept []

      validate attribute_in(:status, [:active, :suspended])

      change set_attribute(:status, :completed)
    end

    update :update_next_due_date do
      require_atomic? false
      accept [:next_due_date]

      argument :next_date, :date do
        allow_nil? false
      end
    end

    update :record_completion do
      require_atomic? false
      accept [:last_completed_date, :completed_work_orders, :total_work_orders]

      argument :completion_date, :date do
        allow_nil? false
      end

      change fn changeset, __context ->
        completion_date = changeset.arguments.completion_date

        completed =
          Ash.Changeset.get_attribute(
            changeset,
            :completed_work_orders
          )

        total = Ash.Changeset.get_attribute(changeset, :total_work_orders)

        # Calculate next due date based on schedule pattern
        next_due = calculate_next_due_date(completion_date, changeset)

        changeset
        |> Ash.Changeset.force_change_attribute(
          :last_completed_date,
          completion_date
        )
        |> Ash.Changeset.force_change_attribute(:next_due_date, next_due)
        |> Ash.Changeset.force_change_attribute(
          :completed_work_orders,
          completed + 1
        )
        |> Ash.Changeset.force_change_attribute(:total_work_orders, total + 1)
      end
    end

    update :update_usage do
      require_atomic? false
      accept [:current_usage_value]

      argument :usage_value, :float do
        allow_nil? false
        constraints min: 0
      end

      validate attribute_equals(:schedule_type, :usage_based)

      change fn changeset, __context ->
        usage_value = changeset.arguments.usage_value

        trigger_value =
          Ash.Changeset.get_attribute(
            changeset,
            :usage_trigger_value
          )

        _changeset =
          Ash.Changeset.force_change_attribute(
            changeset,
            :current_usage_value,
            usage_value
          )

        # Check if usage trigger is met
        if trigger_value && usage_value >= trigger_value do
          # This could trigger work order generation in real implementation
          changeset
        else
          changeset
        end
      end
    end

    update :add_blackout_date do
      require_atomic? false
      accept [:blackout_dates]

      argument :blackout_date, :date do
        allow_nil? false
      end

      change fn changeset, __context ->
        blackouts =
          Ash.Changeset.get_attribute(
            changeset,
            :blackout_dates
          ) || []

        new_date = changeset.arguments.blackout_date

        if new_date in blackouts do
          changeset
        else
          Ash.Changeset.force_change_attribute(
            changeset,
            :blackout_dates,
            [new_date | blackouts]
          )
        end
      end
    end

    update :remove_blackout_date do
      require_atomic? false
      accept [:blackout_dates]

      argument :blackout_date, :date do
        allow_nil? false
      end

      change fn changeset, __context ->
        blackouts =
          Ash.Changeset.get_attribute(
            changeset,
            :blackout_dates
          ) || []

        date_to_remove = changeset.arguments.blackout_date

        updated_blackouts = Enum.reject(blackouts, &(&1 == date_to_remove))

        Ash.Changeset.force_change_attribute(
          changeset,
          :blackout_dates,
          updated_blackouts
        )
      end
    end

    update :update_performance_metrics do
      require_atomic? false

      accept [
        :on_time_completion_rate,
        :average_completion_time_hours,
        :average_cost
      ]

      change fn changeset, __context ->
        completed =
          Ash.Changeset.get_attribute(
            changeset,
            :completed_work_orders
          )

        total = Ash.Changeset.get_attribute(changeset, :total_work_orders)

        if total > 0 do
          completion_rate = completed / total * 100.0

          Ash.Changeset.force_change_attribute(
            changeset,
            :on_time_completion_rate,
            completion_rate
          )
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
    calculate :is_due?, :boolean do
      calculation fn records, __context ->
        today = Date.utc_today()

        values =
          Enum.map(
            records,
            fn schedule ->
              schedule.status == :active &&
                Date.compare(
                  today,
                  schedule.next_due_date
                ) != :lt
            end
          )

        {:ok, values}
      end
    end

    calculate :is_overdue?, :boolean do
      calculation fn records, __context ->
        today = Date.utc_today()

        values =
          Enum.map(
            records,
            fn schedule ->
              schedule.status == :active &&
                Date.compare(
                  today,
                  schedule.next_due_date
                ) == :gt
            end
          )

        {:ok, values}
      end
    end

    calculate :days_until_due, :integer do
      calculation fn records, __context ->
        today = Date.utc_today()

        values =
          Enum.map(records, fn schedule ->
            Date.diff(schedule.next_due_date, today)
          end)

        {:ok, values}
      end
    end

    calculate :usage_percentage, :float do
      calculation fn records, __context ->
        values =
          Enum.map(
            records,
            fn schedule ->
              if schedule.schedule_type == :usage_based && schedule.usage_trigger_value do
                schedule.current_usage_value / schedule.usage_trigger_value *
                  100.0
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :completion_rate, :float do
      calculation fn records, __context ->
        values =
          Enum.map(
            records,
            fn schedule ->
              if schedule.total_work_orders > 0 do
                schedule.completed_work_orders / schedule.total_work_orders *
                  100.0
              else
                nil
              end
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
      authorize_if actor_attribute_equals(:role, "manager")
      authorize_if actor_attribute_equals(:role, "technician")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "manager")
    end

    policy action([:activate, :suspend, :reactivate, :complete]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "manager")
    end

    policy action([:record_completion, :update_usage, :update_performance_metrics]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "manager")
      authorize_if actor_attribute_equals(:role, "technician")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :activate
    define :suspend
    define :reactivate
    define :complete
    define :update_next_due_date
    define :record_completion
    define :update_usage
    define :add_blackout_date
    define :remove_blackout_date
    define :update_performance_metrics
    define :destroy
  end

  postgres do
    table "maintenance_schedules"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :schedule_code], unique: true
      index [:equipment_id], where: "equipment_id IS NOT NULL"
      index [:site_id], where: "site_id IS NOT NULL"

      index [:preferred_technician_id],
        where: "preferred_technician_id IS NOT NULL"

      index [:preferred_team_id], where: "preferred_team_id IS NOT NULL"
      index [:vendor_id], where: "vendor_id IS NOT NULL"
      index [:status]
      index [:schedule_type]
      index [:maintenance_category]
      index [:maintenance_type]
      index [:recurrence_pattern]
      index [:next_due_date]
      index [:criticality]

      index [:safety_critical?],
        name: "schedules_safety_critical_index",
        where: "safety_critical? = true"

      index [:regulatory_requirement?],
        name: "schedules_regulatory_index",
        where: "regulatory_requirement? = true"

      index [:auto_generate?],
        name: "schedules_auto_generate_index",
        where: "auto_generate? = true"
    end
  end

  # Helper functions
  @spec calculate_next_due_date(term(), term()) :: term()
  defp calculate_next_due_date(base_date, changeset) do
    pattern =
      Ash.Changeset.get_argument_or_attribute(
        changeset,
        :recurrence_pattern
      )

    interval =
      Ash.Changeset.get_argument_or_attribute(
        changeset,
        :recurrence_interval
      ) || 1

    case pattern do
      :daily ->
        Date.add(base_date, interval)

      :weekly ->
        Date.add(base_date, interval * 7)

      # Approximate
      :monthly ->
        Date.add(base_date, interval * 30)

      :quarterly ->
        Date.add(base_date, interval * 90)

      :semi_annual ->
        Date.add(base_date, interval * 180)

      :annual ->
        Date.add(base_date, interval * 365)

      :biennial ->
        Date.add(base_date, interval * 730)

      :custom ->
        # Custom recurrence would be calculated based on recurrence_details
        # Default fallback
        Date.add(base_date, 30)

      _ ->
        Date.add(base_date, 30)
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Maintenance
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
