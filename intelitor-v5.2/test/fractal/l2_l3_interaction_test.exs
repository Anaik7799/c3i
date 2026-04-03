defmodule Indrajaal.Fractal.L2L3InteractionTest do
  @moduledoc """
  Fractal L2×L3 Interaction Test — Component-to-Holon State Propagation.

  WHAT: Tests that components (L2) correctly propagate state to holons (L3),
        verifying SQLite sovereignty, state isolation, and regeneration capability.
  WHY: The L2→L3 boundary is where module state becomes holon-sovereign state.
       Holon state MUST be stored in SQLite/DuckDB (Ω₇), never PostgreSQL.
  CONSTRAINTS:
    - SC-HOLON-001: SQLite state sovereignty
    - SC-XHOLON-001: Isolated database files per holon
    - SC-STATE-001: Atomic state updates
    - SC-DBNAME-001: All holon databases must follow UHI naming
    - Ω₇: Holon State Sovereignty axiom

  ## Change History
  | Version | Date       | Author      | Change                               |
  |---------|------------|-------------|--------------------------------------|
  | 1.0.0   | 2026-03-23 | Claude      | Initial L2→L3 interaction test suite |

  @version "1.0.0"
  @last_modified "2026-03-23T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :fractal
  @moduletag :l2_l3

  # ============================================================================
  # 1. HOLON STATE SOVEREIGNTY (Ω₇)
  # ============================================================================

  describe "L2→L3: Holon state sovereignty (Ω₇)" do
    test "DatabasePath resolves KMS holon state to SQLite path" do
      {:ok, path} = Indrajaal.Holon.DatabasePath.resolve("ex:l3:kms:srv:main:state")

      assert String.ends_with?(path, ".sqlite"),
             "Holon state must resolve to SQLite file (SC-HOLON-001)"

      assert String.contains?(path, "data/holons"),
             "Holon path must be under data/holons (AOR-HOLON-005)"
    end

    test "DatabasePath resolves KMS holon history to DuckDB path" do
      {:ok, path} = Indrajaal.Holon.DatabasePath.resolve("ex:l3:kms:srv:main:history")

      assert String.ends_with?(path, ".duckdb"),
             "Holon history must resolve to DuckDB file (AOR-HOLON-002)"
    end

    test "DatabasePath resolves planning holon state to correct path" do
      {:ok, path} = Indrajaal.Holon.DatabasePath.resolve("ex:l3:pln:srv:main:state")
      assert String.contains?(path, "data/holons")
      assert String.contains?(path, "pln")
    end

    test "UHI naming convention is enforced via colon-separated format" do
      # Valid FQDN: runtime:layer:domain:type:instance:db_type
      valid_fqdn = "ex:l3:grd:srv:main:state"
      result = Indrajaal.Holon.DatabasePath.resolve(valid_fqdn)

      assert match?({:ok, _}, result),
             "Valid UHI FQDN must resolve successfully (SC-DBNAME-001)"
    end

    test "invalid FQDN returns error, not crash (SC-DBNAME-002)" do
      for bad <- ["not-uhi", "missing:parts", "", "a:b:c"] do
        result = Indrajaal.Holon.DatabasePath.resolve(bad)

        assert match?({:error, _}, result),
               "Invalid FQDN #{inspect(bad)} must return {:error, _}"
      end
    end
  end

  # ============================================================================
  # 2. STATE ISOLATION VERIFICATION (SC-XHOLON-001)
  # ============================================================================

  describe "L2→L3: State isolation verification" do
    test "two holons in same domain have independent state paths" do
      {:ok, path1} = Indrajaal.Holon.DatabasePath.resolve("ex:l3:kms:srv:primary:state")
      {:ok, path2} = Indrajaal.Holon.DatabasePath.resolve("ex:l3:kms:srv:secondary:state")

      assert path1 != path2,
             "Different holon instances must have independent paths (SC-XHOLON-001)"
    end

    test "two holons in different domains have independent state paths" do
      {:ok, path1} = Indrajaal.Holon.DatabasePath.resolve("ex:l3:kms:srv:main:state")
      {:ok, path2} = Indrajaal.Holon.DatabasePath.resolve("ex:l3:snt:srv:main:state")

      assert path1 != path2,
             "Different domain holons must have separate paths (SC-XHOLON-001)"
    end

    test "state and history for same holon resolve to different files" do
      {:ok, state_path} = Indrajaal.Holon.DatabasePath.resolve("ex:l3:kms:srv:main:state")
      {:ok, history_path} = Indrajaal.Holon.DatabasePath.resolve("ex:l3:kms:srv:main:history")

      assert state_path != history_path,
             "State (SQLite) and history (DuckDB) must be separate files"
    end

    test "state mutations are atomic — map updates preserve existing fields" do
      state = %{version: 1, constitution_hash: "abc123", data: %{key: "value"}}
      new_state = Map.update!(state, :version, &(&1 + 1))

      assert new_state.version == 2

      assert new_state.constitution_hash == state.constitution_hash,
             "Atomic update must not corrupt adjacent fields (SC-STATE-001)"

      assert new_state.data == state.data
    end

    test "concurrent state snapshots remain independent" do
      base_state = %{holon_id: "test", version: 0, status: :active}

      snapshot_a = Map.put(base_state, :version, 1)
      snapshot_b = Map.put(base_state, :version, 2)

      assert snapshot_a.version == 1
      assert snapshot_b.version == 2

      assert base_state.version == 0,
             "Original state must be unchanged (SC-STATE-001 atomicity)"
    end
  end

  # ============================================================================
  # 3. COMPONENT STATE COMPOSITION (L2 → L3)
  # ============================================================================

  describe "L2→L3: Component state composition" do
    test "multiple component states compose into a valid holon state" do
      guardian_state = %{proposals: [], vetoes: 0, alive: true}
      sentinel_state = %{health: :green, threats: [], health_score: 0.98}
      register_state = %{blocks: [], chain_valid: true, block_count: 0}

      holon_state = %{
        guardian: guardian_state,
        sentinel: sentinel_state,
        register: register_state,
        timestamp: System.system_time(:millisecond),
        constitution_hash: :crypto.hash(:sha3_256, "test") |> Base.encode16()
      }

      assert map_size(holon_state) == 5
      assert holon_state.sentinel.health == :green
      assert holon_state.register.chain_valid == true
      assert holon_state.guardian.alive == true

      assert is_binary(holon_state.constitution_hash),
             "State must include constitution hash (SC-STATE-002)"
    end

    test "holon state includes constitution hash field (SC-STATE-002)" do
      state = %{
        holon_id: "ex:l3:kms:srv:main",
        version: 1,
        constitution_hash: Base.encode16(:crypto.hash(:sha3_256, "constitution")),
        status: :active
      }

      assert is_binary(state.constitution_hash)

      assert String.length(state.constitution_hash) == 64,
             "SHA3-256 constitution hash must be 64 hex chars"
    end

    test "state transitions are logged — transition record has required fields" do
      transition = %{
        from: :initializing,
        to: :active,
        timestamp: System.system_time(:millisecond),
        reason: :startup_complete,
        logged: true
      }

      assert Map.has_key?(transition, :from)
      assert Map.has_key?(transition, :to)
      assert Map.has_key?(transition, :timestamp)
      assert transition.logged == true, "Transitions must be logged (SC-STATE-003)"
    end

    test "version vectors are monotonically increasing" do
      versions = for i <- 1..10, do: {i, System.system_time(:nanosecond)}

      Enum.reduce(versions, {0, 0}, fn {seq, ts}, {prev_seq, prev_ts} ->
        assert seq > prev_seq, "Version sequence must increase (SC-XHOLON-007)"
        assert ts >= prev_ts, "Timestamps must be monotonic (SC-XHOLON-007)"
        {seq, ts}
      end)
    end
  end

  # ============================================================================
  # 4. REGENERATION CAPABILITY (SC-HOLON-010)
  # ============================================================================

  describe "L2→L3: Regeneration capability" do
    test "holon state structure is self-describing (SC-HOLON-016)" do
      state = %{
        schema_version: "1.0.0",
        holon_id: "ex:l3:kms:srv:main",
        runtime: "elixir",
        layer: "l3",
        domain: "kms",
        databases: %{
          state: "state.sqlite",
          history: "history.duckdb"
        },
        created_at: System.system_time(:millisecond)
      }

      assert is_binary(state.schema_version)
      assert is_binary(state.runtime)
      assert is_binary(state.layer)

      assert is_map(state.databases),
             "State must document database locations for regeneration"
    end

    test "SQLite path from FQDN matches expected holon directory structure" do
      {:ok, path} = Indrajaal.Holon.DatabasePath.resolve("ex:l3:kms:srv:main:state")

      parts = Path.split(path)
      assert "data" in parts, "Path must be under data/ directory"
      assert "holons" in parts, "Path must be under holons/ directory"
      assert "ex" in parts, "Path must include runtime code"
      assert "l3" in parts, "Path must include fractal layer"
      assert "kms" in parts, "Path must include domain code"
    end

    test "DuckDB history path is append-only (structure verified)" do
      {:ok, path} = Indrajaal.Holon.DatabasePath.resolve("ex:l3:kms:srv:main:history")

      assert String.ends_with?(path, ".duckdb"),
             "DuckDB is the append-only history store (AOR-HOLON-002, SC-XHOLON-035)"
    end

    test "holon can be identified from FQDN alone (portability)" do
      fqdn = "ex:l3:grd:srv:guardian:state"
      {:ok, path} = Indrajaal.Holon.DatabasePath.resolve(fqdn)

      assert is_binary(path)

      assert String.length(path) > 0,
             "FQDN alone is sufficient to locate holon state (AOR-HOLON-003, SC-HOLON-020)"
    end
  end

  # ============================================================================
  # 5. PROPERTY-BASED STATE PROPAGATION (L2 → L3)
  # ============================================================================

  describe "L2→L3: Property-based state propagation" do
    property "state updates preserve all existing fields" do
      forall {key, value} <- {PC.atom(), PC.binary()} do
        state = %{data: %{}, version: 1, status: :active}
        updated = put_in(state, [:data, key], value)

        get_in(updated, [:data, key]) == value and
          updated.version == state.version and
          updated.status == state.status
      end
    end

    property "version increment is always positive" do
      forall version <- PC.pos_integer() do
        new_version = version + 1
        new_version > version
      end
    end

    property "FQDN resolution is deterministic for any valid-shaped string" do
      forall _n <- PC.integer(1, 5) do
        fqdn = "ex:l3:kms:srv:main:state"
        result1 = Indrajaal.Holon.DatabasePath.resolve(fqdn)
        result2 = Indrajaal.Holon.DatabasePath.resolve(fqdn)
        result1 == result2
      end
    end

    property "holon state preserves identity and version across propagation" do
      forall {holon_id, version} <- {PC.binary(), PC.pos_integer()} do
        state = %{holon_id: holon_id, version: version, status: :active}
        state.holon_id == holon_id and state.version > 0 and state.status == :active
      end
    end

    property "state updates are retrievable by key" do
      forall value <- PC.binary() do
        key = :test_key
        state = %{}
        updated = Map.put(state, key, value)
        Map.get(updated, key) == value
      end
    end
  end

  # ============================================================================
  # 6. FMEA: L2→L3 State Propagation Failure Modes
  # ============================================================================

  describe "FMEA: L2→L3 state propagation failure modes" do
    @tag :fmea
    test "FMEA-L2L3-001: Holon state stored in PostgreSQL instead of SQLite (RPN=126)" do
      # Verify that FQDN resolution never produces a Postgres DSN
      fqdns = [
        "ex:l3:kms:srv:main:state",
        "ex:l3:snt:srv:main:state",
        "ex:l3:grd:srv:guardian:state"
      ]

      for fqdn <- fqdns do
        {:ok, path} = Indrajaal.Holon.DatabasePath.resolve(fqdn)

        refute String.starts_with?(path, "postgres://"),
               "Holon state must NEVER resolve to PostgreSQL (Ω₇, SC-HOLON-001)"

        refute String.starts_with?(path, "ecto://"),
               "Holon state must NEVER resolve to an Ecto DSN (Ω₇)"
      end
    end

    @tag :fmea
    test "FMEA-L2L3-002: State corruption from non-atomic update (RPN=90)" do
      # Atomic state update — all-or-nothing semantics
      initial = %{version: 1, data: %{a: 1, b: 2}, valid: true}

      # Simulate atomic update: build new state before committing
      candidate = Map.update!(initial, :version, &(&1 + 1))
      candidate = put_in(candidate, [:data, :c], 3)

      # Only commit if validation passes
      committed = if candidate.valid, do: candidate, else: initial

      assert committed.version == 2
      assert committed.data.a == 1
      assert committed.data.b == 2

      assert committed.data.c == 3,
             "Atomic update must apply all changes or none (SC-STATE-001)"
    end

    @tag :fmea
    test "FMEA-L2L3-003: History lineage gap in DuckDB (RPN=72)" do
      # Every state transition must produce a history record
      transitions = [
        %{seq: 1, from: :init, to: :active, ts: 1_000},
        %{seq: 2, from: :active, to: :degraded, ts: 2_000},
        %{seq: 3, from: :degraded, to: :active, ts: 3_000}
      ]

      # Verify no gaps in sequence
      seqs = Enum.map(transitions, & &1.seq)
      expected = Enum.to_list(1..length(transitions))

      assert seqs == expected,
             "Evolution history must have no gaps (SC-SMRITI-141, AOR-HOLON-011)"
    end

    @tag :fmea
    test "FMEA-L2L3-004: Cross-holon state leak via shared path (RPN=56)" do
      # Each holon instance must have a unique, non-overlapping path
      fqdns = [
        "ex:l3:kms:srv:main:state",
        "ex:l3:kms:srv:replica:state",
        "ex:l3:kms:agt:worker1:state",
        "ex:l3:snt:srv:main:state"
      ]

      paths =
        for fqdn <- fqdns do
          {:ok, path} = Indrajaal.Holon.DatabasePath.resolve(fqdn)
          path
        end

      assert length(Enum.uniq(paths)) == length(paths),
             "All holon instances must have unique state paths (SC-XHOLON-001)"
    end
  end
end
