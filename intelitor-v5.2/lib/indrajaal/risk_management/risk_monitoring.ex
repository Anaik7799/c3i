defmodule Indrajaal.RiskManagement.RiskMonitoring do
  @moduledoc """
  Continuous risk monitoring with KPIs and automated alerts.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.RiskManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :monitoring_type, :atom do
      constraints one_of: [
                    :continuous,
                    :periodic,
                    :__event_driven,
                    :threshold_based,
                    :trend_analysis
                  ]

      allow_nil? false
    end

    attribute :monitoring_f_requency, :atom do
      constraints one_of: [:real_time, :daily, :weekly, :monthly, :quarterly, :annually]
      allow_nil? false
    end

    attribute :kpi_name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :kpi_description, :string do
      constraints max_length: 500
    end

    attribute :measurement_unit, :string do
      constraints max_length: 50
    end

    attribute :current_value, :decimal do
      constraints precision: 15, scale: 4
    end

    attribute :threshold_warning, :decimal do
      constraints precision: 15, scale: 4
    end

    attribute :threshold_critical, :decimal do
      constraints precision: 15, scale: 4
    end

    attribute :target_value, :decimal do
      constraints precision: 15, scale: 4
    end

    attribute :trend_direction, :atom do
      constraints one_of: [:improving, :stable, :declining, :volatile]
    end

    attribute :last_measurement_date, :utc_datetime
    attribute :next_measurement_date, :utc_datetime

    attribute :data_source, :string do
      constraints max_length: 200
    end

    attribute :automated_collection, :boolean do
      default false
    end

    attribute :alert_enabled, :boolean do
      default true
    end

    attribute :alert_recipients, {:array, :uuid} do
      default []
    end

    attribute :historical_data, {:array, :map} do
      default []
    end

    attribute :monitoring_notes, :string do
      constraints max_length: 1000
    end

    timestamps()
  end

  relationships do
    belongs_to :risk, Indrajaal.RiskManagement.Risk do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :monitor_owner, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    has_many :incidents, Indrajaal.RiskManagement.RiskIncident do
      destination_attribute :triggered_by_monitoring_id
    end
  end

  calculations do
    calculate :variance_from_target, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case {record.current_value, record.target_value} do
            {current, target} when not is_nil(current) and not is_nil(target) ->
              Decimal.sub(current, target)

            _ ->
              nil
          end
        end)
      end
    end

    calculate :is_threshold_breached, :boolean do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          current = record.current_value
          critical = record.threshold_critical
          warning = record.threshold_warning

          cond do
            is_nil(current) ->
              false

            not is_nil(critical) and
                Decimal.compare(
                  current,
                  critical
                ) != :lt ->
              true

            not is_nil(warning) and
                Decimal.compare(
                  current,
                  warning
                ) != :lt ->
              true

            true ->
              false
          end
        end)
      end
    end

    calculate :days_since_measurement, :integer do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          case record.last_measurement_date do
            nil -> nil
            last_date -> DateTime.diff(now, last_date, :day)
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :setup_monitoring do
      argument :risk_id, :uuid do
        allow_nil? false
      end

      argument :monitoring_type, :atom do
        allow_nil? false
      end

      argument :f_requency, :atom do
        allow_nil? false
      end

      argument :kpi_name, :string do
        allow_nil? false
      end

      argument :monitor_owner_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:risk_id, arg(:risk_id))
      change set_attribute(:monitoring_type, arg(:monitoring_type))
      change set_attribute(:monitoring_f_requency, arg(:f_requency))
      change set_attribute(:kpi_name, arg(:kpi_name))
      change set_attribute(:monitor_owner_id, arg(:monitor_owner_id))
    end

    update :set_thresholds do
      require_atomic? false
      argument :warning_threshold, :decimal
      argument :critical_threshold, :decimal
      argument :target_value, :decimal

      change set_attribute(:threshold_warning, arg(:warning_threshold))
      change set_attribute(:threshold_critical, arg(:critical_threshold))
      change set_attribute(:target_value, arg(:target_value))
    end

    update :record_measurement do
      require_atomic? false

      argument :value, :decimal do
        allow_nil? false
      end

      argument :measurement_notes, :string

      change set_attribute(:current_value, arg(:value))
      change set_attribute(:last_measurement_date, &DateTime.utc_now/0)
      change set_attribute(:monitoring_notes, arg(:measurement_notes))

      change fn changeset, _ ->
        # Add to historical data
        current_history = changeset.data.historical_data || []
        new_value = Ash.Changeset.get_argument(changeset, :value)

        new_entry = %{
          "value" => new_value,
          "timestamp" => DateTime.utc_now(),
          "notes" => Ash.Changeset.get_argument(changeset, :measurement_notes)
        }

        # Keep only last 100 measurements
        updated_history = [new_entry | current_history] |> Enum.take(100)
        Ash.Changeset.change_attribute(changeset, :historical_data, updated_history)
      end
    end

    update :update_trend do
      require_atomic? false

      argument :trend_direction, :atom do
        allow_nil? false
      end

      change set_attribute(:trend_direction, arg(:trend_direction))
    end

    update :schedule_next_measurement do
      require_atomic? false

      argument :next_date, :utc_datetime do
        allow_nil? false
      end

      change set_attribute(:next_measurement_date, arg(:next_date))
    end

    update :configure_alerts do
      require_atomic? false

      argument :alert_enabled, :boolean do
        allow_nil? false
      end

      argument :alert_recipients, {:array, :uuid}

      change set_attribute(:alert_enabled, arg(:alert_enabled))
      change set_attribute(:alert_recipients, arg(:alert_recipients))
    end

    update :enable_automation do
      require_atomic? false

      argument :data_source, :string do
        allow_nil? false
      end

      change set_attribute(:automated_collection, true)
      change set_attribute(:data_source, arg(:data_source))
    end

    update :disable_automation do
      require_atomic? false
      change set_attribute(:automated_collection, false)
    end
  end

  code_interface do
    define :create
    define :setup_monitoring
    define :set_thresholds
    define :record_measurement
    define :update_trend
    define :schedule_next_measurement
    define :configure_alerts
    define :enable_automation
    define :disable_automation
  end

  postgres do
    table "risk_monitoring"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :risk_id]
      index [:tenant_id, :monitoring_type]
      index [:tenant_id, :monitoring_f_requency]
      index [:tenant_id, :monitor_owner_id]
      index [:tenant_id, :last_measurement_date]

      index [:tenant_id, :next_measurement_date],
        where: "next_measurement_date IS NOT NULL"

      index [:tenant_id, :alert_enabled]
      index [:tenant_id, :automated_collection]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Risk management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
