defmodule Indrajaal.Distributed.DashboardTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Distributed.Dashboard

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Dashboard)
    end
  end

  describe "public API" do
    test "defines start_link/1" do
      assert function_exported?(Dashboard, :start_link, 1)
    end

    test "defines get_dashboard/0" do
      assert function_exported?(Dashboard, :get_dashboard, 0)
    end

    test "defines get_mesh_overview/0" do
      assert function_exported?(Dashboard, :get_mesh_overview, 0)
    end

    test "defines get_container_status/0" do
      assert function_exported?(Dashboard, :get_container_status, 0)
    end

    test "defines get_fqun_summary/0" do
      assert function_exported?(Dashboard, :get_fqun_summary, 0)
    end

    test "defines get_system_metrics/0" do
      assert function_exported?(Dashboard, :get_system_metrics, 0)
    end

    test "defines execute_command/2" do
      assert function_exported?(Dashboard, :execute_command, 2)
    end

    test "defines render_text/0" do
      assert function_exported?(Dashboard, :render_text, 0)
    end
  end

  describe "GenServer" do
    test "defines child_spec/1" do
      assert function_exported?(Dashboard, :child_spec, 1)
    end

    test "child_spec returns valid map" do
      spec = Dashboard.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end
end
