defmodule Indrajaal.MaintenanceTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Maintenance

  test "module exists" do
    assert Code.ensure_loaded?(Maintenance)
  end

  test "list_work_orders/1 is exported" do
    assert function_exported?(Maintenance, :list_work_orders, 1)
  end

  test "list_work_orders/1 returns ok tuple" do
    assert {:ok, _} = Maintenance.list_work_orders("tenant-123")
  end
end
