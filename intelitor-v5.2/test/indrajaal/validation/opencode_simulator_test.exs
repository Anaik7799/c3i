defmodule Indrajaal.Validation.OpenCodeSimulatorTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.OpenCodeSimulator.

  Tests offline code validation simulation.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.OpenCodeSimulator

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(OpenCodeSimulator)
    end

    test "validate/1 is exported" do
      assert function_exported?(OpenCodeSimulator, :validate, 1)
    end

    test "simulate_analysis/2 is exported" do
      assert function_exported?(OpenCodeSimulator, :simulate_analysis, 2)
    end
  end

  describe "validate/1" do
    test "returns ok tuple for valid elixir code" do
      result = OpenCodeSimulator.validate("def hello, do: :world")
      assert match?({:ok, _}, result)
    end

    test "result map contains valid key" do
      {:ok, result} = OpenCodeSimulator.validate("def hello, do: :world")
      assert Map.has_key?(result, :valid)
      assert is_boolean(result.valid)
    end

    test "result map contains issues key" do
      {:ok, result} = OpenCodeSimulator.validate("def hello, do: :world")
      assert Map.has_key?(result, :issues)
      assert is_list(result.issues)
    end

    test "result map contains confidence key" do
      {:ok, result} = OpenCodeSimulator.validate("def hello, do: :world")
      assert Map.has_key?(result, :confidence)
      assert is_float(result.confidence)
    end

    test "result map contains validator key" do
      {:ok, result} = OpenCodeSimulator.validate("def hello, do: :world")
      assert Map.has_key?(result, :validator)
      assert result.validator == :opencode_simulator
    end

    test "code with def keyword is marked valid" do
      {:ok, result} = OpenCodeSimulator.validate("def my_func(x), do: x + 1")
      assert result.valid == true
    end

    test "code with invalid keyword is marked invalid" do
      {:ok, result} = OpenCodeSimulator.validate("invalid code here")
      assert result.valid == false
    end

    test "confidence is between 0.0 and 1.0" do
      {:ok, result} = OpenCodeSimulator.validate("def hello, do: :world")
      assert result.confidence >= 0.0
      assert result.confidence <= 1.0
    end

    test "code with TODO adds an issue" do
      {:ok, result} = OpenCodeSimulator.validate("def hello do\n  # TODO: implement\n  :ok\nend")
      assert length(result.issues) > 0
    end

    test "handles empty string" do
      result = OpenCodeSimulator.validate("")
      assert match?({:ok, _}, result)
    end
  end

  describe "simulate_analysis/2" do
    test "returns ok tuple for compilation analysis" do
      result = OpenCodeSimulator.simulate_analysis("def hello, do: :world", :compilation)
      assert match?({:ok, _}, result)
    end

    test "result contains status key" do
      {:ok, result} = OpenCodeSimulator.simulate_analysis("def hello, do: :world", :compilation)
      assert Map.has_key?(result, :status)
      assert result.status == :completed
    end

    test "result contains findings key" do
      {:ok, result} = OpenCodeSimulator.simulate_analysis("def hello, do: :world", :compilation)
      assert Map.has_key?(result, :findings)
      assert is_list(result.findings)
    end

    test "result contains confidence key" do
      {:ok, result} = OpenCodeSimulator.simulate_analysis("def hello, do: :world", :compilation)
      assert Map.has_key?(result, :confidence)
      assert is_float(result.confidence)
    end

    test "result contains simulation_mode key" do
      {:ok, result} = OpenCodeSimulator.simulate_analysis("def hello, do: :world", :compilation)
      assert Map.has_key?(result, :simulation_mode)
      assert result.simulation_mode == true
    end

    test "result contains ep110_risk key" do
      {:ok, result} = OpenCodeSimulator.simulate_analysis("def hello, do: :world", :compilation)
      assert Map.has_key?(result, :ep110_risk)
      assert result.ep110_risk == false
    end

    test "detects security issues for String.to_atom usage" do
      {:ok, result} =
        OpenCodeSimulator.simulate_analysis(
          "def danger(s), do: String.to_atom(s)",
          :security_analysis
        )

      assert length(result.findings) > 0
    end

    test "returns ok for unknown analysis type" do
      result = OpenCodeSimulator.simulate_analysis("def hello, do: :world", :unknown_analysis)
      assert match?({:ok, _}, result)
    end

    test "confidence is a positive float" do
      {:ok, result} = OpenCodeSimulator.simulate_analysis("def hello, do: :world", :compilation)
      assert result.confidence > 0.0
    end
  end
end
