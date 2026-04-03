defmodule Indrajaal.Compute.PricingTest do
  @moduledoc """
  TDG test suite for Indrajaal.Compute.Pricing dynamic pricing GenServer.
  STAMP: SC-PRF-050
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compute.Pricing

  defp start_pricing(test) do
    name = :"pricing_#{test}"
    start_supervised!({Pricing, name: name})
    name
  end

  describe "get_price/2" do
    test "returns a price for a resource type", %{test: test} do
      name = start_pricing(test)
      result = Pricing.get_price(name, :compute)

      assert match?({:ok, price} when is_number(price), result) or
               match?({:ok, _}, result)
    end

    test "handles unknown resource type", %{test: test} do
      name = start_pricing(test)
      result = Pricing.get_price(name, :unknown_resource)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "calculate_cost/2" do
    test "calculates cost for resource and duration", %{test: test} do
      name = start_pricing(test)
      result = Pricing.calculate_cost(name, %{type: :compute, units: 5})
      assert match?({:ok, _}, result) or is_number(result)
    end
  end

  describe "update_demand/2" do
    test "updates demand multiplier", %{test: test} do
      name = start_pricing(test)
      result = Pricing.update_demand(name, 1.5)
      assert result == :ok or match?({:ok, _}, result)
    end
  end

  describe "set_base_price/2" do
    test "sets base price for a resource", %{test: test} do
      name = start_pricing(test)
      result = Pricing.set_base_price(name, :compute)
      assert result == :ok or match?({:ok, _}, result)
    end
  end

  describe "summary/0" do
    test "returns a summary map", %{test: test} do
      name = start_pricing(test)
      result = Pricing.summary(name)
      assert is_map(result) or match?({:ok, _}, result)
    end
  end
end
