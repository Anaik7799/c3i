defmodule Indrajaal.RiskManagement.RiskControl do
  @moduledoc """
  Risk controls and control effectiveness testing.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.RiskManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :control_id, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :control_name, :string do
      allow_nil? false
      constraints max_length: 200
    end

    attribute :control_description, :string do
      allow_nil? false
      constraints max_length: 1000
    end

    attribute :control_type, :atom do
      constraints one_of: [:pr_eventive, :detective, :corrective, :compensating]
      allow_nil? false
    end

    attribute :control_nature, :atom do
      constraints one_of: [:manual, :automated, :hybrid]
      allow_nil? false
    end

    attribute :control_f_requency, :atom do
      constraints one_of: [
                    :continuous,
                    :daily,
                    :weekly,
                    :monthly,
                    :quarterly,
                    :annually,
                    :__event_driven
                  ]

      allow_nil? false
    end

    attribute :control_status, :atom do
      constraints one_of: [:planned, :implemented, :operating, :deficient, :disabled]
      default :planned
    end

    attribute :implementation_date, :date
    attribute :last_test_date, :date
    attribute :next_test_date, :date

    attribute :test_f_requency, :atom do
      constraints one_of: [:monthly, :quarterly, :semi_annually, :annually, :bi_annually]
      default :quarterly
    end

    attribute :effectiveness_rating, :atom do
      constraints one_of: [
                    :ineffective,
                    :partially_effective,
                    :largely_effective,
                    :fully_effective
                  ]
    end

    attribute :control_objective, :string do
      constraints max_length: 500
    end

    attribute :control_procedures, :string do
      constraints max_length: 2000
    end

    attribute :responsible_party, :string do
      constraints max_length: 200
    end

    attribute :evidence_requirements, {:array, :string} do
      default []
    end

    attribute :test_results, :string do
      constraints max_length: 2000
    end

    attribute :deficiencies_identified, {:array, :string} do
      default []
    end

    attribute :remediation_plan, :string do
      constraints max_length: 1000
    end

    timestamps()
  end

  relationships do
    belongs_to :risk, Indrajaal.RiskManagement.Risk do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :mitigation, Indrajaal.RiskManagement.RiskMitigation do
      attribute_writable? true
    end

    belongs_to :control_owner, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :tested_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end
  end

  calculations do
    calculate :days_since_last_test, :integer do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          case record.last_test_date do
            nil -> nil
            last_test -> Date.diff(today, last_test)
          end
        end)
      end
    end

    calculate :is_test_overdue, :boolean do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          case record.next_test_date do
            nil -> false
            next_test -> Date.compare(today, next_test) == :gt
          end
        end)
      end
    end

    calculate :control_maturity_score, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          base_score =
            case record.control_status do
              :planned -> 1
              :implemented -> 2
              :operating -> 3
              :deficient -> 2
              :disabled -> 0
            end

          effectiveness_bonus =
            case record.effectiveness_rating do
              :fully_effective -> 2
              :largely_effective -> 1
              :partially_effective -> 0
              :ineffective -> -1
              nil -> 0
            end

          automation_bonus =
            case record.control_nature do
              :automated -> 1
              :hybrid -> 0
              :manual -> 0
            end

          base_score + effectiveness_bonus + automation_bonus
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :implement_control do
      argument :control_id, :string do
        allow_nil? false
      end

      argument :control_name, :string do
        allow_nil? false
      end

      argument :control_type, :atom do
        allow_nil? false
      end

      argument :control_nature, :atom do
        allow_nil? false
      end

      argument :control_f_requency, :atom do
        allow_nil? false
      end

      argument :risk_id, :uuid do
        allow_nil? false
      end

      argument :control_owner_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:control_id, arg(:control_id))
      change set_attribute(:control_name, arg(:control_name))
      change set_attribute(:control_type, arg(:control_type))
      change set_attribute(:control_nature, arg(:control_nature))
      change set_attribute(:control_f_requency, arg(:control_f_requency))
      change set_attribute(:risk_id, arg(:risk_id))
      change set_attribute(:control_owner_id, arg(:control_owner_id))
    end

    update :activate_control do
      require_atomic? false
      change set_attribute(:control_status, :operating)
      change set_attribute(:implementation_date, Date.utc_today())
    end

    update :test_control do
      require_atomic? false

      argument :tested_by_id, :uuid do
        allow_nil? false
      end

      argument :test_results, :string do
        allow_nil? false
      end

      argument :effectiveness_rating, :atom do
        allow_nil? false
      end

      argument :deficiencies, {:array, :string}

      change set_attribute(:tested_by_id, arg(:tested_by_id))
      change set_attribute(:test_results, arg(:test_results))
      change set_attribute(:effectiveness_rating, arg(:effectiveness_rating))
      change set_attribute(:deficiencies_identified, arg(:deficiencies))
      change set_attribute(:last_test_date, Date.utc_today())

      # Calculate next test date based on f_requency
      change fn changeset, _ ->
        f_requency = changeset.data.test_f_requency
        today = Date.utc_today()

        next_date =
          case f_requency do
            :monthly -> Date.add(today, 30)
            :quarterly -> Date.add(today, 90)
            :semi_annually -> Date.add(today, 180)
            :annually -> Date.add(today, 365)
            :bi_annually -> Date.add(today, 730)
            _ -> Date.add(today, 90)
          end

        Ash.Changeset.change_attribute(changeset, :next_test_date, next_date)
      end
    end

    update :identify_deficiency do
      require_atomic? false

      argument :deficiencies, {:array, :string} do
        allow_nil? false
      end

      argument :remediation_plan, :string do
        allow_nil? false
      end

      change set_attribute(:control_status, :deficient)
      change set_attribute(:deficiencies_identified, arg(:deficiencies))
      change set_attribute(:remediation_plan, arg(:remediation_plan))
    end

    update :remediate_control do
      require_atomic? false

      argument :remediation_notes, :string do
        allow_nil? false
      end

      change set_attribute(:control_status, :operating)
      change set_attribute(:remediation_plan, arg(:remediation_notes))

      change fn changeset, _ ->
        # Clear deficiencies
        Ash.Changeset.change_attribute(changeset, :deficiencies_identified, [])
      end
    end

    update :disable_control do
      require_atomic? false

      argument :reason, :string do
        allow_nil? false
      end

      change set_attribute(:control_status, :disabled)

      change fn changeset, _ ->
        current_desc = changeset.data.control_description
        reason = Ash.Changeset.get_argument(changeset, :reason)
        updated_desc = "#{current_desc}

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Risk management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
\n\nDISABLED: #{reason}"
        Ash.Changeset.change_attribute(changeset, :control_description, updated_desc)
      end
    end

    update :schedule_test do
      require_atomic? false

      argument :next_test_date, :date do
        allow_nil? false
      end

      change set_attribute(:next_test_date, arg(:next_test_date))
    end
  end

  code_interface do
    define :create
    define :implement_control
    define :activate_control
    define :test_control
    define :identify_deficiency
    define :remediate_control
    define :disable_control
    define :schedule_test
  end

  postgres do
    table "risk_controls"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :control_id], unique: true
      index [:tenant_id, :risk_id]
      index [:tenant_id, :control_type]
      index [:tenant_id, :control_status]
      index [:tenant_id, :control_owner_id]
      index [:tenant_id, :effectiveness_rating]
      index [:tenant_id, :next_test_date], where: "next_test_date IS NOT NULL"
      index [:tenant_id, :last_test_date], where: "last_test_date IS NOT NULL"
    end
  end
end
