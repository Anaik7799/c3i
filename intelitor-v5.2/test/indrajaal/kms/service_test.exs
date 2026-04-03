defmodule Indrajaal.KMS.ServiceTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.KMS.Service.
  Tests module existence, pure path-resolution functions, and API surface.
  Do NOT start GenServer (requires SQLite/DuckDB initialization on startup).
  STAMP: SC-KMS-001 to SC-KMS-004, SC-DBNAME-001, SC-DBNAME-002
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.Service

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Service)
    end

    test "implements GenServer behaviour" do
      assert function_exported?(Service, :start_link, 1)
      assert function_exported?(Service, :init, 1)
    end
  end

  describe "pure path-resolution functions" do
    test "data_dir/0 returns a string path" do
      path = Service.data_dir()
      assert is_binary(path)
      assert String.length(path) > 0
    end

    test "sqlite_path/0 returns a .sqlite path string" do
      path = Service.sqlite_path()
      assert is_binary(path)
      assert String.ends_with?(path, ".sqlite")
    end

    test "duckdb_path/0 returns a .duckdb path string" do
      path = Service.duckdb_path()
      assert is_binary(path)
      assert String.ends_with?(path, ".duckdb")
    end

    test "stamp_constraints/0 returns a non-empty map" do
      constraints = Service.stamp_constraints()
      assert is_map(constraints)
      assert map_size(constraints) > 0
    end

    test "stamp_constraints includes SC-KMS-001" do
      constraints = Service.stamp_constraints()
      assert Map.has_key?(constraints, "SC-KMS-001")
    end
  end

  describe "public API surface" do
    test "exports get_holon/1" do
      assert function_exported?(Service, :get_holon, 1)
    end

    test "exports get_holon_by_fqun/1" do
      assert function_exported?(Service, :get_holon_by_fqun, 1)
    end

    test "exports list_holons/1" do
      assert function_exported?(Service, :list_holons, 1)
    end

    test "exports create_holon/1" do
      assert function_exported?(Service, :create_holon, 1)
    end

    test "exports update_holon/2" do
      assert function_exported?(Service, :update_holon, 2)
    end

    test "exports delete_holon/1" do
      assert function_exported?(Service, :delete_holon, 1)
    end

    test "exports create_edge/4" do
      assert function_exported?(Service, :create_edge, 4)
    end

    test "exports get_edges/1" do
      assert function_exported?(Service, :get_edges, 1)
    end

    test "exports search/2" do
      assert function_exported?(Service, :search, 2)
    end

    test "exports health_report/0" do
      assert function_exported?(Service, :health_report, 0)
    end

    test "exports log_event/3" do
      assert function_exported?(Service, :log_event, 3)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = Service.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end
end
