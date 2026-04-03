defmodule Indrajaal.Deployment.FlagConfigManagerTest do
  @moduledoc """
  TDG test suite for Indrajaal.Deployment.FlagConfigManager.

  WHAT: Tests the FlagConfigManager stub module that will eventually manage
  feature-flag configuration (CRUD for flags, rollout percentages, targeting
  rules, persistence). Currently exposes only placeholder/0; tests verify
  module contract, behavioral properties, and public API surface.

  CONSTRAINTS: SC-CMP-025
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Deployment.FlagConfigManager

  # ---------------------------------------------------------------------------
  # Module contract
  # ---------------------------------------------------------------------------

  describe "module API" do
    test "module is loaded" do
      assert Code.ensure_loaded?(FlagConfigManager)
    end

    test "placeholder/0 is exported" do
      assert function_exported?(FlagConfigManager, :placeholder, 0)
    end

    test "placeholder/0 is in the public functions list" do
      fns = FlagConfigManager.__info__(:functions)
      assert {:placeholder, 0} in fns
    end
  end

  # ---------------------------------------------------------------------------
  # placeholder/0 — behavioral contract
  # ---------------------------------------------------------------------------

  describe "placeholder/0" do
    test "returns :ok" do
      assert FlagConfigManager.placeholder() == :ok
    end

    test "return value is the atom :ok (strict equality)" do
      assert FlagConfigManager.placeholder() === :ok
    end

    test "returns an atom" do
      assert is_atom(FlagConfigManager.placeholder())
    end

    test "does not return nil" do
      refute is_nil(FlagConfigManager.placeholder())
    end

    test "does not return an error tuple" do
      refute match?({:error, _}, FlagConfigManager.placeholder())
    end

    test "idempotent across multiple sequential calls" do
      for _ <- 1..5 do
        assert FlagConfigManager.placeholder() == :ok
      end
    end

    test "does not raise or throw" do
      outcome =
        try do
          FlagConfigManager.placeholder()
          :ok
        rescue
          _ -> :rescued
        catch
          :throw, _ -> :thrown
        end

      assert outcome == :ok
    end

    test "does not crash the calling process" do
      FlagConfigManager.placeholder()
      assert Process.alive?(self())
    end

    test "concurrent calls all return :ok" do
      parent = self()

      for i <- 1..8 do
        spawn(fn -> send(parent, {i, FlagConfigManager.placeholder()}) end)
      end

      for i <- 1..8 do
        assert_receive {^i, :ok}, 2_000
      end
    end
  end
end
