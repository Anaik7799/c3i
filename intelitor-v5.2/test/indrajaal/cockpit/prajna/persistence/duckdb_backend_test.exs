defmodule Indrajaal.Cockpit.Prajna.Persistence.DuckdbBackendTest do
  @moduledoc """
  TDG tests for Indrajaal.Cockpit.Prajna.Persistence.DuckdbBackend.

  ## STAMP Safety Integration
  - SC-HOLON-001: State persists to SQLite/DuckDB only
  - SC-LED-001: Entries MUST be immutable

  ## TPS 5-Level RCA Context
  - L1 Symptom: Cockpit state not persisted
  - L5 Root Cause: DuckDB backend not writing records
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif

  alias Indrajaal.Cockpit.Prajna.Persistence.DuckdbBackend

  describe "append/1" do
    test "returns :ok for a map record" do
      record = %{type: :test, timestamp: DateTime.utc_now(), data: "sample"}
      assert :ok = DuckdbBackend.append(record)
    end

    test "returns :ok for an empty map" do
      assert :ok = DuckdbBackend.append(%{})
    end

    test "returns :ok for a record with nested data" do
      record = %{
        type: :block,
        payload: %{action: :update, value: 42},
        timestamp: DateTime.utc_now()
      }

      assert :ok = DuckdbBackend.append(record)
    end

    test "accepts arbitrary map keys" do
      record = %{foo: 1, bar: 2, baz: "hello"}
      assert :ok = DuckdbBackend.append(record)
    end
  end

  describe "read_all/0" do
    test "returns a list" do
      result = DuckdbBackend.read_all()
      assert is_list(result)
    end

    test "returns empty list when no records appended (stub)" do
      result = DuckdbBackend.read_all()
      assert result == []
    end
  end

  describe "function exports" do
    test "append/1 is exported" do
      assert function_exported?(DuckdbBackend, :append, 1)
    end

    test "read_all/0 is exported" do
      assert function_exported?(DuckdbBackend, :read_all, 0)
    end
  end
end
