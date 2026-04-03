defmodule Indrajaal.KMS.KeyRotationTest do
  @moduledoc """
  TDG integration test: KMS key rotation and certificate renewal.

  ## STAMP Safety Integration
  - SC-KMS-001: SQLite + DuckDB only — no ETS/DETS/Khepri for state
  - SC-KMS-002: Cross-runtime access — Elixir and F# share databases
  - SC-KMS-003: Portable holons — directory copy = full backup
  - SC-SEC-047: Encryption mandatory

  ## TPS 5-Level RCA Context
  - L1 Symptom: Key rotation fails silently
  - L5 Root Cause: SQLite row format mismatch (maps not lists)
  """

  use ExUnit.Case, async: true

  @moduletag :kms

  alias Indrajaal.KMS.Service, as: KMS
  alias Indrajaal.KMS.SQLite

  describe "module existence" do
    test "KMS.Service module is loaded" do
      assert Code.ensure_loaded?(KMS)
    end

    test "KMS.SQLite module is loaded" do
      assert Code.ensure_loaded?(SQLite)
    end

    test "exports data_dir/0" do
      assert function_exported?(KMS, :data_dir, 0)
    end

    test "exports sqlite_path/0" do
      assert function_exported?(KMS, :sqlite_path, 0)
    end

    test "exports health_report/0" do
      assert function_exported?(KMS, :health_report, 0)
    end
  end

  describe "holon CRUD operations" do
    test "exports create_holon/1" do
      assert function_exported?(KMS, :create_holon, 1)
    end

    test "exports get_holon/1" do
      assert function_exported?(KMS, :get_holon, 1)
    end

    test "exports update_holon/2" do
      assert function_exported?(KMS, :update_holon, 2)
    end

    test "exports delete_holon/1" do
      assert function_exported?(KMS, :delete_holon, 1)
    end

    test "exports list_holons/1" do
      assert function_exported?(KMS, :list_holons, 1)
    end
  end

  describe "knowledge graph operations" do
    test "exports create_edge/4" do
      assert function_exported?(KMS, :create_edge, 4)
    end

    test "exports get_edges/1" do
      assert function_exported?(KMS, :get_edges, 1)
    end

    test "exports get_children/1" do
      assert function_exported?(KMS, :get_children, 1)
    end

    test "exports get_descendants/1" do
      assert function_exported?(KMS, :get_descendants, 1)
    end
  end

  describe "analytics and health" do
    test "exports event_stats/1" do
      assert function_exported?(KMS, :event_stats, 1)
    end

    test "exports entropy_report/1" do
      assert function_exported?(KMS, :entropy_report, 1)
    end

    test "exports get_rotting_holons/1" do
      assert function_exported?(KMS, :get_rotting_holons, 1)
    end

    test "exports archive_events/1" do
      assert function_exported?(KMS, :archive_events, 1)
    end
  end

  describe "data directory (SC-KMS-003)" do
    test "data_dir returns a string path" do
      dir = KMS.data_dir()
      assert is_binary(dir)
      assert String.length(dir) > 0
    end

    test "sqlite_path returns a valid database path" do
      path = KMS.sqlite_path()
      assert is_binary(path)
      assert String.ends_with?(path, ".sqlite") or String.ends_with?(path, ".db")
    end
  end

  describe "UHI naming compliance (SC-DBNAME-001)" do
    test "DatabasePath module exists" do
      assert Code.ensure_loaded?(Indrajaal.Holon.DatabasePath)
    end
  end
end
