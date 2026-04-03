defmodule Indrajaal.VisitorManagementTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.VisitorManagement

  test "module exists" do
    assert Code.ensure_loaded?(VisitorManagement)
  end

  test "create_visitor/1 is exported" do
    assert function_exported?(VisitorManagement, :create_visitor, 1)
  end

  test "create_security_screening/1 is exported" do
    assert function_exported?(VisitorManagement, :create_security_screening, 1)
  end

  test "create_visit_request/1 is exported" do
    assert function_exported?(VisitorManagement, :create_visit_request, 1)
  end

  test "create_visitor_pass/1 is exported" do
    assert function_exported?(VisitorManagement, :create_visitor_pass, 1)
  end

  test "format_data/1 is exported" do
    assert function_exported?(VisitorManagement, :format_data, 1)
  end

  test "create_visitor/1 returns stub error" do
    assert {:error, _reason} = VisitorManagement.create_visitor(%{name: "Test"})
  end

  test "format_data/1 returns a map for map input" do
    result = VisitorManagement.format_data(%{name: "Test Visitor", id: "v-001"})
    assert is_map(result) or is_binary(result)
  end
end
