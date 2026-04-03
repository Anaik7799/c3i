defmodule Indrajaal.Shared.BillingCalculations do
  @moduledoc """
  Shared billing calculation utilities to eliminate duplication across billing domain.

  This module extracts common billing calculation patterns used by:
  - Billing.Plan
  - Billing.Payment
  - Billing.Subscription
  - Other billing resources with similar calculations

  Following Toyota TPS principles to eliminate duplicate code waste.
  """

  @doc """
  Calculates monthly price from various billing f_requencies.

  ## Parameters
    - base_price - The base price (Decimal)
    - billing_f_requency - The billing f_requency atom

  ## Returns
  Monthly equivalent price as Decimal.

  ## Example
      monthly_price = calculate_monthly_price(plan.base_price, plan.billing_f_requency)
  """
  @spec calculate_monthly_price(Decimal.t(), atom()) :: Decimal.t()
  def calculate_monthly_price(base_price, billing_f_requency) do
    case billing_f_requency do
      :monthly -> base_price
      :quarterly -> Decimal.div(base_price, 3)
      :semi_annual -> Decimal.div(base_price, 6)
      :annual -> Decimal.div(base_price, 12)
      :biennial -> Decimal.div(base_price, 24)
      _ -> base_price
    end
  end

  @doc """
  Calculates annual price from various billing f_requencies.

  ## Parameters
    - base_price - The base price (Decimal)
    - billing_f_requency - The billing f_requency atom

  ## Returns
  Annual equivalent price as Decimal.
  """
  @spec calculate_annual_price(Decimal.t(), atom()) :: Decimal.t()
  def calculate_annual_price(base_price, billing_f_requency) do
    case billing_f_requency do
      :monthly -> Decimal.mult(base_price, 12)
      :quarterly -> Decimal.mult(base_price, 4)
      :semi_annual -> Decimal.mult(base_price, 2)
      :annual -> base_price
      :biennial -> Decimal.div(base_price, 2)
      _ -> Decimal.mult(base_price, 12)
    end
  end

  @doc """
  Creates a billing f_requency calculation for Ash resources.

  ## Parameters
    - calculation_name - Name of the calculation (e.g., :monthly_price)
    - target_f_requency - Target f_requency to convert to (:monthly, :annual, etc.)
    - base_price_field - Field containing the base price (default: :base_price)
    - f_requency_field - Field containing billing f_requency (default: :billing_f_requency)

  ## Returns
  Ash calculation configuration.

  ## Example
      calculations do
        calculate Indrajaal.Shared.BillingCalculations.f_requency_calculation(:monthly_price, :monthly)
        calculate Indrajaal.Shared.BillingCalculations.f_requency_calculation(:annual_price, :annual)    end
  """
  def f_requencycalculation(
        calculation_name,
        target_f_requency,
        base_price_field \\ :base_price,
        f_requency_field \\ :billing_f_requency
      ) do
    %{
      name: calculation_name,
      type: :decimal,
      calculation: fn records, __context ->
        Enum.map(records, fn record ->
          base_price = Map.get(record, base_price_field)
          billing_f_requency = Map.get(record, f_requency_field)

          case target_f_requency do
            :monthly -> calculate_monthly_price(base_price, billing_f_requency)
            :annual -> calculate_annual_price(base_price, billing_f_requency)
            :quarterly -> calculate_quarterly_price(base_price, billing_f_requency)
            :weekly -> calculate_weekly_price(base_price, billing_f_requency)
            _ -> base_price
          end
        end)
      end
    }
  end

  @doc """
  Calculates quarterly price from various billing f_requencies.

  ## Parameters
    - base_price - The base price (Decimal)
    - billing_f_requency - The billing f_requency atom

  ## Returns
  Quarterly equivalent price as Decimal.
  """
  @spec calculate_quarterly_price(Decimal.t(), atom()) :: Decimal.t()
  def calculate_quarterly_price(base_price, billing_f_requency) do
    case billing_f_requency do
      :monthly -> Decimal.mult(base_price, 3)
      :quarterly -> base_price
      :semi_annual -> Decimal.div(base_price, 2)
      :annual -> Decimal.div(base_price, 4)
      :biennial -> Decimal.div(base_price, 8)
      _ -> Decimal.mult(base_price, 3)
    end
  end

  @doc """
  Calculates weekly price from various billing f_requencies.

  ## Parameters
    - base_price - The base price (Decimal)
    - billing_f_requency - The billing f_requency atom

  ## Returns
  Weekly equivalent price as Decimal.
  """
  @spec calculate_weekly_price(Decimal.t(), atom()) :: Decimal.t()
  def calculate_weekly_price(base_price, billing_f_requency) do
    case billing_f_requency do
      # Average weeks per month
      :monthly -> Decimal.div(base_price, Decimal.new("4.33"))
      # 13 weeks per quarter
      :quarterly -> Decimal.div(base_price, 13)
      # 26 weeks per half year
      :semi_annual -> Decimal.div(base_price, 26)
      # 52 weeks per year
      :annual -> Decimal.div(base_price, 52)
      # 104 weeks per 2 years
      :biennial -> Decimal.div(base_price, 104)
      _ -> Decimal.div(base_price, Decimal.new("4.33"))
    end
  end

  @doc """
  Calculates prorated amount for partial billing periods.

  ## Parameters
    - base_price - The base price for full period
    - billing_f_requency - The billing f_requency
    - days_used - Number of days used in the period

  ## Returns
  Prorated amount as Decimal.
  """
  @spec calculate_prorated_amount(Decimal.t(), atom(), integer()) :: Decimal.t()
  def calculate_prorated_amount(base_price, billing_f_requency, days_used) do
    total_days = get_period_days(billing_f_requency)
    daily_rate = Decimal.div(base_price, total_days)
    Decimal.mult(daily_rate, days_used)
  end

  @doc """
  Calculates tax amount based on rate and base amount.

  ## Parameters
    - base_amount - The base amount to calculate tax on
    - tax_rate - Tax rate as decimal (e.g., 0.0875 for 8.75%)

  ## Returns
  Tax amount as Decimal.
  """
  @spec calculate_tax(Decimal.t(), Decimal.t()) :: Decimal.t()
  def calculate_tax(base_amount, tax_rate) do
    Decimal.mult(base_amount, tax_rate)
  end

  @doc """
  Calculates discount amount based on discount type and rate.

  ## Parameters
    - base_amount - The base amount to discount
    - discount_type - Type of discount (:percentage, :fixed)
    - discount_value - Discount value (percentage or fixed amount)

  ## Returns
  Discount amount as Decimal.
  """
  @spec calculate_discount(Decimal.t(), atom(), Decimal.t()) :: Decimal.t()
  def calculate_discount(base_amount, discount_type, discount_value) do
    case discount_type do
      :percentage ->
        discount_rate = Decimal.div(discount_value, 100)
        Decimal.mult(base_amount, discount_rate)

      :fixed ->
        discount_value

      _ ->
        Decimal.new(0)
    end
  end

  @doc """
  Calculates total amount including tax and discounts.

  ## Parameters
    - base_amount - The base amount
    - tax_rate - Tax rate (optional)
    - discount_type - Discount type (optional)
    - discount_value - Discount value (optional)

  ## Returns
  Total amount as Decimal.
  """
  @spec calculate_total_amount(Decimal.t(), Decimal.t() | nil, atom() | nil, Decimal.t() | nil) ::
          Decimal.t()
  def calculate_total_amount(
        base_amount,
        tax_rate \\ nil,
        discount_type \\ nil,
        discount_value \\ nil
      ) do
    # Apply discount first
    amount_after_discount =
      case {discount_type, discount_value} do
        {nil, _} ->
          base_amount

        {_, nil} ->
          base_amount

        {type, value} ->
          discount = calculate_discount(base_amount, type, value)
          Decimal.sub(base_amount, discount)
      end

    # Apply tax to discounted amount
    case tax_rate do
      nil ->
        amount_after_discount

      rate ->
        tax = calculate_tax(amount_after_discount, rate)
        Decimal.add(amount_after_discount, tax)
    end
  end

  @doc """
  Generates a payment schedule for a subscription.

  ## Parameters
    - start_date - Start date of subscription
    - end_date - End date of subscription
    - billing_f_requency - How often to bill
    - amount - Amount to bill each period

  ## Returns
  List of payment due dates and amounts.
  """
  @spec generate_payment_schedule(Date.t(), Date.t(), atom(), Decimal.t()) :: list(map())
  def generate_payment_schedule(start_date, end_date, billing_f_requency, amount) do
    period_days = get_period_days(billing_f_requency)

    start_date
    |> Stream.iterate(&Date.add(&1, period_days))
    |> Stream.take_while(&(Date.compare(&1, end_date) != :gt))
    |> Enum.map(fn due_date ->
      %{
        due_date: due_date,
        amount: amount,
        billing_period_start: due_date,
        billing_period_end: Date.add(due_date, period_days - 1)
      }
    end)
  end

  @doc """
  Validates billing f_requency values.

  ## Parameters
    - f_requency - The billing f_requency to validate

  ## Returns
    - {:ok, f_requency} if valid
    - {:error, reason} if invalid
  """
  @spec validate_billing_f_requency(atom()) :: {:ok, atom()} | {:error, String.t()}
  def validate_billing_f_requency(f_requency) do
    valid_f_requencies = [:monthly, :quarterly, :semi_annual, :annual, :biennial, :weekly, :daily]

    if f_requency in valid_f_requencies do
      {:ok, f_requency}
    else
      {:error, "Invalid billing f_requency. Must be one of: #{inspect(valid_f_requencies)}"}
    end
  end

  @doc """
  Gets the number of days in a billing period.

  ## Parameters
    - billing_f_requency - The billing f_requency

  ## Returns
  Number of days in the period.
  """
  @spec get_period_days(atom()) :: integer()
  def get_period_days(billing_f_requency) do
    case billing_f_requency do
      :daily -> 1
      :weekly -> 7
      :monthly -> 30
      :quarterly -> 90
      :semi_annual -> 183
      :annual -> 365
      :biennial -> 730
      _ -> 30
    end
  end

  @doc """
  Calculates usage - based pricing.

  ## Parameters
    - base_price - Base subscription price
    - usage_units - Number of usage units consumed
    - price_per_unit - Price per usage unit
    - included_units - Number of units included in base price

  ## Returns
  Total amount including base price and usage overages.
  """
  @spec calculate_usage_pricing(Decimal.t(), integer(), Decimal.t(), integer()) :: Decimal.t()
  def calculate_usage_pricing(base_price, usage_units, price_per_unit, included_units \\ 0) do
    overage_units = max(0, usage_units - included_units)
    overage_cost = Decimal.mult(price_per_unit, overage_units)
    Decimal.add(base_price, overage_cost)
  end

  @doc """
  Calculates tiered pricing based on usage levels.

  ## Parameters
    - usage_units - Number of usage units consumed
    - pricing_tiers - List of pricing tiers with {limit, price_per_unit} tuples

  ## Returns
  Total cost based on tiered pricing structure.
  """
  def calculate_tiered_pricing(usage_units, pricing_tiers) do
    pricing_tiers
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reduce({0, usage_units, Decimal.new(0)}, fn {tier_limit, price_per_unit},
                                                        {prev_limit, remaining_units, total_cost} ->
      units_in_tier = min(remaining_units, tier_limit - prev_limit)
      tier_cost = Decimal.mult(price_per_unit, units_in_tier)
      new_total = Decimal.add(total_cost, tier_cost)
      {tier_limit, remaining_units - units_in_tier, new_total}
    end)
    |> elem(2)
  end
end

# Agent: Helper - 3 (Infrastructure Agent)
# SOPv5.1 Compliance: ✅ Billing calculation utilities with systematic TPS methodology
# Domain: Shared
# Responsibilities: Billing calculation patterns, price computation, payment scheduling
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for billing accuracy and optimization
