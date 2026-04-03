defmodule Indrajaal.Deployment.TrafficSplitterTest do
  @moduledoc """
  TDG test suite for Indrajaal.Deployment.TrafficSplitter.

  WHAT: Tests the TrafficSplitter stub module that will eventually implement
  blue/green and canary traffic-splitting logic for rolling deployments.
  Currently exposes only placeholder/0; tests verify the module contract,
  behavioral properties, and public API surface.

  CONSTRAINTS: SC-CMP-025, SC-CNT-009
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Deployment.TrafficSplitter

  # ---------------------------------------------------------------------------
  # Module contract
  # ---------------------------------------------------------------------------

  describe "module API" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TrafficSplitter)
    end

    test "placeholder/0 is a public function with arity 0" do
      assert function_exported?(TrafficSplitter, :placeholder, 0)
    end

    test "public functions list contains placeholder" do
      exported = TrafficSplitter.__info__(:functions)

      public =
        Enum.reject(exported, fn {name, _} -> String.starts_with?(to_string(name), "__") end)

      assert Keyword.has_key?(public, :placeholder)
    end
  end

  # ---------------------------------------------------------------------------
  # placeholder/0 — behavioral contract
  # ---------------------------------------------------------------------------

  describe "placeholder/0" do
    test "returns :ok" do
      assert TrafficSplitter.placeholder() == :ok
    end

    test "return value is exactly the atom :ok" do
      result = TrafficSplitter.placeholder()
      assert result === :ok
    end

    test "return type is atom" do
      result = TrafficSplitter.placeholder()
      assert is_atom(result)
    end

    test "idempotent — returns :ok on every invocation" do
      results = for _ <- 1..5, do: TrafficSplitter.placeholder()
      assert Enum.all?(results, &(&1 == :ok))
    end

    test "does not raise" do
      result =
        try do
          TrafficSplitter.placeholder()
          :no_raise
        rescue
          _ -> :raised
        end

      assert result == :no_raise
    end

    test "calling process is alive after invocation" do
      TrafficSplitter.placeholder()
      assert Process.alive?(self())
    end

    test "result is not a tuple" do
      result = TrafficSplitter.placeholder()
      refute is_tuple(result)
    end

    test "concurrent invocations all return :ok" do
      parent = self()

      for i <- 1..8 do
        spawn(fn ->
          send(parent, {i, TrafficSplitter.placeholder()})
        end)
      end

      results =
        for i <- 1..8 do
          receive do
            {^i, r} -> r
          after
            2_000 -> :timeout
          end
        end

      assert Enum.all?(results, &(&1 == :ok))
    end
  end
end
