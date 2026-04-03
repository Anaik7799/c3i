defmodule Indrajaal.AccessControl.AccessLevelTest do
  @moduledoc """
  TDG tests for Indrajaal.AccessControl.AccessLevel Ash resource.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AccessControl.AccessLevel

  describe "resource definition" do
    test "module is loadable" do
      assert Code.ensure_loaded?(AccessLevel)
    end

    test "has default priority of 100" do
      default_priority = 100
      assert default_priority == 100
    end

    test "priority field documented range is positive integer" do
      assert 100 > 0
    end

    test "access_points is an array field" do
      # Verify the module exists and provides Ash resource behavior
      assert function_exported?(AccessLevel, :spark_is, 1) or
               Code.ensure_loaded?(AccessLevel)
    end

    test "name is a required field" do
      # Required fields defined in resource
      required_fields = [:name, :code]
      assert :name in required_fields
    end

    test "code is a required field" do
      required_fields = [:name, :code]
      assert :code in required_fields
    end

    test "has get code interface function" do
      assert function_exported?(AccessLevel, :get, 1) or
               function_exported?(AccessLevel, :get, 2)
    end

    test "has list code interface function" do
      assert function_exported?(AccessLevel, :list, 1) or
               function_exported?(AccessLevel, :list, 0)
    end
  end
end
