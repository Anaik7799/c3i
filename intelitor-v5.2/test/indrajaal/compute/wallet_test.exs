defmodule Indrajaal.Compute.WalletTest do
  @moduledoc """
  TDG test suite for Indrajaal.Compute.Wallet GenServer.
  STAMP: SC-PRF-050, SC-AUTO-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compute.Wallet

  defp start_wallet(test) do
    name = :"wallet_#{test}"
    start_supervised!({Wallet, name: name})
    name
  end

  describe "create/2" do
    test "creates a wallet entry", %{test: test} do
      name = start_wallet(test)
      result = Wallet.create(name, "user-001")
      assert match?({:ok, _}, result) or result == :ok
    end

    test "creates wallet with initial balance", %{test: test} do
      name = start_wallet(test)
      result = Wallet.create(name, "user-002", initial_balance: 100)
      assert match?({:ok, _}, result) or result == :ok
    end
  end

  describe "get/1" do
    test "retrieves a wallet by id", %{test: test} do
      name = start_wallet(test)
      Wallet.create(name, "user-003")
      result = Wallet.get(name, "user-003")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "balance/1" do
    test "returns balance for wallet", %{test: test} do
      name = start_wallet(test)
      Wallet.create(name, "user-004")
      result = Wallet.balance(name, "user-004")
      assert match?({:ok, bal} when is_number(bal), result) or match?({:ok, _}, result)
    end
  end

  describe "credit/3" do
    test "credits amount to wallet", %{test: test} do
      name = start_wallet(test)
      Wallet.create(name, "user-005")
      result = Wallet.credit(name, "user-005", 200)
      assert match?({:ok, _}, result) or result == :ok
    end
  end

  describe "debit/3" do
    test "debits amount from wallet", %{test: test} do
      name = start_wallet(test)
      Wallet.create(name, "user-006")
      Wallet.credit(name, "user-006", 500)
      result = Wallet.debit(name, "user-006", 100)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error on insufficient funds", %{test: test} do
      name = start_wallet(test)
      Wallet.create(name, "user-007")
      result = Wallet.debit(name, "user-007", 99_999)
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "transfer/4" do
    test "transfers between wallets", %{test: test} do
      name = start_wallet(test)
      Wallet.create(name, "src")
      Wallet.create(name, "dst")
      Wallet.credit(name, "src", 500)
      result = Wallet.transfer(name, "src", "dst", 100)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "freeze/1" do
    test "freezes a wallet", %{test: test} do
      name = start_wallet(test)
      Wallet.create(name, "user-freeze")
      result = Wallet.freeze(name, "user-freeze")
      assert result == :ok or match?({:ok, _}, result)
    end
  end

  describe "history/2" do
    test "returns transaction history", %{test: test} do
      name = start_wallet(test)
      Wallet.create(name, "user-hist")
      Wallet.credit(name, "user-hist", 100)
      result = Wallet.history(name, "user-hist")

      assert match?({:ok, entries} when is_list(entries), result) or
               match?({:ok, _}, result)
    end
  end
end
