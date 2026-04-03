defmodule Indrajaal.Deployment.GrafanaManagerTest do
  @moduledoc """
  TDG test suite for Indrajaal.Deployment.GrafanaManager.

  WHAT: Tests the GrafanaManager stub module that will eventually manage
  Grafana dashboards and datasources for deployment observability (provision,
  deprovision, health-check dashboards). Currently exposes only placeholder/0;
  tests verify module contract and behavioral properties.

  CONSTRAINTS: SC-CMP-025, SC-OBS-069
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Deployment.GrafanaManager

  # ---------------------------------------------------------------------------
  # Module contract
  # ---------------------------------------------------------------------------

  describe "module API" do
    test "module is loaded" do
      assert Code.ensure_loaded?(GrafanaManager)
    end

    test "placeholder/0 is a public function with arity 0" do
      assert function_exported?(GrafanaManager, :placeholder, 0)
    end

    test "__info__/1 :functions includes placeholder/0" do
      fns = GrafanaManager.__info__(:functions)
      assert {:placeholder, 0} in fns
    end
  end

  # ---------------------------------------------------------------------------
  # placeholder/0 — behavioral contract
  # ---------------------------------------------------------------------------

  describe "placeholder/0" do
    test "returns :ok" do
      assert GrafanaManager.placeholder() == :ok
    end

    test "return value is strictly the atom :ok" do
      assert GrafanaManager.placeholder() === :ok
    end

    test "return value is an atom" do
      assert is_atom(GrafanaManager.placeholder())
    end

    test "does not return nil" do
      refute is_nil(GrafanaManager.placeholder())
    end

    test "does not return an error tuple" do
      refute match?({:error, _}, GrafanaManager.placeholder())
    end

    test "idempotent over repeated sequential calls" do
      for _ <- 1..5 do
        assert GrafanaManager.placeholder() == :ok
      end
    end

    test "does not raise on invocation" do
      result =
        try do
          GrafanaManager.placeholder()
          :no_raise
        rescue
          _ -> :raised
        end

      assert result == :no_raise
    end

    test "calling process remains alive after invocation" do
      GrafanaManager.placeholder()
      assert Process.alive?(self())
    end

    test "concurrent calls all return :ok" do
      parent = self()

      for i <- 1..8 do
        spawn(fn -> send(parent, {i, GrafanaManager.placeholder()}) end)
      end

      for i <- 1..8 do
        assert_receive {^i, :ok}, 2_000
      end
    end
  end
end
