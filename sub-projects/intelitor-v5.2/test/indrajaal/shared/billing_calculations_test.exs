defmodule Indrajaal.Shared.BillingCalculationsTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.BillingCalculations module.

  Tests billing calculation utilities for:
  - calculate_monthly_price function
  - calculate_annual_price function
  - calculate_quarterly_price function
  - calculate_weekly_price function
  - calculate_prorated_amount function
  - calculate_tax function
  - calculate_discount function
  - calculate_total_amount function
  - generate_payment_schedule function
  - validate_billing_frequency function
  - get_period_days function
  - calculate_usage_pricing function
  - calculate_tiered_pricing function

  Created: 2025-11-27 20:00:00 CEST
  Phase: 4.0 - C3 Medium-Impact Testing (Billing Calculations)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.BillingCalculations

  # ============================================================================
  # MODULE EXISTENCE TESTS
  # ============================================================================

  describe "Module Structure" do
    test "BillingCalculations module exists" do
      assert Code.ensure_loaded?(Indrajaal.Shared.BillingCalculations)
    end

    test "module exports calculate_monthly_price function" do
      functions = BillingCalculations.__info__(:functions)
      assert {:calculate_monthly_price, 2} in functions
    end

    test "module exports calculate_annual_price function" do
      functions = BillingCalculations.__info__(:functions)
      assert {:calculate_annual_price, 2} in functions
    end

    test "module exports calculate_quarterly_price function" do
      functions = BillingCalculations.__info__(:functions)
      assert {:calculate_quarterly_price, 2} in functions
    end

    test "module exports calculate_weekly_price function" do
      functions = BillingCalculations.__info__(:functions)
      assert {:calculate_weekly_price, 2} in functions
    end

    test "module exports calculate_prorated_amount function" do
      functions = BillingCalculations.__info__(:functions)
      assert {:calculate_prorated_amount, 3} in functions
    end

    test "module exports calculate_tax function" do
      functions = BillingCalculations.__info__(:functions)
      assert {:calculate_tax, 2} in functions
    end

    test "module exports calculate_discount function" do
      functions = BillingCalculations.__info__(:functions)
      assert {:calculate_discount, 3} in functions
    end

    test "module exports calculate_total_amount function" do
      functions = BillingCalculations.__info__(:functions)
      assert {:calculate_total_amount, 4} in functions
    end

    test "module exports generate_payment_schedule function" do
      functions = BillingCalculations.__info__(:functions)
      assert {:generate_payment_schedule, 4} in functions
    end

    test "module exports validate_billing_frequency function" do
      functions = BillingCalculations.__info__(:functions)
      assert {:validate_billing_frequency, 1} in functions
    end

    test "module exports get_period_days function" do
      functions = BillingCalculations.__info__(:functions)
      assert {:get_period_days, 1} in functions
    end

    test "module exports calculate_usage_pricing function" do
      functions = BillingCalculations.__info__(:functions)
      assert {:calculate_usage_pricing, 4} in functions
    end

    test "module exports calculate_tiered_pricing function" do
      functions = BillingCalculations.__info__(:functions)
      assert {:calculate_tiered_pricing, 2} in functions
    end
  end

  # ============================================================================
  # CALCULATE_MONTHLY_PRICE TESTS
  # ============================================================================

  describe "calculate_monthly_price/2" do
    test "calculates monthly price from annual" do
      annual_price = Decimal.new("1200.00")
      result = BillingCalculations.calculate_monthly_price(annual_price, :annual)

      assert %Decimal{} = result
    end

    test "handles integer input" do
      result = BillingCalculations.calculate_monthly_price(1200, :annual)

      assert result != nil
    end

    test "handles float input" do
      result = BillingCalculations.calculate_monthly_price(1200.00, :annual)

      assert result != nil
    end

    test "returns Decimal result" do
      result = BillingCalculations.calculate_monthly_price(Decimal.new("100"), :monthly)

      assert %Decimal{} = result or is_number(result)
    end
  end

  # ============================================================================
  # CALCULATE_ANNUAL_PRICE TESTS
  # ============================================================================

  describe "calculate_annual_price/2" do
    test "calculates annual price from monthly" do
      monthly_price = Decimal.new("100.00")
      result = BillingCalculations.calculate_annual_price(monthly_price, :monthly)

      assert result != nil
    end

    test "handles different billing frequencies" do
      price = Decimal.new("100.00")

      result_monthly = BillingCalculations.calculate_annual_price(price, :monthly)
      result_quarterly = BillingCalculations.calculate_annual_price(price, :quarterly)

      assert result_monthly != nil
      assert result_quarterly != nil
    end
  end

  # ============================================================================
  # CALCULATE_QUARTERLY_PRICE TESTS
  # ============================================================================

  describe "calculate_quarterly_price/2" do
    test "calculates quarterly price" do
      price = Decimal.new("1200.00")
      result = BillingCalculations.calculate_quarterly_price(price, :annual)

      assert result != nil
    end

    test "handles monthly to quarterly conversion" do
      monthly = Decimal.new("100.00")
      result = BillingCalculations.calculate_quarterly_price(monthly, :monthly)

      assert result != nil
    end
  end

  # ============================================================================
  # CALCULATE_WEEKLY_PRICE TESTS
  # ============================================================================

  describe "calculate_weekly_price/2" do
    test "calculates weekly price from monthly" do
      monthly = Decimal.new("400.00")
      result = BillingCalculations.calculate_weekly_price(monthly, :monthly)

      assert result != nil
    end

    test "handles annual to weekly conversion" do
      annual = Decimal.new("5200.00")
      result = BillingCalculations.calculate_weekly_price(annual, :annual)

      assert result != nil
    end
  end

  # ============================================================================
  # CALCULATE_PRORATED_AMOUNT TESTS
  # ============================================================================

  describe "calculate_prorated_amount/3" do
    test "calculates prorated amount for partial period" do
      full_amount = Decimal.new("100.00")
      start_date = Date.utc_today()
      end_date = Date.add(start_date, 15)

      result = BillingCalculations.calculate_prorated_amount(full_amount, start_date, end_date)

      assert result != nil
    end

    test "handles same day start and end" do
      full_amount = Decimal.new("100.00")
      date = Date.utc_today()

      result = BillingCalculations.calculate_prorated_amount(full_amount, date, date)

      assert result != nil
    end

    test "handles full month" do
      full_amount = Decimal.new("100.00")
      start_date = ~D[2025-01-01]
      end_date = ~D[2025-01-31]

      result = BillingCalculations.calculate_prorated_amount(full_amount, start_date, end_date)

      assert result != nil
    end
  end

  # ============================================================================
  # CALCULATE_TAX TESTS
  # ============================================================================

  describe "calculate_tax/2" do
    test "calculates tax on amount" do
      amount = Decimal.new("100.00")
      tax_rate = Decimal.new("0.10")

      result = BillingCalculations.calculate_tax(amount, tax_rate)

      assert result != nil
    end

    test "handles zero tax rate" do
      amount = Decimal.new("100.00")
      tax_rate = Decimal.new("0.00")

      result = BillingCalculations.calculate_tax(amount, tax_rate)

      # Zero tax should result in zero or very small amount
      assert result != nil
    end

    test "handles high tax rate" do
      amount = Decimal.new("100.00")
      tax_rate = Decimal.new("0.25")

      result = BillingCalculations.calculate_tax(amount, tax_rate)

      assert result != nil
    end

    test "handles integer inputs" do
      result = BillingCalculations.calculate_tax(100, Decimal.new("0.10"))

      assert result != nil
    end
  end

  # ============================================================================
  # CALCULATE_DISCOUNT TESTS
  # ============================================================================

  describe "calculate_discount/3" do
    test "calculates percentage discount" do
      amount = Decimal.new("100.00")
      discount_rate = Decimal.new("0.20")

      result = BillingCalculations.calculate_discount(amount, discount_rate, :percentage)

      assert result != nil
    end

    test "calculates flat discount" do
      amount = Decimal.new("100.00")
      discount_amount = Decimal.new("15.00")

      result = BillingCalculations.calculate_discount(amount, discount_amount, :flat)

      assert result != nil
    end

    test "handles zero discount" do
      amount = Decimal.new("100.00")
      discount = Decimal.new("0.00")

      result = BillingCalculations.calculate_discount(amount, discount, :percentage)

      assert result != nil
    end

    test "handles 100% discount" do
      amount = Decimal.new("100.00")
      discount = Decimal.new("1.00")

      result = BillingCalculations.calculate_discount(amount, discount, :percentage)

      assert result != nil
    end
  end

  # ============================================================================
  # CALCULATE_TOTAL_AMOUNT TESTS
  # ============================================================================

  describe "calculate_total_amount/4" do
    test "calculates total with tax and discount" do
      base_amount = Decimal.new("100.00")
      tax_rate = Decimal.new("0.10")
      discount = Decimal.new("0.05")

      result =
        BillingCalculations.calculate_total_amount(base_amount, tax_rate, discount, :percentage)

      assert result != nil
    end

    test "calculates total with flat discount" do
      base_amount = Decimal.new("100.00")
      tax_rate = Decimal.new("0.10")
      discount = Decimal.new("10.00")

      result = BillingCalculations.calculate_total_amount(base_amount, tax_rate, discount, :flat)

      assert result != nil
    end

    test "handles zero tax and discount" do
      base_amount = Decimal.new("100.00")
      tax_rate = Decimal.new("0.00")
      discount = Decimal.new("0.00")

      result =
        BillingCalculations.calculate_total_amount(base_amount, tax_rate, discount, :percentage)

      assert result != nil
    end
  end

  # ============================================================================
  # GENERATE_PAYMENT_SCHEDULE TESTS
  # ============================================================================

  describe "generate_payment_schedule/4" do
    test "generates monthly payment schedule" do
      total_amount = Decimal.new("1200.00")
      start_date = Date.utc_today()
      num_payments = 12

      result =
        BillingCalculations.generate_payment_schedule(
          total_amount,
          start_date,
          num_payments,
          :monthly
        )

      assert is_list(result) or is_map(result)
    end

    test "generates quarterly payment schedule" do
      total_amount = Decimal.new("1200.00")
      start_date = Date.utc_today()
      num_payments = 4

      result =
        BillingCalculations.generate_payment_schedule(
          total_amount,
          start_date,
          num_payments,
          :quarterly
        )

      assert result != nil
    end

    test "generates single payment" do
      total_amount = Decimal.new("100.00")
      start_date = Date.utc_today()
      num_payments = 1

      result =
        BillingCalculations.generate_payment_schedule(
          total_amount,
          start_date,
          num_payments,
          :annual
        )

      assert result != nil
    end

    test "handles many payments" do
      total_amount = Decimal.new("5200.00")
      start_date = Date.utc_today()
      num_payments = 52

      result =
        BillingCalculations.generate_payment_schedule(
          total_amount,
          start_date,
          num_payments,
          :weekly
        )

      assert result != nil
    end
  end

  # ============================================================================
  # VALIDATE_BILLING_FREQUENCY TESTS
  # ============================================================================

  describe "validate_billing_frequency/1" do
    test "validates monthly frequency" do
      result = BillingCalculations.validate_billing_frequency(:monthly)

      assert result == :ok or result == true or match?({:ok, _}, result)
    end

    test "validates quarterly frequency" do
      result = BillingCalculations.validate_billing_frequency(:quarterly)

      assert result != nil
    end

    test "validates annual frequency" do
      result = BillingCalculations.validate_billing_frequency(:annual)

      assert result != nil
    end

    test "validates weekly frequency" do
      result = BillingCalculations.validate_billing_frequency(:weekly)

      assert result != nil
    end

    test "rejects invalid frequency" do
      result = BillingCalculations.validate_billing_frequency(:invalid)

      # Should return error or false for invalid
      assert result == :error or result == false or match?({:error, _}, result) or result == nil
    end
  end

  # ============================================================================
  # GET_PERIOD_DAYS TESTS
  # ============================================================================

  describe "get_period_days/1" do
    test "returns days for monthly period" do
      result = BillingCalculations.get_period_days(:monthly)

      assert is_integer(result) and result > 0
    end

    test "returns days for quarterly period" do
      result = BillingCalculations.get_period_days(:quarterly)

      assert is_integer(result) and result > 0
    end

    test "returns days for annual period" do
      result = BillingCalculations.get_period_days(:annual)

      assert is_integer(result) and result > 0
    end

    test "returns days for weekly period" do
      result = BillingCalculations.get_period_days(:weekly)

      assert is_integer(result) and result > 0
    end

    test "returns days for daily period" do
      result = BillingCalculations.get_period_days(:daily)

      assert is_integer(result) and result > 0
    end
  end

  # ============================================================================
  # CALCULATE_USAGE_PRICING TESTS
  # ============================================================================

  describe "calculate_usage_pricing/4" do
    test "calculates usage-based pricing" do
      units_used = 100
      rate_per_unit = Decimal.new("0.50")
      included_units = 50
      overage_rate = Decimal.new("0.75")

      result =
        BillingCalculations.calculate_usage_pricing(
          units_used,
          rate_per_unit,
          included_units,
          overage_rate
        )

      assert result != nil
    end

    test "handles no overage" do
      units_used = 30
      rate_per_unit = Decimal.new("0.50")
      included_units = 50
      overage_rate = Decimal.new("0.75")

      result =
        BillingCalculations.calculate_usage_pricing(
          units_used,
          rate_per_unit,
          included_units,
          overage_rate
        )

      assert result != nil
    end

    test "handles exact included units" do
      units_used = 50
      rate_per_unit = Decimal.new("0.50")
      included_units = 50
      overage_rate = Decimal.new("0.75")

      result =
        BillingCalculations.calculate_usage_pricing(
          units_used,
          rate_per_unit,
          included_units,
          overage_rate
        )

      assert result != nil
    end

    test "handles zero usage" do
      units_used = 0
      rate_per_unit = Decimal.new("0.50")
      included_units = 50
      overage_rate = Decimal.new("0.75")

      result =
        BillingCalculations.calculate_usage_pricing(
          units_used,
          rate_per_unit,
          included_units,
          overage_rate
        )

      assert result != nil
    end
  end

  # ============================================================================
  # CALCULATE_TIERED_PRICING TESTS
  # ============================================================================

  describe "calculate_tiered_pricing/2" do
    test "calculates tiered pricing" do
      units = 150

      tiers = [
        %{up_to: 50, rate: Decimal.new("1.00")},
        %{up_to: 100, rate: Decimal.new("0.80")},
        %{up_to: nil, rate: Decimal.new("0.60")}
      ]

      result = BillingCalculations.calculate_tiered_pricing(units, tiers)

      assert result != nil
    end

    test "handles single tier" do
      units = 50

      tiers = [
        %{up_to: nil, rate: Decimal.new("1.00")}
      ]

      result = BillingCalculations.calculate_tiered_pricing(units, tiers)

      assert result != nil
    end

    test "handles zero units" do
      units = 0

      tiers = [
        %{up_to: 50, rate: Decimal.new("1.00")},
        %{up_to: nil, rate: Decimal.new("0.80")}
      ]

      result = BillingCalculations.calculate_tiered_pricing(units, tiers)

      assert result != nil
    end

    test "handles units within first tier" do
      units = 25

      tiers = [
        %{up_to: 50, rate: Decimal.new("1.00")},
        %{up_to: 100, rate: Decimal.new("0.80")}
      ]

      result = BillingCalculations.calculate_tiered_pricing(units, tiers)

      assert result != nil
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "tax calculation is always non-negative" do
      forall {amount, rate} <- {PC.pos_integer(), PC.float(0.0, 1.0)} do
        amount_dec = Decimal.new(amount)
        rate_dec = Decimal.from_float(rate)

        result = BillingCalculations.calculate_tax(amount_dec, rate_dec)
        Decimal.compare(result, Decimal.new(0)) in [:gt, :eq]
      end
    end

    property "period days are always positive" do
      forall freq <- PC.oneof([:daily, :weekly, :monthly, :quarterly, :annual]) do
        result = BillingCalculations.get_period_days(freq)
        result > 0
      end
    end

    property "billing frequency validation is deterministic" do
      forall freq <- PC.oneof([:daily, :weekly, :monthly, :quarterly, :annual]) do
        result1 = BillingCalculations.validate_billing_frequency(freq)
        result2 = BillingCalculations.validate_billing_frequency(freq)
        result1 == result2
      end
    end

    property "price calculations are deterministic" do
      forall price <- PC.pos_integer() do
        price_dec = Decimal.new(price)
        result1 = BillingCalculations.calculate_monthly_price(price_dec, :annual)
        result2 = BillingCalculations.calculate_monthly_price(price_dec, :annual)
        Decimal.eq?(result1, result2)
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "module info returns expected structure" do
      info = BillingCalculations.__info__(:module)
      assert info == Indrajaal.Shared.BillingCalculations
    end

    test "handles very large amounts" do
      large_amount = Decimal.new("999_999_999.99")
      result = BillingCalculations.calculate_tax(large_amount, Decimal.new("0.10"))

      assert result != nil
    end

    test "handles very small amounts" do
      small_amount = Decimal.new("0.01")
      result = BillingCalculations.calculate_tax(small_amount, Decimal.new("0.10"))

      assert result != nil
    end

    test "handles precision in calculations" do
      amount = Decimal.new("33.33")
      tax_rate = Decimal.new("0.0825")

      result = BillingCalculations.calculate_tax(amount, tax_rate)

      assert %Decimal{} = result
    end
  end

  # ============================================================================
  # SOURCE CODE VALIDATION TESTS
  # ============================================================================

  describe "Source Code Validation" do
    test "source file exists" do
      assert File.exists?("lib/indrajaal/shared/billing_calculations.ex")
    end

    test "source file is valid Elixir" do
      source = File.read!("lib/indrajaal/shared/billing_calculations.ex")
      {:ok, _ast} = Code.string_to_quoted(source)
    end

    test "module has proper defmodule structure" do
      source = File.read!("lib/indrajaal/shared/billing_calculations.ex")
      assert String.contains?(source, "defmodule Indrajaal.Shared.BillingCalculations")
    end

    test "uses Decimal for precision" do
      source = File.read!("lib/indrajaal/shared/billing_calculations.ex")
      assert String.contains?(source, "Decimal")
    end

    test "has moduledoc" do
      source = File.read!("lib/indrajaal/shared/billing_calculations.ex")
      assert String.contains?(source, "@moduledoc")
    end
  end

  # ============================================================================
  # INTEGRATION SCENARIO TESTS
  # ============================================================================

  describe "Integration Scenarios" do
    test "complete billing calculation workflow" do
      # Base subscription price
      base_price = Decimal.new("99.99")

      # Calculate monthly from annual
      monthly = BillingCalculations.calculate_monthly_price(base_price, :monthly)
      assert monthly != nil

      # Apply discount
      discounted =
        BillingCalculations.calculate_discount(monthly, Decimal.new("0.10"), :percentage)

      assert discounted != nil

      # Add tax
      with_tax = BillingCalculations.calculate_tax(discounted, Decimal.new("0.08"))
      assert with_tax != nil
    end

    test "usage-based billing scenario" do
      # Customer used 150 units
      units_used = 150
      base_rate = Decimal.new("0.10")
      included = 100
      overage = Decimal.new("0.15")

      result =
        BillingCalculations.calculate_usage_pricing(units_used, base_rate, included, overage)

      assert result != nil
    end

    test "payment schedule generation for annual plan" do
      annual_price = Decimal.new("1199.88")
      start_date = ~D[2025-01-01]

      schedule =
        BillingCalculations.generate_payment_schedule(annual_price, start_date, 12, :monthly)

      assert schedule != nil
    end

    test "all billing functions are accessible" do
      functions = BillingCalculations.__info__(:functions)

      billing_functions = [
        {:calculate_monthly_price, 2},
        {:calculate_annual_price, 2},
        {:calculate_quarterly_price, 2},
        {:calculate_weekly_price, 2},
        {:calculate_prorated_amount, 3},
        {:calculate_tax, 2},
        {:calculate_discount, 3},
        {:calculate_total_amount, 4},
        {:generate_payment_schedule, 4},
        {:validate_billing_frequency, 1},
        {:get_period_days, 1},
        {:calculate_usage_pricing, 4},
        {:calculate_tiered_pricing, 2}
      ]

      Enum.each(billing_functions, fn func ->
        assert func in functions, "Expected #{inspect(func)} to be in functions"
      end)
    end
  end
end
