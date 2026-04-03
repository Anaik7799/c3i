defmodule Indrajaal.AssetManagement.AssetRetirement do
  @moduledoc """
  Asset retirement, disposal, and end - of - life management.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AssetManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :retirement_type, :atom do
      constraints one_of: [
                    :end_of_life,
                    :obsolete,
                    :damaged_beyond_repair,
                    :security_risk,
                    :cost_ineffective,
                    :upgrade
                  ]

      allow_nil? false
    end

    attribute :retirement_status, :atom do
      constraints one_of: [:proposed, :approved, :in_progress, :completed, :cancelled]
      default :proposed
    end

    attribute :proposed_date, :date do
      allow_nil? false
      default &Date.utc_today/0
    end

    attribute :approved_date, :date
    attribute :retirement_date, :date

    attribute :retirement_reason, :string do
      allow_nil? false
      constraints max_length: 1000
    end

    attribute :disposal_method, :atom do
      constraints one_of: [
                    :sale,
                    :donation,
                    :recycling,
                    :destruction,
                    :return_to_vendor,
                    :trade_in
                  ]
    end

    attribute :disposal_value, :decimal do
      constraints precision: 10, scale: 2
    end

    attribute :disposal_cost, :decimal do
      constraints precision: 10, scale: 2
    end

    attribute :environmental_impact, :string do
      constraints max_length: 500
    end

    attribute :__data_destruction_required, :boolean do
      default false
    end

    attribute :__data_destruction_completed, :boolean do
      default false
    end

    attribute :__data_destruction_method, :string do
      constraints max_length: 200
    end

    attribute :certificate_of_destruction, :string do
      constraints max_length: 200
    end

    attribute :replacement_asset_id, :uuid

    attribute :retirement_notes, :string do
      constraints max_length: 2000
    end

    attribute :regulatory_requirements, {:array, :string} do
      default []
    end

    attribute :compliance_verified, :boolean do
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :asset, Indrajaal.AssetManagement.Asset do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :proposed_by, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :approved_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    belongs_to :completed_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    belongs_to :replacement_asset, Indrajaal.AssetManagement.Asset do
      attribute_writable? true
    end
  end

  calculations do
    calculate :net_disposal_value, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          disposal_value = record.disposal_value || Decimal.new(0)
          disposal_cost = record.disposal_cost || Decimal.new(0)
          Decimal.sub(disposal_value, disposal_cost)
        end)
      end
    end

    calculate :days_since_proposed, :integer do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          Date.diff(today, record.proposed_date)
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :propose_retirement do
      argument :asset_id, :uuid do
        allow_nil? false
      end

      argument :retirement_type, :atom do
        allow_nil? false
      end

      argument :retirement_reason, :string do
        allow_nil? false
      end

      argument :proposed_by_id, :uuid do
        allow_nil? false
      end

      argument :proposed_date, :date, default: &Date.utc_today/0

      change set_attribute(:asset_id, arg(:asset_id))
      change set_attribute(:retirement_type, arg(:retirement_type))
      change set_attribute(:retirement_reason, arg(:retirement_reason))
      change set_attribute(:proposed_by_id, arg(:proposed_by_id))
      change set_attribute(:proposed_date, arg(:proposed_date))
    end

    update :approve_retirement do
      require_atomic? false

      argument :approved_by_id, :uuid do
        allow_nil? false
      end

      argument :disposal_method, :atom do
        allow_nil? false
      end

      argument :expected_disposal_value, :decimal

      change set_attribute(:retirement_status, :approved)
      change set_attribute(:approved_date, Date.utc_today())
      change set_attribute(:approved_by_id, arg(:approved_by_id))
      change set_attribute(:disposal_method, arg(:disposal_method))
      change set_attribute(:disposal_value, arg(:expected_disposal_value))
    end

    update :start_retirement do
      require_atomic? false
      change set_attribute(:retirement_status, :in_progress)
    end

    update :complete_retirement do
      require_atomic? false

      argument :completed_by_id, :uuid do
        allow_nil? false
      end

      argument :actual_disposal_value, :decimal
      argument :disposal_cost, :decimal
      argument :completion_notes, :string

      change set_attribute(:retirement_status, :completed)
      change set_attribute(:retirement_date, Date.utc_today())
      change set_attribute(:completed_by_id, arg(:completed_by_id))
      change set_attribute(:disposal_value, arg(:actual_disposal_value))
      change set_attribute(:disposal_cost, arg(:disposal_cost))
      change set_attribute(:retirement_notes, arg(:completion_notes))
    end

    update :complete_data_destruction do
      require_atomic? false

      argument :destruction_method, :string do
        allow_nil? false
      end

      argument :certificate_number, :string

      change set_attribute(:__data_destruction_completed, true)
      change set_attribute(:__data_destruction_method, arg(:destruction_method))

      change set_attribute(
               :certificate_of_destruction,
               arg(:certificate_number)
             )
    end

    update :verify_compliance do
      require_atomic? false
      change set_attribute(:compliance_verified, true)
    end

    update :cancel_retirement do
      require_atomic? false

      argument :cancellation_reason, :string do
        allow_nil? false
      end

      change set_attribute(:retirement_status, :cancelled)
      change set_attribute(:retirement_notes, arg(:cancellation_reason))
    end

    update :assign_replacement do
      require_atomic? false

      argument :replacement_asset_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:replacement_asset_id, arg(:replacement_asset_id))
    end
  end

  code_interface do
    define :create
    define :propose_retirement
    define :approve_retirement
    define :start_retirement
    define :complete_retirement
    define :complete_data_destruction
    define :verify_compliance
    define :cancel_retirement
    define :assign_replacement
  end

  postgres do
    table "asset_retirements"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :asset_id]
      index [:tenant_id, :retirement_status]
      index [:tenant_id, :retirement_type]
      index [:tenant_id, :proposed_date]
      index [:tenant_id, :retirement_date], where: "retirement_date IS NOT NULL"
      index [:tenant_id, :__data_destruction_required]
      index [:tenant_id, :compliance_verified]

      index [:tenant_id, :replacement_asset_id],
        where: "replacement_asset_id IS NOT NULL"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Asset management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
