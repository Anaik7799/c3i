defmodule Intelitor.Maintenance.WorkOrder do
  @moduledoc """
  Represents maintenance work orders for equipment and facilities.

  Work orders are the primary mechanism for requesting, scheduling, and tracking
  maintenance activities. They include resource allocation, progress tracking,
  cost management, and quality assurance processes.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Maintenance,
    table: "maintenance_work_orders"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Work order identification
    attribute :work_order_number, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
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

    # Work order type and classification
    attribute :work_order_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :preventive,
                    :corrective,
                    :emergency,
                    :inspection,
                    :installation,
                    :upgrade,
                    :replacement,
                    :calibration
                  ]

      default :corrective
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

    attribute :subcategory, :string do
      public? true
      constraints max_length: 100
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

    attribute :safety_critical?, :boolean do
      allow_nil? false
      public? true
      default false
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

    attribute :area_coordinates, :map do
      public? true
      default %{}
    end

    # Scheduling
    attribute :requested_date, :date do
      public? true
    end

    attribute :scheduled_start, :utc_datetime_usec do
      public? true
    end

    attribute :scheduled_end, :utc_datetime_usec do
      public? true
    end

    attribute :estimated_duration_hours, :float do
      public? true
      constraints min: 0
    end

    # Assignment and resources
    attribute :assigned_technician_id, :uuid do
      public? true
    end

    attribute :assigned_team_id, :uuid do
      public? true
    end

    attribute :required_skills, {:array, :string} do
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

    # Status tracking
    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :draft,
                    :requested,
                    :approved,
                    :scheduled,
                    :assigned,
                    :in_progress,
                    :on_hold,
                    :completed,
                    :cancelled,
                    :rejected
                  ]

      default :draft
    end

    attribute :substatus, :string do
      public? true
      constraints max_length: 100
    end

    # Time tracking
    attribute :created_date, :date do
      allow_nil? false
      public? true
    end

    attribute :approved_at, :utc_datetime_usec do
      public? true
    end

    attribute :started_at, :utc_datetime_usec do
      public? true
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
    end

    attribute :actual_duration_hours, :float do
      public? true
      constraints min: 0
    end

    # Financial information
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

    attribute :external_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :budget_code, :string do
      public? true
      constraints max_length: 50
    end

    # Quality and compliance
    attribute :quality_rating, :integer do
      public? true
      constraints min: 1, max: 5
    end

    attribute :compliance_required?, :boolean do
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

    attribute :inspection_passed?, :boolean do
      public? true
    end

    # Documentation
    attribute :work_performed, :string do
      public? true
      constraints max_length: 5000
    end

    attribute :materials_used, {:array, :map} do
      public? true
      default []
    end

    attribute :findings, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :recommendations, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :warranty_info, :map do
      public? true
      default %{}
    end

    # Safety and environment
    attribute :safety_precautions, {:array, :string} do
      public? true
      default []
    end

    attribute :environmental_impact, :atom do
      public? true
      constraints one_of: [:none, :low, :medium, :high]
      default :none
    end

    attribute :hazards_identified, {:array, :string} do
      public? true
      default []
    end

    # External vendors
    attribute :vendor_id, :uuid do
      public? true
    end

    attribute :vendor_contact, :string do
      public? true
      constraints max_length: 200
    end

    attribute :external_work_order, :string do
      public? true
      constraints max_length: 100
    end

    # Communication and updates
    attribute :communication_log, {:array, :map} do
      public? true
      default []
    end

    attribute :photo_urls, {:array, :string} do
      public? true
      default []
    end

    attribute :document_urls, {:array, :string} do
      public? true
      default []
    end

    # Recurring maintenance
    attribute :recurring?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :parent_schedule_id, :uuid do
      public? true
    end

    attribute :next_occurrence_date, :date do
      public? true
    end

    # Performance metrics
    attribute :response_time_hours, :float do
      public? true
      constraints min: 0
    end

    attribute :completion_rating, :integer do
      public? true
      constraints min: 1, max: 10
    end

    attribute :customer_satisfaction, :integer do
      public? true
      constraints min: 1, max: 5
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
    belongs_to :equipment, Intelitor.Maintenance.Equipment do
      attribute_public? true
    end

    belongs_to :site, Intelitor.Sites.Site do
      attribute_public? true
    end

    belongs_to :assigned_technician, Intelitor.Accounts.User do
      attribute_public? true
    end

    belongs_to :parent_schedule, Intelitor.Maintenance.Schedule do
      attribute_public? true
    end

    has_many :tasks, Intelitor.Maintenance.Task
    has_many :service_records, Intelitor.Maintenance.ServiceRecord
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :title,
        :description,
        :work_order_type,
        :category,
        :subcategory,
        :priority,
        :urgency,
        :safety_critical?,
        :equipment_id,
        :site_id,
        :location_description,
        :area_coordinates,
        :requested_date,
        :estimated_duration_hours,
        :required_skills,
        :required_tools,
        :required_parts,
        :estimated_cost,
        :budget_code,
        :compliance_required?,
        :compliance_standards,
        :safety_precautions,
        :environmental_impact,
        :vendor_id,
        :vendor_contact,
        :recurring?,
        :parent_schedule_id,
        :metadata
      ]

      change fn changeset, _context ->
        changeset
        |> generate_work_order_number()
        |> Ash.Changeset.force_change_attribute(:created_date, Date.utc_today())
        |> Ash.Changeset.force_change_attribute(:status, :draft)
      end
    end


    update :submit do
      accept []
      require_atomic? false

      validate attribute_equals(:status, :draft)

      change set_attribute(:status, :requested)
    end

    update :approve do
      require_atomic? false
      accept [:approved_at]

      validate attribute_equals(:status, :requested)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :approved)
        |> Ash.Changeset.force_change_attribute(:approved_at, DateTime.utc_now())
      end
    end

    update :reject do
      require_atomic? false
      accept []

      argument :reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      validate attribute_equals(:status, :requested)

      change fn changeset, _context ->
        reason = changeset.arguments.reason

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :rejected)
        |> Ash.Changeset.force_change_attribute(:substatus, reason)
      end
    end

    update :schedule do
      require_atomic? false
      accept [:scheduled_start, :scheduled_end]

      argument :start_time, :utc_datetime_usec do
        allow_nil? false
      end

      argument :end_time, :utc_datetime_usec do
        allow_nil? false
      end

      validate attribute_in(:status, [:approved, :scheduled])

      validate fn changeset, _context ->
        start_time = changeset.arguments.start_time
        end_time = changeset.arguments.end_time

        if DateTime.compare(start_time, end_time) != :lt do
          {:error, field: :scheduled_end, message: "end time must be after start time"}
        else
          :ok
        end
      end

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :scheduled)
        |> Ash.Changeset.force_change_attribute(
          :scheduled_start,
          changeset.arguments.start_time
        )
        |> Ash.Changeset.force_change_attribute(
          :scheduled_end,
          changeset.arguments.end_time
        )
      end
    end

    update :assign do
      require_atomic? false
      accept [:assigned_technician_id, :assigned_team_id]

      argument :technician_id, :uuid
      argument :team_id, :uuid

      validate attribute_in(:status, [:approved, :scheduled])

      change fn changeset, _context ->
        changeset = Ash.Changeset.force_change_attribute(changeset, :status, :assigned)

        if technician_id = changeset.arguments.technician_id do
          changeset =
            Ash.Changeset.force_change_attribute(
              changeset,
              :assigned_technician_id,
              technician_id
            )
        end

        if team_id = changeset.arguments.team_id do
          changeset = Ash.Changeset.force_change_attribute(changeset, :assigned_team_id, team_id)
        end

        changeset
      end
    end

    update :start_work do
      require_atomic? false
      accept [:started_at]

      validate attribute_in(:status, [:assigned, :scheduled])

      change fn changeset, _context ->
        start_time = DateTime.utc_now()

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :in_progress)
        |> Ash.Changeset.force_change_attribute(:started_at, start_time)
      end
    end

    update :put_on_hold do
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
        |> Ash.Changeset.force_change_attribute(:status, :on_hold)
        |> Ash.Changeset.force_change_attribute(:substatus, reason)
      end
    end

    update :resume_work do
      require_atomic? false
      accept []

      validate attribute_equals(:status, :on_hold)

      change set_attribute(:status, :in_progress)
    end

    update :complete do
      accept [
      require_atomic? false
        :work_performed,
        :materials_used,
        :findings,
        :recommendations,
        :actual_cost,
        :labor_cost,
        :parts_cost,
        :external_cost,
        :quality_rating,
        :completion_rating
      ]

      argument :work_performed, :string do
        allow_nil? false
        constraints max_length: 5000
      end

      validate attribute_equals(:status, :in_progress)

      change fn changeset, _context ->
        completion_time = DateTime.utc_now()
        started_at = Ash.Changeset.get_attribute(changeset, :started_at)

        actual_duration =
          if started_at do
            DateTime.diff(completion_time, started_at) / 3600.0
          else
            nil
          end

        changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(:status, :completed)
          |> Ash.Changeset.force_change_attribute(:completed_at, completion_time)

        if actual_duration do
          Ash.Changeset.force_change_attribute(
            changeset,
            :actual_duration_hours,
            actual_duration
          )
        else
          changeset
        end
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

        if status in [:completed, :cancelled] do
          {:error, field: :status, message: "cannot cancel work order in current state"}
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

    update :add_communication do
      require_atomic? false
      accept [:communication_log]

      argument :message, :string do
        allow_nil? false
        constraints max_length: 1000
      end

      argument :sender, :string do
        allow_nil? false
        constraints max_length: 100
      end

      change fn changeset, _context ->
        log = Ash.Changeset.get_attribute(changeset, :communication_log) || []

        new_entry = %{
          "timestamp" => DateTime.utc_now(),
          "message" => changeset.arguments.message,
          "sender" => changeset.arguments.sender
        }

        Ash.Changeset.force_change_attribute(
          changeset,
          :communication_log,
          [new_entry | log]
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
          Ash.Changeset.add_error(
            changeset,
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

      validate attribute_equals(:status, :completed)
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

    update :calculate_costs do
      require_atomic? false
      accept [:actual_cost, :labor_cost, :parts_cost, :external_cost]

      change fn changeset, _context ->
        labor = Ash.Changeset.get_attribute(changeset, :labor_cost) || 0.0
        parts = Ash.Changeset.get_attribute(changeset, :parts_cost) || 0.0
        external = Ash.Changeset.get_attribute(changeset, :external_cost) || 0.0

        total_cost = labor + parts + external

        Ash.Changeset.force_change_attribute(changeset, :actual_cost, total_cost)
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
          Enum.map(
            records,
            fn work_order ->
              work_order.status in [
                :draft,
                :requested,
                :approved,
                :scheduled,
                :assigned,
                :in_progress,
                :on_hold
              ]
            end
          )

        {:ok, values}
      end
    end

    calculate :is_overdue?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn work_order ->
              work_order.scheduled_end &&
                DateTime.compare(DateTime.utc_now(), work_order.scheduled_end) == :gt &&
                work_order.status in [:scheduled, :assigned, :in_progress]
            end
          )

        {:ok, values}
      end
    end

    calculate :duration_variance_hours, :float do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn work_order ->
              if work_order.actual_duration_hours && work_order.estimated_duration_hours do
                work_order.actual_duration_hours - work_order.estimated_duration_hours
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :cost_variance, :float do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn work_order ->
              if work_order.actual_cost && work_order.estimated_cost do
                work_order.actual_cost - work_order.estimated_cost
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :calculated_response_time_hours, :float do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn work_order ->
              if work_order.started_at && work_order.approved_at do
                DateTime.diff(
                  work_order.started_at,
                  work_order.approved_at
                ) / 3600.0
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

    policy action(:create) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "manager")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action([:update, :submit]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "manager")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action([:approve, :reject, :assign]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "manager")
    end

    policy action([
             :start_work,
             :put_on_hold,
             :resume_work,
             :complete,
             :add_communication,
             :add_photo
           ]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "manager")
      authorize_if actor_attribute_equals(:role, "technician")
      # Assigned technician can update their work orders
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
    define :submit
    define :approve
    define :reject
    define :schedule
    define :assign
    define :start_work
    define :put_on_hold
    define :resume_work
    define :complete
    define :cancel
    define :add_communication
    define :add_photo
    define :record_inspection
    define :calculate_costs
    define :destroy
  end

  postgres do
    table "maintenance_work_orders"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :work_order_number], unique: true
      index [:equipment_id], where: "equipment_id IS NOT NULL"
      index [:site_id], where: "site_id IS NOT NULL"
      index [:assigned_technician_id], where: "assigned_technician_id IS NOT NULL"
      index [:assigned_team_id], where: "assigned_team_id IS NOT NULL"
      index [:parent_schedule_id], where: "parent_schedule_id IS NOT NULL"
      index [:status]
      index [:work_order_type]
      index [:category]
      index [:priority]
      index [:urgency]

      index [:safety_critical?],
        name: "work_orders_safety_critical_index",
        where: "safety_critical? = true"

      index [:scheduled_start]
      index [:scheduled_end]
      index [:created_date]
      index [:recurring?], name: "work_orders_recurring_index", where: "recurring? = true"
    end
  end

  # Helper functions
  defp generate_work_order_number(changeset) do
    # Generate work order number like WO-20251206-001
    date_str = Date.utc_today() |> Date.to_string() |> String.replace("-", "")

    random_suffix =
      :rand.uniform(999)
      |> Integer.to_string()
      |> String.pad_leading(3, "0")

    work_order_number = "WO-#{date_str}-#{random_suffix}"

    Ash.Changeset.force_change_attribute(
      changeset,
      :work_order_number,
      work_order_number
    )
  end
end
