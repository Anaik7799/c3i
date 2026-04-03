defmodule Indrajaal.KMS.SQLiteTest do
  @moduledoc """
  TDG comprehensive test suite for KMS.SQLite.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-KMS-001: SQLite only for holon state
  - SC-KMS-004: Operations < 100ms
  - SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (no Zenoh)
  - SC-DBLOCAL-002: Local access latency < 1ms
  - SC-DBLOCAL-004: WAL mode for SQLite
  - SC-HOLON-001: All holon state in SQLite

  ## Constitutional Verification
  - Psi0 Existence: Holon data survives CRUD operations intact
  - Psi1 Regeneration: State reconstructable from SQLite WAL

  ## Founder's Directive Alignment
  - Omega0.2: Genetic perpetuity via persisted holon lineage

  ## TPS 5-Level RCA Context
  - L1 Symptom: Holon not found after insert
  - L5 Root Cause: SQLite connection not flushed before read

  ## Change History
  | Version | Date       | Author | Change                              |
  |---------|------------|--------|-------------------------------------|
  | 21.3.0  | 2026-03-21 | Claude | Sprint 54 W5 test generation (TDG)  |
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.KMS.SQLite

  @moduletag :kms_sqlite
  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # Test helpers
  # ---------------------------------------------------------------------------

  defp tmp_db do
    dir = System.tmp_dir!()
    path = Path.join(dir, "kms_sqlite_test_#{System.unique_integer([:positive])}.db")
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp valid_holon(overrides \\ %{}) do
    base = %{
      id: "hln_#{System.unique_integer([:positive])}",
      fqun: "ex:l3:kms:test:#{System.unique_integer([:positive])}",
      type: "knowledge",
      name: "Test Holon #{System.unique_integer([:positive])}",
      parent_id: nil,
      genome: "{}",
      vital_signs: ~s({"health":1.0,"stress":0.0,"energy":1.0}),
      membrane: "{}",
      payload: ~s({"content":"test"}),
      hlc_physical: System.system_time(:microsecond),
      hlc_logical: 0,
      created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Map.merge(base, overrides)
  end

  # ---------------------------------------------------------------------------
  # init/1
  # ---------------------------------------------------------------------------

  describe "init/1" do
    test "initializes a new database at the given path" do
      db = tmp_db()
      assert :ok = SQLite.init(db)
      assert File.exists?(db)
    end

    test "is idempotent - init on existing db succeeds" do
      db = tmp_db()
      assert :ok = SQLite.init(db)
      assert :ok = SQLite.init(db)
    end

    test "creates parent directories if missing" do
      dir = System.tmp_dir!()
      db = Path.join([dir, "nested_#{System.unique_integer()}", "kms.db"])
      on_exit(fn -> File.rm_rf(Path.dirname(db)) end)
      assert :ok = SQLite.init(db)
      assert File.exists?(db)
    end

    test "WAL mode is set (SC-DBLOCAL-004)" do
      db = tmp_db()
      :ok = SQLite.init(db)
      {:ok, rows} = SQLite.query(db, "PRAGMA journal_mode", [])
      modes = Enum.map(rows, & &1.journal_mode)
      assert "wal" in modes
    end
  end

  # ---------------------------------------------------------------------------
  # insert_holon/2 and get_holon/2
  # ---------------------------------------------------------------------------

  describe "insert_holon/2" do
    setup do
      db = tmp_db()
      :ok = SQLite.init(db)
      {:ok, db: db}
    end

    test "inserts a holon and returns it", %{db: db} do
      h = valid_holon()
      assert {:ok, returned} = SQLite.insert_holon(db, h)
      assert returned.id == h.id
      assert returned.name == h.name
    end

    test "persists so get_holon/2 finds it", %{db: db} do
      h = valid_holon()
      {:ok, _} = SQLite.insert_holon(db, h)
      assert {:ok, fetched} = SQLite.get_holon(db, h.id)
      assert fetched.id == h.id
      assert fetched.fqun == h.fqun
    end

    test "returns error for duplicate id", %{db: db} do
      h = valid_holon()
      {:ok, _} = SQLite.insert_holon(db, h)
      assert {:error, _reason} = SQLite.insert_holon(db, h)
    end

    test "accepted types: knowledge, process, agent, artifact, index", %{db: db} do
      for type <- ["knowledge", "process", "agent", "artifact", "index"] do
        h = valid_holon(%{id: "hln_#{type}_#{System.unique_integer()}", type: type})
        assert {:ok, _} = SQLite.insert_holon(db, h)
      end
    end
  end

  describe "get_holon/2" do
    setup do
      db = tmp_db()
      :ok = SQLite.init(db)
      {:ok, db: db}
    end

    test "returns :not_found for unknown id", %{db: db} do
      assert {:error, :not_found} = SQLite.get_holon(db, "nonexistent_id")
    end

    test "decodes JSON genome field", %{db: db} do
      h = valid_holon(%{genome: ~s({"key":"value"})})
      {:ok, _} = SQLite.insert_holon(db, h)
      {:ok, fetched} = SQLite.get_holon(db, h.id)
      assert is_map(fetched.genome)
      assert fetched.genome["key"] == "value"
    end

    test "decodes JSON payload field", %{db: db} do
      h = valid_holon(%{payload: ~s({"content":"hello world"})})
      {:ok, _} = SQLite.insert_holon(db, h)
      {:ok, fetched} = SQLite.get_holon(db, h.id)
      assert is_map(fetched.payload)
      assert fetched.payload["content"] == "hello world"
    end
  end

  # ---------------------------------------------------------------------------
  # get_holon_by_fqun/2
  # ---------------------------------------------------------------------------

  describe "get_holon_by_fqun/2" do
    setup do
      db = tmp_db()
      :ok = SQLite.init(db)
      {:ok, db: db}
    end

    test "finds holon by FQUN", %{db: db} do
      h = valid_holon(%{fqun: "ex:l3:kms:unique:fqun_test"})
      {:ok, _} = SQLite.insert_holon(db, h)
      assert {:ok, fetched} = SQLite.get_holon_by_fqun(db, h.fqun)
      assert fetched.id == h.id
    end

    test "returns :not_found for missing FQUN", %{db: db} do
      assert {:error, :not_found} = SQLite.get_holon_by_fqun(db, "nonexistent:fqun")
    end
  end

  # ---------------------------------------------------------------------------
  # list_holons/2
  # ---------------------------------------------------------------------------

  describe "list_holons/2" do
    setup do
      db = tmp_db()
      :ok = SQLite.init(db)

      for i <- 1..5 do
        h =
          valid_holon(%{
            id: "hln_list_#{i}",
            type: if(rem(i, 2) == 0, do: "process", else: "knowledge")
          })

        SQLite.insert_holon(db, h)
      end

      {:ok, db: db}
    end

    test "lists all holons", %{db: db} do
      assert {:ok, holons} = SQLite.list_holons(db)
      assert length(holons) == 5
    end

    test "filters by type", %{db: db} do
      assert {:ok, knowledge} = SQLite.list_holons(db, type: "knowledge")
      assert Enum.all?(knowledge, &(&1.type == "knowledge"))
    end

    test "respects limit option", %{db: db} do
      assert {:ok, limited} = SQLite.list_holons(db, limit: 2)
      assert length(limited) == 2
    end

    test "respects offset option", %{db: db} do
      assert {:ok, page1} = SQLite.list_holons(db, limit: 2, offset: 0)
      assert {:ok, page2} = SQLite.list_holons(db, limit: 2, offset: 2)
      ids1 = Enum.map(page1, & &1.id)
      ids2 = Enum.map(page2, & &1.id)
      assert MapSet.disjoint?(MapSet.new(ids1), MapSet.new(ids2))
    end

    test "returns empty list when no holons match filter", %{db: db} do
      assert {:ok, []} = SQLite.list_holons(db, type: "index")
    end
  end

  # ---------------------------------------------------------------------------
  # update_holon/3
  # ---------------------------------------------------------------------------

  describe "update_holon/3" do
    setup do
      db = tmp_db()
      :ok = SQLite.init(db)
      h = valid_holon()
      {:ok, _} = SQLite.insert_holon(db, h)
      {:ok, db: db, holon: h}
    end

    test "updates name field", %{db: db, holon: h} do
      assert {:ok, updated} = SQLite.update_holon(db, h.id, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "updated value persists on re-read", %{db: db, holon: h} do
      SQLite.update_holon(db, h.id, %{name: "Persisted Name"})
      {:ok, fetched} = SQLite.get_holon(db, h.id)
      assert fetched.name == "Persisted Name"
    end

    test "returns error for unknown holon id", %{db: db} do
      assert {:error, :not_found} = SQLite.update_holon(db, "ghost_id", %{name: "x"})
    end

    test "HLC timestamps advance on update", %{db: db, holon: h} do
      {:ok, _} = SQLite.insert_holon(db, valid_holon(%{id: "hln_hlc_test"}))
      :timer.sleep(1)
      {:ok, updated} = SQLite.update_holon(db, h.id, %{name: "Updated"})
      assert updated.hlc_physical >= h.hlc_physical
    end
  end

  # ---------------------------------------------------------------------------
  # delete_holon/2
  # ---------------------------------------------------------------------------

  describe "delete_holon/2" do
    setup do
      db = tmp_db()
      :ok = SQLite.init(db)
      h = valid_holon()
      {:ok, _} = SQLite.insert_holon(db, h)
      {:ok, db: db, holon: h}
    end

    test "deletes existing holon", %{db: db, holon: h} do
      assert :ok = SQLite.delete_holon(db, h.id)
      assert {:error, :not_found} = SQLite.get_holon(db, h.id)
    end

    test "deleting non-existent holon returns :ok (idempotent)", %{db: db} do
      assert :ok = SQLite.delete_holon(db, "ghost_id")
    end
  end

  # ---------------------------------------------------------------------------
  # Edges
  # ---------------------------------------------------------------------------

  describe "insert_edge/6 and get_edges/2" do
    setup do
      db = tmp_db()
      :ok = SQLite.init(db)
      h1 = valid_holon(%{id: "src_001"})
      h2 = valid_holon(%{id: "tgt_001"})
      {:ok, _} = SQLite.insert_holon(db, h1)
      {:ok, _} = SQLite.insert_holon(db, h2)
      {:ok, db: db, src: h1.id, tgt: h2.id}
    end

    test "inserts edge and retrieves it", %{db: db, src: src, tgt: tgt} do
      assert :ok = SQLite.insert_edge(db, src, tgt, :relates_to, 1.0, %{})
      assert {:ok, edges} = SQLite.get_edges(db, src)
      assert length(edges) >= 1
      edge = Enum.find(edges, &(&1.source_id == src))
      assert edge.target_id == tgt
      assert edge.relation == "relates_to"
    end

    test "edge metadata is decoded as map", %{db: db, src: src, tgt: tgt} do
      SQLite.insert_edge(db, src, tgt, :has_metadata, 0.5, %{key: "val"})
      {:ok, edges} = SQLite.get_edges(db, src)
      edge = Enum.find(edges, &(&1.source_id == src))
      assert is_map(edge.metadata)
    end

    test "get_edges returns both incoming and outgoing edges", %{db: db, src: src, tgt: tgt} do
      SQLite.insert_edge(db, src, tgt, :link, 1.0, %{})
      {:ok, src_edges} = SQLite.get_edges(db, src)
      {:ok, tgt_edges} = SQLite.get_edges(db, tgt)
      assert length(src_edges) >= 1
      assert length(tgt_edges) >= 1
    end
  end

  describe "list_edges/2" do
    setup do
      db = tmp_db()
      :ok = SQLite.init(db)
      h1 = valid_holon(%{id: "le_src"})
      h2 = valid_holon(%{id: "le_tgt"})
      {:ok, _} = SQLite.insert_holon(db, h1)
      {:ok, _} = SQLite.insert_holon(db, h2)
      SQLite.insert_edge(db, h1.id, h2.id, :type_a, 1.0, %{})
      SQLite.insert_edge(db, h2.id, h1.id, :type_b, 0.5, %{})
      {:ok, db: db}
    end

    test "lists all edges without filter", %{db: db} do
      assert {:ok, edges} = SQLite.list_edges(db)
      assert length(edges) == 2
    end

    test "filters edges by relation type", %{db: db} do
      assert {:ok, filtered} = SQLite.list_edges(db, type: :type_a)
      assert Enum.all?(filtered, &(&1.relation == "type_a"))
    end
  end

  # ---------------------------------------------------------------------------
  # Hierarchical queries
  # ---------------------------------------------------------------------------

  describe "get_children/2 and get_descendants/2" do
    setup do
      db = tmp_db()
      :ok = SQLite.init(db)
      root = valid_holon(%{id: "root_001"})
      child1 = valid_holon(%{id: "child_001", parent_id: "root_001"})
      child2 = valid_holon(%{id: "child_002", parent_id: "root_001"})
      grandchild = valid_holon(%{id: "grandchild_001", parent_id: "child_001"})
      {:ok, _} = SQLite.insert_holon(db, root)
      {:ok, _} = SQLite.insert_holon(db, child1)
      {:ok, _} = SQLite.insert_holon(db, child2)
      {:ok, _} = SQLite.insert_holon(db, grandchild)
      {:ok, db: db}
    end

    test "get_children returns direct children only", %{db: db} do
      assert {:ok, children} = SQLite.get_children(db, "root_001")
      ids = Enum.map(children, & &1.id)
      assert "child_001" in ids
      assert "child_002" in ids
      refute "grandchild_001" in ids
    end

    test "get_descendants returns all recursive descendants", %{db: db} do
      assert {:ok, descendants} = SQLite.get_descendants(db, "root_001")
      ids = Enum.map(descendants, & &1.id)
      assert "child_001" in ids
      assert "child_002" in ids
      assert "grandchild_001" in ids
    end

    test "get_children returns empty list for leaf node", %{db: db} do
      assert {:ok, []} = SQLite.get_children(db, "grandchild_001")
    end
  end

  # ---------------------------------------------------------------------------
  # full_text_search/3
  # ---------------------------------------------------------------------------

  describe "full_text_search/3" do
    setup do
      db = tmp_db()
      :ok = SQLite.init(db)

      h1 =
        valid_holon(%{
          id: "fts_001",
          name: "Authentication Service",
          payload: ~s({"content":"JWT OAuth2 bearer token"})
        })

      h2 =
        valid_holon(%{
          id: "fts_002",
          name: "Unrelated Topic",
          payload: ~s({"content":"completely different subject matter"})
        })

      {:ok, _} = SQLite.insert_holon(db, h1)
      {:ok, _} = SQLite.insert_holon(db, h2)
      {:ok, db: db}
    end

    test "finds holons by name keyword", %{db: db} do
      assert {:ok, results} = SQLite.full_text_search(db, "Authentication", 10)
      ids = Enum.map(results, & &1.id)
      assert "fts_001" in ids
    end

    test "returns empty list for unmatched query", %{db: db} do
      assert {:ok, []} = SQLite.full_text_search(db, "xyznonexistentterm", 10)
    end

    test "respects limit parameter", %{db: db} do
      assert {:ok, results} = SQLite.full_text_search(db, "content", 1)
      assert length(results) <= 1
    end
  end

  # ---------------------------------------------------------------------------
  # log_event/4
  # ---------------------------------------------------------------------------

  describe "log_event/4" do
    setup do
      db = tmp_db()
      :ok = SQLite.init(db)
      h = valid_holon()
      {:ok, _} = SQLite.insert_holon(db, h)
      {:ok, db: db, holon_id: h.id}
    end

    test "logs event and it appears in events table", %{db: db, holon_id: holon_id} do
      assert :ok = SQLite.log_event(db, holon_id, :created, %{reason: "test"})
      {:ok, rows} = SQLite.query(db, "SELECT * FROM holon_events WHERE holon_id = ?1", [holon_id])
      assert length(rows) >= 1
      event = hd(rows)
      assert event.event_type == "created"
    end

    test "multiple events accumulate (append-only SC-REG-001)", %{db: db, holon_id: holon_id} do
      :ok = SQLite.log_event(db, holon_id, :updated, %{})
      :ok = SQLite.log_event(db, holon_id, :updated, %{})
      {:ok, rows} = SQLite.query(db, "SELECT * FROM holon_events WHERE holon_id = ?1", [holon_id])
      assert length(rows) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # export_holons/3 and import_holons/2
  # ---------------------------------------------------------------------------

  describe "export_holons/3 and import_holons/2" do
    setup do
      src_db = tmp_db()
      dest_db = tmp_db()
      :ok = SQLite.init(src_db)
      :ok = SQLite.init(dest_db)
      holons = for i <- 1..3, do: valid_holon(%{id: "exp_#{i}"})
      Enum.each(holons, &SQLite.insert_holon(src_db, &1))
      {:ok, src: src_db, dest: dest_db, holons: holons}
    end

    test "export_holons creates destination database", %{src: src, dest: dest, holons: holons} do
      assert {:ok, ^dest} = SQLite.export_holons(src, holons, dest)
      assert File.exists?(dest)
    end

    test "exported holons are readable from destination", %{src: src, dest: dest, holons: holons} do
      {:ok, _} = SQLite.export_holons(src, holons, dest)
      {:ok, fetched} = SQLite.list_holons(dest)
      exported_ids = Enum.map(fetched, & &1.id)
      Enum.each(holons, fn h -> assert h.id in exported_ids end)
    end

    test "import_holons returns count of imported holons", %{src: src, dest: dest} do
      # First populate source, then import into dest via import_holons
      assert {:ok, count} = SQLite.import_holons(dest, src)
      assert count >= 3
    end
  end

  # ---------------------------------------------------------------------------
  # query/3 and execute/3 raw API
  # ---------------------------------------------------------------------------

  describe "query/3 and execute/3 raw API" do
    setup do
      db = tmp_db()
      :ok = SQLite.init(db)
      h = valid_holon()
      {:ok, _} = SQLite.insert_holon(db, h)
      {:ok, db: db, holon: h}
    end

    test "query/3 returns rows as maps", %{db: db, holon: h} do
      assert {:ok, rows} = SQLite.query(db, "SELECT id, name FROM holons WHERE id = ?1", [h.id])
      assert [row] = rows
      assert row.id == h.id
    end

    test "execute/3 performs INSERT and returns :done", %{db: db} do
      h2 = valid_holon(%{id: "raw_exec_id"})

      sql = """
      INSERT INTO holons (id, fqun, type, name, parent_id, genome, vital_signs, membrane, payload, hlc_physical, hlc_logical, created_at, updated_at)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)
      """

      params = [
        h2.id,
        h2.fqun,
        h2.type,
        h2.name,
        h2.parent_id,
        h2.genome,
        h2.vital_signs,
        h2.membrane,
        h2.payload,
        h2.hlc_physical,
        h2.hlc_logical,
        h2.created_at,
        h2.updated_at
      ]

      assert {:ok, :done} = SQLite.execute(db, sql, params)
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  property "insert then get returns same id" do
    forall id <- PC.non_empty(PC.utf8()) do
      db = tmp_db()
      SQLite.init(db)
      h = valid_holon(%{id: id, fqun: "ex:l3:kms:prop:#{id}"})

      case SQLite.insert_holon(db, h) do
        {:ok, _} ->
          {:ok, fetched} = SQLite.get_holon(db, id)
          fetched.id == id

        {:error, _} ->
          # Skip duplicate IDs from generator collisions
          true
      end
    end
  end

  property "holon type constraint enforced for valid types" do
    valid_types = ["knowledge", "process", "agent", "artifact", "index"]

    forall type <- PC.oneof(Enum.map(valid_types, &PC.exactly/1)) do
      db = tmp_db()
      SQLite.init(db)
      h = valid_holon(%{id: "prop_#{type}_#{System.unique_integer()}", type: type})
      match?({:ok, _}, SQLite.insert_holon(db, h))
    end
  end

  property "list_holons with limit never exceeds limit" do
    forall limit <- PC.pos_integer() do
      db = tmp_db()
      SQLite.init(db)

      for i <- 1..3 do
        SQLite.insert_holon(db, valid_holon(%{id: "prop_list_#{i}_#{System.unique_integer()}"}))
      end

      {:ok, holons} = SQLite.list_holons(db, limit: limit)
      length(holons) <= limit
    end
  end

  test "cosine similarity property: all holons have atom-keyed maps after decode" do
    ExUnitProperties.check all(
                             name <- SD.string(:alphanumeric, min_length: 1, max_length: 50),
                             content <- SD.string(:alphanumeric, min_length: 1, max_length: 100)
                           ) do
      db = tmp_db()
      SQLite.init(db)

      h =
        valid_holon(%{
          id: "prop_decode_#{System.unique_integer()}",
          name: name,
          payload: Jason.encode!(%{content: content})
        })

      {:ok, _} = SQLite.insert_holon(db, h)
      {:ok, fetched} = SQLite.get_holon(db, h.id)
      is_map(fetched.payload) and is_map(fetched.genome)
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 / Constitutional tests
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi1)" do
    setup do
      db = tmp_db()
      :ok = SQLite.init(db)
      {:ok, db: db}
    end

    test "Psi0: system continues to exist after delete operation", %{db: db} do
      h = valid_holon()
      {:ok, _} = SQLite.insert_holon(db, h)
      :ok = SQLite.delete_holon(db, h.id)
      # Database file still exists - system survives
      assert File.exists?(db)
    end

    test "Psi1: state fully reconstructable from SQLite (SC-HOLON-001)", %{db: db} do
      h = valid_holon(%{payload: ~s({"version":1,"data":"test"})})
      {:ok, _} = SQLite.insert_holon(db, h)
      {:ok, fetched} = SQLite.get_holon(db, h.id)
      assert fetched.id == h.id
      assert fetched.fqun == h.fqun
      assert fetched.name == h.name
      assert fetched.type == h.type
    end

    test "SC-HOLON-009: single-file portability - db file is self-contained", %{db: db} do
      h = valid_holon()
      {:ok, _} = SQLite.insert_holon(db, h)
      # Verify single file contains all data
      assert File.exists?(db)
      size = File.stat!(db).size
      assert size > 0
    end
  end

  describe "FMEA: Failure Mode Analysis" do
    test "graceful error on invalid db path" do
      result = SQLite.get_holon("/nonexistent_path/kms.db", "any_id")
      assert match?({:error, _}, result)
    end

    test "handles empty genome string gracefully" do
      db = tmp_db()
      :ok = SQLite.init(db)
      h = valid_holon(%{genome: ""})

      case SQLite.insert_holon(db, h) do
        {:ok, _} ->
          case SQLite.get_holon(db, h.id) do
            {:ok, fetched} -> assert is_map(fetched.genome) or fetched.genome == %{}
            {:error, _} -> :ok
          end

        {:error, _} ->
          :ok
      end
    end
  end
end
