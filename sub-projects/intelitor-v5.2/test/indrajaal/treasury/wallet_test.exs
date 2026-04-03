defmodule Indrajaal.Treasury.WalletTest do
  @moduledoc """
  TDG Tests for Fractal Treasury Wallet (SC-FOUNDER-002, SC-HOLON-001).

  WHAT: Test multi-asset wallet management for Founder's wealth accumulation.
  WHY: SC-FOUNDER-002 (Resource acquisition PRIMARY), SC-FOUNDER-008 (Wealth flows to Founder).

  CONSTRAINTS:
    - SC-HOLON-001: State in SQLite/DuckDB ONLY
    - SC-REG-001: All mutations via append-only register
    - SC-FOUNDER-002: Resource acquisition is PRIMARY objective
    - SC-FOUNDER-008: Wealth flows to Founder's benefit
    - EP-GEN-014: PropCheck/StreamData disambiguation
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' ExUnitProperties.check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 1, property: 2, property: 3]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Treasury.Wallet

  @moduletag :treasury
  @moduletag :founder_directive

  setup do
    # Clean state for each test
    on_exit(fn ->
      if Process.whereis(Wallet) do
        GenServer.stop(Wallet, :normal)
      end
    end)

    :ok
  end

  describe "Wallet GenServer lifecycle" do
    test "starts with empty multi-asset balances" do
      {:ok, pid} = Wallet.start_link(skip_persistence: true)

      state = :sys.get_state(pid)

      assert state.balances.btc == 0
      assert state.balances.eth == 0
      assert state.balances.icp == 0
      assert state.balances.fiat == 0
      assert state.transaction_count == 0
    end

    test "persists state to SQLite on initialization (SC-HOLON-001)" do
      sqlite_path = "data/holons/test_wallet_#{:erlang.unique_integer([:positive])}.db"

      {:ok, _pid} = Wallet.start_link(sqlite_path: sqlite_path)

      assert File.exists?(sqlite_path)

      # Cleanup
      File.rm(sqlite_path)
    end

    test "loads existing state from SQLite on restart (SC-HOLON-001)" do
      sqlite_path = "data/holons/test_wallet_restart_#{:erlang.unique_integer([:positive])}.db"

      # First instance
      {:ok, pid1} = Wallet.start_link(sqlite_path: sqlite_path)
      :ok = Wallet.deposit(pid1, :btc, 100_000_000)
      GenServer.stop(pid1, :normal)

      # Second instance - should reload state
      {:ok, pid2} = Wallet.start_link(sqlite_path: sqlite_path)
      balance = Wallet.balance(pid2, :btc)

      assert balance == 100_000_000

      # Cleanup
      GenServer.stop(pid2, :normal)
      File.rm(sqlite_path)
    end
  end

  describe "Multi-asset balance management" do
    setup do
      {:ok, pid} = Wallet.start_link(skip_persistence: true)
      %{wallet: pid}
    end

    test "deposits BTC correctly", %{wallet: wallet} do
      assert :ok = Wallet.deposit(wallet, :btc, 100_000_000)
      assert Wallet.balance(wallet, :btc) == 100_000_000
    end

    test "deposits ETH correctly", %{wallet: wallet} do
      assert :ok = Wallet.deposit(wallet, :eth, 1_000_000_000_000_000_000)
      assert Wallet.balance(wallet, :eth) == 1_000_000_000_000_000_000
    end

    test "deposits ICP correctly", %{wallet: wallet} do
      assert :ok = Wallet.deposit(wallet, :icp, 500_000_000)
      assert Wallet.balance(wallet, :icp) == 500_000_000
    end

    test "deposits FIAT correctly", %{wallet: wallet} do
      assert :ok = Wallet.deposit(wallet, :fiat, 1_000_000)
      assert Wallet.balance(wallet, :fiat) == 1_000_000
    end

    test "withdraws with sufficient balance", %{wallet: wallet} do
      :ok = Wallet.deposit(wallet, :btc, 100_000_000)
      assert {:ok, _tx_id} = Wallet.withdraw(wallet, :btc, 50_000_000)
      assert Wallet.balance(wallet, :btc) == 50_000_000
    end

    test "rejects withdrawal with insufficient balance", %{wallet: wallet} do
      :ok = Wallet.deposit(wallet, :btc, 100_000_000)
      assert {:error, :insufficient_balance} = Wallet.withdraw(wallet, :btc, 150_000_000)
      assert Wallet.balance(wallet, :btc) == 100_000_000
    end

    test "supports multiple concurrent assets", %{wallet: wallet} do
      :ok = Wallet.deposit(wallet, :btc, 100_000_000)
      :ok = Wallet.deposit(wallet, :eth, 2_000_000_000_000_000_000)
      :ok = Wallet.deposit(wallet, :icp, 500_000_000)
      :ok = Wallet.deposit(wallet, :fiat, 1_000_000)

      balances = Wallet.all_balances(wallet)

      assert balances.btc == 100_000_000
      assert balances.eth == 2_000_000_000_000_000_000
      assert balances.icp == 500_000_000
      assert balances.fiat == 1_000_000
    end
  end

  describe "Transaction history (SC-HOLON-003)" do
    setup do
      {:ok, pid} = Wallet.start_link(skip_persistence: true)
      %{wallet: pid}
    end

    test "records deposit transactions", %{wallet: wallet} do
      {:ok, tx_id} = Wallet.deposit(wallet, :btc, 100_000_000)

      tx = Wallet.get_transaction(wallet, tx_id)

      assert tx.type == :deposit
      assert tx.asset == :btc
      assert tx.amount == 100_000_000
      assert tx.tx_id == tx_id
    end

    test "records withdrawal transactions", %{wallet: wallet} do
      :ok = Wallet.deposit(wallet, :btc, 100_000_000)
      {:ok, tx_id} = Wallet.withdraw(wallet, :btc, 50_000_000)

      tx = Wallet.get_transaction(wallet, tx_id)

      assert tx.type == :withdraw
      assert tx.asset == :btc
      assert tx.amount == 50_000_000
    end

    test "maintains chronological transaction history", %{wallet: wallet} do
      Wallet.deposit(wallet, :btc, 100_000_000)
      Wallet.deposit(wallet, :eth, 1_000_000_000_000_000_000)
      Wallet.withdraw(wallet, :btc, 20_000_000)

      history = Wallet.transaction_history(wallet)

      assert length(history) == 3
      assert Enum.at(history, 0).type == :deposit
      assert Enum.at(history, 1).type == :deposit
      assert Enum.at(history, 2).type == :withdraw
    end
  end

  describe "ImmutableRegister integration (SC-REG-001)" do
    setup do
      {:ok, pid} = Wallet.start_link(skip_persistence: true)
      %{wallet: pid}
    end

    test "logs all mutations to register", %{wallet: wallet} do
      {:ok, block_hash} = Wallet.deposit(wallet, :btc, 100_000_000)

      assert is_binary(block_hash)
      assert String.length(block_hash) == 64
    end

    test "verifies register chain integrity on startup", %{wallet: wallet} do
      Wallet.deposit(wallet, :btc, 100_000_000)
      Wallet.deposit(wallet, :eth, 1_000_000_000_000_000_000)

      assert :valid = Wallet.verify_register(wallet)
    end
  end

  describe "Property-based testing (EP-GEN-014)" do
    # PropCheck property test
    property "deposits always increase balance", [:verbose] do
      forall {asset, amount} <- {PC.oneof([:btc, :eth, :icp, :fiat]), PC.pos_integer()} do
        {:ok, wallet} = Wallet.start_link(skip_persistence: true)

        initial = Wallet.balance(wallet, asset)
        :ok = Wallet.deposit(wallet, asset, amount)
        final = Wallet.balance(wallet, asset)

        GenServer.stop(wallet, :normal)
        final == initial + amount
      end
    end

    # ExUnitProperties check all
    @tag :property
    test "withdrawal never exceeds balance" do
      ExUnitProperties.check all(
                               asset <- SD.member_of([:btc, :eth, :icp, :fiat]),
                               initial <- SD.positive_integer(),
                               withdraw_amount <- SD.positive_integer()
                             ) do
        {:ok, wallet} = Wallet.start_link(skip_persistence: true)

        :ok = Wallet.deposit(wallet, asset, initial)

        result = Wallet.withdraw(wallet, asset, withdraw_amount)

        if withdraw_amount <= initial do
          assert {:ok, _tx_id} = result
          assert Wallet.balance(wallet, asset) == initial - withdraw_amount
        else
          assert {:error, :insufficient_balance} = result
          assert Wallet.balance(wallet, asset) == initial
        end

        GenServer.stop(wallet, :normal)
      end
    end
  end

  describe "Founder's Directive compliance (SC-FOUNDER-002, SC-FOUNDER-008)" do
    setup do
      {:ok, pid} = Wallet.start_link(skip_persistence: true, owner: :founder)
      %{wallet: pid}
    end

    test "wallet owner is Founder", %{wallet: wallet} do
      state = :sys.get_state(wallet)
      assert state.owner == :founder
    end

    test "tracks total wealth accumulation for Founder (SC-FOUNDER-008)", %{wallet: wallet} do
      :ok = Wallet.deposit(wallet, :btc, 100_000_000)
      :ok = Wallet.deposit(wallet, :eth, 2_000_000_000_000_000_000)
      :ok = Wallet.deposit(wallet, :fiat, 1_000_000)

      total_value_usd = Wallet.total_value_usd(wallet)

      # Should calculate total across all assets
      assert total_value_usd > 0
    end
  end
end
