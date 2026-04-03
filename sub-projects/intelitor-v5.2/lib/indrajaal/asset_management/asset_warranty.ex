defmodule Indrajaal.AssetManagement.AssetWarranty do
  @moduledoc """
  Warranty tracking and management for assets.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AssetManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :warranty_type, :atom do
      constraints one_of: [:manufacturer, :extended, :service_contract, :insurance]
      allow_nil? false
    end

    attribute :provider_name, :string do
      allow_nil? false
      constraints max_length: 200
    end

    attribute :warranty_number, :string do
      constraints max_length: 100
    end

    attribute :start_date, :date do
      allow_nil? false
    end

    attribute :end_date, :date do
      allow_nil? false
    end

    attribute :coverage_type, :atom do
      constraints one_of: [:full, :parts_only, :labor_only, :limited]
      default :full
    end

    attribute :coverage_details, :string do
      constraints max_length: 1000
    end

    attribute :cost, :decimal do
      constraints precision: 10, scale: 2
    end

    attribute :terms_and_conditions, :string do
      constraints max_length: 5000
    end

    attribute :contact_info, :map do
      default %{}
    end

    attribute :is_active, :boolean do
      default true
    end

    attribute :auto_renewal, :boolean do
      default false
    end

    attribute :renewal_notice_days, :integer do
      default 30
      constraints min: 1, max: 365
    end

    timestamps()
  end

  relationships do
    belongs_to :asset, Indrajaal.AssetManagement.Asset do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :purchased_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end
  end

  calculations do
    calculate :days_remaining, :integer do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          Date.diff(record.end_date, today)
        end)
      end
    end

    calculate :is_expired, :boolean do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          Date.compare(today, record.end_date) == :gt
        end)
      end
    end

    calculate :is_expiring_soon, :boolean do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          days_until_expiry = Date.diff(record.end_date, today)
          notice_days = record.renewal_notice_days || 30
          days_until_expiry <= notice_days && days_until_expiry > 0
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :register_warranty do
      argument :asset_id, :uuid do
        allow_nil? false
      end

      argument :warranty_type, :atom do
        allow_nil? false
      end

      argument :provider_name, :string do
        allow_nil? false
      end

      argument :start_date, :date do
        allow_nil? false
      end

      argument :end_date, :date do
        allow_nil? false
      end

      change set_attribute(:asset_id, arg(:asset_id))
      change set_attribute(:warranty_type, arg(:warranty_type))
      change set_attribute(:provider_name, arg(:provider_name))
      change set_attribute(:start_date, arg(:start_date))
      change set_attribute(:end_date, arg(:end_date))
    end

    update :extend_warranty do
      require_atomic? false

      argument :new_end_date, :date do
        allow_nil? false
      end

      argument :additional_cost, :decimal

      change set_attribute(:end_date, arg(:new_end_date))

      change fn changeset, _ ->
        current_cost = changeset.data.cost || Decimal.new(0)
        additional = Ash.Changeset.get_argument(changeset, :additional_cost) || Decimal.new(0)
        new_cost = Decimal.add(current_cost, additional)
        Ash.Changeset.change_attribute(changeset, :cost, new_cost)
      end
    end

    update :activate do
      require_atomic? false
      change set_attribute(:is_active, true)
    end

    update :deactivate do
      require_atomic? false
      change set_attribute(:is_active, false)
    end

    update :enable_auto_renewal do
      require_atomic? false
      argument :notice_days, :integer, default: 30

      change set_attribute(:auto_renewal, true)
      change set_attribute(:renewal_notice_days, arg(:notice_days))
    end

    update :disable_auto_renewal do
      require_atomic? false
      change set_attribute(:auto_renewal, false)
    end
  end

  validations do
    validate compare(:end_date, greater_than: :start_date),
      message: "End date must be after start date"
  end

  code_interface do
    define :create
    define :register_warranty
    define :extend_warranty
    define :activate
    define :deactivate
    define :enable_auto_renewal
    define :disable_auto_renewal
  end

  postgres do
    table "asset_warranties"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :asset_id]
      index [:tenant_id, :warranty_type]
      index [:tenant_id, :provider_name]
      index [:tenant_id, :end_date]
      index [:tenant_id, :is_active]
      index [:tenant_id, :auto_renewal]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Asset management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
