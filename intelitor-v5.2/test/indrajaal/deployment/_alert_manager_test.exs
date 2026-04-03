defmodule Indrajaal.Deployment.AlertManagerTest do
  @moduledoc """
  TDG test suite for Indrajaal.Deployment.AlertManager.

  WHAT: Tests the AlertManager stub module that will eventually send deployment
  alerts (Slack, PagerDuty, email) on rollout events. Currently exposes only
  placeholder/0; tests verify module contract, behavioral properties, and public
  API surface.

  CONSTRAINTS: SC-CMP-025, SC-OBS-069
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Deployment.AlertManager

  # ---------------------------------------------------------------------------
  # Module contract
  # ---------------------------------------------------------------------------

  describe "module API" do
    test "module is loaded" do
      assert Code.ensure_loaded?(AlertManager)
    end

    test "placeholder/0 is a public function with arity 0" do
      assert function_exported?(AlertManager, :placeholder, 0)
    end

    test "module info functions list contains placeholder/0" do
      fns = AlertManager.__info__(:functions)
      assert {:placeholder, 0} in fns
    end
  end

  # ---------------------------------------------------------------------------
  # placeholder/0 — behavioral contract
  # ---------------------------------------------------------------------------

  describe "placeholder/0" do
    test "returns :ok" do
      assert AlertManager.placeholder() == :ok
    end

    test "return value is the atom :ok (strict equality)" do
      assert AlertManager.placeholder() === :ok
    end

    test "return value is an atom" do
      assert is_atom(AlertManager.placeholder())
    end

    test "return value is not nil" do
      refute is_nil(AlertManager.placeholder())
    end

    test "return value is not a tuple" do
      refute is_tuple(AlertManager.placeholder())
    end

    test "idempotent over 5 sequential calls" do
      results = for _ <- 1..5, do: AlertManager.placeholder()
      assert Enum.all?(results, &(&1 == :ok))
    end

    test "does not raise on invocation" do
      result =
        try do
          AlertManager.placeholder()
          :no_raise
        rescue
          _ -> :raised
        end

      assert result == :no_raise
    end

    test "calling process survives invocation" do
      AlertManager.placeholder()
      assert Process.alive?(self())
    end

    test "8 concurrent calls all return :ok" do
      parent = self()

      for i <- 1..8 do
        spawn(fn -> send(parent, {i, AlertManager.placeholder()}) end)
      end

      for i <- 1..8 do
        assert_receive {^i, :ok}, 2_000
      end
    end
  end
end
