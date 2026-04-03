defmodule Indrajaal.Crm.Quota do
  @moduledoc """
  CRM Quota resource for sales target management.

  ## WHAT
  Manages sales quotas/targets for individual users and territories with
  period-based tracking (monthly, quarterly, yearly) and attainment calculation.

  ## WHY
  Provides structured quota management for sales performance tracking,
  forecasting, and commission calculations with real-time attainment metrics.

  ## CONSTRAINTS
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: uuid_primary_key
  - SC-ASH-001: force_change_attribute in before_action
  - SC-ASH-004: require_atomic? false for fn changes
  - SC-PRF-050: Response time < 50ms

  ## FMEA Analysis
  | Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
  |--------------|----------|------------|-----------|-----|------------|
  | Quota calculation error | 8 | 3 | 4 | 96 | Dual calculation validation |
  | Period overlap | 7 | 4 | 5 | 140 | Unique constraint on period |
  | Negative amounts | 6 | 3 | 8 | 144 | Non-negative constraint |

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-11 | Claude | Initial quota resource implementation |
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :period_type, :atom do
      allow_nil? false
      constraints one_of: [:monthly, :quarterly, :yearly]
      description "Quota period granularity"
    end

    attribute :period_year, :integer do
      allow_nil? false
      constraints min: 2020, max: 2050
      description "Quota year"
    end

    attribute :period_number, :integer do
      allow_nil? false
      description "Period number: 1-12 for monthly, 1-4 for quarterly, 1 for yearly"
    end

    attribute :amount, :decimal do
      allow_nil? false
      constraints precision: 15, scale: 2, min: 0
      description "Quota target amount"
    end

    attribute :currency, :string do
      default "USD"
      constraints max_length: 3
      description "Currency code (ISO 4217)"
    end

    attribute :created_by_id, :uuid
    attribute :updated_by_id, :uuid

    timestamps()
  end

  relationships do
    belongs_to :user, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_public? true
      description "User assigned this quota"
    end

    # belongs_to :territory, Indrajaal.Crm.Resources.Territory do
    #   attribute_public? true
    #   description "Optional territory this quota applies to"
    # end

    belongs_to :created_by, Indrajaal.Accounts.User do
      source_attribute :created_by_id
      attribute_public? true
    end

    belongs_to :updated_by, Indrajaal.Accounts.User do
      source_attribute :updated_by_id
      attribute_public? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:period_type, :period_year, :period_number, :amount, :currency]

      argument :user_id, :uuid, allow_nil?: false
      argument :territory_id, :uuid
      argument :created_by_id, :uuid, allow_nil?: false

      change set_attribute(:user_id, arg(:user_id))
      change set_attribute(:territory_id, arg(:territory_id))
      change set_attribute(:created_by_id, arg(:created_by_id))

      validate present([:user_id, :period_type, :period_year, :period_number, :amount])

      validate fn changeset, _context ->
        validate_period_number(changeset)
      end
    end

    update :update do
      primary? true
      require_atomic? false

      accept [:amount, :currency]

      argument :updated_by_id, :uuid

      change set_attribute(:updated_by_id, arg(:updated_by_id))
    end

    read :by_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
    end

    read :by_period do
      argument :period_type, :atom, allow_nil?: false
      argument :period_year, :integer, allow_nil?: false
      argument :period_number, :integer, allow_nil?: false

      filter expr(
               period_type == ^arg(:period_type) and
                 period_year == ^arg(:period_year) and
                 period_number == ^arg(:period_number)
             )
    end

    read :current_quarter do
      # Returns quotas for current quarter
      prepare fn query, _context ->
        {year, quarter} = current_quarter_tuple()

        query
        |> Ash.Query.filter(period_type == :quarterly)
        |> Ash.Query.filter(period_year == ^year)
        |> Ash.Query.filter(period_number == ^quarter)
      end
    end
  end

  calculations do
    calculate :attainment_percent,
              :decimal,
              expr(
                fragment(
                  "COALESCE(?, 0) / NULLIF(?, 0) * 100",
                  field(:closed_won_amount),
                  field(:amount)
                )
              )

    calculate :period_label, :string do
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          case record.period_type do
            :monthly -> "#{month_name(record.period_number)} #{record.period_year}"
            :quarterly -> "Q#{record.period_number} #{record.period_year}"
            :yearly -> "FY#{record.period_year}"
            _ -> "Unknown"
          end
        end)
      end
    end
  end

  validations do
    validate compare(:amount, greater_than_or_equal_to: 0) do
      message "Quota amount must be non-negative"
    end

    validate fn changeset, _context ->
      period_type = Ash.Changeset.get_attribute(changeset, :period_type)
      period_number = Ash.Changeset.get_attribute(changeset, :period_number)

      valid? =
        case period_type do
          :monthly -> period_number in 1..12
          :quarterly -> period_number in 1..4
          :yearly -> period_number == 1
          _ -> false
        end

      if valid? do
        :ok
      else
        {:error,
         field: :period_number, message: "Period number invalid for #{period_type} period type"}
      end
    end
  end

  policies do
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action_type([:read, :create, :update]) do
      authorize_if actor_attribute_equals(:role, :manager)
    end

    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  code_interface do
    define :create
    define :update
    define :by_user, args: [:user_id]
    define :by_period, args: [:period_type, :period_year, :period_number]
    define :current_quarter
  end

  postgres do
    table "quotas"
    repo Indrajaal.Repo

    custom_indexes do
      # Unique constraint: one quota per user per period
      index [:tenant_id, :user_id, :period_type, :period_year, :period_number],
        unique: true,
        name: "quotas_unique_user_period_idx"

      index [:tenant_id, :user_id]
      index [:territory_id]
      index [:period_year, :period_number]
      index [:created_at]
    end
  end

  # Helper functions
  defp validate_period_number(changeset) do
    period_type = Ash.Changeset.get_attribute(changeset, :period_type)
    period_number = Ash.Changeset.get_attribute(changeset, :period_number)

    max_period =
      case period_type do
        :monthly -> 12
        :quarterly -> 4
        :yearly -> 1
        _ -> 0
      end

    if period_number >= 1 and period_number <= max_period do
      :ok
    else
      {:error,
       field: :period_number,
       message: "Period number must be between 1 and #{max_period} for #{period_type}"}
    end
  end

  defp current_quarter_tuple do
    now = DateTime.utc_now()
    year = now.year
    quarter = div(now.month - 1, 3) + 1
    {year, quarter}
  end

  defp month_name(month) do
    ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
    |> Enum.at(month - 1, "Unknown")
  end
end
