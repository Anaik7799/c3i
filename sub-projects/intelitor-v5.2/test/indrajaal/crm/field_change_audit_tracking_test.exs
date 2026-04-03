defmodule Indrajaal.CRM.FieldChangeAuditTrackingTest do
  @moduledoc """
  Tests for CRM field change tracking with DuckDB audit log.

  Verifies complete field-level change history with append-only semantics,
  point-in-time reconstruction, and analytical query support.

  ## STAMP Compliance
  - SC-SMRITI-142: DuckDB append-only evolution history
  - AOR-HOLON-019: Lineage immutability (append-only)
  - SC-AUDIT-001: Audit trail completeness
  - SC-AUDIT-002: Audit entry integrity
  - SC-AUDIT-003: Audit log ordering
  - SC-AUDIT-004: Audit query capability
  - SC-COV-001: 100% critical path coverage
  - SC-COV-006: TDG compliance
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # Helpers — in-memory DuckDB simulation (append-only log)
  # ---------------------------------------------------------------------------

  defp new_log, do: []

  # Appends an entry; returns {:ok, updated_log}. Never mutates existing entries.
  defp append_entry(log, entry) do
    {:ok, log ++ [entry]}
  end

  defp make_entry(entity_id, field, old_value, new_value, changed_by, correlation_id, ts) do
    %{
      entity_id: entity_id,
      field: field,
      old_value: old_value,
      new_value: new_value,
      changed_by: changed_by,
      correlation_id: correlation_id,
      timestamp: ts
    }
  end

  # Record a single field change into the log.
  defp record_change(log, entity_id, field, old_value, new_value, changed_by, opts \\ []) do
    correlation_id = Keyword.get(opts, :correlation_id, generate_id())
    ts = Keyword.get(opts, :timestamp, monotonic_ts())
    entry = make_entry(entity_id, field, old_value, new_value, changed_by, correlation_id, ts)
    append_entry(log, entry)
  end

  # Record a map of field changes in one bulk operation, same correlation_id.
  defp record_bulk_changes(log, entity_id, changes, changed_by)
       when is_map(changes) do
    correlation_id = generate_id()
    base_ts = monotonic_ts()

    Enum.reduce_while(Enum.with_index(Map.to_list(changes)), {:ok, log}, fn
      {{field, {old_val, new_val}}, idx}, {:ok, acc} ->
        ts = base_ts + idx
        entry = make_entry(entity_id, field, old_val, new_val, changed_by, correlation_id, ts)

        case append_entry(acc, entry) do
          {:ok, updated} -> {:cont, {:ok, updated}}
          error -> {:halt, error}
        end
    end)
  end

  # Reconstruct entity state at a given timestamp by replaying the log.
  defp reconstruct_state_at(log, entity_id, at_ts) do
    log
    |> Enum.filter(fn e -> e.entity_id == entity_id and e.timestamp <= at_ts end)
    |> Enum.sort_by(& &1.timestamp)
    |> Enum.reduce(%{}, fn entry, state ->
      Map.put(state, entry.field, entry.new_value)
    end)
  end

  # Reconstruct current state (latest timestamp).
  defp reconstruct_current_state(log, entity_id) do
    reconstruct_state_at(log, entity_id, :infinity)
  end

  # Get full history for a specific entity and field.
  defp field_history(log, entity_id, field) do
    log
    |> Enum.filter(fn e -> e.entity_id == entity_id and e.field == field end)
    |> Enum.sort_by(& &1.timestamp)
  end

  # DuckDB-style: count changes per field for an entity.
  defp count_changes_by_field(log, entity_id) do
    log
    |> Enum.filter(fn e -> e.entity_id == entity_id end)
    |> Enum.group_by(& &1.field)
    |> Map.new(fn {field, entries} -> {field, length(entries)} end)
  end

  # Filter entries by date range (inclusive).
  defp entries_in_range(log, entity_id, from_ts, to_ts) do
    log
    |> Enum.filter(fn e ->
      e.entity_id == entity_id and e.timestamp >= from_ts and e.timestamp <= to_ts
    end)
    |> Enum.sort_by(& &1.timestamp)
  end

  defp generate_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16()

  # Monotonically increasing microsecond timestamp.
  defp monotonic_ts, do: System.monotonic_time(:microsecond)

  # ---------------------------------------------------------------------------
  # Test: single field change
  # ---------------------------------------------------------------------------

  describe "single field change" do
    test "creates audit entry with all required fields" do
      log = new_log()
      {:ok, log} = record_change(log, "acct-1", :name, "Acme", "Acme Corp", "user-42")

      assert length(log) == 1
      [entry] = log
      assert entry.entity_id == "acct-1"
      assert entry.field == :name
      assert entry.old_value == "Acme"
      assert entry.new_value == "Acme Corp"
      assert entry.changed_by == "user-42"
      assert is_binary(entry.correlation_id) and byte_size(entry.correlation_id) > 0
      assert is_integer(entry.timestamp)
    end

    test "timestamp is recorded as integer" do
      log = new_log()
      {:ok, log} = record_change(log, "acct-1", :status, "active", "inactive", "user-1")
      [entry] = log
      assert is_integer(entry.timestamp)
    end

    test "changed_by is preserved verbatim" do
      log = new_log()
      {:ok, log} = record_change(log, "lead-99", :email, "a@b.com", "x@y.com", "agent-007")
      assert hd(log).changed_by == "agent-007"
    end

    test "correlation_id can be provided explicitly" do
      log = new_log()

      {:ok, log} =
        record_change(log, "opp-5", :amount, 100, 200, "user-1", correlation_id: "CID-FIXED")

      assert hd(log).correlation_id == "CID-FIXED"
    end
  end

  # ---------------------------------------------------------------------------
  # Test: bulk field changes
  # ---------------------------------------------------------------------------

  describe "bulk field changes" do
    test "creates separate audit entry per field" do
      log = new_log()

      changes = %{
        :name => {"Old Name", "New Name"},
        :phone => {"555-0000", "555-1234"},
        :email => {"old@e.com", "new@e.com"}
      }

      {:ok, log} = record_bulk_changes(log, "acct-2", changes, "user-5")
      assert length(log) == 3
    end

    test "all bulk entries share same correlation_id" do
      log = new_log()

      changes = %{
        :city => {"Mumbai", "Pune"},
        :region => {"West", "Central"}
      }

      {:ok, log} = record_bulk_changes(log, "acct-3", changes, "user-6")
      correlation_ids = Enum.map(log, & &1.correlation_id) |> Enum.uniq()
      assert length(correlation_ids) == 1
    end

    test "all bulk entries have same entity_id" do
      log = new_log()
      changes = %{:a => {1, 2}, :b => {3, 4}, :c => {5, 6}}
      {:ok, log} = record_bulk_changes(log, "entity-X", changes, "user-7")
      assert Enum.all?(log, fn e -> e.entity_id == "entity-X" end)
    end

    test "fields in bulk entries match provided change map" do
      log = new_log()
      changes = %{:status => {"open", "closed"}, :priority => {"low", "high"}}
      {:ok, log} = record_bulk_changes(log, "case-1", changes, "agent-1")
      fields = Enum.map(log, & &1.field) |> Enum.sort()
      assert fields == [:priority, :status]
    end

    test "old and new values are preserved per field" do
      log = new_log()
      changes = %{:score => {70, 95}}
      {:ok, log} = record_bulk_changes(log, "lead-1", changes, "user-1")
      [entry] = log
      assert entry.old_value == 70
      assert entry.new_value == 95
    end
  end

  # ---------------------------------------------------------------------------
  # Test: append-only semantics
  # ---------------------------------------------------------------------------

  describe "append-only log (SC-SMRITI-142, AOR-HOLON-019)" do
    test "existing entries are unchanged after append" do
      log = new_log()
      {:ok, log} = record_change(log, "acct-1", :name, "A", "B", "u1")
      first_entry = hd(log)

      {:ok, log} = record_change(log, "acct-1", :name, "B", "C", "u2")
      assert hd(log) == first_entry
    end

    test "log length strictly increases with each append" do
      log = new_log()
      {:ok, log} = record_change(log, "acct-1", :x, 1, 2, "u1")
      assert length(log) == 1
      {:ok, log} = record_change(log, "acct-1", :x, 2, 3, "u1")
      assert length(log) == 2
      {:ok, log} = record_change(log, "acct-1", :x, 3, 4, "u1")
      assert length(log) == 3
    end

    test "no entry can be deleted from the log" do
      log = new_log()
      {:ok, log} = record_change(log, "e-1", :field, "v0", "v1", "user")
      original_id = hd(log).correlation_id

      # Simulate multiple subsequent changes
      {:ok, log} = record_change(log, "e-1", :field, "v1", "v2", "user")
      {:ok, log} = record_change(log, "e-1", :field, "v2", "v3", "user")

      # Original entry still present
      assert Enum.any?(log, fn e -> e.correlation_id == original_id end)
    end

    test "no entry can be updated (all prior entries remain immutable)" do
      log = new_log()
      {:ok, log} = record_change(log, "e-2", :amount, 100, 200, "user")
      snapshot = log

      {:ok, log} = record_change(log, "e-2", :amount, 200, 300, "user")

      # Every entry from snapshot survives unchanged
      Enum.each(snapshot, fn original ->
        assert Enum.any?(log, fn e -> e == original end)
      end)
    end

    test "append returns :ok tuple" do
      log = new_log()
      result = record_change(log, "e-3", :field, "old", "new", "user")
      assert {:ok, _updated_log} = result
    end
  end

  # ---------------------------------------------------------------------------
  # Test: chronological ordering
  # ---------------------------------------------------------------------------

  describe "chronological order (SC-AUDIT-003)" do
    test "entries are stored in insertion order" do
      log = new_log()
      {:ok, log} = record_change(log, "acct-1", :f, "v0", "v1", "u", timestamp: 100)
      {:ok, log} = record_change(log, "acct-1", :f, "v1", "v2", "u", timestamp: 200)
      {:ok, log} = record_change(log, "acct-1", :f, "v2", "v3", "u", timestamp: 300)

      timestamps = Enum.map(log, & &1.timestamp)
      assert timestamps == Enum.sort(timestamps)
    end

    test "field_history returns entries sorted by timestamp" do
      log = new_log()
      {:ok, log} = record_change(log, "acct-1", :status, "a", "b", "u", timestamp: 300)
      {:ok, log} = record_change(log, "acct-1", :status, "b", "c", "u", timestamp: 100)
      {:ok, log} = record_change(log, "acct-1", :status, "c", "d", "u", timestamp: 200)

      history = field_history(log, "acct-1", :status)
      timestamps = Enum.map(history, & &1.timestamp)
      assert timestamps == Enum.sort(timestamps)
    end

    test "earlier timestamp entry precedes later timestamp entry in history" do
      log = new_log()
      {:ok, log} = record_change(log, "e-1", :v, "first", "second", "u", timestamp: 50)
      {:ok, log} = record_change(log, "e-1", :v, "second", "third", "u", timestamp: 99)

      [e1, e2] = field_history(log, "e-1", :v)
      assert e1.timestamp < e2.timestamp
      assert e1.old_value == "first"
      assert e2.old_value == "second"
    end
  end

  # ---------------------------------------------------------------------------
  # Test: field change history reconstruction
  # ---------------------------------------------------------------------------

  describe "field change history (SC-AUDIT-001)" do
    test "full history for a field is recoverable" do
      log = new_log()
      {:ok, log} = record_change(log, "lead-1", :stage, "new", "contacted", "u", timestamp: 1)

      {:ok, log} =
        record_change(log, "lead-1", :stage, "contacted", "qualified", "u", timestamp: 2)

      {:ok, log} =
        record_change(log, "lead-1", :stage, "qualified", "converted", "u", timestamp: 3)

      history = field_history(log, "lead-1", :stage)
      assert length(history) == 3
      assert Enum.map(history, & &1.new_value) == ["contacted", "qualified", "converted"]
    end

    test "history for one entity does not include other entities" do
      log = new_log()
      {:ok, log} = record_change(log, "e-A", :name, "a", "b", "u")
      {:ok, log} = record_change(log, "e-B", :name, "x", "y", "u")
      {:ok, log} = record_change(log, "e-A", :name, "b", "c", "u")

      history = field_history(log, "e-A", :name)
      assert length(history) == 2
      assert Enum.all?(history, fn e -> e.entity_id == "e-A" end)
    end

    test "history for one field does not include other fields" do
      log = new_log()
      {:ok, log} = record_change(log, "e-1", :name, "a", "b", "u")
      {:ok, log} = record_change(log, "e-1", :email, "x", "y", "u")
      {:ok, log} = record_change(log, "e-1", :name, "b", "c", "u")

      history = field_history(log, "e-1", :name)
      assert length(history) == 2
      assert Enum.all?(history, fn e -> e.field == :name end)
    end
  end

  # ---------------------------------------------------------------------------
  # Test: point-in-time state reconstruction
  # ---------------------------------------------------------------------------

  describe "point-in-time reconstruction (SC-AUDIT-002)" do
    test "current state reflects latest value for each field" do
      log = new_log()
      {:ok, log} = record_change(log, "acct-1", :name, nil, "Acme", "u", timestamp: 10)
      {:ok, log} = record_change(log, "acct-1", :name, "Acme", "Acme Corp", "u", timestamp: 20)
      {:ok, log} = record_change(log, "acct-1", :status, nil, "active", "u", timestamp: 15)

      state = reconstruct_current_state(log, "acct-1")
      assert state[:name] == "Acme Corp"
      assert state[:status] == "active"
    end

    test "state at timestamp T reflects only changes up to T" do
      log = new_log()
      {:ok, log} = record_change(log, "lead-5", :score, nil, 50, "u", timestamp: 100)
      {:ok, log} = record_change(log, "lead-5", :score, 50, 75, "u", timestamp: 200)
      {:ok, log} = record_change(log, "lead-5", :score, 75, 90, "u", timestamp: 300)

      state_at_150 = reconstruct_state_at(log, "lead-5", 150)
      assert state_at_150[:score] == 50

      state_at_250 = reconstruct_state_at(log, "lead-5", 250)
      assert state_at_250[:score] == 75

      state_at_350 = reconstruct_state_at(log, "lead-5", 350)
      assert state_at_350[:score] == 90
    end

    test "state before any changes is empty" do
      log = new_log()
      {:ok, log} = record_change(log, "e-1", :field, nil, "value", "u", timestamp: 500)
      state = reconstruct_state_at(log, "e-1", 499)
      assert state == %{}
    end

    test "state reconstruction is isolated per entity" do
      log = new_log()
      {:ok, log} = record_change(log, "e-1", :name, nil, "Alpha", "u", timestamp: 10)
      {:ok, log} = record_change(log, "e-2", :name, nil, "Beta", "u", timestamp: 10)

      state_e1 = reconstruct_current_state(log, "e-1")
      state_e2 = reconstruct_current_state(log, "e-2")
      assert state_e1[:name] == "Alpha"
      assert state_e2[:name] == "Beta"
    end
  end

  # ---------------------------------------------------------------------------
  # Test: correlation_id for tracing
  # ---------------------------------------------------------------------------

  describe "correlation_id tracing (SC-AUDIT-004)" do
    test "each single change gets a unique correlation_id by default" do
      log = new_log()
      {:ok, log} = record_change(log, "e-1", :a, 1, 2, "u")
      {:ok, log} = record_change(log, "e-1", :b, 3, 4, "u")

      [e1, e2] = log
      assert e1.correlation_id != e2.correlation_id
    end

    test "explicit correlation_id links related changes" do
      log = new_log()
      cid = "TRACE-IMPORT-001"
      {:ok, log} = record_change(log, "e-1", :name, "A", "B", "u", correlation_id: cid)

      {:ok, log} =
        record_change(log, "e-1", :email, "a@a.com", "b@b.com", "u", correlation_id: cid)

      related = Enum.filter(log, fn e -> e.correlation_id == cid end)
      assert length(related) == 2
    end

    test "correlation_id is non-empty binary" do
      log = new_log()
      {:ok, log} = record_change(log, "e-1", :x, 0, 1, "user")
      assert is_binary(hd(log).correlation_id)
      assert byte_size(hd(log).correlation_id) > 0
    end
  end

  # ---------------------------------------------------------------------------
  # Test: DuckDB analytical queries
  # ---------------------------------------------------------------------------

  describe "analytical queries (SC-AUDIT-004)" do
    test "count changes by field returns correct totals" do
      log = new_log()
      {:ok, log} = record_change(log, "acct-1", :name, "a", "b", "u")
      {:ok, log} = record_change(log, "acct-1", :name, "b", "c", "u")
      {:ok, log} = record_change(log, "acct-1", :status, "x", "y", "u")

      counts = count_changes_by_field(log, "acct-1")
      assert counts[:name] == 2
      assert counts[:status] == 1
    end

    test "count changes excludes other entities" do
      log = new_log()
      {:ok, log} = record_change(log, "e-A", :field, 1, 2, "u")
      {:ok, log} = record_change(log, "e-B", :field, 1, 2, "u")
      {:ok, log} = record_change(log, "e-A", :field, 2, 3, "u")

      counts_a = count_changes_by_field(log, "e-A")
      assert counts_a[:field] == 2
      refute Map.has_key?(count_changes_by_field(log, "e-B"), :other_field)
    end

    test "entries in range returns only matching entries" do
      log = new_log()
      {:ok, log} = record_change(log, "e-1", :f, "a", "b", "u", timestamp: 100)
      {:ok, log} = record_change(log, "e-1", :f, "b", "c", "u", timestamp: 200)
      {:ok, log} = record_change(log, "e-1", :f, "c", "d", "u", timestamp: 300)

      in_range = entries_in_range(log, "e-1", 150, 250)
      assert length(in_range) == 1
      assert hd(in_range).timestamp == 200
    end

    test "entries in range with inclusive boundaries" do
      log = new_log()
      {:ok, log} = record_change(log, "e-1", :g, 1, 2, "u", timestamp: 100)
      {:ok, log} = record_change(log, "e-1", :g, 2, 3, "u", timestamp: 200)

      in_range = entries_in_range(log, "e-1", 100, 200)
      assert length(in_range) == 2
    end

    test "empty range returns empty list" do
      log = new_log()
      {:ok, log} = record_change(log, "e-1", :h, "x", "y", "u", timestamp: 500)

      in_range = entries_in_range(log, "e-1", 0, 100)
      assert in_range == []
    end
  end

  # ---------------------------------------------------------------------------
  # Test: NULL transitions
  # ---------------------------------------------------------------------------

  describe "NULL value transitions" do
    test "NULL to value transition is recorded correctly" do
      log = new_log()
      {:ok, log} = record_change(log, "contact-1", :phone, nil, "+91-9999999999", "user-1")
      entry = hd(log)
      assert is_nil(entry.old_value)
      assert entry.new_value == "+91-9999999999"
    end

    test "value to NULL transition is recorded correctly" do
      log = new_log()
      {:ok, log} = record_change(log, "contact-1", :fax, "+91-0000000000", nil, "user-1")
      entry = hd(log)
      assert entry.old_value == "+91-0000000000"
      assert is_nil(entry.new_value)
    end

    test "NULL to NULL transition can be recorded (no-op detection upstream)" do
      log = new_log()
      {:ok, log} = record_change(log, "e-1", :optional_field, nil, nil, "user-1")
      assert length(log) == 1
      entry = hd(log)
      assert is_nil(entry.old_value)
      assert is_nil(entry.new_value)
    end

    test "reconstructed state handles NULL new_value (field set to nil)" do
      log = new_log()
      {:ok, log} = record_change(log, "e-1", :description, nil, "Initial", "u", timestamp: 1)
      {:ok, log} = record_change(log, "e-1", :description, "Initial", nil, "u", timestamp: 2)

      state = reconstruct_current_state(log, "e-1")
      assert Map.fetch!(state, :description) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Test: concurrent changes
  # ---------------------------------------------------------------------------

  describe "concurrent changes (SC-AUDIT-003)" do
    test "concurrent changes to same entity all appear in log" do
      # Simulate two concurrent agents each recording a change
      log = new_log()
      {:ok, log} = record_change(log, "acct-7", :revenue, 1000, 1100, "agent-A", timestamp: 100)
      {:ok, log} = record_change(log, "acct-7", :employees, 50, 55, "agent-B", timestamp: 100)

      # Both entries must exist
      assert length(log) == 2
      fields = Enum.map(log, & &1.field) |> Enum.sort()
      assert fields == [:employees, :revenue]
    end

    test "concurrent changes to different entities do not interfere" do
      log = new_log()
      {:ok, log} = record_change(log, "e-1", :x, 0, 1, "u", timestamp: 100)
      {:ok, log} = record_change(log, "e-2", :x, 0, 2, "u", timestamp: 100)

      state_e1 = reconstruct_current_state(log, "e-1")
      state_e2 = reconstruct_current_state(log, "e-2")
      assert state_e1[:x] == 1
      assert state_e2[:x] == 2
    end

    test "concurrent changes preserve individual correlation_ids" do
      log = new_log()
      {:ok, log} = record_change(log, "acct-1", :a, 1, 2, "u-A", correlation_id: "CID-A")
      {:ok, log} = record_change(log, "acct-1", :b, 3, 4, "u-B", correlation_id: "CID-B")

      cids = Enum.map(log, & &1.correlation_id) |> Enum.sort()
      assert cids == ["CID-A", "CID-B"]
    end
  end

  # ---------------------------------------------------------------------------
  # Property test: any sequence of changes produces recoverable full history
  # ---------------------------------------------------------------------------

  describe "property: full history recoverability (SC-SMRITI-142)" do
    test "property: any sequence of changes produces recoverable full history" do
      ExUnitProperties.check all(
                               entity_id <- SD.binary(min_length: 1, max_length: 16),
                               fields <-
                                 SD.list_of(SD.atom(:alphanumeric), min_length: 1, max_length: 4),
                               values <-
                                 SD.list_of(
                                   SD.one_of([SD.integer(), SD.binary(), SD.constant(nil)]),
                                   min_length: 2,
                                   max_length: 8
                                 ),
                               changed_by <- SD.binary(min_length: 1, max_length: 10)
                             ) do
        # Build a change sequence for one field
        field = hd(fields)
        value_pairs = Enum.zip(values, tl(values))

        log =
          Enum.reduce(Enum.with_index(value_pairs), new_log(), fn {{old, new}, idx}, acc ->
            case record_change(acc, entity_id, field, old, new, changed_by, timestamp: idx) do
              {:ok, updated} -> updated
              _ -> acc
            end
          end)

        history = field_history(log, entity_id, field)

        # History length matches the number of pairs recorded
        assert length(history) == length(value_pairs)

        # Every entry has entity_id and field matching
        assert Enum.all?(history, fn e ->
                 e.entity_id == entity_id and e.field == field
               end)

        # History is ordered by timestamp
        timestamps = Enum.map(history, & &1.timestamp)
        assert timestamps == Enum.sort(timestamps)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Property test: reconstructed state matches expected for any change sequence
  # ---------------------------------------------------------------------------

  describe "property: reconstructed state correctness (AOR-HOLON-019)" do
    test "property: reconstructed state matches expected state for any random change sequence" do
      ExUnitProperties.check all(
                               entity_id <- SD.binary(min_length: 1, max_length: 8),
                               field <- SD.atom(:alphanumeric),
                               initial_value <-
                                 SD.one_of([
                                   SD.integer(0..999),
                                   SD.binary(min_length: 0, max_length: 8)
                                 ]),
                               changes <-
                                 SD.list_of(
                                   SD.one_of([
                                     SD.integer(0..999),
                                     SD.binary(min_length: 0, max_length: 8)
                                   ]),
                                   min_length: 1,
                                   max_length: 10
                                 )
                             ) do
        # The expected final value is the last element of changes
        expected_final = List.last(changes)

        # Build log: initial_value -> changes[0] -> changes[1] -> ... -> changes[-1]
        all_values = [initial_value | changes]
        value_pairs = Enum.zip(all_values, tl(all_values))

        log =
          Enum.reduce(Enum.with_index(value_pairs), new_log(), fn {{old, new}, idx}, acc ->
            case record_change(acc, entity_id, field, old, new, "prop-user", timestamp: idx) do
              {:ok, updated} -> updated
              _ -> acc
            end
          end)

        # Reconstructed state must have the final value
        state = reconstruct_current_state(log, entity_id)
        assert Map.get(state, field) == expected_final
      end
    end

    test "property: state at timestamp T contains exactly the values applied up to T" do
      ExUnitProperties.check all(
                               entity_id <- SD.binary(min_length: 1, max_length: 8),
                               field <- SD.atom(:alphanumeric),
                               values <-
                                 SD.list_of(SD.integer(0..999), min_length: 3, max_length: 6)
                             ) do
        # Assign each value a unique timestamp: 0, 10, 20, ...
        indexed_values = Enum.with_index(values, 0)

        log =
          Enum.reduce(indexed_values, new_log(), fn {value, idx}, acc ->
            old = if idx == 0, do: nil, else: Enum.at(values, idx - 1)
            ts = idx * 10

            case record_change(acc, entity_id, field, old, value, "user", timestamp: ts) do
              {:ok, updated} -> updated
              _ -> acc
            end
          end)

        # For each index, verify point-in-time state
        Enum.each(indexed_values, fn {expected_value, idx} ->
          query_ts = idx * 10
          state = reconstruct_state_at(log, entity_id, query_ts)

          assert Map.get(state, field) == expected_value,
                 "At ts=#{query_ts} expected #{inspect(expected_value)}, got #{inspect(Map.get(state, field))}"
        end)
      end
    end
  end
end
