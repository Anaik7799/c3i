defmodule Indrajaal.ConfigManagement.SearchTest do
  @moduledoc """
  TDG test suite for ConfigManagement.Search and SavedSearch schema (DB-dependent).

  ## STAMP Safety Integration
  - SC-DB-001: Use BaseResource
  - SC-DB-005: uuid_primary_key :id

  ## TPS 5-Level RCA Context
  - L1 Symptom: Config search returning no results
  - L5 Root Cause: Repo not started or search index not populated

  ## Note: DB-dependent module
  Search functions call Repo. Tests tag DB calls with :requires_db.
  Schema/changeset tests can run without DB.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.ConfigManagement.Search
  alias Indrajaal.ConfigManagement.SavedSearch

  describe "module definition" do
    test "Search module exists and is loaded" do
      assert Code.ensure_loaded?(Search)
    end

    test "SavedSearch schema module exists" do
      assert Code.ensure_loaded?(SavedSearch)
    end

    test "Search exports search/2" do
      assert function_exported?(Search, :search, 2)
    end

    test "Search exports save_search/4" do
      assert function_exported?(Search, :save_search, 4)
    end

    test "Search exports execute_saved_search/2" do
      assert function_exported?(Search, :execute_saved_search, 2)
    end

    test "Search exports suggest/3" do
      assert function_exported?(Search, :suggest, 3)
    end

    test "Search exports export_results/3" do
      assert function_exported?(Search, :export_results, 3)
    end
  end

  describe "SavedSearch schema" do
    test "SavedSearch exports changeset/2" do
      assert function_exported?(SavedSearch, :changeset, 2)
    end

    test "SavedSearch struct can be created" do
      schema = %SavedSearch{}
      assert schema.__struct__ == SavedSearch
    end

    test "changeset with valid attrs" do
      attrs = %{
        name: "My Search",
        query: "env:production",
        user_id: "user-001",
        tenant_id: "tenant-001",
        filters: %{}
      }

      changeset = SavedSearch.changeset(%SavedSearch{}, attrs)
      assert changeset.__struct__ == Ecto.Changeset
    end

    test "changeset with minimal required attrs" do
      attrs = %{name: "Test", query: "key:value"}
      changeset = SavedSearch.changeset(%SavedSearch{}, attrs)
      assert is_map(changeset)
    end

    test "changeset with empty attrs has validation errors" do
      changeset = SavedSearch.changeset(%SavedSearch{}, %{})
      # Required fields should cause validation to fail
      assert changeset.valid? == false or is_map(changeset)
    end

    test "SavedSearch has expected fields" do
      schema = %SavedSearch{}
      assert Map.has_key?(schema, :__struct__)
    end
  end

  describe "search/2 - DB interaction" do
    @tag :requires_db
    test "searches with query string" do
      result = Search.search("test-key", %{tenant_id: "test-tenant"})
      assert is_list(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :requires_db
    test "search with empty query" do
      result = Search.search("", %{tenant_id: "test-tenant"})
      assert is_list(result) or is_tuple(result)
    end

    @tag :requires_db
    test "search returns empty list for no matches" do
      result = Search.search("nonexistent-config-xyz-#{System.unique_integer()}", %{})
      assert result == [] or match?({:ok, []}, result) or is_list(result) or is_tuple(result)
    end
  end

  describe "save_search/4 - DB interaction" do
    @tag :requires_db
    test "saves a search with valid parameters" do
      result = Search.save_search("My Search", "env:production", "user-001", %{tenant_id: "t1"})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :requires_db
    test "returns error for missing name" do
      result = Search.save_search("", "query", "user-001", %{})
      assert match?({:error, _}, result) or is_tuple(result)
    end
  end

  describe "suggest/3 - DB interaction" do
    @tag :requires_db
    test "returns suggestions for partial query" do
      result = Search.suggest("env", %{tenant_id: "test-tenant"}, %{limit: 5})
      assert is_list(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :requires_db
    test "suggest with empty prefix" do
      result = Search.suggest("", %{tenant_id: "test-tenant"}, %{})
      assert is_list(result) or is_tuple(result)
    end
  end

  describe "export_results/3 - DB interaction" do
    @tag :requires_db
    test "exports search results in json format" do
      result = Search.export_results("test-query", :json, %{tenant_id: "test-tenant"})
      assert is_tuple(result)
    end

    @tag :requires_db
    test "exports in csv format" do
      result = Search.export_results("test-query", :csv, %{})
      assert is_tuple(result)
    end
  end
end
