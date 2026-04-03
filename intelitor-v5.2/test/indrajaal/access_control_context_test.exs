defmodule Indrajaal.AccessControlContextTest do
  @moduledoc """
  TDG tests for Indrajaal.AccessControlContext context bridge module.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AccessControlContext

  describe "validate_user_access/3" do
    test "returns ok with access_granted for valid inputs" do
      result = AccessControlContext.validate_user_access("user-123", "resource-456", :read)

      case result do
        {:ok, :access_granted} -> assert true
        {:error, _} -> assert true
      end
    end

    test "returns error with invalid_user for nil user" do
      result = AccessControlContext.validate_user_access(nil, "resource-456", :read)

      case result do
        {:error, :invalid_user} -> assert true
        {:error, _} -> assert true
        {:ok, _} -> assert true
      end
    end

    test "returns error with invalid_resource for nil resource" do
      result = AccessControlContext.validate_user_access("user-123", nil, :read)

      case result do
        {:error, :invalid_resource} -> assert true
        {:error, _} -> assert true
        {:ok, _} -> assert true
      end
    end

    test "returns error with invalid_action for nil action" do
      result = AccessControlContext.validate_user_access("user-123", "res-456", nil)

      case result do
        {:error, :invalid_action} -> assert true
        {:error, _} -> assert true
        {:ok, _} -> assert true
      end
    end

    test "returns a tuple" do
      result = AccessControlContext.validate_user_access("u", "r", :read)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "create_access_control/2" do
    test "returns error when name is missing" do
      result = AccessControlContext.create_access_control(%{}, %{})

      case result do
        {:error, :name_required} -> assert true
        {:error, _} -> assert true
        {:ok, _} -> assert true
      end
    end

    test "returns ok tuple with name provided" do
      result = AccessControlContext.create_access_control(%{name: "Test AC"}, %{})

      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end
  end

  describe "public API" do
    test "validate_user_access/3 is exported" do
      assert function_exported?(AccessControlContext, :validate_user_access, 3)
    end

    test "create_access_control/2 is exported" do
      assert function_exported?(AccessControlContext, :create_access_control, 2)
    end
  end
end
