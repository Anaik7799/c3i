defmodule Indrajaal.RiskManagement.RiskCategory do
  # EP-012: UnifiedCategoryFramework alias removed (unused)
  # PHASE P: Category patterns unified

  @moduledoc """
  Risk categories for classification and management framework organization.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.RiskManagement

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
                    :operational,
                    :financial,
                    :strategic,
                    :compliance,
                    :cyber_security,
                    :physical_security,
                    :reputational,
                    :environmental
                  ]

      allow_nil? false
    end

    attribute :severity_scale, :map do
      default %{
        "1" => "Minimal",
        "2" => "Minor",
        "3" => "Moderate",
        "4" => "Major",
        "5" => "Critical"
      }
    end

    attribute :probability_scale, :map do
      default %{
        "1" => "Very Low",
        "2" => "Low",
        "3" => "Medium",
        "4" => "High",
        "5" => "Very High"
      }
    end

    attribute :default_assessment_f_requency, :integer do
      default 90
      constraints min: 7, max: 365
    end

    attribute :regulatory_framework, {:array, :string} do
      default []
    end

    attribute :is_active, :boolean do
      default true
    end

    attribute :escalation_threshold, :integer do
      default 15
      constraints min: 1, max: 25
    end

    timestamps()
  end

  relationships do
    belongs_to :parent_category, Indrajaal.RiskManagement.RiskCategory do
      attribute_writable? true
    end

    has_many :subcategories, Indrajaal.RiskManagement.RiskCategory do
      destination_attribute :parent_category_id
    end

    has_many :risks, Indrajaal.RiskManagement.Risk do
      destination_attribute :category_id
    end

    has_many :risk_matrices, Indrajaal.RiskManagement.RiskMatrix do
      destination_attribute :category_id
    end
  end

  actions do
    defaults [:read, :update, :destroy]

    create :create do
      primary? true

      accept [
        :name,
        :description,
        :category_code,
        :category_type,
        :is_active,
        :severity_scale,
        :probability_scale,
        :default_assessment_f_requency,
        :regulatory_framework,
        :escalation_threshold
      ]
    end

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

    update :update_scales do
      require_atomic? false
      argument :severity_scale, :map
      argument :probability_scale, :map

      change set_attribute(:severity_scale, arg(:severity_scale))
      change set_attribute(:probability_scale, arg(:probability_scale))
    end
  end

  code_interface do
    define :create
    define :create_category
    define :activate
    define :deactivate
    define :update_scales
  end

  postgres do
    table "risk_categories"
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
# Domain: Risk management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
