defmodule Indrajaal.Maintenance.Equipment do
  @moduledoc """
  Represents equipment and assets managed by the maintenance system.

  Equipment records track physical assets including specifications, maintenance
  history,
    performance metrics, and lifecycle management. They support pr_eventive
  maintenance scheduling, warranty tracking, and asset optimization.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Maintenance

  use Indrajaal.Multitenancy.TenantResource

  postgres do
    table "maintenance_equipment"
    repo Indrajaal.Repo
  end

  attributes do
    uuid_primary_key :id

    # Equipment identification
    attribute :asset_tag, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :equipment_name, :string do
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :serial_number, :string do
      public? true
      constraints max_length: 100
    end

    attribute :model_number, :string do
      public? true
      constraints max_length: 100
    end

    # Equipment classification
    attribute :equipment_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :security_panel,
                    :camera,
                    :sensor,
                    :access_control,
                    :network_device,
                    :server,
                    :ups,
                    :hvac,
                    :fire_system,
                    :lighting,
                    :elevator,
                    :generator,
                    :pump,
                    :motor,
                    :valve,
                    :controller
                  ]

      default :security_panel
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
                    :safety,
                    :environmental
                  ]

      default :security
    end

    attribute :subcategory, :string do
      public? true
      constraints max_length: 100
    end

    attribute :criticality, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    # Manufacturer information
    attribute :manufacturer, :string do
      public? true
      constraints max_length: 200
    end

    attribute :vendor_id, :uuid do
      public? true
    end

    attribute :vendor_name, :string do
      public? true
      constraints max_length: 200
    end

    attribute :manufacturer_part_number, :string do
      public? true
      constraints max_length: 100
    end

    # Location and installation
    attribute :site_id, :uuid do
      public? true
    end

    attribute :building_id, :uuid do
      public? true
    end

    attribute :floor_id, :uuid do
      public? true
    end

    attribute :location_description, :string do
      public? true
      constraints max_length: 500
    end

    attribute :coordinates, :map do
      public? true
      default %{}
    end

    attribute :installation_date, :date do
      public? true
    end

    attribute :commissioning_date, :date do
      public? true
    end

    # Status and condition
    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :active,
                    :inactive,
                    :maintenance,
                    :retired,
                    :disposed,
                    :in_storage,
                    :on_order,
                    :installation_pending
                  ]

      default :active
    end

    attribute :operational_status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:operational, :limited, :non_operational, :unknown]
      default :operational
    end

    attribute :condition_rating, :integer do
      public? true
      constraints min: 1, max: 5
    end

    attribute :last_condition_assessment, :date do
      public? true
    end

    # Technical specifications
    attribute :specifications, :map do
      public? true
      default %{}
    end

    attribute :operating_parameters, :map do
      public? true
      default %{}
    end

    attribute :performance_standards, :map do
      public? true
      default %{}
    end

    attribute :rated_capacity, :string do
      public? true
      constraints max_length: 100
    end

    attribute :power_requirements, :string do
      public? true
      constraints max_length: 200
    end

    attribute :environmental_requirements, :map do
      public? true
      default %{}
    end

    # Maintenance information
    attribute :maintenance_strategy, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :pr_eventive,
                    :predictive,
                    :reactive,
                    :condition_based,
                    :risk_based,
                    :reliability_centered
                  ]

      default :pr_eventive
    end

    attribute :maintenance_f_requency, :atom do
      public? true

      constraints one_of: [
                    :weekly,
                    :monthly,
                    :quarterly,
                    :semi_annual,
                    :annual,
                    :biennial
                  ]
    end

    attribute :planned_maintenance_hours_annual, :integer do
      public? true
      constraints min: 0
    end

    attribute :actual_maintenance_hours_ytd, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :last_service_date, :date do
      public? true
    end

    attribute :next_service_due, :date do
      public? true
    end

    attribute :service_interval_days, :integer do
      public? true
      constraints min: 1
    end

    # Usage and performance tracking
    attribute :operating_hours_total, :float do
      allow_nil? false
      public? true
      constraints min: 0
      default 0.0
    end

    attribute :operating_hours_ytd, :float do
      allow_nil? false
      public? true
      constraints min: 0
      default 0.0
    end

    attribute :cycles_total, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :cycles_ytd, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :last_usage_reading, :utc_datetime_usec do
      public? true
    end

    attribute :usage_unit, :atom do
      public? true
      constraints one_of: [:hours, :cycles, :distance, :volume, :count]
    end

    # Reliability metrics
    attribute :mtbf_hours, :float do
      public? true
      constraints min: 0
    end

    attribute :mttr_hours, :float do
      public? true
      constraints min: 0
    end

    attribute :availability_percentage, :float do
      public? true
      constraints min: 0, max: 100
    end

    attribute :failure_count_ytd, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :downtime_hours_ytd, :float do
      allow_nil? false
      public? true
      constraints min: 0
      default 0.0
    end

    # Financial information
    attribute :purchase_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :current_value, :float do
      public? true
      constraints min: 0
    end

    attribute :replacement_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :annual_operating_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :maintenance_cost_ytd, :float do
      allow_nil? false
      public? true
      constraints min: 0
      default 0.0
    end

    attribute :depreciation_method, :atom do
      public? true
      constraints one_of: [:straight_line, :declining_balance, :sum_of_years]
    end

    attribute :useful_life_years, :integer do
      public? true
      constraints min: 1, max: 100
    end

    # Warranty and contracts
    attribute :warranty_start_date, :date do
      public? true
    end

    attribute :warranty_end_date, :date do
      public? true
    end

    attribute :warranty_provider, :string do
      public? true
      constraints max_length: 200
    end

    attribute :warranty_terms, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :service_contract_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :service_contract_provider, :string do
      public? true
      constraints max_length: 200
    end

    attribute :service_contract_expires, :date do
      public? true
    end

    # Spare parts and inventory
    attribute :critical_spare_parts, {:array, :map} do
      public? true
      default []
    end

    attribute :recommended_spare_parts, {:array, :map} do
      public? true
      default []
    end

    attribute :spare_parts_cost, :float do
      public? true
      constraints min: 0
    end

    attribute :spare_parts_lead_time_days, :integer do
      public? true
      constraints min: 0
    end

    # Safety and compliance
    attribute :safety_critical?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :regulatory_requirements, {:array, :string} do
      public? true
      default []
    end

    attribute :compliance_standards, {:array, :string} do
      public? true
      default []
    end

    attribute :last_inspection_date, :date do
      public? true
    end

    attribute :next_inspection_due, :date do
      public? true
    end

    attribute :inspection_f_requency_months, :integer do
      public? true
      constraints min: 1, max: 60
    end

    attribute :safety_permits_required, {:array, :string} do
      public? true
      default []
    end

    # Environmental impact
    attribute :energy_consumption_rating, :string do
      public? true
      constraints max_length: 10
    end

    attribute :environmental_impact_rating, :atom do
      public? true
      constraints one_of: [:low, :medium, :high]
    end

    attribute :disposal_requirements, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :recycling_instructions, :string do
      public? true
      constraints max_length: 1000
    end

    # Documentation and references
    attribute :manual_urls, {:array, :string} do
      public? true
      default []
    end

    attribute :drawing_urls, {:array, :string} do
      public? true
      default []
    end

    attribute :photo_urls, {:array, :string} do
      public? true
      default []
    end

    attribute :procedure_references, {:array, :string} do
      public? true
      default []
    end

    attribute :training_requirements, {:array, :string} do
      public? true
      default []
    end

    # Integration and monitoring
    attribute :monitoring_enabled?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :sensor_ids, {:array, :uuid} do
      public? true
      default []
    end

    attribute :alarm_points, {:array, :map} do
      public? true
      default []
    end

    attribute :performance_thresholds, :map do
      public? true
      default %{}
    end

    attribute :data_collection_f_requency, :atom do
      public? true
      constraints one_of: [:continuous, :hourly, :daily, :weekly, :monthly]
    end

    # Lifecycle management
    attribute :expected_retirement_date, :date do
      public? true
    end

    attribute :replacement_planning_date, :date do
      public? true
    end

    attribute :lifecycle_stage, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :planning,
                    :procurement,
                    :installation,
                    :commissioning,
                    :operation,
                    :maintenance,
                    :upgrade,
                    :retirement,
                    :disposal
                  ]

      default :operation
    end

    attribute :successor_equipment_id, :uuid do
      public? true
    end

    # Notes and metadata
    attribute :notes, :string do
      public? true
      constraints max_length: 2000
    end

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
    belongs_to :site, Indrajaal.Sites.Site do
      attribute_public? true
    end

    belongs_to :building, Indrajaal.Sites.Building do
      attribute_public? true
    end

    belongs_to :floor, Indrajaal.Sites.Floor do
      attribute_public? true
    end

    belongs_to :successor_equipment, Indrajaal.Maintenance.Equipment do
      attribute_public? true
    end

    has_many :work_orders, Indrajaal.Maintenance.WorkOrder
    has_many :schedules, Indrajaal.Maintenance.Schedule
    has_many :service_records, Indrajaal.Maintenance.ServiceRecord
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :asset_tag,
        :equipment_name,
        :description,
        :serial_number,
        :model_number,
        :equipment_type,
        :category,
        :subcategory,
        :criticality,
        :manufacturer,
        :vendor_id,
        :vendor_name,
        :manufacturer_part_number,
        :site_id,
        :building_id,
        :floor_id,
        :location_description,
        :coordinates,
        :installation_date,
        :commissioning_date,
        :specifications,
        :operating_parameters,
        :performance_standards,
        :rated_capacity,
        :power_requirements,
        :environmental_requirements,
        :maintenance_strategy,
        :maintenance_f_requency,
        :planned_maintenance_hours_annual,
        :service_interval_days,
        :usage_unit,
        :purchase_cost,
        :current_value,
        :replacement_cost,
        :annual_operating_cost,
        :depreciation_method,
        :useful_life_years,
        :warranty_start_date,
        :warranty_end_date,
        :warranty_provider,
        :warranty_terms,
        :service_contract_id,
        :service_contract_provider,
        :service_contract_expires,
        :critical_spare_parts,
        :recommended_spare_parts,
        :spare_parts_cost,
        :spare_parts_lead_time_days,
        :safety_critical?,
        :regulatory_requirements,
        :compliance_standards,
        :inspection_f_requency_months,
        :safety_permits_required,
        :energy_consumption_rating,
        :environmental_impact_rating,
        :disposal_requirements,
        :recycling_instructions,
        :manual_urls,
        :drawing_urls,
        :photo_urls,
        :procedure_references,
        :training_requirements,
        :monitoring_enabled?,
        :sensor_ids,
        :alarm_points,
        :performance_thresholds,
        :data_collection_f_requency,
        :expected_retirement_date,
        :replacement_planning_date,
        :lifecycle_stage,
        :notes,
        :metadata
      ]

      change fn changeset, __context ->
        commissioning_date =
          Ash.Changeset.get_argument_or_attribute(
            changeset,
            :commissioning_date
          )

        service_interval =
          Ash.Changeset.get_argument_or_attribute(
            changeset,
            :service_interval_days
          )

        next_service =
          if commissioning_date && service_interval do
            Date.add(commissioning_date, service_interval)
          else
            nil
          end

        _changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(:status, :active)
          |> Ash.Changeset.force_change_attribute(
            :operational_status,
            :operational
          )

        if next_service do
          Ash.Changeset.force_change_attribute(changeset, :next_service_due, next_service)
        else
          changeset
        end
      end
    end

    update :update_status do
      require_atomic? false
      accept [:status, :operational_status]

      argument :status, :atom do
        allow_nil? false

        constraints one_of: [
                      :active,
                      :inactive,
                      :maintenance,
                      :retired,
                      :disposed,
                      :in_storage,
                      :on_order,
                      :installation_pending
                    ]
      end

      argument :operational_status, :atom do
        constraints one_of: [:operational, :limited, :non_operational, :unknown]
      end
    end

    update :update_condition do
      require_atomic? false
      accept [:condition_rating, :last_condition_assessment]

      argument :rating, :integer do
        allow_nil? false
        constraints min: 1, max: 5
      end

      argument :assessment_notes, :string do
        constraints max_length: 1000
      end

      change fn changeset, __context ->
        assessment_data = %{
          "rating" => changeset.arguments.rating,
          "date" => Date.utc_today(),
          "notes" => changeset.arguments.assessment_notes
        }

        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        updated_metadata = Map.put(metadata, "last_condition_assessment", assessment_data)

        changeset
        |> Ash.Changeset.force_change_attribute(
          :condition_rating,
          changeset.arguments.rating
        )
        |> Ash.Changeset.force_change_attribute(
          :last_condition_assessment,
          Date.utc_today()
        )
        |> Ash.Changeset.force_change_attribute(:metadata, updated_metadata)
      end
    end

    update :update_usage do
      require_atomic? false

      accept [
        :operating_hours_total,
        :operating_hours_ytd,
        :cycles_total,
        :cycles_ytd,
        :last_usage_reading
      ]

      argument :hours_increment, :float do
        constraints min: 0
      end

      argument :cycles_increment, :integer do
        constraints min: 0
      end

      change fn changeset, __context ->
        hours_inc = changeset.arguments.hours_increment || 0.0
        cycles_inc = changeset.arguments.cycles_increment || 0

        current_hours_total =
          Ash.Changeset.get_attribute(
            changeset,
            :operating_hours_total
          )

        current_hours_ytd =
          Ash.Changeset.get_attribute(
            changeset,
            :operating_hours_ytd
          )

        current_cycles_total =
          Ash.Changeset.get_attribute(
            changeset,
            :cycles_total
          )

        current_cycles_ytd = Ash.Changeset.get_attribute(changeset, :cycles_ytd)

        changeset
        |> Ash.Changeset.force_change_attribute(
          :operating_hours_total,
          current_hours_total + hours_inc
        )
        |> Ash.Changeset.force_change_attribute(
          :operating_hours_ytd,
          current_hours_ytd + hours_inc
        )
        |> Ash.Changeset.force_change_attribute(
          :cycles_total,
          current_cycles_total + cycles_inc
        )
        |> Ash.Changeset.force_change_attribute(
          :cycles_ytd,
          current_cycles_ytd + cycles_inc
        )
        |> Ash.Changeset.force_change_attribute(
          :last_usage_reading,
          DateTime.utc_now()
        )
      end
    end

    update :record_service do
      require_atomic? false
      accept [:last_service_date, :next_service_due, :actual_maintenance_hours_ytd]

      argument :service_date, :date do
        allow_nil? false
      end

      argument :hours_spent, :float do
        allow_nil? false
        constraints min: 0
      end

      change fn changeset, __context ->
        service_date = changeset.arguments.service_date
        hours_spent = changeset.arguments.hours_spent

        service_interval =
          Ash.Changeset.get_attribute(
            changeset,
            :service_interval_days
          )

        current_maintenance_hours =
          Ash.Changeset.get_attribute(changeset, :actual_maintenance_hours_ytd)

        next_service =
          if service_interval do
            Date.add(service_date, service_interval)
          else
            nil
          end

        _changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(
            :last_service_date,
            service_date
          )
          |> Ash.Changeset.force_change_attribute(
            :actual_maintenance_hours_ytd,
            current_maintenance_hours + hours_spent
          )

        if next_service do
          Ash.Changeset.force_change_attribute(changeset, :next_service_due, next_service)
        else
          changeset
        end
      end
    end

    update :record_failure do
      require_atomic? false
      accept [:failure_count_ytd, :downtime_hours_ytd]

      argument :downtime_hours, :float do
        allow_nil? false
        constraints min: 0
      end

      argument :failure_description, :string do
        allow_nil? false
        constraints max_length: 1000
      end

      change fn changeset, __context ->
        downtime = changeset.arguments.downtime_hours
        description = changeset.arguments.failure_description

        current_failures =
          Ash.Changeset.get_attribute(
            changeset,
            :failure_count_ytd
          )

        current_downtime =
          Ash.Changeset.get_attribute(
            changeset,
            :downtime_hours_ytd
          )

        failure_data = %{
          "date" => Date.utc_today(),
          "downtime_hours" => downtime,
          "description" => description
        }

        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        failures = Map.get(metadata, "failures", [])
        updated_metadata = Map.put(metadata, "failures", [failure_data | failures])

        changeset
        |> Ash.Changeset.force_change_attribute(
          :failure_count_ytd,
          current_failures + 1
        )
        |> Ash.Changeset.force_change_attribute(
          :downtime_hours_ytd,
          current_downtime + downtime
        )
        |> Ash.Changeset.force_change_attribute(:metadata, updated_metadata)
      end
    end

    update :update_costs do
      require_atomic? false
      accept [:maintenance_cost_ytd, :current_value]

      argument :additional_cost, :float do
        allow_nil? false
        constraints min: 0
      end

      change fn changeset, __context ->
        additional_cost = changeset.arguments.additional_cost

        current_maintenance_cost =
          Ash.Changeset.get_attribute(
            changeset,
            :maintenance_cost_ytd
          )

        Ash.Changeset.force_change_attribute(
          changeset,
          :maintenance_cost_ytd,
          current_maintenance_cost + additional_cost
        )
      end
    end

    update :schedule_inspection do
      require_atomic? false
      accept [:next_inspection_due]

      argument :inspection_date, :date do
        allow_nil? false
      end

      change fn changeset, __context ->
        inspection_date = changeset.arguments.inspection_date

        f_requency =
          Ash.Changeset.get_attribute(
            changeset,
            :inspection_f_requency_months
          )

        next_inspection =
          if f_requency do
            # Approximate
            Date.add(inspection_date, f_requency * 30)
          else
            nil
          end

        if next_inspection do
          Ash.Changeset.force_change_attribute(
            changeset,
            :next_inspection_due,
            next_inspection
          )
        else
          changeset
        end
      end
    end

    update :retire do
      require_atomic? false
      accept [:status, :lifecycle_stage]

      argument :retirement_date, :date do
        allow_nil? false
      end

      argument :retirement_reason, :string do
        allow_nil? false
        constraints max_length: 1000
      end

      change fn changeset, __context ->
        retirement_data = %{
          "date" => changeset.arguments.retirement_date,
          "reason" => changeset.arguments.retirement_reason
        }

        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        updated_metadata = Map.put(metadata, "retirement", retirement_data)

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :retired)
        |> Ash.Changeset.force_change_attribute(:lifecycle_stage, :retirement)
        |> Ash.Changeset.force_change_attribute(:metadata, updated_metadata)
      end
    end

    update :add_spare_part do
      require_atomic? false
      accept [:critical_spare_parts]

      argument :part_number, :string do
        allow_nil? false
        constraints max_length: 100
      end

      argument :description, :string do
        allow_nil? false
        constraints max_length: 200
      end

      argument :quantity_required, :integer do
        allow_nil? false
        constraints min: 1
      end

      argument :unit_cost, :float do
        constraints min: 0
      end

      change fn changeset, __context ->
        parts =
          Ash.Changeset.get_attribute(
            changeset,
            :critical_spare_parts
          ) || []

        new_part = %{
          "part_number" => changeset.arguments.part_number,
          "description" => changeset.arguments.description,
          "quantity_required" => changeset.arguments.quantity_required,
          "unit_cost" => changeset.arguments.unit_cost,
          "total_cost" =>
            (changeset.arguments.unit_cost || 0.0) * changeset.arguments.quantity_required
        }

        Ash.Changeset.force_change_attribute(
          changeset,
          :critical_spare_parts,
          [new_part | parts]
        )
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :is_due_for_service?, :boolean do
      calculation fn records, __context ->
        today = Date.utc_today()

        values =
          Enum.map(
            records,
            fn equipment ->
              equipment.next_service_due &&
                Date.compare(
                  today,
                  equipment.next_service_due
                ) != :lt
            end
          )

        {:ok, values}
      end
    end

    calculate :service_overdue_days, :integer do
      calculation fn records, __context ->
        today = Date.utc_today()

        values =
          Enum.map(
            records,
            fn equipment ->
              if equipment.next_service_due do
                diff =
                  Date.diff(
                    today,
                    equipment.next_service_due
                  )

                if diff > 0, do: diff, else: nil
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :warranty_active?, :boolean do
      calculation fn records, __context ->
        today = Date.utc_today()

        values =
          Enum.map(
            records,
            fn equipment ->
              equipment.warranty_end_date &&
                Date.compare(
                  today,
                  equipment.warranty_end_date
                ) == :lt
            end
          )

        {:ok, values}
      end
    end

    calculate :age_years, :float do
      calculation fn records, __context ->
        today = Date.utc_today()

        values =
          Enum.map(
            records,
            fn equipment ->
              if equipment.installation_date do
                Date.diff(
                  today,
                  equipment.installation_date
                ) / 365.25
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :utilization_rate, :float do
      calculation fn records, __context ->
        values =
          Enum.map(
            records,
            fn equipment ->
              if equipment.planned_maintenance_hours_annual &&
                   equipment.planned_maintenance_hours_annual > 0 do
                equipment.actual_maintenance_hours_ytd /
                  equipment.planned_maintenance_hours_annual *
                  100.0
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :maintenance_cost_per_hour, :float do
      calculation fn records, __context ->
        values =
          Enum.map(
            records,
            fn equipment ->
              if equipment.operating_hours_ytd > 0 do
                equipment.maintenance_cost_ytd / equipment.operating_hours_ytd
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :availability_calculated, :float do
      calculation fn records, __context ->
        values =
          Enum.map(
            records,
            fn equipment ->
              total_hours = equipment.operating_hours_ytd + equipment.downtime_hours_ytd

              if total_hours > 0 do
                equipment.operating_hours_ytd / total_hours * 100.0
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

    policy action([
             :update_status,
             :update_condition,
             :update_usage,
             :record_service,
             :record_failure,
             :update_costs,
             :schedule_inspection
           ]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "manager")
      authorize_if actor_attribute_equals(:role, "technician")
    end

    policy action(:retire) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "manager")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :update_status
    define :update_condition
    define :update_usage
    define :record_service
    define :record_failure
    define :update_costs
    define :schedule_inspection
    define :retire
    define :add_spare_part
    define :destroy
  end

  postgres do
    table "maintenance_equipment"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :asset_tag], unique: true
      index [:serial_number], where: "serial_number IS NOT NULL"
      index [:model_number], where: "model_number IS NOT NULL"
      index [:vendor_id], where: "vendor_id IS NOT NULL"
      index [:site_id], where: "site_id IS NOT NULL"
      index [:building_id], where: "building_id IS NOT NULL"
      index [:floor_id], where: "floor_id IS NOT NULL"

      index [:successor_equipment_id],
        where: "successor_equipment_id IS NOT NULL"

      index [:equipment_type]
      index [:category]
      index [:criticality]
      index [:status]
      index [:operational_status]
      index [:lifecycle_stage]
      index [:installation_date]
      index [:last_service_date]
      index [:next_service_due], where: "next_service_due IS NOT NULL"
      index [:warranty_end_date], where: "warranty_end_date IS NOT NULL"

      index [:service_contract_expires],
        where: "service_contract_expires IS NOT NULL"

      index [:next_inspection_due], where: "next_inspection_due IS NOT NULL"

      index [:safety_critical?],
        name: "equipment_safety_critical_index",
        where: "safety_critical? = true"

      index [:monitoring_enabled?],
        name: "equipment_monitoring_index",
        where: "monitoring_enabled? = true"

      index [:expected_retirement_date],
        where: "expected_retirement_date IS NOT NULL"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Maintenance
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
