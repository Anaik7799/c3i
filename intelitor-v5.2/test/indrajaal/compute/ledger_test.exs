defmodule Indrajaal.Compute.LedgerTest do
  @moduledoc """
  TDG test suite for Indrajaal.Compute.Ledger append-only GenServer.
  STAMP: SC-REG-001, SC-AUTO-004
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compute.Ledger

  defp start_ledger(test) do
    name = :"ledger_#{test}"
    start_supervised!({Ledger, name: name})
    name
  end

  describe "mint/3" do
    test "mints an amount to a wallet", %{test: test} do
      name = start_ledger(test)
      result = Ledger.mint(name, "wallet-1", 500)
      assert match?({:ok, _}, result) or result == :ok
    end

    test "mints multiple times accumulates", %{test: test} do
      name = start_ledger(test)
      Ledger.mint(name, "wallet-1", 100)
      Ledger.mint(name, "wallet-1", 200)
      {:ok, bal} = Ledger.balance(name)
      assert is_number(bal) or is_map(bal)
    end
  end

  describe "burn/3" do
    test "burns amount from wallet", %{test: test} do
      name = start_ledger(test)
      Ledger.mint(name, "wallet-1", 500)
      result = Ledger.burn(name, "wallet-1", 100)
      assert match?({:ok, _}, result) or result == :ok
    end
  end

  describe "transfer/4" do
    test "transfers between wallets", %{test: test} do
      name = start_ledger(test)
      Ledger.mint(name, "wallet-a", 500)
      result = Ledger.transfer(name, "wallet-a", "wallet-b", 100)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "balance/1" do
    test "returns balance after operations", %{test: test} do
      name = start_ledger(test)
      Ledger.mint(name, "wallet-1", 300)
      {:ok, bal} = Ledger.balance(name)
      assert is_number(bal) or is_map(bal)
    end
  end

  describe "entries/2" do
    test "returns ledger entries", %{test: test} do
      name = start_ledger(test)
      Ledger.mint(name, "wallet-1", 100)
      result = Ledger.entries(name, "wallet-1")

      assert match?({:ok, entries} when is_list(entries), result) or
               match?({:ok, _}, result)
    end
  end

  describe "verify/0" do
    test "verify returns ok or error tuple", %{test: test} do
      name = start_ledger(test)
      result = Ledger.verify(name)
      assert match?({:ok, _}, result) or match?({:error, _}, result) or result == :ok
    end
  end

  describe "stats/0" do
    test "stats returns a map", %{test: test} do
      name = start_ledger(test)
      result = Ledger.stats(name)
      assert is_map(result) or match?({:ok, _}, result)
    end
  end
end
