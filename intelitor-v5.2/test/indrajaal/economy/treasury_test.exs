defmodule Indrajaal.Economy.TreasuryTest do
  @moduledoc """
  Tests for Indrajaal.Economy.Treasury.

  STAMP: SC-SEC-047
  Coverage: init/0, deposit/3 — all public functions.
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Economy.Treasury

  describe "init/0" do
    test "returns a Treasury struct" do
      t = Treasury.init()
      assert %Treasury{} = t
    end

    test "initial balance is zero" do
      t = Treasury.init()
      assert t.balance == 0
    end

    test "initial assets is an empty map" do
      t = Treasury.init()
      assert t.assets == %{}
    end

    test "returns identical struct on repeated calls" do
      assert Treasury.init() == Treasury.init()
    end
  end

  describe "deposit/3" do
    setup do
      {:ok, treasury: Treasury.init()}
    end

    test "returns a Treasury struct", %{treasury: t} do
      result = Treasury.deposit(t, :btc, 100)
      assert %Treasury{} = result
    end

    test "adds a new asset with the given amount", %{treasury: t} do
      result = Treasury.deposit(t, :btc, 50)
      assert result.assets[:btc] == 50
    end

    test "accumulates amounts for the same asset on sequential deposits", %{treasury: t} do
      result =
        t
        |> Treasury.deposit(:btc, 30)
        |> Treasury.deposit(:btc, 20)

      assert result.assets[:btc] == 50
    end

    test "stores multiple different assets independently", %{treasury: t} do
      result =
        t
        |> Treasury.deposit(:btc, 10)
        |> Treasury.deposit(:eth, 200)

      assert result.assets[:btc] == 10
      assert result.assets[:eth] == 200
    end

    test "zero-amount deposit records zero for a new asset", %{treasury: t} do
      result = Treasury.deposit(t, :btc, 0)
      assert result.assets[:btc] == 0
    end

    test "zero-amount deposit on existing asset preserves existing value", %{treasury: t} do
      result =
        t
        |> Treasury.deposit(:btc, 100)
        |> Treasury.deposit(:btc, 0)

      assert result.assets[:btc] == 100
    end

    test "deposit does not change the balance field", %{treasury: t} do
      result = Treasury.deposit(t, :btc, 999)
      assert result.balance == t.balance
    end

    test "deposit does not modify unrelated existing assets", %{treasury: t} do
      result =
        t
        |> Treasury.deposit(:eth, 500)
        |> Treasury.deposit(:btc, 100)

      assert result.assets[:eth] == 500
    end

    test "three sequential deposits for same asset accumulate correctly", %{treasury: t} do
      result =
        t
        |> Treasury.deposit(:gold, 1)
        |> Treasury.deposit(:gold, 2)
        |> Treasury.deposit(:gold, 3)

      assert result.assets[:gold] == 6
    end

    test "works with string keys as well as atom keys", %{treasury: t} do
      result = Treasury.deposit(t, "usd", 1000)
      assert result.assets["usd"] == 1000
    end
  end
end
