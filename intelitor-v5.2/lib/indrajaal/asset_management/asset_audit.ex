defmodule Indrajaal.AssetManagement.AssetAudit do
  @moduledoc """
  Asset audit trails and periodic inventory verification.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AssetManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :audit_type, :atom do
      constraints one_of: [
                    :physical_inventory,
                    :financial_audit,
                    :compliance_check,
                    :condition_assessment,
                    :periodic_review
                  ]

      allow_nil? false
    end

    attribute :audit_date, :date do
      allow_nil? false
      default &Date.utc_today/0
    end

    attribute :audit_status, :atom do
      constraints one_of: [:scheduled, :in_progress, :completed, :failed, :cancelled]
      default :scheduled
    end

    attribute :physical_condition, :atom do
      constraints one_of: [:excellent, :good, :fair, :poor, :damaged, :missing]
    end

    attribute :location_verified, :boolean do
      default false
    end

    attribute :assignment_verified, :boolean do
      default false
    end

    attribute :documentation_complete, :boolean do
      default false
    end

    attribute :compliance_status, :atom do
      constraints one_of: [:compliant, :non_compliant, :needs_review, :not_applicable]
    end

    attribute :findings, :string do
      constraints max_length: 2000
    end

    attribute :recommendations, {:array, :string} do
      default []
    end

    attribute :corrective_actions_required, :boolean do
      default false
    end

    attribute :estimated_current_value, :decimal do
      constraints precision: 15, scale: 2
    end

    attribute :audit_notes, :string do
      constraints max_length: 2000
    end

    attribute :photos_attached, :boolean do
      default false
    end

    attribute :next_audit_date, :date

    timestamps()
  end

  relationships do
    belongs_to :asset, Indrajaal.AssetManagement.Asset do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :auditor, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :reviewed_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end
  end

  calculations do
    calculate :days_since_audit, :integer do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          Date.diff(today, record.audit_date)
        end)
      end
    end

    calculate :is_audit_overdue, :boolean do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          case record.next_audit_date do
            nil -> false
            next_date -> Date.compare(today, next_date) == :gt
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :schedule_audit do
      argument :asset_id, :uuid do
        allow_nil? false
      end

      argument :audit_type, :atom do
        allow_nil? false
      end

      argument :auditor_id, :uuid do
        allow_nil? false
      end

      argument :audit_date, :date do
        allow_nil? false
      end

      change set_attribute(:asset_id, arg(:asset_id))
      change set_attribute(:audit_type, arg(:audit_type))
      change set_attribute(:auditor_id, arg(:auditor_id))
      change set_attribute(:audit_date, arg(:audit_date))
    end

    update :start_audit do
      require_atomic? false
      change set_attribute(:audit_status, :in_progress)
    end

    update :complete_audit do
      require_atomic? false

      argument :physical_condition, :atom do
        allow_nil? false
      end

      argument :location_verified, :boolean do
        allow_nil? false
      end

      argument :findings, :string
      argument :estimated_value, :decimal

      change set_attribute(:audit_status, :completed)
      change set_attribute(:physical_condition, arg(:physical_condition))
      change set_attribute(:location_verified, arg(:location_verified))
      change set_attribute(:findings, arg(:findings))
      change set_attribute(:estimated_current_value, arg(:estimated_value))
    end

    update :add_findings do
      require_atomic? false

      argument :findings, :string do
        allow_nil? false
      end

      argument :recommendations, {:array, :string}
      argument :__requires_action, :boolean, default: false

      change set_attribute(:findings, arg(:findings))
      change set_attribute(:recommendations, arg(:recommendations))
      change set_attribute(:corrective_actions_required, arg(:__requires_action))
    end

    update :schedule_next_audit do
      require_atomic? false

      argument :next_date, :date do
        allow_nil? false
      end

      change set_attribute(:next_audit_date, arg(:next_date))
    end

    update :cancel_audit do
      require_atomic? false

      argument :reason, :string do
        allow_nil? false
      end

      change set_attribute(:audit_status, :cancelled)
      change set_attribute(:audit_notes, arg(:reason))
    end
  end

  code_interface do
    define :create
    define :schedule_audit
    define :start_audit
    define :complete_audit
    define :add_findings
    define :schedule_next_audit
    define :cancel_audit
  end

  postgres do
    table "asset_audits"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :asset_id]
      index [:tenant_id, :audit_type]
      index [:tenant_id, :audit_status]
      index [:tenant_id, :audit_date]
      index [:tenant_id, :auditor_id]
      index [:tenant_id, :next_audit_date], where: "next_audit_date IS NOT NULL"
      index [:tenant_id, :physical_condition]
      index [:tenant_id, :compliance_status]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Asset management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
