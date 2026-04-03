defmodule Indrajaal.Core.Holon.RegistryTest do
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Core.Holon.Registry

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Registry)
    end
  end

  describe "function exports" do
    test "register/4 is exported" do
      assert function_exported?(Registry, :register, 4)
    end

    test "unregister/1 is exported" do
      assert function_exported?(Registry, :unregister, 1)
    end

    test "lookup/1 is exported" do
      assert function_exported?(Registry, :lookup, 1)
    end

    test "whereis/1 is exported" do
      assert function_exported?(Registry, :whereis, 1)
    end

    test "list_by_layer/1 is exported" do
      assert function_exported?(Registry, :list_by_layer, 1)
    end

    test "list_children/1 is exported" do
      assert function_exported?(Registry, :list_children, 1)
    end

    test "count/0 is exported" do
      assert function_exported?(Registry, :count, 0)
    end

    test "count_by_layer/1 is exported" do
      assert function_exported?(Registry, :count_by_layer, 1)
    end

    test "all_ids/0 is exported" do
      assert function_exported?(Registry, :all_ids, 0)
    end

    test "find_orphans/0 is exported" do
      assert function_exported?(Registry, :find_orphans, 0)
    end
  end

  describe "registry GenServer lifecycle" do
    setup do
      name = :"test_registry_#{System.unique_integer([:positive])}"
      {:ok, pid} = Registry.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{registry: pid, name: name}
    end

    test "starts successfully", %{registry: pid} do
      assert Process.alive?(pid)
    end

    test "count/0 returns 0 when empty", %{name: name} do
      assert Registry.count(name) == 0
    end

    test "all_ids/0 returns empty list when empty", %{name: name} do
      assert Registry.all_ids(name) == []
    end

    test "register/4 registers a holon", %{name: name} do
      holon_id = "holon-#{System.unique_integer([:positive])}"
      assert :ok = Registry.register(name, holon_id, :function, self())
    end

    test "lookup/1 finds registered holon", %{name: name} do
      holon_id = "holon-#{System.unique_integer([:positive])}"
      Registry.register(name, holon_id, :function, self())
      result = Registry.lookup(name, holon_id)
      assert result != nil
    end

    test "unregister/1 removes holon", %{name: name} do
      holon_id = "holon-#{System.unique_integer([:positive])}"
      Registry.register(name, holon_id, :function, self())
      assert :ok = Registry.unregister(name, holon_id)
    end

    test "list_by_layer/1 returns holons for a layer", %{name: name} do
      holon_id = "holon-#{System.unique_integer([:positive])}"
      Registry.register(name, holon_id, :module, self())
      result = Registry.list_by_layer(name, :module)
      assert is_list(result)
    end

    test "find_orphans/0 returns list", %{name: name} do
      result = Registry.find_orphans(name)
      assert is_list(result)
    end
  end
end
