defmodule Indrajaal.CoreTest do
  @moduledoc """
  TDG test suite for Indrajaal.Core (BaseDomain).
  STAMP: SC-DB-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core

  describe "archive/1" do
    test "returns :ok for any input" do
      assert Core.archive(%{id: "abc"}) == :ok
    end

    test "returns :ok for nil input" do
      assert Core.archive(nil) == :ok
    end
  end

  describe "register/1" do
    test "returns ok tuple with id and name" do
      result = Core.register(%{name: "TestTenant"})
      assert match?({:ok, %{id: _, name: _}}, result)
    end

    test "returned map has a UUID id" do
      {:ok, %{id: id}} = Core.register(%{})
      assert is_binary(id)
      assert String.length(id) > 0
    end

    test "returned map has Demo Tenant name" do
      {:ok, %{name: name}} = Core.register(%{})
      assert name == "Demo Tenant"
    end
  end

  describe "module" do
    test "archive/1 is exported" do
      assert function_exported?(Core, :archive, 1)
    end

    test "register/1 is exported" do
      assert function_exported?(Core, :register, 1)
    end
  end
end
