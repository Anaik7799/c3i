defmodule RequestTransformerTest do
  @moduledoc """
  Tests for RequestTransformer (top-level module, stub implementation).
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "transform/1" do
    test "function is exported" do
      assert function_exported?(RequestTransformer, :transform, 1)
    end

    test "returns not-yet-implemented error for any request" do
      result = RequestTransformer.transform(%{method: "GET", path: "/health"})
      assert match?({:error, _}, result)
    end

    test "error message mentions stub" do
      {:error, msg} = RequestTransformer.transform(%{})
      assert is_binary(msg)

      assert String.contains?(String.downcase(msg), "stub") or
               String.contains?(msg, "not yet implemented")
    end
  end

  describe "transform/2" do
    test "function is exported" do
      assert function_exported?(RequestTransformer, :transform, 2)
    end

    test "returns error for any request and options" do
      result = RequestTransformer.transform(%{}, [])
      assert match?({:error, _}, result)
    end
  end

  describe "validate_request/1" do
    test "function is exported" do
      assert function_exported?(RequestTransformer, :validate_request, 1)
    end

    test "returns error (stub)" do
      result = RequestTransformer.validate_request(%{method: "POST"})
      assert match?({:error, _}, result)
    end
  end

  describe "apply_transformations/2" do
    test "function is exported" do
      assert function_exported?(RequestTransformer, :apply_transformations, 2)
    end

    test "returns error (stub)" do
      result = RequestTransformer.apply_transformations(%{}, [])
      assert match?({:error, _}, result)
    end
  end
end
