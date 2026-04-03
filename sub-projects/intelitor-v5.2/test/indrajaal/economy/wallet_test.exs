defmodule Indrajaal.Economy.WalletTest do
  @moduledoc """
  Tests for Indrajaal.Economy.Wallet.

  The Wallet module is a stub (empty body) — the implementation is pending.
  These tests document the expected API surface and verify the current
  state: the module loads but no public functions are yet exported.

  STAMP: SC-KMS-001 (KMS domain)

  NOTE: When Wallet is implemented, update these tests to cover the full
  public API (e.g., new/0, credit/3, debit/3, balance/1, history/1).
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Economy.Wallet

  # ---------------------------------------------------------------------------
  # Module existence (always true even for stub modules)
  # ---------------------------------------------------------------------------

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Wallet)
    end

    test "module atom resolves to a loaded module" do
      assert is_atom(Wallet)
      assert Code.ensure_loaded?(Wallet)
    end

    test "module info is accessible" do
      info = Wallet.__info__(:module)
      assert info == Indrajaal.Economy.Wallet
    end

    test "module info functions list is a keyword list" do
      fns = Wallet.__info__(:functions)
      assert is_list(fns)
    end
  end

  # ---------------------------------------------------------------------------
  # Stub state documentation
  # ---------------------------------------------------------------------------

  describe "stub module state" do
    test "no public functions exported yet (module is a stub)" do
      # Wallet is currently an empty module body. This test documents the current
      # state. When implementation is added, this test should be removed and
      # replaced with concrete function tests.
      fns = Wallet.__info__(:functions)
      # Filter out auto-generated functions that Elixir adds (__info__, etc.)
      # The stub should have no user-defined public functions
      user_functions =
        Enum.reject(fns, fn {name, _} ->
          name in [:__info__, :module_info, :__struct__, :__changeset__]
        end)

      assert user_functions == []
    end

    test "module does not define a struct" do
      # Wallet has no defstruct — unlike Treasury which defines %Treasury{}
      refute function_exported?(Wallet, :__struct__, 0)
      refute function_exported?(Wallet, :__struct__, 1)
    end
  end
end
