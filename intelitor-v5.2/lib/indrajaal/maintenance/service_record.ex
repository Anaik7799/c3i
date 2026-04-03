defmodule Indrajaal.Maintenance.ServiceRecord do
  @moduledoc """
  Represents historical maintenance service records for equipment.

  Service records provide a comprehensive maintenance history including
  all work performed, parts used, costs incurred, and performance metrics.
  They support warranty tracking, compliance reporting, and asset management.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Maintenance

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Record identification
    attribute :record_number, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :work_order_id, :uuid do
      public? true
    end

    attribute :equipment_id, :uuid do
      allow_nil? false
      public? true
    end

    # Service details
    attribute :service_date, :date do
      allow_nil? false
      public? true
    end

    attribute :service_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :pr_eventive,
                    :corrective,
                    :emergency,
                    :inspection,
                    :installation,
                    :upgrade,
                    :replacement,
                    :calibration,
                    :warranty,
                    :recall
                  ]

      default :pr_eventive
    end

    attribute :service_category, :atom do
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

    attribute :service_description, :string do
      allow_nil? false
      public? true
      constraints max_length: 2000
    end

    # Personnel and organization
    attribute :technician_id, :uuid do
      public? true
    end

    attribute :technician_name, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :supervisor_id, :uuid do
      public? true
    end

    attribute :vendor_id, :uuid do
      public? true
    end

    attribute :vendor_name, :string do
      public? true
      constraints max_length: 200
    end

    attribute :external_service?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Work performed
    attribute :work_performed, :string do
      allow_nil? false
      public? true
      constraints max_length: 5000
    end

    attribute :procedures_followed, {:array, :string} do
      public? true
      default []
    end

    attribute :tasks_completed, {:array, :map} do
      public? true
      default []
    end

    attribute :issues_found, :string do
      public? true
      constraints max_length: 3000
    end

    attribute :corrective_actions, :string do
      public? true
      constraints max_length: 3000
    end

    # Parts and materials
    attribute :parts_used, {:array, :map} do
      public? true
      default []
    end

    attribute :materials_consumed, {:array, :map} do
      public? true
      default []
    end

    attribute :parts_removed, {:array, :map} do
      public? true
      default []
    end

    attribute :parts_disposal_method, :string do
      public? true
      constraints max_length: 500
    end

    # Time tracking
    attribute :start_time, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :end_time, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :duration_hours, :float do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :downtime_hours, :float do
      public? true
      constraints min: 0
    end

    attribute :travel_time_hours, :float do
      public? true
      constraints min: 0
    end

    # Cost breakdown
    attribute :total_cost, :float do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :labor_cost, :float do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :parts_cost, :float do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :materials_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :external_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :travel_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :overhead_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :currency, :string do
      allow_nil? false
      public? true
      constraints max_length: 3
      default "USD"
    end

    # Measurements and readings
    attribute :pre_service_readings, {:array, :map} do
      public? true
      default []
    end

    attribute :post_service_readings, {:array, :map} do
      public? true
      default []
    end

    attribute :calibration_results, {:array, :map} do
      public? true
      default []
    end

    attribute :test_results, {:array, :map} do
      public? true
      default []
    end

    attribute :performance_metrics, :map do
      public? true
      default %{}
    end

    # Quality and compliance
    attribute :quality_rating, :integer do
      public? true
      constraints min: 1, max: 5
    end

    attribute :compliance_standards_met, {:array, :string} do
      public? true
      default []
    end

    attribute :certifications_issued, {:array, :string} do
      public? true
      default []
    end

    attribute :inspection_passed?, :boolean do
      public? true
    end

    attribute :inspector_name, :string do
      public? true
      constraints max_length: 100
    end

    attribute :inspection_date, :date do
      public? true
    end

    # Warranty and guarantees
    attribute :warranty_work?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :warranty_provider, :string do
      public? true
      constraints max_length: 200
    end

    attribute :warranty_claim_number, :string do
      public? true
      constraints max_length: 100
    end

    attribute :new_warranty_period, :integer do
      public? true
      constraints min: 0
    end

    attribute :warranty_start_date, :date do
      public? true
    end

    attribute :warranty_end_date, :date do
      public? true
    end

    # Recommendations and follow - up
    attribute :recommendations, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :next_service_due, :date do
      public? true
    end

    attribute :next_service_type, :atom do
      public? true

      constraints one_of: [
                    :pr_eventive,
                    :corrective,
                    :inspection,
                    :calibration,
                    :replacement
                  ]
    end

    attribute :follow_up_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :follow_up_date, :date do
      public? true
    end

    attribute :follow_up_description, :string do
      public? true
      constraints max_length: 1000
    end

    # Equipment condition
    attribute :equipment_condition_before, :atom do
      public? true
      constraints one_of: [:excellent, :good, :fair, :poor, :critical]
    end

    attribute :equipment_condition_after, :atom do
      public? true
      constraints one_of: [:excellent, :good, :fair, :poor, :critical]
    end

    attribute :functional_test_passed?, :boolean do
      public? true
    end

    attribute :operational_status, :atom do
      public? true
      constraints one_of: [:operational, :limited, :non_operational]
    end

    # Environmental conditions
    attribute :environmental_conditions, :map do
      public? true
      default %{}
    end

    attribute :ambient_temperature, :float do
      public? true
    end

    attribute :humidity_percent, :float do
      public? true
      constraints min: 0, max: 100
    end

    attribute :weather_conditions, :string do
      public? true
      constraints max_length: 200
    end

    # Safety and incidents
    attribute :safety_incidents?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :safety_incident_details, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :ppe_used, {:array, :string} do
      public? true
      default []
    end

    attribute :safety_permits_required, {:array, :string} do
      public? true
      default []
    end

    attribute :lockout_tagout_performed?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Documentation
    attribute :photo_urls, {:array, :string} do
      public? true
      default []
    end

    attribute :document_urls, {:array, :string} do
      public? true
      default []
    end

    attribute :report_urls, {:array, :string} do
      public? true
      default []
    end

    attribute :drawing_updates, {:array, :string} do
      public? true
      default []
    end

    # Customer interaction
    attribute :customer_present?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :customer_signature?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :customer_satisfaction, :integer do
      public? true
      constraints min: 1, max: 5
    end

    attribute :customer_feedback, :string do
      public? true
      constraints max_length: 1000
    end

    # Administrative
    attribute :created_by, :uuid do
      allow_nil? false
      public? true
    end

    attribute :approved_by, :uuid do
      public? true
    end

    attribute :approval_date, :date do
      public? true
    end

    attribute :record_status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:draft, :submitted, :approved, :archived]
      default :draft
    end

    # Integration and references
    attribute :asset_tag, :string do
      public? true
      constraints max_length: 100
    end

    attribute :purchase_order, :string do
      public? true
      constraints max_length: 100
    end

    attribute :invoice_number, :string do
      public? true
      constraints max_length: 100
    end

    attribute :external_references, :map do
      public? true
      default %{}
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
    belongs_to :work_order, Indrajaal.Maintenance.WorkOrder do
      attribute_public? true
    end

    belongs_to :equipment, Indrajaal.Maintenance.Equipment do
      attribute_public? true
    end

    belongs_to :technician, Indrajaal.Accounts.User do
      attribute_public? true
    end

    belongs_to :supervisor, Indrajaal.Accounts.User do
      attribute_public? true
    end

    belongs_to :created_by_user, Indrajaal.Accounts.User do
      source_attribute :created_by
      attribute_public? true
    end

    belongs_to :approved_by_user, Indrajaal.Accounts.User do
      source_attribute :approved_by
      attribute_public? true
    end
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :work_order_id,
        :equipment_id,
        :service_date,
        :service_type,
        :service_category,
        :service_description,
        :technician_id,
        :technician_name,
        :supervisor_id,
        :vendor_id,
        :vendor_name,
        :external_service?,
        :work_performed,
        :procedures_followed,
        :tasks_completed,
        :issues_found,
        :corrective_actions,
        :parts_used,
        :materials_consumed,
        :parts_removed,
        :parts_disposal_method,
        :start_time,
        :end_time,
        :downtime_hours,
        :travel_time_hours,
        :labor_cost,
        :parts_cost,
        :materials_cost,
        :external_cost,
        :travel_cost,
        :overhead_cost,
        :currency,
        :pre_service_readings,
        :post_service_readings,
        :calibration_results,
        :test_results,
        :performance_metrics,
        :quality_rating,
        :compliance_standards_met,
        :certifications_issued,
        :inspection_passed?,
        :inspector_name,
        :inspection_date,
        :warranty_work?,
        :warranty_provider,
        :warranty_claim_number,
        :new_warranty_period,
        :warranty_start_date,
        :warranty_end_date,
        :recommendations,
        :next_service_due,
        :next_service_type,
        :follow_up_required?,
        :follow_up_date,
        :follow_up_description,
        :equipment_condition_before,
        :equipment_condition_after,
        :functional_test_passed?,
        :operational_status,
        :environmental_conditions,
        :ambient_temperature,
        :humidity_percent,
        :weather_conditions,
        :safety_incidents?,
        :safety_incident_details,
        :ppe_used,
        :safety_permits_required,
        :lockout_tagout_performed?,
        :photo_urls,
        :document_urls,
        :report_urls,
        :drawing_updates,
        :customer_present?,
        :customer_signature?,
        :customer_satisfaction,
        :customer_feedback,
        :created_by,
        :asset_tag,
        :purchase_order,
        :invoice_number,
        :external_references,
        :metadata
      ]

      change fn changeset, __context ->
        start_time =
          Ash.Changeset.get_argument_or_attribute(
            changeset,
            :start_time
          )

        end_time = Ash.Changeset.get_argument_or_attribute(changeset, :end_time)

        duration =
          if start_time && end_time do
            DateTime.diff(end_time, start_time) / 3600.0
          else
            0.0
          end

        labor_cost =
          Ash.Changeset.get_argument_or_attribute(
            changeset,
            :labor_cost
          ) || 0.0

        parts_cost =
          Ash.Changeset.get_argument_or_attribute(
            changeset,
            :parts_cost
          ) || 0.0

        materials_cost =
          Ash.Changeset.get_argument_or_attribute(
            changeset,
            :materials_cost
          ) || 0.0

        external_cost =
          Ash.Changeset.get_argument_or_attribute(
            changeset,
            :external_cost
          ) || 0.0

        travel_cost =
          Ash.Changeset.get_argument_or_attribute(
            changeset,
            :travel_cost
          ) || 0.0

        overhead_cost =
          Ash.Changeset.get_argument_or_attribute(
            changeset,
            :overhead_cost
          ) || 0.0

        total_cost =
          labor_cost + parts_cost + materials_cost + external_cost + travel_cost

        +overhead_cost

        changeset
        |> generate_record_number()
        |> Ash.Changeset.force_change_attribute(:duration_hours, duration)
        |> Ash.Changeset.force_change_attribute(:total_cost, total_cost)
        |> Ash.Changeset.force_change_attribute(:record_status, :draft)
      end
    end

    update :submit do
      require_atomic? false
      accept []

      validate attribute_equals(:record_status, :draft)

      change set_attribute(:record_status, :submitted)
    end

    update :approve do
      require_atomic? false
      accept [:approved_by, :approval_date]

      argument :approved_by, :uuid do
        allow_nil? false
      end

      validate attribute_equals(:record_status, :submitted)

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:record_status, :approved)
        |> Ash.Changeset.force_change_attribute(:approved_by, changeset.arguments.approved_by)
        |> Ash.Changeset.force_change_attribute(:approval_date, Date.utc_today())
      end
    end

    update :archive do
      require_atomic? false
      accept []

      validate attribute_equals(:record_status, :approved)

      change set_attribute(:record_status, :archived)
    end

    update :add_part_used do
      require_atomic? false
      accept [:parts_used]

      argument :part_number, :string do
        allow_nil? false
        constraints max_length: 100
      end

      argument :description, :string do
        allow_nil? false
        constraints max_length: 200
      end

      argument :quantity, :integer do
        allow_nil? false
        constraints min: 1
      end

      argument :unit_cost, :float do
        constraints min: 0
      end

      change fn changeset, __context ->
        parts = Ash.Changeset.get_attribute(changeset, :parts_used) || []

        new_part = %{
          "part_number" => changeset.arguments.part_number,
          "description" => changeset.arguments.description,
          "quantity" => changeset.arguments.quantity,
          "unit_cost" => changeset.arguments.unit_cost,
          "total_cost" => (changeset.arguments.unit_cost || 0.0) * changeset.arguments.quantity
        }

        Ash.Changeset.force_change_attribute(changeset, :parts_used, [new_part | parts])
      end
    end

    update :add_reading do
      require_atomic? false
      accept [:post_service_readings]

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

      change fn changeset, __context ->
        readings =
          Ash.Changeset.get_attribute(
            changeset,
            :post_service_readings
          ) || []

        new_reading = %{
          "measurement_point" => changeset.arguments.measurement_point,
          "value" => changeset.arguments.value,
          "unit" => changeset.arguments.unit,
          "timestamp" => DateTime.utc_now()
        }

        Ash.Changeset.force_change_attribute(
          changeset,
          :post_service_readings,
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

      change fn changeset, __context ->
        photos = Ash.Changeset.get_attribute(changeset, :photo_urls) || []
        new_url = changeset.arguments.photo_url

        if new_url in photos do
          changeset
        else
          Ash.Changeset.force_change_attribute(changeset, :photo_urls, [new_url | photos])
        end
      end
    end

    update :record_inspection do
      require_atomic? false
      accept [:inspection_passed?, :inspector_name, :inspection_date]

      argument :passed?, :boolean do
        allow_nil? false
      end

      argument :inspector, :string do
        allow_nil? false
        constraints max_length: 100
      end

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:inspection_passed?, changeset.arguments.passed?)
        |> Ash.Changeset.force_change_attribute(:inspector_name, changeset.arguments.inspector)
        |> Ash.Changeset.force_change_attribute(:inspection_date, Date.utc_today())
      end
    end

    update :calculate_total_cost do
      require_atomic? false
      accept [:total_cost]

      change fn changeset, __context ->
        labor = Ash.Changeset.get_attribute(changeset, :labor_cost) || 0.0
        parts = Ash.Changeset.get_attribute(changeset, :parts_cost) || 0.0

        materials =
          Ash.Changeset.get_attribute(
            changeset,
            :materials_cost
          ) || 0.0

        external = Ash.Changeset.get_attribute(changeset, :external_cost) || 0.0
        travel = Ash.Changeset.get_attribute(changeset, :travel_cost) || 0.0
        overhead = Ash.Changeset.get_attribute(changeset, :overhead_cost) || 0.0

        total = labor + parts + materials + external + travel + overhead

        Ash.Changeset.force_change_attribute(changeset, :total_cost, total)
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :service_efficiency, :float do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn record ->
            if record.duration_hours > 0 do
              # Efficiency based on work performed vs time spent
              # This is a simplified calculation
              100.0 - (record.travel_time_hours || 0.0) / record.duration_hours * 100.0
            else
              nil
            end
          end)

        {:ok, values}
      end
    end

    calculate :cost_per_hour, :float do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn record ->
            if record.duration_hours > 0 do
              record.total_cost / record.duration_hours
            else
              nil
            end
          end)

        {:ok, values}
      end
    end

    calculate :warranty_active?, :boolean do
      calculation fn records, __context ->
        today = Date.utc_today()

        values =
          Enum.map(records, fn record ->
            record.warranty_end_date &&
              Date.compare(today, record.warranty_end_date) == :lt
          end)

        {:ok, values}
      end
    end

    calculate :follow_up_overdue?, :boolean do
      calculation fn records, __context ->
        today = Date.utc_today()

        values =
          Enum.map(records, fn record ->
            record.follow_up_required? &&
              record.follow_up_date &&
              Date.compare(today, record.follow_up_date) == :gt
          end)

        {:ok, values}
      end
    end

    calculate :condition_improvement?, :boolean do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn record ->
            before = record.equipment_condition_before
            after_condition = record.equipment_condition_after

            if before && after_condition do
              condition_order = [:critical, :poor, :fair, :good, :excellent]
              before_index = Enum.find_index(condition_order, &(&1 == before)) || 0
              after_index = Enum.find_index(condition_order, &(&1 == after_condition)) || 0
              after_index > before_index
            else
              nil
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
      authorize_if actor_attribute_equals(:role, "inspector")
    end

    policy action(:create) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "manager")
      authorize_if actor_attribute_equals(:role, "technician")
    end

    policy action([:update, :submit]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "manager")
      authorize_if actor_attribute_equals(:role, "technician")
      # Record creator can update their records
      authorize_if expr(created_by == ^actor(:id))
    end

    policy action([:approve, :archive]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "manager")
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
    define :archive
    define :add_part_used
    define :add_reading
    define :add_photo
    define :record_inspection
    define :calculate_total_cost
    define :destroy
  end

  postgres do
    table "maintenance_service_records"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :record_number], unique: true
      index [:work_order_id], where: "work_order_id IS NOT NULL"
      index [:equipment_id]
      index [:technician_id], where: "technician_id IS NOT NULL"
      index [:supervisor_id], where: "supervisor_id IS NOT NULL"
      index [:vendor_id], where: "vendor_id IS NOT NULL"
      index [:created_by]
      index [:approved_by], where: "approved_by IS NOT NULL"
      index [:service_date]
      index [:service_type]
      index [:service_category]
      index [:record_status]

      index [:external_service?],
        name: "service_records_external_index",
        where: "external_service? = true"

      index [:warranty_work?],
        name: "service_records_warranty_index",
        where: "warranty_work? = true"

      index [:follow_up_required?],
        name: "service_records_follow_up_index",
        where: "follow_up_required? = true"

      index [:next_service_due], where: "next_service_due IS NOT NULL"
      index [:total_cost]
    end
  end

  # Helper functions
  @spec generate_record_number(term()) :: term()
  defp generate_record_number(changeset) do
    # Generate record number like SR - 20_251_206 - 001
    date_str = Date.utc_today() |> Date.to_string() |> String.replace("-", "")

    random_num = :rand.uniform(999)

    random_suffix =
      random_num
      |> Integer.to_string()
      |> String.pad_leading(3, "0")

    record_number = "SR-#{date_str}-#{random_suffix}"

    Ash.Changeset.force_change_attribute(changeset, :record_number, record_number)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Maintenance
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
