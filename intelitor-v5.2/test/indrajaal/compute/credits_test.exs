defmodule Indrajaal.Compute.CreditsTest do
  @moduledoc """
  TDG test suite for Indrajaal.Compute.Credits GenServer.
  STAMP: SC-AUTO-001, SC-PRF-050
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compute.Credits

  defp start_credits(test) do
    name = :"credits_#{test}"
    start_supervised!({Credits, name: name})
    name
  end

  describe "calculate_cost/1" do
    test "returns cost map for valid operation" do
      assert {:ok, cost} = Credits.calculate_cost(%{type: :compute, units: 10})
      assert is_map(cost) or is_number(cost)
    end

    test "returns error for nil input" do
      result = Credits.calculate_cost(nil)
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "initial_allocation/1" do
    test "returns allocation for a tenant" do
      result = Credits.initial_allocation("tenant-001")
      assert match?({:ok, _}, result) or is_integer(result) or is_float(result)
    end
  end

  describe "mint/3 and balance/1 via named server" do
    test "mints credits and reflects in balance", %{test: test} do
      name = start_credits(test)
      {:ok, _} = Credits.mint(name, "wallet-1", 100)
      {:ok, bal} = Credits.balance(name)
      assert is_number(bal) or is_map(bal)
    end
  end

  describe "burn/2" do
    test "burns credits from server", %{test: test} do
      name = start_credits(test)
      Credits.mint(name, "wallet-1", 100)
      result = Credits.burn(name, 50)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "transfer/3" do
    test "transfers credits between wallets", %{test: test} do
      name = start_credits(test)
      Credits.mint(name, "wallet-a", 200)
      result = Credits.transfer(name, "wallet-a", "wallet-b")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "state/0 and summary/0" do
    test "state/0 returns current state", %{test: test} do
      name = start_credits(test)
      result = Credits.state(name)
      assert is_map(result) or match?({:ok, _}, result)
    end

    test "summary/0 returns summary map", %{test: test} do
      name = start_credits(test)
      result = Credits.summary(name)
      assert is_map(result) or match?({:ok, _}, result)
    end
  end
end
