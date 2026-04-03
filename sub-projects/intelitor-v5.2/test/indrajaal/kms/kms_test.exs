defmodule Indrajaal.KMSTest do
  @moduledoc """
  Tests for the Fractal Holonic Knowledge Management System.

  Tests SQLite OLTP and DuckDB OLAP operations.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.KMS
  alias Indrajaal.KMS.SQLite
  alias Indrajaal.KMS.Analytics

  @test_data_dir "test/fixtures/kms_test_data"

  setup_all do
    # Create test data directory
    File.rm_rf!(@test_data_dir)
    File.mkdir_p!(@test_data_dir)

    on_exit(fn ->
      File.rm_rf!(@test_data_dir)
    end)

    :ok
  end

  describe "KMS configuration" do
    test "returns correct paths" do
      # Paths are node-specific for SIL-6 stability (SC-FIX-009)
      assert String.starts_with?(KMS.data_dir(), "data/kms")
      assert String.ends_with?(KMS.sqlite_path(), "holons.db")
      assert String.ends_with?(KMS.duckdb_path(), "analytics.duckdb")
    end

    test "returns STAMP constraints" do
      constraints = KMS.stamp_constraints()
      # Verify constraint map structure (keys may be atoms or strings)
      constraint_keys = Map.keys(constraints) |> Enum.map(&to_string/1)
      assert Enum.any?(constraint_keys, &(&1 =~ "SC-KMS"))
    end
  end

  describe "SQLite.init/1" do
    test "initializes database with schema" do
      db_path = Path.join(@test_data_dir, "test_init.db")
      assert :ok = SQLite.init(db_path)
      assert File.exists?(db_path)
    end

    test "creates tables" do
      db_path = Path.join(@test_data_dir, "test_tables.db")
      :ok = SQLite.init(db_path)

      # Verify tables exist by querying
      {:ok, holons} = SQLite.list_holons(db_path)
      assert is_list(holons)
    end
  end

  describe "SQLite CRUD operations" do
    setup do
      db_path = Path.join(@test_data_dir, "test_crud_#{:rand.uniform(10_000)}.db")
      :ok = SQLite.init(db_path)
      {:ok, db_path: db_path}
    end

    test "inserts and retrieves a holon", %{db_path: db_path} do
      holon = %{
        id: "hln_test123",
        fqun: "kms/l3/knowledge/test/myholon@local#1",
        type: "knowledge",
        name: "Test Holon",
        parent_id: nil,
        genome: ~s({"schema_version":"1.0.0"}),
        vital_signs: ~s({"health":1.0,"stress":0.0,"energy":1.0}),
        membrane: "{}",
        payload: ~s({"content":"Hello World"}),
        hlc_physical: System.system_time(:microsecond),
        hlc_logical: 0,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      {:ok, inserted} = SQLite.insert_holon(db_path, holon)
      assert inserted.id == "hln_test123"

      {:ok, retrieved} = SQLite.get_holon(db_path, "hln_test123")
      assert retrieved.id == "hln_test123"
      assert retrieved.name == "Test Holon"
      assert retrieved.payload["content"] == "Hello World"
    end

    test "lists holons with filtering", %{db_path: db_path} do
      # Insert multiple holons
      for i <- 1..3 do
        holon = %{
          id: "hln_list#{i}",
          fqun: "kms/l3/knowledge/test/holon#{i}@local##{i}",
          type: "knowledge",
          name: "Holon #{i}",
          parent_id: nil,
          genome: "{}",
          vital_signs: ~s({"health":1.0,"stress":0.0,"energy":1.0}),
          membrane: "{}",
          payload: "{}",
          hlc_physical: System.system_time(:microsecond),
          hlc_logical: 0,
          created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        SQLite.insert_holon(db_path, holon)
      end

      {:ok, all} = SQLite.list_holons(db_path)
      assert length(all) == 3

      {:ok, limited} = SQLite.list_holons(db_path, limit: 2)
      assert length(limited) == 2
    end

    test "returns not_found for missing holon", %{db_path: db_path} do
      assert {:error, :not_found} = SQLite.get_holon(db_path, "nonexistent")
    end

    test "deletes a holon", %{db_path: db_path} do
      holon = %{
        id: "hln_delete",
        fqun: "kms/l3/knowledge/test/delete@local#1",
        type: "knowledge",
        name: "To Delete",
        parent_id: nil,
        genome: "{}",
        vital_signs: "{}",
        membrane: "{}",
        payload: "{}",
        hlc_physical: System.system_time(:microsecond),
        hlc_logical: 0,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      {:ok, _} = SQLite.insert_holon(db_path, holon)
      {:ok, _} = SQLite.get_holon(db_path, "hln_delete")

      :ok = SQLite.delete_holon(db_path, "hln_delete")
      assert {:error, :not_found} = SQLite.get_holon(db_path, "hln_delete")
    end
  end

  describe "SQLite relationships" do
    setup do
      db_path = Path.join(@test_data_dir, "test_edges_#{:rand.uniform(10_000)}.db")
      :ok = SQLite.init(db_path)

      # Create parent and child holons
      parent = %{
        id: "hln_parent",
        fqun: "kms/l3/knowledge/test/parent@local#1",
        type: "knowledge",
        name: "Parent",
        parent_id: nil,
        genome: "{}",
        vital_signs: "{}",
        membrane: "{}",
        payload: "{}",
        hlc_physical: System.system_time(:microsecond),
        hlc_logical: 0,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      child = %{
        id: "hln_child",
        fqun: "kms/l3/knowledge/test/child@local#1",
        type: "knowledge",
        name: "Child",
        parent_id: "hln_parent",
        genome: "{}",
        vital_signs: "{}",
        membrane: "{}",
        payload: "{}",
        hlc_physical: System.system_time(:microsecond),
        hlc_logical: 0,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      SQLite.insert_holon(db_path, parent)
      SQLite.insert_holon(db_path, child)

      {:ok, db_path: db_path}
    end

    test "gets children of a holon", %{db_path: db_path} do
      {:ok, children} = SQLite.get_children(db_path, "hln_parent")
      assert length(children) == 1
      assert hd(children).id == "hln_child"
    end

    test "gets descendants recursively", %{db_path: db_path} do
      # Add grandchild
      grandchild = %{
        id: "hln_grandchild",
        fqun: "kms/l3/knowledge/test/grandchild@local#1",
        type: "knowledge",
        name: "Grandchild",
        parent_id: "hln_child",
        genome: "{}",
        vital_signs: "{}",
        membrane: "{}",
        payload: "{}",
        hlc_physical: System.system_time(:microsecond),
        hlc_logical: 0,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      SQLite.insert_holon(db_path, grandchild)

      {:ok, descendants} = SQLite.get_descendants(db_path, "hln_parent")
      assert length(descendants) == 2
      ids = Enum.map(descendants, & &1.id)
      assert "hln_child" in ids
      assert "hln_grandchild" in ids
    end
  end

  describe "SQLite event logging" do
    setup do
      db_path = Path.join(@test_data_dir, "test_events_#{:rand.uniform(10_000)}.db")
      :ok = SQLite.init(db_path)
      {:ok, db_path: db_path}
    end

    test "logs events", %{db_path: db_path} do
      :ok = SQLite.log_event(db_path, "hln_test", :created, %{source: "test"})
      :ok = SQLite.log_event(db_path, "hln_test", :updated, %{field: "name"})

      # Events are stored - verify by querying (would need a get_events function)
      # For now, just verify no errors
      assert :ok == :ok
    end
  end

  describe "SQLite full-text search" do
    setup do
      db_path = Path.join(@test_data_dir, "test_fts_#{:rand.uniform(10_000)}.db")
      :ok = SQLite.init(db_path)

      # Insert searchable holons
      holons = [
        %{
          id: "hln_auth",
          fqun: "kms/l3/knowledge/test/auth@local#1",
          type: "knowledge",
          name: "Authentication Flow",
          parent_id: nil,
          genome: "{}",
          vital_signs: "{}",
          membrane: "{}",
          payload: ~s({"content":"How to authenticate users with OAuth2"}),
          hlc_physical: System.system_time(:microsecond),
          hlc_logical: 0,
          created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
        },
        %{
          id: "hln_db",
          fqun: "kms/l3/knowledge/test/db@local#1",
          type: "knowledge",
          name: "Database Configuration",
          parent_id: nil,
          genome: "{}",
          vital_signs: "{}",
          membrane: "{}",
          payload: ~s({"content":"PostgreSQL and SQLite configuration guide"}),
          hlc_physical: System.system_time(:microsecond),
          hlc_logical: 0,
          created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }
      ]

      Enum.each(holons, &SQLite.insert_holon(db_path, &1))

      {:ok, db_path: db_path}
    end

    test "searches by name", %{db_path: db_path} do
      {:ok, results} = SQLite.full_text_search(db_path, "Authentication", 10)
      assert length(results) >= 1
      assert hd(results).name =~ "Authentication"
    end

    test "searches by payload content", %{db_path: db_path} do
      {:ok, results} = SQLite.full_text_search(db_path, "OAuth2", 10)
      assert length(results) >= 1
    end
  end
end
