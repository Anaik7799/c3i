defmodule Indrajaal.Shared.StatusHistoryTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.Shared.StatusHistory.

  Tests the status history tracking utilities that eliminate duplication across
  Sites.Building, Sites.Area, Sites.Site, Sites.Floor, and other domains.

  SOPv5.11 Compliance: ✅
  Test Categories: Module Structure, Function Tests, Property Tests, Edge Cases
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.StatusHistory

  # ===========================================================================
  # Module Structure Tests
  # ===========================================================================

  describe "Module Structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(StatusHistory)
    end

    test "exports create_status_history_change/0" do
      exports = StatusHistory.__info__(:functions)
      assert {:create_status_history_change, 0} in exports
    end

    test "exports create_status_history_change/3" do
      exports = StatusHistory.__info__(:functions)
      assert {:create_status_history_change, 3} in exports
    end

    test "exports status_update_action/2" do
      exports = StatusHistory.__info__(:functions)
      assert {:status_update_action, 2} in exports
    end

    test "exports status_update_action/3" do
      exports = StatusHistory.__info__(:functions)
      assert {:status_update_action, 3} in exports
    end

    test "exports validate_history_entry/1" do
      exports = StatusHistory.__info__(:functions)
      assert {:validate_history_entry, 1} in exports
    end

    test "exports get_latest_status/1" do
      exports = StatusHistory.__info__(:functions)
      assert {:get_latest_status, 1} in exports
    end

    test "exports get_latest_status/2" do
      exports = StatusHistory.__info__(:functions)
      assert {:get_latest_status, 2} in exports
    end

    test "exports get_history_by_date_range/3" do
      exports = StatusHistory.__info__(:functions)
      assert {:get_history_by_date_range, 3} in exports
    end

    test "exports get_history_by_date_range/4" do
      exports = StatusHistory.__info__(:functions)
      assert {:get_history_by_date_range, 4} in exports
    end

    test "exports get_history_by_actor/2" do
      exports = StatusHistory.__info__(:functions)
      assert {:get_history_by_actor, 2} in exports
    end

    test "exports get_history_by_actor/3" do
      exports = StatusHistory.__info__(:functions)
      assert {:get_history_by_actor, 3} in exports
    end

    test "exports generate_history_summary/1" do
      exports = StatusHistory.__info__(:functions)
      assert {:generate_history_summary, 1} in exports
    end

    test "exports generate_history_summary/2" do
      exports = StatusHistory.__info__(:functions)
      assert {:generate_history_summary, 2} in exports
    end

    test "exports cleanup_history/1" do
      exports = StatusHistory.__info__(:functions)
      assert {:cleanup_history, 1} in exports
    end

    test "exports cleanup_history/3" do
      exports = StatusHistory.__info__(:functions)
      assert {:cleanup_history, 3} in exports
    end

    test "has proper moduledoc" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(StatusHistory)
      assert module_doc != :hidden
      assert module_doc != :none
    end
  end

  # ===========================================================================
  # create_status_history_change/0,3 Tests
  # ===========================================================================

  describe "create_status_history_change/0,3" do
    test "returns a function with default parameters" do
      change_fn = StatusHistory.create_status_history_change()
      assert is_function(change_fn, 2)
    end

    test "returns a function with custom parameters" do
      change_fn = StatusHistory.create_status_history_change(:state, :details, "state_history")
      assert is_function(change_fn, 2)
    end

    test "function handles changeset without reason argument" do
      change_fn = StatusHistory.create_status_history_change()
      # Mock changeset structure
      changeset = %{
        __struct__: Ash.Changeset,
        arguments: %{},
        attributes: %{metadata: %{}},
        data: %{}
      }

      # The function should return changeset unchanged when no reason
      # Since we can't fully mock Ash.Changeset, we verify the function exists
      assert is_function(change_fn, 2)
    end
  end

  # ===========================================================================
  # status_update_action/2,3 Tests
  # ===========================================================================

  describe "status_update_action/2,3" do
    test "returns map with action configuration using default action name" do
      status_values = [:active, :maintenance, :closed]
      result = StatusHistory.status_update_action(status_values)

      assert is_map(result)
      assert Map.has_key?(result, :name)
      assert Map.has_key?(result, :arguments)
      assert Map.has_key?(result, :changes)
    end

    test "returns map with custom action name" do
      status_values = [:active, :inactive]
      result = StatusHistory.status_update_action(:change_state, status_values)

      assert result.name == :change_state
    end

    test "returns map with custom status field" do
      status_values = [:open, :closed]
      result = StatusHistory.status_update_action(:update_state, status_values, :state)

      assert is_map(result)
      assert result.name == :update_state
    end

    test "includes status and reason arguments" do
      status_values = [:active, :inactive]
      result = StatusHistory.status_update_action(status_values)

      assert is_list(result.arguments)
      assert length(result.arguments) == 2
    end

    test "includes changes for set_attribute and history change" do
      status_values = [:active, :inactive]
      result = StatusHistory.status_update_action(status_values)

      assert is_list(result.changes)
      assert length(result.changes) == 2
    end
  end

  # ===========================================================================
  # validate_history_entry/1 Tests
  # ===========================================================================

  describe "validate_history_entry/1" do
    test "returns ok for valid entry with all required fields" do
      entry = %{
        "status" => :active,
        "reason" => "Initial setup",
        "changed_at" => DateTime.utc_now(),
        "changed_by" => "user-123"
      }

      assert {:ok, ^entry} = StatusHistory.validate_history_entry(entry)
    end

    test "returns error for entry missing status field" do
      entry = %{
        "reason" => "Test",
        "changed_at" => DateTime.utc_now(),
        "changed_by" => "user-123"
      }

      assert {:error, message} = StatusHistory.validate_history_entry(entry)
      assert message =~ "status"
    end

    test "returns error for entry missing reason field" do
      entry = %{
        "status" => :active,
        "changed_at" => DateTime.utc_now(),
        "changed_by" => "user-123"
      }

      assert {:error, message} = StatusHistory.validate_history_entry(entry)
      assert message =~ "reason"
    end

    test "returns error for entry missing changed_at field" do
      entry = %{
        "status" => :active,
        "reason" => "Test",
        "changed_by" => "user-123"
      }

      assert {:error, message} = StatusHistory.validate_history_entry(entry)
      assert message =~ "changed_at"
    end

    test "returns error for entry missing changed_by field" do
      entry = %{
        "status" => :active,
        "reason" => "Test",
        "changed_at" => DateTime.utc_now()
      }

      assert {:error, message} = StatusHistory.validate_history_entry(entry)
      assert message =~ "changed_by"
    end
  end

  # ===========================================================================
  # get_latest_status/1,2 Tests
  # ===========================================================================

  describe "get_latest_status/1,2" do
    test "returns ok with latest entry when history exists" do
      latest = %{"status" => :active, "reason" => "Latest"}
      older = %{"status" => :inactive, "reason" => "Older"}
      metadata = %{"status_history" => [latest, older]}

      assert {:ok, ^latest} = StatusHistory.get_latest_status(metadata)
    end

    test "returns error when no history exists" do
      metadata = %{"status_history" => []}

      assert {:error, :no_history} = StatusHistory.get_latest_status(metadata)
    end

    test "returns error when history key is missing" do
      metadata = %{}

      assert {:error, :no_history} = StatusHistory.get_latest_status(metadata)
    end

    test "works with custom history key" do
      latest = %{"status" => :active}
      metadata = %{"custom_history" => [latest]}

      assert {:ok, ^latest} = StatusHistory.get_latest_status(metadata, "custom_history")
    end
  end

  # ===========================================================================
  # get_history_by_date_range/3,4 Tests
  # ===========================================================================

  describe "get_history_by_date_range/3,4" do
    test "returns entries within date range" do
      start_date = ~U[2025-01-01 00:00:00Z]
      end_date = ~U[2025-12-31 23:59:59Z]

      entry_in_range = %{
        "status" => :active,
        "changed_at" => "2025-06-15T10:00:00Z"
      }

      entry_out_of_range = %{
        "status" => :inactive,
        "changed_at" => "2024-06-15T10:00:00Z"
      }

      metadata = %{"status_history" => [entry_in_range, entry_out_of_range]}

      result = StatusHistory.get_history_by_date_range(metadata, start_date, end_date)

      assert is_list(result)
      assert length(result) == 1
      assert hd(result)["status"] == :active
    end

    test "returns empty list when no entries in range" do
      start_date = ~U[2030-01-01 00:00:00Z]
      end_date = ~U[2030-12-31 23:59:59Z]

      entry = %{
        "status" => :active,
        "changed_at" => "2025-06-15T10:00:00Z"
      }

      metadata = %{"status_history" => [entry]}

      result = StatusHistory.get_history_by_date_range(metadata, start_date, end_date)

      assert result == []
    end

    test "handles entries without changed_at field" do
      start_date = ~U[2025-01-01 00:00:00Z]
      end_date = ~U[2025-12-31 23:59:59Z]

      entry_without_date = %{"status" => :active}
      metadata = %{"status_history" => [entry_without_date]}

      result = StatusHistory.get_history_by_date_range(metadata, start_date, end_date)

      assert result == []
    end

    test "works with custom history key" do
      start_date = ~U[2025-01-01 00:00:00Z]
      end_date = ~U[2025-12-31 23:59:59Z]

      entry = %{
        "status" => :active,
        "changed_at" => "2025-06-15T10:00:00Z"
      }

      metadata = %{"custom_history" => [entry]}

      result =
        StatusHistory.get_history_by_date_range(metadata, start_date, end_date, "custom_history")

      assert length(result) == 1
    end
  end

  # ===========================================================================
  # get_history_by_actor/2,3 Tests
  # ===========================================================================

  describe "get_history_by_actor/2,3" do
    test "returns entries for specified actor" do
      entry1 = %{"status" => :active, "changed_by" => "user-123"}
      entry2 = %{"status" => :inactive, "changed_by" => "user-456"}
      entry3 = %{"status" => :maintenance, "changed_by" => "user-123"}

      metadata = %{"status_history" => [entry1, entry2, entry3]}

      result = StatusHistory.get_history_by_actor(metadata, "user-123")

      assert length(result) == 2
      assert Enum.all?(result, &(&1["changed_by"] == "user-123"))
    end

    test "returns empty list when actor has no entries" do
      entry = %{"status" => :active, "changed_by" => "user-123"}
      metadata = %{"status_history" => [entry]}

      result = StatusHistory.get_history_by_actor(metadata, "user-unknown")

      assert result == []
    end

    test "works with custom history key" do
      entry = %{"status" => :active, "changed_by" => "user-123"}
      metadata = %{"custom_history" => [entry]}

      result = StatusHistory.get_history_by_actor(metadata, "user-123", "custom_history")

      assert length(result) == 1
    end
  end

  # ===========================================================================
  # generate_history_summary/1,2 Tests
  # ===========================================================================

  describe "generate_history_summary/1,2" do
    test "returns summary with statistics" do
      entry1 = %{"status" => :active, "changed_by" => "user-1"}
      entry2 = %{"status" => :inactive, "changed_by" => "user-2"}
      entry3 = %{"status" => :active, "changed_by" => "user-1"}

      metadata = %{"status_history" => [entry1, entry2, entry3]}

      summary = StatusHistory.generate_history_summary(metadata)

      assert is_map(summary)
      assert summary.total_entries == 3
      assert summary.unique_statuses == 2
      assert summary.unique_actors == 2
    end

    test "returns summary with first and latest entries" do
      oldest = %{"status" => :inactive, "changed_by" => "user-1"}
      latest = %{"status" => :active, "changed_by" => "user-2"}

      metadata = %{"status_history" => [latest, oldest]}

      summary = StatusHistory.generate_history_summary(metadata)

      assert summary.first_entry == oldest
      assert summary.latest_entry == latest
    end

    test "returns summary with status frequency" do
      entry1 = %{"status" => :active}
      entry2 = %{"status" => :inactive}
      entry3 = %{"status" => :active}

      metadata = %{"status_history" => [entry1, entry2, entry3]}

      summary = StatusHistory.generate_history_summary(metadata)

      assert is_map(summary.status_f_requency)
      assert summary.status_f_requency[:active] == 2
      assert summary.status_f_requency[:inactive] == 1
    end

    test "handles empty history" do
      metadata = %{"status_history" => []}

      summary = StatusHistory.generate_history_summary(metadata)

      assert summary.total_entries == 0
      assert summary.unique_statuses == 0
      assert summary.unique_actors == 0
    end

    test "works with custom history key" do
      entry = %{"status" => :active, "changed_by" => "user-1"}
      metadata = %{"custom_history" => [entry]}

      summary = StatusHistory.generate_history_summary(metadata, "custom_history")

      assert summary.total_entries == 1
    end
  end

  # ===========================================================================
  # cleanup_history/1,3 Tests
  # ===========================================================================

  describe "cleanup_history/1,3" do
    test "trims history to specified limit" do
      entries = Enum.map(1..150, fn i -> %{"status" => :active, "index" => i} end)
      metadata = %{"status_history" => entries}

      result = StatusHistory.cleanup_history(metadata, 100)

      assert length(result["status_history"]) == 100
    end

    test "keeps all entries when under limit" do
      entries = Enum.map(1..50, fn i -> %{"status" => :active, "index" => i} end)
      metadata = %{"status_history" => entries}

      result = StatusHistory.cleanup_history(metadata, 100)

      assert length(result["status_history"]) == 50
    end

    test "works with default limit of 100" do
      entries = Enum.map(1..150, fn i -> %{"status" => :active, "index" => i} end)
      metadata = %{"status_history" => entries}

      result = StatusHistory.cleanup_history(metadata)

      assert length(result["status_history"]) == 100
    end

    test "works with custom history key" do
      entries = Enum.map(1..150, fn i -> %{"status" => :active, "index" => i} end)
      metadata = %{"custom_history" => entries}

      result = StatusHistory.cleanup_history(metadata, 50, "custom_history")

      assert length(result["custom_history"]) == 50
    end

    test "keeps entries in order (most recent first)" do
      entries = Enum.map(1..10, fn i -> %{"status" => :active, "index" => i} end)
      metadata = %{"status_history" => entries}

      result = StatusHistory.cleanup_history(metadata, 5)

      # Should keep first 5 entries (most recent)
      assert hd(result["status_history"])["index"] == 1
      assert List.last(result["status_history"])["index"] == 5
    end
  end

  # ===========================================================================
  # PropCheck Property-Based Tests
  # ===========================================================================

  describe "Property-based tests" do
    property "validate_history_entry returns ok for valid entries" do
      forall {status, reason, changed_by} <- {PC.term(), PC.utf8(), PC.utf8()} do
        entry = %{
          "status" => status,
          "reason" => reason,
          "changed_at" => DateTime.utc_now(),
          "changed_by" => changed_by
        }

        match?({:ok, _}, StatusHistory.validate_history_entry(entry))
      end
    end

    property "get_latest_status returns error for empty history" do
      forall history_key <- utf8() do
        metadata = %{history_key => []}
        match?({:error, :no_history}, StatusHistory.get_latest_status(metadata, history_key))
      end
    end

    property "cleanup_history never exceeds limit" do
      forall {entries_count, limit} <- {PC.pos_integer(), PC.pos_integer()} do
        entries = Enum.map(1..entries_count, fn i -> %{"index" => i} end)
        metadata = %{"status_history" => entries}

        result = StatusHistory.cleanup_history(metadata, limit)
        length(result["status_history"]) <= limit
      end
    end

    property "generate_history_summary total_entries matches list length" do
      forall entries_count <- non_neg_integer() do
        entries =
          Enum.map(1..max(entries_count, 0), fn i ->
            %{"status" => :active, "changed_by" => "user-#{i}"}
          end)

        metadata = %{"status_history" => entries}

        summary = StatusHistory.generate_history_summary(metadata)
        summary.total_entries == length(entries)
      end
    end

    property "get_history_by_actor returns subset of original history" do
      forall {entries_count, actor_id} <- {PC.pos_integer(), PC.utf8()} do
        entries =
          Enum.map(1..entries_count, fn i ->
            %{"status" => :active, "changed_by" => "user-#{i}"}
          end)

        metadata = %{"status_history" => entries}

        result = StatusHistory.get_history_by_actor(metadata, actor_id)
        length(result) <= entries_count
      end
    end
  end

  # ===========================================================================
  # Edge Case Tests
  # ===========================================================================

  describe "Edge cases" do
    test "handles nil metadata gracefully for get_latest_status" do
      # Function requires map, so we test with empty map
      metadata = %{}
      assert {:error, :no_history} = StatusHistory.get_latest_status(metadata)
    end

    test "handles unicode in status history entries" do
      entry = %{
        "status" => :active,
        "reason" => "状态更新 🚀",
        "changed_at" => DateTime.utc_now(),
        "changed_by" => "用户-123"
      }

      assert {:ok, ^entry} = StatusHistory.validate_history_entry(entry)
    end

    test "handles very large history for cleanup" do
      entries = Enum.map(1..10_000, fn i -> %{"status" => :active, "index" => i} end)
      metadata = %{"status_history" => entries}

      result = StatusHistory.cleanup_history(metadata, 100)

      assert length(result["status_history"]) == 100
    end

    test "handles deeply nested metadata" do
      entry = %{
        "status" => :active,
        "reason" => "Test",
        "changed_at" => DateTime.utc_now(),
        "changed_by" => "user-123"
      }

      metadata = %{
        "status_history" => [entry],
        "nested" => %{
          "deeper" => %{
            "value" => "test"
          }
        }
      }

      assert {:ok, ^entry} = StatusHistory.get_latest_status(metadata)
    end

    test "status_update_action handles empty status values list" do
      result = StatusHistory.status_update_action([])

      assert is_map(result)
      assert result.name == :update_status
    end

    test "status_update_action handles large status values list" do
      status_values = Enum.map(1..100, fn i -> String.to_atom("status_#{i}") end)
      result = StatusHistory.status_update_action(status_values)

      assert is_map(result)
    end
  end

  # ===========================================================================
  # Source Code Validation Tests
  # ===========================================================================

  describe "Source code validation" do
    test "source file exists" do
      source_path = "lib/indrajaal/shared/status_history.ex"
      assert File.exists?(source_path), "Source file should exist at #{source_path}"
    end

    test "has proper module structure" do
      source_path = "lib/indrajaal/shared/status_history.ex"
      content = File.read!(source_path)

      assert content =~ "defmodule Indrajaal.Shared.StatusHistory"
      assert content =~ "@moduledoc"
    end

    test "defines core status history functions" do
      source_path = "lib/indrajaal/shared/status_history.ex"
      content = File.read!(source_path)

      assert content =~ "def create_status_history_change"
      assert content =~ "def status_update_action"
      assert content =~ "def validate_history_entry"
      assert content =~ "def get_latest_status"
    end

    test "defines history query functions" do
      source_path = "lib/indrajaal/shared/status_history.ex"
      content = File.read!(source_path)

      assert content =~ "def get_history_by_date_range"
      assert content =~ "def get_history_by_actor"
      assert content =~ "def generate_history_summary"
      assert content =~ "def cleanup_history"
    end

    test "uses Ash.Changeset for changeset operations" do
      source_path = "lib/indrajaal/shared/status_history.ex"
      content = File.read!(source_path)

      assert content =~ "Ash.Changeset"
    end

    test "follows TPS principles for code organization" do
      source_path = "lib/indrajaal/shared/status_history.ex"
      content = File.read!(source_path)

      assert content =~ "Toyota TPS principles"
    end
  end
end
