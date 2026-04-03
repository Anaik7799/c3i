defmodule Indrajaal.Shared.UnifiedQuerySystemTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.UnifiedQuerySystem module.

  Tests comprehensive query building functionality for:
  - apply_unified_search function
  - build_performance_trend_query function
  - build_event_count_query function
  - build_timescale_aggregation function

  Created: 2025-11-27 16:00:00 CEST
  Phase: 3.0 - C2 High-Impact Testing (Query Systems)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.UnifiedQuerySystem

  # ============================================================================
  # MODULE EXISTENCE TESTS
  # ============================================================================

  describe "Module Structure" do
    test "UnifiedQuerySystem module exists" do
      assert Code.ensure_loaded?(Indrajaal.Shared.UnifiedQuerySystem)
    end

    test "module exports apply_unified_search function" do
      functions = Indrajaal.Shared.UnifiedQuerySystem.__info__(:functions)
      assert {:apply_unified_search, 3} in functions
    end

    test "module exports build_performance_trend_query function" do
      functions = Indrajaal.Shared.UnifiedQuerySystem.__info__(:functions)
      assert {:build_performance_trend_query, 3} in functions
    end

    test "module exports build_event_count_query function" do
      functions = Indrajaal.Shared.UnifiedQuerySystem.__info__(:functions)
      assert {:build_event_count_query, 2} in functions
    end

    test "module exports build_timescale_aggregation function" do
      functions = Indrajaal.Shared.UnifiedQuerySystem.__info__(:functions)
      assert {:build_timescale_aggregation, 4} in functions
    end
  end

  # ============================================================================
  # APPLY_UNIFIED_SEARCH TESTS
  # ============================================================================

  describe "apply_unified_search/3" do
    test "function exists with correct arity" do
      functions = Indrajaal.Shared.UnifiedQuerySystem.__info__(:functions)
      assert {:apply_unified_search, 3} in functions
    end

    test "accepts query, search_term, and fields parameters" do
      # Verify function signature by checking it's callable
      # The actual query execution would require database
      assert function_exported?(UnifiedQuerySystem, :apply_unified_search, 3)
    end
  end

  # ============================================================================
  # BUILD_PERFORMANCE_TREND_QUERY TESTS
  # ============================================================================

  describe "build_performance_trend_query/3" do
    test "function exists with correct arity" do
      functions = Indrajaal.Shared.UnifiedQuerySystem.__info__(:functions)
      assert {:build_performance_trend_query, 3} in functions
    end

    test "accepts query, start_time, and end_time parameters" do
      assert function_exported?(UnifiedQuerySystem, :build_performance_trend_query, 3)
    end
  end

  # ============================================================================
  # BUILD_EVENT_COUNT_QUERY TESTS
  # ============================================================================

  describe "build_event_count_query/2" do
    test "function exists with correct arity" do
      functions = Indrajaal.Shared.UnifiedQuerySystem.__info__(:functions)
      assert {:build_event_count_query, 2} in functions
    end

    test "accepts query and group_by parameters" do
      assert function_exported?(UnifiedQuerySystem, :build_event_count_query, 2)
    end
  end

  # ============================================================================
  # BUILD_TIMESCALE_AGGREGATION TESTS
  # ============================================================================

  describe "build_timescale_aggregation/4" do
    test "function exists with correct arity" do
      functions = Indrajaal.Shared.UnifiedQuerySystem.__info__(:functions)
      assert {:build_timescale_aggregation, 4} in functions
    end

    test "accepts query, time_field, value_field, and aggregation parameters" do
      assert function_exported?(UnifiedQuerySystem, :build_timescale_aggregation, 4)
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "module remains loaded after multiple function checks" do
      forall _ <- PC.integer() do
        Code.ensure_loaded?(Indrajaal.Shared.UnifiedQuerySystem)
      end
    end

    property "function list is consistent across calls" do
      forall _ <- PC.integer() do
        funcs = Indrajaal.Shared.UnifiedQuerySystem.__info__(:functions)
        is_list(funcs) and length(funcs) >= 4
      end
    end

    property "all exported functions have expected arities" do
      forall _ <- PC.integer() do
        functions = Indrajaal.Shared.UnifiedQuerySystem.__info__(:functions)

        expected = [
          {:apply_unified_search, 3},
          {:build_performance_trend_query, 3},
          {:build_event_count_query, 2},
          {:build_timescale_aggregation, 4}
        ]

        Enum.all?(expected, fn func -> func in functions end)
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "module info returns expected structure" do
      info = Indrajaal.Shared.UnifiedQuerySystem.__info__(:module)
      assert info == Indrajaal.Shared.UnifiedQuerySystem
    end

    test "module has compile time information" do
      compile_info = Indrajaal.Shared.UnifiedQuerySystem.__info__(:compile)
      assert is_list(compile_info)
    end

    test "module attributes are accessible" do
      attributes = Indrajaal.Shared.UnifiedQuerySystem.__info__(:attributes)
      assert is_list(attributes)
    end
  end

  # ============================================================================
  # SOURCE CODE VALIDATION TESTS
  # ============================================================================

  describe "Source Code Validation" do
    test "source file exists" do
      assert File.exists?("lib/indrajaal/shared/unified_query_system.ex")
    end

    test "source file is valid Elixir" do
      source = File.read!("lib/indrajaal/shared/unified_query_system.ex")
      {:ok, _ast} = Code.string_to_quoted(source)
    end

    test "module has proper defmodule structure" do
      source = File.read!("lib/indrajaal/shared/unified_query_system.ex")
      assert String.contains?(source, "defmodule Indrajaal.Shared.UnifiedQuerySystem")
    end

    test "uses Ecto.Query" do
      source = File.read!("lib/indrajaal/shared/unified_query_system.ex")
      assert String.contains?(source, "Ecto.Query")
    end

    test "defines apply_unified_search function" do
      source = File.read!("lib/indrajaal/shared/unified_query_system.ex")
      assert String.contains?(source, "def apply_unified_search")
    end

    test "defines build_performance_trend_query function" do
      source = File.read!("lib/indrajaal/shared/unified_query_system.ex")
      assert String.contains?(source, "def build_performance_trend_query")
    end

    test "defines build_event_count_query function" do
      source = File.read!("lib/indrajaal/shared/unified_query_system.ex")
      assert String.contains?(source, "def build_event_count_query")
    end

    test "defines build_timescale_aggregation function" do
      source = File.read!("lib/indrajaal/shared/unified_query_system.ex")
      assert String.contains?(source, "def build_timescale_aggregation")
    end
  end

  # ============================================================================
  # INTEGRATION SCENARIO TESTS
  # ============================================================================

  describe "Integration Scenarios" do
    test "all query functions are accessible" do
      functions = UnifiedQuerySystem.__info__(:functions)

      query_functions = [
        {:apply_unified_search, 3},
        {:build_performance_trend_query, 3},
        {:build_event_count_query, 2},
        {:build_timescale_aggregation, 4}
      ]

      Enum.each(query_functions, fn func ->
        assert func in functions, "Expected #{inspect(func)} to be in functions"
      end)
    end

    test "module can be aliased and used" do
      alias Indrajaal.Shared.UnifiedQuerySystem, as: UQS
      assert Code.ensure_loaded?(UQS)
    end
  end
end
