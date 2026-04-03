defmodule Intelitor.AssetManagement.AssetDepreciation do
  @moduledoc """
  Depreciation calculations and tracking for asset valuation.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.AssetManagement,
    table: "asset_depreciation"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :depreciation_method, :atom do
      constraints one_of: [
                    :straight_line,
                    :declining_balance,
                    :sum_of_years,
                    :units_of_production
                  ]

      allow_nil? false
    end

    attribute :calculation_date, :date do
      allow_nil? false
      default &Date.utc_today/0
    end

    attribute :original_cost, :decimal do
      allow_nil? false
      constraints precision: 15, scale: 2
    end

    attribute :salvage_value, :decimal do
      default 0
      constraints precision: 15, scale: 2
    end

    attribute :useful_life_years, :integer do
      allow_nil? false
      constraints min: 1, max: 50
    end

    attribute :current_book_value, :decimal do
      allow_nil? false
      constraints precision: 15, scale: 2
    end

    attribute :accumulated_depreciation, :decimal do
      default 0
      constraints precision: 15, scale: 2
    end

    attribute :annual_depreciation, :decimal do
      constraints precision: 15, scale: 2
    end

    attribute :monthly_depreciation, :decimal do
      constraints precision: 15, scale: 2
    end

    attribute :depreciation_percentage, :decimal do
      constraints precision: 5, scale: 2
    end

    attribute :calculation_notes, :string do
      constraints max_length: 1000
    end

    attribute :is_fully_depreciated, :boolean do
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :asset, Intelitor.AssetManagement.Asset do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :calculated_by, Intelitor.Accounts.User do
      attribute_writable? true
    end
  end

  calculations do
    calculate :remaining_useful_life, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          if record.asset && record.asset.acquisition_date do
            years_elapsed = Date.diff(Date.utc_today(), record.asset.acquisition_date) / 365.25
            remaining = Decimal.sub(record.useful_life_years, years_elapsed)
            Decimal.max(remaining, 0)
          else
            nil
          end
        end)
      end
    end

    calculate :depreciation_rate_percentage, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          if record.useful_life_years > 0 do
            Decimal.div(100, record.useful_life_years)
          else
            nil
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    create :calculate_depreciation do
      argument :asset_id, :uuid do
        allow_nil? false
      end

      argument :depreciation_method, :atom do
        allow_nil? false
      end

      argument :original_cost, :decimal do
        allow_nil? false
      end

      argument :useful_life_years, :integer do
        allow_nil? false
      end

      argument :salvage_value, :decimal, default: 0

      change set_attribute(:asset_id, arg(:asset_id))
      change set_attribute(:depreciation_method, arg(:depreciation_method))
      change set_attribute(:original_cost, arg(:original_cost))
      change set_attribute(:useful_life_years, arg(:useful_life_years))
      change set_attribute(:salvage_value, arg(:salvage_value))

      change fn changeset, _ ->
        method = Ash.Changeset.get_argument(changeset, :depreciation_method)
        cost = Ash.Changeset.get_argument(changeset, :original_cost)
        salvage = Ash.Changeset.get_argument(changeset, :salvage_value) || Decimal.new(0)
        life = Ash.Changeset.get_argument(changeset, :useful_life_years)

        depreciable_amount = Decimal.sub(cost, salvage)

        {annual_depreciation, monthly_depreciation} =
          case method do
            :straight_line ->
              annual = Decimal.div(depreciable_amount, life)
              monthly = Decimal.div(annual, 12)
              {annual, monthly}

            :declining_balance ->
              rate = Decimal.div(2, life)
              annual = Decimal.mult(cost, rate)
              monthly = Decimal.div(annual, 12)
              {annual, monthly}

            _ ->
              annual = Decimal.div(depreciable_amount, life)
              monthly = Decimal.div(annual, 12)
              {annual, monthly}
          end

        changeset
        |> Ash.Changeset.change_attribute(:current_book_value, cost)
        |> Ash.Changeset.change_attribute(:annual_depreciation, annual_depreciation)
        |> Ash.Changeset.change_attribute(:monthly_depreciation, monthly_depreciation)
      end
    end

    update :recalculate do
      require_atomic? false
      change fn changeset, _ ->
        # Recalculate depreciation based on current date and method
        asset = changeset.data.asset

        if asset && asset.acquisition_date do
          months_elapsed = Date.diff(Date.utc_today(), asset.acquisition_date) / 30.44
          monthly_dep = changeset.data.monthly_depreciation || Decimal.new(0)

          accumulated = Decimal.mult(monthly_dep, Decimal.from_float(months_elapsed))
          current_value = Decimal.sub(changeset.data.original_cost, accumulated)

          # Ensure book value doesn't go below salvage value
          salvage = changeset.data.salvage_value || Decimal.new(0)
          final_value = Decimal.max(current_value, salvage)

          fully_depreciated = Decimal.equal?(final_value, salvage)

          changeset
          |> Ash.Changeset.change_attribute(:accumulated_depreciation, accumulated)
          |> Ash.Changeset.change_attribute(:current_book_value, final_value)
          |> Ash.Changeset.change_attribute(:is_fully_depreciated, fully_depreciated)
          |> Ash.Changeset.change_attribute(:calculation_date, Date.utc_today())
        else
          changeset
        end
      end
    end
  end

  validations do
    validate compare(:current_book_value, greater_than_or_equal_to: :salvage_value),
      message: "Book value cannot be less than salvage value"

    validate compare(:original_cost, greater_than: :salvage_value),
      message: "Original cost must be greater than salvage value"
  end

  code_interface do
    define :create
    define :calculate_depreciation
    define :recalculate
  end

  postgres do
    table "asset_depreciation"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :asset_id]
      index [:tenant_id, :depreciation_method]
      index [:tenant_id, :calculation_date]
      index [:tenant_id, :is_fully_depreciated]
    end
  end
end
