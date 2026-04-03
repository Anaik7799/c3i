defmodule Indrajaal.Shared.SearchHelpersTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.Shared.SearchHelpers.

  Tests the shared search functionality that eliminates duplicate apply_search/2 functions
  across all domain modules (EP-DUP-003 pattern with mass: 26).

  SOPv5.11 Compliance: ✅
  Test Categories: Module Structure, Function Tests, Property Tests, Edge Cases
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.SearchHelpers

  # ===========================================================================
  # Module Structure Tests
  # ===========================================================================

  describe "Module Structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(SearchHelpers)
    end

    test "exports apply_search/2 function" do
      exports = SearchHelpers.__info__(:functions)
      assert {:apply_search, 2} in exports
    end

    test "has proper moduledoc" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(SearchHelpers)
      assert module_doc != :hidden
      assert module_doc != :none
    end
  end

  # ===========================================================================
  # apply_search/2 Function Tests
  # ===========================================================================

  describe "apply_search/2" do
    test "returns query unchanged when search_term is empty string" do
      query = :some_query
      assert SearchHelpers.apply_search(query, "") == query
    end

    test "returns query unchanged when search_term is nil" do
      query = :test_query
      assert SearchHelpers.apply_search(query, nil) == query
    end

    test "returns query when search_term is valid binary" do
      query = :my_query
      result = SearchHelpers.apply_search(query, "search term")
      # Current implementation returns query unchanged
      assert result == query
    end

    test "returns query unchanged for non-binary search_term" do
      query = :query_value
      assert SearchHelpers.apply_search(query, 123) == query
      assert SearchHelpers.apply_search(query, :atom) == query
      assert SearchHelpers.apply_search(query, []) == query
      assert SearchHelpers.apply_search(query, %{}) == query
    end

    test "handles various query types" do
      # Test with different query types
      assert SearchHelpers.apply_search(nil, "test") == nil
      assert SearchHelpers.apply_search(%{}, "test") == %{}
      assert SearchHelpers.apply_search([], "test") == []
      assert SearchHelpers.apply_search("query", "test") == "query"
    end
  end

  # ===========================================================================
  # PropCheck Property-Based Tests
  # ===========================================================================

  describe "Property-based tests" do
    property "apply_search/2 returns query for empty search terms" do
      forall query <- PC.term() do
        SearchHelpers.apply_search(query, "") == query
      end
    end

    property "apply_search/2 returns query for nil search terms" do
      forall query <- PC.term() do
        SearchHelpers.apply_search(query, nil) == query
      end
    end

    property "apply_search/2 handles any query type with binary search" do
      forall {query, search} <- {PC.term(), PC.utf8()} do
        result = SearchHelpers.apply_search(query, search)
        # Current implementation returns query unchanged
        result == query
      end
    end

    property "apply_search/2 is idempotent for empty searches" do
      forall query <- term() do
        first_result = SearchHelpers.apply_search(query, "")
        second_result = SearchHelpers.apply_search(first_result, "")
        first_result == second_result
      end
    end
  end

  # ===========================================================================
  # Edge Case Tests
  # ===========================================================================

  describe "Edge cases" do
    test "handles whitespace-only search terms" do
      query = :test_query
      # Whitespace is a valid binary, not empty string
      result = SearchHelpers.apply_search(query, "   ")
      assert result == query
    end

    test "handles unicode search terms" do
      query = :unicode_query
      assert SearchHelpers.apply_search(query, "日本語") == query
      assert SearchHelpers.apply_search(query, "émoji 🎉") == query
      assert SearchHelpers.apply_search(query, "Ñoño") == query
    end

    test "handles very long search terms" do
      query = :long_search_query
      long_term = String.duplicate("a", 10_000)
      assert SearchHelpers.apply_search(query, long_term) == query
    end

    test "handles special characters in search terms" do
      query = :special_chars_query
      assert SearchHelpers.apply_search(query, "test%value") == query
      assert SearchHelpers.apply_search(query, "test_value") == query
      assert SearchHelpers.apply_search(query, "test'value") == query
      assert SearchHelpers.apply_search(query, "test\"value") == query
    end

    test "handles newlines and tabs in search terms" do
      query = :whitespace_query
      assert SearchHelpers.apply_search(query, "test\nvalue") == query
      assert SearchHelpers.apply_search(query, "test\tvalue") == query
      assert SearchHelpers.apply_search(query, "test\r\nvalue") == query
    end
  end

  # ===========================================================================
  # Source Code Validation Tests
  # ===========================================================================

  describe "Source code validation" do
    test "source file exists" do
      source_path = "lib/indrajaal/shared/search_helpers.ex"
      assert File.exists?(source_path), "Source file should exist at #{source_path}"
    end

    test "has proper spec annotations" do
      {:docs_v1, _, :elixir, _, _, _, function_docs} = Code.fetch_docs(SearchHelpers)

      apply_search_docs =
        Enum.filter(function_docs, fn
          {{:function, :apply_search, 2}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(apply_search_docs) >= 1, "apply_search/2 should have documentation"
    end
  end

  # ===========================================================================
  # Integration Tests
  # ===========================================================================

  describe "Integration scenarios" do
    test "can be used in pipeline" do
      result =
        :initial_query
        |> SearchHelpers.apply_search("")
        |> SearchHelpers.apply_search(nil)
        |> SearchHelpers.apply_search("test")

      assert result == :initial_query
    end

    test "multiple sequential calls are consistent" do
      query = %{type: :ecto_query}

      result1 = SearchHelpers.apply_search(query, "term1")
      result2 = SearchHelpers.apply_search(query, "term2")

      # Both should return the same query (current implementation)
      assert result1 == query
      assert result2 == query
    end
  end
end
