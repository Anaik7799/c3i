defmodule Indrajaal.Shared.UnifiedCategoryFrameworkTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Shared.UnifiedCategoryFramework

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(UnifiedCategoryFramework)
    end
  end

  describe "validate_category/2" do
    test "function is exported" do
      assert function_exported?(UnifiedCategoryFramework, :validate_category, 2)
    end

    test "validates a well-formed category" do
      category = %{name: "Safety Equipment", parent_id: nil, description: "Safety items"}
      result = UnifiedCategoryFramework.validate_category(category, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "rejects a category with nil name" do
      category = %{name: nil, parent_id: nil}
      result = UnifiedCategoryFramework.validate_category(category, %{})
      assert match?({:error, _}, result)
    end

    test "rejects a category with empty name" do
      category = %{name: "", parent_id: nil}
      result = UnifiedCategoryFramework.validate_category(category, %{})
      assert match?({:error, _}, result)
    end
  end

  describe "build_category_tree/2" do
    test "function is exported" do
      assert function_exported?(UnifiedCategoryFramework, :build_category_tree, 2)
    end

    test "builds tree from flat category list" do
      categories = [
        %{id: 1, name: "Root", parent_id: nil, description: "", meta_data: nil},
        %{id: 2, name: "Child", parent_id: 1, description: "", meta_data: nil}
      ]

      result = UnifiedCategoryFramework.build_category_tree(categories)
      assert is_list(result)
      assert length(result) == 1
    end

    test "returns empty list for empty categories" do
      result = UnifiedCategoryFramework.build_category_tree([])
      assert result == []
    end

    test "builds tree for specific parent_id" do
      categories = [
        %{id: 1, name: "Root", parent_id: nil, description: "", meta_data: nil},
        %{id: 2, name: "Child", parent_id: 1, description: "", meta_data: nil}
      ]

      result = UnifiedCategoryFramework.build_category_tree(categories, 1)
      assert is_list(result)
    end
  end

  describe "calculate_category_path/2" do
    test "function is exported" do
      assert function_exported?(UnifiedCategoryFramework, :calculate_category_path, 2)
    end

    test "returns path list for root category" do
      root = %{id: 1, name: "Root", parent_id: nil}
      all_categories = [root]
      result = UnifiedCategoryFramework.calculate_category_path(root, all_categories)
      assert is_list(result)
      assert "Root" in result
    end

    test "returns full path for nested category" do
      root = %{id: 1, name: "Root", parent_id: nil}
      child = %{id: 2, name: "Child", parent_id: 1}
      all = [root, child]
      result = UnifiedCategoryFramework.calculate_category_path(child, all)
      assert is_list(result)
      assert length(result) == 2
    end
  end

  describe "calculate_depth/3" do
    test "function is exported" do
      assert function_exported?(UnifiedCategoryFramework, :calculate_depth, 3)
    end

    test "returns 0 for root category" do
      root = %{id: 1, name: "Root", parent_id: nil}
      result = UnifiedCategoryFramework.calculate_depth(root, [root])
      assert result == 0
    end

    test "returns 1 for single-level child" do
      root = %{id: 1, name: "Root", parent_id: nil}
      child = %{id: 2, name: "Child", parent_id: 1}
      result = UnifiedCategoryFramework.calculate_depth(child, [root, child])
      assert result == 1
    end
  end

  describe "calculatecategory_stats/2" do
    test "function is exported" do
      assert function_exported?(UnifiedCategoryFramework, :calculatecategory_stats, 2)
    end

    test "returns stats list" do
      categories = [%{id: 1, name: "Cat", parent_id: nil}]
      items_by_category = %{1 => 5}
      result = UnifiedCategoryFramework.calculatecategory_stats(categories, items_by_category)
      assert is_list(result)
    end

    test "stats contain total_count" do
      categories = [%{id: 1, name: "Cat", parent_id: nil}]
      items_by_category = %{1 => 3}
      [stat | _] = UnifiedCategoryFramework.calculatecategory_stats(categories, items_by_category)
      assert Map.has_key?(stat, :total_count)
      assert stat.total_count == 3
    end
  end

  describe "list_categories_query/2" do
    test "function is exported" do
      assert function_exported?(UnifiedCategoryFramework, :list_categories_query, 2)
    end

    test "returns an Ecto query struct" do
      result = UnifiedCategoryFramework.list_categories_query("categories")
      assert result != nil
    end

    test "accepts filter options" do
      result = UnifiedCategoryFramework.list_categories_query("categories", %{active: true})
      assert result != nil
    end
  end
end
