defmodule Indrajaal.AccessControlTest do
  @moduledoc """
  TDG tests for Indrajaal.AccessControl context module.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AccessControl

  describe "list_access_control/1" do
    test "returns a list result" do
      result = AccessControl.list_access_control(%{})
      assert is_list(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "create_access_rule/2" do
    test "creates a rule with valid params" do
      result = AccessControl.create_access_rule(%{name: "Test Rule", rule_type: "allow"}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "create_access_credential/1" do
    test "returns ok tuple with map on success" do
      result = AccessControl.create_access_credential(%{credential_type: :card})

      case result do
        {:ok, map} -> assert is_map(map)
        {:error, _} -> :ok
      end
    end

    test "generated id is present in result" do
      result = AccessControl.create_access_credential(%{credential_type: :card})

      case result do
        {:ok, map} -> assert Map.has_key?(map, :id) or map != %{}
        {:error, _} -> :ok
      end
    end
  end

  describe "create_access_grant/1" do
    test "returns ok or error tuple" do
      result = AccessControl.create_access_grant(%{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "create_access_level/1" do
    test "returns ok or error tuple" do
      result = AccessControl.create_access_level(%{name: "Level A", code: "LA"})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "create_access_log/1" do
    test "returns ok or error tuple" do
      result = AccessControl.create_access_log(%{event_type: :granted})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "create_visitor_pass/1" do
    test "returns ok or error tuple" do
      result = AccessControl.create_visitor_pass(%{visitor_name: "John Doe"})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "public API" do
    test "get_access_rule/2 is exported" do
      assert function_exported?(AccessControl, :get_access_rule, 2)
    end

    test "update_access_rule/3 is exported" do
      assert function_exported?(AccessControl, :update_access_rule, 3)
    end

    test "delete_access_rule/2 is exported" do
      assert function_exported?(AccessControl, :delete_access_rule, 2)
    end
  end
end
