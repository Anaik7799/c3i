defmodule Indrajaal.Cockpit.Prajna.Persistence.WalTest do
  @moduledoc """
  TDG tests for Indrajaal.Cockpit.Prajna.Persistence.Wal.

  ## STAMP Safety Integration
  - SC-HOLON-001: WAL mode for SQLite
  - SC-LED-003: Entry order MUST be preserved

  ## TPS 5-Level RCA Context
  - L1 Symptom: State mutations not logged
  - L5 Root Cause: WAL not receiving entries
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif

  alias Indrajaal.Cockpit.Prajna.Persistence.Wal

  describe "log/1" do
    test "returns :ok for a valid entry" do
      entry = %{type: :state_change, data: %{key: "value"}, timestamp: DateTime.utc_now()}
      assert :ok = Wal.log(entry)
    end

    test "returns :ok for an empty map" do
      assert :ok = Wal.log(%{})
    end

    test "returns :ok for an entry with atom keys" do
      assert :ok = Wal.log(%{action: :update, id: "abc123"})
    end

    test "returns :ok for string-keyed map" do
      assert :ok = Wal.log(%{"event" => "test", "version" => 1})
    end

    test "returns :ok for a list entry" do
      assert :ok = Wal.log(action: :write, payload: "data")
    end

    test "accepts any term as entry" do
      assert :ok = Wal.log(:arbitrary_atom)
    end
  end

  describe "function exports" do
    test "log/1 is exported" do
      assert function_exported?(Wal, :log, 1)
    end
  end
end
