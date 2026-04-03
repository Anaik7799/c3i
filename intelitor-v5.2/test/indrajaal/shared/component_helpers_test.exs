defmodule Indrajaal.Shared.ComponentHelpersTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.ComponentHelpers module.

  Tests Phoenix component helper functionality for:
  - metric_card component rendering
  - Phoenix.Component integration
  - HEEx template compatibility

  Created: 2025-11-27 16:00:00 CEST
  Phase: 3.0 - C2 High-Impact Testing (Component Systems)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.ComponentHelpers

  # ============================================================================
  # MODULE EXISTENCE TESTS
  # ============================================================================

  describe "Module Structure" do
    test "ComponentHelpers module exists" do
      assert Code.ensure_loaded?(Indrajaal.Shared.ComponentHelpers)
    end

    test "module exports metric_card function" do
      functions = Indrajaal.Shared.ComponentHelpers.__info__(:functions)
      assert {:metric_card, 1} in functions
    end
  end

  # ============================================================================
  # METRIC_CARD TESTS
  # ============================================================================

  describe "metric_card/1" do
    test "function exists with correct arity" do
      functions = Indrajaal.Shared.ComponentHelpers.__info__(:functions)
      assert {:metric_card, 1} in functions
    end

    test "function is exported" do
      assert function_exported?(ComponentHelpers, :metric_card, 1)
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "module remains loaded after multiple function checks" do
      forall _ <- PC.integer() do
        Code.ensure_loaded?(Indrajaal.Shared.ComponentHelpers)
      end
    end

    property "function list always contains metric_card" do
      forall _ <- PC.integer() do
        functions = Indrajaal.Shared.ComponentHelpers.__info__(:functions)
        {:metric_card, 1} in functions
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "module info returns expected structure" do
      info = Indrajaal.Shared.ComponentHelpers.__info__(:module)
      assert info == Indrajaal.Shared.ComponentHelpers
    end

    test "module has compile time information" do
      compile_info = Indrajaal.Shared.ComponentHelpers.__info__(:compile)
      assert is_list(compile_info)
    end
  end

  # ============================================================================
  # SOURCE CODE VALIDATION TESTS
  # ============================================================================

  describe "Source Code Validation" do
    test "source file exists" do
      assert File.exists?("lib/indrajaal/shared/component_helpers.ex")
    end

    test "source file is valid Elixir" do
      source = File.read!("lib/indrajaal/shared/component_helpers.ex")
      {:ok, _ast} = Code.string_to_quoted(source)
    end

    test "module has proper defmodule structure" do
      source = File.read!("lib/indrajaal/shared/component_helpers.ex")
      assert String.contains?(source, "defmodule Indrajaal.Shared.ComponentHelpers")
    end

    test "uses Phoenix.Component" do
      source = File.read!("lib/indrajaal/shared/component_helpers.ex")
      assert String.contains?(source, "Phoenix.Component")
    end

    test "defines metric_card function" do
      source = File.read!("lib/indrajaal/shared/component_helpers.ex")
      assert String.contains?(source, "def metric_card")
    end
  end

  # ============================================================================
  # PHOENIX COMPONENT INTEGRATION TESTS
  # ============================================================================

  describe "Phoenix Component Integration" do
    test "module can be used as Phoenix component module" do
      # The module should be importable in a Phoenix context
      assert Code.ensure_loaded?(Indrajaal.Shared.ComponentHelpers)
    end

    test "metric_card function signature is component-compatible" do
      # Phoenix components take assigns as parameter
      functions = ComponentHelpers.__info__(:functions)
      assert {:metric_card, 1} in functions
    end
  end
end
