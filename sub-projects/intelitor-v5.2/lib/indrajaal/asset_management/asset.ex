defmodule Indrajaal.AssetManagement.Asset do
  @moduledoc """
  Core asset records with comprehensive tracking and lifecycle management.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AssetManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :asset_tag, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 200
    end

    attribute :description, :string do
      constraints max_length: 1000
    end

    attribute :manufacturer, :string do
      constraints max_length: 100
    end

    attribute :model, :string do
      constraints max_length: 100
    end

    attribute :serial_number, :string do
      constraints max_length: 100
    end

    attribute :asset_status, :atom do
      constraints one_of: [:active, :inactive, :maintenance, :retired, :disposed, :lost, :stolen]
      default :active
    end

    attribute :acquisition_date, :date

    attribute :acquisition_cost, :decimal do
      constraints precision: 15, scale: 2
    end

    attribute :current_value, :decimal do
      constraints precision: 15, scale: 2
    end

    attribute :useful_life_years, :integer do
      constraints min: 1, max: 50
    end

    attribute :depreciation_start_date, :date
    attribute :warranty_expiry_date, :date

    attribute :criticality_level, :atom do
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    attribute :purchase_order_number, :string do
      constraints max_length: 50
    end

    attribute :vendor_info, :map do
      default %{}
    end

    attribute :specifications, :map do
      default %{}
    end

    attribute :custom_fields, :map do
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :category, Indrajaal.AssetManagement.AssetCategory do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :current_location, Indrajaal.AssetManagement.AssetLocation do
      attribute_writable? true
    end

    belongs_to :assigned_to, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    has_many :asset_assignments, Indrajaal.AssetManagement.AssetAssignment do
      destination_attribute :asset_id
    end

    has_many :maintenance_records, Indrajaal.AssetManagement.AssetMaintenance do
      destination_attribute :asset_id
    end

    has_many :warranties, Indrajaal.AssetManagement.AssetWarranty do
      destination_attribute :asset_id
    end

    has_many :depreciation_records,
             Indrajaal.AssetManagement.AssetDepreciation do
      destination_attribute :asset_id
    end

    has_many :audit_records, Indrajaal.AssetManagement.AssetAudit do
      destination_attribute :asset_id
    end

    has_many :transfers, Indrajaal.AssetManagement.AssetTransfer do
      destination_attribute :asset_id
    end
  end

  calculations do
    calculate :age_in_years, :decimal do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          case record.acquisition_date do
            nil ->
              nil

            date ->
              days = Date.diff(today, date)
              Decimal.div(days, 365.25)
          end
        end)
      end
    end

    calculate :days_until_warranty_expiry, :integer do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          case record.warranty_expiry_date do
            nil -> nil
            date -> Date.diff(date, today)
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :register_asset do
      argument :asset_tag, :string do
        allow_nil? false
      end

      argument :name, :string do
        allow_nil? false
      end

      argument :category_id, :uuid do
        allow_nil? false
      end

      argument :acquisition_cost, :decimal
      argument :acquisition_date, :date

      change set_attribute(:asset_tag, arg(:asset_tag))
      change set_attribute(:name, arg(:name))
      change set_attribute(:category_id, arg(:category_id))
      change set_attribute(:acquisition_cost, arg(:acquisition_cost))
      change set_attribute(:acquisition_date, arg(:acquisition_date))
    end

    update :assign_to_user do
      require_atomic? false

      argument :user_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:assigned_to_id, arg(:user_id))
    end

    update :update_location do
      require_atomic? false

      argument :location_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:current_location_id, arg(:location_id))
    end

    update :change_status do
      require_atomic? false

      argument :new_status, :atom do
        allow_nil? false
      end

      change set_attribute(:asset_status, arg(:new_status))
    end

    update :update_value do
      require_atomic? false

      argument :new_value, :decimal do
        allow_nil? false
      end

      change set_attribute(:current_value, arg(:new_value))
    end

    update :retire_asset do
      require_atomic? false
      change set_attribute(:asset_status, :retired)
    end
  end

  validations do
    validate present([:asset_tag, :name, :category_id]),
      message: "Required fields must be present"

    validate compare(:current_value, greater_than_or_equal_to: 0),
      message: "Current value must be non - negative"
  end

  code_interface do
    define :create
    define :register_asset
    define :assign_to_user
    define :update_location
    define :change_status
    define :update_value
    define :retire_asset
  end

  postgres do
    table "assets"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :asset_tag], unique: true
      index [:tenant_id, :serial_number], unique: true, where: "serial_number IS NOT NULL"
      index [:tenant_id, :category_id]
      index [:tenant_id, :asset_status]
      index [:tenant_id, :assigned_to_id]
      index [:tenant_id, :current_location_id]
      index [:tenant_id, :acquisition_date]
      index [:tenant_id, :warranty_expiry_date]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Asset management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
