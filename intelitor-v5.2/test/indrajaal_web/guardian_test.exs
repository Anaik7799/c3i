defmodule IndrajaalWeb.GuardianTest do
  @moduledoc """
  Tests for IndrajaalWeb.Guardian.

  WHAT: Verifies Guardian JWT authentication module functions.
  WHY: Ensures token generation and resource lookup are correctly defined.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-SEC-044
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Guardian

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Guardian)
    end
  end

  describe "subject_for_token/2" do
    test "function exists" do
      assert function_exported?(Guardian, :subject_for_token, 2)
    end

    test "returns ok tuple for resource with id" do
      result = Guardian.subject_for_token(%{id: "user-123"}, %{})
      assert match?({:ok, _}, result)
    end

    test "returns error for resource without id" do
      result = Guardian.subject_for_token(%{}, %{})
      assert match?({:error, _}, result)
    end
  end

  describe "resource_from_claims/1" do
    test "function exists" do
      assert function_exported?(Guardian, :resource_from_claims, 1)
    end

    test "returns error for claims without sub" do
      result = Guardian.resource_from_claims(%{})
      assert match?({:error, _}, result)
    end
  end
end
