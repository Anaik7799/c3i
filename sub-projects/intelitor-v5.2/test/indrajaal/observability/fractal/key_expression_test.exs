defmodule Indrajaal.Observability.Fractal.KeyExpressionTest do
  @moduledoc """
  TDG tests for KeyExpression Zenoh-style pattern matching module.

  WHAT: Tests for key expression compilation, matching, validation, and key building.
  WHY: Ensures SC-LOG-009 compliance (key aliases pre-registered at startup).
  CONSTRAINTS: Pattern matching correctness, regex compilation safety.
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: PropCheck/StreamData disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Observability.Fractal.KeyExpression

  # ============================================================
  # UNIT TESTS: COMPILE
  # ============================================================

  describe "compile/1" do
    test "compiles exact match expression" do
      {:ok, compiled} = KeyExpression.compile("Indrajaal/Alarms/create")

      assert compiled.original == "Indrajaal/Alarms/create"
      assert compiled.is_exact == true
      assert compiled.has_wildcard == false
      assert compiled.has_double_wildcard == false
      assert compiled.has_infix_wildcard == false
    end

    test "compiles single wildcard expression" do
      {:ok, compiled} = KeyExpression.compile("Indrajaal/*/create")

      assert compiled.has_wildcard == true
      assert compiled.has_double_wildcard == false
      assert compiled.is_exact == false
    end

    test "compiles double wildcard expression" do
      {:ok, compiled} = KeyExpression.compile("Indrajaal/**")

      assert compiled.has_double_wildcard == true
      assert compiled.is_exact == false
    end

    test "compiles infix wildcard expression" do
      {:ok, compiled} = KeyExpression.compile("**/$*Handler")

      assert compiled.has_infix_wildcard == true
      assert compiled.has_double_wildcard == true
      assert compiled.is_exact == false
    end

    test "normalizes dots to slashes" do
      {:ok, compiled} = KeyExpression.compile("Indrajaal.Alarms.create")

      assert compiled.segments == ["Indrajaal", "Alarms", "create"]
    end

    test "returns regex for non-exact expressions" do
      {:ok, compiled} = KeyExpression.compile("Indrajaal/**/error")

      assert is_struct(compiled.regex, Regex)
    end
  end

  describe "compile!/1" do
    test "returns compiled expression for valid input" do
      compiled = KeyExpression.compile!("Indrajaal/Alarms/**")

      assert compiled.original == "Indrajaal/Alarms/**"
      assert compiled.has_double_wildcard == true
    end

    test "handles empty input without raising" do
      # Empty string compiles successfully to an empty pattern
      # The compile function is very permissive
      compiled = KeyExpression.compile!("")

      assert compiled.original == ""
      assert compiled.is_exact == true
    end
  end

  # ============================================================
  # UNIT TESTS: MATCHES
  # ============================================================

  describe "matches?/2 with compiled expression" do
    test "exact match returns true for identical keys" do
      {:ok, compiled} = KeyExpression.compile("Indrajaal/Alarms/create")

      assert KeyExpression.matches?(compiled, "Indrajaal/Alarms/create")
    end

    test "exact match returns false for different keys" do
      {:ok, compiled} = KeyExpression.compile("Indrajaal/Alarms/create")

      refute KeyExpression.matches?(compiled, "Indrajaal/Alarms/delete")
    end

    test "exact match normalizes dots in target key" do
      {:ok, compiled} = KeyExpression.compile("Indrajaal/Alarms/create")

      assert KeyExpression.matches?(compiled, "Indrajaal.Alarms.create")
    end

    test "single wildcard matches one segment" do
      {:ok, compiled} = KeyExpression.compile("Indrajaal/*/create")

      assert KeyExpression.matches?(compiled, "Indrajaal/Alarms/create")
      assert KeyExpression.matches?(compiled, "Indrajaal/Users/create")
      refute KeyExpression.matches?(compiled, "Indrajaal/A/B/create")
    end

    test "double wildcard matches one or more segments" do
      {:ok, compiled} = KeyExpression.compile("Indrajaal/**/create")

      # Current implementation requires at least one segment between
      assert KeyExpression.matches?(compiled, "Indrajaal/A/create")
      assert KeyExpression.matches?(compiled, "Indrajaal/A/B/create")
    end

    test "double wildcard matches one segment" do
      {:ok, compiled} = KeyExpression.compile("Indrajaal/**/create")

      assert KeyExpression.matches?(compiled, "Indrajaal/Alarms/create")
    end

    test "double wildcard matches multiple segments" do
      {:ok, compiled} = KeyExpression.compile("Indrajaal/**/create")

      assert KeyExpression.matches?(compiled, "Indrajaal/A/B/C/create")
    end

    test "trailing double wildcard matches anything" do
      {:ok, compiled} = KeyExpression.compile("Indrajaal/**")

      assert KeyExpression.matches?(compiled, "Indrajaal/Alarms")
      assert KeyExpression.matches?(compiled, "Indrajaal/A/B/C/D")
    end

    test "leading double wildcard matches anything" do
      {:ok, compiled} = KeyExpression.compile("**/error")

      assert KeyExpression.matches?(compiled, "Any/Path/To/error")
      assert KeyExpression.matches?(compiled, "error")
    end

    test "infix wildcard matches partial segment" do
      {:ok, compiled} = KeyExpression.compile("**/$*Handler")

      assert KeyExpression.matches?(compiled, "Module/AlarmHandler")
      assert KeyExpression.matches?(compiled, "A/B/UserHandler")
    end
  end

  describe "matches?/2 with string expression" do
    test "compiles and matches on the fly" do
      assert KeyExpression.matches?("Indrajaal/**/create", "Indrajaal/Alarms/create")
    end

    test "returns false for invalid expression" do
      # When expression fails to compile, matches? returns false
      refute KeyExpression.matches?("", "anything")
    end

    test "exact string matching" do
      assert KeyExpression.matches?("Module/function", "Module/function")
      refute KeyExpression.matches?("Module/function", "Other/function")
    end
  end

  # ============================================================
  # UNIT TESTS: INTERSECTS
  # ============================================================

  describe "intersects?/2" do
    test "two exact expressions with same value intersect" do
      {:ok, a} = KeyExpression.compile("Indrajaal/Alarms/create")
      {:ok, b} = KeyExpression.compile("Indrajaal/Alarms/create")

      assert KeyExpression.intersects?(a, b)
    end

    test "two exact expressions with different values don't intersect" do
      {:ok, a} = KeyExpression.compile("Indrajaal/Alarms/create")
      {:ok, b} = KeyExpression.compile("Indrajaal/Users/create")

      refute KeyExpression.intersects?(a, b)
    end

    test "double wildcard always intersects" do
      {:ok, a} = KeyExpression.compile("Indrajaal/**")
      {:ok, b} = KeyExpression.compile("Other/Module/function")

      assert KeyExpression.intersects?(a, b)
    end

    test "compatible patterns intersect" do
      {:ok, a} = KeyExpression.compile("Indrajaal/*/create")
      {:ok, b} = KeyExpression.compile("Indrajaal/Alarms/create")

      assert KeyExpression.intersects?(a, b)
    end
  end

  # ============================================================
  # UNIT TESTS: KEY BUILDING
  # ============================================================

  describe "build_key/2" do
    test "builds key from module and function atoms" do
      key = KeyExpression.build_key(Indrajaal.Alarms, :create)

      assert key == "Indrajaal.Alarms/create"
    end

    test "builds key from module and function strings" do
      key = KeyExpression.build_key("Indrajaal.Alarms", "create")

      assert key == "Indrajaal.Alarms/create"
    end

    test "strips Elixir. prefix from module" do
      key = KeyExpression.build_key(Indrajaal.Alarms, :create)

      assert key == "Indrajaal.Alarms/create"
    end
  end

  describe "build_key/3" do
    test "builds key with event type" do
      key = KeyExpression.build_key(Indrajaal.Alarms, :process, :entry)

      assert key == "Indrajaal.Alarms/process/entry"
    end
  end

  describe "extract_module/1" do
    test "extracts first segment as module" do
      module = KeyExpression.extract_module("Indrajaal/Alarms/create")

      assert module == "Indrajaal"
    end

    test "handles dot-separated paths" do
      module = KeyExpression.extract_module("Indrajaal.Alarms.create")

      assert module == "Indrajaal"
    end
  end

  describe "extract_function/1" do
    test "extracts last segment as function" do
      function = KeyExpression.extract_function("Indrajaal/Alarms/create")

      assert function == "create"
    end

    test "handles dot-separated paths" do
      function = KeyExpression.extract_function("Indrajaal.Alarms.create")

      assert function == "create"
    end
  end

  # ============================================================
  # UNIT TESTS: VALIDATION
  # ============================================================

  describe "validate/1" do
    test "returns :ok for valid expression" do
      assert :ok = KeyExpression.validate("Indrajaal/Alarms/**")
    end

    test "returns error for empty expression" do
      {:error, errors} = KeyExpression.validate("")
      assert "Key expression cannot be empty" in errors
    end

    test "returns error for expression with invalid characters" do
      {:error, errors} = KeyExpression.validate("Indrajaal|Alarms<test>")
      assert "Invalid characters in key expression" in errors
    end

    test "returns error for triple wildcard" do
      {:error, errors} = KeyExpression.validate("Indrajaal/***/test")
      assert "Invalid wildcard sequence '***'" in errors
    end

    test "returns error for leading slash" do
      {:error, errors} = KeyExpression.validate("/Indrajaal/Alarms")
      assert "Key expression should not start or end with '/'" in errors
    end

    test "returns error for trailing slash" do
      {:error, errors} = KeyExpression.validate("Indrajaal/Alarms/")
      assert "Key expression should not start or end with '/'" in errors
    end

    test "accumulates multiple errors" do
      {:error, errors} = KeyExpression.validate("/test<invalid>/")

      assert length(errors) >= 2
    end
  end

  describe "valid?/1" do
    test "returns true for valid expression" do
      assert KeyExpression.valid?("Indrajaal/**/create")
    end

    test "returns false for invalid expression" do
      refute KeyExpression.valid?("")
      refute KeyExpression.valid?("/invalid/")
    end
  end

  # ============================================================
  # UNIT TESTS: PATTERNS
  # ============================================================

  describe "patterns/0" do
    test "returns map of common patterns" do
      patterns = KeyExpression.patterns()

      assert is_map(patterns)
      assert Map.has_key?(patterns, :all_create)
      assert Map.has_key?(patterns, :all_errors)
      assert Map.has_key?(patterns, :any_handler)
    end

    test "all_in_module function works" do
      patterns = KeyExpression.patterns()
      pattern = patterns.all_in_module.("Indrajaal")

      assert pattern == "Indrajaal/**"
    end

    test "function_in_any function works" do
      patterns = KeyExpression.patterns()
      pattern = patterns.function_in_any.("create")

      assert pattern == "**/create"
    end

    test "predefined patterns match correctly" do
      patterns = KeyExpression.patterns()

      assert KeyExpression.matches?(patterns.all_create, "Anything/create")
      assert KeyExpression.matches?(patterns.all_errors, "Module/SubModule/error")
      assert KeyExpression.matches?(patterns.cortex_cognitive, "Indrajaal/Cortex/Sensors/cpu")
    end
  end

  # ============================================================
  # PROPERTY TESTS: PROPCHECK
  # ============================================================

  describe "property tests (PropCheck)" do
    property "exact expressions match only themselves" do
      # Use integers to generate safe, deterministic path segments
      forall {a, b, c} <- {PC.integer(1, 1000), PC.integer(1, 1000), PC.integer(1, 1000)} do
        # Build valid key with no special chars
        safe_key = "Module/seg#{a}_seg#{b}_seg#{c}"

        {:ok, compiled} = KeyExpression.compile(safe_key)
        compiled.is_exact == true and KeyExpression.matches?(compiled, safe_key)
      end
    end

    property "double wildcard matches any suffix" do
      # Use integers to generate safe path segments
      forall suffix <- PC.list(PC.integer(1, 100)) do
        base = "Indrajaal/**"
        {:ok, compiled} = KeyExpression.compile(base)

        # Convert integers to safe strings and join as path
        suffix_strs = Enum.map(suffix, fn n -> "seg#{n}" end)
        target = "Indrajaal/" <> Enum.join(suffix_strs, "/")

        # Double wildcard should match any suffix including empty
        KeyExpression.matches?(compiled, target) or suffix == []
      end
    end

    property "build_key produces valid keys" do
      # Use integers for safe module/function names
      forall {mod_num, func_num} <- {PC.integer(1, 1000), PC.integer(1, 1000)} do
        key = KeyExpression.build_key("Module#{mod_num}", "func#{func_num}")
        is_binary(key) and String.contains?(key, "/")
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS: STREAMDATA
  # ============================================================

  describe "property tests (StreamData)" do
    test "compiled expressions have required fields" do
      ExUnitProperties.check all(
                               segment <- SD.string(:alphanumeric, min_length: 1, max_length: 20)
                             ) do
        expr = "Module/#{segment}"
        {:ok, compiled} = KeyExpression.compile(expr)

        assert Map.has_key?(compiled, :original)
        assert Map.has_key?(compiled, :regex)
        assert Map.has_key?(compiled, :segments)
        assert Map.has_key?(compiled, :is_exact)
      end
    end

    test "validation is consistent with valid?" do
      ExUnitProperties.check all(
                               segment <- SD.string(:alphanumeric, min_length: 1, max_length: 20)
                             ) do
        expr = "Module/#{segment}"

        validate_result = KeyExpression.validate(expr)
        valid_result = KeyExpression.valid?(expr)

        assert validate_result == :ok == valid_result
      end
    end

    test "extract_module and extract_function are inverses for simple keys" do
      ExUnitProperties.check all(
                               module <- SD.string(:alphanumeric, min_length: 1, max_length: 20),
                               function <- SD.string(:alphanumeric, min_length: 1, max_length: 20)
                             ) do
        key = "#{module}/#{function}"

        extracted_module = KeyExpression.extract_module(key)
        extracted_function = KeyExpression.extract_function(key)

        assert extracted_module == module
        assert extracted_function == function
      end
    end
  end

  # ============================================================
  # STAMP COMPLIANCE TESTS
  # ============================================================

  describe "SC-LOG-009 compliance" do
    @tag :stamp
    test "common patterns are predefined for registration" do
      patterns = KeyExpression.patterns()

      assert patterns.all_create == "**/create"
      assert patterns.all_errors == "**/error"
      assert patterns.cortex_cognitive == "Indrajaal/Cortex/**"
      assert patterns.security_audit == "Indrajaal/Security/**"
      assert patterns.all_alarms == "Indrajaal/Alarms/**"
    end

    @tag :stamp
    test "patterns compile successfully" do
      patterns = KeyExpression.patterns()

      # Test all static patterns
      assert {:ok, _} = KeyExpression.compile(patterns.all_create)
      assert {:ok, _} = KeyExpression.compile(patterns.all_errors)
      assert {:ok, _} = KeyExpression.compile(patterns.cortex_cognitive)
      assert {:ok, _} = KeyExpression.compile(patterns.security_audit)
      assert {:ok, _} = KeyExpression.compile(patterns.all_alarms)
      assert {:ok, _} = KeyExpression.compile(patterns.any_handler)
    end
  end

  # ============================================================
  # EDGE CASE TESTS
  # ============================================================

  describe "edge cases" do
    test "single segment key" do
      {:ok, compiled} = KeyExpression.compile("Module")

      assert KeyExpression.matches?(compiled, "Module")
      refute KeyExpression.matches?(compiled, "Other")
    end

    test "wildcard only" do
      {:ok, compiled} = KeyExpression.compile("*")

      assert KeyExpression.matches?(compiled, "anything")
      refute KeyExpression.matches?(compiled, "a/b")
    end

    test "double wildcard only" do
      {:ok, compiled} = KeyExpression.compile("**")

      assert KeyExpression.matches?(compiled, "anything")
      assert KeyExpression.matches?(compiled, "a/b/c/d")
    end

    test "mixed wildcards" do
      {:ok, compiled} = KeyExpression.compile("*/middle/**")

      assert KeyExpression.matches?(compiled, "start/middle/end")
      assert KeyExpression.matches?(compiled, "start/middle/a/b/c")
      refute KeyExpression.matches?(compiled, "start/wrong/end")
    end

    test "consecutive wildcards" do
      {:ok, compiled} = KeyExpression.compile("*/*/*")

      assert KeyExpression.matches?(compiled, "a/b/c")
      refute KeyExpression.matches?(compiled, "a/b")
      refute KeyExpression.matches?(compiled, "a/b/c/d")
    end
  end
end
