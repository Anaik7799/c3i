defmodule Intelitor.Maintenance.Task do
  @moduledoc """
  Represents individual maintenance tasks within work orders.

  Tasks break down work orders into specific, actionable steps with detailed
  instructions, resource requirements, and progress tracking. They enable
  granular control and monitoring of maintenance activities.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Maintenance,
    table: "maintenance_tasks"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Task identification
    attribute :work_order_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :task_number, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :description, :string do
      allow_nil? false
      public? true
      constraints max_length: 2000
    end

    # Task type and classification
    attribute :task_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :inspection,
                    :cleaning,
                    :lubrication,
                    :adjustment,
                    :replacement,
                    :calibration,
                    :testing,
                    :documentation,
                    :safety_check,
                    :measurement
                  ]

      default :inspection
    end

    attribute :category, :atom do
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

    # Detailed instructions
    attribute :instructions, :string do
      allow_nil? false
      public? true
      constraints max_length: 5000
    end

    attribute :safety_instructions, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :quality_standards, :string do
      public? true
      constraints max_length: 1000
    end

    # Dependencies and sequence
    attribute :sequence_order, :integer do
      allow_nil? false
      public? true
      constraints min: 1
      default 1
    end

    attribute :prerequisite_tasks, {:array, :uuid} do
      public? true
      default []
    end

    attribute :blocking_tasks, {:array, :uuid} do
      public? true
      default []
    end

    attribute :parallel_execution?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    # Time estimation
    attribute :estimated_duration_minutes, :integer do
      allow_nil? false
      public? true
      constraints min: 1
      default 30
    end

    attribute :actual_duration_minutes, :integer do
      public? true
      constraints min: 0
    end

    attribute :complexity_level, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 5
      default 3
    end

    # Resource requirements
    attribute :required_skills, {:array, :string} do
      public? true
      default []
    end

    attribute :required_certifications, {:array, :string} do
      public? true
      default []
    end

    attribute :required_tools, {:array, :string} do
      public? true
      default []
    end

    attribute :required_parts, {:array, :map} do
      public? true
      default []
    end

    attribute :required_materials, {:array, :map} do
      public? true
      default []
    end

    # Assignment
    attribute :assigned_technician_id, :uuid do
      public? true
    end

    attribute :minimum_team_size, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 10
      default 1
    end

    attribute :requires_supervision?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Status and progress
    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :pending,
                    :ready,
                    :in_progress,
                    :waiting_parts,
                    :waiting_approval,
                    :completed,
                    :skipped,
                    :failed,
                    :cancelled
                  ]

      default :pending
    end

    attribute :completion_percentage, :integer do
      allow_nil? false
      public? true
      constraints min: 0, max: 100
      default 0
    end

    attribute :substatus, :string do
      public? true
      constraints max_length: 100
    end

    # Time tracking
    attribute :started_at, :utc_datetime_usec do
      public? true
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
    end

    attribute :paused_duration_minutes, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    # Quality control
    attribute :quality_checkpoints, {:array, :map} do
      public? true
      default []
    end

    attribute :inspection_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :inspection_passed?, :boolean do
      public? true
    end

    attribute :quality_rating, :integer do
      public? true
      constraints min: 1, max: 5
    end

    # Measurements and readings
    attribute :measurement_points, {:array, :map} do
      public? true
      default []
    end

    attribute :readings_taken, {:array, :map} do
      public? true
      default []
    end

    attribute :tolerance_ranges, :map do
      public? true
      default %{}
    end

    attribute :out_of_tolerance?, :boolean do
      public? true
    end

    # Documentation and results
    attribute :work_performed, :string do
      public? true
      constraints max_length: 3000
    end

    attribute :findings, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :issues_encountered, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :recommendations, :string do
      public? true
      constraints max_length: 1000
    end

    # Photo and document evidence
    attribute :photo_urls, {:array, :string} do
      public? true
      default []
    end

    attribute :document_urls, {:array, :string} do
      public? true
      default []
    end

    attribute :evidence_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Safety and environment
    attribute :safety_critical?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :lockout_tagout_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :confined_space?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :hot_work?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :safety_permits, {:array, :string} do
      public? true
      default []
    end

    # Cost tracking
    attribute :estimated_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :actual_cost, :float do
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

    # Failure and retry
    attribute :failure_reason, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :retry_count, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :max_retries, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 3
    end

    # External references
    attribute :procedure_reference, :string do
      public? true
      constraints max_length: 200
    end

    attribute :drawing_reference, :string do
      public? true
      constraints max_length: 200
    end

    attribute :vendor_instructions, :string do
      public? true
      constraints max_length: 1000
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
    belongs_to :work_order, Intelitor.Maintenance.WorkOrder do
      attribute_public? true
    end

    belongs_to :assigned_technician, Intelitor.Accounts.User do
      attribute_public? true
    end
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :work_order_id,
        :task_number,
        :title,
        :description,
        :task_type,
        :category,
        :instructions,
        :safety_instructions,
        :quality_standards,
        :sequence_order,
        :prerequisite_tasks,
        :blocking_tasks,
        :parallel_execution?,
        :estimated_duration_minutes,
        :complexity_level,
        :required_skills,
        :required_certifications,
        :required_tools,
        :required_parts,
        :required_materials,
        :minimum_team_size,
        :requires_supervision?,
        :quality_checkpoints,
        :inspection_required?,
        :measurement_points,
        :tolerance_ranges,
        :evidence_required?,
        :safety_critical?,
        :lockout_tagout_required?,
        :confined_space?,
        :hot_work?,
        :safety_permits,
        :estimated_cost,
        :max_retries,
        :procedure_reference,
        :drawing_reference,
        :vendor_instructions,
        :metadata
      ]
    end


    update :assign do
      require_atomic? false
      accept [:assigned_technician_id]

      argument :technician_id, :uuid do
        allow_nil? false
      end

      validate attribute_in(:status, [:pending, :ready])
    end

    update :make_ready do
      require_atomic? false
      accept []

      validate attribute_equals(:status, :pending)

      # Check prerequisites are completed
      validate fn changeset, context ->
        work_order_id = Ash.Changeset.get_attribute(changeset, :work_order_id)
        prerequisite_ids = Ash.Changeset.get_attribute(changeset, :prerequisite_tasks) || []

        if Enum.empty?(prerequisite_ids) do
          :ok
        else
          # In real implementation, would check if prerequisites are completed
          :ok
        end
      end

      change set_attribute(:status, :ready)
    end

    update :start do
      require_atomic? false
      accept [:started_at]

      validate attribute_equals(:status, :ready)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :in_progress)
        |> Ash.Changeset.force_change_attribute(:started_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:completion_percentage, 0)
      end
    end

    update :update_progress do
      require_atomic? false
      accept [:completion_percentage]

      argument :percentage, :integer do
        allow_nil? false
        constraints min: 0, max: 100
      end

      validate attribute_equals(:status, :in_progress)
    end

    update :pause do
      require_atomic? false
      accept []

      argument :reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      validate attribute_equals(:status, :in_progress)

      change fn changeset, _context ->
        reason = changeset.arguments.reason

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :waiting_parts)
        |> Ash.Changeset.force_change_attribute(:substatus, reason)
      end
    end

    update :resume do
      require_atomic? false
      accept []

      validate attribute_in(:status, [:waiting_parts, :waiting_approval])

      change set_attribute(:status, :in_progress)
    end

    update :complete do
      require_atomic? false
      accept [
        :work_performed,
        :findings,
        :issues_encountered,
        :recommendations,
        :actual_cost,
        :labor_cost,
        :parts_cost,
        :quality_rating
      ]

      argument :work_performed, :string do
        allow_nil? false
        constraints max_length: 3000
      end

      validate attribute_equals(:status, :in_progress)

      change fn changeset, _context ->
        completion_time = DateTime.utc_now()
        started_at = Ash.Changeset.get_attribute(changeset, :started_at)

        actual_duration =
          if started_at do
            div(DateTime.diff(completion_time, started_at), 60)
          else
            nil
          end

        changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(:status, :completed)
          |> Ash.Changeset.force_change_attribute(:completed_at, completion_time)
          |> Ash.Changeset.force_change_attribute(:completion_percentage, 100)

        if actual_duration do
          Ash.Changeset.force_change_attribute(
            changeset,
            :actual_duration_minutes,
            actual_duration
          )
        else
          changeset
        end
      end
    end

    update :fail do
      require_atomic? false
      accept [:failure_reason, :retry_count]

      argument :failure_reason, :string do
        allow_nil? false
        constraints max_length: 1000
      end

      validate attribute_equals(:status, :in_progress)

      change fn changeset, _context ->
        reason = changeset.arguments.failure_reason
        retry_count = Ash.Changeset.get_attribute(changeset, :retry_count)
        max_retries = Ash.Changeset.get_attribute(changeset, :max_retries)

        changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(:failure_reason, reason)
          |> Ash.Changeset.force_change_attribute(:retry_count, retry_count + 1)

        if retry_count + 1 >= max_retries do
          Ash.Changeset.force_change_attribute(changeset, :status, :failed)
        else
          Ash.Changeset.force_change_attribute(changeset, :status, :ready)
        end
      end
    end

    update :skip do
      require_atomic? false
      accept []

      argument :reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      validate attribute_in(:status, [:pending, :ready])

      change fn changeset, _context ->
        reason = changeset.arguments.reason

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :skipped)
        |> Ash.Changeset.force_change_attribute(:substatus, reason)
      end
    end

    update :cancel do
      require_atomic? false
      accept []

      argument :reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      validate fn changeset, _context ->
        status = Ash.Changeset.get_attribute(changeset, :status)

        if status in [:completed, :failed, :cancelled] do
          {:error, field: :status, message: "cannot cancel task in current state"}
        else
          :ok
        end
      end

      change fn changeset, _context ->
        reason = changeset.arguments.reason

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :cancelled)
        |> Ash.Changeset.force_change_attribute(:substatus, reason)
      end
    end

    update :add_reading do
      require_atomic? false
      accept [:readings_taken]

      argument :measurement_point, :string do
        allow_nil? false
        constraints max_length: 100
      end

      argument :value, :float do
        allow_nil? false
      end

      argument :unit, :string do
        allow_nil? false
        constraints max_length: 20
      end

      change fn changeset, _context ->
        readings = Ash.Changeset.get_attribute(changeset, :readings_taken) || []

        new_reading = %{
          "measurement_point" => changeset.arguments.measurement_point,
          "value" => changeset.arguments.value,
          "unit" => changeset.arguments.unit,
          "timestamp" => DateTime.utc_now()
        }

        Ash.Changeset.force_change_attribute(
          changeset,
          :readings_taken,
          [new_reading | readings]
        )
      end
    end

    update :add_photo do
      require_atomic? false
      accept [:photo_urls]

      argument :photo_url, :string do
        allow_nil? false
        constraints max_length: 500
      end

      # Add photo URL to the list
      change fn changeset, _context ->
        photos = Ash.Changeset.get_attribute(changeset, :photo_urls) || []
        new_url = Ash.Changeset.get_argument(changeset, :photo_url)

        if length(photos) >= 50 do
          Ash.Changeset.add_error(changeset,
            field: :photo_urls,
            message: "Maximum 50 photos allowed"
          )
        else
          Ash.Changeset.force_change_attribute(changeset, :photo_urls, [new_url | photos])
        end
      end
    end

    update :record_inspection do
      require_atomic? false
      accept [:inspection_passed?]

      argument :passed?, :boolean do
        allow_nil? false
      end

      argument :inspector, :string do
        allow_nil? false
        constraints max_length: 100
      end

      validate attribute_equals(:inspection_required?, true)

      change fn changeset, _context ->
        passed? = changeset.arguments.passed?
        inspector = changeset.arguments.inspector

        inspection_data = %{
          "inspector" => inspector,
          "inspected_at" => DateTime.utc_now(),
          "passed" => passed?
        }

        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        updated_metadata = Map.put(metadata, "inspection", inspection_data)

        changeset
        |> Ash.Changeset.force_change_attribute(:inspection_passed?, passed?)
        |> Ash.Changeset.force_change_attribute(:metadata, updated_metadata)
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :is_ready_to_start?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn task ->
            task.status == :ready &&
              (is_nil(task.assigned_technician_id) || !is_nil(task.assigned_technician_id))

            # In real implementation, would check prerequisite completion
          end)

        {:ok, values}
      end
    end

    calculate :duration_variance_minutes, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn task ->
            if task.actual_duration_minutes && task.estimated_duration_minutes do
              task.actual_duration_minutes - task.estimated_duration_minutes
            else
              nil
            end
          end)

        {:ok, values}
      end
    end

    calculate :cost_variance, :float do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn task ->
            if task.actual_cost && task.estimated_cost do
              task.actual_cost - task.estimated_cost
            else
              nil
            end
          end)

        {:ok, values}
      end
    end

    calculate :is_blocked?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn task ->
            !Enum.empty?(task.prerequisite_tasks || []) &&
              task.status in [:pending, :ready]

            # In real implementation, would check if prerequisites are incomplete
          end)

        {:ok, values}
      end
    end

    calculate :evidence_complete?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn task ->
            if task.evidence_required? do
              !Enum.empty?(task.photo_urls || []) || !Enum.empty?(task.document_urls || [])
            else
              true
            end
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
      authorize_if actor_attribute_equals(:role, "manager")
      authorize_if actor_attribute_equals(:role, "technician")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "manager")
    end

    policy action([:assign, :make_ready]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "manager")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end

    policy action([
             :start,
             :update_progress,
             :pause,
             :resume,
             :complete,
             :fail,
             :add_reading,
             :add_photo
           ]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "manager")
      authorize_if actor_attribute_equals(:role, "technician")
      # Assigned technician can update their tasks
      authorize_if expr(assigned_technician_id == ^actor(:id))
    end

    policy action(:record_inspection) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "inspector")
      authorize_if actor_attribute_equals(:role, "manager")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :assign
    define :make_ready
    define :start
    define :update_progress
    define :pause
    define :resume
    define :complete
    define :fail
    define :skip
    define :cancel
    define :add_reading
    define :add_photo
    define :record_inspection
    define :destroy
  end

  postgres do
    table "maintenance_tasks"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :work_order_id, :task_number], unique: true
      index [:work_order_id]
      index [:assigned_technician_id], where: "assigned_technician_id IS NOT NULL"
      index [:status]
      index [:task_type]
      index [:category]
      index [:sequence_order]

      index [:safety_critical?],
        name: "tasks_safety_critical_index",
        where: "safety_critical? = true"

      index [:inspection_required?],
        name: "tasks_inspection_required_index",
        where: "inspection_required? = true"

      index [:evidence_required?],
        name: "tasks_evidence_required_index",
        where: "evidence_required? = true"

      index [:completion_percentage]
      index [:started_at]
      index [:completed_at], where: "completed_at IS NOT NULL"
    end
  end
end
