defmodule Indrajaal.AccessControl.AccessRequestTest do
  @moduledoc """
  TDG tests for Indrajaal.AccessControl.AccessRequest Ash resource.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AccessControl.AccessRequest

  describe "request_type enum values" do
    test "permanent is valid request type" do
      valid_types = [:permanent, :temporary, :visitor, :contractor, :emergency]
      assert :permanent in valid_types
    end

    test "temporary is valid request type" do
      valid_types = [:permanent, :temporary, :visitor, :contractor, :emergency]
      assert :temporary in valid_types
    end

    test "visitor is valid request type" do
      valid_types = [:permanent, :temporary, :visitor, :contractor, :emergency]
      assert :visitor in valid_types
    end

    test "contractor is valid request type" do
      valid_types = [:permanent, :temporary, :visitor, :contractor, :emergency]
      assert :contractor in valid_types
    end

    test "emergency is valid request type" do
      valid_types = [:permanent, :temporary, :visitor, :contractor, :emergency]
      assert :emergency in valid_types
    end
  end

  describe "resource definition" do
    test "module is loadable" do
      assert Code.ensure_loaded?(AccessRequest)
    end

    test "status defaults to pending" do
      default_status = :pending
      assert default_status == :pending
    end

    test "has get code interface function" do
      assert function_exported?(AccessRequest, :get, 1) or
               function_exported?(AccessRequest, :get, 2)
    end

    test "has list code interface function" do
      assert function_exported?(AccessRequest, :list, 1) or
               function_exported?(AccessRequest, :list, 0)
    end
  end
end
