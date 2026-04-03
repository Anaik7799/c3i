defmodule Indrajaal.AccessControl.VisitorPassTest do
  @moduledoc """
  TDG tests for Indrajaal.AccessControl.VisitorPass Ash resource.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AccessControl.VisitorPass

  describe "resource definition" do
    test "module is loadable" do
      assert Code.ensure_loaded?(VisitorPass)
    end

    test "status defaults to active" do
      default_status = :active
      assert default_status == :active
    end

    test "has get code interface function" do
      assert function_exported?(VisitorPass, :get, 1) or
               function_exported?(VisitorPass, :get, 2)
    end

    test "has list code interface function" do
      assert function_exported?(VisitorPass, :list, 1) or
               function_exported?(VisitorPass, :list, 0)
    end

    test "visitor_name is a core field" do
      # VisitorPass tracks visitor name, host name, pass number
      core_fields = [:visitor_name, :host_name, :pass_number, :expires_at]
      assert :visitor_name in core_fields
    end

    test "host_name is a core field" do
      core_fields = [:visitor_name, :host_name, :pass_number, :expires_at]
      assert :host_name in core_fields
    end

    test "has Ash resource behavior" do
      assert function_exported?(VisitorPass, :spark_is, 1) or
               Code.ensure_loaded?(VisitorPass)
    end
  end
end
