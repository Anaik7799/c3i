defmodule Indrajaal.RiskManagement.RiskMatrix do
  @moduledoc """
  Risk assessment matrices for consistent risk evaluation and visualization.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.RiskManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :matrix_name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :matrix_description, :string do
      constraints max_length: 500
    end

    attribute :matrix_type, :atom do
      constraints one_of: [:standard_5x5, :standard_4x4, :standard_3x3, :custom]
      default :standard_5x5
    end

    attribute :probability_scale, :map do
      allow_nil? false

      default %{
        "1" => %{"label" => "Very Low", "description" => "0 - 5%", "color" => "#green"},
        "2" => %{"label" => "Low", "description" => "6 - 25%", "color" => "#yellow"},
        "3" => %{"label" => "Medium", "description" => "26 - 50%", "color" => "#orange"},
        "4" => %{"label" => "High", "description" => "51 - 75%", "color" => "#red"},
        "5" => %{"label" => "Very High", "description" => "76 - 100%", "color" => "#darkred"}
      }
    end

    attribute :impact_scale, :map do
      allow_nil? false

      default %{
        "1" => %{"label" => "Minimal", "description" => "Minor disruption", "color" => "#green"},
        "2" => %{"label" => "Minor", "description" => "Some disruption", "color" => "#yellow"},
        "3" => %{
          "label" => "Moderate",
          "description" => "Significant impact",
          "color" => "#orange"
        },
        "4" => %{"label" => "Major", "description" => "Major disruption", "color" => "#red"},
        "5" => %{"label" => "Critical", "description" => "Severe impact", "color" => "#darkred"}
      }
    end

    attribute :risk_tolerance_levels, :map do
      default %{
        "low" => %{"range" => "1 - 4", "action" => "Monitor", "color" => "#green"},
        "medium" => %{"range" => "5 - 12", "action" => "Manage", "color" => "#yellow"},
        "high" => %{"range" => "13 - 20", "action" => "Mitigate", "color" => "#orange"},
        "critical" => %{"range" => "21 - 25", "action" => "Immediate Action", "color" => "#red"}
      }
    end

    attribute :matrix_grid, :map do
      default %{}
    end

    attribute :is_default, :boolean do
      default false
    end

    attribute :is_active, :boolean do
      default true
    end

    attribute :approval_required, :boolean do
      default false
    end

    attribute :version, :string do
      default "1.0"
      constraints max_length: 10
    end

    timestamps()
  end

  relationships do
    belongs_to :category, Indrajaal.RiskManagement.RiskCategory do
      attribute_writable? true
    end

    belongs_to :created_by, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :approved_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end
  end

  calculations do
    calculate :total_risk_levels, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          prob_levels = map_size(record.probability_scale)
          impact_levels = map_size(record.impact_scale)
          prob_levels * impact_levels
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :create_matrix do
      argument :matrix_name, :string do
        allow_nil? false
      end

      argument :matrix_type, :atom do
        allow_nil? false
      end

      argument :created_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:matrix_name, arg(:matrix_name))
      change set_attribute(:matrix_type, arg(:matrix_type))
      change set_attribute(:created_by_id, arg(:created_by_id))

      # Generate matrix grid based on type
      change fn changeset, _ ->
        matrix_type = Ash.Changeset.get_argument(changeset, :matrix_type)

        grid =
          case matrix_type do
            :standard_5x5 -> generate_5x5_grid()
            :standard_4x4 -> generate_4x4_grid()
            :standard_3x3 -> generate_3x3_grid()
            :custom -> %{}
          end

        Ash.Changeset.change_attribute(changeset, :matrix_grid, grid)
      end
    end

    update :customize_scales do
      require_atomic? false

      argument :probability_scale, :map do
        allow_nil? false
      end

      argument :impact_scale, :map do
        allow_nil? false
      end

      change set_attribute(:probability_scale, arg(:probability_scale))
      change set_attribute(:impact_scale, arg(:impact_scale))
      change set_attribute(:matrix_type, :custom)
    end

    update :set_tolerance_levels do
      require_atomic? false

      argument :tolerance_levels, :map do
        allow_nil? false
      end

      change set_attribute(:risk_tolerance_levels, arg(:tolerance_levels))
    end

    update :activate_matrix do
      require_atomic? false
      change set_attribute(:is_active, true)
    end

    update :deactivate_matrix do
      require_atomic? false
      change set_attribute(:is_active, false)
    end

    update :set_as_default do
      require_atomic? false
      change set_attribute(:is_default, true)
    end

    update :approve_matrix do
      require_atomic? false

      argument :approved_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:approved_by_id, arg(:approved_by_id))
    end

    update :update_version do
      require_atomic? false

      argument :new_version, :string do
        allow_nil? false
      end

      change set_attribute(:version, arg(:new_version))
    end
  end

  code_interface do
    define :create
    define :create_matrix
    define :customize_scales
    define :set_tolerance_levels
    define :activate_matrix
    define :deactivate_matrix
    define :set_as_default
    define :approve_matrix
    define :update_version
  end

  # Helper functions for generating standard grids
  defp generate_5x5_grid do
    %{
      "1,1" => %{"score" => 1, "level" => "low", "color" => "#green"},
      "1,2" => %{"score" => 2, "level" => "low", "color" => "#green"},
      "1,3" => %{"score" => 3, "level" => "low", "color" => "#green"},
      "1,4" => %{"score" => 4, "level" => "low", "color" => "#green"},
      "1,5" => %{"score" => 5, "level" => "medium", "color" => "#yellow"},
      "2,1" => %{"score" => 2, "level" => "low", "color" => "#green"},
      "2,2" => %{"score" => 4, "level" => "low", "color" => "#green"},
      "2,3" => %{"score" => 6, "level" => "medium", "color" => "#yellow"},
      "2,4" => %{"score" => 8, "level" => "medium", "color" => "#yellow"},
      "2,5" => %{"score" => 10, "level" => "medium", "color" => "#yellow"},
      "3,1" => %{"score" => 3, "level" => "low", "color" => "#green"},
      "3,2" => %{"score" => 6, "level" => "medium", "color" => "#yellow"},
      "3,3" => %{"score" => 9, "level" => "medium", "color" => "#yellow"},
      "3,4" => %{"score" => 12, "level" => "medium", "color" => "#yellow"},
      "3,5" => %{"score" => 15, "level" => "high", "color" => "#orange"},
      "4,1" => %{"score" => 4, "level" => "low", "color" => "#green"},
      "4,2" => %{"score" => 8, "level" => "medium", "color" => "#yellow"},
      "4,3" => %{"score" => 12, "level" => "medium", "color" => "#yellow"},
      "4,4" => %{"score" => 16, "level" => "high", "color" => "#orange"},
      "4,5" => %{"score" => 20, "level" => "high", "color" => "#orange"},
      "5,1" => %{"score" => 5, "level" => "medium", "color" => "#yellow"},
      "5,2" => %{"score" => 10, "level" => "medium", "color" => "#yellow"},
      "5,3" => %{"score" => 15, "level" => "high", "color" => "#orange"},
      "5,4" => %{"score" => 20, "level" => "high", "color" => "#orange"},
      "5,5" => %{"score" => 25, "level" => "critical", "color" => "#red"}
    }
  end

  defp generate_4x4_grid do
    %{
      "1,1" => %{"score" => 1, "level" => "low", "color" => "#green"},
      "1,2" => %{"score" => 2, "level" => "low", "color" => "#green"},
      "1,3" => %{"score" => 3, "level" => "low", "color" => "#green"},
      "1,4" => %{"score" => 4, "level" => "medium", "color" => "#yellow"},
      "2,1" => %{"score" => 2, "level" => "low", "color" => "#green"},
      "2,2" => %{"score" => 4, "level" => "medium", "color" => "#yellow"},
      "2,3" => %{"score" => 6, "level" => "medium", "color" => "#yellow"},
      "2,4" => %{"score" => 8, "level" => "medium", "color" => "#yellow"},
      "3,1" => %{"score" => 3, "level" => "low", "color" => "#green"},
      "3,2" => %{"score" => 6, "level" => "medium", "color" => "#yellow"},
      "3,3" => %{"score" => 9, "level" => "medium", "color" => "#yellow"},
      "3,4" => %{"score" => 12, "level" => "high", "color" => "#orange"},
      "4,1" => %{"score" => 4, "level" => "medium", "color" => "#yellow"},
      "4,2" => %{"score" => 8, "level" => "medium", "color" => "#yellow"},
      "4,3" => %{"score" => 12, "level" => "high", "color" => "#orange"},
      "4,4" => %{"score" => 16, "level" => "critical", "color" => "#red"}
    }
  end

  defp generate_3x3_grid do
    %{
      "1,1" => %{"score" => 1, "level" => "low", "color" => "#green"},
      "1,2" => %{"score" => 2, "level" => "low", "color" => "#green"},
      "1,3" => %{"score" => 3, "level" => "medium", "color" => "#yellow"},
      "2,1" => %{"score" => 2, "level" => "low", "color" => "#green"},
      "2,2" => %{"score" => 4, "level" => "medium", "color" => "#yellow"},
      "2,3" => %{"score" => 6, "level" => "medium", "color" => "#yellow"},
      "3,1" => %{"score" => 3, "level" => "medium", "color" => "#yellow"},
      "3,2" => %{"score" => 6, "level" => "medium", "color" => "#yellow"},
      "3,3" => %{"score" => 9, "level" => "high", "color" => "#red"}
    }
  end

  postgres do
    table "risk_matrices"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :matrix_name], unique: true
      index [:tenant_id, :matrix_type]
      index [:tenant_id, :is_default]
      index [:tenant_id, :is_active]
      index [:tenant_id, :category_id]
      index [:tenant_id, :created_by_id]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: OK - General system coordination and management with cybernetic feedback
# Domain: Risk management
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
