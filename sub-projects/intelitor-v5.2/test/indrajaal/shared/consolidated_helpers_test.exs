defmodule Indrajaal.Shared.ConsolidatedHelpersTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.ConsolidatedHelpers module.

  Tests consolidated helper functions for:
  - sanitize_string function
  - format_currency function
  - normalize_params function
  - calculate_percentage function
  - generate_reference_number function
  - create_audit_entry function
  - log_audit_event function

  Created: 2025-11-27 16:30:00 CEST
  Phase: 3.0 - C2 High-Impact Testing (Consolidated Helpers)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  import ExUnit.CaptureLog

  alias Indrajaal.Shared.ConsolidatedHelpers

  # ============================================================================
  # MODULE EXISTENCE TESTS
  # ============================================================================

  describe "Module Structure" do
    test "ConsolidatedHelpers module exists" do
      assert Code.ensure_loaded?(Indrajaal.Shared.ConsolidatedHelpers)
    end

    test "module exports sanitize_string function" do
      functions = Indrajaal.Shared.ConsolidatedHelpers.__info__(:functions)
      assert {:sanitize_string, 1} in functions
    end

    test "module exports format_currency function" do
      functions = Indrajaal.Shared.ConsolidatedHelpers.__info__(:functions)
      assert {:format_currency, 1} in functions
    end

    test "module exports normalize_params function" do
      functions = Indrajaal.Shared.ConsolidatedHelpers.__info__(:functions)
      assert {:normalize_params, 1} in functions
    end

    test "module exports calculate_percentage function" do
      functions = Indrajaal.Shared.ConsolidatedHelpers.__info__(:functions)
      assert {:calculate_percentage, 2} in functions
    end

    test "module exports generate_reference_number function" do
      functions = Indrajaal.Shared.ConsolidatedHelpers.__info__(:functions)
      assert {:generate_reference_number, 1} in functions
    end

    test "module exports create_audit_entry function" do
      functions = Indrajaal.Shared.ConsolidatedHelpers.__info__(:functions)
      assert {:create_audit_entry, 3} in functions
    end

    test "module exports log_audit_event function" do
      functions = Indrajaal.Shared.ConsolidatedHelpers.__info__(:functions)
      assert {:log_audit_event, 1} in functions
    end
  end

  # ============================================================================
  # SANITIZE_STRING TESTS
  # ============================================================================

  describe "sanitize_string/1" do
    test "trims whitespace from string" do
      result = ConsolidatedHelpers.sanitize_string("  hello  ")

      assert result == "hello"
    end

    test "removes control characters" do
      result = ConsolidatedHelpers.sanitize_string("hello\x00world")

      assert result == "helloworld"
    end

    test "handles empty string" do
      result = ConsolidatedHelpers.sanitize_string("")

      assert result == ""
    end

    test "preserves normal text" do
      result = ConsolidatedHelpers.sanitize_string("Hello World!")

      assert result == "Hello World!"
    end

    test "handles string with only whitespace" do
      result = ConsolidatedHelpers.sanitize_string("   ")

      assert result == ""
    end

    test "removes newlines and tabs as control characters" do
      result = ConsolidatedHelpers.sanitize_string("hello\nworld\t!")

      # Newlines and tabs are control characters
      assert not String.contains?(result, "\n")
      assert not String.contains?(result, "\t")
    end
  end

  # ============================================================================
  # FORMAT_CURRENCY TESTS
  # ============================================================================

  describe "format_currency/1" do
    test "formats integer cents to dollars" do
      result = ConsolidatedHelpers.format_currency(1000)

      assert result == "10.00"
    end

    test "formats with decimal precision" do
      result = ConsolidatedHelpers.format_currency(1050)

      assert result == "10.50"
    end

    test "formats zero" do
      result = ConsolidatedHelpers.format_currency(0)

      assert result == "0.00"
    end

    test "formats small amounts" do
      result = ConsolidatedHelpers.format_currency(1)

      assert result == "0.01"
    end

    test "formats large amounts" do
      result = ConsolidatedHelpers.format_currency(1_000_000)

      assert result == "10_000.00"
    end

    test "handles float input" do
      result = ConsolidatedHelpers.format_currency(1000.0)

      assert result == "10.00"
    end
  end

  # ============================================================================
  # NORMALIZE_PARAMS TESTS
  # ============================================================================

  describe "normalize_params/1" do
    test "trims string values" do
      params = %{name: "  test  "}

      result = ConsolidatedHelpers.normalize_params(params)

      assert result.name == "test"
    end

    test "preserves atom keys" do
      params = %{name: "test", count: 5}

      result = ConsolidatedHelpers.normalize_params(params)

      assert Map.has_key?(result, :name)
      assert Map.has_key?(result, :count)
    end

    test "handles empty map" do
      result = ConsolidatedHelpers.normalize_params(%{})

      assert result == %{}
    end

    test "preserves non-string values" do
      params = %{count: 10, active: true}

      result = ConsolidatedHelpers.normalize_params(params)

      assert result.count == 10
      assert result.active == true
    end
  end

  # ============================================================================
  # CALCULATE_PERCENTAGE TESTS
  # ============================================================================

  describe "calculate_percentage/2" do
    test "calculates correct percentage" do
      result = ConsolidatedHelpers.calculate_percentage(50, 100)

      assert result == 50
    end

    test "rounds to integer" do
      result = ConsolidatedHelpers.calculate_percentage(1, 3)

      # 1/3 = 33.33... rounds to 33
      assert result == 33
    end

    test "handles zero part" do
      result = ConsolidatedHelpers.calculate_percentage(0, 100)

      assert result == 0
    end

    test "handles 100%" do
      result = ConsolidatedHelpers.calculate_percentage(100, 100)

      assert result == 100
    end

    test "handles values greater than total" do
      result = ConsolidatedHelpers.calculate_percentage(150, 100)

      assert result == 150
    end

    test "handles float inputs" do
      result = ConsolidatedHelpers.calculate_percentage(2.5, 10.0)

      assert result == 25
    end
  end

  # ============================================================================
  # GENERATE_REFERENCE_NUMBER TESTS
  # ============================================================================

  describe "generate_reference_number/1" do
    test "generates reference with default prefix" do
      result = ConsolidatedHelpers.generate_reference_number()

      assert String.starts_with?(result, "REF-")
    end

    test "generates reference with custom prefix" do
      result = ConsolidatedHelpers.generate_reference_number("ORD")

      assert String.starts_with?(result, "ORD-")
    end

    test "generates unique references" do
      ref1 = ConsolidatedHelpers.generate_reference_number()
      ref2 = ConsolidatedHelpers.generate_reference_number()

      assert ref1 != ref2
    end

    test "includes timestamp component" do
      result = ConsolidatedHelpers.generate_reference_number("TEST")

      parts = String.split(result, "-")
      assert length(parts) >= 2
    end

    test "reference format is consistent" do
      result = ConsolidatedHelpers.generate_reference_number("INV")

      # Should be PREFIX-TIMESTAMP-RANDOM
      assert Regex.match?(~r/^INV-\d+-\d+$/, result)
    end
  end

  # ============================================================================
  # CREATE_AUDIT_ENTRY TESTS
  # ============================================================================

  describe "create_audit_entry/3" do
    test "creates audit entry with required fields" do
      result = ConsolidatedHelpers.create_audit_entry(:create, :user)

      assert Map.has_key?(result, :action)
      assert Map.has_key?(result, :resource)
      assert Map.has_key?(result, :timestamp)
      assert Map.has_key?(result, :meta_data)
    end

    test "converts action to string" do
      result = ConsolidatedHelpers.create_audit_entry(:delete, :record)

      assert result.action == "delete"
    end

    test "converts resource to string" do
      result = ConsolidatedHelpers.create_audit_entry(:update, :user)

      assert result.resource == "user"
    end

    test "includes timestamp" do
      result = ConsolidatedHelpers.create_audit_entry(:read, :config)

      assert %DateTime{} = result.timestamp
    end

    test "includes provided meta_data" do
      meta_data = %{user_id: 123, ip: "127.0.0.1"}

      result = ConsolidatedHelpers.create_audit_entry(:login, :session, meta_data)

      assert result.meta_data == meta_data
    end

    test "defaults meta_data to empty map" do
      result = ConsolidatedHelpers.create_audit_entry(:action, :resource)

      assert result.meta_data == %{}
    end
  end

  # ============================================================================
  # LOG_AUDIT_EVENT TESTS
  # ============================================================================

  describe "log_audit_event/1" do
    test "logs audit entry" do
      audit_entry = %{
        action: "create",
        resource: "user",
        meta_data: %{user_id: 123},
        timestamp: DateTime.utc_now()
      }

      log =
        capture_log(fn ->
          ConsolidatedHelpers.log_audit_event(audit_entry)
        end)

      assert log =~ "Audit"
    end

    test "includes action in log" do
      audit_entry = %{
        action: "delete",
        resource: "record",
        meta_data: %{},
        timestamp: DateTime.utc_now()
      }

      log =
        capture_log(fn ->
          ConsolidatedHelpers.log_audit_event(audit_entry)
        end)

      assert log =~ "delete"
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "sanitize_string returns binary" do
      forall s <- PC.binary() do
        result = ConsolidatedHelpers.sanitize_string(s)
        is_binary(result)
      end
    end

    property "format_currency returns binary with decimal point" do
      forall n <- PC.non_neg_integer() do
        result = ConsolidatedHelpers.format_currency(n)
        is_binary(result) and String.contains?(result, ".")
      end
    end

    property "calculate_percentage returns non-negative integer when total > 0" do
      forall {part, total} <- {PC.non_neg_integer(), PC.pos_integer()} do
        result = ConsolidatedHelpers.calculate_percentage(part, total)
        is_integer(result) and result >= 0
      end
    end

    property "generate_reference_number always starts with prefix" do
      forall prefix <- PC.non_empty(PC.binary()) do
        result = ConsolidatedHelpers.generate_reference_number(prefix)
        String.starts_with?(result, prefix <> "-")
      end
    end

    property "create_audit_entry always has timestamp" do
      forall {action, resource} <- {PC.atom(), PC.atom()} do
        result = ConsolidatedHelpers.create_audit_entry(action, resource)
        Map.has_key?(result, :timestamp) and result.timestamp != nil
      end
    end

    property "normalize_params always returns map" do
      forall params <- PC.map(PC.atom(), PC.any()) do
        result = ConsolidatedHelpers.normalize_params(params)
        is_map(result)
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "module info returns expected structure" do
      info = ConsolidatedHelpers.__info__(:module)
      assert info == Indrajaal.Shared.ConsolidatedHelpers
    end

    test "calculate_percentage handles edge case of 0 part" do
      result = ConsolidatedHelpers.calculate_percentage(0, 1000)
      assert result == 0
    end

    test "generate_reference_number creates unique values rapidly" do
      refs = for _ <- 1..100, do: ConsolidatedHelpers.generate_reference_number()
      unique_refs = Enum.uniq(refs)

      # All should be unique
      assert length(refs) == length(unique_refs)
    end
  end

  # ============================================================================
  # SOURCE CODE VALIDATION TESTS
  # ============================================================================

  describe "Source Code Validation" do
    test "source file exists" do
      assert File.exists?("lib/indrajaal/shared/consolidated_helpers.ex")
    end

    test "source file is valid Elixir" do
      source = File.read!("lib/indrajaal/shared/consolidated_helpers.ex")
      {:ok, _ast} = Code.string_to_quoted(source)
    end

    test "module has proper defmodule structure" do
      source = File.read!("lib/indrajaal/shared/consolidated_helpers.ex")
      assert String.contains?(source, "defmodule Indrajaal.Shared.ConsolidatedHelpers")
    end

    test "sanitize_string has @spec" do
      source = File.read!("lib/indrajaal/shared/consolidated_helpers.ex")
      assert String.contains?(source, "@spec sanitize_string")
    end

    test "format_currency has @spec" do
      source = File.read!("lib/indrajaal/shared/consolidated_helpers.ex")
      assert String.contains?(source, "@spec format_currency")
    end

    test "calculate_percentage has @spec" do
      source = File.read!("lib/indrajaal/shared/consolidated_helpers.ex")
      assert String.contains?(source, "@spec calculate_percentage")
    end
  end

  # ============================================================================
  # INTEGRATION SCENARIO TESTS
  # ============================================================================

  describe "Integration Scenarios" do
    test "complete audit workflow" do
      # Create audit entry
      entry = ConsolidatedHelpers.create_audit_entry(:create, :user, %{user_id: 123})

      # Log the event
      log =
        capture_log(fn ->
          ConsolidatedHelpers.log_audit_event(entry)
        end)

      assert entry.action == "create"
      assert log =~ "Audit"
    end

    test "parameter sanitization and normalization workflow" do
      # Sanitize a string
      sanitized = ConsolidatedHelpers.sanitize_string("  user input  ")

      # Use in params normalization
      params = %{name: sanitized, count: 10}
      normalized = ConsolidatedHelpers.normalize_params(params)

      assert normalized.name == "user input"
    end

    test "all helper functions are accessible" do
      functions = ConsolidatedHelpers.__info__(:functions)

      helper_functions = [
        {:sanitize_string, 1},
        {:format_currency, 1},
        {:normalize_params, 1},
        {:calculate_percentage, 2},
        {:generate_reference_number, 1},
        {:create_audit_entry, 3},
        {:log_audit_event, 1}
      ]

      Enum.each(helper_functions, fn func ->
        assert func in functions, "Expected #{inspect(func)} to be in functions"
      end)
    end
  end
end
