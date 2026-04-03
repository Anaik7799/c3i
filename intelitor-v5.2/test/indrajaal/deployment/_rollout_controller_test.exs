defmodule Indrajaal.Deployment.RolloutControllerUnderscoreTest do
  @moduledoc """
  TDG test suite for Indrajaal.Deployment.RolloutController.

  WHAT: Tests the RolloutController stub module that will eventually orchestrate
  phased rollouts (canary, blue/green, ring-based) for the deployment pipeline.
  Currently exposes only placeholder/0; tests verify module contract, behavioral
  properties, and public API surface.

  CONSTRAINTS: SC-CMP-025, SC-CNT-009
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Deployment.RolloutController

  # ---------------------------------------------------------------------------
  # Module contract
  # ---------------------------------------------------------------------------

  describe "module API" do
    test "module is loaded" do
      assert Code.ensure_loaded?(RolloutController)
    end

    test "placeholder/0 is exported" do
      assert function_exported?(RolloutController, :placeholder, 0)
    end

    test "__info__/1 :functions includes placeholder/0" do
      assert {:placeholder, 0} in RolloutController.__info__(:functions)
    end
  end

  # ---------------------------------------------------------------------------
  # placeholder/0 — behavioral contract
  # ---------------------------------------------------------------------------

  describe "placeholder/0" do
    test "returns :ok" do
      assert RolloutController.placeholder() == :ok
    end

    test "return value is strictly :ok (not a tagged tuple)" do
      result = RolloutController.placeholder()
      assert result === :ok
    end

    test "return value is an atom" do
      assert is_atom(RolloutController.placeholder())
    end

    test "idempotent across repeated calls" do
      for _ <- 1..5 do
        assert RolloutController.placeholder() == :ok
      end
    end

    test "does not raise or throw" do
      outcome =
        try do
          RolloutController.placeholder()
          :ok
        rescue
          e -> {:rescued, e}
        catch
          :throw, t -> {:thrown, t}
          :exit, r -> {:exited, r}
        end

      assert outcome == :ok
    end

    test "does not crash the calling process" do
      RolloutController.placeholder()
      assert Process.alive?(self())
    end

    test "result is not nil" do
      refute is_nil(RolloutController.placeholder())
    end

    test "concurrent calls complete and all return :ok" do
      parent = self()

      for i <- 1..8 do
        spawn(fn -> send(parent, {i, RolloutController.placeholder()}) end)
      end

      for i <- 1..8 do
        assert_receive {^i, :ok}, 2_000
      end
    end
  end
end
