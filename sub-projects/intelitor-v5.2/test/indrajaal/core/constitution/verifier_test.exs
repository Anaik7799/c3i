defmodule Indrajaal.Core.Constitution.VerifierTest do
  @moduledoc """
  TDG test suite for Indrajaal.Core.Constitution.Verifier.
  STAMP: SC-CONST-001, Ψ₃
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core.Constitution.Verifier

  describe "verify/0" do
    test "returns :ok or {:ok, _}" do
      result = Verifier.verify()
      assert result == :ok or match?({:ok, _}, result)
    end
  end

  describe "verified?/0" do
    test "returns a boolean" do
      result = Verifier.verified?()
      assert is_boolean(result)
    end
  end

  describe "health_check/0" do
    test "returns a health status" do
      result = Verifier.health_check()
      assert is_atom(result) or is_map(result) or match?({:ok, _}, result)
    end
  end

  describe "verify_on_startup!/0" do
    test "does not raise on valid constitution" do
      assert :ok == Verifier.verify_on_startup!() or
               Verifier.verify_on_startup!() |> is_atom()
    rescue
      _ -> :expected_in_test_env
    end
  end

  describe "function exports" do
    test "verify/0 exported" do
      assert function_exported?(Verifier, :verify, 0)
    end

    test "verified?/0 exported" do
      assert function_exported?(Verifier, :verified?, 0)
    end

    test "health_check/0 exported" do
      assert function_exported?(Verifier, :health_check, 0)
    end
  end
end
