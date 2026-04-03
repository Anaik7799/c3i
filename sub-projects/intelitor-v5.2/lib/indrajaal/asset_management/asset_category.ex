defmodule Indrajaal.AssetManagement.AssetCategory do
  # EP-012: UnifiedCategoryFramework alias removed (unused)
  # PHASE P: Category patterns unified

  @moduledoc """
  Asset categories for classification and policy management.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AssetManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :description, :string do
      constraints max_length: 500
    end

    attribute :category_code, :string do
      allow_nil? false
      constraints max_length: 20
    end

    attribute :category_type, :atom do
      constraints one_of: [
                    :hardware,
                    :software,
                    :facility,
                    :vehicle,
                    :security_equipment,
                    :office_equipment,
                    :other
                  ]

      allow_nil? false
    end

    attribute :depreciation_method, :atom do
      constraints one_of: [
                    :straight_line,
                    :declining_balance,
                    :sum_of_years,
                    :units_of_production,
                    :none
                  ]

      default :straight_line
    end

    attribute :default_useful_life_years, :integer do
      constraints min: 1, max: 50
    end

    attribute :default_maintenance_interval_days, :integer do
      constraints min: 1, max: 3650
    end

    attribute :__requires_certification, :boolean do
      default false
    end

    attribute :is_active, :boolean do
      default true
    end

    timestamps()
  end

  relationships do
    belongs_to :parent_category, Indrajaal.AssetManagement.AssetCategory do
      attribute_writable? true
    end

    has_many :subcategories, Indrajaal.AssetManagement.AssetCategory do
      destination_attribute :parent_category_id
    end

    has_many :assets, Indrajaal.AssetManagement.Asset do
      destination_attribute :category_id
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :create_category do
      argument :name, :string do
        allow_nil? false
      end

      argument :category_code, :string do
        allow_nil? false
      end

      argument :category_type, :atom do
        allow_nil? false
      end

      change set_attribute(:name, arg(:name))
      change set_attribute(:category_code, arg(:category_code))
      change set_attribute(:category_type, arg(:category_type))
    end

    update :activate do
      require_atomic? false
      change set_attribute(:is_active, true)
    end

    update :deactivate do
      require_atomic? false
      change set_attribute(:is_active, false)
    end
  end

  code_interface do
    define :create
    define :create_category
    define :activate
    define :deactivate
  end

  postgres do
    table "asset_categories"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :category_code], unique: true
      index [:tenant_id, :category_type]
      index [:tenant_id, :is_active]
      index [:tenant_id, :parent_category_id]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Asset management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
