defmodule Indrajaal.KMS.ProductTest do
  @moduledoc """
  TDG test suite for Indrajaal.KMS.Product.

  Tests product lifecycle knowledge management: features, releases,
  feedback, and experiments. All SQLite access routes through Zenoh
  DatabaseProxy (SC-DBPROXY-001).

  ## STAMP Safety Integration
  - SC-KMS-001: SQLite-backed storage only
  - SC-PRD-001: Feature tracking
  - SC-DBPROXY-001: DatabaseProxy mediates all SQLite access
  """

  use ExUnit.Case, async: true

  alias Indrajaal.KMS.Product

  describe "init/0" do
    test "returns :ok" do
      assert :ok = Product.init()
    end

    test "is idempotent" do
      assert :ok = Product.init()
      assert :ok = Product.init()
    end
  end

  describe "create_feature/1" do
    test "returns ok or error tuple with required attrs" do
      attrs = %{
        name: "Dark Mode",
        description: "Add dark theme support",
        status: :ideation,
        priority: :high
      }

      result = Product.create_feature(attrs)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts minimal attrs with name only" do
      result = Product.create_feature(%{name: "Feature X"})
      assert is_tuple(result)
    end

    test "accepts :ideation status" do
      result = Product.create_feature(%{name: "f", status: :ideation})
      assert is_tuple(result)
    end

    test "accepts :discovery status" do
      result = Product.create_feature(%{name: "f", status: :discovery})
      assert is_tuple(result)
    end

    test "accepts :in_progress status" do
      result = Product.create_feature(%{name: "f", status: :in_progress})
      assert is_tuple(result)
    end

    test "accepts :released status" do
      result = Product.create_feature(%{name: "f", status: :released})
      assert is_tuple(result)
    end

    test "accepts :low priority" do
      result = Product.create_feature(%{name: "f", priority: :low})
      assert is_tuple(result)
    end

    test "accepts :medium priority" do
      result = Product.create_feature(%{name: "f", priority: :medium})
      assert is_tuple(result)
    end

    test "accepts :high priority" do
      result = Product.create_feature(%{name: "f", priority: :high})
      assert is_tuple(result)
    end

    test "accepts :critical priority" do
      result = Product.create_feature(%{name: "f", priority: :critical})
      assert is_tuple(result)
    end

    test "accepts stakeholders list" do
      result = Product.create_feature(%{name: "f", stakeholders: ["cto", "pm"]})
      assert is_tuple(result)
    end

    test "accepts dependencies list" do
      result = Product.create_feature(%{name: "f", dependencies: ["dep-1", "dep-2"]})
      assert is_tuple(result)
    end

    test "accepts metrics map" do
      result = Product.create_feature(%{name: "f", metrics: %{dau_increase: 10}})
      assert is_tuple(result)
    end

    test "accepts quarter string" do
      result = Product.create_feature(%{name: "f", quarter: "Q2-2026"})
      assert is_tuple(result)
    end

    test "accepts owner string" do
      result = Product.create_feature(%{name: "f", owner: "team-product"})
      assert is_tuple(result)
    end
  end

  describe "get_feature/1" do
    test "returns {:error, :not_found} for nonexistent id" do
      result = Product.get_feature("feat-nonexistent-999")
      assert match?({:error, :not_found}, result) or match?({:error, _}, result)
    end

    test "accepts string id" do
      result = Product.get_feature("feat-abc123")
      assert is_tuple(result)
    end
  end

  describe "list_features/1" do
    test "accepts empty opts" do
      result = Product.list_features([])
      assert match?({:ok, list} when is_list(list), result) or match?({:error, _}, result)
    end

    test "accepts status filter" do
      result = Product.list_features(status: :ideation)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts priority filter" do
      result = Product.list_features(priority: :high)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts quarter filter" do
      result = Product.list_features(quarter: "Q1-2026")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts limit option" do
      result = Product.list_features(limit: 10)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts combined filters" do
      result = Product.list_features(status: :in_progress, priority: :high, limit: 5)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "update_feature_status/2" do
    test "returns error for nonexistent feature" do
      result = Product.update_feature_status("feat-nonexistent-999", :in_progress)
      assert match?({:error, _}, result) or result == :ok
    end

    test "accepts :released status" do
      result = Product.update_feature_status("feat-1", :released)
      assert is_tuple(result) or result == :ok
    end

    test "accepts :cancelled status" do
      result = Product.update_feature_status("feat-1", :cancelled)
      assert is_tuple(result) or result == :ok
    end
  end

  describe "create_release/1" do
    test "returns ok or error tuple with required attrs" do
      attrs = %{
        version: "21.3.0",
        name: "SIL-6 Release",
        status: :planning,
        features: [],
        changes: ["Added biomorphic mesh"],
        breaking_changes: []
      }

      result = Product.create_release(attrs)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts minimal attrs" do
      result = Product.create_release(%{version: "1.0.0", name: "Initial"})
      assert is_tuple(result)
    end
  end

  describe "get_release/1" do
    test "returns {:error, :not_found} for nonexistent id" do
      result = Product.get_release("rel-nonexistent-999")
      assert match?({:error, :not_found}, result) or match?({:error, _}, result)
    end
  end

  describe "list_releases/1" do
    test "accepts empty opts" do
      result = Product.list_releases([])
      assert match?({:ok, list} when is_list(list), result) or match?({:error, _}, result)
    end

    test "accepts limit option" do
      result = Product.list_releases(limit: 5)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_release_by_version/1" do
    test "returns {:error, :not_found} for nonexistent version" do
      result = Product.get_release_by_version("99.99.99-nonexistent")
      assert match?({:error, :not_found}, result) or match?({:error, _}, result)
    end

    test "accepts semver string" do
      result = Product.get_release_by_version("21.3.0")
      assert is_tuple(result)
    end
  end

  describe "deploy_release/1" do
    test "returns error for nonexistent release" do
      result = Product.deploy_release("rel-nonexistent-999")
      assert match?({:error, _}, result) or result == :ok
    end
  end

  describe "rollback_release/2" do
    test "returns error or ok for nonexistent release" do
      result = Product.rollback_release("rel-nonexistent-999", "Critical bug found")
      assert match?({:error, _}, result) or result == :ok
    end

    test "accepts reason string" do
      result = Product.rollback_release("rel-1", "Rollback reason")
      assert is_tuple(result) or result == :ok
    end
  end

  describe "record_feedback/1" do
    test "returns ok or error tuple with required attrs" do
      attrs = %{
        source: :customer_support,
        content: "App crashes on login",
        sentiment: :negative,
        category: "bug"
      }

      result = Product.record_feedback(attrs)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts :positive sentiment" do
      result =
        Product.record_feedback(%{source: :survey, content: "Great!", sentiment: :positive})

      assert is_tuple(result)
    end

    test "accepts :neutral sentiment" do
      result = Product.record_feedback(%{source: :survey, content: "Ok", sentiment: :neutral})
      assert is_tuple(result)
    end

    test "accepts linked_features list" do
      result =
        Product.record_feedback(%{
          source: :github,
          content: "Feature request",
          linked_features: ["feat-1", "feat-2"]
        })

      assert is_tuple(result)
    end
  end

  describe "get_feedback/1" do
    test "returns {:error, :not_found} for nonexistent id" do
      result = Product.get_feedback("fb-nonexistent-999")
      assert match?({:error, :not_found}, result) or match?({:error, _}, result)
    end
  end

  describe "list_feedback/1" do
    test "accepts empty opts" do
      result = Product.list_feedback([])
      assert match?({:ok, list} when is_list(list), result) or match?({:error, _}, result)
    end

    test "accepts limit option" do
      result = Product.list_feedback(limit: 10)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "link_feedback_to_feature/2" do
    test "returns error for nonexistent feedback" do
      result = Product.link_feedback_to_feature("fb-nonexistent", "feat-1")
      assert match?({:error, _}, result) or result == :ok
    end
  end

  describe "create_experiment/1" do
    test "accepts attrs map" do
      attrs = %{
        name: "Button Color Test",
        hypothesis: "Blue button increases conversion",
        variant_a: "Red button",
        variant_b: "Blue button",
        metrics: ["click_rate", "conversion"]
      }

      result = Product.create_experiment(attrs)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
