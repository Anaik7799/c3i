defmodule Indrajaal.RiskManagement.RiskIncident do
  @moduledoc """
  Risk incidents and materialized risk __events with impact analysis.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.RiskManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :incident_id, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :incident_title, :string do
      allow_nil? false
      constraints max_length: 200
    end

    attribute :incident_description, :string do
      allow_nil? false
      constraints max_length: 3000
    end

    attribute :incident_date, :utc_datetime do
      allow_nil? false
    end

    attribute :discovery_date, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :incident_status, :atom do
      constraints one_of: [:reported, :investigating, :contained, :resolved, :closed]
      default :reported
    end

    attribute :severity_level, :atom do
      constraints one_of: [:minimal, :minor, :moderate, :major, :critical]
      allow_nil? false
    end

    attribute :actual_impact, :string do
      constraints max_length: 2000
    end

    attribute :financial_impact, :decimal do
      constraints precision: 15, scale: 2
    end

    attribute :operational_impact, :string do
      constraints max_length: 1000
    end

    attribute :reputational_impact, :string do
      constraints max_length: 1000
    end

    attribute :regulatory_impact, :string do
      constraints max_length: 1000
    end

    attribute :root_cause_analysis, :string do
      constraints max_length: 3000
    end

    attribute :contributing_factors, {:array, :string} do
      default []
    end

    attribute :lessons_learned, :string do
      constraints max_length: 2000
    end

    attribute :corrective_actions, {:array, :string} do
      default []
    end

    attribute :pr_eventive_actions, {:array, :string} do
      default []
    end

    attribute :containment_actions, {:array, :string} do
      default []
    end

    attribute :recovery_time, :integer

    attribute :notification_sent, :boolean do
      default false
    end

    attribute :external_reporting_required, :boolean do
      default false
    end

    attribute :external_agencies_notified, {:array, :string} do
      default []
    end

    timestamps()
  end

  relationships do
    belongs_to :risk, Indrajaal.RiskManagement.Risk do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :reported_by, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :incident_manager, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    belongs_to :triggered_by_monitoring,
               Indrajaal.RiskManagement.RiskMonitoring do
      attribute_writable? true
    end
  end

  calculations do
    calculate :time_to_discovery, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          DateTime.diff(record.discovery_date, record.incident_date, :hour)
        end)
      end
    end

    calculate :days_since_incident, :integer do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          DateTime.diff(now, record.incident_date, :day)
        end)
      end
    end

    calculate :is_high_impact, :boolean do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          record.severity_level in [:major, :critical] or
            (not is_nil(record.financial_impact) and
               Decimal.compare(record.financial_impact, 10_000) != :lt)
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :report_incident do
      argument :incident_id, :string do
        allow_nil? false
      end

      argument :title, :string do
        allow_nil? false
      end

      argument :description, :string do
        allow_nil? false
      end

      argument :incident_date, :utc_datetime do
        allow_nil? false
      end

      argument :risk_id, :uuid do
        allow_nil? false
      end

      argument :reported_by_id, :uuid do
        allow_nil? false
      end

      argument :severity_level, :atom do
        allow_nil? false
      end

      change set_attribute(:incident_id, arg(:incident_id))
      change set_attribute(:incident_title, arg(:title))
      change set_attribute(:incident_description, arg(:description))
      change set_attribute(:incident_date, arg(:incident_date))
      change set_attribute(:risk_id, arg(:risk_id))
      change set_attribute(:reported_by_id, arg(:reported_by_id))
      change set_attribute(:severity_level, arg(:severity_level))
    end

    update :assign_manager do
      require_atomic? false

      argument :manager_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:incident_manager_id, arg(:manager_id))
      change set_attribute(:incident_status, :investigating)
    end

    update :assess_impact do
      require_atomic? false

      argument :actual_impact, :string do
        allow_nil? false
      end

      argument :financial_impact, :decimal
      argument :operational_impact, :string
      argument :reputational_impact, :string

      change set_attribute(:actual_impact, arg(:actual_impact))
      change set_attribute(:financial_impact, arg(:financial_impact))
      change set_attribute(:operational_impact, arg(:operational_impact))
      change set_attribute(:reputational_impact, arg(:reputational_impact))
    end

    update :conduct_root_cause_analysis do
      require_atomic? false

      argument :root_cause, :string do
        allow_nil? false
      end

      argument :contributing_factors, {:array, :string}

      change set_attribute(:root_cause_analysis, arg(:root_cause))
      change set_attribute(:contributing_factors, arg(:contributing_factors))
    end

    update :implement_containment do
      require_atomic? false

      argument :containment_actions, {:array, :string} do
        allow_nil? false
      end

      change set_attribute(:incident_status, :contained)
      change set_attribute(:containment_actions, arg(:containment_actions))
    end

    update :implement_corrective_actions do
      require_atomic? false

      argument :corrective_actions, {:array, :string} do
        allow_nil? false
      end

      argument :pr_eventive_actions, {:array, :string}

      change set_attribute(:corrective_actions, arg(:corrective_actions))
      change set_attribute(:pr_eventive_actions, arg(:pr_eventive_actions))
    end

    update :resolve_incident do
      require_atomic? false

      argument :lessons_learned, :string do
        allow_nil? false
      end

      argument :recovery_time_hours, :integer

      change set_attribute(:incident_status, :resolved)
      change set_attribute(:lessons_learned, arg(:lessons_learned))
      change set_attribute(:recovery_time, arg(:recovery_time_hours))
    end

    update :close_incident do
      require_atomic? false
      change set_attribute(:incident_status, :closed)
    end

    update :send_notifications do
      require_atomic? false
      argument :external_agencies, {:array, :string}

      change set_attribute(:notification_sent, true)
      change set_attribute(:external_agencies_notified, arg(:external_agencies))
      change set_attribute(:external_reporting_required, true)
    end
  end

  code_interface do
    define :create
    define :report_incident
    define :assign_manager
    define :assess_impact
    define :conduct_root_cause_analysis
    define :implement_containment
    define :implement_corrective_actions
    define :resolve_incident
    define :close_incident
    define :send_notifications
  end

  postgres do
    table "risk_incidents"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :incident_id], unique: true
      index [:tenant_id, :risk_id]
      index [:tenant_id, :incident_status]
      index [:tenant_id, :severity_level]
      index [:tenant_id, :incident_date]
      index [:tenant_id, :discovery_date]
      index [:tenant_id, :reported_by_id]
      index [:tenant_id, :incident_manager_id]
      index [:tenant_id, :external_reporting_required]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Risk management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
