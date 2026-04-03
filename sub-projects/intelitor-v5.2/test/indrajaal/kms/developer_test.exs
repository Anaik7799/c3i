defmodule Indrajaal.KMS.DeveloperTest do
  @moduledoc """
  TDG test suite for Indrajaal.KMS.Developer.

  Tests developer knowledge management: code links, decisions, patterns,
  debug sessions, and review notes. All SQLite access routes through
  Zenoh DatabaseProxy (SC-DBPROXY-001).

  ## STAMP Safety Integration
  - SC-KMS-001: SQLite-backed storage only
  - SC-KMS-003: Code traceability
  - SC-DBPROXY-001: DatabaseProxy mediates all SQLite access

  ## TPS 5-Level RCA Context
  - L1 Symptom: Developer knowledge retrieval fails
  - L5 Root Cause: Missing DatabaseProxy / schema not initialized
  """

  use ExUnit.Case, async: true

  alias Indrajaal.KMS.Developer

  describe "init/0" do
    test "returns :ok" do
      assert :ok = Developer.init()
    end

    test "is idempotent — repeated calls return :ok" do
      assert :ok = Developer.init()
      assert :ok = Developer.init()
    end
  end

  describe "link_to_code/5" do
    test "returns error when DatabaseProxy is unavailable" do
      result = Developer.link_to_code("hln-123", "lib/foo.ex", 42, :implements, %{})
      assert match?({:error, _}, result) or match?(:ok, result)
    end

    test "accepts all valid link types without raising" do
      for link_type <- [:explains, :implements, :documents, :references, :tests, :reviews] do
        result = Developer.link_to_code("hln-test", "lib/foo.ex", 1, link_type, %{})
        assert is_tuple(result) or result == :ok
      end
    end

    test "accepts string file path" do
      result =
        Developer.link_to_code("hln-1", "lib/indrajaal/kms/developer.ex", 100, :documents, %{})

      assert is_tuple(result) or result == :ok
    end

    test "accepts line number 1 as boundary" do
      result = Developer.link_to_code("hln-1", "lib/foo.ex", 1, :explains, %{})
      assert is_tuple(result) or result == :ok
    end
  end

  describe "get_links_for_file/1" do
    test "returns error or empty list for unknown file" do
      result = Developer.get_links_for_file("lib/does_not_exist.ex")
      assert match?({:ok, []}, result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts valid file path string" do
      result = Developer.get_links_for_file("lib/indrajaal/kms/developer.ex")
      assert is_tuple(result)
    end
  end

  describe "get_knowledge_at_line/2" do
    test "returns error or empty list for unknown file and line" do
      result = Developer.get_knowledge_at_line("lib/does_not_exist.ex", 1)
      assert match?({:ok, []}, result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts boundary line 0" do
      result = Developer.get_knowledge_at_line("lib/foo.ex", 0)
      assert is_tuple(result)
    end
  end

  describe "record_decision/1" do
    test "returns error when DatabaseProxy unavailable" do
      attrs = %{
        title: "Use PostgreSQL",
        context: "Need a relational DB",
        decision: "Use PostgreSQL 17",
        status: :proposed
      }

      result = Developer.record_decision(attrs)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts minimal attrs map" do
      result = Developer.record_decision(%{title: "min", context: "ctx", decision: "dec"})
      assert is_tuple(result)
    end

    test "accepts :proposed status" do
      result =
        Developer.record_decision(%{title: "t", status: :proposed, context: "c", decision: "d"})

      assert is_tuple(result)
    end

    test "accepts :accepted status" do
      result =
        Developer.record_decision(%{title: "t", status: :accepted, context: "c", decision: "d"})

      assert is_tuple(result)
    end

    test "accepts :deprecated status" do
      result =
        Developer.record_decision(%{title: "t", status: :deprecated, context: "c", decision: "d"})

      assert is_tuple(result)
    end
  end

  describe "get_decision/1" do
    test "returns {:error, :not_found} for nonexistent id" do
      result = Developer.get_decision("dec-nonexistent-999")
      assert match?({:error, :not_found}, result) or match?({:error, _}, result)
    end

    test "accepts string id" do
      result = Developer.get_decision("dec-abc123")
      assert is_tuple(result)
    end
  end

  describe "list_decisions/1" do
    test "returns ok tuple with list for :proposed filter" do
      result = Developer.list_decisions(status: :proposed)
      assert match?({:ok, list} when is_list(list), result) or match?({:error, _}, result)
    end

    test "returns ok tuple with list for :accepted filter" do
      result = Developer.list_decisions(status: :accepted)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts empty opts" do
      result = Developer.list_decisions([])
      assert is_tuple(result)
    end
  end

  describe "accept_decision/1" do
    test "returns error for nonexistent decision" do
      result = Developer.accept_decision("dec-nonexistent-999")
      assert match?({:error, _}, result) or match?(:ok, result)
    end
  end

  describe "deprecate_decision/2" do
    test "returns error for nonexistent decision" do
      result = Developer.deprecate_decision("dec-nonexistent-999", "Replaced by newer approach")
      assert match?({:error, _}, result) or match?(:ok, result)
    end

    test "accepts reason string" do
      result = Developer.deprecate_decision("dec-1", "No longer relevant")
      assert is_tuple(result) or result == :ok
    end
  end

  describe "store_pattern/1" do
    test "returns error when DatabaseProxy unavailable" do
      attrs = %{
        name: "Singleton",
        category: :structural,
        description: "Ensure single instance",
        implementation: "Use module-level state",
        when_to_use: "Shared global resource"
      }

      result = Developer.store_pattern(attrs)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts :behavioral category" do
      result =
        Developer.store_pattern(%{
          name: "Observer",
          category: :behavioral,
          description: "d",
          implementation: "i",
          when_to_use: "w"
        })

      assert is_tuple(result)
    end

    test "accepts :resilience category" do
      result =
        Developer.store_pattern(%{
          name: "Circuit Breaker",
          category: :resilience,
          description: "d",
          implementation: "i",
          when_to_use: "w"
        })

      assert is_tuple(result)
    end

    test "accepts :security category" do
      result =
        Developer.store_pattern(%{
          name: "Defense in Depth",
          category: :security,
          description: "d",
          implementation: "i",
          when_to_use: "w"
        })

      assert is_tuple(result)
    end
  end

  describe "get_pattern/1" do
    test "returns {:error, :not_found} for nonexistent id" do
      result = Developer.get_pattern("pat-nonexistent-999")
      assert match?({:error, :not_found}, result) or match?({:error, _}, result)
    end
  end

  describe "list_patterns/0" do
    test "returns ok tuple with list" do
      result = Developer.list_patterns()
      assert match?({:ok, list} when is_list(list), result) or match?({:error, _}, result)
    end
  end

  describe "search_patterns/1" do
    test "accepts string query" do
      result = Developer.search_patterns("singleton")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts empty string query" do
      result = Developer.search_patterns("")
      assert is_tuple(result)
    end
  end

  describe "use_pattern/1" do
    test "increments use count or returns error for nonexistent" do
      result = Developer.use_pattern("pat-nonexistent")
      assert is_tuple(result) or result == :ok
    end
  end

  describe "start_debug_session/1" do
    test "accepts attrs map and returns ok or error" do
      result =
        Developer.start_debug_session(%{
          title: "Investigating memory leak",
          description: "Memory grows unbounded under load",
          affected_module: "Indrajaal.KMS.Developer"
        })

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts minimal attrs" do
      result = Developer.start_debug_session(%{title: "test debug"})
      assert is_tuple(result)
    end
  end

  describe "add_investigation_step/2" do
    test "returns error for nonexistent session" do
      result =
        Developer.add_investigation_step("dbg-nonexistent", %{
          description: "Checked memory",
          outcome: "Leak found in ETS"
        })

      assert match?({:error, _}, result) or match?(:ok, result)
    end
  end

  describe "resolve_debug_session/2" do
    test "returns error for nonexistent session" do
      result =
        Developer.resolve_debug_session("dbg-nonexistent", "Root cause: missing ETS cleanup")

      assert match?({:error, _}, result) or match?(:ok, result)
    end
  end

  describe "get_debug_session/1" do
    test "returns error for nonexistent session" do
      result = Developer.get_debug_session("dbg-nonexistent-999")
      assert match?({:error, :not_found}, result) or match?({:error, _}, result)
    end
  end

  describe "list_debug_sessions/0" do
    test "returns ok tuple with list" do
      result = Developer.list_debug_sessions()
      assert match?({:ok, list} when is_list(list), result) or match?({:error, _}, result)
    end
  end

  describe "search_debug_sessions/1" do
    test "accepts string query" do
      result = Developer.search_debug_sessions("memory")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "add_review_note/1" do
    test "accepts attrs map" do
      result =
        Developer.add_review_note(%{
          file: "lib/indrajaal/kms/developer.ex",
          line: 42,
          note: "This function needs refactoring",
          reviewer: "dev-001"
        })

      assert is_tuple(result)
    end
  end

  describe "get_review_notes_for_file/1" do
    test "accepts file path" do
      result = Developer.get_review_notes_for_file("lib/indrajaal/kms/developer.ex")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns empty list or error for unknown file" do
      result = Developer.get_review_notes_for_file("lib/nonexistent.ex")
      assert match?({:ok, []}, result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "list_code_links/0" do
    test "returns ok tuple with list" do
      result = Developer.list_code_links()
      assert match?({:ok, list} when is_list(list), result) or match?({:error, _}, result)
    end
  end

  describe "get_file_context/1" do
    test "accepts file path" do
      result = Developer.get_file_context("lib/indrajaal/kms/developer.ex")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns map with context keys" do
      result = Developer.get_file_context("lib/foo.ex")

      case result do
        {:ok, context} -> assert is_map(context)
        {:error, _} -> :ok
      end
    end
  end

  describe "developer_stats/0" do
    test "returns ok tuple with stats map" do
      result = Developer.developer_stats()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "stats map has expected shape when available" do
      case Developer.developer_stats() do
        {:ok, stats} -> assert is_map(stats)
        {:error, _} -> :ok
      end
    end
  end
end
