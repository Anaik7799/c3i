defmodule Indrajaal.Validation.MultiAiValidatorTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.MultiAiValidator.

  Tests multi-AI consensus validation framework.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.MultiAiValidator

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(MultiAiValidator)
    end

    test "validate/2 is exported" do
      assert function_exported?(MultiAiValidator, :validate, 2)
    end

    test "validate_with/3 is exported" do
      assert function_exported?(MultiAiValidator, :validate_with, 3)
    end

    test "health_check/0 is exported" do
      assert function_exported?(MultiAiValidator, :health_check, 0)
    end
  end

  describe "validate/2" do
    test "returns ok tuple for valid elixir code" do
      result = MultiAiValidator.validate("def hello, do: :world")
      assert match?({:ok, _}, result)
    end

    test "result map contains consensus key" do
      {:ok, result} = MultiAiValidator.validate("def hello, do: :world")
      assert Map.has_key?(result, :consensus)
      assert is_boolean(result.consensus)
    end

    test "result map contains valid key" do
      {:ok, result} = MultiAiValidator.validate("def hello, do: :world")
      assert Map.has_key?(result, :valid)
      assert is_boolean(result.valid)
    end

    test "result map contains confidence key" do
      {:ok, result} = MultiAiValidator.validate("def hello, do: :world")
      assert Map.has_key?(result, :confidence)
      assert is_float(result.confidence)
    end

    test "result map contains issues key" do
      {:ok, result} = MultiAiValidator.validate("def hello, do: :world")
      assert Map.has_key?(result, :issues)
      assert is_list(result.issues)
    end

    test "result map contains validators_used key" do
      {:ok, result} = MultiAiValidator.validate("def hello, do: :world")
      assert Map.has_key?(result, :validators_used)
      assert is_integer(result.validators_used)
    end

    test "result map contains ep_110_check key" do
      {:ok, result} = MultiAiValidator.validate("def hello, do: :world")
      assert Map.has_key?(result, :ep_110_check)
      assert is_map(result.ep_110_check)
    end

    test "ep_110_check contains risk_level" do
      {:ok, result} = MultiAiValidator.validate("def hello, do: :world")
      assert Map.has_key?(result.ep_110_check, :risk_level)
      assert result.ep_110_check.risk_level in [:low, :medium, :high]
    end

    test "accepts custom validators option" do
      result = MultiAiValidator.validate("def hello, do: :world", validators: [:local])
      assert match?({:ok, _}, result)
    end

    test "local validator detects valid code" do
      {:ok, result} = MultiAiValidator.validate("def hello, do: :world", validators: [:local])
      assert result.valid == true
    end

    test "local validator detects invalid syntax" do
      {:ok, result} = MultiAiValidator.validate("def invalid(", validators: [:local])
      assert result.valid == false
    end
  end

  describe "validate_with/3" do
    test "local validator returns ok tuple" do
      result = MultiAiValidator.validate_with(:local, "def hello, do: :world")
      assert match?({:ok, _}, result)
    end

    test "local validator result has valid key" do
      {:ok, result} = MultiAiValidator.validate_with(:local, "def hello, do: :world")
      assert Map.has_key?(result, :valid)
    end

    test "local validator result has confidence key" do
      {:ok, result} = MultiAiValidator.validate_with(:local, "def hello, do: :world")
      assert Map.has_key?(result, :confidence)
    end

    test "local validator result identifies validator" do
      {:ok, result} = MultiAiValidator.validate_with(:local, "def hello, do: :world")
      assert result.validator == :local
    end

    test "unknown validator returns error" do
      result = MultiAiValidator.validate_with(:unknown_validator_xyz, "def hello do end")
      assert result == {:error, :unknown_validator}
    end

    test "claude validator returns ok tuple" do
      result = MultiAiValidator.validate_with(:claude, "def hello, do: :world")
      assert match?({:ok, _}, result)
    end

    test "gemini validator returns ok tuple" do
      result = MultiAiValidator.validate_with(:gemini, "def hello, do: :world")
      assert match?({:ok, _}, result)
    end
  end

  describe "health_check/0" do
    test "returns a map" do
      result = MultiAiValidator.health_check()
      assert is_map(result)
    end

    test "health map contains opencode key" do
      result = MultiAiValidator.health_check()
      assert Map.has_key?(result, :opencode)
    end

    test "health map contains claude key" do
      result = MultiAiValidator.health_check()
      assert Map.has_key?(result, :claude)
    end

    test "health map contains gemini key" do
      result = MultiAiValidator.health_check()
      assert Map.has_key?(result, :gemini)
    end

    test "health map contains local key" do
      result = MultiAiValidator.health_check()
      assert Map.has_key?(result, :local)
      assert result.local == :healthy
    end

    test "health map contains consensus_engine key" do
      result = MultiAiValidator.health_check()
      assert Map.has_key?(result, :consensus_engine)
      assert result.consensus_engine == :healthy
    end
  end
end
